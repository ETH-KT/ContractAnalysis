// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Analyst : KT
 * @title Analyze Link : https://github.com/ETH-KT/ContractAnalysis
 */

/**
 * @dev 申明Magic接口,在这里只写了mint方法，实例化后的合约也只能调用mint方法
 */
interface IMagic {
    function mint(address to, uint256 numberOfTokens) external;
}

contract Land is ERC721, ERC721Enumerable, Ownable {
    /**
     * uriPrefix1,uriPrefix2,uriPrefix3,uriPrefix4,uriPrefix5 URI前缀
     * uriSuffix 后缀
     * @notice 这里使用5种资源，分别对应1级白土地、2级浅蓝土地、3级深蓝土地、4级金土地、5级红土地
     * MAX_SUPPLY 总供应量10000
     * PRICE_PER_TOKEN mint一个的价格
     * maxMintPerTx 每次最多mint多少个
     * erc20Token BNeon代币地址
     * magic 潘多拉魔盒NFT地址
     * tokenLevels 每个TokenId对应的土地级别
     * inviteCounts 邀请数量
     * claimedErc20Rewards 已取出的BNeon代币
     * claimedNftcRewards 已取出的Magic魔盒
     * erc20RewardPerInvite 每邀请一个可获得BNeon代币数量
     * nftcRewardPer10Invites 每邀请10个可获得Magic魔盒数量
     */
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

    /**
     * @dev mint土地的方法
     * requireConditionsForMint mint的前置条件
     * mintTokens 进行mint的逻辑处理
     */
    function mint(uint256 numberOfTokens) public payable {
        requireConditionsForMint(numberOfTokens);
        mintTokens(numberOfTokens, address(0));
    }

    /**
     * @dev mint土地的方法
     * requireConditionsForMint mint的前置条件
     * mintTokens 进行mint的逻辑处理
     */
    function mintWithInviter(
        uint256 numberOfTokens,
        address inviter
    ) public payable {
        requireConditionsForMint(numberOfTokens);
        mintTokens(numberOfTokens, inviter);
    }

    /**
     * @dev mint前置条件处理
     * @param numberOfTokens mint的数量
     * ts + numberOfTokens <= MAX_SUPPLY,当前已mint的NFT数量+预铸造的数量小于等于总供应量
     * numberOfTokens <= maxMintPerTx, 一次mint的次数小于等于一次可mint最大值
     * PRICE_PER_TOKEN * numberOfTokens <= msg.value,支付的额度大于等于需要的额度，这里应该是调用端进行了计算并控制了msg.value
     * @notice 这里既然是用来mint的前置条件判断，是不是用函数修饰器更加优雅呢？
     */
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

    /**
     * @dev mint的逻辑处理
     * @param numberOfTokens mint的数量
     * @param inviter 邀请人地址
     * _safeMint(msg.sender, newTokenId); 调用内置mint方法，给调用者铸造id为newTokenId的NFT
     * assignLevel(newTokenId); 给当前tokenId设置等级，主要是为了后续查询tokenId对应的土地等级，从而对不同的等级进行URI资源拼接
     * 如果邀请人地址不是零地址或者调用者本身，便给邀请人的邀请记录加1
     */
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

    /**
     * @dev 对每个tokenId设置等级
     * @param tokenId NFT的编号Id
     * uint256(keccak256(abi.encodePacked(block.timestamp, tokenId))) % 100;
     * 使用abi.encodePacked对当前区块时间戳和tokenId进行编码，在进行哈希运算,再转为uint256类型，在进行100取模，将随机数控制在0-99
     * determineLevel(randomNum),根据随机数给tokenId分配等级
     * @notice 通过block.timestamp是可被预测,被攻击的
     */
    function assignLevel(uint256 tokenId) private {
        uint256 randomNum = uint256(
            keccak256(abi.encodePacked(block.timestamp, tokenId))
        ) % 100;
        tokenLevels[tokenId] = determineLevel(randomNum);
    }

    /**
     * @dev 对每个tokenId设置等级
     * @param randomNum 随机值
     * @notice 等级5 - 1%   等级4 - 4%  等级3 - 15%  等级2 - 30%  等级1 - 50%
     */
    function determineLevel(uint256 randomNum) private pure returns (uint8) {
        if (randomNum < 50) return 1;
        if (randomNum < 80) return 2;
        if (randomNum < 95) return 3;
        if (randomNum < 99) return 4;
        return 5;
    }

    /**
     * @dev 查询TokenId对应的资源URI链接
     * @param tokenId NFT编号
     * tokenLevels[tokenId] 查询tokenId对应的等级
     * getBaseURI(level) 根据tokenId等级不同，分配不同的baseURI资源
     * (level == 5)? 1: (tokenId %(level == 1 ? 50 : level == 2 ? 30 : level == 3 ? 15 : 4)) + 1;
     * 等级5,jsonId默认为1；
     * 等级为1,TokenId对50取模，jsonId取值0-49,最后加1了->1-50
     * 等级为2,TokenId对30取模,jsonId取值0-29,最终1-30
     * 等级为3,TokenId对15取模,jsonId取值0-14,最终1-15
     * 等级为4,TokenId对4取模,jsonId取值0-3,最终1-4
     * @notice 这样做目的，其实是做了双重随机，第一重就是上文提到的TokenId等级的随机，分别是1-5等级,现在是分别是不同等级进行同等级下不同资源的随机
     * 从这里可以看出,等级5的红土地就只有1种样式的NFT,等级4的金土地就有4种样式的NFT,等级3的深蓝土地就有15种样式的NFT,等级2的浅蓝土地就有30种样式的NFT,等级1的白土地就有50种样式的NFT
     */
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

    /**
     * @dev 获取当前等级对应的URI资源
     * @param level 等级
     */
    function getBaseURI(uint256 level) private view returns (string memory) {
        if (level == 1) return uriPrefix1;
        if (level == 2) return uriPrefix2;
        if (level == 3) return uriPrefix3;
        if (level == 4) return uriPrefix4;
        return uriPrefix5;
    }

    /**
     * @dev 交易前钩子函数,需override
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    /**
     * @dev IERC165，接口查询, 用于查询该合约是否有某接口
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev 设置mint一个NFT的价格
     */
    function setPrice(uint256 newPrice) public onlyOwner {
        PRICE_PER_TOKEN = newPrice;
    }

    /**
     * @dev 提现，只能owner操作
     */
    function withdraw() public onlyOwner {
        (bool os, ) = payable(owner()).call{value: address(this).balance}("");
        require(os);
    }

    /**
     * @dev 设置每邀请一个人可获取的BNeon代币数
     */
    function setERC20RewardPerInvite(uint256 amount) public onlyOwner {
        erc20RewardPerInvite = amount;
    }

    /**
     * @dev 设置每邀请十个人可获取的Magic魔盒数
     */
    function setNftcRewardPer10Invites(uint256 amount) public onlyOwner {
        nftcRewardPer10Invites = amount;
    }

    /**
     * @dev 设置BNeon代币地址
     */
    function setERC20TokenAddress(
        address newERC20TokenAddress
    ) public onlyOwner {
        require(
            newERC20TokenAddress != address(0),
            "ERC20 token address cannot be the zero address"
        );
        erc20Token = IERC20(newERC20TokenAddress);
    }

    /**
     * @dev 设置Magic盒子NFT地址
     */
    function setMagicAddress(address newMagicAddress) public onlyOwner {
        require(
            newMagicAddress != address(0),
            "Magic contract address cannot be the zero address"
        );
        magic = IMagic(newMagicAddress);
    }

    /**
     * @dev 提取BNeon代币
     * inviteCounts[msg.sender] * erc20RewardPerInvite; 获取调用者通过邀请可获取的BNeon总量
     * claimedErc20Rewards[msg.sender];获取调用者已提取的总量
     * totalRewards - claimedRewards;获取到未提取的值
     * claimedErc20Rewards[msg.sender] += unclaimedRewards;已提取的值先增加再转账
     * erc20Token.transfer(msg.sender, unclaimedRewards);通过合约给调用者转移对应数量的BNeon
     * @notice 可能会有朋友有疑问，为啥不在mintTokens的时候就直接转了，还需要增加这么多值来存，然后又还需要用户自己来调用。
     * 其实这种业务拆离,降低耦合度是非常必要的，安全又容易审阅代码，也方便合约升级(虽然这里并没有用到可升级合约)
     */
    function claimErc20Rewards() external {
        uint256 totalRewards = inviteCounts[msg.sender] * erc20RewardPerInvite;
        uint256 claimedRewards = claimedErc20Rewards[msg.sender];
        uint256 unclaimedRewards = totalRewards - claimedRewards;

        require(unclaimedRewards > 0, "No rewards available");

        claimedErc20Rewards[msg.sender] += unclaimedRewards;
        erc20Token.transfer(msg.sender, unclaimedRewards);
    }

    /**
     * @dev 提取Magic盒子NFT
     * (totalInvites / 10) * nftcRewardPer10Invites; 每10个才能获取1个
     *  magic.mint(msg.sender, unclaimedRewards); 给调用者铸造unclaimedRewards数量的魔盒
     */
    function claimNftcRewards() external {
        uint256 totalInvites = inviteCounts[msg.sender];
        uint256 totalRewards = (totalInvites / 10) * nftcRewardPer10Invites;
        uint256 claimedRewards = claimedNftcRewards[msg.sender];
        uint256 unclaimedRewards = totalRewards - claimedRewards;

        require(unclaimedRewards > 0, "No rewards available");

        claimedNftcRewards[msg.sender] += unclaimedRewards;
        magic.mint(msg.sender, unclaimedRewards);
    }

    /**
     * @dev 查询当前owner所拥有的所有Land NFT的TokenId
     */
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
