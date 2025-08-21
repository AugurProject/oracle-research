
# Price Oracle
The PLACEHOLDER needs a reliable $\frac{REP}{ETH}$ price oracle for four purposes:
1) The Escalation Game needs to know how much the Open Interest is worth in REP, to know how much Open Interest is being forcefully locked out from withdrawing because of a delay
2) The Security Pools have a Local Security Bond minting check:
```math
\text{Security Bonds Minted} \leq \frac{\text{Security Deposit}}{\text{Security Multiplier} \times \text{Price}_{REP/ETH}}
```
3) The Security Pools have a Global Security Bond minting check:
```math
\text{Total Security Bonds Minted} \leq \frac{\text{REP Supply}}{\text{Security Multiplier} \times \text{Price}_{REP/ETH}}
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

This means we need a price oracle that is accurate enough to be within $[-50\%,+100\%]$ of the correct values (security parameter away).

## Price oracle design

```math
\text{TWAP}_{REP/ETH} = \prod_{i=0}^n{p_i}=\sum_{i=0}^n \text{Tick}_i
```

We use 30-minute and 1-day winsorized geometric mean TWAPs. The oracle follows the standard geometric mean TWAP design, with the key modification that the spot prices fed into it are bounded. Specifically, the spot price for each block is winsorized by limiting the tick movement relative to the 10-block TWAP. The allowed range is $[-9116, 9116]$ ticks, which corresponds to a maximum increase of approximately 2.5x or a decrease of about 60%. This bounding mechanism ensures that short-term spot price fluctuations cannot exceed predefined limits, thereby constraining their influence on the TWAP.

Winsorization plays a crucial role in preventing manipulation by Ethereum validators. Without it, a validator could temporarily push the spot price to an extreme level for a single block and then revert it in the following block. This would significantly distort the geometric mean TWAP, while costing the validator only the liquidity provider fees.

A simple per-block winsorization scheme, which restricts deviations from recent prices, is sufficient to protect against validators controlling one or two sequential blocks (including single-block access through flashbot-style relays). However, if a validator controls a longer consecutive sequence of blocks, the manipulation can accumulate exponentially with each block. To address this, we extend the winsorization reference point to longer horizons (e.g., 10 blocks). This design increases the difficulty of an attack, since an adversary must control a substantially larger fraction of blocks to succeed.

Even with these defenses, the security of the oracle ultimately relies on the assumption that Ethereum validators remain sufficiently decentralized, and that no single entity controls a large enough share of the network to mount such attacks.

## Non-validator manipulation

Non validators can also manipulate the price feed by moving the price and then let arbitragers move it back the next block. This is very expensive thought. To move Price by manipulation amount in a single block, assuming all the liquidity is full range. Let's then assume arbitragers always move the price back after manipulation.

To perform the manipulation attack against a single block, it costs:

$$
\text{Single Block Cost} = \text{ETH}_{Pool} \cdot \frac{\text{Pool Fee} \cdot \left( 1.0001^\text{Per Block Tick Manipulation}  - 1 \right)}{(1 - \text{Pool Fee}) \left( 1 + 1.0001^\text{Per Block Tick Manipulation}  \right)}
$$

This means the manipulator puts ETH into the pool and receives REP back. The REP is valued with the original price of the pool. The arbitragers then manipulate the price back, but the TWAP oracle will record the manipulated price as a spot price for it. Let's then assume the manipulator manipulates every block in the TWAP by the same amount:
```math
\text{Manipulation Cost}_{ETH} = \text{TWAP Length}
\cdot
\text{ETH}_{Pool} \cdot \frac{\text{Pool Fee} \cdot \left( 1.0001^\text{Per Block Tick Manipulation}  - 1 \right)}{(1 - \text{Pool Fee}) \left( 1 + 1.0001^\text{Per Block Tick Manipulation}  \right)}
```
[https://eprint.iacr.org/2022/445.pdf]

To pump the REP/ETH price by $\text{Total Manipulation Amount}$ percentage for TWAP of length $\text{TWAP length}$. By pumping the price, the attacked can profit

```math
\text{Profit} = \text{Attack Revenue} - \text{Manipulation Cost}_{ETH} 
```

Let's assume the attacker is able to manipulate the price to be higher than Security Parameter, acquire false tokens for all this open interest for free (for simpler analysis) fork the system for free (for simpler analysis) and then Migrate their share of Open Interest to lying universe and then pocket this excess while losing the REP in process:

```math
\text{Attack Revenue} = \text{Open Interest} - \text{REP migrated} / \frac{REP}{ETH}
```
Let's assume the attacker also controls all the REP, and we get:
```math
\text{Attack Revenue} = \frac{\text{REP Market Cap}}{\text{Security Parameter}}\cdot {\text{Total Manipulation Amount}} - \text{REP Market Cap}
```

```math
\text{Tota Manipulation Amount} = 1.0001^\text{Per Block Tick Manipulation}
```

where $\text{Open Interest} > \text{REP migrated} / \frac{REP}{ETH}$

This simplifies to:
```math
\text{Attack Revenue} = \text{REP Market Cap} \left( \frac{\text{Total Manipulation Amount}}{\text{Security Parameter}} - 1\right)
```

We can then calculate when attacker is not profitable $\text{Profit} < 0 $, and we get:

$$
\text{Pool Fraction} = \frac{\text{ETH}_{Pool}}{\text{REP Market Cap}} > \frac{(1 - \text{Pool Fee})}{\text{TWAP Length} \cdot \text{Pool Fee} \cdot \text{Security Parameter}} \cdot \frac{\big( 1.0001^\text{Per Block Tick Manipulation} - \text{Security Parameter} \big) \cdot \big( 1 + 1.0001^\text{Per Block Tick Manipulation} \big)}{1.0001^\text{Per Block Tick Manipulation} - 1}
$$


### Attacks
#### Liquidity triggering attacks
- steal from security pools by holding rep and liquidating other REP
#### Sell More Security Bonds from Your pool
- If you can manipulate rep/eth to be very high, you can mint a lot security bonds and sell them while profiting

#### Steal Open Interest
- If you can manipulate rep/eth to be very high, other peoples security pools might allow you to mint complete sets for a market with very uneven odds, you could sell your NO shares for epsilon
-> then trigger fork where the actual REP value is less than open interest you have generated and you can fork the system to steal this open interest (by resolving market wrong)

