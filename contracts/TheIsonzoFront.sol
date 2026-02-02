// SPDX-License-Identifier: UNICENSE
import { ReputationToken } from '../ReputationToken.sol';
import { Zoltar } from '../Zoltar.sol';

pragma solidity 0.8.33;

contract PriorityQueue {
	struct Entry {
		address user;
		uint priority;
	}

	Entry[] public heap;
	mapping(address => uint) public indexInHeap;

	function insertOrUpdate(address user, uint newPriority) public {
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

	function remove(address user) public {
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

	function getTop3() public view returns (Entry[3] memory top) {
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

uint256 constant FORK_THRESHOLD = 100000000;
uint256 constant FREEZE_THRESHOLD = FORK_THRESHOLD * 2;
uint256 constant maxTime = 8 weeks;
uint256 constant IMMUNE_MARKETS_COUNT = 3;

contract EscalationGame {
	uint256 public startingTime;
	uint256[3] public balances; //outcome -> amount
	mapping(uint256 => Deposit[]) public deposits;
	uint256 public lastSyncedPauseDuration;
	bool public immune;
	IsonzoFront public escalationGameManager;
	ReputationToken reputationToken;

	constructor(IsonzoFront _escalationGameManager, address designatedReporter, Outcome outcome, uint256 _lastSyncedPauseDuration) {
		startingTime = block.timestamp + 1 weeks;
		lastSyncedPauseDuration = _lastSyncedPauseDuration;
		escalationGameManager = _escalationGameManager;
		reputationToken = escalationGameManager.reputationToken();
	}

	function getBalances() public view returns (uint256[3] memory) {
		return [balances[0], balances[1], balances[2]];
	}

	function syncMarket() public {
		require(msg.sender == address(escalationGameManager), 'only manager can call');
		if (immune) return;
		uint256 currentTotalPaused = escalationGameManager.currentTotalPaused();
		uint256 newPaused = currentTotalPaused - lastSyncedPauseDuration;
		startingTime += newPaused;
		lastSyncedPauseDuration = currentTotalPaused;
	}

	function makeImmune() public {
		require(msg.sender == address(escalationGameManager), 'only manager can call');
		require(immune == false, 'Already immune!');
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

	function totalCost() public returns (uint256) {
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
		if ((balances[0] >= balances[1] && balances[0] <= balances[2]) || (balances[0] >= balances[2] && balances[0] <= balances[1])) {
			return balances[0];
		} else if ((balances[1] >= balances[0] && balances[1] <= balances[2]) || (balances[1] >= balances[2] && balances[1] <= balances[0])) {
			return balances[1];
		}
		return balances[2];
	}

	function hasForked() public view returns (bool) {
		uint8 invalidOver = balances[0] >= FORK_THRESHOLD ? 1 : 0;
		uint8 yesOver = balances[1] >= FORK_THRESHOLD ? 1 : 0;
		uint8 noOver = balances[2] >= FORK_THRESHOLD ? 1 : 0;
		if (invalidOver + yesOver + noOver >= 2) return true;
		return false;
	}

	function hasGameTimeoutedIfNotForked() public returns (bool ended, Outcome winner){
		uint256 currentTotalCost = totalCost();
		uint8 invalidOver = balances[0] >= currentTotalCost ? 1 : 0;
		uint8 yesOver = balances[1] >= currentTotalCost ? 1 : 0;
		uint8 noOver = balances[2] >= currentTotalCost ? 1 : 0;
		if (invalidOver + yesOver + noOver >= 2) return (false, Outcome.Invalid); // if two or more outcomes aer over the total cost, the game is still going
		// the game has ended to timeout
		if (balances[0] > balances[1] && balances[0] > balances[2]) {
			return (true, Outcome.Invalid);
		}
		if (balances[1] > balances[0] && balances[1] > balances[2]) {
			return (true, Outcome.Yes);
		}
		return (true, Outcome.No);
	}

	function depositOnOutcome(address depositor, Outcome outcome, uint256 amount) public {
		require(msg.sender == address(escalationGameManager), 'only manager can call');
		require(!hasForked(), 'System has already forked');
		(bool ended,) = hasGameTimeoutedIfNotForked();
		require(!ended, 'System has already timeouted');
		require(balances[uint256(outcome)] >= FORK_THRESHOLD, 'Already full');
		Deposit memory deposit;
			deposit.depositor = depositor;
			deposit.amount = amount;
			deposit.cumulativeAmount = balances[uint256(outcome)];
		balances[uint256(outcome)] += amount;
		if (balances[uint256(outcome)] > FORK_THRESHOLD) {
			reputationToken.transfer(depositor, balances[uint256(outcome)] - FORK_THRESHOLD);
			deposit.amount -= balances[uint256(outcome)] - FORK_THRESHOLD;
			balances[uint256(outcome)] = FORK_THRESHOLD;
		}
		deposits[uint256(outcome)].push(deposit);
	}

	function withdrawDeposit(uint depositIndex) public {
		require(!hasForked(), 'System has forked');
		(bool ended, Outcome winner) = hasGameTimeoutedIfNotForked();
		require(ended, 'System has already timeouted');
		Deposit memory deposit = deposits[uint256(winner)][depositIndex];
		deposits[uint256(winner)][depositIndex].amount = 0;
		require(deposit.depositor == msg.sender, 'Not depositor');
		uint256 maxWithdrawableBalance = getBindingCapital();
		if (deposit.cumulativeAmount > maxWithdrawableBalance) {
			reputationToken.transfer(msg.sender, deposit.amount);
		}
		else if (deposit.cumulativeAmount + deposit.amount > maxWithdrawableBalance) {
			uint256 excess = (deposit.cumulativeAmount + deposit.amount - maxWithdrawableBalance);
			reputationToken.transfer(msg.sender, (deposit.amount-excess) * 2 + excess);
		} else {
			reputationToken.transfer(msg.sender, deposit.amount * 2);
		}
	}
}

contract IsonzoFront is PriorityQueue {
	mapping(address => EscalationGame) public escalationGames; // market address -> game
	uint256 public totalBindingCapital;
	bool public isFrozen;
	uint256 public globalFreezeStart;
	uint256 public totalPausedDuration;
	address[IMMUNE_MARKETS_COUNT] public immuneMarkets;
	ReputationToken public reputationToken;
	event GameCreated(EscalationGame gameAddress, address market, address designatedReporter, Outcome outcome, uint256 startingStake);
	event DepositToGame(address market, address designatedReporter, Outcome outcome, uint256 startingStake);
	event Freeze();
	// TODO, support forking
	constructor(Zoltar zoltar) {
		(reputationToken,,) = zoltar.universes(0);
	}

	function createNewGame(address market, address designatedReporter, Outcome outcome, uint256 startingStake) public {
		require(address(escalationGames[market]) == address(0x0), 'Game already exists');
		escalationGames[market] = new EscalationGame{ salt: keccak256(abi.encodePacked(market)) }(this, designatedReporter, outcome, currentTotalPaused());
		emit GameCreated(escalationGames[market], market, designatedReporter, outcome, startingStake);

		tässä joku bugi, tulee over/underflow
		_depositToGame(msg.sender, market, outcome, startingStake);
	}

	function currentTotalPaused() public view returns (uint256) {
		if (isFrozen) {
			return totalPausedDuration + (block.timestamp - globalFreezeStart);
		} else {
			return totalPausedDuration;
		}
	}

	function _depositToGame(address depositor, address market, Outcome outcome, uint256 amount) private {
		emit DepositToGame(depositor, market, outcome, amount);
		totalBindingCapital -= escalationGames[market].getBindingCapital();
		reputationToken.transferFrom(depositor, address(escalationGames[market]), amount);
		escalationGames[market].depositOnOutcome(depositor, outcome, amount);
		uint256 marketBindingCapital = escalationGames[market].getBindingCapital();
		totalBindingCapital += marketBindingCapital;
		insertOrUpdate(market, marketBindingCapital);
		if (!isFrozen && totalBindingCapital > FREEZE_THRESHOLD) {
			freezeAll();
		}
	}

	function depositToGame(address market, Outcome outcome, uint256 amount) public {
		_depositToGame(msg.sender, market, outcome, amount);
	}

	function freezeAll() private {
		require(!isFrozen, "Already frozen");
		emit Freeze();
		isFrozen = true;
		globalFreezeStart = block.timestamp;
		updateImmunities();
	}

	function updateImmunities() private {
		if (!isFrozen) return;
		// handle old immunities
		uint256 currentImmuneMarkets = 0;
		uint i = 0;
		while (i < IMMUNE_MARKETS_COUNT) {
			address marketAddress = immuneMarkets[i];
			if (marketAddress == address(0)) continue;
			(bool ended,) = escalationGames[marketAddress].hasGameTimeoutedIfNotForked();
			if (escalationGames[marketAddress].hasForked() || ended) {
				internalfinalizeGame(marketAddress);
				immuneMarkets[i] = address(0);
			}
			currentImmuneMarkets++;
		}
		if (totalBindingCapital < FREEZE_THRESHOLD) {
			unfreezeAll();
			return;
		}

		if (currentImmuneMarkets == IMMUNE_MARKETS_COUNT) return; // already at max immune
		Entry[3] memory top = getTop3();
		uint256 priorityIndex = 0;
		// make top3 markets as immune
		i = 0;
		while (i < IMMUNE_MARKETS_COUNT) {
			address marketAddress = immuneMarkets[i];
			if (marketAddress != address(0)) continue;
			address newImmuneMarket = top[priorityIndex].user;
			if (newImmuneMarket == address(0)) break; // run out of markets
			immuneMarkets[i] = newImmuneMarket;
			EscalationGame(newImmuneMarket).makeImmune();
			remove(newImmuneMarket);
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
		remove(market);
	}

	function finalizeGame(address market) public {
		require(!escalationGames[market].hasForked(), 'The market has forked!');
		(bool ended,) = escalationGames[market].hasGameTimeoutedIfNotForked();
		require(ended, 'The game has not timeouted');
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
