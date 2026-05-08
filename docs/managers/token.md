# TokenGroupChatManager

基础代币群 Manager。

## 合约

- `src/managers/TokenGroupChatManager.sol`

## 激活

```solidity
function activate(address token) external returns (uint256 chatGroupId);
```

流程：

- Manager 生成群 NFT 名：`mgr_token_[symbol]_[xxxxxx]`
- 从调用者拉取 GroupNFT 铸造所需 LOVE20
- 调用 `GroupNFT.mint(...)` 得到 `chatGroupId`
- 激活对应 chat

写入：

- `tokenOf[chatGroupId] = token`
- `chatGroupIdOfToken[token] = chatGroupId`
- `_activatedTokens.push(token)`
- `GroupChat.scopeSource = address(this)`
- `GroupChat.denySource = DENY_SOURCE_ADDRESS`
- `GroupChat.beforePostPlugin = BEFORE_POST_PLUGIN_ADDRESS`
- `GroupChat.afterPostPlugin = AFTER_POST_PLUGIN_ADDRESS`
- `delegateId = 0`

## 发言资格

满足任一条件即可发言：

- `IERC20Balance(token).balanceOf(account) > 1`
- `ILOVE20Stake.validGovVotes(token, account) != 0`
- `ILOVE20Join.amountByAccount(token, account) != 0`
- 当前 round 已投行动中，`ExtensionCenter.isAccountJoined(token, actionId, account) == true`

## 黑名单票权

```solidity
denyVoteWeightOf(...) = ILOVE20Stake.validGovVotes(token, voter)
```

未激活时返回 `0`。

## 依赖

从 `ExtensionCenter` 固定读取：

- `STAKE_ADDRESS`
- `JOIN_ADDRESS`
- `VOTE_ADDRESS`

## 状态

- `mapping(uint256 => address) public tokenOf`
- `mapping(address => uint256) public chatGroupIdOfToken`
- `address[] internal _activatedTokens`
- `tokenOf(chatGroupId) == address(0)` 表示未激活

## 列表查询

- `activatedTokensCount()`
- `activatedTokens(offset, limit, reverse)`：返回 `tokens`、`chatGroupIds`

## Review 重点

- 持币阈值是 `> 1`，不是 `> 0`。
- extension action participation 只检查当前 `Join.currentRound()` 的已投行动。
- extension 参与状态以 `ExtensionCenter` 为准。
