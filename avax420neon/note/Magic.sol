// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Magic is ERC721URIStorage, Ownable {
    /**
     *  using Strings for uint256; 给 uint256类型附加Strings方法,作为库，uint256可作为第一个参数直接调用方法
     *  ItemType,枚举类型,0-9分表代表不同的盒子种类
     *  User,枚举类型,0-1
     *  ItemAttributes 盒子的属性,包括盒子种类,等级,dna唯一标识,user
     *  paymentToken,购买Magic潘多拉魔盒需要的XNeno代币地址
     *  pricePerToken,购买一个所需的XNeno地址
     *  tokenCounter,已mint的盒子总数 (这合约没有继承oz的ERC721Enumerable库，因此索引,个数这些都需要自己记录,不知道是没有考虑到还是做个gas对比,这样部署gas费用更低)
     *  baseTokenURI,基础的盒子资源链接
     *  initialBaseTokenURI,初始化的基础合约盒子资源链接
     *  openedBaseTokenURI,已经打开潘多拉魔盒资源链接
     *  isOpened,潘多拉魔盒是否可以被打开的开关
     *  itemAttributes,每个潘多拉魔盒 NFT对应的属性
     *  miners,已铸造过魔盒的地址
     *  TokenMinted,魔盒被铸造时,释放事件,铸造者地址+魔盒编号
     *  BaseURIChanged,基础资源链接被修改时,释放事件,新资源链接
     *  UnboxingStarted,盒子默认被锁定,可以被打开时,释放事件
     */
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

    /**
     * @dev 函数修饰器,只有铸造者才能调用
     * @notice 看到这里我在想,如果这里用数组存了miners,如果只是为了检查是否是铸造者，是否用 mapping(address=>bool) 更好一点呢?
     */
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

    /**
     * @dev 构造函数,进行初始化
     * @param _paymentToken 进行支付所需的ERC20代币
     * @notice 按照白皮书所说,这里应该是XNeon代币地址
     */
    constructor(IERC20 _paymentToken) ERC721("Magic", "Magic") {
        paymentToken = _paymentToken;
        initialBaseTokenURI = "ipfs://QmYfT7zNRK4PyR5KNwwb7fcFT42dYQKG6S5P3bqsUTdSUK/magic.json";
    }

    /**
     * @dev 管理者铸造盒子
     * _mintItem(msg.sender),给调用者铸造盒子NFT
     */
    function mintBlindBox() public onlyOwner {
        _mintItem(msg.sender);
    }

    /**
     * @dev 管理者设置初始化的资源链接
     * @param newUri 新的盒子URI资源链接
     */
    function setInitialBaseTokenURI(string memory newUri) public onlyOwner {
        initialBaseTokenURI = newUri;
    }

    /**
     * @dev 管理者设置被打开的盒子资源URI链接,释放BaseURIChanged事件
     * @param _openedBaseTokenURI 被打开的盒子资源URI链接
     */
    function setOpenedBaseTokenURI(
        string memory _openedBaseTokenURI
    ) public onlyOwner {
        openedBaseTokenURI = _openedBaseTokenURI;
        emit BaseURIChanged(_openedBaseTokenURI);
    }

    /**
     * @dev 管理者添加铸造者地址
     * @param _miner 铸造者地址
     */
    function addMiner(address _miner) public onlyOwner {
        miners.push(_miner);
    }

    /**
     * @dev 管理者移除铸造者地址
     * @param _miner 铸造者地址
     */
    function removeMiner(address _miner) public onlyOwner {
        for (uint i = 0; i < miners.length; i++) {
            if (miners[i] == _miner) {
                miners[i] = miners[miners.length - 1];
                miners.pop();
                break;
            }
        }
    }

    /**
     * @dev 管理者设置可以开盒子的状态,释放UnboxingStarted事件
     * @notice 因为打开盒子后，资源的指向改变，因此这里需要判断一下openedBaseTokenURI资源是否已经被设置
     */
    function startUnboxing() public onlyOwner {
        require(
            bytes(openedBaseTokenURI).length > 0,
            "Opened base URI not set"
        );
        isOpened = true;
        baseTokenURI = openedBaseTokenURI;
        emit UnboxingStarted();
    }

    /**
     * @dev 管理者打开盒子并给此盒子生成对应属性
     * @param tokenId 盒子编号
     *  _generateItemAttributes(tokenId); 生成盒子属性
     */
    function openBlindBox(uint256 tokenId) public onlyOwner {
        require(isOpened, "Unboxing not started yet");
        require(_exists(tokenId), "Token does not exist");
        _generateItemAttributes(tokenId);
    }

    /**
     * @dev 潘多拉魔盒铸造,所有人均可mint,需要收费
     * @param numberOfTokens mint的盒子数量
     * pricePerToken * numberOfTokens; 计算铸造这些数量的盒子一共所需的XNeon代币数
     * paymentToken.transferFrom(msg.sender, address(this), totalPrice),调用者向当前合约支付totalPrice数量的XNeon代币
     * _mintItem(msg.sender); 给调用者铸造盒子
     */
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

    /**
     * @dev 可mint的角色调用此方法给to地址免费制造numberOfTokens的盒子
     * @param to 调用者
     * @param numberOfTokens mint的盒子数量
     * @notice 结合白皮书和官网来理解的话，这里主要是为了给质押AVAX420或者Land的用户免费铸造的，质押合约调用此方法，此合约的管理员给质押合约设置为可mint名单
     */
    function mint(address to, uint256 numberOfTokens) external onlyMiner {
        for (uint256 i = 0; i < numberOfTokens; i++) {
            _mintItem(to);
        }
    }

    /**
     * @dev 设置支付代币
     * @param _paymentToken ERC20代币地址
     */
    function setPaymentToken(IERC20 _paymentToken) public onlyOwner {
        paymentToken = _paymentToken;
    }

    /**
     * @dev 设置支付代币数量
     * @param _pricePerToken mint一个所需的代币数量
     */
    function setPricePerToken(uint256 _pricePerToken) public onlyOwner {
        pricePerToken = _pricePerToken;
    }

    /**
     * @dev 铸造盒子方法,释放TokenMinted事件
     * @param to 铸造给谁
     */
    function _mintItem(address to) private {
        uint256 tokenId = tokenCounter;
        _safeMint(to, tokenId);
        tokenCounter++;
        emit TokenMinted(to, tokenId);
    }

    /**
     * @dev 生成盒子属性
     * @param tokenId 盒子编号
     * _randomItemType() 生成随机盒子种类
     * ItemAttributes(
            randomItemType,
            _randomLevel(randomItemType),
            _randomDNA(),
            _randomUser()
        );给当前 TokenId 的盒子生成相对应的属性
        _randomLevel(randomItemType),根据不同种类分配相对应的随机等级
        _randomDNA(),生成随机 DNA
        _randomUser(),生成随机的人物等级
        _setTokenURI(tokenId, _generateTokenURI(tokenId));给tokenId设置对应资源链接
        _generateTokenURI(tokenId)根据tokenId拼接URI资源
     */
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

    /**
     * @dev 随机生成盒子的种类
     * _random() % 10;uint256随机数对10取余,值为0-9
     * ItemType(randomNum)转为对应的盒子类型
     */
    function _randomItemType() private view returns (ItemType) {
        uint256 randomNum = _random() % 10;
        return ItemType(randomNum);
    }

    /**
     * @dev 根据盒子的种类随机生成对应种类的等级范围值
     * _random() % 10;uint256随机数对10取余,值为0-9
     * Magic 1-10
     * Skill MartialArts Elemental 1-9
     * Sorcery Healing 1 - 12
     * Stealth Enchantment 1-15
     * Summoning Divination 1-10
     */
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

    /**
     * @dev 根据盒子的种类随机生成对应种类的等级范围值
     */
    function _randomDNA() private view returns (string memory) {
        uint256 rand = _random();
        return _toBase36(rand % 36 ** 9);
    }

    /**
     * @dev 随机生成人物等级
     * @notice 10% boos 90% normal
     */
    function _randomUser() private view returns (User) {
        uint256 randomNum = _random() % 100; // 0-99
        return randomNum < 10 ? User.Boss : User.Normal;
    }

    /**
     * @dev 生成随机数
     * block.timestamp 区块时间戳
     * block.prevrandao 上一个区块的随机数
     * msg.sender 调用者
     * @notice 使用block.timestamp,block.prevrandao,msg.sender三个值进行编码取随机值,可被预测,可被攻击
     */
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

    /**
     * @dev uint256=>base36
     * @param value uint245 转的值
     */
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

    /**
     *
     * @param _owner 查询用户所拥有的NFT数量
     */
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

    /**
     * @dev 给相应的魔盒生成URI资源链接
     * @param tokenId 魔盒编号
     */
    function _generateTokenURI(
        uint256 tokenId
    ) private view returns (string memory) {
        return
            string(abi.encodePacked(baseTokenURI, tokenId.toString(), ".json"));
    }
}
