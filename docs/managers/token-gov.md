# TokenGovGroupChatManager

代币治理者群 Manager。

## 合约

- `src/managers/TokenGovGroupChatManager.sol`

## 激活

```solidity
function activate(address token) external returns (uint256 chatGroupId);
```

流程：

- Manager 生成群 NFT 名：`mgr_token_gov_[symbol]_[xxxxxx]`
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

- `STAKE_ADDRESS`

## 状态

- `mapping(uint256 => address) public tokenOf`
- `mapping(address => uint256) public chatGroupIdOfToken`
- `address[] internal _activatedTokens`
- `tokenOf(chatGroupId) == address(0)` 表示未激活

## 列表查询

- `activatedTokensCount()`
- `activatedTokens(offset, limit, reverse)`：返回 `tokens`、`chatGroupIds`

## Review 重点

- 这是治理票群，不是持币群。
- 发言资格和黑名单票权使用同一个治理票来源。
