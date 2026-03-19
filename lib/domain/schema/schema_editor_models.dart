enum TableIndexKind {
  primary,
  unique,
  secondary,
  fullText,
}

extension TableIndexKindPresentation on TableIndexKind {
  String get label {
    switch (this) {
      case TableIndexKind.primary:
        return 'PRIMARY';
      case TableIndexKind.unique:
        return 'UNIQUE';
      case TableIndexKind.secondary:
        return 'INDEX';
      case TableIndexKind.fullText:
        return 'FULLTEXT';
    }
  }
}

class TableColumnDraft {
  const TableColumnDraft({
    required this.name,
    required this.typeLabel,
    this.nullable = true,
    this.primaryKey = false,
    this.autoIncrement = false,
    this.unique = false,
    this.defaultValue,
    this.comment,
  });

  final String name;
  final String typeLabel;
  final bool nullable;
  final bool primaryKey;
  final bool autoIncrement;
  final bool unique;
  final String? defaultValue;
  final String? comment;

  TableColumnDraft copyWith({
    String? name,
    String? typeLabel,
    bool? nullable,
    bool? primaryKey,
    bool? autoIncrement,
    bool? unique,
    String? defaultValue,
    String? comment,
  }) {
    return TableColumnDraft(
      name: name ?? this.name,
      typeLabel: typeLabel ?? this.typeLabel,
      nullable: nullable ?? this.nullable,
      primaryKey: primaryKey ?? this.primaryKey,
      autoIncrement: autoIncrement ?? this.autoIncrement,
      unique: unique ?? this.unique,
      defaultValue: defaultValue ?? this.defaultValue,
      comment: comment ?? this.comment,
    );
  }
}

class TableIndexDraft {
  const TableIndexDraft({
    required this.name,
    required this.kind,
    required this.columns,
  });

  final String name;
  final TableIndexKind kind;
  final List<String> columns;

  TableIndexDraft copyWith({
    String? name,
    TableIndexKind? kind,
    List<String>? columns,
  }) {
    return TableIndexDraft(
      name: name ?? this.name,
      kind: kind ?? this.kind,
      columns: columns ?? this.columns,
    );
  }
}

class ForeignKeyDraft {
  const ForeignKeyDraft({
    required this.name,
    required this.sourceColumns,
    required this.referenceTable,
    required this.referenceColumns,
    this.onDelete = 'RESTRICT',
    this.onUpdate = 'CASCADE',
  });

  final String name;
  final List<String> sourceColumns;
  final String referenceTable;
  final List<String> referenceColumns;
  final String onDelete;
  final String onUpdate;

  ForeignKeyDraft copyWith({
    String? name,
    List<String>? sourceColumns,
    String? referenceTable,
    List<String>? referenceColumns,
    String? onDelete,
    String? onUpdate,
  }) {
    return ForeignKeyDraft(
      name: name ?? this.name,
      sourceColumns: sourceColumns ?? this.sourceColumns,
      referenceTable: referenceTable ?? this.referenceTable,
      referenceColumns: referenceColumns ?? this.referenceColumns,
      onDelete: onDelete ?? this.onDelete,
      onUpdate: onUpdate ?? this.onUpdate,
    );
  }
}

class TableDesignDraft {
  const TableDesignDraft({
    required this.schemaName,
    required this.tableName,
    required this.engineName,
    required this.columns,
    required this.indexes,
    required this.foreignKeys,
    this.comment,
  });

  final String schemaName;
  final String tableName;
  final String engineName;
  final List<TableColumnDraft> columns;
  final List<TableIndexDraft> indexes;
  final List<ForeignKeyDraft> foreignKeys;
  final String? comment;

  TableDesignDraft copyWith({
    String? schemaName,
    String? tableName,
    String? engineName,
    List<TableColumnDraft>? columns,
    List<TableIndexDraft>? indexes,
    List<ForeignKeyDraft>? foreignKeys,
    String? comment,
  }) {
    return TableDesignDraft(
      schemaName: schemaName ?? this.schemaName,
      tableName: tableName ?? this.tableName,
      engineName: engineName ?? this.engineName,
      columns: columns ?? this.columns,
      indexes: indexes ?? this.indexes,
      foreignKeys: foreignKeys ?? this.foreignKeys,
      comment: comment ?? this.comment,
    );
  }

  String toCreateTableSql() {
    final definitions = <String>[
      for (final column in columns) _buildColumnSql(column),
      for (final index in indexes) _buildIndexSql(index),
      for (final foreignKey in foreignKeys) _buildForeignKeySql(foreignKey),
    ];

    final commentClause =
        comment == null || comment!.trim().isEmpty ? '' : "\nCOMMENT='${comment!.trim()}'";

    return '''
CREATE TABLE `$schemaName`.`$tableName` (
  ${definitions.join(',\n  ')}
)
ENGINE=$engineName
DEFAULT CHARSET=utf8mb4$commentClause;
''';
  }

  String _buildColumnSql(TableColumnDraft column) {
    final parts = <String>[
      '`${column.name}`',
      column.typeLabel,
      column.nullable ? 'NULL' : 'NOT NULL',
      if (column.autoIncrement) 'AUTO_INCREMENT',
      if (column.unique && !column.primaryKey) 'UNIQUE',
      if (column.defaultValue != null && column.defaultValue!.trim().isNotEmpty)
        'DEFAULT ${column.defaultValue}',
      if (column.comment != null && column.comment!.trim().isNotEmpty)
        "COMMENT '${column.comment!.trim()}'",
    ];
    return parts.join(' ');
  }

  String _buildIndexSql(TableIndexDraft index) {
    final joinedColumns =
        index.columns.map((column) => '`$column`').join(', ');

    switch (index.kind) {
      case TableIndexKind.primary:
        return 'PRIMARY KEY ($joinedColumns)';
      case TableIndexKind.unique:
        return 'UNIQUE KEY `${index.name}` ($joinedColumns)';
      case TableIndexKind.secondary:
        return 'KEY `${index.name}` ($joinedColumns)';
      case TableIndexKind.fullText:
        return 'FULLTEXT KEY `${index.name}` ($joinedColumns)';
    }
  }

  String _buildForeignKeySql(ForeignKeyDraft fk) {
    final source = fk.sourceColumns.map((column) => '`$column`').join(', ');
    final target = fk.referenceColumns.map((column) => '`$column`').join(', ');
    return 'CONSTRAINT `${fk.name}` FOREIGN KEY ($source) REFERENCES `${fk.referenceTable}` ($target) ON UPDATE ${fk.onUpdate} ON DELETE ${fk.onDelete}';
  }
}

class DataEditorColumn {
  const DataEditorColumn({
    required this.name,
    required this.typeLabel,
    this.primaryKey = false,
    this.nullable = true,
  });

  final String name;
  final String typeLabel;
  final bool primaryKey;
  final bool nullable;
}

class EditableRowDraft {
  const EditableRowDraft({
    required this.id,
    required this.values,
    this.dirty = false,
    this.newlyInserted = false,
    this.pendingDelete = false,
  });

  final String id;
  final Map<String, String> values;
  final bool dirty;
  final bool newlyInserted;
  final bool pendingDelete;

  EditableRowDraft copyWith({
    String? id,
    Map<String, String>? values,
    bool? dirty,
    bool? newlyInserted,
    bool? pendingDelete,
  }) {
    return EditableRowDraft(
      id: id ?? this.id,
      values: values ?? this.values,
      dirty: dirty ?? this.dirty,
      newlyInserted: newlyInserted ?? this.newlyInserted,
      pendingDelete: pendingDelete ?? this.pendingDelete,
    );
  }

  EditableRowDraft clone() {
    return EditableRowDraft(
      id: id,
      values: Map<String, String>.from(values),
      dirty: dirty,
      newlyInserted: newlyInserted,
      pendingDelete: pendingDelete,
    );
  }
}

class DataEditorModel {
  const DataEditorModel({
    required this.schemaName,
    required this.tableName,
    required this.columns,
    required this.rows,
    required this.totalRowEstimate,
    required this.pageLabel,
  });

  final String schemaName;
  final String tableName;
  final List<DataEditorColumn> columns;
  final List<EditableRowDraft> rows;
  final int totalRowEstimate;
  final String pageLabel;

  int get dirtyRowsCount => rows.where((row) => row.dirty).length;
  int get pendingDeleteCount => rows.where((row) => row.pendingDelete).length;
  int get pendingChangeCount => rows
      .where((row) => row.dirty || row.newlyInserted || row.pendingDelete)
      .length;

  DataEditorModel copyWith({
    String? schemaName,
    String? tableName,
    List<DataEditorColumn>? columns,
    List<EditableRowDraft>? rows,
    int? totalRowEstimate,
    String? pageLabel,
  }) {
    return DataEditorModel(
      schemaName: schemaName ?? this.schemaName,
      tableName: tableName ?? this.tableName,
      columns: columns ?? this.columns,
      rows: rows ?? this.rows,
      totalRowEstimate: totalRowEstimate ?? this.totalRowEstimate,
      pageLabel: pageLabel ?? this.pageLabel,
    );
  }

  DataEditorModel clone() {
    return DataEditorModel(
      schemaName: schemaName,
      tableName: tableName,
      columns: List<DataEditorColumn>.from(columns),
      rows: rows.map((row) => row.clone()).toList(),
      totalRowEstimate: totalRowEstimate,
      pageLabel: pageLabel,
    );
  }
}

class SchemaDiagramNode {
  const SchemaDiagramNode({
    required this.id,
    required this.title,
    required this.kind,
    required this.positionX,
    required this.positionY,
    required this.fields,
  });

  final String id;
  final String title;
  final String kind;
  final double positionX;
  final double positionY;
  final List<String> fields;
}

class SchemaDiagramEdge {
  const SchemaDiagramEdge({
    required this.fromId,
    required this.toId,
    required this.label,
  });

  final String fromId;
  final String toId;
  final String label;
}

class SchemaDiagramModel {
  const SchemaDiagramModel({
    required this.title,
    required this.nodes,
    required this.edges,
  });

  final String title;
  final List<SchemaDiagramNode> nodes;
  final List<SchemaDiagramEdge> edges;
}
