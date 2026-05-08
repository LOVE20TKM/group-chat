const prototypeData = window.LOVE20_CHAT_PROTOTYPE_DATA;

if (!prototypeData) {
  throw new Error('Missing LOVE20_CHAT_PROTOTYPE_DATA. Load prototype-data.js before app.js.');
}

const state = JSON.parse(JSON.stringify(prototypeData.initialState));
const { bottomTabs, inboxFilters, activationTabs } = prototypeData;
const blacklistPageSize = prototypeData.pageSizes.blacklist;
const voterPageSize = prototypeData.pageSizes.voter;
const avatarLongPressMs = 520;
let avatarPressState = null;
let suppressAvatarClick = false;

function escapeHtml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

function activeChat() {
  return state.chats.find((chat) => chat.chatGroupId === state.activeChatId);
}

function activeChatEntry() {
  const chat = state.chats.find((item) => String(item.chatGroupId) === String(state.activeChatGroupId));
  return chat ? { kind: 'group', item: chat } : null;
}

function nftProfile(senderId) {
  return state.nftProfiles[senderId] || { name: '群成员', badge: '人' };
}

function currentDefaultGroupId() {
  return state.defaultGroupId;
}

function ownerOfGroupId(chatGroupId) {
  return state.groupOwners?.[String(chatGroupId)] || '';
}

function validDefaultGroupIdOf(address) {
  const chatGroupId = state.defaultGroupIdsByAddress?.[address];
  return chatGroupId && ownerOfGroupId(chatGroupId) === address ? chatGroupId : '';
}

function resolveNftInput(value, mode = 'name') {
  const raw = String(value || '').trim();
  if (!raw) return '';
  const query = raw.toLowerCase();
  const entries = Object.entries(state.nftProfiles);
  if (mode === 'id') return /^\d+$/.test(raw) ? raw : '';
  const exact = entries.find(([, profile]) => profile.name.toLowerCase() === query);
  if (exact) return exact[0];
  const partial = entries.find(([, profile]) => profile.name.toLowerCase().includes(query));
  return partial ? partial[0] : '';
}

function resolveKnownNftInput(value, mode = 'name') {
  const resolved = resolveNftInput(value, mode);
  return resolved && state.nftProfiles[resolved] ? resolved : '';
}

function resolveOptionalNftInput(value, mode = 'name') {
  const raw = String(value || '').trim();
  if (!raw || raw === '0') return '0';
  return resolveNftInput(raw, mode);
}

function resolveOptionalKnownNftInput(value, mode = 'name') {
  const raw = String(value || '').trim();
  if (!raw || raw === '0') return '0';
  return resolveKnownNftInput(raw, mode);
}

function messagesForChat(chatGroupId = state.activeChatGroupId) {
  return state.messages.filter((message) => message.chatGroupId === String(chatGroupId));
}

function messageById(messageId, chatGroupId = state.activeChatGroupId) {
  return messagesForChat(chatGroupId).find((message) => message.messageId === Number(messageId));
}

function unreadMessagesForChat(chatGroupId) {
  const lastRead = Number(state.readCursorsByChatGroupId?.[String(chatGroupId)] || 0);
  return messagesForChat(chatGroupId).filter((message) => !message.mine && message.messageId > lastRead);
}

function markChatRead(chatGroupId) {
  const key = String(chatGroupId);
  if (!state.readCursorsByChatGroupId) state.readCursorsByChatGroupId = {};
  const latestMessageId = messagesForChat(key).reduce((latest, message) => Math.max(latest, Number(message.messageId) || 0), 0);
  state.readCursorsByChatGroupId[key] = latestMessageId;
}

function conversationStatus(chat) {
  const unread = unreadMessagesForChat(chat.chatGroupId);
  const mySenderId = Number(currentDefaultGroupId());
  return {
    unreadCount: unread.length,
    hasMentionMe: unread.some((message) => (message.mentionedSenderIds || []).map(Number).includes(mySenderId)),
    hasMentionAll: unread.some((message) => message.mentionAll),
  };
}

function messageMenuKey(message) {
  return `${message.chatGroupId}:${message.messageId}`;
}

function activeQuotedMessageId() {
  return state.quotedMessagesByChatGroupId[String(state.activeChatGroupId)] || null;
}

function canQuoteMessage(message) {
  return Number(message?.messageId) > 0;
}

function clearActiveQuote() {
  delete state.quotedMessagesByChatGroupId[String(state.activeChatGroupId)];
}

function chatDisplayName(chat) {
  if (chat.type === 'token-community') return `大群 ${chatTokenSymbol(chat)}`;
  if (chat.type === 'token-gov') return `治理群 ${chatTokenSymbol(chat)}`;
  if (chat.type === 'action') return `行动大群 #${chat.actionId}-${actionTitle(chat)}`;
  if (chat.type === 'action-gov') return `行动治理群 #${chat.actionId}-${actionTitle(chat)}`;
  if (chat.type === 'chain-service') return `链群#${chat.chatGroupId}-${chat.chainName || chat.shortTitle}`;
  return chat.title;
}

function chatTokenSymbol(chat) {
  return chat.tokenSymbol || chat.token;
}

function actionTitle(chat) {
  const action = state.actions.find((item) => item.token === chatTokenSymbol(chat) && item.actionId === chat.actionId);
  return action ? action.title : '行动';
}

function chatIconLabel(chat) {
  const labels = {
    'token-community': '大',
    'token-gov': '治',
    action: '行',
    'action-gov': '审',
    'chain-service': '链',
  };
  return labels[chat.type] || '群';
}

function activationTypeForChat(chat) {
  if (!chat) return 'token';
  if (['token-community', 'token-gov'].includes(chat.type)) return 'token';
  if (['action', 'action-gov'].includes(chat.type)) return 'action';
  if (chat.type === 'chain-service') return 'chain';
  return 'token';
}

function activationDraftFor(chat) {
  const key = String(chat.chatGroupId);
  if (!state.activationDrafts[key]) {
    state.activationDrafts[key] = {
      ...chat.params,
      metaTitle: chatDisplayName(chat),
      metaDescription: chat.typeLabel,
      scopeSource: chat.ruleSlots.scopeSource,
      denySource: chat.ruleSlots.denySource,
      beforePostPlugin: chat.ruleSlots.beforePostPlugin,
      afterPostPlugin: chat.ruleSlots.afterPostPlugin,
      delegateId: chat.ruleSlots.delegateId,
    };
  }
  return state.activationDrafts[key];
}

function activationFieldLabel(field) {
  const labels = {
    chatGroupId: 'chatGroupId',
    token: 'token',
    actionId: 'actionId',
    metaTitle: 'meta.title',
    metaDescription: 'meta.description',
    scopeSource: 'scopeSource',
    denySource: 'denySource',
    beforePostPlugin: 'beforePostPlugin',
    afterPostPlugin: 'afterPostPlugin',
    delegateId: 'delegateId',
  };
  return labels[field] || field;
}

function activationInputMode(field) {
  return ['chatGroupId', 'actionId'].includes(field) ? 'numeric' : 'text';
}

function ruleSlotOptions(slot) {
  const options = {
    scopeSource: [
      { value: 'address(0)', label: '不设置' },
      { value: 'GroupJoinScopeSource', label: 'GroupJoinScopeSource' },
    ],
    denySource: [
      { value: 'address(0)', label: '不设置' },
      { value: 'AdminDenySource', label: 'AdminDenySource' },
    ],
    beforePostPlugin: [
      { value: 'address(0)', label: '不设置' },
    ],
    afterPostPlugin: [
      { value: 'address(0)', label: '不设置' },
    ],
  };
  return options[slot] || null;
}

function captureActivationDraft(chat) {
  const draft = activationDraftFor(chat);
  document.querySelectorAll('[data-activation-field]').forEach((input) => {
    draft[input.dataset.activationField] = input.value.trim();
  });
  if (chat.model === 'chain-service') {
    draft.chatGroupId = draft.chatGroupId || String(chat.chatGroupId);
  }
  return draft;
}

function activationBlocker(chat, draft) {
  if (!chat) return '请选择群聊';
  if (chat.active) return '该群聊已激活';
  if (chat.model === 'chain-service') {
    if (Number(draft.chatGroupId) !== chat.chatGroupId) return 'chatGroupId 必须等于当前 GroupNFT tokenId';
    if (chat.role !== 'owner') return '只有 chatGroupId 当前 owner 可以直接激活';
    const delegateId = resolveOptionalKnownNftInput(draft.delegateId, state.nftInputMode);
    if (!delegateId) return `未找到 NFT：${draft.delegateId}`;
    if (Number(delegateId || 0) === chat.chatGroupId) return 'delegateId 不能等于 chatGroupId';
  }
  return '';
}

function activationPreview(chat, draft) {
  if (chat.model === 'chain-service') {
    const delegateId = resolveOptionalKnownNftInput(draft.delegateId, state.nftInputMode);
    return `activateChat(${draft.chatGroupId}, metaKeys, metaValues, ${draft.scopeSource}, ${draft.denySource}, ${draft.beforePostPlugin}, ${draft.afterPostPlugin}, ${delegateId})`;
  }
  const values = Object.keys(chat.params).map((key) => draft[key]).join(', ');
  return `${chat.manager}.activate(${values})`;
}

function manageableRole(chat) {
  return chat && ['owner', 'delegate', 'admin'].includes(chat.role);
}

function myChainServiceRole(chat) {
  return chat && ['owner', 'delegate'].includes(chat.role);
}

function canEditRules(chat) {
  return chat && ['owner', 'delegate'].includes(chat.role);
}

function isAdminDenyOperator(chat) {
  return Boolean(chat?.adminDeny?.adminIds.includes(String(currentDefaultGroupId())));
}

function canEditAdminDeny(chat) {
  return chat && chat.blacklistMode === 'admin' && isAdminDenyOperator(chat);
}

function canEditExempt(chat) {
  return chat && ['owner', 'delegate'].includes(chat.role);
}

function targetDenied(target) {
  return Number(target.support) > Number(target.oppose);
}

function normalizeBlacklistTargetType(targetType) {
  return targetType === 'nft' ? 'group' : targetType;
}

function blacklistTypeLabel(targetType) {
  return targetType === 'address' ? '地址' : 'NFT';
}

function blacklistRowKey(targetType, target) {
  return `${targetType}:${target}`;
}

function govTargets(chat, targetType) {
  targetType = normalizeBlacklistTargetType(targetType);
  return targetType === 'address' ? chat.govDeny.addressTargets : chat.govDeny.senderIdTargets;
}

function findGovTarget(chat, targetType, target) {
  return govTargets(chat, targetType).find((item) => item.target === target);
}

function ensureGovTarget(chat, targetType, target) {
  const list = govTargets(chat, targetType);
  let item = findGovTarget(chat, targetType, target);
  if (!item) {
    item = { target, support: 0, oppose: 0, voters: 0, myVote: null, myWeight: 0, voterList: [] };
    list.push(item);
  }
  return item;
}

function currentSenderDenied(chat) {
  if (!chat || chat.blacklistMode === 'none') return false;
  if (chat.blacklistMode === 'gov') {
    const addressDenied = chat.govDeny.addressTargets.some((item) => item.target === state.account && targetDenied(item));
    const groupDenied = chat.govDeny.senderIdTargets.some((item) => item.target === String(currentDefaultGroupId()) && targetDenied(item));
    return addressDenied || groupDenied;
  }

  const deny = chat.adminDeny;
  const groupExempt = deny.senderIdExemptList.includes(String(currentDefaultGroupId()));
  if (groupExempt) return false;
  return deny.addressDenyList.includes(state.account) || deny.senderIdDenyList.includes(String(currentDefaultGroupId()));
}

function chatStatus(chat) {
  if (!chat) return { allowed: false, reasonCode: 'ChatNotSelected', label: '未选择群聊' };
  if (!chat.active) return { allowed: false, reasonCode: 'ChatNotActive', label: '未激活' };
  if (chat.defaultGroupOwnerMatches === false) {
    return { allowed: false, reasonCode: 'SenderAddressNotSenderIdOwner', label: '不是 defaultGroupId owner' };
  }
  if (!chat.scopeAllowed) return { allowed: false, reasonCode: 'ScopeRejected', label: '无发言资格' };
  if (currentSenderDenied(chat)) return { allowed: false, reasonCode: 'DenyRejected', label: '命中黑名单' };
  return { allowed: true, reasonCode: '0x00000000', label: '可发言' };
}

function renderBottomNav() {
  document.getElementById('bottom-nav').innerHTML = bottomTabs
    .map((tab) => {
      const active = state.bottomTab === tab.id ? ' active' : '';
      return `<button class="bottom-nav-item${active}" type="button" data-action="set-bottom-tab" data-tab="${tab.id}"><span></span>${tab.label}</button>`;
    })
    .join('');
}

function renderHeader() {
  const title = document.getElementById('screen-title');
  const subtitle = document.getElementById('screen-subtitle');
  const wallet = document.getElementById('wallet-button');
  const back = document.querySelector('[data-action="go-back"]');
  const canGoBack = state.bottomTab !== 'chat' || state.view !== 'inbox';

  wallet.textContent = state.walletConnected ? state.account : '连接钱包';
  back.classList.toggle('is-hidden', !canGoBack);
  back.disabled = !canGoBack;

  title.textContent = '';
  subtitle.textContent = '';
  if (state.bottomTab === 'chat') return;

  const tab = bottomTabs.find((item) => item.id === state.bottomTab);
  title.textContent = tab.label;
  subtitle.textContent = 'interface-test 原页面占位';
}

function renderWorkspace() {
  const workspace = document.getElementById('workspace-screen');
  const messageList = document.getElementById('message-list');
  const composer = document.getElementById('composer');
  const composerBlocked = document.getElementById('composer-blocked');
  const statusStrip = document.getElementById('status-strip');
  const chatView = state.bottomTab === 'chat' && state.view === 'chat';
  const active = activeChatEntry();
  const chat = active && active.kind === 'group' ? active.item : null;
  const status = chatStatus(chat);
  const canCompose = chatView && status.allowed;
  const showComposerBlocked = chatView && !status.allowed;

  workspace.hidden = chatView;
  messageList.hidden = !chatView;
  composer.hidden = !canCompose;
  composerBlocked.hidden = !showComposerBlocked;
  composerBlocked.innerHTML = showComposerBlocked ? renderCannotPost(chat, status) : '';
  statusStrip.hidden = !(state.bottomTab === 'chat' && state.view === 'chat') || showComposerBlocked;

  if (state.bottomTab !== 'chat') {
    workspace.innerHTML = renderPlaceholder();
    return;
  }

  if (state.view === 'inbox') workspace.innerHTML = renderInbox();
  if (state.view === 'activate') workspace.innerHTML = renderActivationHub();
  if (state.view === 'activate-form') workspace.innerHTML = renderActivationForm();
  if (state.view === 'details') workspace.innerHTML = renderGroupDetails();
  if (state.view === 'manage') workspace.innerHTML = renderManagement();
  if (state.view === 'blacklist') workspace.innerHTML = renderBlacklist();
  if (state.view === 'exempt') workspace.innerHTML = renderExemptList();
  if (chatView) renderMessages();
}

function renderPlaceholder() {
  return `
    <section class="workspace-band">
      <div class="screen-heading">
        <h1>${escapeHtml(bottomTabs.find((item) => item.id === state.bottomTab).label)}</h1>
        <span>占位</span>
      </div>
      <div class="empty-state">这里代表 interface-test 现有底导航页面；本原型只替换左下角入口为爱聊。</div>
    </section>
  `;
}

function renderInbox() {
  return `
    <div class="inbox-filter-row">
      <div class="filter-tabs">
        ${inboxFilters
          .map((filter) => `<button class="filter-tab${state.inboxFilter === filter.id ? ' active' : ''}" type="button" data-action="set-inbox-filter" data-filter="${filter.id}">${filter.label}</button>`)
          .join('')}
      </div>
      <button class="sheet-button primary" type="button" data-action="set-view" data-view="activate">群聊激活</button>
    </div>
    <section class="conversation-list">${renderConversationRows()}</section>
  `;
}

function inboxConversations() {
  const groups = state.chats.map((item) => ({ kind: 'group', item }));

  if (state.inboxFilter === 'group') return groups.filter((entry) => entry.item.active);
  if (state.inboxFilter === 'managed') return groups.filter((entry) => entry.item.active && myChainServiceRole(entry.item));
  return groups.filter((entry) => entry.item.active);
}

function renderConversationRows() {
  const rows = inboxConversations();
  if (!rows.length) return '<div class="empty-state">暂无会话</div>';
  return rows.map(renderConversationRow).join('');
}

function renderConversationRow(entry) {
  const chat = entry.item;
  const rowAction = chat.active ? 'open-chat' : 'open-activation';
  const rowTarget = chat.active ? `data-chat-group-id="${chat.chatGroupId}"` : `data-chat-id="${chat.chatGroupId}"`;
  const status = conversationStatus(chat);
  const badges = [];
  if (status.hasMentionMe) badges.push('<span class="conversation-badge mention-me">@我</span>');
  if (status.hasMentionAll) badges.push('<span class="conversation-badge mention-all">@全部</span>');
  const unread = status.unreadCount > 0 ? `<span class="unread">${status.unreadCount}</span>` : '';

  return `
    <article class="conversation-row group-row" data-action="${rowAction}" ${rowTarget}>
      <div class="avatar group group-icon group-icon-${chat.type}">${chatIconLabel(chat)}</div>
      <div class="conversation-main">
        <div class="conversation-title">${escapeHtml(chatDisplayName(chat))}</div>
        ${badges.length ? `<div class="conversation-badges">${badges.join('')}</div>` : ''}
      </div>
      ${unread}
    </article>
  `;
}

function renderActivationHub() {
  return `
    <div class="screen-heading">
      <h1>激活群聊</h1>
      <span>${state.activeToken}</span>
    </div>
    <div class="chat-picker">
      ${activationTabs
        .map((tab) => `<button class="picker-button${state.activationType === tab.id ? ' active' : ''}" type="button" data-action="set-activation-type" data-activation-type="${tab.id}">${tab.label}</button>`)
        .join('')}
    </div>
    ${renderActivationSection()}
  `;
}

function renderActivationSection() {
  if (state.activationType === 'token') return `
    <section class="workspace-band">
      <h2>代币群</h2>
      ${state.chats
        .filter((chat) => chat.token === state.activeToken && ['token-community', 'token-gov'].includes(chat.type))
        .map(renderActivationCard)
        .join('')}
    </section>
  `;

  if (state.activationType === 'action') return `
    <section class="workspace-band">
      <h2>行动群</h2>
      ${state.actions.filter((action) => action.token === state.activeToken).map(renderActionActivation).join('')}
    </section>
  `;

  return `
    <section class="workspace-band">
      <h2>链群</h2>
      ${state.chats
        .filter((chat) => chat.token === state.activeToken && chat.type === 'chain-service')
        .map(renderChainActivation)
        .join('')}
    </section>
  `;
}

function renderActivationCard(chat) {
  const mainAction = chat.active ? 'open-chat' : 'open-activation-form';
  const mainTarget = chat.active ? `data-chat-group-id="${chat.chatGroupId}"` : `data-chat-id="${chat.chatGroupId}"`;
  return `
    <article class="type-card">
      <div class="card-topline">
        <strong>${escapeHtml(chatDisplayName(chat))}</strong>
        <span class="pill ${chat.active ? 'pill-ok' : 'pill-warn'}">${chat.active ? '已激活' : '待激活'}</span>
      </div>
      <div class="muted">${escapeHtml(chat.manager)} · ${escapeHtml(chat.activationCall)}</div>
      <div class="kv-grid">${renderParams(chat.params)}</div>
      <div class="card-actions">
        <button class="sheet-button primary" type="button" data-action="${mainAction}" ${mainTarget}>${chat.active ? '进入' : '配置入参'}</button>
        <button class="sheet-button" type="button" data-action="open-blacklist" data-chat-id="${chat.chatGroupId}" ${chat.active ? '' : 'disabled'}>黑名单</button>
      </div>
    </article>
  `;
}

function renderActionActivation(action) {
  const actionChat = chatById(action.actionChatId);
  const actionGovChat = chatById(action.actionGovChatId);
  return `
    <article class="action-row">
      <div class="card-topline">
        <strong>#${escapeHtml(action.actionId)} ${escapeHtml(action.title)}</strong>
        <span>round ${action.round}</span>
      </div>
      <div class="split-cards">
        ${renderMiniActivate(actionChat)}
        ${renderMiniActivate(actionGovChat)}
      </div>
    </article>
  `;
}

function renderMiniActivate(chat) {
  const mainAction = chat.active ? 'open-chat' : 'open-activation-form';
  const mainTarget = chat.active ? `data-chat-group-id="${chat.chatGroupId}"` : `data-chat-id="${chat.chatGroupId}"`;
  return `
    <div class="mini-card">
      <strong>${escapeHtml(chatDisplayName(chat))}</strong>
      <button class="sheet-button${chat.active ? '' : ' primary'}" type="button" data-action="${mainAction}" ${mainTarget}>
        ${chat.active ? '进入' : '配置'}
      </button>
    </div>
  `;
}

function renderChainActivation(chat) {
  return `
    <article class="action-row">
      <div class="card-topline">
        <strong>${escapeHtml(chatDisplayName(chat))}</strong>
        <span class="pill ${chat.active ? 'pill-ok' : 'pill-warn'}">${chat.active ? chat.role : '待激活'}</span>
      </div>
      <div class="muted">一个代币社区可有多个链群服务者管理群</div>
      <div class="inline-actions">
        <button type="button" data-action="${chat.active ? 'open-chat' : 'open-activation-form'}" ${chat.active ? `data-chat-group-id="${chat.chatGroupId}"` : `data-chat-id="${chat.chatGroupId}"`}>${chat.active ? '进入' : '配置'}</button>
        ${chat.active && canEditRules(chat) ? `<button type="button" data-action="open-manage" data-chat-id="${chat.chatGroupId}">群管理</button>` : ''}
        ${chat.active ? `<button type="button" data-action="open-blacklist" data-chat-id="${chat.chatGroupId}">黑名单</button>` : ''}
      </div>
    </article>
  `;
}

function renderActivationForm() {
  const chat = activeChat();
  if (!chat) return renderActivationHub();
  const draft = activationDraftFor(chat);
  const blocker = activationBlocker(chat, draft);
  const fields = chat.model === 'chain-service'
    ? renderDirectActivationFields(chat, draft)
    : renderManagerActivationFields(chat, draft);

  return `
    <section class="workspace-band activation-form">
      <div class="screen-heading">
        <h1>${escapeHtml(chatDisplayName(chat))}</h1>
        <span class="pill ${chat.active ? 'pill-ok' : 'pill-warn'}">${chat.active ? '已激活' : '待激活'}</span>
      </div>
      <div class="kv-grid">${renderParams(chat.params)}</div>
      ${fields}
      <div class="activation-preview">
        <b>调用预览</b>
        <code>${escapeHtml(activationPreview(chat, draft))}</code>
      </div>
      ${blocker ? `<div class="notice-row">${escapeHtml(blocker)}</div>` : ''}
      <div class="card-actions">
        <button class="sheet-button primary" type="button" data-action="activate-chat" data-chat-id="${chat.chatGroupId}" ${blocker ? 'disabled' : ''}>提交激活</button>
        <button class="sheet-button" type="button" data-action="set-view" data-view="activate">返回列表</button>
      </div>
    </section>
  `;
}

function renderManagerActivationFields(chat, draft) {
  return `
    <section class="activation-section">
      <h2>Manager 入参</h2>
      ${Object.keys(chat.params).map((field) => renderActivationTextInput(field, draft[field], field === 'chatGroupId')).join('')}
      <div class="rule-table">${renderRuleRows(chat)}</div>
      <div class="notice-row">Manager 型群聊激活后不再修改 token、actionId 或规则槽；recentRounds 由 Manager 构造配置固定。</div>
    </section>
  `;
}

function renderDirectActivationFields(chat, draft) {
  return `
    <section class="activation-section">
      <h2>metadata</h2>
      ${renderActivationTextInput('metaTitle', draft.metaTitle)}
      ${renderActivationTextInput('metaDescription', draft.metaDescription)}
    </section>
    <section class="activation-section">
      <h2>规则槽</h2>
      ${renderActivationChoice('scopeSource', draft.scopeSource)}
      ${renderActivationChoice('denySource', draft.denySource)}
      ${renderActivationChoice('beforePostPlugin', draft.beforePostPlugin)}
      ${renderActivationChoice('afterPostPlugin', draft.afterPostPlugin)}
      ${renderActivationTextInput('delegateId', draft.delegateId)}
    </section>
  `;
}

function renderActivationTextInput(field, value, readonly = false) {
  const id = `activation-${field}-input`;
  const placeholder = field === 'delegateId' ? (state.nftInputMode === 'name' ? '输入 NFT 名称' : '输入 NFT 编号') : '';
  const inputMode = field === 'delegateId' ? (state.nftInputMode === 'id' ? 'numeric' : 'text') : activationInputMode(field);
  const selector = field === 'delegateId' ? `
      <div class="filter-tabs admin-query-tabs">
        <button class="filter-tab${state.nftInputMode === 'name' ? ' active' : ''}" type="button" data-action="set-nft-input-mode" data-mode="name">按名称</button>
        <button class="filter-tab${state.nftInputMode === 'id' ? ' active' : ''}" type="button" data-action="set-nft-input-mode" data-mode="id">按编号</button>
      </div>
  ` : '';
  return `
    <div class="field-row activation-field-row">
      <label for="${id}">${escapeHtml(activationFieldLabel(field))}</label>
      ${selector}
      <input id="${id}" data-activation-field="${field}" value="${escapeHtml(value ?? '')}" inputmode="${inputMode}" placeholder="${placeholder}" ${readonly ? 'readonly' : ''}>
    </div>
  `;
}

function renderActivationChoice(field, value) {
  const options = ruleSlotOptions(field) || [];
  return `
    <div class="field-row activation-choice-row">
      <label>${escapeHtml(activationFieldLabel(field))}</label>
      <div class="choice-group">
        ${options.map((option) => `
          <button class="picker-button${value === option.value ? ' active' : ''}" type="button" data-action="set-activation-option" data-field="${field}" data-value="${escapeHtml(option.value)}">${escapeHtml(option.label)}</button>
        `).join('')}
      </div>
    </div>
  `;
}

function renderParams(params) {
  return Object.entries(params)
    .map(([key, value]) => `<span><b>${escapeHtml(key)}</b>${escapeHtml(value)}</span>`)
    .join('');
}

function renderManagement() {
  const chat = activeChat();
  if (!chat) return '<div class="empty-state">请选择群聊</div>';
  if (chat.model === 'decentralized') return renderDecentralizedManagement(chat);
  return renderChainServiceManagement(chat);
}

function renderDecentralizedManagement(chat) {
  return `
    <section class="workspace-band">
      <div class="screen-heading">
        <h1>${escapeHtml(chat.shortTitle)}</h1>
        <span class="pill pill-ok">Manager 持有 NFT</span>
      </div>
      <div class="rule-table">${renderRuleRows(chat)}</div>
      <div class="notice-row">去中心化群聊激活后不提供关闭、重配规则槽、改 token/action 的入口。</div>
      <div class="card-actions single-action">
        <button class="sheet-button primary" type="button" data-action="open-blacklist" data-chat-id="${chat.chatGroupId}">治理黑名单</button>
      </div>
    </section>
  `;
}

function renderChainServiceManagement(chat) {
  const ruleEditor = canEditRules(chat) ? `
    <section class="workspace-band">
      <h2>owner / delegate 配置</h2>
      ${renderRuleInput(chat, 'scopeSource')}
      ${renderRuleInput(chat, 'denySource')}
      ${renderRuleInput(chat, 'beforePostPlugin')}
      ${renderRuleInput(chat, 'afterPostPlugin')}
      ${renderDelegateInput(chat)}
    </section>
    <section class="workspace-band">
      <h2>管理员 NFT</h2>
      ${renderAdminIdControls(chat)}
      ${state.adminIdQueryResult ? `<div class="query-result">${escapeHtml(state.adminIdQueryResult)}</div>` : ''}
      ${renderAdminList(chat.adminDeny.adminIds, 'adminIds', canEditRules(chat))}
    </section>
  ` : '';

  return `
    <section class="workspace-band">
      <div class="screen-heading">
        <h1>${escapeHtml(chat.shortTitle)}</h1>
        <span class="pill ${manageableRole(chat) ? 'pill-ok' : 'pill-warn'}">${escapeHtml(chat.role)}</span>
      </div>
      <div class="rule-table">${renderRuleRows(chat)}</div>
      <div class="notice-row">${managementNotice(chat)}</div>
    </section>
    ${ruleEditor}
  `;
}

function renderRuleInput(chat, slot) {
  const options = ruleSlotOptions(slot);
  if (options) return renderRuleChoice(chat, slot, options);

  const id = `${slot}-input`;
  return `
    <div class="field-row">
      <label for="${id}">${slot}</label>
      <input id="${id}" value="${escapeHtml(chat.ruleSlots[slot])}" inputmode="text">
      <button class="sheet-button" type="button" data-action="set-rule-slot" data-slot="${slot}" data-input="${id}">更新</button>
    </div>
  `;
}

function renderDelegateInput(chat) {
  const value = chat.ruleSlots.delegateId || '0';
  const placeholder = state.nftInputMode === 'name' ? '输入代理 NFT 名称' : '输入代理 NFT 编号';
  const inputMode = state.nftInputMode === 'id' ? 'numeric' : 'text';
  return `
    <div class="delegate-panel">
      <div class="card-topline">
        <strong>代理 NFT</strong>
        <span>delegateId</span>
      </div>
      <div class="query-result">${escapeHtml(delegateDisplay(value))}</div>
      <div class="filter-tabs admin-query-tabs">
        <button class="filter-tab${state.nftInputMode === 'name' ? ' active' : ''}" type="button" data-action="set-nft-input-mode" data-mode="name">按名称</button>
        <button class="filter-tab${state.nftInputMode === 'id' ? ' active' : ''}" type="button" data-action="set-nft-input-mode" data-mode="id">按编号</button>
      </div>
      <div class="query-row delegate-query-row">
        <input id="delegateId-input" value="" inputmode="${inputMode}" placeholder="${placeholder}">
        <button class="sheet-button primary" type="button" data-action="set-rule-slot" data-slot="delegateId" data-input="delegateId-input">确认</button>
      </div>
      <div class="muted">输入 0 表示不设置代理。</div>
      ${state.delegateQueryResult ? `<div class="query-result">${escapeHtml(state.delegateQueryResult)}</div>` : ''}
    </div>
  `;
}

function managementNotice(chat) {
  if (canEditRules(chat)) return 'owner/delegate 可管理规则槽、管理员 NFT 和豁免名单。黑名单仅管理员 NFT 可维护。';
  if (canEditAdminDeny(chat)) return '当前默认 NFT 命中管理员名单，可维护黑名单。';
  return '当前地址只读。';
}

function renderRuleChoice(chat, slot, options) {
  return `
    <div class="field-row activation-choice-row">
      <label>${slot}</label>
      <div class="choice-group">
        ${options.map((option) => `
          <button class="picker-button${chat.ruleSlots[slot] === option.value ? ' active' : ''}" type="button" data-action="set-rule-slot-option" data-slot="${slot}" data-value="${escapeHtml(option.value)}">${escapeHtml(option.label)}</button>
        `).join('')}
      </div>
    </div>
  `;
}

function renderAdminIdControls(chat) {
  const placeholder = state.adminIdQueryType === 'name' ? '输入 NFT 名称' : '输入 NFT 编号';
  const inputMode = state.adminIdQueryType === 'name' ? 'text' : 'numeric';
  return `
    <div class="admin-id-controls">
      <div class="filter-tabs admin-query-tabs">
        <button class="filter-tab${state.adminIdQueryType === 'name' ? ' active' : ''}" type="button" data-action="set-admin-query-type" data-query-type="name">按名称</button>
        <button class="filter-tab${state.adminIdQueryType === 'id' ? ' active' : ''}" type="button" data-action="set-admin-query-type" data-query-type="id">按编号</button>
      </div>
      <input id="admin-id-input" value="${escapeHtml(state.adminIdQuery)}" placeholder="${placeholder}" inputmode="${inputMode}">
      <div class="admin-action-row">
        <button class="sheet-button" type="button" data-action="query-admin-self">查自己</button>
        <button class="sheet-button" type="button" data-action="query-admin-id" data-input="admin-id-input">查询</button>
        <button class="sheet-button primary" type="button" data-action="admin-list-add" data-list="adminIds" data-input="admin-id-input" ${canEditRules(chat) ? '' : 'disabled'}>加入名单</button>
      </div>
    </div>
  `;
}

function renderAdminList(items, listName, canRemove) {
  if (!items.length) return '<div class="empty-state">暂无记录</div>';
  return `
    <div class="admin-nft-list">
      ${items.map((item) => `
        <article class="list-row admin-nft-row">
          <div>
            <strong>NFT #${escapeHtml(item)}</strong>
            <small>${escapeHtml(nftProfile(item).name)}</small>
          </div>
          <button type="button" data-action="admin-list-remove" data-list="${listName}" data-value="${escapeHtml(item)}" ${canRemove ? '' : 'disabled'} aria-label="移除">×</button>
        </article>
      `).join('')}
    </div>
  `;
}

function renderRuleRows(chat) {
  return Object.entries(chat.ruleSlots)
    .map(([key, value]) => `<div><span>${escapeHtml(key)}</span><strong>${escapeHtml(ruleSlotDisplay(key, value))}</strong></div>`)
    .join('');
}

function ruleSlotDisplay(key, value) {
  if (key !== 'delegateId' || value === '0') return value;
  return delegateDisplay(value);
}

function delegateDisplay(value) {
  if (!value || value === '0') return '当前代理：未设置';
  return `当前代理：NFT #${value} · ${nftProfile(value).name}`;
}

function renderGroupPicker() {
  const groups = state.chats.filter((chat) => chat.active);
  return `
    <div class="chat-picker" aria-label="选择群聊">
      ${groups.map((chat) => `<button class="picker-button${chat.chatGroupId === state.activeChatId ? ' active' : ''}" type="button" data-action="select-chat" data-chat-id="${chat.chatGroupId}">${escapeHtml(chat.shortTitle)}</button>`).join('')}
    </div>
  `;
}

function renderBlacklist() {
  const chat = activeChat();
  if (!chat) return '<div class="empty-state">请选择群聊</div>';
  return chat.blacklistMode === 'gov' ? renderGovBlacklist(chat) : renderAdminBlacklist(chat);
}

function renderGovBlacklist(chat) {
  return renderBlacklistPanel(chat);
}

function renderAdminBlacklist(chat) {
  return renderBlacklistPanel(chat);
}

function renderBlacklistPanel(chat) {
  const version = chat.blacklistMode === 'gov' ? chat.govDeny.stateVersion : chat.adminDeny.stateVersion;
  const placeholder = state.blacklistQueryType === 'address'
    ? '输入地址 0x...'
    : state.nftInputMode === 'name' ? '输入 NFT 名称' : '输入 NFT 编号';
  const selfLabel = state.blacklistQueryType === 'address' ? '查自己' : '查我的NFT';
  const nftModeTabs = state.blacklistQueryType === 'nft' ? `
      <div class="filter-tabs admin-query-tabs">
        <button class="filter-tab${state.nftInputMode === 'name' ? ' active' : ''}" type="button" data-action="set-nft-input-mode" data-mode="name">按名称</button>
        <button class="filter-tab${state.nftInputMode === 'id' ? ' active' : ''}" type="button" data-action="set-nft-input-mode" data-mode="id">按编号</button>
      </div>
  ` : '';
  return `
    <section class="workspace-band">
      <div class="screen-heading">
        <h1>群黑名单</h1>
        <span>v${version}</span>
      </div>
      <div class="muted">${escapeHtml(chatDisplayName(chat))}</div>
      <div class="filter-tabs blacklist-query-tabs">
        <button class="filter-tab${state.blacklistQueryType === 'address' ? ' active' : ''}" type="button" data-action="set-blacklist-query-type" data-query-type="address">按地址</button>
        <button class="filter-tab${state.blacklistQueryType === 'nft' ? ' active' : ''}" type="button" data-action="set-blacklist-query-type" data-query-type="nft">按NFT</button>
      </div>
      ${nftModeTabs}
      ${renderBlacklistControls(chat, placeholder, selfLabel)}
      ${state.blacklistQueryResult ? `<div class="query-result">${escapeHtml(state.blacklistQueryResult)}</div>` : ''}
      <div class="tab-content-block">
        ${renderBlacklistRows(chat)}
      </div>
    </section>
  `;
}

function renderBlacklistControls(chat, placeholder, selfLabel) {
  const listName = state.blacklistQueryType === 'address' ? 'addressDenyList' : 'senderIdDenyList';
  const adminAdd = renderAdminBlacklistAdd(chat, listName);
  const countClass = chat.blacklistMode === 'admin' ? 'count-3' : 'count-2';
  const inputMode = state.blacklistQueryType === 'nft' && state.nftInputMode === 'id' ? 'numeric' : 'text';
  return `
    <div class="blacklist-controls ${countClass}">
      <input id="blacklist-query-input" value="${escapeHtml(state.blacklistQuery)}" inputmode="${inputMode}" placeholder="${placeholder}">
      <div class="blacklist-action-row ${countClass}">
        <button class="sheet-button" type="button" data-action="query-self">${selfLabel}</button>
        <button class="sheet-button primary" type="button" data-action="query-blacklist" data-input="blacklist-query-input">查询</button>
        ${adminAdd}
      </div>
    </div>
  `;
}

function renderAdminBlacklistAdd(chat, listName) {
  if (chat.blacklistMode !== 'admin') return '';
  const label = listName === 'senderIdDenyList' ? '联动加入黑名单' : '加入黑名单';
  return `<button class="sheet-button primary" type="button" data-action="admin-list-add" data-list="${listName}" data-input="blacklist-query-input" ${canEditAdminDeny(chat) ? '' : 'disabled'}>${label}</button>`;
}

function blacklistRows(chat) {
  if (chat.blacklistMode === 'gov') {
    return [
      ...chat.govDeny.addressTargets.map((item) => {
        const denied = targetDenied(item);
        return {
          type: 'address',
          target: item.target,
          label: item.target,
          status: denied ? '已拉黑' : '未拉黑',
          statusClass: denied ? 'pill-bad' : 'pill-ok',
          detail: `支持 ${item.support} / 反对 ${item.oppose}`,
        };
      }),
      ...chat.govDeny.senderIdTargets.map((item) => {
        const denied = targetDenied(item);
        return {
          type: 'nft',
          target: item.target,
          label: `NFT #${item.target}`,
          status: denied ? '已拉黑' : '未拉黑',
          statusClass: denied ? 'pill-bad' : 'pill-ok',
          detail: `支持 ${item.support} / 反对 ${item.oppose}`,
        };
      }),
    ];
  }

  return [
    ...chat.adminDeny.addressDenyList.map((item) => ({
      type: 'address',
      target: item,
      label: item,
      status: '已拉黑',
      statusClass: 'pill-bad',
      detail: 'AdminDenySource',
    })),
    ...chat.adminDeny.senderIdDenyList.map((item) => ({
      type: 'nft',
      target: item,
      label: `NFT #${item}`,
      status: '已拉黑',
      statusClass: 'pill-bad',
      detail: 'AdminDenySource',
    })),
  ];
}

function renderBlacklistRows(chat) {
  const rows = blacklistRows(chat).filter((row) => row.type === state.blacklistQueryType);
  const listLabel = state.blacklistQueryType === 'address' ? '地址列表' : 'NFT列表';
  if (!rows.length) return `<div class="empty-state">暂无${listLabel}记录</div>`;
  const totalPages = Math.max(1, Math.ceil(rows.length / blacklistPageSize));
  const page = Math.min(Math.max(1, state.blacklistPage), totalPages);
  const start = (page - 1) * blacklistPageSize;
  const items = rows.slice(start, start + blacklistPageSize).map((row) => renderBlacklistRow(chat, row)).join('');
  return `
    <div class="card-topline blacklist-list-head">
      <h2>${listLabel}</h2>
      <span>${rows.length} 条</span>
    </div>
    ${items}
    ${renderBlacklistPager(page, totalPages)}
  `;
}

function renderBlacklistRow(chat, row) {
  const key = blacklistRowKey(row.type, row.target);
  const menu = state.activeBlacklistMenuKey === key ? renderBlacklistRowMenu(chat, row) : '';
  return `
    <article class="list-row blacklist-row" data-action="toggle-blacklist-menu" data-target-type="${row.type}" data-target="${escapeHtml(row.target)}">
      <div>
        <strong>${escapeHtml(row.label)}</strong>
        <small>${blacklistTypeLabel(row.type)} · ${escapeHtml(row.detail)}</small>
      </div>
      <span class="pill ${row.statusClass}">${row.status}</span>
      ${menu}
    </article>
  `;
}

function renderBlacklistRowMenu(chat, row) {
  if (chat.blacklistMode === 'gov') {
    const voteDisabled = chat.voteWeight > 0 ? '' : 'disabled';
    return `
      <div class="blacklist-menu">
        <button type="button" data-action="gov-vote" data-target-type="${row.type}" data-target="${escapeHtml(row.target)}" data-stance="support" ${voteDisabled}>支持</button>
        <button type="button" data-action="gov-vote" data-target-type="${row.type}" data-target="${escapeHtml(row.target)}" data-stance="oppose" ${voteDisabled}>反对</button>
        <button type="button" data-action="gov-vote" data-target-type="${row.type}" data-target="${escapeHtml(row.target)}" data-stance="clear" ${voteDisabled}>撤票</button>
        <button type="button" data-action="open-gov-voters" data-target-type="${row.type}" data-target="${escapeHtml(row.target)}">查看voter列表</button>
      </div>
    `;
  }

  const listName = row.type === 'address' ? 'addressDenyList' : 'senderIdDenyList';
  const label = row.type === 'address' ? '移出黑名单' : '联动移出黑名单';
  const disabled = canEditAdminDeny(chat) ? '' : 'disabled';
  return `
    <div class="blacklist-menu">
      <button type="button" data-action="admin-list-remove" data-list="${listName}" data-value="${escapeHtml(row.target)}" ${disabled}>${label}</button>
    </div>
  `;
}

function renderBlacklistPager(page, totalPages) {
  if (totalPages <= 1) return '';
  return `
    <div class="pager-row">
      <button class="sheet-button" type="button" data-action="set-blacklist-page" data-page="${page - 1}" ${page <= 1 ? 'disabled' : ''}>上一页</button>
      <span>${page} / ${totalPages}</span>
      <button class="sheet-button" type="button" data-action="set-blacklist-page" data-page="${page + 1}" ${page >= totalPages ? 'disabled' : ''}>下一页</button>
    </div>
  `;
}

function renderExemptList() {
  const chat = activeChat();
  if (!chat) return '<div class="empty-state">请选择群聊</div>';
  if (!chat.adminDeny) return '<div class="empty-state">该群没有豁免名单</div>';
  const placeholder = state.nftInputMode === 'name' ? '输入 NFT 名称' : '输入 NFT 编号';
  const inputMode = state.nftInputMode === 'id' ? 'numeric' : 'text';
  return `
    <section class="workspace-band">
      <div class="screen-heading">
        <h1>豁免名单</h1>
        <span>v${chat.adminDeny.stateVersion}</span>
      </div>
      <div class="muted">${escapeHtml(chatDisplayName(chat))}</div>
      <div class="filter-tabs admin-query-tabs">
        <button class="filter-tab${state.nftInputMode === 'name' ? ' active' : ''}" type="button" data-action="set-nft-input-mode" data-mode="name">按名称</button>
        <button class="filter-tab${state.nftInputMode === 'id' ? ' active' : ''}" type="button" data-action="set-nft-input-mode" data-mode="id">按编号</button>
      </div>
      <div class="field-row compact">
        <input id="exempt-input" inputmode="${inputMode}" placeholder="${placeholder}">
        <button class="sheet-button primary" type="button" data-action="admin-list-add" data-list="senderIdExemptList" data-input="exempt-input" ${canEditExempt(chat) ? '' : 'disabled'}>加入豁免</button>
      </div>
      <div class="tab-content-block">
        ${renderExemptRows(chat)}
      </div>
    </section>
  `;
}

function exemptRows(chat) {
  return chat.adminDeny.senderIdExemptList.map((item) => ({ type: 'nft', target: item, label: `NFT #${item}` }));
}

function renderExemptRows(chat) {
  const rows = exemptRows(chat);
  if (!rows.length) return '<div class="empty-state">暂无NFT列表记录</div>';
  const totalPages = Math.max(1, Math.ceil(rows.length / blacklistPageSize));
  const page = Math.min(Math.max(1, state.blacklistPage), totalPages);
  const start = (page - 1) * blacklistPageSize;
  const items = rows.slice(start, start + blacklistPageSize).map((row) => renderExemptRow(chat, row)).join('');
  return `
    <div class="card-topline blacklist-list-head">
      <h2>NFT列表</h2>
      <span>${rows.length} 条</span>
    </div>
    ${items}
    ${renderBlacklistPager(page, totalPages)}
  `;
}

function renderExemptRow(chat, row) {
  const key = blacklistRowKey(row.type, row.target);
  const menu = state.activeExemptMenuKey === key ? renderExemptRowMenu(chat, row) : '';
  return `
    <article class="list-row blacklist-row" data-action="toggle-exempt-menu" data-target-type="${row.type}" data-target="${escapeHtml(row.target)}">
      <div>
        <strong>${escapeHtml(row.label)}</strong>
        <small>${blacklistTypeLabel(row.type)} · 豁免</small>
      </div>
      <span class="pill pill-ok">已豁免</span>
      ${menu}
    </article>
  `;
}

function renderExemptRowMenu(chat, row) {
  const disabled = canEditExempt(chat) ? '' : 'disabled';
  return `
    <div class="blacklist-menu">
      <button type="button" data-action="admin-list-remove" data-list="senderIdExemptList" data-value="${escapeHtml(row.target)}" ${disabled}>移出豁免名单</button>
    </div>
  `;
}

function renderMessages() {
  const active = activeChatEntry();
  const chatGroupId = state.activeChatGroupId;
  const visibleMessages = messagesForChat(chatGroupId);
  const chat = active ? active.item : null;
  const groupTools = chat ? renderChatTools(chat) : '';
  const roundLabel = chat ? `<div class="round-divider">Round ${chat.round}</div>` : '';
  const items = visibleMessages.map((message) => renderMessage(chat, message)).join('');
  document.getElementById('message-list').innerHTML = `${groupTools}${roundLabel}${items || '<div class="empty-state">暂无消息</div>'}`;
}

function renderChatTools(chat) {
  const exemptMenuItem = chat.adminDeny
    ? `<button type="button" data-action="open-exempt" data-chat-id="${chat.chatGroupId}">豁免名单</button>`
    : '';
  const blacklistLabel = '黑名单';
  const manageMenuItem = canEditRules(chat)
    ? `<button type="button" data-action="open-manage" data-chat-id="${chat.chatGroupId}">管理</button>`
    : '<button type="button" disabled title="仅 NFT 拥有者或代理可以进">管理</button>';
  const menu = state.activeGroupMenuId === chat.chatGroupId ? `
    <div class="chat-menu">
      <button type="button" data-action="open-details" data-chat-id="${chat.chatGroupId}">详情</button>
      <button type="button" data-action="simulate-message-gap" data-chat-id="${chat.chatGroupId}">模拟缺口</button>
      <button type="button" data-action="open-blacklist" data-chat-id="${chat.chatGroupId}">${blacklistLabel}</button>
      ${exemptMenuItem}
      ${manageMenuItem}
    </div>
  ` : '';
  return `
    <div class="chat-tools">
      <strong>${escapeHtml(chatDisplayName(chat))}</strong>
      <button class="chat-menu-button" type="button" data-action="toggle-chat-menu" data-chat-id="${chat.chatGroupId}" aria-label="群聊菜单">...</button>
      ${menu}
    </div>
  `;
}

function renderCannotPost(chat, status) {
  return `
    <div class="cannot-post">
      <strong>无法发言 · ${escapeHtml(status.reasonCode)}</strong>
      <span>${escapeHtml(postBlockReason(chat, status))}</span>
    </div>
  `;
}

function postBlockReason(chat, status) {
  if (!chat) return '还没有选中群聊。';
  if (status.reasonCode === 'ChatNotActive') return '这个群聊还没有激活，链上暂时没有可用的发言规则。';
  if (status.reasonCode === 'SenderAddressNotSenderIdOwner') return '当前钱包不是 defaultGroupId 的 owner，合约会返回 SenderAddressNotSenderIdOwner。';
  if (status.reasonCode === 'DenyRejected') return '发言资格已通过，但 denySource 拦截了当前地址或当前 NFT。请检查黑名单和豁免名单。';
  if (status.reasonCode === 'ScopeRejected') return scopeSourceReason(chat);
  return '当前地址暂时不满足这个群聊的发言条件。';
}

function scopeSourceReason(chat) {
  const source = chat.ruleSlots?.scopeSource || chat.params?.scopeSource || 'scopeSource';
  const messages = {
    TokenGroupChatManager: 'scopeSource 会检查当前地址是否属于这个代币的大群范围；当前地址不在范围内。',
    TokenGovGroupChatManager: 'scopeSource 会检查当前地址是否有这个代币治理群的发言资格；当前地址不满足。',
    TokenActionGroupChatManager: 'scopeSource 会检查当前地址是否属于这个行动群的参与范围；当前地址不在范围内。',
    TokenActionGovGroupChatManager: 'scopeSource 会检查当前地址是否有这个行动治理群的发言资格；当前地址不满足。',
    GroupJoinScopeSource: 'scopeSource 会检查当前地址是否在该链群下参与至少一个代币社区行动；当前地址不满足。',
  };
  return messages[source] || `${source} 判断当前地址没有这个群聊的发言资格。`;
}

function renderMessage(chat, message) {
  const mine = message.mine ? ' mine' : '';
  const profile = nftProfile(message.senderId);
  const quoted = message.quotedMessageId ? messageById(message.quotedMessageId, message.chatGroupId) : null;
  const quote = quoted ? `<div class="quote-preview">引用 ${escapeHtml(nftProfile(quoted.senderId).name)}</div>` : '';
  const content = renderMessageContent(message);
  const avatarMenu = state.activeAvatarMenuKey === messageMenuKey(message)
    ? `<div class="message-actions avatar-actions">${renderSenderDenyAction(chat, message)}</div>`
    : '';
  const quoteAction = canQuoteMessage(message)
    ? `<button type="button" data-action="quote-message" data-message-id="${message.messageId}">引用</button>`
    : '';
  const actions = state.activeMenuMessageId === message.messageId
    ? `
      <div class="message-actions">
        ${quoteAction}
        <button type="button" data-action="copy-message" data-message-id="${message.messageId}">复制</button>
      </div>
    `
    : '';
  return `
    <article class="message-row${mine}" data-action="select-message" data-message-id="${message.messageId}">
      <div class="avatar" data-action="toggle-avatar-menu" data-long-press-mention data-chat-group-id="${message.chatGroupId}" data-message-id="${message.messageId}" data-sender-id="${message.senderId || currentDefaultGroupId()}">${escapeHtml(profile.badge)}</div>
      <div class="message-body">
        <div class="message-meta">${escapeHtml(profile.name)}</div>
        <div class="message-bubble${mine}">${quote}${content}</div>
        ${avatarMenu}
        ${actions}
      </div>
    </article>
  `;
}

function renderMessageContent(message) {
  let content = escapeHtml(message.content);
  const tokens = [];
  if (message.mentionAll) tokens.push('@全部');
  for (const senderId of message.mentionedSenderIds || []) {
    tokens.push(mentionTokenFor(senderId));
  }
  for (const token of tokens.sort((left, right) => right.length - left.length)) {
    const escapedToken = escapeHtml(token);
    content = content.split(escapedToken).join(`<span class="message-mention">${escapedToken}</span>`);
  }
  return content;
}

function renderSenderDenyAction(chat, message) {
  if (!canShowAvatarDenyMenu(chat, message)) return '';
  return `<button type="button" data-action="add-sender-deny" data-chat-group-id="${message.chatGroupId}" data-message-id="${message.messageId}">拉黑sender</button>`;
}

function canShowAvatarDenyMenu(chat, message) {
  return Boolean(chat && !message.mine && message.senderAddress && message.senderId && canEditAdminDeny(chat));
}

function renderStatus() {
  const statusStrip = document.getElementById('status-strip');
  const statusText = state.syncHint;
  statusStrip.hidden = statusStrip.hidden || !statusText;
  statusStrip.innerHTML = `
    <span>${escapeHtml(statusText)}</span>
  `;
}

function renderGroupDetails() {
  const active = activeChatEntry();
  const chat = active ? active.item : activeChat();
  const status = chatStatus(chat);
  const className = status.allowed ? 'status-ok' : 'status-bad';
  const statusBadge = status.allowed ? '' : `<span class="${className}">无法发言</span>`;
  const statusRows = status.allowed ? '' : `
      <dt>无法发言原因</dt>
      <dd>${escapeHtml(postBlockReason(chat, status))}</dd>
  `;
  const groupAbout = chat ? `
      <dt>群聊</dt>
      <dd>${escapeHtml(chatDisplayName(chat))}</dd>
      <dt>chatGroupId</dt>
      <dd>#${chat.chatGroupId}</dd>
      <dt>类型</dt>
      <dd>${escapeHtml(chat.typeLabel)}</dd>
  ` : `
      <dt>入口</dt>
      <dd>底导航 爱聊 / LOVE20 Chat</dd>
  `;
  return `
    <section class="workspace-band">
      <div class="screen-heading">
        <h1>群详情</h1>
        ${statusBadge}
      </div>
    <dl class="status-card">
      ${groupAbout}
      <dt>当前 defaultGroupId</dt>
      <dd>defaultGroupId #${currentDefaultGroupId()}</dd>
      <dt>canPostStatus</dt>
      <dd>${escapeHtml(status.reasonCode)}</dd>
      ${statusRows}
    </dl>
    <div class="close-row status-actions">
      ${chat && canEditRules(chat) ? `<button type="button" class="sheet-button primary" data-action="open-manage" data-chat-id="${chat.chatGroupId}">管理</button>` : ''}
      ${chat ? `<button type="button" class="sheet-button" data-action="open-blacklist" data-chat-id="${chat.chatGroupId}">黑名单</button>` : ''}
    </div>
    </section>
  `;
}

function renderComposerChips() {
  const chips = [];
  const quotedMessageId = activeQuotedMessageId();
  if (quotedMessageId) {
    const quoted = messageById(quotedMessageId, state.activeChatGroupId);
    const quotedName = quoted ? nftProfile(quoted.senderId).name : '消息';
    chips.push(`<button class="chip" type="button" data-action="clear-quote">引用 ${escapeHtml(quotedName)} ×</button>`);
  }
  const composerChips = document.getElementById('composer-chips');
  composerChips.hidden = !chips.length;
  composerChips.innerHTML = chips.join('');
}

function render() {
  renderHeader();
  renderBottomNav();
  renderWorkspace();
  renderStatus();
  renderComposerChips();
}

function chatById(chatId) {
  return state.chats.find((chat) => chat.chatGroupId === Number(chatId));
}

function setBottomTab(tab) {
  state.bottomTab = tab;
  if (tab === 'chat') state.view = 'inbox';
  state.pageReturnStack = [];
  render();
}

function setView(view) {
  state.pageReturnStack = [];
  state.view = view;
  render();
}

function goBack() {
  const previous = state.pageReturnStack.pop();
  if (previous) {
    state.bottomTab = previous.bottomTab;
    state.view = previous.view;
    state.activeChatGroupId = previous.activeChatGroupId;
    state.activeChatId = previous.activeChatId;
    state.activeGroupMenuId = null;
  } else if (state.bottomTab !== 'chat') {
    state.bottomTab = 'chat';
    state.view = 'inbox';
  } else if (state.view === 'chat') {
    state.view = 'inbox';
  } else if (state.view === 'activate-form') {
    state.view = 'activate';
  } else if (state.view !== 'inbox') {
    state.view = 'inbox';
  }
  render();
}

function rememberPageReturn() {
  state.pageReturnStack.push({
    bottomTab: state.bottomTab,
    view: state.view,
    activeChatGroupId: state.activeChatGroupId,
    activeChatId: state.activeChatId,
  });
}

function selectChat(chatId) {
  const chat = chatById(chatId);
  if (!chat) return;
  state.activeChatId = chat.chatGroupId;
  state.activeChatGroupId = String(chat.chatGroupId);
  state.blacklistQueryResult = '';
  state.blacklistPage = 1;
  state.activeBlacklistMenuKey = null;
  state.activeExemptMenuKey = null;
  state.adminIdQuery = '';
  state.adminIdQueryResult = '';
  state.activeAvatarMenuKey = null;
  state.syncHint = `已选择 chatGroupId #${chat.chatGroupId}`;
  render();
}

function openActivation(chatId) {
  if (chatId) {
    openActivationForm(chatId);
    return;
  }
  state.view = 'activate';
  render();
}

function openActivationForm(chatId) {
  const chat = chatById(chatId);
  if (chat) {
    state.activeChatId = chat.chatGroupId;
    state.activeChatGroupId = String(chat.chatGroupId);
    state.activeToken = chat.token;
    state.activationType = activationTypeForChat(chat);
  }
  state.view = 'activate-form';
  render();
}

function openChat(chatGroupId) {
  state.activeChatGroupId = String(chatGroupId);
  const chat = chatById(chatGroupId);
  if (chat) state.activeChatId = chat.chatGroupId;
  markChatRead(chatGroupId);
  state.view = 'chat';
  state.activeMenuMessageId = null;
  state.activeAvatarMenuKey = null;
  state.activeGroupMenuId = null;
  state.pageReturnStack = [];
  render();
}

function openManage(chatId) {
  const chat = chatById(chatId);
  state.activeGroupMenuId = null;
  if (!canEditRules(chat)) {
    state.syncHint = '仅 NFT 拥有者或代理可以进入管理。';
    render();
    return;
  }
  rememberPageReturn();
  selectChat(chat.chatGroupId);
  state.view = 'manage';
  render();
}

function openBlacklist(chatId) {
  state.activeGroupMenuId = null;
  state.activeBlacklistMenuKey = null;
  rememberPageReturn();
  selectChat(chatId);
  state.view = 'blacklist';
  render();
}

function openExempt(chatId) {
  const chat = chatById(chatId);
  state.activeGroupMenuId = null;
  state.activeExemptMenuKey = null;
  if (!chat || !chat.adminDeny) {
    state.syncHint = '该群没有豁免名单。';
    render();
    return;
  }
  rememberPageReturn();
  selectChat(chat.chatGroupId);
  state.view = 'exempt';
  state.blacklistQueryType = 'nft';
  state.blacklistPage = 1;
  render();
}

function openDetails(chatId) {
  const chat = chatById(chatId);
  state.activeGroupMenuId = null;
  if (!chat) return;
  rememberPageReturn();
  selectChat(chat.chatGroupId);
  state.view = 'details';
  render();
}

function toggleChatMenu(chatId) {
  const chatGroupId = Number(chatId);
  state.activeGroupMenuId = state.activeGroupMenuId === chatGroupId ? null : chatGroupId;
  render();
}

function setBlacklistQueryType(queryType) {
  state.blacklistQueryType = queryType === 'nft' ? 'nft' : 'address';
  state.blacklistQuery = '';
  state.blacklistQueryResult = '';
  state.blacklistPage = 1;
  state.activeBlacklistMenuKey = null;
  state.activeExemptMenuKey = null;
  render();
}

function setBlacklistPage(page) {
  state.blacklistPage = Math.max(1, Number(page) || 1);
  state.activeBlacklistMenuKey = null;
  state.activeExemptMenuKey = null;
  render();
}

function toggleBlacklistMenu(targetType, target) {
  const key = blacklistRowKey(targetType, target);
  state.activeBlacklistMenuKey = state.activeBlacklistMenuKey === key ? null : key;
  render();
}

function toggleExemptMenu(targetType, target) {
  const key = blacklistRowKey(targetType, target);
  state.activeExemptMenuKey = state.activeExemptMenuKey === key ? null : key;
  render();
}

function nextManagedChatGroupId() {
  return state.chats.reduce((maxId, chat) => Math.max(maxId, Number(chat.chatGroupId) || 0), 0) + 1;
}

function syncManagedChatGroupId(chat, nextGroupId) {
  const prevGroupId = Number(chat.chatGroupId);
  if (prevGroupId === nextGroupId) return;

  chat.chatGroupId = nextGroupId;

  if (chat.type === 'action' || chat.type === 'action-gov') {
    const action = state.actions.find((item) => item.token === chat.token && item.actionId === chat.actionId);
    if (action) {
      if (chat.type === 'action') action.actionChatId = nextGroupId;
      else action.actionGovChatId = nextGroupId;
    }
  }

  if (state.activeChatId === prevGroupId) state.activeChatId = nextGroupId;
  if (String(state.activeChatGroupId) === String(prevGroupId)) state.activeChatGroupId = String(nextGroupId);
  if (state.activeGroupMenuId === prevGroupId) state.activeGroupMenuId = nextGroupId;

  state.pageReturnStack.forEach((entry) => {
    if (entry.activeChatId === prevGroupId) entry.activeChatId = nextGroupId;
    if (String(entry.activeChatGroupId) === String(prevGroupId)) entry.activeChatGroupId = String(nextGroupId);
  });

  if (state.activationDrafts[String(prevGroupId)]) {
    state.activationDrafts[String(nextGroupId)] = state.activationDrafts[String(prevGroupId)];
    delete state.activationDrafts[String(prevGroupId)];
  }

  if (state.quotedMessagesByChatGroupId[String(prevGroupId)] !== undefined) {
    state.quotedMessagesByChatGroupId[String(nextGroupId)] = state.quotedMessagesByChatGroupId[String(prevGroupId)];
    delete state.quotedMessagesByChatGroupId[String(prevGroupId)];
  }

  state.messages.forEach((message) => {
    if (String(message.chatGroupId) === String(prevGroupId)) {
      message.chatGroupId = String(nextGroupId);
    }
  });
}

function activateChat(chatId) {
  const chat = chatById(chatId);
  if (!chat || chat.active) return;
  const draft = captureActivationDraft(chat);
  const blocker = activationBlocker(chat, draft);
  if (blocker) {
    state.syncHint = blocker;
    render();
    return;
  }

  if (chat.model === 'chain-service') {
    chat.ruleSlots.scopeSource = draft.scopeSource || 'address(0)';
    chat.ruleSlots.denySource = draft.denySource || 'address(0)';
    chat.ruleSlots.beforePostPlugin = draft.beforePostPlugin || 'address(0)';
    chat.ruleSlots.afterPostPlugin = draft.afterPostPlugin || 'address(0)';
    chat.ruleSlots.delegateId = resolveOptionalKnownNftInput(draft.delegateId, state.nftInputMode);
    chat.params = {
      chatGroupId: String(chat.chatGroupId),
      scopeSource: chat.ruleSlots.scopeSource,
      denySource: chat.ruleSlots.denySource,
    };
    chat.meta = {
      title: draft.metaTitle,
      description: draft.metaDescription,
    };
  } else {
    Object.keys(chat.params).forEach((key) => {
      chat.params[key] = draft[key];
    });
    if (draft.token) chat.tokenAddress = draft.token;
    if (draft.actionId) chat.actionId = draft.actionId;
    syncManagedChatGroupId(chat, nextManagedChatGroupId());
  }

  chat.active = true;
  chat.lastMessageId = 0;
  state.activeChatId = chat.chatGroupId;
  state.activeChatGroupId = String(chat.chatGroupId);
  state.view = 'chat';
  state.syncHint = chat.model === 'chain-service'
    ? `${activationPreview(chat, draft)} 已模拟提交。`
    : `${activationPreview(chat, draft)} => chatGroupId ${chat.chatGroupId} 已模拟提交。`;
  render();
}

function setActivationOption(field, value) {
  const chat = activeChat();
  if (!chat) return;
  const draft = captureActivationDraft(chat);
  draft[field] = value;
  render();
}

function setRuleSlot(slot, inputId) {
  const chat = activeChat();
  const input = document.getElementById(inputId);
  let value = input.value.trim();
  if (!chat || !canEditRules(chat)) return;
  if (slot === 'delegateId') {
    if (!value) {
      state.delegateQueryResult = '请输入代理 NFT 名称或编号；输入 0 表示不设置代理。';
      render();
      return;
    }
    value = resolveOptionalKnownNftInput(value, state.nftInputMode);
    if (!value) {
      state.delegateQueryResult = state.nftInputMode === 'id'
        ? `未加载 NFT #${input.value.trim()}，无法确认名称。`
        : `未找到 NFT：${input.value.trim()}`;
      render();
      return;
    }
    if (value !== '0' && Number(value) === chat.chatGroupId) {
      state.delegateQueryResult = '代理 NFT 不能等于当前群聊 NFT。';
      render();
      return;
    }
    chat.ruleSlots[slot] = value;
    state.delegateQueryResult = value === '0' ? '已确认：不设置代理。' : `已确认：NFT #${value} · ${nftProfile(value).name}`;
    state.syncHint = `${slot} 已更新为 ${value}`;
    render();
    return;
  }
  if (!value) return;
  chat.ruleSlots[slot] = value;
  state.syncHint = `${slot} 已更新为 ${value}`;
  render();
}

function setRuleSlotOption(slot, value) {
  const chat = activeChat();
  const options = ruleSlotOptions(slot);
  if (!chat || !options || !canEditRules(chat)) return;
  if (!options.some((option) => option.value === value)) return;
  chat.ruleSlots[slot] = value;
  state.syncHint = `${slot} 已更新为 ${value}`;
  render();
}

function addAdminList(listName, inputId) {
  const chat = activeChat();
  const input = document.getElementById(inputId);
  const value = input.value.trim();
  if (!chat || !chat.adminDeny || !value) return;
  if (listName.includes('Exempt') && !canEditExempt(chat)) return;
  if (!listName.includes('Exempt') && listName !== 'adminIds' && !canEditAdminDeny(chat)) return;
  if (listName === 'adminIds' && !canEditRules(chat)) return;
  const nftList = ['adminIds', 'senderIdDenyList', 'senderIdExemptList'].includes(listName);
  const targetValue = nftList ? resolveNftInput(value, listName === 'adminIds' ? state.adminIdQueryType : state.nftInputMode) : value;
  if (!targetValue) {
    if (listName === 'adminIds') state.adminIdQueryResult = `未找到 NFT：${value}`;
    else state.syncHint = `未找到 NFT：${value}`;
    render();
    return;
  }
  if (listName === 'senderIdDenyList') {
    const profileAddress = ownerOfGroupId(targetValue);
    if (!profileAddress) {
      state.syncHint = `GroupNotExist：NFT #${targetValue} 当前 ownerOf 不存在`;
      render();
      return;
    }
    let changes = 0;
    if (!chat.adminDeny.senderIdDenyList.includes(targetValue)) {
      chat.adminDeny.senderIdDenyList.push(targetValue);
      changes += 1;
    }
    if (profileAddress && !chat.adminDeny.addressDenyList.includes(profileAddress)) {
      chat.adminDeny.addressDenyList.push(profileAddress);
      changes += 1;
    }
    if (changes > 0) {
      chat.adminDeny.stateVersion += 1;
      state.syncHint = `addDenyListsBySenderIds([${targetValue}]) 已模拟，当前 ownerOf=${profileAddress}`;
    }
    render();
    return;
  }
  if (listName === 'addressDenyList') {
    const targetGroupId = validDefaultGroupIdOf(targetValue);
    let changes = 0;
    if (!chat.adminDeny.addressDenyList.includes(targetValue)) {
      chat.adminDeny.addressDenyList.push(targetValue);
      changes += 1;
    }
    if (targetGroupId && !chat.adminDeny.senderIdDenyList.includes(targetGroupId)) {
      chat.adminDeny.senderIdDenyList.push(targetGroupId);
      changes += 1;
    }
    if (changes > 0) {
      chat.adminDeny.stateVersion += 1;
      state.syncHint = targetGroupId
        ? `addDenyListsBySenderAddresses([${targetValue}]) 已模拟，联动 NFT #${targetGroupId}`
        : `addDenyListsBySenderAddresses([${targetValue}]) 已模拟`;
    }
    render();
    return;
  }
  if (!chat.adminDeny[listName].includes(targetValue)) {
    chat.adminDeny[listName].push(targetValue);
    chat.adminDeny.stateVersion += 1;
    state.syncHint = `${listName} 新增 ${targetValue}`;
  }
  if (listName === 'adminIds') {
    state.adminIdQuery = value;
    queryAdminIdValue(value, false);
    render();
    return;
  }
  render();
}

function setAdminIdQueryType(queryType) {
  state.adminIdQueryType = queryType === 'id' ? 'id' : 'name';
  state.adminIdQuery = '';
  state.adminIdQueryResult = '';
  render();
}

function setNftInputMode(mode) {
  state.nftInputMode = mode === 'id' ? 'id' : 'name';
  state.blacklistQuery = '';
  state.blacklistQueryResult = '';
  state.delegateQueryResult = '';
  state.blacklistPage = 1;
  state.activeBlacklistMenuKey = null;
  state.activeExemptMenuKey = null;
  render();
}

function queryAdminSelf() {
  state.adminIdQuery = state.adminIdQueryType === 'name'
    ? nftProfile(currentDefaultGroupId()).name
    : String(currentDefaultGroupId());
  queryAdminIdValue(state.adminIdQuery, true);
}

function queryAdminId(inputId) {
  const input = document.getElementById(inputId);
  state.adminIdQuery = input.value.trim();
  queryAdminIdValue(state.adminIdQuery, true);
}

function queryAdminIdValue(value, shouldRender) {
  const chat = activeChat();
  if (!chat || !chat.adminDeny || !value) return;
  const chatGroupId = resolveNftInput(value, state.adminIdQueryType);
  if (!chatGroupId) {
    state.adminIdQueryResult = `未找到 NFT：${value}`;
    if (shouldRender) render();
    return;
  }
  const inList = chat.adminDeny.adminIds.includes(chatGroupId);
  const profile = nftProfile(chatGroupId);
  state.adminIdQueryResult = `NFT #${chatGroupId} · ${profile.name} · ${inList ? '已在管理员名单' : '不在管理员名单'}`;
  if (shouldRender) render();
}

function resolveAdminIdQuery(value) {
  return resolveNftInput(value, state.adminIdQueryType);
}

function removeAdminList(listName, value) {
  const chat = activeChat();
  if (!chat || !chat.adminDeny) return;
  if (listName.includes('Exempt') && !canEditExempt(chat)) return;
  if (!listName.includes('Exempt') && listName !== 'adminIds' && !canEditAdminDeny(chat)) return;
  if (listName === 'adminIds' && !canEditRules(chat)) return;
  if (listName === 'senderIdDenyList') {
    const profileAddress = ownerOfGroupId(value);
    if (!profileAddress) {
      state.syncHint = `GroupNotExist：NFT #${value} 当前 ownerOf 不存在`;
      render();
      return;
    }
    let changes = 0;
    if (chat.adminDeny.senderIdDenyList.includes(value)) {
      chat.adminDeny.senderIdDenyList = chat.adminDeny.senderIdDenyList.filter((item) => item !== value);
      changes += 1;
    }
    if (profileAddress && chat.adminDeny.addressDenyList.includes(profileAddress)) {
      chat.adminDeny.addressDenyList = chat.adminDeny.addressDenyList.filter((item) => item !== profileAddress);
      changes += 1;
    }
    if (changes > 0) {
      chat.adminDeny.stateVersion += 1;
      state.syncHint = `removeDenyListsBySenderIds([${value}]) 已模拟，当前 ownerOf=${profileAddress}`;
    }
  } else if (listName === 'addressDenyList') {
    const targetGroupId = validDefaultGroupIdOf(value);
    let changes = 0;
    if (chat.adminDeny.addressDenyList.includes(value)) {
      chat.adminDeny.addressDenyList = chat.adminDeny.addressDenyList.filter((item) => item !== value);
      changes += 1;
    }
    if (targetGroupId && chat.adminDeny.senderIdDenyList.includes(targetGroupId)) {
      chat.adminDeny.senderIdDenyList = chat.adminDeny.senderIdDenyList.filter((item) => item !== targetGroupId);
      changes += 1;
    }
    if (changes > 0) {
      chat.adminDeny.stateVersion += 1;
      state.syncHint = targetGroupId
        ? `removeDenyListsBySenderAddresses([${value}]) 已模拟，联动 NFT #${targetGroupId}`
        : `removeDenyListsBySenderAddresses([${value}]) 已模拟`;
    }
  } else {
    chat.adminDeny[listName] = chat.adminDeny[listName].filter((item) => item !== value);
    chat.adminDeny.stateVersion += 1;
    state.syncHint = `${listName} 移除 ${value}`;
  }
  state.activeBlacklistMenuKey = null;
  state.activeExemptMenuKey = null;
  render();
}

function addGovTarget(targetType, inputId) {
  const chat = activeChat();
  const input = document.getElementById(inputId);
  const rawTarget = input.value.trim();
  const target = targetType === 'nft' ? resolveNftInput(rawTarget, state.nftInputMode) : rawTarget;
  if (!chat || chat.blacklistMode !== 'gov') return;
  if (!target) {
    state.syncHint = targetType === 'nft' ? `未找到 NFT：${rawTarget}` : '请输入目标地址。';
    render();
    return;
  }
  if (chat.voteWeight <= 0) {
    state.syncHint = '当前地址没有票权，只能查看、查询、发起 revalidate。';
    render();
    return;
  }
  ensureGovTarget(chat, targetType, target);
  voteGovTarget(targetType, target, 'support');
}

function applyGovVote(item, stance, weight) {
  if (!item || weight <= 0) return false;
  if (item.myVote === stance && item.myWeight === weight) return false;
  if (!item.myVote && stance === 'clear') return false;

  if (item.myVote === 'support') item.support -= item.myWeight;
  if (item.myVote === 'oppose') item.oppose -= item.myWeight;
  if (item.myVote && stance === 'clear') item.voters -= 1;

  if (stance === 'support') {
    if (!item.myVote) item.voters += 1;
    item.support += weight;
    item.myVote = 'support';
    item.myWeight = weight;
  } else if (stance === 'oppose') {
    if (!item.myVote) item.voters += 1;
    item.oppose += weight;
    item.myVote = 'oppose';
    item.myWeight = weight;
  } else {
    item.myVote = null;
    item.myWeight = 0;
  }

  item.voterList = (item.voterList || []).filter((entry) => entry.voter !== state.account);
  if (item.myVote) item.voterList.unshift({ voter: state.account, stance: item.myVote === 'support' ? '支持' : '反对', weight });
  return true;
}

function voteGovTarget(targetType, target, stance) {
  const chat = activeChat();
  const item = chat && findGovTarget(chat, targetType, target);
  if (!chat || !item || chat.voteWeight <= 0) return;
  const weight = chat.voteWeight;
  const changed = applyGovVote(item, stance, weight);
  if (!changed) {
    state.syncHint = `VoteUnchanged：${targetType} ${target}`;
    render();
    return;
  }
  chat.govDeny.stateVersion += 1;
  state.activeBlacklistMenuKey = null;
  state.syncHint = `GovVotedDenySource ${targetType} ${target} -> ${stance}`;
  render();
}

function addSenderDenyFromMessage(messageId, chatGroupId = state.activeChatGroupId) {
  const message = messageById(messageId, chatGroupId);
  const chat = message && chatById(message.chatGroupId);
  if (!chat || chat.blacklistMode !== 'admin' || !canEditAdminDeny(chat)) return;

  const targetSenderId = String(message.senderId);
  const targetAddress = ownerOfGroupId(targetSenderId);
  if (!targetAddress) {
    state.syncHint = `GroupNotExist：NFT #${targetSenderId} 当前 ownerOf 不存在`;
    render();
    return;
  }
  let changes = 0;
  if (!chat.adminDeny.addressDenyList.includes(targetAddress)) {
    chat.adminDeny.addressDenyList.push(targetAddress);
    changes += 1;
  }
  if (!chat.adminDeny.senderIdDenyList.includes(targetSenderId)) {
    chat.adminDeny.senderIdDenyList.push(targetSenderId);
    changes += 1;
  }

  if (changes > 0) {
    chat.adminDeny.stateVersion += 1;
    state.syncHint =
      `addDenyListsBySenderIds([${targetSenderId}]) 已模拟，当前 ownerOf=${targetAddress}，消息发送地址=${message.senderAddress}`;
  } else {
    state.syncHint = `sender ${targetAddress} / NFT #${targetSenderId} 已在黑名单`;
  }
  state.activeMenuMessageId = null;
  state.activeAvatarMenuKey = null;
  render();
}

function simulateMessageGap(chatId) {
  const chat = chatById(chatId);
  if (!chat) return;
  const chatGroupId = String(chat.chatGroupId);
  const visibleMessages = messagesForChat(chatGroupId);
  const latestMessageId = visibleMessages.length ? Math.max(...visibleMessages.map((message) => message.messageId)) : 0;
  const eventMessageId = latestMessageId + 3;
  const startMessageId = latestMessageId + 1;
  for (let messageId = startMessageId; messageId <= eventMessageId; messageId++) {
    state.messages.push({
      chatGroupId,
      senderId: 9101,
      senderAddress: ownerOfGroupId(9101),
      round: chat.round,
      messageId,
      content: `外部消息 #${messageId} 已通过 messages 区间补拉。`,
      mentionedSenderIds: [],
      mentionAll: false,
      quotedMessageId: 0,
      mine: false,
    });
  }
  chat.lastMessageId = eventMessageId;
  if (String(state.activeChatGroupId) === chatGroupId) markChatRead(chatGroupId);
  state.activeGroupMenuId = null;
  state.syncHint =
    `MessagePost 发现 messageId #${eventMessageId}，本地最新 #${latestMessageId}，已通过 messages(${chatGroupId}, ${latestMessageId}, ${eventMessageId - latestMessageId}, false) 补拉 #${startMessageId}-#${eventMessageId}。`;
  render();
}

function openGovVoters(targetType, target) {
  const chat = activeChat();
  const item = chat && findGovTarget(chat, targetType, target);
  if (!chat || !item) return;
  state.activeBlacklistMenuKey = null;
  state.activeGovVoterTargetType = targetType;
  state.activeGovVoterTarget = target;
  state.voterPage = 1;
  state.voterQuery = '';
  state.voterQueryResult = '';
  render();
  renderGovVoterSheet();
}

function activeGovVoterTarget() {
  const chat = activeChat();
  const item = chat && findGovTarget(chat, state.activeGovVoterTargetType, state.activeGovVoterTarget);
  return { chat, item };
}

function filteredGovVoters(item) {
  const voters = item ? item.voterList || [] : [];
  const query = state.voterQuery.trim();
  if (!query) return voters;
  return voters.filter((entry) => entry.voter.toLowerCase() === query.toLowerCase());
}

function renderGovVoterSheet() {
  const { item } = activeGovVoterTarget();
  if (!item) return;
  const voters = filteredGovVoters(item);
  const totalPages = Math.max(1, Math.ceil(voters.length / voterPageSize));
  const page = Math.min(Math.max(1, state.voterPage), totalPages);
  const start = (page - 1) * voterPageSize;
  const rows = voters.slice(start, start + voterPageSize);
  document.getElementById('status-sheet-content').innerHTML = `
    <dl class="status-card">
      <dt>目标</dt>
      <dd>${escapeHtml(blacklistTypeLabel(state.activeGovVoterTargetType))} ${escapeHtml(state.activeGovVoterTargetType === 'address' ? state.activeGovVoterTarget : `#${state.activeGovVoterTarget}`)}</dd>
      <dt>投票</dt>
      <dd>支持 ${item.support} · 反对 ${item.oppose}</dd>
    </dl>
    <section class="workspace-band">
      <h2>voter列表</h2>
      <div class="query-row blacklist-query-row">
        <input id="voter-query-input" value="${escapeHtml(state.voterQuery)}" placeholder="输入 voter 地址">
        <button class="sheet-button primary" type="button" data-action="query-voter" data-input="voter-query-input">查询</button>
        <button class="sheet-button" type="button" data-action="clear-voter-query">清除</button>
      </div>
      ${state.voterQueryResult ? `<div class="query-result">${escapeHtml(state.voterQueryResult)}</div>` : ''}
      ${rows.length ? rows.map((entry) => `
        <article class="list-row">
          <div>
            <strong>${escapeHtml(entry.voter)}</strong>
            <small>权重 ${entry.weight}</small>
          </div>
          <span class="pill ${entry.stance === '支持' ? 'pill-ok' : 'pill-warn'}">${escapeHtml(entry.stance)}</span>
          <div class="row-actions">
            <button type="button" data-action="revalidate-voter" data-voter="${escapeHtml(entry.voter)}">重算</button>
          </div>
        </article>
      `).join('') : '<div class="empty-state">暂无 voter</div>'}
      ${renderVoterPager(page, totalPages)}
    </section>
    <div class="close-row"><button type="button" class="sheet-button" data-action="close-gov-voters">关闭</button></div>
  `;
  document.getElementById('status-sheet').hidden = false;
}

function closeGovVoterSheet() {
  document.getElementById('status-sheet').hidden = true;
}

function renderVoterPager(page, totalPages) {
  if (totalPages <= 1) return '';
  return `
    <div class="pager-row">
      <button class="sheet-button" type="button" data-action="set-voter-page" data-page="${page - 1}" ${page <= 1 ? 'disabled' : ''}>上一页</button>
      <span>${page} / ${totalPages}</span>
      <button class="sheet-button" type="button" data-action="set-voter-page" data-page="${page + 1}" ${page >= totalPages ? 'disabled' : ''}>下一页</button>
    </div>
  `;
}

function setVoterPage(page) {
  state.voterPage = Math.max(1, Number(page) || 1);
  renderGovVoterSheet();
}

function queryVoter(inputId) {
  const input = document.getElementById(inputId);
  const voter = input.value.trim();
  const { item } = activeGovVoterTarget();
  state.voterQuery = voter;
  state.voterPage = 1;
  const found = item && voter ? (item.voterList || []).find((entry) => entry.voter.toLowerCase() === voter.toLowerCase()) : null;
  state.voterQueryResult = voter ? `${voter}：${found ? `${found.stance} · 权重 ${found.weight}` : '未投票'}` : '';
  renderGovVoterSheet();
}

function clearVoterQuery() {
  state.voterQuery = '';
  state.voterQueryResult = '';
  state.voterPage = 1;
  renderGovVoterSheet();
}

function revalidateVoter(voter) {
  if (!voter) return;
  state.revalidateVoter = voter;
  state.voterQueryResult = `已重算 voter ${voter}`;
  state.syncHint = `已发起 revalidate：target ${state.activeGovVoterTarget} / voter ${voter}`;
  renderGovVoterSheet();
}

function revalidateGovVote(targetType, target, inputId) {
  const chat = activeChat();
  const input = document.getElementById(inputId);
  const voter = input.value.trim();
  if (!chat || !voter) return;
  state.revalidateVoter = voter;
  state.syncHint = `已发起 revalidate：target ${target} / voter ${voter}`;
  render();
}

function querySelf() {
  const query = state.blacklistQueryType === 'address'
    ? state.account
    : state.nftInputMode === 'name' ? nftProfile(currentDefaultGroupId()).name : String(currentDefaultGroupId());
  state.blacklistQuery = query;
  queryBlacklistValue(query);
}

function queryBlacklist(inputId) {
  const input = document.getElementById(inputId);
  state.blacklistQuery = input.value.trim();
  queryBlacklistValue(state.blacklistQuery);
}

function queryBlacklistValue(value) {
  const chat = activeChat();
  if (!chat || !value) return;
  const isAddress = state.blacklistQueryType === 'address';
  const targetType = isAddress ? 'address' : 'nft';
  const govType = normalizeBlacklistTargetType(targetType);
  const resolvedValue = isAddress ? value : resolveNftInput(value, state.nftInputMode);
  const label = blacklistTypeLabel(targetType);
  let result = false;
  let extra = '';
  if (!resolvedValue) {
    state.activeBlacklistMenuKey = null;
    state.blacklistQueryResult = `未找到 NFT：${value}`;
    render();
    return;
  }
  if (chat.blacklistMode === 'gov') {
    const target = findGovTarget(chat, govType, resolvedValue);
    result = target ? targetDenied(target) : false;
    extra = target ? `support ${target.support} / oppose ${target.oppose}` : '无投票目标';
  } else {
    const deny = chat.adminDeny;
    const exempt = !isAddress && deny.senderIdExemptList.includes(resolvedValue);
    const denied = isAddress ? deny.addressDenyList.includes(resolvedValue) : deny.senderIdDenyList.includes(resolvedValue);
    result = exempt ? false : denied;
    extra = exempt ? '命中豁免名单' : 'AdminDenySource 当前状态';
  }
  state.activeBlacklistMenuKey = null;
  state.blacklistQuery = resolvedValue;
  state.blacklistQueryResult = `${label} ${resolvedValue}：${result ? '在黑名单' : '不在黑名单'} · ${extra}`;
  render();
}

function mentionTokenFor(senderId) {
  return `@${nftProfile(senderId).name}`;
}

function insertComposerToken(token) {
  const input = document.getElementById('composer-input');
  if (!input || input.value.includes(token)) return;
  const start = input.selectionStart ?? input.value.length;
  const end = input.selectionEnd ?? start;
  const before = input.value.slice(0, start);
  const after = input.value.slice(end);
  const prefix = before && !/\s$/.test(before) ? ' ' : '';
  const suffix = after && !/^\s/.test(after) ? ' ' : ' ';
  input.value = `${before}${prefix}${token}${suffix}${after}`;
  const cursor = before.length + prefix.length + token.length + 1;
  input.focus();
  input.setSelectionRange(cursor, cursor);
}

function parseComposerMentionedSenderIds(content) {
  const selected = new Set(state.mentionedSenderIds.map(String));
  let duplicateCount = 0;
  for (const [senderId, profile] of Object.entries(state.nftProfiles)) {
    const token = `@${profile.name}`;
    const count = tokenOccurrences(content, token);
    if (count > 0) selected.add(senderId);
    if (count > 1) duplicateCount += count - 1;
  }
  const matchedMentionedSenderIds = [];
  for (const senderId of selected) {
    if (content.includes(mentionTokenFor(senderId))) matchedMentionedSenderIds.push(Number(senderId));
  }
  const overLimitCount = Math.max(0, matchedMentionedSenderIds.length - 32);
  return {
    mentionedSenderIds: matchedMentionedSenderIds,
    mentionAll: content.includes('@全部'),
    duplicateCount,
    overLimitCount,
  };
}

function tokenOccurrences(content, token) {
  return content.split(token).length - 1;
}

function mentionSenderIdsValidationHint(draftMentionedSenderIds) {
  const notices = [];
  if (draftMentionedSenderIds.duplicateCount > 0) notices.push(`已去重 ${draftMentionedSenderIds.duplicateCount} 个重复 @`);
  if (draftMentionedSenderIds.overLimitCount > 0) notices.push(`超过 32 个，请删除 ${draftMentionedSenderIds.overLimitCount} 个`);
  return notices.length ? `mentionedSenderIds ${notices.join('；')}。` : '';
}

function sendMessage() {
  const input = document.getElementById('composer-input');
  const content = input.value.trim();
  const draftMentionedSenderIds = parseComposerMentionedSenderIds(content);
  const active = activeChatEntry();
  const chat = active && active.kind === 'group' ? active.item : null;
  const status = chatStatus(chat);
  if (!content || !status.allowed) {
    state.syncHint = status.allowed ? 'ContentEmpty：空消息会被合约拒绝。' : `${status.reasonCode}：当前 defaultGroupId 不能发言。`;
    render();
    return;
  }
  if (draftMentionedSenderIds.overLimitCount > 0) {
    state.syncHint =
      `TooManyMentionedSenderIds：mentionedSenderIds 最多 32 个，当前 ${draftMentionedSenderIds.mentionedSenderIds.length} 个；请删除 ${draftMentionedSenderIds.overLimitCount} 个 @ 后再发送。`;
    render();
    return;
  }

  const visibleMessages = messagesForChat(state.activeChatGroupId);
  const nextMessageId = visibleMessages.length ? Math.max(...visibleMessages.map((message) => message.messageId)) + 1 : 1;
  const quotedMessageId = activeQuotedMessageId() || 0;
  state.messages.push({
    chatGroupId: state.activeChatGroupId,
    senderId: currentDefaultGroupId(),
    senderAddress: state.account,
    round: chat ? chat.round : 0,
    messageId: nextMessageId,
    content,
    mentionedSenderIds: draftMentionedSenderIds.mentionedSenderIds,
    mentionAll: draftMentionedSenderIds.mentionAll,
    quotedMessageId,
    mine: true,
  });
  if (chat) chat.lastMessageId = nextMessageId;
  const mentionHint = mentionSenderIdsValidationHint(draftMentionedSenderIds);
  state.syncHint = `MessagePost 发现 messageId #${nextMessageId}，正文已通过 messages 补拉。${mentionHint ? ` ${mentionHint}` : ''}`;
  clearActiveQuote();
  state.mentionedSenderIds = [];
  state.mentionAll = false;
  input.value = '';
  render();
}

function quoteMessage(messageId) {
  const message = messageById(messageId);
  if (!canQuoteMessage(message)) return;
  state.quotedMessagesByChatGroupId[String(state.activeChatGroupId)] = Number(messageId);
  state.activeMenuMessageId = null;
  render();
}

async function copyMessage(messageId) {
  const message = messageById(messageId);
  if (!message) return;
  state.activeMenuMessageId = null;
  try {
    await writeClipboardText(message.content);
    state.syncHint = '已复制消息正文。';
  } catch (error) {
    state.syncHint = '复制失败：浏览器没有开放剪贴板权限。';
  }
  render();
}

async function writeClipboardText(text) {
  if (navigator.clipboard?.writeText) {
    await navigator.clipboard.writeText(text);
    return;
  }
  const textarea = document.createElement('textarea');
  textarea.value = text;
  textarea.setAttribute('readonly', '');
  textarea.style.position = 'fixed';
  textarea.style.opacity = '0';
  document.body.appendChild(textarea);
  textarea.select();
  const copied = document.execCommand('copy');
  textarea.remove();
  if (!copied) throw new Error('copy failed');
}

function addMention(senderId) {
  const chatGroupId = Number(senderId);
  if (!state.mentionedSenderIds.includes(chatGroupId) && state.mentionedSenderIds.length < 32) state.mentionedSenderIds.push(chatGroupId);
  insertComposerToken(mentionTokenFor(chatGroupId));
  state.activeMenuMessageId = null;
  render();
}

function selectMessage(messageId) {
  const index = Number(messageId);
  state.activeMenuMessageId = state.activeMenuMessageId === index ? null : index;
  state.activeAvatarMenuKey = null;
  render();
}

function toggleAvatarMenu(messageId, chatGroupId = state.activeChatGroupId) {
  if (suppressAvatarClick) {
    suppressAvatarClick = false;
    return;
  }

  const message = messageById(messageId, chatGroupId);
  const chat = message && chatById(message.chatGroupId);
  if (!message || !canShowAvatarDenyMenu(chat, message)) {
    state.activeAvatarMenuKey = null;
    render();
    return;
  }

  const key = messageMenuKey(message);
  state.activeAvatarMenuKey = state.activeAvatarMenuKey === key ? null : key;
  state.activeMenuMessageId = null;
  render();
}

function clearAvatarPress() {
  if (avatarPressState) clearTimeout(avatarPressState.timer);
  avatarPressState = null;
}

document.addEventListener('pointerdown', (event) => {
  const avatar = event.target.closest('[data-long-press-mention]');
  if (!avatar || event.button !== 0) return;
  clearAvatarPress();
  avatarPressState = {
    pointerId: event.pointerId,
    senderId: avatar.dataset.senderId,
    x: event.clientX,
    y: event.clientY,
    timer: setTimeout(() => {
      const senderId = avatarPressState?.senderId;
      avatarPressState = null;
      suppressAvatarClick = true;
      if (senderId) addMention(senderId);
    }, avatarLongPressMs),
  };
});

document.addEventListener('pointermove', (event) => {
  if (!avatarPressState || event.pointerId !== avatarPressState.pointerId) return;
  const moved = Math.abs(event.clientX - avatarPressState.x) > 10 || Math.abs(event.clientY - avatarPressState.y) > 10;
  if (moved) clearAvatarPress();
});

document.addEventListener('pointerup', clearAvatarPress);
document.addEventListener('pointercancel', clearAvatarPress);
document.addEventListener('contextmenu', (event) => {
  if (event.target.closest('[data-long-press-mention]')) event.preventDefault();
});

document.addEventListener('click', (event) => {
  const target = event.target.closest('[data-action]');
  if (!target) return;
  const action = target.dataset.action;
  if (action !== 'toggle-avatar-menu') suppressAvatarClick = false;

  if (action === 'set-bottom-tab') setBottomTab(target.dataset.tab);
  if (action === 'go-back') goBack();
  if (action === 'toggle-wallet') {
    state.walletConnected = !state.walletConnected;
    render();
  }
  if (action === 'set-view') setView(target.dataset.view);
  if (action === 'set-inbox-filter') {
    state.inboxFilter = target.dataset.filter;
    render();
  }
  if (action === 'set-blacklist-query-type') setBlacklistQueryType(target.dataset.queryType);
  if (action === 'set-blacklist-page') setBlacklistPage(target.dataset.page);
  if (action === 'toggle-blacklist-menu') toggleBlacklistMenu(target.dataset.targetType, target.dataset.target);
  if (action === 'toggle-exempt-menu') toggleExemptMenu(target.dataset.targetType, target.dataset.target);
  if (action === 'set-activation-type') {
    state.activationType = target.dataset.activationType;
    render();
  }
  if (action === 'select-chat') selectChat(target.dataset.chatId);
  if (action === 'open-activation') openActivation(target.dataset.chatId);
  if (action === 'open-activation-form') openActivationForm(target.dataset.chatId);
  if (action === 'open-chat') openChat(target.dataset.chatGroupId);
  if (action === 'activate-chat') activateChat(target.dataset.chatId);
  if (action === 'set-activation-option') setActivationOption(target.dataset.field, target.dataset.value);
  if (action === 'toggle-chat-menu') toggleChatMenu(target.dataset.chatId);
  if (action === 'simulate-message-gap') simulateMessageGap(target.dataset.chatId);
  if (action === 'open-manage') openManage(target.dataset.chatId);
  if (action === 'open-details') openDetails(target.dataset.chatId);
  if (action === 'open-blacklist') openBlacklist(target.dataset.chatId);
  if (action === 'open-exempt') openExempt(target.dataset.chatId);
  if (action === 'set-rule-slot') setRuleSlot(target.dataset.slot, target.dataset.input);
  if (action === 'set-rule-slot-option') setRuleSlotOption(target.dataset.slot, target.dataset.value);
  if (action === 'admin-list-add') addAdminList(target.dataset.list, target.dataset.input);
  if (action === 'admin-list-remove') removeAdminList(target.dataset.list, target.dataset.value);
  if (action === 'set-admin-query-type') setAdminIdQueryType(target.dataset.queryType);
  if (action === 'set-nft-input-mode') setNftInputMode(target.dataset.mode);
  if (action === 'query-admin-self') queryAdminSelf();
  if (action === 'query-admin-id') queryAdminId(target.dataset.input);
  if (action === 'gov-add-target') addGovTarget(target.dataset.targetType, target.dataset.input);
  if (action === 'gov-vote') voteGovTarget(target.dataset.targetType, target.dataset.target, target.dataset.stance);
  if (action === 'open-gov-voters') openGovVoters(target.dataset.targetType, target.dataset.target);
  if (action === 'set-voter-page') setVoterPage(target.dataset.page);
  if (action === 'query-voter') queryVoter(target.dataset.input);
  if (action === 'clear-voter-query') clearVoterQuery();
  if (action === 'revalidate-voter') revalidateVoter(target.dataset.voter);
  if (action === 'gov-revalidate') revalidateGovVote(target.dataset.targetType, target.dataset.target, target.dataset.input);
  if (action === 'query-self') querySelf();
  if (action === 'query-blacklist') queryBlacklist(target.dataset.input);
  if (action === 'close-gov-voters') closeGovVoterSheet();
  if (action === 'toggle-avatar-menu') toggleAvatarMenu(target.dataset.messageId, target.dataset.chatGroupId);
  if (action === 'select-message') selectMessage(target.dataset.messageId);
  if (action === 'quote-message') quoteMessage(target.dataset.messageId);
  if (action === 'copy-message') copyMessage(target.dataset.messageId);
  if (action === 'add-mention') addMention(target.dataset.senderId);
  if (action === 'add-sender-deny') addSenderDenyFromMessage(target.dataset.messageId, target.dataset.chatGroupId);
  if (action === 'clear-quote') {
    clearActiveQuote();
    render();
  }
});

document.getElementById('send-button').addEventListener('click', sendMessage);

render();
