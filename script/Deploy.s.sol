// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {DelegatorAgent} from "../contracts/DelegatorAgent.sol";

// No console; we'll just return the address
contract DeployDelegatorAgent {
    function deploy() external returns (DelegatorAgent) {
        return new DelegatorAgent();
    }
}
