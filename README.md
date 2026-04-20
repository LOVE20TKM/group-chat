# group-chat

LOVE20 `GroupNFT` 群聊协议仓库。

目标：`1 NFT = 1 Chat`，公开链上、完全去中心化、可扩展。

## 文档

- [需求文档](./docs/requirements.md)
- [实现说明](./docs/implementation-notes.md)
- [插件需求：基于链群NFT持有者指定群管理下的黑名单管理 beforePost](./docs/plugins/group-managed-blacklist-whitelist-before-post.md)
- [插件需求：基于 LOVE20 治理的去中心化黑名单管理 beforePost](./docs/plugins/governance-blacklist-before-post.md)

## 当前状态

- 主接口与主合约已落地
- Foundry 测试已拆分为多文件主题结构
- 当前测试结果：`28 passed`

## 目录

- `src/`
  - `IGroupChat.sol`
  - `GroupChat.sol`
- `test/`
  - `GroupChatLifecycle.t.sol`
  - `GroupChatMeta.t.sol`
  - `GroupChatDelegate.t.sol`
  - `GroupChatMessages.t.sol`
  - `GroupChatPlugins.t.sol`
- `script/`
  - `DeployGroupChat.s.sol`
  - `ScriptBase.sol`

## 本地开发

运行测试：

```bash
forge test
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

- `LOVE20_GROUP_ADDRESS`
- `ORIGIN_BLOCKS`
- `PHASE_BLOCKS`
- `network`

直接 `forge script` 示例：

```bash
LOVE20_GROUP_ADDRESS=0x... \
ORIGIN_BLOCKS=123456 \
PHASE_BLOCKS=30126 \
network=anvil \
forge script script/DeployGroupChat.s.sol:DeployGroupChat --broadcast
```

shell 一键部署：

- 上游 `LOVE20Group` 地址直接使用从 `group` 仓库复制过来的 `script/network/<network>/address.group.params`
- 当前仓库自身参数从 `script/network/<network>/group.chat.params` 读取

```bash
cd script/deploy
source ./one_click_deploy.sh anvil
```

部署结果会写入：

- `script/network/<network>/address.group.chat.params`

当前已补模板网络：

- `anvil`
- `thinkium70001_public`
- `thinkium70001_public_test`
