// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.6.0/contracts/token/ERC20/ERC20.sol";

contract SureCoin is ERC20 {
    constructor(uint256 initialSupply) ERC20("Surecoin", "SURE") {
        _mint(msg.sender, initialSupply);
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }
}
