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

if (data.includes('inboxFilters') || data.includes('inboxFilter') || js.includes('set-inbox-filter')) {
  throw new Error('Inbox list must use pinned/recommended sections, not filter tabs');
}

if (prototypeSource.includes('group-icon') || js.includes('chatIconLabel')) {
  throw new Error('Inbox conversation rows must not render group icons');
}

if (prototypeSource.includes('conversation-group-id') || prototypeSource.includes('conversation-side')) {
  throw new Error('Inbox conversation rows must not render right-side group id');
}

if (prototypeSource.includes('type-meta') || js.includes('chatAccessLabel') || js.includes('chatControlLabel')) {
  throw new Error('Inbox reminder row must not include posting or manager status badges');
}

if (prototypeSource.includes('conversation-badges')) {
  throw new Error('Inbox reminders must render in the first row, not as a third row');
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

const conversationRowBlock = css.match(/\.conversation-row \{([\s\S]*?)\n\}/)?.[1] || '';
if (conversationRowBlock.includes('border-radius') || conversationRowBlock.includes('box-shadow')) {
  throw new Error('Inbox conversation rows must render as a flat list, not rounded cards');
}

const requiredHtml = [
  'data-entry="love20-chat"',
  'id="wallet-button"',
  'id="bottom-nav"',
  'id="workspace-screen"',
  'id="message-list"',
  'id="composer-input"',
  'placeholder="输入公开链上消息"',
  'id="composer-banned"',
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
  '--primary: #191c1f',
  '--primary-action: #1e3a8a',
  '--secondary: #2926e8',
  '--greyscale-200: #e1e6ea',
  '.bottom-nav',
  '.conversation-row',
  '.conversation-row.group-row',
  '.conversation-section-label',
  '.conversation-menu',
  '.conversation-badge.mention-me',
  '.conversation-badge.mention-all',
  '.chat-menu-button',
  '.chat-menu',
  '.message-mention',
  '.blacklist-row',
  '.blacklist-menu',
  '.pager-row',
  '.inbox-action-row',
  '.filter-tabs',
  '.action-row',
  '.query-row',
  '.composer-banned',
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
  'renderConversationSection',
  'chatDisplayName',
  'activationTypeForChat',
  'renderActivationSection',
  'renderChatMenuButtons',
  'set-activation-type',
  'toggleChatMenu',
  'toggleConversationPin',
  'activeConversationMenuGroupId',
  'activeGroupMenuId',
  'pageReturnStack',
  'renderGroupDetails',
  'openDetails',
  'postBanReason',
  'scopeSourceReason',
  'blacklistQueryType',
  'blacklistRows',
  'govMyVoteDetail',
  'adminBanListPage',
  'adminBanRowsFromPage',
  'setAdminBanOperator',
  'setBlacklistQueryType',
  'setNftInputMode',
  'set-nft-input-mode-select',
  'set-admin-query-type-select',
  'set-member-query-type-select',
  'setBlacklistPage',
  'toggleBlacklistMenu',
  'data-action="copy-message"',
  'data-long-press-mention',
  'data-long-press-conversation',
  'data-action="toggle-avatar-menu"',
  'activeAvatarMenuKey',
  'toggleAvatarMenu',
  'canShowAvatarBanMenu',
  'SenderAddressNotSenderIdOwner',
  'ChatNotActivated',
  'PostingNotAllowed',
  'messagesForChat',
  'renderMessageContent',
  'showBlacklistedMessages',
  'messageSenderBanned',
  'shouldHideMessage',
  'set-show-blacklisted',
  '显示黑名单消息',
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
  '投票列表',
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
  'renderNftLookupControl',
  'delegateDisplay',
  'delegateQueryResult',
  'resolveOptionalKnownNftInput',
  'managementNotice',
  'renderAdminIdControls',
  'renderMemberIdControls',
  'setAdminIdQueryType',
  'setMemberIdQueryType',
  'NFT名称',
  'NFT ID',
  'queryAdminSelf',
  'queryAdminId',
  'queryMemberSelf',
  'queryMemberId',
  'admin-nft-row',
  'renderBlacklistControls',
  'blacklist-controls',
  '黑名单',
  'renderGovBlacklist',
  'renderAdminBlacklist',
  'queryBlacklist',
  'ownerOfGroupId',
  'validDefaultGroupIdOf',
  'addSenderBanFromMessage',
  'banBySenderIds',
  'banBySenders',
  'conversationStatus',
  'unreadMessagesForChat',
  'data-action="add-sender-ban"',
  'revalidateGovVote',
  'canEditRules',
  'canEditAdminBan',
  'canEditMemberScope',
  'groupAdminState',
  'groupMemberScopeState',
  'activateChat',
  '配置入参',
  'setRuleSlot',
  'MessagePost',
  'GroupMemberScope.addMemberIds',
  'setDelegateId',
  'set-delegate-id',
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
  'GroupMemberScope',
  'GroupJoinScopeSource',
  'AdminBanSource',
  'GovVotedBanSource',
  'groupAdmin',
  'groupMemberScope',
  'addressBanOperatorStates',
  'senderIdBanOperatorStates',
  'memberIds',
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
  if (chat.blacklistMode === 'gov' && !chat.govBan) throw new Error(`Gov chat ${chat.groupId} missing govBan`);
  if (chat.blacklistMode === 'gov') {
    for (const field of ['addressBanList', 'senderIdBanList', 'addressTargets', 'senderIdTargets']) {
      if (!Array.isArray(chat.govBan[field])) throw new Error(`Gov chat ${chat.groupId} govBan.${field} must be an array`);
    }
  }
  if (chat.blacklistMode === 'admin' && !chat.adminBan) throw new Error(`Admin chat ${chat.groupId} missing adminBan`);
  if (chat.blacklistMode === 'admin') {
    if (!chat.groupAdmin) throw new Error(`Admin chat ${chat.groupId} missing groupAdmin`);
    if (!Array.isArray(chat.groupAdmin.adminIds)) throw new Error(`Admin chat ${chat.groupId} groupAdmin.adminIds must be an array`);
    if ('adminIds' in chat.adminBan) throw new Error(`Admin chat ${chat.groupId} must not store adminIds under adminBan`);
    for (const field of ['addressBanOperatorStates', 'senderIdBanOperatorStates']) {
      if (!chat.adminBan[field] || typeof chat.adminBan[field] !== 'object' || Array.isArray(chat.adminBan[field])) {
        throw new Error(`Admin chat ${chat.groupId} adminBan.${field} must be an object`);
      }
    }
  }
  if (chat.model === 'chain-service') {
    if (!chat.groupMemberScope) throw new Error(`Chain service chat ${chat.groupId} missing groupMemberScope`);
    if (!Array.isArray(chat.groupMemberScope.memberIds)) {
      throw new Error(`Chain service chat ${chat.groupId} groupMemberScope.memberIds must be an array`);
    }
  }
  if (chat.params?.token !== undefined) {
    if (!/^0x[a-fA-F0-9]{40}$/.test(chat.params.token)) {
      throw new Error(`Chat ${chat.groupId} params.token must be a token contract address`);
    }
    if (chat.tokenAddress !== chat.params.token) {
      throw new Error(`Chat ${chat.groupId} tokenAddress must match params.token`);
    }
  }
}

if (!Array.isArray(initialState.pinnedGroupIds)) {
  throw new Error('initialState.pinnedGroupIds must be an array');
}
for (const groupId of initialState.pinnedGroupIds) {
  if (!chatIds.has(Number(groupId))) throw new Error(`Pinned chat groupId not found: ${groupId}`);
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
  'banSource',
  'beforePostPlugin',
  'afterPostPlugin',
  'groupDelegate',
  'stateVersion',
  'banThresholdRatio',
  'totalWeight',
  'addressBanList',
  'senderIdBanList',
  'addressBanOperatorStates',
  'senderIdBanOperatorStates',
  'GroupAdmin',
  'GroupMemberScope',
  'memberIds',
  'voteWeight',
  'tokenAddress',
  'revalidate',
  '激活群聊',
  '代币群',
  '${chatTokenSymbol(chat)} 主群',
  '${chatTokenSymbol(chat)} 治理群',
  '行动主群-No.',
  '行动治理群-No.',
  '链群-${chat.chainName || chat.groupId}',
  '春节公益铸造',
  '雪松节点',
  '我的投票：',
  '拉黑人：',
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
  throw new Error('Mention parser must keep over-limit mentionedSenderIds so sending can be banned');
}
const overLimitHint = mentionSenderIdsValidationHint(overLimitDraft);
if (!overLimitHint.includes('超过 32') || !overLimitHint.includes('请删除 2') || overLimitHint.includes('截断')) {
  throw new Error('Mention validation hint must explain that overflow prevents sending');
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
    extractFunctionSource(js, 'govAddressBanned'),
    extractFunctionSource(js, 'govSenderIdBanned'),
    extractFunctionSource(js, 'messagePreferenceKey'),
    extractFunctionSource(js, 'groupMessagePreference'),
    extractFunctionSource(js, 'showBlacklistedMessages'),
    extractFunctionSource(js, 'messageSenderBanned'),
    extractFunctionSource(js, 'shouldHideMessage'),
    'return { showBlacklistedMessages, messageSenderBanned, shouldHideMessage };',
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
if (!blacklistApi.messageSenderBanned(blacklistChat, blacklistedMessage)) {
  throw new Error('Blacklisted sender message must be detected from address or NFT ban state');
}
blacklistChat.govBan.addressTargets.push({ target: '0x55...aa', support: 20, oppose: 1, voters: 2, myVote: null, myWeight: 0, voterList: [] });
const unsettledVoteMessage = { groupId: '1024', senderId: 9012, senderAddress: '0x55...aa' };
if (blacklistApi.messageSenderBanned(blacklistChat, unsettledVoteMessage)) {
  throw new Error('Gov messages must use the settled ban list, not support/oppose tallies, for hidden state');
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

const blacklistRowsHarness = new Function(
  'state',
  [
    extractFunctionSource(js, 'nftProfile'),
    extractFunctionSource(js, 'blacklistNftLabel'),
    extractFunctionSource(js, 'sameAddress'),
    extractFunctionSource(js, 'normalizeBlacklistTargetType'),
    extractFunctionSource(js, 'govAddressBanned'),
    extractFunctionSource(js, 'govSenderIdBanned'),
    extractFunctionSource(js, 'govMyVoteDetail'),
    extractFunctionSource(js, 'adminBanOperatorRecord'),
    extractFunctionSource(js, 'adminBanOperatorDetailFromValues'),
    extractFunctionSource(js, 'adminBanTargets'),
    extractFunctionSource(js, 'adminBanListPage'),
    extractFunctionSource(js, 'adminBanRowsFromPage'),
    extractFunctionSource(js, 'blacklistRows'),
    'return { blacklistRows, govMyVoteDetail, adminBanListPage, adminBanRowsFromPage };',
  ].join('\n'),
);

const blacklistRowsApi = blacklistRowsHarness(JSON.parse(JSON.stringify(initialState)));
const govRows = blacklistRowsApi.blacklistRows(initialState.chats.find((chat) => chat.groupId === 1024));
const govSenderRow = govRows.find((row) => row.type === 'nft' && row.target === '9011');
const govAddressRow = govRows.find((row) => row.type === 'address' && row.target === '0x44...aa');
if (!govSenderRow?.detail.includes('我的投票：支持 18') || !govAddressRow?.detail.includes('我的投票：未投票')) {
  throw new Error('Gov blacklist rows must show the current account vote state');
}
if (govSenderRow?.label !== '争议账号' || !govSenderRow.detail.includes('NFT #9011')) {
  throw new Error('Gov NFT blacklist rows must show the NFT name and keep the token id in detail');
}
const adminRows = blacklistRowsApi.blacklistRows(initialState.chats.find((chat) => chat.groupId === 1301));
const adminAddressRow = adminRows.find((row) => row.type === 'address' && row.target === '0x66...d0');
const adminSenderRow = adminRows.find((row) => row.type === 'nft' && row.target === '9017');
if (!adminAddressRow?.detail.includes('NFT #1308') || !adminAddressRow?.detail.includes('0x21...ce')) {
  throw new Error('Admin address ban rows must show who added the blacklist entry');
}
if (!adminSenderRow?.detail.includes('NFT #1310') || !adminSenderRow?.detail.includes('0x31...10')) {
  throw new Error('Admin senderId ban rows must show who added the blacklist entry');
}
if (adminSenderRow?.label !== 'NFT #9017' || !adminSenderRow.detail.includes('NFT #9017')) {
  throw new Error('Admin NFT blacklist rows must fall back to the token id when the NFT name is unavailable');
}
const adminAddressPage = blacklistRowsApi.adminBanListPage(initialState.chats.find((chat) => chat.groupId === 1301), 'address', 0, 1);
if (adminAddressPage.targets[0] !== '0x66...d0' || adminAddressPage.operatorAddresses[0] !== '0x21...ce' || adminAddressPage.operatorIds[0] !== '1308') {
  throw new Error('Admin address ban list page must return target, operatorAddress, and operatorId together');
}
const adminSenderRows = blacklistRowsApi.adminBanRowsFromPage(initialState.chats.find((chat) => chat.groupId === 1301), 'nft', 0, 1);
if (!adminSenderRows[0]?.detail.includes('NFT #9017') || !adminSenderRows[0]?.detail.includes('NFT #1310')) {
  throw new Error('Admin senderId rows must be derived from the paged tuple response and keep both target and operator ids');
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
  throw new Error('sendMessage must prevent over-limit mentionedSenderIds instead of truncating and sending');
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

const groupDetailNavigationHarness = new Function(
  'state',
  'render',
  [
    extractFunctionSource(js, 'chatById'),
    extractFunctionSource(js, 'rememberPageReturn'),
    'function selectChat(groupId) { const chat = chatById(groupId); if (!chat) return; state.activeGroupNumericId = chat.groupId; state.activeGroupId = String(chat.groupId); render(); }',
    extractFunctionSource(js, 'openGroupDetailView'),
    'return { openGroupDetailView };',
  ].join('\n'),
);

const groupDetailNavigationState = {
  bottomTab: 'chat',
  view: 'settings',
  activeGroupId: '1301',
  activeGroupNumericId: 1301,
  activeGroupMenuId: 1301,
  pageReturnStack: [],
  chats: [{ groupId: 1301 }, { groupId: 1302 }],
};
let groupDetailNavigationRenderCount = 0;
const groupDetailNavigation = groupDetailNavigationHarness(groupDetailNavigationState, () => { groupDetailNavigationRenderCount += 1; });
groupDetailNavigation.openGroupDetailView('1301', 'settings');
if (groupDetailNavigationState.pageReturnStack.length !== 0 || groupDetailNavigationState.activeGroupMenuId !== null) {
  throw new Error('Opening the current group detail page must close the menu without pushing a duplicate return entry');
}
if (groupDetailNavigationRenderCount !== 1) {
  throw new Error('Opening the current group detail page must render the closed menu state');
}
groupDetailNavigation.openGroupDetailView('1301', 'members');
if (groupDetailNavigationState.pageReturnStack.length !== 1 || groupDetailNavigationState.view !== 'members') {
  throw new Error('Opening a different group detail page must push the previous page and switch views');
}

const conversationPinHarness = new Function(
  'state',
  'render',
  [
    extractFunctionSource(js, 'chatById'),
    'let suppressConversationClick = true;',
    extractFunctionSource(js, 'toggleConversationPin'),
    'return { toggleConversationPin, getSuppressConversationClick: () => suppressConversationClick };',
  ].join('\n'),
);

const conversationPinState = JSON.parse(JSON.stringify(initialState));
conversationPinState.pinnedGroupIds = [1024];
conversationPinState.activeConversationMenuGroupId = 1301;
conversationPinState.activeGroupMenuId = 1301;
let conversationPinRenderCount = 0;
const conversationPin = conversationPinHarness(conversationPinState, () => { conversationPinRenderCount += 1; });
conversationPin.toggleConversationPin('1301');
if (
  !conversationPinState.pinnedGroupIds.includes(1301)
  || conversationPinState.activeConversationMenuGroupId !== null
  || conversationPinState.activeGroupMenuId !== null
) {
  throw new Error('toggleConversationPin must pin the requested groupId and close every open group menu');
}
conversationPin.toggleConversationPin('1024');
if (conversationPinState.pinnedGroupIds.includes(1024) || conversationPin.getSuppressConversationClick()) {
  throw new Error('toggleConversationPin must unpin existing groupIds and clear suppressed row clicks');
}
if (conversationPinRenderCount !== 2) {
  throw new Error('toggleConversationPin must render after pin state changes');
}

const groupDetailMenuHarness = new Function(
  'state',
  [
    extractFunctionSource(js, 'isPinnedConversation'),
    extractFunctionSource(js, 'renderChatMenuButtons'),
    'function escapeHtml(value) { return String(value); }',
    'function chatDisplayName(chat) { return chat.title || String(chat.groupId); }',
    extractFunctionSource(js, 'groupDetailMetaClass'),
    extractFunctionSource(js, 'renderGroupDetailHeader'),
    'return { renderChatMenuButtons, renderGroupDetailHeader };',
  ].join('\n'),
);

const groupDetailMenuState = JSON.parse(JSON.stringify(initialState));
const groupDetailMenuApi = groupDetailMenuHarness(groupDetailMenuState);
const chatMenu = groupDetailMenuApi.renderChatMenuButtons({ groupId: 1301 });
if (!chatMenu.includes('data-action="open-members" data-group-id="1301">群成员</button>')) {
  throw new Error('Chat view menu must keep detail-page navigation entries');
}
const detailHeader = groupDetailMenuApi.renderGroupDetailHeader({ groupId: 1301, title: '示例群' }, '群成员', '本机');
if (detailHeader.includes('data-action="toggle-chat-menu"') || detailHeader.includes('details-menu-button')) {
  throw new Error('Group detail pages must not render a top-right menu button');
}

const blacklistPanelHarness = new Function(
  'state',
  [
    'function escapeHtml(value) { return String(value); }',
    'function chatDisplayName(chat) { return chat.title || String(chat.groupId); }',
    extractFunctionSource(js, 'groupDetailMetaClass'),
    extractFunctionSource(js, 'renderGroupDetailHeader'),
    'function renderBlacklistPermissionNotice() { return "<div>permission</div>"; }',
    'function renderBlacklistControls() { return "<div>controls</div>"; }',
    'function renderBlacklistRows() { return "<div>rows</div>"; }',
    extractFunctionSource(js, 'renderBlacklistPanel'),
    'return { renderBlacklistPanel };',
  ].join('\n'),
);

const blacklistPanelState = { blacklistQueryType: 'address', nftInputMode: 'id', blacklistQueryResult: '' };
const blacklistPanelApi = blacklistPanelHarness(blacklistPanelState);
const blacklistPanel = blacklistPanelApi.renderBlacklistPanel({ groupId: 1301, title: '示例群', blacklistMode: 'admin', adminBan: { stateVersion: 3 } });
if ((blacklistPanel.match(/示例群/g) || []).length !== 1) {
  throw new Error('Blacklist page must not render the group name twice');
}

const blacklistControlsHarness = new Function(
  'state',
  [
    'function escapeHtml(value) { return String(value); }',
    extractFunctionSource(js, 'renderNftLookupControl'),
    'function canEditAdminBan(chat) { return Boolean(chat.canEditAdminBan); }',
    extractFunctionSource(js, 'renderBlacklistAddAction'),
    extractFunctionSource(js, 'renderBlacklistControls'),
    'return { renderBlacklistControls };',
  ].join('\n'),
);

const blacklistControlsApi = blacklistControlsHarness({ blacklistQueryType: 'nft', nftInputMode: 'id', blacklistQuery: '' });
const nftBlacklistControls = blacklistControlsApi.renderBlacklistControls({ blacklistMode: 'gov', voteWeight: 18 }, '请输入NFT ID', '我的');
if (!nftBlacklistControls.includes('class="nft-lookup"') || !nftBlacklistControls.includes('data-action="set-nft-input-mode-select"')) {
  throw new Error('NFT blacklist query must use the integrated lookup control style');
}
if (!nftBlacklistControls.includes('NFT名称') || !nftBlacklistControls.includes('NFT ID') || !nftBlacklistControls.includes('>我的</button>')) {
  throw new Error('NFT blacklist query must expose name/id lookup modes inside the input control');
}
if (!nftBlacklistControls.includes('data-action="gov-add-target"') || !nftBlacklistControls.includes('>加入黑名单</button>')) {
  throw new Error('Gov blacklist query must render the add-to-blacklist action');
}

const nftLookupHarness = new Function(
  'state',
  [
    'function escapeHtml(value) { return String(value); }',
    'function canEditRules() { return true; }',
    'function canEditMemberScope() { return true; }',
    'function delegateDisplay(value) { return value; }',
    'function activationInputMode() { return "text"; }',
    'function activationFieldLabel(field) { return field; }',
    extractFunctionSource(js, 'renderNftLookupControl'),
    extractFunctionSource(js, 'renderActivationTextInput'),
    extractFunctionSource(js, 'renderDelegateInput'),
    extractFunctionSource(js, 'renderAdminIdControls'),
    extractFunctionSource(js, 'renderMemberIdControls'),
    'return { renderActivationTextInput, renderDelegateInput, renderAdminIdControls, renderMemberIdControls };',
  ].join('\n'),
);

const nftLookupApi = nftLookupHarness({
  nftInputMode: 'id',
  adminIdQueryType: 'id',
  adminIdQuery: '',
  memberIdQueryType: 'name',
  memberIdQuery: '',
  delegateQueryResult: '',
});
const activationMetaInput = nftLookupApi.renderActivationTextInput('metaTitle', '');
if (activationMetaInput.includes('class="nft-lookup"')) {
  throw new Error('Activation fields must not render the removed delegate NFT lookup');
}
if (!nftLookupApi.renderDelegateInput({ groupDelegate: { delegateId: '0' } }, true).includes('data-action="set-delegate-id"')) {
  throw new Error('Delegate editor must call GroupDelegate setDelegateId flow');
}
if (!nftLookupApi.renderDelegateInput({ groupDelegate: { delegateId: '0' } }, true).includes('data-action="set-nft-input-mode-select"')) {
  throw new Error('Delegate editor must reuse the shared NFT lookup control');
}
if (!nftLookupApi.renderAdminIdControls({}).includes('data-action="set-admin-query-type-select"')) {
  throw new Error('Admin NFT query must reuse the shared NFT lookup control');
}
if (!nftLookupApi.renderMemberIdControls({}).includes('data-action="set-member-query-type-select"')) {
  throw new Error('Member NFT query must reuse the shared NFT lookup control');
}

const blacklistTextHarness = new Function(
  'state',
  [
    'function renderPermissionNotice(allowed, allowedText, bannedText) { return allowed ? allowedText : bannedText; }',
    'function canEditAdminBan(chat) { return Boolean(chat.canEditAdminBan); }',
    'function escapeHtml(value) { return String(value); }',
    'function blacklistRowKey(targetType, target) { return `${targetType}:${target}`; }',
    'function renderBlacklistRowMenu() { return ""; }',
    extractFunctionSource(js, 'renderBlacklistPermissionNotice'),
    extractFunctionSource(js, 'renderBlacklistRow'),
    'return { renderBlacklistPermissionNotice, renderBlacklistRow };',
  ].join('\n'),
);

const blacklistTextApi = blacklistTextHarness({});
const govPermissionText = blacklistTextApi.renderBlacklistPermissionNotice({ blacklistMode: 'gov', voteWeight: 18, voteWeightLabel: '治理票' });
if (govPermissionText.includes('有权限：') || govPermissionText.includes('无权限：')) {
  throw new Error('Blacklist permission notice must not prefix texts with access labels');
}
const adminPermissionText = blacklistTextApi.renderBlacklistPermissionNotice({ blacklistMode: 'admin', canEditAdminBan: true });
if (adminPermissionText.includes('有权限：') || adminPermissionText.includes('无权限：')) {
  throw new Error('Admin blacklist permission notice must not prefix texts with access labels');
}
const addressBlacklistRow = blacklistTextApi.renderBlacklistRow(null, {
  type: 'address',
  target: '0xabc',
  label: '0xabc',
  detail: '支持 20 / 反对 1',
  status: '已拉黑',
  statusClass: 'pill-bad',
});
if (addressBlacklistRow.includes('<small>地址 ·')) {
  throw new Error('Address blacklist rows must not repeat the type label in detail text');
}
const nftBlacklistRow = blacklistTextApi.renderBlacklistRow(null, {
  type: 'nft',
  target: '1024',
  label: '治理观察员',
  detail: '支持 20 / 反对 1',
  status: '已拉黑',
  statusClass: 'pill-bad',
});
if (nftBlacklistRow.includes('<small>NFT ·')) {
  throw new Error('NFT blacklist rows must not repeat the type label in detail text');
}
if (!nftBlacklistRow.includes('<strong>治理观察员</strong>')) {
  throw new Error('NFT blacklist rows must render the NFT name as the primary label');
}

const adminIdQueryHarness = new Function(
  'state',
  'render',
  [
    extractFunctionSource(js, 'activeChat'),
    extractFunctionSource(js, 'nftProfile'),
    extractFunctionSource(js, 'resolveNftInput'),
    extractFunctionSource(js, 'groupAdminState'),
    extractFunctionSource(js, 'groupAdminIds'),
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
  || !adminIdQueryState.adminIdQueryResult.includes('已在 GroupAdmin 管理员名单')
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
    'function activationIssue() { return ""; }',
    'function activationPreview(chat, draft) { const values = Object.keys(chat.params).map((key) => draft[key]).join(", "); return `${chat.manager}.activate(${values})`; }',
    'function resolveOptionalKnownNftInput(value) { return value; }',
    'function refreshManualMemberScopeAllowed() {}',
    extractFunctionSource(js, 'activateChat'),
    'return { activateChat };',
  ].join('\n'),
);

const managerActivationState = JSON.parse(JSON.stringify(initialState));
const managerActivationTarget = managerActivationState.chats.find((chat) => chat.type === 'action-gov' && !chat.activated);
if (!managerActivationTarget) {
  throw new Error('Fixture must include an inactive action-gov chat for manager activation');
}
const expectedMintedGroupId =
  managerActivationState.chats.reduce((maxId, chat) => Math.max(maxId, Number(chat.groupId) || 0), 0) + 1;
managerActivateHarness(managerActivationState, () => {}).activateChat(managerActivationTarget.groupId);

const activatedActionGovChat = managerActivationState.chats.find((chat) => chat.type === 'action-gov' && chat.actionId === managerActivationTarget.actionId);
const linkedAction = managerActivationState.actions.find((action) => action.token === managerActivationTarget.token && action.actionId === managerActivationTarget.actionId);
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
