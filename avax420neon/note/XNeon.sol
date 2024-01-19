// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Analyst : KT
 * @title Analyze Link : https://github.com/ETH-KT/ContractAnalysis
 */

contract XNeon is ERC20, Ownable {
    /**
     * @dev
     * _mint(msg.sender, 21000000 * 10 ** decimals());总供应量21000000个
     * @notice 项目方代币，无法增发，固定总量21000000个，目前47.84%进入LBPair池子,45.23%归项目方所有，剩下归玩家所有，
     * 游戏还没推出，目前仅能通过池子购买和质押Land和AVAX420获取
     */
    constructor() ERC20("XNeon", "XNeon") {
        _mint(msg.sender, 21000000 * 10 ** decimals());
    }
}
