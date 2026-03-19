import '../../domain/database/connection_models.dart';
import '../../domain/database/database_driver.dart';
import '../../domain/database/query_execution_models.dart';

class MockMySqlDriver implements DatabaseDriver {
  const MockMySqlDriver();

  @override
  DatabaseEngine get engine => DatabaseEngine.mysql;

  @override
  Future<ConnectionTestResult> testConnection(
    DatabaseConnectionConfig config,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));

    if (config.host.trim().isEmpty && !config.engine.isFileBased) {
      return const ConnectionTestResult(
        success: false,
        message: 'Host 不能为空。',
        latency: Duration(milliseconds: 0),
      );
    }

    if (config.database.trim().isEmpty) {
      return const ConnectionTestResult(
        success: false,
        message: 'Database 不能为空。',
        latency: Duration(milliseconds: 0),
      );
    }

    final latency = _durationFor(config.name + config.host, base: 12);

    return ConnectionTestResult(
      success: true,
      message: 'Mock MySQL 驱动测试通过，后面替换成真实 TCP 握手即可。',
      latency: latency,
    );
  }

  @override
  Future<QueryExecutionResult> executeQuery({
    required DatabaseConnectionConfig config,
    required String sql,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 650));

    final normalized = sql.trim().toLowerCase();

    if (normalized.isEmpty) {
      return const QueryExecutionResult(
        kind: QueryResultKind.notice,
        columns: <String>['message'],
        rows: <List<String>>[
          <String>['No SQL provided'],
        ],
        duration: Duration(milliseconds: 4),
        summary: 'Empty query',
        notice: '请先输入 SQL。',
        statusLabel: 'Empty',
      );
    }

    final isWriteQuery = normalized.startsWith('update ') ||
        normalized.startsWith('delete ') ||
        normalized.startsWith('insert ') ||
        normalized.startsWith('truncate ') ||
        normalized.startsWith('alter ') ||
        normalized.startsWith('drop ');

    if (isWriteQuery && config.readOnly) {
      throw StateError('当前连接处于只读模式，已拦截写入类 SQL。');
    }

    if (normalized.contains('show processlist')) {
      return QueryExecutionResult(
        kind: QueryResultKind.resultSet,
        columns: const <String>['id', 'user', 'db', 'command', 'time'],
        rows: const <List<String>>[
          <String>['91', 'readonly', 'orders', 'Query', '2'],
          <String>['93', 'reporter', 'analytics', 'Sleep', '15'],
          <String>['95', 'sync_bot', 'orders', 'Query', '1'],
        ],
        duration: _durationFor(sql),
        summary: 'MySQL process list preview',
        statusLabel: 'Read',
        highlights: const <String>[
          '这是一份模拟的 MySQL 进程列表结果。',
          '后面接入真实驱动后会显示会话级实时状态。',
        ],
      );
    }

    if (normalized.contains('count(')) {
      return QueryExecutionResult(
        kind: QueryResultKind.resultSet,
        columns: const <String>['count'],
        rows: <List<String>>[
          <String>['${(sql.length * 7) % 9000 + 100}'],
        ],
        duration: _durationFor(sql),
        summary: 'Aggregate result',
        statusLabel: 'Read',
      );
    }

    if (normalized.contains('from products')) {
      return QueryExecutionResult(
        kind: QueryResultKind.resultSet,
        columns: const <String>['sku', 'title', 'sync_state', 'updated_at'],
        rows: const <List<String>>[
          <String>['SKU-10023', 'Desk Lamp', 'synced', '2026-03-18 18:18:44'],
          <String>['SKU-40018', 'Coffee Grinder', 'pending', '2026-03-18 18:17:01'],
          <String>['SKU-12991', 'Ceramic Cup', 'error', '2026-03-18 18:15:20'],
        ],
        duration: _durationFor(sql),
        summary: 'Products preview',
        statusLabel: 'Read',
        highlights: const <String>[
          '结果来自 mock products 数据集。',
        ],
      );
    }

    if (normalized.contains('from orders')) {
      return QueryExecutionResult(
        kind: QueryResultKind.resultSet,
        columns: const <String>['order_id', 'status', 'total_amount', 'created_at'],
        rows: const <List<String>>[
          <String>['ORD-881201', 'paid', '192.30', '2026-03-18 18:20:19'],
          <String>['ORD-881198', 'pending', '88.00', '2026-03-18 18:19:02'],
          <String>['ORD-881191', 'refunded', '22.80', '2026-03-18 18:17:51'],
          <String>['ORD-881187', 'paid', '420.10', '2026-03-18 18:16:33'],
        ],
        duration: _durationFor(sql),
        summary: 'Orders preview',
        statusLabel: 'Read',
      );
    }

    if (isWriteQuery) {
      final affectedRows = (sql.length % 40) + 1;
      return QueryExecutionResult(
        kind: QueryResultKind.mutation,
        columns: const <String>['affected_rows', 'status'],
        rows: <List<String>>[
          <String>['$affectedRows', 'ok'],
        ],
        duration: _durationFor(sql, base: 55),
        summary: 'Write query simulated',
        notice: '当前是 mock driver，后面会替换成真实执行结果。',
        statusLabel: 'Updated',
        affectedRowCount: affectedRows,
        highlights: <String>[
          '影响行数：$affectedRows',
          if (normalized.startsWith('insert ')) '检测到 INSERT 语句。',
          if (normalized.startsWith('update ')) '检测到 UPDATE 语句。',
          if (normalized.startsWith('delete ')) '检测到 DELETE 语句。',
          if (normalized.startsWith('alter ')) '检测到结构变更语句。',
        ],
      );
    }

    return QueryExecutionResult(
      kind: QueryResultKind.notice,
      columns: const <String>['preview'],
      rows: <List<String>>[
        <String>['Mock execution for ${config.engine.label}'],
        <String>['Database: ${config.database}'],
        <String>['Endpoint: ${config.endpoint}'],
      ],
      duration: _durationFor(sql),
      summary: 'Generic preview',
      notice: 'SQL 已走通执行链路，后面只需把 mock driver 替换成真实 MySQL driver。',
      statusLabel: 'Info',
      highlights: const <String>[
        '当前返回的是通用预览结果。',
      ],
    );
  }

  @override
  Future<List<DatabaseObjectNode>> loadSchema(
    DatabaseConnectionConfig config,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 280));

    final primaryDatabase = config.database.isEmpty ? 'default_db' : config.database;

    return <DatabaseObjectNode>[
      DatabaseObjectNode(
        name: primaryDatabase,
        kind: 'database',
        children: const <DatabaseObjectNode>[
          DatabaseObjectNode(name: 'orders', kind: 'table'),
          DatabaseObjectNode(name: 'order_items', kind: 'table'),
          DatabaseObjectNode(name: 'sync_jobs', kind: 'table'),
          DatabaseObjectNode(name: 'daily_revenue_view', kind: 'view'),
        ],
      ),
      const DatabaseObjectNode(
        name: 'information_schema',
        kind: 'system',
        children: <DatabaseObjectNode>[
          DatabaseObjectNode(name: 'tables', kind: 'table'),
          DatabaseObjectNode(name: 'columns', kind: 'table'),
        ],
      ),
    ];
  }

  Duration _durationFor(String seed, {int base = 36}) {
    final hash = seed.codeUnits.fold<int>(0, (sum, item) => sum + item);
    return Duration(milliseconds: base + (hash % 90));
  }
}
