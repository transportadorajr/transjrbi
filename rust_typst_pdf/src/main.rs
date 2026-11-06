use std::io::{self, Read, Write};
use std::process::exit;

use time::OffsetDateTime;
use typst::diag::{FileError, FileResult, SourceDiagnostic};
use typst::foundations::{Bytes, Datetime, Duration};
use typst::syntax::{FileId, Source};
use typst::text::{Font, FontBook};
use typst::utils::LazyHash;
use typst::{Library, LibraryExt, World, WorldExt};
use typst_layout::PagedDocument;
use typst_pdf::PdfOptions;

/// A [`World`] for a single, self-contained Typst source read from STDIN.
///
/// The Rails `.pdf.erb` views render the whole markup, so there is nothing to
/// resolve from disk: `file` and any `source` other than the main one are
/// refused, and the fonts are the ones embedded in this binary.
struct MarkupWorld {
    library: LazyHash<Library>,
    book: LazyHash<FontBook>,
    fonts: Vec<Font>,
    source: Source,
}

impl MarkupWorld {
    fn new(markup: String) -> Self {
        let fonts: Vec<Font> = typst_assets::fonts()
            .flat_map(|data| Font::iter(Bytes::new(data)))
            .collect();

        Self {
            library: LazyHash::new(Library::default()),
            book: LazyHash::new(FontBook::from_fonts(&fonts)),
            fonts,
            source: Source::detached(markup),
        }
    }

    /// Format diagnostics the way the Typst CLI does, so a broken template can
    /// be traced back to a line of the rendered markup.
    fn report(&self, diagnostics: &[SourceDiagnostic]) -> String {
        diagnostics
            .iter()
            .map(|diagnostic| {
                let location = self
                    .range(diagnostic.span)
                    .and_then(|range| self.source.lines().byte_to_line_column(range.start))
                    .map(|(line, column)| format!("line {}, column {}: ", line + 1, column + 1))
                    .unwrap_or_default();

                let hints: String = diagnostic
                    .hints
                    .iter()
                    .map(|hint| format!("\n  hint: {}", hint.v))
                    .collect();

                format!("{location}{}{hints}", diagnostic.message)
            })
            .collect::<Vec<_>>()
            .join("\n")
    }
}

impl World for MarkupWorld {
    fn library(&self) -> &LazyHash<Library> {
        &self.library
    }

    fn book(&self) -> &LazyHash<FontBook> {
        &self.book
    }

    fn main(&self) -> FileId {
        self.source.id()
    }

    fn source(&self, id: FileId) -> FileResult<Source> {
        if id == self.source.id() {
            Ok(self.source.clone())
        } else {
            Err(unsupported_file())
        }
    }

    fn file(&self, _id: FileId) -> FileResult<Bytes> {
        Err(unsupported_file())
    }

    fn font(&self, index: usize) -> Option<Font> {
        self.fonts.get(index).cloned()
    }

    fn today(&self, offset: Option<Duration>) -> Option<Datetime> {
        // `now_local` fails when the process is already multi-threaded, which is
        // the case once the compiler starts; UTC is the fallback. Templates take
        // their timestamps from Rails, so this only backs Typst's `datetime`.
        let now = match offset {
            None => OffsetDateTime::now_local().unwrap_or_else(|_| OffsetDateTime::now_utc()),
            Some(offset) => OffsetDateTime::now_utc() + time::Duration::from(offset),
        };

        Datetime::from_ymd(now.year(), now.month() as u8, now.day())
    }
}

fn unsupported_file() -> FileError {
    FileError::Other(Some(
        "this binary compiles a single self-contained source read from STDIN, \
         so external files and packages cannot be loaded"
            .into(),
    ))
}

fn fail(message: String) -> ! {
    eprintln!("{message}");
    exit(1);
}

fn main() {
    let mut markup = String::new();
    if let Err(error) = io::stdin().read_to_string(&mut markup) {
        fail(format!(
            "Failed to read the Typst markup from STDIN: {error}"
        ));
    }

    let world = MarkupWorld::new(markup);

    let document = match typst::compile::<PagedDocument>(&world).output {
        Ok(document) => document,
        Err(diagnostics) => fail(world.report(&diagnostics)),
    };

    let pdf = match typst_pdf::pdf(&document, &PdfOptions::default()) {
        Ok(pdf) => pdf,
        Err(diagnostics) => fail(world.report(&diagnostics)),
    };

    if let Err(error) = io::stdout().write_all(&pdf) {
        fail(format!("Failed to write the PDF to STDOUT: {error}"));
    }
}
