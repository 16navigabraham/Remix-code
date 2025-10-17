// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title MemeVibeNFT
 * @dev An NFT collection contract with free and paid minting options
 */
contract MemeVibeNFT is ERC721, ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;
    uint256 public mintPrice;
    string private _baseTokenURI;

    /**
     * @dev Emitted when a token is minted
     * @param minter Address of the minter
     * @param tokenId ID of the minted token
     * @param tokenURI URI of the minted token
     */
    event TokenMinted(address indexed minter, uint256 indexed tokenId, string tokenURI);

    /**
     * @dev Constructor initializes the contract with name and symbol
     */
    constructor() ERC721("MemeVibeNFT", "MVNFT") Ownable() {
        mintPrice = 0;
    }

    /**
     * @dev Mints a new token to the caller for free
     * @param tokenURI The URI for the token metadata
     * @return tokenId The ID of the newly minted token
     */
    function mintToken(string memory tokenURI) public returns (uint256) {
        require(bytes(tokenURI).length > 0, "Token URI cannot be empty");
        
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        
        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, tokenURI);
        
        emit TokenMinted(msg.sender, tokenId, tokenURI);
        return tokenId;
    }

    /**
     * @dev Mints a new token to the caller for the set mint price
     * @param tokenURI The URI for the token metadata
     * @return tokenId The ID of the newly minted token
     */
    function mintTokenPayable(string memory tokenURI) public payable returns (uint256) {
        require(msg.value >= mintPrice, "Insufficient payment");
        require(bytes(tokenURI).length > 0, "Token URI cannot be empty");
        
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        
        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, tokenURI);
        
        emit TokenMinted(msg.sender, tokenId, tokenURI);
        return tokenId;
    }

    /**
     * @dev Sets the mint price for paid minting (owner only)
     * @param newMintPrice The new mint price in wei
     */
    function setMintPrice(uint256 newMintPrice) public onlyOwner {
        mintPrice = newMintPrice;
    }

    /**
     * @dev Sets the base URI for token metadata (owner only)
     * @param baseURI The new base URI
     */
    function setBaseURI(string calldata baseURI) public onlyOwner {
        _baseTokenURI = baseURI;
    }

    /**
     * @dev Withdraws the contract balance to the owner (owner only)
     */
    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        
        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Withdrawal failed");
    }

    /**
     * @dev Returns the total number of tokens minted
     * @return The current token count
     */
    function totalSupply() public view returns (uint256) {
        return _tokenIdCounter.current();
    }

    /**
     * @dev Returns the base URI for token metadata
     * @return The base URI string
     */
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    /**
     * @dev Returns the token URI, checking individual token URI first, then base URI
     * @param tokenId The token ID to get URI for
     * @return The complete token URI
     */
    function tokenURI(uint256 tokenId) public view virtual override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    /**
     * @dev Checks if the contract supports an interface
     * @param interfaceId The interface identifier
     * @return True if the interface is supported
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev Internal function to burn a token (overrides required)
     * @param tokenId The token ID to burn
     */
    function _burn(uint256 tokenId) internal virtual override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }
}
