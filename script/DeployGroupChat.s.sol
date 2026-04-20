// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {GroupChat} from "../src/GroupChat.sol";
import {ScriptBase} from "./ScriptBase.sol";

contract DeployGroupChat is ScriptBase {
    function run() external {
        address love20GroupAddress = vm.envAddress("LOVE20_GROUP_ADDRESS");
        uint256 originBlocks = vm.envOr("ORIGIN_BLOCKS", uint256(0));
        uint256 phaseBlocks = vm.envOr("PHASE_BLOCKS", uint256(30126));

        vm.startBroadcast();
        GroupChat groupChat =
            new GroupChat(love20GroupAddress, originBlocks, phaseBlocks);
        vm.stopBroadcast();

        string memory network = vm.envOr("network", string("anvil"));
        string memory dir = string.concat("script/network/", network);
        vm.createDir(dir, true);

        string memory addressFile = string.concat(dir, "/address.group.chat.params");
        string memory content = string.concat(
            "groupChatAddress=",
            vm.toString(address(groupChat)),
            "\noriginBlocks=",
            vm.toString(originBlocks),
            "\nphaseBlocks=",
            vm.toString(phaseBlocks),
            "\n"
        );

        vm.writeFile(addressFile, content);
    }
}
