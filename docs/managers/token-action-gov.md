# TokenActionGovGroupChatManager

代币行动治理者群 Manager。

## 合约

- `src/managers/TokenActionGovGroupChatManager.sol`

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

最近 `recentRounds` 轮内给该 `actionId` 投过票。

不包含：

- 持币资格
- 普通 join 资格
- extension join 资格

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

## 状态

```solidity
struct TokenActionGovChatParams {
    address token;
    uint256 actionId;
    uint256 recentRounds;
}

mapping(uint256 => TokenActionGovChatParams) public paramsOf;
```

`paramsOf(chatGroupId).token == address(0)` 表示未激活。

## Review 重点

- 这是行动投票治理者群，不是行动参与者群。
- 发言资格只来自近期投票。
- 黑名单票权只看当前行动轮投票数，不看历史轮。
