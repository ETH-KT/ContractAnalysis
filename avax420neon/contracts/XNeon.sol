// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract XNeon is ERC20, Ownable {
    constructor() ERC20("XNeon", "XNeon") {
        _mint(msg.sender, 21000000 * 10 ** decimals());
    }
}
