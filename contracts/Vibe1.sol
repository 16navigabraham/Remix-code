// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract ProofOfVibesChallenge is ERC721, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    
    // Challenge types
    enum ChallengeType { MEME, WORKSPACE, GIF_REACTION }
    
    // Badge structure for different challenges
    struct Badge {
        ChallengeType challengeType;
        string name;
        string description;
        string ipfsHash;
        uint256 vibesReward;
        bool active;
    }
    
    // User progress tracking
    struct UserProfile {
        uint256 totalVibes;
        uint256 totalBadges;
        mapping(ChallengeType => bool) completedChallenges;
        mapping(ChallengeType => uint256) challengeTokenIds;
    }
    
    // Mappings
    mapping(ChallengeType => Badge) public challengeBadges;
    mapping(address => UserProfile) public userProfiles;
    mapping(uint256 => ChallengeType) public tokenToChallenge;
    
    // Events
    event ChallengeCompleted(address indexed user, ChallengeType challengeType, uint256 tokenId, uint256 vibesEarned);
    event BadgeUpdated(ChallengeType challengeType, string newHash);
    
    constructor() ERC721("Proof of Vibes", "POV") Ownable(msg.sender) {
        // Initialize challenge badges
        _initializeChallenges();
    }
    
    function _initializeChallenges() private {
        // Meme Challenge
        challengeBadges[ChallengeType.MEME] = Badge({
            challengeType: ChallengeType.MEME,
            name: "Meme Master",
            description: "Submitted an epic crypto meme",
            ipfsHash: "", // Set later
            vibesReward: 100,
            active: true
        });
        
        // Workspace Challenge  
        challengeBadges[ChallengeType.WORKSPACE] = Badge({
            challengeType: ChallengeType.WORKSPACE,
            name: "Setup Flex",
            description: "Showed off your coding workspace",
            ipfsHash: "", // Set later
            vibesReward: 150,
            active: true
        });
        
        // GIF Challenge
        challengeBadges[ChallengeType.GIF_REACTION] = Badge({
            challengeType: ChallengeType.GIF_REACTION,
            name: "Reaction King",
            description: "Created the perfect GIF reaction",
            ipfsHash: "", // Set later
            vibesReward: 120,
            active: true
        });
    }
    
    /**
     * @dev Complete a challenge and mint badge
     * @param challengeType Type of challenge completed
     */
    function completeChallenge(ChallengeType challengeType) external {
        require(challengeBadges[challengeType].active, "Challenge not active");
        require(!userProfiles[msg.sender].completedChallenges[challengeType], "Challenge already completed");
        
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        
        // Mint the badge NFT
        _safeMint(msg.sender, newTokenId);
        
        // Update user profile
        userProfiles[msg.sender].completedChallenges[challengeType] = true;
        userProfiles[msg.sender].challengeTokenIds[challengeType] = newTokenId;
        userProfiles[msg.sender].totalVibes += challengeBadges[challengeType].vibesReward;
        userProfiles[msg.sender].totalBadges += 1;
        
        // Map token to challenge type
        tokenToChallenge[newTokenId] = challengeType;
        
        emit ChallengeCompleted(
            msg.sender, 
            challengeType, 
            newTokenId, 
            challengeBadges[challengeType].vibesReward
        );
    }
    
    /**
     * @dev Update badge IPFS hash for a challenge type
     * @param challengeType Challenge to update
     * @param newIpfsHash New IPFS hash from Pinata
     */
    function updateBadgeHash(ChallengeType challengeType, string memory newIpfsHash) external onlyOwner {
        challengeBadges[challengeType].ipfsHash = newIpfsHash;
        emit BadgeUpdated(challengeType, newIpfsHash);
    }
    
    /**
     * @dev Toggle challenge active status
     * @param challengeType Challenge to toggle
     */
    function toggleChallenge(ChallengeType challengeType) external onlyOwner {
        challengeBadges[challengeType].active = !challengeBadges[challengeType].active;
    }
    
    /**
     * @dev Get user's completion status for all challenges
     * @param user User address to check
     * @return memeComplete, workspaceComplete, gifComplete
     */
    function getUserProgress(address user) external view returns (bool, bool, bool) {
        return (
            userProfiles[user].completedChallenges[ChallengeType.MEME],
            userProfiles[user].completedChallenges[ChallengeType.WORKSPACE],
            userProfiles[user].completedChallenges[ChallengeType.GIF_REACTION]
        );
    }
    
    /**
     * @dev Get user's total vibes and badges
     * @param user User address
     * @return totalVibes, totalBadges
     */
    function getUserStats(address user) external view returns (uint256, uint256) {
        return (userProfiles[user].totalVibes, userProfiles[user].totalBadges);
    }
    
    /**
     * @dev Check if user completed specific challenge
     * @param user User address
     * @param challengeType Challenge type to check
     * @return completed status
     */
    function hasCompletedChallenge(address user, ChallengeType challengeType) external view returns (bool) {
        return userProfiles[user].completedChallenges[challengeType];
    }
    
    /**
     * @dev Get token URI based on challenge type
     * @param tokenId Token ID to get URI for
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "Token does not exist");
        
        ChallengeType challengeType = tokenToChallenge[tokenId];
        string memory ipfsHash = challengeBadges[challengeType].ipfsHash;
        
        return string(abi.encodePacked("https://gateway.pinata.cloud/ipfs/", ipfsHash));
    }
    
    /**
     * @dev Get challenge badge info
     * @param challengeType Challenge type
     * @return name, description, vibesReward, active
     */
    function getChallengeInfo(ChallengeType challengeType) external view returns (
        string memory name,
        string memory description, 
        uint256 vibesReward,
        bool active
    ) {
        Badge memory badge = challengeBadges[challengeType];
        return (badge.name, badge.description, badge.vibesReward, badge.active);
    }
    
    /**
     * @dev Get total number of badges minted
     */
    function totalSupply() external view returns (uint256) {
        return _tokenIds.current();
    }
    
    /**
     * @dev Get leaderboard data (top 10 by vibes)
     * Note: This is a simplified version. In production, consider using events + indexing
     */
    function getTopUsers(address[] memory users) external view returns (
        address[] memory topAddresses,
        uint256[] memory topVibes
    ) {
        // Simple sorting for demo - in production use The Graph or similar
        uint256 length = users.length > 10 ? 10 : users.length;
        topAddresses = new address[](length);
        topVibes = new uint256[](length);
        
        // Copy and basic sort (bubble sort for simplicity)
        for (uint i = 0; i < length; i++) {
            topAddresses[i] = users[i];
            topVibes[i] = userProfiles[users[i]].totalVibes;
        }
        
        // Simple bubble sort
        for (uint i = 0; i < length - 1; i++) {
            for (uint j = 0; j < length - i - 1; j++) {
                if (topVibes[j] < topVibes[j + 1]) {
                    // Swap vibes
                    uint256 tempVibes = topVibes[j];
                    topVibes[j] = topVibes[j + 1];
                    topVibes[j + 1] = tempVibes;
                    
                    // Swap addresses
                    address tempAddr = topAddresses[j];
                    topAddresses[j] = topAddresses[j + 1];
                    topAddresses[j + 1] = tempAddr;
                }
            }
        }
        
        return (topAddresses, topVibes);
    }
}