// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {ContentfulSends} from "../contracts/src/ContentfulSends.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockERC3009} from "./mocks/MockERC3009.sol";

contract ContentfulSendsTest is Test {
    ContentfulSends public sends;
    MockERC20 public token;
    MockERC3009 public token3009;
    
    address public constant ALICE = address(0x1);
    address public constant BOB = address(0x2);
    uint256 public constant INITIAL_BALANCE = 1000e18;
    
    function setUp() public {
        sends = new ContentfulSends();
        token = new MockERC20("Test", "TST");
        token3009 = new MockERC3009("Test3009", "TST9");
        
        // Setup balances and approvals
        token.mint(ALICE, INITIAL_BALANCE);
        token3009.mint(ALICE, INITIAL_BALANCE);
        
        vm.prank(ALICE);
        token.approve(address(sends), type(uint256).max);
    }
    
    function testSendErc20() public {
        uint256 amount = 100e18;
        string memory message = "Hello Bob!";
        
        vm.prank(ALICE);
        sends.sendErc20(address(token), ALICE, BOB, amount, message);
        
        assertEq(token.balanceOf(BOB), amount);
        assertEq(token.balanceOf(ALICE), INITIAL_BALANCE - amount);
    }
    
    function testSendErc20EmitsEvent() public {
        uint256 amount = 100e18;
        string memory message = "Hello Bob!";
        
        vm.expectEmit(true, true, false, true);
        emit ContentfulSends.MessagedTransfer(ALICE, BOB, amount, message);
        
        vm.prank(ALICE);
        sends.sendErc20(address(token), ALICE, BOB, amount, message);
    }
    
    function testSendErc20FailsWithoutApproval() public {
        uint256 amount = 100e18;
        
        vm.prank(ALICE);
        token.approve(address(sends), 0); // Remove approval
        
        vm.expectRevert("Transfer failed");
        vm.prank(ALICE);
        sends.sendErc20(address(token), ALICE, BOB, amount, "Should fail");
    }
    
    function testSendErc20FailsWithInsufficientBalance() public {
        uint256 amount = INITIAL_BALANCE + 1;
        
        vm.expectRevert("Transfer failed");
        vm.prank(ALICE);
        sends.sendErc20(address(token), ALICE, BOB, amount, "Should fail");
    }
    
    function testSendErc3009WithPermit() public {
        uint256 amount = 100e18;
        uint256 validAfter = block.timestamp;
        uint256 validBefore = block.timestamp + 1 days;
        bytes32 nonce = bytes32(uint256(1));
        
        // Create signature (in real test this would be a valid signature)
        bytes memory signature = new bytes(65);
        
        vm.prank(ALICE);
        sends.sendErc20WithPermit(
            address(token3009),
            ALICE,
            BOB,
            amount,
            validAfter,
            validBefore,
            nonce,
            signature,
            "Hello from ERC3009!"
        );
        
        assertEq(token3009.balanceOf(BOB), amount);
        assertEq(token3009.balanceOf(ALICE), INITIAL_BALANCE - amount);
    }
    
    function testSendErc3009EmitsEvent() public {
        uint256 amount = 100e18;
        uint256 validAfter = block.timestamp;
        uint256 validBefore = block.timestamp + 1 days;
        bytes32 nonce = bytes32(uint256(1));
        bytes memory signature = new bytes(65);
        string memory message = "Hello from ERC3009!";
        
        vm.expectEmit(true, true, false, true);
        emit ContentfulSends.MessagedTransfer(ALICE, BOB, amount, message);
        
        vm.prank(ALICE);
        sends.sendErc20WithPermit(
            address(token3009),
            ALICE,
            BOB,
            amount,
            validAfter,
            validBefore,
            nonce,
            signature,
            message
        );
    }
} 