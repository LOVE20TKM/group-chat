# TokenActionGovGroupChatManager

代币行动治理者群 Manager。

## 合约

- `src/managers/TokenActionGovGroupChatManager.sol`

## 激活

```solidity
function activate(
    address token,
    uint256 actionId
) external returns (uint256 chatGroupId);
```

`recentRounds` 是构造函数入参，当前部署配置为 `3`；`recentRounds == 0` 必须在构造时 revert。

流程：

- Manager 生成群 NFT 名：`mgr_action_gov_[symbol]_[actionId]_[xxxxxx]`
- 从调用者拉取 GroupNFT 铸造所需 LOVE20
- 调用 `GroupNFT.mint(...)` 得到 `chatGroupId`
- 激活对应 chat

写入：

- `paramsOf[chatGroupId].token = token`
- `paramsOf[chatGroupId].actionId = actionId`
- `chatGroupIdOfAction[token][actionId] = chatGroupId`
- `_activatedActionIdsByToken[token].push(actionId)`
- `GroupChat.scopeSource = address(this)`
- `GroupChat.denySource = DENY_SOURCE_ADDRESS`
- `GroupChat.beforePostPlugin = BEFORE_POST_PLUGIN_ADDRESS`
- `GroupChat.afterPostPlugin = AFTER_POST_PLUGIN_ADDRESS`
- `delegateId = 0`

## 发言资格

最近 `RECENT_ROUNDS` 轮内给该 `actionId` 投过票。

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

- `VOTE_ADDRESS`

## 状态

```solidity
struct TokenActionGovChatParams {
    address token;
    uint256 actionId;
}

mapping(uint256 => TokenActionGovChatParams) public paramsOf;
mapping(address => mapping(uint256 => uint256)) public chatGroupIdOfAction;
mapping(address => uint256[]) internal _activatedActionIdsByToken;
uint256 public immutable RECENT_ROUNDS;
```

`paramsOf(chatGroupId).token == address(0)` 表示未激活。

## 列表查询

- `activatedActionsCount(token)`
- `activatedActions(token, offset, limit, reverse)`：返回 `actionIds`、`chatGroupIds`
- `chatGroupIdsOfActions(token, actionIds)`：按输入顺序等长返回 `chatGroupId`，未激活返回 `0`

## Review 重点

- 这是行动投票治理者群，不是行动参与者群。
- 发言资格只来自近期投票。
- 黑名单票权只看当前行动轮投票数，不看历史轮。
