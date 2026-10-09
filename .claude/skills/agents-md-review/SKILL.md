---
name: agents-md-review
description: Review a GitHub PR (or the current diff) against the project conventions in AGENTS.md. Use when the user passes a PR number/URL and asks for a code review, "revisar PR", "review this PR", or asks whether changes follow AGENTS.md. Checks every changed file against the rules in AGENTS.md and reports violations with file:line and the rule that was broken.
---

# AGENTS.md code review

Review changed code against **AGENTS.md at the repository root**. AGENTS.md is the single
source of truth — never review from memory of these rules, and never invent conventions that
are not written there.

## 1. Load the rules

Read `AGENTS.md` in full **before** looking at any diff. It changes often; a cached
understanding from a previous session is not valid. Keep the exact wording of each rule
available, because every finding must quote the rule it breaks.

## 2. Get the changes

**PR target** (number, URL, or branch given by the user):

```bash
gh pr view <PR> --json number,title,headRefName,baseRefName,body,url
gh pr diff <PR> --patch                 # full patch
gh pr view <PR> --json files --jq '.files[] | "\(.path) +\(.additions) -\(.deletions)"'
```

If `gh pr diff` is too large to read at once, fetch it per file:

```bash
gh pr diff <PR> --patch -- <path>
```

**No target given:** review the current branch against `main`:

```bash
git diff main...HEAD
git diff --stat main...HEAD
```

Review **every** changed file — do not sample. If a file's diff is large, read it in chunks
until you have seen all of it.

Read the surrounding file (not only the patch hunks) whenever a rule is about structure —
for example annotation position, constants at the top of a model, whether an `index` action
uses `has_scope`/`apply_scopes`/`.page`, or whether a table was split into `_table`/`_row`
partials. A hunk alone cannot prove those.

## 3. Map each changed file to the rules that apply

Use this routing table to know which AGENTS.md sections to check for each file. The table
is only a router — the authoritative text is always AGENTS.md itself.

| Changed path | AGENTS.md sections to apply |
| --- | --- |
| `app/views/**/*.html.erb` | View and Helper Patterns (I18n without `default:`, `page_header_tag`, hash value omission, Rails helpers over raw HTML, no inline styles, no classless `<div>`, no ERB state variables, no inline conditionals, `_table`/`_row` split, `shared/no_content`, `text-end` actions column, `counter_card`, `status_badge`, `responsive_actions_menu`, filter modal layout, `components/new_modal`, `remote-container` for turbo_stream modals, `col-12` + `col-lg-*`, `simple_form_for` for autocomplete, CPF/CNPJ `mask` controller) |
| `app/views/**/*.pdf.erb` | PDFs (I18n, `typst_currency`, header row fill only, `generated_at` format, no hardcoded `R$`, no engine references) |
| `app/helpers/**` | View and Helper Patterns, Charts (`content_tag` over raw HTML, palette constants, chart building in helpers) |
| `app/models/**` | Models, Database (annotation block at the **end**, constants at the top, `_cents` bigint + `Money.from_cents`, no `is_` prefix, `preload` never `includes`, scopes for filters with Arel `matches` + `sanitize_sql_like`, enums with `validate: true` + translations, AASM guard methods instead of controller `rescue`) |
| `app/models/dashboard/**` | Charts (data prepared outside the view, labels through `I18n.t`/`I18n.l`) |
| `app/controllers/**` | Controllers (`has_scope` + `apply_scopes` + `.page(params[:page])` on `index`, `authorize!`, `params.expect`, no `rescue` for expected states, `self.statuses`) |
| `app/forms/**`, any new form | Architecture (a `FooForm` class in `foo_form.rb` holds the form validations) |
| `lib/<integration>/**` | Architecture (client class pattern: `lib/xp/client.rb`, `lib/xp/companies_client.rb`) |
| `db/migrate/**`, `db/schema.rb` | Database (generated via `rails g migration`, enum column and PG type with `_type` suffix, monetary columns as `bigint` `_cents`) |
| `spec/**/*_spec.rb` | Testing Conventions (English descriptions, `context` with `let!` for persisted records, `html_table_to_rows`, `dl_to_hash`, `Model.count`, persisted-attribute checks and `.to change(Model, :count)`, mail delivery assertions, no schema annotation block) |
| `spec/factories/**` | Database (factories must never carry a schema annotation block) |
| `spec/mailers/**`, `app/mailers/**` | Testing Conventions (every new e-mail flow needs a preview in `spec/mailers/previews`) |
| `app/javascript/**` | Frontend Stack, Charts (Chart.js plugins registered once in `charts.js`, datalabels never enabled globally) |
| `config/locales/**` | View and Helper Patterns (translations must exist for every `t()` key added, enums translated under `enums.<model>.<column>`) |
| any file | Code Style (no `# rubocop:disable` / `# rubocop:todo`), and **no comments added to any file** unless the PR description says they were requested |

Cross-file checks that are easy to miss:

- Every new `t('.key')` in a view/PDF must have a matching entry in `config/locales/**`. Grep for it.
- A new enum needs both the migration (`create_enum` with `_type`), the model declaration
  (`validate: true`) and the locale entries under `enums.<model>.<column>`.
- A new listing screen needs the controller scopes **and** the `_table`/`_row` partials **and**
  the `shared/no_content` fallback — flag whichever piece is missing.
- A new destroy menu item must carry `turbo_confirm` **and** `turbo_method: :delete`.

## 4. Verify before reporting

Every finding must survive this check, or it is dropped:

1. **The rule exists.** Point at the AGENTS.md line that says it. No rule, no finding.
2. **The code really violates it.** Re-read the actual file in the repo, not just the patch.
   Confirm the helper/partial/locale key genuinely is absent — grep for it.
3. **The PR introduced it.** Pre-existing code that the PR only moved or touched nearby is not
   a finding; mention it at most as a note.
4. **It is not already correct elsewhere.** E.g. a translation may live in a shared scope.

Prefer fewer, certain findings over a long list of guesses. A false positive costs more than a
miss.

## 5. Report

Answer in the language the user wrote in (Portuguese if they wrote in Portuguese). Structure:

```
## Revisão de PR #<n> — <title>

<one-line verdict: aprovado / aprovado com ressalvas / requer ajustes>

### Violações de AGENTS.md

**1. <short title>** — `app/views/foo/index.html.erb:42`
> Regra (AGENTS.md): "<exact quote>"

<what the code does, and the concrete fix — with the corrected snippet when short>

### Observações (não bloqueiam)

- ...

### Conforme AGENTS.md

- <rules that were relevant and correctly followed, one line each>
```

Order findings by severity: rules stated with **must**/**never**/**NEVER** first, then the
remaining conventions, then non-blocking notes. Always include the "Conforme" section — it
shows which rules were actually checked.

Do not run the test suite or linters as part of this review unless the user asks; this is a
conventions review. If you do want to confirm a lint-related finding, the commands are in the
AGENTS.md "Development Commands" section.

## 6. Optional actions

Only when the user explicitly asks:

- **Post the review on the PR:** `gh pr comment <PR> --body-file <file>` — write the body to a
  file in the scratchpad first and show it to the user before posting.
- **Fix the findings:** apply the corrections to the working tree, respecting AGENTS.md
  (notably: never add comments, never add `# rubocop:disable`).
