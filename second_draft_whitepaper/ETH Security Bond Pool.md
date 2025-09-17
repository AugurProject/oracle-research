# ETH Security Bond Pool - Getting rid of price oracle

We can remove the dependency on an ETH price oracle by applying ideas from [Ajna](https://www.ajna.finance/pdf/Ajna_Protocol_Whitepaper_01-11-2024.pdf).

## Initial Setup

Assume the real ETH/REP exchange rate is 0.5. An ETH Security Bond Pool allows users to create REP-collateralized positions. Three users - Alice, Bob, and Cecilia - each open a position by posting a limit order to sell 100 REP for ETH, with different collateralization levels that determine their liquidation prices:

| Position Owner | Security Bonds Minted | Liquidation Price (ETH/REP) | REP Balance | REP Balance in ETH |
| -------------- | --------------------- | --------------------------- | ----------- | ------------------ |
| Alice          | 10                    | 0.2                         | 100         | 50                 |
| Bob            | 12.5                  | 0.25                        | 100         | 50                 |
| Cecilia        | 20                    | 0.4                         | 100         | 50                 |

Each position creator chooses the liquidation price for their position based on how much Security Bonds they have chosen to mint. They can mint Security Bonds against the posted REP collateral, which traders can then buy. The liquidation price for each position is:

```math
\text{Liquidation Price}_{ETH/REP} = \frac{\text{Security Bonds Minted} \times \text{Security Multiplier}}{\text{REP Balance}}
```

A Security Bond can be paired with 1 ETH to form a "Complete Set" for any market on PLACEHOLDER. Complete Sets are denominated in ETH and backed by REP. When the market settles, the Security Bond is released and can be returned to the position to reduce outstanding bond debt.

## Liquidation When ETH/REP Falls

Suppose the ETH/REP price drops to 0.3. Any position with a liquidation price above 0.3 can be liquidated profitably.

To trigger a liquidation auction, a liquidator posts a bounty in REP:

```math
\text{Liquidation Bounty} = \text{Position REP Balance} \times \text{Liquidation Bonus Fraction}
```

* Cecilia’s position is the first eligible for liquidation since its liquidation price (0.4) is the higest above market.
* Bob’s position could also be targeted, but only after Cecilia’s is already under liquidation, preventing griefing of healthier positions.

Once liquidation begins, Cecilia’s pool becomes frozen: no deposits, withdrawals, or bounty adjustments are allowed. A pay-as-bid Dutch auction is then started for Cecilia’s 100 REP, with the opening price:

```math
\text{Auction Start Price} = \text{Liquidation Price} \times \text{REP Balance} \times 256 = 0.4 \times 100 \times 256 = 1024 ETH
```

* Auction proceeds are paid to Cecilia.
* If the final clearing price is above her liquidation price, Cecilia also receives the liquidation bounty.
* If it ends below, the bounty is refunded to the liquidator.

Once the auction closes (successful or not), the position unfreezes and can be used normally again.

The purchaser of complete or sub position will then move the bought REP into their own position along with the security bond debts. The liquidator is also able to purchase liquidity bonds off the market to close the whole position without moving it into their position.

## Liquidation Penalty (Work in Progress)

To discourage position owners from griefing liquidators (e.g. by buying their own position back at a high price), a penalty is applied:

```math
\text{Borrower Liquidation Penalty} = \text{Amount} \times \left( \frac{4}{4}\text{Liquidation Bonus Fraction} - \frac{1}{4}\text{Bond Payment Factor} \right)
```

(Details to be finalized.)
