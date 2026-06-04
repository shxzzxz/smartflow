# PRD：Feature MVVM 与错误处理架构收敛

## 问题陈述

SmartFlow 当前 feature 层的 View 与 ViewModel 职责没有被清晰定义。大量页面直接承担表单状态、provider 聚合、提交编排、application command 组装、错误处理和 UI 反馈，导致页面文件膨胀、重复 helper 增多、测试边界模糊。

同时，命令式业务流程大量使用 `Result` / `Failure` 表达可预期失败。这个模式让 application、domain、feature 都需要反复检查失败结果，并且让事务 runner 需要把失败结果转换为内部回滚信号再还原。随着 MVVM 迁移推进，如果 ViewModel 也继续返回 `Result`，会和业务层历史 `Result` 产生语义混淆。

工程文档也出现膨胀：原工程结构文档承载了分层、目录、MVVM、测试、命名、演进、事务等多类规则，不利于 agent 和开发者快速定位目标规范。

复杂页面还存在“页面动态渲染”和“业务行为分发”边界不清的问题。页面可能根据业务类型、账务行为或业务归属展示不同字段、按钮、横幅和编辑入口，也可能在用户点击后分发到不同 application service。若这些判断散落在 widget、路由、公开 policy 或组件工厂中，View 会膨胀，行为分发也会被误抽象成跨页面契约。

## 解决方案

收敛 feature 层到明确的 MVVM 边界：View 负责 Flutter 渲染、控件生命周期、字段级校验和 UI 副作用；ViewModel 负责页面级状态、用户意图、页面级提交编排、application command 组装和 submit outcome；presentation 负责无状态纯展示转换。

复杂页面的动态渲染由页面级 ViewModel 输出 view state 控制。路由只提供身份或初始化信号；View 只根据 view state 渲染字段可编辑状态、按钮显示、banner、禁用原因等页面状态。用户操作以页面语义事件交给 ViewModel，ViewModel 再根据当前 state、read model、业务类型和业务归属转换为 application command。

单页面内的类型 / 归属分发默认作为 ViewModel 私有实现细节存在。只有多个页面已经稳定复用同一套页面无关动作协议时，才提升为共享 handler 或策略对象。组件工厂只用于拆分 UI 结构差异，不作为业务行为分发机制。

命令式业务失败逐步从 `Result` 迁移为内部异常。内部异常分为业务异常和基础设施异常，携带稳定命名空间字符串 code 和 fallback message。Request-Response 型 ViewModel 在用户命令边界捕获 `AppException` 并转换为 UI 语义 outcome；普通 `Exception` 兜底为未知错误，不向用户展示具体技术信息；`Error` 和未处理异步异常继续交给全局异常处理。纯函数、`tryParse`、可组合转换、预检、规则校验和批量校验不强制使用异常，但长期值返回失败应使用场景专用 violation / validation report，不继续扩散通用 `Failure`。

错误展示由 View 或全局 UI handler 决定。ViewModel 只暴露错误语义，不携带 snackbar、dialog、banner、fullscreen 等展示方式。字段级校验使用 Flutter `Form` / `FormField.validator` 机制，validator 可按复用范围沉淀到设计系统、业务组件或 feature presentation。

工程文档拆分为总览入口和 engineering 子文档。后续实现以交易表单为参考切片，验证 MVVM、内部异常、ViewModel outcome、validator/helper 收口和测试边界。

## 最终目标

本 PRD 的最终目标是完成 feature MVVM、错误处理和 helper 收口的系统性重构，而不只是完成参考切片。

完成状态应满足：

- 复杂页面遵循 View / ViewModel / presentation 边界，页面不再承担提交编排、command 组装和跨数据源状态聚合。
- 复杂页面的动态渲染由页面级 view state 表达，View 不在 widget 内复制跨数据源、跨业务域或业务归属判断。
- 页面事件到 application command 的转换由页面级 ViewModel 负责；单页面内的业务类型 / 业务归属分发保持私有实现。
- 路由只提供页面身份或初始化信号，不承载复杂渲染或业务行为分发。
- 公开 policy / handler / strategy 只在多个页面稳定复用同一套页面无关动作协议时引入。
- 命令式 application API 不再默认使用 `Result` / `Failure` 表达预期业务失败，而是使用内部异常。
- 历史 `Result` / `Failure` 仅作为迁移遗留保留，不作为新主路径类型；长期值返回失败应使用场景专用 violation / validation report。
- ViewModel 对 View 使用 UI 语义 outcome，不使用业务层历史 `Result`。
- 重复 helper 按语义收口到设计系统、业务组件、presentation、core 或具体 ViewModel，不再在页面内重复散落。
- 字段级校验使用 Flutter 表单 validator 和可复用 validator，ViewModel 不承担字段内联错误展示。
- 用户命令中的内部异常由 ViewModel 捕获并转换为 UI outcome；普通 `Exception` 由 ViewModel 兜底为未知错误；`Error` 和未处理异步异常进入全局异常处理。
- 工程文档与实现保持一致，后续 agent 能按文档独立迁移页面。

## 落地策略

本 PRD 是一个渐进式架构收敛 PRD，不要求一次性完成所有页面迁移。它的目标是先建立清晰边界和参考实现，再通过后续 issue 按触达式逐步解决页面膨胀、helper 重复和错误处理不一致的问题。

建议按以下阶段推进：

1. 建立基础协议和交易表单参考切片：工程文档、内部异常、错误 code interface、UI outcome、交易表单 ViewModel 和测试提供第一组样板。
2. 补全交易表单参考切片：覆盖编辑、收入、转账、借入、报销垫付等路径，验证 ViewModel state、初始化幂等、command 构造和 outcome 一致性。
3. 收口重复 helper：在交易表单补全过程中优先沉淀金额校验、controller 同步、UI feedback 等复用能力。
4. 迁移复杂页面动态渲染与业务行为分发：以交易详情页为代表，把页面状态收敛到 ViewModel view state，把类型 / 归属分发收为 ViewModel 私有实现。
5. 改造事务和命令边界：将更多命令式业务失败迁移为内部异常；既有 `Result` API 只作为迁移遗留保留。
6. 扩展到高收益页面：按风险和收益迁移账户与分类表单、信贷合同编辑、还款表单、日历和首页等页面。
7. 建立全局异常最小闭环：捕获 `Error`、未处理异步异常和命令边界之外的异常，记录日志并提供兜底展示。

## 用户故事

1. 作为 SmartFlow 用户，我希望保存交易时要么成功完成，要么看到清晰错误提示，从而知道发生了什么。
2. 作为 SmartFlow 用户，我希望字段级输入错误展示在对应输入控件附近，从而能快速修正问题。
3. 作为 SmartFlow 用户，我希望业务规则失败能结合当前页面解释，从而知道下一步可以怎么做。
4. 作为 SmartFlow 用户，我希望非预期异常被一致处理，从而应用不会静默失败或在正式版本展示技术错误。
5. 作为 SmartFlow 用户，我希望首页、日历、列表和图表在账务事实变化后自动刷新，从而不需要手动刷新。
6. 作为 SmartFlow 用户，我希望编辑交易时已有值能可靠加载，从而编辑交易不会重置或重复初始化表单状态。
7. 作为 SmartFlow 用户，我希望交易表单输入金额和备注时光标与文本行为稳定，从而输入体验可预测。
8. 作为开发者，我希望 View 代码专注于渲染和 Flutter 生命周期，从而页面更容易阅读和修改。
9. 作为开发者，我希望 ViewModel 拥有页面状态和用户意图处理，从而提交行为可以脱离 widget test 进行单元测试。
10. 作为开发者，我希望 presentation 函数保持纯净无状态，从而文案、金额、图标、分组规则可以低成本测试。
11. 作为开发者，我希望字段 validator 留在 View 或可复用输入组件，从而简单输入校验不会让 ViewModel 膨胀。
12. 作为开发者，我希望 ViewModel outcome 类型避免命名为 `Result`，从而 UI 协议不会和历史业务 `Result` 混淆。
13. 作为开发者，我希望命令式 application API 用内部异常表达预期业务失败，从而减少重复的 result 分支判断。
14. 作为开发者，我希望纯函数和 `tryParse` 类 helper 保留值返回失败模式，从而普通判断和组合仍然显式。
15. 作为开发者，我希望事务 runner 的目标接口对异常友好，从而回滚直接使用数据库事务机制。
16. 作为开发者，我希望已知持久化冲突能转换成业务异常，从而幂等冲突和版本冲突按预期失败处理。
17. 作为开发者，我希望未知基础设施失败不被误标记为业务错误；用户命令中只展示未知错误文案，命令边界之外进入页面加载错误或全局异常处理。
18. 作为开发者，我希望内部异常携带稳定字符串 code，从而测试、日志和展示映射不依赖中文 message。
19. 作为开发者，我希望错误 code 按领域或调用类型分组，从而避免一个持续膨胀的全局 enum。
20. 作为开发者，我希望 UI 反馈方式留在 View 或全局 UI 处理层，从而 ViewModel 不知道 snackbar、dialog、banner 或 fullscreen 组件。
21. 作为开发者，我希望可复用 helper 按语义归属放置，从而项目不会积累泛化的工具目录。
22. 作为开发者，我希望工程文档按主题拆分，从而 agent 和开发者都能快速找到分层、MVVM、错误处理、测试和命名规则。
23. 作为实现 agent，我希望有交易表单参考实现，从而后续 feature 重构可以遵循具体模式。
24. 作为实现 agent，我希望 ViewModel 和 presentation 的测试边界被清楚记录，从而测试覆盖正确层级。
25. 作为实现 agent，我希望迁移按触达式推进而不是一次性全量重构，从而架构演进不会干扰无关页面。
26. 作为维护者，我希望全局异常处理先做到捕获、记录和兜底展示，从而应用具备基础安全网但不过度复杂。
27. 作为维护者，我希望字段校验和业务校验清晰分离，从而 UI 规则和账务核心规则不会混在一起。
28. 作为维护者，我希望 ViewModel state 使用不可变对象，复杂 state 用 Freezed 生成，从而状态更新可预测且可测试。
29. 作为维护者，我希望页面级 provider 聚合放在 feature 内，从而 app 级 provider 不会变成中央状态仓库。
30. 作为维护者，我希望后续实现拆成可独立领取的 issue，从而 agent 可以按垂直切片实施。

## 实现决策

- 工程文档拆分为简洁总览和面向主题的 engineering 子文档。
- Feature MVVM 建立在现有分层架构之上，不新增 `model` 目录；Model 指现有 application / domain / read model 体系。
- ViewModel 按页面级用户工作流建立，不按 widget 机械拆分。
- View 拥有 Flutter 生命周期对象、UI 渲染、导航、dialog、snackbar、focus、controller、form key 和字段级内联校验展示。
- ViewModel 拥有页面状态、用户意图、页面级提交编排、command 构造、loading/submitting 状态和内部异常映射。
- ViewModel 负责复杂页面的动态渲染 view state，包括字段可编辑状态、按钮显示、禁用原因、banner 语义、当前选择、加载状态和提交状态。
- ViewModel 负责页面事件到 application command 的转换；类型 / 归属分发默认作为 ViewModel 私有函数或私有类存在。
- 路由参数只作为页面身份或初始化信号，不直接决定复杂渲染规则，也不承载业务行为分发逻辑。
- 组件工厂只用于拆分差异明显的 UI 结构，不作为跨业务域 command 分发机制。
- 不为了单个页面新增公开 policy / handler 契约；只有多个页面稳定复用同一套页面无关动作协议时，才提升为共享 handler 或策略对象。
- ViewModel state 使用不可变对象。复杂 state 使用 Freezed，不手写大量 `copyWith`。
- 页面级 provider 聚合和 ViewModel provider 移到对应 feature 内，不继续堆积到 app 级 provider。
- Reactive 页面从 ViewModel 暴露单一页面级 UI state。View 不直接组合多个底层 query provider。
- presentation 是无状态、无副作用的转换层，用于格式化、分组、展示文案、图标 key 和展示语义。
- presentation 优先返回展示语义而不是 Flutter 视觉值；实际颜色、字号、主题映射由 View 或业务组件完成。
- 字段使用 Flutter `Form` / `FormField.validator` 机制校验。可复用 validator 按语义归属放置。
- View 在调用 ViewModel submit 前先执行表单校验。ViewModel 仍执行 command 前置检查，防止绕过 UI 提交非法 state。
- ViewModel 到 View 的提交协议使用 `SubmitOutcome`、`UiActionOutcome` 等 UI 语义命名，不使用 `Result`。
- 命令式 application API 逐步迁移为用内部异常表达预期业务失败。
- 纯函数、`tryParse`、可选转换、非 mutating 预检或规则校验和批量校验可以继续使用值返回失败，不强制抛异常；返回类型应优先使用场景专用 violation / validation report，而不是通用 `Failure`。
- 校验产物和错误产物分离：violation / validation report 表达规则判断结果；`BusinessException`、`InfrastructureException`、`UiError` 和错误 code 表达命令或调用失败后的错误语义。
- violation 可以比错误 code 更贴近具体规则；映射为内部异常或 UI 错误语义时，再归并到稳定外部处理类别。
- 失败语义命名只作为软约定。返回 violation / validation report 的校验方法可使用 `validate`、`check`、`evaluate`；失败时抛内部异常的方法优先使用 `ensure`、`require` 或具体命令动词。
- 内部异常基础类型为 `BusinessException` 和 `InfrastructureException`。
- 内部异常携带稳定命名空间字符串 code 和 fallback message。
- 错误 code 使用 `<domain>.<subject>.<reason>` 风格字符串，不使用数字码。
- 错误 code 按领域或调用类型分组，不引入持续膨胀的全局大 enum。
- 已知持久化冲突可以在 repository 或 adapter 边界局部转换成内部异常，例如影响行数为 0、幂等表唯一冲突或版本冲突。不要给每条 SQL 或每个 repository 方法套通用 guard。
- 未知数据库异常不包装为业务失败；在用户命令链路中由 ViewModel 的普通 `Exception` 兜底为未知错误，在非命令链路中进入页面加载错误或全局异常处理。
- 事务 runner 目标接口对异常友好，直接返回 body 结果，不再包装 `Result`。
- Request-Response 型 ViewModel 先捕获 `AppException` 并映射为 UI 语义错误或 outcome failure，再捕获普通 `Exception` 并返回未知错误。
- ViewModel 不捕获 `Error`，例如 `StateError`、`TypeError` 和断言错误；这类错误交给全局异常处理。
- 暂不引入 `BaseViewModel` 或通用 submit helper 处理 `submitting`、`isLoading`、`SubmitOutcome` 等样板；待多个页面演化出稳定模式后再以组合式 helper 优先收口。
- `UiError` 只包含错误语义，不包含 snackbar、dialog、banner、inline、fullscreen 等展示指令。
- View 根据页面上下文决定展示 snackbar、dialog、全屏占位、内联字段反馈或 banner。
- 全局异常处理先建立最小闭环：捕获、记录、兜底展示，不做复杂业务恢复。
- 禁止新增泛化 `utils` 或 `helper` 目录。重复 helper 按语义归属放置。
- 交易表单作为第一个参考实现，因为它同时覆盖表单状态、编辑初始化、command 构造、submit outcome 和测试。
- 迁移采用触达式策略。既有 `Result` API 和页面不做一次性全量迁移。
- 本 PRD 不预期涉及数据库 schema 变更。

## 测试决策

- 测试应验证外部行为和稳定架构契约，不测试私有实现细节。
- domain 测试继续覆盖纯账务核心不变量和领域服务行为。
- application 测试覆盖命令编排、事务行为、内部异常传播和已知持久化冲突转换。
- infrastructure 测试使用 in-memory Drift 或等价替身验证 repository / adapter 行为。
- feature ViewModel 测试覆盖状态转换、command 前置检查、command 构造行为、内部异常映射和 submit outcome。
- feature ViewModel 测试覆盖 view state 派生，包括字段可编辑状态、按钮显示、禁用原因和页面入口显示。
- 业务行为分发测试通过页面语义事件后的可观察 outcome、fake service 调用或 state 变化验证，不测试 ViewModel 私有分发类本身。
- presentation 测试覆盖格式化、分组、展示文案、图标语义和纯展示转换。
- widget test 覆盖渲染、`Form` / `FormField.validator` 行为、controller 同步和交互连线。
- 全局异常处理测试验证内部异常在 ViewModel 边界被处理，用户命令中的普通 `Exception` 被兜底为未知错误，`Error` 和未处理异步异常进入全局处理。
- 交易表单参考测试应覆盖新建、编辑初始化、字段非法阻断、提交成功、业务异常失败、普通 `Exception` 兜底未知错误和 controller 同步行为；#2 已提供日常支出 ViewModel unit test 和交易表单 widget test 先例，后续交易类型按同一 seam 补齐。
- 现有 domain unit test、core value object test、feature widget test 和 transaction form test 可作为先例。新增 ViewModel test 应使用 ProviderContainer override 或 fake application service，而不是完整 widget test。

## 不在范围内

- 单个 issue 或首个实现切片内一次性迁移所有页面到 MVVM；页面迁移应通过后续 issue 按触达式逐步推进。
- 单个 issue 或首个实现切片内一次性移除所有历史 `Result` 和 `Failure` 类型。
- 单个 issue 或首个实现切片内一次性迁移所有 application command API 到内部异常。
- 完整网络 / 同步架构设计。
- 复杂全局错误恢复、错误队列或自动状态恢复。
- 错误文案国际化。
- 数据库 schema、migration 或持久化模型变更。
- 表单或反馈组件的大规模视觉重设计。
- 单个 issue 或首个实现切片内一次性重写所有已有 helper；helper 收口应随页面和组件迁移逐步完成。
- 不新增 PRD 级总括 issue；后续优先更新既有 issue，只有出现新的独立迁移范围时再补充迁移 issue。

## 补充说明

- 后续 issue 应保持可独立领取。
- 工程文档已经记录当前决策，实现过程中如出现新约束应同步更新。
- 后续 issue 创建或调整后建议使用 `ready-for-agent` 状态或标签。

## #12 补充验收标准

- 审计并清理迁移期双轨命名，例如 `runValue`、`persistPostingValue`、`xxOrThrow` 等只表达返回风格的方法名。
- 异常式命令主路径应占用语义最自然的方法名；旧 `Result` 兼容路径如仍需保留，应显式带 `Result` 后缀或随迁移删除。
- 不应让新主路径长期携带 `Value`、`OrThrow` 等实现风格后缀。

## Issue 拆分

- [#1 基础错误协议与 ViewModel outcome 契约](https://github.com/shxzzxz/smartflow/issues/1)
- [#2 交易表单 MVVM 参考切片：日常支出保存路径](https://github.com/shxzzxz/smartflow/issues/2)
- [#3 交易表单补全：编辑、收入、转账、借入、报销垫付](https://github.com/shxzzxz/smartflow/issues/3)
- [#4 交易表单输入与 helper 收口](https://github.com/shxzzxz/smartflow/issues/4)
- [#5 全局异常处理最小闭环](https://github.com/shxzzxz/smartflow/issues/5)
- [#6 交易详情页 ViewModel 迁移：动态渲染与业务行为分发](https://github.com/shxzzxz/smartflow/issues/6)
- [#7 账户与分类表单迁移到 ViewModel outcome](https://github.com/shxzzxz/smartflow/issues/7)
- [#8 信贷合同编辑表单 MVVM 与错误处理迁移](https://github.com/shxzzxz/smartflow/issues/8)
- [#9 信贷还款相关表单迁移](https://github.com/shxzzxz/smartflow/issues/9)
- [#10 日历页 Reactive ViewModel 与 presentation 收口](https://github.com/shxzzxz/smartflow/issues/10)
- [#11 首页 Reactive ViewModel 与交易行 presentation 收口](https://github.com/shxzzxz/smartflow/issues/11)
- [#12 历史 Result/Failure 迁移审计与剩余切片拆分](https://github.com/shxzzxz/smartflow/issues/12)
- [#13 helper 重复审计与收口完成度检查](https://github.com/shxzzxz/smartflow/issues/13)
