// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IERC20 {
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

interface IERC3009 {
    function transferWithAuthorization(
        address from,
        address to,
        uint256 value,
        uint256 validAfter,
        uint256 validBefore,
        bytes32 nonce,
        bytes memory signature
    ) external;
}

contract ContentfulSends {
    event MessagedTransfer(
        address indexed from,
        address indexed to,
        uint256 value,
        string message
    );

    function sendErc20WithPermit(
        address token,
        address from,
        address to,
        uint256 value,
        uint256 validAfter,
        uint256 validBefore,
        bytes32 nonce,
        bytes calldata signature,
        string calldata message
    ) external {
        // Execute the EIP3009 transfer
        IERC3009(token).transferWithAuthorization(
            from,
            to,
            value,
            validAfter,
            validBefore,
            nonce,
            signature
        );

        // Emit the message event
        emit MessagedTransfer(from, to, value, message);
    }

    function sendErc20(
        address token,
        address from,
        address to,
        uint256 value,
        string calldata message
    ) external {
        // Execute regular ERC20 transfer
        require(IERC20(token).transferFrom(from, to, value), "Transfer failed");
        
        // Emit the message event
        emit MessagedTransfer(from, to, value, message);
    }
} 