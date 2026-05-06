# 部署说明

## 入口

- `script/DeployGroupChat.s.sol`
- `script/deploy/one_click_deploy.sh`

一键部署：

```bash
cd script/deploy
source ./one_click_deploy.sh <network>
```

## 部署内容

同次部署：

- `GroupChat`
- `AdminDenySource`
- `GovVotedDenySource`
- `GroupJoinScopeSource`
- `TokenGroupChatManager`
- `TokenGovGroupChatManager`
- `TokenActionGroupChatManager`
- `TokenActionGovGroupChatManager`

## 必填参数

- `GROUP_DEFAULTS_ADDRESS`
- `EXTENSION_CENTER_ADDRESS`
- `GROUP_JOIN_ADDRESS`
- `ORIGIN_BLOCKS`
- `PHASE_BLOCKS`：必须大于 `0`
- `network`
- `KEYSTORE_ACCOUNT`：写在 `script/network/<network>/.account`
- `ACCOUNT_ADDRESS`：写在 `script/network/<network>/.account`

## 可选参数

- `LOVE20_GROUP_ADDRESS`：仅用于部署后校验。
- `GROUP_CHAT_BEFORE_POST_PLUGIN_ADDRESS`：Manager 固定 beforePostPlugin。
- `GROUP_CHAT_AFTER_POST_PLUGIN_ADDRESS`：Manager 固定 afterPostPlugin。

`ORIGIN_BLOCKS` 与 `PHASE_BLOCKS` 是部署输入，写在 `script/network/<network>/group.chat.params`。
`thinkium70001_public` 当前按约 24 小时一轮配置为 `PHASE_BLOCKS=30126`；`thinkium70001_public_test` 当前按约 5 分钟一轮配置。

`DeployGroupChat` 固定部署 `AdminDenySource` 与 `GovVotedDenySource`。
`DeployGroupChat` 固定部署 `GroupJoinScopeSource`，构造参数为 `GROUP_JOIN_ADDRESS`。
四个 typed Manager 的 `DENY_SOURCE` 固定为本次部署的 `GovVotedDenySource`。
`AdminDenySource` 作为中心化 / 链群等 owner-admin 管理型 deny source 产物写入地址文件，不自动挂到 typed Manager。
`GroupJoinScopeSource` 作为链群服务者管理型群聊的 scope source 产物写入地址文件，不自动挂到 typed Manager。

## 参数文件

每个网络至少包含：

- `script/network/<network>/network.params`
- `script/network/<network>/.account`
- `script/network/<network>/group.chat.params`
- `script/network/<network>/address.group.params`
- `script/network/<network>/address.group.defaults.params`

`.account` 为本地运行必需文件，必须包含 `KEYSTORE_ACCOUNT` 与 `ACCOUNT_ADDRESS`；可从同目录 `.account.example` 复制生成，真实 `.account` 不提交。

部署结果写入：

- `script/network/<network>/address.group.chat.params`

结果字段只包含当前仓库本次部署产物；上游依赖地址继续从 `address.group.params`、`address.group.defaults.params` 与 `group.chat.params` 读取。

- `adminDenySourceAddress`
- `groupChatDenySourceAddress`
- `groupJoinScopeSourceAddress`
- `groupChatAddress`
- `tokenGroupChatManagerAddress`
- `tokenGovGroupChatManagerAddress`
- `tokenActionGovGroupChatManagerAddress`
- `tokenActionGroupChatManagerAddress`

## Verify

子脚本默认由 `one_click_deploy.sh` 调用；单独运行前必须先执行 `source ./00_init.sh <network>`。

`script/deploy/02_verify.sh` 会验证：

- `GroupChat`
- `AdminDenySource`
- `GovVotedDenySource`
- `GroupJoinScopeSource`
- 四个 typed Manager

Manager 构造参数统一为：

```text
groupChatAddress
groupChatDenySourceAddress
GROUP_CHAT_BEFORE_POST_PLUGIN_ADDRESS
GROUP_CHAT_AFTER_POST_PLUGIN_ADDRESS
EXTENSION_CENTER_ADDRESS
```

## Check

子脚本默认由 `one_click_deploy.sh` 调用；单独运行前必须先执行 `source ./00_init.sh <network>`。
`99_check.sh` 会重新读取 `script/network/<network>/address.group.chat.params`、`address.group.params`、`address.group.defaults.params` 与 `group.chat.params`，并将链上 immutable `originBlocks` / `phaseBlocks` 与配置文件值比对；不一致即视为部署失败，该合约实例不得继续使用。

`script/deploy/99_check.sh` 会检查：

- `GroupChat.GROUP_DEFAULTS`
- `GroupChat.LOVE20_GROUP`
- `originBlocks`
- `phaseBlocks`
- `AdminDenySource` 固定依赖
- `GovVotedDenySource` 固定依赖
- `GroupJoinScopeSource.GROUP_JOIN`
- 四个 Manager 的 `GROUP_CHAT`
- 四个 Manager 的固定规则槽
- 四个 Manager 的 `EXTENSION_CENTER`
- Manager 从 `ExtensionCenter` 读取到的 `STAKE` / `JOIN` / `VOTE` / `SUBMIT`
