// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./StandaloneToken.sol";

/**
 * @title SimpleTokenFactory
 * @dev Easy-to-use factory for creating custom ERC20 tokens
 */
contract SimpleTokenFactory {
    
    // Simple struct to track created tokens
    struct Token {
        address tokenAddress;
        string name;
        string symbol;
        address creator;
        uint256 createdAt;
    }
    
    // Store all created tokens
    Token[] public allTokens;
    
    // Track tokens by creator
    mapping(address => address[]) public myTokens;
    
    // Events
    event TokenCreated(
        address indexed tokenAddress,
        address indexed creator,
        string name,
        string symbol
    );
    
    /**
     * @dev Create a new token - SIMPLIFIED VERSION
     * @param name Token name (e.g., "My Coin")
     * @param symbol Token symbol (e.g., "MYC")
     * @param supply How many tokens to create
     * @return tokenAddress Address of your new token
     */
    function createToken(
        string memory name,
        string memory symbol,
        uint256 supply
    ) external returns (address tokenAddress) {
        
        // Basic validation
        require(bytes(name).length > 0, "Name cannot be empty");
        require(bytes(symbol).length > 0, "Symbol cannot be empty");
        require(supply > 0, "Supply must be greater than 0");
        
        // Create the token with standard settings
        CustomToken newToken = new CustomToken(
            name,           // Token name
            symbol,         // Token symbol  
            18,             // Standard 18 decimals
            supply,         // Initial supply
            supply * 2,     // Max supply (2x initial for future minting)
            msg.sender      // You own the token
        );
        
        tokenAddress = address(newToken);
        
        // Store the token info
        Token memory newTokenInfo = Token({
            tokenAddress: tokenAddress,
            name: name,
            symbol: symbol,
            creator: msg.sender,
            createdAt: block.timestamp
        });
        
        allTokens.push(newTokenInfo);
        myTokens[msg.sender].push(tokenAddress);
        
        emit TokenCreated(tokenAddress, msg.sender, name, symbol);
        
        return tokenAddress;
    }
    
    /**
     * @dev Get all tokens you created
     * @return Array of your token addresses
     */
    function getMyTokens() external view returns (address[] memory) {
        return myTokens[msg.sender];
    }
    
    /**
     * @dev Get total number of tokens created by everyone
     */
    function getTotalTokens() external view returns (uint256) {
        return allTokens.length;
    }
    
    /**
     * @dev Get info about any token by its index
     * @param index Token index (0 to getTotalTokens()-1)
     */
    function getTokenByIndex(uint256 index) external view returns (
        address tokenAddress,
        string memory name,
        string memory symbol,
        address creator,
        uint256 createdAt
    ) {
        require(index < allTokens.length, "Token doesn't exist");
        Token memory token = allTokens[index];
        return (
            token.tokenAddress,
            token.name,
            token.symbol,
            token.creator,
            token.createdAt
        );
    }
    
    /**
     * @dev Get the latest tokens created (up to 10)
     */
    function getLatestTokens() external view returns (Token[] memory) {
        uint256 totalTokens = allTokens.length;
        uint256 returnCount = totalTokens > 10 ? 10 : totalTokens;
        
        Token[] memory latestTokens = new Token[](returnCount);
        
        for (uint256 i = 0; i < returnCount; i++) {
            latestTokens[i] = allTokens[totalTokens - 1 - i];
        }
        
        return latestTokens;
    }
}