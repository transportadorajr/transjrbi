# Projeção de faturamento: metodologia

Status: **implementado** nos PRs #207 (feriados), #208 (motor de projeção) e #209 (tela, atrás da flag `revenue_projection`).

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
         + Σ (faturamento típico de cada dia que falta × fator de feriado)
```

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

1. pega o faturamento de cada um desses dias nas **últimas 12 semanas** (84 dias);
2. tira os **feriados, emendas e pontos facultativos**, para não puxar o típico para baixo;
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

Quando um tipo de dia tem **2 ou mais feriados no último ano**, o fator deixa de ser o inicial e passa a ser aprendido com o histórico:

```
observação = faturamento real do feriado ÷ mediana do mesmo dia da semana nas 4 semanas antes e depois
fator      = mediana das observações (entre 0 e 1)
```

Com os dados atuais, o fator aprendido para feriado em dia útil foi **0,32** (de 12/10 e 02/11/2026), bem perto do 0,30 inicial.

### 4.5 Faixa provável

A mesma conta é refeita trocando a mediana por dois percentis:

- **percentil 25:** como se os dias que faltam fossem de uma semana mais fraca (limite inferior);
- **percentil 75:** como se fossem de uma semana mais forte (limite superior).

No começo do mês a faixa é larga: há pouco faturado e muitos dias pela frente. Ela vai estreitando conforme o mês avança.

## 5. Exemplo

Dados de teste: dias úteis com típico de R$ 1.000 e sábados com típico de R$ 500. Situação: quarta-feira, 11/11/2026 às 15h, com o feriado de 20/11 (sexta) cadastrado.

| Parte | Valor |
|---|---|
| Faturado de 01/11 até agora | R$ 8.500 |
| 13 dias úteis restantes × R$ 1.000 | R$ 13.000 |
| 3 sábados restantes × R$ 500 | R$ 1.500 |
| Feriado de 20/11: R$ 1.000 × 0,30 em vez de R$ 1.000 | − R$ 700 |
| **Projeção do mês** | **R$ 22.300** |

## 6. Precisão medida

Backtest com os dados reais, comparando a projeção feita em cada data com o fechamento real:

| Período | Erro da projeção |
|---|---|
| Mês de setembro/2026 (dias 5 a 28, às 17h) | de −5,4% a +0,5% |
| Mês de outubro/2026 (dias 5 a 28, às 17h) | de −7,6% a −1,7% |
| Semana de 01/11 a 07/11/2026, de terça a sábado | de +1,0% a +7,0% |
| Semana de 01/11 a 07/11/2026, no próprio feriado (02/11) | +17,7% |

## 7. Limitações conhecidas

- **Tende a ficar abaixo do real no mês.** A mediana das 12 semanas demora a acompanhar quando o faturamento está crescendo, e pode haver um pico de fim de mês que ainda não é modelado. Em outubro, o real ficou acima da faixa provável.
- **Não prevê eventos novos.** Um contrato novo ou um cliente que parou só entram na conta conforme o faturamento real aparece nas semanas seguintes.
- **Feriado no dia de hoje:** enquanto houver menos de 2 feriados do mesmo tipo no último ano, vale o fator inicial, que pode não refletir a empresa.
- **Empresa sem histórico:** a projeção é igual ao faturado, e a tela avisa.

## 8. Próximos passos

1. **Memória de projeções:** guardar a projeção em horários fixos (8h, 12h, 17h) e comparar com o real no fechamento, medindo erro e viés.
2. **Projeção por cliente, motorista e veículo**, com o mesmo método.
3. **Efeito de fim de mês e correção de viés**, usando a memória de projeções para corrigir a tendência de ficar abaixo do real.

## 9. Onde está no código

| Parte | Arquivo |
|---|---|
| Cálculo | `app/command/revenue_projections/calculate_command.rb` |
| Faturamento típico e curva do dia | `app/models/revenue_projection/baseline.rb` |
| Fatores de feriado | `app/models/revenue_projection/holiday_factors.rb` |
| Resultado (totais e faixa) | `app/models/revenue_projection/result.rb` |
| Dados do gráfico | `app/models/dashboard/revenue_projection.rb` |
| Tela | `app/controllers/revenue_projections_controller.rb` e `app/views/revenue_projections/` |
| Feriados nacionais | `app/command/holidays/seed_national_command.rb` |
