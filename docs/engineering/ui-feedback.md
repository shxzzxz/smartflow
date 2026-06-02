# UI 错误展示

本文档定义 View 如何展示 ViewModel 暴露的错误状态。ViewModel 不决定 snackbar、dialog、banner 等 UI 形态。

## 基本原则

- ViewModel 输出错误语义，例如 `UiError(code, message, fieldErrors)`。
- View 根据页面上下文决定展示方式。
- `UiError` 不包含 snackbar / dialog / banner / fullscreen 等展示类型。
- 非预期异常由全局错误处理接管，不在页面 ViewModel 中吞掉。

## 展示方式

- 全屏占位：页面加载失败、关键数据不存在、页面无法继续渲染。
- 内联提示：表单字段错误、输入格式错误、可定位到具体字段的校验失败。
- Snackbar：一次性操作失败或成功提示，例如保存失败、删除失败、导出完成。
- Dialog：需要用户确认、需要阻断当前流程、错误影响较大且需要明确反馈。
- Banner：持续性页面或全局状态，例如离线、同步异常、恢复备份后的全局提示。

## MVVM 边界

字段级错误使用 Flutter `Form` / `FormField.validator` 机制，由 View 或输入组件控制内联展示。ViewModel 可以区分 load state 和 submit outcome，但不指定具体展示组件，不默认持有字段级错误状态。
