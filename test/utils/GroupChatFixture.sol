// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {GroupChat} from "../../src/GroupChat.sol";
import {IGroupChatErrors, IGroupChatStructs} from "../../src/interfaces/IGroupChat.sol";
import {MockLOVE20Group} from "../mocks/MockLOVE20Group.sol";
import {MockGroupDefaults} from "../mocks/MockGroupDefaults.sol";
import {TestBase, Vm} from "./TestBase.sol";

abstract contract GroupChatFixture is TestBase {
    MockLOVE20Group internal groupNft;
    MockGroupDefaults internal groupDefaults;
    GroupChat internal chat;

    address internal chatOwner = address(0xA11CE);
    address internal senderOwner = address(0xB0B);
    address internal other = address(0xCAFE);
    address internal delegateIdOwner = address(0xD36E6A7E);

    uint256 internal chatGroupId;
    uint256 internal senderId;
    uint256 internal otherGroupId;
    uint256 internal delegateId;
    uint256 internal originBlocks;
    uint256 internal phaseBlocks = 100;
    bytes32 internal constant META_SET_SIG = keccak256("MetaSet(uint256,address,uint256,string,bytes,bytes)");
    bytes32 internal constant DELEGATE_GROUP_ID_SET_SIG =
        keccak256("DelegateIdSet(uint256,address,uint256,uint256,uint256)");
    bytes32 internal constant SCOPE_SOURCE_SET_SIG = keccak256("ScopeSourceSet(uint256,address,address,uint256,address)");
    bytes32 internal constant DENY_SOURCE_SET_SIG = keccak256("DenySourceSet(uint256,address,address,uint256,address)");
    bytes32 internal constant BEFORE_POST_PLUGIN_SET_SIG =
        keccak256("BeforePostPluginSet(uint256,address,address,uint256,address)");
    bytes32 internal constant AFTER_POST_PLUGIN_SET_SIG =
        keccak256("AfterPostPluginSet(uint256,address,address,uint256,address)");
    bytes32 internal constant CHAT_ACTIVATE_SIG = keccak256("ChatActivate(uint256,address,uint256)");
    bytes32 internal constant MESSAGE_POST_SIG = keccak256("MessagePost(uint256,uint256,address,uint256,uint256)");
    bytes32 internal constant MESSAGE_MENTION_SIG = keccak256("MessageMention(uint256,uint256,uint256)");
    bytes32 internal constant MESSAGE_MENTION_ALL_SIG = keccak256("MessageMentionAll(uint256,uint256)");
    bytes32 internal constant AFTER_POST_PLUGIN_FAILED_SIG =
        keccak256("AfterPostPluginFailed(uint256,uint256,address,uint256,bytes)");
    bytes32 internal constant DEFAULT_GROUP_ID_SET_SIG = keccak256("SetDefaultGroupId(address,uint256)");
    bytes32 internal constant DEFAULT_GROUP_ID_CLEARED_SIG = keccak256("ClearDefaultGroupId(address,uint256)");

    function setUp() public virtual {
        groupNft = new MockLOVE20Group();
        chatGroupId = groupNft.mint(chatOwner);
        senderId = groupNft.mint(senderOwner);
        otherGroupId = groupNft.mint(other);
        delegateId = groupNft.mint(delegateIdOwner);

        originBlocks = block.number + 50;
        groupDefaults = new MockGroupDefaults(address(groupNft));
        chat = new GroupChat(address(groupDefaults), originBlocks, phaseBlocks);
    }

    function _emptyMeta() internal pure returns (string[] memory keys, bytes[] memory values) {
        keys = new string[](0);
        values = new bytes[](0);
    }

    function _emptyMentions() internal pure returns (uint256[] memory mentions) {
        mentions = new uint256[](0);
    }

    function _post(uint256 chatGroupId_, uint256 senderId_, string memory content) internal {
        chat.post(chatGroupId_, senderId_, content, _emptyMentions(), false, 0);
    }

    function _postWithMentions(
        uint256 chatGroupId_,
        uint256 senderId_,
        string memory content,
        uint256[] memory mentions,
        bool mentionAll
    ) internal {
        chat.post(chatGroupId_, senderId_, content, mentions, mentionAll, 0);
    }

    function _postWithQuote(
        uint256 chatGroupId_,
        uint256 senderId_,
        string memory content,
        uint256 quotedMessageId
    ) internal {
        chat.post(chatGroupId_, senderId_, content, _emptyMentions(), false, quotedMessageId);
    }

    function _postByDefaultSender(uint256 chatGroupId_, string memory content) internal {
        chat.postByDefaultSender(chatGroupId_, content, _emptyMentions(), false, 0);
    }

    function _activateEmpty() internal {
        (string[] memory keys, bytes[] memory values) = _emptyMeta();
        vm.prank(chatOwner);
        chat.activateChat(chatGroupId, keys, values, address(0), address(0), address(0), address(0), 0);
    }

    function _decodeMetaConfigVersion(bytes memory data) internal pure returns (uint256 version) {
        (version,,,) = abi.decode(data, (uint256, string, bytes, bytes));
    }

    function _decodeMetaKey(bytes memory data) internal pure returns (string memory key) {
        (, key,,) = abi.decode(data, (uint256, string, bytes, bytes));
    }

    function _decodeMetaValue(bytes memory data) internal pure returns (bytes memory value) {
        (,, value,) = abi.decode(data, (uint256, string, bytes, bytes));
    }

    function _decodeMetaPrevValue(bytes memory data) internal pure returns (bytes memory prevValue) {
        (,,, prevValue) = abi.decode(data, (uint256, string, bytes, bytes));
    }

    function _decodeVersionAndAddress(bytes memory data) internal pure returns (uint256 version) {
        (version,) = abi.decode(data, (uint256, address));
    }

    function _decodeVersionAndUint256(bytes memory data) internal pure returns (uint256 version) {
        (version,) = abi.decode(data, (uint256, uint256));
    }

    function _decodeChatActivateVersion(bytes memory data) internal pure returns (uint256 version) {
        version = abi.decode(data, (uint256));
    }

    function _decodeMessagePost(bytes memory data) internal pure returns (uint256 round, uint256 messageId) {
        (round, messageId) = abi.decode(data, (uint256, uint256));
    }

    function _decodeMessageId(bytes memory data) internal pure returns (uint256 messageId) {
        messageId = abi.decode(data, (uint256));
    }

    function _decodeAfterPostFailedRound(bytes memory data) internal pure returns (uint256 round) {
        (round,) = abi.decode(data, (uint256, bytes));
    }
}
