use std::sync::Arc;
use std::time::Instant;

use axum::Router;
use axum::body::Bytes;
use axum::extract::{DefaultBodyLimit, State};
use axum::http::{HeaderMap, StatusCode, header};
use axum::response::{IntoResponse, Response};
use axum::routing::{get, post};
use serde_json::json;
use tokio::sync::Semaphore;
use tower_http::trace::TraceLayer;

use crate::spec::{self, ExportError};
use crate::workbook;

pub const XLSX_CONTENT_TYPE: &str = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";

#[derive(Debug, Clone)]
pub struct Config {
    pub token: Option<String>,
    pub max_body_bytes: usize,
    pub max_concurrency: usize,
}

#[derive(Clone)]
struct AppState {
    token: Option<Arc<str>>,
    permits: Arc<Semaphore>,
}

pub fn router(config: &Config) -> Router {
    let state = AppState {
        token: config.token.as_deref().map(Arc::from),
        permits: Arc::new(Semaphore::new(config.max_concurrency.max(1))),
    };

    Router::new()
        .route("/up", get(up))
        .route(
            "/v1/workbooks",
            post(create_workbook).layer(DefaultBodyLimit::max(config.max_body_bytes)),
        )
        .layer(TraceLayer::new_for_http())
        .with_state(state)
}

async fn up() -> &'static str {
    "ok"
}

async fn create_workbook(State(state): State<AppState>, headers: HeaderMap, body: Bytes) -> Response {
    if !authorized(state.token.as_deref(), &headers) {
        return error_response(StatusCode::UNAUTHORIZED, "missing or invalid bearer token");
    }

    let Ok(_permit) = state.permits.acquire_owned().await else {
        return error_response(StatusCode::SERVICE_UNAVAILABLE, "the service is shutting down");
    };

    let started = Instant::now();
    let rendered = tokio::task::spawn_blocking(move || {
        let spec = spec::parse(&body)?;
        let rows = spec.row_count();
        let sheets = spec.sheets.len();
        workbook::render(&spec).map(|bytes| (bytes, sheets, rows))
    })
    .await;

    match rendered {
        Ok(Ok((bytes, sheets, rows))) => {
            tracing::info!(
                sheets,
                rows,
                bytes = bytes.len(),
                elapsed_ms = started.elapsed().as_millis() as u64,
                "workbook rendered"
            );
            ([(header::CONTENT_TYPE, XLSX_CONTENT_TYPE)], bytes).into_response()
        }
        Ok(Err(error)) if error.is_client_error() => error_response(StatusCode::UNPROCESSABLE_ENTITY, &error.to_string()),
        Ok(Err(error)) => internal_error(&error),
        Err(error) => {
            tracing::error!(%error, "render task failed");
            error_response(StatusCode::INTERNAL_SERVER_ERROR, "failed to build the workbook")
        }
    }
}

fn internal_error(error: &ExportError) -> Response {
    tracing::error!(%error, "render failed");
    error_response(StatusCode::INTERNAL_SERVER_ERROR, "failed to build the workbook")
}

fn error_response(status: StatusCode, message: &str) -> Response {
    (status, axum::Json(json!({ "error": message }))).into_response()
}

fn authorized(expected: Option<&str>, headers: &HeaderMap) -> bool {
    let Some(expected) = expected else {
        return true;
    };

    headers
        .get(header::AUTHORIZATION)
        .and_then(|value| value.to_str().ok())
        .and_then(|value| value.strip_prefix("Bearer "))
        .is_some_and(|given| constant_time_eq(given.as_bytes(), expected.as_bytes()))
}

fn constant_time_eq(left: &[u8], right: &[u8]) -> bool {
    left.len() == right.len() && left.iter().zip(right).fold(0u8, |diff, (a, b)| diff | (a ^ b)) == 0
}
