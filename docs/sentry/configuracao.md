# Configuração do Sentry e do aviso de erros no Discord

Os erros de produção (controllers, jobs do GoodJob e tudo que passa por `Rails.error`) são
enviados ao Sentry pelas gems `sentry-ruby` e `sentry-rails`. O Sentry agrupa as ocorrências
repetidas numa única issue. O aviso no canal do Discord é feito pela própria aplicação, por
webhook (item 3).

O envio só acontece em `production` (`config.enabled_environments`). Em desenvolvimento e
nos specs nada sai da máquina, mesmo com o DSN configurado.

---

## 1. Criar o projeto no Sentry

1. Em https://sentry.io, crie um projeto do tipo **Rails**.
2. Copie o **DSN** (Settings → Projects → *projeto* → Client Keys (DSN)).

## 2. Informar o DSN para a aplicação

Use **uma** das opções (a variável de ambiente tem prioridade):

- Variável de ambiente na VPS:

  ```bash
  SENTRY_DSN=https://<chave>@o<org>.ingest.sentry.io/<projeto>
  ```

- Ou nas credentials:

  ```bash
  EDITOR="code --wait" bin/rails credentials:edit
  ```

  ```yml
  sentry:
    dsn: https://<chave>@o<org>.ingest.sentry.io/<projeto>
  ```

Opcional: `SENTRY_TRACES_SAMPLE_RATE` (de `0` a `1`) liga o monitoramento de performance para
essa fração das requisições. O padrão é `0` (desligado), para não gastar a cota do plano.

## 3. Aviso no Discord (webhook)

Além do Sentry, a própria aplicação avisa o canal do Discord por um **webhook**, sem depender
do bot do Sentry. O `Discord::ErrorSubscriber` (`lib/discord/error_subscriber.rb`) assina o
`Rails.error` em produção e chama o `Discord::NotifyErrorCommand`, que envia uma mensagem com
a classe do erro, a mensagem, a origem, o tenant/usuário e as primeiras linhas do backtrace.

A URL do webhook fica nas credentials (nunca no código nem em variáveis versionadas):

```yml
discord:
  error_webhook_url: https://discord.com/api/webhooks/<id>/<token>
```

Regras do aviso:

- Só erros de servidor: os que viram resposta 4xx (`RecordNotFound`, rota inexistente…) e os
  avisos (`severity: :warning`) não são enviados.
- O mesmo erro (mesma classe e mesma linha de origem) é avisado **uma vez por hora** por
  processo, para não inundar o canal. Os detalhes de todas as ocorrências ficam no Sentry.
- Se o Discord estiver fora do ar, a falha só é registrada no log: ela nunca derruba a
  requisição nem gera um novo aviso.
- Menções (`@everyone`, `@here`) dentro da mensagem do erro são ignoradas pelo Discord.

Para trocar o webhook (por exemplo, se o token vazar), gere um novo em *Configurações do canal
→ Integrações → Webhooks* e atualize `discord.error_webhook_url` com `bin/rails credentials:edit`.

## O que vai junto com cada erro

- `user.id`: o usuário logado. Nas telas do admin vai também `segment: admin`.
- tag `tenant_id`: o tenant do usuário, para filtrar os erros por cliente.

Nenhum dado pessoal é enviado (`send_default_pii = false`): sem e-mail, IP ou cookies, e os
parâmetros filtrados em `filter_parameter_logging.rb` chegam mascarados.

## Testar depois do deploy

```bash
bin/rails runner 'Sentry.capture_message("Teste de integração com o Sentry")'
```

A mensagem deve aparecer no Sentry. Para conferir o Discord:

```bash
bin/rails runner 'Discord::NotifyErrorCommand.call(RuntimeError.new("Teste de aviso no Discord"), handled: true)'
```
