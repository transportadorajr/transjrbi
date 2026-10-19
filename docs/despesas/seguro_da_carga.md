# Seguro da carga como despesa de frete: descritivo técnico

Status: **implementado** na branch `freight-insurance`, seguindo as opções propostas na seção 6.

## 1. Objetivo

Criar uma nova despesa de frete, o **seguro da carga**, calculada automaticamente para cada CT-e e somada em cada viagem (MDF-e), do mesmo jeito que já funcionam a comissão e o custo por tonelada. O valor entra no frete líquido do CT-e e da viagem.

As alíquotas ficam num cadastro próprio (**Alíquotas de seguro**), para que uma mudança futura seja feita na tela, sem alterar o código.

## 2. Regra de cálculo

```
base do seguro = valor da carga (vl_nota_fiscal) + valor do frete (vl_frete_empresa)
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
| Valor do frete | R$ 555,04 | R$ 555,04 |
| Base do seguro | R$ 8.945,02 | R$ 8.945,02 |
| Seguro (0,022%) | R$ 1,97 | R$ 1,97 |
| IOF (7,38% do seguro) | — | R$ 0,15 |
| **Despesa** | **R$ 1,97** | **R$ 2,12** |

Na amostra real do `rel_ctrc_detalhado` (01 a 13/10/2026: 509 CT-es, 498 depois de tirar 11 complementos), o seguro somaria **R$ 9.502,46**. Essa amostra não tem nenhum CT-e internacional.

### Vigência das alíquotas

Cada alíquota cadastrada tem uma **data de início de vigência**. O CT-e usa a alíquota vigente na sua data de emissão. Com isso, uma alteração futura não muda o seguro dos CT-es já emitidos: basta cadastrar uma alíquota nova com a nova data de início. Se um CT-e foi emitido antes da primeira vigência cadastrada, usamos a vigência mais antiga, como o custo por tonelada já faz (`TonnageRate.for_month`).

## 3. Cadastro de alíquotas de seguro

### Banco de dados (migration gerada com `rails g migration`)

Tabela `insurance_rates`:

| Coluna | Tipo | Observação |
|---|---|---|
| `tenant_id` | references, not null, FK | |
| `valid_from` | date, not null | início da vigência; índice único com `tenant_id` |
| `insurance_percentage` | decimal(7,4), not null | 0,0220 |
| `iof_percentage` | decimal(7,4), not null | 7,3800 |
| timestamps | | |

A migration também registra o recurso de permissão `insurance_rates` na tabela `resources` (mesmo padrão de `AddTonnageRatesResource`), para que a tela entre no controle de acesso dos usuários.

### Código

- **Modelo** `InsuranceRate` (`app/models/insurance_rate.rb`): `belongs_to :tenant`, `has_many :freight_expenses, dependent: :restrict_with_error`, validações (`insurance_percentage` > 0 e < 100, `iof_percentage` ≥ 0 e < 100, `valid_from` obrigatório e único por tenant), o método `self.for_date(rates, date)` (alíquota vigente na data) e os métodos `insurance_cents(base_cents)` e `iof_cents(insurance_cents)`.
- **Form object** `InsuranceRateForm` (`app/forms/insurance_rate_form.rb`): validações do formulário. Ao salvar, enfileira `FreightExpenses::CalculateJob`, como fazem `CommissionRuleForm` e `TonnageRateForm`.
- **Controller** `InsuranceRatesController < BaseController` com `index`, `show`, `new`, `create`, `edit`, `update` e `destroy`, com `authorize!` no recurso `:insurance_rates` e `has_scope`/`apply_scopes`/`.page` na listagem.
- **Telas** (mobile-first, com `page_header_tag`, `create_button`, `_table`/`_row`, `responsive_actions_menu` e `turbo_confirm` na exclusão):
  - listagem com início da vigência, alíquota do seguro, alíquota do IOF e uma marcação de qual está **vigente hoje**;
  - detalhe (`dl_to_hash`) com quantos CT-es usam a alíquota e o total de seguro calculado, como já existe em custo por tonelada;
  - formulário com os campos de percentual (`inputmode: decimal`).
- **Exclusão** de uma alíquota já usada por despesas fica bloqueada (`restrict_with_error`) e mostra a mensagem de erro. Para mudar o valor, o caminho é cadastrar uma nova vigência.
- **Menu** `config/menu.yml`: nova entrada `insurance_rates` no mesmo grupo de "Regras de comissão" e "Custos por tonelada".
- **Seed/backfill** `InsuranceRates::BackfillCommand` (idempotente): cria a alíquota inicial (0,022% e 7,38%) com vigência a partir da data mais antiga de CT-e do tenant, para o histórico já importado ser calculado. Só cria se o tenant não tiver nenhuma alíquota.
- **I18n:** todos os textos em `config/locales/pt-BR.yml` (modelo, atributos, telas, mensagens), sem `default:`.

## 4. Despesa de frete "Seguro da carga"

### Banco de dados

Na tabela `freight_expenses`:

- adicionar o valor `insurance` ao enum `freight_expense_kind_type`;
- `insurance_rate_id` (references, FK, opcional), `iof_percentage` (decimal(7,4)) e `iof_cents` (bigint, default 0, not null).

As colunas existentes são reaproveitadas: `base_cents` (valor da carga + frete), `percentage` (alíquota do seguro) e `amount_cents` (seguro + IOF, o total da despesa). O índice único `(transport_document_id, kind_type)` garante uma linha de seguro por CT-e.

### Modelo `FreightExpense`

- `KINDS = %i[commission tonnage insurance]`;
- `belongs_to :insurance_rate, optional: true`;
- `monetize :iof_cents`;
- validações quando `insurance?`: `insurance_rate`, `base_cents` e `percentage` obrigatórios;
- tradução do novo tipo em `enums.freight_expense.kind_type.insurance` ("Seguro da carga").

### Comando de cálculo

`FreightExpenses::CalculateInsuranceCommand` (`app/command/freight_expenses/calculate_insurance_command.rb`), no mesmo formato de `CalculateCommissionsCommand` e `CalculateTonnageCommand`:

1. carrega as alíquotas do tenant (se não houver nenhuma, não calcula nada e remove os seguros existentes);
2. para cada CT-e coberto, escolhe a alíquota vigente na emissão, calcula base, seguro, IOF (se `EX`) e total;
3. compara com o que já está gravado e só faz `upsert_all` do que mudou; remove os seguros de CT-es que deixaram de ser cobertos (cancelados, inativados);
4. retorna `Result(saved:, removed:)`.

O comando é idempotente: rodar duas vezes seguidas não altera nada.

**Quando roda:** o comando entra em `FreightExpenses::CalculateJob`, junto com a comissão e a tonelagem. Esse job já é disparado ao fim de cada importação da Atua, pelo botão "Recalcular" da tela de despesas de frete e ao salvar uma regra. Também passa a ser disparado ao salvar ou excluir uma alíquota de seguro.

### Onde aparece

| Tela | O que muda |
|---|---|
| **Detalhe do CT-e** | O card "Despesas de frete" ganha a linha "Seguro da carga". O card "Frete líquido" ganha a linha **Seguro da carga** (em vermelho, descontada). |
| **Detalhe da viagem (MDF-e)** | Mesmas mudanças: uma linha de seguro por CT-e da viagem e o seguro somado no frete líquido da viagem. |
| **Despesas de frete** (listagem) | O novo tipo aparece na lista e no filtro "Tipo". Colunas: detalhe = vigência da alíquota + "Internacional (com IOF de R$ x)" quando houver; base = carga + frete; ICMS = "—"; taxa = alíquota do seguro; valor = seguro + IOF. Novo alerta quando o tenant não tem alíquota de seguro cadastrada. |

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
  - `spec/models/insurance_rate_spec.rb`: validações, `for_date` (vigência na data, antes da primeira vigência) e cálculo com arredondamento;
  - `spec/forms/insurance_rate_form_spec.rb`: validações e enfileiramento do job;
  - `spec/command/freight_expenses/calculate_insurance_command_spec.rb`: nacional, internacional com IOF, troca de vigência, complemento e cancelado ignorados, idempotência, remoção quando o CT-e deixa de ser coberto e tenant sem alíquota;
  - `spec/command/insurance_rates/backfill_command_spec.rb`: cria só uma vez;
  - `spec/models/net_freight_spec.rb`: desconta o seguro;
  - `spec/models/freight_expense_spec.rb`: validações do novo tipo.
- **End-to-end** (`spec/features/`):
  - CRUD de alíquotas, com conferência do registro gravado, permissões, bloqueio de exclusão e tela de celular;
  - seguro no detalhe do CT-e e da viagem, e frete líquido com o desconto;
  - listagem de despesas de frete com o filtro pelo novo tipo e o alerta de alíquota ausente;
  - isolamento entre tenants.

## 6. Decisões adotadas (revisar se alguma não vale)

1. **Vigência ou valor único?** A proposta é guardar o histórico com data de início, para não mudar o passado quando a alíquota mudar. A alternativa é um único registro editável que recalcula todo o histórico ao ser alterado.
2. **Complementos de valores ficam fora?** A proposta é que fiquem, para não cobrar duas vezes o seguro da mesma carga.
3. **Frete com ICMS?** A proposta usa `vl_frete_empresa`, que é o frete total do CT-e, com ICMS. Se a apólice considera o frete sem ICMS, a base muda.
4. **Internacional só pela UF de destino `EX`?** Uma importação (origem no exterior, destino no Brasil) não teria IOF por esse critério.
5. **Cálculo retroativo:** o backfill calcula o seguro para todos os CT-es já importados. Se preferir a partir de uma data, informe qual.

## 7. Entrega

Quatro migrations: tabela `insurance_rates`, novo tipo e colunas em `freight_expenses`, recurso de permissão `insurance_rates` e o backfill da alíquota inicial de cada empresa (`InsuranceRates::BackfillCommand`, que já calcula o seguro do histórico). O PR traz também o cadastro completo de alíquotas, o comando de cálculo plugado em `FreightExpenses::CalculateJob`, o seguro no frete líquido e nas três telas, as traduções e os testes acima.
