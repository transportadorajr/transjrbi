#!/usr/bin/env bash
# Baixa o relatório rel_ctrc_detalhado (CT-es emitidos) da Atua.
#
# Uso:
#   ./baixar_ctrc.sh 01/10/2026 13/10/2026
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

ARQ_SAIDA="ctrc_$(echo "$DATA_INI" | tr -d /)_$(echo "$DATA_FIM" | tr -d /)"

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
# 2. Relatório de CT-es
#    Parâmetros copiados do formulário do navegador (form data).
#    f_id_formato=2 é o formato escolhido na tela (provavelmente Excel).
#    f_arr_nm_campos_dinamicos[...] são as colunas que vêm no relatório.
# ---------------------------------------------------------------------------
PARAMS=()
while IFS= read -r linha; do
  [ -z "$linha" ] && continue
  linha="${linha//\{\{DATA_INI\}\}/$DATA_INI}"
  linha="${linha//\{\{DATA_FIM\}\}/$DATA_FIM}"
  PARAMS+=(--data-urlencode "$linha")
done << 'PARAMETROS'
f__submitted=1
f_dt_emissao_inicio={{DATA_INI}}
f_dt_emissao_final={{DATA_FIM}}
f_dt_lancamento_inicio=
f_dt_lancamento_final=
f_dt_emissao_inicio_cf=
f_dt_emissao_final_cf=
f_dt_cancelamento_inicio=
f_dt_cancelamento_termino=
f_nr_ctrc_inicial=
f_nr_ctrc_final=
f_nr_carta_frete_inicial=
f_nr_carta_frete_final=
f_id_cd_pessoa_remetente==
f_cd_pessoa_remetente=
f_id_nm_pessoa_remetente=~*
f_nm_pessoa_remetente=
f_id_cd_pessoa_destinatario==
f_cd_pessoa_destinatario=
f_id_nm_pessoa_destinatario=~*
f_nm_pessoa_destinatario=
f_id_cd_pessoa_pagador==
f_cd_pessoa_pagador=
f_id_nm_pessoa_pagador=~*
f_nm_pessoa_pagador=
f_id_cd_pessoa_consignatario==
f_cd_pessoa_consignatario=
f_id_nm_pessoa_consignatario=~*
f_nm_pessoa_consignatario=
f_id_cd_pessoa_consignatario_expedidor==
f_cd_pessoa_consignatario_expedidor=
f_id_nm_pessoa_consignatario_expedidor=~*
f_nm_pessoa_consignatario_expedidor=
f_cd_grupo_cliente=
f_nm_grupo_cliente=
f_ds_placa=
f_ds_veiculo=
f_cd_tipo_veiculo_cavalo=
f_id_cd_pessoa_proprietario_veiculo==
f_cd_pessoa_proprietario_veiculo=
f_id_nm_pessoa_proprietario_veiculo=~*
f_nm_pessoa_proprietario_veiculo=
f_id_cd_pessoa_proprietario_veiculo_doc==
f_cd_pessoa_proprietario_veiculo_doc=
f_id_nm_pessoa_proprietario_veiculo_doc=~*
f_nm_pessoa_proprietario_veiculo_doc=
f_id_cd_pessoa_motorista==
f_cd_pessoa_motorista=
f_id_nm_pessoa_motorista=~*
f_nm_pessoa_motorista=
f_ds_placa_carreta=
f_cd_tipo_veiculo_carreta_1=
f_cd_tipo_veiculo_carreta_2=
f_cd_tipo_veiculo_carreta_3=
f_nm_produto_transportado=
f_nr_natureza=
f_id_cd_lote==
f_cd_lote=
f_id_nm_lote=~*
f_ds_lote=
f_id_cd_agencia_lote==
f_cd_agencia_lote=
f_id_nm_agencia_lote=~*
f_nm_agencia_lote=
f_id_cd_pessoa_responsavel_lote==
f_cd_pessoa_responsavel_lote=
f_id_nm_pessoa_responsavel_lote=~*
f_nm_pessoa_responsavel_lote=
f_id_cd_agencia_ordem==
f_cd_agencia_ordem=
f_id_nm_agencia_ordem=~*
f_nm_agencia_ordem=
f_cd_pessoa_usuario_ordem=
f_nm_pessoa_usuario_ordem=
f_id_cd_pessoa_usuario_agenciador==
f_cd_pessoa_usuario_agenciador=
f_id_nm_pessoa_usuario_agenciador=~*
f_nm_pessoa_usuario_agenciador=
f_id_possui_lote=
f_id_possui_ordem=
f_id_tipo_emissao=
f_dt_nf_cliente_inicio=
f_dt_nf_cliente_final=
f_nr_nf_cliente=
f_id_ctrc_troca_nota=
f_cd_movimento=
f_id_lista_cte_desacordo=0
f_qt_linhas_agencia_lancamento_controle=1
f_qt_linhas_agencia_lancamento=1
f_id_cd_agencia_lancamento_1==
f_cd_agencia_lancamento_1=
f_id_nm_agencia_lancamento_1=~*
f_nm_agencia_lancamento_1=
f_cd_pessoa_usuario=
f_nm_pessoa_usuario=
f_id_situacao_cte_op==
f_id_situacao_cte=
f_qt_linhas_empresa=1
f_id_pessoa_matriz_0==
f_cd_pessoa_matriz_0=2
f_id_pessoa_filial_0==
f_cd_pessoa_filial_0=
f_id_pessoa_matriz==
f_cd_pessoa_matriz=
f_id_pessoa_filial==
f_cd_pessoa_filial=
f_cd_unidade_operacional=
f_cd_centro_custo=
f_id_tipo_proprietario_veiculo=
f_id_proprietario_veiculo=
f_id_tipo_proprietario_veiculo_doc=
f_id_proprietario_veiculo_doc=
f_id_enquadramento_federal=
f_id_quitado=
f_id_tipo_documento=
f_id_operacao=1
f_id_frete=
f_id_servico=
f_id_tipo_complemento_op==
f_id_tipo_complemento=
f_id_tipo_cte_op==
f_id_tipo_cte=
f_id_cancelado_fiscal=
f_id_cancelado_sistema=0
f_id_mostrar_ce_substituido_nfe=0
f_id_contra_cte=
f_id_pedagio_empresa_op==
f_id_pedagio_empresa=
f_id_pedagio_motorista_op==
f_id_pedagio_motorista=
f_id_soma_pedagio_op==
f_id_soma_pedagio=
f_cd_motivo_cancelamento=
f_id_cidade_origem=~*
f_nm_cidade_origem=
f_id_sigla_origem=~*
f_ds_sigla_origem=
f_id_cidade_destino=~*
f_nm_cidade_destino=
f_id_sigla_destino=~*
f_ds_sigla_destino=
f_pr_diferenca_frete_maior=
f_pr_diferenca_frete_menor=
f_pr_margem_maior=
f_pr_margem_menor=
f_id_deduz_credito_icms_resultado=1
f_id_associado=
f_cd_categoria_associado=
f_id_destino_mercadoria=
f_id_pis_cofins=
f_id_icms=
f_id_issqn=
f_id_pedagio_ctrc=1
f_id_pedagio_cf=1
f_id_doc_associado_viagem=
f_id_veiculo_comissao=
f_nr_embarque=
f_id_situacao_rastreamento=
f_cd_pessoa_adm_pgto_eletronico=
f_id_forma_pagamento_carta_frete=0
f_id_nr_ctrc=IN
f_nr_ctrc=
f_ds_serie=
f_id_mdfe=
f_id_possui_anexo=
f_dt_anexo_inicio=
f_dt_anexo_termino=
f_id_cd_comprovante=
f_cd_comprovante=
f_id_assinatura_carta_frete=
f_id_carta_frete_assinada=
f_id_bloquear_ctrc_faturamento=
f_id_nr_documento_extra==
f_nr_documento_extra=
f_id_lista_contra_cte_empresa=1
f_id_ambiente=1
f_id_cd_agencia_manifestador==
f_cd_agencia_manifestador=
f_nm_agencia_manifestador=
f_id_cd_agencia_agenciador==
f_cd_agencia_agenciador=
f_nm_agencia_agenciador=
f_id_cd_agencia_gerente==
f_cd_agencia_gerente=
f_nm_agencia_gerente=
f_id_cd_agencia_supervisor==
f_cd_agencia_supervisor=
f_nm_agencia_supervisor=
f_ds_email_recebimento_relatorio=
f_id_quebra_pagina=0
f_id_sub_total=0
f_id_ordenacao=0
f_id_formato=2
f_vl_width_atual_relatorio_dinamico=0
f_id_permite_submit=1
f_arr_nm_campos_dinamicos[cd_ctrc]=1
f_arr_nm_campos_dinamicos[nr_ctrc]=1
f_arr_nm_campos_dinamicos[ds_serie]=1
f_arr_nm_campos_dinamicos[nr_cfop]=1
f_arr_nm_campos_dinamicos[id_sintegra]=1
f_arr_nm_campos_dinamicos[ds_servico]=1
f_arr_nm_campos_dinamicos[id_situacao_cte]=1
f_arr_nm_campos_dinamicos[nr_contrato]=1
f_arr_nm_campos_dinamicos[nr_pedido]=1
f_arr_nm_campos_dinamicos[nr_ordem_compra]=1
f_arr_nm_campos_dinamicos[nr_liberacao_embarque]=1
f_arr_nm_campos_dinamicos[dt_cancelamento]=1
f_arr_nm_campos_dinamicos[dt_emissao]=1
f_arr_nm_campos_dinamicos[dt_mes_emissao]=1
f_arr_nm_campos_dinamicos[dt_lancamento]=1
f_arr_nm_campos_dinamicos[dt_chegada]=1
f_arr_nm_campos_dinamicos[dt_vencimento_titulo]=1
f_arr_nm_campos_dinamicos[cd_pessoa_filial]=1
f_arr_nm_campos_dinamicos[nm_pessoa_filial]=1
f_arr_nm_campos_dinamicos[cd_agencia]=1
f_arr_nm_campos_dinamicos[nm_agencia]=1
f_arr_nm_campos_dinamicos[nm_cidade_origem]=1
f_arr_nm_campos_dinamicos[ds_uf_origem]=1
f_arr_nm_campos_dinamicos[nm_cidade_destino]=1
f_arr_nm_campos_dinamicos[ds_uf_destino]=1
f_arr_nm_campos_dinamicos[cd_pessoa_usuario]=1
f_arr_nm_campos_dinamicos[nm_pessoa_usuario]=1
f_arr_nm_campos_dinamicos[cd_pessoa_embarque]=1
f_arr_nm_campos_dinamicos[nm_pessoa_remetente]=1
f_arr_nm_campos_dinamicos[nr_cnpj_cpf_remetente]=1
f_arr_nm_campos_dinamicos[ds_endereco_remetente]=1
f_arr_nm_campos_dinamicos[ds_uf_remetente]=1
f_arr_nm_campos_dinamicos[nm_cidade_remetente]=1
f_arr_nm_campos_dinamicos[cd_pessoa_consignatario]=1
f_arr_nm_campos_dinamicos[nm_pessoa_consignatario]=1
f_arr_nm_campos_dinamicos[nr_cnpj_cpf_consignatario]=1
f_arr_nm_campos_dinamicos[ds_uf_consignatario]=1
f_arr_nm_campos_dinamicos[nm_cidade_consignatario]=1
f_arr_nm_campos_dinamicos[cd_pessoa_consignatario_embarque]=1
f_arr_nm_campos_dinamicos[nm_pessoa_consignatario_embarque]=1
f_arr_nm_campos_dinamicos[cd_pessoa_entrega]=1
f_arr_nm_campos_dinamicos[nm_pessoa_destinatario]=1
f_arr_nm_campos_dinamicos[nr_cnpj_cpf_destinatario]=1
f_arr_nm_campos_dinamicos[ds_endereco_destinatario]=1
f_arr_nm_campos_dinamicos[ds_uf_destinatario]=1
f_arr_nm_campos_dinamicos[nm_cidade_destinatario]=1
f_arr_nm_campos_dinamicos[cd_pessoa_pagador]=1
f_arr_nm_campos_dinamicos[nm_pessoa_pagador]=1
f_arr_nm_campos_dinamicos[nm_grupo_cliente]=1
f_arr_nm_campos_dinamicos[nm_grupo_pai]=1
f_arr_nm_campos_dinamicos[nr_cnpj_cpf_pagador]=1
f_arr_nm_campos_dinamicos[ds_uf_pagador]=1
f_arr_nm_campos_dinamicos[nm_cidade_pagador]=1
f_arr_nm_campos_dinamicos[cd_pessoa_motorista]=1
f_arr_nm_campos_dinamicos[nm_pessoa_motorista]=1
f_arr_nm_campos_dinamicos[nr_cpf_motorista]=1
f_arr_nm_campos_dinamicos[cd_veiculo]=1
f_arr_nm_campos_dinamicos[ds_placa]=1
f_arr_nm_campos_dinamicos[ds_placa_carreta]=1
f_arr_nm_campos_dinamicos[nr_eixo]=1
f_arr_nm_campos_dinamicos[nr_cnpj_cpf_proprietario_veiculo_doc]=1
f_arr_nm_campos_dinamicos[cd_pessoa_proprietario_veiculo_doc]=1
f_arr_nm_campos_dinamicos[nm_pessoa_proprietario_veiculo_doc]=1
f_arr_nm_campos_dinamicos[id_enquadramento_proprietario_antt]=1
f_arr_nm_campos_dinamicos[ds_endereco_proprietario_doc]=1
f_arr_nm_campos_dinamicos[cd_pessoa_proprietario_veiculo_posse]=1
f_arr_nm_campos_dinamicos[nm_pessoa_proprietario_veiculo_posse]=1
f_arr_nm_campos_dinamicos[ds_endereco_proprietario_posse]=1
f_arr_nm_campos_dinamicos[vl_peso]=1
f_arr_nm_campos_dinamicos[vl_peso_kg]=1
f_arr_nm_campos_dinamicos[vl_nota_fiscal]=1
f_arr_nm_campos_dinamicos[qt_produto]=1
f_arr_nm_campos_dinamicos[nm_produto]=1
f_arr_nm_campos_dinamicos[ncm]=1
f_arr_nm_campos_dinamicos[nm_marca]=1
f_arr_nm_campos_dinamicos[ds_modelo]=1
f_arr_nm_campos_dinamicos[vl_frete_empresa]=1
f_arr_nm_campos_dinamicos[vl_frete_peso]=1
f_arr_nm_campos_dinamicos[vl_outros]=1
f_arr_nm_campos_dinamicos[vl_advalorem]=1
f_arr_nm_campos_dinamicos[vl_frete_motorista]=1
f_arr_nm_campos_dinamicos[vl_frete_pedagio_motorista]=1
f_arr_nm_campos_dinamicos[vl_frete_ped_mot_saldo_adiantamento]=1
f_arr_nm_campos_dinamicos[nr_nota_fiscal]=1
f_arr_nm_campos_dinamicos[cd_pessoa_tomador]=1
f_arr_nm_campos_dinamicos[nm_pessoa_tomador]=1
f_arr_nm_campos_dinamicos[nr_chave_nf]=1
f_arr_nm_campos_dinamicos[ds_modelo_nf]=1
f_arr_nm_campos_dinamicos[pr_tolerancia_de_quebra]=1
f_arr_nm_campos_dinamicos[ds_quebra_sobre]=1
f_arr_nm_campos_dinamicos[vl_falta]=1
f_arr_nm_campos_dinamicos[vl_peso_dif]=1
f_arr_nm_campos_dinamicos[nm_unidade_operacional]=1
f_arr_nm_campos_dinamicos[nm_grupo_produto]=1
f_arr_nm_campos_dinamicos[nm_grupo_produto_transportado]=1
f_arr_nm_campos_dinamicos[vl_adiantamento]=1
f_arr_nm_campos_dinamicos[pr_adiantamento_motorista]=1
f_arr_nm_campos_dinamicos[vl_tarifa_empresa]=1
f_arr_nm_campos_dinamicos[vl_tarifa_motorista]=1
f_arr_nm_campos_dinamicos[pr_dif_frete]=1
f_arr_nm_campos_dinamicos[vl_base_empresa]=1
f_arr_nm_campos_dinamicos[vl_base_motorista]=1
f_arr_nm_campos_dinamicos[vl_desconto_carta_frete]=1
f_arr_nm_campos_dinamicos[vl_base_icms_issqn]=1
f_arr_nm_campos_dinamicos[vl_icms_issqn]=1
f_arr_nm_campos_dinamicos[vl_icms_st]=1
f_arr_nm_campos_dinamicos[vl_icms_diferenca]=1
f_arr_nm_campos_dinamicos[nr_cst]=1
f_arr_nm_campos_dinamicos[vl_pedagio_ctrc]=1
f_arr_nm_campos_dinamicos[vl_pedagio_pago_motorista]=1
f_arr_nm_campos_dinamicos[id_pedagio_ctrc]=1
f_arr_nm_campos_dinamicos[vl_pedagio_empresa]=1
f_arr_nm_campos_dinamicos[vl_pedagio_motorista]=1
f_arr_nm_campos_dinamicos[id_pedagio_motorista]=1
f_arr_nm_campos_dinamicos[vl_vale_combustivel]=1
f_arr_nm_campos_dinamicos[vl_corretor]=1
f_arr_nm_campos_dinamicos[nm_corretor]=1
f_arr_nm_campos_dinamicos[vl_base]=1
f_arr_nm_campos_dinamicos[vl_base_original]=1
f_arr_nm_campos_dinamicos[vl_comissao]=1
f_arr_nm_campos_dinamicos[vl_imposto_federal]=1
f_arr_nm_campos_dinamicos[vl_imposto_federal_debito]=1
f_arr_nm_campos_dinamicos[vl_imposto_federal_credito]=1
f_arr_nm_campos_dinamicos[vl_frete_valor]=1
f_arr_nm_campos_dinamicos[vl_custo]=1
f_arr_nm_campos_dinamicos[vl_acrescimo_motorista]=1
f_arr_nm_campos_dinamicos[vl_seguro]=1
f_arr_nm_campos_dinamicos[vl_seguro_descontado]=1
f_arr_nm_campos_dinamicos[id_seguradora]=1
f_arr_nm_campos_dinamicos[nm_pessoa_seguradora]=1
f_arr_nm_campos_dinamicos[vl_taxa_adm]=1
f_arr_nm_campos_dinamicos[pr_margem_resultado]=1
f_arr_nm_campos_dinamicos[vl_resultado]=1
f_arr_nm_campos_dinamicos[cd_lote_carregamento]=1
f_arr_nm_campos_dinamicos[ds_lote_carregamento]=1
f_arr_nm_campos_dinamicos[nr_cartao_vale_pedagio]=1
f_arr_nm_campos_dinamicos[nm_emissao_vale_pedagio]=1
f_arr_nm_campos_dinamicos[id_destino_mercadoria]=1
f_arr_nm_campos_dinamicos[id_enquadramento_federal]=1
f_arr_nm_campos_dinamicos[nr_ciot]=1
f_arr_nm_campos_dinamicos[nr_pgto_eletronico]=1
f_arr_nm_campos_dinamicos[cd_pessoa_adm_pgto_eletronico]=1
f_arr_nm_campos_dinamicos[nm_administradora]=1
f_arr_nm_campos_dinamicos[vl_km_rodado]=1
f_arr_nm_campos_dinamicos[nm_categoria]=1
f_arr_nm_campos_dinamicos[nr_embarque]=1
f_arr_nm_campos_dinamicos[ds_placa_embarque]=1
f_arr_nm_campos_dinamicos[cd_pessoa_motorista_embarque]=1
f_arr_nm_campos_dinamicos[nm_pessoa_embarque]=1
f_arr_nm_campos_dinamicos[dt_saida_embarque]=1
f_arr_nm_campos_dinamicos[cd_agencia_agenciador]=1
f_arr_nm_campos_dinamicos[nm_agencia_agenciador]=1
f_arr_nm_campos_dinamicos[cd_agencia_gerente]=1
f_arr_nm_campos_dinamicos[nm_agencia_gerente]=1
f_arr_nm_campos_dinamicos[cd_agencia_manifestador]=1
f_arr_nm_campos_dinamicos[nm_agencia_manifestador]=1
f_arr_nm_campos_dinamicos[cd_agencia_supervisor]=1
f_arr_nm_campos_dinamicos[nm_agencia_supervisor]=1
f_arr_nm_campos_dinamicos[cd_uf_origem]=1
f_arr_nm_campos_dinamicos[cd_uf_destino]=1
f_arr_nm_campos_dinamicos[cd_cidade_origem]=1
f_arr_nm_campos_dinamicos[cd_cidade_destino]=1
f_arr_nm_campos_dinamicos[id_cobrado]=1
f_arr_nm_campos_dinamicos[ds_observacao]=1
f_arr_nm_campos_dinamicos[ds_percurso]=1
f_arr_nm_campos_dinamicos[cd_pessoa_matriz]=1
f_arr_nm_campos_dinamicos[nm_pessoa_matriz]=1
f_arr_nm_campos_dinamicos[id_tipo]=1
f_arr_nm_campos_dinamicos[id_operacao]=1
f_arr_nm_campos_dinamicos[nr_ctrc_novo]=1
f_arr_nm_campos_dinamicos[nr_ctrc_complementado]=1
f_arr_nm_campos_dinamicos[nr_ordem]=1
f_arr_nm_campos_dinamicos[cd_agencia_ordem]=1
f_arr_nm_campos_dinamicos[nm_agencia_ordem]=1
f_arr_nm_campos_dinamicos[cd_usuario_ordem]=1
f_arr_nm_campos_dinamicos[nm_usuario_ordem]=1
f_arr_nm_campos_dinamicos[nr_chave]=1
f_arr_nm_campos_dinamicos[ds_di]=1
f_arr_nm_campos_dinamicos[nr_prefixo]=1
f_arr_nm_campos_dinamicos[ds_agencia_navegacao]=1
f_arr_nm_campos_dinamicos[vl_tara]=1
f_arr_nm_campos_dinamicos[ds_dta]=1
f_arr_nm_campos_dinamicos[ds_navio_saida]=1
f_arr_nm_campos_dinamicos[nr_atrac]=1
f_arr_nm_campos_dinamicos[ds_motivo_cancelamento]=1
f_arr_nm_campos_dinamicos[id_issqn_retido]=1
f_arr_nm_campos_dinamicos[dt_embarque]=1
f_arr_nm_campos_dinamicos[dt_chegada_destino]=1
f_arr_nm_campos_dinamicos[nr_solicitacao]=1
f_arr_nm_campos_dinamicos[nr_lacres]=1
f_arr_nm_campos_dinamicos[perna]=1
f_arr_nm_campos_dinamicos[nr_ctrc_primeira_perna]=1
f_arr_nm_campos_dinamicos[nr_doc_anterior]=1
f_arr_nm_campos_dinamicos[dt_emissao_doc_anterior]=1
f_arr_nm_campos_dinamicos[nr_nfse]=1
f_arr_nm_campos_dinamicos[id_pendente_emissao_nfse]=1
f_arr_nm_campos_dinamicos[pr_desconto_base_comissao_ctrc]=1
f_arr_nm_campos_dinamicos[pr_desconto_mercadoria_base_comissao_ctrc]=1
f_arr_nm_campos_dinamicos[vl_inss_patronal]=1
f_arr_nm_campos_dinamicos[ds_motivo_diaria]=1
f_arr_nm_campos_dinamicos[nr_pedido_pedagio]=1
f_arr_nm_campos_dinamicos[vl_inss_retido]=1
f_arr_nm_campos_dinamicos[vl_sest_senat]=1
f_arr_nm_campos_dinamicos[id_proprietario_veiculo]=1
f_arr_nm_campos_dinamicos[ds_operacao_minuta]=1
f_arr_nm_campos_dinamicos[vl_ibs]=1
f_arr_nm_campos_dinamicos[vl_cbs]=1
f_arr_nm_campos_dinamicos[nr_mdfe]=1
PARAMETROS

echo "→ Gerando relatório de $DATA_INI a $DATA_FIM..."
curl -sS -b "$COOKIES" -c "$COOKIES" -A "$UA" -L \
  -H "Origin: https://transjr.atua.com.br" \
  -H "Referer: $BASE/rel_ctrc_detalhado.php" \
  "${PARAMS[@]}" \
  -D "$ARQ_SAIDA.headers.txt" \
  -o "$ARQ_SAIDA.bin" \
  "$BASE/rel_ctrc_detalhado.php"

# ---------------------------------------------------------------------------
# 3. Descobre o que veio e dá a extensão certa
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
