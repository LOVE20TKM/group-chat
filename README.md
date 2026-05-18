# group-chat

LOVE20 `GroupNFT` 群聊协议仓库。

目标：`1 NFT = 1 Chat`，公开链上，支持去中心化与 owner-admin 管理型群聊，可扩展。

## 文档

- [文档入口](./docs/requirements.md)
- [核心协议](./docs/spec/core-protocol.md)
- [发言与查询](./docs/spec/posting-query.md)
- [ABI / 事件 / 错误](./docs/spec/abi-events-errors.md)
- [群聊类型](./docs/chat-types.md)
- [GroupAdmin](./docs/group-admin.md)
- [Manager 总览](./docs/managers/README.md)
- [ScopeSource 总览](./docs/sources/scope/README.md)
- [DenySource 总览](./docs/sources/deny/README.md)
- [实现说明](./docs/implementation-notes.md)
- [部署说明](./docs/deployment.md)
- [测试矩阵](./docs/tests.md)

## 当前状态

- 主接口与主合约已落地
- Typed Manager 已落地
- Foundry 测试已拆分为多文件主题结构

## 目录

- `src/`
  - `interfaces/IGroupChat.sol`
  - `interfaces/`：本仓库协议接口与扩展点
  - `interfaces/external/`：上游合约或通用标准的最小适配接口
  - `interfaces/plugins/`：发帖前后插件接口
  - `interfaces/sources/`：ScopeSource / DenySource 接口
  - `GroupChat.sol`
  - `managers/`
  - `sources/`：ScopeSource / DenySource 实现
- `test/`
  - 详见 [测试矩阵](./docs/tests.md)
- `script/`
  - `DeployGroupChat.s.sol`
  - `ScriptBase.sol`

## 本地开发

运行测试：

```bash
forge test
```

交互原型：

- [GroupChat 手机优先原型](./prototype/group-chat/index.html)
- 交互仿微信聊天布局，样式参考 `interface-test`
- 模拟 `canPost`、`chatInfo` 配置字段、引用、mentionedSenderIds、mentionAll、1-based `messageId`、`MessagePost` 同步提示和通知标记

原型 smoke test：

```bash
node prototype/group-chat/smoke-test.mjs
```

本地预览：

```bash
cd prototype/group-chat
python3 -m http.server 8012
```

## 部署

最小部署脚本：

- [DeployGroupChat.s.sol](./script/DeployGroupChat.s.sol)
- 一键 shell：
  - [00_init.sh](./script/deploy/00_init.sh)
  - [01_deploy_group_chat.sh](./script/deploy/01_deploy_group_chat.sh)
  - [02_verify.sh](./script/deploy/02_verify.sh)
  - [99_check.sh](./script/deploy/99_check.sh)
  - [one_click_deploy.sh](./script/deploy/one_click_deploy.sh)

依赖环境变量：

- `GROUP_DEFAULTS_ADDRESS`
- `EXTENSION_CENTER_ADDRESS`
- `GROUP_JOIN_ADDRESS`
- `GROUP_CHAT_ACTION_RECENT_ROUNDS`（当前配置为 `3`）
- `network`
- `KEYSTORE_ACCOUNT`：写在 `script/network/<network>/.account`
- `ACCOUNT_ADDRESS`：写在 `script/network/<network>/.account`

可选环境变量：

- `GROUP_ADDRESS`
- `GROUP_CHAT_DENY_THRESHOLD_RATIO`：默认 `3000000000000000`（`0.3%`）
- `GROUP_CHAT_MAX_ADMIN_IDS`
- `GROUP_CHAT_BEFORE_POST_PLUGIN_ADDRESS`
- `GROUP_CHAT_AFTER_POST_PLUGIN_ADDRESS`

直接 `forge script` 时也先从网络配置加载参数；round 参数由 `EXTENSION_CENTER_ADDRESS.joinAddress()` 指向的 core Join 合约读取：

```bash
cd script/deploy
source ./00_init.sh thinkium70001_public_test
forge_script ../DeployGroupChat.s.sol:DeployGroupChat --sig "run()"
```

shell 一键部署：

- 上游 `GroupDefaults` 地址使用从 `group` 仓库复制过来的 `script/network/<network>/address.group.defaults.params`
- 上游 `LOVE20Group` 地址可使用从 `group` 仓库复制过来的 `script/network/<network>/address.group.params` 做校验
- 当前仓库自身参数从 `script/network/<network>/group.chat.params` 读取
- `DeployGroupChat` 固定同时部署 `GroupAdmin`、`AdminDenySource` 与 `GovVotedDenySource`
- `DeployGroupChat` 固定同时部署 `GroupMemberScope` 与 `GroupJoinScopeSource`
- 四个 typed Manager 固定挂本次部署的 `GovVotedDenySource`
- 部署会同时产出 `GroupChat` 与四个 typed Manager

```bash
cd script/deploy
source ./one_click_deploy.sh thinkium70001_public_test
```

部署结果字段以 [部署说明](./docs/deployment.md) 为准。

当前已补模板网络：

- `thinkium70001_public`
- `thinkium70001_public_test`
