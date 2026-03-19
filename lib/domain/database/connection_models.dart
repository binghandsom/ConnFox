enum DatabaseEngine {
  mysql,
  mariadb,
  postgresql,
  sqlite,
  sqlServer,
}

extension DatabaseEnginePresentation on DatabaseEngine {
  String get label {
    switch (this) {
      case DatabaseEngine.mysql:
        return 'MySQL';
      case DatabaseEngine.mariadb:
        return 'MariaDB';
      case DatabaseEngine.postgresql:
        return 'PostgreSQL';
      case DatabaseEngine.sqlite:
        return 'SQLite';
      case DatabaseEngine.sqlServer:
        return 'SQL Server';
    }
  }

  int get defaultPort {
    switch (this) {
      case DatabaseEngine.mysql:
      case DatabaseEngine.mariadb:
        return 3306;
      case DatabaseEngine.postgresql:
        return 5432;
      case DatabaseEngine.sqlite:
        return 0;
      case DatabaseEngine.sqlServer:
        return 1433;
    }
  }

  bool get isFileBased => this == DatabaseEngine.sqlite;
}

class DatabaseConnectionConfig {
  const DatabaseConnectionConfig({
    required this.id,
    required this.name,
    required this.engine,
    required this.host,
    required this.port,
    required this.database,
    required this.username,
    required this.password,
    this.environment = 'DEV',
    this.useTls = false,
    this.readOnly = false,
    this.useSshTunnel = false,
    this.sshHost,
    this.sshPort,
    this.notes,
  });

  final String id;
  final String name;
  final DatabaseEngine engine;
  final String host;
  final int port;
  final String database;
  final String username;
  final String password;
  final String environment;
  final bool useTls;
  final bool readOnly;
  final bool useSshTunnel;
  final String? sshHost;
  final int? sshPort;
  final String? notes;

  String get endpoint => engine.isFileBased ? database : '$host:$port';

  DatabaseConnectionConfig copyWith({
    String? id,
    String? name,
    DatabaseEngine? engine,
    String? host,
    int? port,
    String? database,
    String? username,
    String? password,
    String? environment,
    bool? useTls,
    bool? readOnly,
    bool? useSshTunnel,
    String? sshHost,
    int? sshPort,
    String? notes,
  }) {
    return DatabaseConnectionConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      engine: engine ?? this.engine,
      host: host ?? this.host,
      port: port ?? this.port,
      database: database ?? this.database,
      username: username ?? this.username,
      password: password ?? this.password,
      environment: environment ?? this.environment,
      useTls: useTls ?? this.useTls,
      readOnly: readOnly ?? this.readOnly,
      useSshTunnel: useSshTunnel ?? this.useSshTunnel,
      sshHost: sshHost ?? this.sshHost,
      sshPort: sshPort ?? this.sshPort,
      notes: notes ?? this.notes,
    );
  }
}

class ConnectionTestResult {
  const ConnectionTestResult({
    required this.success,
    required this.message,
    required this.latency,
  });

  final bool success;
  final String message;
  final Duration latency;

  String get latencyLabel => '${latency.inMilliseconds} ms';
}
