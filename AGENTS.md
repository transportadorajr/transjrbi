# AGENTS.md

This file provides guidance to AI agents when working with code in this repository.

This file must always be written in English — every section heading and every instruction — even when the request that motivated the change was made in another language. Only user-facing strings quoted from the app (locale values, UI copy) may appear in Portuguese.

## Project Overview

A River project is a SaaS, when resolve companies problems, like a schedule work, sales and a charge's rules to our customers. But the system is focused on Business Inteligence of our customers. Our customers are a small and medium companies, and, our customers are not invest on business for their companies, so, we come to their realities to change their mind to inteligence about your business. We don't want change the product or deprecate their products or services, we want transform the company to them gonna be take more money and have a better sales.

## Development Commands

### Full Build & Test Suite
```bash
script/build  # Runs all linters and tests
```

### Development Server
```bash
./bin/dev  # Starts Rails, CSS/JS watchers, GoodJob workers, and Sinatra mock server
```

### Individual Commands
```bash
# Testing
bundle exec rspec spec/path/to/spec.rb              # Run single spec
bundle exec rspec spec/path/to/spec.rb:42           # Run spec at line

# Linting
bundle exec rubocop                    # Ruby linting
bundle exec rubocop -A                 # Auto-fix Ruby issues
bun run prettier -c app/javascript     # Check JS formatting
bun test                               # JavaScript unit tests (spec/javascript, happy-dom)
bundle exec erb_lint --lint-all        # ERB template linting
bundle exec herb analyze app/views     # Herb ERB analyzer

# Security
bundle exec brakeman -q -w2            # Security scanner
bundle exec bundle audit --update      # Dependency vulnerabilities

# Assets
bun run build:css                      # Compile and prefix CSS
bun run build                          # Build JavaScript

# When you need a new database migration (never create migration files manually):
bundle exec rails g migration ...
```

## Architecture

- Every form on HTML when need have a FormO bject class, default name is a object name + form. Example: form to add user, must be named UserForm and file user_form.rb. Form object will be has the form validations.

- Every APIs integrations, if don't have gems to integrate, we write a Client class. Will be create a folder with the integration's name. Ex: We are integrate with XP Investimentos, a brazilian platform to invest our money, the pattern is a foldername xp, and client class is a client.rb. Example of a basic structure is on project: river/lib/xp/client.rb. If we have other client for the same company integration, only we have diferent preffix with the client sufix, ex: river/lib/xp/companies_client.rb

### Commands

- Every class that executes a task — anything that is not a model, a form object or an API client — is a **Command**. Do not create service classes (`app/services`, `*Service`); we use commands instead.

- Commands live in `app/command/`, namespaced by the context they act on, and the class name always carries the `Command` suffix. The file name mirrors the class with the `_command` suffix:

  ```ruby
  # app/command/tenants/provisioning_command.rb — Tenants::ProvisioningCommand
  module Tenants
    class ProvisioningCommand
      class << self
        def call(tenant)
          new(tenant).call
        end
      end

      def initialize(tenant)
        @tenant = tenant
      end

      def call
        # the task
      end

      private

      attr_reader :tenant
    end
  end
  ```

- A command exposes a `call` class method that instantiates and runs it, so callers always write `Tenants::ProvisioningCommand.call(tenant)`.

- Commands must be idempotent whenever they can be triggered more than once (a callback plus a manual re-run, a backfill, a retried job). Check for the work already being done and return the existing result instead of duplicating it.

- Specs mirror the directory: `spec/command/tenants/provisioning_command_spec.rb`.

### Frontend Stack

- Hotwire (Turbo + Stimulus) for interactivity
- Bootstrap 5 for styling
- Bun for JavaScript bundling
- SCSS with PostCSS/Autoprefixer
- Chartkick (backed by Chart.js) for charts, with Groupdate for the time-series grouping

### Charts

- Charts are rendered with the Chartkick view helpers (`column_chart`, `pie_chart`, …). Never call them straight from a template: build the chart in a helper method so colors, height, and Chart.js options stay out of the views. See `app/helpers/home_helper.rb`.
- Chart data must be prepared outside the view as well — a dashboard object under `app/models/dashboard/` receives an already-scoped relation and returns ready-to-plot hashes (see `app/models/dashboard/sales.rb`). Labels inside these hashes are user-facing, so they go through `I18n.t`/`I18n.l` like any other string.
- Chart.js plugins are registered once in `app/javascript/charts.js`. `chartjs-plugin-datalabels` is registered there but disabled by default (`Chart.defaults.plugins.datalabels.display = false`); a chart opts in through its own `library: { plugins: { datalabels: { display: ... } } }`. Never enable it globally — a number on every bar of a time series is noise.
- Series colors come from the palette constants at the top of the chart helper, never inline hex in a template. A single-series chart uses the brand blue; an ordinal breakdown (time windows) uses one blue ramp from darkest (most recent) to lightest; a categorical breakdown uses blue/orange, which stays readable for colorblind users.
- Chartkick applies 50% opacity to non-stacked bar fills. When a solid bar is wanted, set it explicitly via `dataset: { backgroundColor: ... }`.

## Testing Conventions

- **Never write controller specs or request specs.** The project has no `spec/controllers` and no `spec/requests` directory, and no spec may be tagged `type: :controller` or `type: :request`. Controller behaviour is covered through the screens that reach it. The suite is made of four kinds of specs only:
  - **End-to-end specs** (`spec/features/`): the whole stack driven by Capybara, the way a user reaches it — navigation, forms, permissions, turbo updates, PDF exports and multi-tenant isolation.
  - **Unit specs** (`spec/models/`, `spec/forms/`, `spec/command/`, `spec/helpers/`, `spec/lib/`, `spec/mailers/`, `spec/db/`, `spec/migrations/`): a single class in isolation — validations, scopes, calculations, state transitions and error messages. Every model, form object and command must be covered by one — an abstract base class through the specs of its subclasses.
  - **JavaScript unit specs** (`spec/javascript/`, `*.test.js`): a Stimulus controller or a plain JS module in isolation, run by `bun test` on top of happy-dom (`bunfig.toml` preloads `spec/javascript/setup.js`). Mount the controller on a fixture DOM, drive it through clicks and value changes, and stub the Turbo/network edges (`window.Turbo`, `turbo:frame-load`) instead of reaching Rails.
  - **Regression specs**: every bug fix ships with a spec that fails without the fix, written as an end-to-end spec when the bug is visible on a screen and as a unit spec when it lives inside a class. Name the example after the behaviour that broke, never after the ticket.
- Behaviour that has no visible control on a screen (a status code, a redirect, a turbo stream, a route that must not exist) is still covered end-to-end from a feature spec, using the Capybara driver directly instead of a request spec:
  ```ruby
  page.driver.submit :delete, customer_path(customer), {}      # non-GET actions
  page.driver.header('Accept', 'text/vnd.turbo-stream.html')   # turbo stream responses
  expect(page.status_code).to eq(404)
  expect(page.response_headers['Content-Disposition']).to include('inline')
  ```
- Assert a PDF export from a feature spec by visiting the `.pdf` path and reading the text of the generated document with `PDF::Inspector::Text.analyze(page.body).strings.join`.
- Do not add comments to any file unless explicitly requested via prompt. This applies to all file types (Ruby, JS, ERB, etc.).
- Whenever a feature flag needs to be enabled in a test, add it to the test metadata after the description using `flipper: :feature_name` to indicate that the feature flag is enabled for that test.
- Write `context`, `scenario` and `it` descriptions in English.
- Prefer organizing feature specs with `context` blocks that create the factories needed for that scenario before defining the examples.
- When a test scenario depends on persisted records (for example, `create(:tenant)`), create these records outside the `scenario` block, preferably inside a dedicated `context` using `let!` (or `before`) and keep a test variable for reuse in the scenario.
- When validating data rendered in HTML tables, prefer using `html_table_to_rows` to assert the listed rows instead of relying only on generic page text checks. Always check the content using `expect(html_table_to_rows).to eq(....)`.
- When validating data rendered in HTML dt, dl and dd, prefer using `dl_to_hash` to assert the listed items instead of relying only on generic page text checks. Always check the content using `expect(dl_to_hash).to eq(....)`.
- Every new e-mail flow must include a mailer preview in `spec/mailers/previews`.
- In tests that trigger e-mail sending, always assert whether the e-mail was sent or not (for example, checking `ActionMailer::Base.deliveries.count` changes).
- When testing listing screens, always verify the total count of records in the database matches the number of records created in the test context. Use `Model.count` or `expect(Model.count).to eq(N)` alongside `html_table_to_rows` assertions.
- When testing the show screen of a record, use `dl_to_hash` to verify every attribute displayed matches the value stored in the database for that record.
- In all create and edit scenarios, after a successful form submission always verify the persisted record's attributes in the database (e.g., `record = Model.last; expect(record.field).to eq(value)`) and check the count change (e.g., `.to change(Model, :count).by(1)`).

## View and Helper Patterns

- Whenever the property name being passed to a render (or any method) is the same as the local variable name, use the hash value omission syntax. This format is not valid if the passed variable is an instance variable.
  ```erb
  <%# Correct %>
  <%= render 'row', foo: %>
  <%= render 'row', foo: @foo %>

  <%# Wrong %>
  <%= render 'row', foo: foo %>
  ```

- Do not use plain text in Portuguese (or any language) directly in the views or application code for labels, placeholders, or any user-facing text. Always use the internationalization files and fetch them via `t()` (I18n) or `Model.human_attribute_name(:attribute)`.
- **NEVER USE the `default:` parameter in an I18n `t()` call! We already have `.yml` files for this. Always properly define the translations in the locale files.**

- Regarding icons, always call the `icons(:name_icon)` helper method. If the icon name contains dashes, use `icon(:'name-icon')`.

- Every page title (the `page-header`/`page-title` markup at the top of a screen) must be rendered through the `page_header_tag` helper (`app/helpers/application_helper.rb`) instead of hand-rolled HTML. This applies to **every** screen — `index`, `show`, `new`, and `edit` alike — with no exceptions. Never write a raw `<h1 class="page-title">` outside of the helper: the `.page-title` CSS rule is scoped as `.page-header .page-title`, so a hand-rolled `h1.page-title` without the `.page-header` wrapper silently falls back to Bootstrap's default heading styles (larger, lighter weight) instead of the app's title style. This keeps the title structure consistent across screens and avoids drift when the markup needs to change. Pass a block for `page-actions` buttons/links, `subtitle:` for a secondary line under the title, and `back_path:`/`back_title:` when the header needs a back button (typically on `show`/`edit`/`new` pages with a breadcrumb). Example usage:
  ```erb
  <%# Simple title, no actions %>
  <%= page_header_tag t('.title') %>

  <%# Title with actions %>
  <%= page_header_tag t('.title') do %>
    <%= link_to_filters('#filtersModal', class: 'btn btn-outline-secondary') %>
    <%= create_button(t('.new_feature')) %>
  <% end %>

  <%# Show page with breadcrumb + back button %>
  <%= page_header_tag @feature.name, back_path: features_path, back_title: t('.back'), wrapper_class: 'mb-0' do %>
    <%= link_to edit_feature_path(@feature), class: 'btn btn-outline-secondary' do %>
      <%= icon(:pencil, class: 'me-2') %>
      <%= t('shared.edit') %>
    <% end %>
  <% end %>
  ```

- The "add" button of a screen must always be rendered through the `create_button` helper (`app/helpers/application_helper.rb`) instead of a hand-written `link_to` with the `plus-circle` icon. It only takes the title; the path defaults to `new_<controller>_path`, and a second argument overrides it when the route does not follow that convention:
  ```erb
  <%# Correct %>
  <%= create_button(t('.new_feature')) %>
  <%= create_button(t('.new_feature'), new_account_feature_path(@account)) %>

  <%# Wrong %>
  <%= link_to new_feature_path, class: 'btn btn-primary btn-primary-action btn-round' do %>
    <%= icon(:'plus-circle', class: 'me-2') %>
    <%= t('.new_feature') %>
  <% end %>
  ```

- Always prefer Rails view helpers over raw HTML tags. Use `link_to` instead of `<a>`, `button_tag` instead of `<button>`, `content_tag` instead of manually writing HTML tags in helpers. This keeps views consistent and idiomatic Rails. Example:
  ```erb
  <%# Correct %>
  <%= link_to t('.label'), some_path, class: 'page-link' %>

  <%# Wrong %>
  <a href="<%= some_path %>" class="page-link"><%= t('.label') %></a>
  ```

- Do not create local ERB state variables inside view templates for control flow or presentation state. Do not assign instance variables or calculate state directly in the views (e.g., `<% @active_count = ... %>` or `<% active_count = ... %>`). Always calculate these values in the controller and pass them as instance variables. Keep complex presentation logic in helpers, form objects, presenters, and controllers.

- Whenever a view needs conditional logic (`if`/`else`, `case`/`when`, ternaries used to branch business rules) to decide what to display, never write it inline in the template. Extract it into a helper method and call that method from the view instead. This keeps the view layer free of business rules and readable as pure presentation.
- Whenever adding a table to list records in the system, follow this structure.
- In `index.html.erb`, compare the related collection and, when records exist, render `_table.html.erb`, passing the collection to that partial.
- Split the table into dedicated partials:
  `'_table.html.erb'`: contains the full table structure, including the `<table>` tag.
  `'_row.html.erb'`: contains the row content rendered inside `<tbody>`.
- In `index.html.erb`, use `@collection.any?` to decide whether to render the table partial. If the collection is empty, render `<%= render 'shared/no_content' %>`.
- `_table.html.erb` must be responsible for rendering the collection rows by calling `_row.html.erb`. Always use `Model.human_attribute_name(:attribute)` for table column headers when the table is linked to a model collection.
- `_row.html.erb` must receive a single collection item and render the table row for that item.
- If the table has selection menus for edit, delete, or any other action, use the `responsive_actions_menu` class, passing to it a helper method responsible for returning the menu items.
- Create a helper for this functionality when one does not already exist. Follow this structure:

```ruby
module FeatureNameHelper
  def feature_name_menu(feature_name)
    menus = []

    # Always verify permissions before adding a menu item
    menus << feature_name_show_menu(feature_name) if can?(:read, feature_name)
    menus << feature_name_edit_menu(feature_name) if can?(:update, feature_name)
    menus << feature_name_destroy_menu(feature_name) if can?(:destroy, feature_name)

    menus
  end

  private

  def feature_name_edit_menu(feature_name)
    Menu.new(name: :edit, record: feature_name, url: feature_name_path(feature_name.id), icon: :pencil)
  end

  def feature_name_destroy_menu(feature_name)
    Menu.new(
      name: :destroy,
      record: feature_name,
      url: feature_name_path(feature_name.id),
      icon: :'x-circle',
      data: {
        turbo_confirm: t('feature_name.index.confirm_destroy'),
        turbo_method: :delete,
      },
    )
  end
end
```

- Every destroy action menu item **must** include `data: { turbo_confirm: t('...confirm_destroy'), turbo_method: :delete }`. This ensures the user is always prompted before any deletion. Never omit `turbo_confirm` from a destroy menu.
- Use other views in this pattern to development a new view.
- Use this pattern for every screen that has options/actions in listing tables, because it keeps the UI responsive for both web and mobile.

- The last column of every listing table (the actions column) must always be right-aligned. Set `class: "text-end"` on both the `<th>` and `<td>` of the actions column.

- Whenever a listing screen requires filters, use a Bootstrap Modal. The modal is rendered via a `_filters.html.erb` partial. Add a filter button using the `link_to_filters` helper (which renders a funnel icon) with `btn-outline-secondary` style, positioned to the left of the insert/new button. The modal must contain a `form_with` that submits a GET request to the index action, passing the filter parameters. For status select fields in filters, always use `Model.statuses` to populate the options (e.g., `Passport.statuses`). All filter modals must follow the standardized layout:
  - Use `modal-header border-bottom-0 pb-0` with an `h5` title and the `filter` icon.
  - Action buttons (Apply/Clear) must be located inside the `modal-body` at the bottom, using a `d-flex flex-column gap-2 mt-4` container.
  - Input fields should use `bg-light` class for better contrast.
  - Labels should use `fw-medium` class for consistency.

- When formatting CPF and CNPJ input fields, always use the Stimulus `mask` controller with the specific patterns. The standard implementation is: `data: { controller: 'mask', mask_pattern_value: %w[000.000.000-00 00.000.000/0000-00] }`. Do not use arbitrary string masks like `mask: 'cpf_cnpj'`. When the field only accepts a CPF (e.g. a driver's `legal_id`, validated as CPF by its form object), use the CPF pattern alone: `mask_pattern_value: %w[000.000.000-00]`.

- Do not use inline styles (`style="..."`) in view templates or helpers. Always prefer using Bootstrap classes (e.g. `d-none` instead of `display: none`, grid classes for widths). If a custom style is needed that cannot be achieved with Bootstrap utilities, define it in a stylesheet file.

- Do not use plain `<div>` tags without classes in view templates. If a `<div>` does not require a class for styling or layout (like Bootstrap grid or utility classes), it likely shouldn't exist.

- The form that uses the autocomplete component must always be a `simple_form_for`. Do not use `form_with` directly when you need an autocomplete field. Example: `<%= f.input :customer_id, as: :autocomplete, collection: @customers %>`

- Whenever a listing screen includes summary statistics (count cards) at the top, always use the `counter_card` helper method. This ensures consistent styling, colors, and layout across the platform. The helper accepts a Bootstrap theme type, a label, and a value.
  - Use `success` for active records.
  - Use `danger` for inactive/deactivated records.
  - Use `dark` for total/general counts.
  - All card elements (border, label, and value) will automatically use the themed color.

  Example usage:
  ```erb
  <div class="row g-3 mb-4">
    <%= counter_card(:dark, t('.total'), @collection.size) %>
    <%= counter_card(:success, t('.active'), @active_count) %>
    <%= counter_card(:danger, t('.inactive'), @inactive_count) %>
  </div>
  ```

- Totalizer cards (e.g., `totalizer_card` or sum aggregations) must always be placed at the bottom of the page content (e.g., below the main list or table) when requested, so users can view the totals after the listed items.

- Whenever displaying a status badge in a listing table (like active/inactive/invited states), always use the `status_badge` helper method. It expects the translated status text and a Bootstrap theme type (`:success`, `:danger`, `:warning`, etc.).
  
  Example usage:
  ```erb
  <% if item.active? %>
    <%= status_badge(t('.active'), kind: :success) %>
  <% else %>
    <%= status_badge(t('.deactivated'), kind: :danger) %>
  <% end %>
  ```

- In all forms, fields must stack vertically (one below the other) on mobile and iPad screens. To achieve this, always use `col-12` as the base grid class and apply `lg` breakpoints (e.g., `col-lg-4`, `col-lg-6`) for horizontal layouts on larger screens. The specific grid layout for web (desktop) views is up to the software engineer implementing the feature.

- Modals injected dynamically via `turbo_stream` (e.g. `turbo_stream.update` from a controller action) must always target the `remote-container` div declared in `app/views/layouts/application.html.erb`, never a page-local container (e.g. an empty `<div id="modals"></div>` inside a specific view). `remote-container` sits as a direct sibling at the body level, so the modal's fixed positioning and backdrop aren't broken by an ancestor with `overflow`/`transform` inside the page content. Do not create per-page modal mount points; reuse `remote-container` instead. Prefer `turbo_stream.update` over `append`/`replace` for this target, so a repeated response (e.g. a re-submitted validation error) swaps the modal in place instead of stacking duplicate elements.

- Every modal (static or injected via `turbo_stream`) must be built with the `components/new_modal` layout partial (`app/views/components/_new_modal.html.erb`) instead of hand-rolled `modal fade`/`modal-dialog`/`modal-content` markup. It already wires up the shared Stimulus `modal` controller, the header/close button, and an optional footer, so individual features never need to write their own JS to open or close a modal. Usage:
  ```erb
  <%= render layout: 'components/new_modal',
             locals: { id: 'my_modal', title: t('.title'), auto_show: true, show_footer: false } do %>
    modal body content
  <% end %>
  ```
  - Pass `auto_show: true` when the modal is injected via `turbo_stream` and must open as soon as it's rendered (this sets `data-modal-auto-show-value`, read by the `modal` Stimulus controller's `connect()` — no bespoke controller needed). Leave it `false`/omitted for modals that already sit in the page and are opened via a trigger (`data-bs-toggle="modal" data-bs-target="#my_modal"`).
  - Closing is handled by Bootstrap's native `data-bs-dismiss="modal"` data-api (already loaded globally in `app/javascript/application.js`); don't write a controller action for it.
  - Use `show_footer: false` when the modal's action buttons live inside its own form (as with `estimate_items/_missing_customer_modal.html.erb`); otherwise the component renders a default footer with a Cancel button. To render custom footer content instead, wrap it in `content_for :footer do ... end` inside the block — the partial exposes it via `yield :footer`.
  - See `app/views/estimate_items/_missing_customer_modal.html.erb` and `app/views/estimate_items/missing_customer.turbo_stream.erb` for a full reference implementation (`turbo_stream.update` + `auto_show: true`).

## Admin Namespace

The application is served from two subdomains, both derived from `config.x.domain` in `config/application.rb`:

- `River::APP_SUBDOMAIN` (`app`) — the product used by our customers, reachable at `config.x.app_host`.
- `River::ADMIN_SUBDOMAIN` (`admin`) — the internal back office, reachable at `config.x.admin_host`.

Each subdomain gets its own `constraints subdomain: ...` block in `config/routes.rb`, and the admin block wraps a `namespace :admin, path: '/'` so the back office lives at the root of its own subdomain (`admin.<domain>/`, `admin.<domain>/login`, …). Both hosts are whitelisted in `config.hosts` (`config/environments/production.rb`); locally they resolve through `app.localhost` / `admin.localhost` with no extra setup.

On the VPS the two hosts also have to exist in the nginx layer: `on_premise/install` resolves a Let's Encrypt certificate for each subdomain (issuing one via certbot when none covers it) and writes a `server` block per host into `nginx/nginx.conf`. Anything not listed there falls into the `default_server` block and gets `return 444`, so a new subdomain needs both its DNS record pointing at the VPS and its own block in the generated config — the certificates are independent, and a missing `admin.` DNS record leaves the app untouched.

### Naming Convention

Everything that belongs to the admin domain is namespaced twice — in the database and in Ruby:

- **Tables** carry the `admin_` prefix: `admin_users`, `admin_sessions`, `admin_resources`.
- **Models** live under the `Admin::` namespace in `app/models/admin/`: `Admin::User`, `Admin::Session`, `Admin::Resource`.

The prefix is wired up by `Admin.table_name_prefix` (`app/models/admin.rb`), so a namespaced model maps to the prefixed table without any `self.table_name` override:

```ruby
# db/migrate/*_create_admin_users.rb
class CreateAdminUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :admin_users do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.string :password_digest, null: false

      t.timestamps
    end

    add_index :admin_users, :email, unique: true
  end
end

# app/models/admin/user.rb — maps to admin_users
module Admin
  class User < ApplicationRecord
    has_secure_password
  end
end
```

Controllers, views, forms and specs follow the same namespace: `app/controllers/admin/`, `app/views/admin/`, `app/forms/admin/`, `spec/features/admin/`, `spec/forms/admin/`, `spec/models/admin/`.

### Authentication

The admin area has its own authentication, fully independent from the customer app — an `App` login never grants access to `Admin`, and vice versa. Devise is **only** used by `User` (the app side); the admin side is database-backed:

- `Admin::User` uses `has_secure_password`. There is no public sign up and no password recovery: admin users are created manually through the console or `db/seeds.rb` (guarded by the `ADMIN_USER_EMAIL` / `ADMIN_USER_PASSWORD` env vars).
- `Admin::Session` is a real record (`admin_sessions`) holding the session `token`, the request metadata and `last_active_at`. The token is stored in the Rails session cookie under `Admin::Authentication::SESSION_TOKEN_KEY`.
- Sessions expire after `Admin::Session::INACTIVITY_TIMEOUT` (30 minutes) without activity; every authenticated request calls `renew` and pushes the timer forward.
- `Admin::Authentication` (`app/controllers/concerns/admin/authentication.rb`) exposes `current_admin_user`, `sign_in_admin_user` and `sign_out_admin_user`.
- Every admin controller inherits from `Admin::BaseController`, which includes the concern, enforces the timeout and sets `Current.admin_user`. Only `Admin::SessionsController` (the `/login` screen) inherits from `ApplicationController` directly.

There is no granular authorization in the admin area yet: any authenticated `Admin::User` sees every admin screen. Do not introduce CanCan abilities there without an explicit request.

### Navigation

The admin sidebar reuses the same `Menu`/`config/menu.yml` pattern as the app. Admin entries live under the `shared.admin` key and are rendered with `Menu.find_and_wrap(:admin)` from `app/views/layouts/_admin_aside.html.erb`. Admin screens use the `admin` layout (`app/views/layouts/admin.html.erb`); the `/login` screen uses `bare`, like the app login.

### Specs

Tag an admin feature spec with the `:admin` metadata so it runs against the admin host — `spec/support/capybara.rb` swaps `Capybara.app_host` for the tagged examples:

```ruby
RSpec.describe 'Admin authentication', :admin do
  # ...
end
```

## Models

- The `# == Schema Information` annotation block (generated by `annotaterb`) must always be placed at the **end** of the file, after a blank line following the last line of code — never at the top. This applies only to models (`app/models`). Factories (`spec/factories`) and specs (`spec/**/*_spec.rb`) must not carry the annotation block at all: they are test support/test classes and don't need the schema documentation.

- Always keep constants in Models at the top of the file, right after any include/extend statements or class declarations, to improve readability and avoid scattering constants.

- Always create monetary fields in the database as `bigint` with a `_cents` suffix (e.g., `price_cents`). When manually initializing a Money object from these fields, always use `Money.from_cents` (e.g., `Money.from_cents(value)`).

- Do not use the `is_` prefix for boolean columns, methods, or variables (e.g., prefer `active` over `is_active`, `default` over `is_default`). In Ruby, boolean methods automatically use the `?` convention (e.g., `active?`), making the `is_` prefix redundant and contrary to Rails conventions.

- Never use `includes` to eager load associations. Always use `preload` instead. We avoid `includes` because its automatic strategy selection (join vs. separate query) can produce unpredictable behavior; `preload` is explicit and always issues separate queries.

Whenever we need to create specific filters for a listing, we define them as named scopes in the model. Scopes keep filter logic encapsulated, reusable, and easy to test independently of the controller.

```ruby
class Feature < ApplicationRecord
  # Use Arel `matches` for case-insensitive text search (ILIKE).
  # Always wrap with `sanitize_sql_like` to prevent injection via LIKE wildcards.
  scope :by_name, ->(name) { where(arel_table[:name].matches("%#{sanitize_sql_like(name)}%")) }
end
```

## Database

- Every enum created in the database must have the `_type` suffix. This applies both to the column that holds the enum and to the PostgreSQL enum type backing it, so the column reads as a type discriminator and stays consistent with the existing ones (`user_type`, `estimates_owner_type`, `name_type`).

  ```ruby
  class CreateSalesConfigurations < ActiveRecord::Migration[8.0]
    def change
      create_enum :sales_configuration_name_type, %w[treatment work_order sale]

      create_table :sales_configurations do |t|
        t.references :tenant, null: false, foreign_key: true, index: { unique: true }
        t.enum :name_type, enum_type: :sales_configuration_name_type, null: false, default: 'sale'

        t.timestamps
      end
    end
  end
  ```

- Never create migration files manually — always generate them with `bundle exec rails g migration ...`.

- The schema information block (`# == Schema Information`) is generated automatically by the `annotaterb` gem and **must always sit at the end of the file, never at the top**. This applies to models (`app/models/**`) only. Never write or move these blocks by hand: they are produced by `db:migrate` (the `lib/tasks/annotate_rb.rake` hook runs `annotaterb models` after every migration) and configured in `.annotaterb.yml` via `:position*: after`. If an annotation looks stale or misplaced, regenerate it with `bundle exec annotaterb models` instead of editing the comment.

- Factories (`spec/factories/**`) must **never** carry a schema information block — a factory is test support code and does not need the table definition duplicated in it. This is enforced by `:exclude_factories: true` in `.annotaterb.yml`; do not add these comments to factories manually, and delete them if a merge or an older branch brings them back.

- Spec files (`spec/**/*_spec.rb`) must **never** carry a schema information block — a test class does not need the table definition. This is enforced by `:exclude_tests: true` in `.annotaterb.yml`; do not add these comments to specs manually.

- Every enum must be declared in the model with `validate: true` (or `validate: { allow_nil: true }` when the column is nullable) and have its values translated under the `enums.<model>.<column>` scope in the locale files, never rendered raw in a view.

## Code Style

- **NEVER use `# rubocop:disable` (or `# rubocop:todo`) comments to silence an offense.** A disable comment is not a fix — it hides a real problem and leaves the codebase inconsistent. When RuboCop reports an offense, rewrite the code so the cop passes. Examples of the expected fixes instead of a disable:
  - `Rails/StrongParametersExpect` → use `params.expect(...)` instead of `params.require(...).permit(...)`, with the double-array syntax for nested attributes: `params.expect(sale: [:customer_id, { sale_items_attributes: [%i[id owner_id _destroy]] }])`.
  - `Naming/PredicateMethod` / `Naming/PredicatePrefix` → rename the method or change what it returns (see the AASM guard pattern in the Controllers section) so it follows the Ruby convention.
  - `Rails/OutputSafety` → build the markup with `content_tag`/`safe_join`/`sanitize` instead of `html_safe`.
  - Metrics cops (`AbcSize`, `MethodLength`, `ClassLength`) → extract private methods, a form object, a helper, or a presenter.
  If a cop genuinely does not fit this project, the correct action is to configure it in `.rubocop.yml` (with the exclusion or option that expresses the rule), never to scatter inline disables across the code.

## Controllers

- Every controller of the app **must** inherit from `BaseController` (`app/controllers/base_controller.rb`), never from `ApplicationController` directly. `BaseController` inherits from `ApplicationController` and runs the `require_signed_in_user` `before_action`: a signed-in user goes on to the requested screen, and a visitor without a session is redirected to the login screen (`new_user_session_path`). The only controllers that keep inheriting from `ApplicationController` are the ones that must be reachable without a session — the Devise controllers (login), which already redirect a signed-in user to the home page, and `Admin::SessionsController`. Do not skip the authentication with `skip_before_action` to make a screen public without an explicit request.

Every `index` action that lists a collection **must** declare scopes with `has_scope`, apply them with `apply_scopes`, and paginate with `.page(params[:page])`. This is the standard pattern for all listing screens. Deviation from this only when explicitly requested.

```ruby
# Controller — declare scopes with has_scope, then apply + paginate in index
class FeaturesController < BaseController
  has_scope :by_name, as: :name

  def index
    authorize!(:read, Feature)

    @features = apply_scopes(current_tenant.features).page(params[:page])
  end
end
```

- Always chain `apply_scopes` before `.page()` so Kaminari paginates the already-filtered relation.
- For text searches with case-insensitive matching (ILIKE), always use Arel `matches` instead of raw SQL. Always wrap with `sanitize_sql_like` to prevent injection via LIKE wildcards.
- For models that have status-like fields used in select dropdowns, define a `self.statuses` class method that returns a hash mapping human-readable names (via I18n) to internal keys. This is the standard pattern for populating select fields in views.

- Do not `rescue` expected/known failure states (e.g. an AASM `InvalidTransition` because a record is already in the target state) directly in a controller action. Instead, add a guard method to the model (e.g. `validate_finish`, `validate_approve`) that checks the relevant AASM state predicate, adds an `errors.add(:base, ...)` and returns (bare `return`, no explicit boolean) when the action isn't allowed, or fires the event and returns its result otherwise. Never write `return true` / `return false` (or any branch that always returns a literal boolean) to make this pattern work — that trips `Naming/PredicateMethod` and only invites a `# rubocop:disable` you don't need; rely on the AASM event call's own truthy return and an implicit `nil` from the early `return` instead. The controller then branches on that value and reads `record.errors.full_messages.to_sentence` for the alert message, the same way form objects are handled — no `rescue` involved. Only use `rescue` in a controller action when explicitly requested, or for truly exceptional/unexpected errors (e.g. an external error class raised by a collaborator, like `Estimate::MissingCustomerError`) that don't fit the errors-on-the-model pattern.

  ```ruby
  # Model
  class Sale < ApplicationRecord
    def validate_finish(finished_by)
      if finished?
        errors.add(:base, :already_finished, message: I18n.t('sales.errors.already_finished'))
        return
      end

      finish!(finished_by)
    end
  end

  # Controller
  def finish
    authorize!(:finish_sale, :sale)

    if @sale.validate_finish(current_user)
      redirect_to sale_path(@sale), notice: t('.success')
    else
      redirect_to sale_path(@sale), alert: @sale.errors.full_messages.to_sentence
    end
  end
  ```

## PDFs

- The markup is compiled by `rust_typst_pdf`, a Rust binary that embeds Typst as a library and reads the markup from STDIN. It is **not** versioned: `bin/setup` compiles it into `bin/rust_typst_pdf` for development, and each Docker image compiles its own in the `typst-builder` stage. Never commit the binary — a macOS build cannot run in the Linux image. Templates are self-contained, so the compiler has no file system access: `#image(...)` and Typst packages are refused by design.

- PDF templates are `.pdf.erb` files that generate Typst markup. They follow the same I18n rules as HTML views — never use plain text directly; always use `t()` or `Model.human_attribute_name`.

- The PDF page header must **never** contain the raw label of the document (e.g., "Orçamento - River" is not acceptable as a standalone header label). Use a descriptive report title like `Relatório de Orçamento - River`.

- In PDF listing tables, only the **header row** should have a background color. Data rows must have no background fill. The correct Typst pattern is:
  ```
  fill: (col, row) => if row == 0 { rgb("#1a2a3a") } else { none },
  ```
  This rule applies to **all** PDF files in the project.

- The `generated_at` footer line must follow the same format as `index.pdf.erb`: `Gerado em %{time}.` — without any engine or technology references (e.g., do **not** include "via Rust/Typst Engine" or similar).

- Never hardcode a currency symbol (e.g. `R$`) in a PDF template. Always format monetary values with the `typst_currency` helper (`app/helpers/application_helper.rb`), which wraps Rails' `number_to_currency` so the symbol/format follow the active I18n locale. Because Typst uses `$` to enter math mode, `typst_currency` escapes the symbol (`\$`) — never interpolate `number_to_currency` directly into a `.pdf.erb` template.

- All PDF templates (`.pdf.erb`) must be internationalized like any other view: never inline plain-text labels, always use `t()`/`Model.human_attribute_name`, and format numbers/currency/dates through locale-aware helpers rather than hardcoded formats.
