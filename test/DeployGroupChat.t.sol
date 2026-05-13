// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {DeployGroupChat} from "../script/DeployGroupChat.s.sol";
import {IGroupChat} from "../src/interfaces/IGroupChat.sol";
import {BaseManager} from "../src/managers/BaseManager.sol";
import {BaseTokenActionManager} from "../src/managers/BaseTokenActionManager.sol";
import {BaseTokenManager} from "../src/managers/BaseTokenManager.sol";
import {TokenActionGovManager} from "../src/managers/TokenActionGovManager.sol";
import {TokenActionManager} from "../src/managers/TokenActionManager.sol";
import {AdminDenySource} from "../src/sources/deny/AdminDenySource.sol";
import {GovVotedDenySource} from "../src/sources/deny/GovVotedDenySource.sol";
import {GroupJoinScopeSource} from "../src/sources/scope/GroupJoinScopeSource.sol";
import {MockGroupDefaults} from "./mocks/MockGroupDefaults.sol";
import {MockLOVE20Group} from "./mocks/MockLOVE20Group.sol";
import {MockLOVE20Protocols} from "./mocks/MockLOVE20Protocols.sol";
import {TestBase} from "./utils/TestBase.sol";

contract DeployMockGroupJoin {
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
        uint256 actionRecentRounds,
        uint256 denyThresholdRatio
    ) external view returns (DeployConfig memory) {
        return _configFromCoreJoin(
            groupDefaults,
            extensionCenter,
            groupJoin,
            beforePostPlugin,
            afterPostPlugin,
            actionRecentRounds,
            denyThresholdRatio
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
    uint256 internal constant DENY_THRESHOLD_RATIO = 3e15;

    MockLOVE20Group internal groupNft;
    MockGroupDefaults internal groupDefaults;
    MockLOVE20Protocols internal protocol;
    DeployMockGroupJoin internal groupJoin;
    DeployGroupChatHarness internal deployer;

    function setUp() public {
        groupNft = new MockLOVE20Group();
        groupDefaults = new MockGroupDefaults(address(groupNft));
        protocol = new MockLOVE20Protocols();
        groupJoin = new DeployMockGroupJoin();
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
            actionRecentRounds: 3,
            denyThresholdRatio: DENY_THRESHOLD_RATIO
        });

        DeployGroupChat.DeployedAddresses memory deployed = deployer.deployForTest(config);

        assertTrue(deployed.groupChat.code.length != 0);
        assertTrue(deployed.adminDenySource.code.length != 0);
        assertTrue(deployed.groupChatDenySource.code.length != 0);
        assertTrue(deployed.groupJoinScopeSource.code.length != 0);
        assertTrue(deployed.tokenManager.code.length != 0);
        assertTrue(deployed.tokenGovManager.code.length != 0);
        assertTrue(deployed.tokenActionGovManager.code.length != 0);
        assertTrue(deployed.tokenActionManager.code.length != 0);

        assertEq(IGroupChat(deployed.groupChat).GROUP_DEFAULTS_ADDRESS(), address(groupDefaults));
        assertEq(IGroupChat(deployed.groupChat).LOVE20_GROUP_ADDRESS(), address(groupNft));
        assertEq(IGroupChat(deployed.groupChat).originBlocks(), 100);
        assertEq(IGroupChat(deployed.groupChat).phaseBlocks(), 25);

        assertEq(AdminDenySource(deployed.adminDenySource).GROUP_CHAT_ADDRESS(), deployed.groupChat);
        assertEq(AdminDenySource(deployed.adminDenySource).GROUP_DEFAULTS_ADDRESS(), address(groupDefaults));
        assertEq(AdminDenySource(deployed.adminDenySource).LOVE20_GROUP_ADDRESS(), address(groupNft));
        assertEq(GovVotedDenySource(deployed.groupChatDenySource).GROUP_ADDRESS(), address(groupNft));
        assertEq(GovVotedDenySource(deployed.groupChatDenySource).PRECISION(), 1e18);
        assertEq(GovVotedDenySource(deployed.groupChatDenySource).DENY_THRESHOLD_RATIO(), DENY_THRESHOLD_RATIO);
        assertEq(GroupJoinScopeSource(deployed.groupJoinScopeSource).GROUP_JOIN_ADDRESS(), address(groupJoin));

        _assertManagerCommon(deployed.tokenManager, deployed);
        _assertManagerCommon(deployed.tokenGovManager, deployed);
        _assertManagerCommon(deployed.tokenActionGovManager, deployed);
        _assertManagerCommon(deployed.tokenActionManager, deployed);

        assertEq(BaseTokenManager(deployed.tokenManager).EXTENSION_CENTER_ADDRESS(), address(protocol));
        assertEq(BaseTokenManager(deployed.tokenGovManager).EXTENSION_CENTER_ADDRESS(), address(protocol));
        assertEq(BaseTokenActionManager(deployed.tokenActionGovManager).EXTENSION_CENTER_ADDRESS(), address(protocol));
        assertEq(BaseTokenActionManager(deployed.tokenActionManager).EXTENSION_CENTER_ADDRESS(), address(protocol));

        _assertTokenManagerDerivedAddressGettersHidden(deployed.tokenManager);
        _assertTokenManagerDerivedAddressGettersHidden(deployed.tokenGovManager);
        _assertActionManagerDerivedAddressGettersHidden(deployed.tokenActionGovManager);
        _assertActionManagerDerivedAddressGettersHidden(deployed.tokenActionManager);

        assertEq(TokenActionGovManager(deployed.tokenActionGovManager).RECENT_ROUNDS(), 3);
        assertEq(TokenActionManager(deployed.tokenActionManager).RECENT_ROUNDS(), 3);
    }

    function testT140B_configUsesCoreJoinRoundParameters() public {
        protocol.setPhase(321, 44);

        DeployGroupChat.DeployConfig memory config = deployer.configFromCoreJoinForTest(
            address(groupDefaults),
            address(protocol),
            address(groupJoin),
            address(0xBEEF),
            address(0xCAFE),
            7,
            DENY_THRESHOLD_RATIO
        );

        assertEq(config.groupDefaults, address(groupDefaults));
        assertEq(config.extensionCenter, address(protocol));
        assertEq(config.groupJoin, address(groupJoin));
        assertEq(config.beforePostPlugin, address(0xBEEF));
        assertEq(config.afterPostPlugin, address(0xCAFE));
        assertEq(config.originBlocks, 321);
        assertEq(config.phaseBlocks, 44);
        assertEq(config.actionRecentRounds, 7);
        assertEq(config.denyThresholdRatio, DENY_THRESHOLD_RATIO);
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
            actionRecentRounds: 7,
            denyThresholdRatio: DENY_THRESHOLD_RATIO
        });
        DeployGroupChat.DeployedAddresses memory deployed = DeployGroupChat.DeployedAddresses({
            groupChat: address(0x101),
            adminDenySource: address(0x102),
            groupChatDenySource: address(0x103),
            groupJoinScopeSource: address(0x104),
            tokenManager: address(0x105),
            tokenGovManager: address(0x106),
            tokenActionGovManager: address(0x107),
            tokenActionManager: address(0x108)
        });

        string memory content = deployer.addressFileContentForTest(config, deployed);

        _assertContains(content, "adminDenySourceAddress=");
        _assertContains(content, "groupChatDenySourceAddress=");
        _assertContains(content, "groupJoinScopeSourceAddress=");
        _assertContains(content, "groupChatAddress=");
        _assertContains(content, "tokenManagerAddress=");
        _assertContains(content, "tokenGovManagerAddress=");
        _assertContains(content, "tokenActionGovManagerAddress=");
        _assertContains(content, "tokenActionManagerAddress=");
        _assertNotContains(content, "groupDefaultsAddress=");
        _assertNotContains(content, "extensionCenterAddress=");
        _assertNotContains(content, "groupJoinAddress=");
        _assertNotContains(content, "groupChatBeforePostPluginAddress=");
        _assertNotContains(content, "groupChatAfterPostPluginAddress=");
        _assertNotContains(content, "originBlocks=");
        _assertNotContains(content, "phaseBlocks=");
    }

    function _assertManagerCommon(address manager, DeployGroupChat.DeployedAddresses memory deployed) internal view {
        assertEq(BaseManager(manager).GROUP_CHAT_ADDRESS(), deployed.groupChat);
        assertEq(BaseManager(manager).DENY_SOURCE_ADDRESS(), deployed.groupChatDenySource);
        assertEq(BaseManager(manager).BEFORE_POST_PLUGIN_ADDRESS(), address(0));
        assertEq(BaseManager(manager).AFTER_POST_PLUGIN_ADDRESS(), address(0));
    }

    function _assertTokenManagerDerivedAddressGettersHidden(address manager) internal {
        _expectUnknownSelector(manager, abi.encodeWithSignature("STAKE_ADDRESS()"));
        _expectUnknownSelector(manager, abi.encodeWithSignature("LAUNCH_ADDRESS()"));
        _expectUnknownSelector(manager, abi.encodeWithSignature("JOIN_ADDRESS()"));
        _expectUnknownSelector(manager, abi.encodeWithSignature("VOTE_ADDRESS()"));
    }

    function _assertActionManagerDerivedAddressGettersHidden(address manager) internal {
        _expectUnknownSelector(manager, abi.encodeWithSignature("STAKE_ADDRESS()"));
        _expectUnknownSelector(manager, abi.encodeWithSignature("LAUNCH_ADDRESS()"));
        _expectUnknownSelector(manager, abi.encodeWithSignature("VOTE_ADDRESS()"));
        _expectUnknownSelector(manager, abi.encodeWithSignature("JOIN_ADDRESS()"));
    }

    function _expectUnknownSelector(address target, bytes memory data) internal {
        (bool ok,) = target.call(data);
        assertTrue(!ok);
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
