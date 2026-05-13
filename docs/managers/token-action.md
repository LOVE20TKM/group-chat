# TokenActionManager

代币行动群 Manager。

## 合约

- `src/managers/TokenActionManager.sol`

## 激活

```solidity
function activate(
    address token,
    uint256 actionId
) external returns (uint256 groupId);
```

`recentRounds` 是构造函数入参，当前部署配置为 `3`；`recentRounds == 0` 必须在构造时 revert。

流程：

- 校验 `Launch.isLOVE20Token(token) == true`
- Manager 生成群 NFT 名：`mgr_action_[symbol]_[actionId]_[xxxxxx]`
- 从调用者拉取 GroupNFT 铸造所需 LOVE20
- 调用 `GroupNFT.mint(...)` 得到 `groupId`
- 激活对应 chat

写入：

- `actionOfGroup[groupId].token = token`
- `actionOfGroup[groupId].actionId = actionId`
- `groupIdOfAction[token][actionId] = groupId`
- `_actionIdsByToken[token].push(actionId)`
- `GroupChat.scopeSource = address(this)`
- `GroupChat.denySource = DENY_SOURCE_ADDRESS`
- `GroupChat.beforePostPlugin = BEFORE_POST_PLUGIN_ADDRESS`
- `GroupChat.afterPostPlugin = AFTER_POST_PLUGIN_ADDRESS`
- `delegateId = 0`

## 发言资格

满足任一条件即可发言：

- 最近 `RECENT_ROUNDS` 轮内给该 `actionId` 投过票
- `ILOVE20Join.amountByActionIdByAccount(token, actionId, account) != 0`
- `ExtensionCenter.isAccountJoined(token, actionId, account) == true`

## 黑名单票权

```solidity
denyVoteWeightOf(groupId, voter) =
    ILOVE20Vote.votesNumByAccountByActionId(
        token,
        ILOVE20Vote.currentRound(),
        voter,
        actionId
    )
denyVoteTotalWeightOf(groupId) = ILOVE20Stake.govVotesNum(token)
```

未激活时返回 `0`。

## 依赖

构造时从 `EXTENSION_CENTER_ADDRESS` 指向的 `ExtensionCenter` 固定读取以下内部依赖；这些派生地址不作为 Manager public getter 暴露：

- `VOTE_ADDRESS`
- `STAKE_ADDRESS`
- `LAUNCH_ADDRESS`
- `JOIN_ADDRESS`

## 状态

```solidity
struct ActionChat {
    address token;
    uint256 actionId;
}

mapping(uint256 => ActionChat) public actionOfGroup;
mapping(address => mapping(uint256 => uint256)) public groupIdOfAction;
mapping(address => uint256[]) internal _actionIdsByToken;
uint256 public immutable RECENT_ROUNDS;
```

`actionOfGroup(groupId).token == address(0)` 表示未激活。

## 列表查询

- `actionsByTokenCount(token)`
- `actionsByToken(token, offset, limit, reverse)`：返回 `actionIds`、`groupIds`
- `groupIdsOfActions(token, actionIds)`：按输入顺序等长返回 `groupId`，未激活返回 `0`
- `actionsOfGroups(groupIds)`：按输入顺序等长返回 `tokens`、`actionIds`，未激活返回 `address(0)`、`0`

## Review 重点

- recent vote 检查从 `Vote.currentRound()` 往前扫。
- action participation 和 extension participation 都可获得发言资格。
- 黑名单票权只看当前行动轮投票数，不看历史轮。
