use std::io::{Read, Write};
use std::net::{SocketAddr, TcpStream};
use std::process::ExitCode;
use std::time::Duration;

use tracing_subscriber::EnvFilter;
use xlsx_export::server::{self, Config};
use xlsx_export::{spec, workbook};

const DEFAULT_BIND: &str = "0.0.0.0:4000";
const DEFAULT_MAX_BODY_MB: usize = 64;

fn main() -> ExitCode {
    match std::env::args().nth(1).as_deref() {
        None | Some("serve") => serve(),
        Some("convert") => convert(),
        Some("healthcheck") => healthcheck(),
        Some(_) => {
            eprintln!("usage: xlsx_export [serve|convert|healthcheck]");
            ExitCode::from(64)
        }
    }
}

fn serve() -> ExitCode {
    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info")))
        .init();

    let bind = env_or("XLSX_EXPORT_BIND", DEFAULT_BIND.to_string());
    let config = Config {
        token: std::env::var("XLSX_EXPORT_TOKEN").ok().filter(|token| !token.is_empty()),
        max_body_bytes: env_or("XLSX_EXPORT_MAX_BODY_MB", DEFAULT_MAX_BODY_MB) * 1024 * 1024,
        max_concurrency: env_or(
            "XLSX_EXPORT_MAX_CONCURRENCY",
            std::thread::available_parallelism().map(usize::from).unwrap_or(2),
        ),
    };

    if config.token.is_none() {
        tracing::warn!("XLSX_EXPORT_TOKEN is not set: every request will be accepted");
    }

    let runtime = match tokio::runtime::Runtime::new() {
        Ok(runtime) => runtime,
        Err(error) => {
            eprintln!("failed to start the runtime: {error}");
            return ExitCode::FAILURE;
        }
    };

    runtime.block_on(async move {
        let listener = match tokio::net::TcpListener::bind(&bind).await {
            Ok(listener) => listener,
            Err(error) => {
                tracing::error!(%error, %bind, "failed to bind");
                return ExitCode::FAILURE;
            }
        };

        tracing::info!(%bind, max_body_bytes = config.max_body_bytes, max_concurrency = config.max_concurrency, "xlsx_export listening");

        match axum::serve(listener, server::router(&config)).with_graceful_shutdown(shutdown_signal()).await {
            Ok(()) => ExitCode::SUCCESS,
            Err(error) => {
                tracing::error!(%error, "server stopped");
                ExitCode::FAILURE
            }
        }
    })
}

fn convert() -> ExitCode {
    let mut input = Vec::new();
    if let Err(error) = std::io::stdin().read_to_end(&mut input) {
        eprintln!("failed to read STDIN: {error}");
        return ExitCode::FAILURE;
    }

    match spec::parse(&input).and_then(|spec| workbook::render(&spec)) {
        Ok(bytes) => match std::io::stdout().lock().write_all(&bytes) {
            Ok(()) => ExitCode::SUCCESS,
            Err(error) => {
                eprintln!("failed to write STDOUT: {error}");
                ExitCode::FAILURE
            }
        },
        Err(error) => {
            eprintln!("{error}");
            ExitCode::from(if error.is_client_error() { 65 } else { 70 })
        }
    }
}

fn healthcheck() -> ExitCode {
    let bind = env_or("XLSX_EXPORT_BIND", DEFAULT_BIND.to_string());
    let port = bind
        .rsplit(':')
        .next()
        .and_then(|port| port.parse::<u16>().ok())
        .unwrap_or(4000);
    let address = SocketAddr::from(([127, 0, 0, 1], port));

    let healthy = TcpStream::connect_timeout(&address, Duration::from_secs(2))
        .and_then(|mut stream| {
            stream.set_read_timeout(Some(Duration::from_secs(2)))?;
            stream.write_all(b"GET /up HTTP/1.0\r\nHost: localhost\r\n\r\n")?;
            let mut response = String::new();
            stream.read_to_string(&mut response)?;
            Ok(response)
        })
        .is_ok_and(|response| response.starts_with("HTTP/1.0 200") || response.starts_with("HTTP/1.1 200"));

    if healthy { ExitCode::SUCCESS } else { ExitCode::FAILURE }
}

async fn shutdown_signal() {
    let ctrl_c = async {
        let _ = tokio::signal::ctrl_c().await;
    };

    #[cfg(unix)]
    let terminate = async {
        match tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate()) {
            Ok(mut signal) => {
                signal.recv().await;
            }
            Err(_) => std::future::pending::<()>().await,
        }
    };

    #[cfg(not(unix))]
    let terminate = std::future::pending::<()>();

    tokio::select! {
        () = ctrl_c => {},
        () = terminate => {},
    }

    tracing::info!("shutting down");
}

fn env_or<T: std::str::FromStr>(name: &str, default: T) -> T {
    std::env::var(name)
        .ok()
        .and_then(|value| value.parse().ok())
        .unwrap_or(default)
}
