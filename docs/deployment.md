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
- `GroupAdmin`
- `AdminDenySource`
- `GovVotedDenySource`
- `GroupMemberScope`
- `GroupJoinScopeSource`
- `TokenMainManager`
- `TokenGovManager`
- `TokenActionMainManager`
- `TokenActionGovManager`

## 必填参数

- `GROUP_DEFAULTS_ADDRESS`
- `EXTENSION_CENTER_ADDRESS`
- `GROUP_JOIN_ADDRESS`
- `GROUP_CHAT_ACTION_RECENT_ROUNDS`
- `network`
- `KEYSTORE_ACCOUNT`：写在 `script/network/<network>/.account`
- `ACCOUNT_ADDRESS`：写在 `script/network/<network>/.account`

## 可选参数

- `GROUP_ADDRESS`：仅用于部署后校验。
- `GROUP_CHAT_DENY_THRESHOLD_RATIO`：默认 `3000000000000000`（`3e15`），即 `0.3%`；比例精度为 `1e18 = 100%`。
- `GROUP_CHAT_MAX_ADMIN_IDS`：`GroupAdmin.setAdmins` 单组最多管理员 NFT 数，默认 `20`。
- `GROUP_CHAT_BEFORE_POST_PLUGIN_ADDRESS`：Manager 固定 beforePostPlugin。
- `GROUP_CHAT_AFTER_POST_PLUGIN_ADDRESS`：Manager 固定 afterPostPlugin。

`GroupChat.originBlocks` 与 `GroupChat.phaseBlocks` 部署时直接读取 `EXTENSION_CENTER_ADDRESS.joinAddress()` 指向的 core Join 合约，保证 `currentRound()` 对齐 Join 合约。

`DeployGroupChat` 固定部署 `GroupAdmin`、`AdminDenySource` 与 `GovVotedDenySource`。
`GovVotedDenySource` 构造参数固定写入黑名单生效阈值。
`DeployGroupChat` 固定部署 `GroupMemberScope` 与 `GroupJoinScopeSource`。
四个 typed Manager 的 `DENY_SOURCE_ADDRESS` 固定为本次部署的 `GovVotedDenySource`。
`GroupAdmin` 是 owner-admin 管理型模块共享的管理员名单。
`AdminDenySource` 作为中心化 / 链群等 owner-admin 管理型 deny source 产物写入地址文件，不自动挂到 typed Manager。
`GroupMemberScope` 与 `GroupJoinScopeSource` 作为链群服务者可选 scope source 产物写入地址文件，不自动挂到 typed Manager。

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

- `groupAdminAddress`
- `adminDenySourceAddress`
- `govVotedDenySourceAddress`
- `groupMemberScopeAddress`
- `groupJoinScopeSourceAddress`
- `groupChatAddress`
- `tokenMainManagerAddress`
- `tokenGovManagerAddress`
- `tokenActionGovManagerAddress`
- `tokenActionMainManagerAddress`

## Verify

子脚本默认由 `one_click_deploy.sh` 调用；单独运行前必须先执行 `source ./00_init.sh <network>`。

`script/deploy/02_verify.sh` 会验证：

- `GroupChat`
- `GroupAdmin`
- `AdminDenySource`
- `GovVotedDenySource`
- `GroupMemberScope`
- `GroupJoinScopeSource`
- 四个 typed Manager

基础 token 类 Manager 构造参数为：

```text
groupChatAddress
govVotedDenySourceAddress
GROUP_CHAT_BEFORE_POST_PLUGIN_ADDRESS
GROUP_CHAT_AFTER_POST_PLUGIN_ADDRESS
EXTENSION_CENTER_ADDRESS
```

Action 类 Manager 额外追加：

```text
GROUP_CHAT_ACTION_RECENT_ROUNDS
```

## Check

子脚本默认由 `one_click_deploy.sh` 调用；单独运行前必须先执行 `source ./00_init.sh <network>`。
`99_check.sh` 会重新读取 `script/network/<network>/address.group.chat.params`、`address.group.params`、`address.group.defaults.params` 与 `group.chat.params`，并将链上 immutable `originBlocks` / `phaseBlocks` 与 core Join 合约值比对；不一致即视为部署失败，该合约实例不得继续使用。

`script/deploy/99_check.sh` 会检查：

- `GroupChat.GROUP_DEFAULTS_ADDRESS`
- `GroupChat.GROUP_ADDRESS`
- `originBlocks` 对齐 core Join
- `phaseBlocks` 对齐 core Join
- `GroupChat.currentRound()` 与 core Join 当前轮一致
- `GroupAdmin` 固定依赖
- `GroupAdmin.MAX_ADMIN_IDS`
- `AdminDenySource` 固定依赖
- `GovVotedDenySource` 固定依赖
- `GovVotedDenySource` 禁言阈值
- `GroupMemberScope.GROUP_ADMIN_ADDRESS`
- `GroupJoinScopeSource.GROUP_MEMBER_SCOPE_ADDRESS`
- `GroupJoinScopeSource.GROUP_JOIN_ADDRESS`
- 四个 Manager 的 `GROUP_CHAT_ADDRESS`
- 四个 Manager 的固定规则槽
- 四个 Manager 的 `EXTENSION_CENTER_ADDRESS`
- `ExtensionCenter` 本身及其 `LAUNCH_ADDRESS` / `STAKE_ADDRESS` / `JOIN_ADDRESS` / `VOTE_ADDRESS` 对应合约地址有代码
