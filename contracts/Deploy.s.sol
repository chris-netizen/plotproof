// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {PlotProof} from "./PlotProof.sol";

/// Deploy with:
///   forge script contracts/Deploy.s.sol:DeployPlotProof \
///     --rpc-url $MONAD_RPC --private-key $PK --broadcast
contract DeployPlotProof is Script {
    function run() external {
        vm.startBroadcast();
        PlotProof p = new PlotProof();
        console.log("PlotProof deployed at:", address(p));
        vm.stopBroadcast();
    }
}
