import 'connection_models.dart';
import 'database_driver.dart';

class DriverRegistry {
  DriverRegistry(Iterable<DatabaseDriver> drivers)
      : _drivers = <DatabaseEngine, DatabaseDriver>{
          for (final driver in drivers) driver.engine: driver,
        };

  final Map<DatabaseEngine, DatabaseDriver> _drivers;

  DatabaseDriver driverFor(DatabaseEngine engine) {
    final driver = _drivers[engine];
    if (driver == null) {
      throw UnsupportedError('No database driver registered for ${engine.label}.');
    }
    return driver;
  }

  List<DatabaseEngine> get supportedEngines => _drivers.keys.toList();
}
