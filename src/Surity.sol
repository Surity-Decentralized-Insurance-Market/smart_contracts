// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.6;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.6.0/contracts/token/ERC20/ERC20.sol";
import "./InsuranceController.sol";
import "./Surecoin.sol";

contract Surity {
    ERC20 usdt;
    ERC20 rewardToken;
    address public serverAddress =
        address(0x27b6E7edae917EB5AC116597A7C2279F4CB0620B);
    uint256 rewardRate;
    uint256 deployedAt;

    constructor(address _usdtAddress) {
        SureCoin surecoin = new SureCoin(100000000 * (10**18));
        rewardToken = ERC20(address(surecoin));
        usdt = ERC20(_usdtAddress);
        deployedAt = block.timestamp;
    }

    address[] private schemes;
    mapping(address => bool) private addressIsScheme;
    address[] private stakers;
    mapping(address => bool) private isAddressStaker;
    mapping(address => address[]) private policiesStakedInByUserArray;
    mapping(address => mapping(address => bool))
        private policiesStakedInByUserMapping;

    modifier onlyServerSigned(bytes32 _message, bytes memory _signature) {
        require(
            recoverAddressV2(_message, _signature) == serverAddress,
            "Tampered Server Signature"
        );
        _;
    }

    function deployNewScheme(
        uint256 _initialStake,
        bytes32 _digestFunctionVerification
    ) external returns (address) {
        require(
            _initialStake > 5 * usdt.decimals(),
            "Insufficient Initial Stake"
        );
        require(
            usdt.transferFrom(msg.sender, address(this), _initialStake),
            "Transfer failed"
        );
        InsuranceController scheme = new InsuranceController(
            serverAddress,
            address(usdt),
            _initialStake,
            _digestFunctionVerification
        );
        schemes.push(address(scheme));
        addressIsScheme[address(scheme)] = true;
        return address(scheme);
    }

    function getLatestScheme() public view returns (address) {
        return schemes[schemes.length - 1];
    }

    function getAllSchemes() public view returns (address[] memory) {
        return schemes;
    }

    function getpoliciesStakedInByUser(address _addr)
        public
        view
        returns (address[] memory)
    {
        return policiesStakedInByUserArray[_addr];
    }

    function addPolicyToUsersRecords(address _user) external {
        require(addressIsScheme[msg.sender], "Not allowed");
        if (!policiesStakedInByUserMapping[_user][msg.sender]) {
            policiesStakedInByUserArray[_user].push(msg.sender);
            policiesStakedInByUserMapping[_user][msg.sender] = true;
            if (!isAddressStaker[_user]) {
                stakers.push(_user);
            }
        }
    }

    function getRewardEarned(
        address _user,
        address _policy,
        uint256 _index
    ) public view returns (uint256) {
        uint256 denom = 0;
        for (uint256 i = 0; i < stakers.length; i++) {
            for (
                uint256 j = 0;
                j < policiesStakedInByUserArray[stakers[i]].length;
                j++
            ) {
                InsuranceController insuranceOfThisUser = InsuranceController(
                    policiesStakedInByUserArray[stakers[i]][j]
                );
                for (
                    uint256 k = 0;
                    k < insuranceOfThisUser.getStakesCountByUser(_user);
                    k++
                ) {
                    (
                        uint256 stakeAmount,
                        uint256 stakeTimestamp
                    ) = insuranceOfThisUser.getStakeOfUserByIndex(_user, k);
                    denom +=
                        stakeAmount *
                        ((block.timestamp - stakeTimestamp) / (1000 * 60));
                }
            }
        }

        uint256 rewardsGivenOut = 0;
        if (block.timestamp - deployedAt > 30 * 24 * 60 * 60 * 1000) {
            rewardsGivenOut = (block.timestamp - deployedAt) * rewardRate;
        }
        (uint256 staked, uint256 stakedAt) = InsuranceController(_policy)
            .getStakeOfUserByIndex(_user, _index);

        return
            ((staked * ((block.timestamp - stakedAt) / (1000 * 60))) / denom) *
            rewardsGivenOut;
    }

    function claimRewardEarned(address _policy, uint256 _index) external {
        uint256 reward = getRewardEarned(msg.sender, _policy, _index);
        require(reward > 1, "Earn more rewards before claiming");
        InsuranceController(_policy).removeStake(msg.sender, _index);
        require(
            rewardToken.transfer(msg.sender, reward),
            "Failed to transfer, please try again"
        );
    }

    function toEthSignedMessageHash(bytes32 hash)
        internal
        pure
        returns (bytes32 _message)
    {
        assembly {
            mstore(0x00, "\x19Ethereum Signed Message:\n32")
            mstore(0x1c, hash)
            _message := keccak256(0x00, 0x3c)
        }
    }

    function recoverAddressV2(bytes32 _packed, bytes memory _signature)
        public
        pure
        returns (address)
    {
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
