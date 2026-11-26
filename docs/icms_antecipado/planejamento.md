# ICMS antecipado (guias de ICMS) — caso Gerdau

Planejamento do card 230 do Trello ("CLIENTE GERDAU", quadro Transportadora JR - Suporte): a Gerdau de SP paga o frete **mais ICMS**, e a JR recolhe esse ICMS em guias para a SEFAZ-SP. O pedido é entender no BI como esse caso aparece hoje e o que precisa mudar.

## 1. Diagnóstico (feito sobre os CT-es importados da Atua; os valores ficam fora deste documento e podem ser consultados na tela da Fase 1)

### 1.1 Como o caso da Gerdau aparece hoje

| Item | O que os dados mostram |
| --- | --- |
| CT-es | Todos os CT-es ativos do grupo GERDAU são **SP → PR**, CFOP **6932** (prestação iniciada em UF diferente da do prestador), CST 90, filial JR TRANSPORTES. |
| Frete do CT-e | `freight_cents` já inclui o ICMS: a base do ICMS é igual ao frete, com a alíquota interestadual de 12%. |
| ICMS ST no CT-e | `icms_st_cents` é **zero** em todos. O "ST" do card não vem no campo `vl_icms_st`. |
| Guia | Lançada no caixa do Atua com o histórico **503 – ICMS ANTECIPADO**, favorecida a SEFAZ-SP, modelo "Guia", com número de documento = número do CT-e. O `LinkExpensesCommand` já vincula a guia ao CT-e (`cost_object`). |
| Valor da guia | Em todos os CT-es da Gerdau com guia, o valor da guia é **exatamente** o ICMS do CT-e (nenhuma divergência). |
| Sem guia | Os CT-es sem guia são, quase todos, os emitidos nos últimos dias (a guia ainda não foi lançada no caixa). |

### 1.2 Como isso entra no faturamento e no frete líquido

- **Faturamento bruto**: soma `freight_cents`, então inclui o ICMS que vai para a SEFAZ-SP.
- **Frete líquido** (`Atua::TransportDocument.net_freight_of_document`): frete − despesas de frete calculadas (`freight_expenses`) − despesas do Atua vinculadas ao CT-e − pedágio. Como a guia 503 é uma despesa vinculada ao CT-e, ela **já é descontada do líquido** quando está lançada.
- Consequência 1: enquanto a guia não é lançada, o líquido do CT-e fica **inflado em ~12%** e cai depois, quando a guia chega (os números do mês corrente mudam sozinhos).
- Consequência 2: para os CT-es da Gerdau o líquido sai **sem ICMS**; para os demais clientes, o líquido sai **com ICMS** (o ICMS próprio não é descontado, por decisão já tomada no BI). Os dois tipos são somados juntos no mesmo ranking e no mesmo R$/km.

### 1.3 Não é só a Gerdau

| Recorte | O que os dados mostram |
| --- | --- |
| CT-es com ICMS e prestação iniciada fora do PR | Vários clientes e UFs de origem (SP, RJ, MG, SC, DF, MT, RS). |
| … com guia 503 vinculada | Uma pequena parte: Gerdau, ArcelorMittal (RJ/SP), Rudolf Sizing (SP), Arauco (RS), Indemil. |
| … sem guia | A grande maioria: Usiminas (SP/MG), Panorama, Bigolin, Movistar, Construcal, Unidas, ACB, ArcelorMittal (MG, CST 00)… |
| CT-es com origem no PR e guia 503 | Casos isolados (provável lançamento errado). |
| Guias 503 sem CT-e vinculado | Poucas. |

O CST (90 em quase todos) **não diferencia** quem tem guia de quem não tem. Ou seja, os dados do CT-e sozinhos não dizem se a JR paga a guia: isso depende do acordo com o tomador (se ele retém/recolhe o ICMS ou se a JR recolhe e cobra no frete).

## 2. Perguntas para fechar com o financeiro/contabilidade antes de codar

1. **Quem paga a guia?** Para quais clientes/rotas a JR recolhe o ICMS em guia (Gerdau, ArcelorMittal RJ/SP, Rudolf…)? E nos CT-es sem guia (ex.: Usiminas SP, Panorama), o ICMS é recolhido pelo tomador, pela apuração normal, ou a guia simplesmente não está sendo lançada?
2. **O tomador paga o valor cheio do CT-e?** Se o tomador retém o ICMS (substituição tributária), ele paga o frete sem ICMS e o faturamento bruto do BI está maior que o recebido. Já existe um indício: a comissão da Usiminas usa a base "frete sem ICMS".
3. **Frete líquido com ou sem ICMS?** Hoje o líquido mistura os dois critérios (seção 1.2). Queremos o líquido sempre sem o ICMS que sai do caixa em guia, e o bruto mantido como está?
4. **Prazo da guia**: em quantos dias depois da emissão a guia deve estar lançada? (Define quando um CT-e vira "guia pendente".)
5. **Regra estável**: a obrigação de pagar a guia é por **grupo de clientes**, por **cliente tomador** ou por **UF de origem**?

## 3. Plano de desenvolvimento

Cada fase é um PR independente, entregável sozinho e compatível com o deploy sem downtime (seção Deploy do `AGENTS.md`).

### Fase 1 — Conferência de guias de ICMS antecipado (visibilidade, sem mudar números)

Objetivo: mostrar, CT-e a CT-e, o ICMS que deveria ter guia e o que foi pago. Responde ao card ("estudar no BI como está acontecendo") sem decidir ainda a regra do líquido.

- `Atua::Expense`: constante `ADVANCE_ICMS_HISTORY_CODES = [503].freeze` e o scope `advance_icms`, no padrão de `UNLOADING_HISTORY_CODES`/`FUEL_HISTORY_CODES`.
- `Atua::TransportDocument` (concern `Atua::AdvanceIcms`): scope `advance_icms` com os CT-es ativos, não cancelados, com **CFOP 5932/6932 e ICMS**, ou com alguma guia 503 vinculada (para mostrar guias lançadas em CT-e errado). O tenant não tem UF cadastrada, e o CFOP x932 é justamente "prestação iniciada em UF diferente da do prestador". Mais o select `with_advance_icms_guide` com o total das guias, no padrão de `expenses_total`.
- Status calculado por CT-e: **guia paga** (guia = ICMS), **guia divergente** (guia ≠ ICMS) e **sem guia**. A separação de "sem guia" entre pendente e não esperada fica para a Fase 2, que cadastra quem paga a guia.
- Nova tela "ICMS antecipado" (`AdvanceIcmsController#index`, no menu Fiscal):
  - `counter_card`s: CT-es (dark), guias pagas (success), pendentes (warning), divergentes (danger), totais em R$ (primary).
  - Tabela paginada (`listing_page`) com `_table`/`_row`, ordenação por data, cliente, ICMS e guia (`sortable`), colunas secundárias escondidas no celular.
  - Filtros em modal (`_filters.html.erb`): período, grupo de clientes, UF de origem, status.
  - Exportação PDF e Excel (`respond_with_listing`, `Exportable`/`export_field`).
- Nova resource de permissão no `db/seeds.rb` (idempotente) e entrada no `config/menu.yml`.
- Specs: unit do scope e do status (`spec/models/atua/`), feature da tela (listagem com `html_table_to_rows` + `Model.count`, filtros, celular com `use_mobile_screen`, PDF, `:xlsx_service`).

### Fase 2 — Regra de quem paga a guia (cadastro)

Configuração no **grupo de clientes**, como já existe `toll_reimbursed`. Só a GERDAU foi marcada, porque o card confirma que a JR paga as guias dela; os demais grupos (ArcelorMittal, Rudolf…) ficam para quem responder as perguntas 1 e 5 marcar no cadastro.

- Coluna nova `pays_advance_icms_at` (datetime nulo, **nunca boolean**, conforme a seção Database) em `customer_groups`, exposta com `time_based_flag :pays_advance_icms`; o `CustomerGroupForm` ganha o checkbox virtual `pays_advance_icms` ("JR paga a guia de ICMS antecipado"), e a tela do grupo mostra a regra.
- A migração de dados `MarkAdvanceIcmsCustomerGroups` marca a GERDAU já existente; o `CustomerGroups::BackfillCommand` marca a GERDAU criada para um tenant novo.
- A tela da Fase 1 separa o CT-e sem guia em **Guia pendente** (tomador de grupo marcado) e **Sem guia esperada**. Os contadores mostram total, pagas, divergentes e pendentes; "Sem guia esperada" fica no filtro.
- A migração de `toll_reimbursed` (boolean legado) para `toll_reimbursed_at` não foi feita aqui: a coluna não foi alterada, e ela pede um expand/contract próprio.

### Fase 3 — Frete líquido estável (provisão da guia pendente)

Corrige o líquido inflado enquanto a guia não é lançada. Segue o critério que o BI já usava para esses CT-es: quando a guia é lançada, ela é descontada do líquido; a provisão só antecipa esse desconto. Não muda o líquido dos clientes cujo grupo não está marcado (pergunta 3 continua aberta para eles).

- Novo tipo `advance_icms` em `FreightExpense::KINDS` (valor novo no enum `freight_expense_kind_type`), calculado por `FreightExpenses::CalculateAdvanceIcmsCommand`, idempotente, no padrão do `CalculateTarpLiningCommand`: para cada CT-e com a situação **Guia pendente** (Fase 2), grava o ICMS do CT-e como base e valor; quando a guia 503 é vinculada, o grupo é desmarcado ou o CT-e é cancelado, a provisão é apagada. A guia real e a provisão nunca existem ao mesmo tempo.
- O comando roda no `FreightExpenses::CalculateJob`, no `Atua::LinkExpensesJob` (depois de vincular as despesas importadas, que é quando a guia chega) e, pelo `CalculateJob`, quando a regra do grupo muda no cadastro.
- O frete líquido em SQL já soma todas as `freight_expenses`; o quadro do frete líquido do CT-e e do MDF-e (`NetFreight`) ganhou a linha "(−) ICMS antecipado com guia pendente". A provisão aparece também na tela Despesas de frete, com o tipo "Provisão de ICMS antecipado".

### Fase 4 — Indicadores no BI

Depende da resposta 2.

- Dashboard de frete: total de ICMS recolhido em guia no período e % sobre o faturamento, por grupo de clientes (dados em `app/models/dashboard/`, gráfico em helper, cor conforme a seção Charts).
- Se o tomador retém o ICMS em alguns clientes: avaliar a visão "faturamento sem ICMS retido" para o bruto não ficar acima do recebido.
- Alerta de guia pendente fora do prazo (resposta 4), no mesmo formato dos avisos já existentes.

## 4. Ordem sugerida e tamanho

| Fase | Depende de | Tamanho |
| --- | --- | --- |
| 1 — Conferência de guias | nada | médio (1 tela completa) |
| 2 — Regra por grupo | respostas 1 e 5 | pequeno |
| 3 — Provisão no líquido | Fase 2 + resposta 3 | médio |
| 4 — Indicadores | Fase 3 + resposta 2 | médio |

A Fase 1 pode começar já, enquanto as perguntas da seção 2 são respondidas: ela não muda nenhum número do BI e já mostra ao financeiro os CT-es com guia pendente ou divergente.
