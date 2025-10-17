// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title CryptoQuest Rewards Contract
 * @dev Allows quiz platform to distribute ERC20 token rewards to users
 */
contract CryptoQuestRewards is Ownable, ReentrancyGuard, Pausable {
    
    // The ERC20 token used for rewards
    IERC20 public rewardToken;
    
    // Quiz difficulty levels and their base rewards
    enum DifficultyLevel { 
        BEGINNER,     // 50 tokens
        INTERMEDIATE, // 150 tokens  
        ADVANCED,     // 300 tokens
        EXPERT,       // 500 tokens
        MASTER        // 1000 tokens
    }
    
    // Base reward amounts for each difficulty (in token's smallest unit)
    mapping(DifficultyLevel => uint256) public baseRewards;
    
    // Track user claims to prevent double claiming
    mapping(address => mapping(bytes32 => bool)) public hasClaimed;
    
    // Track total rewards distributed
    uint256 public totalRewardsDistributed;
    
    // Track individual user rewards
    mapping(address => uint256) public userTotalRewards;
    
    // ============ NEW WHITELIST FUNCTIONALITY ============
    // Mapping to track whitelisted addresses
    mapping(address => bool) public whitelist;
    
    // Flag to enable/disable whitelist requirement
    bool public whitelistEnabled = false;
    
    // Events
    event RewardClaimed(
        address indexed user, 
        bytes32 indexed quizId, 
        DifficultyLevel difficulty, 
        uint256 amount, 
        uint256 multiplier
    );
    
    event TokensDeposited(address indexed depositor, uint256 amount);
    event TokensWithdrawn(address indexed owner, uint256 amount);
    event BaseRewardsUpdated(DifficultyLevel difficulty, uint256 newAmount);
    
    // New whitelist events
    event AddressWhitelisted(address indexed user);
    event AddressRemovedFromWhitelist(address indexed user);
    event WhitelistStatusChanged(bool enabled);
    
    /**
     * @dev Constructor - Fixed for OpenZeppelin v5.x
     * @param _rewardToken Address of the ERC20 token to use for rewards
     * @param initialOwner Address that will own the contract
     */
    constructor(address _rewardToken, address initialOwner) Ownable(initialOwner) {
        require(_rewardToken != address(0), "Invalid token address");
        require(initialOwner != address(0), "Invalid owner address");
        
        rewardToken = IERC20(_rewardToken);
        
        // Set initial base rewards (assuming 18 decimal token)
        baseRewards[DifficultyLevel.BEGINNER] = 50 * 10**18;      // 50 tokens
        baseRewards[DifficultyLevel.INTERMEDIATE] = 150 * 10**18; // 150 tokens
        baseRewards[DifficultyLevel.ADVANCED] = 300 * 10**18;     // 300 tokens
        baseRewards[DifficultyLevel.EXPERT] = 500 * 10**18;       // 500 tokens
        baseRewards[DifficultyLevel.MASTER] = 1000 * 10**18;      // 1000 tokens
    }
    
    /**
     * @dev Modifier to check if address is whitelisted (when whitelist is enabled)
     */
    modifier onlyWhitelisted() {
        if (whitelistEnabled) {
            require(whitelist[msg.sender], "Address not whitelisted");
        }
        _;
    }
    
    /**
     * @dev Allows owner to deposit reward tokens into the contract
     * @param amount Amount of tokens to deposit
     */
    function depositRewardTokens(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than 0");
        
        bool success = rewardToken.transferFrom(msg.sender, address(this), amount);
        require(success, "Token transfer failed");
        
        emit TokensDeposited(msg.sender, amount);
    }
    
    /**
     * @dev Main function for users to claim quiz rewards
     * @param quizId Unique identifier for the completed quiz
     * @param difficulty The difficulty level of the completed quiz
     * @param score User's score (0-100)
     * @param multiplier Bonus multiplier (100 = 1x, 150 = 1.5x, 200 = 2x, etc.)
     */
    function claimReward(
        bytes32 quizId,
        DifficultyLevel difficulty,
        uint256 score,
        uint256 multiplier
    ) external nonReentrant whenNotPaused onlyWhitelisted {
        require(quizId != bytes32(0), "Invalid quiz ID");
        require(score >= 70, "Minimum score of 70% required");
        require(multiplier >= 100 && multiplier <= 300, "Invalid multiplier");
        require(!hasClaimed[msg.sender][quizId], "Reward already claimed");
        
        // Calculate reward amount
        uint256 baseAmount = baseRewards[difficulty];
        uint256 rewardAmount = (baseAmount * multiplier) / 100;
        
        // Check contract has enough tokens
        require(
            rewardToken.balanceOf(address(this)) >= rewardAmount, 
            "Insufficient contract balance"
        );
        
        // Mark as claimed
        hasClaimed[msg.sender][quizId] = true;
        
        // Update tracking
        totalRewardsDistributed += rewardAmount;
        userTotalRewards[msg.sender] += rewardAmount;
        
        // Transfer reward tokens
        bool success = rewardToken.transfer(msg.sender, rewardAmount);
        require(success, "Reward transfer failed");
        
        emit RewardClaimed(msg.sender, quizId, difficulty, rewardAmount, multiplier);
    }
    
    /**
     * @dev Batch claim multiple rewards (gas optimization)
     * @param quizIds Array of quiz IDs
     * @param difficulties Array of difficulty levels
     * @param scores Array of scores
     * @param multipliers Array of multipliers
     */
    function claimMultipleRewards(
        bytes32[] calldata quizIds,
        DifficultyLevel[] calldata difficulties,
        uint256[] calldata scores,
        uint256[] calldata multipliers
    ) external nonReentrant whenNotPaused onlyWhitelisted {
        require(quizIds.length == difficulties.length, "Array length mismatch");
        require(quizIds.length == scores.length, "Array length mismatch");
        require(quizIds.length == multipliers.length, "Array length mismatch");
        require(quizIds.length <= 10, "Too many claims at once");
        
        uint256 totalReward = 0;
        
        for (uint256 i = 0; i < quizIds.length; i++) {
            bytes32 quizId = quizIds[i];
            
            require(quizId != bytes32(0), "Invalid quiz ID");
            require(scores[i] >= 70, "Minimum score of 70% required");
            require(multipliers[i] >= 100 && multipliers[i] <= 300, "Invalid multiplier");
            require(!hasClaimed[msg.sender][quizId], "Reward already claimed");
            
            // Calculate reward
            uint256 baseAmount = baseRewards[difficulties[i]];
            uint256 rewardAmount = (baseAmount * multipliers[i]) / 100;
            
            // Mark as claimed
            hasClaimed[msg.sender][quizId] = true;
            totalReward += rewardAmount;
            
            emit RewardClaimed(msg.sender, quizId, difficulties[i], rewardAmount, multipliers[i]);
        }
        
        // Check contract has enough tokens
        require(
            rewardToken.balanceOf(address(this)) >= totalReward, 
            "Insufficient contract balance"
        );
        
        // Update tracking
        totalRewardsDistributed += totalReward;
        userTotalRewards[msg.sender] += totalReward;
        
        // Transfer total reward
        bool success = rewardToken.transfer(msg.sender, totalReward);
        require(success, "Reward transfer failed");
    }
    
    // ============ NEW WHITELIST FUNCTIONS ============
    
    /**
     * @dev Add an address to the whitelist (only owner)
     * @param user Address to whitelist
     */
    function whitelistAddress(address user) external onlyOwner {
        require(user != address(0), "Invalid address");
        require(!whitelist[user], "Address already whitelisted");
        
        whitelist[user] = true;
        emit AddressWhitelisted(user);
    }
    
    /**
     * @dev Check if an address is whitelisted
     * @param user Address to check
     * @return bool True if address is whitelisted or whitelist is disabled
     */
    function isWhitelisted(address user) external view returns (bool) {
        if (!whitelistEnabled) {
            return true; // If whitelist is disabled, everyone is considered whitelisted
        }
        return whitelist[user];
    }
    
    /**
     * @dev Remove an address from the whitelist (only owner)
     * @param user Address to remove from whitelist
     */
    function removeFromWhitelist(address user) external onlyOwner {
        require(user != address(0), "Invalid address");
        require(whitelist[user], "Address not whitelisted");
        
        whitelist[user] = false;
        emit AddressRemovedFromWhitelist(user);
    }
    
    /**
     * @dev Enable or disable whitelist requirement (only owner)
     * @param enabled True to enable whitelist, false to disable
     */
    function setWhitelistEnabled(bool enabled) external onlyOwner {
        whitelistEnabled = enabled;
        emit WhitelistStatusChanged(enabled);
    }
    
    /**
     * @dev Batch whitelist multiple addresses (gas optimization)
     * @param users Array of addresses to whitelist
     */
    function batchWhitelistAddresses(address[] calldata users) external onlyOwner {
        require(users.length <= 50, "Too many addresses at once");
        
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            require(user != address(0), "Invalid address in batch");
            
            if (!whitelist[user]) {
                whitelist[user] = true;
                emit AddressWhitelisted(user);
            }
        }
    }
    
    // ============ EXISTING VIEW FUNCTIONS ============
    
    /**
     * @dev Check if a user has claimed reward for a specific quiz
     */
    function hasUserClaimed(address user, bytes32 quizId) external view returns (bool) {
        return hasClaimed[user][quizId];
    }
    
    /**
     * @dev Get the reward amount for a difficulty level with multiplier
     */
    function calculateReward(DifficultyLevel difficulty, uint256 multiplier) 
        external 
        view 
        returns (uint256) 
    {
        require(multiplier >= 100 && multiplier <= 300, "Invalid multiplier");
        return (baseRewards[difficulty] * multiplier) / 100;
    }
    
    /**
     * @dev Get contract's token balance
     */
    function getContractBalance() external view returns (uint256) {
        return rewardToken.balanceOf(address(this));
    }
    
    // ============ ADMIN FUNCTIONS ============
    
    /**
     * @dev Update base reward for a difficulty level
     */
    function updateBaseReward(DifficultyLevel difficulty, uint256 newAmount) 
        external 
        onlyOwner 
    {
        require(newAmount > 0, "Amount must be greater than 0");
        baseRewards[difficulty] = newAmount;
        emit BaseRewardsUpdated(difficulty, newAmount);
    }
    
    /**
     * @dev Emergency withdrawal of tokens (only owner)
     */
    function emergencyWithdraw(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than 0");
        require(
            rewardToken.balanceOf(address(this)) >= amount, 
            "Insufficient balance"
        );
        
        bool success = rewardToken.transfer(owner(), amount);
        require(success, "Withdrawal failed");
        
        emit TokensWithdrawn(owner(), amount);
    }
    
    /**
     * @dev Pause the contract (emergency use)
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @dev Unpause the contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }
    
    /**
     * @dev Update the reward token address (emergency use)
     */
    function updateRewardToken(address newToken) external onlyOwner {
        require(newToken != address(0), "Invalid token address");
        rewardToken = IERC20(newToken);
    }
}