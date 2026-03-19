import 'connection_models.dart';
import 'driver_registry.dart';
import 'query_execution_models.dart';

class QueryExecutionService {
  const QueryExecutionService({
    required DriverRegistry driverRegistry,
  }) : _driverRegistry = driverRegistry;

  final DriverRegistry _driverRegistry;

  Future<ConnectionTestResult> testConnection(
    DatabaseConnectionConfig config,
  ) {
    return _driverRegistry.driverFor(config.engine).testConnection(config);
  }

  Future<QueryExecutionResult> execute({
    required DatabaseConnectionConfig config,
    required String sql,
  }) {
    return _driverRegistry.driverFor(config.engine).executeQuery(
          config: config,
          sql: sql,
        );
  }

  Future<List<DatabaseObjectNode>> loadSchema(
    DatabaseConnectionConfig config,
  ) {
    return _driverRegistry.driverFor(config.engine).loadSchema(config);
  }
}
