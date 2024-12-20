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
    uint256 public constant ALICE_PRIVATE_KEY = uint256(0x1234);
    
    function setUp() public {
        sends = new ContentfulSends();
        token = new MockERC20("Test", "TST");
        token3009 = new MockERC3009("Test3009", "TST9");
        
        // Setup balances and approvals
        token.mint(ALICE, INITIAL_BALANCE);
        token3009.mint(ALICE, INITIAL_BALANCE);
        
        vm.prank(ALICE);
        token.approve(address(sends), type(uint256).max);
        
        // Label addresses for better error messages
        vm.label(ALICE, "ALICE");
        vm.label(BOB, "BOB");
        
        // Set block timestamp to a known value
        vm.warp(1000);
    }
    
    function _signTransferAuthorization(
        address from,
        address to,
        uint256 amount,
        uint256 validAfter,
        uint256 validBefore,
        bytes32 nonce
    ) internal view returns (bytes memory) {
        bytes32 digest = token3009.getTransferWithAuthorizationDigest(
            from,
            to,
            amount,
            validAfter,
            validBefore,
            nonce
        );
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ALICE_PRIVATE_KEY, digest);
        return abi.encodePacked(r, s, bytes1(v));
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
        
        vm.expectRevert("Insufficient allowance");
        vm.prank(ALICE);
        sends.sendErc20(address(token), ALICE, BOB, amount, "Should fail");
    }
    
    function testSendErc20FailsWithInsufficientBalance() public {
        uint256 amount = INITIAL_BALANCE + 1;
        
        vm.expectRevert("Insufficient balance");
        vm.prank(ALICE);
        sends.sendErc20(address(token), ALICE, BOB, amount, "Should fail");
    }
    
    function testSendErc3009WithPermit() public {
        uint256 amount = 100e18;
        uint256 validAfter = block.timestamp;
        uint256 validBefore = block.timestamp + 1 days;
        bytes32 nonce = bytes32(uint256(1));
        string memory message = "Hello from ERC3009!";
        
        bytes memory signature = _signTransferAuthorization(
            ALICE,
            BOB,
            amount,
            validAfter,
            validBefore,
            nonce
        );
        
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
        
        assertEq(token3009.balanceOf(BOB), amount);
        assertEq(token3009.balanceOf(ALICE), INITIAL_BALANCE - amount);
    }
    
    function testSendErc3009EmitsEvent() public {
        uint256 amount = 100e18;
        uint256 validAfter = block.timestamp;
        uint256 validBefore = block.timestamp + 1 days;
        bytes32 nonce = bytes32(uint256(1));
        string memory message = "Hello from ERC3009!";
        
        bytes memory signature = _signTransferAuthorization(
            ALICE,
            BOB,
            amount,
            validAfter,
            validBefore,
            nonce
        );
        
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
    
    function testSendErc20WithZeroAmount() public {
        vm.prank(ALICE);
        sends.sendErc20(address(token), ALICE, BOB, 0, "Zero amount transfer");
        
        assertEq(token.balanceOf(BOB), 0);
        assertEq(token.balanceOf(ALICE), INITIAL_BALANCE);
    }
    
    function testSendErc20ToSelf() public {
        uint256 amount = 100e18;
        
        vm.prank(ALICE);
        sends.sendErc20(address(token), ALICE, ALICE, amount, "Self transfer");
        
        assertEq(token.balanceOf(ALICE), INITIAL_BALANCE);
    }
    
    function testSendErc20WithEmptyMessage() public {
        uint256 amount = 100e18;
        
        vm.prank(ALICE);
        sends.sendErc20(address(token), ALICE, BOB, amount, "");
        
        assertEq(token.balanceOf(BOB), amount);
        assertEq(token.balanceOf(ALICE), INITIAL_BALANCE - amount);
    }
    
    function testSendErc3009WithExpiredValidBefore() public {
        uint256 amount = 100e18;
        uint256 validAfter = block.timestamp;
        uint256 validBefore = block.timestamp - 1; // Expired
        bytes32 nonce = bytes32(uint256(1));
        
        bytes memory signature = _signTransferAuthorization(
            ALICE,
            BOB,
            amount,
            validAfter,
            validBefore,
            nonce
        );
        
        vm.expectRevert("Authorization expired");
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
            "Should fail"
        );
    }
    
    function testSendErc3009WithFutureValidAfter() public {
        uint256 amount = 100e18;
        uint256 validAfter = block.timestamp + 1 hours; // Future
        uint256 validBefore = block.timestamp + 2 hours;
        bytes32 nonce = bytes32(uint256(1));
        
        bytes memory signature = _signTransferAuthorization(
            ALICE,
            BOB,
            amount,
            validAfter,
            validBefore,
            nonce
        );
        
        vm.expectRevert("Authorization not yet valid");
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
            "Should fail"
        );
    }
} 