# Projeção de faturamento: metodologia

Status: **implementado** nos PRs #207 (feriados), #208 (motor de projeção), #209 (tela, atrás da flag `revenue_projection`) e no PR da memória da projeção (seção 6).

## 1. Objetivo

Responder, a qualquer momento do mês ou da semana, a pergunta:

> Hoje, às 15:17, faturamos R$ X. No nosso ritmo, onde vamos fechar o mês (dia 30 às 23:59) e a semana (sábado às 23:59)?

A projeção aparece em **Inteligência > Projeção de faturamento**, com um card para o mês e outro para a semana.

## 2. O que é "faturamento" aqui

A projeção é de **faturamento**, ou seja, o frete bruto dos CT-es emitidos. **Não é arrecadação** (dinheiro recebido), que depende de prazo e de inadimplência.

Ela conta exatamente o mesmo que a tela **Faturamento** (`Tenant#billable_freights`):

- CT-es de frete (sem venda de veículo);
- ativos no Atua e não cancelados;
- fora dos emissores desconsiderados;
- pela data e hora de emissão (`issued_at`), no fuso de Brasília.

## 3. Fórmula

```
Projeção = Faturado até agora
         + Resto do dia de hoje
         + Σ (faturamento típico de cada dia que falta × fator do dia × correção do dia da semana)
```

- **Fator do dia:** 1 num dia normal; o fator de feriado, emenda, ponto facultativo ou fim de mês nos demais (4.4 e 4.6).
- **Correção do dia da semana:** quanto cada dia da semana tem faturado acima ou abaixo do típico nas últimas 8 semanas (4.7).

- **Mês:** do dia 1 às 00:00 até o último dia às 23:59.
- **Semana:** de domingo às 00:00 até sábado às 23:59, o mesmo início de semana da tela de Faturamento.

## 4. Passo a passo

### 4.1 "Agora" é a última importação do Atua

O horário de referência é o fim da **última importação concluída do Atua** (`Tenant#last_synced_at`), e não o relógio. Se a última importação terminou às 14:00, o faturado conta até 14:00 e o resto do dia é projetado a partir dali.

Usar o relógio puxaria a projeção para baixo a cada atraso de sincronização, porque o sistema acharia que nada foi faturado desde a última importação.

Limites:

- se a última importação for **anterior ao início do período**, a referência passa a ser o início do período (tudo é projetado);
- se a empresa **nunca importou**, a referência é o horário atual.

### 4.2 Faturamento típico de cada dia da semana

Para cada dia da semana (domingo, segunda, …, sábado):

1. pega o faturamento de cada um desses dias nas **últimas 12 semanas** (84 dias), lido do consolidado diário da memória (seção 6);
2. tira os **feriados, emendas, pontos facultativos e dias de fim de mês**, para não distorcer o típico;
3. usa a **mediana** desses valores.

A mediana, e não a média, para que um dia fora da curva (uma carga muito grande, um dia parado) não distorça o típico.

Só entram dias a partir do primeiro CT-e da empresa, para que um período sem dados não conte como dia sem faturamento.

### 4.3 O resto do dia de hoje

O sistema aprende a **curva do dia**: que parte do faturamento costuma sair até cada hora, separada por dia da semana, com as mesmas 12 semanas.

```
Resto de hoje = típico do dia × fator de feriado × (1 − parte já faturada até a hora de referência)
```

Exemplo: se numa quarta até as 15h costuma sair 70% do faturamento do dia, ainda faltam 30% do típico de uma quarta.

Sem histórico por hora, a curva é distribuída por igual ao longo das 24 horas.

### 4.4 Fator de feriado

Os feriados vêm do cadastro **Cadastros > Feriados**:

- os **nacionais** são gerados automaticamente para o ano anterior, o atual e o próximo, incluindo as emendas;
- os **estaduais e municipais** são cadastrados na tela.

O feriado reduz o faturamento típico do dia conforme o tipo:

| Tipo de dia | Fator inicial | Leitura |
|---|---|---|
| Feriado de segunda a sexta | 0,30 | fatura ~30% de um dia normal |
| Feriado no sábado | 0,80 | impacto pequeno |
| Emenda (dia útil entre feriado e fim de semana) | 0,60 | |
| Ponto facultativo (Carnaval, Corpus Christi) | 0,50 | |
| Feriado no domingo | 1,00 | sem ajuste |

A **emenda** é marcada automaticamente:

- feriado na **terça** → a **segunda** vira emenda;
- feriado na **quinta** → a **sexta** vira emenda.

#### Fator aprendido

Quando um tipo de dia tem **2 ou mais ocorrências no último ano** na memória, o fator deixa de ser o inicial e passa a ser aprendido:

```
observação = faturamento real do dia ÷ (típico previsto para ele × correção do dia da semana)
fator      = mediana das observações (entre 0 e 1)
```

### 4.5 Faixa provável

A mesma conta é refeita trocando a mediana por dois percentis:

- **percentil 25:** como se os dias que faltam fossem de uma semana mais fraca (limite inferior);
- **percentil 75:** como se fossem de uma semana mais forte (limite superior).

No começo do mês a faixa é larga: há pouco faturado e muitos dias pela frente. Ela vai estreitando conforme o mês avança.

### 4.6 Fim de mês

Os **3 últimos dias do mês que não são domingo** costumam faturar diferente (fechamento com clientes). Eles ficam fora do típico e recebem um fator próprio, aprendido com os fins de mês dos últimos 6 meses (pelo menos 6 dias), entre 0,5 e 2. Até lá, o fator é 1.

Com os dados locais, o fator aprendido foi **1,12**: os últimos dias do mês faturam 12% acima do típico.

### 4.7 Correção do dia da semana

A mediana das 12 semanas demora a acompanhar quando o faturamento está crescendo (ou caindo). Para corrigir isso, a memória compara, para cada dia da semana, o faturamento real com o típico que tinha sido previsto, nas **últimas 8 semanas**:

```
correção = mediana(faturamento real ÷ típico previsto), entre 0,80 e 1,25
```

Precisa de pelo menos 4 dias normais daquele dia da semana; até lá, a correção é 1.

## 5. Exemplo

Dados de teste: dias úteis com típico de R$ 1.000 e sábados com típico de R$ 500. Situação: quarta-feira, 11/11/2026 às 15h, com o feriado de 20/11 (sexta) cadastrado.

| Parte | Valor |
|---|---|
| Faturado de 01/11 até agora | R$ 8.500 |
| 13 dias úteis restantes × R$ 1.000 | R$ 13.000 |
| 3 sábados restantes × R$ 500 | R$ 1.500 |
| Feriado de 20/11: R$ 1.000 × 0,30 em vez de R$ 1.000 | − R$ 700 |
| **Projeção do mês** | **R$ 22.300** |

## 6. Memória da projeção

A memória são três tabelas no banco, atualizadas **toda madrugada às 6h** (`RevenueProjections::RefreshMemoryJob`) para cada empresa com CT-e:

| Tabela | O que guarda | Para que serve |
|---|---|---|
| `revenue_projection_daily_totals` | O faturamento de cada dia: total, nº de CT-es, faturamento por hora (24 valores), dia da semana e tipo do dia (normal, feriado em dia útil, feriado no sábado, emenda, ponto facultativo, fim de mês) | Base histórica do típico e da curva do dia, sem recalcular a partir dos CT-es |
| `revenue_projection_day_forecasts` | A previsão de cada dia, feita no início dele com o que se sabia até a véspera: típico, fator aplicado, previsto, faixa, real e erro | Mostra onde a projeção erra e alimenta o aprendizado |
| `revenue_projection_factors` | Os fatores aprendidos (feriados, emenda, ponto facultativo, fim de mês, correção de cada dia da semana), com o nº de dias que basearam cada um e se já foi aprendido ou ainda é o padrão | O motor lê os fatores daqui |

Ordem da atualização diária:

1. **Consolida os dias** até ontem. Os últimos 35 dias são refeitos sempre, para pegar cancelamentos e a reimportação do mês anterior (dia 3).
2. **Reclassifica os dias** pelo cadastro de feriados atual. Um feriado municipal cadastrado depois corrige o histórico.
3. **Preenche o real e o erro** de cada previsão já feita.
4. **Reaprende os fatores.**
5. **Prevê o dia de hoje.**

Na primeira execução, a memória é **reconstruída a partir do histórico**: os dias são consolidados desde o primeiro CT-e, e as previsões dos dias passados são refeitas semana a semana, cada uma só com os dados e os fatores que existiam antes daquele dia. Essas previsões ficam marcadas como reconstruídas (`backfilled`).

A tela mostra a memória na seção **Memória da projeção**: o erro médio por dia e a tendência dos últimos 90 dias, onde a projeção erra (por dia da semana, feriados e fim de mês) e o que ela aprendeu.

## 7. Precisão medida

Backtest com os dados locais: projeção às 17h dos dias 5, 10, 15, 20, 25 e 28 de setembro e outubro/2026 (mês), e de segunda a sexta às 17h de 07/09 a 07/11/2026 (semana). Em cada data, os fatores foram reaprendidos só com o que se sabia até ela.

| Versão | Erro médio no mês | Tendência no mês | Real dentro da faixa (mês) | Erro médio na semana |
|---|---|---|---|---|
| Sem memória (mediana + feriados) | 4,9% | −4,9% | 6 de 12 | 6,1% |
| + fim de mês | 4,7% | −4,6% | 6 de 12 | 6,0% |
| **+ fim de mês + correção do dia da semana** | **2,7%** | **−2,0%** | **9 de 12** | 6,5% |

A correção do dia da semana praticamente corta pela metade o erro do mês. Na semana, o erro fica no mesmo patamar.

## 8. Limitações conhecidas

- **Ainda fica um pouco abaixo do real no mês** (−2% em média no backtest).
- **Não prevê eventos novos.** Um contrato novo ou um cliente que parou só entram na conta conforme o faturamento real aparece nas semanas seguintes.
- **Poucos feriados no histórico:** enquanto houver menos de 2 do mesmo tipo no último ano, vale o fator inicial.
- **Empresa sem histórico:** a projeção é igual ao faturado, e a tela avisa.

## 9. Próximos passos

1. **Projeção por cliente, motorista e veículo**, com o mesmo método e a mesma memória (o consolidado diário por dimensão).

## 10. Onde está no código

| Parte | Arquivo |
|---|---|
| Cálculo | `app/command/revenue_projections/calculate_command.rb` |
| Previsão de um dia (típico, curva do dia, fatores) | `app/models/revenue_projection/forecaster.rb` |
| Tipo de cada dia (feriado, emenda, fim de mês) | `app/models/revenue_projection/calendar.rb` |
| Fatores lidos da memória | `app/models/revenue_projection/factor_set.rb` |
| Atualização diária da memória | `app/command/revenue_projections/refresh_memory_command.rb` |
| Consolidado diário, previsão do dia e aprendizado | `consolidate_days_command.rb`, `forecast_days_command.rb` e `learn_factors_command.rb` em `app/command/revenue_projections/` |
| Resultado (totais e faixa) | `app/models/revenue_projection/result.rb` |
| Dados do gráfico | `app/models/dashboard/revenue_projection.rb` |
| Tela | `app/controllers/revenue_projections_controller.rb` e `app/views/revenue_projections/` |
| Feriados nacionais | `app/command/holidays/seed_national_command.rb` |
