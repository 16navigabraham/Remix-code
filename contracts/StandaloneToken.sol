// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

/**
 * @title CustomToken
 * @dev ERC20 token with additional features for factory deployment
 * @author YourName
 */
contract CustomToken is ERC20, ERC20Burnable, Ownable, Pausable {
    uint8 private _decimals;
    uint256 public maxSupply;
    bool public mintingFinished;
    
    mapping(address => bool) public minters;
    
    event MinterAdded(address indexed minter);
    event MinterRemoved(address indexed minter);
    event MintingFinished();
    
    modifier onlyMinter() {
        require(minters[msg.sender] || msg.sender == owner(), "Not authorized to mint");
        _;
    }
    
    modifier canMint() {
        require(!mintingFinished, "Minting is finished");
        _;
    }
    
    /**
     * @dev Constructor for CustomToken
     * @param name Token name
     * @param symbol Token symbol
     * @param decimals_ Number of decimals
     * @param initialSupply Initial token supply (in tokens, not wei)
     * @param maxSupply_ Maximum token supply (in tokens, not wei)
     * @param owner_ Token owner address
     */
    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals_,
        uint256 initialSupply,
        uint256 maxSupply_,
        address owner_
    ) ERC20(name, symbol) Ownable(owner_) {
        _decimals = decimals_;
        maxSupply = maxSupply_ * 10**decimals_;
        
        if (initialSupply > 0) {
            _mint(owner_, initialSupply * 10**decimals_);
        }
        
        minters[owner_] = true;
    }
    
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
    
    /**
     * @dev Mint tokens to specified address
     * @param to Address to mint tokens to
     * @param amount Amount of tokens to mint (in wei)
     */
    function mint(address to, uint256 amount) public onlyMinter canMint whenNotPaused {
        require(to != address(0), "Cannot mint to zero address");
        require(totalSupply() + amount <= maxSupply, "Would exceed max supply");
        
        _mint(to, amount);
    }
    
    /**
     * @dev Batch mint tokens to multiple addresses
     * @param recipients Array of recipient addresses
     * @param amounts Array of amounts to mint (in wei)
     */
    function batchMint(address[] memory recipients, uint256[] memory amounts) 
        external onlyMinter canMint whenNotPaused 
    {
        require(recipients.length == amounts.length, "Arrays length mismatch");
        require(recipients.length <= 100, "Too many recipients");
        
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }
        
        require(totalSupply() + totalAmount <= maxSupply, "Would exceed max supply");
        
        for (uint256 i = 0; i < recipients.length; i++) {
            require(recipients[i] != address(0), "Cannot mint to zero address");
            _mint(recipients[i], amounts[i]);
        }
    }
    
    /**
     * @dev Add minter role to address
     * @param minter Address to add as minter
     */
    function addMinter(address minter) external onlyOwner {
        require(minter != address(0), "Cannot add zero address as minter");
        minters[minter] = true;
        emit MinterAdded(minter);
    }
    
    /**
     * @dev Remove minter role from address
     * @param minter Address to remove from minters
     */
    function removeMinter(address minter) external onlyOwner {
        minters[minter] = false;
        emit MinterRemoved(minter);
    }
    
    /**
     * @dev Finish minting permanently - cannot be undone
     */
    function finishMinting() external onlyOwner {
        mintingFinished = true;
        emit MintingFinished();
    }
    
    /**
     * @dev Pause token transfers
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @dev Unpause token transfers
     */
    function unpause() external onlyOwner {
        _unpause();
    }
    
    /**
     * @dev Get remaining mintable supply
     */
    function remainingSupply() external view returns (uint256) {
        return maxSupply - totalSupply();
    }
    
    /**
     * @dev Check if address has minter role
     */
    function isMinter(address account) external view returns (bool) {
        return minters[account] || account == owner();
    }
    
    /**
     * @dev Override _update to add pause functionality
     */
    function _update(
        address from,
        address to,
        uint256 value
    ) internal override whenNotPaused {
        super._update(from, to, value);
    }
}