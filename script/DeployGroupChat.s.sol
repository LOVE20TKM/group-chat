// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {GroupChat} from "../src/GroupChat.sol";
import {IExtensionCenter} from "../src/interfaces/external/IExtensionCenter.sol";
import {ILOVE20Join} from "../src/interfaces/external/ILOVE20Join.sol";
import {TokenActionGovManager} from "../src/managers/TokenActionGovManager.sol";
import {TokenActionManager} from "../src/managers/TokenActionManager.sol";
import {TokenGovManager} from "../src/managers/TokenGovManager.sol";
import {TokenManager} from "../src/managers/TokenManager.sol";
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
        uint256 actionRecentRounds;
        uint256 denyThresholdBps;
    }

    struct DeployedAddresses {
        address groupChat;
        address adminDenySource;
        address groupChatDenySource;
        address groupJoinScopeSource;
        address tokenManager;
        address tokenGovManager;
        address tokenActionGovManager;
        address tokenActionManager;
    }

    function run() external {
        address groupJoin = vm.envAddress("GROUP_JOIN_ADDRESS");
        DeployConfig memory config = _configFromCoreJoin(
            vm.envAddress("GROUP_DEFAULTS_ADDRESS"),
            vm.envAddress("EXTENSION_CENTER_ADDRESS"),
            groupJoin,
            vm.envOr("GROUP_CHAT_BEFORE_POST_PLUGIN_ADDRESS", address(0)),
            vm.envOr("GROUP_CHAT_AFTER_POST_PLUGIN_ADDRESS", address(0)),
            vm.envUint("GROUP_CHAT_ACTION_RECENT_ROUNDS"),
            vm.envOr("GROUP_CHAT_DENY_THRESHOLD_BPS", uint256(30))
        );

        vm.startBroadcast();
        DeployedAddresses memory deployed = _deploy(config);
        vm.stopBroadcast();

        string memory network = vm.envString("network");
        string memory dir = string.concat("script/network/", network);
        vm.createDir(dir, true);
        _writeAddressFile(dir, config, deployed);
    }

    function _configFromCoreJoin(
        address groupDefaults,
        address extensionCenter,
        address groupJoin,
        address beforePostPlugin,
        address afterPostPlugin,
        uint256 actionRecentRounds,
        uint256 denyThresholdBps
    ) internal view returns (DeployConfig memory) {
        address coreJoin = IExtensionCenter(extensionCenter).joinAddress();
        return DeployConfig({
            groupDefaults: groupDefaults,
            extensionCenter: extensionCenter,
            groupJoin: groupJoin,
            beforePostPlugin: beforePostPlugin,
            afterPostPlugin: afterPostPlugin,
            originBlocks: ILOVE20Join(coreJoin).originBlocks(),
            phaseBlocks: ILOVE20Join(coreJoin).phaseBlocks(),
            actionRecentRounds: actionRecentRounds,
            denyThresholdBps: denyThresholdBps
        });
    }

    function _deploy(DeployConfig memory config) internal returns (DeployedAddresses memory deployed) {
        GroupChat groupChat = new GroupChat(config.groupDefaults, config.originBlocks, config.phaseBlocks);
        deployed.groupChat = address(groupChat);
        deployed.adminDenySource = address(new AdminDenySource(address(groupChat)));
        deployed.groupChatDenySource = address(
            new GovVotedDenySource(
                groupChat.LOVE20_GROUP_ADDRESS(), groupChat.GROUP_DEFAULTS_ADDRESS(), config.denyThresholdBps
            )
        );
        deployed.groupJoinScopeSource = address(new GroupJoinScopeSource(config.groupJoin));

        TokenManager tokenManager = new TokenManager(
            address(groupChat),
            deployed.groupChatDenySource,
            config.beforePostPlugin,
            config.afterPostPlugin,
            config.extensionCenter
        );
        deployed.tokenManager = address(tokenManager);
        TokenGovManager tokenGovManager = new TokenGovManager(
            address(groupChat),
            deployed.groupChatDenySource,
            config.beforePostPlugin,
            config.afterPostPlugin,
            config.extensionCenter
        );
        deployed.tokenGovManager = address(tokenGovManager);
        TokenActionGovManager tokenActionGovManager = new TokenActionGovManager(
            address(groupChat),
            deployed.groupChatDenySource,
            config.beforePostPlugin,
            config.afterPostPlugin,
            config.extensionCenter,
            config.actionRecentRounds
        );
        deployed.tokenActionGovManager = address(tokenActionGovManager);
        TokenActionManager tokenActionManager = new TokenActionManager(
            address(groupChat),
            deployed.groupChatDenySource,
            config.beforePostPlugin,
            config.afterPostPlugin,
            config.extensionCenter,
            config.actionRecentRounds
        );
        deployed.tokenActionManager = address(tokenActionManager);
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
            _addressLine("tokenManagerAddress", deployed.tokenManager),
            _addressLine("tokenGovManagerAddress", deployed.tokenGovManager)
        );
        content = string.concat(
            content,
            _addressLine("tokenActionGovManagerAddress", deployed.tokenActionGovManager),
            _addressLine("tokenActionManagerAddress", deployed.tokenActionManager)
        );
        return content;
    }

    function _addressLine(string memory key, address value) internal pure returns (string memory) {
        return string.concat(key, "=", vm.toString(value), "\n");
    }
}
