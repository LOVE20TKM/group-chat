# group-chat

LOVE20 `GroupNFT` 群聊协议仓库。

目标：`1 NFT = 1 Chat`，公开链上、完全去中心化、可扩展。

## 文档

- [文档入口](./docs/requirements.md)
- [核心协议](./docs/spec/core-protocol.md)
- [发言与查询](./docs/spec/posting-query.md)
- [ABI / 事件 / 错误](./docs/spec/abi-events-errors.md)
- [群聊类型](./docs/chat-types.md)
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
- 当前测试结果：`75 passed`

## 目录

- `src/`
  - `IGroupChat.sol`
  - `GroupChat.sol`
  - `managers/`
- `test/`
  - `GroupChatLifecycle.t.sol`
  - `GroupChatMeta.t.sol`
  - `GroupChatDelegate.t.sol`
  - `GroupChatMessages.t.sol`
  - `GroupChatPlugins.t.sol`
  - `GroupChatManager.t.sol`
  - `GroupChatTypedManagers.t.sol`
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
- 模拟 `canPostStatus`、`ruleSlots`、引用、mentions、mentionAll、消息索引和 `MessagePost` 同步提示

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
- `ORIGIN_BLOCKS`
- `PHASE_BLOCKS`
- `GROUP_JOIN_ADDRESS`
- `network`

可选环境变量：

- `LOVE20_GROUP_ADDRESS`
- `GROUP_CHAT_BEFORE_POST_PLUGIN_ADDRESS`
- `GROUP_CHAT_AFTER_POST_PLUGIN_ADDRESS`

直接 `forge script` 示例：

```bash
GROUP_DEFAULTS_ADDRESS=0x... \
EXTENSION_CENTER_ADDRESS=0x... \
GROUP_JOIN_ADDRESS=0x... \
ORIGIN_BLOCKS=123456 \
PHASE_BLOCKS=30126 \
network=anvil \
forge script script/DeployGroupChat.s.sol:DeployGroupChat --broadcast
```

shell 一键部署：

- 上游 `GroupDefaults` 地址使用从 `group` 仓库复制过来的 `script/network/<network>/address.group.defaults.params`
- 上游 `LOVE20Group` 地址可使用从 `group` 仓库复制过来的 `script/network/<network>/address.group.params` 做校验
- 当前仓库自身参数从 `script/network/<network>/group.chat.params` 读取
- `DeployGroupChat` 固定同时部署 `AdminDenySource` 与 `GovVotedDenySource`
- `DeployGroupChat` 固定同时部署 `GroupJoinScopeSource`
- 四个 typed Manager 固定挂本次部署的 `GovVotedDenySource`
- 部署会同时产出 `GroupChat` 与四个 typed Manager

```bash
cd script/deploy
source ./one_click_deploy.sh anvil
```

部署结果会写入：

- `script/network/<network>/address.group.chat.params`
  - `groupChatAddress`
  - `groupJoinScopeSourceAddress`
  - `tokenGroupChatManagerAddress`
  - `tokenGovGroupChatManagerAddress`
  - `tokenActionGovGroupChatManagerAddress`
  - `tokenActionGroupChatManagerAddress`

当前已补模板网络：

- `anvil`
- `thinkium70001_public`
- `thinkium70001_public_test`
