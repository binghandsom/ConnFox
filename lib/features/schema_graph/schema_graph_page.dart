import 'package:flutter/material.dart';

import '../../app/connfox_theme.dart';
import '../../data/mock_schema_editor_data.dart';
import '../../domain/schema/schema_editor_models.dart';
import '../../models/workbench_models.dart';

class SchemaGraphPage extends StatefulWidget {
  const SchemaGraphPage({
    super.key,
    required this.connection,
    required this.tableName,
  });

  final ConnectionProfile connection;
  final String tableName;

  @override
  State<SchemaGraphPage> createState() => _SchemaGraphPageState();
}

class _SchemaGraphPageState extends State<SchemaGraphPage> {
  static const double _cardWidth = 220;
  static const double _cardHeight = 166;

  late SchemaDiagramModel _diagram;
  late String _selectedNodeId;

  @override
  void initState() {
    super.initState();
    _diagram = buildMockSchemaDiagram(
      widget.connection,
      tableName: widget.tableName,
    );
    _selectedNodeId = _diagram.nodes.first.id;
  }

  SchemaDiagramNode get _selectedNode =>
      _diagram.nodes.firstWhere((node) => node.id == _selectedNodeId);

  List<SchemaDiagramEdge> get _relatedEdges {
    return _diagram.edges
        .where((edge) => edge.fromId == _selectedNodeId || edge.toId == _selectedNodeId)
        .toList();
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
            child: Column(
              children: <Widget>[
                _buildHeader(context),
                const SizedBox(height: 16),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(
                        child: _buildCanvasPanel(context),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 320,
                        child: _buildInspectorPanel(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return _GraphPanel(
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
                  'Schema Graph',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.connection.name} · ${_diagram.title}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: ConnFoxPalette.mutedText,
                      ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => _showHint('这里后面可以接自动布局和导出图片。'),
            icon: const Icon(Icons.auto_awesome_motion_rounded),
            label: const Text('自动布局'),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: () => _showHint('后面这里适合接 PNG / SVG 导出。'),
            icon: const Icon(Icons.share_rounded),
            label: const Text('导出关系图'),
          ),
        ],
      ),
    );
  }

  Widget _buildCanvasPanel(BuildContext context) {
    return _GraphPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'ER Diagram Canvas',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                _LegendChip(label: '${_diagram.nodes.length} tables'),
                const SizedBox(width: 10),
                _LegendChip(label: '${_diagram.edges.length} relations'),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: InteractiveViewer(
              boundaryMargin: const EdgeInsets.all(140),
              minScale: 0.6,
              maxScale: 1.8,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: SizedBox(
                    width: 1220,
                    height: 720,
                    child: Stack(
                      children: <Widget>[
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _SchemaEdgePainter(
                              diagram: _diagram,
                              selectedNodeId: _selectedNodeId,
                              cardWidth: _cardWidth,
                              cardHeight: _cardHeight,
                            ),
                          ),
                        ),
                        for (final node in _diagram.nodes)
                          Positioned(
                            left: node.positionX,
                            top: node.positionY,
                            child: _DiagramNodeCard(
                              node: node,
                              selected: node.id == _selectedNodeId,
                              width: _cardWidth,
                              height: _cardHeight,
                              onTap: () {
                                setState(() {
                                  _selectedNodeId = node.id;
                                });
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
        ],
      ),
    );
  }

  Widget _buildInspectorPanel(BuildContext context) {
    return _GraphPanel(
      padding: const EdgeInsets.all(18),
      child: ListView(
        children: <Widget>[
          Text(
            'Inspector',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ConnFoxPalette.accentSoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _selectedNode.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedNode.kind,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: ConnFoxPalette.mutedText,
                      ),
                ),
                const SizedBox(height: 12),
                ..._selectedNode.fields.map(
                  (field) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(field),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _RelationBox(
            title: 'Related Edges',
            items: _relatedEdges.map((edge) => edge.label).toList(),
          ),
          const SizedBox(height: 16),
          _RelationBox(
            title: '为什么关系图必须做',
            items: const <String>[
              '查表依赖更快',
              '建表和改表时更安心',
              '帮助理解联表 SQL',
              '排查脏数据时很省时间',
            ],
          ),
        ],
      ),
    );
  }
}

class _GraphPanel extends StatelessWidget {
  const _GraphPanel({
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

class _LegendChip extends StatelessWidget {
  const _LegendChip({
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

class _DiagramNodeCard extends StatelessWidget {
  const _DiagramNodeCard({
    required this.node,
    required this.selected,
    required this.width,
    required this.height,
    required this.onTap,
  });

  final SchemaDiagramNode node;
  final bool selected;
  final double width;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          width: width,
          height: height,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? ConnFoxPalette.accentSoft : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? ConnFoxPalette.accent : ConnFoxPalette.border,
              width: selected ? 1.4 : 1,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      node.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: ConnFoxPalette.panelMuted,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      node.kind,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              ...node.fields.take(5).map(
                (field) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    field,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: ConnFoxPalette.ink,
                        ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RelationBox extends StatelessWidget {
  const _RelationBox({
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

class _SchemaEdgePainter extends CustomPainter {
  const _SchemaEdgePainter({
    required this.diagram,
    required this.selectedNodeId,
    required this.cardWidth,
    required this.cardHeight,
  });

  final SchemaDiagramModel diagram;
  final String selectedNodeId;
  final double cardWidth;
  final double cardHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final defaultPaint = Paint()
      ..color = const Color(0xFFB9C4D0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final highlightPaint = Paint()
      ..color = ConnFoxPalette.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    for (final edge in diagram.edges) {
      final from = diagram.nodes.firstWhere((node) => node.id == edge.fromId);
      final to = diagram.nodes.firstWhere((node) => node.id == edge.toId);

      final goesRight = to.positionX >= from.positionX;
      final start = Offset(
        goesRight ? from.positionX + cardWidth : from.positionX,
        from.positionY + cardHeight / 2,
      );
      final end = Offset(
        goesRight ? to.positionX : to.positionX + cardWidth,
        to.positionY + cardHeight / 2,
      );
      final midX = (start.dx + end.dx) / 2;

      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(
          midX,
          start.dy,
          midX,
          end.dy,
          end.dx,
          end.dy,
        );

      final highlighted = edge.fromId == selectedNodeId || edge.toId == selectedNodeId;
      canvas.drawPath(path, highlighted ? highlightPaint : defaultPaint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: edge.label,
          style: TextStyle(
            color: highlighted ? ConnFoxPalette.accent : ConnFoxPalette.mutedText,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 220);

      textPainter.paint(
        canvas,
        Offset(
          midX - textPainter.width / 2,
          (start.dy + end.dy) / 2 - 10,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SchemaEdgePainter oldDelegate) {
    return oldDelegate.diagram != diagram ||
        oldDelegate.selectedNodeId != selectedNodeId;
  }
}
