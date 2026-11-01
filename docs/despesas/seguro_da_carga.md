# Seguro da carga como despesa de frete: descritivo técnico

Status: **implementado** na branch `freight-insurance`, seguindo as opções propostas na seção 6.

## 1. Objetivo

Criar uma nova despesa de frete, o **seguro da carga**, calculada automaticamente para cada CT-e e somada em cada viagem (MDF-e), do mesmo jeito que já funcionam a comissão e o custo por tonelada. O valor entra no frete líquido do CT-e e da viagem.

As alíquotas ficam num cadastro próprio (**Alíquota de seguro**), um único registro por empresa, para que uma mudança futura seja feita na tela, sem alterar o código.

## 2. Regra de cálculo

```
base do seguro = valor da carga (vl_nota_fiscal), sem o valor do frete
seguro         = base do seguro × alíquota do seguro          (hoje 0,022%)
IOF            = seguro × alíquota do IOF                      (hoje 7,38%, só em frete internacional)
despesa        = seguro + IOF
```

- **Frete internacional** é o CT-e com UF de destino `EX`, o mesmo critério que a comissão já usa (`CommissionRule::FOREIGN_STATE`). No frete nacional o IOF é zero.
- **Arredondamento:** o seguro é arredondado para centavos (meio para cima) e o IOF é calculado sobre o seguro já arredondado. Assim, a soma das parcelas exibidas sempre bate com o total.
- **CT-es considerados:** ativos, não cancelados e do tipo CTRC, **excluindo** os de "Complemento de Valores". O complemento repete o valor da nota do CT-e original, então incluí-lo cobraria o seguro da mesma carga duas vezes. É o mesmo filtro que a comissão usa hoje (`Atua::TransportDocument.commissionable`).
- **Vale para todos os CT-es**, sem depender de grupo de clientes, porque a apólice é da transportadora.

### Exemplos

| | Nacional | Internacional |
|---|---|---|
| Valor da carga | R$ 8.389,98 | R$ 8.389,98 |
| Base do seguro | R$ 8.389,98 | R$ 8.389,98 |
| Seguro (0,022%) | R$ 1,85 | R$ 1,85 |
| IOF (7,38% do seguro) | — | R$ 0,14 |
| **Despesa** | **R$ 1,85** | **R$ 1,99** |

### Alíquota única, sem vigência

Cada empresa tem **uma única alíquota**, sem data de vigência. O valor efetivamente descontado é o da despesa de frete gerada a partir dela: cada despesa grava a base, os percentuais e o valor calculados. Ao alterar a alíquota, o seguro de **todos** os CT-es é recalculado com o novo valor, inclusive os já emitidos.

## 3. Cadastro da alíquota de seguro

### Banco de dados (migration gerada com `rails g migration`)

Tabela `insurance_rates`:

| Coluna | Tipo | Observação |
|---|---|---|
| `tenant_id` | references, not null, FK | índice único: uma alíquota por empresa |
| `insurance_percentage` | decimal(7,4), not null | 0,0220 |
| `iof_percentage` | decimal(7,4), not null | 7,3800 |
| timestamps | | |

A primeira versão tinha a coluna `valid_from` (vigência). A migration `RemoveValidFromFromInsuranceRates` a remove: em cada empresa com mais de uma alíquota, mantém a vigente hoje, aponta para ela as despesas das demais, apaga as outras e recalcula o seguro.

A migration também registra o recurso de permissão `insurance_rates` na tabela `resources` (mesmo padrão de `AddTonnageRatesResource`), para que a tela entre no controle de acesso dos usuários.

### Código

- **Modelo** `InsuranceRate` (`app/models/insurance_rate.rb`): `belongs_to :tenant`, `has_many :freight_expenses, dependent: :restrict_with_error`, validações (`insurance_percentage` > 0 e < 100, `iof_percentage` ≥ 0 e < 100, uma por tenant) e os métodos `insurance_cents(base_cents)` e `iof_cents(insurance_cents)`.
- **Form object** `InsuranceRateForm` (`app/forms/insurance_rate_form.rb`): `for_tenant(tenant)` carrega a alíquota da empresa ou sugere os valores padrão quando ainda não há nenhuma. Ao salvar (cria ou altera), enfileira `FreightExpenses::CalculateJob`, como fazem `CommissionRuleForm` e `TonnageRateForm`.
- **Controller** `InsuranceRatesController < BaseController` num recurso singular (`resource :insurance_rate, only: %i[show edit update]`, como `company`), com `authorize!` no recurso `:insurance_rates`. Não há listagem, cadastro nem exclusão.
- **Telas** (mobile-first, com `page_header_tag`):
  - detalhe (`dl_to_hash`) com as alíquotas, quantos CT-es têm seguro e o total calculado, e o alerta quando a empresa ainda não tem alíquota;
  - formulário com os campos de percentual (`inputmode: decimal`), já preenchido com os valores padrão quando não há alíquota.
- **Menu** `config/menu.yml`: entrada "Alíquota de seguro" no mesmo grupo de "Regras de comissão" e "Custos por tonelada".
- **Seed/backfill** `InsuranceRates::BackfillCommand` (idempotente): cria a alíquota inicial (0,022% e 7,38%) da empresa, para o histórico já importado ser calculado. Só cria se a empresa não tiver alíquota.
- **I18n:** todos os textos em `config/locales/pt-BR.yml` (modelo, atributos, telas, mensagens), sem `default:`.

## 4. Despesa de frete "Seguro da carga"

### Banco de dados

Na tabela `freight_expenses`:

- adicionar o valor `insurance` ao enum `freight_expense_kind_type`;
- `insurance_rate_id` (references, FK, opcional), `iof_percentage` (decimal(7,4)) e `iof_cents` (bigint, default 0, not null).

As colunas existentes são reaproveitadas: `base_cents` (valor da carga), `percentage` (alíquota do seguro) e `amount_cents` (seguro + IOF, o total da despesa). O índice único `(transport_document_id, kind_type)` garante uma linha de seguro por CT-e.

### Modelo `FreightExpense`

- `KINDS = %i[commission tonnage insurance]`;
- `belongs_to :insurance_rate, optional: true`;
- `monetize :iof_cents`;
- validações quando `insurance?`: `insurance_rate`, `base_cents` e `percentage` obrigatórios;
- tradução do novo tipo em `enums.freight_expense.kind_type.insurance` ("Seguro da carga").

### Comando de cálculo

`FreightExpenses::CalculateInsuranceCommand` (`app/command/freight_expenses/calculate_insurance_command.rb`), no mesmo formato de `CalculateCommissionsCommand` e `CalculateTonnageCommand`:

1. carrega a alíquota do tenant (se não houver, não calcula nada e remove os seguros existentes);
2. para cada CT-e coberto, calcula base, seguro, IOF (se `EX`) e total;
3. compara com o que já está gravado e só faz `upsert_all` do que mudou; remove os seguros de CT-es que deixaram de ser cobertos (cancelados, inativados);
4. retorna `Result(saved:, removed:)`.

O comando é idempotente: rodar duas vezes seguidas não altera nada.

**Quando roda:** o comando entra em `FreightExpenses::CalculateJob`, junto com a comissão e a tonelagem. Esse job já é disparado ao fim de cada importação da Atua, pelo botão "Recalcular" da tela de despesas de frete e ao salvar uma regra. Também passa a ser disparado ao salvar a alíquota de seguro, recalculando o seguro de todos os CT-es.

### Onde aparece

| Tela | O que muda |
|---|---|
| **Detalhe do CT-e** | O card "Despesas de frete" ganha a linha "Seguro da carga". O card "Frete líquido" ganha a linha **Seguro da carga** (em vermelho, descontada). |
| **Detalhe da viagem (MDF-e)** | Mesmas mudanças: uma linha de seguro por CT-e da viagem e o seguro somado no frete líquido da viagem. |
| **Despesas de frete** (listagem) | O novo tipo aparece na lista e no filtro "Tipo". Colunas: detalhe = "Alíquota de seguro" + "Internacional (com IOF de R$ x)" quando houver; base = valor da carga; ICMS = "—"; taxa = alíquota do seguro; valor = seguro + IOF. Novo alerta quando o tenant não tem alíquota de seguro cadastrada. |

O filtro por grupo de clientes dessa listagem continua considerando só comissão e tonelagem, porque o seguro não depende de grupo.

### Frete líquido

`NetFreight` ganha o atributo `insurance` (soma de `FreightExpense.insurance` dos CT-es) e passa a calcular:

```
frete líquido = frete − comissão − custo por tonelada − seguro da carga − despesas lançadas
```

### Relação com o `vl_seguro` da Atua

O campo `insurance_cents` de `Atua::TransportDocument` (vem do `vl_seguro` da Atua, hoje sempre zero) **não é alterado nem usado** no cálculo. Ele continua refletindo o que vem do ERP. O seguro calculado vive só em `freight_expenses`.

## 5. Testes

Seguindo o AGENTS.md (sem specs de controller/request):

- **Unitários:**
  - `spec/models/insurance_rate_spec.rb`: validações (uma por tenant) e cálculo com arredondamento;
  - `spec/forms/insurance_rate_form_spec.rb`: criação e alteração, valores padrão, validações e enfileiramento do job;
  - `spec/command/freight_expenses/calculate_insurance_command_spec.rb`: nacional, internacional com IOF, recálculo de todos os CT-es ao alterar a alíquota, complemento e cancelado ignorados, idempotência, remoção quando o CT-e deixa de ser coberto e tenant sem alíquota;
  - `spec/command/insurance_rates/backfill_command_spec.rb`: cria só uma vez;
  - `spec/models/net_freight_spec.rb`: desconta o seguro;
  - `spec/models/freight_expense_spec.rb`: validações do novo tipo;
  - `spec/migrations/remove_valid_from_from_insurance_rates_spec.rb`: mantém a alíquota vigente e recalcula o seguro.
- **End-to-end** (`spec/features/`):
  - detalhe e alteração da alíquota, com conferência do registro gravado, permissões, ausência de listagem/cadastro/exclusão e tela de celular;
  - seguro no detalhe do CT-e e da viagem, e frete líquido com o desconto;
  - listagem de despesas de frete com o filtro pelo novo tipo e o alerta de alíquota ausente;
  - isolamento entre tenants.

## 6. Decisões adotadas (revisar se alguma não vale)

1. **Vigência ou valor único?** Decidido: valor único por empresa, sem vigência. Ao alterar, todo o histórico é recalculado.
2. **Complementos de valores ficam fora?** A proposta é que fiquem, para não cobrar duas vezes o seguro da mesma carga.
3. **Base do seguro:** somente o valor da carga. O valor do frete não entra na base.
4. **Internacional só pela UF de destino `EX`?** Uma importação (origem no exterior, destino no Brasil) não teria IOF por esse critério.
5. **Cálculo retroativo:** o backfill calcula o seguro para todos os CT-es já importados. Se preferir a partir de uma data, informe qual.

## 7. Entrega

Cinco migrations: tabela `insurance_rates`, novo tipo e colunas em `freight_expenses`, recurso de permissão `insurance_rates`, o backfill da alíquota inicial de cada empresa (`InsuranceRates::BackfillCommand`, que já calcula o seguro do histórico) e a remoção da vigência (`RemoveValidFromFromInsuranceRates`). O PR traz também a tela da alíquota, o comando de cálculo plugado em `FreightExpenses::CalculateJob`, o seguro no frete líquido e nas três telas, as traduções e os testes acima.
