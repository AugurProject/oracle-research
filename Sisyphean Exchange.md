# $${\color{ForestGreen}{\textsf{Glossary}}}$$

## $${\color{ProcessBlue}{\textsf{CASH}}}$$
Anytime someone enters new ETH into the system they will deposit it into a contract and receive CASH tokens in exchange.  All ETH in the CASH contract is "insured" by the oracle, and any ETH not in the contract is not insured by the oracle.  When markets finalize, any CASH associated with them is converted to ETH.  When users close out complete sets or redeem winnings, the CASH is converted to ETH.

Everything in the system uses CASH or REP, no other assets are accepted or used in the protocol.

The exchange rate of CASH per ETH starts at 1 and increases over time.  The rate of increase goes up if the system finds that it needs REP to have more value, and it goes down if REP can have less value.  The excess ETH in the contract from this inflation is distributed to REP holders, and is the core mechanism that gives REP value.

The amount of ETH in the CASH contract is strictly constrained to be some multiple less than the current REP Discounted Cash Flow (DCF) at any given time.  If it is equal to or higher than this multiple (e.g., 2x) then no new CASH can be issued.  The inflationary pressure on CASH will attempt to increase REP DCF somewhat, but the hard cap reduces the risk that the system goes underwater (ETH > REP DCF).


# $${\color{ForestGreen}{\textsf{Outline}}}$$

## $${\color{ProcessBlue}{\textsf{Escalation Game}}}$$
If the initial report for a market is disputed, an escalation game ensues.  The escalation game is played with REP.  The escalation game works the same as Augur v2.

* Time until stalemate: 8 weeks
* REP Contributed at stalemate: 1% of total supply

<details>
<summary>$${\color{BurntOrange}{\textsf{Other escalation games can work here.}}}$$</summary>
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

## $${\color{ProcessBlue}{\textsf{Market Forking}}}$$
Once the escalation game reaches a stalemate, all markets will fork and have exact copies in all possible universes.  The CASH token will also fork, and a copy with identical balances will exist in each universe.  The forking market will be finalized on each universe, but all other markets will return to pre-reporting state (possibly entering reporting immediately upon migration completion).

## $${\color{ProcessBlue}{\textsf{REP Migration}}}$$
Once the escalation game has reached its stalemate state, all REP holders will have a time limited opportunity to migrate their REP to one of the child universes.  Any REP that participated in the escalation game automatically migrates to the universe it was staked on.  All other REP can choose any child universe.

* Migration Time Limit: 8 weeks

## $${\color{ProcessBlue}{\textsf{CASH Migration}}}$$
After the REP migration period ends, the system will look at how the REP is distributed across universes and migrate all CASH proportionately to the REP migration.  If 20% of REP migrated to universe A, 50% migrated to universe B, and 30% failed to migrate within the window then 20% of the CASH would migrate to universe A, 50% of CASH would migrate to universe B, and 30% of CASH would remain behind.

The CASH that remains behind is distributed to REP holders who failed to migrate.  The REP becomes worthless at this point and serves no purpose other than to redeem for CASH.  Transfers remain enabled so people can withdraw REP from exchanges and other contracts in order to redeem for CASH, but it no longer serves any purpose within the system.

## $${\color{ProcessBlue}{\textsf{CASH for REP Auction}}}$$
On each universe, a dutch auction is held where people are bidding ETH in exchange for REP.  The system starts by offering `rep_supply/1,000,000` REP for the needed amount of CASH and the amount of REP offered increases every second until it reaches `rep_supply*1,000,000` REP offered.  The auction ends when either (A) one or more parties combined are willing to buy the CASH deficit worth of ETH for the current REP price or (B) it reaches the end without enough ETH willing to buy even at the final price.  The REP that auction participants receive will be minted and distributed when the auction finalizes.  The ETH proceeds of the auction will be added to the CASH contract on the auction's universe.

If the auction fails to raise the necessary ETH (B), then the CASH contract's redemption price will be adjusted accordingly.  If the auction succeeds at raising enough ETH (A) then the CASH contract's redemption price will remain at its normal value.

In the case of a failed auction (failure to raise enough ETH to cover traders before minting 1000x of migrated supply of REP), all auction participants will be refunded and the auction will be cancelled.  The universe will shutdown except for withdraws of OI at a reduced price from their intended value.

<details>
<summary>$${\color{BurntOrange}{\textsf{Other auctions may work here.}}}$$</summary>
The main requirement of the auction is that it sells minted REP for ETH and raises as much ETH as possible (up to the needed amount to make CASH contract whole) while minting as little REP as possible.  Other useful properties include:

* Low gas cost.
* Encourages early participation.
* Finalizes quickly.
</details>


# $${\color{ForestGreen}{\textsf{Examples}}}$$

## $${\color{ProcessBlue}{\textsf{Baseline}}}$$
Unless otherwise specified, all scenarios below have the following baseline:

* REP Supply: 200
* CASH: 50
* REP DCF Before Fork: $200 ($1/REP)
* CASH value: $1
* ETH value: $1
* Auction Efficiency: 75%
* DCF in True Universe: 100% (no change)
* DCF in False Universe: 0% (wiped out)


<details>
<summary>

## $${\color{ProcessBlue}{\textsf{Happy Path: Weak Attack, No Sleeping, True Auction Success}}}$$

</summary>

### REP Migration
* 190 REP -> True
* 10 REP -> False
### CASH Migration
* 47.5 CASH -> True
* 2.5 CASH -> False
### Auction
* True auction raises 2.5 ETH, and mints 3.5 REP-T (rounded for simplicity).
* False auction raises ~0 ETH, and mints 1,000,000 REP-F.
### Outcome
* True universe has 50 ETH in CASH available for distribution to winners.
* True universe has 193.5 REP worth $200 total, REP-True holders gain $6.5 ($0.0336/REP).
* False universe has 2.5 ETH in CASH available for distribution to attacker.
* False universe has 1,000,010 REP worth $0 total.
* Attacker lost $${\color{Red}{\textsf{\\$7.5}}}$$.
* Defenders gained $${\color{OliveGreen}{\textsf{\\$6.5}}}$$.
* Traders lost $${\color{RoyalBlue}{\textsf{\\$0}}}$$.
* Auction participants profited $${\color{OliveGreen}{\textsf{\\$1}}}$$.

</details>

<details>
<summary>

## $${\color{ProcessBlue}{\textsf{Suicidal Whale: Strong Attack, No Sleeping, True Auction Success}}}$$

</summary>
	
## REP Migration
* 10 REP -> True
* 190 REP -> False
## CASH Migration
* 2.5 CASH -> True
* 47.5 CASH -> False
## Auction
* True auction raises 47.5 ETH, and mints 65 REP (rounded for simplicity).
* False auction raises ~0 ETH, and mints 1,000,000 REP-F.
## Outcome
* True universe has 50 ETH in CASH available for distribution to winners.
* True universe has 75 REP worth $200 total, REP-True holders gain $125 ($1.667/REP).
* False universe has 47.5 ETH in CASH available for distribution to attacker.
* False universe has 1,000,190 REP worth $0 total.
* Attacker lost $${\color{Red}{\textsf{\\$142.5}}}$$.
* Defenders gained $${\color{OliveGreen}{\textsf{\\$125}}}$$.
* Traders lost $${\color{RoyalBlue}{\textsf{\\$0}}}$$.
* Auction participants profited $${\color{OliveGreen}{\textsf{\\$17.5}}}$$.

</details>

<details>
<summary>

## $${\color{ProcessBlue}{\textsf{Sleepy REP: Strong Attack, Many Asleep, True Auction Success}}}$$

</summary>

## REP Migration
* 5 REP -> True
* 15 REP -> False
* 180 REP didn't move
## CASH Migration
* 1.25 CASH -> True
* 3.75 CASH -> False
* 45 CASH remains in parent universe.
## Auction
* True auction raises 48.75 ETH, and mints 65 REP.
* False auction raises ~0 ETH, and mints 1,000,000 REP-F.
## Outcome
* True universe has 50 ETH in CASH available for distribution to winners.
* True universe has 70 REP worth $200 total, REP-True holders gain $130 ($1.857/REP).
* False universe has 3.75 ETH in CASH available for distribution to attacker.
* False universe has 1,000,190 REP worth $0 total.
* 45 CASH distributed to 180 sleeping REP holders.
* Attacker lost $${\color{Red}{\textsf{\\$11.25}}}$$.
* Defenders gained $${\color{OliveGreen}{\textsf{\\$130}}}$$.
* Sleeping REP holders lost $${\color{Red}{\textsf{\\$135}}}$$.
* Traders lost $${\color{RoyalBlue}{\textsf{\\$0}}}$$.
* Auction participants profited $${\color{OliveGreen}{\textsf{\\$16.25}}}$$.

</details>

<details>
<summary>

## $${\color{ProcessBlue}{\textsf{DCF Harmed: DCF Decreases After Fork, Middling Attack, No Sleeping, True Auction Success}}}$$

</summary>

* DCF in True Universe: 50% ($100 after fork)
## REP Migration
* 10 REP -> True
* 190 REP -> False
## CASH Migration
* 2.5 CASH -> True
* 47.5 CASH -> False
## Auction
* True auction raises 47.5 ETH, and mints 65 REP (rounded for simplicity).
* False auction raises ~0 ETH, and mints 1,000,000 REP-F.
## Outcome
* True universe has 50 ETH in CASH available for distribution to winners.
* True universe has 75 REP worth $100 total, REP-True holders gain $25 ($0.333/REP).
* False universe has 47.5 ETH in CASH available for distribution to attacker.
* False universe has 1,000,190 REP worth $0 total.
* Attacker lost $${\color{Red}{\textsf{\\$142.5}}}$$.
* Defenders gained $${\color{OliveGreen}{\textsf{\\$25}}}$$.
* Traders lost $${\color{RoyalBlue}{\textsf{\\$0}}}$$.
* Auction participants profited $${\color{OliveGreen}{\textsf{\\$17.5}}}$$.
* Truemarkets™ gained $${\color{OliveGreen}{\textsf{\\$100}}}$$ (DCF must have gone somewhere)

</details>

<details>
<summary>

## $${\color{Magenta}{\textsf{Contentious Market: DCF Splits Between Universes, No Sleeping, True and False Auctions Success}}}$$

</summary>

### REP Migration
* 100 REP -> A
* 100 REP -> B
### CASH Migration
* 25 CASH -> A
* 25 CASH -> B
### Auction
* A auction raises 25 ETH, and mints 35 REP-A (rounded for simplicity).
* B auction raises 25 ETH, and mints 35 REP-B (rounded for simplicity).
### Outcome
* A universe has 50 ETH in CASH available for distribution to winners.
* A universe has 135 REP worth $100 total, REP-A holders lose $35 (-$0.259/REP).
* B universe has 50 ETH in CASH available for distribution to winners.
* B universe has 135 REP worth $100 total, REP-B holders gain $15 ($0.259/REP).
* A migrators lost $${\color{Red}{\textsf{\\$35}}}$$.
* B migrators lost $${\color{Red}{\textsf{\\$35}}}$$.
* Traders gained $${\color{OliveGreen}{\textsf{\\$50}}}$$.
* Auction participants profited $${\color{OliveGreen}{\textsf{\\$20}}}$$.

</details>

<details>
<summary>

## $${\color{Magenta}{\textsf{All Auctions Fail: Strong Attack, No Sleeping, True Auction Failure, DCF Wiped Out}}}$$

</summary>

* DCF in True Universe: 0% (wiped out)
## REP Migration
* 10 REP -> True
* 190 REP -> False
## CASH Migration
* 2.5 CASH -> True
* 47.5 CASH -> False
## Auction
* True auction raises ~0 ETH, and mints 1,000,000 REP-True.
* False auction raises ~0 ETH, and mints 1,000,000 REP-False.
## Outcome
* True universe has 2.5 ETH in CASH available for distribution to winners.
* True universe has 1,000,010 REP worth $0 total, REP-True holders **lose** ~$200 (-$1/REP).
* False universe has 47.5 ETH in CASH available for distribution to attacker.
* False universe has 1,000,190 REP worth $0 total.
* Attacker lost $${\color{Red}{\textsf{\\$142.5}}}$$.
* Defenders lost $${\color{Red}{\textsf{\\$10}}}$$.
* Traders lost $${\color{Red}{\textsf{\\$47.5}}}$$.
* Auction participants profited $${\color{RoyalBlue}{\textsf{\\$0}}}$$.

</details>
