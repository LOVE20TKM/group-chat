// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IGroupChat} from "../interfaces/IGroupChat.sol";
import {IPostScopeSource} from "../interfaces/IPostScopeSource.sol";
import {IDenyVoteWeightSource} from "../interfaces/IDenyVoteWeightSource.sol";
import {IERC721Receiver} from "../interfaces/IERC721Receiver.sol";

abstract contract BaseGroupChatManager is IPostScopeSource, IDenyVoteWeightSource, IERC721Receiver {
    error ManagerAddressHasNoCode();
    error ChatAlreadyManaged();
    error RecentRoundsZero();

    address public immutable GROUP_CHAT;
    address public immutable DENY_SOURCE;
    address public immutable BEFORE_POST_PLUGIN;
    address public immutable AFTER_POST_PLUGIN;

    constructor(address groupChat_, address denySource_, address beforePostPlugin_, address afterPostPlugin_) {
        _requireCode(groupChat_);
        _requireOptionalCode(denySource_);
        _requireOptionalCode(beforePostPlugin_);
        _requireOptionalCode(afterPostPlugin_);

        GROUP_CHAT = groupChat_;
        DENY_SOURCE = denySource_;
        BEFORE_POST_PLUGIN = beforePostPlugin_;
        AFTER_POST_PLUGIN = afterPostPlugin_;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function _activateManagedChat(uint256 chatGroupId) internal {
        string[] memory metaKeys = new string[](0);
        bytes[] memory metaValues = new bytes[](0);
        IGroupChat(GROUP_CHAT).activateChat(
            chatGroupId, metaKeys, metaValues, address(this), DENY_SOURCE, BEFORE_POST_PLUGIN, AFTER_POST_PLUGIN, 0
        );
    }

    function _requireCode(address target) internal view {
        if (target.code.length == 0) revert ManagerAddressHasNoCode();
    }

    function _requireOptionalCode(address target) internal view {
        if (target != address(0)) {
            _requireCode(target);
        }
    }

    function _requireNotManaged(bool managed) internal pure {
        if (managed) revert ChatAlreadyManaged();
    }

    function _requireRecentRounds(uint256 recentRounds) internal pure {
        if (recentRounds == 0) revert RecentRoundsZero();
    }
}
