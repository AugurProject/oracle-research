# PLACEHOLDER - a Decentralized Oracle and Prediction Market Platform

PLACEHOLDER is a game theoretically secure decentralized prediction market and oracle service running on Ethereum. PLACEHOLDER is built on ideas from Augur V2, DEFI protocols on and other oracles.

## Summary

## Motivation

## PLACEHOLDER Security Assumption

1. **Users are greedy**: Users value more money over less money.
2. **A fork doesn't change the total value of the system**. Market cap of a previous universe equals ATLEAST market cap of the formed universes: 
```math
\text{value of assets prior fork}= \sum_{\text{future universes}}{\text{value of assets}_{universe}}
```
3. **Users value honest universe(s)**: User prefers to use an universe that is honest in their opinion:
```math
\text{value of assets prior fork } = \text{value of assets}_{\text{truthful universe}}
```
4. **Neglible operation costs**: Transaction fees (eg, gas fee) are neglible compared to financial value of the transactions.
5. **Access to information**: Users should have reliable and timely access to information in order to determine the most truthful outcome of a market.
6. **Migrating is not too hard**: Users, exchanges and other tools using the systems are okay to migrate into fork they believe is truthful.

7. Some amount of truthfull REP can be sold for ETH lost in a fork for a small enough fee:
8. It is assumed Traders hold enough REP to delay wrongly reported markets enough so that participants with more REP are alerted to continue disputing the market
9. REP is liquid enough (access is needed to create security pools if existing holders do not), needed for dispute games too
10. TWAP price oracle is hard enough to manipulate (TODO: research more)
11. The system is able to maintain inequality: Open interest < REP's market cap
12. People find value in being able to use a betting platform.
13. People are willing to pay some amount of money for rights to use a betting platform for some amount of time.
14. Requirement (security): People need to be willing to pay more in fees to rent access to using Augur than 2x the Time Value of Money for the duration of their bet.
15. We need enough users in the platfom for (not necessary true as the system can be revived later too)

[TODO missing security pool assumptions]
[TODO missing escalation game assmptions]
[TODO go throught these again and see which are really assumptions and which can be deriverd]

## System Overview
![image](images/SystemFlow.png)
### System Participants
- REP Holders
- OI holders
- Traders (yes,no,invalid holders)
- Security Pool holders
- Keepers
- Market Makers
- REP/ETH traders

## Creating Prediction Markets
Anyone can create a prediction market on PLACEHOLDER. To create a market you need to
1) Write up a **Market Description**
2) Decide what is **Market End Date**
3) Decide who is **Designated Reporter**
4) Deposit **Market Creator Bond** worth of $REP$ to the system.

The created market needs to obey [Reporting Rules](./Reporting%20Rules.md) to be considered to be a valid market. Markets not obeying the rules are considered Invalid, which is one reporting option. PLACEHOLDER only has markets that resolve into one of three outcomes: YES, No or Invalid. Given PLACEHOLDER's assumptions, the users of the market can expect the market to resolve correctly according to a real world event outcome.

## Minting Market Shares

To trade on a market in PLACEHOLDER, the user must first mint Complete Sets. A Complete Set is a bundle of tokens composed of equal amounts of Yes, No, and Invalid shares, and is specific to a single market (each market has its own Complete Sets).

There are multiple ways to access Complete Sets in PLACEHOLDER, such as,

1) Create a personal Security Pool that mints Complete Sets using ETH and REP
2) Purchase Complete Sets directly from other traders on the market
3) Buy Complete Sets from an Open Security Pool
4) Contripute REP to some Open Security Pool that grants it's members to mint complete sets

### [Security Pools](./SecurityPools.md)

## Trading
Once a user acquires a Complete Set for a market, they can sell parts of it to take a position. For example, selling all No shares from a Complete Set effectively places the user in a Yes position. If the market resolves to Yes, the user can redeem their Yes shares for 1 ETH each and keep the profit from having sold the No shares.

In most cases, Complete Sets are redeemable for 1 ETH (though there are exceptions [TODO: clarify exceptions here]).

Market shares can be traded on various external trading platforms, as PLACEHOLDER itself does not provide trading functionality. However, because anyone can create a market on PLACEHOLDER, the platform may accumulate a large number of low-quality or poorly defined markets. This makes it challenging for traders to distinguish between well-constructed and potentially invalid markets.

To address this, it is recommended that trading platforms implement some form of "invalid market insurance." Under such a system, if a market resolves as invalid, traders would be refunded. This would reduce the incentive to create invalid markets and improve overall market quality.

## Reporting
When market ends; current time is past **Market End Date**. The **Designated Reporter** can report on the market according to what actually happened in the real world. The designated reporter decides if the market resolves as Yes, No or Invalid. The Designated Reporter has **Designated Reporter Time** to do this. If they fail to do this, anyone can report on the market. This person or Designated reporter is called as **Initial Reporter**. There is no deadline for **Initial Reporter** to report on the market.

[TODO: add designated reporter->initial reporter REP stake swapping option]

### Disputing
If users disagree with the **Initial Reporter**, they are able to dispute the market by staking REP, this will start an [Escalation Game](Escalation%20Game.md). If the escalation game ends up as a timeout, the market finalizes at its outcome. After the market has finalized the Security Bond Debts of Security Pools are cleared for this market and traders can redeem their Yes, No or Invalid tokens to ETH depending on which outcome the market finalized on.

#### Disputing via Security Pool
Users are able to participate Escalation Game by using REP they have or REP staked to a Security Pool. Participating the game with a Security Pool does not remove the REP from the Pool. However, if the REP staked by this way gets lost in the escalation game, it gets pulled out from the Security Pool and given the winner of the game. 

A Security Pool allows only up to 50% of its REP being used in an escalation game. This is to prevent too much Open Interest being non-accounted by some Security Pool.

## [Escalation Game](Escalation%20Game.md)

## Fork
If PLACEHOLDER's Escalation Game fails to find consensus on the outcome, PLACEHOLDER enters into a fork state, during forking state:
1) No market can finalize
2) No market can be created on parent universe (allowed for child)
3) Escalation games freeze
4) No new escalation games can be created
5) No complete sets can be created anymore
6) Complete sets can be redeemed for ETHs before **ETH Migration** is triggered
7) Security Pool Security Bond Minting, Liquidations, REP withdrawals and REP Deposits are disabled
8) Security Pools of child universe can mint Security Bonds, do REP withdrawals and deposits, but cannot be liquidated.

When fork is triggered, PLACEHOLDER splits into yes/no/invalid universes, these are called child universes, the current universe is called parent universe from perspective of child universes. Child universes have all the non-finalized parent markets migrated over.

Universe is a system that holds it's own Reputation token, it's own markets, its own market shares and such. Different universes are independent of each other.

The fork state lasts $\text{Fork Duration}$.

### REP Migration
All REP holders will have $\text{Fork Duration}$ amount of time to migrate their REP to one of the child universes. Any REP that participated in the escalation game that triggered the fork automatically migrates to the universe it was staked on. The REP in other escalation games is released and the owner of it can choose any child universe it belongs into. Exception to this is the REP staked as **Market Creator Bond** which gets migrated into all universes.

#### Security Pool Migration
When PLACEHOLDER forks, the security pools fork as well. The Security Pool Controller must decide how much REP to migrate into each forked branch. The Controller can allocate REP to multiple branches, which is especially useful when managing REP for multiple users rather than a single account.

During a fork, security bonds in the Security Pool are duplicated and minted in all universes. As a result, a healthy Security Pool can still face liquidation, since the number of Security Bonds remains constant while some of its REP is migrated to other universes.

### ETH Migration
After the REP migration period ends ($\text{Fork Duration}$ period), complete sets can no longer be redeemed for ETH. Original REP token is frozen. The system will look at how the REP is distributed across universes and migrate all ETH proportionately to the REP migration. If 20% of REP migrated to universe A, 50% migrated to universe B, and 30% failed to migrate within the window then 20% of the ETH would migrate to universe A, 50% of ETH would migrate to universe B, and 30% of ETH would remain behind.

This is game theoretically sound operation to make, as the REP migrating is more valuable than the migrating ETH, and the only way for the REP to maintain its value is to migrate into universe that maintains its value. REP holder can migrate into a false universe, to capture the ETH, but this makes the REP valueless. Here we are assuming that users prefer trading on an universe that reports truth and thus are willing to pay the oracle for this. And the fork does not have a significant negative impact on the systems value or traders willing to trade there.

The ETH that remains behind is distributed to REP holders who failed to migrate. The REP becomes worthless at this point and serves no purpose other than to redeem for ETH. Transfers remain enabled so people can withdraw REP from exchanges and other contracts in order to redeem for ETH, but it no longer serves any purpose within the system.

## ETH for REP Auction
On each universe, a dutch auction is started right after when ETH migration is finalized. In the auction, people are bidding ETH in exchange for REP of the given universe. The auction starts by offering $\frac{\text{REP Supply}}{\text{Dutch Auction Divisor Range}}$ REP for the needed amount of ETH and the amount of REP offered increases every second until it reaches $\text{REP Supply}\cdot \text{Dutch Auction Divisor Range}$ REP offered. The auction ends when either (A) one or more parties combined are willing to buy the ETH deficit for the current REP price or (B) it reaches the end without enough ETH willing to buy even at the final price. The final prize is reached when the auction has lasted $\text{REP to ETH Auction Length}$.

The auction participants are also able to submit non-cancelable limit orders to the auction "I am willing to buy 100 REP with price of 10 ETH", these limit orders can be submited right after the system has entered into a fork state, even thought the auction itself has not yet started.

### Auction Success
The REP that auction participants receive will be minted and distributed when the auction finalizes. Every auction participant get the same price for the REP. The auction proceeds of the auction will be added to the top of the Migrated ETH and complete sets can be redeemed and created again at 1:1 value.

### Auction Shortfall
If the auction fails to raise the necessary ETH then the CASH contract's redemption price will be adjusted accordingly and CASH is no longer backed by 1:1 of ETH.

In the case of auction failure to raise enough ETH to cover traders before minting 1000x of migrated supply of REP, all auction participants will be refunded and the auction will be cancelled. The universe will shutdown except for withdraws of OI at a reduced price from their intended value.

## Invalid markets
- should we adjust Market Creator Bond like augurv2 with invalid markets
- should we punish market creator for making invalid market by burning the stake?

# Parameters

| Parameter                       | Value              |
| ------------------------------- | ------------------ |
| Escalation Game Time Limit      | 7 weeks            |
| Market Creator Bond             | 1 REP              |
| Fork Theshold                   | 2.5% of REP Supply |
| Security Multiplier             | 2                  |
| Fork Duration                   | 8 weeks            |
| Designated Reporter Time        | 3 days             |
| Dispute Period Length           | 4 days             |
| REP to ETH Auction Length       | 1 week             |
| Dutch Auction Divisor Range     | 1 000 000          |

# Open Questions
- how to fund TWAP
- how to maintain TWAP security?
- Should we have turnstile?

# Vocabulary

| Term                       | Description              |
| ------------------------------- | ------------------ |
| Token | |
| REP | |
| ETH | |
| FORK | |
| Minting Tokens | Minting means creating tokens out of nowhere. |
**Market Description**
**Market End Date**
**Designated Reporter**
**Market Creator Bond**

# Random ideas
- hmm, one soft limit that we have not thought of: We could only allow minting complete sets with some speed limit
- add global limits to OI and REP that increase over time. To try to phis out attackers of the system as early as possible and limit losses of the system. This could work nicely with artic-tern oracles as they are somewhat parasitic interest resistant
- todo add analysis on price oracle, how PLACEHOLDER adds liquidity into the pool
- hmm, we could allow a security vault to burn 20% * forkTreshold * 2 rep at any time to trigger fork instantly (we could allow some crowdsourcer for this as well)

- Oracle security could be maintained by requiring security pool holders to deposit enough rep/eth?