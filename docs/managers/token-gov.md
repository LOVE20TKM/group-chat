# TokenGovGroupChatManager

代币治理者群 Manager。

## 合约

- `src/managers/TokenGovGroupChatManager.sol`

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

```solidity
ILOVE20Stake.validGovVotes(token, account) != 0
```

## 黑名单票权

```solidity
denyVoteWeightOf(...) = ILOVE20Stake.validGovVotes(token, voter)
```

未激活时返回 `0`。

## 依赖

从 `ExtensionCenter` 固定读取：

- `STAKE`

## 状态

- `mapping(uint256 => address) public tokenOf`
- `tokenOf(chatGroupId) == address(0)` 表示未激活

## Review 重点

- 这是治理票群，不是持币群。
- 发言资格和黑名单票权使用同一个治理票来源。
