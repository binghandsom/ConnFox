import 'connection_models.dart';
import 'query_execution_models.dart';

abstract interface class DatabaseDriver {
  DatabaseEngine get engine;

  Future<ConnectionTestResult> testConnection(DatabaseConnectionConfig config);

  Future<QueryExecutionResult> executeQuery({
    required DatabaseConnectionConfig config,
    required String sql,
  });

  Future<List<DatabaseObjectNode>> loadSchema(DatabaseConnectionConfig config);
}
