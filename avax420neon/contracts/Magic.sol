// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Magic is ERC721URIStorage, Ownable {
    using Strings for uint256;

    enum ItemType {
        Magic,
        Skill,
        MartialArts,
        Sorcery,
        Healing,
        Stealth,
        Enchantment,
        Summoning,
        Elemental,
        Divination
    }

    enum User {
        Normal,
        Boss
    }

    struct ItemAttributes {
        ItemType itemType;
        uint8 level;
        string dna;
        User user;
    }

    IERC20 public paymentToken;
    uint256 public pricePerToken = 100 ether;
    uint256 public tokenCounter;
    string private baseTokenURI;
    string private initialBaseTokenURI;
    string private openedBaseTokenURI;
    bool private isOpened = false;
    mapping(uint256 => ItemAttributes) public itemAttributes;
    address[] public miners;

    event TokenMinted(address to, uint256 tokenId);
    event BaseURIChanged(string newBaseURI);
    event UnboxingStarted();

    modifier onlyMiner() {
        bool isMiner = false;
        for (uint i = 0; i < miners.length; i++) {
            if (msg.sender == miners[i]) {
                isMiner = true;
                break;
            }
        }
        require(isMiner, "Caller is not a miner");
        _;
    }

    constructor(IERC20 _paymentToken) ERC721("Magic", "Magic") {
        paymentToken = _paymentToken;
        initialBaseTokenURI = "ipfs://QmYfT7zNRK4PyR5KNwwb7fcFT42dYQKG6S5P3bqsUTdSUK/magic.json";
    }

    function mintBlindBox() public onlyOwner {
        _mintItem(msg.sender);
    }

    function setInitialBaseTokenURI(string memory newUri) public onlyOwner {
        initialBaseTokenURI = newUri;
    }

    function setOpenedBaseTokenURI(
        string memory _openedBaseTokenURI
    ) public onlyOwner {
        openedBaseTokenURI = _openedBaseTokenURI;
        emit BaseURIChanged(_openedBaseTokenURI);
    }

    function addMiner(address _miner) public onlyOwner {
        miners.push(_miner);
    }

    function removeMiner(address _miner) public onlyOwner {
        for (uint i = 0; i < miners.length; i++) {
            if (miners[i] == _miner) {
                miners[i] = miners[miners.length - 1];
                miners.pop();
                break;
            }
        }
    }

    function startUnboxing() public onlyOwner {
        require(
            bytes(openedBaseTokenURI).length > 0,
            "Opened base URI not set"
        );
        isOpened = true;
        baseTokenURI = openedBaseTokenURI;
        emit UnboxingStarted();
    }

    function openBlindBox(uint256 tokenId) public onlyOwner {
        require(isOpened, "Unboxing not started yet");
        require(_exists(tokenId), "Token does not exist");
        _generateItemAttributes(tokenId);
    }

    function mint(uint256 numberOfTokens) public {
        uint256 totalPrice = pricePerToken * numberOfTokens;
        require(
            paymentToken.transferFrom(msg.sender, address(this), totalPrice),
            "Payment failed"
        );

        for (uint256 i = 0; i < numberOfTokens; i++) {
            _mintItem(msg.sender);
        }
    }

    function mint(address to, uint256 numberOfTokens) external onlyMiner {
        for (uint256 i = 0; i < numberOfTokens; i++) {
            _mintItem(to);
        }
    }

    function setPaymentToken(IERC20 _paymentToken) public onlyOwner {
        paymentToken = _paymentToken;
    }

    function setPricePerToken(uint256 _pricePerToken) public onlyOwner {
        pricePerToken = _pricePerToken;
    }

    function _mintItem(address to) private {
        uint256 tokenId = tokenCounter;
        _safeMint(to, tokenId);
        tokenCounter++;
        emit TokenMinted(to, tokenId);
    }

    function _generateItemAttributes(uint256 tokenId) private {
        ItemType randomItemType = _randomItemType();
        itemAttributes[tokenId] = ItemAttributes(
            randomItemType,
            _randomLevel(randomItemType),
            _randomDNA(),
            _randomUser()
        );
        _setTokenURI(tokenId, _generateTokenURI(tokenId));
    }

    function _randomItemType() private view returns (ItemType) {
        uint256 randomNum = _random() % 10;
        return ItemType(randomNum);
    }

    function _randomLevel(ItemType itemType) private view returns (uint8) {
        if (itemType == ItemType.Magic) {
            return uint8((_random() % 10) + 1); // 1 - 10
        } else if (
            itemType == ItemType.Skill ||
            itemType == ItemType.MartialArts ||
            itemType == ItemType.Elemental
        ) {
            return uint8((_random() % 9) + 1); // 1 - 9
        } else if (
            itemType == ItemType.Sorcery || itemType == ItemType.Healing
        ) {
            return uint8((_random() % 12) + 1); // 1 - 12
        } else if (
            itemType == ItemType.Stealth || itemType == ItemType.Enchantment
        ) {
            return uint8((_random() % 15) + 1); // 1 - 15
        } else if (
            itemType == ItemType.Summoning || itemType == ItemType.Divination
        ) {
            return uint8((_random() % 10) + 1); // 1 - 10
        } else {
            return 1;
        }
    }

    function _randomDNA() private view returns (string memory) {
        uint256 rand = _random();
        return _toBase36(rand % 36 ** 9);
    }

    function _randomUser() private view returns (User) {
        uint256 randomNum = _random() % 100; // 0-99
        return randomNum < 10 ? User.Boss : User.Normal;
    }

    function _random() private view returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        block.timestamp,
                        block.prevrandao,
                        msg.sender
                    )
                )
            );
    }

    function _toBase36(uint256 value) private pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        string memory base36 = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";
        bytes memory base36Bytes = bytes(base36);
        string memory result = "";
        while (value > 0) {
            result = string(abi.encodePacked(base36Bytes[value % 36], result));
            value /= 36;
        }
        return result;
    }

    function walletOfOwner(
        address _owner
    ) public view returns (uint256[] memory) {
        uint256 ownerTokenCount = balanceOf(_owner);
        uint256[] memory ownedTokenIds = new uint256[](ownerTokenCount);
        uint256 currentTokenId = 0;
        uint256 ownedTokenIndex = 0;

        while (ownedTokenIndex < ownerTokenCount) {
            address currentTokenOwner = ownerOf(currentTokenId);

            if (currentTokenOwner == _owner) {
                ownedTokenIds[ownedTokenIndex] = currentTokenId;

                ownedTokenIndex++;
            }

            currentTokenId++;
        }

        return ownedTokenIds;
    }

    function _generateTokenURI(
        uint256 tokenId
    ) private view returns (string memory) {
        return
            string(abi.encodePacked(baseTokenURI, tokenId.toString(), ".json"));
    }
}
