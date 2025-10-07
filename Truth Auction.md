
# Truth Auction
Truth auctions are implemented as limit order same price dutch auctions.
## Auction Phases

1. **Auction Creation**
   * The contract is deployed with a `fundReceiver` address.
   * At this stage, participants can place **limit orders** by sending ETH and specifying the maximum REP/ETH price they are willing to pay.
   * Example: A user sends 10 ETH and specifies a maximum price of 0.5 REP/ETH.
   * There's min bid size: `minBidSizeEth` no order can be smaller than this

2. **Auction Start**
   * When the auction begins, the auction is notified on the max amount of rep available (`repDeposit`), but this REP is not transfered to the contract.
   * The auction is configured to raise a target amount of ETH (`ethRaise`).
   * The **starting price** is calculated as: `startingPrice = (repDeposit * 1 000 000) / ethRaise`

3. **Auction Progress & End**
   * The auction lasts for **one week**.
   * The price decreases stepwise (`step_size = 1%`) linearly from the starting price down to `repDeposit / ethRaise`. The bids can only be made into these fixed step sizes.
   * The auction ends early if the total raised ETH reaches `ethRaise` before one week.

4. **Finalization**
   * After the auction ends, anyone can call `finalizeAuction()`.
   * If the auction failed to raise `ethRaise` amount of ETH, the contract keeps all the ETH raised, and accounts all the REP to the bids distributed equally among the ETH contribution.
   * Raised ETH is sent to the `fundReceiver`.
   * Bidders can withdraw their refunded ETH.
   * Another contract needs to be able to read how much REP each account purchased and how much REP in total was purchased.

### Bid Cancellation Rules
* Bids cannot normally be canceled.
* However, if the auction already holds the full `repDeposit` worth of ETH at a **higher REP/ETH price**, a bidder may cancel to reclaim their funds.

```ts
contract Auction {
	mapping(address => uint256) public purchasedRep;
	constructor(address fundReceiver, uint256 minBidSizeEth) {
		// auction contract is created, anyone can bid
	}
	function startAuction(uint256 ethAmountToBuy) public {
		// one week long auction is started
	}
	function finalizeAuction() public {
		// auction is finalized, people can withdraw their REP / ETH, the auction sends the left over REP and ETH to fundReceiver
	}
}
```

## Participation Reward
To encourage users to submit their bids early, we introduce a participation reward. Early bids help signal to open interest holders that the auction is likely to succeed.

If the auction concludes with a final price that results in only part of the attackers’ REP being sold for the available ETH, there will be some remaining REP that does not belong to current system participants. Instead of distributing this remaining REP proportionally to existing REP holders, a more effective approach is to reward it to users who locked ETH in the auction early.

The reward can be distributed as follows:

```math
\text{Reward}_{user} = 
\frac{
\text{Time the bid was binding}_{user} \times \text{Bid size in ETH}_{user}
}{
\sum_{all\ users} \left( \text{Time the bid was binding}_{user} \times \text{Bid size in ETH}_{user} \right)
}
\times \text{Total Reward}
```

This formula ensures that users who committed larger amounts of ETH earlier receive proportionally higher rewards.

While the actual distribution of rewards occurs outside the auction contract, the auction contract must expose the necessary data so that the reward mechanism can be implemented accurately by an external contract.
