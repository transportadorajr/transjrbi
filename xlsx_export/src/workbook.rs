use std::collections::HashSet;

use chrono::{DateTime, NaiveDate, NaiveDateTime};
use rust_xlsxwriter::{Color, Format, FormatAlign, Workbook, Worksheet};
use serde_json::Value;

use crate::spec::{ColumnKind, ColumnSpec, ExportError, SheetSpec, WorkbookSpec, invalid};

const MAX_CELL_CHARS: usize = 32_767;
const MAX_SHEET_NAME_CHARS: usize = 31;
const HEADER_BACKGROUND: u32 = 0x1A2A3A;
const WIDTH_SAMPLE_ROWS: usize = 1_000;
const MIN_WIDTH: f64 = 8.0;
const MAX_WIDTH: f64 = 60.0;

pub fn render(spec: &WorkbookSpec) -> Result<Vec<u8>, ExportError> {
    spec.validate()?;

    let mut workbook = Workbook::new();
    let header_format = Format::new()
        .set_bold()
        .set_font_color(Color::White)
        .set_background_color(Color::RGB(HEADER_BACKGROUND))
        .set_align(FormatAlign::VerticalCenter);

    for (sheet, name) in spec.sheets.iter().zip(sheet_names(spec)) {
        let worksheet = workbook.add_worksheet_with_constant_memory()?;
        worksheet.set_name(&name)?;
        write_sheet(worksheet, sheet, &header_format)?;
    }

    Ok(workbook.save_to_buffer()?)
}

fn write_sheet(worksheet: &mut Worksheet, sheet: &SheetSpec, header_format: &Format) -> Result<(), ExportError> {
    let formats: Vec<Format> = sheet.columns.iter().map(column_format).collect();

    for (index, column) in sheet.columns.iter().enumerate() {
        let col = column_index(index);
        worksheet.set_column_width(col, column.width.unwrap_or_else(|| auto_width(sheet, index)))?;
        worksheet.write_string_with_format(0, col, &column.header, header_format)?;
    }

    for (row_index, row) in sheet.rows.iter().enumerate() {
        let excel_row = (row_index + 1) as u32;
        for (index, value) in row.iter().enumerate() {
            let column = &sheet.columns[index];
            write_cell(worksheet, excel_row, column_index(index), column, &formats[index], value).map_err(|message| {
                invalid(format!(
                    "sheet {:?}, row {}, column {:?}: {message}",
                    sheet.name,
                    row_index + 1,
                    column.header
                ))
            })?;
        }
    }

    worksheet.set_freeze_panes(1, 0)?;
    worksheet.autofilter(0, 0, sheet.rows.len() as u32, column_index(sheet.columns.len() - 1))?;
    Ok(())
}

fn write_cell(
    worksheet: &mut Worksheet,
    row: u32,
    col: u16,
    column: &ColumnSpec,
    format: &Format,
    value: &Value,
) -> Result<(), String> {
    if value.is_null() {
        return Ok(());
    }

    let result = match column.kind {
        ColumnKind::String => worksheet.write_string_with_format(row, col, truncate(&text(value)?), format),
        ColumnKind::Integer => worksheet.write_number_with_format(row, col, integer(value)? as f64, format),
        ColumnKind::Decimal => worksheet.write_number_with_format(row, col, decimal(value)?, format),
        ColumnKind::Money => worksheet.write_number_with_format(row, col, integer(value)? as f64 / 100.0, format),
        ColumnKind::Percentage => worksheet.write_number_with_format(row, col, decimal(value)? / 100.0, format),
        ColumnKind::Date => worksheet.write_datetime_with_format(row, col, date(value)?, format),
        ColumnKind::Datetime => worksheet.write_datetime_with_format(row, col, datetime(value)?, format),
        ColumnKind::Boolean => worksheet.write_boolean_with_format(row, col, boolean(value)?, format),
    };

    result.map(|_| ()).map_err(|error| error.to_string())
}

fn column_format(column: &ColumnSpec) -> Format {
    match column.format.as_deref().or(column.kind.default_format()) {
        Some(num_format) => Format::new().set_num_format(num_format),
        None => Format::new(),
    }
}

fn text(value: &Value) -> Result<String, String> {
    match value {
        Value::String(string) => Ok(string.clone()),
        Value::Number(number) => Ok(number.to_string()),
        Value::Bool(boolean) => Ok(boolean.to_string()),
        _ => Err(format!("expected text, got {value}")),
    }
}

fn integer(value: &Value) -> Result<i64, String> {
    match value {
        Value::Number(number) => number.as_i64().ok_or_else(|| format!("expected an integer, got {number}")),
        Value::String(string) => string
            .trim()
            .parse()
            .map_err(|_| format!("expected an integer, got {string:?}")),
        _ => Err(format!("expected an integer, got {value}")),
    }
}

fn decimal(value: &Value) -> Result<f64, String> {
    let number = match value {
        Value::Number(number) => number.as_f64(),
        Value::String(string) => string.trim().parse().ok(),
        _ => None,
    };
    number
        .filter(|number| number.is_finite())
        .ok_or_else(|| format!("expected a number, got {value}"))
}

fn date(value: &Value) -> Result<NaiveDate, String> {
    value
        .as_str()
        .and_then(|string| NaiveDate::parse_from_str(string, "%Y-%m-%d").ok())
        .ok_or_else(|| format!("expected a date as YYYY-MM-DD, got {value}"))
}

fn datetime(value: &Value) -> Result<NaiveDateTime, String> {
    value
        .as_str()
        .and_then(|string| {
            DateTime::parse_from_rfc3339(string)
                .map(|datetime| datetime.naive_local())
                .or_else(|_| NaiveDateTime::parse_from_str(string, "%Y-%m-%dT%H:%M:%S%.f"))
                .ok()
        })
        .ok_or_else(|| format!("expected an ISO 8601 date and time, got {value}"))
}

fn boolean(value: &Value) -> Result<bool, String> {
    value.as_bool().ok_or_else(|| format!("expected true or false, got {value}"))
}

fn truncate(string: &str) -> &str {
    match string.char_indices().nth(MAX_CELL_CHARS) {
        Some((byte_index, _)) => &string[..byte_index],
        None => string,
    }
}

fn auto_width(sheet: &SheetSpec, index: usize) -> f64 {
    let column = &sheet.columns[index];
    let header = column.header.chars().count() + 2;
    let values = match column.kind {
        ColumnKind::String => sheet
            .rows
            .iter()
            .take(WIDTH_SAMPLE_ROWS)
            .filter_map(|row| text(&row[index]).ok())
            .map(|string| string.chars().count())
            .max()
            .unwrap_or(0),
        kind => kind.estimated_width(),
    };
    ((header.max(values) + 2) as f64).clamp(MIN_WIDTH, MAX_WIDTH)
}

fn column_index(index: usize) -> u16 {
    index as u16
}

fn sheet_names(spec: &WorkbookSpec) -> Vec<String> {
    let mut taken = HashSet::new();
    spec.sheets
        .iter()
        .enumerate()
        .map(|(index, sheet)| {
            let base = sanitize_sheet_name(&sheet.name, index + 1);
            let mut name = base.clone();
            let mut counter = 2;
            while !taken.insert(name.to_lowercase()) {
                let suffix = format!(" ({counter})");
                let room = MAX_SHEET_NAME_CHARS - suffix.chars().count();
                name = format!("{}{suffix}", base.chars().take(room).collect::<String>().trim_end());
                counter += 1;
            }
            name
        })
        .collect()
}

fn sanitize_sheet_name(name: &str, position: usize) -> String {
    let cleaned: String = name
        .chars()
        .map(|char| {
            if matches!(char, '[' | ']' | ':' | '*' | '?' | '/' | '\\') || char.is_control() {
                ' '
            } else {
                char
            }
        })
        .collect();
    let cleaned = cleaned.trim().trim_matches('\'').trim();
    let truncated: String = cleaned.chars().take(MAX_SHEET_NAME_CHARS).collect();
    let truncated = truncated.trim_end().to_string();

    if truncated.is_empty() || truncated.eq_ignore_ascii_case("history") {
        format!("Sheet{position}")
    } else {
        truncated
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sanitizes_and_deduplicates_sheet_names() {
        let spec: WorkbookSpec = serde_json::from_value(serde_json::json!({
            "sheets": [
                { "name": "Fretes: [2026/11]", "columns": [{ "header": "Placa" }] },
                { "name": "fretes   2026 11", "columns": [{ "header": "Placa" }] },
                { "name": "''", "columns": [{ "header": "Placa" }] },
                { "name": "Uma aba com um nome muito maior que trinta e um", "columns": [{ "header": "Placa" }] }
            ]
        }))
        .unwrap();

        let names = sheet_names(&spec);

        assert_eq!(names[0], "Fretes   2026 11");
        assert_eq!(names[1], "fretes   2026 11 (2)");
        assert_eq!(names[2], "Sheet3");
        assert_eq!(names[3], "Uma aba com um nome muito maior");
    }

    #[test]
    fn truncates_text_to_the_excel_cell_limit() {
        let long = "á".repeat(MAX_CELL_CHARS + 10);

        assert_eq!(truncate(&long).chars().count(), MAX_CELL_CHARS);
        assert_eq!(truncate("curto"), "curto");
    }

    #[test]
    fn parses_typed_values() {
        assert_eq!(integer(&serde_json::json!("1234")).unwrap(), 1234);
        assert_eq!(decimal(&serde_json::json!("12.5")).unwrap(), 12.5);
        assert_eq!(
            date(&serde_json::json!("2026-11-06")).unwrap(),
            NaiveDate::from_ymd_opt(2026, 11, 6).unwrap()
        );
        assert_eq!(
            datetime(&serde_json::json!("2026-11-06T08:30:00-03:00")).unwrap(),
            NaiveDate::from_ymd_opt(2026, 11, 6).unwrap().and_hms_opt(8, 30, 0).unwrap()
        );
        assert!(integer(&serde_json::json!(1.5)).is_err());
        assert!(date(&serde_json::json!("06/11/2026")).is_err());
        assert!(boolean(&serde_json::json!("sim")).is_err());
    }
}
