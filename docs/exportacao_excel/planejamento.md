# Exportação das telas para Excel

Planejamento da exportação em `.xlsx` de todas as telas de listagem do TransJRBI, com a geração da planilha feita por um microserviço em Rust (`xlsx_export/`).

## 1. Objetivo

Em toda tela de listagem, um botão **Exportar** baixa uma planilha Excel com **todos os registros que a tela mostraria com os filtros e a ordenação atuais** (sem paginação) e **todas as colunas do registro, exceto o `id`**.

## 2. Regras da exportação

| Regra | Decisão |
| --- | --- |
| Colunas | Todas as colunas da tabela do registro, mesmo as que a tela não mostra, mais as colunas calculadas da tela (ex.: totais de frete, frete líquido, quantidade de clientes do grupo). |
| `id` | Nunca exportado. O microserviço também recusa (HTTP 422) qualquer coluna com o cabeçalho `id`, como segunda barreira. |
| Chaves estrangeiras (`*_id`) | Trocadas pelo nome legível do registro associado (`customer_group_id` → coluna "Grupo de clientes" com o nome do grupo). |
| Colunas técnicas | Saem também: `tenant_id`, `atua_import_id`, `raw_data`, duplicatas `*_document_digits`. |
| Colunas sensíveis | Nunca exportadas: `encrypted_password`, `reset_password_token`, `confirmation_token`, `*_sign_in_ip` (usuários), `atua_device_token` e `atua_device_hash` (tenants), cabeçalhos e corpos de requisição (admin). |
| Cabeçalhos | `Model.human_attribute_name(:coluna)`, como nas tabelas. |
| Enums | Valores traduzidos por `enums.<model>.<coluna>`, nunca a chave crua. |
| Dinheiro | Colunas `_cents` saem como número em reais com formato de moeda vindo do I18n (nunca `R$` fixo no código). |
| Datas | Saem como datas de verdade do Excel (dá para filtrar e ordenar), no fuso do tenant. |
| Arrays (`cities`, `plates`, `product_names`, `emails`) | Unidos em um texto separado por vírgula. |
| Filtros e ordenação | Os mesmos da tela: o link carrega a query string atual (`apply_scopes` + `apply_sort`), só sem `.page`. |
| Permissões | Mesmo `authorize!` do `index`. Colunas que o usuário não vê na tela também não saem (ex.: frete líquido sem `can?(:read, :freight_expenses)`). |
| Multi-tenant | Sempre a partir de `current_tenant`, igual à listagem. |
| Nome do arquivo | `<titulo-da-tela>-<AAAA-MM-DD>.xlsx` (ex.: `ct-e-2026-11-06.xlsx`). |
| Aba | Uma aba com o título da tela; dashboards têm uma aba por tabela. |

## 3. Arquitetura

```
Navegador ──GET /transport_documents.xlsx?start_date=…&sort=…──▶ Rails (web)
                                                                  │ authorize!, apply_scopes, apply_sort
                                                                  │ Exportable / Export::Column → colunas e tipos
                                                                  │ Exports::XlsxCommand → linhas em JSON
                                                                  ▼
                                                     XlsxExport::Client (lib/xlsx_export/client.rb)
                                                                  │ POST http://xlsx:4000/v1/workbooks
                                                                  ▼                   (rede interna do Docker)
                                                     xlsx_export (Rust, axum + rust_xlsxwriter)
                                                                  │ .xlsx
Navegador ◀───────────── send_data (attachment) ──────────────────┘
```

O Rails continua dono de tudo que é regra de negócio (tenant, permissão, filtros, I18n, formatação). O microserviço só recebe linhas tipadas e devolve o arquivo — não acessa o banco e não conhece os modelos. Assim ele é pequeno, sem estado e fácil de escalar ou reiniciar.

## 4. Microserviço `xlsx_export` (implementado)

Código em `xlsx_export/`. Um único binário com três modos:

| Comando | `app/command/exports/xlsx_command.rb` (`Exports::XlsxCommand`) | Recebe as abas (`Export::Sheet`), monta o JSON e chama o cliente. |
| --- | --- |
| `xlsx_export serve` | Servidor HTTP (padrão do container). |
| `xlsx_export convert < entrada.json > saida.xlsx` | Gera a planilha pelo STDIN/STDOUT, sem servidor. Útil em scripts e depuração. |
| `xlsx_export healthcheck` | Bate em `/up`; usado pelo `HEALTHCHECK` da imagem (a imagem distroless não tem `curl`). |

### Endpoints

- `GET /up` → `200 ok`, público.
- `POST /v1/workbooks` → corpo JSON, resposta `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`.
  - `401` sem `Authorization: Bearer <XLSX_EXPORT_TOKEN>`.
  - `413` corpo acima do limite.
  - `422` JSON inválido, coluna `id`, linha com quantidade de valores errada ou valor que não bate com o tipo — a mensagem diz aba, linha e coluna (`sheet "Fretes", row 2, column "Lançado em": expected a date as YYYY-MM-DD, got "06/11/2026"`).

### Contrato

```json
{
  "sheets": [
    {
      "name": "CT-e",
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
        [1234, "ABC1D23", 1234567, "32.5", 2, "2026-11-06", "2026-11-06T08:30:00-03:00", false]
      ]
    }
  ]
}
```

| `type` | Valor esperado na linha | Gravado no Excel como | Formato padrão |
| --- | --- | --- | --- |
| `string` (padrão) | texto (números e booleanos viram texto) | texto, cortado em 32.767 caracteres | — |
| `integer` | inteiro ou texto numérico | número | `0` (sem separador de milhar: códigos e anos) |
| `decimal` | número ou texto (`BigDecimal#to_json`) | número | `#,##0.00` |
| `money` | **centavos** (inteiro) | número ÷ 100 | `#,##0.00` |
| `percentage` | número em pontos percentuais (`2` = 2%) | número ÷ 100 | `0.00%` |
| `date` | `AAAA-MM-DD` | data | `dd/mm/yyyy` |
| `datetime` | ISO 8601 (com ou sem fuso; o horário local enviado é mantido) | data e hora | `dd/mm/yyyy hh:mm` |
| `boolean` | `true`/`false` | booleano | — |

`null` vira célula vazia em qualquer tipo. `format` (código de formato do Excel) e `width` são opcionais por coluna; sem `width`, a largura é calculada pelo conteúdo (8 a 60). Campos desconhecidos são recusados.

Toda aba sai com cabeçalho em negrito (fundo `#1a2a3a`, o mesmo dos PDFs), primeira linha congelada e autofiltro. Textos são sempre gravados como texto — um valor como `=HYPERLINK(...)` vindo do ERP não vira fórmula. Nomes de aba são limpos (`[]:*?/\`, 31 caracteres) e desduplicados.

### Configuração

| Variável | Padrão | |
| --- | --- | --- |
| `XLSX_EXPORT_BIND` | `0.0.0.0:4000` | |
| `XLSX_EXPORT_TOKEN` | — | Obrigatória em produção; sem ela o serviço aceita qualquer requisição e avisa no log. |
| `XLSX_EXPORT_MAX_BODY_MB` | `64` | |
| `XLSX_EXPORT_MAX_CONCURRENCY` | nº de CPUs | Planilhas geradas ao mesmo tempo; as demais esperam na fila. |
| `RUST_LOG` | `info` | O log registra abas, linhas, bytes e tempo — nunca o conteúdo. |

### Medição

Máquina de desenvolvimento, build release: **50.000 linhas × 104 colunas** (o tamanho de um CT-e) → JSON de 60 MB, planilha de 15 MB, **8,4 s** e **131 MB** de pico de memória (abas em modo *constant memory* do `rust_xlsxwriter`). A planilha foi aberta com openpyxl e todos os tipos conferiram.

### Testes

```bash
cd xlsx_export && cargo test && cargo clippy --all-targets && cargo fmt --check
```

## 5. Lado Rails

| Peça | Arquivo | Papel |
| --- | --- | --- |
| MIME | `config/initializers/mime_types.rb` | `Mime::Type.register 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', :xlsx` |
| Cliente | `lib/xlsx_export/client.rb` (`XlsxExport::Client`) | `Net::HTTP` (como `lib/atua/client.rb`), URL e token em `Rails.application.credentials.dig(:xlsx_export, ...)`/`ENV`, timeouts, erros `XlsxExport::Error`. |
| Colunas | `app/models/concerns/exportable.rb` (`Exportable`), `app/models/export/column.rb`, `app/models/export/sheet.rb` | O modelo declara `include Exportable`; as colunas saem de `Model.column_names` menos `id`, `*_id`, as técnicas e as sensíveis. `Export::Column` mapeia o tipo (`_cents` → `money`, `*percentage` → `percentage`, `date`, `datetime`, `boolean`, `decimal`/`float` → `decimal`, `integer` → `integer`, enum → texto traduzido, array → texto). `Export::Sheet` junta as colunas e as linhas da relação. Nas fases 2 e 3 entram o nome dos registros associados no lugar dos `*_id` e as colunas calculadas da tela. |
| Comando | `app/command/exports/xlsx_command.rb` (`Exports::XlsxCommand`) | Recebe as abas (`Export::Sheet`), monta o JSON e chama o cliente. |
| Concern de controller | `app/controllers/concerns/listing_export.rb` (`ListingExport`, antigo `PdfListing`) | `respond_with_listing(xlsx: @colecao)` acrescenta `format.xlsx` ao lado do PDF quando a flag está ligada; `send_data` com `disposition: 'attachment'` e o nome do arquivo. Em `XlsxExport::Error`: `Rails.error.report` e volta para a listing (com os mesmos filtros) com `alert`. |
| Botão | `xlsx_export_button` em `ApplicationHelper` | Ícone `file-earmark-spreadsheet` com `btn-outline-success btn-round`, ao lado do botão de PDF; mantém `request.query_parameters` (menos `page`) e troca o formato para `xlsx`. No celular só o ícone. Só aparece com a flag ligada. |
| Flag | Flipper `xlsx_export` | Libera o botão e o formato `.xlsx` por tenant durante a implantação. |
| I18n | `config/locales/*.yml` | Rótulo do botão, mensagem de erro, formato de moeda/datas usados no `format` das colunas. |

Os dashboards (`Dashboard::Freight`, `Dashboard::Trip`) não têm tabela própria: exportam as linhas de `sorted_rows` (todas as colunas de cada linha) com a definição montada no próprio objeto de dashboard.

### Specs

- **Unitárias**: `spec/models/concerns/exportable_spec.rb` (sem `id`, sem colunas sensíveis, todas traduzidas), `spec/models/export/column_spec.rb` (tipos e valores), `spec/models/export/sheet_spec.rb`, `spec/command/exports/xlsx_command_spec.rb`, `spec/lib/xlsx_export/client_spec.rb` (WebMock: sucesso, 401, 422, timeout).
- **Ponta a ponta** (`spec/features/`), uma por tela: clicar em Exportar, ler o arquivo com `roo` (`downloaded_xlsx_rows`/`downloaded_xlsx_records` em `spec/support/xlsx_export.rb`) e comparar cabeçalhos e linhas com o banco (`Model.count` incluso); conferir que não há coluna `ID`; que filtros e ordenação valem; que outro tenant não vaza; que colunas restritas somem sem permissão; que a flag desligada devolve 406 no `.xlsx`; e o botão no celular (`use_mobile_screen`).
- Para as specs ponta a ponta usarem o serviço real, a tag `:xlsx_service` (`spec/support/xlsx_export.rb`) sobe `bin/xlsx_export serve` uma vez por suíte em porta livre. O `script/build` e a CI passam a compilar o binário (`cargo build --release --manifest-path xlsx_export/Cargo.toml`) e rodar `cargo test`.

## 6. Inventário das telas

Colunas = colunas da tabela (sem `id`) antes de tirar as técnicas/sensíveis.

### App

| Tela | Rota | Origem | Colunas | Observações |
| --- | --- | --- | --- | --- |
| CT-e | `/transport_documents` | `Atua::TransportDocument` + `with_freight_totals` | 107 | `origin_macro_region_id`, `product_group_id`, `route_distance_id`, `complemented_transport_document_id` → nome/número. Frete líquido só com permissão. A maior exportação. |
| MDF-e | `/manifests` | `Atua::Manifest` + `with_trip_totals` | 22 | Inclui os totais de viagem e frete/km da tela. |
| Despesas | `/expenses` | `Atua::Expense` | 60 | 16 colunas de dinheiro; `cost_object` (polimórfico) → descrição. |
| Despesas de frete | `/freight_expenses` | `FreightExpense` | 19 | `transport_document_id` → nº do CT-e; regra, tarifa, seguro e grupo de caminhão → nome. |
| Clientes | `/customers` | `Atua::Customer` | 34 | Grupo de clientes pelo nome. |
| Veículos | `/vehicles` | `Atua::Vehicle` | 45 | Piloto da implantação (tela simples, sem permissões especiais). |
| Motoristas | `/drivers` | `Atua::Vehicle.drivers` | — | Só as colunas `driver_*` e veículos vinculados, não o cadastro inteiro do veículo. |
| Usuários | `/users` | `User` | 21 | Sem senha, tokens e IPs. `user_type` traduzido. |
| Grupos de clientes | `/customer_groups` | `CustomerGroup` | 5 | + quantidade de clientes. |
| Grupos de produtos | `/product_groups` | `ProductGroup` | 6 | `parent_id` → grupo pai; + quantidade de subgrupos. |
| Regras de comissão | `/commission_rules` | `CommissionRule` | 10 | `cities` (array) em texto. |
| Tarifas por tonelada | `/tonnage_rates` | `TonnageRate` | 10 | Respeita o filtro de mês de vigência. |
| Distâncias de rota | `/route_distances` | `RouteDistance` | 8 | + cliente e quantidade de CT-e. |
| Grupos de caminhões | `/truck_groups` | `TruckGroup` | 8 | `plates` (array) em texto. |
| Macrorregiões | `/macro_regions` | `MacroRegion` | 5 | + cidades em texto. |
| Cidades | `/cities` | `City` | 5 | Macrorregião pelo nome. |
| Emitentes excluídos | `/excluded_issuers` | `ExcludedIssuer` | 4 | + totais de documentos da tela. |
| Início (dashboard) | `/` | consultas do `HomeController` | — | Uma aba por tabela do dashboard; gráficos não. |
| Faturamento de frete | `/freight_billing` (+ `detail`, `freights`, `month`) | `Dashboard::Freight#sorted_rows` | — | Cada sub-tela exporta a sua tabela. |
| Viagens | `/trips` | `Dashboard::Trip#sorted_rows` | — | |

### Admin

| Tela | Rota | Origem | Colunas | Observações |
| --- | --- | --- | --- | --- |
| Importações | `/` (admin) | `Atua::Import` | 16 | Tenant pelo nome. |
| Requisições HTTP | `/http_requests` | `Admin::HttpRequest` | 21 | Sem cabeçalhos e corpos (podem ter tokens e são grandes). |
| Tenants | `/tenants` | `Tenant` | 7 | Sem `atua_device_token`/`atua_device_hash`. |
| Recursos | `/resources` | `Resource` | 4 | |

Fora do escopo desta entrega: as tabelas internas das telas de detalhe (ex.: trechos vazios em Veículos, despesas dentro do CT-e) e as telas singulares (Empresa, Seguro).

## 7. Implantação

O serviço entra em `deploy/compose.yaml` como mais um serviço da rede interna — **sem `ports` e sem labels do Traefik**, para nunca ficar exposto à internet:

```yaml
  xlsx:
    image: transjr/transjrbi-xlsx:${APP_VERSION:-latest}
    environment:
      XLSX_EXPORT_TOKEN: ${XLSX_EXPORT_TOKEN:?XLSX_EXPORT_TOKEN must be set in .env}
      XLSX_EXPORT_MAX_CONCURRENCY: "2"
    restart: unless-stopped
```

- `.github/workflows/publish.yml` ganha um segundo `docker/build-push-action` com `context: xlsx_export` publicando `transjrbi-xlsx` com a mesma versão; `deploy/release` sobe o `xlsx` antes do `docker rollout web`.
- O `web` recebe `XLSX_EXPORT_URL=http://xlsx:4000` e o mesmo `XLSX_EXPORT_TOKEN`; documentar em `docs/deploy/configuracao.md`.
- Compatibilidade entre versões (o `web` antigo e o novo servem juntos): o serviço vai num deploy com a flag `xlsx_export` desligada e só depois a flag é ligada. Mudanças no contrato entram como `/v2/...`, mantendo `/v1` por pelo menos um deploy.
- Desenvolvimento: linha `xlsx: cargo run --release --manifest-path xlsx_export/Cargo.toml -- serve` no `Procfile.dev` e build no `bin/setup`.

## 8. Fases

| Fase | Entrega |
| --- | --- |
| 0 | Microserviço `xlsx_export` com testes e Dockerfile. **Feito.** |
| 1 | Infra Rails (MIME, cliente, `Exportable` + `Export::Column`/`Export::Sheet`, comando, concern `ListingExport`, botão, flag, spec support) + deploy do serviço + tela piloto **Veículos**. **Feito.** |
| 2 | Cadastros: cidades, macrorregiões, grupos de clientes/produtos/caminhões, regras de comissão, tarifas por tonelada, distâncias de rota, emitentes excluídos, usuários, feriados. **Feito.** |
| 3 | Telas do Atua: CT-e, MDF-e, despesas, despesas de frete, clientes, motoristas. **Feito.** |
| 4 | Dashboards: faturamento de frete (tabela do agrupamento + total), viagens (tabela + total) e projeção de faturamento (resumo e dia a dia). O início só redireciona para o faturamento. **Feito.** |
| 5 | Admin: importações, requisições HTTP, tenants, recursos. |
| 6 | Exportações grandes em segundo plano: acima de um limite (sugestão: 20 mil linhas), um job GoodJob gera a planilha, guarda no Active Storage e avisa o usuário com o link; abaixo do limite continua síncrono. |

## 9. Riscos

- **Volume**: o CT-e tem 107 colunas; um ano inteiro sem filtro pode passar de 50 mil linhas (~8 s só na geração). Até a fase 6, limitar a exportação síncrona e pedir para filtrar o período quando passar do limite.
- **Memória do Rails**: montar o JSON inteiro em memória; gerar em lotes e, se preciso, mandar o corpo em streaming.
- **Serviço fora do ar**: a tela continua funcionando; só a exportação mostra o alerta e o erro vai para o Sentry/Discord.

## 10. Para confirmar

1. "Todas as colunas" é mesmo **todas as colunas do registro** (como planejado) e não só as visíveis na tela?
2. Tirar as colunas técnicas (`tenant_id`, `atua_import_id`, `raw_data`, `*_digits`) além do `id` está ok?
3. Os dashboards entram nesta entrega ou ficam para depois?
4. Qual o limite de linhas aceitável para a exportação síncrona?
