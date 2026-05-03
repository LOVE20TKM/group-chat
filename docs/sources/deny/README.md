# DenySource

DenySource 判断“某身份 / 地址是否被禁言”。

## 主协议语义

- `denySource = address(0)` 表示无黑名单。
- 非零 `denySource` 必须有代码。
- `isDenied(...) == true` 时，`post(...)` 整笔 revert。
- `denySource` 调用失败时，`canPostStatus(...)` 返回 `DenySourceFailed.selector`。
- 豁免名单不是主协议概念；如果需要，由具体 DenySource 内部实现。

## 接口

```solidity
function isDenied(
    uint256 chatGroupId,
    uint256 senderGroupId,
    address senderAddress
) external view returns (bool);
```

## 当前文档

- [AdminDenySource](./admin-deny-source.md)
- [GovVotedDenySource](./gov-voted-deny-source.md)

## 共同约束

- 不得保存 chat owner 或 delegate 当前 owner 快照。
- 权限判断必须实时读取 `GroupChat`。
- 状态必须按 `chatGroupId` 隔离。
- 不允许 DenySource 级全局管理员绕过 chat 控制权。

## 前端规则

- 未在可信地址表中的 denySource，不调用专用展示接口。
- 可信 denySource 可选实现 `stateVersion(chatGroupId)` 和 `StateVersionChanged`，供前端重拉专用状态。
