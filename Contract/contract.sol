// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title GratitudeVault
 * @dev A decentralized appreciation platform for sending support with heartfelt messages
 */
contract GratitudeVault {
    address public beneficiary;

    event AppreciationSent(address indexed supporter, uint256 amount, string message);

    constructor() {
        beneficiary = msg.sender;
    }

    /**
     * @dev Send appreciation and support to the beneficiary
     * @param message A heartfelt message of gratitude
     */
    function sendAppreciation(string memory message) public payable {
        require(msg.value > 0, "Appreciation must be more than 0");
        emit AppreciationSent(msg.sender, msg.value, message);
        payable(beneficiary).transfer(msg.value);
    }

    /**
     * @dev Get the current beneficiary address
     * @return The address receiving the appreciation
     */
    function currentBeneficiary() public view returns (address) {
        return beneficiary;
    }
}