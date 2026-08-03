# 分类迁移、统计与交易查询设计

> 状态：主方案已落地；落地后审查问题已完成决策，待在后续会话按第 7 节实施选定修复。
>
> 本文替代“归档分类用于查询归并”的方向；三部分主路径已实现并通过现有验证，审查发现的边界问题已完成讨论，其中部分需要修复，部分明确暂缓或不处理。

## 实施进度

- [x] 第一部分：分类迁移与安全删除。分类迁移以整个顶层交易组为原子单位重写；有交易引用或子分类时禁止删除，并移除历史归档归并模型。
- [x] 第二部分：分类统计。将活跃两层分类树的归并收口在应用查询层；一级自身金额以“未细分”项呈现。
- [x] 第三部分：交易查询与列表读模型。支持分类/结算账户独立筛选，并替换列表投影。

## 1. 已确定的业务语义

### 1.1 分类删除与交易迁移

- 删除分类不再归档分类，也不保留第三层归并树。
- 分类有任何交易分录引用时，禁止删除；UI 提示用户先迁移交易。
- 交易迁移是独立的分类管理操作：用户选择一个源分类和一个同类型、活跃的目标分类，将所有受影响交易的分类改为目标分类。
- 迁移成功后，历史交易的当前分类事实就是目标分类；保留旧分类对用户与统计均无收益。
- 迁移一次只处理一个分类，不递归迁移分类树。
- 一级分类须先处理或删除其二级分类，才能删除；删除操作只处理无交易引用且无子分类的单个分类。
- 迁移与删除不捆绑：迁移完成后由用户自行再次发起删除。
- v25 升级将旧归档分类的物化余额合并到历史归并目标，改写其分录、报销分类事实与导入分类映射，并删除旧归档节点。

### 1.2 批量迁移接口与事务

新增应用层模块 `CategoryTransactionMigrationAppService`（名称可按实现目录微调）：

```dart
abstract interface class CategoryTransactionMigrationAppService {
  Future<CategoryTransactionMigrationResult> migrate(
    CategoryTransactionMigrationCommand command,
  );
}

class CategoryTransactionMigrationCommand {
  const CategoryTransactionMigrationCommand({
    required this.sourceCategoryId,
    required this.targetCategoryId,
  });

  final String sourceCategoryId;
  final String targetCategoryId;
}
```

- 对外接口只表达“源分类迁移到目标分类”，不暴露交易组、分录或批处理细节。
- 实现先校验源、目标分类均为活跃分类，且收入/支出类型一致。
- 实现查询命中源分类的顶层交易组；按交易用途分派到既有 `TransactionEditAppService` 的支出、收入或报销垫付编辑能力。
- 单笔编辑继续复用 `TransactionGroupRewriteService`，从而保留交易组重写、退款/报销派生分录同步和余额维护规则。
- 整批处理包在一个外层 `TransactionRunner` 中。任何一笔重写失败即整体回滚；不产生部分迁移。
- 不为此提前引入后台任务状态机。后续以代表性数据量压测决定是否需要进度 UI 或可恢复任务。

## 2. 分类统计

### 2.1 统计口径

活跃分类树恒为两层，一级和二级分类都允许直接记账。

若一级分类 `A` 的直接金额为 `a`，二级分类 `B` 的直接金额为 `b`：

```text
A.total = a + b
B.amount = b
```

一级分类自身的直接金额以一个“未细分”二级统计项呈现；该项使用 `A` 的真实分类 ID。这样二级统计项之和始终等于一级分类总额。

- 统计返回统计区间内存在命中分录的物理分类；借贷净额为零但存在活动的分类仍返回。
- 一级分类只要自身或任一二级分类存在统计活动就返回；一级总额允许因不同物理分类正负抵消而为零。
- “未细分”与真实二级分类采用相同规则：有命中分录即返回，金额允许为零；完全没有命中分录的节点不返回。

### 2.2 分层与读模型

保留数据库按物理分类聚合分录金额的能力：

```text
SQL：entries 按真实 category account_id 聚合
  ↓
应用层：加载活跃二层分类树，计算一级累计额与未细分项
  ↓
分类统计读模型：一级分类 total + 二级分类 own amount
  ↓
前端：纯渲染，不解析 parentId 或账户快照拼树
```

不得继续让 `statistics_presentation.dart` 沿 `parentId` 组装分类统计。分类树归并属于应用查询层。

数据库层的分类聚合仍是正确的性能边界：按分类粒度聚合，而不是加载每笔交易后再计算。

### 2.3 统计钻取

- 用户点击一级分类 `A`：流水查询匹配 `{A, A 的全部二级分类}`。
- 用户点击二级分类 `B` 或“未细分”项：只匹配 `{B}` 或 `{A}`。
- 前端将用户所选活跃分类及匹配范围作为一个分类选择提交；常规选择展开子树，“未细分”选择仅匹配一级自身。分类子树展开仍由应用查询层完成，匹配范围不是第三个独立筛选维度。
- 分类贡献流水与账户详情流水采用相同的实际交易语义，查询父交易和子交易（`topLevelOnly = false`）；命中子交易时直接返回该子交易，不反查或归并为顶层交易组。

## 3. 交易流水查询

### 3.1 查询接口语义

第一版对外只支持一个分类筛选与一个结算账户筛选：

```dart
TransactionListQuery(
  category: CategorySelection.withDescendants(categoryId),
  settlementAccountId: settlementAccountId,
  occurredFrom: from,
  occurredUntil: until,
)
```

- `category`：一个用户选择的活跃分类及其匹配范围。常规一级分类在应用层展开为自身与全部二级分类；二级分类展开为自身；“未细分”使用 `CategorySelection.ownOnly` 只匹配一级自身。
- `settlementAccountId`：用户选择的结算账户，不表达“任意账户 ID”。
- 应用层校验结算账户必须是活跃的资产或负债用户账户；不存在、归档或系统账户按无匹配结果处理。
- 两个维度同时存在时取交集；同一维度后续需要多选时，内部可以自然扩展为集合，但当前 UI 与外部接口不提前支持多选。
- `topLevelOnly` 只控制返回顶层交易还是实际父子交易，不改变分类与结算账户都通过分录账户 ID 匹配的基础语义。首页使用顶层交易；账户详情与统计贡献流水使用实际父子交易。

应用层负责：加载分类快照、校验/展开分类，并将已展开的物理分类 ID 和结算账户 ID 交给仓储。仓储不理解分类树。

### 3.2 数据库查询

每个筛选维度对应一个独立的分录子查询；不能把分类和结算账户 ID 混入一个 `IN` 集合。

```sql
SELECT t.*
FROM transactions t
WHERE t.parent_transaction_id IS NULL
  AND t.occurred_at >= :from
  AND t.occurred_at < :until
  AND EXISTS (
    SELECT 1
    FROM entries category_entry
    WHERE category_entry.transaction_id = t.id
      AND category_entry.account_id IN (:physicalCategoryIds)
  )
  AND EXISTS (
    SELECT 1
    FROM entries settlement_entry
    WHERE settlement_entry.transaction_id = t.id
      AND settlement_entry.account_id IN (:settlementAccountIds)
  )
ORDER BY t.occurred_at DESC, t.id DESC;
```

任一筛选维度缺省时省略对应条件。

Drift 中可以复用现有 `entries.transactionId` 子查询模式，并对分类与结算账户各调用一次：

```dart
void andEntryMatch(
  SimpleSelectStatement<$TransactionsTable, TransactionRow> select,
  Set<String>? accountIds,
) {
  if (accountIds == null) return;
  final ids = _db.selectOnly(_db.entries, distinct: true)
    ..addColumns([_db.entries.transactionId])
    ..where(_db.entries.accountId.isIn(accountIds));
  select.where((transaction) => transaction.id.isInQuery(ids));
}
```

两个独立子查询等价于两个 `EXISTS`：表达“结算账户命中 且 分类命中”，也避免直接 `JOIN entries` 产生一笔交易多行的重复结果。

现有索引 `entries(account_id, transaction_id)` 与顶层交易时间排序索引已覆盖这一访问路径，无需因本设计新增索引。

### 3.3 订阅刷新

交易列表订阅必须同时响应：

- transactions、entries 的变化；
- 分类账户的名称、图标、父子关系变化。

分类变化会影响列表展示分类，也可能改变一级分类筛选展开出的二级分类集合。因此 `TransactionQueryService` 必须监听分类快照变化后重新规范化查询并重新投影；不能只监听交易表。

## 4. 列表读模型

### 4.1 目标形状

```dart
class TransactionListReadModel {
  const TransactionListReadModel({
    required this.id,
    required this.businessPurpose,
    required this.occurredAt,
    required this.primaryAmount,
    required this.isExcludedFromStats,
    required this.isExcludedFromBudget,
    required this.category,
    required this.settlementEntries,
    required this.adjustments,
  });

  final String id;
  final BusinessPurpose businessPurpose;
  final DateTime occurredAt;
  final Money primaryAmount;
  final bool isExcludedFromStats;
  final bool isExcludedFromBudget;
  final TransactionCategoryRef? category;
  final List<TransactionSettlementEntryRef> settlementEntries;
  final List<TransactionAdjustment> adjustments;
}
```

列表模型不再暴露领域 `Entry`、`TransactionDetailRecord`、完整账户对象，或仅供详情页使用的备注、对手方、父交易 ID 与子交易计数。

### 4.2 分类投影

```dart
class TransactionCategoryRef {
  const TransactionCategoryRef({
    required this.id,
    required this.name,
    required this.iconKey,
  });

  final String id;
  final String name;
  final String? iconKey;
}
```

- `category` 表示交易的主收支分类，不是从任意分录猜出的“第一个分类”。
- 日常支出、日常收入、报销垫付有主收支分类；转账、借款、还款、退款、报销到账、结束报销、期初余额与余额调整为 `null`。
- 日常支出从唯一的 `expense + debit + primaryAmount` 分录解析，日常收入从唯一的 `income + credit + primaryAmount` 分录解析；候选缺失或不唯一时退化为 `null`，不得按分录顺序任意选择。
- 报销垫付继续使用显式的 `reimbursementExpenseAccountId`。本轮不新增写侧唯一性校验，为未来多分类等演进保留空间。
- 不携带父级、排序、归档状态、余额或完整账户配置。
- 不携带 `AccountType`；`businessPurpose` 已足以决定收入/支出的展示语义，写侧负责类型合法性。
- 分类筛选不依赖该字段，始终按物理分录和查询层的分类树展开执行。

### 4.3 结算分录投影

```dart
class TransactionSettlementEntryRef {
  const TransactionSettlementEntryRef({
    required this.accountId,
    required this.accountName,
    required this.accountIconKey,
    required this.direction,
    required this.amount,
  });

  final String accountId;
  final String accountName;
  final String? accountIconKey;
  final EntryDirection direction;
  final Money amount;
}
```

它只承载非分类结算分录的列表展示信息。一般交易投影资产/负债账户；期初余额和余额调整还投影系统期初余额对手方，以表达完整流向。页面可根据 `businessPurpose` 与 `direction` 组织付款、收款、负债或应收流向；账户详情页可用 `direction + amount` 计算该账户的余额变化，而无需访问原始 `Entry`。

### 4.4 调整摘要

```dart
enum TransactionAdjustmentKind {
  refund,
  reimbursementReceived,
  repaymentInterest,
  repaymentFee,
  repaymentDiscount,
  reimbursementGapIncome,
  reimbursementGapExpense,
}

class TransactionAdjustment {
  const TransactionAdjustment({
    required this.kind,
    required this.amount,
  });

  final TransactionAdjustmentKind kind;
  final Money amount; // 恒为正；文案、正负色由 kind 决定。
}
```

- 普通支出：退款摘要。
- 报销垫付：退款、报销到账、差额摘要。
- 还款：利息、手续费、优惠摘要。
- 其他交易：空列表。

列表展示的“退 / 报 / 利 / 费 / 优 / 差收 / 差支”只消费此摘要。原始 details、退款子交易数量和报销子交易数量不再由列表模型暴露。

### 4.5 交易类型适配

| 交易用途 | 主分类 | 结算投影 | 调整摘要 |
| --- | --- | --- | --- |
| 日常支出、日常收入 | 有 | 付款或收款账户 | 支出可有退款 |
| 报销垫付 | 有 | 付款账户、应收账户 | 退款、报销到账、差额 |
| 转账、借款 | 无 | 两侧结算账户 | 通常为空 |
| 还款 | 无 | 付款、负债等结算账户 | 利息、手续费、优惠 |
| 退款、报销到账、结束报销 | 无 | 实际结算账户 | 通常为空 |
| 期初余额、余额调整 | 无 | 受影响账户及必要的系统对手方投影 | 为空 |

## 5. 范围与后续

- 本轮仅替换 `TransactionListReadModel` 与其查询、展示调用方。
- `TransactionDetail` 继续服务详情页、编辑与完整分录展示；不随列表读模型一同重构。
- 由于分类必须先迁移交易才能删除，详情读模型不会引用已删除分类；后续若重构详情读模型，应独立设计其分类与账户投影。

## 6. 实施验证

至少覆盖以下用例：

1. 有交易引用的分类删除被拒绝；迁移后可删除无子分类、无引用的分类。
2. 支出、收入、报销垫付迁移后，分类分录和关联交易组派生分录正确重写；任一步失败会整体回滚。
3. `A` 自身金额 `a`、子分类 `B` 金额 `b` 时，统计返回 `A.total = a + b`、`B.amount = b` 与金额为 `a` 的“未细分”项。
4. 完全没有命中分录的分类不返回；有命中分录但净额为零的一级、二级或“未细分”统计项仍返回。
5. 点击 `A` 的流水钻取命中 `A` 与 `B`；点击 `B` 只命中 `B`。
6. 同时筛选现金和餐饮时，只返回同时命中这两个独立分录条件的交易。
7. 分类改名、换图标或调整二级归属后，已订阅的分类流水列表重新投影；只命中子交易分类分录时返回该实际子交易。
8. 列表读模型不暴露原始 `Entry`、`TransactionDetailRecord` 或领域 `Account`；各交易用途均能构造所需的分类、结算与调整投影。

## 7. 落地后审查（2026-08-04）

审查范围为 `5e07dea...c09f8e9`。相关定向测试共 38 项通过，`fvm dart analyze` 通过；这些结果只证明现有覆盖通过，不消除下述审查发现。

### 7.1 已确定：系统分类的管理边界

当前系统分类与普通分类都使用 `AccountType.income / expense`，区别由 `systemKey` 表达：

```text
系统分类：type.isCategory && systemKey != null
可管理分类：type.isCategory && systemKey == null
```

确定规则：

- 分类迁移与删除只作用于可管理分类。
- 系统分类禁止删除，禁止作为分类迁移源，也禁止作为分类迁移目标。
- application service 必须执行强校验；UI 隐藏操作入口、迁移目标列表过滤仅作为交互约束，不能替代应用层校验。
- 系统分类继续参与统计和交易列表展示。
- 不新增“主收支分类事实”作为领域分类类型；当前只区分收入/支出类型与系统/可管理边界。

该规则解决当前高风险问题：交易目标查询会命中还款利息、手续费、优惠、报销差额收入等系统分类分录，但迁移执行器只支持日常支出、日常收入与报销垫付。禁止系统分类参与迁移后，这些派生分录不会进入错误的用途分派。

实施时至少补充：

1. 系统分类即使没有引用也不能删除。
2. 系统分类作为迁移源或目标时，在查询和重写交易前即被拒绝。
3. 系统分类不展示迁移、删除入口，也不出现在迁移目标列表。
4. application service 与 ViewModel 分别覆盖拒绝结果和 command/outcome 映射测试。

### 7.2 已确定的 Spec 问题

1. **统计钻取遗漏子交易贡献：修复。** 分类贡献流水与账户详情流水一致，使用 `topLevelOnly = false`。分类和结算账户都先按实际交易分录匹配；父交易、子交易分别作为实际流水返回，不做交易组归并。
2. **列表主分类依赖分录顺序：修复读侧。** 日常支出/收入按用途、账户类型、借贷方向和主金额解析唯一候选；缺失或不唯一时返回 `null`。报销垫付使用 `reimbursementExpenseAccountId`。不新增写侧校验。
3. **整批回滚与派生分录重写缺少真实验证：暂不补。** 当前外层迁移事务逐组调用真实编辑接口，Drift 嵌套事务语义满足异常向外传播时整体回滚；保留现有实现与测试范围。
4. **零净额分类活动：保留。** 统计项是否存在由聚合记录是否存在决定，不由净额是否为零决定。一级、二级和“未细分”项有命中分录即返回，金额允许为零。
5. **历史提交混入无关变更：不改历史。** 不重写、不拆分、不回退既有交叉提交；后续修复按问题独立提交。

### 7.3 工程规范问题决策

后续修复：

- 为 `CategoriesViewModel.migrateTransactions` 补充 command 组装及成功/失败 outcome 映射单元测试。
- application 分类统计 read model 使用 `Money`，不再暴露 `totalMinor / amountMinor`。
- `FinancialMetricsService` 的异构并行查询改用具名 future，移除 `results[index]` 与运行时 cast，同时保持并行执行。

明确不处理：

- `TransactionAdjustmentKind` 的 label 与 tone 分别表达不同展示语义，穷尽 switch 已提供编译期保护，不为合并它们新增抽象。
- 首页两个设置控件的本地 optimistic state 同步结构重复范围小、控件形态不同，且属于既有交叉提交，不在本轮抽象。

### 7.4 预算边界决策

- 账务核心的分类迁移与删除完全不感知预算；分类迁移只改写交易当前分类事实，不触发预算迁移、合并或校验。
- 分类删除不以预算引用作为账务核心前置条件。
- 预算域如何处理已删除分类属于预算功能自身的兼容与交互问题；若产品需要删除前提示或引导用户处理预算，最多由未来预算 feature / ViewModel 编排，不上升为账务核心约束。
- 撤回预算随分类删除或迁移自动迁移、同月合并的旧文档规则。

### 7.5 已同步的长期文档

- `CONTEXT.md`
- `docs/02. 核心功能.md`
- `docs/domains/ledger/核心业务规则.md`
- `docs/domains/ledger/数据模型.md`
- `docs/domains/ledger/账务核心业务设计.md`
- `docs/domains/ledger/业务场景流程示例.md`
- `docs/domains/budget/预算业务设计.md`

下一会话按第 7.1、7.2 与 7.3 的“修复”项实施；不补第 7.2.3 的数据库集成测试，不处理第 7.3 明确排除的两项，也不改写历史提交。
