# Geração de PDF (Typst + Rust)

Os PDFs são gerados pelo `rust_typst_pdf`, um binário Rust que embute o Typst como biblioteca. Ele lê o markup Typst pelo STDIN e devolve o PDF pelo STDOUT, sem acessar o disco: `#image(...)` e pacotes Typst são recusados.

## Compilando o motor

O binário não é versionado. Em desenvolvimento, o `bin/setup` compila e copia para `bin/rust_typst_pdf`:

```bash
cargo build --release --locked --manifest-path rust_typst_pdf/Cargo.toml
cp rust_typst_pdf/target/release/rust_typst_pdf bin/rust_typst_pdf
```

A imagem Docker compila o seu próprio binário no estágio `typst-builder`, e a CI guarda o binário em cache pelo hash do crate. O caminho pode ser trocado pela variável `TYPST_PDF_BINARY`.

## Exportando uma listagem

Toda listagem tem o botão "Exportar PDF" (`pdf_export_button`), que abre a mesma URL com `.pdf` e mantém os filtros e a ordenação, sem a paginação.

1. No controller, troque o `.page(params[:page])` por `listing_page(...)` e termine o `index` com `respond_with_listing` (ou `respond_with_listing(orientation: :landscape)`). Os dois vêm do concern `PdfListing`, incluído no `BaseController`. O nome do arquivo vem de `<controller>.<action>.pdf.filename`.
2. No helper da tela, crie um `<tela>_pdf_report` que devolve um `PdfReport` com o título, as colunas (`pdf_column(label, largura, align:)`), as linhas e, quando houver, o subtítulo, os indicadores (`pdf_highlight`) e a linha de totais. As células podem reaproveitar os helpers da tela: badges e links viram texto puro.
3. O `index.pdf.erb` só renderiza o template compartilhado:

```erb
<%= render 'shared/pdf_listing', report: cities_pdf_report(@cities), page_orientation: %>
```

`orientation:` aceita `:portrait` (padrão) e `:landscape`. Use paisagem nas listagens com seis colunas ou mais.
