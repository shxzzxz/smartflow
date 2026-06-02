# 分层、目录与导入边界

本文档定义 SmartFlow 的工程分层、目录模板、事务边界、Drift 单库规则和 import 边界。

## 分层职责

### application

application 是**用例编排层**，不是某个业务域的附属实现细节。

职责：

- 表达一个具体用户用例。
- 编排一个或多个领域。
- 控制事务边界。
- 调用 domain service / aggregate / port。
- 定义并组装查询 read model、query scope 与响应式查询投影。
- 返回 UI 或其它调用方需要的结果 DTO。

排除：

- 不承载领域不变量。
- 不把另一个 application use case 当成可复用领域能力。
- 不直接依赖 Drift / SQL 实现；纯读侧通过 application query interface 由 infrastructure 提供实现。

### domain

domain 负责领域规则与不变量。判断标准：

```text
如果规则被破坏会让记账数学错、借贷不平、余额错算、状态机非法跃迁，归 domain。
如果只是流程编排、事务控制、数据刷新、页面展示、调用顺序，归 application 或 feature。
```

domain service / aggregate 可以依赖**本领域定义的 ports** 获取领域事实。不要把“domain 不依赖 infrastructure 实现”误解为“domain 不能获取领域事实”。

例如复杂账务原语所需事实属于账务领域知识：

- 退款需要父交易、原分录结构、已退款总额。
- 报销结案需要垫付交易、已到账总额、剩余应收、原支出分类。
- 转账和还款由账务核心解析利息 / 手续费 / 优惠等系统科目；业务域只传递已确定金额和参与账户。
- 更正 / 冲销需要原交易详情和分录结构。

这些事实应由 `domain/ledger` 的领域服务通过 `domain/ledger/port` 获取，或由账务领域明确声明为上下文对象；不要让 `credit` / import / UI 等调用方复制账务事实加载规则。

### infrastructure

infrastructure 实现 port 与 query interfaces，不承载业务决策。

职责：

- Drift repository / query source 实现。
- SQL 表达式与 mapper。
- application query interface 的 Drift / SQL 实现。
- RPC / 文件 / 平台能力实现。
- 数据库事务执行器实现。

排除：

- 不解释业务原语。
- 不编码业务流程字面量。
- 不让兄弟业务域直接调用自己的实现类。

### feature

`feature/` 按页面与用户工作流组织。UI 不强行归属到 DDD 业务域。

例如：

- `home` 可能消费账务、预算、信贷摘要。
- `calendar` 可能消费交易、还款计划和预算。
- `transactions` 是账务入口，但详情页可能通过 action policy 接入其它业务域。

## 业务域与角色

业务域按领域语言命名，主要出现在 `domain/`、`application/`、`infrastructure/` 的层内目录。

| 业务域 | 角色 | 说明 |
| :--- | :--- | :--- |
| `ledger`（账务核心） | Shared Kernel | 账户、交易、分录、过账规则、账务流图原语；查询投影位于 application query side |
| `credit`（信贷） | 独立业务域 | 分期合同 / 计划 / 还款状态机；调用账务核心完成入账 |
| `budget`（预算） | 薄业务域 | 预算配置与预算查询，当前不强制完整三层 |
| `preset`（预设记账） | 独立业务域候选 | 周期记账、模板记账，待业务复杂度明确后落地 |
| `analytics`（分析） | 薄业务域 / 查询域 | 趋势、洞察、预测、报告投影 |

重域使用完整分层：

```text
application/ledger + domain/ledger + infrastructure/ledger
application/credit + domain/credit + infrastructure/credit
```

薄域允许先保持轻量结构；当长出复杂不变量、状态机或跨用例规则，再拆完整分层。

## 目录结构模板

业务域可以在 `application/<domain>/` 根部提供 `<domain>_command_api.dart`、`<domain>_query_api.dart`、`<domain>_query_port_api.dart` 等窄 facade 文件，但 facade 文件名不进入目录模板。

```text
lib/
├── main.dart
├── app/                                  # MaterialApp、router、顶层 provider、bootstrap、依赖装配
├── core/                                 # 无业务语义、无 UI 的基础能力（money / time / result / errors / patch 等）
├── application/                          # 用例编排层
│   ├── <domain>/                         # ledger / credit / budget ...
│   │   └── <capability>/                # account / category / transaction / metrics ...
│   │       ├── command/                 # 写用例 + command model；无写侧时可省略
│   │       └── query/                   # 读用例 + query/read model；读侧 port 放 query/port
│   │           └── port/                # 读侧 application port；无 port 时可省略
│   └── shared/                          # 事务执行抽象等 application 共享能力
├── domain/                               # 领域层：按业务域分子目录
│   ├── <domain>/
│   │   ├── entity/
│   │   ├── valobj/
│   │   ├── service/
│   │   └── port/
│   └── ...
├── infrastructure/                       # ports 实现与技术细节
│   ├── <domain>/
│   │   ├── repository/
│   │   ├── mapper/
│   │   └── sql/
│   └── database/                         # Drift 单库装配、tables、migrations、seed、数据库工具
├── feature/                              # 页面与 UI 状态编排
├── design_system/                        # 项目级设计系统
├── widget/business/                      # 跨 feature 复用的业务组件
└── l10n/
```

feature 内部按需使用：

```text
feature/<feature>/
├── page/
├── widget/
├── provider/
├── view_model/
├── presentation/
└── action_policy/                        # 可选；目前主要用于 transaction feature
```

## 事务与 Drift 单库

事务边界属于 application 用例。domain 不知道事务，infrastructure 只实现事务机制。

当前 `TransactionRunner` 可以作为 application 与 infrastructure 之间的事务抽象。目标规则：

```text
一个 application use case 拥有一个顶层事务边界。
application use case 不应通过调用另一个完整 application use case 来复用领域能力。
跨域用例在自己的事务内组合多个 domain service / ports。
```

跨域用例由最外层 application use case 拥有提交 / 回滚权。

`TransactionRunner` 只负责承接这个边界：

- 目标接口为 `Future<T> run<T>(Future<T> Function() body)`。
- 命令式业务失败抛内部异常，由底层事务机制自然回滚。
- 非业务异常由底层事务机制回滚后继续抛出，不转成业务失败。
- repository / service 不自行开启完整用例事务；事务只在 application 编排层收口。

过渡期代码中可能仍存在 repository / store 内部自行开启数据库事务的情况；这属于历史实现细节，不是目标边界。重构时应逐步收敛为 application 用例控制事务，infrastructure 写入方法参与当前调用链，不自行表达完整用例事务。

模块化不等于 Drift schema 分散化。以下能力必须保持应用级集中管理：

- `AppDatabase`
- `schemaVersion`
- migration strategy
- 表注册
- 内置数据初始化

集中位置：

```text
lib/infrastructure/database/app_database.dart
lib/infrastructure/database/database_provider.dart
lib/infrastructure/database/migration/*
lib/infrastructure/database/builtin_data.dart
lib/infrastructure/database/table/*
```

禁止把迁移版本号和 schema 管理拆进各业务域，避免迁移撞号和装配混乱。

## Import 边界

- `domain/*` 不依赖 `application/`、`infrastructure/`、`feature/`、`app/`、Drift、Riverpod。
- `domain/*` 不依赖 application query DTO / read model / scope filter。
- `application/*` 可以依赖一个或多个 `domain/*`；`application/<domain>/<capability>/query` 可定义纯读侧查询接口、查询参数与 read model。
- `infrastructure/*` 实现 `domain/*/port` 和 application query interfaces，可以依赖对应接口和模型。
- `feature/*` 不直接依赖 `domain/*` 或 `infrastructure/*`，通过 application provider / use case / query 使用业务能力。
- `domain/ledger` 不依赖 `domain/credit`、`domain/budget` 等兄弟业务域。
- 兄弟业务域之间如需组合，由 application 用例编排。
