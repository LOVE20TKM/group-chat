const state = {
  account: '0x8b...91',
  activeChatId: 1024,
  senderGroupId: 9007,
  indexMode: 'messages',
  quotedMessageIndex: null,
  mentions: [],
  mentionAll: false,
  activeMenuIndex: null,
  syncHint: 'MessagePost 只做发现信号，正文以 message/messages view 回查。',
  chats: [
    {
      groupId: 1024,
      title: '群聊 #1024',
      kind: '代币社区群',
      active: true,
      lastMessageIndex: 79,
      round: 42,
      memberCount: 78,
      canPostStatus: { allowed: true, reasonCode: '0x00000000', label: '可发言' },
      ruleSlots: {
        scopeSource: 'TokenGroupChatManager',
        denySource: 'GovVotedDenySource',
        beforePostPlugin: 'address(0)',
        afterPostPlugin: 'address(0)',
      },
    },
    {
      groupId: 1188,
      title: '群聊 #1188',
      kind: '代币行动群',
      active: true,
      lastMessageIndex: 32,
      round: 42,
      memberCount: 26,
      canPostStatus: { allowed: false, reasonCode: 'ScopeRejected', label: '无发言资格' },
      ruleSlots: {
        scopeSource: 'TokenActionGroupChatManager',
        denySource: 'GovVotedDenySource',
        beforePostPlugin: 'address(0)',
        afterPostPlugin: 'address(0)',
      },
    },
    {
      groupId: 1301,
      title: '群聊 #1301',
      kind: '链群服务者管理型',
      active: true,
      lastMessageIndex: 12,
      round: 42,
      memberCount: 41,
      canPostStatus: { allowed: false, reasonCode: 'DenyRejected', label: '已被禁言' },
      ruleSlots: {
        scopeSource: 'GroupJoinScopeSource',
        denySource: 'AdminDenySource',
        beforePostPlugin: 'address(0)',
        afterPostPlugin: 'address(0)',
      },
    },
  ],
  messages: [
    {
      chatGroupId: 1024,
      senderGroupId: 9001,
      senderAddress: '0x3a...02',
      round: 42,
      messageIndex: 77,
      content: '本轮行动投票窗口已经开始，建议先确认治理票。',
      mentions: [],
      mentionAll: false,
      quotedMessageIndex: 0,
      mine: false,
    },
    {
      chatGroupId: 1024,
      senderGroupId: 9007,
      senderAddress: '0x8b...91',
      round: 42,
      messageIndex: 78,
      content: '@1029 我补充：MessagePost 只是发现信号，正文回查 messages。',
      mentions: [1029],
      mentionAll: false,
      quotedMessageIndex: 77,
      mine: true,
    },
    {
      chatGroupId: 1024,
      senderGroupId: 1029,
      senderAddress: '0x52...13',
      round: 42,
      messageIndex: 79,
      content: 'mentionAll 只记录声明语义，主协议不做许可判断。',
      mentions: [],
      mentionAll: true,
      quotedMessageIndex: 0,
      mine: false,
    },
  ],
};

const statusModes = {
  ok: { allowed: true, reasonCode: '0x00000000', label: '可发言' },
  ScopeRejected: { allowed: false, reasonCode: 'ScopeRejected', label: '无发言资格' },
  DenyRejected: { allowed: false, reasonCode: 'DenyRejected', label: '已被禁言' },
  SenderNotGroupOwner: { allowed: false, reasonCode: 'SenderNotGroupOwner', label: '不是身份 owner' },
};

function activeChat() {
  return state.chats.find((chat) => chat.groupId === state.activeChatId);
}

function renderChatList() {
  const html = state.chats
    .map((chat) => {
      const active = chat.groupId === state.activeChatId ? ' active' : '';
      return `
        <article class="chat-card${active}">
          <strong>${chat.title}</strong>
          <div>${chat.kind}</div>
          <small>round ${chat.round} · last #${chat.lastMessageIndex}</small>
        </article>
      `;
    })
    .join('');
  document.getElementById('desktop-chat-list').innerHTML = html;
}

function renderMessages() {
  const items = state.messages
    .filter((message) => message.chatGroupId === state.activeChatId)
    .map((message) => {
      const mine = message.mine ? ' mine' : '';
      const quote = message.quotedMessageIndex
        ? `<div class="quote-preview">引用 #${message.quotedMessageIndex} · quotedMessageIndex</div>`
        : '';
      const mention = message.mentions.length ? ` · mentions ${message.mentions.join(', ')}` : '';
      const mentionAll = message.mentionAll ? ' · mentionAll' : '';
      const actions = state.activeMenuIndex === message.messageIndex
        ? `
          <div class="message-actions">
            <button type="button" data-action="quote-message" data-message-index="${message.messageIndex}">引用</button>
            <button type="button" data-action="mention-sender" data-sender-group-id="${message.senderGroupId}">@身份</button>
            <button type="button" data-action="copy-index" data-message-index="${message.messageIndex}">复制 #</button>
          </div>
        `
        : '';
      return `
        <article class="message-row${mine}" data-action="select-message" data-message-index="${message.messageIndex}">
          <div class="avatar">${message.senderGroupId}</div>
          <div class="message-body">
            <div class="message-meta">#${message.senderGroupId} · message #${message.messageIndex}${mention}${mentionAll}</div>
            <div class="message-bubble${mine}">
              ${quote}
              ${message.content}
            </div>
            ${actions}
          </div>
        </article>
      `;
    })
    .join('');
  document.getElementById('message-list').innerHTML = `<div class="round-divider">Round ${activeChat().round}</div>${items}`;
}

function renderStatus() {
  const chat = activeChat();
  const status = chat.canPostStatus;
  const statusClass = status.allowed ? 'status-ok' : 'status-bad';
  const statusHtml = `
    <span class="${statusClass}">${status.label}</span>
    <span> · senderGroupId #${state.senderGroupId} · canPostStatus ${status.reasonCode}</span>
  `;
  const detailsHtml = `
    <dl class="status-card">
      <dt>canPostStatus</dt>
      <dd><span class="${statusClass}">${status.label}</span> · ${status.reasonCode}</dd>
      <dt>ruleSlots</dt>
      <dd>scopeSource: ${chat.ruleSlots.scopeSource}<br>denySource: ${chat.ruleSlots.denySource}</dd>
      <dt>senderGroupId</dt>
      <dd>#${state.senderGroupId} · GroupDefaults.defaultGroupIdOf(account)</dd>
      <dt>消息索引</dt>
      <dd>${state.indexMode} / messagesByRound / messagesBySender / messagesByMention / messagesByMentionAll</dd>
      <dt>同步策略</dt>
      <dd>${state.syncHint}</dd>
    </dl>
    <div class="sheet-actions">
      ${Object.keys(statusModes)
        .map((mode) => {
          const active = chat.canPostStatus.reasonCode === statusModes[mode].reasonCode ? ' active' : '';
          return `<button type="button" class="sheet-button${active}" data-action="set-status-mode" data-status-mode="${mode}">${statusModes[mode].label}</button>`;
        })
        .join('')}
    </div>
    <div class="sheet-actions">
      ${['messages', 'messagesByRound', 'messagesBySender', 'messagesByMention', 'messagesByMentionAll']
        .map((mode) => {
          const active = state.indexMode === mode ? ' active' : '';
          return `<button type="button" class="sheet-button${active}" data-action="set-index-mode" data-index-mode="${mode}">${mode}</button>`;
        })
        .join('')}
    </div>
  `;
  document.getElementById('status-strip').innerHTML = statusHtml;
  document.getElementById('desktop-status-content').innerHTML = detailsHtml;
  document.getElementById('status-sheet-content').innerHTML = detailsHtml;
}

function renderComposerChips() {
  const chips = [];
  if (state.quotedMessageIndex) {
    chips.push(`<button class="chip" type="button" data-action="clear-quote">引用 #${state.quotedMessageIndex} ×</button>`);
  }
  for (const mention of state.mentions) {
    chips.push(`<button class="chip" type="button" data-action="remove-mention" data-sender-group-id="${mention}">@${mention} ×</button>`);
  }
  if (state.mentionAll) {
    chips.push('<button class="chip" type="button" data-action="toggle-mention-all">@all ×</button>');
  }
  document.getElementById('composer-chips').innerHTML = chips.join('');
}

function renderMorePanel() {
  document.getElementById('more-panel-content').innerHTML = `
    <div class="panel-grid">
      <button class="panel-button" type="button" data-action="add-mention" data-sender-group-id="1029">@1029</button>
      <button class="panel-button${state.mentionAll ? ' active' : ''}" type="button" data-action="toggle-mention-all">mentionAll</button>
      <button class="panel-button" type="button" data-action="set-index-mode" data-index-mode="messagesByRound">按 round</button>
      <button class="panel-button" type="button" data-action="set-index-mode" data-index-mode="messagesBySender">按 sender</button>
    </div>
  `;
}

function renderHeader() {
  const chat = activeChat();
  document.getElementById('chat-title').textContent = chat.title;
  document.getElementById('chat-subtitle').textContent = `${chat.kind} · ${chat.memberCount}人`;
}

function render() {
  renderHeader();
  renderChatList();
  renderMessages();
  renderStatus();
  renderComposerChips();
  renderMorePanel();
}

render();

function openStatusSheet() {
  document.getElementById('status-sheet').hidden = false;
}

function closeStatusSheet() {
  document.getElementById('status-sheet').hidden = true;
}

function openMorePanel() {
  document.getElementById('more-panel').hidden = false;
}

function closeMorePanel() {
  document.getElementById('more-panel').hidden = true;
}

function quoteMessage(messageIndex) {
  state.quotedMessageIndex = Number(messageIndex);
  state.activeMenuIndex = null;
  render();
}

function addMention(senderGroupId) {
  const groupId = Number(senderGroupId);
  if (!state.mentions.includes(groupId) && state.mentions.length < 32) {
    state.mentions.push(groupId);
  }
  state.activeMenuIndex = null;
  render();
}

function toggleMentionAll() {
  state.mentionAll = !state.mentionAll;
  render();
}

function sendMessage() {
  const input = document.getElementById('composer-input');
  const content = input.value.trim();
  const status = activeChat().canPostStatus;
  if (!content || !status.allowed) {
    state.syncHint = status.allowed ? 'ContentEmpty：空消息会被合约拒绝。' : `${status.reasonCode}：当前身份不能发言。`;
    render();
    return;
  }

  const nextIndex = Math.max(...state.messages.map((message) => message.messageIndex)) + 1;
  state.messages.push({
    chatGroupId: state.activeChatId,
    senderGroupId: state.senderGroupId,
    senderAddress: state.account,
    round: activeChat().round,
    messageIndex: nextIndex,
    content,
    mentions: [...state.mentions],
    mentionAll: state.mentionAll,
    quotedMessageIndex: state.quotedMessageIndex || 0,
    mine: true,
  });
  activeChat().lastMessageIndex = nextIndex;
  state.syncHint = `MessagePost 发现 messageIndex #${nextIndex}，正文已通过 messages 补拉。`;
  state.quotedMessageIndex = null;
  state.mentions = [];
  state.mentionAll = false;
  input.value = '';
  render();
}

function setStatusMode(mode) {
  activeChat().canPostStatus = { ...statusModes[mode] };
  render();
}

function setIndexMode(mode) {
  state.indexMode = mode;
  state.syncHint = `当前查看 ${mode} 索引；事件缺口时按区间补拉。`;
  render();
}

function removeMention(senderGroupId) {
  const groupId = Number(senderGroupId);
  state.mentions = state.mentions.filter((mention) => mention !== groupId);
  render();
}

function selectMessage(messageIndex) {
  const index = Number(messageIndex);
  state.activeMenuIndex = state.activeMenuIndex === index ? null : index;
  render();
}

document.addEventListener('click', (event) => {
  const target = event.target.closest('[data-action]');
  if (!target) return;
  const action = target.dataset.action;

  if (action === 'open-status') openStatusSheet();
  if (action === 'close-status') closeStatusSheet();
  if (action === 'open-more') openMorePanel();
  if (action === 'close-more') closeMorePanel();
  if (action === 'select-message') selectMessage(target.dataset.messageIndex);
  if (action === 'quote-message') quoteMessage(target.dataset.messageIndex);
  if (action === 'mention-sender' || action === 'add-mention') addMention(target.dataset.senderGroupId);
  if (action === 'copy-index') {
    state.syncHint = `已复制 messageIndex #${target.dataset.messageIndex}`;
    render();
  }
  if (action === 'clear-quote') {
    state.quotedMessageIndex = null;
    render();
  }
  if (action === 'remove-mention') removeMention(target.dataset.senderGroupId);
  if (action === 'toggle-mention-all') toggleMentionAll();
  if (action === 'set-status-mode') setStatusMode(target.dataset.statusMode);
  if (action === 'set-index-mode') setIndexMode(target.dataset.indexMode);
});

document.getElementById('send-button').addEventListener('click', sendMessage);
