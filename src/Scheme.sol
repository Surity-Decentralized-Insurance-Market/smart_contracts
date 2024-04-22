// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.6;

contract InsuranceController {
    address public owner;

    struct Instance {
        uint256 boughtAt;
        uint256 duration;
        string claimFunction;
        bool claimApproved;
        bool claimed;
        uint256 premiumAmount;
        uint256 claimAmount;
        bool flag;
    }

    address public serverAddress;
    mapping(address => Instance) instances;

    constructor(address _serverAddress) {
        serverAddress = _serverAddress;
    }

    modifier onlyServerSigned(bytes32 _message, bytes memory _signature) {
        require(
            recoverAddressV2(_message, _signature) == serverAddress,
            "Tampered Server Signature"
        );
        _;
    }

    modifier notOwningInsurance(address _addr) {
        require(!instances[_addr].flag, "Already have insruance running");
        _;
    }

    function buyInsurance(
        bytes32 _premiumParameters,
        uint256 _claimAmount,
        uint256 _premiumAmount,
        uint256 _duration,
        string calldata _claimFunction,
        bytes memory _signature
    )
        external
        payable
        notOwningInsurance(msg.sender)
        onlyServerSigned(
            keccak256(
                abi.encodePacked(
                    _premiumParameters,
                    _claimAmount,
                    _premiumAmount,
                    _duration
                )
            ),
            _signature
        )
    {
        require(
            msg.value > _premiumAmount,
            "Not Enough Value to match premium amount"
        );

        Instance memory newInsurance = Instance(
            block.timestamp,
            _duration,
            _claimFunction,
            false,
            false,
            _premiumAmount,
            _claimAmount,
            true
        );
        instances[msg.sender] = newInsurance;
    }

    function toEthSignedMessageHash(
        bytes32 hash
    ) internal pure returns (bytes32 _message) {
        assembly {
            mstore(0x00, "\x19Ethereum Signed Message:\n32")
            mstore(0x1c, hash)
            _message := keccak256(0x00, 0x3c)
        }
    }

    function recoverAddressV2(
        bytes32 _packed,
        bytes memory _signature
    ) public pure returns (address) {
        bytes32 message = toEthSignedMessageHash(_packed);

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(_signature, 0x20))
            s := mload(add(_signature, 0x40))
            v := byte(0, mload(add(_signature, 0x60)))
        }

        if (v < 27) {
            v += 27;
        }

        return ecrecover(message, v, r, s);
    }
}
