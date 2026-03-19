# ConnFox

ConnFox 是一个面向 macOS 的 Flutter 桌面数据库客户端。
第一阶段先把 MySQL 做扎实，架构上从一开始就预留 PostgreSQL、SQLite、SQL Server 等后续驱动接入点。

当前你的 Flutter 还没安装完成，所以这个仓库先做了两件事：

- 补好项目骨架和示例工作台界面
- 把多窗口、多 Tab、连接管理、结果面板这些核心能力先按可扩展方式规划好

目前已经补到第三件事：

- 连接配置页、驱动抽象和 mock 查询执行链路
- 表设计器、数据编辑器、表关系图页面骨架
- SQL 编辑器、常用 SQL 模板入口和工作台快捷键
- 本地自动保存、备份导出和导入恢复骨架

## 目标体验

- 支持多个连接窗口
- 每个窗口支持多个 SQL Tab
- 左侧连接/Schema 浏览，中间编辑器和结果区，右侧历史/片段/操作面板
- 支持建表、改表、编辑表数据、查看表关系图
- 支持把连接信息和 SQL 工作区落到本地，并允许导出 / 导入恢复
- 常用数据库客户端能力尽量对齐 Beekeeper 高级版的主流体验
- 桌面端优先，交互流畅，结构清晰，后续方便扩数据库类型

## 当前仓库内容

- `lib/`：Flutter 桌面客户端初始壳层和示例工作台
- `docs/architecture.md`：产品和技术架构草案
- `docs/roadmap.md`：分阶段实施路线
- `tool/bootstrap_macos.sh`：Flutter 安装完成后补齐 macOS 工程的脚本

## Flutter 装好之后怎么接上

在仓库根目录执行：

```bash
./tool/bootstrap_macos.sh
flutter run -d macos
```

这个脚本会做下面几步：

```bash
flutter config --enable-macos-desktop
flutter create --platforms=macos .
flutter pub get
```

## 这版骨架先解决什么

- 先把桌面端产品结构捋顺
- 先把多窗口 / 多 Tab 的状态模型建起来
- 先做 MySQL-first 的 UI/workbench 壳层
- 先把 Connection Center、Driver Registry、QueryExecutionService 串起来
- 先把表设计 / 数据编辑 / 关系图入口和页面骨架搭出来
- 先把 SQL 编辑、运行、格式化和 Tab 快捷键手感做顺
- 先把本地自动保存、备份文件导出和恢复入口接出来
- 后面等 Flutter 安装完成，再接真实连接、驱动、Keychain、导出、SSH/SSL 等能力

## 推荐阅读顺序

1. `docs/architecture.md`
2. `docs/roadmap.md`
3. `lib/features/workbench/workbench_page.dart`
