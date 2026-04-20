// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

interface IGroupChatStructs {
    struct ChatInfo {
        uint256 groupId;
        address owner;
        bool active;
        uint256 configVersion;
        address firstActivatedOwner;
        uint256 firstActivatedBlockNumber;
        uint256 firstActivatedTimestamp;
    }

    struct Message {
        uint256 chatGroupId;
        uint256 senderGroupId;
        address senderAddress;
        uint256 round;
        uint256 messageIndex;
        string content;
        uint256 blockNumber;
        uint256 timestamp;
    }

    struct RoundSpan {
        uint256 round;
        uint256 startIndex;
        uint256 endIndex;
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
    error NotChatOwnerOrDelegateGroupOwner();
    error SenderNotGroupOwner();
    error RoundNotStarted();
    error MetaKeyEmpty();
    error MetaArrayLengthMismatch();
    error DuplicateMetaKey();
    error MetaValueUnchanged();
    error MetaKeyNotFound();
    error DelegateGroupIdCannotBeChatGroupId();
    error DelegateGroupIdUnchanged();
    error PluginAddressHasNoCode();
    error PluginAddressUnchanged();
    error ContentEmpty();
    error ContentTooLong(uint256 length, uint256 maxLength);
}

interface IGroupChatEvents {
    event ChatActivate(
        uint256 indexed groupId,
        address indexed owner,
        uint256 configVersion
    );

    event ChatDeactivate(
        uint256 indexed groupId,
        address indexed owner,
        uint256 configVersion
    );

    event MetaSet(
        uint256 indexed groupId,
        address indexed operator,
        uint256 configVersion,
        string key,
        bytes value,
        bytes prevValue
    );

    event DelegateGroupIdSet(
        uint256 indexed groupId,
        address indexed owner,
        uint256 indexed delegateGroupId,
        uint256 configVersion,
        uint256 prevDelegateGroupId
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
        uint256 indexed chatGroupId,
        uint256 indexed senderGroupId,
        address indexed senderAddress,
        uint256 configVersion,
        uint256 round,
        uint256 messageIndex
    );

    event AfterPostPluginFailed(
        uint256 indexed chatGroupId,
        uint256 indexed messageIndex,
        address indexed pluginAddress,
        uint256 configVersion,
        uint256 round,
        bytes errorData
    );
}

interface IGroupChat is
    IGroupChatStructs,
    IGroupChatErrors,
    IGroupChatEvents
{
    function LOVE20_GROUP() external view returns (address);

    function originBlocks() external view returns (uint256);

    function phaseBlocks() external view returns (uint256);

    function MAX_CONTENT_LENGTH() external view returns (uint256);

    function activateChat(
        uint256 groupId,
        string[] calldata metaKeys,
        bytes[] calldata metaValues,
        address beforePostPlugin_,
        address afterPostPlugin_,
        uint256 delegateGroupId_
    ) external;

    function deactivateChat(uint256 groupId) external;

    function setMeta(
        uint256 groupId,
        string calldata key,
        bytes calldata value
    ) external;

    function setMetaBatch(
        uint256 groupId,
        string[] calldata keys,
        bytes[] calldata values
    ) external;

    function setDelegateGroupId(
        uint256 groupId,
        uint256 delegateGroupId_
    ) external;

    function setBeforePostPlugin(
        uint256 groupId,
        address pluginAddress
    ) external;

    function setAfterPostPlugin(
        uint256 groupId,
        address pluginAddress
    ) external;

    function post(
        uint256 chatGroupId,
        uint256 senderGroupId,
        string calldata content
    ) external;

    function chatInfo(uint256 groupId) external view returns (ChatInfo memory);

    function metaValue(
        uint256 groupId,
        string calldata key
    ) external view returns (bytes memory);

    function metaEntries(
        uint256 groupId,
        uint256 offset,
        uint256 limit,
        bool reverse
    ) external view returns (MetaEntry[] memory);

    function delegateGroupIdOf(uint256 groupId) external view returns (uint256);

    function beforePostPlugin(uint256 groupId) external view returns (address);

    function afterPostPlugin(uint256 groupId) external view returns (address);

    function currentRound() external view returns (uint256);

    function messagesCount(uint256 chatGroupId) external view returns (uint256);

    function messagesByRoundCount(
        uint256 chatGroupId,
        uint256 round
    ) external view returns (uint256);

    function messagesBySenderCount(
        uint256 chatGroupId,
        uint256 senderGroupId
    ) external view returns (uint256);

    function senderGroupIdsCount(
        uint256 chatGroupId
    ) external view returns (uint256);

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
        uint256 senderGroupId,
        uint256 offset,
        uint256 limit,
        bool reverse
    ) external view returns (Message[] memory);

    function messageIndexesBySender(
        uint256 chatGroupId,
        uint256 senderGroupId,
        uint256 offset,
        uint256 limit,
        bool reverse
    ) external view returns (uint256[] memory);

    function senderGroupIds(
        uint256 chatGroupId,
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
}
