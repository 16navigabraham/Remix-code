// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
//Authored by @AbrahamNAVIG, 2025//10/17//
//@dipersion contract for a  dapps//
// allows user to send tokens to multiple recipients in a single transaction//
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
  
contract Dipersion is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Address for address;

    // Events
    event TokensSent(address indexed token, address indexed from, address[] recipients, uint256[] amounts);
    event TokenSent(address indexed token, address indexed from, address indexed to, uint256 amount);
    event InsufficientAllowance(address indexed token, address indexed from, address indexed to, uint256 required, uint256 available);
    event InsufficientBalance(address indexed token, address indexed from, uint256 required, uint256 available);

//to send different amounts of tokens to multiple recipients//
//to send same amount of tokens to multiple recipients//
//throws error if insufficient balance//
//throws error if no recipients provided//

    function sendSameAmount(address token, address[] calldata recipients, uint256 amount) external whenNotPaused nonReentrant {
        require(recipients.length > 0, "No recipients provided");
        require(amount > 0, "Amount must be greater than zero");

        IERC20 erc20 = IERC20(token);
        uint256 totalAmount = amount * recipients.length;
        require(erc20.balanceOf(msg.sender) >= totalAmount, "Insufficient balance");

        for (uint256 i = 0; i < recipients.length; i++) {
            erc20.transferFrom(msg.sender, recipients[i], amount);
        }
    }

//ability to send different amounts of tokens to multiple recipients//
//throws error if insufficient balance//
//ability to handle varying lengths of recipient and amount arrays//
    function sendDifferentAmounts(address token, address[] calldata recipients, uint256[] calldata amounts) external whenNotPaused nonReentrant {
        require(recipients.length > 0, "No recipients provided");
        require(recipients.length == amounts.length, "Recipients and amounts length mismatch");

        IERC20 erc20 = IERC20(token);
        uint256 totalAmount = 0;

        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }

        require(erc20.balanceOf(msg.sender) >= totalAmount, "Insufficient balance");

        for (uint256 i = 0; i < recipients.length; i++) {
            erc20.transferFrom(msg.sender, recipients[i], amounts[i]);
        }
    }


//combined function to send different amounts of tokens to multiple recipients with event logging//
//throws error if insufficient balance//

    function sendmixedTokens(address token, address[] calldata recipients, uint256[] calldata amounts) external whenNotPaused nonReentrant {
        require(recipients.length > 0, "No recipients provided");
        require(recipients.length == amounts.length, "Recipients and amounts length mismatch");

        IERC20 erc20 = IERC20(token);
        uint256 totalAmount = 0;

        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }

        require(erc20.balanceOf(msg.sender) >= totalAmount, "Insufficient balance");

        for (uint256 i = 0; i < recipients.length; i++) {
            erc20.transferFrom(msg.sender, recipients[i], amounts[i]);
        }
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}