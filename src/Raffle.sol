// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title A sample Raffle contract
 * @author whn
 * @notice This contract is for creating a sample raffle
 * @dev Implements Chainlink VRF2.5
 */
contract Raffle is VRFConsumerBaseV2Plus {
    /* Errors */
    error Raffle__SendMoreToEnterRaffle();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(
        uint256 balance,
        uint256 playersLength,
        uint256 raffleState
    );

    /* Type declarations */
    enum RaffleState {
        OPEN, // 0
        CALCULATING // 1
    }

    /* State Variables 状态变量*/
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable i_entranceFee;
    // @dev The duration of the lottery in seconds
    uint256 private immutable i_interval;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState; // start as open

    /* Events */
    event RaffleEntered(address player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    /* 构造函数初始化合约的状态变量，并设置 VRF 的参数 */
    constructor(
        uint256 subscriptionId,
        bytes32 gasLane, // keyhash
        uint256 interval,
        uint256 entranceFee,
        uint32 callbackGasLimit,
        address vrfCoodininator
    ) VRFConsumerBaseV2Plus(vrfCoodininator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        // s_vrfCoordinator.requestRandomWords()
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;

        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }

    /* 主要功能

    1.进入抽奖 */
    // 检查是否满足条件（足够的费用和抽奖状态是否开放），允许用户发送以太币以进入抽奖。
    function enterRaffle() external payable {
        // require(msg.value > i_entranceFee, "Not enough ETH sent!");
        // require(msg.value >= i_entranceFee, SendMoreToEnterRaffle( ));

        if (msg.value < i_entranceFee) {
            revert Raffle__SendMoreToEnterRaffle();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }

        s_players.push(payable(msg.sender));
        // 1.Makes migration easier - Event
        // 2.Makes front end "indexing" easier - Event
        emit RaffleEntered(msg.sender);
    }

    // 1.Get a random number
    // 2.Use the number to pick a player

    // When should the winner be picked?
    /**
     * @dev This is the function that the Chainlink nodes wil call to see
     * if the lottery is ready to have a winner picked.
     * The following should be true in oreder for upkeepNeeded to be true:
     * 1. The time interval has passed between raffle runs
     * 2. The lottery is open
     * 3. The contract has ETH (has players)
     * 4. Implicitly, your subcription has LINK
     * @param - ignored
     * @return upkeepNeeded - true if it's time to restart the lottery
     * @return - ignored
     */

    // 2.检查自动化，检查是否满足条件以进行抽奖自动化（时间间隔、状态、余额和参与者）。
    function checkUpkeep(
        bytes memory /* checkData */
    ) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool timeHasPassed = ((block.timestamp - s_lastTimeStamp) >=
            i_interval);
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;
        return (upkeepNeeded, "");
    }

    // 3.执行自动化，如果满足条件，改变抽奖状态并请求随机数。 Be automaticlly called
    function performUpkeep(bytes calldata /* performData */) external {
        // Check to see if enough time has passed
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }

        s_raffleState = RaffleState.CALCULATING;

        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient
            .RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            });
        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);

        // Quiz... is this redundant? Yes, just for tests a little easier making learning a little bit easier here
        emit RequestedRaffleWinner(requestId);
    }

    //CEI: Checks, Effects, Interactions Pattern

    // 4.处理随机数，处理随机数并选出赢家，重置抽奖状态和参与者列表，转账。
    function fulfillRandomWords(
        uint256 /*requestId*/,
        uint256[] calldata randomWords
    ) internal override {
        // Checks

        // Effect(Internal Contract State)
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0); // Wipe out everything in s_players and just reset it to a brand new blank array.
        s_lastTimeStamp = block.timestamp; // Our interval can restart.
        emit WinnerPicked(s_recentWinner);

        // Interactions (External Contract Interactions)
        /*转账给中奖者：这段代码执行了一个以太币的转账，将合约当前余额的所有以太币转给最近的赢家（recentWinner）。使用了 Solidity 的一种低级调用方式 call，设置了转账的金额为合约的余额。
        检查转账结果：success 用于捕获转账结果。如果转账失败，将会抛出自定义错误 Raffle__TransferFailed()。这样做能够确保合约在转账时处理意外情况，提高了合约的健壮性。*/
        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    /**
     * Getter Functions，Getter 函数用于外部读取合约的状态数据，不改变合约的状态。
     */

    // 返回参与抽奖所需的费用（i_entranceFee）。外部用户可以调用此方法了解当前的参与费用。
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    // 返回当前抽奖的状态（即 s_raffleState）。可以是 OPEN 或 CALCULATING，这有助于用户了解抽奖是否正在进行。
    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    // 通过索引返回参与抽奖的玩家地址。用户可以传入一个索引值以获取具体玩家的地址，这是一个有用的函数，可以用于前端显示所有参与者信息。
    function getPlayer(uint256 indexOfPlayer) external view returns (address) {
        return s_players[indexOfPlayer];
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }
    
}
