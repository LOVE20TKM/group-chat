const prototypeData = window.LOVE20_CHAT_PROTOTYPE_DATA;

if (!prototypeData) {
  throw new Error('Missing LOVE20_CHAT_PROTOTYPE_DATA. Load prototype-data.js before app.js.');
}

const messagePreferenceStorageKey = 'love20-chat:message-preferences:v1';
const state = JSON.parse(JSON.stringify(prototypeData.initialState));
state.localMessagePreferences = readLocalMessagePreferences();
const { bottomTabs, activationTabs } = prototypeData;
const blacklistPageSize = prototypeData.pageSizes.blacklist;
const voterPageSize = prototypeData.pageSizes.voter;
const avatarLongPressMs = 520;
const conversationLongPressMs = 520;
let avatarPressState = null;
let conversationPressState = null;
let suppressAvatarClick = false;
let suppressConversationClick = false;

function escapeHtml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

function readLocalMessagePreferences() {
  try {
    const raw = window.localStorage?.getItem(messagePreferenceStorageKey);
    const parsed = raw ? JSON.parse(raw) : {};
    return parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : {};
  } catch (error) {
    return {};
  }
}

function writeLocalMessagePreferences() {
  try {
    if (!window.localStorage) {
      state.syncHint = '本地偏好缓存失败，当前只在页面内生效。';
      return false;
    }
    window.localStorage.setItem(messagePreferenceStorageKey, JSON.stringify(state.localMessagePreferences || {}));
    return true;
  } catch (error) {
    state.syncHint = '本地偏好缓存失败，当前只在页面内生效。';
    return false;
  }
}

function activeChat() {
  return state.chats.find((chat) => chat.groupId === state.activeGroupNumericId);
}

function activeChatEntry() {
  const chat = state.chats.find((item) => String(item.groupId) === String(state.activeGroupId));
  return chat ? { kind: 'group', item: chat } : null;
}

function nftProfile(senderId) {
  return state.nftProfiles[senderId] || { name: '群成员', badge: '人' };
}

function currentDefaultGroupId() {
  return state.defaultGroupId;
}

function ownerOfGroupId(groupId) {
  return state.groupOwners?.[String(groupId)] || '';
}

function validDefaultGroupIdOf(address) {
  const groupId = state.defaultGroupIdsByAddress?.[address];
  return groupId && ownerOfGroupId(groupId) === address ? groupId : '';
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

function messagesForChat(groupId = state.activeGroupId) {
  return state.messages.filter((message) => message.groupId === String(groupId));
}

function messageById(messageId, groupId = state.activeGroupId) {
  return messagesForChat(groupId).find((message) => message.messageId === Number(messageId));
}

function unreadMessagesForChat(groupId) {
  const lastRead = Number(state.readCursorsByGroupId?.[String(groupId)] || 0);
  const chat = chatById(groupId);
  return messagesForChat(groupId).filter((message) => !message.mine && message.messageId > lastRead && !shouldHideMessage(chat, message));
}

function markChatRead(groupId) {
  const key = String(groupId);
  if (!state.readCursorsByGroupId) state.readCursorsByGroupId = {};
  const latestMessageId = messagesForChat(key).reduce((latest, message) => Math.max(latest, Number(message.messageId) || 0), 0);
  state.readCursorsByGroupId[key] = latestMessageId;
}

function conversationStatus(chat) {
  const unread = unreadMessagesForChat(chat.groupId);
  const mySenderId = Number(currentDefaultGroupId());
  return {
    unreadCount: unread.length,
    hasMentionMe: unread.some((message) => (message.mentionedSenderIds || []).map(Number).includes(mySenderId)),
    hasMentionAll: unread.some((message) => message.mentionAll),
  };
}

function messageMenuKey(message) {
  return `${message.groupId}:${message.messageId}`;
}

function activeQuotedMessageId() {
  return state.quotedMessagesByGroupId[String(state.activeGroupId)] || null;
}

function canQuoteMessage(message) {
  return Number(message?.messageId) > 0;
}

function clearActiveQuote() {
  delete state.quotedMessagesByGroupId[String(state.activeGroupId)];
}

function chatDisplayName(chat) {
  if (chat.type === 'token-community') return `${chatTokenSymbol(chat)} 主群`;
  if (chat.type === 'token-gov') return `${chatTokenSymbol(chat)} 治理群`;
  if (chat.type === 'action') return `${chatTokenSymbol(chat)} 行动主群-No.${chat.actionId}-${actionTitle(chat)}`;
  if (chat.type === 'action-gov') return `${chatTokenSymbol(chat)} 行动治理群-No.${chat.actionId}-${actionTitle(chat)}`;
  if (chat.type === 'chain-service') return `链群-${chat.chainName || chat.groupId}`;
  return chat.title;
}

function chatListTitle(chat) {
  if (chat.type === 'action' || chat.type === 'action-gov') return `No.${chat.actionId} ${actionTitle(chat)}`;
  if (chat.type === 'chain-service') return chat.chainName || chat.shortTitle || String(chat.groupId);
  return chatDisplayName(chat);
}

function chatTokenSymbol(chat) {
  return chat.tokenSymbol || chat.token;
}

function actionTitle(chat) {
  const action = state.actions.find((item) => item.token === chatTokenSymbol(chat) && item.actionId === chat.actionId);
  return action ? action.title : '行动';
}

function chatTypeLabel(chat) {
  const labels = {
    'token-community': '主群',
    'token-gov': '治理',
    action: '行动主群',
    'action-gov': '行动治理',
    'chain-service': '链群',
  };
  return labels[chat.type] || '群聊';
}

function conversationReminders(status) {
  const reminders = [];
  if (status.hasMentionMe) reminders.push({ label: '@我', html: '<span class="conversation-badge mention-me">@我</span>' });
  if (status.hasMentionAll) reminders.push({ label: '@全部', html: '<span class="conversation-badge mention-all">@全部</span>' });
  if (status.unreadCount > 0) reminders.push({ label: `未读 ${status.unreadCount}`, html: `<span class="conversation-badge unread-meta">未读 ${status.unreadCount}</span>` });
  return reminders;
}

function chatListMeta(chat) {
  const meta = chat.type === 'chain-service'
    ? [chatTypeLabel(chat), `G#${chat.groupId}`]
    : [chatTokenSymbol(chat), chatTypeLabel(chat), `G#${chat.groupId}`];
  return meta.join(' · ');
}

function renderChatListHeader(chat, reminders) {
  const metaText = chatListMeta(chat);
  const reminderText = reminders.length ? ` ${reminders.map((item) => item.label).join(' ')}` : '';
  const headerLabel = `${metaText}${reminderText}`;
  return `
    <div class="conversation-kicker" aria-label="${escapeHtml(headerLabel)}">
      <span class="conversation-meta-text">${escapeHtml(metaText)}</span>
      ${reminders.length ? `<span class="conversation-reminders">${reminders.map((item) => item.html).join('')}</span>` : ''}
    </div>
  `;
}

function isPinnedConversation(groupId) {
  return (state.pinnedGroupIds || []).map(Number).includes(Number(groupId));
}

function activationTypeForChat(chat) {
  if (!chat) return 'token';
  if (['token-community', 'token-gov'].includes(chat.type)) return 'token';
  if (['action', 'action-gov'].includes(chat.type)) return 'action';
  if (chat.type === 'chain-service') return 'chain';
  return 'token';
}

function activationDraftFor(chat) {
  const key = String(chat.groupId);
  if (!state.activationDrafts[key]) {
    state.activationDrafts[key] = {
      ...chat.params,
      metaTitle: chatDisplayName(chat),
      metaDescription: chat.typeLabel,
      scopeSource: chat.chatInfo.scopeSource,
      banSource: chat.chatInfo.banSource,
      beforePostPlugin: chat.chatInfo.beforePostPlugin,
      afterPostPlugin: chat.chatInfo.afterPostPlugin,
      delegateId: chat.chatInfo.delegateId,
    };
  }
  return state.activationDrafts[key];
}

function activationFieldLabel(field) {
  const labels = {
    groupId: 'groupId',
    token: 'token',
    actionId: 'actionId',
    metaTitle: 'meta.title',
    metaDescription: 'meta.description',
    scopeSource: 'scopeSource',
    banSource: 'banSource',
    beforePostPlugin: 'beforePostPlugin',
    afterPostPlugin: 'afterPostPlugin',
    delegateId: 'delegateId',
  };
  return labels[field] || field;
}

function activationInputMode(field) {
  return ['groupId', 'actionId'].includes(field) ? 'numeric' : 'text';
}

function ruleSlotOptions(slot) {
  const options = {
    scopeSource: [
      { value: 'address(0)', label: '不设置' },
      { value: 'GroupMemberScope', label: 'GroupMemberScope' },
      { value: 'GroupJoinScopeSource', label: 'GroupJoinScopeSource' },
    ],
    banSource: [
      { value: 'address(0)', label: '不设置' },
      { value: 'AdminBanSource', label: 'AdminBanSource' },
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
    draft.groupId = draft.groupId || String(chat.groupId);
  }
  return draft;
}

function activationIssue(chat, draft) {
  if (!chat) return '请选择群聊';
  if (chat.activated) return '该群聊已激活';
  if (chat.model === 'chain-service') {
    if (Number(draft.groupId) !== chat.groupId) return 'groupId 必须等于当前 GroupNFT tokenId';
    if (chat.role !== 'owner') return '只有 groupId 当前 owner 可以直接激活';
    const delegateId = resolveOptionalKnownNftInput(draft.delegateId, state.nftInputMode);
    if (!delegateId) return `未找到 NFT：${draft.delegateId}`;
    if (Number(delegateId || 0) === chat.groupId) return 'delegateId 不能等于 groupId';
  }
  return '';
}

function activationPreview(chat, draft) {
  if (chat.model === 'chain-service') {
    const delegateId = resolveOptionalKnownNftInput(draft.delegateId, state.nftInputMode);
    return `activateChat(${draft.groupId}, metaKeys, metaValues, ${draft.scopeSource}, ${draft.banSource}, ${draft.beforePostPlugin}, ${draft.afterPostPlugin}, ${delegateId})`;
  }
  const values = Object.keys(chat.params).map((key) => draft[key]).join(', ');
  return `${chat.manager}.activate(${values})`;
}

function manageableRole(chat) {
  return chat && ['owner', 'delegate', 'admin'].includes(chat.role);
}

function canEditRules(chat) {
  return chat && ['owner', 'delegate'].includes(chat.role);
}

function groupAdminState(chat) {
  return chat?.groupAdmin || { stateVersion: 0, adminIds: [] };
}

function ensureGroupAdminState(chat) {
  if (!chat.groupAdmin) chat.groupAdmin = { stateVersion: 0, adminIds: [] };
  return chat.groupAdmin;
}

function groupAdminIds(chat) {
  return groupAdminState(chat).adminIds || [];
}

function groupMemberScopeState(chat) {
  return chat?.groupMemberScope || { stateVersion: 0, memberIds: [] };
}

function ensureGroupMemberScopeState(chat) {
  if (!chat.groupMemberScope) chat.groupMemberScope = { stateVersion: 0, memberIds: [] };
  return chat.groupMemberScope;
}

function refreshManualMemberScopeAllowed(chat) {
  if (chat?.chatInfo?.scopeSource !== 'GroupMemberScope') return;
  chat.scopeAllowed = groupMemberScopeState(chat).memberIds.includes(String(currentDefaultGroupId()));
}

function isAdminBanOperator(chat) {
  return Boolean(groupAdminIds(chat).includes(String(currentDefaultGroupId())));
}

function canEditAdminBan(chat) {
  return chat && chat.blacklistMode === 'admin' && isAdminBanOperator(chat);
}

function canEditMemberScope(chat) {
  return Boolean(chat?.groupMemberScope) && isAdminBanOperator(chat);
}

const BAN_THRESHOLD_PRECISION = 1000000000000000000n;

function uintLike(value) {
  const raw = String(value ?? 0).trim();
  return /^\d+$/.test(raw) ? BigInt(raw) : 0n;
}

function targetBanned(chat, target) {
  const support = uintLike(target.support);
  const oppose = uintLike(target.oppose);
  if (support <= oppose) return false;
  const totalWeight = uintLike(chat?.govBan?.totalWeight);
  const thresholdRatio = uintLike(chat?.govBan?.banThresholdRatio);
  if (totalWeight === 0n || thresholdRatio === 0n) return true;
  return support * BAN_THRESHOLD_PRECISION >= totalWeight * thresholdRatio;
}

function normalizeBlacklistTargetType(targetType) {
  return targetType === 'nft' ? 'group' : targetType;
}

function blacklistTypeLabel(targetType) {
  return targetType === 'address' ? '地址' : 'NFT';
}

function blacklistNftLabel(target) {
  const profile = state.nftProfiles?.[String(target)];
  return profile?.name || `NFT #${target}`;
}

function blacklistRowKey(targetType, target) {
  return `${targetType}:${target}`;
}

function sameAddress(left, right) {
  return String(left || '').toLowerCase() === String(right || '').toLowerCase();
}

function govTargets(chat, targetType) {
  targetType = normalizeBlacklistTargetType(targetType);
  return targetType === 'address' ? chat.govBan.addressTargets : chat.govBan.senderIdTargets;
}

function govAddressBanned(chat, senderAddress) {
  return Boolean(senderAddress && chat?.govBan?.addressBanList?.some((item) => sameAddress(item, senderAddress)));
}

function govSenderIdBanned(chat, senderId) {
  return Boolean(senderId && chat?.govBan?.senderIdBanList?.includes(String(senderId)));
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

function govMyVoteDetail(item) {
  if (!item || !item.myVote) return '我的投票：未投票';
  return `我的投票：${item.myVote === 'support' ? '支持' : '反对'} ${item.myWeight}`;
}

function adminBanOperatorRecord(chat, targetType, target) {
  const normalizedType = normalizeBlacklistTargetType(targetType);
  const mapName = normalizedType === 'address' ? 'addressBanOperatorStates' : 'senderIdBanOperatorStates';
  const records = chat?.adminBan?.[mapName] || {};
  if (normalizedType === 'address') {
    const found = Object.entries(records).find(([key]) => sameAddress(key, target));
    return found ? found[1] : null;
  }
  return records[String(target)] || null;
}

function adminBanOperatorDetailFromValues(operatorAddress, operatorId) {
  if (!operatorAddress) return '拉黑人：无当前记录';
  operatorId = operatorId ? String(operatorId) : '';
  const operatorNft = operatorId && operatorId !== '0' ? `NFT #${operatorId} · ${nftProfile(operatorId).name}` : 'NFT 未知';
  return `拉黑人：${operatorNft} · ${operatorAddress}`;
}

function adminBanTargets(chat, targetType) {
  const normalizedType = normalizeBlacklistTargetType(targetType);
  return normalizedType === 'address' ? chat.adminBan.addressBanList : chat.adminBan.senderIdBanList;
}

function adminBanListPage(chat, targetType, offset, limit) {
  const targets = adminBanTargets(chat, targetType).slice(offset, offset + limit);
  const operatorAddresses = [];
  const operatorIds = [];
  for (const target of targets) {
    const record = adminBanOperatorRecord(chat, targetType, target);
    operatorAddresses.push(record?.operatorAddress || '');
    operatorIds.push(record?.operatorId ? String(record.operatorId) : '0');
  }
  return { targets, operatorAddresses, operatorIds };
}

function adminBanRowsFromPage(chat, targetType, offset, limit) {
  const page = adminBanListPage(chat, targetType, offset, limit);
  return page.targets.map((target, index) => ({
    type: targetType === 'address' ? 'address' : 'nft',
    target,
    label: targetType === 'address' ? target : blacklistNftLabel(target),
    status: '已拉黑',
    statusClass: 'pill-bad',
    detail: targetType === 'address'
      ? adminBanOperatorDetailFromValues(page.operatorAddresses[index], page.operatorIds[index])
      : `NFT #${target} · ${adminBanOperatorDetailFromValues(page.operatorAddresses[index], page.operatorIds[index])}`,
  }));
}

function setAdminBanOperator(chat, targetType, target) {
  const normalizedType = normalizeBlacklistTargetType(targetType);
  const mapName = normalizedType === 'address' ? 'addressBanOperatorStates' : 'senderIdBanOperatorStates';
  if (!chat.adminBan[mapName]) chat.adminBan[mapName] = {};
  chat.adminBan[mapName][String(target)] = {
    operatorAddress: state.account,
    operatorId: String(currentDefaultGroupId()),
  };
}

function clearAdminBanOperator(chat, targetType, target) {
  const normalizedType = normalizeBlacklistTargetType(targetType);
  const mapName = normalizedType === 'address' ? 'addressBanOperatorStates' : 'senderIdBanOperatorStates';
  if (chat.adminBan[mapName]) delete chat.adminBan[mapName][String(target)];
}

function currentSenderBanned(chat) {
  if (!chat || chat.blacklistMode === 'none') return false;
  if (chat.blacklistMode === 'gov') {
    return govAddressBanned(chat, state.account) || govSenderIdBanned(chat, currentDefaultGroupId());
  }

  const ban = chat.adminBan;
  return ban.addressBanList.includes(state.account) || ban.senderIdBanList.includes(String(currentDefaultGroupId()));
}

function messagePreferenceKey(groupId = state.activeGroupId) {
  return `${state.account || 'disconnected'}:${String(groupId)}`;
}

function groupMessagePreference(groupId = state.activeGroupId) {
  return state.localMessagePreferences?.[messagePreferenceKey(groupId)] || {};
}

function showBlacklistedMessages(groupId = state.activeGroupId) {
  return Boolean(groupMessagePreference(groupId).showBlacklistedMessages);
}

function setShowBlacklistedMessages(groupId, value) {
  const key = messagePreferenceKey(groupId);
  state.localMessagePreferences = {
    ...(state.localMessagePreferences || {}),
    [key]: { ...groupMessagePreference(groupId), showBlacklistedMessages: Boolean(value) },
  };
  return writeLocalMessagePreferences();
}

function messageSenderBanned(chat, message) {
  if (!chat || !message || chat.blacklistMode === 'none') return false;
  const senderAddress = message.senderAddress;
  const senderId = message.senderId ? String(message.senderId) : '';

  if (chat.blacklistMode === 'gov') {
    return govAddressBanned(chat, senderAddress) || govSenderIdBanned(chat, senderId);
  }

  const ban = chat.adminBan;
  if (!ban) return false;
  return Boolean(
    (senderAddress && ban.addressBanList.some((item) => sameAddress(item, senderAddress))) ||
    (senderId && ban.senderIdBanList.includes(senderId)),
  );
}

function shouldHideMessage(chat, message) {
  return messageSenderBanned(chat, message) && !showBlacklistedMessages(message.groupId);
}

function chatStatus(chat) {
  if (!chat) return { allowed: false, reasonCode: 'ChatNotSelected', label: '未选择群聊' };
  if (!chat.activated) return { allowed: false, reasonCode: 'ChatNotActivated', label: '未激活' };
  if (!chat.postingAllowed) return { allowed: false, reasonCode: 'PostingNotAllowed', label: '已停止发言' };
  if (chat.defaultGroupOwnerMatches === false) {
    return { allowed: false, reasonCode: 'SenderAddressNotSenderIdOwner', label: '不是 defaultGroupId owner' };
  }
  if (!chat.scopeAllowed) return { allowed: false, reasonCode: 'ScopeRejected', label: '无发言资格' };
  if (currentSenderBanned(chat)) return { allowed: false, reasonCode: 'BanRejected', label: '命中黑名单' };
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
  const composerBanned = document.getElementById('composer-banned');
  const statusStrip = document.getElementById('status-strip');
  const chatView = state.bottomTab === 'chat' && state.view === 'chat';
  const active = activeChatEntry();
  const chat = active && active.kind === 'group' ? active.item : null;
  const status = chatStatus(chat);
  const canCompose = chatView && status.allowed;
  const showComposerBanned = chatView && !status.allowed;

  workspace.hidden = chatView;
  messageList.hidden = !chatView;
  composer.hidden = !canCompose;
  composerBanned.hidden = !showComposerBanned;
  composerBanned.innerHTML = showComposerBanned ? renderCannotPost(chat, status) : '';
  statusStrip.hidden = !(state.bottomTab === 'chat' && state.view === 'chat') || showComposerBanned;

  if (state.bottomTab !== 'chat') {
    workspace.innerHTML = renderPlaceholder();
    return;
  }

  if (state.view === 'inbox') workspace.innerHTML = renderInbox();
  if (state.view === 'activate') workspace.innerHTML = renderActivationHub();
  if (state.view === 'activate-form') workspace.innerHTML = renderActivationForm();
  if (state.view === 'details') workspace.innerHTML = renderGroupDetails();
  if (state.view === 'preferences') workspace.innerHTML = renderGroupPreferences();
  if (state.view === 'members') workspace.innerHTML = renderGroupMembers();
  if (state.view === 'admins') workspace.innerHTML = renderGroupAdmins();
  if (state.view === 'settings') workspace.innerHTML = renderGroupSettings();
  if (state.view === 'manage') workspace.innerHTML = renderManagement();
  if (state.view === 'blacklist') workspace.innerHTML = renderBlacklist();
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
    <section class="conversation-list">${renderConversationRows()}</section>
    <div class="inbox-action-row">
      <button class="sheet-button primary" type="button" data-action="set-view" data-view="activate">群聊激活</button>
    </div>
  `;
}

function inboxConversations() {
  const groups = state.chats.map((item) => ({ kind: 'group', item }));
  return groups.filter((entry) => entry.item.activated);
}

function renderConversationRows() {
  const rows = inboxConversations();
  if (!rows.length) return '<div class="empty-state">暂无会话</div>';
  const pinnedRows = rows.filter((entry) => isPinnedConversation(entry.item.groupId));
  const recommendedRows = rows.filter((entry) => !isPinnedConversation(entry.item.groupId));

  return [
    renderConversationSection('置顶群聊', pinnedRows, '暂无置顶群聊'),
    renderConversationSection('推荐群聊', recommendedRows, '暂无更多推荐群聊'),
  ].join('');
}

function renderConversationSection(label, rows, emptyText) {
  const count = rows.length ? `<span>${rows.length} 个</span>` : '';
  const content = rows.length
    ? rows.map(renderConversationRow).join('')
    : `<div class="empty-state compact">${emptyText}</div>`;

  return `
    <div class="conversation-section">
      <div class="conversation-section-label"><strong>${label}</strong>${count}</div>
      ${content}
    </div>
  `;
}

function renderConversationRow(entry) {
  const chat = entry.item;
  const rowAction = chat.activated ? 'open-chat' : 'open-activation';
  const rowTarget = chat.activated ? `data-group-id="${chat.groupId}"` : `data-group-id="${chat.groupId}"`;
  const status = conversationStatus(chat);
  const reminders = conversationReminders(status);
  const pinned = isPinnedConversation(chat.groupId);
  const menu = state.activeConversationMenuGroupId === chat.groupId ? `
    <div class="conversation-menu">
      <button type="button" data-action="toggle-conversation-pin" data-group-id="${chat.groupId}">${pinned ? '取消置顶' : '置顶'}</button>
    </div>
  ` : '';

  return `
    <article class="conversation-row group-row conversation-type-${chat.type}${pinned ? ' pinned' : ''}" data-action="${rowAction}" ${rowTarget} data-long-press-conversation data-menu-open="${state.activeConversationMenuGroupId === chat.groupId ? 'true' : 'false'}">
      <div class="conversation-type-rail" aria-hidden="true"></div>
      <div class="conversation-main">
        <div class="conversation-title">${escapeHtml(chatListTitle(chat))}</div>
        ${renderChatListHeader(chat, reminders)}
      </div>
      ${menu}
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
  const mainAction = chat.activated ? 'open-chat' : 'open-activation-form';
  const mainTarget = chat.activated ? `data-group-id="${chat.groupId}"` : `data-group-id="${chat.groupId}"`;
  return `
    <article class="type-card">
      <div class="card-topline">
        <strong>${escapeHtml(chatDisplayName(chat))}</strong>
        <span class="pill ${chat.activated ? 'pill-ok' : 'pill-warn'}">${chat.activated ? '已激活' : '待激活'}</span>
      </div>
      <div class="muted">${escapeHtml(chat.manager)} · ${escapeHtml(chat.activationCall)}</div>
      <div class="kv-grid">${renderParams(chat.params)}</div>
      <div class="card-actions">
        <button class="sheet-button primary" type="button" data-action="${mainAction}" ${mainTarget}>${chat.activated ? '进入' : '配置入参'}</button>
        <button class="sheet-button" type="button" data-action="open-blacklist" data-group-id="${chat.groupId}" ${chat.activated ? '' : 'disabled'}>黑名单</button>
      </div>
    </article>
  `;
}

function renderActionActivation(action) {
  const actionChat = chatById(action.actionGroupId);
  const actionGovChat = chatById(action.actionGovGroupId);
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
  const mainAction = chat.activated ? 'open-chat' : 'open-activation-form';
  const mainTarget = chat.activated ? `data-group-id="${chat.groupId}"` : `data-group-id="${chat.groupId}"`;
  return `
    <div class="mini-card">
      <strong>${escapeHtml(chatDisplayName(chat))}</strong>
      <button class="sheet-button${chat.activated ? '' : ' primary'}" type="button" data-action="${mainAction}" ${mainTarget}>
        ${chat.activated ? '进入' : '配置'}
      </button>
    </div>
  `;
}

function renderChainActivation(chat) {
  return `
    <article class="action-row">
      <div class="card-topline">
        <strong>${escapeHtml(chatDisplayName(chat))}</strong>
        <span class="pill ${chat.activated ? 'pill-ok' : 'pill-warn'}">${chat.activated ? chat.role : '待激活'}</span>
      </div>
      <div class="muted">一个代币社区可有多个链群服务者管理群</div>
      <div class="inline-actions">
        <button type="button" data-action="${chat.activated ? 'open-chat' : 'open-activation-form'}" ${chat.activated ? `data-group-id="${chat.groupId}"` : `data-group-id="${chat.groupId}"`}>${chat.activated ? '进入' : '配置'}</button>
        ${chat.activated && (canEditRules(chat) || canEditMemberScope(chat)) ? `<button type="button" data-action="open-manage" data-group-id="${chat.groupId}">群管理</button>` : ''}
        ${chat.activated ? `<button type="button" data-action="open-blacklist" data-group-id="${chat.groupId}">黑名单</button>` : ''}
      </div>
    </article>
  `;
}

function renderActivationForm() {
  const chat = activeChat();
  if (!chat) return renderActivationHub();
  const draft = activationDraftFor(chat);
  const issue = activationIssue(chat, draft);
  const fields = chat.model === 'chain-service'
    ? renderDirectActivationFields(chat, draft)
    : renderManagerActivationFields(chat, draft);

  return `
    <section class="workspace-band activation-form">
      <div class="screen-heading">
        <h1>${escapeHtml(chatDisplayName(chat))}</h1>
        <span class="pill ${chat.activated ? 'pill-ok' : 'pill-warn'}">${chat.activated ? '已激活' : '待激活'}</span>
      </div>
      <div class="kv-grid">${renderParams(chat.params)}</div>
      ${fields}
      <div class="activation-preview">
        <b>调用预览</b>
        <code>${escapeHtml(activationPreview(chat, draft))}</code>
      </div>
      ${issue ? `<div class="notice-row">${escapeHtml(issue)}</div>` : ''}
      <div class="card-actions">
        <button class="sheet-button primary" type="button" data-action="activate-chat" data-group-id="${chat.groupId}" ${issue ? 'disabled' : ''}>提交激活</button>
        <button class="sheet-button" type="button" data-action="set-view" data-view="activate">返回列表</button>
      </div>
    </section>
  `;
}

function renderManagerActivationFields(chat, draft) {
  return `
    <section class="activation-section">
      <h2>Manager 入参</h2>
      ${Object.keys(chat.params).map((field) => renderActivationTextInput(field, draft[field], field === 'groupId')).join('')}
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
      ${renderActivationChoice('banSource', draft.banSource)}
      ${renderActivationChoice('beforePostPlugin', draft.beforePostPlugin)}
      ${renderActivationChoice('afterPostPlugin', draft.afterPostPlugin)}
      ${renderActivationTextInput('delegateId', draft.delegateId)}
    </section>
  `;
}

function renderNftLookupControl(inputId, value, mode, placeholder, selectAction, readonly = false, inputMode = 'text', inputAttrs = '') {
  return `
    <div class="nft-lookup">
      <div class="nft-lookup-mode">
        <select class="nft-lookup-mode-select" data-action="${selectAction}" aria-label="NFT查询方式" ${readonly ? 'disabled' : ''}>
          <option value="name" ${mode === 'name' ? 'selected' : ''}>NFT名称</option>
          <option value="id" ${mode === 'id' ? 'selected' : ''}>NFT ID</option>
        </select>
        <span class="nft-lookup-mode-arrow" aria-hidden="true"></span>
      </div>
      <input
        id="${inputId}"
        class="nft-lookup-input${mode === 'id' ? ' is-id' : ''}"
        value="${escapeHtml(value ?? '')}"
        inputmode="${inputMode}"
        placeholder="${placeholder}"
        ${inputAttrs}
        ${readonly ? 'readonly' : ''}
      >
    </div>
  `;
}

function renderActivationTextInput(field, value, readonly = false) {
  const id = `activation-${field}-input`;
  const placeholder = field === 'delegateId' ? (state.nftInputMode === 'name' ? '请输入NFT名称' : '请输入NFT ID') : '';
  const inputMode = field === 'delegateId' ? (state.nftInputMode === 'id' ? 'numeric' : 'text') : activationInputMode(field);
  const control = field === 'delegateId'
    ? renderNftLookupControl(id, value, state.nftInputMode, placeholder, 'set-nft-input-mode-select', readonly, inputMode, `data-activation-field="${field}"`)
    : `<input id="${id}" data-activation-field="${field}" value="${escapeHtml(value ?? '')}" inputmode="${inputMode}" placeholder="${placeholder}" ${readonly ? 'readonly' : ''}>`;
  return `
    <div class="field-row activation-field-row">
      <label for="${id}">${escapeHtml(activationFieldLabel(field))}</label>
      ${control}
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
  return renderGroupSettings();
}

function renderGroupSettings() {
  const chat = activeChat();
  if (!chat) return '<div class="empty-state">请选择群聊</div>';
  if (chat.model === 'decentralized') return renderDecentralizedManagement(chat);
  return renderChainServiceManagement(chat);
}

function renderDecentralizedManagement(chat) {
  return `
    <section class="workspace-band">
      ${renderGroupDetailHeader(chat, '群设置', 'Manager 持有 NFT')}
      <div class="rule-table">${renderRuleRows(chat)}</div>
      ${renderPermissionNotice(false, '', '去中心化群聊由 Manager 持有群聊 NFT；激活后这里没有可修改的群设置。')}
    </section>
  `;
}

function renderChainServiceManagement(chat) {
  const canEdit = canEditRules(chat);

  return `
    <section class="workspace-band">
      ${renderGroupDetailHeader(chat, '群设置', chat.role)}
      ${renderPermissionNotice(
        canEdit,
        '有权限：当前身份是 owner/delegate，可修改 postingAllowed、规则槽和代理 NFT。',
        '无权限：群设置只允许当前 owner 或有效 delegate 修改；本页只读。',
      )}
      ${renderGroupStatusCard(chat)}
      <section class="activation-section">
        <h2>owner / delegate 配置</h2>
        ${renderPostingAllowedControl(chat, canEdit)}
        ${renderRuleInput(chat, 'scopeSource', canEdit)}
        ${renderRuleInput(chat, 'banSource', canEdit)}
        ${renderRuleInput(chat, 'beforePostPlugin', canEdit)}
        ${renderRuleInput(chat, 'afterPostPlugin', canEdit)}
        ${renderDelegateInput(chat, canEdit)}
      </section>
    </section>
  `;
}

function renderPostingAllowedControl(chat, canEdit = canEditRules(chat)) {
  return `
    <div class="field-row activation-choice-row">
      <label>postingAllowed</label>
      <div class="choice-group">
        <button class="picker-button${chat.postingAllowed ? ' active' : ''}" type="button" data-action="set-posting-allowed" data-value="true" ${canEdit ? '' : 'disabled'}>允许发言</button>
        <button class="picker-button${chat.postingAllowed ? '' : ' active'}" type="button" data-action="set-posting-allowed" data-value="false" ${canEdit ? '' : 'disabled'}>停止发言</button>
      </div>
    </div>
  `;
}

function renderRuleInput(chat, slot, canEdit = canEditRules(chat)) {
  const options = ruleSlotOptions(slot);
  if (options) return renderRuleChoice(chat, slot, options, canEdit);

  const id = `${slot}-input`;
  return `
    <div class="field-row">
      <label for="${id}">${slot}</label>
      <input id="${id}" value="${escapeHtml(chat.chatInfo[slot])}" inputmode="text" ${canEdit ? '' : 'readonly'}>
      <button class="sheet-button" type="button" data-action="set-rule-slot" data-slot="${slot}" data-input="${id}" ${canEdit ? '' : 'disabled'}>更新</button>
    </div>
  `;
}

function renderDelegateInput(chat, canEdit = canEditRules(chat)) {
  const value = chat.chatInfo.delegateId || '0';
  const placeholder = state.nftInputMode === 'name' ? '请输入代理NFT名称' : '请输入代理NFT ID';
  const inputMode = state.nftInputMode === 'id' ? 'numeric' : 'text';
  return `
    <div class="delegate-panel">
      <div class="card-topline">
        <strong>代理 NFT</strong>
        <span>delegateId</span>
      </div>
      <div class="query-result">${escapeHtml(delegateDisplay(value))}</div>
      <div class="query-row delegate-query-row">
        ${renderNftLookupControl('delegateId-input', '', state.nftInputMode, placeholder, 'set-nft-input-mode-select', !canEdit, inputMode)}
        <button class="sheet-button primary" type="button" data-action="set-rule-slot" data-slot="delegateId" data-input="delegateId-input" ${canEdit ? '' : 'disabled'}>确认</button>
      </div>
      <div class="muted">输入 0 表示不设置代理。</div>
      ${state.delegateQueryResult ? `<div class="query-result">${escapeHtml(state.delegateQueryResult)}</div>` : ''}
    </div>
  `;
}

function managementNotice(chat) {
  if (canEditRules(chat)) return 'owner/delegate 可管理群聊设置和 GroupAdmin 管理员 NFT。黑名单与成员 NFT 由管理员 NFT 维护。';
  if (canEditMemberScope(chat)) return '当前默认 NFT 命中 GroupAdmin 管理员名单，可维护黑名单与成员 NFT。';
  return '当前地址只读。';
}

function renderRuleChoice(chat, slot, options, canEdit = canEditRules(chat)) {
  return `
    <div class="field-row activation-choice-row">
      <label>${slot}</label>
      <div class="choice-group">
        ${options.map((option) => `
          <button class="picker-button${chat.chatInfo[slot] === option.value ? ' active' : ''}" type="button" data-action="set-rule-slot-option" data-slot="${slot}" data-value="${escapeHtml(option.value)}" ${canEdit ? '' : 'disabled'}>${escapeHtml(option.label)}</button>
        `).join('')}
      </div>
    </div>
  `;
}

function renderAdminIdControls(chat) {
  const placeholder = state.adminIdQueryType === 'name' ? '请输入NFT名称' : '请输入NFT ID';
  const inputMode = state.adminIdQueryType === 'name' ? 'text' : 'numeric';
  return `
    <div class="admin-id-controls">
      ${renderNftLookupControl('admin-id-input', state.adminIdQuery, state.adminIdQueryType, placeholder, 'set-admin-query-type-select', false, inputMode)}
      <div class="admin-action-row">
        <button class="sheet-button" type="button" data-action="query-admin-self">查自己</button>
        <button class="sheet-button" type="button" data-action="query-admin-id" data-input="admin-id-input">查询</button>
        <button class="sheet-button primary" type="button" data-action="admin-list-add" data-list="adminIds" data-input="admin-id-input" ${canEditRules(chat) ? '' : 'disabled'}>加入名单</button>
      </div>
    </div>
  `;
}

function renderMemberIdControls(chat) {
  const placeholder = state.memberIdQueryType === 'name' ? '请输入NFT名称' : '请输入NFT ID';
  const inputMode = state.memberIdQueryType === 'name' ? 'text' : 'numeric';
  return `
    <div class="admin-id-controls">
      ${renderNftLookupControl('member-id-input', state.memberIdQuery, state.memberIdQueryType, placeholder, 'set-member-query-type-select', false, inputMode)}
      <div class="admin-action-row">
        <button class="sheet-button" type="button" data-action="query-member-self">查自己</button>
        <button class="sheet-button" type="button" data-action="query-member-id" data-input="member-id-input">查询</button>
        <button class="sheet-button primary" type="button" data-action="admin-list-add" data-list="memberIds" data-input="member-id-input" ${canEditMemberScope(chat) ? '' : 'disabled'}>加入成员</button>
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
  return Object.entries(chat.chatInfo)
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
  const groups = state.chats.filter((chat) => chat.activated);
  return `
    <div class="chat-picker" aria-label="选择群聊">
      ${groups.map((chat) => `<button class="picker-button${chat.groupId === state.activeGroupNumericId ? ' active' : ''}" type="button" data-action="select-chat" data-group-id="${chat.groupId}">${escapeHtml(chat.shortTitle)}</button>`).join('')}
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
  const version = chat.blacklistMode === 'gov' ? chat.govBan.stateVersion : chat.adminBan.stateVersion;
  const placeholder = state.blacklistQueryType === 'address'
    ? '输入地址 0x...'
    : state.nftInputMode === 'name' ? '请输入NFT名称' : '请输入NFT ID';
  const selfLabel = state.blacklistQueryType === 'address' ? '查自己' : '我的';
  return `
    <section class="workspace-band">
      ${renderGroupDetailHeader(chat, '黑名单', `v${version}`)}
      ${renderBlacklistPermissionNotice(chat)}
      <div class="filter-tabs blacklist-query-tabs">
        <button class="filter-tab${state.blacklistQueryType === 'address' ? ' active' : ''}" type="button" data-action="set-blacklist-query-type" data-query-type="address">按地址</button>
        <button class="filter-tab${state.blacklistQueryType === 'nft' ? ' active' : ''}" type="button" data-action="set-blacklist-query-type" data-query-type="nft">按NFT</button>
      </div>
      ${renderBlacklistControls(chat, placeholder, selfLabel)}
      ${state.blacklistQueryResult ? `<div class="query-result">${escapeHtml(state.blacklistQueryResult)}</div>` : ''}
      <div class="tab-content-block">
        ${renderBlacklistRows(chat)}
      </div>
    </section>
  `;
}

function renderBlacklistPermissionNotice(chat) {
  if (chat.blacklistMode === 'gov') {
    return renderPermissionNotice(
      chat.voteWeight > 0,
      `当前地址有 ${chat.voteWeight} ${chat.voteWeightLabel}，可参与治理黑名单投票。`,
      `当前地址没有 ${chat.voteWeightLabel}，只能查看和查询治理黑名单。`,
    );
  }

  if (chat.blacklistMode === 'admin') {
    return renderPermissionNotice(
      canEditAdminBan(chat),
      '当前 defaultGroupId 命中 GroupAdmin 管理员名单，可维护黑名单。',
      '当前 defaultGroupId 不在 GroupAdmin 管理员名单；本页只能查看和查询。',
    );
  }

  return renderPermissionNotice(false, '', '当前群聊未启用黑名单源。');
}

function renderBlacklistControls(chat, placeholder, selfLabel) {
  const listName = state.blacklistQueryType === 'address' ? 'addressBanList' : 'senderIdBanList';
  const addAction = renderBlacklistAddAction(chat, listName, state.blacklistQueryType);
  const countClass = addAction ? 'count-3' : 'count-2';
  const inputMode = state.blacklistQueryType === 'nft' && state.nftInputMode === 'id' ? 'numeric' : 'text';
  const queryField = state.blacklistQueryType === 'nft'
    ? renderNftLookupControl('blacklist-query-input', state.blacklistQuery, state.nftInputMode, placeholder, 'set-nft-input-mode-select', false, inputMode)
    : `<input id="blacklist-query-input" value="${escapeHtml(state.blacklistQuery)}" inputmode="${inputMode}" placeholder="${placeholder}">`;
  return `
    <div class="blacklist-controls ${countClass}">
      ${queryField}
      <div class="blacklist-action-row ${countClass}">
        <button class="sheet-button" type="button" data-action="query-self">${selfLabel}</button>
        <button class="sheet-button primary" type="button" data-action="query-blacklist" data-input="blacklist-query-input">查询</button>
        ${addAction}
      </div>
    </div>
  `;
}

function renderBlacklistAddAction(chat, listName, targetType) {
  if (chat.blacklistMode === 'gov') {
    return `<button class="sheet-button primary" type="button" data-action="gov-add-target" data-target-type="${targetType}" data-input="blacklist-query-input" ${chat.voteWeight > 0 ? '' : 'disabled'}>加入黑名单</button>`;
  }
  if (chat.blacklistMode !== 'admin') return '';
  return `<button class="sheet-button primary" type="button" data-action="admin-list-add" data-list="${listName}" data-input="blacklist-query-input" ${canEditAdminBan(chat) ? '' : 'disabled'}>加入黑名单</button>`;
}

function blacklistRows(chat) {
  if (chat.blacklistMode === 'gov') {
    return [
      ...chat.govBan.addressTargets.map((item) => {
        const banned = govAddressBanned(chat, item.target);
        return {
          type: 'address',
          target: item.target,
          label: item.target,
          status: banned ? '已拉黑' : '未拉黑',
          statusClass: banned ? 'pill-bad' : 'pill-ok',
          detail: `支持 ${item.support} / 反对 ${item.oppose} · ${govMyVoteDetail(item)}`,
        };
      }),
      ...chat.govBan.senderIdTargets.map((item) => {
        const banned = govSenderIdBanned(chat, item.target);
        return {
          type: 'nft',
          target: item.target,
          label: blacklistNftLabel(item.target),
          status: banned ? '已拉黑' : '未拉黑',
          statusClass: banned ? 'pill-bad' : 'pill-ok',
          detail: `NFT #${item.target} · 支持 ${item.support} / 反对 ${item.oppose} · ${govMyVoteDetail(item)}`,
        };
      }),
    ];
  }

  return [
    ...adminBanRowsFromPage(chat, 'address', 0, chat.adminBan.addressBanList.length),
    ...adminBanRowsFromPage(chat, 'nft', 0, chat.adminBan.senderIdBanList.length),
  ];
}

function renderBlacklistRows(chat) {
  if (chat.blacklistMode === 'admin') return renderAdminBlacklistRows(chat);

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

function renderAdminBlacklistRows(chat) {
  const targetType = state.blacklistQueryType;
  const rows = adminBanTargets(chat, targetType);
  const listLabel = targetType === 'address' ? '地址列表' : 'NFT列表';
  if (!rows.length) return `<div class="empty-state">暂无${listLabel}记录</div>`;
  const totalPages = Math.max(1, Math.ceil(rows.length / blacklistPageSize));
  const page = Math.min(Math.max(1, state.blacklistPage), totalPages);
  const start = (page - 1) * blacklistPageSize;
  const items = adminBanRowsFromPage(chat, targetType, start, blacklistPageSize).map((row) => renderBlacklistRow(chat, row)).join('');
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
        <small>${escapeHtml(row.detail)}</small>
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
        <button type="button" data-action="open-gov-voters" data-target-type="${row.type}" data-target="${escapeHtml(row.target)}">投票列表</button>
      </div>
    `;
  }

  const listName = row.type === 'address' ? 'addressBanList' : 'senderIdBanList';
  const disabled = canEditAdminBan(chat) ? '' : 'disabled';
  return `
    <div class="blacklist-menu">
      <button type="button" data-action="admin-list-remove" data-list="${listName}" data-value="${escapeHtml(row.target)}" ${disabled}>移出黑名单</button>
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

function renderMessages() {
  const active = activeChatEntry();
  const groupId = state.activeGroupId;
  const chat = active ? active.item : null;
  const allMessages = messagesForChat(groupId);
  const visibleMessages = allMessages.filter((message) => !shouldHideMessage(chat, message));
  const groupTools = chat ? renderChatTools(chat) : '';
  const roundLabel = chat ? `<div class="round-divider">Round ${chat.round}</div>` : '';
  const items = visibleMessages.map((message) => renderMessage(chat, message)).join('');
  const emptyState = '<div class="empty-state">暂无消息</div>';
  document.getElementById('message-list').innerHTML = `${groupTools}${roundLabel}${items || emptyState}`;
}

function renderChatTools(chat) {
  const menu = state.activeGroupMenuId === chat.groupId ? `
    <div class="chat-menu">
      ${renderChatMenuButtons(chat)}
    </div>
  ` : '';
  return `
    <div class="chat-tools">
      <strong>${escapeHtml(chatDisplayName(chat))}</strong>
      <button class="chat-menu-button" type="button" data-action="toggle-chat-menu" data-group-id="${chat.groupId}" aria-label="群聊菜单">...</button>
      ${menu}
    </div>
  `;
}

function renderChatMenuButtons(chat) {
  const pinned = isPinnedConversation(chat.groupId);
  return `
    <button type="button" data-action="toggle-conversation-pin" data-group-id="${chat.groupId}">${pinned ? '取消置顶' : '置顶'}</button>
    <button type="button" data-action="open-preferences" data-group-id="${chat.groupId}">偏好</button>
    <button type="button" data-action="open-members" data-group-id="${chat.groupId}">群成员</button>
    <button type="button" data-action="open-blacklist" data-group-id="${chat.groupId}">黑名单</button>
    <button type="button" data-action="open-admins" data-group-id="${chat.groupId}">管理员</button>
    <button type="button" data-action="open-settings" data-group-id="${chat.groupId}">群设置</button>
  `;
}

function renderGroupDetailHeader(chat, title, meta = '') {
  return `
    <div class="screen-heading group-detail-heading">
      <div class="group-detail-title">
        <h1>${escapeHtml(title)}</h1>
        ${chat ? `<span>${escapeHtml(chatDisplayName(chat))}</span>` : ''}
      </div>
      ${meta ? `<span class="pill ${groupDetailMetaClass(chat, meta)}">${escapeHtml(meta)}</span>` : ''}
    </div>
  `;
}

function groupDetailMetaClass(chat, meta) {
  if (meta === '只读') return 'pill-warn';
  if (chat && meta === chat.role) return manageableRole(chat) ? 'pill-ok' : 'pill-warn';
  return 'pill-ok';
}

function renderPermissionNotice(allowed, allowedText, bannedText) {
  return `
    <div class="notice-row permission-row ${allowed ? 'permission-ok' : 'permission-warn'}">
      ${escapeHtml(allowed ? allowedText : bannedText)}
    </div>
  `;
}

function renderCannotPost(chat, status) {
  return `
    <div class="cannot-post">
      <strong>无法发言 · ${escapeHtml(status.reasonCode)}</strong>
      <span>${escapeHtml(postBanReason(chat, status))}</span>
    </div>
  `;
}

function postBanReason(chat, status) {
  if (!chat) return '还没有选中群聊。';
  if (status.reasonCode === 'ChatNotActivated') return '这个群聊还没有激活，链上暂时没有可用的发言规则。';
  if (status.reasonCode === 'PostingNotAllowed') return '这个群聊已激活，但 postingAllowed=false，当前不能发消息。';
  if (status.reasonCode === 'SenderAddressNotSenderIdOwner') return '当前钱包不是 defaultGroupId 的 owner，合约会返回 SenderAddressNotSenderIdOwner。';
  if (status.reasonCode === 'BanRejected') return '发言资格已通过，但 banSource 拦截了当前地址或当前 NFT。请检查黑名单。';
  if (status.reasonCode === 'ScopeRejected') return scopeSourceReason(chat);
  return '当前地址暂时不满足这个群聊的发言条件。';
}

function scopeSourceReason(chat) {
  const source = chat.chatInfo?.scopeSource || chat.params?.scopeSource || 'scopeSource';
  const messages = {
    TokenMainManager: 'scopeSource 会检查当前地址是否属于这个代币的大群范围；当前地址不在范围内。',
    TokenGovManager: 'scopeSource 会检查当前地址是否有这个代币治理群的发言资格；当前地址不满足。',
    TokenActionMainManager: 'scopeSource 会检查当前地址是否属于这个行动群的参与范围；当前地址不在范围内。',
    TokenActionGovManager: 'scopeSource 会检查当前地址是否有这个行动治理群的发言资格；当前地址不满足。',
    GroupMemberScope: 'scopeSource 会检查当前 senderId 是否在 GroupMemberScope 成员 NFT 名单；当前 NFT 不在名单内。',
    GroupJoinScopeSource: 'scopeSource 会先检查 GroupMemberScope 成员 NFT，再检查当前地址是否在该链群下参与至少一个代币社区行动；两者都不满足。',
  };
  return messages[source] || `${source} 判断当前地址没有这个群聊的发言资格。`;
}

function renderMessage(chat, message) {
  const mine = message.mine ? ' mine' : '';
  const banned = messageSenderBanned(chat, message);
  const bannedClass = banned ? ' banned' : '';
  const bannedBadge = banned ? '<span class="message-ban-badge">黑名单</span>' : '';
  const profile = nftProfile(message.senderId);
  const quoted = message.quotedMessageId ? messageById(message.quotedMessageId, message.groupId) : null;
  const quote = quoted ? `<div class="quote-preview">引用 ${escapeHtml(nftProfile(quoted.senderId).name)}</div>` : '';
  const content = renderMessageContent(message);
  const avatarMenu = state.activeAvatarMenuKey === messageMenuKey(message)
    ? `<div class="message-actions avatar-actions">${renderSenderBanAction(chat, message)}</div>`
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
    <article class="message-row${mine}${bannedClass}" data-action="select-message" data-message-id="${message.messageId}">
      <div class="avatar" data-action="toggle-avatar-menu" data-long-press-mention data-group-id="${message.groupId}" data-message-id="${message.messageId}" data-sender-id="${message.senderId || currentDefaultGroupId()}">${escapeHtml(profile.badge)}</div>
      <div class="message-body">
        <div class="message-meta">${escapeHtml(profile.name)}${bannedBadge}</div>
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

function renderSenderBanAction(chat, message) {
  if (!canShowAvatarBanMenu(chat, message)) return '';
  return `<button type="button" data-action="add-sender-ban" data-group-id="${message.groupId}" data-message-id="${message.messageId}">拉黑sender</button>`;
}

function canShowAvatarBanMenu(chat, message) {
  return Boolean(chat && !message.mine && message.senderAddress && message.senderId && canEditAdminBan(chat));
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
  return renderGroupSettings();
}

function renderGroupPreferences() {
  const chat = activeChat();
  if (!chat) return '<div class="empty-state">请选择群聊</div>';
  return `
    <section class="workspace-band">
      ${renderGroupDetailHeader(chat, '偏好', '本机')}
    </section>
    ${renderMessagePreferenceControl(chat)}
  `;
}

function renderGroupMembers() {
  const chat = activeChat();
  if (!chat) return '<div class="empty-state">请选择群聊</div>';
  const hasMemberScope = Boolean(chat.groupMemberScope);
  const canEdit = canEditMemberScope(chat);
  const memberScope = groupMemberScopeState(chat);
  const permission = hasMemberScope
    ? renderPermissionNotice(
      canEdit,
      '有权限：当前 defaultGroupId 命中 GroupAdmin 管理员名单，可维护成员 NFT。',
      '无权限：当前 defaultGroupId 不在 GroupAdmin 管理员名单；本页只能查看和查询。',
    )
    : renderPermissionNotice(false, '', '当前群聊不使用 GroupMemberScope；群成员资格由 scopeSource 规则决定。');

  return `
    <section class="workspace-band">
      ${renderGroupDetailHeader(chat, '群成员', hasMemberScope ? `v${memberScope.stateVersion}` : '只读')}
      ${permission}
      ${hasMemberScope ? `
        ${renderMemberIdControls(chat)}
        ${state.memberIdQueryResult ? `<div class="query-result">${escapeHtml(state.memberIdQueryResult)}</div>` : ''}
        ${renderAdminList(memberScope.memberIds, 'memberIds', canEdit)}
      ` : `<div class="rule-table">${renderRuleRows(chat)}</div>`}
    </section>
  `;
}

function renderGroupAdmins() {
  const chat = activeChat();
  if (!chat) return '<div class="empty-state">请选择群聊</div>';
  const hasGroupAdmin = Boolean(chat.groupAdmin);
  const canEdit = hasGroupAdmin && canEditRules(chat);
  const groupAdmin = groupAdminState(chat);
  const permission = hasGroupAdmin
    ? renderPermissionNotice(
      canEdit,
      '有权限：当前身份是 owner/delegate，可维护 GroupAdmin 管理员 NFT。',
      '无权限：管理员名单只允许当前 owner 或有效 delegate 修改；本页只能查看和查询。',
    )
    : renderPermissionNotice(false, '', '当前群聊不使用 GroupAdmin 管理员名单。');

  return `
    <section class="workspace-band">
      ${renderGroupDetailHeader(chat, '管理员', hasGroupAdmin ? `v${groupAdmin.stateVersion}` : '只读')}
      ${permission}
      ${hasGroupAdmin ? `
        ${renderAdminIdControls(chat)}
        ${state.adminIdQueryResult ? `<div class="query-result">${escapeHtml(state.adminIdQueryResult)}</div>` : ''}
        ${renderAdminList(groupAdminIds(chat), 'adminIds', canEdit)}
      ` : `<div class="rule-table">${renderRuleRows(chat)}</div>`}
    </section>
  `;
}

function renderGroupStatusCard(chat) {
  const status = chatStatus(chat);
  const statusRows = status.allowed ? '' : `
      <dt>无法发言原因</dt>
      <dd>${escapeHtml(postBanReason(chat, status))}</dd>
  `;
  const groupAbout = chat ? `
      <dt>群聊</dt>
      <dd>${escapeHtml(chatDisplayName(chat))}</dd>
      <dt>groupId</dt>
      <dd>#${chat.groupId}</dd>
      <dt>类型</dt>
      <dd>${escapeHtml(chat.typeLabel)}</dd>
      <dt>activated</dt>
      <dd>${chat.activated ? 'true' : 'false'}</dd>
      <dt>postingAllowed</dt>
      <dd>${chat.postingAllowed ? 'true' : 'false'}</dd>
  ` : `
      <dt>入口</dt>
      <dd>底导航 爱聊 / LOVE20 Chat</dd>
  `;
  return `
    <dl class="status-card">
      ${groupAbout}
      <dt>当前 defaultGroupId</dt>
      <dd>defaultGroupId #${currentDefaultGroupId()}</dd>
      <dt>canPost</dt>
      <dd>${escapeHtml(status.reasonCode)}</dd>
      ${statusRows}
    </dl>
  `;
}

function renderMessagePreferenceControl(chat) {
  const showBanned = showBlacklistedMessages(chat.groupId);
  return `
    <section class="workspace-band message-preference-panel">
      <div class="card-topline">
        <strong>本机阅读偏好</strong>
        <span>localStorage</span>
      </div>
      <div class="field-row activation-choice-row">
        <label>显示黑名单消息</label>
        <div class="choice-group">
          <button class="picker-button${showBanned ? ' active' : ''}" type="button" data-action="set-show-blacklisted" data-group-id="${chat.groupId}" data-value="true">开启</button>
          <button class="picker-button${showBanned ? '' : ' active'}" type="button" data-action="set-show-blacklisted" data-group-id="${chat.groupId}" data-value="false">关闭</button>
        </div>
      </div>
    </section>
  `;
}

function renderComposerChips() {
  const chips = [];
  const quotedMessageId = activeQuotedMessageId();
  if (quotedMessageId) {
    const quoted = messageById(quotedMessageId, state.activeGroupId);
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

function chatById(groupId) {
  return state.chats.find((chat) => chat.groupId === Number(groupId));
}

function setBottomTab(tab) {
  state.bottomTab = tab;
  if (tab === 'chat') state.view = 'inbox';
  state.pageReturnStack = [];
  state.activeConversationMenuGroupId = null;
  render();
}

function setView(view) {
  state.pageReturnStack = [];
  state.view = view;
  state.activeConversationMenuGroupId = null;
  render();
}

function goBack() {
  const previous = state.pageReturnStack.pop();
  if (previous) {
    state.bottomTab = previous.bottomTab;
    state.view = previous.view;
    state.activeGroupId = previous.activeGroupId;
    state.activeGroupNumericId = previous.activeGroupNumericId;
    state.activeGroupMenuId = null;
    state.activeConversationMenuGroupId = null;
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
  state.activeConversationMenuGroupId = null;
  render();
}

function rememberPageReturn() {
  state.pageReturnStack.push({
    bottomTab: state.bottomTab,
    view: state.view,
    activeGroupId: state.activeGroupId,
    activeGroupNumericId: state.activeGroupNumericId,
  });
}

function selectChat(groupId) {
  const chat = chatById(groupId);
  if (!chat) return;
  state.activeGroupNumericId = chat.groupId;
  state.activeGroupId = String(chat.groupId);
  state.blacklistQueryResult = '';
  state.blacklistPage = 1;
  state.activeBlacklistMenuKey = null;
  state.adminIdQuery = '';
  state.adminIdQueryResult = '';
  state.activeAvatarMenuKey = null;
  state.activeConversationMenuGroupId = null;
  if (state.syncHint && state.syncHint.startsWith('已选择 groupId #')) state.syncHint = '';
  render();
}

function openActivation(groupId) {
  if (groupId) {
    openActivationForm(groupId);
    return;
  }
  state.activeConversationMenuGroupId = null;
  state.view = 'activate';
  render();
}

function openActivationForm(groupId) {
  const chat = chatById(groupId);
  if (chat) {
    state.activeGroupNumericId = chat.groupId;
    state.activeGroupId = String(chat.groupId);
    state.activeToken = chat.token;
    state.activationType = activationTypeForChat(chat);
  }
  state.activeConversationMenuGroupId = null;
  state.view = 'activate-form';
  render();
}

function openChat(groupId) {
  state.activeGroupId = String(groupId);
  const chat = chatById(groupId);
  if (chat) state.activeGroupNumericId = chat.groupId;
  markChatRead(groupId);
  state.view = 'chat';
  state.activeMenuMessageId = null;
  state.activeAvatarMenuKey = null;
  state.activeConversationMenuGroupId = null;
  state.activeGroupMenuId = null;
  state.pageReturnStack = [];
  render();
}

function toggleConversationPin(groupId) {
  const numericGroupId = Number(groupId);
  if (!chatById(numericGroupId)) return;
  const pinnedGroupIds = (state.pinnedGroupIds || []).map(Number);
  const isPinned = pinnedGroupIds.includes(numericGroupId);
  state.pinnedGroupIds = isPinned
    ? pinnedGroupIds.filter((id) => id !== numericGroupId)
    : [numericGroupId, ...pinnedGroupIds];
  state.activeConversationMenuGroupId = null;
  state.activeGroupMenuId = null;
  suppressConversationClick = false;
  state.syncHint = isPinned ? `已取消置顶 groupId #${numericGroupId}` : `已置顶 groupId #${numericGroupId}`;
  render();
}

function openManage(groupId) {
  openSettings(groupId);
}

function openGroupDetailView(groupId, view) {
  const chat = chatById(groupId);
  state.activeGroupMenuId = null;
  if (!chat) return;
  if (state.bottomTab === 'chat' && state.view === view && state.activeGroupNumericId === chat.groupId) {
    render();
    return;
  }
  rememberPageReturn();
  selectChat(chat.groupId);
  state.view = view;
  render();
}

function openPreferences(groupId) {
  openGroupDetailView(groupId, 'preferences');
}

function openMembers(groupId) {
  openGroupDetailView(groupId, 'members');
}

function openAdmins(groupId) {
  openGroupDetailView(groupId, 'admins');
}

function openSettings(groupId) {
  openGroupDetailView(groupId, 'settings');
}

function openBlacklist(groupId) {
  state.activeBlacklistMenuKey = null;
  openGroupDetailView(groupId, 'blacklist');
}

function openDetails(groupId) {
  openSettings(groupId);
}

function toggleChatMenu(groupId) {
  const numericGroupId = Number(groupId);
  state.activeGroupMenuId = state.activeGroupMenuId === numericGroupId ? null : numericGroupId;
  render();
}

function setShowBlacklistedMessagesPreference(groupId, value) {
  const showBanned = value === 'true';
  const saved = setShowBlacklistedMessages(groupId, showBanned);
  state.activeGroupMenuId = null;
  state.activeMenuMessageId = null;
  state.activeAvatarMenuKey = null;
  if (saved) state.syncHint = showBanned ? '已在本机显示黑名单消息。' : '已在本机隐藏黑名单消息。';
  render();
}

function setBlacklistQueryType(queryType) {
  state.blacklistQueryType = queryType === 'nft' ? 'nft' : 'address';
  state.blacklistQuery = '';
  state.blacklistQueryResult = '';
  state.blacklistPage = 1;
  state.activeBlacklistMenuKey = null;
  render();
}

function setBlacklistPage(page) {
  state.blacklistPage = Math.max(1, Number(page) || 1);
  state.activeBlacklistMenuKey = null;
  render();
}

function toggleBlacklistMenu(targetType, target) {
  const key = blacklistRowKey(targetType, target);
  state.activeBlacklistMenuKey = state.activeBlacklistMenuKey === key ? null : key;
  render();
}

function nextManagedGroupId() {
  return state.chats.reduce((maxId, chat) => Math.max(maxId, Number(chat.groupId) || 0), 0) + 1;
}

function syncManagedGroupId(chat, nextGroupId) {
  const prevGroupId = Number(chat.groupId);
  if (prevGroupId === nextGroupId) return;

  chat.groupId = nextGroupId;

  if (chat.type === 'action' || chat.type === 'action-gov') {
    const action = state.actions.find((item) => item.token === chat.token && item.actionId === chat.actionId);
    if (action) {
      if (chat.type === 'action') action.actionGroupId = nextGroupId;
      else action.actionGovGroupId = nextGroupId;
    }
  }

  if (state.activeGroupNumericId === prevGroupId) state.activeGroupNumericId = nextGroupId;
  if (String(state.activeGroupId) === String(prevGroupId)) state.activeGroupId = String(nextGroupId);
  if (state.activeGroupMenuId === prevGroupId) state.activeGroupMenuId = nextGroupId;

  state.pageReturnStack.forEach((entry) => {
    if (entry.activeGroupNumericId === prevGroupId) entry.activeGroupNumericId = nextGroupId;
    if (String(entry.activeGroupId) === String(prevGroupId)) entry.activeGroupId = String(nextGroupId);
  });

  if (state.activationDrafts[String(prevGroupId)]) {
    state.activationDrafts[String(nextGroupId)] = state.activationDrafts[String(prevGroupId)];
    delete state.activationDrafts[String(prevGroupId)];
  }

  if (state.quotedMessagesByGroupId[String(prevGroupId)] !== undefined) {
    state.quotedMessagesByGroupId[String(nextGroupId)] = state.quotedMessagesByGroupId[String(prevGroupId)];
    delete state.quotedMessagesByGroupId[String(prevGroupId)];
  }

  state.messages.forEach((message) => {
    if (String(message.groupId) === String(prevGroupId)) {
      message.groupId = String(nextGroupId);
    }
  });
}

function activateChat(groupId) {
  const chat = chatById(groupId);
  if (!chat || chat.activated) return;
  const draft = captureActivationDraft(chat);
  const issue = activationIssue(chat, draft);
  if (issue) {
    state.syncHint = issue;
    render();
    return;
  }

  if (chat.model === 'chain-service') {
    chat.chatInfo.scopeSource = draft.scopeSource || 'address(0)';
    chat.chatInfo.banSource = draft.banSource || 'address(0)';
    chat.chatInfo.beforePostPlugin = draft.beforePostPlugin || 'address(0)';
    chat.chatInfo.afterPostPlugin = draft.afterPostPlugin || 'address(0)';
    chat.chatInfo.delegateId = resolveOptionalKnownNftInput(draft.delegateId, state.nftInputMode);
    chat.params = {
      groupId: String(chat.groupId),
      scopeSource: chat.chatInfo.scopeSource,
      banSource: chat.chatInfo.banSource,
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
    syncManagedGroupId(chat, nextManagedGroupId());
  }

  chat.activated = true;
  chat.postingAllowed = true;
  chat.lastMessageId = 0;
  refreshManualMemberScopeAllowed(chat);
  state.activeGroupNumericId = chat.groupId;
  state.activeGroupId = String(chat.groupId);
  state.view = 'chat';
  state.syncHint = chat.model === 'chain-service'
    ? `${activationPreview(chat, draft)} 已模拟提交。`
    : `${activationPreview(chat, draft)} => groupId ${chat.groupId} 已模拟提交。`;
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
    if (value !== '0' && Number(value) === chat.groupId) {
      state.delegateQueryResult = '代理 NFT 不能等于当前群聊 NFT。';
      render();
      return;
    }
    chat.chatInfo[slot] = value;
    state.delegateQueryResult = value === '0' ? '已确认：不设置代理。' : `已确认：NFT #${value} · ${nftProfile(value).name}`;
    state.syncHint = `${slot} 已更新为 ${value}`;
    render();
    return;
  }
  if (!value) return;
  chat.chatInfo[slot] = value;
  refreshManualMemberScopeAllowed(chat);
  state.syncHint = `${slot} 已更新为 ${value}`;
  render();
}

function setRuleSlotOption(slot, value) {
  const chat = activeChat();
  const options = ruleSlotOptions(slot);
  if (!chat || !options || !canEditRules(chat)) return;
  if (!options.some((option) => option.value === value)) return;
  chat.chatInfo[slot] = value;
  refreshManualMemberScopeAllowed(chat);
  state.syncHint = `${slot} 已更新为 ${value}`;
  render();
}

function setPostingAllowed(value) {
  const chat = activeChat();
  if (!chat || !canEditRules(chat)) return;
  const postingAllowed = value === 'true';
  chat.postingAllowed = postingAllowed;
  state.syncHint = `postingAllowed 已更新为 ${postingAllowed ? 'true' : 'false'}`;
  render();
}

function addAdminList(listName, inputId) {
  const chat = activeChat();
  const input = document.getElementById(inputId);
  const value = input.value.trim();
  if (!chat || !value) return;
  const isGroupAdminList = listName === 'adminIds';
  const isMemberList = listName === 'memberIds';
  if (!isGroupAdminList && !isMemberList && !canEditAdminBan(chat)) return;
  if (isGroupAdminList && !canEditRules(chat)) return;
  if (isMemberList && !canEditMemberScope(chat)) return;
  if (!isGroupAdminList && !isMemberList && !chat.adminBan) return;
  const nftList = ['adminIds', 'memberIds', 'senderIdBanList'].includes(listName);
  const queryMode = isGroupAdminList ? state.adminIdQueryType : isMemberList ? state.memberIdQueryType : state.nftInputMode;
  const targetValue = nftList ? resolveNftInput(value, queryMode) : value;
  if (!targetValue) {
    if (isGroupAdminList) state.adminIdQueryResult = `未找到 NFT：${value}`;
    else if (isMemberList) state.memberIdQueryResult = `未找到 NFT：${value}`;
    else state.syncHint = `未找到 NFT：${value}`;
    render();
    return;
  }
  if (isGroupAdminList) {
    const groupAdmin = ensureGroupAdminState(chat);
    if (!groupAdmin.adminIds.includes(targetValue)) {
      groupAdmin.adminIds.push(targetValue);
      groupAdmin.stateVersion += 1;
      state.syncHint = `GroupAdmin.setAdmins([...${targetValue}]) 已模拟`;
    }
    state.adminIdQuery = value;
    queryAdminIdValue(value, false);
    render();
    return;
  }
  if (isMemberList) {
    const memberScope = ensureGroupMemberScopeState(chat);
    if (!memberScope.memberIds.includes(targetValue)) {
      memberScope.memberIds.push(targetValue);
      memberScope.stateVersion += 1;
      state.syncHint = `GroupMemberScope.addMemberIds([${targetValue}]) 已模拟`;
    }
    refreshManualMemberScopeAllowed(chat);
    state.memberIdQuery = value;
    queryMemberIdValue(value, false);
    render();
    return;
  }
  if (listName === 'senderIdBanList') {
    if (!chat.adminBan.senderIdBanList.includes(targetValue)) {
      chat.adminBan.senderIdBanList.push(targetValue);
      setAdminBanOperator(chat, 'nft', targetValue);
      chat.adminBan.stateVersion += 1;
      state.syncHint = `banBySenderIds([${targetValue}]) 已模拟`;
    }
    render();
    return;
  }
  if (listName === 'addressBanList') {
    if (!chat.adminBan.addressBanList.includes(targetValue)) {
      chat.adminBan.addressBanList.push(targetValue);
      setAdminBanOperator(chat, 'address', targetValue);
      chat.adminBan.stateVersion += 1;
      state.syncHint = `banBySenderAddresses([${targetValue}]) 已模拟`;
    }
    render();
    return;
  }
  if (!chat.adminBan[listName].includes(targetValue)) {
    chat.adminBan[listName].push(targetValue);
    chat.adminBan.stateVersion += 1;
    state.syncHint = `${listName} 新增 ${targetValue}`;
  }
  render();
}

function setAdminIdQueryType(queryType) {
  state.adminIdQueryType = queryType === 'id' ? 'id' : 'name';
  state.adminIdQuery = '';
  state.adminIdQueryResult = '';
  render();
}

function setMemberIdQueryType(queryType) {
  state.memberIdQueryType = queryType === 'id' ? 'id' : 'name';
  state.memberIdQuery = '';
  state.memberIdQueryResult = '';
  render();
}

function setNftInputMode(mode) {
  state.nftInputMode = mode === 'id' ? 'id' : 'name';
  state.blacklistQuery = '';
  state.blacklistQueryResult = '';
  state.delegateQueryResult = '';
  state.blacklistPage = 1;
  state.activeBlacklistMenuKey = null;
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
  if (!chat || !value) return;
  const groupId = resolveNftInput(value, state.adminIdQueryType);
  if (!groupId) {
    state.adminIdQueryResult = `未找到 NFT：${value}`;
    if (shouldRender) render();
    return;
  }
  const inList = groupAdminIds(chat).includes(groupId);
  const profile = nftProfile(groupId);
  state.adminIdQueryResult = `NFT #${groupId} · ${profile.name} · ${inList ? '已在 GroupAdmin 管理员名单' : '不在 GroupAdmin 管理员名单'}`;
  if (shouldRender) render();
}

function queryMemberSelf() {
  state.memberIdQuery = state.memberIdQueryType === 'name'
    ? nftProfile(currentDefaultGroupId()).name
    : String(currentDefaultGroupId());
  queryMemberIdValue(state.memberIdQuery, true);
}

function queryMemberId(inputId) {
  const input = document.getElementById(inputId);
  state.memberIdQuery = input.value.trim();
  queryMemberIdValue(state.memberIdQuery, true);
}

function queryMemberIdValue(value, shouldRender) {
  const chat = activeChat();
  if (!chat || !value) return;
  const groupId = resolveNftInput(value, state.memberIdQueryType);
  if (!groupId) {
    state.memberIdQueryResult = `未找到 NFT：${value}`;
    if (shouldRender) render();
    return;
  }
  const memberScope = groupMemberScopeState(chat);
  const inList = memberScope.memberIds.includes(groupId);
  const profile = nftProfile(groupId);
  state.memberIdQueryResult = `NFT #${groupId} · ${profile.name} · ${inList ? '已在 GroupMemberScope 成员名单' : '不在 GroupMemberScope 成员名单'}`;
  if (shouldRender) render();
}

function removeAdminList(listName, value) {
  const chat = activeChat();
  if (!chat) return;
  const isGroupAdminList = listName === 'adminIds';
  const isMemberList = listName === 'memberIds';
  if (!isGroupAdminList && !isMemberList && !canEditAdminBan(chat)) return;
  if (isGroupAdminList && !canEditRules(chat)) return;
  if (isMemberList && !canEditMemberScope(chat)) return;
  if (!isGroupAdminList && !isMemberList && !chat.adminBan) return;
  if (isGroupAdminList) {
    const groupAdmin = ensureGroupAdminState(chat);
    if (groupAdmin.adminIds.includes(value)) {
      groupAdmin.adminIds = groupAdmin.adminIds.filter((item) => item !== value);
      groupAdmin.stateVersion += 1;
      state.syncHint = `GroupAdmin.setAdmins([...]) 已模拟，移除 ${value}`;
    }
  } else if (isMemberList) {
    const memberScope = ensureGroupMemberScopeState(chat);
    if (memberScope.memberIds.includes(value)) {
      memberScope.memberIds = memberScope.memberIds.filter((item) => item !== value);
      memberScope.stateVersion += 1;
      state.syncHint = `GroupMemberScope.removeMemberIds([${value}]) 已模拟`;
    }
    refreshManualMemberScopeAllowed(chat);
  } else if (listName === 'senderIdBanList') {
    if (chat.adminBan.senderIdBanList.includes(value)) {
      chat.adminBan.senderIdBanList = chat.adminBan.senderIdBanList.filter((item) => item !== value);
      clearAdminBanOperator(chat, 'nft', value);
      chat.adminBan.stateVersion += 1;
      state.syncHint = `unbanBySenderIds([${value}]) 已模拟`;
    }
  } else if (listName === 'addressBanList') {
    if (chat.adminBan.addressBanList.includes(value)) {
      chat.adminBan.addressBanList = chat.adminBan.addressBanList.filter((item) => item !== value);
      clearAdminBanOperator(chat, 'address', value);
      chat.adminBan.stateVersion += 1;
      state.syncHint = `unbanBySenderAddresses([${value}]) 已模拟`;
    }
  } else {
    chat.adminBan[listName] = chat.adminBan[listName].filter((item) => item !== value);
    chat.adminBan.stateVersion += 1;
    state.syncHint = `${listName} 移除 ${value}`;
  }
  state.activeBlacklistMenuKey = null;
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
  syncGovBanList(chat, targetType, target, item);
  chat.govBan.stateVersion += 1;
  state.activeBlacklistMenuKey = null;
  state.syncHint = `GovVotedBanSource ${targetType} ${target} -> ${stance}`;
  render();
}

function syncGovBanList(chat, targetType, target, item) {
  const shouldList = targetBanned(chat, item);
  const listName = normalizeBlacklistTargetType(targetType) === 'address' ? 'addressBanList' : 'senderIdBanList';
  if (!chat.govBan[listName]) chat.govBan[listName] = [];
  const list = chat.govBan[listName];
  const exists = listName === 'addressBanList'
    ? list.some((entry) => sameAddress(entry, target))
    : list.includes(String(target));
  if (exists === shouldList) return;
  if (shouldList) {
    list.push(String(target));
    return;
  }
  chat.govBan[listName] = listName === 'addressBanList'
    ? list.filter((entry) => !sameAddress(entry, target))
    : list.filter((entry) => entry !== String(target));
}

function addSenderBanFromMessage(messageId, groupId = state.activeGroupId) {
  const message = messageById(messageId, groupId);
  const chat = message && chatById(message.groupId);
  if (!chat || chat.blacklistMode !== 'admin' || !canEditAdminBan(chat)) return;

  const targetSenderId = String(message.senderId);
  const targetAddress = message.senderAddress;
  if (!targetAddress) {
    state.syncHint = `TargetAddressZero：消息 #${messageId} 缺少 senderAddress`;
    render();
    return;
  }
  let changes = 0;
  if (!chat.adminBan.addressBanList.includes(targetAddress)) {
    chat.adminBan.addressBanList.push(targetAddress);
    setAdminBanOperator(chat, 'address', targetAddress);
    changes += 1;
  }
  if (!chat.adminBan.senderIdBanList.includes(targetSenderId)) {
    chat.adminBan.senderIdBanList.push(targetSenderId);
    setAdminBanOperator(chat, 'nft', targetSenderId);
    changes += 1;
  }

  if (changes > 0) {
    chat.adminBan.stateVersion += 1;
    state.syncHint =
      `banBySenders([${targetSenderId}], [${targetAddress}]) 已模拟，消息发送地址=${message.senderAddress}`;
  } else {
    state.syncHint = `sender ${targetAddress} / NFT #${targetSenderId} 已在黑名单`;
  }
  state.activeMenuMessageId = null;
  state.activeAvatarMenuKey = null;
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
      <h2>投票列表</h2>
      <div class="query-row blacklist-query-row">
        <input id="voter-query-input" value="${escapeHtml(state.voterQuery)}" placeholder="输入投票地址">
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
      `).join('') : '<div class="empty-state">暂无投票</div>'}
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
  state.voterQueryResult = `已重算投票地址 ${voter}`;
  state.syncHint = `已发起重算：目标 ${state.activeGovVoterTarget} / 投票地址 ${voter}`;
  renderGovVoterSheet();
}

function revalidateGovVote(targetType, target, inputId) {
  const chat = activeChat();
  const input = document.getElementById(inputId);
  const voter = input.value.trim();
  if (!chat || !voter) return;
  state.revalidateVoter = voter;
  state.syncHint = `已发起重算：目标 ${target} / 投票地址 ${voter}`;
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
    result = isAddress ? govAddressBanned(chat, resolvedValue) : govSenderIdBanned(chat, resolvedValue);
    extra = target ? `support ${target.support} / oppose ${target.oppose} · ${govMyVoteDetail(target)}` : `无投票目标 · ${govMyVoteDetail(null)}`;
  } else {
    const ban = chat.adminBan;
    result = isAddress
      ? ban.addressBanList.some((item) => sameAddress(item, resolvedValue))
      : ban.senderIdBanList.includes(resolvedValue);
    extra = 'AdminBanSource 当前状态';
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

  const visibleMessages = messagesForChat(state.activeGroupId);
  const nextMessageId = visibleMessages.length ? Math.max(...visibleMessages.map((message) => message.messageId)) + 1 : 1;
  const quotedMessageId = activeQuotedMessageId() || 0;
  state.messages.push({
    groupId: state.activeGroupId,
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
  state.quotedMessagesByGroupId[String(state.activeGroupId)] = Number(messageId);
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
  const groupId = Number(senderId);
  if (!state.mentionedSenderIds.includes(groupId) && state.mentionedSenderIds.length < 32) state.mentionedSenderIds.push(groupId);
  insertComposerToken(mentionTokenFor(groupId));
  state.activeMenuMessageId = null;
  render();
}

function selectMessage(messageId) {
  const index = Number(messageId);
  state.activeMenuMessageId = state.activeMenuMessageId === index ? null : index;
  state.activeAvatarMenuKey = null;
  render();
}

function toggleAvatarMenu(messageId, groupId = state.activeGroupId) {
  if (suppressAvatarClick) {
    suppressAvatarClick = false;
    return;
  }

  const message = messageById(messageId, groupId);
  const chat = message && chatById(message.groupId);
  if (!message || !canShowAvatarBanMenu(chat, message)) {
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

function clearConversationPress() {
  if (conversationPressState) clearTimeout(conversationPressState.timer);
  conversationPressState = null;
}

document.addEventListener('pointerdown', (event) => {
  const conversation = event.target.closest('[data-long-press-conversation]');
  if (conversation && event.button === 0 && !event.target.closest('.conversation-menu')) {
    clearConversationPress();
    conversationPressState = {
      pointerId: event.pointerId,
      groupId: conversation.dataset.groupId,
      x: event.clientX,
      y: event.clientY,
      timer: setTimeout(() => {
        const groupId = Number(conversationPressState?.groupId);
        conversationPressState = null;
        if (!groupId) return;
        suppressConversationClick = true;
        state.activeConversationMenuGroupId = state.activeConversationMenuGroupId === groupId ? null : groupId;
        render();
      }, conversationLongPressMs),
    };
  }

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

document.addEventListener('pointermove', (event) => {
  if (!conversationPressState || event.pointerId !== conversationPressState.pointerId) return;
  const moved = Math.abs(event.clientX - conversationPressState.x) > 10 || Math.abs(event.clientY - conversationPressState.y) > 10;
  if (moved) clearConversationPress();
});

document.addEventListener('pointerup', clearAvatarPress);
document.addEventListener('pointercancel', clearAvatarPress);
document.addEventListener('pointerup', clearConversationPress);
document.addEventListener('pointercancel', clearConversationPress);
document.addEventListener('contextmenu', (event) => {
  if (event.target.closest('[data-long-press-mention], [data-long-press-conversation]')) event.preventDefault();
});

document.addEventListener('click', (event) => {
  const target = event.target.closest('[data-action]');
  if (!target) {
    suppressConversationClick = false;
    if (state.activeConversationMenuGroupId !== null) {
      state.activeConversationMenuGroupId = null;
      render();
    }
    return;
  }
  const action = target.dataset.action;
  if (action !== 'toggle-avatar-menu') suppressAvatarClick = false;
  if (['open-chat', 'open-activation', 'open-activation-form'].includes(action) && suppressConversationClick) {
    suppressConversationClick = false;
    return;
  }
  if (action !== 'toggle-conversation-pin') suppressConversationClick = false;
  if (action !== 'toggle-conversation-pin') state.activeConversationMenuGroupId = null;

  if (action === 'set-bottom-tab') setBottomTab(target.dataset.tab);
  if (action === 'go-back') goBack();
  if (action === 'toggle-wallet') {
    state.walletConnected = !state.walletConnected;
    render();
  }
  if (action === 'set-view') setView(target.dataset.view);
  if (action === 'set-blacklist-query-type') setBlacklistQueryType(target.dataset.queryType);
  if (action === 'set-blacklist-page') setBlacklistPage(target.dataset.page);
  if (action === 'toggle-blacklist-menu') toggleBlacklistMenu(target.dataset.targetType, target.dataset.target);
  if (action === 'set-activation-type') {
    state.activationType = target.dataset.activationType;
    render();
  }
  if (action === 'select-chat') selectChat(target.dataset.groupId);
  if (action === 'open-activation') openActivation(target.dataset.groupId);
  if (action === 'open-activation-form') openActivationForm(target.dataset.groupId);
  if (action === 'open-chat') openChat(target.dataset.groupId);
  if (action === 'toggle-conversation-pin') toggleConversationPin(target.dataset.groupId);
  if (action === 'activate-chat') activateChat(target.dataset.groupId);
  if (action === 'set-activation-option') setActivationOption(target.dataset.field, target.dataset.value);
  if (action === 'toggle-chat-menu') toggleChatMenu(target.dataset.groupId);
  if (action === 'set-show-blacklisted') setShowBlacklistedMessagesPreference(target.dataset.groupId, target.dataset.value);
  if (action === 'open-manage') openManage(target.dataset.groupId);
  if (action === 'open-details') openDetails(target.dataset.groupId);
  if (action === 'open-preferences') openPreferences(target.dataset.groupId);
  if (action === 'open-members') openMembers(target.dataset.groupId);
  if (action === 'open-admins') openAdmins(target.dataset.groupId);
  if (action === 'open-settings') openSettings(target.dataset.groupId);
  if (action === 'open-blacklist') openBlacklist(target.dataset.groupId);
  if (action === 'set-rule-slot') setRuleSlot(target.dataset.slot, target.dataset.input);
  if (action === 'set-rule-slot-option') setRuleSlotOption(target.dataset.slot, target.dataset.value);
  if (action === 'set-posting-allowed') setPostingAllowed(target.dataset.value);
  if (action === 'admin-list-add') addAdminList(target.dataset.list, target.dataset.input);
  if (action === 'admin-list-remove') removeAdminList(target.dataset.list, target.dataset.value);
  if (action === 'set-admin-query-type') setAdminIdQueryType(target.dataset.queryType);
  if (action === 'set-member-query-type') setMemberIdQueryType(target.dataset.queryType);
  if (action === 'set-nft-input-mode') setNftInputMode(target.dataset.mode);
  if (action === 'query-admin-self') queryAdminSelf();
  if (action === 'query-admin-id') queryAdminId(target.dataset.input);
  if (action === 'query-member-self') queryMemberSelf();
  if (action === 'query-member-id') queryMemberId(target.dataset.input);
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
  if (action === 'toggle-avatar-menu') toggleAvatarMenu(target.dataset.messageId, target.dataset.groupId);
  if (action === 'select-message') selectMessage(target.dataset.messageId);
  if (action === 'quote-message') quoteMessage(target.dataset.messageId);
  if (action === 'copy-message') copyMessage(target.dataset.messageId);
  if (action === 'add-mention') addMention(target.dataset.senderId);
  if (action === 'add-sender-ban') addSenderBanFromMessage(target.dataset.messageId, target.dataset.groupId);
  if (action === 'clear-quote') {
    clearActiveQuote();
    render();
  }
});

document.addEventListener('change', (event) => {
  const target = event.target;
  if (!(target instanceof HTMLSelectElement)) return;
  if (target.dataset.action === 'set-nft-input-mode-select') setNftInputMode(target.value);
  if (target.dataset.action === 'set-admin-query-type-select') setAdminIdQueryType(target.value);
  if (target.dataset.action === 'set-member-query-type-select') setMemberIdQueryType(target.value);
});

document.getElementById('send-button').addEventListener('click', sendMessage);

render();
