import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/connfox_theme.dart';
import '../../data/drivers/mock_mysql_driver.dart';
import '../../data/persistence/local_workbench_store.dart';
import '../../data/mock_workbench_data.dart';
import '../../data/drivers/placeholder_database_driver.dart';
import '../../domain/database/connection_models.dart';
import '../../domain/database/database_driver.dart';
import '../../domain/database/driver_registry.dart';
import '../../domain/database/query_execution_models.dart';
import '../../domain/database/query_execution_service.dart';
import '../../domain/persistence/persisted_workbench_state.dart';
import '../../features/connections/connection_center_page.dart';
import '../../features/persistence/backup_center_page.dart';
import '../../features/schema_graph/schema_graph_page.dart';
import '../../features/table_data/table_data_page.dart';
import '../../features/table_designer/table_designer_page.dart';
import '../../models/workbench_models.dart';

class WorkbenchPage extends StatefulWidget {
  const WorkbenchPage({super.key});

  @override
  State<WorkbenchPage> createState() => _WorkbenchPageState();
}

class _WorkbenchPageState extends State<WorkbenchPage> {
  final QueryExecutionService _queryExecutionService = QueryExecutionService(
    driverRegistry: DriverRegistry(
      const <DatabaseDriver>[
        MockMySqlDriver(),
        PlaceholderDatabaseDriver(DatabaseEngine.mariadb),
        PlaceholderDatabaseDriver(DatabaseEngine.postgresql),
        PlaceholderDatabaseDriver(DatabaseEngine.sqlite),
        PlaceholderDatabaseDriver(DatabaseEngine.sqlServer),
      ],
    ),
  );
  final LocalWorkbenchStore _workbenchStore = const LocalWorkbenchStore();

  late List<WindowWorkspace> _workspaces;
  int _activeWorkspaceIndex = 0;
  int _scratchSeed = 1;
  int _windowSeed = 1;
  Timer? _persistDebounce;
  final Set<String> _runningTabIds = <String>{};
  final Map<String, TextEditingController> _tabControllers =
      <String, TextEditingController>{};
  final Map<String, FocusNode> _editorFocusNodes = <String, FocusNode>{};
  static const List<_SqlTemplatePreset> _sqlTemplates = <_SqlTemplatePreset>[
    _SqlTemplatePreset(
      label: 'Select',
      description: '快速查表',
      sql: 'SELECT *\nFROM table_name\nLIMIT 200;',
    ),
    _SqlTemplatePreset(
      label: 'Join',
      description: '联表查询',
      sql:
          'SELECT a.id, a.name, b.status\n'
          'FROM table_a AS a\n'
          'INNER JOIN table_b AS b ON b.a_id = a.id\n'
          'WHERE b.status = \'active\'\n'
          'LIMIT 100;',
    ),
    _SqlTemplatePreset(
      label: 'Insert',
      description: '新增数据',
      sql:
          'INSERT INTO table_name (\n'
          '  column_a,\n'
          '  column_b\n'
          ') VALUES (\n'
          '  value_a,\n'
          '  value_b\n'
          ');',
    ),
    _SqlTemplatePreset(
      label: 'Update',
      description: '修改数据',
      sql:
          'UPDATE table_name\n'
          'SET column_a = value_a\n'
          'WHERE id = target_id;',
    ),
    _SqlTemplatePreset(
      label: 'DDL',
      description: '建表草稿',
      sql:
          'CREATE TABLE table_name (\n'
          '  id BIGINT PRIMARY KEY,\n'
          '  name VARCHAR(255) NOT NULL,\n'
          '  created_at DATETIME NOT NULL\n'
          ');',
    ),
  ];

  WindowWorkspace get _activeWorkspace => _workspaces[_activeWorkspaceIndex];
  QueryTabModel get _activeTab => _activeWorkspace.activeTab;
  String get _activeTabKey => _tabResourceKey(
        _activeWorkspace.id,
        _activeTab.id,
      );

  @override
  void initState() {
    super.initState();
    _workspaces = buildMockWorkspaces();
    for (final workspace in _workspaces) {
      _registerWorkspaceTabs(workspace);
    }
    _scratchSeed = _workspaces.expand((workspace) => workspace.tabs).length + 1;
    _windowSeed = _workspaces.length + 1;
    _focusEditorFor(_activeWorkspace.id, _activeTab.id);
    _restorePersistedState();
  }

  @override
  void dispose() {
    _persistDebounce?.cancel();
    for (final controller in _tabControllers.values) {
      controller.dispose();
    }
    for (final focusNode in _editorFocusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _replaceActiveWorkspace(WindowWorkspace workspace) {
    setState(() {
      _workspaces = List<WindowWorkspace>.of(_workspaces)
        ..[_activeWorkspaceIndex] = workspace;
    });
    _schedulePersist();
  }

  void _replaceWorkspaceById(String workspaceId, WindowWorkspace workspace) {
    final index = _workspaces.indexWhere((item) => item.id == workspaceId);
    if (index == -1) {
      return;
    }

    setState(() {
      _workspaces = List<WindowWorkspace>.of(_workspaces)
        ..[index] = workspace;
    });
    _schedulePersist();
  }

  void _selectWorkspace(int index) {
    final workspace = _workspaces[index];
    setState(() {
      _activeWorkspaceIndex = index;
    });
    _schedulePersist();
    _focusEditorFor(workspace.id, workspace.activeTabId);
  }

  void _selectTab(String tabId) {
    _replaceActiveWorkspace(
      _activeWorkspace.copyWith(activeTabId: tabId),
    );
    _focusEditorFor(_activeWorkspace.id, tabId);
  }

  void _openNewTab() {
    final scratch = buildScratchTab(
      _activeWorkspace.connection,
      _scratchSeed++,
    );
    _registerTab(_activeWorkspace.id, scratch);
    final updatedTabs = <QueryTabModel>[
      ..._activeWorkspace.tabs,
      scratch,
    ];

    _replaceActiveWorkspace(
      _activeWorkspace.copyWith(
        tabs: updatedTabs,
        activeTabId: scratch.id,
      ),
    );

    _focusEditorFor(_activeWorkspace.id, scratch.id);
  }

  void _closeTab(String tabId) {
    if (_activeWorkspace.tabs.length == 1) {
      _showHint('至少保留一个 Tab，后面可以改成自动回到空白工作台。');
      return;
    }

    final tabKey = _tabResourceKey(_activeWorkspace.id, tabId);
    _disposeTabResources(tabKey);

    final updatedTabs = _activeWorkspace.tabs
        .where((tab) => tab.id != tabId)
        .toList();

    final nextActiveTabId = _activeWorkspace.activeTabId == tabId
        ? updatedTabs.first.id
        : _activeWorkspace.activeTabId;

    _replaceActiveWorkspace(
      _activeWorkspace.copyWith(
        tabs: updatedTabs,
        activeTabId: nextActiveTabId,
      ),
    );

    _focusEditorFor(_activeWorkspace.id, nextActiveTabId);
  }

  void _openNewWindow() {
    final scratch = buildScratchTab(
      _activeWorkspace.connection,
      _scratchSeed++,
    );

    final newWorkspace = WindowWorkspace(
      id: 'window-$_windowSeed',
      title: '${_activeWorkspace.connection.name} Window $_windowSeed',
      subtitle: '准备接入真实 macOS 多窗口',
      connection: _activeWorkspace.connection,
      tabs: <QueryTabModel>[scratch],
      activeTabId: scratch.id,
      schema: _activeWorkspace.schema,
      recentQueries: _activeWorkspace.recentQueries,
      snippets: _activeWorkspace.snippets,
      capabilities: _activeWorkspace.capabilities,
    );

    _registerWorkspaceTabs(newWorkspace);

    _windowSeed += 1;

    setState(() {
      _workspaces = <WindowWorkspace>[..._workspaces, newWorkspace];
      _activeWorkspaceIndex = _workspaces.length - 1;
    });
    _schedulePersist();

    _showHint('现在先把窗口状态模型建好，后面接入 macOS 多窗口桥接后就能弹出独立窗口。');
    _focusEditorFor(newWorkspace.id, scratch.id);
  }

  Future<void> _openConnectionCenter() async {
    final profile = await Navigator.of(context).push<ConnectionProfile>(
      MaterialPageRoute<ConnectionProfile>(
        builder: (context) => ConnectionCenterPage(
          queryExecutionService: _queryExecutionService,
        ),
      ),
    );

    if (!mounted || profile == null) {
      return;
    }

    List<SchemaNode> schema;
    try {
      final objects = await _queryExecutionService.loadSchema(profile.config);
      schema = objects.map(_mapSchemaNode).toList();
    } catch (_) {
      schema = <SchemaNode>[
        SchemaNode(
          label: profile.database,
          kind: 'database',
          children: const <SchemaNode>[
            SchemaNode(label: 'loading_failed_placeholder', kind: 'table'),
          ],
        ),
      ];
    }

    final scratch = buildScratchTab(profile, _scratchSeed++);
    final workspace = WindowWorkspace(
      id: 'window-$_windowSeed',
      title: profile.name,
      subtitle: '新连接工作台',
      connection: profile,
      tabs: <QueryTabModel>[scratch],
      activeTabId: scratch.id,
      schema: schema,
      recentQueries: const <String>[
        'SELECT NOW();',
        'SHOW TABLES;',
        'SELECT DATABASE();',
      ],
      snippets: const <String>[
        'Recent Rows',
        'Count Records',
        'Schema Health Check',
      ],
      capabilities: const <String>[
        'Connection Test',
        'Multi-Tab Layout',
        'Schema Preview',
        'Read-Only Guard',
      ],
    );

    _registerWorkspaceTabs(workspace);

    setState(() {
      _workspaces = <WindowWorkspace>[..._workspaces, workspace];
      _activeWorkspaceIndex = _workspaces.length - 1;
      _windowSeed += 1;
    });
    _schedulePersist();

    _showHint('连接已添加到工作台，下一步只需要把 mock driver 换成真实 MySQL driver。');
    _focusEditorFor(workspace.id, scratch.id);
  }

  Future<void> _runActiveQuery() async {
    await _runSqlForActiveTab(runSelectionOnly: false);
  }

  Future<void> _runSelectedQuery() async {
    await _runSqlForActiveTab(runSelectionOnly: true);
  }

  Future<void> _runSqlForActiveTab({
    required bool runSelectionOnly,
  }) async {
    final workspace = _activeWorkspace;
    final tab = _activeTab;
    final controller = _controllerForActiveTab();
    final fullSql = controller.text.trimRight();
    final selectedSql = _selectedSqlFromValue(controller.value);
    final sql = runSelectionOnly ? selectedSql : fullSql;
    final usedSelection = runSelectionOnly && selectedSql != null;

    if (runSelectionOnly && selectedSql == null) {
      _showHint('先选中一段 SQL，再执行选中内容。');
      _focusEditorFor(workspace.id, tab.id);
      return;
    }

    if (sql == null || sql.trim().isEmpty) {
      _showHint('先写一段 SQL 再运行。');
      _focusEditorFor(workspace.id, tab.id);
      return;
    }

    setState(() {
      _runningTabIds.add(tab.id);
    });

    try {
      final result = await _queryExecutionService.execute(
        config: workspace.connection.config,
        sql: sql,
      );

      if (!mounted) {
        return;
      }

      final latestWorkspaceIndex = _workspaces.indexWhere(
        (item) => item.id == workspace.id,
      );
      if (latestWorkspaceIndex == -1) {
        return;
      }

      final latestWorkspace = _workspaces[latestWorkspaceIndex];
      final updatedTabs = latestWorkspace.tabs.map((currentTab) {
        if (currentTab.id != tab.id) {
          return currentTab;
        }

        return currentTab.copyWith(
          sql: controller.text,
          resultColumns: result.columns,
          resultRows: result.rows,
          resultCountLabel: result.rowCountLabel,
          executionLabel: result.durationLabel,
          updatedAtLabel: _formatTime(DateTime.now()),
          summary: result.summary,
          resultKind: result.kind,
          resultNotice: result.notice,
          resultStatusLabel: result.statusLabel,
          affectedRowCount: result.affectedRowCount,
          resultHighlights: <String>[
            if (usedSelection)
              '本次只执行了当前选中的 SQL 片段。'
            else
              '本次执行了当前 Tab 的 SQL 内容。',
            ...result.highlights,
          ],
          lastRunScopeLabel: usedSelection ? 'Selection' : 'Whole tab',
          dirty: usedSelection,
        );
      }).toList();

      _replaceWorkspaceById(
        workspace.id,
        latestWorkspace.copyWith(
          tabs: updatedTabs,
          recentQueries: <String>[
            sql.trim(),
            ...latestWorkspace.recentQueries.where(
              (entry) => entry != sql.trim(),
            ),
          ].take(6).toList(),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showHint(error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _runningTabIds.remove(tab.id);
      });
    }
  }

  String? _selectedSqlFromValue(TextEditingValue value) {
    final selection = value.selection;
    if (!selection.isValid || selection.isCollapsed) {
      return null;
    }

    final start = selection.start < selection.end
        ? selection.start
        : selection.end;
    final end = selection.start < selection.end
        ? selection.end
        : selection.start;

    if (start < 0 || end > value.text.length || start >= end) {
      return null;
    }

    final selected = value.text.substring(start, end).trim();
    return selected.isEmpty ? null : selected;
  }

  String _tabResourceKey(String workspaceId, String tabId) {
    return '$workspaceId::$tabId';
  }

  PersistedWorkbenchState _captureWorkbenchState() {
    return PersistedWorkbenchState(
      schemaVersion: LocalWorkbenchStore.schemaVersion,
      exportedAt: DateTime.now(),
      activeWorkspaceIndex: _activeWorkspaceIndex,
      workspaces: _workspaces,
    );
  }

  void _schedulePersist() {
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 420), () async {
      try {
        await _workbenchStore.save(_captureWorkbenchState());
      } catch (error) {
        if (!mounted) {
          return;
        }
        _showHint('本地自动保存失败：${error.toString()}');
      }
    });
  }

  Future<void> _restorePersistedState() async {
    try {
      final snapshot = await _workbenchStore.load();
      if (!mounted) {
        return;
      }

      if (snapshot == null) {
        _schedulePersist();
        return;
      }

      _applyPersistedState(snapshot, persist: false);
      _showHint(
        '已从本地恢复 ${snapshot.connectionCount} 个连接和 ${snapshot.tabCount} 个 Tab。',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showHint('本地快照读取失败，已继续使用当前工作台。');
      _schedulePersist();
    }
  }

  void _applyPersistedState(
    PersistedWorkbenchState snapshot, {
    required bool persist,
  }) {
    final workspaces = snapshot.workspaces;
    if (workspaces.isEmpty) {
      return;
    }

    _resetTabResources(workspaces);

    final activeIndex =
        snapshot.activeWorkspaceIndex.clamp(0, workspaces.length - 1) as int;

    setState(() {
      _workspaces = workspaces;
      _activeWorkspaceIndex = activeIndex;
      _scratchSeed = _nextScratchSeedFor(workspaces);
      _windowSeed = _nextWindowSeedFor(workspaces);
    });

    _focusEditorFor(_activeWorkspace.id, _activeTab.id);

    if (persist) {
      _schedulePersist();
    }
  }

  void _resetTabResources(List<WindowWorkspace> workspaces) {
    for (final controller in _tabControllers.values) {
      controller.dispose();
    }
    for (final focusNode in _editorFocusNodes.values) {
      focusNode.dispose();
    }
    _tabControllers.clear();
    _editorFocusNodes.clear();

    for (final workspace in workspaces) {
      _registerWorkspaceTabs(workspace);
    }
  }

  int _nextScratchSeedFor(List<WindowWorkspace> workspaces) {
    var nextSeed = 1;
    for (final workspace in workspaces) {
      for (final tab in workspace.tabs) {
        final match = RegExp(r'^scratch-(\d+)$').firstMatch(tab.id);
        if (match == null) {
          continue;
        }
        final value = int.tryParse(match.group(1) ?? '');
        if (value != null && value >= nextSeed) {
          nextSeed = value + 1;
        }
      }
    }
    return nextSeed;
  }

  int _nextWindowSeedFor(List<WindowWorkspace> workspaces) {
    var nextSeed = 1;
    for (final workspace in workspaces) {
      final match = RegExp(r'^window-(\d+)$').firstMatch(workspace.id);
      if (match == null) {
        continue;
      }
      final value = int.tryParse(match.group(1) ?? '');
      if (value != null && value >= nextSeed) {
        nextSeed = value + 1;
      }
    }
    return nextSeed;
  }

  void _registerWorkspaceTabs(WindowWorkspace workspace) {
    for (final tab in workspace.tabs) {
      _registerTab(workspace.id, tab);
    }
  }

  void _registerTab(String workspaceId, QueryTabModel tab) {
    final key = _tabResourceKey(workspaceId, tab.id);
    if (_tabControllers.containsKey(key)) {
      return;
    }

    final controller = TextEditingController(text: tab.sql);
    controller.addListener(() => _handleTabSqlChanged(workspaceId, tab.id));
    _tabControllers[key] = controller;
    _editorFocusNodes[key] = FocusNode(debugLabel: key);
  }

  void _disposeTabResources(String key) {
    _tabControllers.remove(key)?.dispose();
    _editorFocusNodes.remove(key)?.dispose();
  }

  TextEditingController _controllerForActiveTab() {
    final key = _activeTabKey;
    final controller = _tabControllers[key];
    if (controller != null) {
      return controller;
    }
    _registerTab(_activeWorkspace.id, _activeTab);
    return _tabControllers[key]!;
  }

  FocusNode _focusNodeForActiveTab() {
    final key = _activeTabKey;
    final node = _editorFocusNodes[key];
    if (node != null) {
      return node;
    }
    _registerTab(_activeWorkspace.id, _activeTab);
    return _editorFocusNodes[key]!;
  }

  void _focusEditorFor(String workspaceId, String tabId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final node = _editorFocusNodes[_tabResourceKey(workspaceId, tabId)];
      node?.requestFocus();
    });
  }

  void _handleTabSqlChanged(String workspaceId, String tabId) {
    final controller = _tabControllers[_tabResourceKey(workspaceId, tabId)];
    if (controller == null || !mounted) {
      return;
    }

    final workspaceIndex = _workspaces.indexWhere((workspace) => workspace.id == workspaceId);
    if (workspaceIndex == -1) {
      return;
    }

    final workspace = _workspaces[workspaceIndex];
    final tabIndex = workspace.tabs.indexWhere((tab) => tab.id == tabId);
    if (tabIndex == -1) {
      return;
    }

    final currentTab = workspace.tabs[tabIndex];
    final nextSql = controller.text;
    if (currentTab.sql == nextSql) {
      return;
    }

    final updatedTabs = List<QueryTabModel>.of(workspace.tabs);
    updatedTabs[tabIndex] = currentTab.copyWith(
      sql: nextSql,
      dirty: true,
      summary: _buildSqlSummary(nextSql),
    );

    setState(() {
      _workspaces = List<WindowWorkspace>.of(_workspaces)
        ..[workspaceIndex] = workspace.copyWith(tabs: updatedTabs);
    });
    _schedulePersist();
  }

  String _buildSqlSummary(String sql) {
    final normalized = sql
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .join(' ');
    if (normalized.isEmpty) {
      return '空白 SQL 草稿';
    }
    final preview = normalized.length > 42
        ? '${normalized.substring(0, 42)}...'
        : normalized;
    return preview;
  }

  void _closeActiveTab() {
    _closeTab(_activeTab.id);
  }

  void _formatActiveSql() {
    final controller = _controllerForActiveTab();
    final formatted = _simpleFormatSql(controller.text);
    if (formatted == controller.text) {
      _showHint('当前 SQL 已经比较规整了。');
      return;
    }
    controller.value = controller.value.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
      composing: TextRange.empty,
    );
    _showHint('SQL 已格式化。');
  }

  void _insertSqlTemplate(_SqlTemplatePreset template) {
    final controller = _controllerForActiveTab();
    final currentText = controller.text;
    final selection = controller.selection;

    late final String nextText;
    late final int cursorOffset;

    if (selection.isValid &&
        selection.start >= 0 &&
        selection.end >= selection.start) {
      nextText = currentText.replaceRange(
        selection.start,
        selection.end,
        template.sql,
      );
      cursorOffset = selection.start + template.sql.length;
    } else if (currentText.trim().isEmpty) {
      nextText = template.sql;
      cursorOffset = template.sql.length;
    } else {
      nextText = '$currentText\n\n${template.sql}';
      cursorOffset = nextText.length;
    }

    controller.value = controller.value.copyWith(
      text: nextText,
      selection: TextSelection.collapsed(offset: cursorOffset),
      composing: TextRange.empty,
    );
    _showHint('${template.label} 模板已插入到编辑器。');
    _focusEditorFor(_activeWorkspace.id, _activeTab.id);
  }

  Widget _buildEditorContextMenu(
    BuildContext context,
    EditableTextState editableTextState,
    TextEditingController controller,
  ) {
    final selectedSql = _selectedSqlFromValue(controller.value);
    final buttonItems = List<ContextMenuButtonItem>.of(
      editableTextState.contextMenuButtonItems,
    );

    if (selectedSql != null) {
      buttonItems.insert(
        0,
        ContextMenuButtonItem(
          label: '运行所选 SQL',
          onPressed: () {
            ContextMenuController.removeAny();
            _runSelectedQuery();
          },
        ),
      );
    }

    buttonItems.add(
      ContextMenuButtonItem(
        label: '运行整个 Tab',
        onPressed: () {
          ContextMenuController.removeAny();
          _runActiveQuery();
        },
      ),
    );
    buttonItems.add(
      ContextMenuButtonItem(
        label: '格式化 SQL',
        onPressed: () {
          ContextMenuController.removeAny();
          _formatActiveSql();
        },
      ),
    );

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: buttonItems,
    );
  }

  String _resultKindLabel(QueryResultKind kind) {
    switch (kind) {
      case QueryResultKind.resultSet:
        return 'Result Set';
      case QueryResultKind.mutation:
        return 'Mutation';
      case QueryResultKind.notice:
        return 'Notice';
    }
  }

  Future<void> _openBackupCenter() async {
    final autosavePath = await _workbenchStore.autosavePath();
    final exportJson = _workbenchStore.exportToJson(_captureWorkbenchState());
    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => BackupCenterPage(
          autosavePath: autosavePath,
          initialExportJson: exportJson,
          onRefreshExportJson: () async {
            return _workbenchStore.exportToJson(_captureWorkbenchState());
          },
          onWriteBackupFile: () async {
            return _workbenchStore.writeBackupFile(_captureWorkbenchState());
          },
          onImportJson: (json) async {
            final snapshot = _workbenchStore.importFromJson(json);
            if (!mounted) {
              return '导入完成。';
            }
            _applyPersistedState(snapshot, persist: true);
            return '已导入 ${snapshot.connectionCount} 个连接和 ${snapshot.tabCount} 个 Tab。';
          },
          onImportPath: (path) async {
            final snapshot = await _workbenchStore.importFromFile(path);
            if (!mounted) {
              return '导入完成。';
            }
            _applyPersistedState(snapshot, persist: true);
            return '已从路径导入 ${snapshot.connectionCount} 个连接和 ${snapshot.tabCount} 个 Tab。';
          },
        ),
      ),
    );
  }

  String _simpleFormatSql(String sql) {
    var formatted = sql.trim();
    if (formatted.isEmpty) {
      return formatted;
    }

    const replacements = <String>[
      'SELECT',
      'FROM',
      'WHERE',
      'GROUP BY',
      'ORDER BY',
      'LIMIT',
      'HAVING',
      'LEFT JOIN',
      'RIGHT JOIN',
      'INNER JOIN',
      'OUTER JOIN',
      'JOIN',
      'ON',
      'INSERT INTO',
      'VALUES',
      'UPDATE',
      'SET',
      'DELETE',
    ];

    for (final keyword in replacements) {
      final pattern = keyword.replaceAll(' ', r'\s+');
      formatted = formatted.replaceAllMapped(
        RegExp('\\b$pattern\\b', caseSensitive: false),
        (_) => keyword,
      );
    }

    const newlineKeywords = <String>[
      'FROM',
      'WHERE',
      'GROUP BY',
      'ORDER BY',
      'LIMIT',
      'HAVING',
      'LEFT JOIN',
      'RIGHT JOIN',
      'INNER JOIN',
      'OUTER JOIN',
      'JOIN',
      'VALUES',
      'SET',
      'ON',
    ];

    for (final keyword in newlineKeywords) {
      final pattern = keyword.replaceAll(' ', r'\s+');
      formatted = formatted.replaceAllMapped(
        RegExp('\\s+$pattern\\b'),
        (_) => '\n$keyword',
      );
    }

    formatted = formatted
        .replaceAllMapped(RegExp(r',\s*'), (match) => ',\n  ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n');

    final lines = formatted.split('\n');
    final normalizedLines = <String>[];
    for (final line in lines) {
      if (line.trim().isEmpty) {
        continue;
      }

      final trimmed = line.trim();
      if (trimmed.startsWith('FROM') ||
          trimmed.startsWith('WHERE') ||
          trimmed.startsWith('GROUP BY') ||
          trimmed.startsWith('ORDER BY') ||
          trimmed.startsWith('LIMIT') ||
          trimmed.startsWith('HAVING') ||
          trimmed.startsWith('LEFT JOIN') ||
          trimmed.startsWith('RIGHT JOIN') ||
          trimmed.startsWith('INNER JOIN') ||
          trimmed.startsWith('OUTER JOIN') ||
          trimmed.startsWith('JOIN') ||
          trimmed.startsWith('VALUES') ||
          trimmed.startsWith('SET')) {
        normalizedLines.add(trimmed);
      } else if (normalizedLines.isEmpty || trimmed.startsWith('SELECT') || trimmed.startsWith('UPDATE') || trimmed.startsWith('INSERT INTO') || trimmed.startsWith('DELETE')) {
        normalizedLines.add(trimmed);
      } else {
        normalizedLines.add('  $trimmed');
      }
    }

    return normalizedLines.join('\n');
  }

  String _preferredTableName() {
    for (final root in _activeWorkspace.schema) {
      for (final child in root.children) {
        if (child.kind == 'table') {
          return child.label;
        }
      }
    }
    return _activeWorkspace.connection.database;
  }

  void _openTableDesigner() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => TableDesignerPage(
          connection: _activeWorkspace.connection,
          tableName: _preferredTableName(),
        ),
      ),
    );
  }

  void _openTableDataEditor() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => TableDataPage(
          connection: _activeWorkspace.connection,
          tableName: _preferredTableName(),
        ),
      ),
    );
  }

  void _openSchemaGraph() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SchemaGraphPage(
          connection: _activeWorkspace.connection,
          tableName: _preferredTableName(),
        ),
      ),
    );
  }

  SchemaNode _mapSchemaNode(DatabaseObjectNode node) {
    return SchemaNode(
      label: node.name,
      kind: node.kind,
      children: node.children.map(_mapSchemaNode).toList(),
    );
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void _showHint(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Shortcuts(
        shortcuts: <ShortcutActivator, Intent>{
          const SingleActivator(LogicalKeyboardKey.enter, meta: true):
              const _RunQueryIntent(),
          const SingleActivator(LogicalKeyboardKey.enter, control: true):
              const _RunQueryIntent(),
          const SingleActivator(
            LogicalKeyboardKey.enter,
            meta: true,
            shift: true,
          ): const _RunSelectedQueryIntent(),
          const SingleActivator(
            LogicalKeyboardKey.enter,
            control: true,
            shift: true,
          ): const _RunSelectedQueryIntent(),
          const SingleActivator(LogicalKeyboardKey.keyR, meta: true):
              const _RunQueryIntent(),
          const SingleActivator(LogicalKeyboardKey.keyR, control: true):
              const _RunQueryIntent(),
          const SingleActivator(LogicalKeyboardKey.keyT, meta: true):
              const _NewTabIntent(),
          const SingleActivator(LogicalKeyboardKey.keyT, control: true):
              const _NewTabIntent(),
          const SingleActivator(LogicalKeyboardKey.keyW, meta: true):
              const _CloseTabIntent(),
          const SingleActivator(LogicalKeyboardKey.keyW, control: true):
              const _CloseTabIntent(),
          const SingleActivator(
            LogicalKeyboardKey.keyF,
            meta: true,
            shift: true,
          ): const _FormatSqlIntent(),
          const SingleActivator(
            LogicalKeyboardKey.keyF,
            control: true,
            shift: true,
          ): const _FormatSqlIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            _RunQueryIntent: CallbackAction<_RunQueryIntent>(
              onInvoke: (_) {
                if (!_runningTabIds.contains(_activeTab.id)) {
                  _runActiveQuery();
                }
                return null;
              },
            ),
            _RunSelectedQueryIntent: CallbackAction<_RunSelectedQueryIntent>(
              onInvoke: (_) {
                if (!_runningTabIds.contains(_activeTab.id)) {
                  _runSelectedQuery();
                }
                return null;
              },
            ),
            _NewTabIntent: CallbackAction<_NewTabIntent>(
              onInvoke: (_) {
                _openNewTab();
                return null;
              },
            ),
            _CloseTabIntent: CallbackAction<_CloseTabIntent>(
              onInvoke: (_) {
                _closeActiveTab();
                return null;
              },
            ),
            _FormatSqlIntent: CallbackAction<_FormatSqlIntent>(
              onInvoke: (_) {
                _formatActiveSql();
                return null;
              },
            ),
          },
          child: Focus(
            autofocus: true,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    Color(0xFFF9F4EA),
                    Color(0xFFEAE8DF),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: <Widget>[
                      _buildTopBar(context),
                      const SizedBox(height: 16),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final showInspector = constraints.maxWidth >= 1440;
                            final showSchema = constraints.maxWidth >= 1160;

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                SizedBox(
                                  width: 300,
                                  child: _buildSidebar(context),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildWorkbenchSurface(
                                    context,
                                    showSchema: showSchema,
                                    showInspector: showInspector,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return _PanelShell(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: <Color>[
                  ConnFoxPalette.accent,
                  Color(0xFF0E9A89),
                ],
              ),
            ),
            child: const Icon(
              Icons.dataset_linked_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'ConnFox',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Mac-first Flutter SQL workbench for MySQL and beyond',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: ConnFoxPalette.mutedText,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: TextField(
              readOnly: true,
              onTap: () => _showHint('这里后面适合接命令面板、对象搜索和最近命令。'),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: '搜索连接、表、命令、最近查询...',
              ),
            ),
          ),
          const SizedBox(width: 16),
          OutlinedButton.icon(
            onPressed: _openBackupCenter,
            icon: const Icon(Icons.archive_rounded),
            label: const Text('备份'),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: _openConnectionCenter,
            icon: const Icon(Icons.add_link_rounded),
            label: const Text('新连接'),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: _openNewWindow,
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('新窗口'),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    final connection = _activeWorkspace.connection;

    return _PanelShell(
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: <Widget>[
          Text(
            '当前连接',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: ConnFoxPalette.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: connection.accentColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        connection.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    _CapsuleLabel(text: connection.environment),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${connection.engine} · ${connection.endpoint}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: ConnFoxPalette.mutedText,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Database: ${connection.database}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: ConnFoxPalette.mutedText,
                      ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _SoftMetricChip(
                      label: 'Latency',
                      value: connection.latencyLabel,
                    ),
                    _SoftMetricChip(
                      label: 'Status',
                      value: connection.statusLabel,
                    ),
                    _SoftMetricChip(
                      label: 'Mode',
                      value: connection.readOnly ? 'Read only' : 'Read/write',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text(
            '窗口列表',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < _workspaces.length; i++) ...<Widget>[
            _WorkspaceTile(
              workspace: _workspaces[i],
              active: i == _activeWorkspaceIndex,
              onTap: () => _selectWorkspace(i),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 12),
          Text(
            '目标能力',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _activeWorkspace.capabilities
                .map((item) => _CapabilityChip(label: item))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkbenchSurface(
    BuildContext context, {
    required bool showSchema,
    required bool showInspector,
  }) {
    final connection = _activeWorkspace.connection;

    return _PanelShell(
      child: Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: ConnFoxPalette.panelMuted,
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _activeWorkspace.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_activeWorkspace.subtitle} · ${connection.engine} · ${connection.database}',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: ConnFoxPalette.mutedText,
                      ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    _StatusBadge(
                      icon: Icons.storage_rounded,
                      label: connection.database,
                    ),
                    _StatusBadge(
                      icon: Icons.route_rounded,
                      label: connection.endpoint,
                    ),
                    _StatusBadge(
                      icon: Icons.speed_rounded,
                      label: connection.latencyLabel,
                    ),
                    _StatusBadge(
                      icon: Icons.shield_rounded,
                      label: connection.readOnly ? 'Read only' : 'Editable',
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _showHint('查询历史、保存查询、收藏查询会放在这里。'),
                      icon: const Icon(Icons.history_rounded),
                      label: const Text('历史'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _openTableDesigner,
                      icon: const Icon(Icons.table_view_rounded),
                      label: const Text('表设计'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _openTableDataEditor,
                      icon: const Icon(Icons.edit_note_rounded),
                      label: const Text('数据编辑'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _openSchemaGraph,
                      icon: const Icon(Icons.account_tree_rounded),
                      label: const Text('关系图'),
                    ),
                    FilledButton.icon(
                      onPressed: _openNewTab,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('新 Tab'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: _buildTabStrip(context),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (showSchema) ...<Widget>[
                    SizedBox(width: 250, child: _buildSchemaPanel(context)),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      children: <Widget>[
                        SizedBox(
                          height: 360,
                          child: _buildEditorPanel(context),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: _buildResultsPanel(context),
                        ),
                      ],
                    ),
                  ),
                  if (showInspector) ...<Widget>[
                    const SizedBox(width: 12),
                    SizedBox(width: 270, child: _buildInspectorPanel(context)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabStrip(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _activeWorkspace.tabs
                  .map(
                    (tab) => Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: _WorkbenchTabChip(
                        tab: tab,
                        active: tab.id == _activeWorkspace.activeTabId,
                        onTap: () => _selectTab(tab.id),
                        onClose: () => _closeTab(tab.id),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: _openNewTab,
          icon: const Icon(Icons.add_rounded),
          label: const Text('添加 Tab'),
        ),
      ],
    );
  }

  Widget _buildSchemaPanel(BuildContext context) {
    return _PanelShell(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _PanelTitle(
                  title: 'Schema',
                  subtitle: '懒加载和搜索后续接真实元数据',
                ),
              ),
              IconButton(
                onPressed: _openSchemaGraph,
                icon: const Icon(Icons.account_tree_rounded),
                tooltip: '查看关系图',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView(
              children: _activeWorkspace.schema
                  .map((node) => _SchemaBranch(node: node))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditorPanel(BuildContext context) {
    final controller = _controllerForActiveTab();
    final focusNode = _focusNodeForActiveTab();
    final isRunning = _runningTabIds.contains(_activeTab.id);

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final selectedSql = _selectedSqlFromValue(value);
        final hasSelection = selectedSql != null;
        final sqlLines = value.text.isEmpty ? 1 : value.text.split('\n').length;

        return _PanelShell(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: _PanelTitle(
                      title: 'SQL Editor',
                      subtitle: _activeTab.summary,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _showHint('Explain / Analyze 会放到这里。'),
                    icon: const Icon(Icons.timeline_rounded),
                    label: const Text('Explain'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _formatActiveSql,
                    icon: const Icon(Icons.auto_fix_high_rounded),
                    label: const Text('Format'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: !isRunning && hasSelection ? _runSelectedQuery : null,
                    icon: const Icon(Icons.playlist_play_rounded),
                    label: const Text('Run Selected'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: isRunning ? null : _runActiveQuery,
                    icon: isRunning
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.play_arrow_rounded),
                    label: Text(isRunning ? 'Running' : 'Run All'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  _ShortcutPill(label: 'Run All', shortcut: 'Cmd/Ctrl+Enter / R'),
                  _ShortcutPill(label: 'Run Selected', shortcut: 'Cmd/Ctrl+Shift+Enter'),
                  _ShortcutPill(label: 'New Tab', shortcut: 'Cmd/Ctrl+T'),
                  _ShortcutPill(label: 'Close Tab', shortcut: 'Cmd/Ctrl+W'),
                  _ShortcutPill(label: 'Format', shortcut: 'Cmd/Ctrl+Shift+F'),
                  _ShortcutPill(
                    label: 'Selection',
                    shortcut: hasSelection ? 'Ready' : 'None',
                  ),
                  _ShortcutPill(label: 'Lines', shortcut: '$sqlLines'),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: ConnFoxPalette.editorSurface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        width: 52,
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          List<String>.generate(
                            sqlLines,
                            (index) => '${index + 1}',
                          ).join('\n'),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: Color(0xFF7C8A9A),
                            fontSize: 12,
                            height: 1.65,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          focusNode: focusNode,
                          contextMenuBuilder: (context, editableTextState) =>
                              _buildEditorContextMenu(
                                context,
                                editableTextState,
                                controller,
                              ),
                          maxLines: null,
                          expands: true,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          style: const TextStyle(
                            color: ConnFoxPalette.editorText,
                            fontSize: 14,
                            height: 1.6,
                            fontFamily: 'monospace',
                          ),
                          cursorColor: ConnFoxPalette.accentSoft,
                          decoration: const InputDecoration(
                            isCollapsed: true,
                            filled: false,
                            border: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            hintText: '在这里写任意 SQL，支持查询、DDL、DML、多语句草稿...',
                            hintStyle: TextStyle(
                              color: Color(0xFF6B7C8E),
                              fontSize: 14,
                              height: 1.6,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _sqlTemplates
                    .map(
                      (template) => _SqlTemplateChip(
                        template: template,
                        onTap: () => _insertSqlTemplate(template),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 10),
              Text(
                '支持右键菜单运行选中 SQL；快捷键里，Cmd/Ctrl+Shift+Enter 会只执行当前选区。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: ConnFoxPalette.mutedText,
                    ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResultsPanel(BuildContext context) {
    final tab = _activeTab;

    return _PanelShell(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _PanelTitle(
                  title: 'Results',
                  subtitle:
                      '${tab.resultCountLabel} · ${tab.executionLabel} · updated ${tab.updatedAtLabel}',
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _showHint('结果导出、复制行为下一步接到这里。'),
                icon: const Icon(Icons.download_rounded),
                label: const Text('导出'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _ResultMetricChip(label: 'Type', value: _resultKindLabel(tab.resultKind)),
              _ResultMetricChip(label: 'Scope', value: tab.lastRunScopeLabel),
              _ResultMetricChip(label: 'Status', value: tab.resultStatusLabel),
              _ResultMetricChip(label: 'Summary', value: tab.summary),
              if (tab.affectedRowCount != null)
                _ResultMetricChip(
                  label: 'Affected',
                  value: '${tab.affectedRowCount}',
                ),
            ],
          ),
          if (tab.resultNotice != null && tab.resultNotice!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            _ResultNoticeBanner(message: tab.resultNotice!),
          ],
          if (tab.resultHighlights.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tab.resultHighlights
                  .map((item) => _ResultHighlightChip(label: item))
                  .toList(),
            ),
          ],
          const SizedBox(height: 14),
          Expanded(
            child: switch (tab.resultKind) {
              QueryResultKind.resultSet => _ResultTableView(
                  columns: tab.resultColumns,
                  rows: tab.resultRows,
                  emptyLabel: '当前查询没有返回数据。',
                ),
              QueryResultKind.mutation => _ExecutionFeedbackView(
                  icon: Icons.task_alt_rounded,
                  title: '更新语句执行完成',
                  summary: tab.summary,
                  details: tab.resultRows.isEmpty
                      ? const <String>['当前没有附加结果表。']
                      : const <String>['下方保留了受影响结果的摘要表。'],
                  trailingTable: tab.resultRows.isEmpty
                      ? null
                      : _ResultTableView(
                          columns: tab.resultColumns,
                          rows: tab.resultRows,
                          emptyLabel: '没有可展示的更新反馈表。',
                        ),
                ),
              QueryResultKind.notice => _ExecutionFeedbackView(
                  icon: Icons.info_outline_rounded,
                  title: '执行反馈',
                  summary: tab.summary,
                  details: <String>[
                    if (tab.resultRows.isNotEmpty)
                      '下方保留了驱动返回的辅助信息表。'
                    else
                      '当前语句返回的是说明性反馈，没有结果列表。',
                  ],
                  trailingTable: tab.resultRows.isEmpty
                      ? null
                      : _ResultTableView(
                          columns: tab.resultColumns,
                          rows: tab.resultRows,
                          emptyLabel: '没有可展示的执行反馈。',
                        ),
                ),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInspectorPanel(BuildContext context) {
    return _PanelShell(
      padding: const EdgeInsets.all(18),
      child: ListView(
        children: <Widget>[
          _PanelTitle(
            title: 'Inspector',
            subtitle: '把常用辅助能力放在右侧',
          ),
          const SizedBox(height: 16),
          _InspectorSection(
            title: 'Recent Queries',
            items: _activeWorkspace.recentQueries,
          ),
          const SizedBox(height: 14),
          _InspectorSection(
            title: 'Snippets',
            items: _activeWorkspace.snippets,
          ),
          const SizedBox(height: 14),
          _InspectorSection(
            title: 'Schema Tools',
            items: <String>[
              '表设计：${_preferredTableName()}',
              '表数据编辑：支持脏数据标记',
              '关系图：支持查看外键链路',
            ],
          ),
          const SizedBox(height: 14),
          _InspectorSection(
            title: 'Next Features',
            items: const <String>[
              'SSH / SSL',
              'Keychain',
              'Virtualized Grid',
              'Saved Connections',
              'Export Tasks',
            ],
          ),
        ],
      ),
    );
  }
}

class _ShortcutPill extends StatelessWidget {
  const _ShortcutPill({
    required this.label,
    required this.shortcut,
  });

  final String label;
  final String shortcut;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF324557)),
      ),
      child: RichText(
        text: TextSpan(
          children: <InlineSpan>[
            TextSpan(
              text: '$label ',
              style: const TextStyle(
                color: ConnFoxPalette.editorText,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: shortcut,
              style: const TextStyle(
                color: Color(0xFF9FB0BD),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SqlTemplatePreset {
  const _SqlTemplatePreset({
    required this.label,
    required this.description,
    required this.sql,
  });

  final String label;
  final String description;
  final String sql;
}

class _SqlTemplateChip extends StatelessWidget {
  const _SqlTemplateChip({
    required this.template,
    required this.onTap,
  });

  final _SqlTemplatePreset template;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${template.description}，点击插入模板',
      child: ActionChip(
        avatar: const Icon(
          Icons.note_add_rounded,
          size: 18,
          color: ConnFoxPalette.accent,
        ),
        onPressed: onTap,
        backgroundColor: Colors.white,
        side: const BorderSide(color: ConnFoxPalette.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        label: Text(
          '${template.label} · ${template.description}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: ConnFoxPalette.ink,
              ),
        ),
      ),
    );
  }
}

class _ResultMetricChip extends StatelessWidget {
  const _ResultMetricChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 54),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ConnFoxPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: ConnFoxPalette.mutedText,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _ResultNoticeBanner extends StatelessWidget {
  const _ResultNoticeBanner({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ConnFoxPalette.accentSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ConnFoxPalette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: ConnFoxPalette.accent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: ConnFoxPalette.ink,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultHighlightChip extends StatelessWidget {
  const _ResultHighlightChip({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ConnFoxPalette.panelMuted,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: ConnFoxPalette.ink,
            ),
      ),
    );
  }
}

class _ResultTableView extends StatelessWidget {
  const _ResultTableView({
    required this.columns,
    required this.rows,
    required this.emptyLabel,
  });

  final List<String> columns;
  final List<List<String>> rows;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (columns.isEmpty || rows.isEmpty) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ConnFoxPalette.border),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              emptyLabel,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: ConnFoxPalette.mutedText,
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ConnFoxPalette.border),
      ),
      child: Scrollbar(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 28,
              headingRowColor: const MaterialStatePropertyAll<Color>(
                ConnFoxPalette.panelMuted,
              ),
              columns: columns
                  .map(
                    (column) => DataColumn(
                      label: Text(
                        column,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              rows: rows
                  .map(
                    (row) => DataRow(
                      cells: row
                          .map(
                            (value) => DataCell(
                              Text(
                                value,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExecutionFeedbackView extends StatelessWidget {
  const _ExecutionFeedbackView({
    required this.icon,
    required this.title,
    required this.summary,
    required this.details,
    this.trailingTable,
  });

  final IconData icon;
  final String title;
  final String summary;
  final List<String> details;
  final Widget? trailingTable;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ConnFoxPalette.border),
      ),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: ConnFoxPalette.accentSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: ConnFoxPalette.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      summary,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: ConnFoxPalette.mutedText,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (details.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            for (final detail in details) ...<Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Padding(
                    padding: EdgeInsets.only(top: 5),
                    child: Icon(
                      Icons.circle,
                      size: 8,
                      color: ConnFoxPalette.accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      detail,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ],
          if (trailingTable != null) ...<Widget>[
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: trailingTable,
            ),
          ],
        ],
      ),
    );
  }
}

class _RunQueryIntent extends Intent {
  const _RunQueryIntent();
}

class _RunSelectedQueryIntent extends Intent {
  const _RunSelectedQueryIntent();
}

class _NewTabIntent extends Intent {
  const _NewTabIntent();
}

class _CloseTabIntent extends Intent {
  const _CloseTabIntent();
}

class _FormatSqlIntent extends Intent {
  const _FormatSqlIntent();
}

class _PanelShell extends StatelessWidget {
  const _PanelShell({
    required this.child,
    this.padding,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: ConnFoxPalette.panel,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: ConnFoxPalette.border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _PanelTitle extends StatelessWidget {
  const _PanelTitle({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: ConnFoxPalette.mutedText,
              ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ConnFoxPalette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: ConnFoxPalette.accent),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _SoftMetricChip extends StatelessWidget {
  const _SoftMetricChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: ConnFoxPalette.accentSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _CapsuleLabel extends StatelessWidget {
  const _CapsuleLabel({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ConnFoxPalette.ink,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _CapabilityChip extends StatelessWidget {
  const _CapabilityChip({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ConnFoxPalette.border),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _WorkspaceTile extends StatelessWidget {
  const _WorkspaceTile({
    required this.workspace,
    required this.active,
    required this.onTap,
  });

  final WindowWorkspace workspace;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final connection = workspace.connection;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: active ? ConnFoxPalette.accentSoft : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: active ? ConnFoxPalette.accent : ConnFoxPalette.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                workspace.title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                workspace.subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: ConnFoxPalette.mutedText,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                '${connection.engine} · ${connection.database}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkbenchTabChip extends StatelessWidget {
  const _WorkbenchTabChip({
    required this.tab,
    required this.active,
    required this.onTap,
    required this.onClose,
  });

  final QueryTabModel tab;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: active ? ConnFoxPalette.accentSoft : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: active ? ConnFoxPalette.accent : ConnFoxPalette.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (tab.pinned) ...<Widget>[
                const Icon(
                  Icons.push_pin_rounded,
                  size: 16,
                  color: ConnFoxPalette.warning,
                ),
                const SizedBox(width: 8),
              ],
              Text(
                tab.title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              if (tab.dirty) ...<Widget>[
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: ConnFoxPalette.warning,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onClose,
                child: const Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: ConnFoxPalette.mutedText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SchemaBranch extends StatelessWidget {
  const _SchemaBranch({
    required this.node,
    this.depth = 0,
  });

  final SchemaNode node;
  final int depth;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: depth * 14, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: depth == 0 ? ConnFoxPalette.panelMuted : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ConnFoxPalette.border),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  node.kind == 'database'
                      ? Icons.storage_rounded
                      : node.kind == 'view'
                          ? Icons.visibility_outlined
                          : Icons.table_chart_rounded,
                  size: 16,
                  color: ConnFoxPalette.accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    node.label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                Text(
                  node.kind,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: ConnFoxPalette.mutedText,
                      ),
                ),
              ],
            ),
          ),
          if (node.children.isNotEmpty) ...node.children.map(
            (child) => _SchemaBranch(
              node: child,
              depth: depth + 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _InspectorSection extends StatelessWidget {
  const _InspectorSection({
    required this.title,
    required this.items,
  });

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ConnFoxPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          for (final item in items) ...<Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.only(top: 5),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: ConnFoxPalette.accent,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: ConnFoxPalette.ink,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
