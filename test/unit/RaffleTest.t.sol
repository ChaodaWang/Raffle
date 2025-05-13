//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import{CodeConstants} from "script/HelperConfig.s.sol";

contract RaffleTest is CodeConstants, Test {
    Raffle public raffle;
    HelperConfig public helperConfig;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoodininator;
    bytes32 gasLane;
    uint32 callbackGasLimit;
    uint256 subscriptionId;

    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployContract();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoodininator = config.vrfCoodininator;
        gasLane = config.gasLane;
        callbackGasLimit = config.callbackGasLimit;
        subscriptionId = config.subscriptionId;
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    /*//////////////////////////////////////////////////////////////
                        ENTER RAFFLE
    //////////////////////////////////////////////////////////////*/
    function testRaffleRevertsWhenYouDontPayEnough() public {
        // Arrange
        vm.prank(PLAYER);
        // Act / Assert
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayersWhenTheyEnter() public {
        // Arrange
        vm.prank(PLAYER);
        // Act
        raffle.enterRaffle{value: entranceFee}();
        // Assert
        address playerRecord = raffle.getPlayer(0);
        assert(playerRecord == PLAYER);
    }

    // function testEnteringRaffleEmitsEvent() public {
    //     // Arrange
    //     vm.prank(PLAYER);
    //     // Act
    //     vm.expectEmit(true, false, false, false, address(raffle));
    //     emit RaffleEntered(PLAYER);
    //     // Assert
    //     raffle.enterRaffle{value: entranceFee}();
    // }

    function testDontAllowPlayersToEnterWhileRaffleIsCalculation() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        // Act / Assert
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    /*////////////////////////////////////////////////////////////////////////////
                            CHECK UPKEEP
    ////////////////////////////////////////////////////////////////////////////*/
    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        // Arrange （准备阶段）
        // vm.warp(...)：这个函数用于模拟时间的推进。这里将区块时间推进到当前时间加上 interval（一个预先定义的时间间隔）再加上一秒。这通常用于测试合约中的时间相关逻辑。
        // vm.roll(...)：这个函数用于模拟区块高度的增加。将区块高度增加到当前区块高度加一。这可能是为了确保合约的状态更新与新的区块高度相一致。
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act （执行阶段）
        // raffle.checkUpkeep("")：调用 raffle 合约的 checkUpkeep 函数。checkUpkeep 是一个通常用于检查是否需要执行某种操作的函数（例如，是否需要进行抽奖等）。这里传递了一个空字符串作为参数。
        // 该函数返回两个值，第一个是 upkeepNeeded（布尔值），表示是否需要进行维护操作；第二个值被忽略（用逗号表示）。
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert （断言阶段）
        // 使用 assert 语句来验证 upkeepNeeded 为 false。这意味着如果合约没有余额，checkUpkeep 函数应该返回 false，表示
        assert(!upkeepNeeded);

        // 这种测试通常用于确保合约的逻辑正确性，特别是在涉及到定时器、抽奖或其他需要定期检查状态的合约中。通过这样的测试，开发者可以确保合约在不同条件下的行为符合预期，从而提高合约的可靠性和安全性。
    }

    function testCheckUpkeepReturnsFalseIfRaffleIsntOpen() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    // Challange
    // testCheckUpkeepReturnsFalseIfEnoughTimeHasPassed
    // testCheckUpkeepReturnsTrueWhenParametersAreGood

    /*//////////////////////////////////////////////////////////////
                        PERFORM UPKEEP
    //////////////////////////////////////////////////////////////*/

    /**
     * 这个 Solidity 函数 testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue 看起来是一个测试函数，通常用于单元测试框架（如 Hardhat、Truffle 或 Foundry）中，以验证合约的某些功能。下面是对这个函数的逐行讲解：

    函数定义

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
    这是一个公共函数，通常以 test 开头以表明它是一个测试用例。
    函数名表明它的目的是验证 performUpkeep 函数只能在 checkUpkeep 返回 true 时运行。
    Arrange

    // Arrange
    vm.prank(PLAYER);
    raffle.enterRaffle{value: entranceFee}();
    vm.warp(block.timestamp + interval + 1);
    vm.roll(block.number + 1);
    vm.prank(PLAYER);：这是一个模拟调用的设置，表示后续的操作将以 PLAYER 的身份进行。这通常用于模拟某个账户的行为。
    raffle.enterRaffle{value: entranceFee}();：调用 raffle 合约的 enterRaffle 函数，传入 entranceFee 的以太币。这个操作通常是让玩家进入一个抽奖（raffle）。
    vm.warp(block.timestamp + interval + 1);：将区块时间推进到未来的某个时间点。这通常用于模拟时间的流逝，以便在测试中触发某些基于时间的逻辑。
    vm.roll(block.number + 1);：将区块号推进到下一个区块。这通常用于确保合约在新的区块中执行某些逻辑。
    Act / Assert

    // Act / Assert
    raffle.performUpkeep("");
    raffle.performUpkeep("");：调用 raffle 合约的 performUpkeep 函数，并传入空字符串。这个函数通常用于执行一些维护操作，例如处理抽奖逻辑。
    这个调用的目的是测试 performUpkeep 是否能够在 checkUpkeep 返回 true 的情况下成功执行。通常，在测试框架中，您会在此之后添加断言（assertions）来验证合约的状态是否符合预期。
    总结

    这个测试函数的目的是确保 performUpkeep 只有在 checkUpkeep 返回 true 时能够被成功调用。通过设置合适的条件（如时间流逝和区块推进），测试模拟了一个玩家进入抽奖并触发维护操作的场景。通常，您会在这个测试的后面添加一些断言，以验证合约状态或事件是否如预期那样变化。
     */
    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        // Arrange
        vm.prank(PLAYER); // 作用: 该函数用于模拟一个特定地址（在这里是 PLAYER）调用后续的函数。也就是说，任何后续的合约调用（如 raffle.enterRaffle）都将被视为由 PLAYER 地址发起的。这在测试中非常有用，因为它允许开发者模拟不同用户的行为。
        raffle.enterRaffle{value: entranceFee}(); // 作用: 这行代码调用 raffle 合约的 enterRaffle 函数，并通过 {value: entranceFee} 传递入场费。它表示 PLAYER 地址正在支付 entranceFee 进入抽奖。这是模拟用户参与抽奖的行为。
        vm.warp(block.timestamp + interval + 1); // 作用: vm.warp 用于将区块链的时间（block.timestamp）向前推进到一个指定的时间。在这里，它将时间推进到当前时间加上 interval（可能是抽奖的时间间隔）再加上 1 秒。这通常用于测试合约中与时间相关的逻辑，比如抽奖结束的条件。
        vm.roll(block.number + 1); //作用: vm.roll 用于将区块链的区块高度（block.number）向前推进到指定的区块号。在这里，它将区块高度推进到当前区块号加 1。这在测试中用于模拟新的区块被挖掘，通常与时间推进一起使用，以确保合约的状态更新符合预期。

        // Act / Assert
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        // Arrange
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState rState = raffle.getRaffleState();

        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        currentBalance = currentBalance + entranceFee;
        numPlayers = 1;

        // Act / Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                currentBalance,
                numPlayers,
                rState
            )
        );
        raffle.performUpkeep("");
    }

    modifier raffleEntered() {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId()
        public
        raffleEntered
    {
        // Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        // Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(requestId) > 0);
        assert(uint256(raffleState) == 1);
    }

    /*//////////////////////////////////////////////////////////////
                        FULFILLRANDOMWORDS
    //////////////////////////////////////////////////////////////*/
    modifier skipFork(){
        if (block.chainid != LOCAL_CHAIN_ID) {
            return;
        }
        _;
    }
    
    
    function testFulfillrandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId
    ) public raffleEntered skipFork{
        // Arrange / Act / Assert
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoodininator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    function testFulfillrandomWordsPicksAWinnerRequestAndSendsMoney()
        public
        raffleEntered skipFork 
    {
        // Arrange
        uint256 additionalEntrants = 3; // 4 players total
        uint256 startingIndex = 1;
        address expectedWinner = address(1);

        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrants;
            i++
        ) {
            address newPlayer = address(uint160(i));
            hoax(newPlayer, 1 ether);
            raffle.enterRaffle{value: entranceFee}();
        }
        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 winnerStartingBalance = expectedWinner.balance;

        // Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2_5Mock(vrfCoodininator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        // Assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState(); 
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = entranceFee * (additionalEntrants + 1);

        assert(recentWinner == expectedWinner);
        assert(uint256(raffleState) == 0);
        assert(winnerBalance == winnerStartingBalance + prize);
        assert(endingTimeStamp > startingTimeStamp);
    }
}
