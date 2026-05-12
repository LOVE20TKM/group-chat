# Manager 总览

Manager 用于去中心化群聊。

接口位于 `src/interfaces/managers/`。公共面分三层：

- `IBaseGroupChatManager`：所有 Manager 共同配置、scope、deny、ERC721 接收面。
- `IBaseTokenGroupChatManager`：token 类共同激活和查询面。
- `IBaseTokenActionGroupChatManager`：action 类共同激活和查询面。

## 共同职责

- 铸造并持有对应 `GroupNFT`。
- 只允许 `Launch.isLOVE20Token(token) == true` 的 LOVE20 协议代币激活 typed chat。
- 通过 `activate(...)` 激活对应类型的 chat。
- 激活时一次性写入 `scopeSource`、`denySource`、`beforePostPlugin`、`afterPostPlugin`。
- 激活时 `delegateId = 0`。
- 作为该 chat 的 `scopeSource`。
- 作为治理黑名单的 `IDenyVoteWeightSource`。
- 为治理黑名单提供 `denyVoteWeightOf(...)` 与 `denyVoteTotalWeightOf(...)`。

## NFT 命名

- 代币社区群：`mgr_token_[symbol]_[xxxxxx]`
- 代币治理者群：`mgr_token_gov_[symbol]_[xxxxxx]`
- 行动群：`mgr_action_[symbol]_[actionId]_[xxxxxx]`
- 行动治理者群：`mgr_action_gov_[symbol]_[actionId]_[xxxxxx]`

其中 `xxxxxx` 为 6 字节随机子串的 12 位十六进制表示。

若上游 `LOVE20Group` 对应的 LOVE20 代币 symbol 以 `Test` 开头，上游 `mint(...)` 会自动补 `Test` 前缀；Manager 会按同一最终名字先做查重和算价，避免名字长度或 mint cost 失配。

## 共同约束

- 构造依赖必须是已部署合约地址。
- 激活后 Manager 不暴露停止发言入口。
- 激活后不得重配规则槽。
- 激活后不得修改 token / action 等发言资格参数；action 类的 `recentRounds` 由构造函数固定。
- 不得暴露通用 `call` / `delegatecall` / `execute` 后门。
- 不可升级。

## 激活接口

函数名统一为 `activate(...)`，但入参按 Manager 类型定义，不做通用群类型模板。

| Manager | 激活入参 | 发言资格 | 黑名单票权 |
| --- | --- | --- | --- |
| [TokenGroupChatManager](./token.md) | `token` | 持币 / 参与代币行动 / 有治理票 | token 治理票 |
| [TokenGovGroupChatManager](./token-gov.md) | `token` | 有 token 治理票 | token 治理票 |
| [TokenActionGroupChatManager](./token-action.md) | `token, actionId` | 近期投票 / 参与行动 | 当前行动轮投票数 |
| [TokenActionGovGroupChatManager](./token-action-gov.md) | `token, actionId` | 近期给行动投票 | 当前行动轮投票数 |

`activate(...)` 返回新铸造并激活的 `groupId`。

## 共同构造参数

```solidity
constructor(
    address groupChat_,
    address denySource_,
    address beforePostPlugin_,
    address afterPostPlugin_,
    address extensionCenter_
)
```

`denySource_`、`beforePostPlugin_`、`afterPostPlugin_` 可为 `address(0)`。非零时必须有代码。

Action 类 Manager 构造函数额外接收 `uint256 recentRounds_`，当前部署配置为 `3`。

## 读取接口

基础 token 类：

- `tokenOfGroup(groupId)`
- `groupIdOfToken(token)`
- `activatedTokensCount()`
- `activatedTokens(offset, limit, reverse)` 返回 `tokens`、`groupIds`

action 类：

- `actionOfGroup(groupId)` 返回 `token`、`actionId`
- `groupIdOfAction(token, actionId)`
- `actionsCountOf(token)`
- `actionsOf(token, offset, limit, reverse)` 返回 `actionIds`、`groupIds`
- `groupIdsOfActions(token, actionIds)`：等长返回；未激活项为 `0`
- `actionsOfGroups(groupIds)`：等长返回 `tokens`、`actionIds`
- `RECENT_ROUNDS()`

## 测试

- `test/GroupChatManager.t.sol`
- `test/GroupChatTypedManagers.t.sol`
