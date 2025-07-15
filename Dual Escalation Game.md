
# Dual Escalation game

In the Dual Escalation game, participants deposit both ETH and REP into the system. To advance their side, participants invest a certain amount of REP, denoted as `repInvestment(t)`, and ETH, denoted as `ethInvestment(t)`. These investments are then matched by the opposing side to increase the delay.

The players who delay the oracle pay a cost represented by `grantOiHolders(t)`, which corresponds to the fees paid by open interest (OI) holders to the system. This cost is split equally between both sides.

The winning side receives their ETH investment back in REP. To facilitate this, the system requires a `REP/ETH` price oracle to ensure there is enough REP to compensate the winners for their contribution to the OI holders. This oracle does not need to be perfectly accurate because the winners anticipate a significant profit; minor inaccuracies in the price can be absorbed by that profit margin. The variable `α` can be adjusted upwards to accommodate greater inaccuracies in the price oracle.

```math
\begin{aligned}
\text{repInvestment}(t) &= \max \left(
\frac{2}{5}\alpha \cdot \text{grantOiHolders}(t) \cdot \frac{REP}{ETH}, \quad
\text{Fork Treshold} \cdot \frac{t}{tMax} + \left( \text{Fork Treshold} + \text{grantOiHolders}(tMax) \cdot \frac{REP}{ETH} \right) \cdot \left(\frac{t}{tMax}\right)^k
\right)\\[1.5em]
\text{repInvestment}(tMax) &= \text{Fork Treshold}+\text{grantOiHolders}(t)\frac{REP}{ETH} \\[1.5em]
\text{ethInvestment}(t) &= \frac{1}{2}\text{grantOiHolders}(t)\\[1.5em]
\text{grantOiHolders}(t) &= \text{Single Market Open Interest} \cdot \left( 1 - e^{- \text{oiFee} \cdot t} \right) \\[1.5em]
\text{repBurn}(t) &= \frac{1}{5} \text{repInvestment(t)} \\[1.5em]

k &= 5, \quad k \in [2, \infty[ \\[0.5em]
\alpha &= 1, \quad \alpha \in [1, \infty[ \\[0.5em]
\end{aligned}
```

```math
\text{Total Profit in REP} = \frac{2 \cdot (\text{repInvestment(t)} + \text{ethInvestment(t)}\frac{REP}{ETH}) - \text{grantOiHolders(t)}\frac{REP}{ETH} - \text{repBurn(t)}}{\text{repInvestment(t)} + \text{ethInvestment(t)}\frac{REP}{ETH}} \geq \frac{4}{5}
```

When the game ends, either to timeout or fork:
1) Open Interest holders are paid $\text{grantOiHolders}(t)$ in $ETH$
2) Winner is paid $2 \cdot (\text{repInvestment(t)} + \text{ethInvestment(t)}\frac{REP}{ETH}) - \text{grantOiHolders(t)}\frac{REP}{ETH} - \text{repBurn(t)}$ worth in $REP$
3) REP is being burnt: $\text{repBurn(t)}$ $REP$

Since the `REP/ETH` price can change over the course of the game, the system fixes the `REP/ETH` rate at the time of each contribution. This ensures that both sides receive the same effective price for each second of escalation, maintaining fairness regardless of when the contribution is made.
