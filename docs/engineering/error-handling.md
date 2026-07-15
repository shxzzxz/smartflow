# 错误处理

本文档定义 SmartFlow 的错误表达边界。通用 `Result` / `Failure` 已退出命令式业务主路径；命令失败使用内部异常表达，长期值返回失败使用场景专用 violation / validation report。

## 基本原则

校验用于判断输入、规则或状态是否满足要求；错误用于表达一次命令或调用已经失败。异常用于阻断一次命令流程；返回值用于表达普通判断、组合、预检和批量校验。

适合抛内部异常的场景：

- application command / domain service 主路径中的预期业务失败，例如账户角色非法、合同状态不允许编辑、冲销目标不存在。
- 不变量被破坏、代码状态不可能、数据损坏。
- 基础设施、平台、网络调用失败中，调用方明确关心且需要稳定错误语义的失败，经边界转换后的内部失败。
- 已知且可预期的持久化冲突经 repository / adapter 局部转换后的内部失败，例如幂等冲突、版本冲突或唯一性冲突。

不优先用异常表达的场景：

- `tryParse`、可选转换、分支探测。
- 需要组合的纯函数。
- 不修改状态的预检或规则校验；这类返回值应使用场景专用 violation / validation report。当前只需阻断第一个问题时优先返回单个 violation；需要一次收集多个问题时再升级为 validation report。
- 批量校验或需要一次性收集多个字段错误的表单基础校验。
- query/read path 中的正常空态；空结果使用 nullable 或 empty list 表达。

## MVVM 边界

- Request-Response 型 ViewModel 在用户命令边界捕获两层异常：先捕获 `AppException` 并转换为 ViewModel error state 或 submit failure；再捕获普通 `Exception` 并转换为未知错误语义，不向用户展示具体技术信息。
- ViewModel 不捕获 `Error`，例如 `StateError`、`TypeError` 和断言错误；这类编程错误或未处理异步错误交给全局错误处理。
- Reactive State-Driven 页面中的 query / provider 加载失败可以进入页面级 error state 或全局错误处理；不要为了展示错误而把正常空态表达成异常。
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

全局处理不尝试恢复业务状态，不维护复杂错误队列。业务可预期失败应在 ViewModel 捕获 `AppException` 后转成 UI outcome；用户命令中的普通 `Exception` 由 ViewModel 兜底成未知错误；未被命令 outcome 接住的异常和 `Error` 进入全局处理。

## 事务

目标 `TransactionRunner` 接口使用异常友好形态：

```dart
Future<T> run<T>(Future<T> Function() body);
```

命令式业务失败抛内部异常，底层事务机制自然回滚；ViewModel 在 application 调用边界捕获 `AppException` 和普通 `Exception`。`TransactionRunner` 只暴露异常友好的普通返回值接口，不再提供返回通用 `Result<T>` 的事务入口。

repository / adapter 只转换调用方明确关心的持久化失败，例如 `UPDATE` 影响行数为 0、幂等表唯一冲突或版本冲突。不要给每条 SQL 或每个 repository 方法套通用 guard。未知数据库异常不包装为业务失败；在用户命令链路中由 ViewModel 的普通 `Exception` 兜底成未知错误，在非命令链路中进入页面加载错误或全局错误处理。

## 内部异常类型

内部异常先保持最小层级：

- `BusinessException`：用户操作不满足业务规则，例如账户角色不允许、合同状态不允许、交易不可编辑。
- `InfrastructureException`：调用方明确关心的基础设施、平台、网络或持久化失败，并且该失败需要稳定 code 和 fallback message。

不关心具体类型的基础设施异常不强制包装成内部异常。Request-Response 型 ViewModel 捕获普通 `Exception` 后只返回未知错误文案；`Error` 继续上抛给全局错误处理。

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
credit.contract.not_editable
infra.network.timeout
infra.call.invalid_response
infra.persistence.conflict
```

错误 code 按领域或调用类型分组定义，禁止维护一个不断膨胀的全局大 enum。错误 code 表达稳定的外部处理类别，不要求和每个内部判断分支一一对应。

校验返回的 violation 可以比错误 code 更贴近具体规则，但 violation 不是错误码。映射为内部异常或 UI 错误语义时，再归并到稳定外部处理类别，例如 `ledger.account.not_found`、`ledger.account.unavailable`、`ledger.account.invalid_role`。

基础异常类型和错误 code interface 放在 `lib/core/error/`：

```text
lib/core/error/
├── app_exception.dart
└── app_error_code.dart
```

具体领域 code 按领域或调用类型分散定义，不集中进全局大 enum。例如账务 code 放在 ledger 相关目录，信贷 code 放在 credit 相关目录，基础设施调用错误 code 放在对应 adapter / infrastructure 附近；只有真正跨层通用的 code interface 放在 core。

## 迁移原则

- 命令式 application API 使用内部异常表达业务失败，不默认返回 `Result`。
- 代码中不再保留通用 `Result` / `Failure` 主路径；`Result` 后缀仅可用于表达成功返回数据的场景专用 DTO，例如 `PostingResult` 或 `PostedTransactionResult`，不得重新引入通用失败容器。
- 纯函数 / presentation / tryParse / 非 mutating 预检或规则校验 / 批量校验不强制迁移为异常；长期值返回失败应使用场景专用 violation / validation report，而不是通用 `Failure`。
- ViewModel 新增 API 不使用 `Result<T>` 作为默认返回类型；旧页面按触达式迁移到 UI 语义 outcome。
