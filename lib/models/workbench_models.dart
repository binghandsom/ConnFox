import 'package:flutter/material.dart';

import '../domain/database/connection_models.dart';
import '../domain/database/query_execution_models.dart';

const Object _queryTabNoChange = Object();

class ConnectionProfile {
  const ConnectionProfile({
    required this.config,
    required this.environment,
    required this.latencyLabel,
    required this.statusLabel,
    required this.accentColor,
  });

  final DatabaseConnectionConfig config;
  final String environment;
  final String latencyLabel;
  final String statusLabel;
  final Color accentColor;

  factory ConnectionProfile.fromConfig({
    required DatabaseConnectionConfig config,
    required String latencyLabel,
    required String statusLabel,
    required Color accentColor,
  }) {
    return ConnectionProfile(
      config: config,
      environment: config.environment,
      latencyLabel: latencyLabel,
      statusLabel: statusLabel,
      accentColor: accentColor,
    );
  }

  String get id => config.id;
  String get name => config.name;
  String get engine => config.engine.label;
  String get host => config.host;
  int get port => config.port;
  String get database => config.database;
  bool get readOnly => config.readOnly;
  String get endpoint => config.endpoint;
}

class QueryTabModel {
  const QueryTabModel({
    required this.id,
    required this.title,
    required this.summary,
    required this.sql,
    required this.resultColumns,
    required this.resultRows,
    required this.resultCountLabel,
    required this.executionLabel,
    required this.updatedAtLabel,
    this.resultKind = QueryResultKind.resultSet,
    this.resultNotice,
    this.resultStatusLabel = 'Success',
    this.affectedRowCount,
    this.resultHighlights = const <String>[],
    this.lastRunScopeLabel = 'Whole tab',
    this.pinned = false,
    this.dirty = false,
  });

  final String id;
  final String title;
  final String summary;
  final String sql;
  final List<String> resultColumns;
  final List<List<String>> resultRows;
  final String resultCountLabel;
  final String executionLabel;
  final String updatedAtLabel;
  final QueryResultKind resultKind;
  final String? resultNotice;
  final String resultStatusLabel;
  final int? affectedRowCount;
  final List<String> resultHighlights;
  final String lastRunScopeLabel;
  final bool pinned;
  final bool dirty;

  QueryTabModel copyWith({
    String? id,
    String? title,
    String? summary,
    String? sql,
    List<String>? resultColumns,
    List<List<String>>? resultRows,
    String? resultCountLabel,
    String? executionLabel,
    String? updatedAtLabel,
    QueryResultKind? resultKind,
    Object? resultNotice = _queryTabNoChange,
    String? resultStatusLabel,
    Object? affectedRowCount = _queryTabNoChange,
    List<String>? resultHighlights,
    String? lastRunScopeLabel,
    bool? pinned,
    bool? dirty,
  }) {
    return QueryTabModel(
      id: id ?? this.id,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      sql: sql ?? this.sql,
      resultColumns: resultColumns ?? this.resultColumns,
      resultRows: resultRows ?? this.resultRows,
      resultCountLabel: resultCountLabel ?? this.resultCountLabel,
      executionLabel: executionLabel ?? this.executionLabel,
      updatedAtLabel: updatedAtLabel ?? this.updatedAtLabel,
      resultKind: resultKind ?? this.resultKind,
      resultNotice: resultNotice == _queryTabNoChange
          ? this.resultNotice
          : resultNotice as String?,
      resultStatusLabel: resultStatusLabel ?? this.resultStatusLabel,
      affectedRowCount: affectedRowCount == _queryTabNoChange
          ? this.affectedRowCount
          : affectedRowCount as int?,
      resultHighlights: resultHighlights ?? this.resultHighlights,
      lastRunScopeLabel: lastRunScopeLabel ?? this.lastRunScopeLabel,
      pinned: pinned ?? this.pinned,
      dirty: dirty ?? this.dirty,
    );
  }
}

class SchemaNode {
  const SchemaNode({
    required this.label,
    required this.kind,
    this.children = const <SchemaNode>[],
  });

  final String label;
  final String kind;
  final List<SchemaNode> children;
}

class WindowWorkspace {
  const WindowWorkspace({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.connection,
    required this.tabs,
    required this.activeTabId,
    required this.schema,
    required this.recentQueries,
    required this.snippets,
    required this.capabilities,
  });

  final String id;
  final String title;
  final String subtitle;
  final ConnectionProfile connection;
  final List<QueryTabModel> tabs;
  final String activeTabId;
  final List<SchemaNode> schema;
  final List<String> recentQueries;
  final List<String> snippets;
  final List<String> capabilities;

  QueryTabModel get activeTab {
    for (final tab in tabs) {
      if (tab.id == activeTabId) {
        return tab;
      }
    }
    return tabs.first;
  }

  WindowWorkspace copyWith({
    String? id,
    String? title,
    String? subtitle,
    ConnectionProfile? connection,
    List<QueryTabModel>? tabs,
    String? activeTabId,
    List<SchemaNode>? schema,
    List<String>? recentQueries,
    List<String>? snippets,
    List<String>? capabilities,
  }) {
    return WindowWorkspace(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      connection: connection ?? this.connection,
      tabs: tabs ?? this.tabs,
      activeTabId: activeTabId ?? this.activeTabId,
      schema: schema ?? this.schema,
      recentQueries: recentQueries ?? this.recentQueries,
      snippets: snippets ?? this.snippets,
      capabilities: capabilities ?? this.capabilities,
    );
  }
}
