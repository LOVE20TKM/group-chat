# GroupChat Mobile Prototype Implementation Plan（历史归档）

> 归档说明：本文件记录 2026-05-05 早期原型实施计划，仅保留历史上下文，不作为当前实现或验收依据。当前交互以 `docs/superpowers/specs/2026-05-05-group-chat-mobile-prototype-design.md`、`prototype/group-chat/` 和 `prototype/group-chat/smoke-test.mjs` 为准；旧计划里的 `+` 面板、通用 status sheet、桌面三栏和索引切换均已废弃。

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a static, interactive, mobile-first GroupChat prototype based on the current contract/docs, with WeChat-like layout interactions and `interface-test` visual styling.

**Architecture:** Add an isolated static prototype under `prototype/group-chat/`. `index.html` owns semantic markup, `styles.css` owns responsive styling, `app.js` owns mock protocol state and UI interactions, and `smoke-test.mjs` validates deliverable coverage without external dependencies.

**Tech Stack:** Plain HTML, CSS, JavaScript, Node.js `fs`-based smoke test, optional `python3 -m http.server` for local preview.

---

### Task 1: Prototype Scaffold And Smoke Test

**Files:**
- Create: `prototype/group-chat/index.html`
- Create: `prototype/group-chat/styles.css`
- Create: `prototype/group-chat/app.js`
- Create: `prototype/group-chat/smoke-test.mjs`

- [ ] **Step 1: Write the smoke test first**

Create `prototype/group-chat/smoke-test.mjs`:

```js
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

console.log('GroupChat prototype smoke test passed');
```

- [ ] **Step 2: Run test and verify it fails**

Run: `node prototype/group-chat/smoke-test.mjs`

Expected: FAIL with `Missing index.html`.

- [ ] **Step 3: Create minimal files**

Create `index.html` with linked CSS/JS and required markers, `styles.css` with the required tokens, and `app.js` with placeholder state strings.

- [ ] **Step 4: Run test and verify it passes**

Run: `node prototype/group-chat/smoke-test.mjs`

Expected: `GroupChat prototype smoke test passed`.

- [ ] **Step 5: Commit**

```bash
git add prototype/group-chat
git commit -m "test: add group chat prototype smoke test"
```

### Task 2: Mock Protocol State And Rendering

**Files:**
- Modify: `prototype/group-chat/index.html`
- Modify: `prototype/group-chat/app.js`
- Modify: `prototype/group-chat/smoke-test.mjs`

- [ ] **Step 1: Extend smoke test for protocol coverage**

Add checks for UI text and data fields:

```js
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
```

- [ ] **Step 2: Run test and verify it fails**

Run: `node prototype/group-chat/smoke-test.mjs`

Expected: FAIL on the first missing protocol marker.

- [ ] **Step 3: Implement mock data and render functions**

In `app.js`, define mock chats, messages, protocol statuses, and functions:

```js
const statusModes = {
  ok: { allowed: true, reasonCode: '0x00000000', label: '可发言' },
  ScopeRejected: { allowed: false, reasonCode: 'ScopeRejected', label: '无发言资格' },
  DenyRejected: { allowed: false, reasonCode: 'DenyRejected', label: '已被禁言' },
  SenderNotGroupOwner: { allowed: false, reasonCode: 'SenderNotGroupOwner', label: '不是身份 owner' },
};
```

Render chat list, message bubbles, status strip, and status sheet from state.

- [ ] **Step 4: Run test and verify it passes**

Run: `node prototype/group-chat/smoke-test.mjs`

Expected: `GroupChat prototype smoke test passed`.

- [ ] **Step 5: Commit**

```bash
git add prototype/group-chat
git commit -m "feat: render mock group chat protocol state"
```

### Task 3: Interactive Chat Behaviors

**Files:**
- Modify: `prototype/group-chat/index.html`
- Modify: `prototype/group-chat/app.js`
- Modify: `prototype/group-chat/styles.css`
- Modify: `prototype/group-chat/smoke-test.mjs`

- [ ] **Step 1: Extend smoke test for interaction hooks**

Add JS marker checks:

```js
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
```

- [ ] **Step 2: Run test and verify it fails**

Run: `node prototype/group-chat/smoke-test.mjs`

Expected: FAIL on `Missing interaction: openStatusSheet`.

- [ ] **Step 3: Implement interactions**

Implement:

- Top `...` opens status sheet.
- Message click opens action menu.
- Quote sets `quotedMessageIndex`.
- Typing `@姓名` maps to `mentions`.
- Typing `@全部` maps to `mentionAll`.
- Send appends a new mock message and shows `MessagePost` sync hint.
- Status mode buttons simulate `OK`, `ScopeRejected`, `DenyRejected`, `SenderNotGroupOwner`.
- Index mode buttons simulate `messages`, `messagesByRound`, `messagesBySender`, `messagesByMention`, `messagesByMentionAll`.

- [ ] **Step 4: Run test and verify it passes**

Run: `node prototype/group-chat/smoke-test.mjs`

Expected: `GroupChat prototype smoke test passed`.

- [ ] **Step 5: Commit**

```bash
git add prototype/group-chat
git commit -m "feat: add group chat prototype interactions"
```

### Task 4: Responsive Interface-Test Styling

**Files:**
- Modify: `prototype/group-chat/styles.css`
- Modify: `prototype/group-chat/smoke-test.mjs`

- [ ] **Step 1: Extend smoke test for responsive/style markers**

Add CSS marker checks:

```js
const requiredResponsiveCss = [
  '.app-shell',
  '.desktop-chat-list',
  '.desktop-status-panel',
  '.status-sheet',
  'env(safe-area-inset-bottom)',
  'touch-action: manipulation',
];

for (const needle of requiredResponsiveCss) {
  if (!css.includes(needle)) {
    throw new Error(`Missing responsive CSS: ${needle}`);
  }
}
```

- [ ] **Step 2: Run test and verify it fails**

Run: `node prototype/group-chat/smoke-test.mjs`

Expected: FAIL on the first missing CSS marker.

- [ ] **Step 3: Implement final styling**

Implement mobile-first CSS:

- `390px` phone layout as default.
- Chat background gray, bubbles white/secondary.
- Buttons and border radii match `interface-test`.
- Inputs use `font-size: 16px`.
- Desktop `@media (min-width: 900px)` expands left chat list and right status panel.
- No nested page-section cards.

- [ ] **Step 4: Run test and verify it passes**

Run: `node prototype/group-chat/smoke-test.mjs`

Expected: `GroupChat prototype smoke test passed`.

- [ ] **Step 5: Commit**

```bash
git add prototype/group-chat
git commit -m "style: polish mobile group chat prototype"
```

### Task 5: Local Preview Verification

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Document prototype entry**

Add a short README section linking `prototype/group-chat/index.html` and smoke test command.

- [ ] **Step 2: Run smoke test**

Run: `node prototype/group-chat/smoke-test.mjs`

Expected: `GroupChat prototype smoke test passed`.

- [ ] **Step 3: Run local static server**

Run from `prototype/group-chat`:

```bash
python3 -m http.server 8012
```

Expected: server starts on `http://127.0.0.1:8012`.

- [ ] **Step 4: Verify page loads**

Run:

```bash
curl -s http://127.0.0.1:8012/ | grep -q 'GroupChat Prototype'
```

Expected: command exits `0`.

- [ ] **Step 5: Commit**

```bash
git add README.md prototype/group-chat
git commit -m "docs: document group chat prototype"
```
