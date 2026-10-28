# 持久化与版本演进契约

SmartFlow 以数据库 schema v49、逻辑备份 format 3 / `backupSchemaVersion` 1 作为第一个正式基线。本文件定义开发时必须遵守的实现步骤。

## 当前支持范围

- 新建数据库：直接创建 v49 完整 schema。
- 已有数据库：仅支持 v49。低于 v49 的数据库明确拒绝打开。
- 备份恢复：接受 `formatVersion = 3` 且 `backupSchemaVersion = 1` 的备份。
- 备份中的数据库 `schemaVersion` 只记录导出环境，不参与兼容判断。
- 交易导入：账户与分类目标统一使用 `ImportTargetDescriptor`，不使用粗粒度兼容 `kind`。

当前基线快照位于 `drift_schemas/drift_schema_v49.json`。

## 数据库变更流程

1. 修改 Drift 表定义，并把 `AppDatabase.schemaVersion` 增加 1。
2. 只新增本版本到下一版本的固定步骤，不改写已有步骤。
3. 迁移回调使用对应版本的 schema，不读取当前 `AppDatabase` 表 getter。
4. 迁移代码不得导入当前领域实体或依赖当前枚举穷举。
5. 使用 Drift 导出新版本快照：

```powershell
fvm dart run drift_dev schema dump lib/infrastructure/database/app_database.dart drift_schemas/
```

6. 生成步骤辅助代码：

```powershell
fvm dart run drift_dev schema steps drift_schemas/ lib/infrastructure/database/migration/schema_versions.dart
```

7. 生成旧版本测试数据库：

```powershell
fvm dart run drift_dev schema generate drift_schemas/ test/generated_migrations/
```

8. 使用 `SchemaVerifier.startAt(from)` 和 `migrateAndValidate(db, to)` 验证结构，并补充关键数据断言。

## 测试边界

- 每个相邻版本至少有一个单步迁移测试。
- 数据转换测试只覆盖会产生业务语义变化的高风险版本。
- 完整链路只验证最早支持版本到最新版，以及少量历史高风险起点，不穷举所有版本组合。
- 迁移失败必须验证事务回滚和原数据库版本不变。

## 枚举与 wire code

- `textEnum` 或备份中的既有文本值从 v49 起视为稳定的持久化 code。
- 重命名领域枚举时，默认保持 wire code 不变。
- 确实需要改变 wire code 时，新增显式数据库迁移或备份格式迁移，并增加旧 code 的恢复测试。
- 不使用 `intEnum` 序号承诺持久化身份，避免枚举插入或重排造成静默错读。

## 备份格式变更

- `formatVersion` 表示包结构、manifest 和文件组织方式；`backupSchemaVersion` 表示业务表、字段和 wire code 组成的逻辑数据契约。
- 当前只接受 format 3 / `backupSchemaVersion` 1。
- 数据库 schema 单独增加时不修改 `backupSchemaVersion`，因此 v49 数据库产生的同契约备份可以由 v50 恢复。
- 新增、删除、重命名导出表或字段，或者改变 wire code 时，提高 `BackupManifest.currentBackupSchemaVersion`。
- 提高备份版本时，为每个相邻版本增加不可变的 `vN -> vN+1` 数据迁移，把旧备份转换为当前快照后再执行现有完整校验和恢复。
- 最新解析器只处理当前 `backupSchemaVersion`；历史迁移步骤保留固定旧字段和 wire code 的处理规则，不导入当前领域实体或 `AppDatabase` 表定义。
- 包结构发生变化时使用 `formatVersion`，不得通过提高 `backupSchemaVersion` 代替文件格式迁移。

## 交易导入接口

- `ImportTargetDescriptor` 是导入目标名称、能力和账户画像的唯一契约。
- 删除旧粗粒度 `ImportMappingTargetKind` 与 `ImportLedgerTargetKind` 后，不得再次增加兼容回退字段。
- 外部来源文件格式、来源字段兼容和指纹算法版本保持在导入来源边界内，与 SmartFlow 数据库版本独立演进。
