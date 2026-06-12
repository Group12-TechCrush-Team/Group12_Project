// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "forge-std/Test.sol";
import "../src/onChainLottery.sol";

contract onChainLotteryTest is Test {
    onChainLottery public lottery;
    address public manager = address(0xABCD);
    address public player1 = address(0x1001);
    address public player2 = address(0x1002);
    address public player3 = address(0x1003);
    uint256 public constant ENTRY_FEE = 1 ether;

    function setUp() public {
        vm.prank(manager);
        lottery = new onChainLottery(ENTRY_FEE);
    }

    function testConstructorSetsManagerAndEntryFee() public {
        assertEq(lottery.manager(), manager);
        assertEq(lottery.entryFee(), ENTRY_FEE);
        assertFalse(lottery.roundOpen());
        assertEq(lottery.roundId(), 0);
    }

    function testOnlyManagerCanStartRound() public {
        vm.prank(player1);
        vm.expectRevert(bytes("Only the manager can call this function"));
        lottery.startRound(onChainLottery.PrizeType.ETHOnly, 0, ENTRY_FEE);
    }

    function testStartRoundOpensRound() public {
        vm.prank(manager);
        lottery.startRound(onChainLottery.PrizeType.ETHOnly, 0, ENTRY_FEE);

        (bool isOpen, uint256 currentRoundId, uint256 numPlayers, uint256 pot, uint256 fee, , ) = lottery.getCurrentRoundStatus();
        assertTrue(isOpen);
        assertEq(currentRoundId, 0);
        assertEq(numPlayers, 0);
        assertEq(pot, 0);
        assertEq(fee, ENTRY_FEE);
    }

    function testParticipateAddsPlayer() public {
        vm.prank(manager);
        lottery.startRound(onChainLottery.PrizeType.ETHOnly, 0, ENTRY_FEE);

        vm.deal(player1, 2 ether);
        vm.prank(player1);
        lottery.participate{value: ENTRY_FEE}();

        ( , , uint256 numPlayers, uint256 pot, , , ) = lottery.getCurrentRoundStatus();
        assertEq(numPlayers, 1);
        assertEq(pot, ENTRY_FEE);
    }

    function testParticipateTwiceReverts() public {
        vm.prank(manager);
        lottery.startRound(onChainLottery.PrizeType.ETHOnly, 0, ENTRY_FEE);

        vm.deal(player1, 2 ether);
        vm.prank(player1);
        lottery.participate{value: ENTRY_FEE}();

        vm.prank(player1);
        vm.expectRevert(bytes("hasAlreadyEntered()"));
        lottery.participate{value: ENTRY_FEE}();
    }

    function testPickWinnerRevertsWithTooFewPlayers() public {
        vm.prank(manager);
        lottery.startRound(onChainLottery.PrizeType.ETHOnly, 0, ENTRY_FEE);

        vm.deal(player1, 2 ether);
        vm.prank(player1);
        lottery.participate{value: ENTRY_FEE}();

        vm.prank(manager);
        vm.expectRevert(bytes("notEnoughPlayers()"));
        lottery.pickWinner();
    }

    function testPickWinnerCompletesRound() public {
        vm.prank(manager);
        lottery.startRound(onChainLottery.PrizeType.ETHOnly, 0, ENTRY_FEE);

        vm.deal(player1, 5 ether);
        vm.deal(player2, 5 ether);
        vm.deal(player3, 5 ether);

        vm.prank(player1);
        lottery.participate{value: ENTRY_FEE}();
        vm.prank(player2);
        lottery.participate{value: ENTRY_FEE}();
        vm.prank(player3);
        lottery.participate{value: ENTRY_FEE}();

        uint256 managerBefore = manager.balance;
        uint256 player1Before = player1.balance;
        uint256 player2Before = player2.balance;
        uint256 player3Before = player3.balance;

        vm.prank(manager);
        lottery.pickWinner();

        address winnerAddress = lottery.winner();
        uint256 expectedManagerFee = (3 ether * 5) / 100;
        uint256 expectedWinnerPrize = 3 ether - expectedManagerFee;

        assertEq(address(lottery).balance, 0);
        assertEq(manager.balance, managerBefore + expectedManagerFee);

        if (winnerAddress == player1) {
            assertEq(player1.balance, player1Before + expectedWinnerPrize);
        } else if (winnerAddress == player2) {
            assertEq(player2.balance, player2Before + expectedWinnerPrize);
        } else if (winnerAddress == player3) {
            assertEq(player3.balance, player3Before + expectedWinnerPrize);
        } else {
            revert("Winner must be one of the players");
        }

        (bool isOpen, , uint256 numPlayers, , , , ) = lottery.getCurrentRoundStatus();
        assertFalse(isOpen);
        assertEq(numPlayers, 0);
    }

    function testCancelRoundRefundsPlayers() public {
        vm.prank(manager);
        lottery.startRound(onChainLottery.PrizeType.ETHOnly, 0, ENTRY_FEE);

        vm.deal(player1, 5 ether);
        vm.deal(player2, 5 ether);

        vm.prank(player1);
        lottery.participate{value: ENTRY_FEE}();
        vm.prank(player2);
        lottery.participate{value: ENTRY_FEE}();

        uint256 player1Before = player1.balance;
        uint256 player2Before = player2.balance;

        vm.prank(manager);
        lottery.cancelRound();

        assertEq(player1.balance, player1Before + ENTRY_FEE);
        assertEq(player2.balance, player2Before + ENTRY_FEE);
        assertEq(address(lottery).balance, 0);
        assertFalse(lottery.roundOpen());
    }
}
