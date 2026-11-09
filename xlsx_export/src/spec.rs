use serde::Deserialize;
use serde_json::Value;

pub const MAX_DATA_ROWS: usize = 1_048_575;
pub const MAX_COLUMNS: usize = 16_384;
pub const MAX_SHEETS: usize = 255;
pub const FORBIDDEN_HEADERS: [&str; 1] = ["id"];

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct WorkbookSpec {
    pub sheets: Vec<SheetSpec>,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SheetSpec {
    pub name: String,
    pub columns: Vec<ColumnSpec>,
    #[serde(default)]
    pub rows: Vec<Vec<Value>>,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ColumnSpec {
    pub header: String,
    #[serde(rename = "type", default)]
    pub kind: ColumnKind,
    #[serde(default)]
    pub format: Option<String>,
    #[serde(default)]
    pub width: Option<f64>,
}

#[derive(Debug, Clone, Copy, Default, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum ColumnKind {
    #[default]
    String,
    Integer,
    Decimal,
    Money,
    Percentage,
    Date,
    Datetime,
    Boolean,
}

impl ColumnKind {
    pub fn default_format(self) -> Option<&'static str> {
        match self {
            ColumnKind::Integer => Some("0"),
            ColumnKind::Decimal | ColumnKind::Money => Some("#,##0.00"),
            ColumnKind::Percentage => Some("0.00%"),
            ColumnKind::Date => Some("dd/mm/yyyy"),
            ColumnKind::Datetime => Some("dd/mm/yyyy hh:mm"),
            ColumnKind::String | ColumnKind::Boolean => None,
        }
    }

    pub fn estimated_width(self) -> usize {
        match self {
            ColumnKind::Date => 12,
            ColumnKind::Datetime => 17,
            ColumnKind::Boolean => 8,
            ColumnKind::Integer | ColumnKind::Decimal | ColumnKind::Money | ColumnKind::Percentage => 14,
            ColumnKind::String => 0,
        }
    }
}

#[derive(Debug, thiserror::Error)]
pub enum ExportError {
    #[error("invalid JSON: {0}")]
    InvalidJson(#[from] serde_json::Error),
    #[error("{0}")]
    Invalid(String),
    #[error("failed to build the workbook: {0}")]
    Xlsx(#[from] rust_xlsxwriter::XlsxError),
}

impl ExportError {
    pub fn is_client_error(&self) -> bool {
        !matches!(self, ExportError::Xlsx(_))
    }
}

pub fn parse(bytes: &[u8]) -> Result<WorkbookSpec, ExportError> {
    let spec: WorkbookSpec = serde_json::from_slice(bytes)?;
    spec.validate()?;
    Ok(spec)
}

impl WorkbookSpec {
    pub fn validate(&self) -> Result<(), ExportError> {
        if self.sheets.is_empty() {
            return Err(invalid("the workbook needs at least one sheet"));
        }
        if self.sheets.len() > MAX_SHEETS {
            return Err(invalid(format!("the workbook accepts at most {MAX_SHEETS} sheets")));
        }
        self.sheets.iter().try_for_each(SheetSpec::validate)
    }

    pub fn row_count(&self) -> usize {
        self.sheets.iter().map(|sheet| sheet.rows.len()).sum()
    }
}

impl SheetSpec {
    fn validate(&self) -> Result<(), ExportError> {
        if self.columns.is_empty() {
            return Err(invalid(format!("sheet {:?} needs at least one column", self.name)));
        }
        if self.columns.len() > MAX_COLUMNS {
            return Err(invalid(format!("sheet {:?} has more than {MAX_COLUMNS} columns", self.name)));
        }
        if self.rows.len() > MAX_DATA_ROWS {
            return Err(invalid(format!("sheet {:?} has more than {MAX_DATA_ROWS} rows", self.name)));
        }
        if let Some(column) = self.columns.iter().find(|column| is_forbidden(&column.header)) {
            return Err(invalid(format!(
                "sheet {:?} must not export the {:?} column",
                self.name, column.header
            )));
        }
        if let Some(column) = self
            .columns
            .iter()
            .find(|column| column.width.is_some_and(|width| !(0.0..=255.0).contains(&width)))
        {
            return Err(invalid(format!(
                "sheet {:?}, column {:?}: width must be between 0 and 255",
                self.name, column.header
            )));
        }
        if let Some((index, row)) = self.rows.iter().enumerate().find(|(_, row)| row.len() != self.columns.len()) {
            return Err(invalid(format!(
                "sheet {:?}, row {}: expected {} values, got {}",
                self.name,
                index + 1,
                self.columns.len(),
                row.len()
            )));
        }
        Ok(())
    }
}

fn is_forbidden(header: &str) -> bool {
    let header = header.trim();
    FORBIDDEN_HEADERS
        .iter()
        .any(|forbidden| header.eq_ignore_ascii_case(forbidden))
}

pub fn invalid(message: impl Into<String>) -> ExportError {
    ExportError::Invalid(message.into())
}
