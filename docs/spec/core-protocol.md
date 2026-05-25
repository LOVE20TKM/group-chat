# GroupChat 核心协议

## 目标

`GroupChat` 只负责公开链上群聊的最小状态：

- `GroupNFT` 身份与控制权
- chat 激活 / 发言开关
- 四个规则槽位
- 消息落链
- round 与分页索引

组织委托运营身份不属于 `GroupChat` 状态，统一由 `group` 仓库的 `GroupDelegate` 管理。

协议不负责私聊、阅读权限、成员表、链下消息、消息删除 / 编辑、主协议内置治理投票。

## 核心原则

- `1 NFT = 1 Chat`：`groupId` 直接等于 `GroupNFT.tokenId`。
- 身份是 `senderId`，地址只是当前 owner 签名器。
- 协议命名里 `senderId` 永远表示发言身份 NFT 的 `tokenId`，不是地址。
- 凡是地址语义必须显式写成 `senderAddress`、`targetAddress`、`owner`。
- `owner` 永远实时读 `GroupNFT.ownerOf(groupId)`，不缓存。
- 消息只增不改。
- 业务扩展通过 source、plugin 外置。

## 对象模型

`ChatInfo` 至少包含：

- `groupId`
- `owner`
- `activated`
- `postingAllowed`
- `scopeSource`
- `banSource`
- `beforePostPlugin`
- `afterPostPlugin`
- `firstActivatedOwner`
- `firstActivatedBlockNumber`
- `firstActivatedTimestamp`

## 生命周期

- 仅当前 owner 可 `activateChat`。
- `activated=true` 时重复激活必须 revert。
- 激活写入 `firstActivated*`，之后不可重新激活覆盖。
- 激活默认 `postingAllowed=true`。
- owner 或 `GroupDelegate` 中的有效 delegate 可 `setPostingAllowed`。
- `postingAllowed=false` 只禁止发消息，不禁止 source、plugin 管理写。

## Delegate

- `GroupChat` 不存储、不暴露 delegate 设置和查询。
- `GroupChat` 构造时只接收 `GroupAdmin`，并从 `GroupAdmin` 派生 `GroupDefaults`、`GroupDelegate` 与 `Group` 地址。
- `GroupChat.GROUP_DELEGATE_ADDRESS()` 指向 `group` 仓库部署的 `GroupDelegate`。
- `GroupChat` 的管理写权限实时调用 `GroupDelegate.ownerOrDelegateIdOf(groupId, operator)`。
- delegate 只能代管，不能代替发言。
- delegate 不能执行 `activateChat`，可以执行 `setPostingAllowed` 与规则槽更新。
- delegate 设置、清空、NFT 转让失效 / 恢复等规则以 `GroupDelegate` 为准。

## Rule Slots

每个 chat 有四个规则槽：

- `scopeSource`
- `banSource`
- `beforePostPlugin`
- `afterPostPlugin`

规则：

- `address(0)` 表示未挂载。
- `scopeSource=0` 表示默认开放发言。
- `banSource=0` 表示无黑名单。
- 非零地址必须有代码。
- 重复设置为当前值直接 no-op，不发事件。

调用顺序：

```text
核心校验
-> scopeSource
-> banSource
-> beforePostPlugin
-> 写消息
-> afterPostPlugin
```

## NFT 转让

- NFT 转让等同于群聊控制权转移。
- 新 owner 接管 source、plugin 与管理权。
- 历史消息、历史事件、消息归属不变。
- 前端权限判断必须实时读 owner。

## 零值规则

- 不存在的 `GroupNFT`：读写都应 revert。
- 已存在但未激活的 chat：`chatInfo` 返回未激活零值。
- 未挂载的规则槽返回 `address(0)`。
- 分页越界或 `limit == 0` 返回空数组。
- `message(groupId, messageId)` 中 `messageId == 0` 或超过当前消息数时必须 revert。

## 非功能要求

- 无升级管理员。
- 无协议级后门。
- 主协议不依赖任意 source / plugin 自报类型。
- source / plugin 不能越权修改核心状态。
- `post` 与外部模块交互必须防重入。
