import 'package:flutter/material.dart';

import '../../app/connfox_theme.dart';
import '../../data/mock_schema_editor_data.dart';
import '../../domain/schema/schema_editor_models.dart';
import '../../models/workbench_models.dart';

class TableDesignerPage extends StatefulWidget {
  const TableDesignerPage({
    super.key,
    required this.connection,
    required this.tableName,
  });

  final ConnectionProfile connection;
  final String tableName;

  @override
  State<TableDesignerPage> createState() => _TableDesignerPageState();
}

class _TableDesignerPageState extends State<TableDesignerPage> {
  static const List<String> _typeOptions = <String>[
    'BIGINT UNSIGNED',
    'INT',
    'VARCHAR(64)',
    'VARCHAR(128)',
    'VARCHAR(255)',
    'TEXT',
    'DECIMAL(12,2)',
    'DATETIME',
    'TIMESTAMP',
    'JSON',
    'BOOLEAN',
  ];

  late TableDesignDraft _draft;

  @override
  void initState() {
    super.initState();
    _draft = buildMockTableDesign(
      widget.connection,
      tableName: widget.tableName,
    );
  }

  void _updateDraft(TableDesignDraft draft) {
    setState(() {
      _draft = draft;
    });
  }

  void _addColumn() {
    _updateDraft(
      _draft.copyWith(
        columns: <TableColumnDraft>[
          ..._draft.columns,
          const TableColumnDraft(
            name: 'new_column',
            typeLabel: 'VARCHAR(128)',
            nullable: true,
          ),
        ],
      ),
    );
  }

  void _removeColumn(int index) {
    final columns = List<TableColumnDraft>.of(_draft.columns)..removeAt(index);
    _updateDraft(_draft.copyWith(columns: columns));
  }

  void _updateColumn(
    int index,
    TableColumnDraft Function(TableColumnDraft current) updater,
  ) {
    final columns = List<TableColumnDraft>.of(_draft.columns);
    columns[index] = updater(columns[index]);
    _updateDraft(_draft.copyWith(columns: columns));
  }

  void _addIndex() {
    final nextIndex = _draft.indexes.length + 1;
    _updateDraft(
      _draft.copyWith(
        indexes: <TableIndexDraft>[
          ..._draft.indexes,
          TableIndexDraft(
            name: 'idx_${_draft.tableName}_$nextIndex',
            kind: TableIndexKind.secondary,
            columns: <String>[_draft.columns.first.name],
          ),
        ],
      ),
    );
  }

  void _removeIndex(int index) {
    final indexes = List<TableIndexDraft>.of(_draft.indexes)..removeAt(index);
    _updateDraft(_draft.copyWith(indexes: indexes));
  }

  void _updateIndex(
    int index,
    TableIndexDraft Function(TableIndexDraft current) updater,
  ) {
    final indexes = List<TableIndexDraft>.of(_draft.indexes);
    indexes[index] = updater(indexes[index]);
    _updateDraft(_draft.copyWith(indexes: indexes));
  }

  void _addForeignKey() {
    final nextIndex = _draft.foreignKeys.length + 1;
    _updateDraft(
      _draft.copyWith(
        foreignKeys: <ForeignKeyDraft>[
          ..._draft.foreignKeys,
          ForeignKeyDraft(
            name: 'fk_${_draft.tableName}_$nextIndex',
            sourceColumns: <String>[_draft.columns.first.name],
            referenceTable: 'parent_table',
            referenceColumns: const <String>['id'],
          ),
        ],
      ),
    );
  }

  void _removeForeignKey(int index) {
    final foreignKeys = List<ForeignKeyDraft>.of(_draft.foreignKeys)..removeAt(index);
    _updateDraft(_draft.copyWith(foreignKeys: foreignKeys));
  }

  void _updateForeignKey(
    int index,
    ForeignKeyDraft Function(ForeignKeyDraft current) updater,
  ) {
    final foreignKeys = List<ForeignKeyDraft>.of(_draft.foreignKeys);
    foreignKeys[index] = updater(foreignKeys[index]);
    _updateDraft(_draft.copyWith(foreignKeys: foreignKeys));
  }

  void _showHint(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              Color(0xFFF8F3EA),
              Color(0xFFE7E5DE),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 1260;

                return compact
                    ? Column(
                        children: <Widget>[
                          _buildHeader(context),
                          const SizedBox(height: 16),
                          Expanded(
                            child: ListView(
                              children: <Widget>[
                                _buildOverviewPanel(context),
                                const SizedBox(height: 16),
                                _buildEditorPanel(context),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: <Widget>[
                          _buildHeader(context),
                          const SizedBox(height: 16),
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                SizedBox(
                                  width: 320,
                                  child: _buildOverviewPanel(context),
                                ),
                                const SizedBox(width: 16),
                                Expanded(child: _buildEditorPanel(context)),
                              ],
                            ),
                          ),
                        ],
                      );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return _DesignerPanel(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Table Designer',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.connection.name} · ${_draft.schemaName}.${_draft.tableName}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: ConnFoxPalette.mutedText,
                      ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => _showHint('这里后面可以直接弹出 Diff 预览和 Alter SQL。'),
            icon: const Icon(Icons.compare_arrows_rounded),
            label: const Text('结构 Diff'),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: () => _showHint('当前 SQL 预览已准备好，后面可以接复制和执行。'),
            icon: const Icon(Icons.code_rounded),
            label: const Text('预览 SQL'),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: () => _showHint('下一步接真实 DDL 执行后，这里就能直接创建表。'),
            icon: const Icon(Icons.construction_rounded),
            label: const Text('创建表'),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewPanel(BuildContext context) {
    return _DesignerPanel(
      padding: const EdgeInsets.all(18),
      child: ListView(
        children: <Widget>[
          Text(
            'Design Summary',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 14),
          _MetricTile(
            label: 'Columns',
            value: '${_draft.columns.length}',
          ),
          const SizedBox(height: 10),
          _MetricTile(
            label: 'Indexes',
            value: '${_draft.indexes.length}',
          ),
          const SizedBox(height: 10),
          _MetricTile(
            label: 'Foreign Keys',
            value: '${_draft.foreignKeys.length}',
          ),
          const SizedBox(height: 16),
          _InfoCard(
            title: '要好用，表设计要做到',
            items: const <String>[
              '创建表和 Alter Table 分开处理',
              '字段改名、默认值、索引变化都有 Diff',
              '危险变更前给出明确确认',
              '生成 SQL 可复制、可回滚、可审阅',
            ],
          ),
          const SizedBox(height: 16),
          _InfoCard(
            title: '当前已预留的后续点',
            items: const <String>[
              '在线 DDL 选项',
              '字段注释与索引策略',
              '迁移预览',
              '回滚脚本',
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditorPanel(BuildContext context) {
    return _DesignerPanel(
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: <Widget>[
          _SectionCard(
            title: 'Table Basics',
            subtitle: '表名、引擎和注释信息',
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextFormField(
                        initialValue: _draft.tableName,
                        decoration: const InputDecoration(
                          labelText: 'Table Name',
                        ),
                        onChanged: (value) {
                          _updateDraft(_draft.copyWith(tableName: value.trim()));
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        initialValue: _draft.engineName,
                        decoration: const InputDecoration(
                          labelText: 'Engine',
                        ),
                        onChanged: (value) {
                          _updateDraft(_draft.copyWith(engineName: value.trim()));
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: _draft.comment ?? '',
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Comment',
                  ),
                  onChanged: (value) {
                    _updateDraft(_draft.copyWith(comment: value.trim()));
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Columns',
            subtitle: '建表最核心的一层，后续这里要支持更细的类型参数和变更提示',
            trailing: OutlinedButton.icon(
              onPressed: _addColumn,
              icon: const Icon(Icons.add_rounded),
              label: const Text('添加字段'),
            ),
            child: Column(
              children: List<Widget>.generate(_draft.columns.length, (index) {
                final column = _draft.columns[index];
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == _draft.columns.length - 1 ? 0 : 14,
                  ),
                  child: _ColumnCard(
                    title: 'Column ${index + 1}',
                    child: Column(
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: TextFormField(
                                key: ValueKey('column-name-$index-${column.name}'),
                                initialValue: column.name,
                                decoration: const InputDecoration(
                                  labelText: 'Column Name',
                                ),
                                onChanged: (value) {
                                  _updateColumn(
                                    index,
                                    (current) => current.copyWith(name: value.trim()),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _typeOptions.contains(column.typeLabel)
                                    ? column.typeLabel
                                    : _typeOptions.first,
                                decoration: const InputDecoration(
                                  labelText: 'Type',
                                ),
                                items: _typeOptions
                                    .map(
                                      (type) => DropdownMenuItem<String>(
                                        value: type,
                                        child: Text(type),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value == null) {
                                    return;
                                  }
                                  _updateColumn(
                                    index,
                                    (current) => current.copyWith(typeLabel: value),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: TextFormField(
                                key: ValueKey('column-default-$index-${column.defaultValue ?? ''}'),
                                initialValue: column.defaultValue ?? '',
                                decoration: const InputDecoration(
                                  labelText: 'Default Value',
                                ),
                                onChanged: (value) {
                                  _updateColumn(
                                    index,
                                    (current) => current.copyWith(
                                      defaultValue: value.trim().isEmpty ? null : value.trim(),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                key: ValueKey('column-comment-$index-${column.comment ?? ''}'),
                                initialValue: column.comment ?? '',
                                decoration: const InputDecoration(
                                  labelText: 'Comment',
                                ),
                                onChanged: (value) {
                                  _updateColumn(
                                    index,
                                    (current) => current.copyWith(
                                      comment: value.trim().isEmpty ? null : value.trim(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: <Widget>[
                            _ToggleChip(
                              label: 'Nullable',
                              selected: column.nullable,
                              onTap: () {
                                _updateColumn(
                                  index,
                                  (current) => current.copyWith(nullable: !current.nullable),
                                );
                              },
                            ),
                            _ToggleChip(
                              label: 'Primary Key',
                              selected: column.primaryKey,
                              onTap: () {
                                _updateColumn(
                                  index,
                                  (current) => current.copyWith(
                                    primaryKey: !current.primaryKey,
                                    nullable: current.primaryKey ? current.nullable : false,
                                  ),
                                );
                              },
                            ),
                            _ToggleChip(
                              label: 'Auto Increment',
                              selected: column.autoIncrement,
                              onTap: () {
                                _updateColumn(
                                  index,
                                  (current) => current.copyWith(
                                    autoIncrement: !current.autoIncrement,
                                  ),
                                );
                              },
                            ),
                            _ToggleChip(
                              label: 'Unique',
                              selected: column.unique,
                              onTap: () {
                                _updateColumn(
                                  index,
                                  (current) => current.copyWith(unique: !current.unique),
                                );
                              },
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _removeColumn(index),
                              icon: const Icon(Icons.delete_outline_rounded),
                              label: const Text('删除'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Indexes',
            subtitle: '后面这里要支持索引命中预估和命名规范提醒',
            trailing: OutlinedButton.icon(
              onPressed: _addIndex,
              icon: const Icon(Icons.add_rounded),
              label: const Text('添加索引'),
            ),
            child: Column(
              children: List<Widget>.generate(_draft.indexes.length, (index) {
                final item = _draft.indexes[index];
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == _draft.indexes.length - 1 ? 0 : 12,
                  ),
                  child: _ColumnCard(
                    title: item.kind.label,
                    child: Column(
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: TextFormField(
                                initialValue: item.name,
                                decoration: const InputDecoration(
                                  labelText: 'Index Name',
                                ),
                                onChanged: (value) {
                                  _updateIndex(
                                    index,
                                    (current) => current.copyWith(name: value.trim()),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<TableIndexKind>(
                                value: item.kind,
                                decoration: const InputDecoration(
                                  labelText: 'Kind',
                                ),
                                items: TableIndexKind.values
                                    .map(
                                      (kind) => DropdownMenuItem<TableIndexKind>(
                                        value: kind,
                                        child: Text(kind.label),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value == null) {
                                    return;
                                  }
                                  _updateIndex(
                                    index,
                                    (current) => current.copyWith(kind: value),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          initialValue: item.columns.join(', '),
                          decoration: const InputDecoration(
                            labelText: 'Columns',
                            hintText: 'customer_id, status',
                          ),
                          onChanged: (value) {
                            _updateIndex(
                              index,
                              (current) => current.copyWith(
                                columns: value
                                    .split(',')
                                    .map((column) => column.trim())
                                    .where((column) => column.isNotEmpty)
                                    .toList(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            onPressed: () => _removeIndex(index),
                            icon: const Icon(Icons.delete_outline_rounded),
                            label: const Text('删除'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Foreign Keys',
            subtitle: '后续可以在这里直接联动关系图和级联策略提示',
            trailing: OutlinedButton.icon(
              onPressed: _addForeignKey,
              icon: const Icon(Icons.add_rounded),
              label: const Text('添加外键'),
            ),
            child: Column(
              children: List<Widget>.generate(_draft.foreignKeys.length, (index) {
                final item = _draft.foreignKeys[index];
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == _draft.foreignKeys.length - 1 ? 0 : 12,
                  ),
                  child: _ColumnCard(
                    title: item.name,
                    child: Column(
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: TextFormField(
                                initialValue: item.sourceColumns.join(', '),
                                decoration: const InputDecoration(
                                  labelText: 'Source Columns',
                                ),
                                onChanged: (value) {
                                  _updateForeignKey(
                                    index,
                                    (current) => current.copyWith(
                                      sourceColumns: value
                                          .split(',')
                                          .map((column) => column.trim())
                                          .where((column) => column.isNotEmpty)
                                          .toList(),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                initialValue: item.referenceTable,
                                decoration: const InputDecoration(
                                  labelText: 'Reference Table',
                                ),
                                onChanged: (value) {
                                  _updateForeignKey(
                                    index,
                                    (current) => current.copyWith(
                                      referenceTable: value.trim(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: TextFormField(
                                initialValue: item.referenceColumns.join(', '),
                                decoration: const InputDecoration(
                                  labelText: 'Reference Columns',
                                ),
                                onChanged: (value) {
                                  _updateForeignKey(
                                    index,
                                    (current) => current.copyWith(
                                      referenceColumns: value
                                          .split(',')
                                          .map((column) => column.trim())
                                          .where((column) => column.isNotEmpty)
                                          .toList(),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                initialValue: '${item.onDelete} / ${item.onUpdate}',
                                decoration: const InputDecoration(
                                  labelText: 'Delete / Update',
                                ),
                                onChanged: (value) {
                                  final parts = value.split('/');
                                  _updateForeignKey(
                                    index,
                                    (current) => current.copyWith(
                                      onDelete: parts.first.trim().isEmpty
                                          ? current.onDelete
                                          : parts.first.trim(),
                                      onUpdate: parts.length < 2 || parts[1].trim().isEmpty
                                          ? current.onUpdate
                                          : parts[1].trim(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            onPressed: () => _removeForeignKey(index),
                            icon: const Icon(Icons.delete_outline_rounded),
                            label: const Text('删除'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Generated SQL',
            subtitle: '这块后面可以切换 Create / Alter / Rollback 三种视图',
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: ConnFoxPalette.editorSurface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: SelectableText(
                _draft.toCreateTableSql(),
                style: const TextStyle(
                  color: ConnFoxPalette.editorText,
                  fontFamily: 'monospace',
                  height: 1.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DesignerPanel extends StatelessWidget {
  const _DesignerPanel({
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
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: ConnFoxPalette.border),
      ),
      child: child,
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: ConnFoxPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: ConnFoxPalette.mutedText,
                          ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ConnFoxPalette.border),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.items,
  });

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
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
                Expanded(child: Text(item)),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _ColumnCard extends StatelessWidget {
  const _ColumnCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ConnFoxPalette.panelMuted,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? ConnFoxPalette.accentSoft : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? ConnFoxPalette.accent : ConnFoxPalette.border,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}
