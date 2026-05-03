# Manager 总览

Manager 用于去中心化群聊。

## 共同职责

- 持有对应 `GroupNFT`。
- 通过 `activate(...)` 激活对应类型的 chat。
- 激活时一次性写入 `scopeSource`、`denySource`、`beforePostPlugin`、`afterPostPlugin`。
- 激活时 `delegateGroupId = 0`。
- 作为该 chat 的 `scopeSource`。
- 作为治理黑名单的 `IDenyVoteWeightSource`。

## 共同约束

- 构造依赖必须是已部署合约地址。
- 激活后不得关闭 chat。
- 激活后不得重配规则槽。
- 激活后不得修改 token / action / recentRounds 等发言资格参数。
- 不得暴露通用 `call` / `delegatecall` / `execute` 后门。
- 不可升级。

## 激活接口

函数名统一为 `activate(...)`，但入参按 Manager 类型定义，不做通用群类型模板。

| Manager | 激活入参 | 发言资格 | 黑名单票权 |
| --- | --- | --- | --- |
| [TokenGroupChatManager](./token.md) | `chatGroupId, token` | 持币 / 参与代币行动 / 有治理票 | token 治理票 |
| [TokenGovGroupChatManager](./token-gov.md) | `chatGroupId, token` | 有 token 治理票 | token 治理票 |
| [TokenActionGroupChatManager](./token-action.md) | `chatGroupId, token, actionId, recentRounds` | 近期投票 / 参与行动 | 当前行动轮投票数 |
| [TokenActionGovGroupChatManager](./token-action-gov.md) | `chatGroupId, token, actionId, recentRounds` | 近期给行动投票 | 当前行动轮投票数 |

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

## 读取接口

基础 token 类：

- `tokenOf(chatGroupId)`

action 类：

- `paramsOf(chatGroupId)` 返回 `token`、`actionId`、`recentRounds`

## 测试

- `test/GroupChatManager.t.sol`
- `test/GroupChatTypedManagers.t.sol`
