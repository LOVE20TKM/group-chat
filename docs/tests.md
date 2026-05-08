# 测试矩阵

测试文件按行为边界拆分，review 时优先看对应文件。

## 文件对应

- `test/GroupChatLifecycle.t.sol`：部署、激活、发言开关、首次激活快照
- `test/GroupChatMeta.t.sol`：meta、批量写、`configVersion`
- `test/GroupChatDelegate.t.sol`：delegate、NFT 转让失效 / 恢复
- `test/GroupChatMessages.t.sol`：发言、mentionedSenderIds、mention 通知事件、quote、round、分页、sender 索引
- `test/GroupChatPlugins.t.sol`：scope、deny、before / after plugin、重入
- `test/GroupChatDefaultSender.t.sol`：默认发言身份
- `test/GroupChatManager.t.sol`：Manager 共同约束
- `test/GroupChatTypedManagers.t.sol`：四个 typed Manager
- `test/AdminDenySource.t.sol`：中心化 deny source
- `test/GovVotedDenySource.t.sol`：治理投票 deny source
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
- 空 key、重复 key、相同值、删除不存在 key 必须 revert。
- 批量写只递增一次 `configVersion`。

Delegate：

- owner 可设置和清空 delegate。
- delegate 不能激活或代替发言。
- NFT 转出后旧 delegate 失效，转回后恢复。

发言：

- `senderId` owner 才能发。
- 默认允许跨群发言。
- 空内容、超长内容、非法 quote、重复 mentionedSenderIds、超限 mentionedSenderIds 必须 revert。
- `postByDefaultSender` 复用默认身份。

分页：

- 全量、round、sender、mention、mentionAll 都支持正序 / 倒序分页。
- `limit == 0` 和越界返回空数组。
- 轻量索引与完整消息集合一致。

规则槽：

- `scopeSource=false` 拒绝发言。
- `denySource=true` 拒绝发言。
- source 失败返回对应 `canPostStatus` reason。
- 非零无代码地址必须 revert。
- `beforePost` revert 回滚整笔消息。
- `afterPost` 失败不回滚消息。
- 外部调用过程防重入。

Manager：

- 构造依赖必须有代码。
- 激活后不可通过 Manager 停止发言、不可重配规则槽。
- 不暴露通用 call / delegatecall / execute 后门。
- 重复 `activate` 必须 revert。

Source：

- `GroupJoinScopeSource` 只读 `GroupJoin` g 索引。
- `AdminDenySource` 可与 `GroupJoinScopeSource` 组合使用。
- `GovVotedDenySource` 按治理投票权重判定。

部署：

- 固定部署 `AdminDenySource`、`GovVotedDenySource`、`GroupJoinScopeSource`。
- 地址文件只包含当前仓库部署产物字段；上游依赖地址不写入 `address.group.chat.params`。

## 当前验证命令

```bash
forge test
```
