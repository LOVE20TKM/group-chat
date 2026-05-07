# AfterPostPlugin

AfterPostPlugin 处理消息落链后的观察型扩展。

## 主协议语义

- `afterPostPlugin = address(0)` 表示无落链后扩展。
- 非零地址必须有代码。
- `afterPost(...)` 在消息状态写入和 `MessagePost` 事件之后执行。
- `afterPost(...)` 失败不得回滚主消息。
- 失败只发 `AfterPostPluginFailed`。
- 主协议不强制 gas cap。

## 接口

```solidity
function afterPost(
    uint256 chatGroupId,
    uint256 senderGroupId,
    address senderAddress,
    string calldata content,
    uint256[] calldata mentions,
    bool mentionAll,
    uint256 quotedMessageId,
    uint256 messageId,
    uint256 blockNumber,
    uint256 timestamp
) external;
```

## 适用场景

- 镜像
- 索引提示
- 通知
- 外部业务同步

## 不适用场景

- 拒绝消息发送
- 修改已落链消息
- 修改主协议核心状态

## Review 重点

- `MessagePost` 必须先发。
- 插件失败必须可定位到 `chatGroupId`、1-based `messageId`、`pluginAddress`。
- 前端收到失败事件后回查 view 结果，不把事件当正文真源。
