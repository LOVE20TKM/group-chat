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
  'data-view="chat"',
  'data-action="open-status"',
  'data-action="open-more"',
  'id="message-list"',
  'id="composer-input"',
];

for (const needle of requiredHtml) {
  if (!html.includes(needle)) {
    throw new Error(`Missing HTML marker: ${needle}`);
  }
}

const requiredCss = [
  '--secondary: #4f46e5',
  '@media (min-width: 900px)',
  '.message-bubble.mine',
  'font-size: 16px',
];

for (const needle of requiredCss) {
  if (!css.includes(needle)) {
    throw new Error(`Missing CSS marker: ${needle}`);
  }
}

const requiredJs = [
  'canPostStatus',
  'ScopeRejected',
  'DenyRejected',
  'SenderNotGroupOwner',
  'MessagePost',
  'quotedMessageIndex',
  'mentionAll',
  'messagesByMentionAll',
];

for (const needle of requiredJs) {
  if (!js.includes(needle)) {
    throw new Error(`Missing JS marker: ${needle}`);
  }
}

const requiredProtocolCopy = [
  'canPostStatus',
  'ruleSlots',
  'senderGroupId',
  'scopeSource',
  'denySource',
  'quotedMessageIndex',
  'mentions',
  'mentionAll',
];

for (const needle of requiredProtocolCopy) {
  if (!(html + js).includes(needle)) {
    throw new Error(`Missing protocol copy: ${needle}`);
  }
}

const requiredInteractions = [
  'openStatusSheet',
  'closeStatusSheet',
  'openMorePanel',
  'closeMorePanel',
  'quoteMessage',
  'addMention',
  'toggleMentionAll',
  'sendMessage',
  'setStatusMode',
  'setIndexMode',
];

for (const needle of requiredInteractions) {
  if (!js.includes(needle)) {
    throw new Error(`Missing interaction: ${needle}`);
  }
}

const requiredResponsiveCss = [
  '.app-shell',
  '.desktop-chat-list',
  '.desktop-status-panel',
  '.status-sheet',
  '.more-panel',
  'env(safe-area-inset-bottom)',
  'touch-action: manipulation',
  '100dvh',
  'overscroll-behavior: contain',
];

for (const needle of requiredResponsiveCss) {
  if (!css.includes(needle)) {
    throw new Error(`Missing responsive CSS: ${needle}`);
  }
}

console.log('GroupChat prototype smoke test passed');
