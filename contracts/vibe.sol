// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BadgeMinter is ERC721, Ownable {
    uint256 private _tokenId;
    string private _ipfsHash;
    
    mapping(address => bool) public hasMinted;
    
    event BadgeMinted(address indexed user, uint256 tokenId);
    
    constructor(string memory _initialHash) ERC721("Proof of Vibes Badge", "POV") Ownable(msg.sender) {
        _ipfsHash = _initialHash;
    }
    
    function mintBadge() external {
        require(!hasMinted[msg.sender], "Already minted");
        
        _tokenId++;
        hasMinted[msg.sender] = true;
        
        _safeMint(msg.sender, _tokenId);
        
        emit BadgeMinted(msg.sender, _tokenId);
    }
    
    function updateHash(string memory _newHash) external onlyOwner {
        _ipfsHash = _newHash;
    }
    
    function tokenURI(uint256) public view override returns (string memory) {
        return string(abi.encodePacked("https://gateway.pinata.cloud/ipfs/", _ipfsHash));
    }
    
    function totalSupply() public view returns (uint256) {
        return _tokenId;
    }
}