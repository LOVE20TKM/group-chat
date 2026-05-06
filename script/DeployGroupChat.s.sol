// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {GroupChat} from "../src/GroupChat.sol";
import {TokenActionGovGroupChatManager} from "../src/managers/TokenActionGovGroupChatManager.sol";
import {TokenActionGroupChatManager} from "../src/managers/TokenActionGroupChatManager.sol";
import {TokenGovGroupChatManager} from "../src/managers/TokenGovGroupChatManager.sol";
import {TokenGroupChatManager} from "../src/managers/TokenGroupChatManager.sol";
import {AdminDenySource} from "../src/sources/deny/AdminDenySource.sol";
import {GovVotedDenySource} from "../src/sources/deny/GovVotedDenySource.sol";
import {GroupJoinScopeSource} from "../src/sources/scope/GroupJoinScopeSource.sol";
import {ScriptBase} from "./ScriptBase.sol";

contract DeployGroupChat is ScriptBase {
    struct DeployConfig {
        address groupDefaults;
        address extensionCenter;
        address groupJoin;
        address beforePostPlugin;
        address afterPostPlugin;
        uint256 originBlocks;
        uint256 phaseBlocks;
    }

    struct DeployedAddresses {
        address groupChat;
        address adminDenySource;
        address groupChatDenySource;
        address groupJoinScopeSource;
        address tokenGroupChatManager;
        address tokenGovGroupChatManager;
        address tokenActionGovGroupChatManager;
        address tokenActionGroupChatManager;
    }

    function run() external {
        DeployConfig memory config = DeployConfig({
            groupDefaults: vm.envAddress("GROUP_DEFAULTS_ADDRESS"),
            extensionCenter: vm.envAddress("EXTENSION_CENTER_ADDRESS"),
            groupJoin: vm.envAddress("GROUP_JOIN_ADDRESS"),
            beforePostPlugin: vm.envOr("GROUP_CHAT_BEFORE_POST_PLUGIN_ADDRESS", address(0)),
            afterPostPlugin: vm.envOr("GROUP_CHAT_AFTER_POST_PLUGIN_ADDRESS", address(0)),
            originBlocks: vm.envUint("ORIGIN_BLOCKS"),
            phaseBlocks: vm.envUint("PHASE_BLOCKS")
        });

        vm.startBroadcast();
        DeployedAddresses memory deployed = _deploy(config);
        vm.stopBroadcast();

        string memory network = vm.envString("network");
        string memory dir = string.concat("script/network/", network);
        vm.createDir(dir, true);
        _writeAddressFile(dir, config, deployed);
    }

    function _deploy(DeployConfig memory config) internal returns (DeployedAddresses memory deployed) {
        GroupChat groupChat = new GroupChat(config.groupDefaults, config.originBlocks, config.phaseBlocks);
        deployed.groupChat = address(groupChat);
        deployed.adminDenySource = address(new AdminDenySource(address(groupChat)));
        deployed.groupChatDenySource =
            address(new GovVotedDenySource(groupChat.LOVE20_GROUP(), groupChat.GROUP_DEFAULTS()));
        deployed.groupJoinScopeSource = address(new GroupJoinScopeSource(config.groupJoin));

        TokenGroupChatManager tokenGroupChatManager = new TokenGroupChatManager(
            address(groupChat),
            deployed.groupChatDenySource,
            config.beforePostPlugin,
            config.afterPostPlugin,
            config.extensionCenter
        );
        deployed.tokenGroupChatManager = address(tokenGroupChatManager);
        TokenGovGroupChatManager tokenGovGroupChatManager = new TokenGovGroupChatManager(
            address(groupChat),
            deployed.groupChatDenySource,
            config.beforePostPlugin,
            config.afterPostPlugin,
            config.extensionCenter
        );
        deployed.tokenGovGroupChatManager = address(tokenGovGroupChatManager);
        TokenActionGovGroupChatManager tokenActionGovGroupChatManager = new TokenActionGovGroupChatManager(
            address(groupChat),
            deployed.groupChatDenySource,
            config.beforePostPlugin,
            config.afterPostPlugin,
            config.extensionCenter
        );
        deployed.tokenActionGovGroupChatManager = address(tokenActionGovGroupChatManager);
        TokenActionGroupChatManager tokenActionGroupChatManager = new TokenActionGroupChatManager(
            address(groupChat),
            deployed.groupChatDenySource,
            config.beforePostPlugin,
            config.afterPostPlugin,
            config.extensionCenter
        );
        deployed.tokenActionGroupChatManager = address(tokenActionGroupChatManager);
    }

    function _writeAddressFile(string memory dir, DeployConfig memory config, DeployedAddresses memory deployed)
        internal
    {
        string memory addressFile = string.concat(dir, "/address.group.chat.params");
        vm.writeFile(addressFile, _addressFileContent(config, deployed));
    }

    function _addressFileContent(DeployConfig memory, DeployedAddresses memory deployed)
        internal
        pure
        returns (string memory)
    {
        string memory content = string.concat(
            _addressLine("adminDenySourceAddress", deployed.adminDenySource),
            _addressLine("groupChatDenySourceAddress", deployed.groupChatDenySource),
            _addressLine("groupJoinScopeSourceAddress", deployed.groupJoinScopeSource)
        );
        content = string.concat(
            content,
            _addressLine("groupChatAddress", deployed.groupChat),
            _addressLine("tokenGroupChatManagerAddress", deployed.tokenGroupChatManager),
            _addressLine("tokenGovGroupChatManagerAddress", deployed.tokenGovGroupChatManager)
        );
        content = string.concat(
            content,
            _addressLine("tokenActionGovGroupChatManagerAddress", deployed.tokenActionGovGroupChatManager),
            _addressLine("tokenActionGroupChatManagerAddress", deployed.tokenActionGroupChatManager)
        );
        return content;
    }

    function _addressLine(string memory key, address value) internal pure returns (string memory) {
        return string.concat(key, "=", vm.toString(value), "\n");
    }
}
