
![image](https://hackmd.io/_uploads/Hk27KXumel.png)

# Initial Coin Offering Oracle

1) Augur Forks with 100 $ETH$ open interest. All $REP$ is converted into Auction Participation Tokens. Open interest is locked behind these participation tokens.
2) $REP_{true}$ universe conducts Initial Coin Offering using dutch auction: We auction $REP_{true}$ until we have raised 100 $ETH$ that is paid to true-share holders. Each Auction Participation Token entitles participation to the auction (relatively to the amount of tokens held) using the open interest stored in it + they can add more (in open auction?). If 100 $ETH$ is never raised, the universe doesn't function.
5) $REP_{false}$ universe does the same for false-share owners

## Assumptions
- $\text{REP MCAP} > \text{current open interest}$ (otherwise there's incentive to trigger fork to steal open interest)
- $REP_{true}\;\text{future value} >= \text{current open interest}$ (we need future rep holders to buy out the open interest holders

## Two tiered auction:
1) First Auction Participation Tokens holders can move their open interest share over + add bonus in ETH.
2) If all the open interest is covered the auction ends, all the participants are paid minted $REP_{true}$ according their total payment (everyone gets the same price)
3) Free for all dutch auction begins. Participants should be incentivized to buy rep when $REP\;mcap < future\; value$

## Ideal situation
- Augur forks and $REP$ holders move the open interest into right universe. If some $REP$ holders do not participate (eg, the lying $REP$), rest of the open interest is covered with more open auction by dilluting $REP_{true}$ holders.

## Open interest pump attack
1) Open interest = 100 $ETH$, attacker buys cheap lie shares with $\epsilon$, open interest becomes 9100 $ETH$, $REP$ mcap = 500 $ETH$, attacker owns 100% $REP$
2) Attacker moves all open interest to rep false and gets 9100 ETH and loses REP's mcap 500 $ETH$ (loss of 400 $ETH$)
3) $REP_{true}$ freezes as nobody wants to pay 9100 $ETH$ for all the REP, as it's only worth 500 eth. True traders lose 9100 ETH

This attack breaks $\text{Open Interest} < \text{REP Market Cap}$ assumption, and is not profitable for attacker, but causes Augur to freeze
