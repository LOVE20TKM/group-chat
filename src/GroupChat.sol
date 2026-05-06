// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IGroupChat} from "./interfaces/IGroupChat.sol";
import {IBeforePostPlugin} from "./interfaces/IBeforePostPlugin.sol";
import {IAfterPostPlugin} from "./interfaces/IAfterPostPlugin.sol";
import {IGroupDefaults} from "./interfaces/IGroupDefaults.sol";
import {ILOVE20Group} from "./interfaces/ILOVE20Group.sol";
import {IPostScopeSource} from "./interfaces/IPostScopeSource.sol";
import {IPostDenySource} from "./interfaces/IPostDenySource.sol";

contract GroupChat is IGroupChat {
    uint256 public constant MAX_CONTENT_LENGTH = 16384;
    uint256 public constant MAX_MENTIONS = 32;

    address public immutable LOVE20_GROUP;
    address public immutable GROUP_DEFAULTS;
    uint256 public immutable originBlocks;
    uint256 public immutable phaseBlocks;

    struct ChatConfig {
        bool active;
        uint256 configVersion;
        address firstActivatedOwner;
        uint256 firstActivatedBlockNumber;
        uint256 firstActivatedTimestamp;
        uint256 delegateGroupId;
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
    mapping(uint256 => uint256[]) internal _senderGroupIdsByChat;
    mapping(uint256 => mapping(uint256 => bool)) internal _senderTracked;
    mapping(uint256 => mapping(uint256 => RoundState)) internal _roundStates;
    mapping(uint256 => uint256[]) internal _roundListByChat;

    uint256 internal _entered;

    constructor(address groupDefaults_, uint256 originBlocks_, uint256 phaseBlocks_) {
        if (groupDefaults_.code.length == 0) {
            revert GroupDefaultsHasNoCode();
        }
        if (phaseBlocks_ == 0) revert PhaseBlocksZero();
        GROUP_DEFAULTS = groupDefaults_;
        LOVE20_GROUP = IGroupDefaults(groupDefaults_).GROUP_ADDRESS();
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
        uint256 groupId,
        string[] calldata metaKeys_,
        bytes[] calldata metaValues_,
        address scopeSource_,
        address denySource_,
        address beforePostPlugin_,
        address afterPostPlugin_,
        uint256 delegateGroupId_
    ) external nonReentrant {
        address owner = _ownerOfOrRevert(groupId);
        if (msg.sender != owner) revert NotChatOwner();

        ChatConfig storage config = _chatConfigs[groupId];
        if (config.active) revert ChatAlreadyActive();

        bytes32[] memory metaHashes = _validateMetaInput(metaKeys_, metaValues_);
        _validatePluginAddress(scopeSource_);
        _validatePluginAddress(denySource_);
        _validatePluginAddress(beforePostPlugin_);
        _validatePluginAddress(afterPostPlugin_);
        _validateDelegateGroupId(groupId, delegateGroupId_);

        uint256 newVersion = config.configVersion + 1;
        uint256 prevDelegateGroupId = _delegateGroupIdOf(config, owner);

        if (config.firstActivatedOwner == address(0)) {
            config.firstActivatedOwner = owner;
            config.firstActivatedBlockNumber = block.number;
            config.firstActivatedTimestamp = block.timestamp;
        }

        config.active = true;
        config.configVersion = newVersion;

        _applyActivateMeta(groupId, metaKeys_, metaValues_, metaHashes, newVersion);
        _applyActivateDelegateGroupId(groupId, config, owner, delegateGroupId_, newVersion, prevDelegateGroupId);
        _applyActivateSource(groupId, config.scopeSource, scopeSource_, newVersion, true);
        _applyActivateSource(groupId, config.denySource, denySource_, newVersion, false);
        _applyActivatePlugin(groupId, config.beforePostPlugin, beforePostPlugin_, newVersion, true);
        _applyActivatePlugin(groupId, config.afterPostPlugin, afterPostPlugin_, newVersion, false);

        config.scopeSource = scopeSource_;
        config.denySource = denySource_;
        config.beforePostPlugin = beforePostPlugin_;
        config.afterPostPlugin = afterPostPlugin_;
        emit ChatActivate(groupId, owner, newVersion);
    }

    function deactivateChat(uint256 groupId) external nonReentrant {
        address owner = _ownerOfOrRevert(groupId);
        if (msg.sender != owner) revert NotChatOwner();

        ChatConfig storage config = _chatConfigs[groupId];
        if (!config.active) revert ChatAlreadyInactive();

        uint256 newVersion = config.configVersion + 1;
        config.active = false;
        config.configVersion = newVersion;
        emit ChatDeactivate(groupId, owner, newVersion);
    }

    function setMeta(uint256 groupId, string calldata key, bytes calldata value) external nonReentrant {
        _requireOwnerOrDelegateAndActive(groupId);
        _validateMetaKey(key);

        ChatConfig storage config = _chatConfigs[groupId];
        bytes32 hash = _metaHash(key);
        MetaState storage item = _metaStates[groupId][hash];

        if (value.length == 0) {
            if (!item.exists) revert MetaKeyNotFound();
            bytes memory prevValue = item.value;
            _removeMeta(groupId, hash);
            uint256 newVersion = config.configVersion + 1;
            config.configVersion = newVersion;
            emit MetaSet(groupId, msg.sender, newVersion, key, "", prevValue);
            return;
        }

        if (item.exists) {
            if (_bytesEqual(item.value, value)) revert MetaValueUnchanged();
            bytes memory prevValue = item.value;
            item.value = value;
            uint256 newVersion = config.configVersion + 1;
            config.configVersion = newVersion;
            emit MetaSet(groupId, msg.sender, newVersion, key, value, prevValue);
            return;
        }

        _addMeta(groupId, key, value);
        uint256 newVersion2 = config.configVersion + 1;
        config.configVersion = newVersion2;
        emit MetaSet(groupId, msg.sender, newVersion2, key, value, "");
    }

    function setMetaBatch(uint256 groupId, string[] calldata keys, bytes[] calldata values) external nonReentrant {
        _requireOwnerOrDelegateAndActive(groupId);
        if (keys.length != values.length) revert MetaArrayLengthMismatch();
        if (keys.length == 0) {
            return;
        }

        bytes32[] memory hashes = _validateMetaInput(keys, values);
        ChatConfig storage config = _chatConfigs[groupId];

        for (uint256 i = 0; i < keys.length; i++) {
            MetaState storage item = _metaStates[groupId][hashes[i]];
            if (values[i].length == 0) {
                if (!item.exists) revert MetaKeyNotFound();
            } else if (item.exists && _bytesEqual(item.value, values[i])) {
                revert MetaValueUnchanged();
            }
        }

        uint256 newVersion = config.configVersion + 1;
        config.configVersion = newVersion;

        for (uint256 i = 0; i < keys.length; i++) {
            MetaState storage item = _metaStates[groupId][hashes[i]];
            if (values[i].length == 0) {
                bytes memory prevValue = item.value;
                _removeMeta(groupId, hashes[i]);
                emit MetaSet(groupId, msg.sender, newVersion, keys[i], "", prevValue);
            } else if (item.exists) {
                bytes memory prevValue2 = item.value;
                item.value = values[i];
                emit MetaSet(groupId, msg.sender, newVersion, keys[i], values[i], prevValue2);
            } else {
                _addMeta(groupId, keys[i], values[i]);
                emit MetaSet(groupId, msg.sender, newVersion, keys[i], values[i], "");
            }
        }
    }

    function setDelegateGroupId(uint256 groupId, uint256 delegateGroupId_) external nonReentrant {
        address owner = _ownerOfOrRevert(groupId);
        if (msg.sender != owner) revert NotChatOwner();

        ChatConfig storage config = _chatConfigs[groupId];
        if (!config.active) revert ChatNotActive();
        _validateDelegateGroupId(groupId, delegateGroupId_);

        address targetSnapshot = delegateGroupId_ == 0 ? address(0) : owner;
        if (config.delegateGroupId == delegateGroupId_ && config.delegateOwnerSnapshot == targetSnapshot) {
            revert DelegateGroupIdUnchanged();
        }

        uint256 prevDelegateGroupId = _delegateGroupIdOf(config, owner);
        config.delegateGroupId = delegateGroupId_;
        config.delegateOwnerSnapshot = targetSnapshot;

        uint256 newVersion = config.configVersion + 1;
        config.configVersion = newVersion;
        emit DelegateGroupIdSet(groupId, owner, delegateGroupId_, newVersion, prevDelegateGroupId);
    }

    function setScopeSource(uint256 groupId, address sourceAddress) external nonReentrant {
        _requireOwnerOrDelegateAndActive(groupId);
        _validatePluginAddress(sourceAddress);

        ChatConfig storage config = _chatConfigs[groupId];
        if (config.scopeSource == sourceAddress) revert PluginAddressUnchanged();

        address prevSourceAddress = config.scopeSource;
        config.scopeSource = sourceAddress;

        uint256 newVersion = config.configVersion + 1;
        config.configVersion = newVersion;
        emit ScopeSourceSet(groupId, sourceAddress, msg.sender, newVersion, prevSourceAddress);
    }

    function setDenySource(uint256 groupId, address sourceAddress) external nonReentrant {
        _requireOwnerOrDelegateAndActive(groupId);
        _validatePluginAddress(sourceAddress);

        ChatConfig storage config = _chatConfigs[groupId];
        if (config.denySource == sourceAddress) revert PluginAddressUnchanged();

        address prevSourceAddress = config.denySource;
        config.denySource = sourceAddress;

        uint256 newVersion = config.configVersion + 1;
        config.configVersion = newVersion;
        emit DenySourceSet(groupId, sourceAddress, msg.sender, newVersion, prevSourceAddress);
    }

    function setBeforePostPlugin(uint256 groupId, address pluginAddress) external nonReentrant {
        _requireOwnerOrDelegateAndActive(groupId);
        _validatePluginAddress(pluginAddress);

        ChatConfig storage config = _chatConfigs[groupId];
        if (config.beforePostPlugin == pluginAddress) revert PluginAddressUnchanged();

        address prevPluginAddress = config.beforePostPlugin;
        config.beforePostPlugin = pluginAddress;

        uint256 newVersion = config.configVersion + 1;
        config.configVersion = newVersion;
        emit BeforePostPluginSet(groupId, pluginAddress, msg.sender, newVersion, prevPluginAddress);
    }

    function setAfterPostPlugin(uint256 groupId, address pluginAddress) external nonReentrant {
        _requireOwnerOrDelegateAndActive(groupId);
        _validatePluginAddress(pluginAddress);

        ChatConfig storage config = _chatConfigs[groupId];
        if (config.afterPostPlugin == pluginAddress) revert PluginAddressUnchanged();

        address prevPluginAddress = config.afterPostPlugin;
        config.afterPostPlugin = pluginAddress;

        uint256 newVersion = config.configVersion + 1;
        config.configVersion = newVersion;
        emit AfterPostPluginSet(groupId, pluginAddress, msg.sender, newVersion, prevPluginAddress);
    }

    function post(
        uint256 chatGroupId,
        uint256 senderGroupId,
        string calldata content,
        uint256[] calldata mentions,
        bool mentionAll,
        uint256 quotedMessageIndex
    ) external nonReentrant {
        _post(chatGroupId, senderGroupId, content, mentions, mentionAll, quotedMessageIndex);
    }

    function postByDefaultSender(
        uint256 chatGroupId,
        string calldata content,
        uint256[] calldata mentions,
        bool mentionAll,
        uint256 quotedMessageIndex
    ) external nonReentrant {
        uint256 senderGroupId = IGroupDefaults(GROUP_DEFAULTS).defaultGroupIdOf(msg.sender);
        if (senderGroupId == 0) revert DefaultGroupIdNotSet();
        _post(chatGroupId, senderGroupId, content, mentions, mentionAll, quotedMessageIndex);
    }

    function _post(
        uint256 chatGroupId,
        uint256 senderGroupId,
        string calldata content,
        uint256[] calldata mentions,
        bool mentionAll,
        uint256 quotedMessageIndex
    ) internal {
        _requireExistingGroup(chatGroupId);
        ChatConfig storage config = _chatConfigs[chatGroupId];
        if (!config.active) revert ChatNotActive();

        address senderOwner = _ownerOfOrRevert(senderGroupId);
        if (msg.sender != senderOwner) revert SenderNotGroupOwner();

        uint256 contentLength = bytes(content).length;
        if (contentLength == 0) revert ContentEmpty();
        if (contentLength > MAX_CONTENT_LENGTH) {
            revert ContentTooLong(contentLength, MAX_CONTENT_LENGTH);
        }
        _validateMentions(mentions);
        _validateQuotedMessageIndex(chatGroupId, quotedMessageIndex);

        uint256 round = currentRound();
        _requirePostSources(config, chatGroupId, senderGroupId, msg.sender);
        if (config.beforePostPlugin != address(0)) {
            IBeforePostPlugin(config.beforePostPlugin).beforePost(
                chatGroupId, senderGroupId, msg.sender, content, mentions, mentionAll, quotedMessageIndex
            );
        }

        uint256 messageIndex =
            _storeMessage(chatGroupId, senderGroupId, round, content, mentions, mentionAll, quotedMessageIndex);

        _senderMessageIndexes[chatGroupId][senderGroupId].push(messageIndex);
        if (!_senderTracked[chatGroupId][senderGroupId]) {
            _senderTracked[chatGroupId][senderGroupId] = true;
            _senderGroupIdsByChat[chatGroupId].push(senderGroupId);
        }

        _recordRound(chatGroupId, round, messageIndex);

        emit MessagePost(chatGroupId, senderGroupId, msg.sender, round, messageIndex);

        if (config.afterPostPlugin != address(0)) {
            try IAfterPostPlugin(config.afterPostPlugin).afterPost(
                chatGroupId,
                senderGroupId,
                msg.sender,
                content,
                mentions,
                mentionAll,
                quotedMessageIndex,
                messageIndex,
                block.number,
                block.timestamp
            ) {} catch (bytes memory err) {
                emit AfterPostPluginFailed(chatGroupId, messageIndex, config.afterPostPlugin, round, err);
            }
        }
    }

    function chatInfo(uint256 groupId) external view returns (ChatInfo memory) {
        address owner = _ownerOfOrRevert(groupId);
        ChatConfig storage config = _chatConfigs[groupId];
        return ChatInfo({
            groupId: groupId,
            owner: owner,
            active: config.active,
            configVersion: config.configVersion,
            firstActivatedOwner: config.firstActivatedOwner,
            firstActivatedBlockNumber: config.firstActivatedBlockNumber,
            firstActivatedTimestamp: config.firstActivatedTimestamp
        });
    }

    function metaValue(uint256 groupId, string calldata key) external view returns (bytes memory) {
        _requireExistingGroup(groupId);
        return _metaStates[groupId][_metaHash(key)].value;
    }

    function metaEntries(uint256 groupId, uint256 offset, uint256 limit, bool reverse)
        external
        view
        returns (MetaEntry[] memory)
    {
        _requireExistingGroup(groupId);
        string[] storage keys = _metaKeys[groupId];
        uint256 count = _pageCount(keys.length, offset, limit);
        MetaEntry[] memory result = new MetaEntry[](count);

        for (uint256 i = 0; i < count; i++) {
            uint256 idx = _pageIndex(keys.length, offset, i, reverse);
            string storage key = keys[idx];
            result[i] = MetaEntry({key: key, value: _metaStates[groupId][_metaHash(key)].value});
        }

        return result;
    }

    function delegateGroupIdOf(uint256 groupId) external view returns (uint256) {
        address owner = _ownerOfOrRevert(groupId);
        return _delegateGroupIdOf(_chatConfigs[groupId], owner);
    }

    function scopeSource(uint256 groupId) external view returns (address) {
        _requireExistingGroup(groupId);
        return _chatConfigs[groupId].scopeSource;
    }

    function denySource(uint256 groupId) external view returns (address) {
        _requireExistingGroup(groupId);
        return _chatConfigs[groupId].denySource;
    }

    function beforePostPlugin(uint256 groupId) external view returns (address) {
        _requireExistingGroup(groupId);
        return _chatConfigs[groupId].beforePostPlugin;
    }

    function afterPostPlugin(uint256 groupId) external view returns (address) {
        _requireExistingGroup(groupId);
        return _chatConfigs[groupId].afterPostPlugin;
    }

    function ruleSlots(uint256 groupId)
        external
        view
        returns (
            address scopeSource_,
            address denySource_,
            address beforePostPlugin_,
            address afterPostPlugin_
        )
    {
        _requireExistingGroup(groupId);
        ChatConfig storage config = _chatConfigs[groupId];
        return (config.scopeSource, config.denySource, config.beforePostPlugin, config.afterPostPlugin);
    }

    function canPost(uint256 chatGroupId, uint256 senderGroupId, address senderAddress) external view returns (bool) {
        (bool allowed,) = _canPostStatus(chatGroupId, senderGroupId, senderAddress);
        return allowed;
    }

    function canPostStatus(uint256 chatGroupId, uint256 senderGroupId, address senderAddress)
        external
        view
        returns (bool allowed, bytes4 reasonCode)
    {
        return _canPostStatus(chatGroupId, senderGroupId, senderAddress);
    }

    function currentRound() public view returns (uint256) {
        if (block.number < originBlocks) revert RoundNotStarted();
        return (block.number - originBlocks) / phaseBlocks;
    }

    function messagesCount(uint256 chatGroupId) external view returns (uint256) {
        _requireExistingGroup(chatGroupId);
        return _messagesByChat[chatGroupId].length;
    }

    function message(uint256 chatGroupId, uint256 messageIndex) external view returns (Message memory) {
        _requireExistingGroup(chatGroupId);
        if (messageIndex >= _messagesByChat[chatGroupId].length) {
            revert InvalidMessageIndex();
        }
        return _copyMessage(_messagesByChat[chatGroupId][messageIndex]);
    }

    function messagesByRoundCount(uint256 chatGroupId, uint256 round) external view returns (uint256) {
        _requireExistingGroup(chatGroupId);
        RoundState storage state = _roundStates[chatGroupId][round];
        if (!state.exists) {
            return 0;
        }
        return state.endIndex - state.startIndex;
    }

    function messagesBySenderCount(uint256 chatGroupId, uint256 senderGroupId) external view returns (uint256) {
        _requireExistingGroup(chatGroupId);
        return _senderMessageIndexes[chatGroupId][senderGroupId].length;
    }

    function senderGroupIdsCount(uint256 chatGroupId) external view returns (uint256) {
        _requireExistingGroup(chatGroupId);
        return _senderGroupIdsByChat[chatGroupId].length;
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

    function messagesBySender(uint256 chatGroupId, uint256 senderGroupId, uint256 offset, uint256 limit, bool reverse)
        external
        view
        returns (Message[] memory)
    {
        _requireExistingGroup(chatGroupId);
        uint256[] storage indexes = _senderMessageIndexes[chatGroupId][senderGroupId];
        uint256 count = _pageCount(indexes.length, offset, limit);
        Message[] memory result = new Message[](count);

        for (uint256 i = 0; i < count; i++) {
            uint256 pageIdx = _pageIndex(indexes.length, offset, i, reverse);
            result[i] = _copyMessage(_messagesByChat[chatGroupId][indexes[pageIdx]]);
        }

        return result;
    }

    function messageIndexesBySender(
        uint256 chatGroupId,
        uint256 senderGroupId,
        uint256 offset,
        uint256 limit,
        bool reverse
    ) external view returns (uint256[] memory) {
        _requireExistingGroup(chatGroupId);
        uint256[] storage indexes = _senderMessageIndexes[chatGroupId][senderGroupId];
        uint256 count = _pageCount(indexes.length, offset, limit);
        uint256[] memory result = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            result[i] = indexes[_pageIndex(indexes.length, offset, i, reverse)];
        }

        return result;
    }

    function messagesByMentionCount(uint256 chatGroupId, uint256 mentionedGroupId) external view returns (uint256) {
        _requireExistingGroup(chatGroupId);
        return _mentionMessageIndexes[chatGroupId][mentionedGroupId].length;
    }

    function messagesByMention(
        uint256 chatGroupId,
        uint256 mentionedGroupId,
        uint256 offset,
        uint256 limit,
        bool reverse
    ) external view returns (Message[] memory) {
        _requireExistingGroup(chatGroupId);
        uint256[] storage indexes = _mentionMessageIndexes[chatGroupId][mentionedGroupId];
        uint256 count = _pageCount(indexes.length, offset, limit);
        Message[] memory result = new Message[](count);

        for (uint256 i = 0; i < count; i++) {
            uint256 pageIdx = _pageIndex(indexes.length, offset, i, reverse);
            result[i] = _copyMessage(_messagesByChat[chatGroupId][indexes[pageIdx]]);
        }

        return result;
    }

    function messageIndexesByMention(
        uint256 chatGroupId,
        uint256 mentionedGroupId,
        uint256 offset,
        uint256 limit,
        bool reverse
    ) external view returns (uint256[] memory) {
        _requireExistingGroup(chatGroupId);
        uint256[] storage indexes = _mentionMessageIndexes[chatGroupId][mentionedGroupId];
        uint256 count = _pageCount(indexes.length, offset, limit);
        uint256[] memory result = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            result[i] = indexes[_pageIndex(indexes.length, offset, i, reverse)];
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

    function messageIndexesByMentionAll(uint256 chatGroupId, uint256 offset, uint256 limit, bool reverse)
        external
        view
        returns (uint256[] memory)
    {
        _requireExistingGroup(chatGroupId);
        uint256[] storage indexes = _mentionAllMessageIndexes[chatGroupId];
        uint256 count = _pageCount(indexes.length, offset, limit);
        uint256[] memory result = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            result[i] = indexes[_pageIndex(indexes.length, offset, i, reverse)];
        }

        return result;
    }

    function senderGroupIds(uint256 chatGroupId, uint256 offset, uint256 limit, bool reverse)
        external
        view
        returns (uint256[] memory)
    {
        _requireExistingGroup(chatGroupId);
        uint256[] storage senders = _senderGroupIdsByChat[chatGroupId];
        uint256 count = _pageCount(senders.length, offset, limit);
        uint256[] memory result = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            result[i] = senders[_pageIndex(senders.length, offset, i, reverse)];
        }

        return result;
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

    function _applyActivateDelegateGroupId(
        uint256 groupId,
        ChatConfig storage config,
        address owner,
        uint256 delegateGroupId_,
        uint256 newVersion,
        uint256 prevDelegateGroupId
    ) internal {
        address targetSnapshot = delegateGroupId_ == 0 ? address(0) : owner;
        if (config.delegateGroupId == delegateGroupId_ && config.delegateOwnerSnapshot == targetSnapshot) {
            return;
        }

        config.delegateGroupId = delegateGroupId_;
        config.delegateOwnerSnapshot = targetSnapshot;
        emit DelegateGroupIdSet(groupId, owner, delegateGroupId_, newVersion, prevDelegateGroupId);
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

    function _requireOwnerOrDelegateAndActive(uint256 groupId) internal view {
        ChatConfig storage config = _chatConfigs[groupId];
        if (!config.active) revert ChatNotActive();
        if (!_isOwnerOrDelegateGroupOwner(groupId, config, msg.sender)) {
            revert NotChatOwnerOrDelegateGroupOwner();
        }
    }

    function _requirePostSources(
        ChatConfig storage config,
        uint256 chatGroupId,
        uint256 senderGroupId,
        address senderAddress
    ) internal view {
        if (config.scopeSource != address(0)) {
            if (!IPostScopeSource(config.scopeSource).canPost(chatGroupId, senderGroupId, senderAddress)) {
                revert ScopeRejected();
            }
        }
        if (config.denySource != address(0)) {
            if (IPostDenySource(config.denySource).isDenied(chatGroupId, senderGroupId, senderAddress)) {
                revert DenyRejected();
            }
        }
    }

    function _canPostStatus(uint256 chatGroupId, uint256 senderGroupId, address senderAddress)
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

        (bool senderExists, address senderOwner) = _tryOwnerOf(senderGroupId);
        if (!senderExists) {
            return (false, GroupNotExist.selector);
        }
        if (senderAddress != senderOwner) {
            return (false, SenderNotGroupOwner.selector);
        }

        if (config.scopeSource != address(0)) {
            try IPostScopeSource(config.scopeSource).canPost(chatGroupId, senderGroupId, senderAddress)
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
            try IPostDenySource(config.denySource).isDenied(chatGroupId, senderGroupId, senderAddress)
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
        try ILOVE20Group(LOVE20_GROUP).ownerOf(groupId) returns (address resolved) {
            return resolved;
        } catch {
            revert GroupNotExist();
        }
    }

    function _tryOwnerOf(uint256 groupId) internal view returns (bool exists, address owner) {
        try ILOVE20Group(LOVE20_GROUP).ownerOf(groupId) returns (address resolved) {
            return (true, resolved);
        } catch {
            return (false, address(0));
        }
    }

    function _delegateGroupIdOf(ChatConfig storage config, address owner) internal view returns (uint256) {
        if (config.delegateOwnerSnapshot != owner) {
            return 0;
        }
        return config.delegateGroupId;
    }

    function _validateDelegateGroupId(uint256 groupId, uint256 delegateGroupId_) internal view {
        if (delegateGroupId_ == 0) {
            return;
        }
        if (delegateGroupId_ == groupId) {
            revert DelegateGroupIdCannotBeChatGroupId();
        }
        _ownerOfOrRevert(delegateGroupId_);
    }

    function _validatePluginAddress(address pluginAddress) internal view {
        if (pluginAddress != address(0) && pluginAddress.code.length == 0) {
            revert PluginAddressHasNoCode();
        }
    }

    function _isOwnerOrDelegateGroupOwner(uint256 groupId, ChatConfig storage config, address operator)
        internal
        view
        returns (bool)
    {
        address owner = _ownerOfOrRevert(groupId);
        if (operator == owner) {
            return true;
        }

        uint256 delegateGroupId_ = _delegateGroupIdOf(config, owner);
        if (delegateGroupId_ == 0) {
            return false;
        }

        return operator == _ownerOfOrRevert(delegateGroupId_);
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
                    revert DuplicateMentionGroupId();
                }
            }
        }
    }

    function _storeMessage(
        uint256 chatGroupId,
        uint256 senderGroupId,
        uint256 round,
        string calldata content,
        uint256[] calldata mentions,
        bool mentionAll,
        uint256 quotedMessageIndex
    ) internal returns (uint256 messageIndex) {
        messageIndex = _messagesByChat[chatGroupId].length;
        _messagesByChat[chatGroupId].push();

        Message storage message_ = _messagesByChat[chatGroupId][messageIndex];
        message_.chatGroupId = chatGroupId;
        message_.senderGroupId = senderGroupId;
        message_.senderAddress = msg.sender;
        message_.round = round;
        message_.messageIndex = messageIndex;
        message_.content = content;
        message_.blockNumber = block.number;
        message_.timestamp = block.timestamp;
        message_.mentionAll = mentionAll;
        message_.quotedMessageIndex = quotedMessageIndex;

        for (uint256 i = 0; i < mentions.length; i++) {
            uint256 mentionedGroupId = mentions[i];
            message_.mentions.push(mentionedGroupId);
            _mentionMessageIndexes[chatGroupId][mentionedGroupId].push(messageIndex);
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
            startIndex: state.startIndex,
            endIndex: state.endIndex,
            messageCount: state.endIndex - state.startIndex
        });
    }

    function _copyMessage(Message storage source) internal view returns (Message memory result) {
        result.chatGroupId = source.chatGroupId;
        result.senderGroupId = source.senderGroupId;
        result.senderAddress = source.senderAddress;
        result.round = source.round;
        result.messageIndex = source.messageIndex;
        result.content = source.content;
        result.blockNumber = source.blockNumber;
        result.timestamp = source.timestamp;
        result.mentionAll = source.mentionAll;
        result.quotedMessageIndex = source.quotedMessageIndex;
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

    function _validateQuotedMessageIndex(uint256 chatGroupId, uint256 quotedMessageIndex) internal view {
        if (quotedMessageIndex == 0) {
            return;
        }
        if (quotedMessageIndex >= _messagesByChat[chatGroupId].length) {
            revert InvalidQuotedMessageIndex();
        }
    }
}
