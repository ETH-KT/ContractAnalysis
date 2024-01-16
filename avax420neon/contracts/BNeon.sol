// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BNeon is ERC20, Ownable {
    constructor() ERC20("BNeon", "BNeon") {
        _mint(msg.sender, 100000000 * 10 ** decimals());
    }

    function mintAdditionalTokens(uint256 amount) public onlyOwner {
        _mint(msg.sender, amount);
    }
}
