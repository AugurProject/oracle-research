# Partial Colored Coins: Colored Coins with external assets
![image](images/partial_colored_coins.png)

The **Partial Colored Coins** is a variant of the [Colored Coins Prediction Market](/Colored%20Coins.md) that introduces the ability for users to predict using external assets such as Ether, Bitcoin, or USDC. This concept was originally proposed in [Parasitic Immune Augur](https://listed.to/authors/33689/posts/51513).

The design can be summarized as follows:
> Users lock external assets (e.g., Ether) into trade agreements that rely on oracle resolution. Whenever the system reaches a decision point:
> 1. The external assets and their associated claims are converted into a branchable asset (e.g., REP)
> 2. The decision branches - each possible outcome creating a separate path
> 3. Each resulting branch can continue to fork as new decisions arise, allowing the system to evolve indefinitely

An interesting additional benefit we can get with this design is that we could in theory allow any number of any assets being traded on the system. We just need to be able to convert these claims into $REP$.

> [!NOTE]
> #### Example: Simple Single Forking Market Scenario:
> 
> 1. **Bob** has 100 YES shares on the market worth $50
> 2. **Alice** has 100 NO Shares on the market worth $50
> 3. Open interest (\$100) is sold in open market to get \$100 worth of $REP$. Let's assume 1 $REP = 1\$$, meaning we get 100 $REP$ in the sale.
> 4. The market forks and the chain is split into YES and NO universes.
> 5. On the YES universe, **Bob** can convert their 100 YES shares to 100 $REP_{YES}$. On No Universe, **Bob's** shares are worth 0 $REP_{NO}$.
> 6. On the No universe, **Alice** can convert their 100 NO shares to 100 $REP_{NO}$. On Yes Universe, **Alice's** shares are worth 0 $REP_{YES}$.
> 7. **Bob** believes that the NO universe is correct even thought they lost, so they continue to trade in Universe NO in the future.
> 8. **Alice** also believes the NO universe is correct and they continue to trade there. **Alice** sells her $REP_{NO}$ for 100$ and realizes profit of 50$.
> 
> It also might happen that the steps 7-8 go differenly in a way that both traders disagree and continue to trade in YES and NO universes separately. This can result in both universes to be valuable and end up being used for future markets.

## Assumptions for system to be secure
There's a couple big assumptions being made on top of the [colored coin assumptions](/Colored%20Coins.md):

1. **Open interest can be sold to the same worth of REP**: When open interest gets sold on the open market, we get equivalent worth of $REP$ tokens from the market.
2. **Asset swap assumption**: People are okay having their open interest of some external assets being converted into $REP$.

Open interest assumption splits into couple of smaller assumptions:
- **Zero trading fees**: When selling assets on open market to $REP$, you often have to pay trading fees, and which results in the assets to be worth less than their original value.
- **Sufficient liquidity**: When selling big amount of assets, there might not be enough liquidity on the market and there's a lot slippage.
- **Open interest < REP's market cap**: If $REP$'s market cap is less than the open interest being sold, it's not even possible to get equal worth in $REP$ as not enough $REP$ exists for that.
- **REP needs to maintain its value**: After Open interest has been converted into $REP$, $REP$'s price might drop, causing users to lose value.

## External assets need to be sold in a fork

When a fork occurs in Colored Coins, we can simply split the $REP$, resolve the market in each resulting universe, and distribute the new $REP$ accordingly. However, in Partial Colored Coins, this approach doesn't work because external assets cannot be split. Instead, we sell all external assets for $REP$ and then proceed to split the $REP$ in the same manner as with Colored Coins.

Assuming the market cap of $REP$ before the fork equals the combined market cap of the truthful universes, users holding shares in the truthful universes can redeem them for their full value.

> [!NOTE]
> When Partial Colored Coins forks, it becomes Colored Coins System

### How to Sell Assets Effectively

In the event of a fork, the system must be able to liquidate large volumes of assets in exchange for $REP$ tokens. This process is conceptually similar to **margin calls** in traditional finance - where positions are forcibly closed to preserve solvency - but with several important differences:

* In a margin call, **traders can intervene** (e.g., by adding collateral) to prevent liquidation.
* In our system, **liquidation is automatic and unavoidable**; open interest holders cannot interfere once triggered.
* Margin calls prioritize **speed** to avoid further declines in asset value.
* In our case, **speed is secondary** - the priority is to recover $REP$ in a **cost-efficient** manner.

The primary goal is to **maximize the value recovered** for open interest holders. The only significant time-related pressure comes from the **opportunity cost** of having open interest unresolved.

#### Dutch Auctions as a Liquidation Mechanism

A [Dutch auction](https://en.wikipedia.org/wiki/Dutch_auction) offers a strong solution for protocol-driven liquidation, particularly because it is gas-efficient for blockchain environments.

1. The auction begins with a **high starting price**.
2. The price **gradually decreases** over time at a fixed rate.
3. Buyers can purchase at any point while the auction is open.
4. The auction ends when **all assets are sold**.
5. **All participants pay the same price** - the final clearing price when the last asset is sold.

Dutch auction ensure that the assets are sold at a market-driven price, preserving capital for the open interest holders.

> [!WARNING]
> TODO: which is the best auction method to use?
>
> TODO: how long the auction should last?
>
> TODO: how much time we need to alert everyone this auction is going to happen?

### Claiming assets prior liquidation

In prediction markets in general, users can redeem a complete set of outcome shares (e.g., Yes and No) for $1 of collateral. This allows them to exit early, avoiding liquidation and related fees, offering a cost-efficient path that also reduces the system’s liquidation burden - benefiting all open interest holders.

## Parasitic Interest Resistance in Partial Colored Coins System

Both the Colored Coins and Partial Colored Coins systems are inherently secure against the Parasitic Interest Problem (described in [Augur V2 whitepaper](https://github.com/AugurProject/whitepaper/releases/latest/download/augur-whitepaper-v2.pdf)).

Augur V2 addresses this issue by requiring open interest to be registered within the system. This allows Augur contracts to be aware of the open interest and adjust its fee structure accordingly. However, Augur V2 cannot enforce the registration of open interest; it relies on social layer. The community is expected to discourage the use of external systems that exploit Augur V2 without contributing to its security. In essence, the social layer plays a key role in defending against parasitic interest.

To maintain security, Augur V2 also aims to keep its market cap at least 5x the size of its open interest. This ensures resilience even against up to 4x parasitic interest and some volatility of $REP$ price.

In contrast, the Colored Coins solution inherently avoids parasitic interest, as the system does not resolve decisions. Since no resolution occurs, no external system can leech off its outcomes. The Partial Colored Coins approach shares this resistance: open interest is exchanged for $REP$ and migrated into new universes, which similarly do not resolve outcomes. Parasitic parties does not get their assets exchanged into $REP$ and also do not get any kind of oracle resolution.

However, both systems can be susceptible to parasitic behavior when they include escalation games designed to prevent forks. For example, one could construct a wrapper oracle like:

> Use the Colored Coins system with an escalation game, and if the escalation game fails, ask Bob to resolve the market.

This approach reduces Bob's workload, as he only intervenes when the escalation game fails. The trustworthiness of this setup depends on Bob’s valuation of his reputation being higher than any potential gain from exploiting open interest.

Another example is a Market Cap Oracle:

> Use the Colored Coins system with an escalation game, and if it fails, resolve based on the highest traded market cap of the forked colored coin.

This mechanism assumes that traders will gravitate toward the fork representing the truthful universe, even if others attempt to manipulate colored coin prices. In theory, price manipulation wouldn’t matter, as rational traders prefer to trade in a universe they believe to be accurate.

However, this assumption can conflict with the *greed assumption* - that users may act in their own short-term interest, potentially favoring manipulated or parasitic systems if doing so benefits them financially.

## Maintaining the Market Cap of REP

The security of Partial Colored Coins relies on ensuring that open interest remains below the market cap of REP. This same principle applies in Augur V2, where the goal is to maintain this inequality to preserve system integrity.

### Fee-Based Incentive Model

Augur V2 attempts to enforce this by introducing a fee on open interest holders, which is then redistributed to $REP$ holders. The core idea is to make $REP$ valuable by turning it into a yield-generating asset - holders earn a return as long as open interest exists in the system.

However, in Augur V2, this fee is charged only once, regardless of how long the open interest is held. This creates a weakness: users can lock up open interest for extended periods without incurring further cost, reducing the incentive to keep open interest below the $REP$ market cap.

A more robust approach is to implement time-based fees - fees that increase the longer open interest is held. These can be dynamically adjusted to maintain a target relationship between open interest and $REP$ market cap. Time based fees also reduce open interest by two means:
1) The fees are directly taken from the current open interest and thus they reduce the total open interest amount
2) The higher the fees are, the less attractive the platform is for traders

#### Bang–Bang Controller

One simple method to implement time-based fee adjustments is via a [**Bang–bang controller**](https://en.wikipedia.org/wiki/Bang%E2%80%93bang_control):
```math
\text{Fee Change Fraction} = 
\begin{cases}
+\text{increment} & \text{if } \text{open interest} > \text{Target REP Market Cap} \\\\
0 & \text{if } \text{open interest} = \text{Target REP Market Cap} \\\\
-\text{increment} & \text{if } \text{open interest} < \text{Target REP Market Cap}
\end{cases}
```

Here, `increment` is a tunable parameter that determines how quickly the fee reacts to changes in open interest. The key is to adjust fast enough to be effective, but not so fast that it causes fee volatility.

The actual **Open Interest Fee (%)** then evolves over time as:
```math
\text{New Open Interest Fee Fraction} = \text{Previous Open Interest Fee} + \text{Fee Change Fraction} \cdot \Delta time
```

Where:
* `Fee Change` is the output from the Bang–bang controller
* `Δtime` is the time delta since the last adjustment

Alternatively, more sophisticated controllers - such as [**Proportional–Integral–Derivative (PID) controllers**](https://en.wikipedia.org/wiki/Proportional%E2%80%93integral%E2%80%93derivative_controller) - can be used for smoother and more responsive control.

#### Choosing the Target REP Market Cap

The `Target REP Market Cap` must always exceed `Open Interest`. If $REP$’s market cap falls below open interest, the system becomes under-collateralized, making it impossible to convert open interest back into $REP$ securely.

Even when $REP$ Market Cap equals open interest, it would be practically infeasible to acquire all $REP$ to satisfy the open interest claims. Therefore, the target must be set **significantly higher than open interest** to provide room for fee adjustments and ensure system solvency.

* **Augur V2** uses a target of:
```math
  \text{Target Market Cap} = 5 \times \text{Open Interest}
```
* **Partial Colored Coins** may require a significantly higher multiplier, as in fork scenarios, where the REP market cap and liquidity must withstand large, sudden purchases.

> [!WARNING]
> TODO: Research on which Open Interest multiplier should be used

## How to measure open interest?

If the system holds a large number of arbitrary external assets, it must be able to accurately track the price of each one to assess the total open interest. This can be risky, as unreliable or volatile assets may disproportionately affect the calculated open interest. Such distortions are particularly dangerous if the system adjusts its fees based on open interest targets, as Augur V2 does.

An alternative to directly adjusting Augur V2's fees is a dashboard defense approach: instead of trying to enforce a hard cap, a public dashboard could estimate the total value of stored assets and inform users if the system appears insecure. However, this comes with a critical limitation-users who already have assets in the system may not be able to withdraw once the system is undercollateralized, even if they are warned in advance.

It is also possible that the fee adjusting controller does not adjust the fee fast enough and the system can become undercollateralized under the controller as well. In this case the users of the system should also try to exit the system.

## An interesting variation: We don't sell open interest
Instead of auctioning the assets, we could give all the assets to $REP$ holders and mint equal worth of $REP$ tokens to open interest holders. This requires a reliable price oracle for each asset type held by the system. Big advantage here is that this results in zero trading fees for everyone. However, risk that the $REP$ price is being manipulated increases.

Assuming fork does not have an impact on the market cap of $REP$. We need to mint
```math
\text{REP Tokens Minted} = \frac{\text{Open Interest}}{\text{REP Token Price}}
```
tokens for open interest holders to replace their funds with $REP$, however, this dillutes the token supply and $\text{REP Token Price}$ does not remain constant, the price changes to
```math
\text{REP Token Price} = \frac{\text{REP Market Cap}}{\text{REP Token Supply}+\text{REP Tokens Minted}}
```
Combining these equations result in number of tokens we need to mint for the assets:
```math
\boxed{
    \text{REP Tokens Minted} = \frac{\text{Open Interest} \cdot \text{REP Token Supply}}{\text{REP Market Cap} - \text{Open Interest}}
}
```
It can be seen from the equation that $\text{Open Interest}$ needs to be smaller than $\text{REP Market Cap}$, otherwise it becomes impossible to mint enough $REP$.

#### Multiasset support
In the multiple asset case scenario, the open interest need to be known separately for each asset:
```math
\text{Open Interest}_{asset} \in \{\; \text{Open Interest}_{ETH},\;\text{Open Interest}_{Food}, ... \;\}
```
We can then get the minting amount needed:
```math
\text{REP Tokens Minted}_{asset} = \frac{\text{Open Interest}_{asset}}{\text{REP Token Price}_{asset}}
```

where $\text{REP Token Price}_{asset}$ is $REP$ token price in asset, which is again a function of $REP$ we mint, not just the amount we need to mint for $asset$ open interest holders:

```math
\text{REP Tokens Minted} = \sum_{a \in \text{all assets}}{\text{REP Tokens Minted}_a}
```
We can then get $REP$'s token price in the same unit as the market cap is calculated, e.g., dollars($):
```math
\text{REP Token Price}_{USD} = \frac{\text{REP Market Cap}_{USD}}{\text{REP Token Supply}+\sum_{ a \in \text{all assets} }{\text{REP Tokens Minted}_{a}}}
```
We then need to have a price oracle for each $asset$ in dollars:
```math
\text{REP Token Price}_{asset} = \frac{\text{REP Token Price}_{USD}}{\text{Asset Token Price}_{USD}}
```

We can then deduce how much $REP$ we need to mint against each collateral:

```math
\begin{aligned}
\text{REP Tokens Minted}_{asset} =\ & 
\frac{\text{Open Interest}_{asset} \cdot \text{Asset Token Price}_\$}
     {\text{REP Market Cap}_\$ - \text{Open Interest}_{asset} \cdot \text{Asset Token Price}_\$}
\\[10pt]
& \cdot \left( \text{REP Token Supply} + \sum_{a \ne asset}{\text{REP Tokens Minted}_a} \right)
\end{aligned}
```

This can be solved in closed form when there's one or two assets, but requires a numerical solution for more assets.

We also need to assume that minting $REP$ and giving the external assets to $REP$ holders (who might sell the assets) has no impact on the relative asset prices.

#### Attacking the multiasset system

There's an easy attack you can do to against this system. The system requires that we have a reliable price oracle for each collateral. If we allow users to trade with any asset out there, we cannot guarrantee the asset will have a reliable oracle. Given we have an asset $attack$, and we are able to control its price, we can mint infinite $REP$:
```math
\text{REP Tokens Minted}_{asset} =\lim_{\text{REP Token Price}_{attack} \to 0} \frac{\text{Open Interest}_{attack}}{\text{REP Token Price}_{attack}} = \infty
```

#### Pro's and cons compared to liquidation
Pros:
 - No big liquidation events to crash the market
 - Smaller market liquidity requirements: We only need enough $REP$ liquidity for each asset to measure their fair price
 - No trading fees
 - The costs are socialized to $REP$ holders instead to open interest holders

Cons:
 - We need to have an access to reliable price oracles
 - We cannot support arbitary assets
 - During the price measurement, there's two sides trying to manipulate the market:
     - $REP$ holders prefer as little as possible $REP$ to be minted
     - Open interest holders prefer as much as possible $REP$ to be minted

> [!WARNING]
> TODO: research if we can somehow guarrantee that manipulating price oracle is harder than the assets we use for it

## Cost of fork
The cost to trigger a fork should be high enough to cover the potential cost of liquidating all open interest, helping to keep the system solvent during a fork. To prevent abuse, triggering a fork should also require burning some assets - ensuring it’s never free and discouraging spam or griefing. If the system only burns REP as a defense, an attacker who controls 100% of both REP and OI could still fork at no real cost, defeating the purpose of the safeguard. Forks affect all users and are irreversible, similar to Ethereum’s state growth problem, so their cost should reflect the broad impact. This means the cost should scale with the number of users involved, not just the total value at stake. Ultimately, the cost to traders should increase with the amount of open interest in the system to align incentives and maintain security.

## Liquidity of REP
The system's security relies heavily on the liquidity of $REP$. But can we guarantee $REP$ will always be liquid enough? One approach could be to allocate a portion of system fees to a $REP$ liquidity pool. However, this isn't foolproof - we can’t guarantee that the system will have generated enough fee revenue to absorb a major liquidity shock when it's needed most.

## Paying a bonus for open interest holders
The $REP$ gained from the open interest auction is very likely worth less than the original assets, could we compensate these users by minting them extra $REP$?

What is the upper limit bonus we can give to traders that won't break incentives? As the forks are disruptive, there could be some kind of escalation game that results in fork to trigger, similarly to Augur v2. In Augur v2 At least $1.25\%$ of $REP$ needs to be destined for $REP_{lie}$ for a fork to happen, and if the $REP$ targeting mechanism is working properly then this means $1.25\%$ of $5 \cdot \text{Open Interest}$, we need to make sure we don't mint more value than $6.25\%$ of open interest. However, this assumes there are no other incentives for attacking the system.

If we assume then we have at most $\text{Total Compensation}$ assets to give to open interest holders, where:
```math
\text{Total Compensation} < 0.0625 \cdot \text{Open Interest}
```

The open interest holders pay total trading costs of $\text{Total Trading Costs}$ (this includes trading fees, slippage, $REP$ price drop, etc). Let's assume $\text{Total Trading Costs}$ flows outside the system (e.g., the participants of this system are not running their own exchanges). The open interest holders result in asset valuation
```math
\text{Asset Valuation} = \text{Open Interest} - \text{Total Trading Costs} + \text{Total Compensation} 
```
If $\text{TotalCompensation} < \text{Total Trading Costs}$, the Open Interest holders still lose money in the fork.

A happier outcome here is when $\text{Total Compensation} > \text{Total Trading Costs}$, as then traders are paid more than the fees were, and they are compensated for the trouble of the fork. However, this opens an attack surface. If the fork results in open interest holders to gain, an attacker could notice that fork is about to occur and purchase huge amount of open interest and capture most of this compensation for them. The risk of this is difficult to calculate as most likely the bigger the auctioned open interest amount is, the higher the \text{Total Trading Costs}$ become. It is also important that the cost to fork is higher than what open interest holders could profit.

> [!WARNING]
> TODO: We could analyze on the impact on the market and markets liquidity requirements assuming theres x rep, y eth locked in unisvap v2
> 
> TODO: We could also try to try to measure the loss traders are making and minting enough rep to cover it

## Avoiding Forks - The Escalation Game

Forks in partial-colored coin systems can be highly disruptive. When a fork occurs, all open interest is liquidated, and users are forced to migrate to a new universe. To minimize this disruption, forks should be treated as a last resort - only occurring when no other resolution is possible. One mechanism to help avoid forks is the escalation game, which enables users to coordinate and resolve disputes collectively.

The primary goals of the escalation game are:

1. **Long-Term Coordination** - Enable sustained collaboration among participants over time of the dispute
2. **Public Commitment** - Allow individuals to visibly signal their belief in the correct outcome
3. **Anti-Hedging Cost** - Impose a cost on participation to prevent users from supporting multiple sides
4. **Incentive Alignment** - Ensure users who choose correctly are rewarded more than they lose by participating
5. **Collective Funding** - Support pooled contributions toward a shared resolution goal
6. **Decision or Deadlock** - Include a path to force a resolution or formally declare a stalemate
7. **Affordable Stalemate** - Make “no decision” affordable but not easily exploitable
8. **Broad Participation** - Maximize inclusion by making participation widely accessible

In Augur V2, a fork is triggered when 2.5% of all theoretical $REP$ is staked on a single outcome during the escalation game:

> Forking is a last-resort resolution mechanism. It is highly disruptive and intended to be rare. A fork occurs when an outcome in a market successfully fills a dispute bond equal to at least 2.5% of the total theoretical REP.

If the escalation game concludes without triggering a fork, Augur V2 assumes the final staked outcome is correct and resolves the market accordingly.

The escalation games can result in incorrect outcomes. If too few users are willing or able to participate - especially in researching and voting on complex markets - the game may be dominated by poorly informed or misaligned participants. This is especially problematic in high-stakes markets, where the cost of incorrect resolution is significant.

We must prioritize accurate resolution in markets with substantial open interest. These users are paying customers; if they lose money due to incorrect outcomes, their trust in the system erodes. In such cases, user retention and system credibility are at risk.

### Which Token Should Be Used in the Escalation Game?

An escalation game requires a token that is valuable, liquid, and fork - capable. Augur V2 uses $REP$, as it is the only token within the protocol that supports forking. The Partial Colored Coins system extends this by enabling external assets to be converted into $REP$ in the event of a fork.

Using external assets in escalation games brings notable advantages: improved liquidity, greater price stability, having externally valuable asset, and increased participant accessibility. Higher liquidity attracts more users, and stable prices make the potential rewards from escalation more predictable. Being able to access externally valuable asset also allows the system to burn that asset and be more confident that attackers lose value even if they own significant portion of $REP$ tokens.

Moreover, since Partial Colored Coin users may already have exposure to $REP$ through open interest, they might be reluctant to increase that exposure solely to participate in a dispute. Allowing disputes to be funded with external tokens enables these users to engage without acquiring additional $REP$.

However, this approach comes with trade - offs. If the escalation game ends with a "no decision" outcome, participants are forced to convert the external asset back into $REP$, incurring additional fees and re - exposing themselves to $REP$’s volatility risk.

A further complication lies in determining how much of the external asset is needed to trigger a fork. If the external asset is the same as the one used in the open interest, the fork threshold could be set as a percentage of that open interest. But in the Partial Colored Coins system, some markets use $REP$ while others use external assets. Basing the threshold solely on external asset open interest might result in a near - zero threshold, ignoring $REP$ - denominated markets. Both types of markets need to be incorporated into the fork threshold calculation.

### Normalization of Deviance

Escalation games are optimistic systems  -  they assume that the currently winning outcome is correct unless it is actively disputed. If these escalation games resolve correctly most of the time, users may begin to trust them blindly, leading to a phenomenon known as the normalization of deviance: the system appears to work reliably, so people stop scrutinizing it.

In Augur V2, it was assumed that those with the most at stake - users with open interest in a market - would participate in the early rounds of escalation. Their involvement is expected to draw attention to disputes and encourage those with more $REP$ to stake in support of the correct resolution.

One proposed mitigation to this issue is the use of paid reporters who are required to report on every market. If a paid reporter submits an incorrect resolution, others can challenge it through the escalation game. If the challenge succeeds, the reporter is removed from the system, the market is resolved according to the escalation outcome, and the faulty reporter forfeits their position and associated rewards. The system then selects a replacement reporter.

A similar mechanism exists in reality.eth, where a role called the *adjudicator* serves a comparable function - ensuring correctness and accountability in market resolutions.

### Parameters to consider for the escalation game
1) How much to burn (v2 has 20%)
2) How much to award to open interest holder (v2 has 0%)
3) How much award to people who played escalation game (v2 has 40%)

> [!WARNING]
> TODO: The cost of fork should at min be the cost of the pain caused to open interest holders. However, we don't know how much this is, and if we pay too much, it introduces an attack vector.
>
> TODO: The cost should be higher than the cost occured to open interest holders, however, its hard to measure the cost introduced to traders

## Prior Oracles Break "Bet and Forget"
Without prior oracles such as escalation games or designated reporter, you can make a bet, and forget about the bet until you want to bet again or withdraw. Prior oracles break this, as they require you to pay attention to the prior oracle resolutions and be ready to dispute their resolutions. 
