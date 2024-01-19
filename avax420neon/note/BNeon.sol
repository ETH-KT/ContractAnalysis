// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Analyst : KT
 * @title Analyze Link : https://github.com/ETH-KT/ContractAnalysis
 */

contract BNeon is ERC20, Ownable {
    /**
     * @dev
     *  _mint(msg.sender, 100000000 * 10 ** decimals());预铸造100000000个
     *  mintAdditionalTokens;可无限增发,
     * @notice 作为游戏代币，只在游戏内流通，无限增发也能说得过去
     */
    constructor() ERC20("BNeon", "BNeon") {
        _mint(msg.sender, 100000000 * 10 ** decimals());
    }

    function mintAdditionalTokens(uint256 amount) public onlyOwner {
        _mint(msg.sender, amount);
    }
}
