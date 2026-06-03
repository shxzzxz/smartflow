# 命名与演进规则

## 命名约定

- 文件与目录：`snake_case`；类名：`UpperCamelCase`。
- **架构角色目录**一律单数形式（`entity / valobj / service / port / command / query / use_case / read_model / feature / widget / page / view_model / provider / presentation / mapper / repository / migration / table` 等），不写复数或 `-s / -ed` 变形。例外仅限 Drift / SQL 习惯（Drift 表类名 `Accounts / Transactions / Entries`、表注册集合沿用复数）。
- **业务/语义目录**（如 `shared / design_system / l10n`）按其本身语义命名，不机械单数化。
- **文件名**按其承载的主类型、主页面或业务概念命名，不机械单数化；同样不引入复数 / `-ed` 变形。
- 禁止新增 `utils`、`helper` 等杂物目录。重复 helper 必须按语义归入明确层级或组件，例如 `core/money`、`design_system`、`widget/business`、`feature/<feature>/presentation` 或具体 ViewModel。
- 数据库列名：`snake_case`，与 `docs/domains/ledger/数据模型` 一致。
- 金额字段：数据库层用 `_minor` 后缀，领域 / UI 层使用 `Money`。
- Riverpod provider：`<scope>Provider`。
- 业务域目录名用领域语言（`ledger / credit / budget / analytics`），不用技术词替代领域词。
- 失败语义命名只作为软约定，但方法名应让契约可预期：返回 violation / validation report 的校验方法可使用 `validate`、`check`、`evaluate`；失败时抛内部异常的方法优先使用 `ensure`、`require` 或具体命令动词。方法签名和返回类型必须表达契约，不依赖命名猜测。

## 演进规则

- **新增字段**：先改 `docs/domains/ledger/数据模型`，再改 Drift table 与迁移，同步领域模型、application DTO 与 UI。
- **新增账务核心场景（流图原语）**：先改 `docs/domains/ledger/核心业务规则` 和 `docs/domains/ledger/业务场景流程示例`；扩展 `BusinessPurpose` / `TransactionDetailType` / `SystemKey`；落地账务领域规则；按需补 application 用例和查询投影。
- **新增独立业务域**：按 [ADR-0001](../adr/0001-业务域划分与账务核心独立性.md) 的归类判断；先建 domain 规则和 port，再按业务复杂度决定是否补 application / infrastructure 完整结构。
- **新增跨域用例**：放 application 层，由最外层用例编排多个领域；不要把一个领域的 application use case 当作另一个用例的领域能力复用。
- **新增 feature**：优先只建 `page / widget / provider / view_model / presentation`；领域规则不得放入 feature。
- **新增或重构复杂页面**：遵循 feature 内 MVVM 职责边界，优先建立页面级 ViewModel 和不可变 view state；已有页面按触达式迁移，不做一次性全量重构。ViewModel 负责页面动态渲染状态和页面事件到 application command 的转换；单页面内的类型 / 归属分发保持为 ViewModel 私有实现，不预先抽成公开 policy / handler。交易表单作为优先参考切片，用于验证表单状态、编辑初始化、command 组装、提交结果和测试边界。
- **新增纯读侧查询**：优先在 `application/<domain>/<capability>/query` 定义 query / scope / read model，由 infrastructure 实现 Drift / SQL；不要为了 UI 查询把 read model 或 `TransactionScopeFilter` 放进 domain。
- **新增领域规则事实加载**：如果查询结果参与退款、报销、更正、取消等领域判定，应定义 domain port 和领域上下文，不复用 application read model。
- **性能优化**：优先在 infrastructure 查询、application projection 或索引上处理，不在页面层堆业务缓存。
