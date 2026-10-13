#!/usr/bin/env bash
# Baixa o relatório rel_veiculo_terceiro_detalhado (cadastro de veículos) da Atua.
#
# Uso:
#   ./baixar_veiculos.sh
#
# Não tem período: traz o cadastro de veículos com os filtros da captura
# (f_id_situacao_cadastro=2, f_id_lista_motorista=1, f_id_listar_conjunto=0).
#
# Usuário e senha:
#   - por variáveis de ambiente ATUA_USUARIO e ATUA_SENHA, ou
#   - o script pergunta (a senha não aparece na tela).

set -euo pipefail

BASE="https://transjr.atua.com.br/adm"
UA='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0 Safari/537.36'
COOKIES="$(mktemp)"
trap 'rm -f "$COOKIES"' EXIT

ARQ_SAIDA="veiculos_$(date +%Y%m%d)"
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
#    Na captura ele se chamava "submete101044". O número pode mudar a cada
#    abertura da tela, então o script lê o nome atual no formulário.
# ---------------------------------------------------------------------------
echo "→ Abrindo o formulário do relatório..."
FORM_HTML="$(curl -sS -b "$COOKIES" -c "$COOKIES" -A "$UA" -L \
  -H "Referer: $BASE/index.php" \
  "$BASE/rel_veiculo_terceiro_detalhado.php" || true)"

BOTAO="$(echo "$FORM_HTML" | grep -oE 'name="submete[0-9]+"' | head -1 | sed -E 's/name="([^"]+)"/\1/' || true)"
BOTAO="${BOTAO:-submete101044}"
echo "  Botão de envio: $BOTAO"

# ---------------------------------------------------------------------------
# 3. Relatório de veículos (parâmetros do form data capturado)
#    f_form_submitted=1 (aqui o nome é diferente dos outros relatórios)
#    f_id_situacao_cadastro=2 → situação escolhida na tela (provavelmente ativos)
#    f_id_lista_motorista=1 → inclui o motorista vinculado
#    f_id_ordenacao=1, f_id_formato=2 → como na tela
# ---------------------------------------------------------------------------
PARAMS=()
while IFS= read -r linha; do
  [ -z "$linha" ] && continue
  PARAMS+=(--data-urlencode "$linha")
done << 'PARAMETROS'
f_form_submitted=1
f_nr_ano_inicio_fabricacao=
f_nr_ano_final_fabricacao=
f_nr_ano_inicio_modelo=
f_nr_ano_final_modelo=
f_cd_proprietario_veiculo=
f_nm_proprietario_veiculo=
f_nm_cidade=
f_ds_sigla=
f_cd_marca=
f_id_proprietario_veiculo=
f_cd_tipo_veiculo=
f_id_tipo=
f_id_carroceria=
f_ds_placa_cavalo=
f_ds_placa_conjunto=
f_id_listar_conjunto=0
f_id_observacao=
f_id_lista_motorista=1
f_nr_final_placa=
f_id_situacao_cadastro=2
f_id_situacao_dados=
f_dt_inicio_cadastro=
f_dt_termino_cadastro=
f_dt_inicio_atualizacao=
f_dt_termino_atualizacao=
f_dt_inicio_vcto_dados=
f_dt_termino_vcto_dados=
f_dt_inicio_consulta_risco=
f_dt_termino_consulta_risco=
f_dt_inicio_vencimento_crlv=
f_dt_termino_vencimento_crlv=
f_dt_inicio_validade_rntrc_antt=
f_dt_termino_validade_rntrc_antt=
f_cd_pessoa_usuario=
f_nm_pessoa_usuario=
f_cd_unidade_operacional=
f_cd_centro_custo=
f_id_associado=
f_id_alto_desempenho=
f_id_subtotal=0
f_id_ordenacao=1
f_id_formato=2
PARAMETROS
PARAMS+=(--data-urlencode "$BOTAO=Gerar")

echo "→ Gerando relatório de veículos..."
curl -sS -b "$COOKIES" -c "$COOKIES" -A "$UA" -L \
  -H "Origin: https://transjr.atua.com.br" \
  -H "Referer: $BASE/rel_veiculo_terceiro_detalhado.php" \
  "${PARAMS[@]}" \
  -D "$ARQ_SAIDA.headers.txt" \
  -o "$ARQ_SAIDA.bin" \
  "$BASE/rel_veiculo_terceiro_detalhado.php"

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
