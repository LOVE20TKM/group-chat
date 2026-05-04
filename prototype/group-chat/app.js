const canPostStatus = 'canPostStatus';
const messagesByMentionAll = 'messagesByMentionAll';
const placeholderProtocolWords = [
  'ScopeRejected',
  'DenyRejected',
  'SenderNotGroupOwner',
  'MessagePost',
  'quotedMessageIndex',
  'mentionAll',
  canPostStatus,
  messagesByMentionAll,
];

document.getElementById('message-list').innerHTML = `
  <article class="message-bubble">#9001：本轮行动投票窗口已经开始。</article>
  <article class="message-bubble mine">引用 #77：正文以 messages view 为准。</article>
`;

void placeholderProtocolWords;
