# Feature MVVM 职责边界

feature 层采用 MVVM 组织页面与交互状态，但不新增独立 `model/` 目录。MVVM 中的 Model 指既有 application / domain / read model 体系。

## 粒度

ViewModel 按页面级用户工作流建立，不按每个 widget 机械拆分。复杂表单、详情页、日历等页面可以拥有对应 ViewModel；普通展示 widget 不单独建立 ViewModel，除非它自身是跨页面复用且状态复杂的业务控件。

## View

View 负责 Flutter 渲染和 UI 生命周期对象，例如 `BuildContext`、`TextEditingController`、`FocusNode`、`GlobalKey<FormState>`、弹窗、snackbar 与导航。

View 不负责：

- 组合多个底层 query provider。
- 维护跨数据源派生状态。
- 构造 application command。
- 调用 application service 后解释业务失败。
- 维护 `_initialized` / `_editInitialized` 一类跨数据源初始化标记。

## ViewModel

ViewModel 持有普通 Dart 状态、输入值、选择项、加载 / 提交状态和可测试的用户意图处理；ViewModel 不持有 `BuildContext`，不直接执行导航或展示弹窗。

表单页面中，页面级校验、屏幕状态到 application command 的映射、application service 调用和提交状态维护属于 ViewModel。真正业务规则校验仍属于 application / domain，ViewModel 不绕过 application 直接调用 domain 或 infrastructure。

ViewModel 通过 Riverpod 注入 application service、query service 或页面级 query provider，不直接 `new` 依赖，不依赖 infrastructure。ViewModel 不直接调用 domain service；确需使用领域枚举或值对象时可以 import domain 类型，但领域行为通过 application 用例进入。

ViewModel state 使用不可变对象表达，每次状态变化发布新的 state 快照。复杂页面 state 优先使用 Freezed 生成 `copyWith`、相等比较和联合类型；简单状态可以保持轻量，但不通过可变字段暴露给 View。

编辑页的已有数据加载、read model 到表单 state 的映射、初始化幂等控制属于 ViewModel。

## Provider

`app/provider.dart` 只承担应用装配级 provider，例如 database、repository、application service 与全局 facade。页面级查询聚合、ViewModel provider 和交互状态 provider 放在对应 `feature/<feature>/provider` 或 `feature/<feature>/view_model` 下，不继续集中进 `app/provider.dart`。

## Presentation

纯展示计算放在 `feature/<feature>/presentation`，不放在 `view_model`。presentation 必须是无状态、无 Riverpod、无 application service 调用、无副作用的展示转换；它只把已有 read model / UI state 转换为展示文案、格式化金额、图标 key、排序分组或日历格子等可测试结果。ViewModel 可以调用 presentation 函数构造 UI state，presentation 不反向依赖 ViewModel。

presentation 的输出优先使用展示语义而不是具体 Flutter 视觉值。例如返回 `income / expense / neutral` 这类语义 tone、图标 key、文案或格式化金额；具体 `Color`、`TextStyle` 与 Theme 映射由 View 或业务组件完成。既有代码中直接返回 `Color` 的纯函数可作为过渡保留，新代码避免继续扩散。

## 交互模式

feature 与 ViewModel 的交互模式分三类：

- Request-Response：View 主动触发操作并等待 ViewModel 返回结果，适用于保存、删除、导出、备份等用户命令。ViewModel 返回最小结果对象，View 负责导航、snackbar、分享面板等 UI 副作用。
- Reactive State-Driven：ViewModel 监听 query / stream 并转换为 UI state，View watch state 自动重建，适用于列表、首页摘要、预算进度、统计图表等持续展示。
- Global Event-Driven：仅用于 App Shell 级一次性副作用，例如恢复备份后的应用重建、全局安全退出或 App 级更新提示。禁止用全局事件做普通 feature 间通信、列表刷新、跨页面 snackbar 或交易新增后的数据刷新；这些场景应使用 Request-Response 或 Reactive State-Driven。

Reactive 页面由 ViewModel 聚合多个底层 query provider，并向 View 暴露单一页面级 UI state。View 只处理页面级 state 的 loading / error / data 与渲染。

## 表单控件同步

表单字段值以 ViewModel state 为事实来源。`TextEditingController`、`FocusNode` 等只是 View 的输入适配器；View 在初始加载或外部状态变化时按差异同步 controller，用户输入再通过 `onChanged` / listener 更新 ViewModel state。禁止在每次 build 中无条件覆盖 controller 文本。

字段级校验使用 Flutter `Form` / `FormField.validator` 机制，由 View 或输入组件控制内联错误展示。View 在调用 ViewModel 提交前先执行 `formKey.currentState?.validate()`；ViewModel 仍保留 command 前置检查，防止绕过 UI 直接提交非法 state，但不负责字段内联展示。

validator 按复用范围放置：通用文本校验放设计系统或表单组件附近；金额、账户、分类等业务输入校验放对应业务组件附近；页面特有组合校验放 `feature/<feature>/presentation` 或 page 私有函数。validator 不进入 ViewModel，但可以复用 `core` 中的纯解析能力。
