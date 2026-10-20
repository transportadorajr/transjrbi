# Relatórios da Atua: referência para importação

Documento gerado a partir dos arquivos reais exportados em 13/10/2026 (as fixtures em `spec/fixtures/files/atua/` são versões anonimizadas desses arquivos, com a mesma estrutura, os mesmos tipos, códigos e ligações; nomes, documentos, placas e valores mudam) (período de 01/10 a 13/10/2026 nos relatórios com data). Salve em `docs/atua/relatorios.md` no projeto. O Claude Code deve seguir este documento ao criar leitores, tabelas e importadores. Os nomes de colunas abaixo são os do relatório de origem; os nomes de tabelas, modelos e atributos no projeto são em inglês (AGENTS.md), e o mapeamento origem → atributo fica explícito em cada mapeador.

---

## 1. Formato dos arquivos (vale para os 5)

- **Excel binário de verdade (.xls, BIFF8 / Composite Document File V2)**, não HTML disfarçado. Uma única planilha, chamada `Planilha 1`.
- **O arquivo tem uma pequena corrupção na estrutura interna.** O `xlrd` do Python só abre com `ignore_workbook_corruption=True`. **Testar logo no início se `roo-xls`/`spreadsheet` (Ruby) abrem os 5 arquivos.** Se não abrirem, alternativas em ordem de preferência: (a) outra gem/abordagem tolerante; (b) converter com LibreOffice headless (`soffice --headless --convert-to xlsx`) e ler com `roo`; (c) último recurso: script Python com `xlrd` chamado pelo Ruby.
- **Linha 1 = totais**: traz a soma de cada coluna numérica (ex.: soma do frete, do peso, dos impostos); as colunas de texto ficam vazias. Não é um registro. Serve para conferir a leitura: a soma das linhas lidas deve bater com esse total.
- **Linha 2 = cabeçalho, dados a partir da linha 3.** Não há título, filtros impressos nem rodapé.
- **As chaves de acesso** (`nr_chave`, `nr_chave_nf`, `ds_chave_documento`) vêm com um espaço no fim (`"3126…7361 "`), e `nr_ciot` com dois. Sempre aplicar `strip`.
- **Os cabeçalhos são os nomes técnicos dos campos** (`cd_ctrc`, `vl_frete_empresa`…), iguais aos `f_arr_nm_campos_dinamicos[...]` do formulário. Usar os nomes como vêm (já estão em snake_case). Mapear sempre **pelo nome do cabeçalho, nunca pela posição**.
- **Números chegam tipados** (float). Códigos e números inteiros vêm como `80842.0`: converter para inteiro. **Valores monetários são gravados em centavos** (`bigint` com sufixo `_cents`, regra do AGENTS.md): converter o float para `BigDecimal` e depois `(valor * 100).round`. Pesos, quilometragens e percentuais ficam em `decimal`.
- **Algumas colunas misturam número e texto** (ex.: `nr_nota_fiscal` = `2082496.0` ou `"4199237, 4197775"`; `nr_cep` = `85815150.0` ou `"85.815-150"`; `nr_renavam` com zero à esquerda). Ler como texto, tirar o `.0` de números inteiros e preservar zeros à esquerda quando vierem em texto.
- **Células de data (tipo data do Excel) trazem como hora a hora em que o relatório foi gerado** (ex.: 01/10/2026 10:16:06 em todas as linhas do arquivo gerado às 10:16:06). **Gravar só a data** (`date`) e ignorar a hora.
- **Datas que vêm como texto** (estas têm hora real):
  - `rel_ctrc_detalhado.dt_emissao`: `"01/10/26 16:45"` → `dd/mm/aa hh:mm`, **ano com 2 dígitos**;
  - `rel_caixa_detalhado.dt_lancamento`: `"2026-10-01 09:18:04.633085"` (às vezes sem fração);
  - `rel_veiculo_terceiro_detalhado.dt_atualizacao`: `"2015-05-25 15:41:45"`.
  Todas no fuso `America/Sao_Paulo`.
- **Campos sim/não viram `datetime`** (sufixo `_at`, nunca boolean): usar a data correspondente da Atua quando existir (ex.: cancelado → `dt_cancelamento`); se não houver como converter, usar a data e hora atual da importação. "Não" → `nil`. Numa reimportação, preservar o datetime já gravado enquanto continuar "sim".
- Documentos (CNPJ/CPF) vêm formatados de jeitos diferentes (`17.469.701/0066-12`, `069.304.149/80`). Guardar o texto original e uma coluna normalizada só com dígitos para cruzamento.

---

## 2. Granularidade, chave e particularidades de cada relatório

### `rel_ctrc_detalhado` → `Atua::TransportDocument` (Frete, CE, CTRC, CT-e)
- **1 linha = 1 conhecimento.** Chave natural: **`cd_ctrc`** (código interno, único na amostra).
- `id_sintegra` diferencia os tipos: `CTRC` (série 1, com chave de acesso `nr_chave`, situação "Autorizado") e `CE` (série 0, sem chave, sem situação, sem MDF-e). Guardar como `tipo_documento`.
- `nr_ctrc` sozinho **não** é único entre filiais (`JR TRANSPORTES` usa 74xxx, `TRANSJR SABARA` usa 397…411). Para cruzar com outros relatórios use `nr_ctrc` + `ds_serie` + filial, ou `cd_ctrc` quando existir.
- **`nr_mdfe` pode ter vários MDF-e** separados por vírgula (`"40798, 40834"`) → relação N:N com manifestos (tabela de ligação, `Atua::TransportDocumentManifest`).
- **`nr_nota_fiscal` pode ter várias notas** (`"4200788, 4200787, 4200786"`) → guardar como array (array de string no Postgres). `nr_chave_nf` traz a chave de uma nota.
- `id_cobrado`: número da fatura **ou** o texto `"Não Cobrado"` → separar em número da fatura (integer, nulo) e `charged_at` (datetime pela regra de sim/não; nulo quando "Não Cobrado").
- `id_tipo`: `Normal` ou `Complemento de Valores` (complementos apontam o original em `nr_ctrc_complementado`).
- Pessoas: `cd_pessoa_embarque` (remetente), `cd_pessoa_entrega` (destinatário), `cd_pessoa_pagador`, `cd_pessoa_tomador`, `cd_pessoa_consignatario` — **todos existem no cadastro de clientes (`cd_pessoa`)** (100% na amostra). O motorista (`cd_pessoa_motorista`) **não** está no cadastro de clientes: guardar código, nome e CPF no próprio conhecimento.
- Veículo: `cd_veiculo` existe no cadastro de veículos (100%). `ds_placa_carreta` só foi achada em 84% dos casos no cadastro de veículos (o cadastro foi exportado com filtro de situação; ver seção 3).
- O relatório é pedido com `f_id_cancelado_sistema=0` e na amostra não há cancelados (`dt_cancelamento` sempre vazia). **Avaliar trazer também os cancelados**, para que um CT-e cancelado depois seja atualizado e não apenas "suma".
- Campos de valor mais relevantes para análise: `vl_frete_empresa` (frete total), `vl_frete_peso`, `vl_frete_valor`, `vl_outros`, `vl_pedagio_ctrc`, `vl_base_icms_issqn`, `vl_icms_issqn`, `vl_imposto_federal`, `vl_ibs`, `vl_cbs`, `vl_resultado`, `pr_margem_resultado`, `vl_peso` (toneladas), `vl_peso_kg`, `vl_nota_fiscal`, `vl_km_rodado`.

### `rel_manifesto_detalhado` → `Atua::Manifest` + `Atua::ManifestDocument`
- **1 linha = 1 documento (CT-e) dentro de um manifesto.** 390 linhas para 217 manifestos.
- Cabeçalho do manifesto, chave **`cd_manifesto`**: `id_modelo`, `nr_manifesto`, `ds_serie`, `dt_emissao`, `dt_saida`, `dt_encerramento` + `hr_encerramento` (hora em texto `"08:31"`, juntar com a data), `ds_placa`, `nm_filial`, `uf_empresa`, `cidade_empresa`, `nr_chave`, `vl_total_nfe_mdfe`, `ds_situacao` (`Normal`, `Encerrado`, `Cancelado`), `ds_observacao`.
- Por documento (variam dentro do mesmo manifesto), chave **`cd_manifesto` + `nr_ctrc`**: `nr_ctrc` (texto `"74130 / 1"` = número / série), `nr_nota_fiscal` (pode ser lista), `vl_nota_fiscal`, `vl_peso`, `qt_produto`, `vl_total`, `id_frete` (CIF/FOB), `nm_remetente`, `nm_destinatario`, `nm_cidade_origem` / `nm_cidade_destino` (formato `"UF/CIDADE"`, separar UF e cidade), `vl_km_calculado`, `vl_km_doc`.
- `nr_manifesto` é numerado por filial (a `TRANSJR SABARA` tem números baixos, como 189). Cruzar com o conhecimento por `nr_manifesto` + filial.
- `ds_observacao` traz a hora real de início da viagem (`"Início da viagem: 01/10/2026 10:14"`), as chaves dos CT-e vinculados e o percurso. Extrair `inicio_viagem_em` (datetime) dessa linha.
- Ligações conferidas: 100% dos `nr_mdfe` dos conhecimentos existem aqui; 388 de 390 `nr_ctrc` deste relatório existem nos conhecimentos (os 2 restantes provavelmente foram emitidos fora do período).

### `rel_caixa_detalhado` → `Atua::Expense`
- **1 linha = 1 lançamento**, chave **`cd_caixa`**. Exceção vista na amostra: o mesmo `cd_caixa` em 2 linhas idênticas, mudando só `pr_credito_icms` / `vl_credito_icms` (duas alíquotas de crédito). **Não somar a despesa duas vezes**: gravar uma vez, somar `vl_credito_icms` e guardar as linhas originais em `raw_data` (array).
- Traz **várias empresas** (`nm_pessoa_matriz`: JR TRANSPORTES, MME TRANSPORTES, MM ESPINOLA), porque o filtro de matriz foi vazio. Guardar `cd_pessoa_filial`, `nm_pessoa_filial` e `nm_pessoa_matriz` e permitir filtrar.
- Classificação: `cd_historico` / `nm_historico` (ex.: `COMBUSTIVEL - DIESEL`, `CHAPA / CARGA, DESCARGA`), `ds_despesa_viagem` (`Despesa da Viagem` / `Despesa Fora da Viagem`), `id_tipo_gasto` (Custo/Despesa), contas contábeis.
- Valores: `vl_lancamento`, `vl_desconto`, `vl_total`, `vl_lancamento_liquido`, créditos de PIS/COFINS/ICMS, `vl_total_retencoes`, `vl_pago_titulo`.
- Datas: `dt_lancamento` (texto com hora real) e `dt_lancamento_` (célula de data, mesma data) → usar a primeira como `lancado_em` e derivar `data_lancamento`; `dt_documento`, `dt_contabil`, `dt_quitacao`, `dt_movimento`.
- Ligações: `ds_placa` existe 100% em veículos; `cd_ctrc` / `nr_ctrc` (texto `"74071/1"`) apontam o conhecimento (só 17 de 27 estavam no período baixado de CT-e — normal, a despesa pode ser de CT-e de outro mês); `nr_viagem` + `dt_saida` + `nm_motorista_viagem` (texto `"802 / NOME"`, separar código e nome) identificam a viagem.
- `qt_rateio` e `qt_parcela` são informativos (a linha já traz o valor total; não dividir).

### `rel_cliente_detalhado` → `Atua::Customer`
- **1 linha = 1 pessoa**, chave **`cd_pessoa`** (único). Cadastro completo, sem período (4.833 pessoas).
- Campos principais: `nm_pessoa`, `nm_fantasia`, `nr_cpf_cnpj`, `tipo_pessoa`, `nr_ie` (número ou `"ISENTO"`), endereço (`nm_logradouro`, `ds_complemento`, `nm_bairro`, `nr_cep`, `cd_cidade`, `nm_cidade`, `cd_uf`, `ds_sigla`), contato (`nr_telefone`, `id_whatsapp`, `ds_email` — pode ter vários separados por `;`), `nm_atividade`, `id_exportador`, `forma_pagamento`, `prazo_pagamento`, `dt_cadastro`, `dt_ultima_emissao_cliente_pagador`, `id_situacao`.
- `dt_mes_atualizacao` + `dt_ano_atualizacao` (mês às vezes `"01"` em texto, às vezes `10.0`) → montar uma data `atualizado_em_mes` (primeiro dia do mês).
- Muitas colunas de configuração (`id_*`) podem ir só para `raw_data`.

### `rel_veiculo_terceiro_detalhado` → `Atua::Vehicle`
- **1 linha = 1 veículo**, chave **`cd_veiculo`** (único; `ds_placa` também é única). Apesar do nome, traz **próprios, terceiros e agregados** (`id_proprietario_veiculo`).
- Campos principais: `ds_placa`, `id_categoria` (`Caminhão / Cavalo`, `Carreta`, `Outros`), `id_tipo` / `cd_tipo_veiculo`, `id_rodado`, `id_carroceria`, `nm_marca` / `cd_marca`, `ds_modelo` (texto; às vezes numérico como `2528`), `dt_ano_fabricacao`, `dt_ano_modelo`, `nr_renavam` (preservar zeros à esquerda), `nr_chassi`, `ds_cor`, proprietário (`cd_pessoa_transportadora`, `nm_pessoa_transportadora`, `nr_cnpj_cpf`, `nr_antt`), motorista vinculado (`cd_motorista`, `nm_motorista`, `nr_cpf_motorista`, `nr_cnh`), `id_risco` (Habilitado/Vencido), `dt_vcto_dados`, `dt_atualizacao` (texto com hora real), `id_situacao`.

---

## 3. Pontos para decidir

1. **CT-e cancelados**: hoje o relatório exclui (`f_id_cancelado_sistema=0`). Recomendação: trazer também e gravar a situação.
2. **Veículos**: o relatório foi pedido com `f_id_situacao_cadastro=2`. 16% das placas de carreta dos CT-e não aparecem no cadastro baixado. Verificar se vale trazer todas as situações.
3. **Despesas de outras empresas** (MME, MM ESPINOLA): importar tudo e filtrar na análise, ou filtrar na origem pela matriz.
4. **Período dos movimentos**: CT-e por data de emissão; MDF-e e despesas por data de lançamento.

---

## 4. Dicionário de colunas (todas as colunas dos arquivos)

Tipos sugeridos a partir dos dados. Valores monetários são `bigint` em centavos (`_cents`), nunca `decimal`; `decimal` fica só para peso, quilometragem, quantidade e percentual. Não há colunas boolean: campos sim/não viram `datetime` com sufixo `_at`. "Preenchida" = % de linhas com valor na amostra. Colunas 0% podem ir só para `raw_data`.

## `rel_ctrc_detalhado` → `conhecimentos`

Amostra: 420 linhas, 199 colunas.

| Coluna | Tipo sugerido | Preenchida | Exemplo |
|---|---|---|---|
| `cd_ctrc` | integer | 100% | 80842 |
| `nr_ctrc` | integer | 100% | 397 |
| `ds_serie` | integer | 100% | 1 |
| `nr_cfop` | integer | 100% | 6352 |
| `id_sintegra` | string | 100% | CTRC |
| `ds_servico` | string | 100% | Normal |
| `id_situacao_cte` | string | 90% | Autorizado |
| `nr_contrato` | string | 0% |  |
| `nr_pedido` | string | 0% |  |
| `nr_ordem_compra` | string | 0% |  |
| `nr_liberacao_embarque` | string | 0% |  |
| `dt_cancelamento` | date (vazia na amostra) | 0% |  |
| `dt_emissao` | datetime (texto "dd/mm/aa hh:mm") | 100% | 01/10/26 16:45 |
| `dt_mes_emissao` | string (mm/aaaa) | 100% | 10/2026 |
| `dt_lancamento` | date (célula de data; ignorar a hora) | 100% | 01/10/2026 |
| `dt_chegada` | date (célula de data; ignorar a hora) | 100% | 03/10/2026 |
| `cd_pessoa_filial` | integer | 100% | 8042 |
| `nm_pessoa_filial` | string | 100% | TRANSJR SABARA |
| `cd_agencia` | integer | 100% | 2 |
| `nm_agencia` | string | 100% | JR TRANSPORTES |
| `nm_cidade_origem` | string | 100% | JOAO MONLEVADE |
| `ds_uf_origem` | string | 100% | MG |
| `nm_cidade_destino` | string | 100% | TRES LAGOAS |
| `ds_uf_destino` | string | 100% | MS |
| `cd_pessoa_usuario` | integer | 100% | 6001 |
| `nm_pessoa_usuario` | string | 100% | EMISSAO CTE |
| `cd_pessoa_embarque` | integer | 100% | 7752 |
| `nm_pessoa_remetente` | string | 100% | ARCELORMITTAL BRASIL S.A. |
| `nr_cnpj_cpf_remetente` | string | 100% | 17.469.701/0066-12 |
| `ds_endereco_remetente` | string | 100% | AVENIDA GETULIO VARGAS, 100 - CENTRO IND |
| `ds_uf_remetente` | string | 100% | MG |
| `nm_cidade_remetente` | string | 100% | JOAO MONLEVADE |
| `cd_pessoa_consignatario` | integer | 27% | 6870 |
| `nm_pessoa_consignatario` | string | 27% | TRANSJR TRANSPORTADORA LTDA |
| `nr_cnpj_cpf_consignatario` | string | 27% | 10.212.838/0002-83 |
| `ds_uf_consignatario` | string | 27% | PR |
| `nm_cidade_consignatario` | string | 27% | FOZ DO IGUACU |
| `cd_pessoa_consignatario_embarque` | integer | 4% | 9311 |
| `nm_pessoa_consignatario_embarque` | string | 4% | RDV TRANSPORTES E LOGISTICA MS |
| `cd_pessoa_entrega` | integer | 100% | 7761 |
| `nm_pessoa_destinatario` | string | 100% | METAL WIRE METALURGICA LTDA |
| `nr_cnpj_cpf_destinatario` | string | 78% | 08.968.756/0001-30 |
| `ds_endereco_destinatario` | string | 100% | AVENIDA ANTONIO TRAJANO DOS SANTOS, 01 - |
| `ds_uf_destinatario` | string | 100% | MS |
| `nm_cidade_destinatario` | string | 100% | TRES LAGOAS |
| `cd_pessoa_pagador` | integer | 100% | 7752 |
| `nm_pessoa_pagador` | string | 100% | ARCELORMITTAL BRASIL S.A. |
| `nr_cnpj_cpf_pagador` | string | 100% | 17.469.701/0066-12 |
| `ds_uf_pagador` | string | 100% | MG |
| `nm_cidade_pagador` | string | 100% | JOAO MONLEVADE |
| `cd_pessoa_motorista` | integer | 100% | 9267 |
| `nm_pessoa_motorista` | string | 100% | ALTAMIRO GOMES DA SILVA NETO DA LUZ |
| `nr_cpf_motorista` | string | 100% | 086.795.409/43 |
| `cd_veiculo` | integer | 100% | 812 |
| `ds_placa` | string | 100% | EXU0F72 |
| `ds_placa_carreta` | string | 100% | BEV4G50 |
| `nr_eixo` | integer | 100% | 6 |
| `nr_cnpj_cpf_proprietario_veiculo_doc` | string | 100% | 10.212.838/0001-00 |
| `cd_pessoa_proprietario_veiculo_doc` | integer | 100% | 2 |
| `nm_pessoa_proprietario_veiculo_doc` | string | 100% | TRANSJR TRANSPORTADORA LTDA |
| `id_enquadramento_proprietario_antt` | string | 100% | ETC |
| `ds_endereco_proprietario_doc` | string | 100% | RUA PADRE LUIZ LUISE, 198, JR TRANSPORTE |
| `cd_pessoa_proprietario_veiculo_posse` | integer | 100% | 2 |
| `nm_pessoa_proprietario_veiculo_posse` | string | 100% | TRANSJR TRANSPORTADORA LTDA |
| `ds_endereco_proprietario_posse` | string | 100% | RUA PADRE LUIZ LUISE, 198, JR TRANSPORTE |
| `vl_peso` | decimal | 100% | 1.917 |
| `vl_peso_kg` | decimal | 100% | 1917 |
| `vl_nota_fiscal` | bigint (centavos, `_cents`) | 100% | 8389.98 |
| `qt_produto` | decimal | 100% | 70 |
| `nm_produto` | string | 100% | FERRO (FIO MAQUINA/ VERGALHAO ROLO) |
| `ncm` | string | 100% | 7213 |
| `nm_marca` | string | 100% | MERCEDES-BENZ |
| `ds_modelo` | string | 100% | ACTROS 2548S |
| `vl_frete_empresa` | bigint (centavos, `_cents`) | 100% | 555.04 |
| `vl_frete_peso` | bigint (centavos, `_cents`) | 100% | 516.19 |
| `vl_outros` | bigint (centavos, `_cents`) | 100% | 0 |
| `vl_advalorem` | bigint (centavos, `_cents`) | 100% | 0 |
| `vl_frete_motorista` | bigint (centavos, `_cents`) | 100% | 0 |
| `vl_frete_pedagio_motorista` | bigint (centavos, `_cents`) | 100% | 0 |
| `vl_frete_ped_mot_saldo_adiantamento` | bigint (centavos, `_cents`) | 100% | 0 |
| `nr_nota_fiscal` | string (pode ser lista "123, 456") | 99% | 2082496 |
| `cd_pessoa_tomador` | integer | 100% | 7752 |
| `nm_pessoa_tomador` | string | 100% | ARCELORMITTAL BRASIL S.A. |
| `nr_chave_nf` | string | 99% | 3126081746970100661255000002082496173590 |
| `ds_modelo_nf` | string | 100% | 55 NF-e |
| `pr_tolerancia_de_quebra` | decimal | 83% | 0.25 |
| `ds_quebra_sobre` | string | 100% | Somente do Ultrapassado |
| `vl_falta` | string (texto "Kg x R$ 4.5386") | 100% | Kg x R$ 4.5386 |
| `vl_peso_dif` | string (texto) | 47% | Kgs x R$ 0.000 p/ Kg faltante |
| `nm_unidade_operacional` | string | 100% | FROTA PROPRIA |
| `nm_grupo_produto` | string (vazia na amostra) | 0% |  |
| `nm_grupo_produto_transportado` | string (vazia na amostra) | 0% |  |
| `ds_motivo_diaria` | string (vazia na amostra) | 0% |  |
| `dt_vencimento_titulo` | date[] (uma data por parcela, separadas por vírgula; ignorar a hora) | 84% | 29/10/2026 |
| `nr_pedido_pedagio` | string | 26% | 83726007442005872891 |
| `nr_doc_anterior` | string | 0% |  |
| `dt_emissao_doc_anterior` | date (vazia na amostra) | 0% |  |
| `vl_adiantamento` | bigint (centavos, `_cents`) | 47% | 0 |
| `pr_adiantamento_motorista` | decimal | 100% | 0 |
| `vl_tarifa_empresa` | bigint (centavos, `_cents`) | 100% | 516.19 |
| `vl_tarifa_motorista` | bigint (centavos, `_cents`) | 47% | 0 |
| `pr_dif_frete` | decimal | 100% | 100 |
| `vl_base_empresa` | bigint (centavos, `_cents`) | 100% | 516.1877162236675 |
| `vl_base_motorista` | bigint (centavos, `_cents`) | 100% | 0 |
| `vl_desconto_carta_frete` | bigint (centavos, `_cents`) | 47% | 0 |
| `vl_inss_retido` | bigint (centavos, `_cents`) | 47% | 0 |
| `vl_sest_senat` | bigint (centavos, `_cents`) | 47% | 0 |
| `vl_base_icms_issqn` | bigint (centavos, `_cents`) | 100% | 555.04 |
| `vl_icms_issqn` | bigint (centavos, `_cents`) | 100% | 38.85 |
| `vl_icms_st` | bigint (centavos, `_cents`) | 100% | 0 |
| `vl_icms_diferenca` | bigint (centavos, `_cents`) | 100% | 38.85 |
| `nr_cst` | string | 90% | 00 |
| `vl_pedagio_ctrc` | bigint (centavos, `_cents`) | 100% | 0 |
| `id_pedagio_ctrc` | string | 100% | Trajeto s/ Pedágio |
| `vl_pedagio_empresa` | bigint (centavos, `_cents`) | 100% | 0 |
| `vl_pedagio_motorista` | bigint (centavos, `_cents`) | 100% | 0 |
| `vl_pedagio_pago_motorista` | bigint (centavos, `_cents`) | 100% | 0 |
| `id_pedagio_motorista` | string | 47% | Trajeto s/ Pedagio |
| `vl_vale_combustivel` | bigint (centavos, `_cents`) | 47% | 0 |
| `vl_corretor` | bigint (centavos, `_cents`) | 0% |  |
| `nm_corretor` | string (vazia na amostra) | 0% |  |
| `vl_base` | bigint (centavos, `_cents`) | 100% | 0 |
| `vl_base_original` | bigint (centavos, `_cents`) | 0% |  |
| `vl_comissao` | bigint (centavos, `_cents`) | 100% | 0 |
| `vl_imposto_federal` | bigint (centavos, `_cents`) | 100% | 51.34 |
| `vl_imposto_federal_debito` | bigint (centavos, `_cents`) | 100% | 51.34 |
| `vl_imposto_federal_credito` | bigint (centavos, `_cents`) | 100% | 0 |
| `vl_frete_valor` | bigint (centavos, `_cents`) | 100% | 464.85 |
| `vl_custo` | bigint (centavos, `_cents`) | 100% | 0 |
| `vl_acrescimo_motorista` | bigint (centavos, `_cents`) | 100% | 0 |
| `vl_seguro` | bigint (centavos, `_cents`) | 100% | 0 |
| `vl_seguro_descontado` | bigint (centavos, `_cents`) | 47% | 0 |
| `id_seguradora` | string | 100% | Da Transportadora |
| `nm_pessoa_seguradora` | string | 100% | AKAD SEGUROS S.A |
| `vl_taxa_adm` | bigint (centavos, `_cents`) | 0% |  |
| `vl_inss_patronal` | bigint (centavos, `_cents`) | 100% | 0 |
| `pr_margem_resultado` | decimal | 100% | 83.75 |
| `vl_resultado` | bigint (centavos, `_cents`) | 100% | 0 |
| `cd_lote_carregamento` | integer | 0% |  |
| `ds_lote_carregamento` | string (vazia na amostra) | 0% |  |
| `nr_cartao_vale_pedagio` | string | 0% |  |
| `nm_emissao_vale_pedagio` | string | 100% | SEM VALE PEDÁGIO |
| `id_destino_mercadoria` | string | 100% | Nacional |
| `id_enquadramento_federal` | integer | 100% | 3 |
| `nr_ciot` | string | 47% | 5200357883199946   |
| `nr_pgto_eletronico` | string | 0% |  |
| `cd_pessoa_adm_pgto_eletronico` | integer | 47% | 9002 |
| `nm_administradora` | string | 47% | CIOT ANTT |
| `vl_km_rodado` | decimal | 97% | 1055 |
| `nm_categoria` | string | 100% | NAO ASSOCIADO |
| `nr_embarque` | string | 100% | EMBARQUE 692 |
| `ds_placa_embarque` | string | 56% | EXU0F72 |
| `cd_pessoa_motorista_embarque` | integer | 56% | 9267 |
| `nm_pessoa_embarque` | string | 56% | ALTAMIRO GOMES DA SILVA NETO DA LUZ |
| `dt_saida_embarque` | date (célula de data; ignorar a hora) | 56% | 01/10/2026 |
| `cd_agencia_agenciador` | integer | 9% | 2 |
| `nm_agencia_agenciador` | string | 9% | JR TRANSPORTES |
| `cd_agencia_gerente` | integer | 100% | 2 |
| `nm_agencia_gerente` | string | 100% | JR TRANSPORTES |
| `cd_agencia_manifestador` | integer | 100% | 2 |
| `nm_agencia_manifestador` | string | 100% | JR TRANSPORTES |
| `cd_agencia_supervisor` | integer | 9% | 2 |
| `nm_agencia_supervisor` | string | 9% | JR TRANSPORTES |
| `cd_uf_origem` | integer | 100% | 15 |
| `cd_uf_destino` | integer | 100% | 14 |
| `cd_cidade_origem` | integer | 100% | 2017 |
| `cd_cidade_destino` | integer | 100% | 1605 |
| `id_cobrado` | string (nº da fatura ou "Não Cobrado") | 100% | 131391 |
| `ds_observacao` | string | 100% | TR 6102659755## |
| `ds_percurso` | string | 100% | MG / JOAO MONLEVADE X MS / TRES LAGOAS |
| `cd_pessoa_matriz` | integer | 100% | 2 |
| `nm_pessoa_matriz` | string | 100% | JR TRANSPORTES |
| `id_tipo` | string | 100% | Normal |
| `id_operacao` | string | 100% | Normal |
| `nr_ctrc_novo` | string | 0% |  |
| `nr_ctrc_complementado` | integer | 2% | 74081 |
| `nr_ordem` | string | 0% |  |
| `cd_agencia_ordem` | integer | 0% |  |
| `nm_agencia_ordem` | string (vazia na amostra) | 0% |  |
| `cd_usuario_ordem` | integer | 0% |  |
| `nm_usuario_ordem` | string (vazia na amostra) | 0% |  |
| `nr_chave` | string | 90% | 3126101021283800036457001000000397103107 |
| `ds_motivo_cancelamento` | string (vazia na amostra) | 0% |  |
| `id_issqn_retido` | string (vazia na amostra) | 0% |  |
| `dt_embarque` | date (vazia na amostra) | 0% |  |
| `dt_chegada_destino` | date (vazia na amostra) | 0% |  |
| `nr_solicitacao` | string | 0% |  |
| `nr_lacres` | string | 0% |  |
| `pr_desconto_base_comissao_ctrc` | decimal | 0% |  |
| `pr_desconto_mercadoria_base_comissao_ctrc` | decimal | 0% |  |
| `id_proprietario_veiculo` | string | 100% | Próprio |
| `ds_operacao_minuta` | string (vazia na amostra) | 0% |  |
| `nr_nfse` | string | 0% |  |
| `id_pendente_emissao_nfse` | datetime (sim/não → `_at`) | 10% | Não |
| `perna` | integer | 100% | 0 |
| `nr_ctrc_primeira_perna` | string | 0% |  |
| `vl_ibs` | bigint (centavos, `_cents`) | 100% | 0.46 |
| `vl_cbs` | bigint (centavos, `_cents`) | 100% | 4.18 |
| `nr_mdfe` | string (pode ser lista "40798, 40834") | 87% | 183 |

## `rel_manifesto_detalhado` → `manifestos`

Amostra: 390 linhas, 30 colunas.

| Coluna | Tipo sugerido | Preenchida | Exemplo |
|---|---|---|---|
| `cd_manifesto` | integer | 100% | 41236 |
| `id_modelo` | integer | 100% | 58 |
| `nr_manifesto` | integer | 100% | 40772 |
| `ds_serie` | integer | 100% | 1 |
| `dt_saida` | date (célula de data; ignorar a hora) | 100% | 01/10/2026 |
| `ds_placa` | string | 100% | RHJ4E07 |
| `uf_empresa` | string | 100% | PR |
| `cidade_empresa` | string | 100% | CASCAVEL |
| `ds_observacao` | string | 100% | Início da viagem: 01/10/2026 10:14 Infor |
| `nm_filial` | string | 100% | JR TRANSPORTES |
| `nr_ctrc` | string ("74130 / 1" = número / série) | 100% | 74130 / 1 |
| `nr_nota_fiscal` | string (pode ser lista "123, 456") | 100% | 1679763 |
| `vl_nota_fiscal` | bigint (centavos, `_cents`) | 100% | 32082.17 |
| `id_frete` | string | 100% | CIF |
| `nm_remetente` | string | 100% | ARCELORMITTAL BRAS |
| `nm_destinatario` | string | 100% | ACEROS ASUNCION SA |
| `vl_peso` | decimal | 100% | 8043 |
| `qt_produto` | decimal | 100% | 8.043 |
| `vl_total` | bigint (centavos, `_cents`) | 100% | 3217.2 |
| `nm_agencia_origem` | string | 100% | JR TRANSPORTES |
| `nm_cidade_origem` | string | 100% | MG/JUIZ DE FORA |
| `nm_cidade_destino` | string | 100% | PR/FOZ DO IGUACU |
| `dt_emissao` | date (célula de data; ignorar a hora) | 100% | 01/10/2026 |
| `dt_encerramento` | date (célula de data; ignorar a hora) | 89% | 03/10/2026 |
| `hr_encerramento` | string (hh:mm) | 89% | 08:31 |
| `nr_chave` | string | 100% | 4126101021283800010058001000040772123378 |
| `vl_km_calculado` | decimal | 100% | 1705.5882704081196 |
| `vl_km_doc` | decimal | 100% | 1537 |
| `vl_total_nfe_mdfe` | bigint (centavos, `_cents`) | 100% | 112596.72 |
| `ds_situacao` | string | 100% | Encerrado |

## `rel_caixa_detalhado` → `despesas`

Amostra: 1218 linhas, 84 colunas.

| Coluna | Tipo sugerido | Preenchida | Exemplo |
|---|---|---|---|
| `dt_lancamento` | datetime (texto "aaaa-mm-dd hh:mm:ss.ffffff") | 100% | 2026-10-01 08:00:00 |
| `cd_caixa` | integer | 100% | 590252 |
| `cd_pessoa_favorecido` | integer | 100% | 1951 |
| `nr_cpf_cnpj_pessoa_favorecido` | string | 95% | 069.304.149/80 |
| `nm_pessoa_favorecido` | string | 100% | JEFFERSON ANDRE REMONATTO |
| `ds_sigla_uf_favorecido` | string | 100% | PR |
| `nm_pais_favorecido` | string | 100% | BRASIL |
| `cd_historico` | integer | 100% | 434 |
| `nm_historico` | string | 100% | ADMINISTRATIVO - SALARIOS, COMIS. E IRRF |
| `nm_caixa_financeiro` | string | 13% | ITAU |
| `nm_pessoa_filial` | string | 100% | MME TRANSPORTES |
| `nm_pessoa_matriz` | string | 100% | MME TRANSPORTES |
| `cd_pessoa_usuario` | integer | 98% | 1951 |
| `nm_pessoa_usuario` | string | 98% | JEFFERSON ANDRE REMONATTO |
| `dt_lancamento_` | date (célula de data; ignorar a hora) | 100% | 01/10/2026 |
| `dt_documento` | date (célula de data; ignorar a hora) | 100% | 30/09/2026 |
| `nm_atividade_principal_favorecido` | string (vazia na amostra) | 0% |  |
| `nm_logradouro_favorecido` | string | 100% | RUA TEIXEIRINHA |
| `nm_bairro_favorecido` | string | 89% | JD BRASILIA |
| `nr_endereco_favorecido` | string | 95% | 361 |
| `ds_complemento_favorecido` | string | 31% | CASA |
| `nr_cep_favorecido` | string | 89% | 85815150 |
| `nm_cidade_favorecido` | string | 100% | CASCAVEL |
| `dt_quitacao` | date (célula de data; ignorar a hora) | 26% | 06/10/2026 |
| `dt_contabil` | date (célula de data; ignorar a hora) | 100% | 30/09/2026 |
| `vl_lancamento` | bigint (centavos, `_cents`) | 100% | 7250 |
| `vl_desconto` | bigint (centavos, `_cents`) | 100% | 0 |
| `vl_total` | bigint (centavos, `_cents`) | 100% | 7250 |
| `vl_credito_pis` | bigint (centavos, `_cents`) | 100% | 0 |
| `vl_credito_cofins` | bigint (centavos, `_cents`) | 100% | 0 |
| `vl_total_retencoes` | bigint (centavos, `_cents`) | 100% | 0 |
| `vl_lancamento_liquido` | bigint (centavos, `_cents`) | 100% | 7250 |
| `vl_pago_titulo` | bigint (centavos, `_cents`) | 41% | 0 |
| `dt_quitacao_titulo` | date (célula de data; ignorar a hora) | 7% | 05/10/2026 |
| `ds_tipo_pagamento` | string | 7% | INTERNET ITAU |
| `cd_pessoa_filial` | integer | 100% | 2189 |
| `nr_documento` | string | 98% | 10200 |
| `ds_serie` | integer | 100% | 1 |
| `ds_complemento` | string | 54% | REF. SALARIO FIXO |
| `ds_chave_documento` | string | 44% | 4126090486841200150255300000010200193587 |
| `id_estoque` | integer | 100% | 0 |
| `cd_movimento` | integer | 41% | 131033 |
| `dt_movimento` | date (célula de data; ignorar a hora) | 41% | 06/10/2026 |
| `ds_despesa_viagem` | string | 100% | Despesa Fora da Viagem |
| `id_via_documento` | integer | 100% | 1 |
| `ds_via_documento` | string | 100% | 1ª Via |
| `proprietario_posse` | string | 78% | TRANSJR TRANSPORTADORA LTDA |
| `ds_placa` | string | 78% | UAV4A05 |
| `cd_veiculo_manutencao` | integer | 0% |  |
| `ds_modelo` | string | 78% | SCANIA/S500 A6X2 |
| `dt_conferencia` | date (vazia na amostra) | 0% |  |
| `nm_pessoa_conferencia` | string (vazia na amostra) | 0% |  |
| `nr_viagem` | string | 41% | 2500653 |
| `dt_saida` | date (célula de data; ignorar a hora) | 41% | 01/09/2026 |
| `dt_chegada` | date (célula de data; ignorar a hora) | 4% | 30/09/2026 |
| `nm_motorista_viagem` | string | 41% | 802 / MAIKON RODRIGO DE LIMA |
| `id_modelo` | string | 100% | Recibo |
| `nr_contabilidade` | string | 81% | 1104 |
| `nr_classificacao_contabilidade` | string | 78% | 32170043 |
| `nr_acumulador` | string | 97% | 5111 |
| `nr_cfop` | integer | 54% | 1653 |
| `vl_base` | bigint (centavos, `_cents`) | 43% | 3281.1 |
| `pr_aliquota` | decimal | 35% | 111.93 |
| `vl_icms` | bigint (centavos, `_cents`) | 43% | 3672.6 |
| `vl_isento` | bigint (centavos, `_cents`) | 77% | 0 |
| `vl_outras` | bigint (centavos, `_cents`) | 47% | 7250 |
| `vl_base_ibs_cbs` | bigint (centavos, `_cents`) | 0% |  |
| `vl_cbs` | bigint (centavos, `_cents`) | 0% |  |
| `vl_ibs_estadual` | bigint (centavos, `_cents`) | 0% |  |
| `vl_ibs_municipal` | bigint (centavos, `_cents`) | 0% |  |
| `vl_ibs` | bigint (centavos, `_cents`) | 0% |  |
| `cd_ctrc` | integer | 2% | 80750 |
| `nr_ctrc` | string ("74071/1" = número/série) | 2% | 74071/1 |
| `id_tipo_gasto` | string | 5% | Custo |
| `arquivo_anexo` | datetime (sim/não → `_at`) | 100% | Não |
| `COFINS` | bigint (centavos, `_cents`) | 0% | 11.9 |
| `CSLL` | bigint (centavos, `_cents`) | 0% | 3.26 |
| `IRPJ` | bigint (centavos, `_cents`) | 0% |  |
| `ISSQN` | bigint (centavos, `_cents`) | 0% | 23.55 |
| `ds_observacao_titulo` | string | 7% | CHAVE PIX - TELEFONE (45)99966-2431 PANI |
| `qt_rateio` | integer | 100% | 1 |
| `qt_parcela` | integer | 41% | 1 |
| `pr_credito_icms` | decimal | 39% | 12 |
| `vl_credito_icms` | bigint (centavos, `_cents`) | 39% | 393.74 |

## `rel_cliente_detalhado` → `clientes`

Amostra: 4833 linhas, 60 colunas.

| Coluna | Tipo sugerido | Preenchida | Exemplo |
|---|---|---|---|
| `cd_pessoa` | integer | 100% | 294 |
| `nm_pessoa` | string | 100% | 100-TL ARMAZENS GERAIS LTDA. |
| `nm_fantasia` | string | 9% | 100-TL ARMAZENS GERAIS LTDA. |
| `cd_cidade` | integer | 100% | 1605 |
| `nm_cidade` | string | 100% | TRES LAGOAS |
| `cd_uf` | integer | 100% | 14 |
| `ds_sigla` | string | 100% | MS |
| `nm_logradouro` | string | 100% | ROD.MS395 TRES LAGOAS/BRASILANDIA, 0 |
| `ds_complemento` | string | 17% | SALA B LT GJAS R P |
| `nm_bairro` | string | 99% | ZONA RURAL |
| `nr_cep` | string | 98% | 79602970 |
| `nr_telefone` | string | 83% | (45)3224-2867 |
| `id_whatsapp` | datetime (sim/não → `_at`) | 83% | Não |
| `ds_email` | string | 27% | advocacia.bruno@hotmail.com |
| `nr_ie` | string | 99% | 283505230 |
| `forma_pagamento` | string | 9% | DEPOSITO CONTA CORRENTE |
| `prazo_pagamento` | string | 9% | 10 DIAS |
| `dt_base_prazo_pagamento` | string | 0% | Data Embarque |
| `pr_limite_adiantamento` | decimal | 0% |  |
| `vl_nota_fiscal_maximo_ctrc` | bigint (centavos, `_cents`) | 0% |  |
| `vl_credito` | bigint (centavos, `_cents`) | 0% |  |
| `vl_saldo` | bigint (centavos, `_cents`) | 0% |  |
| `cd_usuario_alteracao` | integer | 0% |  |
| `nm_usuario_alteracao` | string (vazia na amostra) | 0% |  |
| `dt_alteracao` | date (vazia na amostra) | 0% |  |
| `vl_aviso` | bigint (centavos, `_cents`) | 0% |  |
| `dt_ultima_emissao_cliente_pagador` | date (célula de data; ignorar a hora) | 26% | 18/03/2020 |
| `dt_cadastro` | date (célula de data; ignorar a hora) | 100% | 13/04/2015 |
| `dt_mes_atualizacao` | integer | 100% | 10 |
| `dt_ano_atualizacao` | integer | 100% | 2024 |
| `nr_cpf_cnpj` | string | 98% | 10.622.725/0001-75 |
| `id_situacao` | string | 100% | Normal |
| `nm_atividade` | string | 86% | OUTROS |
| `id_obrigatoriedade_peso_chegada` | string | 94% | Obrigatório |
| `id_exportador` | datetime (sim/não → `_at`) | 100% | Sim |
| `id_limite_quebra` | string | 28% | Sem quebra |
| `id_pgto_frete_motorista` | string | 100% | Peso de Saída |
| `id_pgto_frete_empresa` | string | 100% | Peso de Saída |
| `id_impressao_vl_frete` | string | 100% | Frete |
| `tipo_pessoa` | string | 100% | Pessoa Jurídica |
| `id_documento_cobranca` | string | 99% | 1ª Via |
| `id_pedagio` | string | 99% | Não Obrigatório |
| `id_documento_cobranca_entrega` | string | 99% | Reter 1ª Via CTRC |
| `id_obrigatorio_comprovante_entrega` | string | 100% | Não Obrigatório |
| `id_responsavel_digitalizacao_comprovante_entrega` | string (vazia na amostra) | 0% |  |
| `id_obrigatorio_ticket_balanca` | string | 100% | Obrigatório |
| `id_responsavel_digitalizacao_ticket_balanca` | string (vazia na amostra) | 0% |  |
| `id_optante_simples` | datetime (sim/não → `_at`) | 1% | NAO |
| `dt_consulta_optante_simples` | date (célula de data; ignorar a hora) | 1% | 20/05/2020 |
| `pr_limite_quebra` | decimal | 0% |  |
| `qt_limite_quebra` | decimal | 0% |  |
| `vl_limite_quebra` | bigint (centavos, `_cents`) | 0% |  |
| `cd_pessoa_seguradora` | integer | 0% |  |
| `nm_pessoa_seguradora` | string (vazia na amostra) | 0% |  |
| `ds_observacao` | string | 0% | Conta para depositar a descarga: banco i |
| `nr_contabilidade_debito` | string | 1% | 43 |
| `nr_contabilidade_adiantamento_cliente` | string | 0% |  |
| `nr_contabilidade_credito` | string | 0% | 664 |
| `nr_contabilidade_adiantamento` | string | 0% |  |
| `nr_contabilidade_adiantamento_fornecedor` | string | 0% |  |

## `rel_veiculo_terceiro_detalhado` → `veiculos`

Amostra: 1391 linhas, 51 colunas.

| Coluna | Tipo sugerido | Preenchida | Exemplo |
|---|---|---|---|
| `nm_pessoa` | string | 100% | R.WELP JUNIOR - TRANSPORTES |
| `id_atualizado` | integer | 100% | 0 |
| `dt_validade` | date (vazia na amostra) | 0% |  |
| `dt_vcto_dados` | date (célula de data; ignorar a hora) | 100% | 21/11/2015 |
| `dt_atualizacao` | datetime (texto "aaaa-mm-dd hh:mm:ss") | 100% | 2015-05-25 15:41:45 |
| `id_situacao` | string | 100% | Normal |
| `ds_placa` | string | 100% | AGL9451 |
| `id_tipo` | string | 100% | CARRETA GRADE BAIXA TRUCADA |
| `dt_ano_fabricacao` | integer | 100% | 1994 |
| `id_categoria` | string | 100% | Carreta |
| `dt_ano_modelo` | integer | 87% | 1994 |
| `nm_marca` | string | 100% | GUERRA |
| `ds_modelo` | string | 100% | 1234 |
| `cd_veiculo` | integer | 100% | 152 |
| `cd_veiculo_conjunto_cavalo` | integer | 0% |  |
| `nr_renavam` | string | 99% | 00661093581 |
| `cd_pessoa_transportadora` | integer | 100% | 240 |
| `nm_pessoa_transportadora` | string | 100% | R.WELP JUNIOR - TRANSPORTES |
| `nr_cnpj_cpf` | string | 57% | 05.505.302/0001-35 |
| `nr_antt` | string | 51% | 3755990 |
| `ds_observacao` | string | 0% | CARRETA LS |
| `cd_motorista` | integer | 37% | 760 |
| `nm_motorista` | string | 37% | LUIZ DIAS DE FREITAS |
| `nr_cpf_motorista` | string | 27% | 804.220.639/91 |
| `nr_cnh` | string | 36% | 947606890 |
| `cd_marca` | integer | 100% | 39 |
| `id_risco` | string | 100% | Vencido |
| `dt_mes_cadastro` | integer | 100% | 04 |
| `dt_ano_cadastro` | integer | 100% | 2015 |
| `dt_mes_atualizacao` | integer | 100% | 05 |
| `dt_ano_atualizacao` | integer | 100% | 2015 |
| `cd_tipo_veiculo` | integer | 100% | 25 |
| `ds_sigla` | string | 100% | PR |
| `cd_uf` | integer | 100% | 18 |
| `nm_cidade` | string | 100% | CASCAVEL |
| `cd_cidade` | integer | 100% | 2895 |
| `id_proprietario_veiculo` | string | 100% | Terceiro |
| `id_rodado` | string | 100% | Utilitário |
| `id_carroceria` | string | 100% | Aberta |
| `nm_empresa_rastreador` | string | 0% | ONIXSAT |
| `id_assoalho` | string | 0% | Ferro |
| `vl_comprimento` | decimal | 0% |  |
| `vl_largura` | decimal | 0% |  |
| `vl_altura` | decimal | 0% |  |
| `nr_telefone_proprietario_doc` | string | 95% | (45)99975-0125 |
| `id_whatsapp_proprietario_doc` | datetime (sim/não → `_at`) | 95% | Não |
| `nr_telefone_motorista` | string | 36% | (45)99815-7621 |
| `id_whatsapp_motorista` | datetime (sim/não → `_at`) | 36% | Não |
| `nr_chassi` | string | 63% | 9MB694024024YB236668 |
| `ds_cor` | string | 53% | PRETA |
| `id_alto_desempenho` | datetime (sim/não → `_at`) | 100% | Não |
