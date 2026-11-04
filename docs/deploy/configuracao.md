# Deploy sem downtime (Traefik + docker rollout)

A produção roda numa VPS com o `deploy/compose.yaml`. O Traefik recebe as portas 80 e 443,
emite os certificados do Let's Encrypt e só manda requisições para containers `web` saudáveis.
O `docker rollout` troca o container `web` sem derrubar a aplicação.

Todo push na branch `production` dispara o workflow `.github/workflows/publish.yml`, que gera a
imagem, copia `deploy/compose.yaml` e `deploy/release` para o `VPS_APP_PATH` e roda o `release`.

---

## 1. Como um deploy acontece

O script `deploy/release` executa, em ordem:

1. Instala o plugin `docker rollout` na VPS, se ainda não estiver instalado.
2. `docker compose pull`: baixa a imagem nova antes de qualquer troca.
3. Roda `db:prepare` num container avulso, uma única vez. As migrations rodam enquanto a
   versão antiga continua atendendo (por isso precisam ser retrocompatíveis, ver o item 4).
4. `docker rollout web`:
   - sobe um segundo container `web` com a versão nova;
   - espera o healthcheck (`/up`) passar, por até 180 segundos. Se não passar, o container
     novo é removido, o antigo continua no ar e o deploy falha;
   - mantém os dois containers atendendo juntos por 60 segundos;
   - cria `tmp/drain` no container antigo: o `/up` passa a responder 503, o Traefik para de
     mandar tráfego para ele e, depois de 20 segundos, o container é parado. O Puma termina as
     requisições em andamento (até 30 segundos).
5. Sobe o Traefik (só recria se a configuração mudou).
6. Recria o container `jobs` com a versão nova. O GoodJob espera até 25 segundos pelos jobs em
   execução antes de sair.

O Traefik usa um cookie (`transjrbi_server`) para manter cada usuário no mesmo container
durante a janela em que os dois estão no ar. Assim uma página gerada pela versão nova não pede
CSS/JS ao container antigo, que não tem esses arquivos.

## 2. Preparar a VPS (uma vez)

1. Adicione ao `.env` do `VPS_APP_PATH`:

   ```bash
   APP_DOMAIN=<domínio, sem o app. na frente>
   ACME_EMAIL=<e-mail que recebe os avisos do Let's Encrypt>
   ```

   O Traefik atende `app.<APP_DOMAIN>` e `admin.<APP_DOMAIN>`. Os dois registros DNS precisam
   apontar para a VPS.

2. Confira se a VPS tem o Docker Engine 25 ou mais novo (`docker version`). O healthcheck do
   `web` usa o `start_interval`, que só existe a partir dessa versão.

## 3. Primeiro deploy (troca do Caddy pelo Traefik)

O primeiro deploy com este compose substitui o Caddy:

- o `web` é trocado pelo `docker rollout` com o Caddy ainda atendendo;
- em seguida o Caddy é removido (`--remove-orphans`) e o Traefik sobe e emite os certificados.

Entre a saída do Caddy e a emissão dos certificados há alguns segundos sem resposta. Faça o
primeiro deploy fora do horário de uso. Os deploys seguintes não têm downtime.

Depois de confirmar que tudo funciona, apague o que era do Caddy na VPS:

```bash
rm Caddyfile
```

```bash
docker volume rm <projeto>_caddy_data
```

## 4. Regras para o código

Durante todo deploy, a versão antiga e a nova atendem ao mesmo tempo. As regras (migrations
retrocompatíveis, seeds idempotentes, jobs compatíveis entre versões) estão na seção **Deploy**
do `AGENTS.md`.

## 5. Rodar um deploy manualmente

No `VPS_APP_PATH`:

```bash
APP_VERSION=<versão> bash release
```
