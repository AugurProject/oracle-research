# PLACEHOLDER2 - a Decentralized Oracle and Prediction Market Platform

PLACEHOLDER2 is a game-theoretically secure, censorship-resistant oracle and prediction market protocol built on Ethereum. It allows users to create, trade, and resolve prediction markets while aligning incentives toward accurate reporting of real-world outcomes.

![image](images/layers.png)

PLACEHOLDER2 is built with multiple layers: 
1) **Core Layer**: A feeless Colored Coins system with an Escalation Game. The Core Layer enables users to submit questions to the PLACEHOLDER2 oracle. The oracle can respond with one of three outcomes - YES, NO, or INVALID - or, if there is disagreement, trigger a fork of the REP token to resolve the question in the forked universe.
2) **Seurity Pool Registry Layer**: Converts the REP backed bets into backed by any other token, eg, ETH/USDC or any untrusted shitcoins.
3) **Shares Layer**: Enables REP holders to sell their share of PLACEHOLDER2’s security to traders through customizable fee structures.
4) **Exchange Layer**: Provides a marketplace where traders can buy and sell shares, as well as place bets on real-world events, using tokens and fee structures defined by the market.

## Colored Coin Core Layer
The Core Layer combines two systems: the Colored Coin system and the Escalation Game system.

The *Colored Coins* system refers to a distinct oracle mechanism, with the earliest mention appears in a brief reference by [zack-bitcoin](https://github.com/zack-bitcoin) in the [Amoveo documentation](https://github.com/zack-bitcoin/amoveo-docs/blob/master/design/oracle_simple.md). This design is entirely separate from the concept of [Colored Coins on Bitcoin](https://en.bitcoin.it/wiki/Colored_Coins), which involves tagging bitcoins to represent alternative assets on the Bitcoin blockchain.

The core principle is:
> Each time the system encounters a decision, the chain of decisions splits-each possible outcome unfolding in its own branch. These branches can then continue to fork with every subsequent decision.

PLACEHOLDER2 implements the same system using REP token than splits decisions. However, not every decisions will trigger a fork. An Escalation Game system is used to prevent disruptive forks.

PLACEHOLDER2 Core implements following functionalities:
1) **REP token**: The system has a token called REP.
2) **Ask question**: Anyone can ask a question by:
	- Write up a **Question Description**
	- Setting a **Question Answer After Date** (the date when reporting on the question begins)
	- Choosing who is **Designated Reporter**
	- Deposit **Question Creator Bond** worth of $REP$ to the system.
3) **Reply to a Question**: After **Question Answer After Date** has passed for a question, designated reporter can reply to the question, if they fail to do so for 3 days, anyone can reply to the question and claim the Question Creator Bond if the reported option ends up as finalized outcome.
4) **Dispute a question**: After the designated reporter (or, if absent, the initial reporter) submits an answer, the outcome can be challenged by starting an [Escalation Game](./Escalation%20Game.md).
5) **Fork**: If an Escalation Game leads to a fork:
	- REP held on each side of the Escalation Game converts into the corresponding forked tokens: REP-Yes, REP-No, REP-Invalid
	- Each REP not in the Escalation Game that triggered the fork converts into three separate tokens: REP-Yes, REP-No, and REP-Invalid
	- Asking new questions with REP is no longer possible
	- Questions must instead be created using REP-Yes, REP-No, and REP-Invalid
	- Already asked, but not finalized questions also fork along with the Question Creator Bond and become their separate questions for each separate REP token

The asked questions should follow rules discussed in [Reporting Rules](./Reporting%20Rules.md) to be considered valid.

## [Seurity Pool Layer](Security%20Pool%20Layer.md)

## [Shares Layer](Shares%20Layer.md)

## Exchange Layer
