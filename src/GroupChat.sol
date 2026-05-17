// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IGroupChat} from "./interfaces/IGroupChat.sol";
import {IGroupDefaults} from "./interfaces/external/IGroupDefaults.sol";
import {ILOVE20Group} from "./interfaces/external/ILOVE20Group.sol";
import {IAfterPostPlugin} from "./interfaces/plugins/IAfterPostPlugin.sol";
import {IBeforePostPlugin} from "./interfaces/plugins/IBeforePostPlugin.sol";
import {IPostDenySource} from "./interfaces/sources/IPostDenySource.sol";
import {IPostScopeSource} from "./interfaces/sources/IPostScopeSource.sol";

contract GroupChat is IGroupChat {
    uint256 public constant MAX_CONTENT_LENGTH = 4096;
    uint256 public constant MAX_MENTIONED_SENDER_IDS = 32;
    uint256 public constant MAX_META_KEYS = 32;
    uint256 public constant MAX_META_VALUE_LENGTH = 4096;

    address public immutable GROUP_ADDRESS;
    address public immutable GROUP_DEFAULTS_ADDRESS;
    uint256 public immutable originBlocks;
    uint256 public immutable phaseBlocks;

    struct ChatConfig {
        bool activated;
        bool postingAllowed;
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
        uint256 indexPlusOne;
        bytes value;
    }

    struct RoundState {
        uint256 startIndexPlusOne;
        uint256 endIndex;
    }

    struct StoredMessage {
        uint256 senderId;
        address senderAddress;
        string content;
        uint256 blockNumber;
        uint256 timestamp;
        uint256[] mentionedSenderIds;
        bool mentionAll;
        uint256 quotedMessageId;
    }

    mapping(uint256 => ChatConfig) internal _chatConfigs;
    mapping(uint256 => mapping(bytes32 => MetaState)) internal _metaStates;
    mapping(uint256 => string[]) internal _metaKeys;
    mapping(uint256 => StoredMessage[]) internal _messagesByChat;
    mapping(uint256 => mapping(uint256 => uint256[])) internal _senderMessageIndexes;
    mapping(uint256 => mapping(uint256 => uint256[])) internal _mentionMessageIndexes;
    mapping(uint256 => uint256[]) internal _mentionAllMessageIndexes;
    mapping(uint256 => uint256[]) internal _senderIdsByChat;
    mapping(uint256 => mapping(uint256 => RoundState)) internal _roundStates;
    mapping(uint256 => uint256[]) internal _roundListByChat;
    uint256[] internal _groupIds;

    uint256 internal _entered;

    constructor(address groupDefaults_, uint256 originBlocks_, uint256 phaseBlocks_) {
        if (groupDefaults_.code.length == 0) {
            revert GroupDefaultsHasNoCode();
        }
        if (phaseBlocks_ == 0) {
            revert PhaseBlocksZero();
        }
        GROUP_DEFAULTS_ADDRESS = groupDefaults_;
        GROUP_ADDRESS = IGroupDefaults(groupDefaults_).GROUP_ADDRESS();
        originBlocks = originBlocks_;
        phaseBlocks = phaseBlocks_;
    }

    modifier nonReentrant() {
        if (_entered != 0) {
            revert Reentrant();
        }
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
        uint256 delegateId_
    ) external nonReentrant {
        address owner = _ownerOfOrRevert(groupId);
        if (msg.sender != owner) {
            revert NotChatOwner();
        }

        ChatConfig storage config = _chatConfigs[groupId];
        if (config.activated) {
            revert ChatAlreadyActivated();
        }

        _validateMetaInput(metaKeys_, metaValues_);
        _validateInitialMetaCapacity(metaValues_);
        _validateSourceAddress(scopeSource_);
        _validateSourceAddress(denySource_);
        _validatePluginAddress(beforePostPlugin_);
        _validatePluginAddress(afterPostPlugin_);
        _validateDelegateId(groupId, delegateId_);

        config.firstActivatedOwner = owner;
        config.firstActivatedBlockNumber = block.number;
        config.firstActivatedTimestamp = block.timestamp;
        _groupIds.push(groupId);

        config.activated = true;
        config.postingAllowed = true;
        config.scopeSource = scopeSource_;
        config.denySource = denySource_;
        config.beforePostPlugin = beforePostPlugin_;
        config.afterPostPlugin = afterPostPlugin_;

        uint256 newVersion = _nextConfigVersion(config);

        _initActivateMeta(groupId, metaKeys_, metaValues_, newVersion);
        if (delegateId_ != 0) {
            config.delegateId = delegateId_;
            config.delegateOwnerSnapshot = owner;
            emit DelegateIdSet(groupId, owner, delegateId_, newVersion, 0);
        }
        if (scopeSource_ != address(0)) {
            emit ScopeSourceSet(groupId, scopeSource_, msg.sender, newVersion, address(0));
        }
        if (denySource_ != address(0)) {
            emit DenySourceSet(groupId, denySource_, msg.sender, newVersion, address(0));
        }
        if (beforePostPlugin_ != address(0)) {
            emit BeforePostPluginSet(groupId, beforePostPlugin_, msg.sender, newVersion, address(0));
        }
        if (afterPostPlugin_ != address(0)) {
            emit AfterPostPluginSet(groupId, afterPostPlugin_, msg.sender, newVersion, address(0));
        }
        emit Activate(groupId, owner, newVersion);
    }

    function setPostingAllowed(uint256 groupId, bool postingAllowed_) external nonReentrant {
        _requireOwnerOrDelegateAndActivated(groupId);

        ChatConfig storage config = _chatConfigs[groupId];
        if (config.postingAllowed == postingAllowed_) {
            return;
        }

        config.postingAllowed = postingAllowed_;
        uint256 newVersion = _nextConfigVersion(config);
        emit PostingAllowedSet(groupId, msg.sender, newVersion, postingAllowed_);
    }

    function setMeta(uint256 groupId, string calldata key, bytes calldata value) external nonReentrant {
        _requireOwnerOrDelegateAndActivated(groupId);
        _validateMetaKey(key);
        _validateMetaValue(value);

        bytes32 hash = _metaHash(key);
        if (!_metaChangeNeeded(groupId, hash, value)) {
            return;
        }
        _validateSingleMetaCapacity(groupId, hash, value);

        ChatConfig storage config = _chatConfigs[groupId];
        uint256 newVersion = _nextConfigVersion(config);
        _applyMetaChange(groupId, key, hash, value, newVersion);
    }

    function setMetaBatch(uint256 groupId, string[] calldata keys, bytes[] calldata values) external nonReentrant {
        _requireOwnerOrDelegateAndActivated(groupId);
        if (keys.length != values.length) {
            revert MetaArrayLengthMismatch();
        }
        if (keys.length == 0) {
            return;
        }

        bytes32[] memory hashes = _validateMetaInput(keys, values);
        ChatConfig storage config = _chatConfigs[groupId];

        bool[] memory changed = new bool[](keys.length);
        bool hasChange;
        for (uint256 i = 0; i < keys.length; i++) {
            if (_metaChangeNeeded(groupId, hashes[i], values[i])) {
                changed[i] = true;
                hasChange = true;
            }
        }
        if (!hasChange) {
            return;
        }
        _validateMetaBatchCapacity(groupId, hashes, values);

        uint256 newVersion = _nextConfigVersion(config);

        for (uint256 i = 0; i < keys.length; i++) {
            if (changed[i]) {
                _applyMetaChange(groupId, keys[i], hashes[i], values[i], newVersion);
            }
        }
    }

    function setDelegateId(uint256 groupId, uint256 delegateId_) external nonReentrant {
        address owner = _ownerOfOrRevert(groupId);
        if (msg.sender != owner) {
            revert NotChatOwner();
        }

        ChatConfig storage config = _chatConfigs[groupId];
        if (!config.activated) {
            revert ChatNotActivated();
        }
        _validateDelegateId(groupId, delegateId_);

        address targetSnapshot = delegateId_ == 0 ? address(0) : owner;
        if (config.delegateId == delegateId_ && config.delegateOwnerSnapshot == targetSnapshot) {
            return;
        }

        uint256 prevDelegateId = _delegateIdOf(config, owner);
        config.delegateId = delegateId_;
        config.delegateOwnerSnapshot = targetSnapshot;

        uint256 newVersion = _nextConfigVersion(config);
        emit DelegateIdSet(groupId, owner, delegateId_, newVersion, prevDelegateId);
    }

    function setScopeSource(uint256 groupId, address sourceAddress) external nonReentrant {
        _setSource(groupId, sourceAddress, true);
    }

    function setDenySource(uint256 groupId, address sourceAddress) external nonReentrant {
        _setSource(groupId, sourceAddress, false);
    }

    function setBeforePostPlugin(uint256 groupId, address pluginAddress) external nonReentrant {
        _setPostPlugin(groupId, pluginAddress, true);
    }

    function setAfterPostPlugin(uint256 groupId, address pluginAddress) external nonReentrant {
        _setPostPlugin(groupId, pluginAddress, false);
    }

    function post(
        uint256 groupId,
        uint256 senderId,
        string calldata content,
        uint256[] calldata mentionedSenderIds,
        bool mentionAll,
        uint256 quotedMessageId
    ) external nonReentrant {
        _post(groupId, senderId, content, mentionedSenderIds, mentionAll, quotedMessageId);
    }

    function postAsDefaultSender(
        uint256 groupId,
        string calldata content,
        uint256[] calldata mentionedSenderIds,
        bool mentionAll,
        uint256 quotedMessageId
    ) external nonReentrant {
        uint256 senderId = IGroupDefaults(GROUP_DEFAULTS_ADDRESS).defaultGroupIdOf(msg.sender);
        if (senderId == 0) {
            revert DefaultGroupIdNotSet();
        }
        _post(groupId, senderId, content, mentionedSenderIds, mentionAll, quotedMessageId);
    }

    function _post(
        uint256 groupId,
        uint256 senderId,
        string calldata content,
        uint256[] calldata mentionedSenderIds,
        bool mentionAll,
        uint256 quotedMessageId
    ) internal {
        _requireExistingGroup(groupId);
        ChatConfig storage config = _chatConfigs[groupId];
        if (!config.activated) {
            revert ChatNotActivated();
        }
        if (!config.postingAllowed) {
            revert PostingNotAllowed();
        }

        address senderOwner = _ownerOfOrRevert(senderId);
        if (msg.sender != senderOwner) {
            revert SenderAddressNotSenderIdOwner();
        }

        uint256 contentLength = bytes(content).length;
        if (contentLength == 0) {
            revert ContentEmpty();
        }
        if (contentLength > MAX_CONTENT_LENGTH) {
            revert ContentTooLong(contentLength, MAX_CONTENT_LENGTH);
        }
        _validateMentionedSenderIds(mentionedSenderIds);
        _validateQuotedMessageId(groupId, quotedMessageId);

        uint256 round = currentRound();
        _requirePostSources(config, groupId, senderId, msg.sender);
        if (config.beforePostPlugin != address(0)) {
            IBeforePostPlugin(config.beforePostPlugin).beforePost(
                groupId, senderId, msg.sender, content, mentionedSenderIds, mentionAll, quotedMessageId
            );
        }

        uint256 messageIndex =
            _storeMessage(groupId, senderId, content, mentionedSenderIds, mentionAll, quotedMessageId);

        if (_senderMessageIndexes[groupId][senderId].length == 0) {
            _senderIdsByChat[groupId].push(senderId);
        }
        _senderMessageIndexes[groupId][senderId].push(messageIndex);

        _recordRound(groupId, round, messageIndex);

        emit MessagePost(groupId, senderId, msg.sender, round, messageIndex + 1);
        for (uint256 i = 0; i < mentionedSenderIds.length; i++) {
            emit MessageMention(groupId, mentionedSenderIds[i], messageIndex + 1);
        }
        if (mentionAll) {
            emit MessageMentionAll(groupId, messageIndex + 1);
        }

        if (config.afterPostPlugin != address(0)) {
            try IAfterPostPlugin(config.afterPostPlugin).afterPost(
                groupId,
                senderId,
                msg.sender,
                content,
                mentionedSenderIds,
                mentionAll,
                quotedMessageId,
                messageIndex + 1,
                block.number,
                block.timestamp
            ) {} catch (bytes memory err) {
                emit AfterPostPluginFailed(groupId, messageIndex + 1, config.afterPostPlugin, round, err);
            }
        }
    }

    function chatInfo(uint256 groupId) external view returns (ChatInfo memory) {
        address owner = _ownerOfOrRevert(groupId);
        ChatConfig storage config = _chatConfigs[groupId];
        return ChatInfo({
            groupId: groupId,
            owner: owner,
            activated: config.activated,
            postingAllowed: config.postingAllowed,
            configVersion: config.configVersion,
            delegateId: _delegateIdOf(config, owner),
            scopeSource: config.scopeSource,
            denySource: config.denySource,
            beforePostPlugin: config.beforePostPlugin,
            afterPostPlugin: config.afterPostPlugin,
            firstActivatedOwner: config.firstActivatedOwner,
            firstActivatedBlockNumber: config.firstActivatedBlockNumber,
            firstActivatedTimestamp: config.firstActivatedTimestamp
        });
    }

    function metaValue(uint256 groupId, string calldata key) external view returns (bytes memory) {
        _requireExistingGroup(groupId);
        return _metaStates[groupId][_metaHash(key)].value;
    }

    function metaEntriesCount(uint256 groupId) external view returns (uint256) {
        _requireExistingGroup(groupId);
        return _metaKeys[groupId].length;
    }

    function metaEntries(uint256 groupId, uint256 offset, uint256 limit, bool reverse)
        external
        view
        returns (string[] memory keys_, bytes[] memory values_)
    {
        _requireExistingGroup(groupId);
        string[] storage keys = _metaKeys[groupId];
        uint256 count = _pageCount(keys.length, offset, limit);
        keys_ = new string[](count);
        values_ = new bytes[](count);

        for (uint256 i = 0; i < count; i++) {
            uint256 idx = _pageIndex(keys.length, offset, i, reverse);
            string storage key = keys[idx];
            keys_[i] = key;
            values_[i] = _metaStates[groupId][_metaHash(key)].value;
        }
    }

    function delegateIdOf(uint256 groupId) external view returns (uint256) {
        address owner = _ownerOfOrRevert(groupId);
        return _delegateIdOf(_chatConfigs[groupId], owner);
    }

    function postingAllowed(uint256 groupId) external view returns (bool) {
        _requireExistingGroup(groupId);
        return _chatConfigs[groupId].postingAllowed;
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

    function canPost(uint256 groupId, uint256 senderId, address senderAddress)
        external
        view
        returns (bool allowed, bytes4 reasonCode)
    {
        return _canPost(groupId, senderId, senderAddress);
    }

    function currentRound() public view returns (uint256) {
        if (block.number < originBlocks) {
            revert RoundNotStarted();
        }
        return _roundByBlockNumber(block.number);
    }

    function messagesCount(uint256 groupId) external view returns (uint256) {
        _requireExistingGroup(groupId);
        return _messagesByChat[groupId].length;
    }

    function message(uint256 groupId, uint256 messageId) external view returns (Message memory) {
        _requireExistingGroup(groupId);
        if (messageId == 0 || messageId > _messagesByChat[groupId].length) {
            revert InvalidMessageId();
        }
        uint256 messageIndex = messageId - 1;
        return _copyMessage(_messagesByChat[groupId][messageIndex], groupId, messageIndex);
    }

    function messagesByRoundCount(uint256 groupId, uint256 round) external view returns (uint256) {
        _requireExistingGroup(groupId);
        RoundState storage state = _roundStates[groupId][round];
        if (state.startIndexPlusOne == 0) {
            return 0;
        }
        uint256 startIndex = state.startIndexPlusOne - 1;
        return state.endIndex - startIndex + 1;
    }

    function messagesBySenderCount(uint256 groupId, uint256 senderId) external view returns (uint256) {
        _requireExistingGroup(groupId);
        return _senderMessageIndexes[groupId][senderId].length;
    }

    function senderIdsCount(uint256 groupId) external view returns (uint256) {
        _requireExistingGroup(groupId);
        return _senderIdsByChat[groupId].length;
    }

    function groupIdsCount() external view returns (uint256) {
        return _groupIds.length;
    }

    function messages(uint256 groupId, uint256 offset, uint256 limit, bool reverse)
        external
        view
        returns (Message[] memory)
    {
        _requireExistingGroup(groupId);
        return _messagesPage(groupId, 0, _messagesByChat[groupId].length, offset, limit, reverse);
    }

    function messagesByRound(uint256 groupId, uint256 round, uint256 offset, uint256 limit, bool reverse)
        external
        view
        returns (Message[] memory)
    {
        _requireExistingGroup(groupId);
        RoundState storage state = _roundStates[groupId][round];
        if (state.startIndexPlusOne == 0) {
            return new Message[](0);
        }

        uint256 startIndex = state.startIndexPlusOne - 1;
        uint256 total = state.endIndex - startIndex + 1;
        return _messagesPage(groupId, startIndex, total, offset, limit, reverse);
    }

    function messagesBySender(uint256 groupId, uint256 senderId, uint256 offset, uint256 limit, bool reverse)
        external
        view
        returns (Message[] memory)
    {
        _requireExistingGroup(groupId);
        return _messagesByIndexes(groupId, _senderMessageIndexes[groupId][senderId], offset, limit, reverse);
    }

    function messageIdsBySender(uint256 groupId, uint256 senderId, uint256 offset, uint256 limit, bool reverse)
        external
        view
        returns (uint256[] memory)
    {
        _requireExistingGroup(groupId);
        return _messageIdsByIndexes(_senderMessageIndexes[groupId][senderId], offset, limit, reverse);
    }

    function messagesByMentionCount(uint256 groupId, uint256 mentionedSenderId) external view returns (uint256) {
        _requireExistingGroup(groupId);
        return _mentionMessageIndexes[groupId][mentionedSenderId].length;
    }

    function messagesByMention(uint256 groupId, uint256 mentionedSenderId, uint256 offset, uint256 limit, bool reverse)
        external
        view
        returns (Message[] memory)
    {
        _requireExistingGroup(groupId);
        return _messagesByIndexes(groupId, _mentionMessageIndexes[groupId][mentionedSenderId], offset, limit, reverse);
    }

    function messageIdsByMention(
        uint256 groupId,
        uint256 mentionedSenderId,
        uint256 offset,
        uint256 limit,
        bool reverse
    ) external view returns (uint256[] memory) {
        _requireExistingGroup(groupId);
        return _messageIdsByIndexes(_mentionMessageIndexes[groupId][mentionedSenderId], offset, limit, reverse);
    }

    function messagesByMentionAllCount(uint256 groupId) external view returns (uint256) {
        _requireExistingGroup(groupId);
        return _mentionAllMessageIndexes[groupId].length;
    }

    function messagesByMentionAll(uint256 groupId, uint256 offset, uint256 limit, bool reverse)
        external
        view
        returns (Message[] memory)
    {
        _requireExistingGroup(groupId);
        return _messagesByIndexes(groupId, _mentionAllMessageIndexes[groupId], offset, limit, reverse);
    }

    function messageIdsByMentionAll(uint256 groupId, uint256 offset, uint256 limit, bool reverse)
        external
        view
        returns (uint256[] memory)
    {
        _requireExistingGroup(groupId);
        return _messageIdsByIndexes(_mentionAllMessageIndexes[groupId], offset, limit, reverse);
    }

    function senderIds(uint256 groupId, uint256 offset, uint256 limit, bool reverse)
        external
        view
        returns (uint256[] memory)
    {
        _requireExistingGroup(groupId);
        return _uint256Page(_senderIdsByChat[groupId], offset, limit, reverse);
    }

    function groupIds(uint256 offset, uint256 limit, bool reverse) external view returns (uint256[] memory) {
        return _uint256Page(_groupIds, offset, limit, reverse);
    }

    function roundsCount(uint256 groupId) external view returns (uint256) {
        _requireExistingGroup(groupId);
        return _roundListByChat[groupId].length;
    }

    function rounds(uint256 groupId, uint256 offset, uint256 limit, bool reverse)
        external
        view
        returns (RoundSpan[] memory)
    {
        _requireExistingGroup(groupId);
        uint256[] storage list = _roundListByChat[groupId];
        uint256 count = _pageCount(list.length, offset, limit);
        RoundSpan[] memory result = new RoundSpan[](count);

        for (uint256 i = 0; i < count; i++) {
            uint256 round = list[_pageIndex(list.length, offset, i, reverse)];
            result[i] = _roundSpan(groupId, round);
        }

        return result;
    }

    function roundInfo(uint256 groupId, uint256 round) external view returns (RoundSpan memory) {
        _requireExistingGroup(groupId);
        return _roundSpanOrEmpty(groupId, round);
    }

    function roundInfos(uint256 groupId, uint256[] calldata rounds_) external view returns (RoundSpan[] memory) {
        _requireExistingGroup(groupId);
        RoundSpan[] memory result = new RoundSpan[](rounds_.length);

        for (uint256 i = 0; i < rounds_.length; i++) {
            result[i] = _roundSpanOrEmpty(groupId, rounds_[i]);
        }

        return result;
    }

    function _initActivateMeta(
        uint256 groupId,
        string[] calldata newKeys,
        bytes[] calldata newValues,
        uint256 newVersion
    ) internal {
        for (uint256 i = 0; i < newKeys.length; i++) {
            if (newValues[i].length == 0) {
                continue;
            }
            _addMeta(groupId, newKeys[i], newValues[i]);
            emit MetaSet(groupId, msg.sender, newVersion, newKeys[i], newValues[i], "");
        }
    }

    function _setSource(uint256 groupId, address sourceAddress, bool isScope) internal {
        _requireOwnerOrDelegateAndActivated(groupId);
        _validateSourceAddress(sourceAddress);

        ChatConfig storage config = _chatConfigs[groupId];
        address prevSourceAddress = isScope ? config.scopeSource : config.denySource;
        if (prevSourceAddress == sourceAddress) {
            return;
        }

        if (isScope) {
            config.scopeSource = sourceAddress;
        } else {
            config.denySource = sourceAddress;
        }

        uint256 newVersion = _nextConfigVersion(config);
        if (isScope) {
            emit ScopeSourceSet(groupId, sourceAddress, msg.sender, newVersion, prevSourceAddress);
        } else {
            emit DenySourceSet(groupId, sourceAddress, msg.sender, newVersion, prevSourceAddress);
        }
    }

    function _setPostPlugin(uint256 groupId, address pluginAddress, bool isBefore) internal {
        _requireOwnerOrDelegateAndActivated(groupId);
        _validatePluginAddress(pluginAddress);

        ChatConfig storage config = _chatConfigs[groupId];
        address prevPluginAddress = isBefore ? config.beforePostPlugin : config.afterPostPlugin;
        if (prevPluginAddress == pluginAddress) {
            return;
        }

        if (isBefore) {
            config.beforePostPlugin = pluginAddress;
        } else {
            config.afterPostPlugin = pluginAddress;
        }

        uint256 newVersion = _nextConfigVersion(config);
        if (isBefore) {
            emit BeforePostPluginSet(groupId, pluginAddress, msg.sender, newVersion, prevPluginAddress);
        } else {
            emit AfterPostPluginSet(groupId, pluginAddress, msg.sender, newVersion, prevPluginAddress);
        }
    }

    function _nextConfigVersion(ChatConfig storage config) internal returns (uint256 newVersion) {
        newVersion = config.configVersion + 1;
        config.configVersion = newVersion;
    }

    function _recordRound(uint256 groupId, uint256 round, uint256 messageIndex) internal {
        RoundState storage state = _roundStates[groupId][round];
        if (state.startIndexPlusOne == 0) {
            state.startIndexPlusOne = messageIndex + 1;
            state.endIndex = messageIndex;
            _roundListByChat[groupId].push(round);
            return;
        }

        state.endIndex = messageIndex;
    }

    function _addMeta(uint256 groupId, string memory key, bytes memory value) internal {
        bytes32 hash = _metaHash(key);
        _metaStates[groupId][hash] = MetaState({indexPlusOne: _metaKeys[groupId].length + 1, value: value});
        _metaKeys[groupId].push(key);
    }

    function _metaChangeNeeded(uint256 groupId, bytes32 hash, bytes calldata value) internal view returns (bool) {
        MetaState storage item = _metaStates[groupId][hash];
        bool exists = item.indexPlusOne != 0;
        if (value.length == 0) {
            return exists;
        }
        return !exists || !_bytesEqual(item.value, value);
    }

    function _validateSingleMetaCapacity(uint256 groupId, bytes32 hash, bytes calldata value) internal view {
        if (value.length == 0 || _metaStates[groupId][hash].indexPlusOne != 0) {
            return;
        }
        uint256 newLength = _metaKeys[groupId].length + 1;
        if (newLength > MAX_META_KEYS) {
            revert TooManyMetaKeys(newLength, MAX_META_KEYS);
        }
    }

    function _validateInitialMetaCapacity(bytes[] calldata values) internal pure {
        uint256 liveKeyCount;
        for (uint256 i = 0; i < values.length; i++) {
            if (values[i].length == 0) {
                continue;
            }
            liveKeyCount++;
        }
        if (liveKeyCount > MAX_META_KEYS) {
            revert TooManyMetaKeys(liveKeyCount, MAX_META_KEYS);
        }
    }

    function _validateMetaBatchCapacity(uint256 groupId, bytes32[] memory hashes, bytes[] calldata values)
        internal
        view
    {
        uint256 finalLength = _metaKeys[groupId].length;
        for (uint256 i = 0; i < values.length; i++) {
            bool exists = _metaStates[groupId][hashes[i]].indexPlusOne != 0;
            if (values[i].length == 0) {
                if (exists) {
                    finalLength--;
                }
            } else if (!exists) {
                finalLength++;
            }
        }
        if (finalLength > MAX_META_KEYS) {
            revert TooManyMetaKeys(finalLength, MAX_META_KEYS);
        }
    }

    function _applyMetaChange(
        uint256 groupId,
        string calldata key,
        bytes32 hash,
        bytes calldata value,
        uint256 newVersion
    ) internal {
        MetaState storage item = _metaStates[groupId][hash];
        if (value.length == 0) {
            bytes memory prevValue = item.value;
            _removeMeta(groupId, hash);
            emit MetaSet(groupId, msg.sender, newVersion, key, "", prevValue);
            return;
        }
        if (item.indexPlusOne != 0) {
            bytes memory prevValue2 = item.value;
            item.value = value;
            emit MetaSet(groupId, msg.sender, newVersion, key, value, prevValue2);
            return;
        }

        _addMeta(groupId, key, value);
        emit MetaSet(groupId, msg.sender, newVersion, key, value, "");
    }

    function _removeMeta(uint256 groupId, bytes32 hash) internal {
        MetaState storage item = _metaStates[groupId][hash];
        uint256 index = item.indexPlusOne - 1;
        string[] storage keys = _metaKeys[groupId];

        for (uint256 i = index; i + 1 < keys.length; i++) {
            keys[i] = keys[i + 1];
            _metaStates[groupId][_metaHash(keys[i])].indexPlusOne = i + 1;
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

    function _messagesPage(
        uint256 groupId,
        uint256 startIndex,
        uint256 total,
        uint256 offset,
        uint256 limit,
        bool reverse
    ) internal view returns (Message[] memory) {
        uint256 count = _pageCount(total, offset, limit);
        Message[] memory result = new Message[](count);

        for (uint256 i = 0; i < count; i++) {
            uint256 messageIndex = startIndex + _pageIndex(total, offset, i, reverse);
            result[i] = _copyMessage(_messagesByChat[groupId][messageIndex], groupId, messageIndex);
        }

        return result;
    }

    function _messagesByIndexes(uint256 groupId, uint256[] storage indexes, uint256 offset, uint256 limit, bool reverse)
        internal
        view
        returns (Message[] memory)
    {
        uint256 count = _pageCount(indexes.length, offset, limit);
        Message[] memory result = new Message[](count);

        for (uint256 i = 0; i < count; i++) {
            uint256 messageIndex = indexes[_pageIndex(indexes.length, offset, i, reverse)];
            result[i] = _copyMessage(_messagesByChat[groupId][messageIndex], groupId, messageIndex);
        }

        return result;
    }

    function _messageIdsByIndexes(uint256[] storage indexes, uint256 offset, uint256 limit, bool reverse)
        internal
        view
        returns (uint256[] memory)
    {
        uint256 count = _pageCount(indexes.length, offset, limit);
        uint256[] memory result = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            result[i] = indexes[_pageIndex(indexes.length, offset, i, reverse)] + 1;
        }

        return result;
    }

    function _requireOwnerOrDelegateAndActivated(uint256 groupId) internal view {
        address owner = _ownerOfOrRevert(groupId);
        ChatConfig storage config = _chatConfigs[groupId];
        if (!config.activated) {
            revert ChatNotActivated();
        }
        if (!_isOwnerOrDelegateIdOwner(config, owner, msg.sender)) {
            revert NotChatOwnerOrDelegateIdOwner();
        }
    }

    function _requirePostSources(ChatConfig storage config, uint256 groupId, uint256 senderId, address senderAddress)
        internal
        view
    {
        bytes4 reasonCode = _postSourceBlocker(config, groupId, senderId, senderAddress);
        if (reasonCode != bytes4(0)) {
            _revertPostSourceReason(reasonCode);
        }
    }

    function _postSourceBlocker(ChatConfig storage config, uint256 groupId, uint256 senderId, address senderAddress)
        internal
        view
        returns (bytes4 reasonCode)
    {
        if (config.scopeSource != address(0)) {
            try IPostScopeSource(config.scopeSource).canPost(groupId, senderId, senderAddress) returns (
                bool sourceAllowed
            ) {
                if (!sourceAllowed) {
                    return ScopeRejected.selector;
                }
            } catch {
                return ScopeSourceFailed.selector;
            }
        }
        if (config.denySource != address(0)) {
            try IPostDenySource(config.denySource).isDenied(groupId, senderId, senderAddress) returns (bool denied) {
                if (denied) {
                    return DenyRejected.selector;
                }
            } catch {
                return DenySourceFailed.selector;
            }
        }
        return bytes4(0);
    }

    function _revertPostSourceReason(bytes4 reasonCode) internal pure {
        if (reasonCode == ScopeRejected.selector) {
            revert ScopeRejected();
        }
        if (reasonCode == ScopeSourceFailed.selector) {
            revert ScopeSourceFailed();
        }
        if (reasonCode == DenyRejected.selector) {
            revert DenyRejected();
        }
        if (reasonCode == DenySourceFailed.selector) {
            revert DenySourceFailed();
        }
        revert();
    }

    function _canPost(uint256 groupId, uint256 senderId, address senderAddress)
        internal
        view
        returns (bool allowed, bytes4 reasonCode)
    {
        (bool chatExists,) = _tryOwnerOf(groupId);
        if (!chatExists) {
            return (false, GroupNotExist.selector);
        }

        ChatConfig storage config = _chatConfigs[groupId];
        if (!config.activated) {
            return (false, ChatNotActivated.selector);
        }
        if (!config.postingAllowed) {
            return (false, PostingNotAllowed.selector);
        }

        (bool senderExists, address senderOwner) = _tryOwnerOf(senderId);
        if (!senderExists) {
            return (false, GroupNotExist.selector);
        }
        if (senderAddress != senderOwner) {
            return (false, SenderAddressNotSenderIdOwner.selector);
        }

        bytes4 sourceReasonCode = _postSourceBlocker(config, groupId, senderId, senderAddress);
        if (sourceReasonCode != bytes4(0)) {
            return (false, sourceReasonCode);
        }

        return (true, bytes4(0));
    }

    function _requireExistingGroup(uint256 groupId) internal view {
        _ownerOfOrRevert(groupId);
    }

    function _ownerOfOrRevert(uint256 groupId) internal view returns (address owner) {
        try ILOVE20Group(GROUP_ADDRESS).ownerOf(groupId) returns (address resolved) {
            return resolved;
        } catch {
            revert GroupNotExist();
        }
    }

    function _tryOwnerOf(uint256 groupId) internal view returns (bool exists, address owner) {
        try ILOVE20Group(GROUP_ADDRESS).ownerOf(groupId) returns (address resolved) {
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
            revert DelegateIdCannotBeGroupId();
        }
        _ownerOfOrRevert(delegateId_);
    }

    function _validateSourceAddress(address sourceAddress) internal view {
        if (sourceAddress != address(0) && sourceAddress.code.length == 0) {
            revert SourceAddressHasNoCode();
        }
    }

    function _validatePluginAddress(address pluginAddress) internal view {
        if (pluginAddress != address(0) && pluginAddress.code.length == 0) {
            revert PluginAddressHasNoCode();
        }
    }

    function _isOwnerOrDelegateIdOwner(ChatConfig storage config, address owner, address operator)
        internal
        view
        returns (bool)
    {
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
        if (keys.length != values.length) {
            revert MetaArrayLengthMismatch();
        }

        hashes = new bytes32[](keys.length);
        for (uint256 i = 0; i < keys.length; i++) {
            _validateMetaKey(keys[i]);
            _validateMetaValue(values[i]);
            hashes[i] = keccak256(bytes(keys[i]));
            for (uint256 j = 0; j < i; j++) {
                if (hashes[j] == hashes[i]) {
                    revert DuplicateMetaKey();
                }
            }
        }
    }

    function _validateMetaValue(bytes calldata value) internal pure {
        if (value.length > MAX_META_VALUE_LENGTH) {
            revert MetaValueTooLong(value.length, MAX_META_VALUE_LENGTH);
        }
    }

    function _validateMentionedSenderIds(uint256[] calldata mentionedSenderIds) internal view {
        if (mentionedSenderIds.length > MAX_MENTIONED_SENDER_IDS) {
            revert TooManyMentionedSenderIds(mentionedSenderIds.length, MAX_MENTIONED_SENDER_IDS);
        }
        // LOVE20Group mints token IDs as 1..totalSupply and does not expose an NFT burn path.
        uint256 mintedCount = ILOVE20Group(GROUP_ADDRESS).totalSupply();
        for (uint256 i = 0; i < mentionedSenderIds.length; i++) {
            uint256 mentionedSenderId = mentionedSenderIds[i];
            if (mentionedSenderId == 0 || mentionedSenderId > mintedCount) {
                revert GroupNotExist();
            }
            for (uint256 j = 0; j < i; j++) {
                if (mentionedSenderIds[j] == mentionedSenderId) {
                    revert DuplicateMentionedSenderId();
                }
            }
        }
    }

    function _storeMessage(
        uint256 groupId,
        uint256 senderId,
        string calldata content,
        uint256[] calldata mentionedSenderIds,
        bool mentionAll,
        uint256 quotedMessageId
    ) internal returns (uint256 messageIndex) {
        messageIndex = _messagesByChat[groupId].length;
        _messagesByChat[groupId].push();

        StoredMessage storage message_ = _messagesByChat[groupId][messageIndex];
        message_.senderId = senderId;
        message_.senderAddress = msg.sender;
        message_.content = content;
        message_.blockNumber = block.number;
        message_.timestamp = block.timestamp;
        message_.mentionAll = mentionAll;
        message_.quotedMessageId = quotedMessageId;

        for (uint256 i = 0; i < mentionedSenderIds.length; i++) {
            uint256 mentionedSenderId = mentionedSenderIds[i];
            message_.mentionedSenderIds.push(mentionedSenderId);
            _mentionMessageIndexes[groupId][mentionedSenderId].push(messageIndex);
        }
        if (mentionAll) {
            _mentionAllMessageIndexes[groupId].push(messageIndex);
        }
    }

    function _validateMetaKey(string calldata key) internal pure {
        if (bytes(key).length == 0) {
            revert MetaKeyEmpty();
        }
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

    function _roundByBlockNumber(uint256 blockNumber) internal view returns (uint256) {
        return (blockNumber - originBlocks) / phaseBlocks;
    }

    function _roundSpan(uint256 groupId, uint256 round) internal view returns (RoundSpan memory) {
        RoundState storage state = _roundStates[groupId][round];
        uint256 startIndex = state.startIndexPlusOne - 1;
        return RoundSpan({
            round: round,
            startMessageId: state.startIndexPlusOne,
            endMessageId: state.endIndex + 1,
            messageCount: state.endIndex - startIndex + 1
        });
    }

    function _roundSpanOrEmpty(uint256 groupId, uint256 round) internal view returns (RoundSpan memory) {
        RoundState storage state = _roundStates[groupId][round];
        if (state.startIndexPlusOne == 0) {
            return RoundSpan(round, 0, 0, 0);
        }
        return _roundSpan(groupId, round);
    }

    function _copyMessage(StoredMessage storage source, uint256 groupId, uint256 messageIndex)
        internal
        view
        returns (Message memory result)
    {
        result.groupId = groupId;
        result.senderId = source.senderId;
        result.senderAddress = source.senderAddress;
        result.round = _roundByBlockNumber(source.blockNumber);
        result.messageId = messageIndex + 1;
        result.content = source.content;
        result.blockNumber = source.blockNumber;
        result.timestamp = source.timestamp;
        result.mentionAll = source.mentionAll;
        result.quotedMessageId = source.quotedMessageId;
        result.mentionedSenderIds = new uint256[](source.mentionedSenderIds.length);

        for (uint256 i = 0; i < source.mentionedSenderIds.length; i++) {
            result.mentionedSenderIds[i] = source.mentionedSenderIds[i];
        }
    }

    function _bytesEqual(bytes memory left, bytes memory right) internal pure returns (bool) {
        return keccak256(left) == keccak256(right);
    }

    function _metaHash(string memory key) internal pure returns (bytes32) {
        return keccak256(bytes(key));
    }

    function _validateQuotedMessageId(uint256 groupId, uint256 quotedMessageId) internal view {
        if (quotedMessageId == 0) {
            return;
        }
        if (quotedMessageId > _messagesByChat[groupId].length) {
            revert InvalidQuotedMessageId();
        }
    }
}
