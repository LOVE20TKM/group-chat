# GroupChat 实现说明

## 当前实现范围

- 主合约：[GroupChat.sol](../src/GroupChat.sol)
- 默认身份注册表：[GroupDefaults.sol](../../group/src/GroupDefaults.sol)
- 主接口：[IGroupChat.sol](../src/interfaces/IGroupChat.sol)
- 本库接口目录：[interfaces](../src/interfaces)
- 外部适配接口目录：[interfaces/external](../src/interfaces/external)
- 上游注册表接口：[IGroupDefaults.sol](../../group/src/interfaces/IGroupDefaults.sol)
- 测试入口：`test/*.t.sol`

当前本仓库已实现并覆盖测试的核心能力：

- `activateChat` / `setPostingAllowed`
- `chatInfo`
- `metaValue` / `metaEntries`
- `setMeta` / `setMetaBatch`
- `setDelegateId` / `delegateIdOf`
- `setScopeSource` / `setDenySource`
- `setBeforePostPlugin` / `setAfterPostPlugin`
- `ruleSlots`
- `canPost` / `canPostStatus`
- `post`
- `postAsDefaultSender`
- `messagesCount` / `messages`
- `messagesByRoundCount` / `messagesByRound`
- `messagesBySenderCount` / `messagesBySender` / `messageIdsBySender`
- `messagesByMentionCount` / `messagesByMention` / `messageIdsByMention`
- `messagesByMentionAllCount` / `messagesByMentionAll` / `messageIdsByMentionAll`
- `senderIdsCount` / `senderIds`
- `roundsCount` / `rounds` / `roundInfo` / `roundInfos`
- 对上游 `GroupDefaults` 的默认发言身份接入

## 当前目录

- `src/`
  - 协议接口与实现
  - `interfaces/` 放本库协议接口与扩展点
  - `interfaces/external/` 放上游合约或通用标准的最小适配接口
- `test/`
  - 按主题拆分的 Foundry 测试
- `script/`
  - 最小部署脚本
- `docs/`
  - 需求与实现说明

## 测试拆分

测试文件和行为边界见 [tests.md](./tests.md)。

## 部署脚本

部署说明见 [deployment.md](./deployment.md)。本节只保留实现侧索引。

脚本文件：

- [DeployGroupChat.s.sol](../script/DeployGroupChat.s.sol)
- [00_init.sh](../script/deploy/00_init.sh)
- [01_deploy_group_chat.sh](../script/deploy/01_deploy_group_chat.sh)
- [02_verify.sh](../script/deploy/02_verify.sh)
- [99_check.sh](../script/deploy/99_check.sh)
- [one_click_deploy.sh](../script/deploy/one_click_deploy.sh)

依赖环境变量：

- `GROUP_DEFAULTS_ADDRESS`
- `EXTENSION_CENTER_ADDRESS`
- `GROUP_JOIN_ADDRESS`
- `ORIGIN_BLOCKS`
- `PHASE_BLOCKS`（必须大于 `0`）
- `GROUP_CHAT_ACTION_RECENT_ROUNDS`
- `network`

可选变量：

- `LOVE20_GROUP_ADDRESS`
- `GROUP_CHAT_BEFORE_POST_PLUGIN_ADDRESS`
- `GROUP_CHAT_AFTER_POST_PLUGIN_ADDRESS`

直接 `forge script` 时也先从网络配置加载参数，不在命令里写 `ORIGIN_BLOCKS` / `PHASE_BLOCKS` 默认值：

```bash
cd script/deploy
source ./00_init.sh thinkium70001_public_test
forge_script ../DeployGroupChat.s.sol:DeployGroupChat --sig "run()"
```

shell 一键部署时：

- 上游 `GroupDefaults` 已归属 `group` 仓库并单独部署，地址直接使用从 `group` 仓库复制过来的 `address.group.defaults.params`
- 上游 `LOVE20Group` 地址可使用从 `group` 仓库复制过来的 `address.group.params` 做部署后校验
- 上游 `GroupJoin` 地址来自 `extension-group` 仓库，用于部署链群 `scopeSource`
- `DeployGroupChat` 不部署 `GroupDefaults`，只读取 `GROUP_DEFAULTS_ADDRESS`
- `DeployGroupChat` 会同时部署 `GroupChat`、`AdminDenySource`、`GovVotedDenySource`、`GroupJoinScopeSource` 与四个 typed Manager
- `GroupChat` 构造时通过 `GroupDefaults.GROUP_ADDRESS()` 派生 `LOVE20_GROUP_ADDRESS`
- `GroupChat` 自身初始化参数与 Manager 依赖从 `group.chat.params` 读取
- 四个 typed Manager 固定挂本次部署的 `GovVotedDenySource`

部署完成后会写入 `script/network/<network>/address.group.chat.params`，只记录当前仓库本次部署产物；字段定义见 [deployment.md](./deployment.md)。

网络模板：

- [script/network/thinkium70001_public/group.chat.params](../script/network/thinkium70001_public/group.chat.params)
- [script/network/thinkium70001_public/address.group.params](../script/network/thinkium70001_public/address.group.params)
- [script/network/thinkium70001_public/address.group.defaults.params](../script/network/thinkium70001_public/address.group.defaults.params)
- [script/network/thinkium70001_public_test/group.chat.params](../script/network/thinkium70001_public_test/group.chat.params)
- [script/network/thinkium70001_public_test/address.group.params](../script/network/thinkium70001_public_test/address.group.params)
- [script/network/thinkium70001_public_test/address.group.defaults.params](../script/network/thinkium70001_public_test/address.group.defaults.params)

## 当前取舍

- 测试基座未依赖外部 `forge-std` 子模块，便于当前仓库独立运行
- 部署脚本使用本地最小 `ScriptBase`
- 事件语义优先对齐 [abi-events-errors.md](./spec/abi-events-errors.md)
- 分页语义优先对齐 [posting-query.md](./spec/posting-query.md)
- 旧的大需求文档已归档到 [requirements-v0.1-monolith.md](./archive/requirements-v0.1-monolith.md)
