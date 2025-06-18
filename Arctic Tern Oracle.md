# The Arctic Tern Oracle

![image](images/arctic_tern.png)

The Arctic tern is a bird species that holds the long-distance migration record for birds, travelling between Arctic breeding grounds and the Antarctic each year.

The Arctic Tern Oracle is a [Partial Colored Coin Oracle](/Partial%20Colored%20Coins.md) designed to shift the volatility risk of $REP$ after a fork from open interest holders to $REP$ holders.

## Open Interest and REP Migration

When a fork occurs following a failed escalation game, all $REP$ holders must choose which universe they believe is correct by migrating their $REP$ accordingly. Since the system includes open interest in external assets (eg, ETH), each migrating $REP$ holder also transfers a proportional share of the open interest to the universe they select. E.g. 1% of all $REP$ can move 1% of the total open interest to the universe where that $REP$ is migrated. This open interest belongs to all of the markets in the original universe (both forking and non-forking markets).

For this mechanism to remain secure, the value of the **$REP$ being migrated must exceed the value of the Open Interest it moves**. Otherwise, a malicious $REP$ holder could shift a significant portion of open interest to a universe in which they hold favorable positions. Therefore, it is essential that:
```math
\text{REP Market Cap} > \text{Open Interest}
```
> \[!NOTE]
>
> #### Example: REP and Open Interest Migration
>
> Bob holds 5 $REP$ out of a total supply of 100 $REP$. The prediction market has a single market with 10 $ETH$ in outstanding bets (Open Interest).
>
> When the Oracle forks into $REP_A$ and $REP_B$, Bob believes universe A is correct and migrates his 5 $REP$ to $REP_A$. As a result:
>
> * He receives 5 $REP_A$
> * He transfers a proportional share of open interest:
>   $\frac{\text{5 ETH}}{\text{100 ETH}} \cdot 10$ $ETH$ $=$ 0.5 $ETH$
>   So, 0.5 $ETH$ of open interest moves to universe A.
>
> The remaining $REP$ holders (95 $REP$) believe universe B is correct and migrate there, transferring:
>
> * 95 $REP_B$
> * $\frac{\text{95 ETH}}{\text{100 ETH }} \cdot 10$ $ETH$ $=$ 9.5 $ETH$ of open interest
>
> In the end:
>
> * Universe A holds 5 $REP_A$ and 0.5 $ETH$ of open interest
> * Universe B holds 95 $REP_B$ and 9.5 $ETH$ of open interest

## Making Open Interest Holders Whole

The open interest migration process helps restore value to open interest holders in their respective universes. However, if not all $REP$ holders migrate to the same universe, open interest holders still lose value.

A fork splits the original $REP$ into multiple universes, each receiving a fraction of the total $REP$. For example, if universe A receives $40\%$ of all $REP$, and we assume that universe A maintains the original universe’s Fully Diluted Valuation (FDV), then:

* **$REP_A$ holders** effectively gain $60$ percentage points in value
* **open interest holders** in universe A lose $100\% - 40\% = 60\%$ of the original open interest

To balance this out, we can mint $60\%$ additional $REP_A$ tokens, restoring the $REP_A$ supply in universe A to match the original. These newly minted tokens can be distributed to open interest holders to compensate for the lost $60\%$ of open interest. The open interest holders in universe A would end up with:

```math
\text{New Open Interest} = \text{Original Open Interest} \cdot 40\% + \text{REP A Market Cap} \cdot 60\%
```

Assuming:
```math
\text{REP A Market Cap} > \text{Original Open Interest}
```

This amount is greater than their initial open interest value.

The net gain for open interest holders depends on two factors:

* How much $REP$ failed to migrate to universe A (bigger the better)
* The ratio of the $REP$ market cap to the original open interest (bigger the better)

### Open Interest Value Capture Attack

Since open interest holders can profit from both attacker-induced and inactive (or "sleeping") $REP$, this opens the door to an opportunistic value capture attack on the system.

Suppose $10\%$ of the total $REP$ and corresponding open interest migrates to a false universe, denoted as $REP_{lie}$. In this case, $10\%$ additional $REP$ is minted in the correct universe, $REP_{truth}$, and distributed to open interest holders there as compensation.

An opportunistic actor could exploit this by generating as much open interest as possible just before the fork, aiming to claim a disproportionate share of the newly minted $REP_{truth}$. Since $90\%$ of the open interest remains in $REP_{truth}$, the attacker recovers most of their open interest ($90\%$) while also gaining bonus $REP_{truth}$ at cost of $10\%$ in open interest.

In the worst-case scenario, nearly all of the open interest (except for a small $\epsilon$) is controlled by the Opportunist. They then receive nearly $100\%$ of the bonus $REP_{truth}$, while the small fraction of honest open interest holders (holding $\epsilon$) receives just enough $REP_{truth}$ to break even. However, if $REP_{truth}$ is volatile, even honest traders may face losses despite this compensation.

An Opportunist will find it profitable to mint new open interest up to the limit where:
```math
\text{Total Open Interest} = \text{REP Market Cap}
```
As long as this condition holds, the attack is economically viable.
### Mitigation: Introducing Auctions with Capped Minting

To prevent value capture attacks, we introduce **$REP_{truth}$ → $ETH$ auctions** as a mitigation mechanism.

The core issue arises when open interest holders are overcompensated with $REP_{truth}$, creating an incentive for opportunistic actors to game the system. Instead of directly giving $REP$ to open interest holders, the system should aim to return **exactly what is owed** to them - no more, no less.

This can be achieved via auctions. In each universe, we auction off the $REP$ **that did not migrate into it**, exchanging it for the open interest asset (e.g., $ETH$). The auction aims to raise just enough value to cover the open interest shortfall. Any unsold $REP$ is **burned**, which benefits honest $REP$ holders by increasing the value of the remaining supply, while penalizing attackers.

If the auction fails to raise sufficient funds to cover the missing open interest - for example, due to low demand or temporary volatility - we fall back to directly distributing the remaining $REP$ to open interest holders.

### All the options

There's a few ways to attempt to make open interest whole after migration:
1) **Give REP**: Give open interest holders the non-migrated $REP$ (vulnerable to opportunistic attack)
2) **Infinite REP Auction**: Auction off at max infinite amount of $REP$ to try to make open interest holders whole. The open interest holders can never receive anything else than a share (or all) their open interest in external assets
3) **Capped Auction**: Auction of the non-migrated $REP$ and burn the rest, if the auction fails to raise, fall back to (1).

## Maintaining REP Market Cap > Open Interest

To ensure the system remains secure, it is absolutely critical that:

```math
\text{REP Market Cap} > \text{Open Interest}
```

One way to maintain this condition is by regulating the cost of maintaining open interest - similar to the dynamic fee model used in Augur V2. However, Augur V2 relies on a controller to adjust fees, which reacts slowly to sudden spikes in open interest.

A more robust alternative is to **enforce a hard cap on insurable open interest**. Augur V2 cannot practically implement this, as it's more important for it to register open interest - even if excessive - than to risk unregistered parasitic interest. However, in a **Partial Colored Coin-based system** like Arctic Tern, only registered open interest is insured. This allows us to set strict limits on how much open interest we are willing to support.

### Security Multiplier

Similar to Augur V2’s Security Multiplier parameter (set to 5× in the design), Arctic Tern can use a hard constraint:

```math
\text{Open Interest} \cdot \text{Security Multiplier} \leq \text{REP Market Cap}
```

To compute REP Market Cap, we use a price oracle that provides the $ETH$ value of $REP$:

```math
\text{REP Market Cap} = \text{REP Supply} \cdot \frac{ETH}{REP}
```

### REP/ETH Price Oracle

Maintaining the critical condition $\text{Open Interest} < \text{REP Market Cap}$ requires a price feed. The Security Multiplier must be set high enough to account for expected inaccuracies or delays in the oracle's price data. This buffer ensures that even with small oracle errors, the system stays within safe bounds.

### Open Interest Burning

An even more final approach to maintaining system security is to **burn a portion of the open interest** when it exceeds safe thresholds. While this results in a loss for open interest holders, it ensures the system remains secure for a fraction of the original open interest by keeping total insured open interest below the $REP$ market cap.

This method effectively sacrifices a fraction of open interest to preserve the integrity of the system. Though harsh, it guarantees that only the insurable portion of open interest - aligned with the $REP$ market cap - remains valid. This ensures that an attacker cannot profit of the system.

> [!WARNING]
> TODO Could we use the extra open interest smarter, eg buy REP?

### Summary of the options:
1) Creating open interest has a cost (onetime / time based)
2) Introduce hard open interest creation cap
3) Burn exess open interest in order to stay under the limit
