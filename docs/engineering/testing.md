# 测试规则

测试目录随结构演进逐步镜像：

```text
test/application/
test/domain/
test/infrastructure/
test/feature/
```

数据库与基础设施测试放在 `test/infrastructure/`。

## 分层测试

- `domain/` 测试用纯 Dart unit test。
- `application/` 测试验证用例编排、事务失败传播和跨领域协调。
- `infrastructure/` 测试用 Drift in-memory 或对应技术替身。
- `feature/` 测试优先 mock provider / application 用例。

## MVVM 测试

- ViewModel 的状态转换、页面级校验、command 组装、submit 成功 / 失败和 application failure 映射用 unit test 覆盖。
- presentation 的格式化、分组、展示语义转换用普通 unit test 覆盖。
- widget test 只覆盖关键渲染、控件同步和用户交互，不用来间接验证大段 ViewModel / application 流程。
