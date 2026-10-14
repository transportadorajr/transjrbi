# Importação dos relatórios da Atua

Todas as classes que capturam dados da Atua ficam em `lib/atua/` (specs em `spec/lib/atua/`). Nenhuma delas é disparada por rake task: os Jobs chamam os commands.

| Command | O que faz |
| --- | --- |
| `Atua::ImportReportCommand.call(tenant, report_type, start_date: nil, end_date: nil, file: nil, client: nil)` | Cria um `Atua::Import` (`running`) por arquivo, baixa o relatório com `Atua::Client` (ou usa o `file` informado), anexa, lê e grava. Devolve a lista de imports. |
| `Atua::ImportAllCommand.call(tenant, start_date:, end_date:)` | Importa `customers → vehicles → manifests → transport_documents → expenses` com a mesma sessão do client. Para no primeiro login recusado, sem tentar logar de novo. |
| `Atua::ReprocessImportCommand.call(import)` | Relê o arquivo já anexado ao import, sem baixar de novo. |
| `Atua::ProcessImportCommand.call(import)` | Lê o arquivo anexado e grava numa transação; termina o import com `succeeded` ou `failed`. |
| `Atua::Save<Relatório>Command` | Grava os registros mapeados de um relatório (uma subclasse de `Atua::SaveReportCommand` por relatório). |

## Períodos

Um período maior que 31 dias é quebrado em meses (`Atua::Report#periods`), com um import e um arquivo por mês. Sem datas, os relatórios com período usam do início do mês até hoje. Cadastros (`customers`, `vehicles`) não têm período.

## Gravação

- `upsert_all` pela chave única `(tenant_id, code)`, em lotes de 500, numa transação por arquivo. Reimportar o mesmo período atualiza sem duplicar.
- `inserted_count` e `updated_count` vêm do próprio upsert (`xmax = 0` indica linha nova).
- Tabelas filhas são substituídas na mesma transação: os `ManifestDocument` de cada manifesto importado e os `TransportDocumentManifest` (montados a partir de `nr_mdfe`) de cada conhecimento importado.
- Datas de "sim/não" já gravadas (`charged_at`, `whatsapp_at`, …) são mantidas enquanto a Atua continuar respondendo "Sim".

## Registros que sumiram da Atua

- Relatórios com período: registros ativos do tenant dentro do período importado (pelo mesmo campo do filtro: `issued_at` do conhecimento, `issued_on` do manifesto, `posted_on` da despesa) que não vieram no arquivo recebem `removed_from_atua_at`. Nada é apagado.
- Cadastros: a mesma regra sobre o cadastro inteiro do tenant.
- Um registro que volta a aparecer tem `removed_from_atua_at` limpo.
- As filhas de um registro removido também são marcadas.
- Proteção: se o arquivo vier com menos da metade dos registros que o banco tem para o período (inclusive vazio), nenhuma remoção é marcada e o motivo fica em `warning_message`.
- Um arquivo de relatório com período importado sem datas não marca remoções (também registrado em `warning_message`).

## Falhas

Qualquer erro (configuração, login, download, layout, conversão, banco) desfaz a gravação do arquivo e fica registrado no import: `status_type: failed`, `error_message` e `finished_at`. O arquivo baixado continua anexado para reprocessamento.
