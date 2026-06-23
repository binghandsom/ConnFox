import '../../domain/database/connection_models.dart';
import '../../domain/database/database_driver.dart';
import '../../domain/database/query_execution_models.dart';

class MockPostgreSqlDriver implements DatabaseDriver {
  const MockPostgreSqlDriver();

  @override
  DatabaseEngine get engine => DatabaseEngine.postgresql;

  @override
  Future<ConnectionTestResult> testConnection(
    DatabaseConnectionConfig config,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 420));

    if (config.host.trim().isEmpty) {
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

    if (config.username.trim().isEmpty) {
      return const ConnectionTestResult(
        success: false,
        message: 'Username 不能为空。',
        latency: Duration(milliseconds: 0),
      );
    }

    return ConnectionTestResult(
      success: true,
      message: 'Mock PostgreSQL 驱动测试通过，默认端口和 Schema 链路已接入。',
      latency: _durationFor(config.name + config.host, base: 10),
    );
  }

  @override
  Future<QueryExecutionResult> executeQuery({
    required DatabaseConnectionConfig config,
    required String sql,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 620));

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
        normalized.startsWith('drop ') ||
        normalized.startsWith('create ');

    if (isWriteQuery && config.readOnly) {
      throw StateError('当前 PostgreSQL 连接处于只读模式，已拦截写入类 SQL。');
    }

    if (normalized.contains('pg_stat_activity')) {
      return QueryExecutionResult(
        kind: QueryResultKind.resultSet,
        columns: const <String>[
          'pid',
          'usename',
          'datname',
          'state',
          'wait_event_type',
          'query_start',
        ],
        rows: const <List<String>>[
          <String>[
            '4418',
            'readonly',
            'warehouse',
            'active',
            'Client',
            '2026-03-18 18:25:02',
          ],
          <String>[
            '4421',
            'analyst',
            'warehouse',
            'idle',
            'Activity',
            '2026-03-18 18:21:31',
          ],
          <String>[
            '4428',
            'etl_bot',
            'warehouse',
            'active',
            'IO',
            '2026-03-18 18:18:10',
          ],
        ],
        duration: _durationFor(sql),
        summary: 'PostgreSQL activity preview',
        statusLabel: 'Read',
        highlights: const <String>[
          '这是一份模拟的 pg_stat_activity 结果。',
          '后面替换真实驱动后可用于展示 PostgreSQL 会话状态。',
        ],
      );
    }

    if (normalized.contains('current_database()') ||
        normalized.contains('select version()') ||
        normalized.contains('select now()')) {
      return QueryExecutionResult(
        kind: QueryResultKind.resultSet,
        columns: const <String>['current_database', 'server_time', 'version'],
        rows: <List<String>>[
          <String>[
            config.database,
            '2026-03-18 18:26:44+08',
            'PostgreSQL 16.x mock',
          ],
        ],
        duration: _durationFor(sql),
        summary: 'PostgreSQL session preview',
        statusLabel: 'Read',
      );
    }

    if (normalized.contains('pg_catalog.pg_tables') ||
        normalized.contains('information_schema.tables')) {
      return QueryExecutionResult(
        kind: QueryResultKind.resultSet,
        columns: const <String>['schemaname', 'tablename', 'tableowner'],
        rows: const <List<String>>[
          <String>['public', 'accounts', 'app_owner'],
          <String>['public', 'events', 'app_owner'],
          <String>['analytics', 'fct_orders', 'analytics_owner'],
        ],
        duration: _durationFor(sql),
        summary: 'PostgreSQL tables preview',
        statusLabel: 'Read',
      );
    }

    if (normalized.contains('count(')) {
      return QueryExecutionResult(
        kind: QueryResultKind.resultSet,
        columns: const <String>['count'],
        rows: <List<String>>[
          <String>['${(sql.length * 11) % 12000 + 200}'],
        ],
        duration: _durationFor(sql),
        summary: 'Aggregate result',
        statusLabel: 'Read',
      );
    }

    if (normalized.contains('from events')) {
      return QueryExecutionResult(
        kind: QueryResultKind.resultSet,
        columns: const <String>[
          'event_id',
          'event_type',
          'payload',
          'created_at',
        ],
        rows: const <List<String>>[
          <String>[
            'evt_70018',
            'checkout.completed',
            '{"amount": 192.30}',
            '2026-03-18 18:23:10+08',
          ],
          <String>[
            'evt_70011',
            'user.created',
            '{"plan": "pro"}',
            '2026-03-18 18:20:41+08',
          ],
          <String>[
            'evt_69998',
            'invoice.failed',
            '{"retry": 2}',
            '2026-03-18 18:17:59+08',
          ],
        ],
        duration: _durationFor(sql),
        summary: 'Events preview',
        statusLabel: 'Read',
        highlights: const <String>[
          '结果来自 mock PostgreSQL events 数据集。',
        ],
      );
    }

    if (normalized.contains('from fct_orders') ||
        normalized.contains('from orders')) {
      return QueryExecutionResult(
        kind: QueryResultKind.resultSet,
        columns: const <String>[
          'order_id',
          'status',
          'gross_amount',
          'created_at',
        ],
        rows: const <List<String>>[
          <String>['ORD-881201', 'paid', '192.30', '2026-03-18 18:20:19+08'],
          <String>['ORD-881198', 'pending', '88.00', '2026-03-18 18:19:02+08'],
          <String>['ORD-881191', 'refunded', '22.80', '2026-03-18 18:17:51+08'],
        ],
        duration: _durationFor(sql),
        summary: 'PostgreSQL orders preview',
        statusLabel: 'Read',
      );
    }

    if (isWriteQuery) {
      final affectedRows = (sql.length % 36) + 1;
      return QueryExecutionResult(
        kind: QueryResultKind.mutation,
        columns: const <String>['affected_rows', 'status'],
        rows: <List<String>>[
          <String>['$affectedRows', 'ok'],
        ],
        duration: _durationFor(sql, base: 52),
        summary: 'PostgreSQL write simulated',
        notice: '当前是 mock PostgreSQL driver，后面会替换成真实执行结果。',
        statusLabel: 'Updated',
        affectedRowCount: affectedRows,
        highlights: <String>[
          '影响行数：$affectedRows',
          if (normalized.startsWith('insert ')) '检测到 INSERT 语句。',
          if (normalized.startsWith('update ')) '检测到 UPDATE 语句。',
          if (normalized.startsWith('delete ')) '检测到 DELETE 语句。',
          if (normalized.startsWith('alter ')) '检测到结构变更语句。',
          if (normalized.startsWith('create ')) '检测到建表或建对象语句。',
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
        const <String>['Dialect: PostgreSQL'],
      ],
      duration: _durationFor(sql),
      summary: 'PostgreSQL generic preview',
      notice: 'SQL 已走通 PostgreSQL 执行链路，后面只需替换成真实 PostgreSQL driver。',
      statusLabel: 'Info',
      highlights: const <String>[
        '当前返回的是 PostgreSQL 通用预览结果。',
      ],
    );
  }

  @override
  Future<List<DatabaseObjectNode>> loadSchema(
    DatabaseConnectionConfig config,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 260));

    final database = config.database.isEmpty ? 'postgres' : config.database;

    return <DatabaseObjectNode>[
      DatabaseObjectNode(
        name: database,
        kind: 'database',
        children: const <DatabaseObjectNode>[
          DatabaseObjectNode(
            name: 'public',
            kind: 'schema',
            children: <DatabaseObjectNode>[
              DatabaseObjectNode(name: 'accounts', kind: 'table'),
              DatabaseObjectNode(name: 'events', kind: 'table'),
              DatabaseObjectNode(name: 'recent_events_view', kind: 'view'),
            ],
          ),
          DatabaseObjectNode(
            name: 'analytics',
            kind: 'schema',
            children: <DatabaseObjectNode>[
              DatabaseObjectNode(name: 'fct_orders', kind: 'table'),
              DatabaseObjectNode(name: 'daily_revenue_mv', kind: 'materialized view'),
            ],
          ),
        ],
      ),
      const DatabaseObjectNode(
        name: 'pg_catalog',
        kind: 'system',
        children: <DatabaseObjectNode>[
          DatabaseObjectNode(name: 'pg_tables', kind: 'view'),
          DatabaseObjectNode(name: 'pg_stat_activity', kind: 'view'),
        ],
      ),
    ];
  }

  Duration _durationFor(String seed, {int base = 34}) {
    final hash = seed.codeUnits.fold<int>(0, (sum, item) => sum + item);
    return Duration(milliseconds: base + (hash % 88));
  }
}
