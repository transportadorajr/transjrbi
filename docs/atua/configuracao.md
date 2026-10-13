# Configuração da integração com a Atua

Guia de setup para conectar a aplicação ao ERP web da Atua (Mais Frete) e baixar os
relatórios. Vale para desenvolvimento (com o mock), para a VPS e para produção.

O que a integração precisa, em resumo:

1. **Credenciais gerais** (usuário e senha) em `Rails.application.credentials.atua`.
2. **Chaves de criptografia** do Active Record (para guardar os tokens do dispositivo).
3. **Por tenant:** a URL da Atua, a flag do Flipper ligada e o **registro do dispositivo**
   (cookie + hash capturados uma vez no navegador).

> ⚠️ **Nunca** acesse a Atua real em desenvolvimento, specs ou console. Fora de produção o
> client só aceita `localhost` (o mock). A única exceção é o teste de conexão único,
> descrito no fim, e ele nunca repete em caso de falha.

---

## 1. Credenciais gerais (usuário e senha)

Ficam em `config/credentials.yml.enc`, editadas com:

```bash
EDITOR="code --wait" bin/rails credentials:edit
```

```yml
atua:
  base_url: https://transjr.atua.com.br/adm   # legado; a URL usada vem do tenant (ver item 3)
  username: SEU_USUARIO
  password: SUA_SENHA
```

- `username` e `password` são os mesmos do login da tela da Atua.
- `base_url` é mantido só como fallback. A URL efetiva vem de `tenant.atua_url`.
- A senha nunca aparece em logs nem em mensagens de erro (é mascarada).

---

## 2. Chaves de criptografia (Active Record Encryption)

As colunas do dispositivo (`atua_device_token`, `atua_device_hash`) são **cifradas**. Para
isso, o Active Record Encryption precisa estar configurado. Gere as chaves:

```bash
bin/rails db:encryption:init
```

e cole o resultado nas credentials (`credentials:edit`):

```yml
active_record_encryption:
  primary_key: ...
  deterministic_key: ...
  key_derivation_salt: ...
```

- Faça isso em **cada ambiente** (dev e produção têm `master.key` diferentes; a VPS usa a sua).
- Em **teste**, as chaves já estão fixas em `config/environments/test.rb` (valores de teste,
  sem segredo real) — nada a fazer.
- Sem essas chaves, gravar o token/hash do dispositivo falha com erro de configuração.

---

## 3. Configuração por tenant

Cada empresa (tenant) que vai importar da Atua precisa de três coisas.

### 3.1. URL da Atua

A URL base fica em `tenants.atua_url` (e **não** nas credentials). Já existe uma migration
que preenche todos os tenants com `https://transjr.atua.com.br/adm`; ajuste pelo console se
for outra:

```ruby
tenant = Tenant.find(ID)
tenant.update!(atua_url: 'https://SUBDOMINIO.atua.com.br/adm')
```

### 3.2. Flag do Flipper

A importação só roda para tenants com a flag `atua_import` ligada, usando o tenant como ator:

```ruby
Flipper.enable_actor(:atua_import, Tenant.find(ID))
```

- `Atua.enabled?(tenant)` responde se está ligada.
- `Atua.enabled_tenants` devolve os tenants habilitados (é o que os jobs vão varrer).

### 3.3. Registro do dispositivo (cookie + hash)

O login da Atua é **vinculado ao dispositivo**. Um dispositivo novo recebe um **código por
e-mail**; depois de autorizado, o navegador guarda duas marcas que precisam ser reenviadas em
todo login:

| Marca | Onde o navegador guarda | Onde a aplicação guarda |
|---|---|---|
| `c_ds_dispositivo_<sub>_<cod>` | **cookie** | `tenants.atua_device_token` (cifrado) |
| `id_hash_aplicativo` | **localStorage** | `tenants.atua_device_hash` (cifrado) |

**Passo a passo (feito uma vez, por você):**

1. Em um navegador, acesse a Atua e **faça o login normalmente**. Se for um dispositivo novo,
   ele vai pedir o **código enviado por e-mail** — informe o código para autorizar.
2. Com a sessão aberta, abra o **DevTools** (F12) → aba **Application** (ou "Aplicativo").
3. **Cookie:** em **Cookies → `https://SUBDOMINIO.atua.com.br`**, copie o cookie cujo nome
   começa com `c_ds_dispositivo_` (ex.: `c_ds_dispositivo_transjr_9430`). Guarde no formato
   **`nome=valor`**.
4. **Hash:** em **Local Storage → `https://SUBDOMINIO.atua.com.br`**, copie o **valor** da
   chave `id_hash_aplicativo`.
5. Grave os dois no tenant, pelo console (local ou na VPS):

```ruby
tenant = Tenant.find(ID)
tenant.update!(
  atua_device_token: 'c_ds_dispositivo_transjr_9430=COLE_O_VALOR_DO_COOKIE',
  atua_device_hash:  'COLE_O_VALOR_DO_id_hash_aplicativo',
)
```

- `atua_device_token` guarda o cookie **inteiro** (`nome=valor`).
- `atua_device_hash` guarda **só o valor** do `id_hash_aplicativo`.
- As duas marcas são duráveis. Se um dia caírem, a Atua volta a pedir login (e, se o
  dispositivo for revogado, um novo código por e-mail) — aí refaça este passo.

---

## 4. Desenvolvimento (sem a Atua real)

O `bin/dev` sobe um **mock** da Atua (Sinatra) na porta 4567, servindo as fixtures de
`spec/fixtures/files/atua/`. O `Procfile.dev` já aponta a aplicação para ele via
`ATUA_BASE_URL=http://localhost:4567/adm`.

- O mock aceita qualquer usuário/senha e não exige o registro de dispositivo.
- Para desenvolver, **não** é preciso preencher cookie/hash do dispositivo.
- Se quiser apontar para o mock manualmente: `ATUA_BASE_URL=http://localhost:4567/adm`.

---

## 5. Variáveis de ambiente

| Variável | Para quê | Onde |
|---|---|---|
| `ATUA_BASE_URL` | Sobrescreve **só** a URL base (aponta para o mock). | Desenvolvimento |
| `ATUA_DEVICE_COOKIE` | Sobrescreve o cookie do dispositivo (`nome=valor`). | Só para o teste de conexão |
| `ATUA_DEVICE_HASH` | Sobrescreve o hash do dispositivo. | Só para o teste de conexão |

Em operação normal, o cookie e o hash vêm das colunas do tenant; as variáveis acima são só
para o teste de conexão manual, para não encostar o segredo em arquivo.

---

## 6. Teste de conexão (uma única vez)

Depois de tudo configurado, dá para validar o login + um download pequeno **uma vez**, sem
gravar o segredo em arquivo (passando por variável de ambiente):

```bash
env -u ATUA_BASE_URL \
  ATUA_DEVICE_COOKIE='c_ds_dispositivo_transjr_9430=VALOR' \
  ATUA_DEVICE_HASH='VALOR' \
  bin/rails runner tmp/atua/connection_test.rb
```

- Em caso de sucesso: imprime status, tamanho e formato do arquivo e salva em `tmp/atua/`.
- Em caso de falha (login recusado, 520, HTML no lugar de Excel, timeout): **não repita** nem
  mude parâmetros — a conta pode ser bloqueada. Analise o erro mostrado (status, cabeçalhos e
  trecho do corpo, sem a senha).

---

## 7. Checklist de setup

- [ ] `credentials.atua` com `username` e `password`.
- [ ] `active_record_encryption` nas credentials do ambiente (`db:encryption:init`).
- [ ] `tenant.atua_url` apontando para a Atua da empresa.
- [ ] Flag `atua_import` ligada para o tenant (`Flipper.enable_actor`).
- [ ] Dispositivo registrado no navegador (código por e-mail) e `atua_device_token` +
      `atua_device_hash` gravados no tenant.
- [ ] (Opcional) Teste de conexão único, apenas quando tudo acima estiver pronto.
