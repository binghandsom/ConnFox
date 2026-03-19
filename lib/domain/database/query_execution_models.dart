enum QueryResultKind {
  resultSet,
  mutation,
  notice,
}

class QueryExecutionResult {
  const QueryExecutionResult({
    required this.kind,
    required this.columns,
    required this.rows,
    required this.duration,
    required this.summary,
    this.notice,
    this.statusLabel = 'OK',
    this.affectedRowCount,
    this.highlights = const <String>[],
  });

  final QueryResultKind kind;
  final List<String> columns;
  final List<List<String>> rows;
  final Duration duration;
  final String summary;
  final String? notice;
  final String statusLabel;
  final int? affectedRowCount;
  final List<String> highlights;

  String get durationLabel => '${duration.inMilliseconds} ms';

  String get rowCountLabel {
    switch (kind) {
      case QueryResultKind.resultSet:
        return '${rows.length} rows';
      case QueryResultKind.mutation:
        return '${affectedRowCount ?? rows.length} affected';
      case QueryResultKind.notice:
        return rows.isEmpty ? 'No rows' : '${rows.length} items';
    }
  }
}

class DatabaseObjectNode {
  const DatabaseObjectNode({
    required this.name,
    required this.kind,
    this.children = const <DatabaseObjectNode>[],
  });

  final String name;
  final String kind;
  final List<DatabaseObjectNode> children;
}
