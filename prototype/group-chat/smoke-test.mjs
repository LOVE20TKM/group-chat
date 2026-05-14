import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('.', import.meta.url).pathname;
const requiredFiles = ['index.html', 'styles.css', 'prototype-data.js', 'app.js', 'AI_EDITING.md'];

for (const file of requiredFiles) {
  const path = join(root, file);
  if (!existsSync(path)) {
    throw new Error(`Missing ${file}`);
  }
}

const html = readFileSync(join(root, 'index.html'), 'utf8');
const css = readFileSync(join(root, 'styles.css'), 'utf8');
const data = readFileSync(join(root, 'prototype-data.js'), 'utf8');
const js = readFileSync(join(root, 'app.js'), 'utf8');
const aiEditing = readFileSync(join(root, 'AI_EDITING.md'), 'utf8');
const prototypeSource = html + data + js;
const renderStatusMatch = js.match(/function renderStatus\(\) \{([\s\S]*?)\n\}/);

function extractFunctionSource(source, name) {
  const start = source.indexOf(`function ${name}(`);
  if (start === -1) throw new Error(`Missing function ${name}`);

  const bodyStart = source.indexOf('{', start);
  let depth = 0;
  for (let index = bodyStart; index < source.length; index += 1) {
    const char = source[index];
    if (char === '{') depth += 1;
    if (char === '}') {
      depth -= 1;
      if (depth === 0) return source.slice(start, index + 1);
    }
  }

  throw new Error(`Unclosed function ${name}`);
}

if (!renderStatusMatch) {
  throw new Error('Missing renderStatus');
}

if (renderStatusMatch[1].includes('chatStatus(') || renderStatusMatch[1].includes('status.label')) {
  throw new Error('Chat input status strip must not render posting status');
}

if (js.includes('data-action="remove-mention"') || js.includes('@all ×')) {
  throw new Error('Mentioned sender IDs must render in composer text, not composer chips');
}

if (html.includes('data-action="open-more"') || html.includes('id="more-panel"') || js.includes('openMorePanel')) {
  throw new Error('Chat composer must not render a plus/more panel');
}

if (js.includes('mentionedSenderIds: [...state.mentionedSenderIds]') || js.includes('mentionAll: state.mentionAll')) {
  throw new Error('Sending must parse mentionedSenderIds from composer content');
}

if (js.includes('...state.messages.map((message) => message.messageId)')) {
  throw new Error('messageId must be calculated per groupId, not globally');
}

if (data.includes('indexMode') || js.includes('setIndexMode') || js.includes('set-index-mode')) {
  throw new Error('Index mode switch is not part of the current prototype interaction');
}

if (js.includes('state.senderId')) {
  throw new Error('Current account posting identity must use defaultGroupId');
}

if (data.includes('senderOwnerMatches') || js.includes('senderOwnerMatches') || js.includes('senderId 的 owner')) {
  throw new Error('Prototype must describe current-account posting ownership as defaultGroupId');
}

if (
  prototypeSource.includes('conversationId') ||
  prototypeSource.includes('activeConversationId') ||
  prototypeSource.includes('data-conversation-id') ||
  aiEditing.includes('conversationId') ||
  aiEditing.includes('activeConversationId') ||
  aiEditing.includes('data-conversation-id')
) {
  throw new Error('Prototype data and handlers must use groupId, not conversationId');
}

if (!js.includes('function canQuoteMessage(') || !js.includes('canQuoteMessage(message)')) {
  throw new Error('Prototype must centralize quote eligibility checks');
}

if (data.includes('quotedMessageId: null') || js.includes('state.quotedMessageId')) {
  throw new Error('Composer quote state must be stored by groupId');
}

const cssOpenBraces = (css.match(/\{/g) || []).length;
const cssCloseBraces = (css.match(/\}/g) || []).length;
if (cssOpenBraces !== cssCloseBraces) {
  throw new Error(`CSS brace mismatch: ${cssOpenBraces} "{" vs ${cssCloseBraces} "}"`);
}

const requiredHtml = [
  'data-entry="love20-chat"',
  'id="wallet-button"',
  'id="bottom-nav"',
  'id="workspace-screen"',
  'id="message-list"',
  'id="composer-input"',
  'placeholder="输入公开链上消息"',
  'id="composer-blocked"',
];

for (const needle of requiredHtml) {
  if (!html.includes(needle)) {
    throw new Error(`Missing HTML marker: ${needle}`);
  }
}

const dataScriptIndex = html.indexOf('src="./prototype-data.js');
const appScriptIndex = html.indexOf('src="./app.js');
if (dataScriptIndex === -1 || appScriptIndex === -1 || dataScriptIndex > appScriptIndex) {
  throw new Error('prototype-data.js must load before app.js');
}

const requiredCss = [
  '--primary: #0f766e',
  '.bottom-nav',
  '.conversation-row',
  '.conversation-row.group-row',
  '.conversation-badge.mention-me',
  '.conversation-badge.mention-all',
  '.group-icon-token-community',
  '.group-icon-token-gov',
  '.group-icon-action',
  '.group-icon-action-gov',
  '.group-icon-chain-service',
  '.chat-menu-button',
  '.chat-menu',
  '.message-mention',
  '.blacklist-row',
  '.blacklist-menu',
  '.pager-row',
  '.inbox-filter-row',
  '.filter-tabs',
  '.action-row',
  '.query-row',
  '.composer-blocked',
  '.delegate-panel',
  '@media (min-width: 900px)',
  '@media (max-width: 390px)',
  'font-size: 16px',
];

for (const needle of requiredCss) {
  if (!css.includes(needle)) {
    throw new Error(`Missing CSS marker: ${needle}`);
  }
}

const requiredAppJs = [
  'LOVE20 Chat',
  'LOVE20_CHAT_PROTOTYPE_DATA',
  'Load prototype-data.js before app.js',
  'prototypeData.initialState',
  'renderInbox',
  'chatDisplayName',
  'chatIconLabel',
  'activationTypeForChat',
  'renderActivationSection',
  'set-activation-type',
  'toggleChatMenu',
  'activeGroupMenuId',
  'pageReturnStack',
  'renderGroupDetails',
  'openDetails',
  'postBlockReason',
  'scopeSourceReason',
  'blacklistQueryType',
  'blacklistRows',
  'setBlacklistQueryType',
  'setNftInputMode',
  'setBlacklistPage',
  'toggleBlacklistMenu',
  'renderExemptList',
  'openExempt',
  'toggleExemptMenu',
  'activeExemptMenuKey',
  'data-action="copy-message"',
  'data-long-press-mention',
  'data-action="toggle-avatar-menu"',
  'activeAvatarMenuKey',
  'toggleAvatarMenu',
  'canShowAvatarDenyMenu',
  'SenderAddressNotSenderIdOwner',
  'ChatNotActivated',
  'PostingNotAllowed',
  'messagesForChat',
  'renderMessageContent',
  'showBlacklistedMessages',
  'messageSenderDenied',
  'shouldHideMessage',
  'toggle-show-blacklisted',
  'set-show-blacklisted',
  '显示黑名单消息',
  '黑名单消息默认隐藏',
  'quotedMessagesByGroupId',
  'activeQuotedMessageId',
  'clearActiveQuote',
  'canQuoteMessage',
  'avatarLongPressMs',
  'insertComposerToken',
  'parseComposerMentionedSenderIds',
  'mentionSenderIdsValidationHint',
  'duplicateCount',
  'overLimitCount',
  'openGovVoters',
  '查看voter列表',
  'voterList',
  'setVoterPage',
  'queryVoter',
  'revalidateVoter',
  'voterPage',
  'openActivation',
  'renderActivationHub',
  'renderActivationForm',
  'setActivationOption',
  'renderChainServiceManagement',
  'renderDelegateInput',
  'delegateDisplay',
  'delegateQueryResult',
  'resolveOptionalKnownNftInput',
  'managementNotice',
  'renderAdminIdControls',
  'setAdminIdQueryType',
  'resolveAdminIdQuery',
  '按名称',
  '按编号',
  'queryAdminSelf',
  'queryAdminId',
  'ruleSlotDisplay',
  'admin-nft-row',
  'renderBlacklistControls',
  'blacklist-controls',
  '黑名单',
  '豁免名单',
  'renderGovBlacklist',
  'renderAdminBlacklist',
  'queryBlacklist',
  'ownerOfGroupId',
  'validDefaultGroupIdOf',
  'addSenderDenyFromMessage',
  'denyBySenderIds',
  'denyBySenders',
  'simulateMessageGap',
  'simulate-message-gap',
  'conversationStatus',
  'unreadMessagesForChat',
  'messages(${resolvedGroupId}, ${latestMessageId}, ${eventMessageId - latestMessageId}, false)',
  'data-action="add-sender-deny"',
  'revalidateGovVote',
  'canEditRules',
  'canEditAdminDeny',
  'canEditExempt',
  'activateChat',
  '配置入参',
  'setRuleSlot',
  'MessagePost',
];

for (const needle of requiredAppJs) {
  if (!js.includes(needle)) {
    throw new Error(`Missing app.js marker: ${needle}`);
  }
}

const requiredDataJs = [
  '爱聊',
  'defaultGroupId',
  'bottomTabs',
  'TokenMainManager',
  'TokenGovManager',
  'TokenActionMainManager',
  'TokenActionGovManager',
  'GroupJoinScopeSource',
  'AdminDenySource',
  'GovVotedDenySource',
  'groupOwners',
  'defaultGroupIdsByAddress',
  'activationTabs',
];

for (const needle of requiredDataJs) {
  if (!data.includes(needle)) {
    throw new Error(`Missing prototype-data.js marker: ${needle}`);
  }
}

const legacyManagerNames = [
  'Token',
  'TokenGov',
  'TokenAction',
  'TokenActionGov',
].map((prefix) => `${prefix}GroupChatManager`);

for (const legacyName of legacyManagerNames) {
  if (data.includes(legacyName) || js.includes(legacyName)) {
    throw new Error(`Legacy manager name must not be used: ${legacyName}`);
  }
}

const dataWindow = {};
new Function('window', data)(dataWindow);
const prototypeData = dataWindow.LOVE20_CHAT_PROTOTYPE_DATA;
if (!prototypeData || !prototypeData.initialState) {
  throw new Error('prototype-data.js did not define LOVE20_CHAT_PROTOTYPE_DATA.initialState');
}

const { initialState } = prototypeData;
if (initialState.senderId !== undefined || initialState.defaultGroupId === undefined) {
  throw new Error('initialState must use defaultGroupId for the current account posting identity');
}
if (!Array.isArray(initialState.chats) || !initialState.chats.length) {
  throw new Error('initialState.chats must be a non-empty array');
}
if (!Array.isArray(initialState.messages)) {
  throw new Error('initialState.messages must be an array');
}

const chatIds = new Set();
for (const chat of initialState.chats) {
  if (chatIds.has(chat.groupId)) throw new Error(`Duplicate chat groupId: ${chat.groupId}`);
  chatIds.add(chat.groupId);
  for (const field of ['groupId', 'shortTitle', 'type', 'model', 'manager', 'params', 'chatInfo']) {
    if (chat[field] === undefined) throw new Error(`Chat ${chat.groupId} missing ${field}`);
  }
  if (chat.blacklistMode === 'gov' && !chat.govDeny) throw new Error(`Gov chat ${chat.groupId} missing govDeny`);
  if (chat.blacklistMode === 'gov') {
    for (const field of ['addressDenyList', 'senderIdDenyList', 'addressTargets', 'senderIdTargets']) {
      if (!Array.isArray(chat.govDeny[field])) throw new Error(`Gov chat ${chat.groupId} govDeny.${field} must be an array`);
    }
  }
  if (chat.blacklistMode === 'admin' && !chat.adminDeny) throw new Error(`Admin chat ${chat.groupId} missing adminDeny`);
  if (chat.params?.token !== undefined) {
    if (!/^0x[a-fA-F0-9]{40}$/.test(chat.params.token)) {
      throw new Error(`Chat ${chat.groupId} params.token must be a token contract address`);
    }
    if (chat.tokenAddress !== chat.params.token) {
      throw new Error(`Chat ${chat.groupId} tokenAddress must match params.token`);
    }
  }
}

for (const action of initialState.actions) {
  if (!chatIds.has(action.actionGroupId)) throw new Error(`Action ${action.actionId} missing actionGroupId ${action.actionGroupId}`);
  if (!chatIds.has(action.actionGovGroupId)) throw new Error(`Action ${action.actionId} missing actionGovGroupId ${action.actionGovGroupId}`);
}

for (const message of initialState.messages) {
  if (!chatIds.has(Number(message.groupId))) {
    throw new Error(`Message ${message.messageId} points to missing groupId ${message.groupId}`);
  }
}

const hasInvalidMessageId = initialState.messages.some((message) => message.messageId === 0);
const hasFirstMessageId = initialState.messages.some((message) => message.messageId === 1);
if (hasInvalidMessageId || !hasFirstMessageId) {
  throw new Error('Prototype fixture must use 1-based local message ids');
}

const messageIdsByChat = new Map();
for (const message of initialState.messages) {
  const key = String(message.groupId);
  if (!messageIdsByChat.has(key)) messageIdsByChat.set(key, new Set());
  const indexes = messageIdsByChat.get(key);
  if (indexes.has(message.messageId)) {
    throw new Error(`Duplicate messageId ${message.messageId} in groupId ${key}`);
  }
  indexes.add(message.messageId);
}

const requiredProtocolCopy = [
  'chatInfo',
  'senderId',
  'scopeSource',
  'denySource',
  'beforePostPlugin',
  'afterPostPlugin',
  'delegateId',
  'stateVersion',
  'denyThresholdRatio',
  'totalWeight',
  'addressDenyList',
  'senderIdDenyList',
  'senderIdExemptList',
  'voteWeight',
  'tokenAddress',
  'revalidate',
  '激活群聊',
  '代币群',
  '大群 ${chatTokenSymbol(chat)}',
  '治理群 ${chatTokenSymbol(chat)}',
  '行动大群',
  '行动治理群',
  '链群#${chat.groupId}',
  '春节公益铸造',
  '雪松节点',
];

for (const needle of requiredProtocolCopy) {
  if (!prototypeSource.includes(needle)) {
    throw new Error(`Missing protocol copy: ${needle}`);
  }
}

const mentionParserHarness = new Function(
  'state',
  [
    extractFunctionSource(js, 'nftProfile'),
    extractFunctionSource(js, 'mentionTokenFor'),
    extractFunctionSource(js, 'parseComposerMentionedSenderIds'),
    extractFunctionSource(js, 'tokenOccurrences'),
    extractFunctionSource(js, 'mentionSenderIdsValidationHint'),
    'return { parseComposerMentionedSenderIds, mentionSenderIdsValidationHint };',
  ].join('\n'),
);

const mentionTestState = {
  mentionedSenderIds: [],
  nftProfiles: Object.fromEntries(
    Array.from({ length: 34 }, (_, index) => {
      const id = String(7000 + index);
      const name = `成员${String(index + 1).padStart(2, '0')}`;
      return [id, { name, badge: '测' }];
    }),
  ),
};
const { parseComposerMentionedSenderIds, mentionSenderIdsValidationHint } = mentionParserHarness(mentionTestState);
const overLimitContent = Object.values(mentionTestState.nftProfiles)
  .map((profile) => `@${profile.name}`)
  .join(' ');
const overLimitDraft = parseComposerMentionedSenderIds(overLimitContent);
if (overLimitDraft.mentionedSenderIds.length !== 34 || overLimitDraft.overLimitCount !== 2) {
  throw new Error('Mention parser must keep over-limit mentionedSenderIds so sending can be blocked');
}
const overLimitHint = mentionSenderIdsValidationHint(overLimitDraft);
if (!overLimitHint.includes('超过 32') || !overLimitHint.includes('请删除 2') || overLimitHint.includes('截断')) {
  throw new Error('Mention validation hint must explain that overflow blocks sending');
}

const duplicateDraft = parseComposerMentionedSenderIds('@成员01 @成员01');
if (duplicateDraft.mentionedSenderIds.length !== 1 || duplicateDraft.duplicateCount !== 1) {
  throw new Error('Mention parser must dedupe repeated @ tokens and report duplicate count');
}
if (!mentionSenderIdsValidationHint(duplicateDraft).includes('已去重 1')) {
  throw new Error('Mention validation hint must explain duplicate dedupe');
}

const blacklistHarness = new Function(
  'state',
  [
    extractFunctionSource(js, 'sameAddress'),
    extractFunctionSource(js, 'govAddressDenied'),
    extractFunctionSource(js, 'govSenderIdDenied'),
    extractFunctionSource(js, 'messagePreferenceKey'),
    extractFunctionSource(js, 'groupMessagePreference'),
    extractFunctionSource(js, 'showBlacklistedMessages'),
    extractFunctionSource(js, 'messageSenderDenied'),
    extractFunctionSource(js, 'shouldHideMessage'),
    'return { showBlacklistedMessages, messageSenderDenied, shouldHideMessage };',
  ].join('\n'),
);

const blacklistState = JSON.parse(JSON.stringify(initialState));
blacklistState.localMessagePreferences = {};
const blacklistApi = blacklistHarness(blacklistState);
const blacklistChat = blacklistState.chats.find((chat) => chat.groupId === 1024);
const blacklistedMessage = blacklistState.messages.find((message) => message.groupId === '1024' && message.senderAddress === '0x44...aa');
if (!blacklistedMessage) {
  throw new Error('Fixture must include a message from a blacklisted sender');
}
if (!blacklistApi.messageSenderDenied(blacklistChat, blacklistedMessage)) {
  throw new Error('Blacklisted sender message must be detected from address or NFT deny state');
}
blacklistChat.govDeny.addressTargets.push({ target: '0x55...aa', support: 20, oppose: 1, voters: 2, myVote: null, myWeight: 0, voterList: [] });
const unsettledVoteMessage = { groupId: '1024', senderId: 9012, senderAddress: '0x55...aa' };
if (blacklistApi.messageSenderDenied(blacklistChat, unsettledVoteMessage)) {
  throw new Error('Gov messages must use the settled deny list, not support/oppose tallies, for hidden state');
}
if (!blacklistApi.shouldHideMessage(blacklistChat, blacklistedMessage)) {
  throw new Error('Blacklisted sender message must be hidden by default');
}
blacklistState.localMessagePreferences[`${blacklistState.account}:1024`] = { showBlacklistedMessages: true };
if (!blacklistApi.showBlacklistedMessages('1024')) {
  throw new Error('Local preference must enable blacklisted message display per account and group');
}
if (blacklistApi.shouldHideMessage(blacklistChat, blacklistedMessage)) {
  throw new Error('Blacklisted sender message must show after local preference is enabled');
}

const sendHarness = new Function(
  'state',
  'document',
  'render',
  [
    extractFunctionSource(js, 'nftProfile'),
    extractFunctionSource(js, 'mentionTokenFor'),
    extractFunctionSource(js, 'parseComposerMentionedSenderIds'),
    extractFunctionSource(js, 'tokenOccurrences'),
    extractFunctionSource(js, 'mentionSenderIdsValidationHint'),
    extractFunctionSource(js, 'messagesForChat'),
    extractFunctionSource(js, 'currentDefaultGroupId'),
    'function activeChatEntry() { return { kind: "group", item: state.chat }; }',
    'function chatStatus() { return { allowed: true, reasonCode: "0x00000000" }; }',
    'function activeQuotedMessageId() { return 0; }',
    'function clearActiveQuote() {}',
    extractFunctionSource(js, 'sendMessage'),
    'return { sendMessage };',
  ].join('\n'),
);

const sendState = {
  account: '0x8b...91',
  defaultGroupId: 9007,
  activeGroupId: '1024',
  messages: [],
  mentionedSenderIds: [],
  mentionAll: false,
  syncHint: '',
  chat: { round: 42 },
  nftProfiles: mentionTestState.nftProfiles,
};
const sendInput = { value: overLimitContent };
const sendDocument = {
  getElementById(id) {
    if (id === 'composer-input') return sendInput;
    throw new Error(`Unexpected document lookup: ${id}`);
  },
};
sendHarness(sendState, sendDocument, () => {}).sendMessage();
if (sendState.messages.length !== 0 || !sendState.syncHint.includes('TooManyMentionedSenderIds')) {
  throw new Error('sendMessage must block over-limit mentionedSenderIds instead of truncating and sending');
}

const quoteHarness = new Function(
  'state',
  'render',
  [
    extractFunctionSource(js, 'messagesForChat'),
    extractFunctionSource(js, 'messageById'),
    extractFunctionSource(js, 'canQuoteMessage'),
    extractFunctionSource(js, 'quoteMessage'),
    'return { canQuoteMessage, quoteMessage };',
  ].join('\n'),
);

const quoteTestState = {
  activeGroupId: '1024',
  activeMenuMessageId: 0,
  quotedMessagesByGroupId: {},
  messages: [
    { groupId: '1024', messageId: 1 },
    { groupId: '1024', messageId: 2 },
  ],
};
const { canQuoteMessage, quoteMessage } = quoteHarness(quoteTestState, () => {});
if (!canQuoteMessage(quoteTestState.messages[0]) || !canQuoteMessage(quoteTestState.messages[1])) {
  throw new Error('canQuoteMessage must allow positive local message ids');
}
quoteMessage(0);
if (quoteTestState.quotedMessagesByGroupId['1024'] !== undefined) {
  throw new Error('quoteMessage must ignore missing messageId 0');
}
quoteMessage(1);
if (quoteTestState.quotedMessagesByGroupId['1024'] !== 1) {
  throw new Error('quoteMessage must store positive messageId quotes');
}

const chatMenuHarness = new Function(
  'state',
  'render',
  [
    extractFunctionSource(js, 'toggleChatMenu'),
    'return { toggleChatMenu };',
  ].join('\n'),
);

const chatMenuState = { activeGroupMenuId: null };
let chatMenuRenderCount = 0;
const { toggleChatMenu } = chatMenuHarness(chatMenuState, () => { chatMenuRenderCount += 1; });
toggleChatMenu('1301');
if (chatMenuState.activeGroupMenuId !== 1301 || chatMenuRenderCount !== 1) {
  throw new Error('toggleChatMenu must open the menu for the requested groupId');
}
toggleChatMenu('1301');
if (chatMenuState.activeGroupMenuId !== null || chatMenuRenderCount !== 2) {
  throw new Error('toggleChatMenu must close the active groupId menu');
}

const adminIdQueryHarness = new Function(
  'state',
  'render',
  [
    extractFunctionSource(js, 'activeChat'),
    extractFunctionSource(js, 'nftProfile'),
    extractFunctionSource(js, 'resolveNftInput'),
    extractFunctionSource(js, 'queryAdminIdValue'),
    'return { queryAdminIdValue };',
  ].join('\n'),
);

const adminIdQueryState = JSON.parse(JSON.stringify(initialState));
adminIdQueryState.activeGroupNumericId = 1301;
adminIdQueryState.adminIdQueryType = 'name';
let adminIdQueryRenderCount = 0;
adminIdQueryHarness(adminIdQueryState, () => { adminIdQueryRenderCount += 1; }).queryAdminIdValue('链群管理员', true);
if (!adminIdQueryState.adminIdQueryResult.includes('NFT #1310')
  || !adminIdQueryState.adminIdQueryResult.includes('已在管理员名单')
  || adminIdQueryRenderCount !== 1) {
  throw new Error('queryAdminIdValue must render the resolved admin NFT status');
}

const managerActivateHarness = new Function(
  'state',
  'render',
  [
    extractFunctionSource(js, 'chatById'),
    extractFunctionSource(js, 'nextManagedGroupId'),
    extractFunctionSource(js, 'syncManagedGroupId'),
    'function captureActivationDraft(chat) { return state.activationDrafts[String(chat.groupId)] || { ...chat.params }; }',
    'function activationBlocker() { return ""; }',
    'function activationPreview(chat, draft) { const values = Object.keys(chat.params).map((key) => draft[key]).join(", "); return `${chat.manager}.activate(${values})`; }',
    'function resolveOptionalKnownNftInput(value) { return value; }',
    extractFunctionSource(js, 'activateChat'),
    'return { activateChat };',
  ].join('\n'),
);

const managerActivationState = JSON.parse(JSON.stringify(initialState));
const expectedMintedGroupId =
  managerActivationState.chats.reduce((maxId, chat) => Math.max(maxId, Number(chat.groupId) || 0), 0) + 1;
managerActivateHarness(managerActivationState, () => {}).activateChat(1189);

const activatedActionGovChat = managerActivationState.chats.find((chat) => chat.type === 'action-gov' && chat.actionId === '77');
const linkedAction = managerActivationState.actions.find((action) => action.token === 'LOVE20A' && action.actionId === '77');
if (!activatedActionGovChat || !activatedActionGovChat.activated || !activatedActionGovChat.postingAllowed) {
  throw new Error('Manager activation must mark the chat activated and postingAllowed');
}
if (activatedActionGovChat.groupId !== expectedMintedGroupId) {
  throw new Error('Manager activation must replace the placeholder groupId with the minted groupId');
}
if (managerActivationState.activeGroupNumericId !== expectedMintedGroupId
  || managerActivationState.activeGroupId !== String(expectedMintedGroupId)) {
  throw new Error('Manager activation must switch the active chat to the minted groupId');
}
if (!linkedAction || linkedAction.actionGovGroupId !== expectedMintedGroupId) {
  throw new Error('Manager activation must sync action references to the minted groupId');
}
if (!managerActivationState.syncHint.includes(`groupId ${expectedMintedGroupId}`)) {
  throw new Error('Manager activation hint must mention the minted groupId');
}

console.log('LOVE20 Chat prototype smoke test passed');
