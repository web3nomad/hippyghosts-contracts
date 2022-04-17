// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.11;

import "forge-std/Test.sol";
import "../HippyGhosts.sol";


contract HippyGhostsTest is Test {
    address userAccount = address(uint160(uint256(keccak256('from account'))));

    function setUp() public {
        //
    }

    function testMint() public {
        hoax(userAccount, 10 ether);
        assertEq(userAccount.balance, 10 ether);
    }
}
