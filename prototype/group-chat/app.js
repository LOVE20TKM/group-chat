const state = {
  account: '0x8b...91',
  activeChatId: 1024,
  senderGroupId: 9007,
  indexMode: 'messages',
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
      return `
        <article class="message-row${mine}" data-message-index="${message.messageIndex}">
          <div class="avatar">${message.senderGroupId}</div>
          <div class="message-body">
            <div class="message-meta">#${message.senderGroupId} · message #${message.messageIndex}${mention}${mentionAll}</div>
            <div class="message-bubble${mine}">
              ${quote}
              ${message.content}
            </div>
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
  `;
  document.getElementById('status-strip').innerHTML = statusHtml;
  document.getElementById('desktop-status-content').innerHTML = detailsHtml;
  document.getElementById('status-sheet-content').innerHTML = detailsHtml;
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
}

render();
