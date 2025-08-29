
# Price Oracle
The PLACEHOLDER needs a reliable $\frac{REP}{ETH}$ price oracle for four purposes:
1) The Escalation Game needs to know how much the Open Interest is worth in REP, to know how much Open Interest is being forcefully locked out from withdrawing because of a delay
2) The Security Pools have a Local Security Bond minting check:
```math
\text{Security Bonds Minted} \leq \frac{\text{Security Deposit}}{\text{Security Multiplier} \cdot \text{Price}_{REP/ETH}}
```
3) The Security Pools have a Global Security Bond minting check:
```math
\text{Total Security Bonds Minted} \leq \frac{\text{REP Supply}}{\text{Security Multiplier} \cdot \text{Price}_{REP/ETH}}
```
4) The liquidation protocol attempts to enforce Local Security Bond limit for each Security pool:
```math
\text{Health Factor} = \frac{\text{Staked REP} \cdot \text{Security Multiplier}}{\text{Security Bonds Issued} \cdot \text{Price}_{REP/ETH}} ≥ 1
```

An attacker can exploit a price oracle by artificially moving the reported price either downwards or upwards.

1) If the attacker drives the $\frac{REP}{ETH}$ price **very low**, they can:
	- Delay the Escalation Game at a lower cost
	- Prevent Security Pools from minting additional Security Bonds
	- Trigger bleeding liquidation across all Security Pools
2) If the attacker drives the $\frac{REP}{ETH}$ price **very high**, they can:
	- Make it more difficult to trigger a fork, since funds must be raised faster
	- Enable Security Pools to mint unsafe amounts of Security Bonds

This means we need a price oracle that is accurate to within [-50%, +100%] relative error (defined by the Security Parameter).

## Price oracle design

We use winsorized geometric mean TWAPs The oracle follows the standard geometric mean TWAP design, with the key modification that the spot prices fed into it are bounded. Specifically, the spot price for each block is winsorized by limiting the tick movement relative to the 10-block TWAP. The allowed range is $[-9116, 9116]$ ticks, which corresponds to a maximum increase of approximately 2.5x or a decrease of about 60%. This bounding mechanism ensures that short-term spot price fluctuations cannot exceed predefined limits, thereby constraining their influence on the TWAP.

Standard TWAP is defined as follows:
```math
\text{TWAP}_{REP/ETH} = \prod_{i=0}^n{\text{price}_i}^\frac{1}{n}=1.0001^{\frac{1}{n}\sum_{i=0}^n \text{tick}_i}
```

Winsorization plays a crucial role in preventing manipulation by Ethereum validators. Without it, a validator could temporarily push the spot price to an extreme level for a single block and then revert it in the following block. This would significantly distort the geometric mean TWAP, while costing the validator only the liquidity provider Pool Fees.

A simple per-block winsorization scheme, which restricts deviations from recent prices, is sufficient to protect against validators controlling one or two sequential blocks (including single-block access through flashbot-style relays). However, if a validator controls a longer consecutive sequence of blocks, the manipulation can accumulate exponentially with each block. To address this, we extend the winsorization reference point to longer horizons (e.g., $\text{Winzoring Comparison Blocks } = 10$ blocks). This design increases the difficulty of an attack, since an adversary must control a substantially larger fraction of blocks to succeed.

Even with these defenses, the security of the oracle ultimately relies on the assumption that Ethereum validators remain sufficiently decentralized, and that no single entity controls a large enough share of the network to mount such attacks.

## Non-validator manipulation

Non-validators can manipulate the price Pool Feed by temporarily pushing the pool price away from its fair value. Arbitragers then restore the price in the following block. This process causes the oracle to record an artificially inflated spot price.

Since arbitragers correct the price each block, the attacker must repeatedly spend capital to maintain the manipulation. The cost of this attack is incurred continuously, block by block.

Assuming all liquidity is provided across the full range, the cost of manipulating the price for a single block is:

$$
\text{Single Block Cost} = \text{ETH}_{Pool} \cdot \frac{\text{Pool Fee} \cdot \left( 1.0001^\text{Per Block Tick Manipulation}  - 1 \right)}{(1 - \text{Pool Fee}) \left( 1 + 1.0001^\text{Per Block Tick Manipulation}  \right)}
$$

In this attack, the manipulator swaps ETH into the pool to push the price, receiving REP in return. The REP is valued according to the pool’s original (pre-manipulation) price. Arbitragers then step in and trade the price back to its fair level.

Even though the price is corrected, the TWAP oracle records the manipulated price as the spot price for that block.

Now, suppose the manipulator repeats this action every block of the TWAP window, shifting the price by the same amount each time. This creates a sustained distortion in the oracle-reported average price, at the cost of paying for the manipulation in each block.

```math
\text{Manipulation Cost}_{ETH} = \text{TWAP Length}
\cdot
\text{ETH}_{Pool} \cdot \frac{\text{Pool Fee} \cdot \left( 1.0001^\text{Per Block Tick Manipulation}  - 1 \right)}{(1 - \text{Pool Fee}) \left( 1 + 1.0001^\text{Per Block Tick Manipulation}  \right)}
```
To pump the REP/ETH price by $\text{Total Manipulation Amount}$($1.0001^\text{Per Block Tick Manipulation}$) percentage for TWAP of length $\text{TWAP length}$ Article [TWAP Oracle Attacks: Easier Done than Said?](https://eprint.iacr.org/2022/445.pdf) goes throught the derivation of this equation.

### Profiting from manipulation

Let's assume the attacker is able to manipulate the price to be higher than Security Parameter, acquire false tokens for all this open interest for free (for simpler analysis) fork the system for free (for simpler analysis) and then migrate their share of Open Interest to lying universe and then pocket this excess while losing the REP in process:

```math
\text{Attack Revenue} = \text{Open Interest} - \text{REP migrated} / \frac{REP}{ETH}
```
Let's assume the attacker also controls all the REP, and we get:
```math
\text{Attack Revenue} = \frac{\text{REP Market Cap}}{\text{Security Parameter}}\cdot {\text{Total Manipulation Amount}} - \text{REP Market Cap}
```

This simplifies to:
```math
\text{Attack Revenue} = \text{REP Market Cap} \left( \frac{\text{Total Manipulation Amount}}{\text{Security Parameter}} - 1\right).
```

The attack is profitable whenever

$$
\text{Attack Revenue} > \text{Manipulation Cost}_{ETH}
$$

If the attacker pushes the price toward infinity, i.e.

$$
\text{Total Manipulation Amount} \to \infty,
$$

then the revenue from the attack grows linearly ($\text{Attack Revenue} \sim \text{Total Manipulation Amount}$) with the manipulation amount, while the cost only increases proportionally to the square root of the manipulation amount ($\text{Manipulation Cost} \sim \sqrt{\text{Total Manipulation Amount}}$). The revenue will eventually outpace the cost, ensuring profitability at sufficiently large manipulations.

For this reason, instead of relying on the TWAP price to determine whether new open interest can be minted (both locally and globally), and instead of taking the last spot price in a block as the oracle price, we use the minimum REP/ETH price observed within a block for the TWAP.

This approach ensures that even a single arbitrager interacting with the pool can restore the price to its fair value, preventing upward manipulation from being recorded by the oracle.

The trade-off is that downward manipulation remains possible. An attacker can repeatedly push the price lower, paying only the liquidity provider Pool Fees each time. By doing so, they could censor the protocol by preventing the creation of additional open interest. However, this attack can be mitigated: defenders can counteract it by adding more liquidity to the pool, increasing the cost of sustained downward manipulation.

## Liquidity required to enable arbitrage

The oracle’s correctness depends on arbitragers being able to restore fair prices. Whenever the oracle records a mispriced value, an arbitrager should have the opportunity to step in and profit by trading against the pool.

If we assume that performing an arbitrage trade costs $\text{Arbitrage Cost}$ ETH (e.g., from Ethereum gas Pool Fees), then the oracle’s pool must contain at least the following minimum liquidity to make arbitrage economically viable:

$$
L \ge 
\frac{ \text{Arbitrage Cost} \cdot 1.0001^{\tfrac{\text{Tracking Accuracy Ticks}}{2}} \cdot \sqrt{\text{Pool Price}_{REP/ETH}} }{ 1.0001^{\tfrac{\text{Tracking Accuracy Ticks}}{2}} - 1 }
\cdot 
\frac{ (1 - \text{Pool Fee}) \cdot 1.0001^{\text{Tracking Accuracy Ticks}} }{ (1 - \text{Pool Fee}) \cdot 1.0001^{\text{Tracking Accuracy Ticks}} - 1 }
$$

Where $\text{Tracking Accuracy Ticks}$ is the amount of deviation in ticks we allow the pool to have. This is $2L\sqrt{REP/ETH}$ worth of ETH (both REP and ETH side liquidity combined). This means that the liquidity requirement does not actually depend on the price:

$$
\text{Liquidity in ETH} \ge 
\frac{2 \cdot \text{Arbitrage Cost} \cdot (1 - \text{Pool Fee}) \cdot 1.0001^{\tfrac{3}{2} \cdot \text{Tracking Accuracy Ticks}}}{\left(1.0001^{\tfrac{1}{2} \cdot \text{Tracking Accuracy Ticks}} - 1\right)\left((1 - \text{Pool Fee}) \cdot 1.0001^{\text{Tracking Accuracy Ticks}} - 1\right)}
$$

However, our liquidity's value change depending on the price:
```math
\text{New liquidity in ETH} = \text{Previous Liquidity in ETH}\cdot\sqrt{\max(\frac{1}{\text{Relative Price Change}}, \text{Relative Price Change})}
```

We want to support some change of price here, eg $\text{Relative Price Change} = 5$, meaning we need to have `2.23` times more liquidity, than with constant price.

Arbitrage Cost can be estimated to be:

```math
\text{Arbitrage Cost} = 2 \cdot \text{Gas Uncertainty Multiplier} \cdot \text{Base Fee} \cdot \text{Worst Case Swap Gas}
```

Here `2` is used to assume the arbitrager sources the funds from similar exchange and it costs the same to do swap there.

## Funding price oracle
The price oracle needs to be funded to track the price. We also need to ensure the price oracle is funded after fork

Here's some ideas on how it could be funded
1) Its not funded, but the whole system freezes if there's not enough liquidity
2) If the system detects the system is underwater, an auction is held to purchase full range liquidity tokens for the pool
3) Security Pools need to hold a position in the oracle

## Parameters

| Parameter                     | Value                  |
| ----------------------------- | ---------------------- |
| Relative Price Change         | 5                      |
| Gas Uncertainty Multiplier    | 4                      |
| Worst Case Swap Gas           | ?                      |
| Tracking Accuracy Ticks       | 1000                   |
| Pool Fee                      | 2% (includes all fees) |
| Security Parameter            | 2                      |
| Tick-spacing                  | 200                    |
| Winzoring Range               | $[-9116, 9116]$ ticks  |
| Winzoring Comparison          | 10 blocks              |
| TWAP Length                   | 1 day                  |
