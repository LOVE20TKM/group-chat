# TokenActionGroupChatManager

代币行动群 Manager。

## 合约

- `src/managers/TokenActionGroupChatManager.sol`

## 激活

```solidity
function activate(
    address token,
    uint256 actionId
) external returns (uint256 chatGroupId);
```

`recentRounds` 是构造函数入参，当前部署配置为 `3`；`recentRounds == 0` 必须在构造时 revert。

流程：

- Manager 生成群 NFT 名：`mgr_action_[symbol]_[actionId]_[xxxxxx]`
- 从调用者拉取 GroupNFT 铸造所需 LOVE20
- 调用 `GroupNFT.mint(...)` 得到 `chatGroupId`
- 激活对应 chat

写入：

- `paramsOf[chatGroupId].token = token`
- `paramsOf[chatGroupId].actionId = actionId`
- `chatGroupIdOfAction[token][actionId] = chatGroupId`
- `GroupChat.scopeSource = address(this)`
- `GroupChat.denySource = DENY_SOURCE_ADDRESS`
- `GroupChat.beforePostPlugin = BEFORE_POST_PLUGIN_ADDRESS`
- `GroupChat.afterPostPlugin = AFTER_POST_PLUGIN_ADDRESS`
- `delegateGroupId = 0`

## 发言资格

满足任一条件即可发言：

- 最近 `RECENT_ROUNDS` 轮内给该 `actionId` 投过票
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

- `VOTE_ADDRESS`
- `JOIN_ADDRESS`

## 状态

```solidity
struct TokenActionChatParams {
    address token;
    uint256 actionId;
}

mapping(uint256 => TokenActionChatParams) public paramsOf;
mapping(address => mapping(uint256 => uint256)) public chatGroupIdOfAction;
uint256 public immutable RECENT_ROUNDS;
```

`paramsOf(chatGroupId).token == address(0)` 表示未激活。

## Review 重点

- recent vote 检查从 `Vote.currentRound()` 往前扫。
- action participation 和 extension participation 都可获得发言资格。
- 黑名单票权只看当前行动轮投票数，不看历史轮。
