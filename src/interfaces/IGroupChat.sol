// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

interface IGroupChatStructs {
    struct ChatInfo {
        uint256 chatGroupId;
        address owner;
        bool active;
        uint256 configVersion;
        address firstActivatedOwner;
        uint256 firstActivatedBlockNumber;
        uint256 firstActivatedTimestamp;
    }

    struct Message {
        uint256 chatGroupId;
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

    struct MetaEntry {
        string key;
        bytes value;
    }
}

interface IGroupChatErrors {
    error GroupNotExist();
    error ChatAlreadyActive();
    error ChatAlreadyInactive();
    error ChatNotActive();
    error NotChatOwner();
    error NotChatOwnerOrDelegateIdOwner();
    error SenderAddressNotSenderIdOwner();
    error RoundNotStarted();
    error PhaseBlocksZero();
    error MetaKeyEmpty();
    error MetaArrayLengthMismatch();
    error DuplicateMetaKey();
    error MetaValueUnchanged();
    error MetaKeyNotFound();
    error DelegateIdCannotBeChatGroupId();
    error DelegateIdUnchanged();
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
    event ChatActivate(
        uint256 indexed chatGroupId,
        address indexed owner,
        uint256 configVersion
    );

    event ChatDeactivate(
        uint256 indexed chatGroupId,
        address indexed owner,
        uint256 configVersion
    );

    event MetaSet(
        uint256 indexed chatGroupId,
        address indexed operator,
        uint256 configVersion,
        string key,
        bytes value,
        bytes prevValue
    );

    event DelegateIdSet(
        uint256 indexed chatGroupId,
        address indexed owner,
        uint256 indexed delegateId,
        uint256 configVersion,
        uint256 prevDelegateId
    );

    event ScopeSourceSet(
        uint256 indexed chatGroupId,
        address indexed sourceAddress,
        address indexed operator,
        uint256 configVersion,
        address prevSourceAddress
    );

    event DenySourceSet(
        uint256 indexed chatGroupId,
        address indexed sourceAddress,
        address indexed operator,
        uint256 configVersion,
        address prevSourceAddress
    );

    event BeforePostPluginSet(
        uint256 indexed chatGroupId,
        address indexed pluginAddress,
        address indexed operator,
        uint256 configVersion,
        address prevPluginAddress
    );

    event AfterPostPluginSet(
        uint256 indexed chatGroupId,
        address indexed pluginAddress,
        address indexed operator,
        uint256 configVersion,
        address prevPluginAddress
    );

    event MessagePost(
        uint256 indexed chatGroupId,
        uint256 indexed senderId,
        address indexed senderAddress,
        uint256 round,
        uint256 messageId
    );

    event MessageMention(
        uint256 indexed chatGroupId,
        uint256 indexed mentionedSenderId,
        uint256 messageId
    );

    event MessageMentionAll(uint256 indexed chatGroupId, uint256 messageId);

    event AfterPostPluginFailed(
        uint256 indexed chatGroupId,
        uint256 indexed messageId,
        address indexed pluginAddress,
        uint256 round,
        bytes errorData
    );
}

interface IGroupChat is IGroupChatStructs, IGroupChatErrors, IGroupChatEvents {
    function LOVE20_GROUP_ADDRESS() external view returns (address);

    function GROUP_DEFAULTS_ADDRESS() external view returns (address);

    function originBlocks() external view returns (uint256);

    function phaseBlocks() external view returns (uint256);

    function MAX_CONTENT_LENGTH() external view returns (uint256);

    function MAX_MENTIONED_SENDER_IDS() external view returns (uint256);

    function activateChat(
        uint256 chatGroupId,
        string[] calldata metaKeys,
        bytes[] calldata metaValues,
        address scopeSource_,
        address denySource_,
        address beforePostPlugin_,
        address afterPostPlugin_,
        uint256 delegateId_
    ) external;

    function deactivateChat(uint256 chatGroupId) external;

    function setMeta(
        uint256 chatGroupId,
        string calldata key,
        bytes calldata value
    ) external;

    function setMetaBatch(
        uint256 chatGroupId,
        string[] calldata keys,
        bytes[] calldata values
    ) external;

    function setDelegateId(uint256 chatGroupId, uint256 delegateId_) external;

    function setScopeSource(
        uint256 chatGroupId,
        address sourceAddress
    ) external;

    function setDenySource(uint256 chatGroupId, address sourceAddress) external;

    function setBeforePostPlugin(
        uint256 chatGroupId,
        address pluginAddress
    ) external;

    function setAfterPostPlugin(
        uint256 chatGroupId,
        address pluginAddress
    ) external;

    function post(
        uint256 chatGroupId,
        uint256 senderId,
        string calldata content,
        uint256[] calldata mentionedSenderIds,
        bool mentionAll,
        uint256 quotedMessageId
    ) external;

    function postByDefaultSender(
        uint256 chatGroupId,
        string calldata content,
        uint256[] calldata mentionedSenderIds,
        bool mentionAll,
        uint256 quotedMessageId
    ) external;

    function chatInfo(
        uint256 chatGroupId
    ) external view returns (ChatInfo memory);

    function metaValue(
        uint256 chatGroupId,
        string calldata key
    ) external view returns (bytes memory);

    function metaEntries(
        uint256 chatGroupId,
        uint256 offset,
        uint256 limit,
        bool reverse
    ) external view returns (MetaEntry[] memory);

    function delegateIdOf(uint256 chatGroupId) external view returns (uint256);

    function scopeSource(uint256 chatGroupId) external view returns (address);

    function denySource(uint256 chatGroupId) external view returns (address);

    function beforePostPlugin(
        uint256 chatGroupId
    ) external view returns (address);

    function afterPostPlugin(
        uint256 chatGroupId
    ) external view returns (address);

    function ruleSlots(
        uint256 chatGroupId
    )
        external
        view
        returns (
            address scopeSource_,
            address denySource_,
            address beforePostPlugin_,
            address afterPostPlugin_
        );

    function canPost(
        uint256 chatGroupId,
        uint256 senderId,
        address senderAddress
    ) external view returns (bool);

    function canPostStatus(
        uint256 chatGroupId,
        uint256 senderId,
        address senderAddress
    ) external view returns (bool allowed, bytes4 reasonCode);

    function currentRound() external view returns (uint256);

    function messagesCount(uint256 chatGroupId) external view returns (uint256);

    function message(
        uint256 chatGroupId,
        uint256 messageId
    ) external view returns (Message memory);

    function messagesByRoundCount(
        uint256 chatGroupId,
        uint256 round
    ) external view returns (uint256);

    function messagesBySenderCount(
        uint256 chatGroupId,
        uint256 senderId
    ) external view returns (uint256);

    function senderIdsCount(
        uint256 chatGroupId
    ) external view returns (uint256);

    function chatGroupIdsCount() external view returns (uint256);

    function activeChatGroupIdsCount() external view returns (uint256);

    function messages(
        uint256 chatGroupId,
        uint256 offset,
        uint256 limit,
        bool reverse
    ) external view returns (Message[] memory);

    function messagesByRound(
        uint256 chatGroupId,
        uint256 round,
        uint256 offset,
        uint256 limit,
        bool reverse
    ) external view returns (Message[] memory);

    function messagesBySender(
        uint256 chatGroupId,
        uint256 senderId,
        uint256 offset,
        uint256 limit,
        bool reverse
    ) external view returns (Message[] memory);

    function messageIdsBySender(
        uint256 chatGroupId,
        uint256 senderId,
        uint256 offset,
        uint256 limit,
        bool reverse
    ) external view returns (uint256[] memory);

    function messagesByMentionCount(
        uint256 chatGroupId,
        uint256 mentionedSenderId
    ) external view returns (uint256);

    function messagesByMention(
        uint256 chatGroupId,
        uint256 mentionedSenderId,
        uint256 offset,
        uint256 limit,
        bool reverse
    ) external view returns (Message[] memory);

    function messageIdsByMention(
        uint256 chatGroupId,
        uint256 mentionedSenderId,
        uint256 offset,
        uint256 limit,
        bool reverse
    ) external view returns (uint256[] memory);

    function messagesByMentionAllCount(
        uint256 chatGroupId
    ) external view returns (uint256);

    function messagesByMentionAll(
        uint256 chatGroupId,
        uint256 offset,
        uint256 limit,
        bool reverse
    ) external view returns (Message[] memory);

    function messageIdsByMentionAll(
        uint256 chatGroupId,
        uint256 offset,
        uint256 limit,
        bool reverse
    ) external view returns (uint256[] memory);

    function senderIds(
        uint256 chatGroupId,
        uint256 offset,
        uint256 limit,
        bool reverse
    ) external view returns (uint256[] memory);

    function chatGroupIds(
        uint256 offset,
        uint256 limit,
        bool reverse
    ) external view returns (uint256[] memory);

    function activeChatGroupIds(
        uint256 offset,
        uint256 limit,
        bool reverse
    ) external view returns (uint256[] memory);

    function roundsCount(uint256 chatGroupId) external view returns (uint256);

    function rounds(
        uint256 chatGroupId,
        uint256 offset,
        uint256 limit,
        bool reverse
    ) external view returns (RoundSpan[] memory);

    function roundInfo(
        uint256 chatGroupId,
        uint256 round
    ) external view returns (RoundSpan memory);

    function roundInfos(
        uint256 chatGroupId,
        uint256[] calldata roundIds
    ) external view returns (RoundSpan[] memory);
}
