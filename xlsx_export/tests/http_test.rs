use std::io::{Cursor, Read};

use axum::body::Body;
use axum::http::{Request, StatusCode, header};
use http_body_util::BodyExt;
use serde_json::{Value, json};
use tower::ServiceExt;
use xlsx_export::server::{Config, XLSX_CONTENT_TYPE, router};

fn config(token: Option<&str>) -> Config {
    Config {
        token: token.map(String::from),
        max_body_bytes: 1024 * 1024,
        max_concurrency: 2,
    }
}

fn payload() -> Value {
    json!({
        "sheets": [{
            "name": "Fretes",
            "columns": [
                { "header": "Número", "type": "integer" },
                { "header": "Placa" },
                { "header": "Frete", "type": "money", "format": "\"R$\" #,##0.00" },
                { "header": "Peso (t)", "type": "decimal", "format": "#,##0.000" },
                { "header": "Comissão", "type": "percentage" },
                { "header": "Lançado em", "type": "date" },
                { "header": "Emitido em", "type": "datetime" },
                { "header": "Venda de veículo", "type": "boolean" }
            ],
            "rows": [
                [1234, "ABC1D23", 1234567, "32.5", 2, "2026-11-06", "2026-11-06T08:30:00-03:00", false],
                [1235, "=HYPERLINK(\"x\")", null, null, null, null, null, null]
            ]
        }]
    })
}

async fn post(app: axum::Router, body: String, token: Option<&str>) -> (StatusCode, Option<String>, Vec<u8>) {
    let mut request = Request::post("/v1/workbooks").header(header::CONTENT_TYPE, "application/json");
    if let Some(token) = token {
        request = request.header(header::AUTHORIZATION, format!("Bearer {token}"));
    }

    let response = app.oneshot(request.body(Body::from(body)).unwrap()).await.unwrap();
    let status = response.status();
    let content_type = response
        .headers()
        .get(header::CONTENT_TYPE)
        .map(|value| value.to_str().unwrap().to_string());
    let bytes = response.into_body().collect().await.unwrap().to_bytes().to_vec();
    (status, content_type, bytes)
}

fn zip_entry(bytes: &[u8], name: &str) -> String {
    let mut archive = zip::ZipArchive::new(Cursor::new(bytes)).unwrap();
    let mut content = String::new();
    archive.by_name(name).unwrap().read_to_string(&mut content).unwrap();
    content
}

#[tokio::test]
async fn up_answers_without_a_token() {
    let response = router(&config(Some("secret")))
        .oneshot(Request::get("/up").body(Body::empty()).unwrap())
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::OK);
}

#[tokio::test]
async fn renders_a_workbook_with_typed_cells() {
    let (status, content_type, bytes) = post(router(&config(Some("secret"))), payload().to_string(), Some("secret")).await;

    assert_eq!(status, StatusCode::OK);
    assert_eq!(content_type.as_deref(), Some(XLSX_CONTENT_TYPE));

    let workbook = zip_entry(&bytes, "xl/workbook.xml");
    let sheet = zip_entry(&bytes, "xl/worksheets/sheet1.xml");
    let styles = zip_entry(&bytes, "xl/styles.xml");

    assert!(workbook.contains("name=\"Fretes\""));
    assert!(sheet.contains("<v>12345.67</v>"));
    assert!(sheet.contains("<v>32.5</v>"));
    assert!(sheet.contains("<v>0.02</v>"));
    assert!(sheet.contains("<autoFilter ref=\"A1:H3\"/>"));
    assert!(sheet.contains("<pane ySplit=\"1\""));
    assert!(!sheet.contains("<f>"));
    assert!(sheet.contains("Número"));
    assert!(sheet.contains("=HYPERLINK"));
    assert!(styles.contains("&quot;R$&quot; #,##0.00"));
}

#[tokio::test]
async fn refuses_requests_without_the_token() {
    let (status, _, _) = post(router(&config(Some("secret"))), payload().to_string(), None).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);

    let (status, _, _) = post(router(&config(Some("secret"))), payload().to_string(), Some("wrong")).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
}

#[tokio::test]
async fn refuses_the_id_column() {
    let mut body = payload();
    body["sheets"][0]["columns"][0]["header"] = json!(" ID ");

    let (status, _, bytes) = post(router(&config(None)), body.to_string(), None).await;

    assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
    assert!(
        String::from_utf8(bytes)
            .unwrap()
            .contains("must not export the \\\" ID \\\" column")
    );
}

#[tokio::test]
async fn reports_the_position_of_an_invalid_value() {
    let mut body = payload();
    body["sheets"][0]["rows"][1][5] = json!("06/11/2026");

    let (status, _, bytes) = post(router(&config(None)), body.to_string(), None).await;
    let error: Value = serde_json::from_slice(&bytes).unwrap();

    assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
    assert_eq!(
        error["error"],
        "sheet \"Fretes\", row 2, column \"Lançado em\": expected a date as YYYY-MM-DD, got \"06/11/2026\""
    );
}

#[tokio::test]
async fn refuses_rows_with_the_wrong_number_of_values() {
    let mut body = payload();
    body["sheets"][0]["rows"][0] = json!([1, "ABC1D23"]);

    let (status, _, bytes) = post(router(&config(None)), body.to_string(), None).await;

    assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
    assert!(String::from_utf8(bytes).unwrap().contains("row 1: expected 8 values, got 2"));
}

#[tokio::test]
async fn refuses_unknown_column_types_and_fields() {
    let mut body = payload();
    body["sheets"][0]["columns"][0]["type"] = json!("currency");
    let (status, _, _) = post(router(&config(None)), body.to_string(), None).await;
    assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);

    let mut body = payload();
    body["sheets"][0]["extra"] = json!(true);
    let (status, _, _) = post(router(&config(None)), body.to_string(), None).await;
    assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
}

#[tokio::test]
async fn refuses_bodies_over_the_limit() {
    let app = router(&Config {
        token: None,
        max_body_bytes: 64,
        max_concurrency: 1,
    });

    let (status, _, _) = post(app, payload().to_string(), None).await;

    assert_eq!(status, StatusCode::PAYLOAD_TOO_LARGE);
}
