// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol"; 

contract BaseflowTask is Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    using SafeERC20 for IERC20; // Safer transfers
    Counters.Counter private _taskIds;

    // 1. DUAL TOKEN SETUP
    IERC20 public token1; // e.g., USDC
    IERC20 public token2; // e.g., connect

    struct Task {
        uint256 id;
        string title;
        string description;
        address creator;
        address assignee;
        uint256 reward;      
        address rewardToken;  // <--- NEW: Tracks which token is used for this task
        uint256 deadline;
        TaskStatus status;
        bool exists;
    }

    enum TaskStatus {
        OPEN,         
        IN_PROGRESS,  
        COMPLETED,
        CANCELLED
    }

    mapping(uint256 => Task) public tasks;
    mapping(address => uint256[]) public userTasks;

    // Events
    event TaskCreated(uint256 indexed taskId, string title, address indexed creator);
    event ContributorHired(uint256 indexed taskId, address indexed assignee, uint256 reward, address token);
    event TaskCompleted(uint256 indexed taskId, address indexed assignee, uint256 reward, address token);
    event TaskCancelled(uint256 indexed taskId);
    event TokenUpdated(string slot, address oldToken, address newToken);

    address public platformFeeRecipient;

    constructor(address _token1, address _token2, address _platformFeeRecipient) Ownable(msg.sender) { 
        require(_token1 != address(0), "Token1 cannot be zero");
        token1 = IERC20(_token1);
        token2 = IERC20(_token2); // Can be added to the contract later
        platformFeeRecipient = _platformFeeRecipient;
    }

    // --- ADMIN: MANAGE TOKENS ---
    function updateToken1(address _newToken) external onlyOwner {
        emit TokenUpdated("Token1", address(token1), _newToken);
        token1 = IERC20(_newToken);
    }

    function updateToken2(address _newToken) external onlyOwner {
        emit TokenUpdated("Token2", address(token2), _newToken);
        token2 = IERC20(_newToken);
    }

    // --- TASK LOGIC ---

    function createTask(
        string memory title,
        string memory description,
        uint256 deadline
    ) external returns (uint256) {
        require(deadline > block.timestamp, "Deadline must be in future");

        _taskIds.increment();
        uint256 taskId = _taskIds.current();

        tasks[taskId] = Task({
            id: taskId,
            title: title,
            description: description,
            creator: msg.sender,
            assignee: address(0),
            reward: 0,
            rewardToken: address(0), // No token set until hiring
            deadline: deadline,
            status: TaskStatus.OPEN,
            exists: true
        });

        userTasks[msg.sender].push(taskId);
        emit TaskCreated(taskId, title, msg.sender);

        return taskId;
    }

    /**
     * @notice Hire a contributor: Select Token -> Escrow Funds -> Assign
     */
    function hireContributor(
        uint256 taskId,
        address contributor,
        uint256 reward,
        address _paymentToken // <--- Creator chooses the token here
    ) external nonReentrant {
        require(contributor != address(0), "Invalid contributor");
        require(reward > 0, "Reward must be > 0");

        // VALIDATE TOKEN
        bool isToken1 = (_paymentToken == address(token1) && address(token1) != address(0));
        bool isToken2 = (_paymentToken == address(token2) && address(token2) != address(0));
        require(isToken1 || isToken2, "Token not supported");

        Task storage task = tasks[taskId];
        require(task.exists, "Task does not exist");
        require(task.creator == msg.sender, "Only creator can hire");
        require(task.status == TaskStatus.OPEN, "Task not open");
        require(task.assignee == address(0), "Already assigned");

        // ESCROW FUNDS (Pull from Creator -> Contract)
        IERC20(_paymentToken).safeTransferFrom(msg.sender, address(this), reward);

        // UPDATE TASK STATE
        task.assignee = contributor;
        task.reward = reward;
        task.rewardToken = _paymentToken; // Save the token choice!
        task.status = TaskStatus.IN_PROGRESS;

        userTasks[contributor].push(taskId);

        emit ContributorHired(taskId, contributor, reward, _paymentToken);
    }

    function completeTask(uint256 taskId, address contributor) external nonReentrant {
        Task storage task = tasks[taskId];
        require(task.exists, "Task does not exist");
        require(task.status == TaskStatus.IN_PROGRESS, "Task not in progress");
        require(task.creator == msg.sender, "Only creator can complete");
        require(task.assignee == contributor, "Invalid contributor");

        uint256 totalReward = task.reward;
        address tokenAddress = task.rewardToken; // Retrieve the stored token
        
        require(totalReward > 0, "No reward set");
        require(tokenAddress != address(0), "Invalid token state");

        // FEE CALCULATION
        uint256 platformFee = (totalReward * 10) / 100; // 10%
        uint256 contributorReward = totalReward - platformFee;

        task.status = TaskStatus.COMPLETED;

        // PAYOUT
        IERC20 token = IERC20(tokenAddress);
        token.safeTransfer(contributor, contributorReward);
        token.safeTransfer(platformFeeRecipient, platformFee);

        emit TaskCompleted(taskId, contributor, contributorReward, tokenAddress);
    }

    function cancelTask(uint256 taskId) external nonReentrant {
        Task storage task = tasks[taskId];
        require(task.exists, "Task does not exist");
        require(task.creator == msg.sender, "Not creator");
        require(task.status == TaskStatus.OPEN, "Cannot cancel assigned task");

        task.status = TaskStatus.CANCELLED;
        emit TaskCancelled(taskId);
    }

    // --- VIEW FUNCTIONS ---
    function getTask(uint256 taskId) external view returns (Task memory) {
        require(tasks[taskId].exists, "Task does not exist");
        return tasks[taskId];
    }

    function getUserTasks(address user) external view returns (uint256[] memory) {
        return userTasks[user];
    }

    // --- WITHDRAWAL (Admin) ---
    // NOTE: withdrawFees needs to know WHICH token to withdraw now
    function withdrawFees(address _tokenAddress, uint256 amount) external onlyOwner {
        IERC20(_tokenAddress).safeTransfer(owner(), amount);
    }

    // Careful: This drains EVERYTHING (including user escrows). 
    // Only use in emergency or if you track fees separately.
    function emergencyWithdraw(address _tokenAddress) external onlyOwner {
        uint256 balance = IERC20(_tokenAddress).balanceOf(address(this));
        IERC20(_tokenAddress).safeTransfer(owner(), balance);
    }
}