# TokenGroupChatManager

基础代币群 Manager。

## 合约

- `src/managers/TokenGroupChatManager.sol`

## 激活

```solidity
function activate(uint256 chatGroupId, address token) external;
```

写入：

- `tokenOf[chatGroupId] = token`
- `GroupChat.scopeSource = address(this)`
- `GroupChat.denySource = DENY_SOURCE`
- `GroupChat.beforePostPlugin = BEFORE_POST_PLUGIN`
- `GroupChat.afterPostPlugin = AFTER_POST_PLUGIN`
- `delegateGroupId = 0`

## 发言资格

满足任一条件即可发言：

- `IERC20Balance(token).balanceOf(account) > 1`
- `ILOVE20Stake.validGovVotes(token, account) != 0`
- `ILOVE20Join.amountByAccount(token, account) != 0`
- 当前 round 已投行动的 extension 中，`joinedAmountByAccount(account) != 0`

## 黑名单票权

```solidity
denyVoteWeightOf(...) = ILOVE20Stake.validGovVotes(token, voter)
```

未激活时返回 `0`。

## 依赖

从 `ExtensionCenter` 固定读取：

- `STAKE`
- `JOIN`
- `VOTE`
- `SUBMIT`

## 状态

- `mapping(uint256 => address) public tokenOf`
- `tokenOf(chatGroupId) == address(0)` 表示未激活

## Review 重点

- 持币阈值是 `> 1`，不是 `> 0`。
- extension action participation 只检查当前 `Join.currentRound()`。
- extension 调用失败被忽略，不影响其他资格判断。
