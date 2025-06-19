# Glossary

## CASH
Anytime someone puts ETH into the system to buy a complete set, they will deposit into a contract and receive CASH tokens in exchange.  Everything in the system uses CASH tokens or REP, no other tokens are accepted or used in the protocol.  The exchange rate of CASH:ETH starts at 1 and increases over time, with the rate of increase going up if the system finds that it needs REP to have more value, and down if REP can have less value.  The excess ETH in the contract is eventually distributed to REP holders, and is the core mechanism that gives REP value, because holders of REP have a right to those accrued fees.


# Outline

## Escalation Game
If the initial report for a market is disputed, an escalation game ensues.  The escalation game is played with REP.  The escalation game works the same as Augur v2.
<details>
<summary>$${\color{yellow}{\textsf{Other escalation games can work here.}}}$$</summary>
The main requirement is that any REP committed in the escalation game is committed to the chosen side in a fork should the escalation game reach a stalemate state.  Other things that make for a good escalation game:

* **Long-Term Coordination** - Enable sustained collaboration among participants over time of the dispute
* **Public Commitment** - Allow individuals to visibly signal their belief in the correct outcome
* **Anti-Hedging Cost** - Impose a cost on participation to prevent users from supporting multiple sides
* **Incentive Alignment** - Ensure users who choose correctly are rewarded more than they lose by participating
* **Collective Funding** - Support pooled contributions toward a shared resolution goal
* **Decision or Deadlock** - Include a path to force a resolution or formally declare a stalemate
* **Affordable Stalemate** - Make “no decision” affordable but not easily exploitable
* **Broad Participation** - Maximize inclusion by making participation widely accessible
</details>

## Market Migratio
All markets will migrate to all possible universes once the escalation game reaches a stalemate.  The forking market will be finalized on each universe, but all other markets will return to pre-reporting state (possibly entering reporting immediately upon migration completion).

## REP Migration
Once the escalation game has reached its stalemate state, all REP holders will have a time-boxed window to migrate their REP.  Any REP that participated in the escalation game automatically migrates to the universe it was staked on.  All other REP can choose any universe.

## CASH Migration
After the REP migration period ends, the system will look at how the REP is distributed across universes and migrate all CASH proportionately to the REP migration.  If 20% of REP migrated to universe A, 50% migrated to universe B, and 30% failed to migrate within the window then 20% of the CASH would migrate to universe A, 50% of CASH would migrate to universe B, and 30% of CASH would remain behind.

The CASH that remains behind is distributed to REP holders who failed to migrate.  The REP becomes worthless at this point and serves no purpose other than to redeem for CASH.  Transfers remain enabled so people can withdraw REP from exchanges and other contracts in order to redeem for CASH, but it no longer serves any purpose within the system.

## CASH for REP Auction
On each universe, a dutch auction is held where people are bidding ETH in exchange for REP.  The auction ends when it either has (A) raised enough ETH to restore the CASH contract on the universe to the pre-fork CASH levels or (B) has reached a point where the amount of REP being sold fully dillutes existing REP holders (minus epsilon).  The REP auction participants receive will be minted and distributed when the auction finalizes.  The ETH proceeds of the auction will be added to the CASH contract on the auction's universe.

If the auction fails to raise the necessary ETH (B), then the CASH contract's redemption price will be adjusted accordingly.  If the auction succeeds at raising enough ETH (A) then the CASH contract's redemption price will remain at its normal value.

<details>
<summary>$${\color{yellow}{\textsf{Other auctions may work here.}}}$$</summary>
The main requirement of the auction is that it sells minted REP for ETH and raises as much ETH as possible (up to the needed amount to make CASH contract whole) while minting as little REP as possible.  Other useful properties include:

* Low gas cost.
* Encourages early participation.
* Finalizes quickly.
</details>


# Examples

## Baseline
Unless otherwise specified, all scenarios below have the following baseline:

* REP Supply: 200
* CASH: 50
* REP DCF Before Fork: $200 ($1/REP)
* CASH value: $1
* ETH value: $1

<details>
<summary>

## Happy Path: Weak Attack, No Sleeping, True Auction Success

</summary>

* DCF Change in True Universe: 100% (no change)
* DCF CHange in False Universe: 0% (wiped out)
### REP Migration
* 10 REP -> False
* 190 REP -> True
### CASH Migration
* 2.5 CASH -> False
* 47.5 CASH -> True
### Auction
* False auction raises only 0.5 ETH, and mints 100,000 REP-F.
* True auction raises 2.5 ETH, and mints 5 REP-T.
### Outcome
* True universe has 50 ETH in CASH available for distribution to winners, no loss for OI holders.
* True universe has 195 REP worth $200 total ($1.0256/REP), REP-True holders gained $0.0256/REP.
* False universe has 3 ETH in CASH available for distribution to attacker.
* False universe has 100,010 REP worth $0 total ($0/REP), REP-False holders lost $10.
* Attacker lost $7 net.
* Defenders gained $5 net.
* Traders lost nothing.
* Auction participants gained $2 (from auction inefficiency).

</details>

<details>
<summary>

## Suicidal Whale: Strong Attack, No Sleeping, True Auction Success

</summary>
	
* DCF Change in True Universe: 100% (no change)
* DCF Change in False Universe: 0% (wiped out)

</details>

<details>
<summary>

## Sleepy REP

</summary>

TODO

</details>

<details>
<summary>

## DCF Harmed

</summary>

TODO

</details>

<details>
<summary>

## Contentious Market

</summary>

TODO

</details>
