// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

interface IGroupChatErrors {
    error GroupNotExist();
    error ChatAlreadyActivated();
    error ChatNotActivated();
    error PostingNotAllowed();
    error PostingAllowedUnchanged();
    error NotChatOwner();
    error NotChatOwnerOrDelegateIdOwner();
    error SenderAddressNotSenderIdOwner();
    error RoundNotStarted();
    error PhaseBlocksZero();
    error MetaKeyEmpty();
    error TooManyMetaKeys(uint256 length, uint256 maxLength);
    error MetaValueTooLong(uint256 length, uint256 maxLength);
    error MetaArrayLengthMismatch();
    error DuplicateMetaKey();
    error MetaValueUnchanged();
    error MetaKeyNotFound();
    error DelegateIdCannotBeGroupId();
    error DelegateIdUnchanged();
    error SourceAddressHasNoCode();
    error SourceAddressUnchanged();
    error PluginAddressHasNoCode();
    error PluginAddressUnchanged();
    error ContentEmpty();
    error ContentTooLong(uint256 length, uint256 maxLength);
    error TooManyMentionedSenderIds(uint256 length, uint256 maxLength);
    error DuplicateMentionedSenderId();
    error InvalidQuotedMessageId();
    error InvalidMessageId();
    error DefaultGroupIdNotSet();
    error GroupDefaultsHasNoCode();
    error ScopeRejected();
    error DenyRejected();
    error ScopeSourceFailed();
    error DenySourceFailed();
}

interface IGroupChatEvents {
    event Activate(uint256 indexed groupId, address indexed owner, uint256 configVersion);

    event PostingAllowedSet(
        uint256 indexed groupId, address indexed operator, uint256 configVersion, bool postingAllowed
    );

    event MetaSet(
        uint256 indexed groupId,
        address indexed operator,
        uint256 configVersion,
        string key,
        bytes value,
        bytes prevValue
    );

    event DelegateIdSet(
        uint256 indexed groupId,
        address indexed owner,
        uint256 indexed delegateId,
        uint256 configVersion,
        uint256 prevDelegateId
    );

    event ScopeSourceSet(
        uint256 indexed groupId,
        address indexed sourceAddress,
        address indexed operator,
        uint256 configVersion,
        address prevSourceAddress
    );

    event DenySourceSet(
        uint256 indexed groupId,
        address indexed sourceAddress,
        address indexed operator,
        uint256 configVersion,
        address prevSourceAddress
    );

    event BeforePostPluginSet(
        uint256 indexed groupId,
        address indexed pluginAddress,
        address indexed operator,
        uint256 configVersion,
        address prevPluginAddress
    );

    event AfterPostPluginSet(
        uint256 indexed groupId,
        address indexed pluginAddress,
        address indexed operator,
        uint256 configVersion,
        address prevPluginAddress
    );

    event MessagePost(
        uint256 indexed groupId,
        uint256 indexed senderId,
        address indexed senderAddress,
        uint256 round,
        uint256 messageId
    );

    event MessageMention(uint256 indexed groupId, uint256 indexed mentionedSenderId, uint256 messageId);

    event MessageMentionAll(uint256 indexed groupId, uint256 messageId);

    event AfterPostPluginFailed(
        uint256 indexed groupId,
        uint256 indexed messageId,
        address indexed pluginAddress,
        uint256 round,
        bytes errorData
    );
}

interface IGroupChat is IGroupChatErrors, IGroupChatEvents {
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

    struct Message {
        uint256 groupId;
        uint256 senderId;
        address senderAddress;
        uint256 round;
        uint256 messageId;
        string content;
        uint256 blockNumber;
        uint256 timestamp;
        uint256[] mentionedSenderIds;
        bool mentionAll;
        uint256 quotedMessageId;
    }

    struct RoundSpan {
        uint256 round;
        uint256 startMessageId;
        uint256 endMessageId;
        uint256 messageCount;
    }

    function GROUP_ADDRESS() external view returns (address);

    function GROUP_DEFAULTS_ADDRESS() external view returns (address);

    function originBlocks() external view returns (uint256);

    function phaseBlocks() external view returns (uint256);

    function MAX_CONTENT_LENGTH() external view returns (uint256);

    function MAX_MENTIONED_SENDER_IDS() external view returns (uint256);

    function MAX_META_KEYS() external view returns (uint256);

    function MAX_META_VALUE_LENGTH() external view returns (uint256);

    function activateChat(
        uint256 groupId,
        string[] calldata metaKeys,
        bytes[] calldata metaValues,
        address scopeSource_,
        address denySource_,
        address beforePostPlugin_,
        address afterPostPlugin_,
        uint256 delegateId_
    ) external;

    function setPostingAllowed(uint256 groupId, bool postingAllowed_) external;

    function setMeta(uint256 groupId, string calldata key, bytes calldata value) external;

    function setMetaBatch(uint256 groupId, string[] calldata keys, bytes[] calldata values) external;

    function setDelegateId(uint256 groupId, uint256 delegateId_) external;

    function setScopeSource(uint256 groupId, address sourceAddress) external;

    function setDenySource(uint256 groupId, address sourceAddress) external;

    function setBeforePostPlugin(uint256 groupId, address pluginAddress) external;

    function setAfterPostPlugin(uint256 groupId, address pluginAddress) external;

    function post(
        uint256 groupId,
        uint256 senderId,
        string calldata content,
        uint256[] calldata mentionedSenderIds,
        bool mentionAll,
        uint256 quotedMessageId
    ) external;

    function postAsDefaultSender(
        uint256 groupId,
        string calldata content,
        uint256[] calldata mentionedSenderIds,
        bool mentionAll,
        uint256 quotedMessageId
    ) external;

    function chatInfo(uint256 groupId) external view returns (ChatInfo memory);

    function metaValue(uint256 groupId, string calldata key) external view returns (bytes memory);

    function metaEntriesCount(uint256 groupId) external view returns (uint256);

    function metaEntries(uint256 groupId, uint256 offset, uint256 limit, bool reverse)
        external
        view
        returns (string[] memory keys, bytes[] memory values);

    function delegateIdOf(uint256 groupId) external view returns (uint256);

    function postingAllowed(uint256 groupId) external view returns (bool);

    function scopeSource(uint256 groupId) external view returns (address);

    function denySource(uint256 groupId) external view returns (address);

    function beforePostPlugin(uint256 groupId) external view returns (address);

    function afterPostPlugin(uint256 groupId) external view returns (address);

    function canPost(uint256 groupId, uint256 senderId, address senderAddress)
        external
        view
        returns (bool allowed, bytes4 reasonCode);

    function messagesCount(uint256 groupId) external view returns (uint256);

    function messages(uint256 groupId, uint256 offset, uint256 limit, bool reverse)
        external
        view
        returns (Message[] memory);

    function message(uint256 groupId, uint256 messageId) external view returns (Message memory);

    function messagesByRoundCount(uint256 groupId, uint256 round) external view returns (uint256);

    function messagesByRound(uint256 groupId, uint256 round, uint256 offset, uint256 limit, bool reverse)
        external
        view
        returns (Message[] memory);

    function messagesBySenderCount(uint256 groupId, uint256 senderId) external view returns (uint256);

    function messagesBySender(uint256 groupId, uint256 senderId, uint256 offset, uint256 limit, bool reverse)
        external
        view
        returns (Message[] memory);

    function messageIdsBySender(uint256 groupId, uint256 senderId, uint256 offset, uint256 limit, bool reverse)
        external
        view
        returns (uint256[] memory);

    function messagesByMentionCount(uint256 groupId, uint256 mentionedSenderId) external view returns (uint256);

    function messagesByMention(uint256 groupId, uint256 mentionedSenderId, uint256 offset, uint256 limit, bool reverse)
        external
        view
        returns (Message[] memory);

    function messageIdsByMention(
        uint256 groupId,
        uint256 mentionedSenderId,
        uint256 offset,
        uint256 limit,
        bool reverse
    ) external view returns (uint256[] memory);

    function messagesByMentionAllCount(uint256 groupId) external view returns (uint256);

    function messagesByMentionAll(uint256 groupId, uint256 offset, uint256 limit, bool reverse)
        external
        view
        returns (Message[] memory);

    function messageIdsByMentionAll(uint256 groupId, uint256 offset, uint256 limit, bool reverse)
        external
        view
        returns (uint256[] memory);

    function senderIdsCount(uint256 groupId) external view returns (uint256);

    function senderIds(uint256 groupId, uint256 offset, uint256 limit, bool reverse)
        external
        view
        returns (uint256[] memory);

    function groupIdsCount() external view returns (uint256);

    function groupIds(uint256 offset, uint256 limit, bool reverse) external view returns (uint256[] memory);

    function currentRound() external view returns (uint256);

    function roundsCount(uint256 groupId) external view returns (uint256);

    function rounds(uint256 groupId, uint256 offset, uint256 limit, bool reverse)
        external
        view
        returns (RoundSpan[] memory);

    function roundInfo(uint256 groupId, uint256 round) external view returns (RoundSpan memory);

    function roundInfos(uint256 groupId, uint256[] calldata rounds) external view returns (RoundSpan[] memory);
}
