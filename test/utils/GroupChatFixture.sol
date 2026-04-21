// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {GroupChat} from "../../src/GroupChat.sol";
import {
    IGroupChatErrors,
    IGroupChatStructs
} from "../../src/interfaces/IGroupChat.sol";
import {MockLOVE20Group} from "../mocks/MockLOVE20Group.sol";
import {TestBase, Vm} from "./TestBase.sol";

abstract contract GroupChatFixture is TestBase {
    MockLOVE20Group internal groupNft;
    GroupChat internal chat;

    address internal chatOwner = address(0xA11CE);
    address internal senderOwner = address(0xB0B);
    address internal other = address(0xCAFE);
    address internal delegateGroupOwner = address(0xD36E6A7E);

    uint256 internal chatGroupId;
    uint256 internal senderGroupId;
    uint256 internal otherGroupId;
    uint256 internal delegateGroupId;
    uint256 internal originBlocks;
    uint256 internal phaseBlocks = 100;
    bytes32 internal constant META_SET_SIG =
        keccak256("MetaSet(uint256,address,uint256,string,bytes,bytes)");
    bytes32 internal constant DELEGATE_GROUP_ID_SET_SIG =
        keccak256("DelegateGroupIdSet(uint256,address,uint256,uint256,uint256)");
    bytes32 internal constant BEFORE_POST_PLUGIN_SET_SIG =
        keccak256(
            "BeforePostPluginSet(uint256,address,address,uint256,address)"
        );
    bytes32 internal constant AFTER_POST_PLUGIN_SET_SIG =
        keccak256(
            "AfterPostPluginSet(uint256,address,address,uint256,address)"
        );
    bytes32 internal constant CHAT_ACTIVATE_SIG =
        keccak256("ChatActivate(uint256,address,uint256)");
    bytes32 internal constant MESSAGE_POST_SIG =
        keccak256(
            "MessagePost(uint256,uint256,address,uint256,uint256,uint256)"
        );
    bytes32 internal constant AFTER_POST_PLUGIN_FAILED_SIG =
        keccak256(
            "AfterPostPluginFailed(uint256,uint256,address,uint256,uint256,bytes)"
        );

    function setUp() public virtual {
        groupNft = new MockLOVE20Group();
        chatGroupId = groupNft.mint(chatOwner);
        senderGroupId = groupNft.mint(senderOwner);
        otherGroupId = groupNft.mint(other);
        delegateGroupId = groupNft.mint(delegateGroupOwner);

        originBlocks = block.number + 50;
        chat = new GroupChat(address(groupNft), originBlocks, phaseBlocks);
    }

    function _emptyMeta()
        internal
        pure
        returns (string[] memory keys, bytes[] memory values)
    {
        keys = new string[](0);
        values = new bytes[](0);
    }

    function _emptyMentions() internal pure returns (uint256[] memory mentions) {
        mentions = new uint256[](0);
    }

    function _post(
        uint256 chatGroupId_,
        uint256 senderGroupId_,
        string memory content
    ) internal {
        chat.post(chatGroupId_, senderGroupId_, content, _emptyMentions(), false);
    }

    function _postWithMentions(
        uint256 chatGroupId_,
        uint256 senderGroupId_,
        string memory content,
        uint256[] memory mentions,
        bool mentionAll
    ) internal {
        chat.post(chatGroupId_, senderGroupId_, content, mentions, mentionAll);
    }

    function _activateEmpty() internal {
        (string[] memory keys, bytes[] memory values) = _emptyMeta();
        vm.prank(chatOwner);
        chat.activateChat(chatGroupId, keys, values, address(0), address(0), 0);
    }

    function _decodeMetaConfigVersion(bytes memory data) internal pure returns (uint256 version) {
        (version, , , ) = abi.decode(data, (uint256, string, bytes, bytes));
    }

    function _decodeMetaKey(bytes memory data) internal pure returns (string memory key) {
        (, key, , ) = abi.decode(data, (uint256, string, bytes, bytes));
    }

    function _decodeMetaValue(bytes memory data) internal pure returns (bytes memory value) {
        (, , value, ) = abi.decode(data, (uint256, string, bytes, bytes));
    }

    function _decodeMetaPrevValue(bytes memory data) internal pure returns (bytes memory prevValue) {
        (, , , prevValue) = abi.decode(data, (uint256, string, bytes, bytes));
    }

    function _decodeVersionAndAddress(bytes memory data) internal pure returns (uint256 version) {
        (version, ) = abi.decode(data, (uint256, address));
    }

    function _decodeVersionAndUint256(bytes memory data) internal pure returns (uint256 version) {
        (version, ) = abi.decode(data, (uint256, uint256));
    }

    function _decodeChatActivateVersion(bytes memory data) internal pure returns (uint256 version) {
        version = abi.decode(data, (uint256));
    }

    function _decodeMessagePostVersion(bytes memory data) internal pure returns (uint256 version) {
        (version, , ) = abi.decode(data, (uint256, uint256, uint256));
    }

    function _decodeMessagePost(
        bytes memory data
    ) internal pure returns (uint256 version, uint256 round, uint256 messageIndex) {
        (version, round, messageIndex) = abi.decode(data, (uint256, uint256, uint256));
    }

    function _decodeAfterPostFailedVersion(bytes memory data) internal pure returns (uint256 version) {
        (version, , ) = abi.decode(data, (uint256, uint256, bytes));
    }
}
