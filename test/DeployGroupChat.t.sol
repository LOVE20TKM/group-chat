// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {DeployGroupChat} from "../script/DeployGroupChat.s.sol";
import {IGroupChat} from "../src/interfaces/IGroupChat.sol";
import {BaseGroupChatManager} from "../src/managers/BaseGroupChatManager.sol";
import {TokenActionGovGroupChatManager} from "../src/managers/TokenActionGovGroupChatManager.sol";
import {TokenActionGroupChatManager} from "../src/managers/TokenActionGroupChatManager.sol";
import {TokenGovGroupChatManager} from "../src/managers/TokenGovGroupChatManager.sol";
import {TokenGroupChatManager} from "../src/managers/TokenGroupChatManager.sol";
import {AdminDenySource} from "../src/sources/deny/AdminDenySource.sol";
import {GovVotedDenySource} from "../src/sources/deny/GovVotedDenySource.sol";
import {GroupJoinScopeSource} from "../src/sources/scope/GroupJoinScopeSource.sol";
import {MockGroupDefaults} from "./mocks/MockGroupDefaults.sol";
import {MockLOVE20Group} from "./mocks/MockLOVE20Group.sol";
import {MockLOVE20Protocols} from "./mocks/MockLOVE20Protocols.sol";
import {TestBase} from "./utils/TestBase.sol";

contract DeployMockGroupJoinGlobal {
    function gTokenAddressesByGroupIdByAccountCount(uint256, address) external pure returns (uint256) {
        return 0;
    }
}

contract DeployGroupChatHarness is DeployGroupChat {
    function configFromCoreJoinForTest(
        address groupDefaults,
        address extensionCenter,
        address groupJoin,
        address beforePostPlugin,
        address afterPostPlugin,
        uint256 actionRecentRounds
    ) external view returns (DeployConfig memory) {
        return _configFromCoreJoin(
            groupDefaults, extensionCenter, groupJoin, beforePostPlugin, afterPostPlugin, actionRecentRounds
        );
    }

    function deployForTest(DeployConfig memory config) external returns (DeployedAddresses memory) {
        return _deploy(config);
    }

    function addressFileContentForTest(DeployConfig memory config, DeployedAddresses memory deployed)
        external
        pure
        returns (string memory)
    {
        return _addressFileContent(config, deployed);
    }
}

contract DeployGroupChatTest is TestBase {
    MockLOVE20Group internal groupNft;
    MockGroupDefaults internal groupDefaults;
    MockLOVE20Protocols internal protocol;
    DeployMockGroupJoinGlobal internal groupJoin;
    DeployGroupChatHarness internal deployer;

    function setUp() public {
        groupNft = new MockLOVE20Group();
        groupDefaults = new MockGroupDefaults(address(groupNft));
        protocol = new MockLOVE20Protocols();
        groupJoin = new DeployMockGroupJoinGlobal();
        deployer = new DeployGroupChatHarness();
    }

    function testT140_deploysSourcesManagersAndWiresDependencies() public {
        DeployGroupChat.DeployConfig memory config = DeployGroupChat.DeployConfig({
            groupDefaults: address(groupDefaults),
            extensionCenter: address(protocol),
            groupJoin: address(groupJoin),
            beforePostPlugin: address(0),
            afterPostPlugin: address(0),
            originBlocks: 100,
            phaseBlocks: 25,
            actionRecentRounds: 3
        });

        DeployGroupChat.DeployedAddresses memory deployed = deployer.deployForTest(config);

        assertTrue(deployed.groupChat.code.length != 0);
        assertTrue(deployed.adminDenySource.code.length != 0);
        assertTrue(deployed.groupChatDenySource.code.length != 0);
        assertTrue(deployed.groupJoinScopeSource.code.length != 0);
        assertTrue(deployed.tokenGroupChatManager.code.length != 0);
        assertTrue(deployed.tokenGovGroupChatManager.code.length != 0);
        assertTrue(deployed.tokenActionGovGroupChatManager.code.length != 0);
        assertTrue(deployed.tokenActionGroupChatManager.code.length != 0);

        assertEq(IGroupChat(deployed.groupChat).GROUP_DEFAULTS_ADDRESS(), address(groupDefaults));
        assertEq(IGroupChat(deployed.groupChat).LOVE20_GROUP_ADDRESS(), address(groupNft));
        assertEq(IGroupChat(deployed.groupChat).originBlocks(), 100);
        assertEq(IGroupChat(deployed.groupChat).phaseBlocks(), 25);

        assertEq(AdminDenySource(deployed.adminDenySource).GROUP_CHAT_ADDRESS(), deployed.groupChat);
        assertEq(AdminDenySource(deployed.adminDenySource).GROUP_DEFAULTS_ADDRESS(), address(groupDefaults));
        assertEq(AdminDenySource(deployed.adminDenySource).LOVE20_GROUP_ADDRESS(), address(groupNft));
        assertEq(GovVotedDenySource(deployed.groupChatDenySource).GROUP_ADDRESS(), address(groupNft));
        assertEq(GovVotedDenySource(deployed.groupChatDenySource).GROUP_DEFAULTS_ADDRESS(), address(groupDefaults));
        assertEq(GroupJoinScopeSource(deployed.groupJoinScopeSource).GROUP_JOIN_ADDRESS(), address(groupJoin));

        _assertManagerCommon(deployed.tokenGroupChatManager, deployed);
        _assertManagerCommon(deployed.tokenGovGroupChatManager, deployed);
        _assertManagerCommon(deployed.tokenActionGovGroupChatManager, deployed);
        _assertManagerCommon(deployed.tokenActionGroupChatManager, deployed);

        assertEq(TokenGroupChatManager(deployed.tokenGroupChatManager).STAKE_ADDRESS(), address(protocol));
        assertEq(TokenGroupChatManager(deployed.tokenGroupChatManager).JOIN_ADDRESS(), address(protocol));
        assertEq(TokenGroupChatManager(deployed.tokenGroupChatManager).VOTE_ADDRESS(), address(protocol));
        assertEq(TokenGovGroupChatManager(deployed.tokenGovGroupChatManager).STAKE_ADDRESS(), address(protocol));
        assertEq(
            TokenActionGovGroupChatManager(deployed.tokenActionGovGroupChatManager).VOTE_ADDRESS(), address(protocol)
        );
        assertEq(TokenActionGovGroupChatManager(deployed.tokenActionGovGroupChatManager).RECENT_ROUNDS(), 3);
        assertEq(TokenActionGroupChatManager(deployed.tokenActionGroupChatManager).VOTE_ADDRESS(), address(protocol));
        assertEq(TokenActionGroupChatManager(deployed.tokenActionGroupChatManager).JOIN_ADDRESS(), address(protocol));
        assertEq(TokenActionGroupChatManager(deployed.tokenActionGroupChatManager).RECENT_ROUNDS(), 3);
    }

    function testT140B_configUsesCoreJoinRoundParameters() public {
        protocol.setPhase(321, 44);

        DeployGroupChat.DeployConfig memory config = deployer.configFromCoreJoinForTest(
            address(groupDefaults), address(protocol), address(groupJoin), address(0xBEEF), address(0xCAFE), 7
        );

        assertEq(config.groupDefaults, address(groupDefaults));
        assertEq(config.extensionCenter, address(protocol));
        assertEq(config.groupJoin, address(groupJoin));
        assertEq(config.beforePostPlugin, address(0xBEEF));
        assertEq(config.afterPostPlugin, address(0xCAFE));
        assertEq(config.originBlocks, 321);
        assertEq(config.phaseBlocks, 44);
        assertEq(config.actionRecentRounds, 7);
    }

    function testT141_addressFileContentIncludesOnlyGroupChatDeploymentFields() public view {
        DeployGroupChat.DeployConfig memory config = DeployGroupChat.DeployConfig({
            groupDefaults: address(groupDefaults),
            extensionCenter: address(protocol),
            groupJoin: address(groupJoin),
            beforePostPlugin: address(0xBEEF),
            afterPostPlugin: address(0xCAFE),
            originBlocks: 123,
            phaseBlocks: 456,
            actionRecentRounds: 7
        });
        DeployGroupChat.DeployedAddresses memory deployed = DeployGroupChat.DeployedAddresses({
            groupChat: address(0x101),
            adminDenySource: address(0x102),
            groupChatDenySource: address(0x103),
            groupJoinScopeSource: address(0x104),
            tokenGroupChatManager: address(0x105),
            tokenGovGroupChatManager: address(0x106),
            tokenActionGovGroupChatManager: address(0x107),
            tokenActionGroupChatManager: address(0x108)
        });

        string memory content = deployer.addressFileContentForTest(config, deployed);

        _assertContains(content, "adminDenySourceAddress=");
        _assertContains(content, "groupChatDenySourceAddress=");
        _assertContains(content, "groupJoinScopeSourceAddress=");
        _assertContains(content, "groupChatAddress=");
        _assertContains(content, "tokenGroupChatManagerAddress=");
        _assertContains(content, "tokenGovGroupChatManagerAddress=");
        _assertContains(content, "tokenActionGovGroupChatManagerAddress=");
        _assertContains(content, "tokenActionGroupChatManagerAddress=");
        _assertNotContains(content, "groupDefaultsAddress=");
        _assertNotContains(content, "extensionCenterAddress=");
        _assertNotContains(content, "groupJoinAddress=");
        _assertNotContains(content, "groupChatBeforePostPluginAddress=");
        _assertNotContains(content, "groupChatAfterPostPluginAddress=");
        _assertNotContains(content, "originBlocks=");
        _assertNotContains(content, "phaseBlocks=");
    }

    function _assertManagerCommon(address manager, DeployGroupChat.DeployedAddresses memory deployed) internal view {
        assertEq(BaseGroupChatManager(manager).GROUP_CHAT_ADDRESS(), deployed.groupChat);
        assertEq(BaseGroupChatManager(manager).DENY_SOURCE_ADDRESS(), deployed.groupChatDenySource);
        assertEq(BaseGroupChatManager(manager).BEFORE_POST_PLUGIN_ADDRESS(), address(0));
        assertEq(BaseGroupChatManager(manager).AFTER_POST_PLUGIN_ADDRESS(), address(0));
    }

    function _assertContains(string memory haystack, string memory needle) internal pure {
        bytes memory h = bytes(haystack);
        bytes memory n = bytes(needle);
        require(n.length != 0 && h.length >= n.length, "ASSERT_CONTAINS");

        for (uint256 i = 0; i <= h.length - n.length; i++) {
            bool matched = true;
            for (uint256 j = 0; j < n.length; j++) {
                if (h[i + j] != n[j]) {
                    matched = false;
                    break;
                }
            }
            if (matched) {
                return;
            }
        }

        revert("ASSERT_CONTAINS");
    }

    function _assertNotContains(string memory haystack, string memory needle) internal pure {
        bytes memory h = bytes(haystack);
        bytes memory n = bytes(needle);
        require(n.length != 0, "ASSERT_NOT_CONTAINS_EMPTY");

        if (h.length < n.length) {
            return;
        }

        for (uint256 i = 0; i <= h.length - n.length; i++) {
            bool matched = true;
            for (uint256 j = 0; j < n.length; j++) {
                if (h[i + j] != n[j]) {
                    matched = false;
                    break;
                }
            }
            require(!matched, "ASSERT_NOT_CONTAINS");
        }
    }
}
