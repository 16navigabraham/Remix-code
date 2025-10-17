
// File: @openzeppelin/contracts/token/ERC20/IERC20.sol


// OpenZeppelin Contracts (last updated v5.4.0) (token/ERC20/IERC20.sol)
// SPDX-License-Identifier: MIT
pragma solidity >=0.4.16;

/**
 * @dev Interface of the ERC-20 standard as defined in the ERC.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

// File: @openzeppelin/contracts/utils/Context.sol


// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

pragma solidity ^0.8.20;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

// File: @openzeppelin/contracts/access/Ownable.sol


// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable.sol)

pragma solidity ^0.8.20;


/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * The initial owner is set to the address provided by the deployer. This can
 * later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error OwnableUnauthorizedAccount(address account);

    /**
     * @dev The owner is not a valid owner account. (eg. `address(0)`)
     */
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the address provided by the deployer as the initial owner.
     */
    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// File: @openzeppelin/contracts/utils/ReentrancyGuard.sol


// OpenZeppelin Contracts (last updated v5.1.0) (utils/ReentrancyGuard.sol)

pragma solidity ^0.8.20;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If EIP-1153 (transient storage) is available on the chain you're deploying at,
 * consider using {ReentrancyGuardTransient} instead.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    uint256 private _status;

    /**
     * @dev Unauthorized reentrant call.
     */
    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be NOT_ENTERED
        if (_status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }

        // Any calls to nonReentrant after this point will fail
        _status = ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == ENTERED;
    }
}

// File: @openzeppelin/contracts/utils/Pausable.sol


// OpenZeppelin Contracts (last updated v5.3.0) (utils/Pausable.sol)

pragma solidity ^0.8.20;


/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
    bool private _paused;

    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    /**
     * @dev The operation failed because the contract is paused.
     */
    error EnforcedPause();

    /**
     * @dev The operation failed because the contract is not paused.
     */
    error ExpectedPause();

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        _requirePaused();
        _;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Throws if the contract is paused.
     */
    function _requireNotPaused() internal view virtual {
        if (paused()) {
            revert EnforcedPause();
        }
    }

    /**
     * @dev Throws if the contract is not paused.
     */
    function _requirePaused() internal view virtual {
        if (!paused()) {
            revert ExpectedPause();
        }
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

// File: pratice/rewards.sol


pragma solidity ^0.8.19;





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