// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IGroupChat} from "./interfaces/IGroupChat.sol";
import {IBeforePostPlugin} from "./interfaces/IBeforePostPlugin.sol";
import {IAfterPostPlugin} from "./interfaces/IAfterPostPlugin.sol";
import {IGroupDefaults} from "./interfaces/external/IGroupDefaults.sol";
import {ILOVE20Group} from "./interfaces/external/ILOVE20Group.sol";
import {IPostScopeSource} from "./interfaces/IPostScopeSource.sol";
import {IPostDenySource} from "./interfaces/IPostDenySource.sol";

contract GroupChat is IGroupChat {
    uint256 public constant MAX_CONTENT_LENGTH = 16384;
    uint256 public constant MAX_MENTIONS = 32;

    address public immutable LOVE20_GROUP_ADDRESS;
    address public immutable GROUP_DEFAULTS_ADDRESS;
    uint256 public immutable originBlocks;
    uint256 public immutable phaseBlocks;

    struct ChatConfig {
        bool active;
        uint256 configVersion;
        address firstActivatedOwner;
        uint256 firstActivatedBlockNumber;
        uint256 firstActivatedTimestamp;
        uint256 delegateId;
        address delegateOwnerSnapshot;
        address scopeSource;
        address denySource;
        address beforePostPlugin;
        address afterPostPlugin;
    }

    struct MetaState {
        bool exists;
        uint256 index;
        string key;
        bytes value;
    }

    struct RoundState {
        bool exists;
        uint256 startIndex;
        uint256 endIndex;
        uint256 listIndex;
    }

    mapping(uint256 => ChatConfig) internal _chatConfigs;
    mapping(uint256 => mapping(bytes32 => MetaState)) internal _metaStates;
    mapping(uint256 => string[]) internal _metaKeys;
    mapping(uint256 => Message[]) internal _messagesByChat;
    mapping(uint256 => mapping(uint256 => uint256[])) internal _senderMessageIndexes;
    mapping(uint256 => mapping(uint256 => uint256[])) internal _mentionMessageIndexes;
    mapping(uint256 => uint256[]) internal _mentionAllMessageIndexes;
    mapping(uint256 => uint256[]) internal _senderIdsByChat;
    mapping(uint256 => mapping(uint256 => bool)) internal _senderTracked;
    mapping(uint256 => mapping(uint256 => RoundState)) internal _roundStates;
    mapping(uint256 => uint256[]) internal _roundListByChat;
    uint256[] internal _chatGroupIds;
    uint256[] internal _activeChatGroupIds;
    mapping(uint256 => uint256) internal _activeChatGroupIdIndexPlusOne;

    uint256 internal _entered;

    constructor(address groupDefaults_, uint256 originBlocks_, uint256 phaseBlocks_) {
        if (groupDefaults_.code.length == 0) {
            revert GroupDefaultsHasNoCode();
        }
        if (phaseBlocks_ == 0) revert PhaseBlocksZero();
        GROUP_DEFAULTS_ADDRESS = groupDefaults_;
        LOVE20_GROUP_ADDRESS = IGroupDefaults(groupDefaults_).GROUP_ADDRESS();
        originBlocks = originBlocks_;
        phaseBlocks = phaseBlocks_;
    }

    modifier nonReentrant() {
        require(_entered == 0, "REENTRANT");
        _entered = 1;
        _;
        _entered = 0;
    }

    function activateChat(
        uint256 chatGroupId,
        string[] calldata metaKeys_,
        bytes[] calldata metaValues_,
        address scopeSource_,
        address denySource_,
        address beforePostPlugin_,
        address afterPostPlugin_,
        uint256 delegateId_
    ) external nonReentrant {
        address owner = _ownerOfOrRevert(chatGroupId);
        if (msg.sender != owner) revert NotChatOwner();

        ChatConfig storage config = _chatConfigs[chatGroupId];
        if (config.active) revert ChatAlreadyActive();

        bytes32[] memory metaHashes = _validateMetaInput(metaKeys_, metaValues_);
        _validatePluginAddress(scopeSource_);
        _validatePluginAddress(denySource_);
        _validatePluginAddress(beforePostPlugin_);
        _validatePluginAddress(afterPostPlugin_);
        _validateDelegateId(chatGroupId, delegateId_);

        uint256 newVersion = config.configVersion + 1;
        uint256 prevDelegateId = _delegateIdOf(config, owner);

        if (config.firstActivatedOwner == address(0)) {
            config.firstActivatedOwner = owner;
            config.firstActivatedBlockNumber = block.number;
            config.firstActivatedTimestamp = block.timestamp;
            _chatGroupIds.push(chatGroupId);
        }

        config.active = true;
        config.configVersion = newVersion;
        _addActiveChatGroupId(chatGroupId);

        _applyActivateMeta(chatGroupId, metaKeys_, metaValues_, metaHashes, newVersion);
        _applyActivateDelegateId(chatGroupId, config, owner, delegateId_, newVersion, prevDelegateId);
        _applyActivateSource(chatGroupId, config.scopeSource, scopeSource_, newVersion, true);
        _applyActivateSource(chatGroupId, config.denySource, denySource_, newVersion, false);
        _applyActivatePlugin(chatGroupId, config.beforePostPlugin, beforePostPlugin_, newVersion, true);
        _applyActivatePlugin(chatGroupId, config.afterPostPlugin, afterPostPlugin_, newVersion, false);

        config.scopeSource = scopeSource_;
        config.denySource = denySource_;
        config.beforePostPlugin = beforePostPlugin_;
        config.afterPostPlugin = afterPostPlugin_;
        emit ChatActivate(chatGroupId, owner, newVersion);
    }

    function deactivateChat(uint256 chatGroupId) external nonReentrant {
        address owner = _ownerOfOrRevert(chatGroupId);
        if (msg.sender != owner) revert NotChatOwner();

        ChatConfig storage config = _chatConfigs[chatGroupId];
        if (!config.active) revert ChatAlreadyInactive();

        uint256 newVersion = config.configVersion + 1;
        config.active = false;
        config.configVersion = newVersion;
        _removeActiveChatGroupId(chatGroupId);
        emit ChatDeactivate(chatGroupId, owner, newVersion);
    }

    function setMeta(uint256 chatGroupId, string calldata key, bytes calldata value) external nonReentrant {
        _requireOwnerOrDelegateAndActive(chatGroupId);
        _validateMetaKey(key);

        ChatConfig storage config = _chatConfigs[chatGroupId];
        bytes32 hash = _metaHash(key);
        MetaState storage item = _metaStates[chatGroupId][hash];

        if (value.length == 0) {
            if (!item.exists) revert MetaKeyNotFound();
            bytes memory prevValue = item.value;
            _removeMeta(chatGroupId, hash);
            uint256 newVersion = config.configVersion + 1;
            config.configVersion = newVersion;
            emit MetaSet(chatGroupId, msg.sender, newVersion, key, "", prevValue);
            return;
        }

        if (item.exists) {
            if (_bytesEqual(item.value, value)) revert MetaValueUnchanged();
            bytes memory prevValue = item.value;
            item.value = value;
            uint256 newVersion = config.configVersion + 1;
            config.configVersion = newVersion;
            emit MetaSet(chatGroupId, msg.sender, newVersion, key, value, prevValue);
            return;
        }

        _addMeta(chatGroupId, key, value);
        uint256 newVersion2 = config.configVersion + 1;
        config.configVersion = newVersion2;
        emit MetaSet(chatGroupId, msg.sender, newVersion2, key, value, "");
    }

    function setMetaBatch(uint256 chatGroupId, string[] calldata keys, bytes[] calldata values) external nonReentrant {
        _requireOwnerOrDelegateAndActive(chatGroupId);
        if (keys.length != values.length) revert MetaArrayLengthMismatch();
        if (keys.length == 0) {
            return;
        }

        bytes32[] memory hashes = _validateMetaInput(keys, values);
        ChatConfig storage config = _chatConfigs[chatGroupId];

        for (uint256 i = 0; i < keys.length; i++) {
            MetaState storage item = _metaStates[chatGroupId][hashes[i]];
            if (values[i].length == 0) {
                if (!item.exists) revert MetaKeyNotFound();
            } else if (item.exists && _bytesEqual(item.value, values[i])) {
                revert MetaValueUnchanged();
            }
        }

        uint256 newVersion = config.configVersion + 1;
        config.configVersion = newVersion;

        for (uint256 i = 0; i < keys.length; i++) {
            MetaState storage item = _metaStates[chatGroupId][hashes[i]];
            if (values[i].length == 0) {
                bytes memory prevValue = item.value;
                _removeMeta(chatGroupId, hashes[i]);
                emit MetaSet(chatGroupId, msg.sender, newVersion, keys[i], "", prevValue);
            } else if (item.exists) {
                bytes memory prevValue2 = item.value;
                item.value = values[i];
                emit MetaSet(chatGroupId, msg.sender, newVersion, keys[i], values[i], prevValue2);
            } else {
                _addMeta(chatGroupId, keys[i], values[i]);
                emit MetaSet(chatGroupId, msg.sender, newVersion, keys[i], values[i], "");
            }
        }
    }

    function setDelegateId(uint256 chatGroupId, uint256 delegateId_) external nonReentrant {
        address owner = _ownerOfOrRevert(chatGroupId);
        if (msg.sender != owner) revert NotChatOwner();

        ChatConfig storage config = _chatConfigs[chatGroupId];
        if (!config.active) revert ChatNotActive();
        _validateDelegateId(chatGroupId, delegateId_);

        address targetSnapshot = delegateId_ == 0 ? address(0) : owner;
        if (config.delegateId == delegateId_ && config.delegateOwnerSnapshot == targetSnapshot) {
            revert DelegateIdUnchanged();
        }

        uint256 prevDelegateId = _delegateIdOf(config, owner);
        config.delegateId = delegateId_;
        config.delegateOwnerSnapshot = targetSnapshot;

        uint256 newVersion = config.configVersion + 1;
        config.configVersion = newVersion;
        emit DelegateIdSet(chatGroupId, owner, delegateId_, newVersion, prevDelegateId);
    }

    function setScopeSource(uint256 chatGroupId, address sourceAddress) external nonReentrant {
        _requireOwnerOrDelegateAndActive(chatGroupId);
        _validatePluginAddress(sourceAddress);

        ChatConfig storage config = _chatConfigs[chatGroupId];
        if (config.scopeSource == sourceAddress) revert PluginAddressUnchanged();

        address prevSourceAddress = config.scopeSource;
        config.scopeSource = sourceAddress;

        uint256 newVersion = config.configVersion + 1;
        config.configVersion = newVersion;
        emit ScopeSourceSet(chatGroupId, sourceAddress, msg.sender, newVersion, prevSourceAddress);
    }

    function setDenySource(uint256 chatGroupId, address sourceAddress) external nonReentrant {
        _requireOwnerOrDelegateAndActive(chatGroupId);
        _validatePluginAddress(sourceAddress);

        ChatConfig storage config = _chatConfigs[chatGroupId];
        if (config.denySource == sourceAddress) revert PluginAddressUnchanged();

        address prevSourceAddress = config.denySource;
        config.denySource = sourceAddress;

        uint256 newVersion = config.configVersion + 1;
        config.configVersion = newVersion;
        emit DenySourceSet(chatGroupId, sourceAddress, msg.sender, newVersion, prevSourceAddress);
    }

    function setBeforePostPlugin(uint256 chatGroupId, address pluginAddress) external nonReentrant {
        _requireOwnerOrDelegateAndActive(chatGroupId);
        _validatePluginAddress(pluginAddress);

        ChatConfig storage config = _chatConfigs[chatGroupId];
        if (config.beforePostPlugin == pluginAddress) revert PluginAddressUnchanged();

        address prevPluginAddress = config.beforePostPlugin;
        config.beforePostPlugin = pluginAddress;

        uint256 newVersion = config.configVersion + 1;
        config.configVersion = newVersion;
        emit BeforePostPluginSet(chatGroupId, pluginAddress, msg.sender, newVersion, prevPluginAddress);
    }

    function setAfterPostPlugin(uint256 chatGroupId, address pluginAddress) external nonReentrant {
        _requireOwnerOrDelegateAndActive(chatGroupId);
        _validatePluginAddress(pluginAddress);

        ChatConfig storage config = _chatConfigs[chatGroupId];
        if (config.afterPostPlugin == pluginAddress) revert PluginAddressUnchanged();

        address prevPluginAddress = config.afterPostPlugin;
        config.afterPostPlugin = pluginAddress;

        uint256 newVersion = config.configVersion + 1;
        config.configVersion = newVersion;
        emit AfterPostPluginSet(chatGroupId, pluginAddress, msg.sender, newVersion, prevPluginAddress);
    }

    function post(
        uint256 chatGroupId,
        uint256 senderId,
        string calldata content,
        uint256[] calldata mentions,
        bool mentionAll,
        uint256 quotedMessageId
    ) external nonReentrant {
        _post(chatGroupId, senderId, content, mentions, mentionAll, quotedMessageId);
    }

    function postByDefaultSender(
        uint256 chatGroupId,
        string calldata content,
        uint256[] calldata mentions,
        bool mentionAll,
        uint256 quotedMessageId
    ) external nonReentrant {
        uint256 senderId = IGroupDefaults(GROUP_DEFAULTS_ADDRESS).defaultGroupIdOf(msg.sender);
        if (senderId == 0) revert DefaultGroupIdNotSet();
        _post(chatGroupId, senderId, content, mentions, mentionAll, quotedMessageId);
    }

    function _post(
        uint256 chatGroupId,
        uint256 senderId,
        string calldata content,
        uint256[] calldata mentions,
        bool mentionAll,
        uint256 quotedMessageId
    ) internal {
        _requireExistingGroup(chatGroupId);
        ChatConfig storage config = _chatConfigs[chatGroupId];
        if (!config.active) revert ChatNotActive();

        address senderOwner = _ownerOfOrRevert(senderId);
        if (msg.sender != senderOwner) revert SenderAddressNotSenderIdOwner();

        uint256 contentLength = bytes(content).length;
        if (contentLength == 0) revert ContentEmpty();
        if (contentLength > MAX_CONTENT_LENGTH) {
            revert ContentTooLong(contentLength, MAX_CONTENT_LENGTH);
        }
        _validateMentions(mentions);
        _validateQuotedMessageId(chatGroupId, quotedMessageId);

        uint256 round = currentRound();
        _requirePostSources(config, chatGroupId, senderId, msg.sender);
        if (config.beforePostPlugin != address(0)) {
            IBeforePostPlugin(config.beforePostPlugin).beforePost(
                chatGroupId, senderId, msg.sender, content, mentions, mentionAll, quotedMessageId
            );
        }

        uint256 messageIndex =
            _storeMessage(chatGroupId, senderId, round, content, mentions, mentionAll, quotedMessageId);

        _senderMessageIndexes[chatGroupId][senderId].push(messageIndex);
        if (!_senderTracked[chatGroupId][senderId]) {
            _senderTracked[chatGroupId][senderId] = true;
            _senderIdsByChat[chatGroupId].push(senderId);
        }

        _recordRound(chatGroupId, round, messageIndex);

        emit MessagePost(chatGroupId, senderId, msg.sender, round, messageIndex + 1);

        if (config.afterPostPlugin != address(0)) {
            try IAfterPostPlugin(config.afterPostPlugin).afterPost(
                chatGroupId,
                senderId,
                msg.sender,
                content,
                mentions,
                mentionAll,
                quotedMessageId,
                messageIndex + 1,
                block.number,
                block.timestamp
            ) {} catch (bytes memory err) {
                emit AfterPostPluginFailed(chatGroupId, messageIndex + 1, config.afterPostPlugin, round, err);
            }
        }
    }

    function chatInfo(uint256 chatGroupId) external view returns (ChatInfo memory) {
        address owner = _ownerOfOrRevert(chatGroupId);
        ChatConfig storage config = _chatConfigs[chatGroupId];
        return ChatInfo({
            chatGroupId: chatGroupId,
            owner: owner,
            active: config.active,
            configVersion: config.configVersion,
            firstActivatedOwner: config.firstActivatedOwner,
            firstActivatedBlockNumber: config.firstActivatedBlockNumber,
            firstActivatedTimestamp: config.firstActivatedTimestamp
        });
    }

    function metaValue(uint256 chatGroupId, string calldata key) external view returns (bytes memory) {
        _requireExistingGroup(chatGroupId);
        return _metaStates[chatGroupId][_metaHash(key)].value;
    }

    function metaEntries(uint256 chatGroupId, uint256 offset, uint256 limit, bool reverse)
        external
        view
        returns (MetaEntry[] memory)
    {
        _requireExistingGroup(chatGroupId);
        string[] storage keys = _metaKeys[chatGroupId];
        uint256 count = _pageCount(keys.length, offset, limit);
        MetaEntry[] memory result = new MetaEntry[](count);

        for (uint256 i = 0; i < count; i++) {
            uint256 idx = _pageIndex(keys.length, offset, i, reverse);
            string storage key = keys[idx];
            result[i] = MetaEntry({key: key, value: _metaStates[chatGroupId][_metaHash(key)].value});
        }

        return result;
    }

    function delegateIdOf(uint256 chatGroupId) external view returns (uint256) {
        address owner = _ownerOfOrRevert(chatGroupId);
        return _delegateIdOf(_chatConfigs[chatGroupId], owner);
    }

    function scopeSource(uint256 chatGroupId) external view returns (address) {
        _requireExistingGroup(chatGroupId);
        return _chatConfigs[chatGroupId].scopeSource;
    }

    function denySource(uint256 chatGroupId) external view returns (address) {
        _requireExistingGroup(chatGroupId);
        return _chatConfigs[chatGroupId].denySource;
    }

    function beforePostPlugin(uint256 chatGroupId) external view returns (address) {
        _requireExistingGroup(chatGroupId);
        return _chatConfigs[chatGroupId].beforePostPlugin;
    }

    function afterPostPlugin(uint256 chatGroupId) external view returns (address) {
        _requireExistingGroup(chatGroupId);
        return _chatConfigs[chatGroupId].afterPostPlugin;
    }

    function ruleSlots(uint256 chatGroupId)
        external
        view
        returns (
            address scopeSource_,
            address denySource_,
            address beforePostPlugin_,
            address afterPostPlugin_
        )
    {
        _requireExistingGroup(chatGroupId);
        ChatConfig storage config = _chatConfigs[chatGroupId];
        return (config.scopeSource, config.denySource, config.beforePostPlugin, config.afterPostPlugin);
    }

    function canPost(uint256 chatGroupId, uint256 senderId, address senderAddress) external view returns (bool) {
        (bool allowed,) = _canPostStatus(chatGroupId, senderId, senderAddress);
        return allowed;
    }

    function canPostStatus(uint256 chatGroupId, uint256 senderId, address senderAddress)
        external
        view
        returns (bool allowed, bytes4 reasonCode)
    {
        return _canPostStatus(chatGroupId, senderId, senderAddress);
    }

    function currentRound() public view returns (uint256) {
        if (block.number < originBlocks) revert RoundNotStarted();
        return (block.number - originBlocks) / phaseBlocks;
    }

    function messagesCount(uint256 chatGroupId) external view returns (uint256) {
        _requireExistingGroup(chatGroupId);
        return _messagesByChat[chatGroupId].length;
    }

    function message(uint256 chatGroupId, uint256 messageId) external view returns (Message memory) {
        _requireExistingGroup(chatGroupId);
        if (messageId == 0 || messageId > _messagesByChat[chatGroupId].length) {
            revert InvalidMessageId();
        }
        return _copyMessage(_messagesByChat[chatGroupId][messageId - 1]);
    }

    function messagesByRoundCount(uint256 chatGroupId, uint256 round) external view returns (uint256) {
        _requireExistingGroup(chatGroupId);
        RoundState storage state = _roundStates[chatGroupId][round];
        if (!state.exists) {
            return 0;
        }
        return state.endIndex - state.startIndex;
    }

    function messagesBySenderCount(uint256 chatGroupId, uint256 senderId) external view returns (uint256) {
        _requireExistingGroup(chatGroupId);
        return _senderMessageIndexes[chatGroupId][senderId].length;
    }

    function senderIdsCount(uint256 chatGroupId) external view returns (uint256) {
        _requireExistingGroup(chatGroupId);
        return _senderIdsByChat[chatGroupId].length;
    }

    function chatGroupIdsCount() external view returns (uint256) {
        return _chatGroupIds.length;
    }

    function activeChatGroupIdsCount() external view returns (uint256) {
        return _activeChatGroupIds.length;
    }

    function messages(uint256 chatGroupId, uint256 offset, uint256 limit, bool reverse)
        external
        view
        returns (Message[] memory)
    {
        _requireExistingGroup(chatGroupId);
        Message[] storage source = _messagesByChat[chatGroupId];
        uint256 count = _pageCount(source.length, offset, limit);
        Message[] memory result = new Message[](count);

        for (uint256 i = 0; i < count; i++) {
            result[i] = _copyMessage(source[_pageIndex(source.length, offset, i, reverse)]);
        }

        return result;
    }

    function messagesByRound(uint256 chatGroupId, uint256 round, uint256 offset, uint256 limit, bool reverse)
        external
        view
        returns (Message[] memory)
    {
        _requireExistingGroup(chatGroupId);
        RoundState storage state = _roundStates[chatGroupId][round];
        if (!state.exists) {
            return new Message[](0);
        }

        uint256 total = state.endIndex - state.startIndex;
        uint256 count = _pageCount(total, offset, limit);
        Message[] memory result = new Message[](count);

        for (uint256 i = 0; i < count; i++) {
            uint256 localIndex = _pageIndex(total, offset, i, reverse);
            result[i] = _copyMessage(_messagesByChat[chatGroupId][state.startIndex + localIndex]);
        }

        return result;
    }

    function messagesBySender(uint256 chatGroupId, uint256 senderId, uint256 offset, uint256 limit, bool reverse)
        external
        view
        returns (Message[] memory)
    {
        _requireExistingGroup(chatGroupId);
        uint256[] storage indexes = _senderMessageIndexes[chatGroupId][senderId];
        uint256 count = _pageCount(indexes.length, offset, limit);
        Message[] memory result = new Message[](count);

        for (uint256 i = 0; i < count; i++) {
            uint256 pageIdx = _pageIndex(indexes.length, offset, i, reverse);
            result[i] = _copyMessage(_messagesByChat[chatGroupId][indexes[pageIdx]]);
        }

        return result;
    }

    function messageIdsBySender(
        uint256 chatGroupId,
        uint256 senderId,
        uint256 offset,
        uint256 limit,
        bool reverse
    ) external view returns (uint256[] memory) {
        _requireExistingGroup(chatGroupId);
        uint256[] storage indexes = _senderMessageIndexes[chatGroupId][senderId];
        uint256 count = _pageCount(indexes.length, offset, limit);
        uint256[] memory result = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            result[i] = indexes[_pageIndex(indexes.length, offset, i, reverse)] + 1;
        }

        return result;
    }

    function messagesByMentionCount(uint256 chatGroupId, uint256 mentionedSenderId) external view returns (uint256) {
        _requireExistingGroup(chatGroupId);
        return _mentionMessageIndexes[chatGroupId][mentionedSenderId].length;
    }

    function messagesByMention(
        uint256 chatGroupId,
        uint256 mentionedSenderId,
        uint256 offset,
        uint256 limit,
        bool reverse
    ) external view returns (Message[] memory) {
        _requireExistingGroup(chatGroupId);
        uint256[] storage indexes = _mentionMessageIndexes[chatGroupId][mentionedSenderId];
        uint256 count = _pageCount(indexes.length, offset, limit);
        Message[] memory result = new Message[](count);

        for (uint256 i = 0; i < count; i++) {
            uint256 pageIdx = _pageIndex(indexes.length, offset, i, reverse);
            result[i] = _copyMessage(_messagesByChat[chatGroupId][indexes[pageIdx]]);
        }

        return result;
    }

    function messageIdsByMention(
        uint256 chatGroupId,
        uint256 mentionedSenderId,
        uint256 offset,
        uint256 limit,
        bool reverse
    ) external view returns (uint256[] memory) {
        _requireExistingGroup(chatGroupId);
        uint256[] storage indexes = _mentionMessageIndexes[chatGroupId][mentionedSenderId];
        uint256 count = _pageCount(indexes.length, offset, limit);
        uint256[] memory result = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            result[i] = indexes[_pageIndex(indexes.length, offset, i, reverse)] + 1;
        }

        return result;
    }

    function messagesByMentionAllCount(uint256 chatGroupId) external view returns (uint256) {
        _requireExistingGroup(chatGroupId);
        return _mentionAllMessageIndexes[chatGroupId].length;
    }

    function messagesByMentionAll(uint256 chatGroupId, uint256 offset, uint256 limit, bool reverse)
        external
        view
        returns (Message[] memory)
    {
        _requireExistingGroup(chatGroupId);
        uint256[] storage indexes = _mentionAllMessageIndexes[chatGroupId];
        uint256 count = _pageCount(indexes.length, offset, limit);
        Message[] memory result = new Message[](count);

        for (uint256 i = 0; i < count; i++) {
            uint256 pageIdx = _pageIndex(indexes.length, offset, i, reverse);
            result[i] = _copyMessage(_messagesByChat[chatGroupId][indexes[pageIdx]]);
        }

        return result;
    }

    function messageIdsByMentionAll(uint256 chatGroupId, uint256 offset, uint256 limit, bool reverse)
        external
        view
        returns (uint256[] memory)
    {
        _requireExistingGroup(chatGroupId);
        uint256[] storage indexes = _mentionAllMessageIndexes[chatGroupId];
        uint256 count = _pageCount(indexes.length, offset, limit);
        uint256[] memory result = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            result[i] = indexes[_pageIndex(indexes.length, offset, i, reverse)] + 1;
        }

        return result;
    }

    function senderIds(uint256 chatGroupId, uint256 offset, uint256 limit, bool reverse)
        external
        view
        returns (uint256[] memory)
    {
        _requireExistingGroup(chatGroupId);
        uint256[] storage senders = _senderIdsByChat[chatGroupId];
        uint256 count = _pageCount(senders.length, offset, limit);
        uint256[] memory result = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            result[i] = senders[_pageIndex(senders.length, offset, i, reverse)];
        }

        return result;
    }

    function chatGroupIds(uint256 offset, uint256 limit, bool reverse) external view returns (uint256[] memory) {
        return _uint256Page(_chatGroupIds, offset, limit, reverse);
    }

    function activeChatGroupIds(uint256 offset, uint256 limit, bool reverse)
        external
        view
        returns (uint256[] memory)
    {
        return _uint256Page(_activeChatGroupIds, offset, limit, reverse);
    }

    function roundsCount(uint256 chatGroupId) external view returns (uint256) {
        _requireExistingGroup(chatGroupId);
        return _roundListByChat[chatGroupId].length;
    }

    function rounds(uint256 chatGroupId, uint256 offset, uint256 limit, bool reverse)
        external
        view
        returns (RoundSpan[] memory)
    {
        _requireExistingGroup(chatGroupId);
        uint256[] storage list = _roundListByChat[chatGroupId];
        uint256 count = _pageCount(list.length, offset, limit);
        RoundSpan[] memory result = new RoundSpan[](count);

        for (uint256 i = 0; i < count; i++) {
            uint256 round = list[_pageIndex(list.length, offset, i, reverse)];
            result[i] = _roundSpan(chatGroupId, round);
        }

        return result;
    }

    function roundInfo(uint256 chatGroupId, uint256 round) external view returns (RoundSpan memory) {
        _requireExistingGroup(chatGroupId);
        RoundState storage state = _roundStates[chatGroupId][round];
        if (!state.exists) {
            return RoundSpan(round, 0, 0, 0);
        }
        return _roundSpan(chatGroupId, round);
    }

    function _applyActivateMeta(
        uint256 groupId,
        string[] calldata newKeys,
        bytes[] calldata newValues,
        bytes32[] memory newHashes,
        uint256 newVersion
    ) internal {
        string[] storage existingKeys = _metaKeys[groupId];
        string[] memory deleteKeys = new string[](existingKeys.length);
        uint256 deleteCount;

        for (uint256 i = 0; i < existingKeys.length; i++) {
            string storage key = existingKeys[i];
            bytes32 hash = _metaHash(key);
            if (!_containsNonEmptyHash(newHashes, newValues, hash)) {
                deleteKeys[deleteCount++] = key;
            }
        }

        for (uint256 i = 0; i < deleteCount; i++) {
            bytes32 hash = _metaHash(deleteKeys[i]);
            bytes memory prevValue = _metaStates[groupId][hash].value;
            _removeMeta(groupId, hash);
            emit MetaSet(groupId, msg.sender, newVersion, deleteKeys[i], "", prevValue);
        }

        for (uint256 i = 0; i < newKeys.length; i++) {
            if (newValues[i].length == 0) {
                continue;
            }
            MetaState storage item = _metaStates[groupId][newHashes[i]];
            if (item.exists) {
                if (!_bytesEqual(item.value, newValues[i])) {
                    bytes memory prevValue = item.value;
                    item.value = newValues[i];
                    emit MetaSet(groupId, msg.sender, newVersion, newKeys[i], newValues[i], prevValue);
                }
            } else {
                _addMeta(groupId, newKeys[i], newValues[i]);
                emit MetaSet(groupId, msg.sender, newVersion, newKeys[i], newValues[i], "");
            }
        }
    }

    function _applyActivateDelegateId(
        uint256 groupId,
        ChatConfig storage config,
        address owner,
        uint256 delegateId_,
        uint256 newVersion,
        uint256 prevDelegateId
    ) internal {
        address targetSnapshot = delegateId_ == 0 ? address(0) : owner;
        if (config.delegateId == delegateId_ && config.delegateOwnerSnapshot == targetSnapshot) {
            return;
        }

        config.delegateId = delegateId_;
        config.delegateOwnerSnapshot = targetSnapshot;
        emit DelegateIdSet(groupId, owner, delegateId_, newVersion, prevDelegateId);
    }

    function _applyActivateSource(
        uint256 groupId,
        address currentSource,
        address newSource,
        uint256 newVersion,
        bool isScope
    ) internal {
        if (currentSource == newSource) {
            return;
        }

        if (isScope) {
            emit ScopeSourceSet(groupId, newSource, msg.sender, newVersion, currentSource);
        } else {
            emit DenySourceSet(groupId, newSource, msg.sender, newVersion, currentSource);
        }
    }

    function _applyActivatePlugin(
        uint256 groupId,
        address currentPlugin,
        address newPlugin,
        uint256 newVersion,
        bool isBefore
    ) internal {
        if (currentPlugin == newPlugin) {
            return;
        }

        if (isBefore) {
            emit BeforePostPluginSet(groupId, newPlugin, msg.sender, newVersion, currentPlugin);
        } else {
            emit AfterPostPluginSet(groupId, newPlugin, msg.sender, newVersion, currentPlugin);
        }
    }

    function _recordRound(uint256 chatGroupId, uint256 round, uint256 messageIndex) internal {
        RoundState storage state = _roundStates[chatGroupId][round];
        if (!state.exists) {
            state.exists = true;
            state.startIndex = messageIndex;
            state.endIndex = messageIndex + 1;
            state.listIndex = _roundListByChat[chatGroupId].length;
            _roundListByChat[chatGroupId].push(round);
            return;
        }

        state.endIndex = messageIndex + 1;
    }

    function _addActiveChatGroupId(uint256 groupId) internal {
        if (_activeChatGroupIdIndexPlusOne[groupId] != 0) {
            return;
        }
        _activeChatGroupIds.push(groupId);
        _activeChatGroupIdIndexPlusOne[groupId] = _activeChatGroupIds.length;
    }

    function _removeActiveChatGroupId(uint256 groupId) internal {
        uint256 indexPlusOne = _activeChatGroupIdIndexPlusOne[groupId];
        if (indexPlusOne == 0) {
            return;
        }

        uint256 index = indexPlusOne - 1;
        uint256 lastIndex = _activeChatGroupIds.length - 1;
        if (index != lastIndex) {
            uint256 lastGroupId = _activeChatGroupIds[lastIndex];
            _activeChatGroupIds[index] = lastGroupId;
            _activeChatGroupIdIndexPlusOne[lastGroupId] = indexPlusOne;
        }

        _activeChatGroupIds.pop();
        delete _activeChatGroupIdIndexPlusOne[groupId];
    }

    function _addMeta(uint256 groupId, string memory key, bytes memory value) internal {
        bytes32 hash = _metaHash(key);
        _metaStates[groupId][hash] = MetaState({exists: true, index: _metaKeys[groupId].length, key: key, value: value});
        _metaKeys[groupId].push(key);
    }

    function _removeMeta(uint256 groupId, bytes32 hash) internal {
        MetaState storage item = _metaStates[groupId][hash];
        uint256 index = item.index;
        string[] storage keys = _metaKeys[groupId];

        for (uint256 i = index; i + 1 < keys.length; i++) {
            keys[i] = keys[i + 1];
            _metaStates[groupId][_metaHash(keys[i])].index = i;
        }

        keys.pop();
        delete _metaStates[groupId][hash];
    }

    function _uint256Page(uint256[] storage source, uint256 offset, uint256 limit, bool reverse)
        internal
        view
        returns (uint256[] memory)
    {
        uint256 count = _pageCount(source.length, offset, limit);
        uint256[] memory result = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            result[i] = source[_pageIndex(source.length, offset, i, reverse)];
        }

        return result;
    }

    function _requireOwnerOrDelegateAndActive(uint256 groupId) internal view {
        ChatConfig storage config = _chatConfigs[groupId];
        if (!config.active) revert ChatNotActive();
        if (!_isOwnerOrDelegateIdOwner(groupId, config, msg.sender)) {
            revert NotChatOwnerOrDelegateIdOwner();
        }
    }

    function _requirePostSources(
        ChatConfig storage config,
        uint256 chatGroupId,
        uint256 senderId,
        address senderAddress
    ) internal view {
        if (config.scopeSource != address(0)) {
            if (!IPostScopeSource(config.scopeSource).canPost(chatGroupId, senderId, senderAddress)) {
                revert ScopeRejected();
            }
        }
        if (config.denySource != address(0)) {
            if (IPostDenySource(config.denySource).isDenied(chatGroupId, senderId, senderAddress)) {
                revert DenyRejected();
            }
        }
    }

    function _canPostStatus(uint256 chatGroupId, uint256 senderId, address senderAddress)
        internal
        view
        returns (bool allowed, bytes4 reasonCode)
    {
        (bool chatExists,) = _tryOwnerOf(chatGroupId);
        if (!chatExists) {
            return (false, GroupNotExist.selector);
        }

        ChatConfig storage config = _chatConfigs[chatGroupId];
        if (!config.active) {
            return (false, ChatNotActive.selector);
        }

        (bool senderExists, address senderOwner) = _tryOwnerOf(senderId);
        if (!senderExists) {
            return (false, GroupNotExist.selector);
        }
        if (senderAddress != senderOwner) {
            return (false, SenderAddressNotSenderIdOwner.selector);
        }

        if (config.scopeSource != address(0)) {
            try IPostScopeSource(config.scopeSource).canPost(chatGroupId, senderId, senderAddress)
                returns (bool sourceAllowed)
            {
                if (!sourceAllowed) {
                    return (false, ScopeRejected.selector);
                }
            } catch {
                return (false, ScopeSourceFailed.selector);
            }
        }

        if (config.denySource != address(0)) {
            try IPostDenySource(config.denySource).isDenied(chatGroupId, senderId, senderAddress)
                returns (bool denied)
            {
                if (denied) {
                    return (false, DenyRejected.selector);
                }
            } catch {
                return (false, DenySourceFailed.selector);
            }
        }

        return (true, bytes4(0));
    }

    function _requireExistingGroup(uint256 groupId) internal view {
        _ownerOfOrRevert(groupId);
    }

    function _ownerOfOrRevert(uint256 groupId) internal view returns (address owner) {
        try ILOVE20Group(LOVE20_GROUP_ADDRESS).ownerOf(groupId) returns (address resolved) {
            return resolved;
        } catch {
            revert GroupNotExist();
        }
    }

    function _tryOwnerOf(uint256 groupId) internal view returns (bool exists, address owner) {
        try ILOVE20Group(LOVE20_GROUP_ADDRESS).ownerOf(groupId) returns (address resolved) {
            return (true, resolved);
        } catch {
            return (false, address(0));
        }
    }

    function _delegateIdOf(ChatConfig storage config, address owner) internal view returns (uint256) {
        if (config.delegateOwnerSnapshot != owner) {
            return 0;
        }
        return config.delegateId;
    }

    function _validateDelegateId(uint256 groupId, uint256 delegateId_) internal view {
        if (delegateId_ == 0) {
            return;
        }
        if (delegateId_ == groupId) {
            revert DelegateIdCannotBeChatGroupId();
        }
        _ownerOfOrRevert(delegateId_);
    }

    function _validatePluginAddress(address pluginAddress) internal view {
        if (pluginAddress != address(0) && pluginAddress.code.length == 0) {
            revert PluginAddressHasNoCode();
        }
    }

    function _isOwnerOrDelegateIdOwner(uint256 groupId, ChatConfig storage config, address operator)
        internal
        view
        returns (bool)
    {
        address owner = _ownerOfOrRevert(groupId);
        if (operator == owner) {
            return true;
        }

        uint256 delegateId_ = _delegateIdOf(config, owner);
        if (delegateId_ == 0) {
            return false;
        }

        return operator == _ownerOfOrRevert(delegateId_);
    }

    function _validateMetaInput(string[] calldata keys, bytes[] calldata values)
        internal
        pure
        returns (bytes32[] memory hashes)
    {
        if (keys.length != values.length) revert MetaArrayLengthMismatch();

        hashes = new bytes32[](keys.length);
        for (uint256 i = 0; i < keys.length; i++) {
            _validateMetaKey(keys[i]);
            hashes[i] = keccak256(bytes(keys[i]));
            for (uint256 j = 0; j < i; j++) {
                if (hashes[j] == hashes[i]) revert DuplicateMetaKey();
            }
        }
    }

    function _validateMentions(uint256[] calldata mentions) internal view {
        if (mentions.length > MAX_MENTIONS) {
            revert TooManyMentions(mentions.length, MAX_MENTIONS);
        }
        for (uint256 i = 0; i < mentions.length; i++) {
            _ownerOfOrRevert(mentions[i]);
            for (uint256 j = 0; j < i; j++) {
                if (mentions[j] == mentions[i]) {
                    revert DuplicateMentionSenderId();
                }
            }
        }
    }

    function _storeMessage(
        uint256 chatGroupId,
        uint256 senderId,
        uint256 round,
        string calldata content,
        uint256[] calldata mentions,
        bool mentionAll,
        uint256 quotedMessageId
    ) internal returns (uint256 messageIndex) {
        messageIndex = _messagesByChat[chatGroupId].length;
        _messagesByChat[chatGroupId].push();

        Message storage message_ = _messagesByChat[chatGroupId][messageIndex];
        message_.chatGroupId = chatGroupId;
        message_.senderId = senderId;
        message_.senderAddress = msg.sender;
        message_.round = round;
        message_.messageId = messageIndex + 1;
        message_.content = content;
        message_.blockNumber = block.number;
        message_.timestamp = block.timestamp;
        message_.mentionAll = mentionAll;
        message_.quotedMessageId = quotedMessageId;

        for (uint256 i = 0; i < mentions.length; i++) {
            uint256 mentionedSenderId = mentions[i];
            message_.mentions.push(mentionedSenderId);
            _mentionMessageIndexes[chatGroupId][mentionedSenderId].push(messageIndex);
        }
        if (mentionAll) {
            _mentionAllMessageIndexes[chatGroupId].push(messageIndex);
        }
    }

    function _validateMetaKey(string calldata key) internal pure {
        if (bytes(key).length == 0) revert MetaKeyEmpty();
    }

    function _pageCount(uint256 total, uint256 offset, uint256 limit) internal pure returns (uint256) {
        if (limit == 0 || offset >= total) {
            return 0;
        }

        uint256 remaining = total - offset;
        return remaining < limit ? remaining : limit;
    }

    function _pageIndex(uint256 total, uint256 offset, uint256 index, bool reverse) internal pure returns (uint256) {
        if (!reverse) {
            return offset + index;
        }
        return total - 1 - offset - index;
    }

    function _roundSpan(uint256 chatGroupId, uint256 round) internal view returns (RoundSpan memory) {
        RoundState storage state = _roundStates[chatGroupId][round];
        return RoundSpan({
            round: round,
            startMessageId: state.startIndex + 1,
            endMessageId: state.endIndex + 1,
            messageCount: state.endIndex - state.startIndex
        });
    }

    function _copyMessage(Message storage source) internal view returns (Message memory result) {
        result.chatGroupId = source.chatGroupId;
        result.senderId = source.senderId;
        result.senderAddress = source.senderAddress;
        result.round = source.round;
        result.messageId = source.messageId;
        result.content = source.content;
        result.blockNumber = source.blockNumber;
        result.timestamp = source.timestamp;
        result.mentionAll = source.mentionAll;
        result.quotedMessageId = source.quotedMessageId;
        result.mentions = new uint256[](source.mentions.length);

        for (uint256 i = 0; i < source.mentions.length; i++) {
            result.mentions[i] = source.mentions[i];
        }
    }

    function _containsHash(bytes32[] memory hashes, bytes32 target) internal pure returns (bool) {
        for (uint256 i = 0; i < hashes.length; i++) {
            if (hashes[i] == target) {
                return true;
            }
        }
        return false;
    }

    function _containsNonEmptyHash(bytes32[] memory hashes, bytes[] calldata values, bytes32 target)
        internal
        pure
        returns (bool)
    {
        for (uint256 i = 0; i < hashes.length; i++) {
            if (hashes[i] == target && values[i].length != 0) {
                return true;
            }
        }
        return false;
    }

    function _bytesEqual(bytes memory left, bytes memory right) internal pure returns (bool) {
        return keccak256(left) == keccak256(right);
    }

    function _metaHash(string memory key) internal pure returns (bytes32) {
        return keccak256(bytes(key));
    }

    function _validateQuotedMessageId(uint256 chatGroupId, uint256 quotedMessageId) internal view {
        if (quotedMessageId == 0) {
            return;
        }
        if (quotedMessageId > _messagesByChat[chatGroupId].length) {
            revert InvalidQuotedMessageId();
        }
    }
}
