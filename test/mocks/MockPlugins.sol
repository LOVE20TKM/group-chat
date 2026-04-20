// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

interface IGroupChatPluginView {
    struct ChatInfo {
        uint256 groupId;
        address owner;
        bool active;
        uint256 configVersion;
        address firstActivatedOwner;
        uint256 firstActivatedBlockNumber;
        uint256 firstActivatedTimestamp;
    }

    function chatInfo(uint256 groupId) external view returns (ChatInfo memory);

    function delegateOf(uint256 groupId) external view returns (address);

    function post(
        uint256 chatGroupId,
        uint256 senderGroupId,
        string calldata content
    ) external;

    function setMeta(
        uint256 groupId,
        string calldata key,
        bytes calldata value
    ) external;
}

contract MockBeforePostRejectPlugin {
    error BeforePostRejected();

    function beforePost(
        uint256,
        uint256,
        address,
        string calldata
    ) external pure {
        revert BeforePostRejected();
    }
}

contract MockAfterPostFailPlugin {
    error AfterPostFailed();

    function afterPost(
        uint256,
        uint256,
        address,
        string calldata
    ) external pure {
        revert AfterPostFailed();
    }
}

contract MockAfterPostReenterPlugin {
    IGroupChatPluginView internal immutable _chat;
    uint256 internal immutable _reenterChatGroupId;
    uint256 internal immutable _reenterSenderGroupId;

    constructor(
        address chat_,
        uint256 reenterChatGroupId_,
        uint256 reenterSenderGroupId_
    ) {
        _chat = IGroupChatPluginView(chat_);
        _reenterChatGroupId = reenterChatGroupId_;
        _reenterSenderGroupId = reenterSenderGroupId_;
    }

    function afterPost(
        uint256,
        uint256,
        address,
        string calldata
    ) external {
        _chat.post(_reenterChatGroupId, _reenterSenderGroupId, "reenter");
    }
}

contract MockAfterPostSetMetaPlugin {
    IGroupChatPluginView internal immutable _chat;

    constructor(address chat_) {
        _chat = IGroupChatPluginView(chat_);
    }

    function afterPost(
        uint256 chatGroupId,
        uint256,
        address,
        string calldata
    ) external {
        _chat.setMeta(chatGroupId, "hook-write", bytes("1"));
    }
}

contract MockManagedPlugin {
    error UnauthorizedPluginManager();

    address public immutable CHAT;
    mapping(uint256 => bytes) public configValue;

    constructor(address chat_) {
        CHAT = chat_;
    }

    function configure(uint256 chatGroupId, bytes calldata value) external {
        IGroupChatPluginView.ChatInfo memory info =
            IGroupChatPluginView(CHAT).chatInfo(chatGroupId);
        address delegate_ = IGroupChatPluginView(CHAT).delegateOf(chatGroupId);
        if (msg.sender != info.owner && msg.sender != delegate_) {
            revert UnauthorizedPluginManager();
        }
        configValue[chatGroupId] = value;
    }
}
