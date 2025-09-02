# Price Oracle

PLACEHOLDER needs a reliable $\frac{REP}{ETH}$ price oracle for four purposes:
1) The Escalation Game needs to know how much the Open Interest is worth in REP, to know how much Open Interest is being forcefully locked out from withdrawing because of the delay caused by the game.
2) The Security Pools have a Local Security Bond minting check:
```math
\text{Security Bonds Minted} \leq \frac{\text{Security Deposit}_{REP}}{\text{Security Multiplier} \cdot \text{Price}_{REP/ETH}}
```
3) The Security Pools have a Global Security Bond minting check:
```math
\text{Total Security Bonds Minted} \leq \frac{\text{Supply}_{REP}}{\text{Security Multiplier} \cdot \text{Price}_{REP/ETH}}
```
4) The liquidation protocol attempts to enforce Local Security Bond limit for each Security pool:
```math
\text{Health Factor} = \frac{\text{Staked}_{REP} \cdot \text{Security Multiplier}}{\text{Security Bonds Issued} \cdot \text{Price}_{REP/ETH}} ≥ 1
```

## PLACEHOLDER's price oracle

The Price Oracle PLACEHOLDER uses is heavily based on the [Open Oracle Design by j0i0m0b0o](https://ethresear.ch/t/proposal-for-a-trust-minimized-price-oracle/22971). 

Open Oracle is an optimistic oracle that allows participants to submit price reports for a token pair (here REP/ETH) and disputes can be raised within a settlement window (10 blocks) if a report is deemed inaccurate. We assume that an Ethereum validator cannot censor 10 blocks in a row to timeout the oracle, making the price oracle to resolve into wrong price.

The system involves three stages:
1) **Report creation** - The protocol initiates a query for the market to find the correct REP/ETH price. The protocol posts a bounty of $\text{Initial Reporter Bounty}$
2) **Initial report submission** - The first reporter submits their report on the price by submiting ($\text{Initial Rep Stake}$ of REP and $\text{Initial ETH Stake}$) of ETH, where the price is implied by the ratio of these.
3) **Dispute mechanism** - Other participants can dispute the report by submitting a better price by swapping against previous disputer and posting escalated amount of money at stake (up to ).
4) **Timeout** - If no disputes are posted after 10 blocks (settlement window), the oracle finalizes and the final price is reported. The final disputers stake is returned and Initial Reporter Bounty is paid.

## Initial Reporting

The Price Oracle operates by having an initial reporter submit a price report while staking both REP and ETH. Specifically:

```math
\text{Initial Implied Price}_{REP/ETH} = \frac{\text{REP Stake}}{\text{ETH Stake}}
```

As a reward for reporting, the initial reporter receives an **Initial Reporter Bounty** in REP tokens.

If no one disputes the report, the initial reporter earns a profit calculated as:

```math
\text{Profit}_{ETH} = \text{Initial Reporter Bounty} \cdot \text{REP/ETH Price} - \text{Gas Fees}
```

## Disputing
The initial report or previous report can be disputed by swapping against the previous reporters balance.

Depending on which token the disputer wants to send to initial reporter/previous disputer, the disputer sends following balances to the contract:

```math
\begin{bmatrix}
 & \text{Amount To Send}_{ETH} & \text{Amount To Send}_{REP} \\
\text{ETH} & \text{Previous Reporter Amount}_{ETH} + \text{New Contract Stake}_{ETH} + \text{Fee}_{ETH} & \text{New Contract Stake}_{REP} - \text{Previous Contract Stake}_{REP} \\
\text{REP} & \text{New Contract Stake}_{ETH} - \text{Previous Contract Stake}_{ETH} & \text{Previous Reporter Amount}_{REP} + \text{New Contract Stake}_{REP} + \text{Fee}_{REP} 
\end{bmatrix}
```

If $\text{Amount To Send}$ are negative, the sender gets a refund by that amount and does not need to send any of that token.

If swap token is ETH, we send ETH to the previous reporter, and REP otherwise: 
```math
\text{Previous Reporter Amount}_{token} = \text{Previous Contract Stake}_{token}
```

The previous participant then in total receives double amount of this token:
```math
\begin{array}{l}
\text{Previous Reporter Gain}_{Token} &=& 2 \cdot \text{Previous Contract Stake}_{Token} \\
\text{Previous Reporter Gain}_{\text{Other Token}} &=&0
\end{array}
```

The contract is then left with $\text{New Contract REP Stake}$ REP and $\text{New Contract ETH Stake}$ ETH, with implied price:
```math
\text{New Implied Price}_{REP/ETH} = \frac{\text{New Contract Stake}_{REP}}{\text{New Contract Stake}_{ETH}}
```

The disputer should select the less valuable token to swap, allowing them to profit by claiming the more valuable one.

We also require the REP stake to be increased by the Escalation amount, unless the Escalation Halt has been reached, in which case the contract does not increase the stake.

```math
\text{New Contract Stake}_{REP} = \min(\text{Escalation Halt}, \text{Previous Contract Stake}_{REP}\cdot(1+\text{Escalation}) )
```

The fees are calculated based on the previous balances:
```math
\begin{array}{l}
\text{Fee}_{REP} = \text{Previous Contract REP Stake}\cdot \text{Protocol Fee} \\
\text{Fee}_{ETH} = \text{Previous Contract ETH Stake}\cdot \text{Protocol Fee}
\end{array}
```

These fees will go directly to the PLACEHOLDER.

TODO: What to do with the ETH claimed? It can be useful to burn this, but it might be more useful to convert it to REP and burn that instead?

### Disputing profit

#### Swapping ETH
If

```math
\text{Correct Price}_{REP/ETH} < \frac{\text{Previous Implied Price}_{REP/ETH}}{\text{Oracle Accuracy}},
```
the disputer should use ETH to swap, the profit that last disputer gets is:
```math
\text{Profit}_{ETH} = \frac{\text{Previous Contract Stake}_{REP}}{\text{Correct Price}_{REP/ETH}} - \text{Previous Contract Stake}_{ETH}\cdot(1 + \text{Protocol Fee}) - \text{Gas Fee}
```

We can then compute when this is profitable:
```math
\frac{\text{Previous Implied Price}_{REP/ETH}}{\text{Correct Price}_{REP/ETH}} > (1+\text{Protocol Fee}) + \frac{\text{Gas Fee}}{\text{Previous Contract Stake}_{ETH}}
```

#### Swapping REP
If
```math
\text{Correct Price}_{REP/ETH} > \text{Previous Implied Price}_{REP/ETH}\cdot \text{Oracle Accuracy},
```
the disputer should use ETH to swap, the profit the disputer gets is:
```math
\text{Profit}_{ETH} = \text{Previous Contract Stake}_{ETH} - \text{Previous Contract Stake}_{REP}\cdot \frac{(1 + \text{Protocol Fee})}{\text{Correct Price}_{REP/ETH}}- \text{Gas Fee}
```
And this is profitable When:
```math
\frac{\text{Previous Implied Price}_{REP/ETH}}{\text{Correct Price}_{REP/ETH}} < \frac{1 - \text{Gas Fee}/\text{Previous Contract Stake}_{ETH}}{1+\text{Protocol Fee}}
```

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

From this, we see that a trade is profitable when either

```math
\text{Relative Price Correction} > 1 + \text{Protocol Fee}
```

or

```math
\text{Relative Price Correction} < \frac{1}{1 + \text{Protocol Fee}}
```

Given `Oracle Accuracy = 6%`, this corresponds to

```math
\text{Relative Price Correction} > 1.06 \quad \text{or} \quad \text{Relative Price Correction} < \frac{1}{1.06}
```

This implies approximately:

```math
\text{Previous Contract Stake}_{ETH} > 55 \cdot \text{Gas Fee}
```

Thus, the **initial staker** must provide at least

```math
\text{Initial Stake}_{ETH} > 55 \cdot \text{Gas Fee}
```

All future stakes should also exceed this threshold to ensure that price corrections remain profitable.

It’s important to note that this calculation only accounts for gas costs required to arbitrage the price. In practice, stakes should be higher to cover additional costs, such as **jump costs** and **capital lockup costs** for the reporter.

## Delaying oracle cost
The oracle can be griefed by deliberately delaying its resolution. A disputer can do this by disputing the oracle by the minimum amount (equal to `Oracle Accuracy`) in each round, which prolongs the resolution process. To delay the oracle, the disputer only needs to pay the `Protocol Fee`.

However, executing this strategy is challenging because the disputer must hope that no other party disputes the price to correct it during the same 10-block period. That said, if enough validator censorship occurs, delaying the resolution becomes cheaper.

The minimum cost to delay the price for every 10-block period (depending on which side is being swapped) is:

```math
\begin{array}{l}
\text{Delay Cost}_{ETH} =
\frac{\min(\text{Escalation Halt}, \text{Previous Contract Stake}_{REP} \cdot (1 + \text{Escalation}) )}{\text{Correct Price}_{REP/ETH}} \cdot \text{Protocol Fee} \\[2mm]
\text{Delay Cost}_{REP} =
\min(\text{Escalation Halt}, \text{Previous Contract Stake}_{REP} \cdot (1 + \text{Escalation}) ) \cdot \text{Protocol Fee}
\end{array}
```

The cost increases exponentially until Escalation Halt is reached, after which it remains constant. The PLACEHOLDER allows for some delay; however, once Time Until Stale has passed since the last fair price, PLACEHOLDER stops minting additional open interest until a new price is reported.

## Determining the Initial Price Reporter Bounty

To ensure that someone is incentivized to submit the first price report (and thus trigger the oracle process), we need to offer an **Initial Reporter Bounty**. Without it, there would be no profit motive for the first reporter.

We can express the bounty as:
```math
\text{Initial Reporter Bounty} = \text{Base Fee} \cdot \text{Gas Amount} \cdot \text{Correct Price}_{REP/ETH} + \text{Jump Cost} + \text{Capital Lockup Cost}
```

* The first term can be estimated accurately, since both Base Fee and Gas Amount are known (aside from future EVM changes, which can still be calculated on-chain).
* The Correct Price can be approximated using either the previous resolved oracle price (with a buffer) or the most recent settlement price.
* The challenging parts are estimating Jump Cost and Capital Lockup Cost:
  * **Jump Cost** reflects the risk that the price moves significantly in the 10 blocks following a correct report.
  * **Capital Lockup Cost** accounts for capital tied up during the early escalation rounds (up to 10 blocks) before resolution.

Additionally, oracle participants must have timely access to both REP and ETH to participate in reporting.

## Two Mechanisms for Determining the Bounty

We use two complementary approaches to ensure a fair bounty level:
1. **Exponential Price Controller**
   If no price update occurs for a defined duration (Oracle Query Frequency, e.g. 3 days), the Initial Reporter Bounty increases exponentially until someone reports.
2. **Big Enough Price Change Controller**
   Anyone can trigger a price update at any time. The bounty they receive depends on how much the price has changed since the last report (finalized when the query resolves).

The oracle only permits one active price query at a time. A new query cannot be started until the previous one has been completed. We also allow the price to increase only by 2x or decrease by 50% in a day ($\text{Max Price Change}$ parameter).

### Exponential Price Controller
When the oracle has not updated for a sufficient number of blocks, the bounty grows according to:

```math
\text{Initial Reporter Bounty} = \frac{\text{Previous Initial Reporter Bounty}}{2}\cdot 2^{\text{Exponential Ramp Up} \cdot \text{Delta Blocks}}
```

Here, Delta Blocks increments each block without an oracle update. This ensures the bounty eventually reaches an attractive level, assuming at least two non-colluding price reporters. We also use:

```math
\text{Exponential Ramp Up} = \frac{13}{3600}
```

This ensures the $\text{Initial Reporter Bounty}$ doubles every hour.

Once a report is submitted, the bounty level at which it triggered is recorded and used as a reference for future queries. This prevents prolonged waiting for updates in the future.

### Big Enough Price Change Controller
To ensure timely updates when prices shift significantly, we introduce a second controller.

First, we compute the reporter’s **net bounty in ETH terms** from the last update:

```math
\text{Initial Reporter Bounty Without Gas}_{ETH} =
\max \left(
	\frac{\text{Bounty Paid}_{REP}}{\text{Oracle Price}_{REP/ETH}}
	- \text{Base Fee} \cdot \text{Gas Amount},
	0
\right)
```

Here, the Oracle Price is the most recent oracle result.

Next, any participant can initiate a new query and, upon resolution, receive the following reward in REP:

```math
\text{Initial Reporter Bounty} =
\Bigg[
	\text{Base Fee} \cdot \text{Gas Amount}
	+
	\left(
		\frac{
			\max(\text{Oracle Price}_{REP/ETH}, \text{Previous Oracle Price}_{REP/ETH})
		}{
			\min(\text{Oracle Price}_{REP/ETH}, \text{Previous Oracle Price}_{REP/ETH})
			\cdot \text{Oracle Accuracy}
		}
	\right)
	\cdot \text{Initial Reporter Bounty Without Gas}_{ETH}
\Bigg]
\cdot \text{Oracle Price}_{REP/ETH}
```

This equation rewards the initiator with
```math
\text{Base Fee} \cdot \text{Gas Amount} + \text{Initial Reporter Bounty Without Gas}_{ETH}
```

worth of REP (in ETH terms) when the price changes by exactly Oracle Accuracy. The payout then scales linearly with the size of the price change - smaller changes earn less, larger changes earn more.

To avoid runaway growth, we cap the bounty for initiated queries (per day):

```math
\text{Initial Reporter Bounty} \leq
\text{Max Initial Bounty Increase} \cdot \text{Previous Initial Reporter Bounty}
```

This prevents the system from inflating rewards too quickly.

## Parameters:

| Parameter                   | Value              |
| --------------------------- | ------------------ |
| Protocol Fee                | 4%                 |
| Oracle Accuracy             | 6%                 |
| Settlement Window           | 10 blocks          |
| Escalation                  | 10%                |
| Escalation Halt             | 0.1% of REP Supply |
| Time Until Stale            | 1000 blocks        |
| Oracle Query Frequency      | 3 day              |
| Max Initial Bounty Increase | 2                  |
| Exponential Ramp Up         | $\frac{13}{3600}$  |
| Max Price Change            | 2x/day             |

## Future improvements
- use block time with block number (both)
- Would it be possible to partially fill rounds so that people with smaller amounts of rep/eth could also participate in later 
stages?
- We could probably use Open Oracle directly
- Gas fee can change, and escalation% should increase to accommodate increased gas costs
- Todo: instead of using system fee, change to fee that pays the previous reporter the fee instead, this solves the problem on what to do with rep/eth the protocol gains and also is more capital efficient/safer for disputers.
-> I think the cheapest way to delay is:
-> 1) someone sets correct price
-> 2) you set the price off by -acccuracy%, then right back to correct, this resets the timer, and you pay the fee once to the other party