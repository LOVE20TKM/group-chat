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

    function delegateGroupIdOf(uint256 groupId) external view returns (uint256);

    function post(
        uint256 chatGroupId,
        uint256 senderGroupId,
        string calldata content,
        uint256[] calldata mentions,
        bool mentionAll,
        uint256 quotedMessageIndex
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
        string calldata,
        uint256[] calldata,
        bool,
        uint256
    ) external pure {
        revert BeforePostRejected();
    }
}

contract MockBeforePostCapturePlugin {
    uint256 public lastChatGroupId;
    uint256 public lastSenderGroupId;
    address public lastSenderAddress;
    string public lastContent;
    bool public lastMentionAll;
    uint256 public lastQuotedMessageIndex;
    uint256[] internal _lastMentions;

    function beforePost(
        uint256 chatGroupId,
        uint256 senderGroupId,
        address senderAddress,
        string calldata content,
        uint256[] calldata mentions,
        bool mentionAll,
        uint256 quotedMessageIndex
    ) external {
        lastChatGroupId = chatGroupId;
        lastSenderGroupId = senderGroupId;
        lastSenderAddress = senderAddress;
        lastContent = content;
        lastMentionAll = mentionAll;
        lastQuotedMessageIndex = quotedMessageIndex;
        delete _lastMentions;
        for (uint256 i = 0; i < mentions.length; i++) {
            _lastMentions.push(mentions[i]);
        }
    }

    function lastMentions() external view returns (uint256[] memory) {
        return _lastMentions;
    }
}

contract MockBeforePostRejectMentionAllPlugin {
    error MentionAllRejected();

    function beforePost(
        uint256,
        uint256,
        address,
        string calldata,
        uint256[] calldata,
        bool mentionAll,
        uint256
    ) external pure {
        if (mentionAll) {
            revert MentionAllRejected();
        }
    }
}

contract MockPostScopeSource {
    bool public allowed = true;

    function setAllowed(bool allowed_) external {
        allowed = allowed_;
    }

    function canPost(
        uint256,
        uint256,
        address
    ) external view returns (bool) {
        return allowed;
    }
}

contract MockPostScopeFailSource {
    error ScopeSourceBoom();

    function canPost(
        uint256,
        uint256,
        address
    ) external pure returns (bool) {
        revert ScopeSourceBoom();
    }
}

contract MockPostDenySource {
    bool public denied;

    function setDenied(bool denied_) external {
        denied = denied_;
    }

    function isDenied(
        uint256,
        uint256,
        address
    ) external view returns (bool) {
        return denied;
    }
}

contract MockPostDenyFailSource {
    error DenySourceBoom();

    function isDenied(
        uint256,
        uint256,
        address
    ) external pure returns (bool) {
        revert DenySourceBoom();
    }
}

contract MockAfterPostFailPlugin {
    error AfterPostFailed();

    function afterPost(
        uint256,
        uint256,
        address,
        string calldata,
        uint256[] calldata,
        bool,
        uint256,
        uint256,
        uint256,
        uint256
    ) external pure {
        revert AfterPostFailed();
    }
}

contract MockAfterPostCapturePlugin {
    uint256 public lastChatGroupId;
    uint256 public lastSenderGroupId;
    address public lastSenderAddress;
    string public lastContent;
    bool public lastMentionAll;
    uint256 public lastQuotedMessageIndex;
    uint256 public lastMessageIndex;
    uint256 public lastBlockNumber;
    uint256 public lastTimestamp;
    uint256[] internal _lastMentions;

    function afterPost(
        uint256 chatGroupId,
        uint256 senderGroupId,
        address senderAddress,
        string calldata content,
        uint256[] calldata mentions,
        bool mentionAll,
        uint256 quotedMessageIndex,
        uint256 messageIndex,
        uint256 blockNumber,
        uint256 timestamp
    ) external {
        lastChatGroupId = chatGroupId;
        lastSenderGroupId = senderGroupId;
        lastSenderAddress = senderAddress;
        lastContent = content;
        lastMentionAll = mentionAll;
        lastQuotedMessageIndex = quotedMessageIndex;
        lastMessageIndex = messageIndex;
        lastBlockNumber = blockNumber;
        lastTimestamp = timestamp;
        delete _lastMentions;
        for (uint256 i = 0; i < mentions.length; i++) {
            _lastMentions.push(mentions[i]);
        }
    }

    function lastMentions() external view returns (uint256[] memory) {
        return _lastMentions;
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
        string calldata,
        uint256[] calldata,
        bool,
        uint256,
        uint256,
        uint256,
        uint256
    ) external {
        uint256[] memory mentions = new uint256[](0);
        _chat.post(
            _reenterChatGroupId,
            _reenterSenderGroupId,
            "reenter",
            mentions,
            false,
            0
        );
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
        string calldata,
        uint256[] calldata,
        bool,
        uint256,
        uint256,
        uint256,
        uint256
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
        uint256 delegateGroupId_ =
            IGroupChatPluginView(CHAT).delegateGroupIdOf(chatGroupId);
        address delegateGroupOwner = delegateGroupId_ == 0
            ? address(0)
            : IGroupChatPluginView(CHAT).chatInfo(delegateGroupId_).owner;
        if (msg.sender != info.owner && msg.sender != delegateGroupOwner) {
            revert UnauthorizedPluginManager();
        }
        configValue[chatGroupId] = value;
    }
}
