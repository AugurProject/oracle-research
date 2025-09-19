# Security Pool Layer

The Security Pool Layer allows users to denominate their bets in different tokens, while ensuring those bets are always backed by a sufficient amount of REP. By securing bets with REP, the system guarantees that outcomes are correctly resolved by the PLACEHOLDER2 oracle.

The Security Pool contracts are not part of the oracle’s core. This means anyone can deploy a new version of these contracts, connect it to the core, and immediately start using it. The registry itself holds no special permissions within the core.

This document describes one possible implementation of the Security Pool.

## Security Pool
The Security Pool enables users to place bets using a single external token type, such as ETH or USDC. For the purposes of this document, we use ETH as the example, though any supported token can be used. The registry also allows anyone to deploy and manage their own Security Pool, which they fully control.

### Security Vault
Security Vault are conceptually somewhat similar to MakerDAO’s Collateralized Debt Positions (CDPs). In MakerDAO, users deposit ETH as collateral to borrow DAI. In PLACEHOLDER2, users deposit REP tokens as a Security Deposit and create Security Bonds backed by that REP. Each Security Bond enables its holder to deposit one ETH and mint one Complete Set for every pair of ETH and Security Bond.

Like MakerDAO, keepers in PLACEHOLDER2 monitor Security Vault (or CDPs) to ensure that the amount of debt remains manageable. The key requirement in PLACEHOLDER2 is:

```math
\text{Security Bonds Minted} \leq \frac{\text{Security Deposit}_{REP}}{\text{Security Multiplier} \times \text{Price}_{REP/ETH}}
```

By managing your own Security Pool with your REP tokens providing Security Bonds, you can trade on PLACEHOLDER2 while only incurring the cost of locked capital.

![image](images/CompleteSet.png)

## Security Bonds
When Security Vault are used to mint Complete Sets, they generate debt measured in Security Bonds. Each individual Complete Set must be backed by one ETH and one Security Bond. This Security Bond debt can be cleared in three ways:

1) Returning Complete Sets for the same market back to the pool (these do not have to be the exact same Complete Sets originally minted by the Security Pool; Complete Sets minted by other Security Vault are also accepted).
2) When the market for the Complete Set ends, its associated debt is transferred to the Global Security Bond Debt.
3) Transferring your debt to another Security Pool, if that pool allows it and the transfer does not cause that pool to exceed its limits.

### Global Security Bond Debt

While Security Vault have their local limit on how much Security Bonds they can generate, PLACEHOLDER2 also has a global limit:

```math
\text{Total Security Bonds Minted} \leq \frac{\text{Total REP in Security Pool}}{\text{Security Multiplier} \times \text{Price}_{REP/ETH}}
```

Here

```math
\text{Total Security Bonds Minted} = \sum_i^{Pools} \left( \text{Security Bonds Minted}_i \right) \ + \ \text{Global Security Bond Debt}
```

When a market is finalized, it's Global Security Bond Debt is cleared.

## [Liquidating Security Pool](./Liquidation.md)

### Security Vault Controllers
While some functions within Security Vault - such as triggering liquidation - can be executed by anyone, most operations are limited to their controllers. A controller can be either a regular Ethereum address or a smart contract. Controllers are responsible for defining how complete sets are minted.

The system itself does not charge any internal fees, but controllers enable REP holders to generate revenue. Only REP holders have permission to mint complete sets through Security Vault. This exclusivity allows REP holders to monetize access to complete sets.

Possible monetization strategies include:
1) Selling complete sets directly to anyone, with prices influenced by factors like market duration, market white list, etc.
2) Selling complete sets while simultaneously buying them back to mint new ones and maintain liquidity
3) Issuing wrapped complete sets that charge a time-based fee instead of distributing sets directly

Enabling REP holders to earn revenue is crucial because the security of the system depends on maintaining an inequality ($\text{REP Market Cap} > \text{Open Interest}$). Since the system imposes no fees itself, it is up to REP holders to develop effective methods for monetizing access to complete sets.

REP holders participating in Security Vault managed by others should exercise caution. Depositing REP into a poorly managed pool can lead to loss of funds and give malicious actors the ability to misuse that REP to attack PLACEHOLDER2.

#### Disputing via Security Pool
Users can also participate in the PLACEHOLDER2 core's Escalation Game using REP they personally hold or REP staked within a Security Pool. Using REP from a Security Pool does not immediately remove it from the pool. However, if that REP is lost in the Escalation Game, it is taken from the pool and awarded to the winner.

Each Security Pool can allocate at most 50% ($\text{Security Pool Escalation Game Participation Fraction}$) of its REP to an Escalation Game. This limit prevents excessive Open Interest from being exposed without proper accounting through a single pool.

## Fork
If PLACEHOLDER2 Core's Escalation Game fails to find consensus on the outcome, Security Pool enters into a fork state, during forking state:

**Origin universe:**
1) No market can finalize
2) No complete sets can be created or redeemed
4) Security Pool Security Bond Minting, Liquidations, REP withdrawals and REP Deposits are disabled

**Child Universe**
1) Complete sets can be redeemend according to how much we have currently available in the contract
2) Security Vault of child universe can mint Security Bonds, do REP withdrawals and deposits, but cannot be liquidated.

When fork is triggered, PLACEHOLDER2 splits into yes/no/invalid universes, these are called child universes, the current universe is called parent universe from perspective of child universes. Child universes have all the non-finalized parent markets migrated over.

Universe is a system that holds it's own Reputation token, it's own markets, its own market shares and such. Different universes are independent of each other, other than the forking process.

The fork state lasts $\text{Fork Duration}$.

### REP Migration
All REP holders in the Security Pool will have $\text{Fork Duration}$ amount of time to migrate their REP to one of the child universes.

#### Security Pool Migration
When PLACEHOLDER2 undergoes a fork, the Security Vault fork as well. The Security Pool Controller must determine how much REP to migrate into each forked branch. The Controller can split REP across multiple branches, which is particularly useful when managing REP on behalf of multiple users rather than a single account.

During a fork, security bonds in the Security Pool are duplicated and minted in every universe. As a result, even a healthy Security Pool may face liquidation (after the fork is over), since the total number of Security Bonds remains the same while portions of its REP are migrated into other universes.

### ETH Migration
After the REP migration period ends ($\text{Fork Duration}$ period), complete sets can no longer be redeemed for ETH. Original REP token is frozen. The system will look at how the REP is distributed across universes and migrate all ETH proportionately to the REP migration. If 20% of REP migrated to universe A, 50% migrated to universe B, and 30% failed to migrate within the window then 20% of the ETH would migrate to universe A, 50% of ETH would migrate to universe B, and 30% of ETH would remain behind.

This is game theoretically sound operation to make, as the REP migrating is more valuable than the migrating ETH, and the only way for the REP to maintain its value is to migrate into universe that maintains its value. REP holder can migrate into a false universe, to capture the ETH, but this makes the REP valueless. Here we are assuming that users prefer trading on an universe that reports truth and thus are willing to pay the oracle for this. And the fork does not have a significant negative impact on the systems value or traders willing to trade there.

The ETH that remains behind is distributed to REP holders who failed to migrate. The REP becomes worthless at this point and serves no purpose other than to redeem for ETH. Transfers remain enabled so people can withdraw REP from exchanges and other contracts in order to redeem for ETH, but it no longer serves any purpose within the system.

## Truth Auction: ETH for REP Auction
On each universe, Security Pool hosts a dutch auction. This starts right after when ETH migration is finalized. In the auction, people are bidding ETH in exchange for REP of the given universe. The auction starts by offering $\frac{\text{Total REP in Security Pool}}{\text{Dutch Auction Divisor Range}}$ REP for the needed amount of ETH and the amount of REP offered increases every second until it reaches $\text{\text{Total REP in Security Pool}}$ REP offered. The REP the system has available for sale is all the REP that migrated into different universe.

The auction ends when either (A) one or more parties combined are willing to buy the ETH deficit for the current REP price or (B) it reaches the end without enough ETH willing to buy even at the final price. The final prize is reached when the auction has lasted $\text{REP to ETH Auction Length}$.

The auction participants are also able to submit non-cancelable limit orders to the auction "I am willing to buy 100 REP with price of 10 ETH", these limit orders can be submited right after the system has entered into a fork state, even thought the auction itself has not yet started.

### Auction Success
The REP that auction participants receive will be distributed when the auction finalizes. Every auction participant get the same price for the REP. The auction proceeds of the auction will be added to the top of the Migrated ETH and complete sets can be redeemed and created again at 1:1 value. The possible left over REP is given equally to all REP holders in the Security Pool.

### Auction Shortfall
If the auction fails to raise the necessary ETH then the CASH contract's redemption price will be adjusted accordingly and CASH is no longer backed by 1:1 of ETH.

In the case of auction failure to raise enough ETH to cover traders, all auction participants will be refunded and the auction will be cancelled. The universe will shutdown except for withdraws of OI at a reduced price from their intended value.

## Market Duration
The longer a market exists on PLACEHOLDER2, the higher likelihood is that the markets complete sets are not backed by bigger amount of REP held in Security Vault. The longer markets are thus more vulnerable than shorter markets. For this reason, PLACEHOLDER2, limits markets length to maximum of one year ($\text{Max Market Duration}$).

There is a partial way to bypass this limitation. An external system can be set up to create a one-year market and, once it finalizes, launch a new long market. The system would then close the open interest in the previous market and transfer it to the next one. This strategy works as long as PLACEHOLDER2 allows the same amount of open interest to be created again, which is possible if both the global and local requirements of the Security Vault are satisfied.

## [ETH Security Bond Pool](./ETH%20Security%20Bond%20Pool.md)

## Ambiguous Markets
Ambiguous markets are those whose resolution criteria are unclear - they are neither clearly invalid nor clearly valid, but exist in a gray area between the two. PLACEHOLDER2 cannot fully defend against such markets, so the best approach is to avoid interacting with them altogether.

### Good practices for Open Security Vault
- REP holders should be able to fork of the pool by taking their share of the open interest with them into new pool to exit the pool
- REP holders should be allowed to use their share of voting power for Escalation Game

## Parameters

| Parameter                     | Value                  |
| ----------------------------- | ---------------------- |
| Security Parameter            | 2                      |

## Todo
- We probably need some limit on how small pools can be (both REP and OI side), eg Maker's CDP's have limit for these to allow liquidators to be profitable
