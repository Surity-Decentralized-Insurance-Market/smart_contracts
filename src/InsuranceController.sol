// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.6;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.6.0/contracts/token/ERC20/ERC20.sol";
import "./Surity.sol";

contract InsuranceController {
    ERC20 usdt;
    Surity surity;
    address public serverAddress =
        address(0x27b6E7edae917EB5AC116597A7C2279F4CB0620B);
    address public owner;

    uint256 public initialStake;

    bytes32 public digestFunctionVerification; // PremiumCalculationFunction, ClaimValidationFunction

    struct Stake {
        uint256 timestamp;
        uint256 amount;
    }

    mapping(address => Stake[]) private stakes;
    address[] stakers;

    enum InstanceState {
        ONGOING,
        CLAIMED,
        EXPIRED
    }

    struct Instance {
        uint256 boughtAt;
        uint256 duration;
        string claimFunction;
        bool claimApproved;
        InstanceState state;
        uint256 premiumAmount;
        uint256 claimAmount;
    }

    mapping(address => Instance[]) instances;

    constructor(
        address _serverAddress,
        address _usdtAddress,
        uint256 _initialStake,
        bytes32 _hashedName,
        bytes memory _serverSignedContractVerification,
        bytes32 _digestFunctionVerification
    ) {
        serverAddress = _serverAddress;

        require(
            recoverAddressV2(
                keccak256(
                    abi.encodePacked(
                        _hashedName,
                        keccak256(abi.encodePacked(tx.origin))
                    )
                ),
                _serverSignedContractVerification
            ) == serverAddress,
            "Tampered Server Signature"
        );

        surity = Surity(msg.sender);
        usdt = ERC20(_usdtAddress);
        initialStake = _initialStake * (10 ** usdt.decimals());
        owner = tx.origin;
        digestFunctionVerification = _digestFunctionVerification;
    }

    modifier ownerOnly() {
        require(msg.sender == owner, "Only owner access");
        _;
    }

    modifier onlyServerSigned(bytes32 _message, bytes memory _signature) {
        require(
            recoverAddressV2(_message, _signature) == serverAddress,
            "Tampered Server Signature"
        );
        _;
    }

    modifier notOwningInsurance(address _addr) {
        require(!isInsuranceOngoing(_addr), "Already have insruance running");
        _;
    }

    modifier insuranceExists(address _addr) {
        require(isInsuranceOngoing(_addr), "No insruance running");
        _;
    }

    function isInsuranceOngoing(address _addr) public view returns (bool) {
        Instance[] memory userInstances = instances[_addr];
        if (userInstances.length == 0) return false;
        Instance memory latestInstance = userInstances[
            userInstances.length - 1
        ];
        return latestInstance.state == InstanceState.ONGOING;
    }

    function getLatestInstance(
        address _addr
    ) public view insuranceExists(_addr) returns (Instance memory) {
        Instance[] memory userInstances = instances[_addr];
        Instance memory latestInstance = userInstances[
            userInstances.length - 1
        ];
        return latestInstance;
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
            usdt.transferFrom(msg.sender, address(this), _premiumAmount),
            "Not Enough Value to match premium amount"
        );

        Instance memory newInsurance = Instance(
            block.timestamp,
            _duration,
            _claimFunction,
            false,
            InstanceState.ONGOING,
            _premiumAmount,
            _claimAmount
        );
        instances[msg.sender].push(newInsurance);
    }

    function approveClaim(
        address _user
    ) external ownerOnly insuranceExists(_user) {
        Instance[] storage userInstances = instances[_user];
        Instance storage latestInstance = userInstances[
            userInstances.length - 1
        ];
        latestInstance.claimApproved = true;
    }

    function raiseClaim(
        bytes memory _signature,
        uint256 _executionTimestamp
    )
        external
        insuranceExists(msg.sender)
        onlyServerSigned(
            keccak256(
                abi.encodePacked(
                    keccak256(abi.encodePacked(msg.sender)),
                    getLatestInstance(msg.sender).claimFunction,
                    _executionTimestamp,
                    "Claimable"
                )
            ),
            _signature
        )
    {
        Instance[] storage userInstances = instances[msg.sender];
        Instance storage instance = userInstances[userInstances.length - 1];
        require(
            _executionTimestamp > block.timestamp - 5 * 60 * 1000,
            "Server Signautre Expired, please try again"
        );
        require(!(instance.state == InstanceState.CLAIMED), "Already Claimed");
        require(
            instance.claimAmount < usdt.balanceOf(address(this)),
            "Sorry, Pool does not have sufficient funds"
        );
        require(usdt.transfer(msg.sender, instance.claimAmount));
        instance.state = InstanceState.CLAIMED;
    }

    function stakeToPolicy(uint256 _amount) external {
        require(
            usdt.transferFrom(msg.sender, address(this), _amount),
            "Invalid transfer of funds"
        );
        if (stakes[msg.sender].length == 0) {
            stakers.push(msg.sender);
        }
        Stake memory newStake = Stake(block.timestamp, _amount);
        stakes[msg.sender].push(newStake);
        surity.addPolicyToUsersRecords(msg.sender);
    }

    function getStakesCountByUser(address _user) public view returns (uint256) {
        return stakes[_user].length;
    }

    function getStakeOfUserByIndex(
        address _user,
        uint256 _index
    ) public view returns (uint256, uint256) {
        return (stakes[_user][_index].amount, stakes[_user][_index].timestamp);
    }

    function revokeStake(uint256 _index) external {
        uint256 stakedAmount = stakes[msg.sender][_index].amount;
        require(
            usdt.balanceOf(address(this)) > stakedAmount,
            "Sorry, not enough tokens in pool"
        );
        require(
            usdt.transfer(msg.sender, stakedAmount),
            "Failed to transfer money"
        );
        delete stakes[msg.sender][_index];
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
