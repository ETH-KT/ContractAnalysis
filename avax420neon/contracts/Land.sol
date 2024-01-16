// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IMagic {
    function mint(address to, uint256 numberOfTokens) external;
}

contract Land is ERC721, ERC721Enumerable, Ownable {
    using Strings for uint256;

    string public uriPrefix1 =
        "ipfs://QmUftKBuaymDfEHnhotPkzJKFkqseyHUY6D7zQxzcruWbZ/";
    string public uriPrefix2 =
        "ipfs://QmZXNrgLdoqPdMnKNKmMYmV84N35FHSugCTu3SfpwZJWGq/";
    string public uriPrefix3 =
        "ipfs://QmPx8k6dkMqRxtB88ZkECiafr2jWLZXDHwXvMFAjC4Nmgp/";
    string public uriPrefix4 =
        "ipfs://QmcZ8fMzRWWBBCeGzyu8CoUVqM6DcY6g92J6i1eDyzGgn3/";
    string public uriPrefix5 =
        "ipfs://QmSVxVyiBw6emJfgoQBzxim5wKjZd8gchn3Q7EUyKSdJgG/";
    string public uriSuffix = ".json";

    uint256 public constant MAX_SUPPLY = 10000;
    uint256 public PRICE_PER_TOKEN = 0.001 ether;
    uint256 public maxMintPerTx = 20;

    IERC20 public erc20Token;
    IMagic public magic;

    mapping(uint256 => uint8) public tokenLevels;
    mapping(address => uint256) public inviteCounts;
    mapping(address => uint256) public claimedErc20Rewards;
    mapping(address => uint256) public claimedNftcRewards;

    uint256 public erc20RewardPerInvite;
    uint256 public nftcRewardPer10Invites;

    constructor(
        address _bNeonAddress,
        address _magicAddress
    ) ERC721("Land", "Land") {
        erc20Token = IERC20(_bNeonAddress);
        magic = IMagic(_magicAddress);
        erc20RewardPerInvite = 500;
        nftcRewardPer10Invites = 1;
    }

    // Mint functions
    function mint(uint256 numberOfTokens) public payable {
        requireConditionsForMint(numberOfTokens);
        mintTokens(numberOfTokens, address(0));
    }

    function mintWithInviter(
        uint256 numberOfTokens,
        address inviter
    ) public payable {
        requireConditionsForMint(numberOfTokens);
        mintTokens(numberOfTokens, inviter);
    }

    // Helper functions for minting
    function requireConditionsForMint(uint256 numberOfTokens) private view {
        uint256 ts = totalSupply();
        require(
            ts + numberOfTokens <= MAX_SUPPLY,
            "Purchase would exceed max tokens"
        );
        require(numberOfTokens <= maxMintPerTx, "Max Mint Per Tx exceed limit");
        require(
            PRICE_PER_TOKEN * numberOfTokens <= msg.value,
            "Ether value sent is not correct"
        );
    }

    function mintTokens(uint256 numberOfTokens, address inviter) private {
        uint256 ts = totalSupply();
        for (uint256 i = 0; i < numberOfTokens; i++) {
            uint256 newTokenId = ts + i;
            _safeMint(msg.sender, newTokenId);
            assignLevel(newTokenId);
        }

        if (inviter != address(0) && inviter != msg.sender) {
            inviteCounts[inviter] += numberOfTokens;
        }
    }

    function assignLevel(uint256 tokenId) private {
        uint256 randomNum = uint256(
            keccak256(abi.encodePacked(block.timestamp, tokenId))
        ) % 100;
        tokenLevels[tokenId] = determineLevel(randomNum);
    }

    function determineLevel(uint256 randomNum) private pure returns (uint8) {
        if (randomNum < 50) return 1;
        if (randomNum < 80) return 2;
        if (randomNum < 95) return 3;
        if (randomNum < 99) return 4;
        return 5;
    }

    // Returns the token URI based on its level
    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        uint256 level = tokenLevels[tokenId];
        string memory baseURI = getBaseURI(level);
        uint256 jsonId = (level == 5)
            ? 1
            : (tokenId %
                (level == 1 ? 50 : level == 2 ? 30 : level == 3 ? 15 : 4)) + 1;

        return string(abi.encodePacked(baseURI, jsonId.toString(), uriSuffix));
    }

    // Helper function to return base URI based on level
    function getBaseURI(uint256 level) private view returns (string memory) {
        if (level == 1) return uriPrefix1;
        if (level == 2) return uriPrefix2;
        if (level == 3) return uriPrefix3;
        if (level == 4) return uriPrefix4;
        return uriPrefix5;
    }

    // ERC721 and ERC721Enumerable overrides
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function setPrice(uint256 newPrice) public onlyOwner {
        PRICE_PER_TOKEN = newPrice;
    }

    function withdraw() public onlyOwner {
        (bool os, ) = payable(owner()).call{value: address(this).balance}("");
        require(os);
    }

    function setERC20RewardPerInvite(uint256 amount) public onlyOwner {
        erc20RewardPerInvite = amount;
    }

    function setNftcRewardPer10Invites(uint256 amount) public onlyOwner {
        nftcRewardPer10Invites = amount;
    }

    function setERC20TokenAddress(
        address newERC20TokenAddress
    ) public onlyOwner {
        require(
            newERC20TokenAddress != address(0),
            "ERC20 token address cannot be the zero address"
        );
        erc20Token = IERC20(newERC20TokenAddress);
    }

    function setMagicAddress(address newMagicAddress) public onlyOwner {
        require(
            newMagicAddress != address(0),
            "Magic contract address cannot be the zero address"
        );
        magic = IMagic(newMagicAddress);
    }

    function claimErc20Rewards() external {
        uint256 totalRewards = inviteCounts[msg.sender] * erc20RewardPerInvite;
        uint256 claimedRewards = claimedErc20Rewards[msg.sender];
        uint256 unclaimedRewards = totalRewards - claimedRewards;

        require(unclaimedRewards > 0, "No rewards available");

        claimedErc20Rewards[msg.sender] += unclaimedRewards;
        erc20Token.transfer(msg.sender, unclaimedRewards);
    }

    function claimNftcRewards() external {
        uint256 totalInvites = inviteCounts[msg.sender];
        uint256 totalRewards = (totalInvites / 10) * nftcRewardPer10Invites;
        uint256 claimedRewards = claimedNftcRewards[msg.sender];
        uint256 unclaimedRewards = totalRewards - claimedRewards;

        require(unclaimedRewards > 0, "No rewards available");

        claimedNftcRewards[msg.sender] += unclaimedRewards;
        magic.mint(msg.sender, unclaimedRewards);
    }

    function walletOfOwner(
        address owner
    ) public view returns (uint256[] memory) {
        uint256 ownerTokenCount = balanceOf(owner);
        uint256[] memory tokenIds = new uint256[](ownerTokenCount);
        for (uint256 i = 0; i < ownerTokenCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(owner, i);
        }
        return tokenIds;
    }
}
