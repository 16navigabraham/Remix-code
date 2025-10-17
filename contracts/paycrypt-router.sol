// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Interface for Stargate Router (LayerZero)
interface IStargateRouter {
    struct lzTxObj {
        uint256 dstGasForCall;
        uint256 dstNativeAmount;
        bytes dstNativeAddr;
    }
    
    function swap(
        uint16 _dstChainId,
        uint256 _srcPoolId,
        uint256 _dstPoolId,
        address payable _refundAddress,
        uint256 _amountLD,
        uint256 _minAmountLD,
        lzTxObj memory _lzTxParams,
        bytes calldata _to,
        bytes calldata _payload
    ) external payable;
    
    function quoteLayerZeroFee(
        uint16 _dstChainId,
        uint8 _functionType,
        bytes calldata _toAddress,
        bytes calldata _transferAndCallPayload,
        lzTxObj memory _lzTxParams
    ) external view returns (uint256, uint256);
}

// Interface for Squid Router
interface ISquidRouter {
    struct SwapData {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 amountOutMin;
        address to;
        uint256 deadline;
        bytes routeData;
    }
    
    function bridgeCall(
        uint256 destinationChainId,
        SwapData calldata swapData,
        bytes calldata bridgeData,
        bytes calldata callData
    ) external payable;
    
    function getAmountOut(
        uint256 amountIn,
        address tokenIn,
        address tokenOut,
        uint256 chainId
    ) external view returns (uint256);
}

// Interface for existing Paycrypt contract
interface IPaycrypt {
    function createOrder(
        bytes32 requestId,
        address tokenAddress,
        uint256 amount
    ) external;
    
    function isTokenSupported(address tokenAddress) external view returns (bool);
}

/**
 * @title PaycryptRouter
 * @dev Multi-chain router for cross-chain payments to Paycrypt
 * @author Paycrypt Team
 */
contract PaycryptRouter is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    
    // Custom Errors
    error UnsupportedChain();
    error UnsupportedToken();
    error InsufficientBalance();
    error InsufficientAllowance();
    error ZeroAmount();
    error ZeroAddress();
    error SlippageTooHigh();
    error BridgeFailed();
    error InvalidProtocol();
    
    // Enums
    enum BridgeProtocol { 
        STARGATE,    // LayerZero-based
        SQUID,       // Axelar-based
        DIRECT       // Same chain, no bridge needed
    }
    
    // Structs
    struct ChainConfig {
        uint256 chainId;
        uint16 stargateChainId;  // LayerZero chain ID
        uint256 squidChainId;    // Squid chain ID
        address paycryptContract;
        address usdcToken;
        address usdtToken;
        bool isActive;
        BridgeProtocol[] supportedProtocols;
    }
    
    struct BridgeConfig {
        BridgeProtocol protocol;
        address routerAddress;
        uint256 poolId;          // For Stargate
        uint256 gasForCall;      // Gas for destination call
        uint256 nativeForGas;    // Native token for gas
        bool isActive;
    }
    
    struct PaymentRequest {
        bytes32 requestId;
        address user;
        address sourceToken;
        address destinationToken;
        uint256 sourceAmount;
        uint256 destinationAmount;
        uint256 sourceChainId;
        uint256 destinationChainId;
        BridgeProtocol protocol;
        uint256 timestamp;
        bool isProcessed;
    }
    
    // State Variables
    mapping(uint256 => ChainConfig) public chainConfigs;
    mapping(BridgeProtocol => BridgeConfig) public bridgeConfigs;
    mapping(bytes32 => PaymentRequest) public paymentRequests;
    mapping(address => mapping(uint256 => bool)) public supportedTokens; // token => chainId => supported
    
    uint256[] public supportedChains;
    address public feeCollector;
    uint256 public bridgeFeePercent = 25; // 0.25% (in basis points)
    uint256 public constant MAX_SLIPPAGE = 500; // 5%
    
    // Events
    event CrossChainPaymentInitiated(
        bytes32 indexed requestId,
        address indexed user,
        uint256 indexed sourceChainId,
        uint256 destinationChainId,
        address sourceToken,
        address destinationToken,
        uint256 sourceAmount,
        uint256 expectedDestinationAmount,
        BridgeProtocol protocol
    );
    
    event PaymentSettled(
        bytes32 indexed requestId,
        address indexed user,
        uint256 amount,
        string serviceType,
        string status
    );
    
    event ChainConfigUpdated(uint256 indexed chainId, bool status);
    event BridgeConfigUpdated(BridgeProtocol indexed protocol, bool status);
    event TokenSupportUpdated(address indexed token, uint256 indexed chainId, bool status);
    event FeeCollectorUpdated(address indexed oldCollector, address indexed newCollector);
    event BridgeFeeUpdated(uint256 oldFee, uint256 newFee);
    
    // Modifiers
    modifier validChain(uint256 chainId) {
        require(chainConfigs[chainId].isActive, "Unsupported chain");
        _;
    }
    
    modifier validToken(address token, uint256 chainId) {
        require(supportedTokens[token][chainId], "Token not supported");
        _;
    }
    
    modifier validAmount(uint256 amount) {
        require(amount > 0, "Zero amount");
        _;
    }
    
    modifier validAddress(address addr) {
        require(addr != address(0), "Zero address");
        _;
    }
    
    /**
     * @dev Constructor
     */
    constructor(
        address initialOwner,
        address _feeCollector
    ) Ownable(initialOwner) {
        require(_feeCollector != address(0), "Invalid fee collector");
        feeCollector = _feeCollector;
        
        // Initialize Base chain config (destination chain)
        _initializeBaseChain();
    }
    
    /**
     * @dev Initialize Base chain configuration
     */
    function _initializeBaseChain() private {
        uint256 baseChainId = 8453; // Base mainnet
        
        chainConfigs[baseChainId] = ChainConfig({
            chainId: baseChainId,
            stargateChainId: 184,  // Base Stargate ID
            squidChainId: baseChainId,
            paycryptContract: address(0), // To be set after deployment
            usdcToken: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913, // Base USDC
            usdtToken: 0xfde4C96c8593536E31F229EA8f37b2ADa2699bb2, // Base USDT
            isActive: true,
            supportedProtocols: new BridgeProtocol[](1)
        });
        
        chainConfigs[baseChainId].supportedProtocols[0] = BridgeProtocol.DIRECT;
        supportedChains.push(baseChainId);
        
        // Mark Base USDC and USDT as supported
        supportedTokens[chainConfigs[baseChainId].usdcToken][baseChainId] = true;
        supportedTokens[chainConfigs[baseChainId].usdtToken][baseChainId] = true;
    }
    
    // Struct to group payment parameters and reduce stack depth
    struct PaymentParams {
        bytes32 requestId;
        address sourceToken;
        uint256 sourceAmount;
        uint256 destinationChainId;
        address destinationToken;
        uint256 minDestinationAmount;
        BridgeProtocol protocol;
        string serviceType;
    }

    /**
     * @dev Initiate cross-chain payment
     */
    function initiatePayment(
        bytes32 requestId,
        address sourceToken,
        uint256 sourceAmount,
        uint256 destinationChainId,
        address destinationToken,
        uint256 minDestinationAmount,
        BridgeProtocol protocol,
        string calldata serviceType
    ) 
        external 
        payable
        nonReentrant 
        whenNotPaused
        validChain(destinationChainId)
        validToken(sourceToken, block.chainid)
        validToken(destinationToken, destinationChainId)
        validAmount(sourceAmount)
    {
        // Create params struct to reduce stack depth
        PaymentParams memory params = PaymentParams({
            requestId: requestId,
            sourceToken: sourceToken,
            sourceAmount: sourceAmount,
            destinationChainId: destinationChainId,
            destinationToken: destinationToken,
            minDestinationAmount: minDestinationAmount,
            protocol: protocol,
            serviceType: serviceType
        });
        
        // Basic validation
        require(paymentRequests[params.requestId].timestamp == 0, "Request exists");
        require(bridgeConfigs[params.protocol].isActive, "Protocol not supported");
        
        // Process payment
        _processPayment(params);
    }
    
    /**
     * @dev Process payment with reduced stack depth
     */
    function _processPayment(PaymentParams memory params) private {
        // Validate balance and allowance
        IERC20 token = IERC20(params.sourceToken);
        require(token.balanceOf(msg.sender) >= params.sourceAmount, "Insufficient balance");
        require(token.allowance(msg.sender, address(this)) >= params.sourceAmount, "Insufficient allowance");
        
        // Calculate fees
        uint256 bridgeFee = (params.sourceAmount * bridgeFeePercent) / 10000;
        uint256 amountAfterFee = params.sourceAmount - bridgeFee;
        
        // Transfer tokens
        token.safeTransferFrom(msg.sender, address(this), params.sourceAmount);
        if (bridgeFee > 0) {
            token.safeTransfer(feeCollector, bridgeFee);
        }
        
        // Store and execute
        _storeAndExecute(params, amountAfterFee);
    }
    
    /**
     * @dev Store payment request and execute
     */
    function _storeAndExecute(PaymentParams memory params, uint256 amountAfterFee) private {
        // Store payment request
        paymentRequests[params.requestId] = PaymentRequest({
            requestId: params.requestId,
            user: msg.sender,
            sourceToken: params.sourceToken,
            destinationToken: params.destinationToken,
            sourceAmount: params.sourceAmount,
            destinationAmount: params.minDestinationAmount,
            sourceChainId: block.chainid,
            destinationChainId: params.destinationChainId,
            protocol: params.protocol,
            timestamp: block.timestamp,
            isProcessed: false
        });
        
        // Execute payment
        if (block.chainid == params.destinationChainId) {
            _executeDirectPayment(params.requestId, params.destinationToken, amountAfterFee, params.serviceType);
        } else {
            _executeBridge(params.requestId, params.sourceToken, amountAfterFee, params.protocol, params.destinationChainId, params.minDestinationAmount);
        }
        
        // Emit event
        emit CrossChainPaymentInitiated(
            params.requestId,
            msg.sender,
            block.chainid,
            params.destinationChainId,
            params.sourceToken,
            params.destinationToken,
            params.sourceAmount,
            params.minDestinationAmount,
            params.protocol
        );
    }
    
    /**
     * @dev Safe approval helper function that handles tokens with non-standard approve behavior
     */
    function _safeApprove(IERC20 token, address spender, uint256 amount) private {
        uint256 currentAllowance = token.allowance(address(this), spender);
        if (currentAllowance != 0) {
            // Reset allowance to 0 first for tokens that require it
            require(token.approve(spender, 0), "Approve reset failed");
        }
        require(token.approve(spender, amount), "Approve failed");
    }

    /**
     * @dev Execute direct payment on same chain
     */
    function _executeDirectPayment(
        bytes32 requestId,
        address tokenAddress,
        uint256 amount,
        string calldata serviceType
    ) private {
        ChainConfig memory config = chainConfigs[block.chainid];
        
        // Safe approval and create order in Paycrypt contract
        IERC20 token = IERC20(tokenAddress);
        _safeApprove(token, config.paycryptContract, amount);
        IPaycrypt(config.paycryptContract).createOrder(requestId, tokenAddress, amount);
        
        paymentRequests[requestId].isProcessed = true;
        
        emit PaymentSettled(requestId, msg.sender, amount, serviceType, "Settled");
    }
    
    // Struct for bridge parameters to reduce stack depth
    struct BridgeParams {
        bytes32 requestId;
        address sourceToken;
        address destinationToken;
        uint256 amount;
        uint256 destinationChainId;
        uint256 minAmount;
    }

    /**
     * @dev Execute cross-chain bridge
     */
    function _executeBridge(
        bytes32 requestId,
        address sourceToken,
        uint256 amount,
        BridgeProtocol protocol,
        uint256 destinationChainId,
        uint256 minAmount
    ) private {
        if (protocol == BridgeProtocol.STARGATE) {
            _executeStargateBridge(requestId, sourceToken, amount, destinationChainId, minAmount);
        } else if (protocol == BridgeProtocol.SQUID) {
            ChainConfig storage destConfig = chainConfigs[destinationChainId];
            BridgeParams memory params = BridgeParams({
                requestId: requestId,
                sourceToken: sourceToken,
                destinationToken: destConfig.usdcToken,
                amount: amount,
                destinationChainId: destinationChainId,
                minAmount: minAmount
            });
            _executeSquidBridge(params);
        } else {
            revert InvalidProtocol();
        }
    }
    
    /**
     * @dev Execute Stargate bridge
     */
    function _executeStargateBridge(
        bytes32 requestId,
        address sourceToken,
        uint256 amount,
        uint256 destinationChainId,
        uint256 minAmount
    ) private {
        BridgeConfig storage bridgeConfig = bridgeConfigs[BridgeProtocol.STARGATE];
        ChainConfig storage destConfig = chainConfigs[destinationChainId];
        
        // Safe approval for router
        IERC20 token = IERC20(sourceToken);
        _safeApprove(token, bridgeConfig.routerAddress, amount);
        
        // Execute bridge with minimal local variables
        IStargateRouter(bridgeConfig.routerAddress).swap{value: msg.value}(
            destConfig.stargateChainId,
            bridgeConfig.poolId,
            bridgeConfig.poolId,
            payable(msg.sender),
            amount,
            minAmount,
            IStargateRouter.lzTxObj({
                dstGasForCall: bridgeConfig.gasForCall,
                dstNativeAmount: bridgeConfig.nativeForGas,
                dstNativeAddr: abi.encodePacked(msg.sender)
            }),
            abi.encodePacked(destConfig.paycryptContract),
            abi.encode(requestId, msg.sender, minAmount)
        );
    }
    
    /**
     * @dev Execute Squid bridge
     */
    function _executeSquidBridge(BridgeParams memory params) private {
        BridgeConfig storage bridgeConfig = bridgeConfigs[BridgeProtocol.SQUID];
        ChainConfig storage destConfig = chainConfigs[params.destinationChainId];
        
        // Safe approval for router
        IERC20 token = IERC20(params.sourceToken);
        _safeApprove(token, bridgeConfig.routerAddress, params.amount);
        
        // Execute bridge
        ISquidRouter(bridgeConfig.routerAddress).bridgeCall{value: msg.value}(
            params.destinationChainId,
            ISquidRouter.SwapData({
                tokenIn: params.sourceToken,
                tokenOut: params.destinationToken,
                amountIn: params.amount,
                amountOutMin: params.minAmount,
                to: destConfig.paycryptContract,
                deadline: block.timestamp + 1800,
                routeData: bytes("")
            }),
            bytes(""),
            abi.encodeWithSelector(
                IPaycrypt.createOrder.selector,
                params.requestId,
                params.destinationToken,
                params.minAmount
            )
        );
    }
    
    /**
     * @dev Handle cross-chain message (called by bridge)
     */
    function sgReceive(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint256 _nonce,
        address _token,
        uint256 amountLD,
        bytes memory payload
    ) external {
        require(msg.sender == bridgeConfigs[BridgeProtocol.STARGATE].routerAddress, "Invalid caller");
        
        // Decode payload
        (bytes32 requestId, address user, uint256 minAmount) = abi.decode(payload, (bytes32, address, uint256));
        
        // Safe approval and create order in Paycrypt
        IERC20 token = IERC20(_token);
        _safeApprove(token, chainConfigs[block.chainid].paycryptContract, amountLD);
        IPaycrypt(chainConfigs[block.chainid].paycryptContract).createOrder(requestId, _token, amountLD);
        
        // Mark as processed
        paymentRequests[requestId].isProcessed = true;
        
        emit PaymentSettled(requestId, user, amountLD, "CrossChain", "Settled");
    }
    
    // Admin Functions
    
    /**
     * @dev Add/update chain configuration
     */
    function setChainConfig(
        uint256 chainId,
        uint16 stargateChainId,
        uint256 squidChainId,
        address paycryptContract,
        address usdcToken,
        address usdtToken,
        bool isActive
    ) external onlyOwner {
        ChainConfig storage config = chainConfigs[chainId];
        
        if (config.chainId == 0) {
            supportedChains.push(chainId);
        }
        
        config.chainId = chainId;
        config.stargateChainId = stargateChainId;
        config.squidChainId = squidChainId;
        config.paycryptContract = paycryptContract;
        config.usdcToken = usdcToken;
        config.usdtToken = usdtToken;
        config.isActive = isActive;
        
        emit ChainConfigUpdated(chainId, isActive);
    }
    
    /**
     * @dev Set bridge configuration
     */
    function setBridgeConfig(
        BridgeProtocol protocol,
        address routerAddress,
        uint256 poolId,
        uint256 gasForCall,
        uint256 nativeForGas,
        bool isActive
    ) external onlyOwner {
        bridgeConfigs[protocol] = BridgeConfig({
            protocol: protocol,
            routerAddress: routerAddress,
            poolId: poolId,
            gasForCall: gasForCall,
            nativeForGas: nativeForGas,
            isActive: isActive
        });
        
        emit BridgeConfigUpdated(protocol, isActive);
    }
    
    /**
     * @dev Set token support for chain
     */
    function setTokenSupport(
        address token,
        uint256 chainId,
        bool supported
    ) external onlyOwner {
        supportedTokens[token][chainId] = supported;
        emit TokenSupportUpdated(token, chainId, supported);
    }
    
    /**
     * @dev Update bridge fee
     */
    function setBridgeFee(uint256 newFeePercent) external onlyOwner {
        require(newFeePercent <= 100, "Fee too high"); // Max 1%
        uint256 oldFee = bridgeFeePercent;
        bridgeFeePercent = newFeePercent;
        emit BridgeFeeUpdated(oldFee, newFeePercent);
    }
    
    /**
     * @dev Update fee collector
     */
    function setFeeCollector(address newCollector) external onlyOwner validAddress(newCollector) {
        address oldCollector = feeCollector;
        feeCollector = newCollector;
        emit FeeCollectorUpdated(oldCollector, newCollector);
    }
    
    /**
     * @dev Emergency withdraw
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        if (token == address(0)) {
            payable(owner()).transfer(amount);
        } else {
            IERC20(token).safeTransfer(owner(), amount);
        }
    }
    
    /**
     * @dev Pause contract
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @dev Unpause contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }
    
    // View Functions
    
    /**
     * @dev Get quote for cross-chain payment
     */
    function getQuote(
        address sourceToken,
        uint256 sourceAmount,
        uint256 destinationChainId,
        address destinationToken,
        BridgeProtocol protocol
    ) external view returns (uint256 destinationAmount, uint256 fee) {
        uint256 bridgeFee = (sourceAmount * bridgeFeePercent) / 10000;
        uint256 amountAfterFee = sourceAmount - bridgeFee;
        
        if (block.chainid == destinationChainId) {
            // Same chain - no bridge fee
            return (amountAfterFee, 0);
        }
        
        // For cross-chain, return estimated amount minus bridge protocol fees
        // This is a simplified calculation - in production, you'd call the actual bridge protocol
        uint256 estimatedAmount = (amountAfterFee * 995) / 1000; // Assume 0.5% bridge fee
        
        return (estimatedAmount, bridgeFee);
    }
    
    /**
     * @dev Check if token is supported on chain
     */
    function isTokenSupported(address token, uint256 chainId) external view returns (bool) {
        return supportedTokens[token][chainId];
    }
    
    /**
     * @dev Get supported chains
     */
    function getSupportedChains() external view returns (uint256[] memory) {
        return supportedChains;
    }
    
    /**
     * @dev Get payment request
     */
    function getPaymentRequest(bytes32 requestId) external view returns (PaymentRequest memory) {
        return paymentRequests[requestId];
    }
    
    receive() external payable {}
}