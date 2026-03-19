import '../domain/schema/schema_editor_models.dart';
import '../models/workbench_models.dart';

TableDesignDraft buildMockTableDesign(
  ConnectionProfile connection, {
  String tableName = 'orders',
}) {
  return TableDesignDraft(
    schemaName: connection.database,
    tableName: tableName,
    engineName: 'InnoDB',
    comment: '订单主表，支撑支付、履约和运营查询。',
    columns: const <TableColumnDraft>[
      TableColumnDraft(
        name: 'id',
        typeLabel: 'BIGINT UNSIGNED',
        nullable: false,
        primaryKey: true,
        autoIncrement: true,
        comment: '主键 ID',
      ),
      TableColumnDraft(
        name: 'order_no',
        typeLabel: 'VARCHAR(64)',
        nullable: false,
        unique: true,
        comment: '业务订单号',
      ),
      TableColumnDraft(
        name: 'customer_id',
        typeLabel: 'BIGINT UNSIGNED',
        nullable: false,
        comment: '客户 ID',
      ),
      TableColumnDraft(
        name: 'status',
        typeLabel: 'VARCHAR(32)',
        nullable: false,
        defaultValue: "'pending'",
      ),
      TableColumnDraft(
        name: 'total_amount',
        typeLabel: 'DECIMAL(12,2)',
        nullable: false,
        defaultValue: '0.00',
      ),
      TableColumnDraft(
        name: 'created_at',
        typeLabel: 'DATETIME',
        nullable: false,
        defaultValue: 'CURRENT_TIMESTAMP',
      ),
      TableColumnDraft(
        name: 'updated_at',
        typeLabel: 'DATETIME',
        nullable: false,
        defaultValue: 'CURRENT_TIMESTAMP',
      ),
    ],
    indexes: const <TableIndexDraft>[
      TableIndexDraft(
        name: 'PRIMARY',
        kind: TableIndexKind.primary,
        columns: <String>['id'],
      ),
      TableIndexDraft(
        name: 'uk_orders_order_no',
        kind: TableIndexKind.unique,
        columns: <String>['order_no'],
      ),
      TableIndexDraft(
        name: 'idx_orders_customer_status',
        kind: TableIndexKind.secondary,
        columns: <String>['customer_id', 'status'],
      ),
    ],
    foreignKeys: const <ForeignKeyDraft>[
      ForeignKeyDraft(
        name: 'fk_orders_customer',
        sourceColumns: <String>['customer_id'],
        referenceTable: 'customers',
        referenceColumns: <String>['id'],
        onDelete: 'RESTRICT',
        onUpdate: 'CASCADE',
      ),
    ],
  );
}

DataEditorModel buildMockDataEditor(
  ConnectionProfile connection, {
  String tableName = 'orders',
}) {
  return DataEditorModel(
    schemaName: connection.database,
    tableName: tableName,
    totalRowEstimate: 124208,
    pageLabel: 'Page 1 / 50',
    columns: const <DataEditorColumn>[
      DataEditorColumn(
        name: 'id',
        typeLabel: 'BIGINT',
        primaryKey: true,
        nullable: false,
      ),
      DataEditorColumn(
        name: 'order_no',
        typeLabel: 'VARCHAR(64)',
        nullable: false,
      ),
      DataEditorColumn(
        name: 'status',
        typeLabel: 'VARCHAR(32)',
        nullable: false,
      ),
      DataEditorColumn(
        name: 'total_amount',
        typeLabel: 'DECIMAL(12,2)',
        nullable: false,
      ),
      DataEditorColumn(
        name: 'created_at',
        typeLabel: 'DATETIME',
        nullable: false,
      ),
    ],
    rows: const <EditableRowDraft>[
      EditableRowDraft(
        id: 'row-1',
        values: <String, String>{
          'id': '881201',
          'order_no': 'ORD-881201',
          'status': 'paid',
          'total_amount': '192.30',
          'created_at': '2026-03-18 18:20:19',
        },
      ),
      EditableRowDraft(
        id: 'row-2',
        values: <String, String>{
          'id': '881198',
          'order_no': 'ORD-881198',
          'status': 'pending',
          'total_amount': '88.00',
          'created_at': '2026-03-18 18:19:02',
        },
        dirty: true,
      ),
      EditableRowDraft(
        id: 'row-3',
        values: <String, String>{
          'id': '881191',
          'order_no': 'ORD-881191',
          'status': 'refunded',
          'total_amount': '22.80',
          'created_at': '2026-03-18 18:17:51',
        },
      ),
    ],
  );
}

SchemaDiagramModel buildMockSchemaDiagram(
  ConnectionProfile connection, {
  String tableName = 'orders',
}) {
  return SchemaDiagramModel(
    title: '${connection.database} · table relations',
    nodes: const <SchemaDiagramNode>[
      SchemaDiagramNode(
        id: 'orders',
        title: 'orders',
        kind: 'table',
        positionX: 120,
        positionY: 90,
        fields: <String>[
          'id',
          'order_no',
          'customer_id',
          'status',
          'total_amount',
        ],
      ),
      SchemaDiagramNode(
        id: 'customers',
        title: 'customers',
        kind: 'table',
        positionX: 500,
        positionY: 60,
        fields: <String>[
          'id',
          'name',
          'email',
          'segment',
        ],
      ),
      SchemaDiagramNode(
        id: 'order_items',
        title: 'order_items',
        kind: 'table',
        positionX: 500,
        positionY: 320,
        fields: <String>[
          'id',
          'order_id',
          'sku_id',
          'quantity',
          'unit_price',
        ],
      ),
      SchemaDiagramNode(
        id: 'payment_retries',
        title: 'payment_retries',
        kind: 'table',
        positionX: 880,
        positionY: 170,
        fields: <String>[
          'id',
          'order_id',
          'reason',
          'retry_count',
        ],
      ),
    ],
    edges: const <SchemaDiagramEdge>[
      SchemaDiagramEdge(
        fromId: 'orders',
        toId: 'customers',
        label: 'customer_id -> customers.id',
      ),
      SchemaDiagramEdge(
        fromId: 'order_items',
        toId: 'orders',
        label: 'order_id -> orders.id',
      ),
      SchemaDiagramEdge(
        fromId: 'payment_retries',
        toId: 'orders',
        label: 'order_id -> orders.id',
      ),
    ],
  );
}
