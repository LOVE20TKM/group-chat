// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

interface IGroupChatPluginView {
    struct ChatInfo {
        uint256 groupId;
        address owner;
        bool activated;
        bool postingAllowed;
        uint256 configVersion;
        uint256 delegateId;
        address scopeSource;
        address denySource;
        address beforePostPlugin;
        address afterPostPlugin;
        address firstActivatedOwner;
        uint256 firstActivatedBlockNumber;
        uint256 firstActivatedTimestamp;
    }

    function chatInfo(uint256 groupId) external view returns (ChatInfo memory);

    function delegateIdOf(uint256 groupId) external view returns (uint256);

    function post(
        uint256 groupId,
        uint256 senderId,
        string calldata content,
        uint256[] calldata mentionedSenderIds,
        bool mentionAll,
        uint256 quotedMessageId
    ) external;

    function setMeta(uint256 groupId, string calldata key, bytes calldata value) external;
}

contract MockBeforePostRejectPlugin {
    error BeforePostRejected();

    function beforePost(uint256, uint256, address, string calldata, uint256[] calldata, bool, uint256) external pure {
        revert BeforePostRejected();
    }
}

contract MockBeforePostCapturePlugin {
    uint256 public lastGroupId;
    uint256 public lastSenderId;
    address public lastSenderAddress;
    string public lastContent;
    bool public lastMentionAll;
    uint256 public lastQuotedMessageId;
    uint256[] internal _lastMentionedSenderIds;

    function beforePost(
        uint256 groupId,
        uint256 senderId,
        address senderAddress,
        string calldata content,
        uint256[] calldata mentionedSenderIds,
        bool mentionAll,
        uint256 quotedMessageId
    ) external {
        lastGroupId = groupId;
        lastSenderId = senderId;
        lastSenderAddress = senderAddress;
        lastContent = content;
        lastMentionAll = mentionAll;
        lastQuotedMessageId = quotedMessageId;
        delete _lastMentionedSenderIds;
        for (uint256 i = 0; i < mentionedSenderIds.length; i++) {
            _lastMentionedSenderIds.push(mentionedSenderIds[i]);
        }
    }

    function lastMentionedSenderIds() external view returns (uint256[] memory) {
        return _lastMentionedSenderIds;
    }
}

contract MockBeforePostRejectMentionAllPlugin {
    error MentionAllRejected();

    function beforePost(uint256, uint256, address, string calldata, uint256[] calldata, bool mentionAll, uint256)
        external
        pure
    {
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

    function canPost(uint256, uint256, address) external view returns (bool) {
        return allowed;
    }
}

contract MockPostScopeFailSource {
    error ScopeSourceBoom();

    function canPost(uint256, uint256, address) external pure returns (bool) {
        revert ScopeSourceBoom();
    }
}

contract MockPostDenySource {
    bool public denied;

    function setDenied(bool denied_) external {
        denied = denied_;
    }

    function isDenied(uint256, uint256, address) external view returns (bool) {
        return denied;
    }
}

contract MockPostDenyFailSource {
    error DenySourceBoom();

    function isDenied(uint256, uint256, address) external pure returns (bool) {
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
    uint256 public lastGroupId;
    uint256 public lastSenderId;
    address public lastSenderAddress;
    string public lastContent;
    bool public lastMentionAll;
    uint256 public lastQuotedMessageId;
    uint256 public lastMessageId;
    uint256 public lastBlockNumber;
    uint256 public lastTimestamp;
    uint256[] internal _lastMentionedSenderIds;

    function afterPost(
        uint256 groupId,
        uint256 senderId,
        address senderAddress,
        string calldata content,
        uint256[] calldata mentionedSenderIds,
        bool mentionAll,
        uint256 quotedMessageId,
        uint256 messageId,
        uint256 blockNumber,
        uint256 timestamp
    ) external {
        lastGroupId = groupId;
        lastSenderId = senderId;
        lastSenderAddress = senderAddress;
        lastContent = content;
        lastMentionAll = mentionAll;
        lastQuotedMessageId = quotedMessageId;
        lastMessageId = messageId;
        lastBlockNumber = blockNumber;
        lastTimestamp = timestamp;
        delete _lastMentionedSenderIds;
        for (uint256 i = 0; i < mentionedSenderIds.length; i++) {
            _lastMentionedSenderIds.push(mentionedSenderIds[i]);
        }
    }

    function lastMentionedSenderIds() external view returns (uint256[] memory) {
        return _lastMentionedSenderIds;
    }
}

contract MockAfterPostReenterPlugin {
    IGroupChatPluginView internal immutable _chat;
    uint256 internal immutable _reenterGroupId;
    uint256 internal immutable _reenterSenderId;

    constructor(address chat_, uint256 reenterGroupId_, uint256 reenterSenderId_) {
        _chat = IGroupChatPluginView(chat_);
        _reenterGroupId = reenterGroupId_;
        _reenterSenderId = reenterSenderId_;
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
        uint256[] memory mentionedSenderIds = new uint256[](0);
        _chat.post(_reenterGroupId, _reenterSenderId, "reenter", mentionedSenderIds, false, 0);
    }
}

contract MockAfterPostSetMetaPlugin {
    IGroupChatPluginView internal immutable _chat;

    constructor(address chat_) {
        _chat = IGroupChatPluginView(chat_);
    }

    function afterPost(
        uint256 groupId,
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
        _chat.setMeta(groupId, "hook-write", bytes("1"));
    }
}

contract MockManagedPlugin {
    error UnauthorizedPluginManager();

    address public immutable CHAT_ADDRESS;
    mapping(uint256 => bytes) public configValue;

    constructor(address chat_) {
        CHAT_ADDRESS = chat_;
    }

    function configure(uint256 groupId, bytes calldata value) external {
        IGroupChatPluginView.ChatInfo memory info = IGroupChatPluginView(CHAT_ADDRESS).chatInfo(groupId);
        uint256 delegateId_ = IGroupChatPluginView(CHAT_ADDRESS).delegateIdOf(groupId);
        address delegateIdOwner =
            delegateId_ == 0 ? address(0) : IGroupChatPluginView(CHAT_ADDRESS).chatInfo(delegateId_).owner;
        if (msg.sender != info.owner && msg.sender != delegateIdOwner) {
            revert UnauthorizedPluginManager();
        }
        configValue[groupId] = value;
    }
}
