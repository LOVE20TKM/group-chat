// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {DeployGroupChat} from "../script/DeployGroupChat.s.sol";
import {GroupAdmin} from "../src/GroupAdmin.sol";
import {IGroupChat} from "../src/interfaces/IGroupChat.sol";
import {IBaseManager} from "../src/interfaces/managers/IBaseManager.sol";
import {BaseTokenActionScopeManager} from "../src/managers/BaseTokenActionScopeManager.sol";
import {BaseTokenScopeManager} from "../src/managers/BaseTokenScopeManager.sol";
import {TokenActionGovManager} from "../src/managers/TokenActionGovManager.sol";
import {TokenActionMainManager} from "../src/managers/TokenActionMainManager.sol";
import {AdminDenySource} from "../src/sources/deny/AdminDenySource.sol";
import {GovVotedDenySource} from "../src/sources/deny/GovVotedDenySource.sol";
import {GroupJoinScopeSource} from "../src/sources/scope/GroupJoinScopeSource.sol";
import {GroupMemberScope} from "../src/sources/scope/GroupMemberScope.sol";
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
        uint256 maxAdminIds,
        uint256 denyThresholdRatio
    ) external view returns (DeployConfig memory) {
        return _configFromCoreJoin(
            groupDefaults,
            extensionCenter,
            groupJoin,
            beforePostPlugin,
            afterPostPlugin,
            actionRecentRounds,
            maxAdminIds,
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
    uint256 internal constant MAX_ADMIN_IDS = 20;

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
            maxAdminIds: MAX_ADMIN_IDS,
            denyThresholdRatio: DENY_THRESHOLD_RATIO
        });

        DeployGroupChat.DeployedAddresses memory deployed = deployer.deployForTest(config);

        assertTrue(deployed.groupChat.code.length != 0);
        assertTrue(deployed.groupAdmin.code.length != 0);
        assertTrue(deployed.adminDenySource.code.length != 0);
        assertTrue(deployed.govVotedDenySource.code.length != 0);
        assertTrue(deployed.groupMemberScope.code.length != 0);
        assertTrue(deployed.groupJoinScopeSource.code.length != 0);
        assertTrue(deployed.tokenMainManager.code.length != 0);
        assertTrue(deployed.tokenGovManager.code.length != 0);
        assertTrue(deployed.tokenActionGovManager.code.length != 0);
        assertTrue(deployed.tokenActionMainManager.code.length != 0);

        assertEq(IGroupChat(deployed.groupChat).GROUP_DEFAULTS_ADDRESS(), address(groupDefaults));
        assertEq(IGroupChat(deployed.groupChat).GROUP_ADDRESS(), address(groupNft));
        assertEq(IGroupChat(deployed.groupChat).originBlocks(), 100);
        assertEq(IGroupChat(deployed.groupChat).phaseBlocks(), 25);

        assertEq(GroupAdmin(deployed.groupAdmin).GROUP_CHAT_ADDRESS(), deployed.groupChat);
        assertEq(GroupAdmin(deployed.groupAdmin).GROUP_DEFAULTS_ADDRESS(), address(groupDefaults));
        assertEq(GroupAdmin(deployed.groupAdmin).GROUP_ADDRESS(), address(groupNft));
        assertEq(GroupAdmin(deployed.groupAdmin).MAX_ADMIN_IDS(), MAX_ADMIN_IDS);
        assertEq(AdminDenySource(deployed.adminDenySource).GROUP_ADMIN_ADDRESS(), deployed.groupAdmin);
        assertEq(AdminDenySource(deployed.adminDenySource).GROUP_CHAT_ADDRESS(), deployed.groupChat);
        assertEq(AdminDenySource(deployed.adminDenySource).GROUP_DEFAULTS_ADDRESS(), address(groupDefaults));
        assertEq(AdminDenySource(deployed.adminDenySource).GROUP_ADDRESS(), address(groupNft));
        assertEq(AdminDenySource(deployed.adminDenySource).MAX_ADMIN_IDS(), MAX_ADMIN_IDS);
        assertEq(GovVotedDenySource(deployed.govVotedDenySource).GROUP_ADDRESS(), address(groupNft));
        assertEq(GovVotedDenySource(deployed.govVotedDenySource).PRECISION(), 1e18);
        assertEq(GovVotedDenySource(deployed.govVotedDenySource).DENY_THRESHOLD_RATIO(), DENY_THRESHOLD_RATIO);
        assertEq(GroupMemberScope(deployed.groupMemberScope).GROUP_ADMIN_ADDRESS(), deployed.groupAdmin);
        assertEq(GroupMemberScope(deployed.groupMemberScope).GROUP_ADDRESS(), address(groupNft));
        assertEq(
            GroupJoinScopeSource(deployed.groupJoinScopeSource).GROUP_MEMBER_SCOPE_ADDRESS(), deployed.groupMemberScope
        );
        assertEq(GroupJoinScopeSource(deployed.groupJoinScopeSource).GROUP_JOIN_ADDRESS(), address(groupJoin));

        _assertManagerCommon(deployed.tokenMainManager, deployed);
        _assertManagerCommon(deployed.tokenGovManager, deployed);
        _assertManagerCommon(deployed.tokenActionGovManager, deployed);
        _assertManagerCommon(deployed.tokenActionMainManager, deployed);

        assertEq(BaseTokenScopeManager(deployed.tokenMainManager).EXTENSION_CENTER_ADDRESS(), address(protocol));
        assertEq(BaseTokenScopeManager(deployed.tokenGovManager).EXTENSION_CENTER_ADDRESS(), address(protocol));
        assertEq(
            BaseTokenActionScopeManager(deployed.tokenActionGovManager).EXTENSION_CENTER_ADDRESS(), address(protocol)
        );
        assertEq(
            BaseTokenActionScopeManager(deployed.tokenActionMainManager).EXTENSION_CENTER_ADDRESS(), address(protocol)
        );

        _assertTokenMainManagerDerivedAddressGettersHidden(deployed.tokenMainManager);
        _assertTokenMainManagerDerivedAddressGettersHidden(deployed.tokenGovManager);
        _assertActionManagerDerivedAddressGettersHidden(deployed.tokenActionGovManager);
        _assertActionManagerDerivedAddressGettersHidden(deployed.tokenActionMainManager);

        assertEq(TokenActionGovManager(deployed.tokenActionGovManager).RECENT_ROUNDS(), 3);
        assertEq(TokenActionMainManager(deployed.tokenActionMainManager).RECENT_ROUNDS(), 3);
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
            MAX_ADMIN_IDS,
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
        assertEq(config.maxAdminIds, MAX_ADMIN_IDS);
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
            maxAdminIds: MAX_ADMIN_IDS,
            denyThresholdRatio: DENY_THRESHOLD_RATIO
        });
        DeployGroupChat.DeployedAddresses memory deployed = DeployGroupChat.DeployedAddresses({
            groupChat: address(0x101),
            groupAdmin: address(0x102),
            adminDenySource: address(0x103),
            govVotedDenySource: address(0x104),
            groupMemberScope: address(0x105),
            groupJoinScopeSource: address(0x106),
            tokenMainManager: address(0x107),
            tokenGovManager: address(0x108),
            tokenActionGovManager: address(0x109),
            tokenActionMainManager: address(0x10A)
        });

        string memory content = deployer.addressFileContentForTest(config, deployed);

        _assertContains(content, "groupAdminAddress=");
        _assertContains(content, "adminDenySourceAddress=");
        _assertContains(content, "govVotedDenySourceAddress=");
        _assertContains(content, "groupMemberScopeAddress=");
        _assertContains(content, "groupJoinScopeSourceAddress=");
        _assertContains(content, "groupChatAddress=");
        _assertContains(content, "tokenMainManagerAddress=");
        _assertContains(content, "tokenGovManagerAddress=");
        _assertContains(content, "tokenActionGovManagerAddress=");
        _assertContains(content, "tokenActionMainManagerAddress=");
        _assertNotContains(content, "groupDefaultsAddress=");
        _assertNotContains(content, "extensionCenterAddress=");
        _assertNotContains(content, "groupJoinAddress=");
        _assertNotContains(content, "groupChatBeforePostPluginAddress=");
        _assertNotContains(content, "groupChatAfterPostPluginAddress=");
        _assertNotContains(content, "originBlocks=");
        _assertNotContains(content, "phaseBlocks=");
        _assertNotContains(content, "maxAdminIds=");
    }

    function _assertManagerCommon(address manager, DeployGroupChat.DeployedAddresses memory deployed) internal view {
        assertEq(IBaseManager(manager).GROUP_CHAT_ADDRESS(), deployed.groupChat);
        assertEq(IBaseManager(manager).DENY_SOURCE_ADDRESS(), deployed.govVotedDenySource);
        assertEq(IBaseManager(manager).BEFORE_POST_PLUGIN_ADDRESS(), address(0));
        assertEq(IBaseManager(manager).AFTER_POST_PLUGIN_ADDRESS(), address(0));
    }

    function _assertTokenMainManagerDerivedAddressGettersHidden(address manager) internal {
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
