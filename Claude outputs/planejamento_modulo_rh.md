# Módulo de RH — escala de folgas 5x2 (plano de desenvolvimento)

Este é o plano para implementar o módulo de RH no projeto `transjrbi`. Leia o `AGENTS.md` antes de começar: todas as regras dele valem aqui. Isso inclui commands em `app/command/`, form objects, a regra de não ter colunas booleanas, os enums com sufixo `_type`, telas mobile-first, I18n sem `default:`, specs sem controller/request, migrations backward compatible e seeds idempotentes.

**Como trabalhar:** entregue em **3 PRs**, nesta ordem, cada um numa branch nova saindo da `main`. Ao terminar cada PR, rode `script/build`, abra o PR e **pare para revisão** antes de começar o próximo.

---

## 1. Contexto e decisões já tomadas

A Emenda Constitucional 141/2026, publicada em 16/10/2026, garante **2 dias de repouso semanal remunerado**, um deles preferencialmente aos domingos e não necessariamente em dias seguidos. A regra passa a valer em dezembro de 2026. A empresa precisa montar a escala de folgas dos **motoristas** (vindos do Atua) e dos **funcionários da oficina** (do módulo de manutenção), e ver quem está fora da regra.

Decisões:

| Tema | Decisão |
| --- | --- |
| Escopo | Escala de folgas + avisos de conformidade. **Sem** controle de horas e **sem** ponto. |
| Quem acessa | Só usuários com permissão no RH. **Motoristas e funcionários não têm login** e não acessam nada. Eles recebem a escala impressa (PDF) ou em planilha. |
| Onde | Subdomínio próprio `rh.<domínio>`, montado igual ao `manutencao`. |
| Regra de folgas | **Sempre 2 folgas por semana** (segunda a domingo). Não existe regime compensatório por convenção coletiva. |
| Folga no domingo | Pelo menos **1 domingo de folga a cada N semanas**, com N configurável e **padrão 4**, que é a regra de "um domingo por mês" da empresa. Na prática, no máximo N−1 domingos trabalhados seguidos. |
| Início da cobrança | Configurável, padrão **17/12/2026**. |
| Oficina | Não trabalha aos domingos. Ainda não sabemos se trabalha aos sábados: os dias de folga padrão da oficina ficam configuráveis, com padrão sábado + domingo. |
| Motoristas não CLT | Agregados e terceiros entram **inativos**. Só entram ativos os motoristas de veículos da frota própria (`OwnFleet#plates`). |
| Motoristas em viagem | A folga pode e deve ser tirada durante a viagem. Desde a ADI 5322 (STF, 2023), o descanso semanal **não pode ser acumulado** para ser tirado na volta. |

Fora do escopo (não implementar): login de funcionários, controle de horas, limite semanal de 42/40h, as 11h entre jornadas, o limite de direção da Lei 13.103, banco de horas e a regra de domingo quinzenal para mulheres (art. 386 da CLT, que depende de uma decisão pendente; veja a seção 7).

---

## 2. Infraestrutura do subdomínio `rh` (PR 1)

Copie o padrão do subdomínio de manutenção:

- `config/application.rb`: `HR_SUBDOMAIN = 'rh'.freeze` e `config.x.hr_host = "#{HR_SUBDOMAIN}.#{config.x.domain}"`. Adicione o host em `config.hosts` (`config/environments/production.rb`).
- `config/routes.rb`: novo bloco `constraints subdomain: Transjrbi::HR_SUBDOMAIN`. O Devise e as telas de senha precisam funcionar nesse subdomínio também (veja como o bloco `[APP_SUBDOMAIN, MAINTENANCE_SUBDOMAIN]` faz). A raiz (`HrHomeController`) redireciona para a primeira tela de RH que o usuário pode ler.
- Concern `HrHost` (espelho de `app/controllers/concerns/maintenance_host.rb`):
  - `hr_host?`;
  - `require_hr_host_feature`, que dá 404 com a flag desligada;
  - `require_hr_access`, que exige `can?(:read, :hr)` e, sem essa permissão, desloga o usuário e manda para o login com uma mensagem I18n.
- `BaseController#current_ability`: troque o ternário por uma escolha por host. No `rh` use `Ability::HR_RESOURCES`, na manutenção `Ability::MAINTENANCE_RESOURCES`, no app `nil`.
- `Ability::HR_RESOURCES = %i[hr hr_employees hr_schedules hr_alerts hr_settings].freeze`.
- Flag do Flipper `hr`, por tenant (exponha como `Hr.enabled?(tenant)`, no mesmo padrão de `MaintenanceOrder.enabled?`).
- `db/seeds.rb` (idempotente, `find_or_create_by!`), com os recursos:
  - `hr` → "Módulo de RH" (`writable: false`);
  - `hr_employees` → "Funcionários do RH";
  - `hr_schedules` → "Escalas de folga";
  - `hr_alerts` → "Avisos de conformidade" (`writable: false`);
  - `hr_settings` → "Configurações do RH".
- `config/menu.yml`: nova chave `hr` (Funcionários, Escala, Avisos, Configurações). Faça o `MenuHelper#sidebar_menus` escolher `:hr` no host do RH. A barra lateral do app **não** ganha entrada de RH.
- `deploy/compose.yaml`: acrescente `|| Host(\`rh.${APP_DOMAIN}\`)` ao `traefik.http.routers.web.rule`. Atualize a seção "Admin Namespace / subdomains" do `AGENTS.md` (em inglês) descrevendo o subdomínio do RH, como já é feito para o de manutenção.
- `spec/support/capybara.rb`: metadata `:hr`, que troca o `Capybara.app_host` para o `hr_host`.

---

## 3. Dados

Use o namespace `Hr::` com prefixo de tabela `hr_`. Crie `app/models/hr.rb` com `def self.table_name_prefix = 'hr_'`, como em `app/models/admin.rb`. Gere as migrations com `bundle exec rails g migration`.

### `hr_employees` (PR 1)

| Coluna | Tipo | Observação |
| --- | --- | --- |
| `tenant_id` | ref, not null | |
| `kind_type` | enum `hr_employee_kind_type` (`driver`, `workshop`), not null | |
| `driver_code` | bigint, null | Preenchido quando `driver` |
| `workshop_employee_id` | ref `workshop_employees`, null | Preenchido quando `workshop` |
| `name` | string, not null | Cópia do nome da origem, atualizada no sync |
| `activated_at` | datetime | Usar `Activatable`. Ativo = o RH acompanha a pessoa |

- Índices únicos parciais: `(tenant_id, driver_code) WHERE driver_code IS NOT NULL` e `(tenant_id, workshop_employee_id) WHERE workshop_employee_id IS NOT NULL`.
- Check constraint: exatamente uma origem preenchida, de acordo com `kind_type`.
- Model `Hr::Employee`: `include Activatable, Sortable, Exportable`, `sortable :name`, scopes `by_name`, `by_kind_type`, `by_status`, enum com `validate: true` e tradução em `enums.hr/employee.kind_type`.

### `hr_schedule_days` (PR 2)

Um registro por pessoa por dia **que não é de trabalho**. Dia sem registro = dia de trabalho.

| Coluna | Tipo | Observação |
| --- | --- | --- |
| `tenant_id` | ref, not null | |
| `hr_employee_id` | ref, not null | |
| `date` | date, not null | |
| `day_type` | enum `hr_schedule_day_type` (`rest`, `rest_on_trip`, `vacation`, `leave`), not null | `rest` = folga, `rest_on_trip` = folga em viagem, `vacation` = férias, `leave` = afastamento/atestado |

- Índices: único `(hr_employee_id, date)` e `(tenant_id, date)`.
- `rest` e `rest_on_trip` contam como folga. `vacation` e `leave` tiram a semana da cobrança.

### `hr_settings` (PR 3)

Um registro por tenant (`has_one :hr_setting`, criado sob demanda com os padrões).

| Coluna | Tipo | Padrão |
| --- | --- | --- |
| `tenant_id` | ref, not null, único | |
| `rule_starts_on` | date, not null | `2026-12-17` |
| `sunday_rest_interval_weeks` | integer, not null | `4` (validar 1..7) |
| `workshop_rest_wdays` | integer[], not null | `{6,0}` (sábado e domingo, no padrão `Date#wday`) |

Lembre do `has_many`/`has_one` com `dependent:` no `Tenant`, como nas outras tabelas.

---

## 4. Sincronização de funcionários (PR 1)

`Hr::SyncEmployeesCommand.call(tenant)` em `app/command/hr/`, **idempotente**:

- **Motoristas:** a partir de `tenant.atua_vehicles.drivers` (um por `driver_code`). O nome é `display_name.presence || driver_name`.
  - Motorista novo entra **ativo** se algum dos veículos dele (`plates`) estiver em `tenant.own_fleet&.plates`. Se a frota própria não tiver placas cadastradas, entra ativo. Caso contrário, entra **inativo** (`activated_at: nil`).
  - Motorista que já existe: atualiza só o `name`. **Nunca** mude o status que o RH definiu.
  - Motorista que saiu do Atua ou foi excluído (`ExcludedDriver`, `Atua::PurgeInactiveDriversCommand`) é desativado.
- **Oficina:** a partir de `tenant.workshop_employees`. Funcionário novo e ativo entra ativo. Atualiza o `name`. Quem foi desativado na oficina é desativado no RH.
- **Quando roda:**
  - no final da importação de veículos do Atua (logo depois de `PurgeInactiveDriversCommand` em `lib/atua/save_vehicles_command.rb`);
  - depois de criar ou editar um funcionário da oficina (no fluxo do form object de `workshop_employees`);
  - por um botão "Sincronizar" na tela de Funcionários do RH.
- Spec em `spec/command/hr/sync_employees_command_spec.rb`, cobrindo:
  - frota própria com e sem placas;
  - rodar duas vezes sem duplicar;
  - status definido pelo RH preservado;
  - desativação de quem saiu da origem.

---

## 5. Telas

Todas mobile-first, com `page_header_tag`, tabelas paginadas (`listing_page` + `paginate`), `responsive_actions_menu`, filtros em modal (`link_to_filters`), `counter_card`, `status_badge` e I18n completo. Siga o `AGENTS.md`.

### PR 1 — Funcionários (`/employees` no host `rh`, controller `Hr::EmployeesController`)

- Contadores: total, ativos, inativos.
- Colunas: nome, tipo (Motorista/Oficina), status. A coluna "folgas na semana atual" entra no PR 2.
- Filtros: nome, tipo, status. Ordenação por nome.
- Ações: ativar/desativar (com `turbo_confirm`) e o botão "Sincronizar".
- Exportação em PDF e XLSX (`respond_with_listing`), atrás da flag `xlsx_export` já existente.
- Sem criar ou excluir manualmente: as pessoas vêm sempre da origem.

### PR 2 — Escala da semana (`/schedule?week=2026-12-21`, `Hr::SchedulesController`)

- A semana vai de segunda a domingo, com navegação para a semana anterior e a próxima.
- **Computador:** grade com pessoas (ativas) nas linhas e os 7 dias nas colunas. **Celular:** uma lista por pessoa, com os 7 dias empilhados.
- Cada célula abre um menu (turbo stream no `remote-container`, componente `components/new_modal` ou dropdown) com as opções: Trabalho (apaga o registro), Folga, Folga em viagem (só para motoristas), Férias e Afastamento. Form object `Hr::ScheduleDayForm`.
- **Dias em viagem (motoristas):**
  - Marque na célula os dias em que o motorista tem MDF-e em aberto, de `Atua::Manifest#trip_started_at` até `closed_at` (sem `closed_at`, até hoje), ligados ao motorista pelo `driver_code` dos CT-es do manifesto. Reaproveite a lógica do motorista principal de `Dashboard::Trip` (o lateral join `main_drivers`) e de `Atua::Manifest#main_driver_name`.
  - Encapsule em um query object, por exemplo `Hr::DriverTripDays.new(tenant, period).for(driver_codes)`, que devolve um hash `driver_code => Set[dates]`.
- **Domingo obrigatório:** marque o domingo em que a folga é obrigatória, ou seja, quando a pessoa já trabalhou N−1 domingos seguidos (N = `sunday_rest_interval_weeks`; até o PR 3 use 4 como constante).
- Coluna e contagem "folgas na semana" por pessoa, com destaque quando for menor que 2.
- **Copiar semana anterior:** `Hr::CopyWeekCommand.call(tenant, week)`, idempotente. Copia só `rest` e `rest_on_trip` e não sobrescreve dias já lançados.
- **Preencher padrão da oficina:** `Hr::ApplyWorkshopPatternCommand`, idempotente. Marca como `rest` os `workshop_rest_wdays` (até o PR 3, use sábado + domingo como constante) para os funcionários da oficina sem lançamento naqueles dias.
- Exportação: PDF da escala da semana (`.pdf.erb` em Typst, seguindo as regras de PDF do `AGENTS.md`) e XLSX (helper `*_xlsx_sheet` com `Export::Sheet.new`).
- Funcionários (PR 1) ganha a coluna "folgas na semana atual".

### PR 3 — Avisos (`/alerts`, `Hr::AlertsController`) e Configurações (`/settings`, `Hr::SettingsController`)

- **Avisos:** contadores por tipo, lista paginada e filtros por semana, tipo e pessoa. Cada aviso leva para a escala da semana correspondente.
- **Configurações:** formulário (`Hr::SettingForm`) com `rule_starts_on`, `sunday_rest_interval_weeks` e `workshop_rest_wdays` (checkboxes dos dias da semana). Troque as constantes do PR 2 pelos valores da configuração.

---

## 6. Regras dos avisos (PR 3)

Calculados na hora, sem gravar. Crie `Hr::ComplianceCheck.new(tenant, period).alerts`, que devolve objetos `Hr::Alert` (kind, employee, week_start, details), com spec unitária para cada regra.

Considere só pessoas **ativas** e semanas (segunda a domingo) **cuja segunda-feira seja igual ou posterior a `rule_starts_on`**.

| Tipo (`kind`) | Regra |
| --- | --- |
| `missing_weekly_rest` | Semana encerrada ou em andamento com menos de 2 dias `rest`/`rest_on_trip`. Ignore a semana se ela tiver qualquer dia `vacation` ou `leave`. |
| `missing_weekly_rest_on_trip` | O mesmo caso anterior, mas o motorista teve dias em viagem naquela semana. Use este tipo **no lugar** do anterior: a mensagem diz que as folgas não podem ficar para a volta. |
| `sunday_rest_overdue` | Domingos trabalhados seguidos ≥ `sunday_rest_interval_weeks`. Domingo com `vacation`/`leave` zera a contagem, como se fosse uma folga. Também avise **antes**: se o próximo domingo é obrigatório e está lançado como trabalho. |
| `schedule_not_filled` | A próxima semana não tem nenhum dia `rest`/`rest_on_trip` lançado para uma pessoa ativa. |

Casos de borda que precisam de spec:

- semana parcial no início da regra;
- pessoa ativada no meio da semana (cobre só semanas completas a partir de `activated_at`);
- motorista sem viagem;
- viagem sem `closed_at`;
- domingo de férias.

---

## 7. Pendências (use o padrão e siga em frente)

- **Intervalo do domingo:** o padrão de 4 semanas vem da regra de "um domingo por mês" que a empresa segue. Fica configurável porque a regra geral da Portaria 671/2021 é de 7 semanas e convenções coletivas podem definir outro prazo.
- **Mulheres:** o art. 386 da CLT exige um domingo de folga a cada 15 dias quando a funcionária trabalha aos domingos. Se a empresa confirmar que há motoristas mulheres, isso vira um PR à parte. **Não implemente agora.**
- **Sábado na oficina:** coberto pelo `workshop_rest_wdays`, padrão sábado + domingo.

---

## 8. Checklist de cada PR

- Migrations backward compatible, seeds idempotentes e annotate no fim dos models.
- Feature specs com a metadata `:hr`, incluindo `use_mobile_screen` nas telas cujo layout muda entre tamanhos de tela. Cubra:
  - acesso negado sem `:hr`;
  - 404 com a flag desligada;
  - usuário sem permissão de escrita não consegue alterar a escala;
  - isolamento entre tenants.
- Listagens verificadas com `html_table_to_rows` e contagem no banco. Formulários verificados nos atributos persistidos e no `change(..., :count)`.
- `script/build` verde (rubocop, erb_lint, herb, brakeman, rspec, bun test).
- Sem comentários no código e sem `# rubocop:disable`.
