# TokenGovGroupChatManager

代币治理者群 Manager。

## 合约

- `src/managers/TokenGovGroupChatManager.sol`

## 激活

```solidity
function activate(address token) external returns (uint256 groupId);
```

流程：

- 校验 `Launch.isLOVE20Token(token) == true`
- Manager 生成群 NFT 名：`mgr_token_gov_[symbol]_[xxxxxx]`
- 从调用者拉取 GroupNFT 铸造所需 LOVE20
- 调用 `GroupNFT.mint(...)` 得到 `groupId`
- 激活对应 chat

写入：

- `tokenOfGroup[groupId] = token`
- `groupIdOfToken[token] = groupId`
- `_tokens.push(token)`
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
denyVoteWeightOf(groupId, voter) = ILOVE20Stake.validGovVotes(token, voter)
denyVoteTotalWeightOf(groupId) = ILOVE20Stake.govVotesNum(token)
```

未激活时返回 `0`。

## 依赖

构造时从 `EXTENSION_CENTER_ADDRESS` 指向的 `ExtensionCenter` 固定读取以下内部依赖；这些派生地址不作为 Manager public getter 暴露：

- `STAKE_ADDRESS`
- `LAUNCH_ADDRESS`

## 状态

- `mapping(uint256 => address) public tokenOfGroup`
- `mapping(address => uint256) public groupIdOfToken`
- `address[] internal _tokens`
- `tokenOfGroup(groupId) == address(0)` 表示未激活

## 列表查询

- `tokensCount()`
- `tokens(offset, limit, reverse)`：返回 `tokens`、`groupIds`

## Review 重点

- 这是治理票群，不是持币群。
- 发言资格和黑名单票权使用同一个治理票来源。
