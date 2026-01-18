// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// @author : Baseconnect 

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract SubscriptionPayment is Ownable2Step, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // --- STATE VARIABLES ---
    IERC20 public token1; 
    IERC20 public token2;

    // Volume Tracking
    uint256 public totalsubscription;
    
    // UPDATED: Track volume per token address to handle different decimals
    mapping(address => uint256) public volumePerToken;

    // Mappings
    // msg.sender -> applicant_id
    mapping(address => string) public payment; 
    
    // applicant_id -> subscription_type -> amount paid
    mapping(string => mapping(string => uint256)) public receipts;
    
    // applicant_id -> list of subscription types (for fetching data)
    mapping(string => string[]) public applicantSubscriptionTypes;

    // --- EVENTS ---
    event Subscribed(address indexed subscriber, string applicantId, string subscriptionType, uint256 amount, address tokenUsed, uint256 timestamp);
    event Withdrawn(address indexed token, uint256 amount, address indexed recipient, uint256 timestamp);
    event TokenUpdated(string slot, address oldToken, address newToken);

    // --- CONSTRUCTOR ---
    constructor(address initialOwner, address _primaryToken) Ownable(initialOwner) {
        require(_primaryToken != address(0), "Token address cannot be zero");
        token1 = IERC20(_primaryToken);
        // token2 starts empty (address(0)) until  added
    }

    // --- ADMIN: UPDATE / REMOVE TOKENS ---

    function updateToken1(address _newToken) external onlyOwner {
        emit TokenUpdated("Token1", address(token1), _newToken);
        token1 = IERC20(_newToken);
    }

    function updateToken2(address _newToken) external onlyOwner {
        emit TokenUpdated("Token2", address(token2), _newToken);
        token2 = IERC20(_newToken);
    }

    // --- MAIN SUBSCRIPTION FUNCTION ---

    /**
     * @notice Subscribe a user using EITHER token1 OR token2
     * @param _applicant_id Unique ID of the applicant
     * @param _subscriptiontype Type of subscription (e.g., "premium")
     * @param _amount Amount to pay (Ensure decimals match the selected token!)
     * @param _selectedToken The address of the token the user wants to pay with
     */
    function subscribe(
        string memory _applicant_id, 
        string memory _subscriptiontype, 
        uint256 _amount, 
        address _selectedToken
    ) public whenNotPaused nonReentrant {
        require(_amount > 0, "Amount must be greater than zero");

        // 1. VALIDATION: Ensure the selected token is valid and active
        bool isToken1 = (_selectedToken == address(token1) && address(token1) != address(0));
        bool isToken2 = (_selectedToken == address(token2) && address(token2) != address(0));

        require(isToken1 || isToken2, "Token not accepted or not active");

        // 2. TRANSFER: Pull funds from the user
        IERC20(_selectedToken).safeTransferFrom(msg.sender, address(this), _amount);

        // 3. STATE UPDATES
        
        // If this is the first time this user pays for this specific type, add it to the list
        if (receipts[_applicant_id][_subscriptiontype] == 0) {
            applicantSubscriptionTypes[_applicant_id].push(_subscriptiontype);
        }

        receipts[_applicant_id][_subscriptiontype] += _amount;
        
        // UPDATED: Add volume to the specific token bucket
        volumePerToken[_selectedToken] += _amount;
        
        totalsubscription += 1;
        payment[msg.sender] = _applicant_id;

        emit Subscribed(msg.sender, _applicant_id, _subscriptiontype, _amount, _selectedToken, block.timestamp);
    }

    // --- GETTER FUNCTIONS ---

    function getListOfUserSubscription(string memory _applicant_id) 
        public 
        view 
        returns (string[] memory, uint256[] memory) 
    {
        string[] memory types = applicantSubscriptionTypes[_applicant_id];
        uint256[] memory amounts = new uint256[](types.length);

        for (uint256 i = 0; i < types.length; i++) {
            amounts[i] = receipts[_applicant_id][types[i]];
        }
        return (types, amounts);
    }

    // UPDATED: Fetch volume for a specific token address
    function getVolumeForToken(address _token) public view returns (uint256) {
        return volumePerToken[_token];
    }

    function getTotalSubscription() public view returns (uint256) {
        return totalsubscription;
    }

    // --- ADMIN: WITHDRAW & PAUSE ---

    function withdraw(address _tokenAddress, uint256 _amount) public onlyOwner {
        require(_tokenAddress != address(0), "Token address cannot be zero");

        IERC20 token = IERC20(_tokenAddress);
        require(token.balanceOf(address(this)) >= _amount, "Insufficient contract balance");

        token.safeTransfer(msg.sender, _amount);

        emit Withdrawn(_tokenAddress, _amount, msg.sender, block.timestamp);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
}