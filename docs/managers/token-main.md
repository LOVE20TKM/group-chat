# TokenMainManager

基础代币群 Manager。

## 合约

- `src/managers/TokenMainManager.sol`

## 激活

```solidity
function activate(address token) external returns (uint256 groupId);
```

流程：

- 校验 `Launch.isLOVE20Token(token) == true`
- Manager 生成群 NFT 名：`mgr_token_main_[symbol]_[xxxxxx]`
- 从调用者拉取 GroupNFT 铸造所需 LOVE20
- 调用 `GroupNFT.mint(...)` 得到 `groupId`
- 激活对应 chat
- 发出 `Activate(token, groupId, operator)`

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

满足任一条件即可发言：

- `IERC20Balance(token).balanceOf(account) > 1`
- `ILOVE20Stake.validGovVotes(token, account) != 0`
- `ILOVE20Join.amountByAccount(token, account) != 0`

## 黑名单票权

```solidity
voteWeightOf(groupId, voter) = ILOVE20Stake.validGovVotes(token, voter)
totalVoteWeight(groupId) = ILOVE20Stake.govVotesNum(token)
```

未激活时返回 `0`。

## 依赖

构造时从 `EXTENSION_CENTER_ADDRESS` 指向的 `ExtensionCenter` 固定读取以下内部依赖；这些派生地址不作为 Manager public getter 暴露：

- `STAKE_ADDRESS`
- `LAUNCH_ADDRESS`
- `JOIN_ADDRESS`

## 状态

- `mapping(uint256 => address) public tokenOfGroup`
- `mapping(address => uint256) public groupIdOfToken`
- `address[] internal _tokens`
- `tokenOfGroup(groupId) == address(0)` 表示未激活

## 列表查询

- `tokensCount()`
- `tokens(offset, limit, reverse)`：返回 `tokens`、`groupIds`

## Review 重点

- 持币阈值是 `> 1`，不是 `> 0`。
- token 主群不把 extension 参与状态作为发言资格，避免按当前轮行动列表做无界扫描。
