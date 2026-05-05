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
const prototypeSource = html + data + js;

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
  'voteSenderDenyFromMessage',
  'addSenderDenyFromMessage',
  'voteDenySenderBySenderGroupId',
  'addDenyListsBySenderGroupId',
  'data-action="vote-sender-deny"',
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
  'bottomTabs',
  'TokenGroupChatManager',
  'TokenGovGroupChatManager',
  'TokenActionGroupChatManager',
  'TokenActionGovGroupChatManager',
  'GroupJoinScopeSource',
  'AdminDenySource',
  'GovVotedDenySource',
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
}

for (const action of initialState.actions) {
  if (!chatIds.has(action.actionChatId)) throw new Error(`Action ${action.actionId} missing actionChatId ${action.actionChatId}`);
  if (!chatIds.has(action.actionGovChatId)) throw new Error(`Action ${action.actionId} missing actionGovChatId ${action.actionGovChatId}`);
}

for (const message of initialState.messages) {
  if (!chatIds.has(Number(message.conversationId))) {
    throw new Error(`Message ${message.messageIndex} points to missing conversationId ${message.conversationId}`);
  }
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
  'revalidate',
  '激活群聊',
  '代币群',
  '大群 ${chat.token}',
  '治理群 ${chat.token}',
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

console.log('LOVE20 Chat prototype smoke test passed');
