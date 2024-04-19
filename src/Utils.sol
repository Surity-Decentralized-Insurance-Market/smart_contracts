// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.6;

contract Utils {
    function memcmp(bytes memory a, bytes memory b) public pure returns (bool) {
        return (a.length == b.length) && (keccak256(a) == keccak256(b));
    }

    function strcmp(
        string memory a,
        string memory b
    ) public pure returns (bool) {
        return memcmp(bytes(a), bytes(b));
    }

    function substring(
        string calldata str,
        uint256 startIndex,
        uint256 endIndex
    ) public pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(endIndex - startIndex);
        for (uint256 i = startIndex; i < endIndex; i++) {
            result[i - startIndex] = strBytes[i];
        }
        return string(result);
    }

    function strlen(string memory s) public pure returns (uint256) {
        bytes memory b = bytes(s);
        return b.length;
    }
}
