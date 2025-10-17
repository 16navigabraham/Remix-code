// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IERC20 {
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

contract TipMe {
    address public owner;

    event TipSent(
        address indexed token,
        address indexed from,
        address indexed to,
        uint256 amount,
        uint timestamp
    );

    constructor() {
        owner = msg.sender;
    }

    // Tip with ERC-20 tokens
    function tipWithERC20(
        address tokenAddress,
        address to,
        uint256 amount
   ) external {
        require(amount > 0, "Amount must be > 0");
        require(to != address(0), "Invalid recipient");

        IERC20 token = IERC20(tokenAddress);
        bool success = token.transferFrom(msg.sender, to, amount);
        require(success, "Transfer failed");

        emit TipSent(tokenAddress, msg.sender, to, amount, block.timestamp);
    }

    // Tip with native token (ETH, MATIC, etc.)
    function tipWithNative(address to) external payable {
        require(msg.value > 0, "no input value");
        require(to != address(0), "Invalid recipient");

        (bool sent, ) = payable(to).call{value: msg.value}("");
        require(sent, "Native transfer failed");

        emit TipSent(address(0), msg.sender, to, msg.value, block.timestamp);
    }
}
