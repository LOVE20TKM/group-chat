# Group Chat 文档入口

- 模块：LOVE20 `GroupNFT` 群聊协议
- 状态：开发中
- 目标：`1 NFT = 1 Chat`，公开链上、可扩展、无协议级特权

## 阅读顺序

1. [核心协议](./spec/core-protocol.md)
2. [发言与查询](./spec/posting-query.md)
3. [ABI / 事件 / 错误](./spec/abi-events-errors.md)
4. [群聊类型](./chat-types.md)
5. [Manager 总览](./managers/README.md)
6. [ScopeSource 总览](./sources/scope/README.md)
7. [DenySource 总览](./sources/deny/README.md)
8. [部署说明](./deployment.md)
9. [测试矩阵](./tests.md)

## 权威边界

- 主协议行为以 `src/GroupChat.sol` 和 [核心协议](./spec/core-protocol.md) 为准。
- ABI、事件、错误以 `src/interfaces/IGroupChat.sol` 和 [ABI / 事件 / 错误](./spec/abi-events-errors.md) 为准。
- 当前正式群聊类型以 [群聊类型](./chat-types.md) 为准。
- 去中心化群聊 Manager 细节以 [managers/](./managers/README.md) 为准。
- 发言资格源、黑名单源以 [sources/](./sources/) 为准。
- 插件只处理规则槽位之外的发言前后扩展，见 [plugins/](./plugins/).

## 当前合约族

主协议：

- `GroupChat`

Typed Managers：

- [TokenManager](./managers/token.md)
- [TokenGovManager](./managers/token-gov.md)
- [TokenActionManager](./managers/token-action.md)
- [TokenActionGovManager](./managers/token-action-gov.md)

Sources：

- [ScopeSource 共同语义](./sources/scope/README.md)
- [DenySource 共同语义](./sources/deny/README.md)
- [AdminDenySource](./sources/deny/admin-deny-source.md)
- [GovVotedDenySource](./sources/deny/gov-voted-deny-source.md)

群聊类型：

- [四种去中心化群聊与链群服务者管理型群聊](./chat-types.md)

Plugins：

- [BeforePostPlugin](./plugins/before-post.md)
- [AfterPostPlugin](./plugins/after-post.md)

## Review 规则

- 改主协议状态或接口，只 review `spec/core-protocol.md` 与 `spec/abi-events-errors.md`。
- 改消息、分页、索引，只 review `spec/posting-query.md`。
- 改某个 Manager，只 review `managers/<name>.md` 和对应合约 / 测试。
- 改某个 source，只 review `sources/<kind>/<name>.md` 和对应合约 / 测试。
- 改部署，只 review `deployment.md` 与 `script/`。

## 历史快照

旧的大文档仅作审计快照，不再作为当前权威：

- [requirements-v0.1-monolith.md](./archive/requirements-v0.1-monolith.md)
- [group-chat-contract-architecture-v0.1.md](./archive/group-chat-contract-architecture-v0.1.md)
- [group-chat-type-policy-requirements-v0.1.md](./archive/group-chat-type-policy-requirements-v0.1.md)
