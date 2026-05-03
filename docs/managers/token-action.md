# TokenActionGroupChatManager

代币行动群 Manager。

## 合约

- `src/managers/TokenActionGroupChatManager.sol`

## 激活

```solidity
function activate(
    uint256 chatGroupId,
    address token,
    uint256 actionId,
    uint256 recentRounds
) external;
```

`recentRounds == 0` 必须 revert。

写入：

- `paramsOf[chatGroupId].token = token`
- `paramsOf[chatGroupId].actionId = actionId`
- `paramsOf[chatGroupId].recentRounds = recentRounds`
- `GroupChat.scopeSource = address(this)`
- `GroupChat.denySource = DENY_SOURCE`
- `GroupChat.beforePostPlugin = BEFORE_POST_PLUGIN`
- `GroupChat.afterPostPlugin = AFTER_POST_PLUGIN`
- `delegateGroupId = 0`

## 发言资格

满足任一条件即可发言：

- 最近 `recentRounds` 轮内给该 `actionId` 投过票
- `ILOVE20Join.amountByActionIdByAccount(token, actionId, account) != 0`
- `ExtensionCenter.isAccountJoined(token, actionId, account) == true`

## 黑名单票权

```solidity
denyVoteWeightOf(...) =
    ILOVE20Vote.votesNumByAccountByActionId(
        token,
        ILOVE20Vote.currentRound(),
        voter,
        actionId
    )
```

未激活时返回 `0`。

## 依赖

从 `ExtensionCenter` 固定读取：

- `VOTE`
- `JOIN`

## 状态

```solidity
struct TokenActionChatParams {
    address token;
    uint256 actionId;
    uint256 recentRounds;
}

mapping(uint256 => TokenActionChatParams) public paramsOf;
```

`paramsOf(chatGroupId).token == address(0)` 表示未激活。

## Review 重点

- recent vote 检查从 `Vote.currentRound()` 往前扫。
- action participation 和 extension participation 都可获得发言资格。
- 黑名单票权只看当前行动轮投票数，不看历史轮。
