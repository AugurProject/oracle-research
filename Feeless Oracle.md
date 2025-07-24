# Feeless Oracle - Collateralized Debt Positions
![image](./images/feeless_oracle.webp)

When evaluating what makes a secure oracle, the most critical criterion is that the total open interest (OI) must be less than the monetary value of the assets backing it. In the [Arctic Tern Oracle](./Arctic%20Tern%20Oracle.md), for example, the open interest must remain below the market capitalization of the REP collateral.

Oracles often require open interest holders to pay fees to the system. However, this fee mechanism is not inherently necessary for the oracle's security. The only requirement is to enforce the inequality between the open interest and the backing collateral. This allows us to decouple the monetization layer from the oracle itself.

Instead, we can permit REP holders to mint open interest under the condition that:

```math
\text{Minted Open Interest} < \frac{\text{Market Cap of REP Collateral}}{\text{Security Multiplier}}
```

By enforcing this constraint, the oracle maintains its security guarantees without needing to charge fees directly. Monetization mechanisms can then be handled externally or through other layers.

Even if all REP holders mint open interest, we can still enforce the condition:

```math
\text{Open Interest} < \text{REP Market Cap}
```

We refer to these individual positions as *Collateralized Debt Positions* (CDPs). Each CDP functions as an isolated pool with the following mechanics:

1. A REP holder deposits REP into a CDP contract.
2. They can mint Open Interest tokens (i.e., complete sets) for a specific `market` by depositing ETH into the Arctic Tern Oracle. This accrues debt to the CDP, bounded by the inequality above.

## Reducing Debt

Debt within a CDP can be reduced in two ways:

1. **Deposit complete sets** of any market back into the CDP. This cancels out the associated debt.
2. **Market finalization**: When a market associated with the CDP finalizes, any debt linked to complete sets from that market is removed from the system.

## Additional CDP Operations

CDP holders can also perform the following operations:

1. **Add more REP**: Increasing the collateral allows the holder to mint additional open interest.
2. **Remove REP**: The inequality still need to be held.
3. **Market Swap**: Deposit complete sets of *any* market into the CDP to replace or offset debt from *any other* market.

## Forced Liquidation

If the price of `REP` drops relative to the amount of minted open interest, anyone can initiate a forced liquidation. This happens when the pool holds open interest in non-finalized markets that exceeds its allowed collateralization:

```math
\text{Minted Open Interest}_{pool} < \frac{\text{REP}_{pool} \cdot \text{ETH/REP}}{\text{Security Multiplier}}
```

A liquidator can submit proof that the pool violates this inequality. Along with this proof, they must deposit complete sets of any market into the pool. This reduces the pool’s outstanding open interest. In return, they can claim a portion of the pool's REP as a liquidation reward.

After liquidation, the new pool state becomes:

```math
\text{Minted Open Interest}_{pool} - \text{Liquidator's OI} > \frac{(\text{REP}_{pool} - \text{Liquidator's REP Profit}) \cdot \text{ETH/REP}}{\text{Security Multiplier}}
```

Additionally, to ensure that liquidation is profitable, this condition must be satisfied:

```math
\text{Liquidator's OI} < \text{Liquidator's REP Profit} \cdot \text{ETH/REP}
```

This guarantees that the liquidator gains more value in REP than they spend acquiring and depositing the open interest. A reasonable profit margin for liquidators is typically in the range of 10–20%.

### Underwater Pools

In some cases, a pool may become undercollateralized to the point that no liquidation is economically viable:

```math
\text{Minted Open Interest}_{pool} > \text{REP}_{pool} \cdot \text{ETH/REP}
```

In such situations, liquidators cannot be repaid adequately from the remaining collateral. To mitigate this, the system could:

* Refund the gas fees incurred by the failed liquidation attempt
* Burn the remaining REP in the pool to reduce systemic risk

This will still result in some bad debt for the system, however, this is still safe if the total open interest of the system is below the REP market cap. We could then also require higher security from the system, so that this risk is democratized across the whole system until the bad debt of the system is cleared by market finalization. Another approach would be to mint enough REP for the liquidator, and democratize the cost that way.

## Automated Access to Open Interest

In the system described above, we outlined CDP-style pools similar to MakerDAO, where users deposit collateral to mint assets. This foundational mechanism enables the creation of more flexible pool designs. Ultimately, open interest must be made accessible to traders in a seamless and scalable way.

### Open Pools

We can introduce **open pools** where any user can deposit and withdraw REP (subject to certain constraints). Open interest can then be minted by depositing ETH and paying a fee to the pool. This fee can be dynamic and depend on factors such as:

1. **Pool utilization**: The closer the pool is to its collateralization limit, the higher the fee. This model mirrors Aave's utilization-based interest rates.
2. **Market characteristics**: Markets with longer finalization times lock up collateral for longer periods, increasing risk and opportunity cost. Minting open interest for these markets should incur higher fees.

To encourage participants to return complete sets and reduce outstanding debt, the system can offer **refundable fees**. For example, users who mint open interest for long-dated markets may be charged a higher fee upfront but can receive a rebate upon returning the complete set. This incentivizes debt clearance and improves system health.

### Permissioned Pools

Pools can also be **permissioned**, restricting access or functionality based on custom rules. Possible models include:

1. **Market-specific minting**: A pool may restrict minting to shares of a specific market—useful if you're operating a dedicated market and want to direct liquidity to it.
2. **Subscription-based access**: Users who pay a subscription fee can mint open interest without incurring per-minting fees.
3. **Bundled services**: Platforms offering broader services (e.g., analytics, trading tools, etc.) may subsidize open interest minting for their users, monetizing through other channels.

## Using REP for Escalation Games
We still need REP to be used for escalation games. There's two ways to implement this:
1) The REP used in escalation games cannot be part of the pool, and thus doesn't accrue open interest fees. This means for system to remain secure, the fees being paid by the pool need to be less than the expected profit from the escalation game.
2) The REP Used in the escalation game can also be part of the pool, when fraction of REP loses in escalation game, this REP is force pulled from the pool its part of

## Pros & Cons

### Pros

* Only REP actively staked in pools is eligible for rewards
* The oracle itself does not require a built-in fee mechanism; monetization is fully outsourced
* The escalation/dispute game remains fee-free and simpler, as no fee accounting is needed
* REP holders have full control over setting fee rates for open interest minted from their pools
* There is a strong incentive for REP holders to attract capital and usage to their own pools

### Cons

* Users must have some access to REP in order to participate. This can be via:

  * Third-party pools that host REP and offer access to open interest
  * REP markets where users can buy REP directly
* The system does not support capital-efficient, time-based fee mechanisms (such as the **CASH** model from [Sisyphean Exchange](./Sisyphean%20Exchange.md))
* Open interest under dispute may remain locked for extended periods, but pools that minted those positions do not receive additional compensation for the lockup
