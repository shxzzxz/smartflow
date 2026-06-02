# 错误处理

本文档定义 SmartFlow 的错误表达边界。当前代码仍存在大量 `Result` / `Failure`，后续按触达式迁移，不做一次性全量重构。

## 基本原则

异常用于阻断一次命令流程；返回值用于表达普通判断和组合。

适合抛内部异常的场景：

- application command / domain service 中的预期业务失败，例如账户角色非法、合同状态不允许编辑、冲销目标不存在。
- 不变量被破坏、代码状态不可能、数据损坏。
- 基础设施、平台、网络调用失败经边界转换后的调用失败。
- 已知且可预期的持久化冲突经 repository / adapter 边界转换后的业务失败，例如幂等冲突、版本冲突或唯一性冲突。

不优先用异常表达的场景：

- `tryParse`、可选转换、分支探测。
- 需要组合的纯函数。
- 批量校验或需要一次性收集多个字段错误的表单基础校验。
- query/read path 中的正常空态；空结果使用 nullable 或 empty list 表达。

## MVVM 边界

- ViewModel 捕获内部异常，并转换为 ViewModel error state 或 submit failure。
- ViewModel 不吞掉非预期异常；非预期异常上抛给全局错误处理。
- View 负责根据 ViewModel 暴露的错误状态执行 snackbar、dialog、inline error、banner 或 fullscreen placeholder。
- ViewModel 对 View 的返回协议不使用 `Result<T>` 命名，避免和业务层历史 `Result` 混用；使用 `SubmitOutcome`、`UiActionOutcome` 或具体页面语义 outcome。
- `UiError` 只包含错误语义和字段错误，不包含 snackbar / dialog / banner 等展示方式。

## 全局异常处理

全局异常处理先保持最小闭环：

- 捕获 Flutter framework error。
- 捕获未处理 async error。
- 后续可通过 Riverpod `ProviderObserver` 记录 provider 错误。
- 记录日志并展示兜底错误页或兜底提示。
- Debug 下保留错误详情；Release 下展示通用文案。

全局处理不尝试恢复业务状态，不维护复杂错误队列。业务可预期失败应在 ViewModel 捕获内部异常后转成 UI outcome；非预期异常才进入全局处理。

## 事务

目标 `TransactionRunner` 接口使用异常友好形态：

```dart
Future<T> run<T>(Future<T> Function() body);
```

命令式业务失败抛内部异常，底层事务机制自然回滚；ViewModel 在 application 调用边界捕获内部异常。既有返回 `Result<T>` 的事务接口按触达式迁移。

repository / adapter 可以把明确识别的数据库异常转换为内部异常；未知数据库异常不吞掉、不包装为业务失败，继续上抛给全局错误处理。

## 内部异常类型

内部异常先保持最小层级：

- `BusinessException`：用户操作不满足业务规则，例如账户角色不允许、合同状态不允许、交易不可编辑。
- `CallException`：外部调用失败，例如网络超时、平台 API 失败、远端返回参数错误并被解析为可展示失败。

非预期异常不包成内部异常，继续上抛给全局错误处理。

内部异常必须携带稳定 `code` 和 fallback `message`。`code` 用于测试、日志、展示映射和未来埋点；`message` 是兜底文案，ViewModel / 展示层可以按页面场景覆盖最终用户文案。

错误 code 使用命名空间字符串码，不使用数字码。格式：

```text
<domain>.<subject>.<reason>
```

示例：

```text
ledger.account.not_found
ledger.account.invalid_role
ledger.transaction.not_editable
credit.contract.not_found
credit.contract.closed
call.timeout
call.invalid_response
```

错误 code 按领域或调用类型分组定义，禁止维护一个不断膨胀的全局大 enum。

基础异常类型和错误 code interface 放在 `lib/core/error/`：

```text
lib/core/error/
├── app_exception.dart
└── app_error_code.dart
```

具体领域 code 按领域或调用类型分散定义，不集中进全局大 enum。例如账务 code 放在 ledger 相关目录，信贷 code 放在 credit 相关目录，调用错误 code 可放在 core 或调用适配层附近。

## 迁移原则

- 新增命令式 application API 优先使用内部异常表达业务失败，不再默认返回 `Result`。
- 既有 `Result` API 按触达式迁移。
- 纯函数 / presentation / tryParse 类函数不强制迁移为异常。
- ViewModel 新增 API 不使用 `Result<T>` 作为默认返回类型；旧页面按触达式迁移到 UI 语义 outcome。
