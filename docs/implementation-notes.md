# GroupChat 实现说明

## 当前实现范围

- 主合约：[GroupChat.sol](../src/GroupChat.sol)
- 主接口：[IGroupChat.sol](../src/interfaces/IGroupChat.sol)
- 测试入口：`test/*.t.sol`

当前已实现并覆盖测试的核心能力：

- `activateChat` / `deactivateChat`
- `chatInfo`
- `metaValue` / `metaEntries`
- `setMeta` / `setMetaBatch`
- `setDelegate` / `delegateOf`
- `setBeforePostPlugin` / `setAfterPostPlugin`
- `post`
- `messages` / `messagesByRound`
- `messagesBySender` / `messageIndexesBySender`
- `senderGroupIds`
- `rounds` / `roundInfo`

## 当前目录

- `src/`
  - 协议接口与实现
- `test/`
  - 按主题拆分的 Foundry 测试
- `script/`
  - 最小部署脚本
- `docs/`
  - 需求与实现说明

## 测试拆分

- `GroupChatLifecycle.t.sol`
  - 构造、激活、关闭、重开
- `GroupChatMeta.t.sol`
  - `meta`、`configVersion`、`ChatActivate` 差异事件
- `GroupChatDelegate.t.sol`
  - `delegate` 与 NFT 转让恢复
- `GroupChatMessages.t.sol`
  - 发消息、分页、round、sender 维度读取
- `GroupChatPlugins.t.sol`
  - `beforePost` / `afterPost` / 重入 / 关闭态插件配置写

## 部署脚本

脚本文件：

- [DeployGroupChat.s.sol](../script/DeployGroupChat.s.sol)
- [00_init.sh](../script/deploy/00_init.sh)
- [01_deploy_group_chat.sh](../script/deploy/01_deploy_group_chat.sh)
- [02_verify.sh](../script/deploy/02_verify.sh)
- [99_check.sh](../script/deploy/99_check.sh)
- [one_click_deploy.sh](../script/deploy/one_click_deploy.sh)

依赖环境变量：

- `LOVE20_GROUP_ADDRESS`
- `ORIGIN_BLOCKS`
- `PHASE_BLOCKS`
- `network`

直接 `forge script` 执行示例：

```bash
LOVE20_GROUP_ADDRESS=0x... \
ORIGIN_BLOCKS=123456 \
PHASE_BLOCKS=30126 \
network=anvil \
forge script script/DeployGroupChat.s.sol:DeployGroupChat --broadcast
```

shell 一键部署时：

- 上游 `LOVE20Group` 地址直接使用从 `group` 仓库复制过来的 `address.group.params`
- `GroupChat` 自身初始化参数从 `group.chat.params` 读取

部署完成后会写入：

- `script/network/<network>/address.group.chat.params`

网络模板：

- [script/network/anvil/group.chat.params](../script/network/anvil/group.chat.params)
- [script/network/anvil/address.group.params](../script/network/anvil/address.group.params)
- [script/network/anvil/network.params](../script/network/anvil/network.params)
- [script/network/anvil/.account.example](../script/network/anvil/.account.example)
- [script/network/thinkium70001_public/group.chat.params](../script/network/thinkium70001_public/group.chat.params)
- [script/network/thinkium70001_public/address.group.params](../script/network/thinkium70001_public/address.group.params)
- [script/network/thinkium70001_public_test/group.chat.params](../script/network/thinkium70001_public_test/group.chat.params)
- [script/network/thinkium70001_public_test/address.group.params](../script/network/thinkium70001_public_test/address.group.params)

## 当前取舍

- 测试基座未依赖外部 `forge-std` 子模块，便于当前仓库独立运行
- 部署脚本使用本地最小 `ScriptBase`
- 事件和分页语义优先对齐 [requirements.md](./requirements.md)
