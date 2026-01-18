// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// 1. The Parent
contract Logger {
    event Deposit(address sender, uint256 amount);

    function logDeposit(uint256 _amount) internal virtual {
        emit Deposit(msg.sender, _amount);
    }
}

// 2. The Child (Inheritance)
contract Wallet is Logger {
    
    // 3. Receive (Direct Payments)
    receive() external payable {
        logDeposit(msg.value);
    }

    // 4. Override Logic
    function logDeposit(uint256 _amount) internal override {
        // We added a check that the parent didn't have
        require(_amount > 0, "Don't log empty tx");
        
        // Call the parent's event
        super.logDeposit(_amount);
    }
}