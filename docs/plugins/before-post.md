# BeforePostPlugin

BeforePostPlugin 处理资格和黑名单之外的发言前额外规则。

## 主协议语义

- `beforePostPlugin = address(0)` 表示无额外发言前规则。
- 非零地址必须有代码。
- `beforePost(...)` revert 时，`post(...)` 整笔 revert。
- revert 不得留下消息、事件或占用的 `messageId`。
- 主协议不包装插件自定义错误。

## 接口

```solidity
function beforePost(
    uint256 groupId,
    uint256 senderId,
    address senderAddress,
    string calldata content,
    uint256[] calldata mentionedSenderIds,
    bool mentionAll,
    uint256 quotedMessageId
) external;
```

## 适用场景

- `mentionAll` 限制
- 内容格式限制
- 频率限制
- 审核前置规则
- 与业务系统同步前的硬拦截

## 不适用场景

- 基础发言资格：用 `scopeSource`
- 黑名单 / 豁免名单：用 `denySource`
- 消息落链后观察：用 `afterPostPlugin`

## Review 重点

- 插件不能修改主协议核心状态。
- 插件内部状态按 `groupId` 隔离。
- 插件内部配置权限应实时锚定 chat owner / 有效 delegate。
