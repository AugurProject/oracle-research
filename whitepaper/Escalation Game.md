# Escalation Game
PLACEHOLDER's Escalation Game is a [War of Attrition](https://en.wikipedia.org/wiki/War_of_attrition_(game)) kind of game where three different potential market resolution outcomes (Invalid, Yes, No) stake REP on each respective side. REP holders can choose to participate on any side of the battle and even participate on multiple sides. The Escalation game ends with one of the following outcomes: `INVALID`, `YES`, `NO`, or `FORK`.

The game starts if someone stakes more than **Market Creator Bond** on a different outcome than Initial Reporter/Designated Reporer reported on before **Dispute Period Length** runs out. If this doesn't happen during the time period the outcome proposed by the reporter is finalized.

If the market is disputed, the battle becomes active. Once a battle is active, anyone may deposit $REP$ on any side. The game functions as a War of Attrition: Escalating the battle becomes increasingly expensive over time. The cost to participate for each side grows over time, following this formula:

```math
\text{matchedRepInvestment(Time Since Start)} = \max(
\frac{\text{OiHarm(Time Since Start)}}{2\cdot \text{BurnShare}}, \text{Fork Treshold} \cdot \left(\frac{\text{Time Since Start}}{\text{Time Limit}}\right)^k)
```

This is also called the attrition cost to stay in the game. In the equation $\text{OiHarm(Time Since Start)}$ is a cost function that is an estimation on how much Open Interest holders of the delayed market are being harmed. The idea with this is that we always burn more REP, than we estimate that griefers can gain by delaying the Open Interest resolving.

 $\text{BurnShare}$ is a fraction of the participating REP that gets burnt, We are using $\text{BurnShare}=\frac{1}{5}$. $\text{Fork Treshold}$ is amount of REP that needs to be contributed to the game at least for the market to fork. If open interest is zero for the market, this is the cost that needs to be paid by each side to fork the market, however, if there's Open Interest in the market, then the fork cost is higher.

$\text{Time Limit}$ is the max amount the Escalation Game lasts. And $k = 5$ is a parameter that can be used to adjust the steepness of the escalation game curve.

The system will then burn $\text{repBurn(Time Since Start)}$ amount of rep:
```math
\text{repBurn(Time Since Start)} = 2 \cdot \text{BurnShare} \cdot \text{matchedRepInvestment(Time Since Start)} 
```

The winner of escalation game (either by timeout, or by fork for each side) gets a profit of:
```math
\text{Total Profit in REP} = \frac{2 \cdot \text{matchedRepInvestment(Time Since Start)} - \text{repBurn(Time Since Start)} + \text{overStake}}{\text{matchedRepInvestment(Time Since Start)}+ \text{overStake}} - 1 \geq \text{Expected Profit}
```

In this equation $\text{overStake}$ is amount of $REP$ the winning side can stake over the matched REP investment while still being rewarded for their stake. The purpose of this parameter is to allow winning side to always stake abit more to be sure the market resolves in their favor. It's always profitable for winning side to stake at most half more of $\text{matchedRepInvestment(Time Since Start)}$ than the losing side to still gain expected profit of 40%.

We estimate that the OiHarm can be modelled with function:
```math
\text{OiHarm(Time Since Start)} = \alpha\cdot\text{Single Market Open Interest} \cdot \text{OiFee} \cdot \text{Time Since Start} \frac{REP}{ETH}
```

In this function $\text{OiFee}$ is estimated per second cost to keep Open Interest locked for extra time and $\frac{REP}{ETH}$ is the estimated price rep/eth price. This oracle does not need to be perfectly accurate because the winners anticipate a significant profit; minor inaccuracies in the price can be absorbed by that profit margin. The variable $α=1.5$ can be adjusted upwards to accommodate greater inaccuracies in the price oracle and in $\text{OiFee}$ estimation.

When the game ends, either to timeout or fork:
1) Winner is paid $2 \cdot \text{matchedRepInvestment(Time Since Start)} - \text{repBurn(Time Since Start) + \text{preStake}}$ $REP$ (where $\text{matchedRepInvestment(Time Since Start)}+\text{preStake}$ is what was invested into the game)
3) REP is being burnt: $\text{repBurn(Time Since Start)}$ $REP$

Since the `REP/ETH` price can change over the course of the game, the system fixes the `REP/ETH` rate at the start of the game. This ensures that both sides receive the same effective price for each second of escalation, maintaining fairness regardless of when the contribution is made.

## Estimating OiFee

Assume that an attacker gets paid 
```math
\text{pay(Time Since Start)} = \frac{REP}{ETH}\cdot\text{Single Market Open Interest}\cdot\text{OiFee}\cdot \text{Time Since Start}
```
for delaying the game for $\text{Time Since Start}$ seconds. it also costs:
```math
\text{repBurn(Time Since Start)} = 2 \cdot \text{BurnShare} \cdot \text{matchedRepInvestment(Time Since Start)} 
```
to delay (stake on both sides) to delay the market. We want the attacker to burn more than they stand to gain:
```math
\text{repBurn(Time Since Start)} \geq \text{pay(Time Since Start)}
```

We can compute how much delayers were willing to burn for delaying a market as:
```math
\text{Burn Rate} =
\begin{cases}
\displaystyle
\frac{\text{REP Burned}'}{\text{Market Delayed}}
& \text{if } \text{Market Delay} > 0 \\[12pt]
0
& \text{otherwise}
\end{cases}
```

We can then create estimator for $\text{OiFee}$ as:
```math
\text{OiFee} = \max(\frac{\sum_{m \in \text{All Finalized Markets}}\text{\text{Burn Rate}}_m \cdot \text{Single Market Open Interest}_m}{\sum_{m \in \text{All Finalized Markets}}\text{Single Market Open Interest}_m},\text{Min OIFee})
```


## Cost to Stay in game
We get following cumulative cost to stay in the battle given each week:

TODO: MISSING IMAGE

If, at any point in time, only one side has successfully paid the attrition cost, the battle ends and that outcome is finalized.

Alternatively, the battle ends in a fork if **two or more sides** each manage to deposit the full $\text{Fork Threshold} + \text{OiHarm(Time Limit)}$ amount of REP. In this case, PLACEHOLDER forks, allowing the creation of separate universes. Notably, **it is not possible** to deposit more than the $\text{Fork Threshold} + \text{OiHarm(Time Limit)}$ on any single side.

### Late Entry into a Battle

An interesting feature of the system is that participants can join an ongoing battle at any time. For example, if `YES` and `NO` are actively competing, the `INVALID` side can still enter later by depositing the required attrition cost at that point in time.

In other words, **it is not necessary to be part of the battle from the beginning** - but joining later requires paying the full cumulative cost up to that moment.

## Capping the Capital

A single escalation described above still shares a core vulnerability with Augur V2:
An attacker can initiate multiple disputes across many markets simultaneously. Unless honest participants have enough capital to defend all of them, attackers can overwhelm the system.

To address this we introduce a priority queue and a global capital cap.

### Freeze Threshold

Under normal conditions, The Escalation Game behaves similarly to Augur V2 - multiple escalation games can run in parallel. However, once the total binding capital across all active battles exceeds a predefined Freeze Threshold, the system enters a special Freezing State.

For example, the Freeze Threshold can be defined as:

```math
\text{Freeze Threshold} = 3 \cdot \text{Fork Threshold}
```

### Freezing State Behavior

When the system enters the Freezing State:

* The top three markets (by binding capital) are selected.
* These markets become immune to freezing for the rest of their lifecycle.
* All other markets are frozen.

Frozen markets can still receive new stakes, but their Attrition Cost remains fixed (i.e., does not increase with time) while the system is in the Freezing State.

### Exiting the Freezing State

The system exits the Freezing State once the total binding capital drops below the Freeze Threshold. After exiting:
* All frozen markets resume normal attrition behavior.
* Markets that were granted immunity remain permanently immune.
* If a new freeze occurs and fewer than three markets are currently immune, new ones are added from the priority queue until the three-slot immunity is filled again.

### Worst-Case Capital Requirement for the Honest Side

In the worst case, attackers create as many markets as possible and submit incorrect reports via designated reporters. The honest side is then forced to defend all these markets, which maximizes their capital requirements.

Before the system enters the Freezing State, the maximum number of active, disputed markets is:

```math
\text{Number of Disputed Markets} = \left\lfloor \frac{\text{Freeze Threshold}}{\text{Start Deposit}} \right\rfloor
```

Adding one more market at this point will push the system into Freezing State.

After the system freezes:
* The top three markets (by binding capital) become immune.
* Honest participants only need to defend these three, up to the Fork Threshold.

Thus, the worst-case capital requirement for the honest side is:

```math
\text{Worst Capital Requirement} = \text{Freeze Threshold} + \text{Start Deposit} + \text{Number of Immune Markets} \cdot (\text{Fork Threshold} - \text{Start Deposit})
```

Assuming:

* `Freeze Threshold = 3 × Fork Threshold`
* `Number of Immune Markets = 3`

Then:

```math
\text{Worst Capital Requirement} = 6 \cdot \text{Fork Threshold} - 2 \cdot \text{Start Deposit}
```

This is a reasonably bounded and predictable worst-case scenario, and a significant improvement over systems like Augur V2.

### Practical Worst Case

Despite this theoretical bound, practical capital requirements may be higher due to stake lock-up. If honest stakers commit funds to markets that later get frozen and don't progress, that capital is stuck without increasing attrition cost-effectively wasting resources.

To mitigate this, one possible improvement is to allow users to withdraw non-binding capital from frozen markets (i.e., funds not currently matched by an opposing side).
