# 中国行政区划数据

`china_regions.json` 来自 [province-city-china](https://github.com/uiwjs/province-city-china) 的 `@province-city-china/level` 9.0.0 数据包，采用 MIT 许可证，完整声明见本目录 `LICENSE`。数据来源及原文件 SHA-256 保存在 JSON 元数据中；包版本不代表行政区划资料年份。

应用内只保留省、市、区县三级的代码、名称和上下级关系。社保选择器只显示省、市两级；其他场景可以显示区县级。应用读取时在直辖市的省级节点下补充同名市级节点，市级包含源数据中的全部区县，例如“北京市 / 北京市 / 东城区”。此数据只辅助地区录入，不作为社保政策数据；已保存的地区文本不随快照更新改写。

更新时运行 `python tool/update_china_regions.py --version <已核对的数据包版本>`，核对来源、许可和行政区划变化，再提交快照。应用运行时离线读取，不访问数据源。
