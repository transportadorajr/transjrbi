#!/usr/bin/env bash
# Baixa o relatório rel_caixa_detalhado (despesas) da Atua.
#
# Uso:
#   ./baixar_despesas.sh 01/10/2026 13/10/2026
#
# O período filtra pela DATA DE LANÇAMENTO da despesa
# (f_dt_lancamento_inicial / f_dt_lancamento_final), como na captura.
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

ARQ_SAIDA="despesas_$(echo "$DATA_INI" | tr -d /)_$(echo "$DATA_FIM" | tr -d /)"

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
#    Na captura ele se chamava "submete101008". O número pode mudar a cada
#    abertura da tela, então o script lê o nome atual no formulário.
# ---------------------------------------------------------------------------
echo "→ Abrindo o formulário do relatório..."
FORM_HTML="$(curl -sS -b "$COOKIES" -c "$COOKIES" -A "$UA" -L \
  -H "Referer: $BASE/index.php" \
  "$BASE/rel_caixa_detalhado.php" || true)"

BOTAO="$(echo "$FORM_HTML" | grep -oE 'name="submete[0-9]+"' | head -1 | sed -E 's/name="([^"]+)"/\1/' || true)"
BOTAO="${BOTAO:-submete101008}"
echo "  Botão de envio: $BOTAO"

# ---------------------------------------------------------------------------
# 3. Relatório de despesas (parâmetros do form data capturado)
#    f_id_listar=Despesa             → lista despesas (não receitas)
#    f_id_listar_despesa_relacionada=1
#    f_dt_base_id_cobranca           → data base da cobrança; usa hoje
#    f_cd_pessoa_matriz              → vazio na captura (todas as empresas)
#    f_id_ordenacao=2, f_id_formato=2 → como na tela
#    f_arr_nm_campos_dinamicos[...]  → colunas do relatório
# ---------------------------------------------------------------------------
DATA_BASE="$(date +%d/%m/%Y)"

PARAMS=()
while IFS= read -r linha; do
  [ -z "$linha" ] && continue
  linha="${linha//\{\{DATA_INI\}\}/$DATA_INI}"
  linha="${linha//\{\{DATA_FIM\}\}/$DATA_FIM}"
  linha="${linha//\{\{DATA_BASE\}\}/$DATA_BASE}"
  PARAMS+=(--data-urlencode "$linha")
done << 'PARAMETROS'
f__submitted=1
f_dt_lancamento_inicial={{DATA_INI}}
f_dt_lancamento_final={{DATA_FIM}}
f_dt_participacao_inicial=
f_dt_participacao_final=
f_dt_documento_inicial=
f_dt_documento_final=
f_dt_contabil_inicial=
f_dt_contabil_final=
f_dt_quitacao_inicial=
f_dt_quitacao_final=
f_cd_pessoa_matriz=
f_cd_filial=
f_id_cobranca=
f_dt_base_id_cobranca={{DATA_BASE}}
f_id_pagamento_op==
f_id_pagamento=
f_id_via_documento=
f_id_possui_despesa_mae=
f_id_despesa_salario=
f_id_possui_ordem_compra=
f_id_credita_pis_cofins=
f_id_conferido=
f_qt_linhas=1
f_id_id_modelo_1==
f_id_modelo_1=
f_cd_movimento=
f_id_integracao_abastecida=
f_qt_linhas_historico_despesa=1
f_cd_historico_despesa_pai=
f_id_id_historico_despesa_1==
f_cd_historico_despesa_1=
f_id_nm_historico_despesa_1==
f_nm_historico_despesa_1=
f_qt_linhas_historico_detalhamento=1
f_cd_historico_detalhamento_1=
f_nm_historico_detalhamento_1=
f_nr_contabilidade=
f_nr_classificacao_contabilidade=
f_nr_acumulador=
f_nr_cfop=
f_id_tipo_custo=
f_id_controle_custo=
f_id_tipo_gasto=
f_id_desconsiderar_pagamento=
f_ds_placa=
f_ds_veiculo=
f_cd_unidade_operacional_veiculo=
f_cd_marca_veiculo=
f_id_categoria=
f_id_medidor=
f_nr_viagem=
f_id_viagem=
f_id_tipo_estoque={0}
f_id_tipo_estoque_0=0
f_id_pago=
f_id_tipo_manutencao=
f_id_tipo_servico=
f_id_possui_manutencao=
f_id_custo_alocado=
f_id_frota_propria=
f_id_possui_participacao=
f_cd_caixa_financeiro=
f_cd_pessoa_usuario=
f_nm_pessoa_usuario=
f_id_cd_favorecido_1==
f_cd_favorecido_1=
f_id_nm_favorecido_1=~*
f_nm_favorecido_1=
f_qt_linhas_favorecido=1
f_id_operador_nr_cnpj_cpf==
f_nr_cnpj_cpf=
f_cd_pais=
f_nm_cidade=
f_ds_sigla_uf=
f_ds_complemento=
f_nr_documento=
f_cd_produto=
f_nm_produto=
f_cd_veiculo_servico=
f_nm_veiculo_servico=
f_id_listar=Despesa
f_id_listar_despesa_relacionada=1
f_id_arquivo_anexo=
f_id_quebra_pagina=0
f_id_sub_total=0
f_id_ordenacao=2
f_id_formato=2
f_vl_width_atual_relatorio_dinamico=0
f_id_permite_submit=1
f_arr_nm_campos_dinamicos[dt_lancamento]=1
f_arr_nm_campos_dinamicos[cd_caixa]=1
f_arr_nm_campos_dinamicos[cd_historico]=1
f_arr_nm_campos_dinamicos[nm_historico]=1
f_arr_nm_campos_dinamicos[nm_caixa_financeiro]=1
f_arr_nm_campos_dinamicos[nm_pessoa_filial]=1
f_arr_nm_campos_dinamicos[nm_pessoa_matriz]=1
f_arr_nm_campos_dinamicos[cd_pessoa_usuario]=1
f_arr_nm_campos_dinamicos[nm_pessoa_usuario]=1
f_arr_nm_campos_dinamicos[dt_lancamento_]=1
f_arr_nm_campos_dinamicos[dt_documento]=1
f_arr_nm_campos_dinamicos[dt_quitacao]=1
f_arr_nm_campos_dinamicos[dt_contabil]=1
f_arr_nm_campos_dinamicos[vl_lancamento]=1
f_arr_nm_campos_dinamicos[vl_lancamento_liquido]=1
f_arr_nm_campos_dinamicos[vl_desconto]=1
f_arr_nm_campos_dinamicos[vl_total_produto]=1
f_arr_nm_campos_dinamicos[vl_total]=1
f_arr_nm_campos_dinamicos[cd_pessoa_filial]=1
f_arr_nm_campos_dinamicos[nr_documento]=1
f_arr_nm_campos_dinamicos[ds_serie]=1
f_arr_nm_campos_dinamicos[ds_complemento]=1
f_arr_nm_campos_dinamicos[ds_chave_documento]=1
f_arr_nm_campos_dinamicos[id_estoque]=1
f_arr_nm_campos_dinamicos[cd_movimento]=1
f_arr_nm_campos_dinamicos[dt_movimento]=1
f_arr_nm_campos_dinamicos[ds_despesa_viagem]=1
f_arr_nm_campos_dinamicos[id_via_documento]=1
f_arr_nm_campos_dinamicos[ds_via_documento]=1
f_arr_nm_campos_dinamicos[proprietario_posse]=1
f_arr_nm_campos_dinamicos[ds_placa]=1
f_arr_nm_campos_dinamicos[cd_veiculo_manutencao]=1
f_arr_nm_campos_dinamicos[ds_modelo]=1
f_arr_nm_campos_dinamicos[nr_viagem]=1
f_arr_nm_campos_dinamicos[dt_saida]=1
f_arr_nm_campos_dinamicos[dt_chegada]=1
f_arr_nm_campos_dinamicos[nm_motorista_viagem]=1
f_arr_nm_campos_dinamicos[id_modelo]=1
f_arr_nm_campos_dinamicos[nr_contabilidade]=1
f_arr_nm_campos_dinamicos[nr_classificacao_contabilidade]=1
f_arr_nm_campos_dinamicos[nr_acumulador]=1
f_arr_nm_campos_dinamicos[cd_ctrc]=1
f_arr_nm_campos_dinamicos[nr_ctrc]=1
f_arr_nm_campos_dinamicos[id_tipo_gasto]=1
f_arr_nm_campos_dinamicos[arquivo_anexo]=1
f_arr_nm_campos_dinamicos[dt_conferencia]=1
f_arr_nm_campos_dinamicos[nm_pessoa_conferencia]=1
f_arr_nm_campos_dinamicos[qt_rateio]=1
f_arr_nm_campos_dinamicos[cd_pessoa_favorecido]=1
f_arr_nm_campos_dinamicos[nr_cpf_cnpj_pessoa_favorecido]=1
f_arr_nm_campos_dinamicos[nm_pessoa_favorecido]=1
f_arr_nm_campos_dinamicos[ds_sigla_uf_favorecido]=1
f_arr_nm_campos_dinamicos[nm_pais_favorecido]=1
f_arr_nm_campos_dinamicos[nm_atividade_principal_favorecido]=1
f_arr_nm_campos_dinamicos[nm_logradouro_favorecido]=1
f_arr_nm_campos_dinamicos[nm_bairro_favorecido]=1
f_arr_nm_campos_dinamicos[nr_endereco_favorecido]=1
f_arr_nm_campos_dinamicos[ds_complemento_favorecido]=1
f_arr_nm_campos_dinamicos[nr_cep_favorecido]=1
f_arr_nm_campos_dinamicos[nm_cidade_favorecido]=1
f_arr_nm_campos_dinamicos[vl_pago_titulo]=1
f_arr_nm_campos_dinamicos[dt_quitacao_titulo]=1
f_arr_nm_campos_dinamicos[ds_tipo_pagamento]=1
f_arr_nm_campos_dinamicos[ds_observacao_titulo]=1
f_arr_nm_campos_dinamicos[qt_parcela]=1
f_arr_nm_campos_dinamicos[nr_cfop]=1
f_arr_nm_campos_dinamicos[vl_base]=1
f_arr_nm_campos_dinamicos[pr_aliquota]=1
f_arr_nm_campos_dinamicos[vl_icms]=1
f_arr_nm_campos_dinamicos[vl_isento]=1
f_arr_nm_campos_dinamicos[vl_outras]=1
f_arr_nm_campos_dinamicos[pr_credito_icms]=1
f_arr_nm_campos_dinamicos[vl_credito_icms]=1
f_arr_nm_campos_dinamicos[vl_total_retencoes]=1
f_arr_nm_campos_dinamicos[vl_base_ibs_cbs]=1
f_arr_nm_campos_dinamicos[vl_cbs]=1
f_arr_nm_campos_dinamicos[vl_ibs_estadual]=1
f_arr_nm_campos_dinamicos[vl_ibs_municipal]=1
f_arr_nm_campos_dinamicos[vl_ibs]=1
f_arr_nm_campos_dinamicos[vl_credito_pis]=1
f_arr_nm_campos_dinamicos[vl_credito_cofins]=1
f_arr_nm_campos_dinamicos[COFINS]=1
f_arr_nm_campos_dinamicos[CSLL]=1
f_arr_nm_campos_dinamicos[IRPJ]=1
f_arr_nm_campos_dinamicos[ISSQN]=1
f_ds_email_recebimento_relatorio=
PARAMETROS
PARAMS+=(--data-urlencode "$BOTAO=Gerar")

echo "→ Gerando relatório de $DATA_INI a $DATA_FIM..."
curl -sS -b "$COOKIES" -c "$COOKIES" -A "$UA" -L \
  -H "Origin: https://transjr.atua.com.br" \
  -H "Referer: $BASE/rel_caixa_detalhado.php" \
  "${PARAMS[@]}" \
  -D "$ARQ_SAIDA.headers.txt" \
  -o "$ARQ_SAIDA.bin" \
  "$BASE/rel_caixa_detalhado.php"

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
