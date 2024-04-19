// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.6;

contract InsuranceScheme{
    address public owner;
    
    struct Instance{
        uint256 boughtAt;
        uint256 duration;
        string claimFunction;
        bool claimApproved;
        bool claimed;
        uint256 premiumAmount;
        uint256 claimAmount;
    }
    
    address serverAddress;
    mapping(address => Instance) instances;
    
    constructor(){}
    
    function buyInsurance(claimAmount uint256, _signedClaimAmount string, duration uint256, _signedDuration string, _signedPremium string) payable external {
        
    }
}
