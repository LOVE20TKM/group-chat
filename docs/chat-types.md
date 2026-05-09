# 群聊类型

`GroupChat` 本身不内置群聊类型。类型由 `GroupNFT` 控制方式和四个规则槽决定。

本文档只覆盖当前正式支持的五类群聊：

- 四种去中心化群聊：由 typed Manager 铸造、持有群聊 NFT 并激活。
- 一种链群服务者管理型群聊：由链群服务者持有群聊 NFT，直接配置 `scopeSource` 与 `denySource`。

## 1. 类型边界

| 类型 | 控制权 | `scopeSource` | `denySource` |
| --- | --- | --- | --- |
| 代币社区群聊 | `TokenGroupChatManager` | `TokenGroupChatManager` | `GovVotedDenySource` |
| 代币治理者群聊 | `TokenGovGroupChatManager` | `TokenGovGroupChatManager` | `GovVotedDenySource` |
| 代币行动群聊 | `TokenActionGroupChatManager` | `TokenActionGroupChatManager` | `GovVotedDenySource` |
| 代币行动治理者群聊 | `TokenActionGovGroupChatManager` | `TokenActionGovGroupChatManager` | `GovVotedDenySource` |
| 链群服务者管理型群聊 | 链群服务者 owner / delegate | `GroupJoinScopeSource` | `AdminDenySource` |

## 2. 四种去中心化群聊

去中心化群聊由 typed Manager 激活。Manager 铸造并持有对应 `GroupNFT`，并在激活时一次性写入：

- `scopeSource`
- `denySource`
- `beforePostPlugin`
- `afterPostPlugin`
- `delegateId = 0`

激活后，Manager 不暴露关闭、重配规则槽或修改发言资格参数的通用入口。

### 2.1 代币社区群聊

入口：[TokenGroupChatManager](./managers/token.md)

用途：面向某个 LOVE20 代币社区的宽口径成员群聊。

发言资格满足任一条件即可：

- 持有该代币余额 `> 1`
- 对该代币有有效治理票
- 通过主协议参与过该代币行动
- 当前轮已投行动的 extension 中参与过

黑名单：治理投票黑名单，票权来自该代币有效治理票。

### 2.2 代币治理者群聊

入口：[TokenGovGroupChatManager](./managers/token-gov.md)

用途：面向某个 LOVE20 代币治理者的群聊。

发言资格：

- 对该代币有有效治理票

黑名单：治理投票黑名单，票权来自该代币有效治理票。

### 2.3 代币行动群聊

入口：[TokenActionGroupChatManager](./managers/token-action.md)

用途：面向某个代币下特定行动相关参与者的群聊。

发言资格满足任一条件即可：

- 最近 `RECENT_ROUNDS` 轮内给该行动投过票
- 通过主协议参与过该行动
- 通过 extension 参与过该行动

黑名单：治理投票黑名单，票权来自当前轮该行动投票数。

### 2.4 代币行动治理者群聊

入口：[TokenActionGovGroupChatManager](./managers/token-action-gov.md)

用途：面向某个代币下特定行动治理者的群聊。

发言资格：

- 最近 `RECENT_ROUNDS` 轮内给该行动投过票

不包含持币资格、普通参与资格或 extension 参与资格。

黑名单：治理投票黑名单，票权来自当前轮该行动投票数。

## 3. 链群服务者管理型群聊

链群服务者管理型群聊不使用 Manager 托管群聊 NFT。

控制权来自：

- `GroupNFT.ownerOf(groupId)` 当前 owner
- `delegateId` 的有效 owner

推荐配置：

```text
GroupChat.scopeSource = GroupJoinScopeSource
GroupChat.denySource = AdminDenySource
GroupChat.beforePostPlugin = 可选
GroupChat.afterPostPlugin = 可选
```

### 3.1 发言资格

基础发言资格由 `scopeSource` 判断。

链群群聊的 `scopeSource` 使用 [GroupJoinScopeSource](./sources/scope/group-join-scope-source.md)，语义是：

```text
GroupJoin.gTokenAddressesByGroupIdByAccountCount(groupId, senderAddress) > 0
```

即发送地址当前在该链群下参与至少一个代币社区行动。

`scopeSource = address(0)` 表示默认开放发言，不适合作为链群行动参与者群聊的默认模型。

### 3.2 黑名单

黑名单使用 [AdminDenySource](./sources/deny/admin-deny-source.md)。

权限模型：

- owner / delegate 可配置管理员、豁免名单。
- admin 管理黑名单；owner / delegate 要管理黑名单，需将自己的默认身份 NFT 加入管理员集合。
- 黑名单支持地址维度与 `senderId` 维度；豁免名单只支持 `senderId` 维度。
- 豁免名单只豁免黑名单，不增加基础发言资格。

链群服务者管理型群聊不使用治理投票黑名单。

### 3.3 配置路径

链群服务者 owner 可通过主协议直接激活：

```solidity
activateChat(
    groupId,
    metaKeys,
    metaValues,
    groupJoinScopeSource,
    adminDenySource,
    beforePostPlugin,
    afterPostPlugin,
    delegateId
)
```

激活后，owner 或有效 delegate 可通过主协议更新：

- `setScopeSource(...)`
- `setDenySource(...)`
- `setBeforePostPlugin(...)`
- `setAfterPostPlugin(...)`

owner 可通过主协议更新：

- `setDelegateId(...)`

这和四种 Manager 型去中心化群聊不同：链群服务者管理型群聊保留 owner / delegate 的人工管理能力。

## 4. 选择规则

- 需要不可由 Manager 停止发言、不可重配、治理投票禁言：使用四种 typed Manager 群聊。
- 需要链群服务者按链群运营实际管理禁言：使用链群服务者管理型群聊。
- 成员资格必须放在 `scopeSource`，不要放进 `AdminDenySource` 的豁免名单。
- 黑名单只回答“是否被拒绝发言”，不回答“是否本来有资格发言”。
