# Price Oracle

The Price Oracle PLACEHOLDER uses is heavily based on the [Open Oracle Design](https://ethresear.ch/t/proposal-for-a-trust-minimized-price-oracle/22971). 

Open Oracle is an optimistic oracle that allows participants to submit price reports for a token pair (here REP/ETH) and disputes can be raised within a settlement window (10 blocks) if a report is deemed inaccurate. We assume that an Ethereum validator cannot censor 10 blocks in a row to timeout the oracle, making the price oracle to resolve into wrong price.

The system involves three stages:
1) **Report creation** - The protocol initiates a query for the market to find the correct REP/ETH price. The protocol posts a bounty of $\text{Initial Reporter Bounty}$
2) **Initial report submission** - The first reporter submits their report on the price by submiting ($\text{Initial Rep Stake}$ of REP and $\text{Initial ETH Stake}$) of ETH, where the price is implied by the ratio of these.
3) **Dispute mechanism** - Other participants can dispute the report by submitting a better price by swapping against previous disputer and posting escalated amount of money at stake (up to ).
4) **Timeout** - If no disputes are posted after 10 blocks (dispute window), the oracle ends and the final price is reported. The final disputers stake is returned to them.

## Initial reporter
The Price Oracle work in a way that first initial reporter posts REP and ETH stakes ($\text{Initial Stake}_{REP}$ and $\text{Initial Stake}_{ETH}$) on the oracle such that:
```math
\text{Initial Implied Price}_{REP/ETH} = \frac{\text{Initial Stake}_{REP}}{\text{Initial Stake}_{ETH}}
```
The initial reporter is paid $\text{Initial Reporter Bounty}$ in REP as reward to do this report. 

If no-one disputes the initial reporter, the initial reporter makes profit of:
```math
\text{Profit}_{ETH} = \text{Initial Reporter Bounty} \cdot \frac{REP}{ETH} - \text{gasFees} 
```

## Disputing
The initial report or previous report can be disputed by swapping against the previous reporters balance.

The disputer has to send following amounts to the contract:

Depending on which token the disputer wants to send to initial reporter/previous disputer, the disputer sends following balances to the contract:
| Swap Token | $\text{Amount To Send}_{ETH}$ | $\text{Amount To Send}_{REP}$ |
| ------------- | ------------- | ------------- |
| ETH  | $\text{Amount To Send Previous Reporter}_{ETH} + \text{New Contract Stake}_{ETH} + \text{Fee}_{ETH}$ | $\text{New Contract Stake}_{REP} - \text{Previous Contract Stake}_{REP}$ |
| REP  | $\text{New Contract Stake}_{ETH} - \text{Previous Contract Stake}_{ETH}$ | $\text{Amount To Send Previous Reporter}_{REP} + \text{New Contract Stake}_{REP} + \text{Fee}_{REP}$|

If $\text{Amount To Send}$s are negative, they sender gets a refund by the amount and does not need to send any of that token.

If swap token is ETH, we send ETH to the previous reporter, and REP otherwise: 
```math
\text{Amount To Send Previous Reporter}_{token} = \text{Previous Contract Stake}_{token}
```

The previous participant then in total receives double amount of this token:
```math
\begin{array}{l}
\text{Previous Reporter Gain}_{Token} = 2 \cdot \text{Previous Contract Stake}_{Token} \\
\text{Previous Reporter Gain}_{\text{Other Token}} = 0
\end{array}
```

The contract is then left with $\text{New Contract REP Stake}$ REP and $\text{New Contract ETH Stake}$ ETH, with implied price:
```math
\text{New Implied Price}_{REP/ETH} = \frac{\text{New Contract REP Stake}}{\text{New Contract ETH Stake}}
```

We also require the REP stake is increased by $\text{Escalation}$ amount uness we have reached the Escalation Halt where we don't increase the stake in the contract.
```math
\text{New Contract REP Stake} = \min(\text{Escalation Halt}, \text{Previous Contract REP Stake}\cdot(1+\text{Escalation}) )
```

The fees are calculated based on the previous balances:
```math
\begin{array}{l}
\text{Fee}_{REP} = \text{Previous Contract REP Stake}\cdot \text{Protocol Fee} \\
\text{Fee}_{ETH} = \text{Previous Contract ETH Stake}\cdot \text{Protocol Fee}
\end{array}
```

These fees will go directly to the PLACEHOLDER.

### Disputing profit

#### ETH Side
If $\text{Correct Price}_{REP/ETH}\cdot \text{Oracle Accuracy} < \text{Previous Implied Price}_{REP/ETH}$, the disputer should use ETH to swap, the profit that last disputer gets is:
```math
\text{Profit}_{ETH} = \frac{\text{Previous Contract Stake}_{REP}}{\text{Correct Price}_{REP/ETH}} - \text{Previous Contract Stake}_{ETH}\cdot(1 + \text{Protocol Fee}) - \text{Gas Fee}
```

We can then compute when this is profitable:
```math
\frac{\text{Previous Implied Price}_{REP/ETH}}{\text{Correct Price}_{REP/ETH}} > (1+\text{Protocol Fee}) + \frac{\text{Gas Fee}}{\text{Previous Contract Stake}_{ETH}}
```

#### REP Side
If $\text{Correct Price}_{REP/ETH} > \text{Previous Implied Price}_{REP/ETH}\cdot \text{Oracle Accuracy}$, the disputer should use ETH to swap, the profit that last disputer gets is:
```math
\text{Profit}_{ETH} = \text{Previous Contract Stake}_{ETH} - \text{Previous Contract Stake}_{REP}\cdot \frac{(1 + \text{Protocol Fee})}{\text{Correct Price}_{REP/ETH}}- \text{Gas Fee}
```
And this is profitable When:
$$
\frac{\text{Previous Implied Price}_{REP/ETH}}{\text{Correct Price}_{REP/ETH}} < \frac{1 - \text{Gas Fee}/\text{Previous Contract Stake}_{ETH}}{1+\text{Protocol Fee}}
$$

We can calculate minima values for contract stakes from these, to ensure that if the oracle is misprised, the next reporter can profit:
```math
\begin{array}{l}
\text{Previous Contract Stake}_{ETH} > \frac{\text{Gas Fee}}{\frac{\text{Previous Implied Price}_{REP/ETH}}{\text{Correct Price}_{REP/ETH}} - (1+\text{Protocol Fee})} \\
\text{Previous Contract Stake}_{ETH} \;>\; \frac{\text{Gas Fee}}{\,1 - \dfrac{\text{Previous Implied Price}_{REP/ETH}}{\text{Correct Price}_{REP/ETH}} \bigl(1 + \text{Protocol Fee}\bigr)\,}
\end{array}
```

We need either of these to be true if the price has deviated enough, thus we get:
```math
\text{Previous Contract Stake}_{ETH} \;>\; \text{Gas Fee} \cdot 
\min\Bigg(
\frac{1}{\frac{\text{Previous Implied Price}_{REP/ETH}}{\text{Correct Price}_{REP/ETH}} - (1 + \text{Protocol Fee})},\;
\frac{1}{1 - \frac{\text{Previous Implied Price}_{REP/ETH}}{\text{Correct Price}_{REP/ETH}} \bigl(1 + \text{Protocol Fee}\bigr)}
\Bigg)
```

We can also use:
```math
\text{Relative Price Correction} = \frac{\text{Previous Implied Price}_{REP/ETH}}{\text{Correct Price}_{REP/ETH}}
```

and get

```math
\text{Previous Contract Stake}_{ETH} \;>\; \text{Gas Fee} \cdot 
\min\Bigg(
\frac{1}{\text{Relative Price Correction} - (1 + \text{Protocol Fee})},\;
\frac{1}{1 - \text{Relative Price Correction} \bigl(1 + \text{Protocol Fee}\bigr)}
\Bigg)
```

From this we get that either $\text{Relative Price Correction}>(1+\text{Protocol Fee})$ or $\text{Relative Price Correction}<\frac{1}{1+\text{Protocol Fee}}$ where the trade is profitable. If we want $\text{Oracle Accuracy}>6\%$ ($\text{Relative Price Correction}>1.06$ or $\text{Relative Price Correction}<\frac{1}{1.06}$>) we get roughly:

$$
\text{Previous Contract Stake}_{ETH} > 55 \cdot \text{Gas Fee}
$$

This means we need to require this from the initial staker ($\text{Initial Stake}_{ETH}>55 \cdot \text{Gas Fee}$), and all the future stakes should be higher than this, and should be profitable to be price corrected. Its good to keep in mind, that this accounts only for gas costs to arbitrage the price up, but we should require higher price than this as there's other costs (jump cost and capital lockup cost) for the reporter.

## Delaying oracle cost
The oracle can be griefed by delaying its resolution. The worst case is to report on the oracle at the last block for every period, this costs per 10 blocks (depending on which side is being swapped):
```math
\begin{array}{l}
\text{Delay Cost}_{ETH} = \frac{\min(\text{Escalation Halt}, \text{Previous Contract Stake}_{REP}\cdot(1+\text{Escalation}) )}{\text{Correct Price}_{REP/ETH}}\cdot \text{Protocol Fee} \\
\text{Delay Cost}_{REP} = \min(\text{Escalation Halt}, \text{Previous Contract Stake}_{REP}\cdot(1+\text{Escalation}) )\cdot \text{Protocol Fee}
\end{array}
````

The costs raises exponentially until $\text{Escalation Halt}$ is reached, then it stays constant. The PLACEHOLDER is okay for some delay, however, if $\text{Time Until Stale}$ has passed since we have gotten a fair price, PLACEHOLDER refuses to mint more open interest until new price is reached.

## Determining the Initial Reporter Bounty

The oracle provides a bounty to the initial reporter if the price has moved sufficiently. The bounty can be expressed as:

```math
\text{Initial Reporter Bounty} = \text{Base Fee} \cdot \text{Gas Amount} \cdot \text{Correct Price}_{REP/ETH} + \text{Jump Cost} + \text{Capital Lockup Cost}
```

We can estimate the first term with reasonable accuracy since the Base Fee and Gas Amount are known. The Correct Price can be estimated either as the previous price (with some padding) or as the resolved oracle value.

However, estimating the Jump Cost is more challenging. This represents the risk that, although the user reports the price correctly, the price may move significantly within the next 10 blocks. Additionally, we must consider the Capital Lockup Cost, which accounts for the capital participants need to lock during the initial rounds before the escalation halt is reached (up to 10 blocks). The oracle participants also need to havean easy access to REP and ETH in order to be able to participate in the oracle reporting.

A practical approach to determining the whole Initial Reporter Bounty is a dynamic strategy:

```math
\text{Initial Reporter Bounty} = \text{Start Bounty} + e^{\text{Ramp Up} \cdot \text{Delta Blocks}}
```

Here, Delta Blocks increments for each block each time no oracle report occurs. This algorithm will eventually converge to an appropriate bounty, assuming at least two non-colluding price reporters. This method can be run once per day to obtain a daily price. 

Once report happens, we record at what price the report happened, and store half of it as start bounty for next oracle query: $\text{\text{Start Bounty}} = \frac{\text{Initial Reporter Bounty}}{2}$. This guarrantees we don't need to search for the price for too long to get reply next time.

A notable downside is that if the price changes frequently, updates occur only once per day. Ideally, the system should update the bounty only when the price changes and remain idle when the price is stable.

## Initial Reporter Bounty based on price change

```math
\text{Initial Reporter Bounty} = \text{Last Paid Bounty Without Gas Fees} + \text{Base Fee} \cdot \text{Gas Amount} \cdot \text{Oracle Price}_{REP/ETH} + \text{Price Reward(Price Deviation)}
```

where
```math
\text{PriceDeviation} = \max(\frac{\text{Oracle Price}_{REP/ETH}}{\text{Previous Oracle Price}_{REP/ETH}},\frac{\text{Previous Oracle Price}_{REP/ETH}}{\text{Oracle Price}_{REP/ETH}})
```

```math
\text(Price Reward(PriceDeviation)) = \frac{\text{PriceDeviation}}{\text{Oracle Accuracy}}
```

## Parameters:

| Parameter              | Value              |
| ---------------------- | ------------------ |
| Protocol Fee           | 4%                 |
| Oracle Accuracy        | 6%                 |
| Settlement Window      | 10 blocks          |
| Escalation             | 10%                |
| Escalation Halt        | 0.1% of REP Supply |
| Time Until Stale       | 1000 blocks        |
| Oracle Query Frequency | 1 day              |
