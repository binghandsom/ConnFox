import '../../domain/database/connection_models.dart';
import '../../domain/database/database_driver.dart';
import '../../domain/database/query_execution_models.dart';

class PlaceholderDatabaseDriver implements DatabaseDriver {
  const PlaceholderDatabaseDriver(this.engine);

  @override
  final DatabaseEngine engine;

  @override
  Future<ConnectionTestResult> testConnection(
    DatabaseConnectionConfig config,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 280));

    return ConnectionTestResult(
      success: true,
      message: '${engine.label} 目前还是占位驱动，连接链路已预留完成。',
      latency: const Duration(milliseconds: 9),
    );
  }

  @override
  Future<QueryExecutionResult> executeQuery({
    required DatabaseConnectionConfig config,
    required String sql,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 320));

    return QueryExecutionResult(
      kind: QueryResultKind.notice,
      columns: const <String>['status', 'engine', 'database'],
      rows: <List<String>>[
        <String>['placeholder', engine.label, config.database],
      ],
      duration: const Duration(milliseconds: 28),
      summary: '${engine.label} placeholder execution',
      notice: '执行链路已接通，后续把占位驱动替换为真实驱动即可。',
      statusLabel: 'Placeholder',
      highlights: const <String>[
        '当前驱动仍是占位实现。',
      ],
    );
  }

  @override
  Future<List<DatabaseObjectNode>> loadSchema(
    DatabaseConnectionConfig config,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 160));

    return <DatabaseObjectNode>[
      DatabaseObjectNode(
        name: config.database.isEmpty ? 'default' : config.database,
        kind: 'database',
        children: const <DatabaseObjectNode>[
          DatabaseObjectNode(name: 'sample_table', kind: 'table'),
          DatabaseObjectNode(name: 'sample_view', kind: 'view'),
        ],
      ),
    ];
  }
}
