# AI 修改指南

目标：后续改原型时，先改最小文件，少碰无关逻辑。

## 文件边界

- `prototype-data.js`：样例状态、群聊、行动、消息、标签、分页数量。优先改这里。
- `app.js`：渲染函数、交互动作、模拟状态变更。只有新增页面、动作或规则时改这里。
- `styles.css`：视觉 token、布局、组件样式。只做视觉或响应式调整时改这里。
- `index.html`：静态壳和脚本加载顺序。一般不改。
- `smoke-test.mjs`：结构护栏。改数据结构或关键入口后同步更新。

## 常见任务

新增群聊：
1. 在 `prototype-data.js` 的 `initialState.chats` 增加 chat。
2. 若是行动群，同步 `initialState.actions` 的 `actionGroupId/actionGovGroupId`。
3. 若要预置消息，在 `initialState.messages` 增加 `groupId = groupId` 的消息。
4. 运行 `node prototype/group-chat/smoke-test.mjs`。

修改文案或样例协议状态：
1. 先搜 `prototype-data.js`。
2. 找不到再搜 `app.js` 中对应 `render*` 或动作函数。

新增交互入口：
1. 在渲染 HTML 上加 `data-action="..."`。
2. 在 `document.addEventListener('click', ...)` 分发动作。
3. 把状态写入 `state`，最后调用 `render()`。

新增视图：
1. 约定一个 `state.view`。
2. 在 `renderWorkspace()` 增加分支。
3. 新增 `renderXxx()` 和 `openXxx()`。
4. 如需返回，用 `rememberPageReturn()`。

改样式：
1. 先改 `:root` token 或现有组件类。
2. 不新增一次性颜色；按钮、卡片、列表复用现有类。
3. 移动端优先检查 `390px`，再看桌面 `900px+`。

## 数据结构约束

- `groupId` 必须唯一。
- `message.groupId` 必须指向已存在的 `chat.groupId`。
- `action.actionGroupId` 和 `action.actionGovGroupId` 必须指向已存在的 chat。
- `blacklistMode = "gov"` 必须有 `govDeny`。
- `blacklistMode = "admin"` 必须有 `adminDeny`。
- `chatInfo` 至少保留 `scopeSource/denySource/beforePostPlugin/afterPostPlugin/delegateId`。

## 验收

每次改完至少运行：

```sh
node prototype/group-chat/smoke-test.mjs
```

如果改了布局，再用浏览器打开 `prototype/group-chat/index.html`，检查移动端宽度下文本不溢出、输入区不遮挡消息。
