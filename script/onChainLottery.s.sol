// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Script, console2} from "forge-std/Script.sol";
import {onChainLottery} from "../src/onChainLottery.sol";

contract DeployOnChainLottery is Script {
    uint256 internal constant DEFAULT_ENTRY_FEE = 0.1 ether;

    function run() external returns (onChainLottery lottery) {
        uint256 initialEntryFee = vm.envOr("INITIAL_ENTRY_FEE", DEFAULT_ENTRY_FEE);

        // Deployment broadcasting:
       uint256 deployerKey = vm.envOr("PRIVATE_KEY", uint256(0));

        if (deployerKey != 0) {
            vm.startBroadcast(deployerKey);
        } else {
            // If no PRIVATE_KEY env provided, rely on Forge CLI `--private-key` flag or the default broadcast key.
            vm.startBroadcast();
        }

        lottery = new onChainLottery(initialEntryFee);

        vm.stopBroadcast();

        console2.log("onChainLottery deployed at:", address(lottery));
        console2.log("Manager:", lottery.manager());
        console2.log("Initial entry fee:", initialEntryFee);
    }
}
