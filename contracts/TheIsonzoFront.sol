// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

contract PriorityQueue {
	struct Entry {
		address user;
		uint priority;
	}

	Entry[] public heap;
	mapping(address => uint) public indexInHeap;

	function insertOrUpdate(address user, uint newPriority) external {
		if (!_exists(user)) {
			Entry memory entry = Entry(user, newPriority);
			heap.push(entry);
			uint i = heap.length - 1;
			indexInHeap[user] = i;
			_heapifyUp(i);
		} else {
			uint i = indexInHeap[user];
			require(heap[i].priority < newPriority, "Priority can only increase");
			heap[i].priority = newPriority;
			_heapifyUp(i);
		}
	}

	function remove(address user) external {
		require(_exists(user), "User not in heap");

		uint i = indexInHeap[user];
		uint last = heap.length - 1;

		_swap(i, last);
		heap.pop();
		delete indexInHeap[user];

		if (i < heap.length) {
			_heapifyUp(i);
			_heapifyDown(i);
		}
	}

	function getTop3() external view returns (Entry[3] memory top) {
		for (uint i = 0; i < 3 && i < heap.length; i++) {
			top[i] = heap[i];
		}
	}

	function _heapifyUp(uint i) internal {
		while (i > 0) {
			uint parent = (i - 1) / 2;
			if (heap[i].priority <= heap[parent].priority) break;

			_swap(i, parent);
			i = parent;
		}
	}

	function _heapifyDown(uint i) internal {
		uint n = heap.length;

		while (true) {
			uint left = 2 * i + 1;
			uint right = 2 * i + 2;
			uint largest = i;

			if (left < n && heap[left].priority > heap[largest].priority) {
				largest = left;
			}
			if (right < n && heap[right].priority > heap[largest].priority) {
				largest = right;
			}

			if (largest == i) break;

			_swap(i, largest);
			i = largest;
		}
	}

	function _swap(uint i, uint j) internal {
		Entry memory temp = heap[i];
		heap[i] = heap[j];
		heap[j] = temp;

		indexInHeap[heap[i].user] = i;
		indexInHeap[heap[j].user] = j;
	}

	function _exists(address user) internal view returns (bool) {
		if (heap.length == 0) return false;
		uint i = indexInHeap[user];
		return i < heap.length && heap[i].user == user;
	}
}

enum Outcome {
	Invalid,
	Yes,
	No
}

struct Deposit {
	address depositor;
	uint256 amount;
	uint256 cumulativeAmount;
}

address escalationGameManager = EscalationGameManager(0x0)
uint256 FORK_THRESHOLD = 100000000;
uint256 FREEZE_THRESHOLD = FORK_THRESHOLD * 2;
uint256 maxTime = 8 weeks;
uint256 IMMUNE_MARKETS_COUNT = 3;

contract EscalationGame {
	private uint256 startingTime;
	private mapping(Outcome => uint256) balances; //outcome -> amount
	private mapping(uint256 => Deposit[]) public deposits;
	public uint256 lastSyncedPauseDuration;
	public boolean immune;
	
	constructor(address designatedReporter, Outcome outcome, uint256 startingStake, uint256 lastSyncedPauseDuration) {
		startingTime = block.timestamp + 1 week;
		this.lastSyncedPauseDuration = lastSyncedPauseDuration;
		depositOnOutcomePrivate(designatedReporter, outcome, startingStake);
	}

	function syncMarket() {
		require(msg.sender === address(escalationGameManager), 'only manager can call');
		if (immune) return;
		uint256 currentTotalPaused = EscalationGameManager.getCurrentTotalPaused();
		uint256 newPaused = currentTotalPaused - m.lastSyncedPauseDuration;
		startingTime += newPaused;
		lastSyncedPauseDuration = currentTotalPaused;
	}

	function makeImmune() {
		require(msg.sender === address(escalationGameManager), 'only manager can call');
		require(immune === false, 'Already immune!');
		syncMarket();
		immune = true;
	}
	
	function pow(uint256 base, uint256 exp, uint256 scale) internal pure returns (uint256) {
		uint256 result = scale;
		while (exp > 0) {
			if (exp % 2 == 1) {
				result = (result * base) / scale;
			}
			base = (base * base) / scale;
			exp /= 2;
		}
		return result;
	}

	function totalCost() public view returns (uint256) {
		syncMarket();
		uint256 timeFromStart = block.timestamp - startingTime;
		if (timeFromStart <= 0) return 0;
		if (timeFromStart >= 4233600) return FORK_THRESHOLD;
		/*
		// approximates e^(ln(FORK_THRESHOLD) / duration) scaled by SCALE
		const duration = 4233600; // 7 weeks
		const FORK_THRESHOLD = 100000000;
		const base = FORK_THRESHOLD ** (1 / duration) // fractional exponent off-chain
		*/
		uint256 base = 1000000000547; // scaled by 1e12
		uint256 scale = 1e12;
		return pow(base, timeFromStart, scale);
	}
	function getBindingCapital() public view returns (uint256) {
		if ((balance[0] >= balance[1] && balance[0] <= balance[2]) || (balance[0] >= balance[2] && balance[0] <= balance[1])) {
			return balance[0];
		} else if ((balance[1] >= balance[0] && balance[1] <= balance[2]) || (balance[1] >= balance[2] && balance[1] <= balance[0])) {
			return balance[1];
		}
		return balance[2];
	}
	
	fuction hasForked() {
		boolean invalidOver = balances[0] >= FORK_THRESHOLD ? 1 : 0;
		boolean yesOver = balances[1] >= FORK_THRESHOLD ? 1 : 0;
		boolean noOver = balances[2] >= FORK_THRESHOLD ? 1 : 0;
		if (invalidOver + yesOver + noOver >= 2) return true;
		return false
	}
	
	function hasGameTimeoutedIfNotForked() returns (boolean ended, uint256 winner){
		uint256 currentTotalCost = totalCost();
		boolean invalidOver = balances[0] >= currentTotalCost ? 1 : 0;
		boolean yesOver = balances[1] >= currentTotalCost ? 1 : 0;
		boolean noOver = balances[2] >= currentTotalCost ? 1 : 0;
		if (invalidOver + yesOver + noOver >= 2) return (false, 0); // if two or more outcomes aer over the total cost, the game is still going
		// the game has ended to timeout
		if (balances[0] > balances[1] && balances[0] > balances[2]) {
			return (true, Outcome.Invalid)
		}
		if (balances[1] > balances[0] && balances[1] > balances[2]) {
			return (true, Outcome.Yes)
		}
		return (true, Outcome.No)
	}
	function depositOnOutcome(address depositor, Outcome outcome, uint256 amount) {
		require(msg.sender === address(escalationGameManager), 'only manager can call');
		require(!hasForked(), 'System has already forked');
		(boolean ended, Outcome winner) = hasGameTimeoutedIfNotForked();
		require(!ended, 'System has already timeouted');
		require(balances[outcome] >= FORK_THRESHOLD, 'Already full');
		Deposit deposit;
			deposit.depositor = depositor;
			deposit.amount = amount;
			deposit.cumulativeAmount = balances[outcome];
		balances[outcome] += amount;
		if (balances[outcome] > FORK_THRESHOLD) {
			//return excess (balances[outcome]-FORK_THRESHOLD)
			deposit.amount -= balances[outcome] - FORK_THRESHOLD;
			balances[outcome] = FORK_THRESHOLD;
		}
		deposits[outcome].push(deposit)
	}
	function withdrawDeposit(uint depositIndex) {
		require(!hasForked(), 'System has forked');
		(boolean ended, Outcome winner) = hasGameTimeoutedIfNotForked();
		require(ended, 'System has already timeouted');
		Deposit deposit = deposits[winner][depositIndex];
		require(deposit.depositor === msg.sender, 'Not depositor');
		uint256 maxWithdrawableBalance = getBindingCapital();
		if (deposit.cumulativeAmount > maxWithdrawableBalance) {
			// return balance without profit, deposited too late to count
			//return deposit.amount;
			return
		}
		if (deposit.cumulativeAmount + deposit.amount; > maxWithdrawableBalance) {
			uint256 excess = (deposit.cumulativeAmount + deposit.amount - maxWithdrawableBalance);
			// return (deposit.amount-excess) * 2 + excess;
			return
		}
		// return deposit.amount * 2;
		return;
	}
}

contract EscalationGameManager {
	private priorityQueue = new PriorityQueue();
	private mapping(address => EscalationGame) escalationGames; //market address -> game
	private uint256 totalBindingCapital;
	private boolean isFrozen;
	private uint256 globalFreezeStart;
	uint256 public totalPausedDuration;
	private address[IMMUNE_MARKETS_COUNT] immuneMarkets;

	function createNewGame(address market, address designatedReporter, uint256 outcome, uint256 startingStake) {
		require(escalationGames[market] === address(0x0), 'Game already exists');
		escalationGames[market] = new EscalationGame(designatedReporter, outcome, startingStake);
	}

	function currentTotalPaused() public view returns (uint256) {
		if (isFrozen) {
			return totalPausedDuration + (block.timestamp - globalFreezeStart)
		} else {
			return totalPausedDuration
		}
	}
	
	function depositToGame(address Market, Outcome outcome, uint256 amount) {
		totalBindingCapital -= escalationGames[address].getBindingCapital();
		escalationGames[address].depositOnOutcome(msg.sender, outcome, amount);
		uint256 marketBindingCapital = escalationGames[address].getBindingCapital();
		totalBindingCapital += marketBindingCapital;
		priorityQueue.insertOrUpdate(market, marketBindingCapital);
		if (!isFrozen && totalBindingCapital > FREEZE_THRESHOLD) {
			freezeAll();
		}
	}

	
	function freezeAll() private {
		require(!isFrozen, "Already frozen");
		isFrozen = true;
		globalFreezeStart = block.timestamp;
		updateImmunities();
	}
	function updateImmunities() private {
		if (!isFrozen) return
		// handle old immunities
		uint256 currentImmuneMarkets = 0;
		uint i = 0;
		while (i < IMMUNE_MARKETS_COUNT) {
			const marketAddress = immuneMarkets[i]
			if (marketAddress === address(0)) continue;
			if (escalationGames[marketAddress].hasForked() || escalationGames[address].hasGameTimeoutedIfNotForked()) {
				internalfinalizeGame(marketAddress);
				immuneMarkets[i] = 0;
			}
			currentImmuneMarkets++;
		}
		if (totalBindingCapital < FREEZE_THRESHOLD) {
			unfreezeAll();
			return;
		}

		if (currentImmuneMarkets === IMMUNE_MARKETS_COUNT) return // already at max immune
		Entry[IMMUNE_MARKETS_COUNT] top = priorityQueue.getTop3();
		uint256 priorityIndex = 0;
		// make top3 markets as immune
		i = 0;
		while (i < IMMUNE_MARKETS_COUNT) {
			const marketAddress = immuneMarkets[i];
			if (marketAddress !== address(0)) continue
			address newImmuneMarket = top[priorityIndex].user;
			if (newImmuneMarket === 0) break // run out of markets
			immuneMarkets[i] = newImmuneMarket;
			EscalationGame(newImmuneMarket).makeImmune();
			priorityQueue.remove(newImmuneMarket);
			priorityIndex++;
		}
	}

	function unfreezeAll() private {
		require(isFrozen, "Not frozen");
		isFrozen = false;
		totalPausedDuration += block.timestamp - globalFreezeStart;
		globalFreezeStart = 0;
	}
	function internalfinalizeGame(address market) private {
		totalBindingCapital -= escalationGames[market].getBindingCapital();
		priorityQueue.remove(market);
	}

	function finalizeGame(address market) {
		require(!escalationGames[market].hasForked(), 'The market has forked!');
		require(escalationGames[market].hasGameTimeoutedIfNotForked(), 'The game has not timeouted');
		internalfinalizeGame(market);
		if (isFrozen) {
			if (totalBindingCapital < FREEZE_THRESHOLD) {
				unfreezeAll();
			} else {
				updateImmunities();
			}
		}
	}
}
