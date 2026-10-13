#!/usr/bin/env bash
# Baixa o relatório rel_manifesto_detalhado (MDF-es) da Atua.
#
# Uso:
#   ./baixar_mdfe.sh 01/10/2026 13/10/2026
#
# O período filtra pela DATA DE LANÇAMENTO do manifesto
# (f_dt_lancamento_inicio / f_dt_lancamento_termino), como na captura.
#
# Usuário e senha:
#   - por variáveis de ambiente ATUA_USUARIO e ATUA_SENHA, ou
#   - o script pergunta (a senha não aparece na tela).

set -euo pipefail

DATA_INI="${1:?Informe a data inicial (dd/mm/aaaa)}"
DATA_FIM="${2:?Informe a data final (dd/mm/aaaa)}"

BASE="https://transjr.atua.com.br/adm"
UA='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0 Safari/537.36'
COOKIES="$(mktemp)"
trap 'rm -f "$COOKIES"' EXIT

ARQ_SAIDA="mdfe_$(echo "$DATA_INI" | tr -d /)_$(echo "$DATA_FIM" | tr -d /)"

if [ -z "${ATUA_USUARIO:-}" ]; then read -rp "Usuário Atua: " ATUA_USUARIO; fi
if [ -z "${ATUA_SENHA:-}" ]; then read -rsp "Senha Atua: " ATUA_SENHA; echo; fi

# ---------------------------------------------------------------------------
# 1. Login
# ---------------------------------------------------------------------------
echo "→ Abrindo a página de login..."
curl -sS -c "$COOKIES" -A "$UA" -o /dev/null \
  "$BASE/login.php?f_popup=true"

echo "→ Fazendo login..."
LOGIN_HTML="$(curl -sS -c "$COOKIES" -b "$COOKIES" -A "$UA" -L \
  -H "Origin: https://transjr.atua.com.br" \
  -H "Referer: $BASE/login.php?f_popup=true" \
  --data-urlencode "f_origem=index.php" \
  --data-urlencode "f_ds_apelido=$ATUA_USUARIO" \
  --data-urlencode "f_ds_senha=$ATUA_SENHA" \
  -w '\n__HTTP_STATUS__%{http_code}' \
  "$BASE/login.php")"

STATUS="${LOGIN_HTML##*__HTTP_STATUS__}"
if [ "$STATUS" != "200" ]; then
  echo "✗ Login retornou HTTP $STATUS. Confira cabeçalhos/campos (veja o 'Copy as cURL' do navegador)." >&2
  exit 1
fi
if echo "$LOGIN_HTML" | grep -qi 'f_ds_senha'; then
  echo "✗ A resposta ainda contém o formulário de login: usuário/senha incorretos ou falta algum campo." >&2
  exit 1
fi
echo "✓ Login OK"

# ---------------------------------------------------------------------------
# 2. Nome do botão "Gerar"
#    Na captura ele se chamava "submete101037". Esse número pode mudar a cada
#    abertura da tela, então o script abre o formulário e lê o nome atual.
#    Se não encontrar, usa o da captura.
# ---------------------------------------------------------------------------
echo "→ Abrindo o formulário do relatório..."
FORM_HTML="$(curl -sS -b "$COOKIES" -c "$COOKIES" -A "$UA" -L \
  -H "Referer: $BASE/index.php" \
  "$BASE/rel_manifesto_detalhado.php" || true)"

BOTAO="$(echo "$FORM_HTML" | grep -oE 'name="submete[0-9]+"' | head -1 | sed -E 's/name="([^"]+)"/\1/' || true)"
BOTAO="${BOTAO:-submete101037}"
echo "  Botão de envio: $BOTAO"

# ---------------------------------------------------------------------------
# 3. Relatório de MDF-es (parâmetros do form data capturado)
#    f_cd_pessoa_matriz=2  → empresa/matriz selecionada
#    f_id_situacao=4       → situação escolhida na tela (confira qual é)
#    f_id_ordenacao=1      → ordenação escolhida na tela
#    f_id_formato=2        → formato de saída (provavelmente Excel)
# ---------------------------------------------------------------------------
echo "→ Gerando relatório de $DATA_INI a $DATA_FIM..."
curl -sS -b "$COOKIES" -c "$COOKIES" -A "$UA" -L \
  -H "Origin: https://transjr.atua.com.br" \
  -H "Referer: $BASE/rel_manifesto_detalhado.php" \
  --data-urlencode "f__submitted=1" \
  --data-urlencode "f_cd_pessoa_matriz=2" \
  --data-urlencode "f_cd_pessoa_filial=" \
  --data-urlencode "f_cd_agencia=" \
  --data-urlencode "f_nm_agencia=" \
  --data-urlencode "f_cd_usuario=" \
  --data-urlencode "f_nm_usuario=" \
  --data-urlencode "f_ds_placa=" \
  --data-urlencode "f_ds_veiculo=" \
  --data-urlencode "f_cd_motorista=" \
  --data-urlencode "f_nm_motorista=" \
  --data-urlencode "f_id_proprietario_veiculo=" \
  --data-urlencode "f_id_enquadramento_proprietario_antt=" \
  --data-urlencode "f_id_modelo=" \
  --data-urlencode "f_nr_manifesto=" \
  --data-urlencode "f_ds_serie=" \
  --data-urlencode "f_dt_lancamento_inicio=$DATA_INI" \
  --data-urlencode "f_dt_lancamento_termino=$DATA_FIM" \
  --data-urlencode "f_dt_emissao_inicio=" \
  --data-urlencode "f_dt_emissao_termino=" \
  --data-urlencode "f_dt_saida_inicio=" \
  --data-urlencode "f_dt_saida_termino=" \
  --data-urlencode "f_dt_encerramento_inicio=" \
  --data-urlencode "f_dt_encerramento_termino=" \
  --data-urlencode "f_vl_total_nfe_mdfe_inicio=" \
  --data-urlencode "f_vl_total_nfe_mdfe_termino=" \
  --data-urlencode "f_id_situacao=4" \
  --data-urlencode "f_cd_status=" \
  --data-urlencode "f_id_operacao=" \
  --data-urlencode "f_id_assinatura=0" \
  --data-urlencode "f_id_quebra_pagina=0" \
  --data-urlencode "f_id_subtotal=0" \
  --data-urlencode "f_id_ordenacao=1" \
  --data-urlencode "f_id_formato=2" \
  --data-urlencode "$BOTAO=Gerar" \
  -D "$ARQ_SAIDA.headers.txt" \
  -o "$ARQ_SAIDA.bin" \
  "$BASE/rel_manifesto_detalhado.php"

# ---------------------------------------------------------------------------
# 4. Descobre o que veio e dá a extensão certa
# ---------------------------------------------------------------------------
TIPO="$(file -b "$ARQ_SAIDA.bin")"
CT="$(grep -i '^content-type:' "$ARQ_SAIDA.headers.txt" | tail -1 | tr -d '\r' || true)"
echo "  Content-Type: ${CT:-?}"
echo "  Conteúdo:     $TIPO"

if grep -qi 'f_ds_senha' "$ARQ_SAIDA.bin" 2>/dev/null; then
  echo "✗ Voltou a tela de login: a sessão não foi aceita no relatório." >&2
  exit 1
fi

case "$TIPO" in
  *"Composite Document"*|*"CDF V2"*|*Excel*) EXT=xls ;;
  *"Microsoft OOXML"*|*"Zip archive"*)        EXT=xlsx ;;
  *HTML*|*XML*)                                EXT=html ;;
  *CSV*|*text*)                                EXT=csv ;;
  *PDF*)                                       EXT=pdf ;;
  *)                                           EXT=bin ;;
esac
mv "$ARQ_SAIDA.bin" "$ARQ_SAIDA.$EXT"
echo "✓ Relatório salvo em $ARQ_SAIDA.$EXT ($(wc -c < "$ARQ_SAIDA.$EXT") bytes)"
