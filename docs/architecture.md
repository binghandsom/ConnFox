# ConnFox 架构草案

## 1. 产品定位

ConnFox 要做的是一个桌面优先的数据库工作台，不是只会“连上数据库然后跑 SQL”的薄工具。

第一阶段目标：

- 平台：macOS
- 技术：Flutter Desktop
- 数据库：先 MySQL / MariaDB
- 体验：多窗口、多 Tab、常用能力完整、响应足够快

后续扩展方向：

- PostgreSQL
- SQLite
- SQL Server
- 更完整的 SSH Tunnel / SSL / 导入导出 / 数据编辑能力

## 2. 体验上优先做对的事情

如果要接近 Beekeeper 高级版的可用性，前面几版必须优先把这些东西做扎实：

- 保存连接、分组、收藏、最近连接
- 一个窗口内多个 SQL Tab
- 多个独立连接窗口
- Schema Browser
- Table Designer
- Data Editor
- Relation Graph / ERD
- SQL 编辑器
- 结果表格查看
- 查询历史
- SQL 片段 / 收藏查询
- 导出 CSV / JSON / SQL
- 只读保护、危险 SQL 确认
- 长查询取消、自动重连、超时提示

## 3. 建议的状态模型

桌面客户端这类工具最怕后期状态纠缠，所以建议从一开始就按下面的对象边界来做：

### 3.1 WindowWorkspace

代表一个真正的桌面窗口。

它负责：

- 当前打开的连接工作区
- 这个窗口里已经打开的 Tab
- 当前 UI 布局状态
- 当前窗口的筛选、搜索、侧栏开关

### 3.2 ConnectionSession

代表一个真实数据库连接会话。

它负责：

- 连接信息
- 驱动类型
- TLS / SSH / 认证配置
- 当前连接状态
- 元数据缓存
- 会话级设置

### 3.3 QueryTab

代表一个 SQL 工作标签页。

它负责：

- SQL 编辑内容
- 运行状态
- 结果集元信息
- 当前排序 / 过滤 / 分页状态
- 最近一次执行耗时
- 是否 dirty

## 4. 建议的代码分层

### 4.1 Shell 层

- app 启动
- 主题
- 窗口布局
- 命令入口

### 4.2 Feature 层

- connections
- workbench
- schema_browser
- query_tabs
- results_grid
- query_history
- snippets
- export
- table_designer
- table_data_editor
- schema_graph
- settings

### 4.3 Domain / Service 层

- `WindowCoordinator`
- `ConnectionManager`
- `QueryExecutor`
- `SchemaCacheService`
- `SchemaDesignerService`
- `RelationGraphService`
- `CredentialVaultService`
- `ExportService`

### 4.4 Driver 层

不要把 MySQL 逻辑直接写进页面和 service 里，建议先定义统一驱动接口：

```dart
abstract interface class DatabaseDriver {
  String get kind;

  Future<void> connect();
  Future<void> disconnect();
  Future<List<String>> loadDatabases();
  Future<List<String>> loadTables(String databaseName);
  Future<QueryExecutionResult> execute(String sql);
}
```

第一阶段只有 MySQL 实现也没关系，但接口要先抽出来。

## 5. 多窗口和多 Tab 怎么落地

建议分两层做：

### 5.1 第一层：应用内部的工作区模型先做好

哪怕最开始还没接真实 macOS 多窗口，也先让代码里有这些概念：

- window
- workspace
- tab
- active session

这样后续从“单窗口假多窗口”升级到“真实多窗口”时，不需要大拆。

### 5.2 第二层：再接 macOS 真实窗口

等 Flutter 和桌面依赖装完以后，再把这些能力接进去：

- 新建窗口
- 恢复上次窗口布局
- 窗口间共享已保存连接
- 每个窗口独立 Tab 状态

## 6. 性能上必须提前规避的坑

### 6.1 Schema 不要一次性全量加载

正确做法：

- 先加载数据库列表
- 展开数据库时再加载表
- 展开表时再加载列、索引、外键
- 对 metadata 做缓存和失效控制

### 6.2 大结果集不要直接全量渲染

正确做法：

- 结果区做分页或增量加载
- 表格组件尽量虚拟化
- 表数据编辑区必须支持脏数据缓存和分页提交
- 导出和大数据格式化扔到 isolate 或后台任务

### 6.3 长连接与查询执行分开治理

建议：

- 连接状态单独管理
- 查询任务可取消
- 执行状态和结果状态分离
- 自动重连但不要吞错误

### 6.4 表编辑一定要有保护层

建议：

- 没有主键时禁止直接可视化更新整表
- 批量编辑要显示 dirty rows
- 保存时只提交变更字段
- 危险写入前要给用户明确确认
- 提供回滚或重新加载入口

## 7. 表设计、数据编辑、关系图怎么做才顺手

### 7.1 Table Designer

- 创建表和修改表结构分开
- 结构变更展示 SQL Diff
- 索引、外键、默认值、注释都要可视化编辑
- 允许预览 Create / Alter / Rollback SQL

### 7.2 Data Editor

- 支持逐格编辑、整行新增、行删除
- dirty 状态明确可见
- 分页编辑，不要默认整表加载
- 行级错误提示要清楚

### 7.3 Relation Graph

- 能从表设计和 Schema Browser 跳过去
- 外键关系可追踪
- 支持缩放、导出、聚焦当前表
- 后续可以叠加字段级关系和查询链路

## 8. macOS 打包时要提前考虑的点

- Keychain 凭据存储
- 文件选择器权限
- 网络权限与签名
- App Sandbox / notarization
- 菜单栏快捷键
- 标题栏 / 窗口行为的 macOS 习惯

## 9. 分阶段建议

### Phase 0：骨架

- 项目结构
- 桌面工作台壳层
- 多窗口 / 多 Tab 状态模型
- Mock 数据驱动的 UI

### Phase 1：MySQL MVP

- 真实连接
- 连接列表与保存
- Schema 浏览
- SQL 执行
- 结果集查看
- 建表
- 表关系图
- 查询历史

### Phase 2：专业功能

- 导出
- Snippets
- 收藏查询
- 只读保护
- 自动重连
- SSH / SSL
- 数据编辑
- Alter Table
- 行级提交 / 回滚

### Phase 3：多数据库

- 驱动抽象稳定
- PostgreSQL 接入
- SQLite 接入
- 不同数据库能力开关化
