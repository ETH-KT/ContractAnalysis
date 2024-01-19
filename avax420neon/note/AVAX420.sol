// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title Analyst : KT
 * @title Analyze Link : https://github.com/ETH-KT/ContractAnalysis
 */

contract AVAX420 is ERC721, ERC721Enumerable, Ownable {
    /**
     * uriPrefix : NFT链接前缀
     * uriSuffix : NFT链接后缀
     * @notice 这样分开，是为了方便接入TokenId，从而组成URI资源路径
     * MAX_SUPPLY 总供应量21000个
     * PRICE_PER_TOKEN Mint价格0.05eth
     * maxMintPerTx 每次mint最多mint 10个
     * @notice 支持每次mint多个，相当于多次mint交易只需要付一次的baseFee
     */
    string public uriPrefix =
        "ipfs://QmUSJaadthr59PCnz7BVSmWKzW5AZduoc8SD8dQJeDcvwq/";
    string public uriSuffix = ".json";

    uint256 public constant MAX_SUPPLY = 21000;

    uint256 public PRICE_PER_TOKEN = 0.05 ether;

    uint256 public maxMintPerTx = 10;

    constructor() ERC721("AVAX420", "AVAX420") {}

    /**
     * @dev 使用oz库,交易前的钩子函数，需要重写
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    /**
     * @dev IERC165,接口查询，主要用于查看当前合约是否支持某方法
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev 设置URI资源链接前缀
     */
    function setUriPrefix(string memory _uriPrefix) public onlyOwner {
        uriPrefix = _uriPrefix;
    }

    /**
     * @dev 设置URI资源链接后缀
     */
    function setUriSuffix(string memory _uriSuffix) public onlyOwner {
        uriSuffix = _uriSuffix;
    }

    /**
     * @dev 查询当前tokenId对应的URI资源
     * @notice 在很多地方可能会看到直接使用 return super.tokenURI(_tokenId)的方式,在这里是不行的。
     * 因为这里的NFT的资源对象都是以.json结尾的，且_tokenId只能是uint256的类型，因此我们需要重写父级tokenURI的方法，加入uriSuffix的编码
     * @notice 如果NFT的资源就是以数字作为文件名，并没有文件后缀，那么就可以直接使用 return super.tokenURI(_tokenId)返回即可
     */
    function tokenURI(
        uint256 _tokenId
    ) public view virtual override returns (string memory) {
        require(
            _exists(_tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );
        string memory currentBaseURI = _baseURI();
        return
            bytes(currentBaseURI).length > 0
                ? string(
                    abi.encodePacked(
                        currentBaseURI,
                        Strings.toString(_tokenId),
                        uriSuffix
                    )
                )
                : "";
    }

    /**
     * @dev 查询当前_owner所拥有的所有NFT的编号
     * @param _owner 查询用户
     * @notice 这里先是使用balanceOf(_owner)获取用户拥有的NFT数量,根据这个数量创建一个定长数组,存储返回
     * currentTokenId 当前TokenId从0开始,ownedTokenIndex索引也从0开始
     * ownedTokenIndex < ownerTokenCount && currentTokenId <= MAX_SUPPLY,判断条件:(用户索引0开始小于拥有数 当前的TokenId小于等于总供应量)进行循环遍历
     * ownerOf(currentTokenId);获取当前TokenId的拥有者地址，然后跟查询用户对比，如果匹配，则将当前的tokenId记录下来。最终遍历完返回查询用户的TokenId
     * @notice 这个功能主要用途在Mint官网要显示用户拥有的所有NFT，不想做这个功能，可以直接引导用户去opensea或者okx这些交易平台直接查看
     * @notice 这里其实不需要这么麻烦，可以直接使用balanceOf(address)获取用户有多少个NFT,然后遍历个数，使用tokenOfOwnerByIndex(address,index),就可以完成此需求了
     */
    function walletOfOwner(
        address _owner
    ) public view returns (uint256[] memory) {
        uint256 ownerTokenCount = balanceOf(_owner);
        uint256[] memory ownedTokenIds = new uint256[](ownerTokenCount);
        uint256 currentTokenId = 0;
        uint256 ownedTokenIndex = 0;

        while (
            ownedTokenIndex < ownerTokenCount && currentTokenId <= MAX_SUPPLY
        ) {
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
     * @dev 对外提供mint NFT的接口
     * @param numberOfTokens mint的个数
     * @notice ts + numberOfTokens <= MAX_SUPPLY,已铸造量+预铸造量小于等于总供应量
     * numberOfTokens <= maxMintPerTx,一次mint的数量小于等于最大设置值
     * PRICE_PER_TOKEN * numberOfTokens <= msg.value,mint numberOfTokens个需要的钱小于等于执行这个方法发送的钱
     * _safeMint(msg.sender, ts + i); ts+i为id进行铸造
     */
    function mint(uint numberOfTokens) public payable {
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

        for (uint256 i = 0; i < numberOfTokens; i++) {
            _safeMint(msg.sender, ts + i);
        }
    }

    /**
     * @dev 基础URI,这个值一旦改变，将会改变所有的TokenURI的指向，包括已铸造的。
     */
    function _baseURI() internal view virtual override returns (string memory) {
        return uriPrefix;
    }

    /**
     * @dev 修改mint一个所需要的价格
     */
    function setPrice(uint256 _price) public onlyOwner {
        PRICE_PER_TOKEN = _price;
    }

    /**
     * @dev 修改一次性可mint的数量
     */
    function setmaxMintPerTx(uint256 _maxMint) public onlyOwner {
        maxMintPerTx = _maxMint;
    }

    /**
     * @dev 提现功能
     * @notice 所有mint所花费的都打入了当前合约，使用此方法进行提到调用者(owner)地址里,使用call要避免被恶意合约reentrancy攻击，这里只有owner才能调用也就不考虑了
     */
    function withdraw() public onlyOwner {
        (bool os, ) = payable(owner()).call{value: address(this).balance}("");
        require(os);
    }
}
