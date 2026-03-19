import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../mock_workbench_data.dart';
import '../../domain/database/connection_models.dart';
import '../../domain/database/query_execution_models.dart';
import '../../domain/persistence/persisted_workbench_state.dart';
import '../../models/workbench_models.dart';

class LocalWorkbenchStore {
  const LocalWorkbenchStore();

  static const int schemaVersion = 1;
  static const JsonEncoder _prettyEncoder = JsonEncoder.withIndent('  ');

  Future<PersistedWorkbenchState?> load() async {
    final file = _autosaveFile();
    if (!await file.exists()) {
      return null;
    }

    final raw = await file.readAsString();
    return importFromJson(raw);
  }

  Future<void> save(PersistedWorkbenchState state) async {
    final file = _autosaveFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(exportToJson(state));
  }

  String exportToJson(PersistedWorkbenchState state) {
    final payload = _encodeSnapshot(
      state.copyWith(
        schemaVersion: schemaVersion,
        exportedAt: DateTime.now(),
      ),
    );
    return _prettyEncoder.convert(payload);
  }

  PersistedWorkbenchState importFromJson(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('备份内容不是合法的 JSON 对象。');
    }
    return _decodeSnapshot(decoded);
  }

  Future<PersistedWorkbenchState> importFromFile(String inputPath) async {
    final normalizedPath = _normalizeInputPath(inputPath);
    final file = File(normalizedPath);
    if (!await file.exists()) {
      throw FormatException('找不到备份文件：$normalizedPath');
    }

    final raw = await file.readAsString();
    return importFromJson(raw);
  }

  Future<String> autosavePath() async {
    return _autosaveFile().path;
  }

  Future<String> writeBackupFile(PersistedWorkbenchState state) async {
    final directory = Directory(_backupDirectoryPath());
    await directory.create(recursive: true);

    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final file = File('${directory.path}/connfox-backup-$timestamp.json');
    await file.writeAsString(exportToJson(state));
    return file.path;
  }

  File _autosaveFile() {
    return File('${_storageDirectoryPath()}/connfox_state.json');
  }

  String _storageDirectoryPath() {
    final home = Platform.environment['HOME'];
    if (home == null || home.trim().isEmpty) {
      return '${Directory.systemTemp.path}/ConnFox';
    }
    return '$home/Library/Application Support/ConnFox';
  }

  String _backupDirectoryPath() {
    final home = Platform.environment['HOME'];
    if (home == null || home.trim().isEmpty) {
      return '${Directory.systemTemp.path}/ConnFoxBackups';
    }
    return '$home/Documents/ConnFox Backups';
  }

  String _normalizeInputPath(String inputPath) {
    final trimmed = inputPath.trim();
    if (trimmed.startsWith('~/')) {
      final home = Platform.environment['HOME'];
      if (home == null || home.trim().isEmpty) {
        throw const FormatException('当前环境无法展开 `~/` 路径。');
      }
      return '$home/${trimmed.substring(2)}';
    }
    return trimmed;
  }

  Map<String, dynamic> _encodeSnapshot(PersistedWorkbenchState state) {
    return <String, dynamic>{
      'schemaVersion': state.schemaVersion,
      'exportedAt': state.exportedAt.toIso8601String(),
      'activeWorkspaceIndex': state.activeWorkspaceIndex,
      'workspaces': state.workspaces
          .map<Map<String, dynamic>>(_encodeWorkspace)
          .toList(),
    };
  }

  PersistedWorkbenchState _decodeSnapshot(Map<String, dynamic> json) {
    final workspacesJson = json['workspaces'];
    if (workspacesJson is! List) {
      throw const FormatException('备份内容缺少 `workspaces` 列表。');
    }

    final workspaces = workspacesJson
        .whereType<Map<String, dynamic>>()
        .map(_decodeWorkspace)
        .toList();
    if (workspaces.isEmpty) {
      throw const FormatException('备份内容里没有可恢复的工作区。');
    }

    return PersistedWorkbenchState(
      schemaVersion: json['schemaVersion'] as int? ?? schemaVersion,
      exportedAt: DateTime.tryParse(json['exportedAt'] as String? ?? '') ??
          DateTime.now(),
      activeWorkspaceIndex: json['activeWorkspaceIndex'] as int? ?? 0,
      workspaces: workspaces,
    );
  }

  Map<String, dynamic> _encodeWorkspace(WindowWorkspace workspace) {
    return <String, dynamic>{
      'id': workspace.id,
      'title': workspace.title,
      'subtitle': workspace.subtitle,
      'connection': _encodeConnectionProfile(workspace.connection),
      'tabs': workspace.tabs.map<Map<String, dynamic>>(_encodeTab).toList(),
      'activeTabId': workspace.activeTabId,
      'schema': workspace.schema.map<Map<String, dynamic>>(_encodeSchema).toList(),
      'recentQueries': workspace.recentQueries,
      'snippets': workspace.snippets,
      'capabilities': workspace.capabilities,
    };
  }

  WindowWorkspace _decodeWorkspace(Map<String, dynamic> json) {
    final connection = _decodeConnectionProfile(
      json['connection'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
    final tabs = (json['tabs'] as List? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(_decodeTab)
        .toList();
    final safeTabs = tabs.isEmpty
        ? <QueryTabModel>[
            buildScratchTab(connection, 1).copyWith(
              id: 'restored-scratch',
              title: 'Restored Scratch',
              summary: '导入后自动补齐的 SQL 草稿',
            ),
          ]
        : tabs;
    final activeTabId = json['activeTabId'] as String?;

    return WindowWorkspace(
      id: json['id'] as String? ?? 'window-restored',
      title: json['title'] as String? ?? 'Restored Workspace',
      subtitle: json['subtitle'] as String? ?? 'Imported from local backup',
      connection: connection,
      tabs: safeTabs,
      activeTabId: safeTabs.any((tab) => tab.id == activeTabId)
          ? activeTabId!
          : safeTabs.first.id,
      schema: (json['schema'] as List? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(_decodeSchema)
          .toList(),
      recentQueries: (json['recentQueries'] as List? ?? const <dynamic>[])
          .map((item) => item.toString())
          .toList(),
      snippets: (json['snippets'] as List? ?? const <dynamic>[])
          .map((item) => item.toString())
          .toList(),
      capabilities: (json['capabilities'] as List? ?? const <dynamic>[])
          .map((item) => item.toString())
          .toList(),
    );
  }

  Map<String, dynamic> _encodeConnectionProfile(ConnectionProfile profile) {
    return <String, dynamic>{
      'config': _encodeConnectionConfig(profile.config),
      'environment': profile.environment,
      'latencyLabel': profile.latencyLabel,
      'statusLabel': profile.statusLabel,
      'accentColor': profile.accentColor.value,
    };
  }

  ConnectionProfile _decodeConnectionProfile(Map<String, dynamic> json) {
    final config = _decodeConnectionConfig(
      json['config'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );

    return ConnectionProfile(
      config: config,
      environment: json['environment'] as String? ?? config.environment,
      latencyLabel: json['latencyLabel'] as String? ?? 'Restored',
      statusLabel: json['statusLabel'] as String? ?? 'Imported',
      accentColor: Color(json['accentColor'] as int? ?? 0xFF0F766E),
    );
  }

  Map<String, dynamic> _encodeConnectionConfig(DatabaseConnectionConfig config) {
    return <String, dynamic>{
      'id': config.id,
      'name': config.name,
      'engine': config.engine.name,
      'host': config.host,
      'port': config.port,
      'database': config.database,
      'username': config.username,
      'password': config.password,
      'environment': config.environment,
      'useTls': config.useTls,
      'readOnly': config.readOnly,
      'useSshTunnel': config.useSshTunnel,
      'sshHost': config.sshHost,
      'sshPort': config.sshPort,
      'notes': config.notes,
    };
  }

  DatabaseConnectionConfig _decodeConnectionConfig(Map<String, dynamic> json) {
    final engineName = json['engine'] as String? ?? DatabaseEngine.mysql.name;
    final engine = DatabaseEngine.values.firstWhere(
      (candidate) => candidate.name == engineName,
      orElse: () => DatabaseEngine.mysql,
    );

    return DatabaseConnectionConfig(
      id: json['id'] as String? ?? 'restored-connection',
      name: json['name'] as String? ?? 'Restored Connection',
      engine: engine,
      host: json['host'] as String? ?? '',
      port: json['port'] as int? ?? engine.defaultPort,
      database: json['database'] as String? ?? '',
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      environment: json['environment'] as String? ?? 'DEV',
      useTls: json['useTls'] as bool? ?? false,
      readOnly: json['readOnly'] as bool? ?? false,
      useSshTunnel: json['useSshTunnel'] as bool? ?? false,
      sshHost: json['sshHost'] as String?,
      sshPort: json['sshPort'] as int?,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> _encodeTab(QueryTabModel tab) {
    return <String, dynamic>{
      'id': tab.id,
      'title': tab.title,
      'summary': tab.summary,
      'sql': tab.sql,
      'resultColumns': tab.resultColumns,
      'resultRows': tab.resultRows,
      'resultCountLabel': tab.resultCountLabel,
      'executionLabel': tab.executionLabel,
      'updatedAtLabel': tab.updatedAtLabel,
      'resultKind': tab.resultKind.name,
      'resultNotice': tab.resultNotice,
      'resultStatusLabel': tab.resultStatusLabel,
      'affectedRowCount': tab.affectedRowCount,
      'resultHighlights': tab.resultHighlights,
      'lastRunScopeLabel': tab.lastRunScopeLabel,
      'pinned': tab.pinned,
      'dirty': tab.dirty,
    };
  }

  QueryTabModel _decodeTab(Map<String, dynamic> json) {
    final kindName = json['resultKind'] as String? ?? QueryResultKind.resultSet.name;
    final resultKind = QueryResultKind.values.firstWhere(
      (candidate) => candidate.name == kindName,
      orElse: () => QueryResultKind.resultSet,
    );

    return QueryTabModel(
      id: json['id'] as String? ?? 'restored-tab',
      title: json['title'] as String? ?? 'Restored Tab',
      summary: json['summary'] as String? ?? 'Imported SQL tab',
      sql: json['sql'] as String? ?? '',
      resultColumns: (json['resultColumns'] as List? ?? const <dynamic>[])
          .map((item) => item.toString())
          .toList(),
      resultRows: (json['resultRows'] as List? ?? const <dynamic>[])
          .map<List<String>>(
            (row) => (row as List? ?? const <dynamic>[])
                .map((cell) => cell.toString())
                .toList(),
          )
          .toList(),
      resultCountLabel: json['resultCountLabel'] as String? ?? 'Restored',
      executionLabel: json['executionLabel'] as String? ?? 'Imported',
      updatedAtLabel: json['updatedAtLabel'] as String? ?? 'Now',
      resultKind: resultKind,
      resultNotice: json['resultNotice'] as String?,
      resultStatusLabel: json['resultStatusLabel'] as String? ?? 'Imported',
      affectedRowCount: json['affectedRowCount'] as int?,
      resultHighlights: (json['resultHighlights'] as List? ?? const <dynamic>[])
          .map((item) => item.toString())
          .toList(),
      lastRunScopeLabel: json['lastRunScopeLabel'] as String? ?? 'Imported',
      pinned: json['pinned'] as bool? ?? false,
      dirty: json['dirty'] as bool? ?? false,
    );
  }

  Map<String, dynamic> _encodeSchema(SchemaNode node) {
    return <String, dynamic>{
      'label': node.label,
      'kind': node.kind,
      'children': node.children.map<Map<String, dynamic>>(_encodeSchema).toList(),
    };
  }

  SchemaNode _decodeSchema(Map<String, dynamic> json) {
    return SchemaNode(
      label: json['label'] as String? ?? 'restored_object',
      kind: json['kind'] as String? ?? 'table',
      children: (json['children'] as List? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(_decodeSchema)
          .toList(),
    );
  }
}
