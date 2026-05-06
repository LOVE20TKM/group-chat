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
  throw new Error('Mentions must render in composer text, not composer chips');
}

if (html.includes('data-action="open-more"') || html.includes('id="more-panel"') || js.includes('openMorePanel')) {
  throw new Error('Chat composer must not render a plus/more panel');
}

if (js.includes('mentions: [...state.mentions]') || js.includes('mentionAll: state.mentionAll')) {
  throw new Error('Sending must parse mentions from composer content');
}

if (js.includes('...state.messages.map((message) => message.messageIndex)')) {
  throw new Error('messageIndex must be calculated per chatGroupId, not globally');
}

if (data.includes('indexMode') || js.includes('setIndexMode') || js.includes('set-index-mode')) {
  throw new Error('Index mode switch is not part of the current prototype interaction');
}

if (js.includes('state.senderGroupId')) {
  throw new Error('Current account posting identity must use defaultGroupId');
}

if (data.includes('senderOwnerMatches') || js.includes('senderOwnerMatches') || js.includes('senderGroupId 的 owner')) {
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
  throw new Error('Prototype data and handlers must use chatGroupId, not conversationId');
}

if (!js.includes('function canQuoteMessage(') || !js.includes('canQuoteMessage(message)')) {
  throw new Error('Prototype must hide quote actions for messageIndex 0');
}

if (data.includes('quotedMessageIndex: null') || js.includes('state.quotedMessageIndex')) {
  throw new Error('Composer quote state must be stored by chatGroupId');
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

const dataScriptIndex = html.indexOf('src="./prototype-data.js"');
const appScriptIndex = html.indexOf('src="./app.js"');
if (dataScriptIndex === -1 || appScriptIndex === -1 || dataScriptIndex > appScriptIndex) {
  throw new Error('prototype-data.js must load before app.js');
}

const requiredCss = [
  '--primary: #0f766e',
  '.bottom-nav',
  '.conversation-row',
  '.conversation-row.group-row',
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
  'SenderNotGroupOwner',
  'ChatNotActive',
  'messagesForChat',
  'renderMessageContent',
  'quotedMessagesByChatGroupId',
  'activeQuotedMessageIndex',
  'clearActiveQuote',
  'canQuoteMessage',
  'avatarLongPressMs',
  'insertComposerToken',
  'parseComposerMentions',
  'mentionValidationHint',
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
  'renderAdminGroupControls',
  'setAdminGroupQueryType',
  'resolveAdminGroupQuery',
  '按名称',
  '按编号',
  'queryAdminSelf',
  'queryAdminGroup',
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
  'addDenyListsBySenderGroupIds',
  'simulateMessageGap',
  'simulate-message-gap',
  'messages(${chatGroupId}, ${startIndex}, ${eventIndex - latestIndex}, false)',
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
  'TokenGroupChatManager',
  'TokenGovGroupChatManager',
  'TokenActionGroupChatManager',
  'TokenActionGovGroupChatManager',
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

const dataWindow = {};
new Function('window', data)(dataWindow);
const prototypeData = dataWindow.LOVE20_CHAT_PROTOTYPE_DATA;
if (!prototypeData || !prototypeData.initialState) {
  throw new Error('prototype-data.js did not define LOVE20_CHAT_PROTOTYPE_DATA.initialState');
}

const { initialState } = prototypeData;
if (initialState.senderGroupId !== undefined || initialState.defaultGroupId === undefined) {
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
  for (const field of ['groupId', 'shortTitle', 'type', 'model', 'manager', 'params', 'ruleSlots']) {
    if (chat[field] === undefined) throw new Error(`Chat ${chat.groupId} missing ${field}`);
  }
  if (chat.blacklistMode === 'gov' && !chat.govDeny) throw new Error(`Gov chat ${chat.groupId} missing govDeny`);
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
  if (!chatIds.has(action.actionChatId)) throw new Error(`Action ${action.actionId} missing actionChatId ${action.actionChatId}`);
  if (!chatIds.has(action.actionGovChatId)) throw new Error(`Action ${action.actionId} missing actionGovChatId ${action.actionGovChatId}`);
}

for (const message of initialState.messages) {
  if (!chatIds.has(Number(message.chatGroupId))) {
    throw new Error(`Message ${message.messageIndex} points to missing chatGroupId ${message.chatGroupId}`);
  }
}

const visibleZeroQuoteConversation = initialState.messages.some((message) => message.messageIndex === 0)
  && initialState.messages.some((message) => message.messageIndex > 0);
if (!visibleZeroQuoteConversation) {
  throw new Error('Prototype fixture must include a visible messageIndex 0 example');
}

const messageIndexesByChat = new Map();
for (const message of initialState.messages) {
  const key = String(message.chatGroupId);
  if (!messageIndexesByChat.has(key)) messageIndexesByChat.set(key, new Set());
  const indexes = messageIndexesByChat.get(key);
  if (indexes.has(message.messageIndex)) {
    throw new Error(`Duplicate messageIndex ${message.messageIndex} in chatGroupId ${key}`);
  }
  indexes.add(message.messageIndex);
}

const requiredProtocolCopy = [
  'ruleSlots',
  'senderGroupId',
  'scopeSource',
  'denySource',
  'beforePostPlugin',
  'afterPostPlugin',
  'delegateGroupId',
  'stateVersion',
  'addressDenyList',
  'senderGroupIdDenyList',
  'senderGroupIdExemptList',
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
    extractFunctionSource(js, 'parseComposerMentions'),
    extractFunctionSource(js, 'tokenOccurrences'),
    extractFunctionSource(js, 'mentionValidationHint'),
    'return { parseComposerMentions, mentionValidationHint };',
  ].join('\n'),
);

const mentionTestState = {
  mentions: [],
  nftProfiles: Object.fromEntries(
    Array.from({ length: 34 }, (_, index) => {
      const id = String(7000 + index);
      const name = `成员${String(index + 1).padStart(2, '0')}`;
      return [id, { name, badge: '测' }];
    }),
  ),
};
const { parseComposerMentions, mentionValidationHint } = mentionParserHarness(mentionTestState);
const overLimitContent = Object.values(mentionTestState.nftProfiles)
  .map((profile) => `@${profile.name}`)
  .join(' ');
const overLimitDraft = parseComposerMentions(overLimitContent);
if (overLimitDraft.mentions.length !== 34 || overLimitDraft.overLimitCount !== 2) {
  throw new Error('Mention parser must keep over-limit mentions so sending can be blocked');
}
const overLimitHint = mentionValidationHint(overLimitDraft);
if (!overLimitHint.includes('超过 32') || !overLimitHint.includes('请删除 2') || overLimitHint.includes('截断')) {
  throw new Error('Mention validation hint must explain that overflow blocks sending');
}

const duplicateDraft = parseComposerMentions('@成员01 @成员01');
if (duplicateDraft.mentions.length !== 1 || duplicateDraft.duplicateCount !== 1) {
  throw new Error('Mention parser must dedupe repeated @ tokens and report duplicate count');
}
if (!mentionValidationHint(duplicateDraft).includes('已去重 1')) {
  throw new Error('Mention validation hint must explain duplicate dedupe');
}

const sendHarness = new Function(
  'state',
  'document',
  'render',
  [
    extractFunctionSource(js, 'nftProfile'),
    extractFunctionSource(js, 'mentionTokenFor'),
    extractFunctionSource(js, 'parseComposerMentions'),
    extractFunctionSource(js, 'tokenOccurrences'),
    extractFunctionSource(js, 'mentionValidationHint'),
    extractFunctionSource(js, 'messagesForChat'),
    extractFunctionSource(js, 'currentDefaultGroupId'),
    'function activeChatEntry() { return { kind: "group", item: state.chat }; }',
    'function chatStatus() { return { allowed: true, reasonCode: "0x00000000" }; }',
    'function activeQuotedMessageIndex() { return 0; }',
    'function clearActiveQuote() {}',
    extractFunctionSource(js, 'sendMessage'),
    'return { sendMessage };',
  ].join('\n'),
);

const sendState = {
  account: '0x8b...91',
  defaultGroupId: 9007,
  activeChatGroupId: '1024',
  messages: [],
  mentions: [],
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
if (sendState.messages.length !== 0 || !sendState.syncHint.includes('TooManyMentions')) {
  throw new Error('sendMessage must block over-limit mentions instead of truncating and sending');
}

const quoteHarness = new Function(
  'state',
  'render',
  [
    extractFunctionSource(js, 'messagesForChat'),
    extractFunctionSource(js, 'messageByIndex'),
    extractFunctionSource(js, 'canQuoteMessage'),
    extractFunctionSource(js, 'quoteMessage'),
    'return { canQuoteMessage, quoteMessage };',
  ].join('\n'),
);

const quoteTestState = {
  activeChatGroupId: '1024',
  activeMenuIndex: 0,
  quotedMessagesByChatGroupId: {},
  messages: [
    { chatGroupId: '1024', messageIndex: 0 },
    { chatGroupId: '1024', messageIndex: 1 },
  ],
};
const { canQuoteMessage, quoteMessage } = quoteHarness(quoteTestState, () => {});
if (canQuoteMessage(quoteTestState.messages[0]) || !canQuoteMessage(quoteTestState.messages[1])) {
  throw new Error('canQuoteMessage must reject messageIndex 0 and allow positive messageIndex');
}
quoteMessage(0);
if (quoteTestState.quotedMessagesByChatGroupId['1024'] !== undefined) {
  throw new Error('quoteMessage must ignore messageIndex 0');
}
quoteMessage(1);
if (quoteTestState.quotedMessagesByChatGroupId['1024'] !== 1) {
  throw new Error('quoteMessage must store positive messageIndex quotes');
}

console.log('LOVE20 Chat prototype smoke test passed');
