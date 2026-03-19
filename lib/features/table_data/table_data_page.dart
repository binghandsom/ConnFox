import 'package:flutter/material.dart';

import '../../app/connfox_theme.dart';
import '../../data/mock_schema_editor_data.dart';
import '../../domain/schema/schema_editor_models.dart';
import '../../models/workbench_models.dart';

class TableDataPage extends StatefulWidget {
  const TableDataPage({
    super.key,
    required this.connection,
    required this.tableName,
  });

  final ConnectionProfile connection;
  final String tableName;

  @override
  State<TableDataPage> createState() => _TableDataPageState();
}

class _TableDataPageState extends State<TableDataPage> {
  late DataEditorModel _baseline;
  late DataEditorModel _draft;

  bool get _hasPendingChanges => _draft.pendingChangeCount > 0;

  @override
  void initState() {
    super.initState();
    _baseline = buildMockDataEditor(
      widget.connection,
      tableName: widget.tableName,
    );
    _draft = _baseline.clone();
  }

  void _showHint(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _editCell(int rowIndex, DataEditorColumn column) async {
    final row = _draft.rows[rowIndex];
    if (row.pendingDelete) {
      _showHint('这行已经标记为待删除，先撤销删除再编辑。');
      return;
    }

    final controller = TextEditingController(
      text: row.values[column.name] ?? '',
    );

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('编辑 ${column.name}'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: '${column.typeLabel} value',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    if (!mounted || result == null) {
      return;
    }

    final rows = List<EditableRowDraft>.of(_draft.rows);
    final values = Map<String, String>.from(rows[rowIndex].values)
      ..[column.name] = result;
    rows[rowIndex] = rows[rowIndex].copyWith(
      values: values,
      dirty: true,
      pendingDelete: false,
    );

    setState(() {
      _draft = _draft.copyWith(rows: rows);
    });
  }

  void _addRow() {
    final rowNumber = _draft.rows.length + 1;
    final values = <String, String>{
      for (final column in _draft.columns)
        column.name: column.primaryKey ? 'new_$rowNumber' : '',
    };

    setState(() {
      _draft = _draft.copyWith(
        rows: <EditableRowDraft>[
          EditableRowDraft(
            id: 'new-row-$rowNumber',
            values: values,
            dirty: true,
            newlyInserted: true,
          ),
          ..._draft.rows,
        ],
      );
    });
  }

  void _deleteRow(int rowIndex) {
    final rows = List<EditableRowDraft>.of(_draft.rows);
    final row = rows[rowIndex];

    if (row.newlyInserted) {
      rows.removeAt(rowIndex);
    } else {
      rows[rowIndex] = row.copyWith(
        pendingDelete: !row.pendingDelete,
        dirty: !row.pendingDelete ? true : row.dirty,
      );
    }

    setState(() {
      _draft = _draft.copyWith(rows: rows);
    });
  }

  void _discardChanges() {
    setState(() {
      _draft = _baseline.clone();
    });
    _showHint('未保存的表数据变更已回滚到上一次快照。');
  }

  void _saveChanges() {
    final committedRows = _draft.rows
        .where((row) => !row.pendingDelete)
        .map(
          (row) => row.copyWith(
            dirty: false,
            newlyInserted: false,
            pendingDelete: false,
          ),
        )
        .toList();

    setState(() {
      _baseline = _draft.copyWith(
        rows: committedRows,
      );
      _draft = _baseline.clone();
    });
    _showHint('已确认提交草稿变更。下一步接真实 UPDATE / INSERT / DELETE 后这里就会写入数据库。');
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
            child: Column(
              children: <Widget>[
                _buildHeader(context),
                const SizedBox(height: 16),
                _buildDraftBanner(context),
                const SizedBox(height: 16),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      SizedBox(width: 320, child: _buildGuidePanel(context)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildGridPanel(context)),
                    ],
                  ),
                ),
                if (_hasPendingChanges) ...<Widget>[
                  const SizedBox(height: 16),
                  _buildPendingActionBar(context),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return _DataPanel(
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
                  'Table Data Editor',
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
            onPressed: _discardChanges,
            icon: const Icon(Icons.restore_rounded),
            label: const Text('放弃变更'),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: _addRow,
            icon: const Icon(Icons.add_rounded),
            label: const Text('新增行'),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: _saveChanges,
            icon: const Icon(Icons.save_rounded),
            label: const Text('确认提交'),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftBanner(BuildContext context) {
    return _DataPanel(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: ConnFoxPalette.accentSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.inventory_2_rounded,
              color: ConnFoxPalette.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _hasPendingChanges
                  ? '当前修改都只保存在本地草稿里，点“确认提交”之后才会真正应用到数据库。'
                  : '当前处于安全编辑模式。你可以先改，再统一点击“确认提交”。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          const SizedBox(width: 12),
          _HeaderBadge(
            label: '待提交 ${_draft.pendingChangeCount}',
          ),
        ],
      ),
    );
  }

  Widget _buildGuidePanel(BuildContext context) {
    return _DataPanel(
      padding: const EdgeInsets.all(18),
      child: ListView(
        children: <Widget>[
          Text(
            'Editing Rules',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 14),
          _InfoStat(label: 'Dirty Rows', value: '${_draft.dirtyRowsCount}'),
          const SizedBox(height: 10),
          _InfoStat(label: 'Pending Delete', value: '${_draft.pendingDeleteCount}'),
          const SizedBox(height: 10),
          _InfoStat(label: 'Loaded Rows', value: '${_draft.rows.length}'),
          const SizedBox(height: 10),
          _InfoStat(label: 'Dataset Size', value: '${_draft.totalRowEstimate}'),
          const SizedBox(height: 16),
          _ChecklistBox(
            title: '好用的数据编辑器应该有',
            items: const <String>[
              '逐格编辑和整行新增',
              '脏数据标记',
              '待删除先标记，不直接生效',
              '批量保存和回滚',
              '主键 / 条件更新保护',
              '大结果集分页',
            ],
          ),
          const SizedBox(height: 16),
          _ChecklistBox(
            title: '下一步接真实库时要加',
            items: const <String>[
              '事务提交',
              '乐观锁或版本列',
              '只更新修改过的字段',
              '行级错误提示',
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGridPanel(BuildContext context) {
    return _DataPanel(
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  readOnly: true,
                  onTap: () => _showHint('下一步这里适合接过滤器、排序和主键定位。'),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: '筛选行、定位主键、快速过滤...',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _HeaderBadge(label: _draft.pageLabel),
              const SizedBox(width: 10),
              _HeaderBadge(label: '${_draft.totalRowEstimate} total'),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Theme(
              data: Theme.of(context).copyWith(
                dividerColor: ConnFoxPalette.border,
              ),
              child: DataTable(
                columnSpacing: 24,
                headingRowColor: const MaterialStatePropertyAll<Color>(
                  ConnFoxPalette.panelMuted,
                ),
                columns: <DataColumn>[
                  const DataColumn(label: Text('State')),
                  ..._draft.columns.map(
                    (column) => DataColumn(
                      label: Text(
                        column.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const DataColumn(label: Text('Actions')),
                ],
                rows: List<DataRow>.generate(_draft.rows.length, (rowIndex) {
                  final row = _draft.rows[rowIndex];
                  return DataRow(
                    color: row.pendingDelete
                        ? const MaterialStatePropertyAll<Color>(
                            Color(0xFFFDE7E7),
                          )
                        : row.dirty
                            ? const MaterialStatePropertyAll<Color>(
                                Color(0xFFFDF4DD),
                              )
                            : null,
                    cells: <DataCell>[
                      DataCell(
                        _RowStateChip(row: row),
                      ),
                      ..._draft.columns.map(
                        (column) => DataCell(
                          Text(
                            row.values[column.name] ?? '',
                            style: TextStyle(
                              fontWeight: column.primaryKey
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              decoration: row.pendingDelete
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                              color: row.pendingDelete
                                  ? ConnFoxPalette.mutedText
                                  : ConnFoxPalette.ink,
                            ),
                          ),
                          showEditIcon: !row.pendingDelete,
                          onTap: row.pendingDelete
                              ? null
                              : () => _editCell(rowIndex, column),
                        ),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            IconButton(
                              onPressed: row.pendingDelete
                                  ? null
                                  : () => _editCell(rowIndex, _draft.columns.first),
                              icon: const Icon(Icons.edit_rounded),
                            ),
                            IconButton(
                              onPressed: () => _deleteRow(rowIndex),
                              icon: Icon(
                                row.pendingDelete
                                    ? Icons.restore_from_trash_rounded
                                    : Icons.delete_outline_rounded,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingActionBar(BuildContext context) {
    return _DataPanel(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '待确认变更',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_draft.pendingChangeCount} 条变更还在草稿中，只有点“确认提交”才会真正应用。',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: ConnFoxPalette.mutedText,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: _discardChanges,
            icon: const Icon(Icons.restore_rounded),
            label: const Text('全部回滚'),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: _saveChanges,
            icon: const Icon(Icons.task_alt_rounded),
            label: const Text('确认提交'),
          ),
        ],
      ),
    );
  }
}

class _DataPanel extends StatelessWidget {
  const _DataPanel({
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

class _InfoStat extends StatelessWidget {
  const _InfoStat({
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
          Expanded(child: Text(label)),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistBox extends StatelessWidget {
  const _ChecklistBox({
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
                  padding: EdgeInsets.only(top: 4),
                  child: Icon(
                    Icons.check_circle_outline_rounded,
                    size: 16,
                    color: ConnFoxPalette.accent,
                  ),
                ),
                const SizedBox(width: 8),
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

class _HeaderBadge extends StatelessWidget {
  const _HeaderBadge({
    required this.label,
  });

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
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _RowStateChip extends StatelessWidget {
  const _RowStateChip({
    required this.row,
  });

  final EditableRowDraft row;

  @override
  Widget build(BuildContext context) {
    final label = row.pendingDelete
        ? 'Delete'
        : row.newlyInserted
            ? 'New'
            : row.dirty
                ? 'Dirty'
                : 'Clean';

    final color = row.pendingDelete
        ? const Color(0xFFFDE7E7)
        : row.newlyInserted
            ? const Color(0xFFE6F4EA)
            : row.dirty
                ? const Color(0xFFFDF4DD)
                : const Color(0xFFEEF2F7);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}
