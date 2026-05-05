import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('.', import.meta.url).pathname;
const requiredFiles = ['index.html', 'styles.css', 'app.js'];

for (const file of requiredFiles) {
  const path = join(root, file);
  if (!existsSync(path)) {
    throw new Error(`Missing ${file}`);
  }
}

const html = readFileSync(join(root, 'index.html'), 'utf8');
const css = readFileSync(join(root, 'styles.css'), 'utf8');
const js = readFileSync(join(root, 'app.js'), 'utf8');

const requiredHtml = [
  'data-entry="love20-chat"',
  'id="wallet-button"',
  'id="bottom-nav"',
  'id="workspace-screen"',
  'id="message-list"',
  'id="composer-input"',
];

for (const needle of requiredHtml) {
  if (!html.includes(needle)) {
    throw new Error(`Missing HTML marker: ${needle}`);
  }
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
  '.filter-tabs',
  '.action-row',
  '.query-row',
  '@media (min-width: 900px)',
  '@media (max-width: 390px)',
  'font-size: 16px',
];

for (const needle of requiredCss) {
  if (!css.includes(needle)) {
    throw new Error(`Missing CSS marker: ${needle}`);
  }
}

const requiredJs = [
  'LOVE20 Chat',
  '爱聊',
  'directMessages',
  'bottomTabs',
  'TokenGroupChatManager',
  'TokenGovGroupChatManager',
  'TokenActionGroupChatManager',
  'TokenActionGovGroupChatManager',
  'GroupJoinScopeSource',
  'AdminDenySource',
  'GovVotedDenySource',
  'renderInbox',
  'chatDisplayName',
  'chatIconLabel',
  'activationTabs',
  'activationTypeForChat',
  'renderActivationSection',
  'set-activation-type',
  'toggleChatMenu',
  'activeGroupMenuId',
  'blacklistQueryType',
  'blacklistRows',
  'setBlacklistQueryType',
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
  '群黑名单',
  '群豁免名单',
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

for (const needle of requiredJs) {
  if (!js.includes(needle)) {
    throw new Error(`Missing JS marker: ${needle}`);
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
  if (!(html + js).includes(needle)) {
    throw new Error(`Missing protocol copy: ${needle}`);
  }
}

console.log('LOVE20 Chat prototype smoke test passed');
