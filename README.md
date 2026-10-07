# TransJRBI

Aplicação Ruby on Rails com Stimulus e Bootstrap.

## Stack

| Item | Versão / ferramenta |
|---|---|
| Ruby | 4.0.7 (`.ruby-version`) |
| Rails | 8.1.x |
| Banco de dados | PostgreSQL 18 |
| JavaScript | Bun (pacotes **e** bundler) · Turbo · Stimulus |
| CSS | Bootstrap 5.3 (pacote JS via Bun, compilado com Sass) · Bootstrap Icons |
| Jobs em segundo plano | GoodJob |
| Autenticação | Devise 5 (+ devise-i18n, pt-BR) |
| E-mail em desenvolvimento | Mailpit |

Não há importmap: todas as bibliotecas JavaScript ficam no `package.json` e são instaladas com `bun install`.

## Requisitos

- Docker (Docker Desktop no macOS/Windows)
- VS Code com a extensão **Dev Containers** (recomendado)

Não é preciso instalar Ruby, Bun ou PostgreSQL na sua máquina.

## Como rodar

### Opção 1: Dev Container (recomendado)

1. Abra a pasta do projeto no VS Code.
2. Execute **Dev Containers: Reopen in Container**.
   Na primeira vez, o `bin/setup` instala as gems, roda `bun install` e prepara o banco.
3. No terminal do VS Code (já dentro do container):

   ```bash
   bin/dev
   ```

### Opção 2: apenas Docker Compose

```bash
docker compose up
```

O serviço `app` roda `bin/setup` (dependências e banco) e em seguida `bin/dev`.

### Endereços

| Serviço | URL |
|---|---|
| Aplicação | http://localhost:3000 |
| Mailpit (e-mails locais) | http://localhost:8025 |
| Dashboard do GoodJob (requer login) | http://localhost:3000/good_job |

## Processos do `bin/dev` (`Procfile.dev`)

| Processo | Comando | Função |
|---|---|---|
| `web` | `bin/rails server` | Rails na porta 3000 |
| `js` | `bun run build --watch` | Empacota `app/javascript` em `app/assets/builds` |
| `css` | `bun run watch:css` | Compila o Bootstrap/SCSS em `app/assets/builds` |
| `worker` | `bundle exec good_job start` | Executa os jobs (inclusive os e-mails do Devise) |

## Front-end

- Entrada JS: `app/javascript/application.js`
- Controllers Stimulus: `app/javascript/controllers/`
  (`bin/rails g stimulus nome` cria um novo controller e atualiza o `index.js`)
- Entrada CSS: `app/assets/stylesheets/application.bootstrap.scss`
  (customize as variáveis do Bootstrap antes do `@import`)
- Nova biblioteca JS: `bun add nome-do-pacote` e depois `import` no `application.js`

## Autenticação e e-mails

Módulos do Devise ativos no `User`: `database_authenticatable`, `registerable`, `recoverable`,
`rememberable`, `validatable`, `confirmable` e `trackable`.

E-mails enviados (em segundo plano, via GoodJob):

- confirmação de conta após o cadastro;
- instruções para redefinir a senha;
- aviso de senha alterada;
- reconfirmação ao trocar o e-mail, com aviso no endereço antigo.

Em desenvolvimento, todos os e-mails são capturados pelo Mailpit (http://localhost:8025).
Nada é enviado para endereços reais. A configuração de produção ainda não foi feita.

## Testes

```bash
bin/rails test
```

## Pendências conhecidas

- Definir perfis/tipos de usuário e o uso do módulo `lockable`.
- Restringir o dashboard do GoodJob por perfil (hoje basta estar logado).
- Configurar o envio de e-mails de produção.
# transjrbi
