# 测试矩阵

测试文件按行为边界拆分，review 时优先看对应文件。

## 文件对应

- `test/GroupChatLifecycle.t.sol`：部署、激活、发言开关、首次激活快照
- `test/GroupChatMeta.t.sol`：meta、批量写、`configVersion`
- `test/GroupChatDelegate.t.sol`：delegate、NFT 转让失效 / 恢复
- `test/GroupChatMessages.t.sol`：发言、mentionedSenderIds、mention 通知事件、quote、round、分页、sender 索引
- `test/GroupChatPlugins.t.sol`：scope、ban、before / after plugin、重入
- `test/GroupChatDefaultSender.t.sol`：默认发言身份
- `test/Manager.t.sol`：Manager 共同约束
- `test/TypedManagers.t.sol`：四个 typed Manager
- `test/GroupAdmin.t.sol`：共享管理员 NFT 配置
- `test/AdminBanSource.t.sol`：手工黑名单公共合约与中心化 ban source 适配器
- `test/GovVotedBanSource.t.sol`：治理投票 ban source
- `test/GroupMemberScope.t.sol`：成员 NFT 公共合约与 scope source 适配器
- `test/GroupJoinScopeSource.t.sol`：链群成员 scope source
- `test/DeployGroupChat.t.sol`：部署产物与地址文件

## 最小覆盖

生命周期：

- 非 owner 不能激活。
- 重复激活必须 revert。
- 停止发言只影响发消息，不清空历史配置和消息。
- 停止发言后仍可更新 live 配置。

Meta：

- 新增、更新、删除。
- 空 key、重复 key 必须 revert；相同值、删除不存在 key 必须 no-op。
- live key 总数超过 `MAX_META_KEYS` 必须 revert。
- 非空 value 超过 `MAX_META_VALUE_LENGTH` 必须 revert。
- 批量写只递增一次 `configVersion`。
- 批量写按最终 live key 总数校验 `MAX_META_KEYS`，失败时不得产生部分写入。

Delegate：

- owner 可设置和清空 delegate。
- delegate 不能激活或代替发言。
- NFT 转出后旧 delegate 失效，转回后恢复。

发言：

- `senderId` owner 才能发。
- 默认允许跨群发言。
- 空内容、超长内容、非法 quote、重复 mentionedSenderIds、超限 mentionedSenderIds 必须 revert。
- `postAsDefaultSender` 复用默认身份。

分页：

- 全量、round、sender、mention、mentionAll 都支持正序 / 倒序分页。
- `limit == 0` 和越界返回空数组。
- 轻量索引与完整消息集合一致。

规则槽：

- `scopeSource=false` 拒绝发言。
- `banSource=true` 拒绝发言。
- source 失败返回对应 `canPost` reason。
- 非零无代码地址必须 revert。
- `beforePost` revert 回滚整笔消息。
- `afterPost` 失败不回滚消息。
- 外部调用过程防重入。

Manager：

- 构造依赖必须有代码。
- typed Manager 只能激活 `Launch.isLOVE20Token(token) == true` 的代币。
- 激活后不可通过 Manager 停止发言、不可重配规则槽。
- 不暴露通用 call / delegatecall / execute 后门。
- 重复 `activate` 必须 revert。

Source：

- `GroupAdmin` 统一 owner / delegate 配管理员 NFT。
- `GroupMember` 维护成员 NFT 名单，`GroupMemberScope` 使用该名单控制发言资格。
- `GroupJoinScopeSource` 组合 `GroupMember` 与 `GroupJoin` g 索引。
- `GroupBanList` 维护手工黑名单，`AdminBanSource` 使用该名单控制发言资格。
- `AdminBanSource` 可与 `GroupJoinScopeSource` 组合使用。
- `GovVotedBanSource` 按治理投票权重和黑名单生效阈值判定。

部署：

- 固定部署 `GroupAdmin`、`GroupBanList`、`AdminBanSource`、`GovVotedBanSource`、`GroupMember`、`GroupMemberScope`、`GroupJoinScopeSource`。
- 地址文件只包含当前仓库部署产物字段；上游依赖地址不写入 `address.group.chat.params`。

## 当前验证命令

```bash
forge test
```

生产合约体积检查只看 `src`，不把 `script` / `test` 产物计入：

```bash
forge build src --sizes
```
