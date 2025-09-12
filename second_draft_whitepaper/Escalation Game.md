# Escalation Game
PLACEHOLDER's Escalation Game is a [War of Attrition](https://en.wikipedia.org/wiki/War_of_attrition_(game)) kind of game where three different potential market resolution outcomes (Invalid, Yes, No) stake REP on each respective side. REP Holders can choose to participate on any side of the battle and even participate on multiple sides. The Escalation Game ends with one of the following outcomes: `INVALID`, `YES`, `NO`, or `FORK`.

The game starts if someone stakes more than Market Creator Bond on a different outcome than Initial Reporter before Dispute Period Length runs out. If this doesn't happen during the time period the outcome proposed by the reporter is finalized.

If the market is disputed, the battle becomes active. Once a battle is active, anyone may deposit REP on any side. The game functions as a War of Attrition: Escalating the battle becomes increasingly expensive over time. The cost to participate for each side grows over time, following formula:

```math
\text{Attrition Cost} = \text{matchedRepInvestment(Time Since Start)} = \max(
\frac{\text{OpenInterestHarm(Time Since Start)}}{2\cdot \text{BurnShare}}, \text{Fork Treshold} \cdot \left(\frac{\text{Time Since Start}}{\text{Time Limit}}\right)^k)
```

In the equation $\text{OpenInterestHarm(Time Since Start)}$ is a cost function that is an estimation on how much Open Interest holders of the delayed market are being harmed. The idea is to always burn more REP than we estimate delayers can gain by delaying the Open Interest from resolving.

$\text{BurnShare}$ is a fraction of the participating REP that gets burnt, We are using $\text{BurnShare}=\frac{1}{5}$. $\text{Fork Treshold}$ is amount of REP that needs to be contributed to the game at least for the market to fork. If open interest is zero for the market, this is the cost that needs to be paid by each side to fork the market, however, if there's Open Interest in the market, then the fork cost is higher.

$\text{Time Limit} = 7$ weeks is the max amount the Escalation Game lasts. And $k = 5$ is a parameter that can be used to adjust the steepness of the escalation game curve.

The system will then burn $\text{repBurn(Time Since Start)}$ amount of REP:
```math
\text{repBurn(Time Since Start)} = 2 \cdot \text{BurnShare} \cdot \text{matchedRepInvestment(Time Since Start)} 
```

# Winning the game
If, at any point in time, only one side has successfully paid the Attrition Cost, the battle ends and that outcome is finalized for the market.

Alternatively, the battle ends in a fork if **two or more sides** manage to deposit the full $\text{Attrition Cost(7 weeks)}$ amount of REP. It is not possible to deposit more than that on any single side.

The winner of the escalation game (either by timeout, or by fork for each side) gets return on investment:
```math
\text{Return On Investment} = \frac{2 \cdot \text{matchedRepInvestment(Time Since Start)} - \text{repBurn(Time Since Start)} + \text{overStake}}{\text{matchedRepInvestment(Time Since Start)}+ \text{overStake}} - 1
```

In this equation $\text{overStake}$ is amount of REP the winning side can stake over the matched REP investment while still being rewarded for their stake. The purpose of this parameter is to allow winning side to always stake more to be sure the market resolves in their favor and have enough time to react if it gets macthed by the opposin side. It's always profitable for winning side to stake at most half more of $\text{matchedRepInvestment(Time Since Start)}$ than the losing side to still gain expected profit of 40%.

If the game ends up in a fork, the sides are rewarded 80% instead, as its not possible to over stake over the maxium amount.

## Open Interest Harm Modeling
The harm that is caused for Open Interest Holders of the market (capital lockup) can be modeled as follows:
```math
\text{OpenInterestHarm(Time Since Start)} = \alpha\cdot\text{Single Market Open Interest} \cdot \text{Open Interest Fee} \cdot \text{Time Since Start} \cdot \frac{REP}{ETH}
```

In this function, $\text{Open Interest Fee}$ represents the estimated per-second cost to keep Open Interest locked for an extended period, while REP/ETH denotes the estimated REP's price in ETH. The price oracle does not need to be perfectly precise because winners expect to earn a substantial profit; small inaccuracies in the price can be absorbed within that profit margin. The parameter α = 1.5 serves as a safety factor and can be increased to account for larger inaccuracies in both the price oracle and the $\text{Open Interest Fee}$ estimation.

When the game ends, either to timeout or fork:
1) Winner is paid $2 \cdot \text{matchedRepInvestment(Time Since Start)} - \text{repBurn(Time Since Start) + \text{preStake}}$ REP (where $\text{matchedRepInvestment(Time Since Start)}+\text{preStake}$ is what was invested into the game from this side)
3) REP is being burnt: $\text{repBurn(Time Since Start)}$ REP

Since the `REP/ETH` price can change over the course of the game, the system fixes the `REP/ETH` rate at the start of the game. This ensures that both sides receive the same effective price for each second of escalation.

## Multiple participants for each side
While the game consists of only three different sides, multiple players can play on each side. Each winning player is rewarded their min 40% return on investment if their stake ends up contributing to the War while the game was running and they contributed before $\frac{3}{2}\text{matchedRepInvestment(Game Ended Time)}$ was invested into the winning side.

## Estimating Open Interest Fee

Let's assume that an attacker gets paid 
```math
\text{pay(Time Since Start)} = \frac{REP}{ETH}\cdot\text{Single Market Open Interest}\cdot\text{Open Interest Fee}\cdot \text{Time Since Start}
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
\max(\frac{d \cdot \text{REP Burned}}{dt})
& \text{if } \text{Market Delayed} > 0 \\[12pt]
0
& \text{otherwise}
\end{cases}
```

We can then create estimator for $\text{Open Interest Fee}$ as:
```math
\text{Open Interest Fee} = \max(\frac{\sum_{m \in \text{All Finalized Markets}}\text{\text{Burn Rate}}_m \cdot \text{Single Market Open Interest}_m}{\sum_{m \in \text{All Finalized Markets}}\text{Single Market Open Interest}_m},\text{Min Open Interest Fee})
```

A big assumption made here is that we assume that all the REP getting burned is being spent because one wants to delay the market. However, this is not always true, one might participate escalation game as a means of communication or with intent to fork. For this reason we calculate $\frac{d \cdot \text{REP Burned}}{dt}$ at most at midpoint over the escalation game ($t\in[0,\frac{1}{2}\text{Time Limit}]$).

### Late Entry into a Battle

An interesting feature of the system is that participants can join an ongoing battle at any time. For example, if `YES` and `NO` are actively competing, the `INVALID` side can still enter later by depositing the required attrition cost at that point in time.

In other words, **it is not necessary to be part of the battle from the beginning** - but joining later requires paying the full cumulative cost up to that moment.

## Capping the Capital

A single escalation game described above still shares a core vulnerability with Augur V2:
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

## Parameters

| Parameter                           | Value                                |
| ----------------------------------- | ------------------------------------ |
| Security Parameter                  | 2                                    |
| Burn Share                          | $\frac{1}{5}$                        |
| k                                   | 5                                    |
| Time Limit                          | 7 weeks                              |
| Market Creator Bond / Start Deposit | 1 / 11 000 000 * 100 % of REP Supply |
| Fork Theshold                       | 2.5% of REP Supply                   |
| Number of Immune Markets            | 3                                    |
| Freeze Threshold                    | 3 × Fork Threshold                   |
