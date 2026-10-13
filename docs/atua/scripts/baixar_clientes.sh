#!/usr/bin/env bash
# Baixa o relatório rel_cliente_detalhado (cadastro de clientes) da Atua.
#
# Uso:
#   ./baixar_clientes.sh                         # todos os clientes (como na captura)
#   ./baixar_clientes.sh 01/10/2026 13/10/2026   # opcional: preenche f_dt_emissao_inicio/termino
#
# Na captura nenhuma data foi preenchida, então por padrão o relatório traz
# o cadastro inteiro. As datas opcionais preenchem o filtro "emissão" da tela
# (confira na tela o que ele filtra antes de usar).
#
# Usuário e senha:
#   - por variáveis de ambiente ATUA_USUARIO e ATUA_SENHA, ou
#   - o script pergunta (a senha não aparece na tela).

set -euo pipefail

DATA_INI="${1:-}"
DATA_FIM="${2:-}"

BASE="https://transjr.atua.com.br/adm"
UA='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0 Safari/537.36'
COOKIES="$(mktemp)"
trap 'rm -f "$COOKIES"' EXIT

if [ -n "$DATA_INI" ]; then
  ARQ_SAIDA="clientes_$(echo "$DATA_INI" | tr -d /)_$(echo "$DATA_FIM" | tr -d /)"
else
  ARQ_SAIDA="clientes_$(date +%Y%m%d)"
fi
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
#    Na captura ele se chamava "submete101053". O número pode mudar a cada
#    abertura da tela, então o script lê o nome atual no formulário.
# ---------------------------------------------------------------------------
echo "→ Abrindo o formulário do relatório..."
FORM_HTML="$(curl -sS -b "$COOKIES" -c "$COOKIES" -A "$UA" -L \
  -H "Referer: $BASE/index.php" \
  "$BASE/rel_cliente_detalhado.php" || true)"

BOTAO="$(echo "$FORM_HTML" | grep -oE 'name="submete[0-9]+"' | head -1 | sed -E 's/name="([^"]+)"/\1/' || true)"
BOTAO="${BOTAO:-submete101053}"
echo "  Botão de envio: $BOTAO"

# ---------------------------------------------------------------------------
# 3. Relatório de clientes (parâmetros do form data capturado)
#    f_id_tipo_cliente=0, f_id_mostra_tde=0, f_id_listar_corretores_ativos=0
#    f_id_ordenacao=1, f_id_formato=2 → como na tela
# ---------------------------------------------------------------------------
PARAMS=()
while IFS= read -r linha; do
  [ -z "$linha" ] && continue
  linha="${linha//\{\{DATA_INI\}\}/$DATA_INI}"
  linha="${linha//\{\{DATA_FIM\}\}/$DATA_FIM}"
  PARAMS+=(--data-urlencode "$linha")
done << 'PARAMETROS'
f__submitted=1
f_nm_pessoa=
f_nr_cnpj_cpf=
f_nm_cidade=
f_ds_sigla=
f_cd_pais=
f_id_atividade=~*
f_cd_atividade=
f_nm_atividade=
f_dt_inicio_cadastro=
f_dt_termino_cadastro=
f_dt_inicio_atualizacao=
f_dt_termino_atualizacao=
f_cd_pessoa_usuario=
f_nm_pessoa_usuario=
f_id_recebe_cte=
f_id_mostra_tde=0
f_cd_pessoa_pagador=
f_nm_pessoa_pagador=
f_id_registra_titulo=
f_id_notificacao_titulo=
f_id_permite_cnpj_duplicado=
f_id_permite_nf_duplicada=
f_cd_tipo_pagamento=
f_cd_condicao=
f_id_condicao_pagamento=
f_nr_dia_pagamento=
f_id_possui_vl_credito=
f_id_faturamento_automatico=
f_id_desconta_quebra=
f_id_limite_quebra=
f_pr_limite_quebra=
f_qt_limite_quebra=
f_id_pgto_frete_motorista=
f_id_soma_pedagio=
f_id_exportador=
f_cd_pessoa_seguradora=
f_id_obrigatoriedade_peso_chegada=
f_id_impressao_vl_frete=
f_id_situacao=
f_id_tipo_pessoa=
f_id_tipo_cliente=0
f_id_dt_nota_fiscal=
f_id_utiliza_nota_fiscal_seguro=
f_id_peso_importacao_nfe=
f_id_quantidade_importacao_nfe=
f_id_calculo_icms=
f_id_pgto_frete_empresa=
f_id_soma_icms=
f_id_soma_icms_st=
f_id_soma_advalorem=
f_id_obrigatorio_documento_eletronico=
f_id_listar_corretores_ativos=0
f_ar_id_obrigatorio_consulta_antt_emissao_ciot=
f_id_documento_cobranca=
f_id_pedagio=
f_id_documento_cobranca_entrega=
f_id_obrigatorio_comprovante_entrega=
f_dt_emissao_inicio={{DATA_INI}}
f_dt_emissao_termino={{DATA_FIM}}
f_id_situacao_cliente=
f_id_embarque=
f_id_quebra_pagina=0
f_id_subtotal=0
f_id_ordenacao=1
f_id_formato=2
f_ds_email_recebimento_relatorio=
PARAMETROS
PARAMS+=(--data-urlencode "$BOTAO=Gerar")

echo "→ Gerando relatório de clientes..."
curl -sS -b "$COOKIES" -c "$COOKIES" -A "$UA" -L \
  -H "Origin: https://transjr.atua.com.br" \
  -H "Referer: $BASE/rel_cliente_detalhado.php" \
  "${PARAMS[@]}" \
  -D "$ARQ_SAIDA.headers.txt" \
  -o "$ARQ_SAIDA.bin" \
  "$BASE/rel_cliente_detalhado.php"

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
