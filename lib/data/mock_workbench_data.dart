import 'package:flutter/material.dart';

import '../domain/database/connection_models.dart';
import '../domain/database/query_execution_models.dart';
import '../models/workbench_models.dart';

List<WindowWorkspace> buildMockWorkspaces() {
  const prodConfig = DatabaseConnectionConfig(
    id: 'mysql-prod',
    name: 'Orders Production',
    engine: DatabaseEngine.mysql,
    host: 'orders-prod.internal',
    port: 3306,
    database: 'orders',
    username: 'readonly',
    password: '',
    environment: 'PROD',
    readOnly: true,
  );

  const stagingConfig = DatabaseConnectionConfig(
    id: 'mysql-staging',
    name: 'Catalog Staging',
    engine: DatabaseEngine.mysql,
    host: 'staging-db.internal',
    port: 3306,
    database: 'catalog',
    username: 'developer',
    password: '',
    environment: 'STG',
  );

  const warehouseConfig = DatabaseConnectionConfig(
    id: 'postgres-warehouse',
    name: 'Warehouse Analytics',
    engine: DatabaseEngine.postgresql,
    host: 'warehouse-pg.internal',
    port: 5432,
    database: 'warehouse',
    username: 'analyst',
    password: '',
    environment: 'DEV',
  );

  const prodConnection = ConnectionProfile(
    config: prodConfig,
    environment: 'PROD',
    latencyLabel: '18 ms',
    statusLabel: 'Stable',
    accentColor: Color(0xFF0F766E),
  );

  const stagingConnection = ConnectionProfile(
    config: stagingConfig,
    environment: 'STG',
    latencyLabel: '11 ms',
    statusLabel: 'Fast',
    accentColor: Color(0xFFB45309),
  );

  const warehouseConnection = ConnectionProfile(
    config: warehouseConfig,
    environment: 'DEV',
    latencyLabel: '14 ms',
    statusLabel: 'Ready',
    accentColor: Color(0xFF1D4ED8),
  );

  return <WindowWorkspace>[
    WindowWorkspace(
      id: 'window-1',
      title: 'Orders Watch',
      subtitle: '只读巡检窗口',
      connection: prodConnection,
      activeTabId: 'tab-orders-overview',
      tabs: const <QueryTabModel>[
        QueryTabModel(
          id: 'tab-orders-overview',
          title: 'Overview',
          summary: '订单看板快速巡检',
          sql: '''
SELECT
  status,
  COUNT(*) AS total_orders,
  SUM(total_amount) AS revenue
FROM orders
WHERE created_at >= NOW() - INTERVAL 7 DAY
GROUP BY status
ORDER BY total_orders DESC;
''',
          resultColumns: <String>['status', 'total_orders', 'revenue'],
          resultRows: <List<String>>[
            <String>['paid', '12,204', '1,840,992.32'],
            <String>['refunded', '321', '52,384.40'],
            <String>['pending', '208', '18,220.10'],
            <String>['failed', '44', '1,230.55'],
          ],
          resultCountLabel: '4 rows',
          executionLabel: '83 ms',
          updatedAtLabel: '18:24',
          pinned: true,
        ),
        QueryTabModel(
          id: 'tab-slow-customers',
          title: 'Slow Customers',
          summary: '检查最近 30 分钟的慢查询对象',
          sql: '''
SELECT
  customer_id,
  COUNT(*) AS retries,
  MAX(updated_at) AS last_seen
FROM payment_retries
WHERE updated_at >= NOW() - INTERVAL 30 MINUTE
GROUP BY customer_id
ORDER BY retries DESC
LIMIT 20;
''',
          resultColumns: <String>['customer_id', 'retries', 'last_seen'],
          resultRows: <List<String>>[
            <String>['cus_0192', '8', '2026-03-18 18:20:03'],
            <String>['cus_1208', '6', '2026-03-18 18:17:44'],
            <String>['cus_8821', '4', '2026-03-18 18:11:09'],
          ],
          resultCountLabel: '3 rows',
          executionLabel: '124 ms',
          updatedAtLabel: '18:20',
          dirty: true,
        ),
      ],
      schema: const <SchemaNode>[
        SchemaNode(
          label: 'orders',
          kind: 'database',
          children: <SchemaNode>[
            SchemaNode(label: 'orders', kind: 'table'),
            SchemaNode(label: 'order_items', kind: 'table'),
            SchemaNode(label: 'payment_retries', kind: 'table'),
            SchemaNode(label: 'daily_revenue_view', kind: 'view'),
          ],
        ),
        SchemaNode(
          label: 'analytics',
          kind: 'database',
          children: <SchemaNode>[
            SchemaNode(label: 'fct_orders', kind: 'table'),
            SchemaNode(label: 'dim_customer', kind: 'table'),
          ],
        ),
      ],
      recentQueries: const <String>[
        'SELECT * FROM orders ORDER BY created_at DESC LIMIT 100;',
        'SHOW PROCESSLIST;',
        'EXPLAIN ANALYZE SELECT * FROM payment_retries;',
      ],
      snippets: const <String>[
        'Recent 24h Revenue',
        'Top Failed Orders',
        'Customer Retry Heatmap',
      ],
      capabilities: const <String>[
        'Query History',
        'Read-Only Guard',
        'CSV Export',
        'Pinned Tabs',
        'Schema Search',
        'Table Designer',
        'Data Editor',
        'ER Diagram',
      ],
    ),
    WindowWorkspace(
      id: 'window-2',
      title: 'Catalog Build',
      subtitle: '联调和验证窗口',
      connection: stagingConnection,
      activeTabId: 'tab-products-review',
      tabs: const <QueryTabModel>[
        QueryTabModel(
          id: 'tab-products-review',
          title: 'Products Review',
          summary: '检查 staging 的商品同步结果',
          sql: '''
SELECT
  sku,
  title,
  sync_state,
  updated_at
FROM products
ORDER BY updated_at DESC
LIMIT 50;
''',
          resultColumns: <String>['sku', 'title', 'sync_state', 'updated_at'],
          resultRows: <List<String>>[
            <String>['SKU-10023', 'Desk Lamp', 'synced', '2026-03-18 18:18:44'],
            <String>['SKU-40018', 'Coffee Grinder', 'pending', '2026-03-18 18:17:01'],
            <String>['SKU-12991', 'Ceramic Cup', 'error', '2026-03-18 18:15:20'],
          ],
          resultCountLabel: '3 preview rows',
          executionLabel: '41 ms',
          updatedAtLabel: '18:19',
          pinned: true,
        ),
        QueryTabModel(
          id: 'tab-price-check',
          title: 'Price Check',
          summary: '抽查价格同步和货币精度',
          sql: '''
SELECT
  sku,
  price,
  currency,
  channel
FROM price_snapshots
WHERE updated_at >= NOW() - INTERVAL 1 DAY
ORDER BY updated_at DESC
LIMIT 30;
''',
          resultColumns: <String>['sku', 'price', 'currency', 'channel'],
          resultRows: <List<String>>[
            <String>['SKU-10023', '69.90', 'USD', 'amazon'],
            <String>['SKU-10023', '479.00', 'CNY', 'tmall'],
            <String>['SKU-40018', '88.50', 'USD', 'shopify'],
          ],
          resultCountLabel: '3 preview rows',
          executionLabel: '52 ms',
          updatedAtLabel: '18:11',
        ),
      ],
      schema: const <SchemaNode>[
        SchemaNode(
          label: 'catalog',
          kind: 'database',
          children: <SchemaNode>[
            SchemaNode(label: 'products', kind: 'table'),
            SchemaNode(label: 'variants', kind: 'table'),
            SchemaNode(label: 'price_snapshots', kind: 'table'),
            SchemaNode(label: 'sync_jobs', kind: 'table'),
          ],
        ),
      ],
      recentQueries: const <String>[
        'SELECT COUNT(*) FROM sync_jobs WHERE state = "error";',
        'SELECT * FROM products WHERE sync_state <> "synced";',
        'SHOW INDEX FROM products;',
      ],
      snippets: const <String>[
        'Products without Images',
        'Price Drift Audit',
        'Recent Sync Errors',
      ],
      capabilities: const <String>[
        'Results Preview',
        'Saved Snippets',
        'Connection Profiles',
        'Multi-Tab Layout',
        'Table Designer',
        'Data Editor',
        'ER Diagram',
      ],
    ),
    WindowWorkspace(
      id: 'window-3',
      title: 'Warehouse Analytics',
      subtitle: 'PostgreSQL 示例窗口',
      connection: warehouseConnection,
      activeTabId: 'tab-pg-events',
      tabs: const <QueryTabModel>[
        QueryTabModel(
          id: 'tab-pg-events',
          title: 'Recent Events',
          summary: '检查 PostgreSQL 事件流',
          sql: '''
SELECT
  event_id,
  event_type,
  payload,
  created_at
FROM public.events
WHERE created_at >= now() - interval '1 day'
ORDER BY created_at DESC
LIMIT 50;
''',
          resultColumns: <String>[
            'event_id',
            'event_type',
            'payload',
            'created_at',
          ],
          resultRows: <List<String>>[
            <String>[
              'evt_70018',
              'checkout.completed',
              '{"amount": 192.30}',
              '2026-03-18 18:23:10+08',
            ],
            <String>[
              'evt_70011',
              'user.created',
              '{"plan": "pro"}',
              '2026-03-18 18:20:41+08',
            ],
            <String>[
              'evt_69998',
              'invoice.failed',
              '{"retry": 2}',
              '2026-03-18 18:17:59+08',
            ],
          ],
          resultCountLabel: '3 preview rows',
          executionLabel: '46 ms',
          updatedAtLabel: '18:25',
          pinned: true,
        ),
        QueryTabModel(
          id: 'tab-pg-activity',
          title: 'Activity',
          summary: '查看 PostgreSQL 会话状态',
          sql: '''
SELECT
  pid,
  usename,
  datname,
  state,
  wait_event_type
FROM pg_stat_activity
WHERE datname = current_database()
ORDER BY query_start DESC
LIMIT 20;
''',
          resultColumns: <String>[
            'pid',
            'usename',
            'datname',
            'state',
            'wait_event_type',
          ],
          resultRows: <List<String>>[
            <String>['4418', 'readonly', 'warehouse', 'active', 'Client'],
            <String>['4421', 'analyst', 'warehouse', 'idle', 'Activity'],
            <String>['4428', 'etl_bot', 'warehouse', 'active', 'IO'],
          ],
          resultCountLabel: '3 preview rows',
          executionLabel: '38 ms',
          updatedAtLabel: '18:24',
        ),
      ],
      schema: const <SchemaNode>[
        SchemaNode(
          label: 'warehouse',
          kind: 'database',
          children: <SchemaNode>[
            SchemaNode(
              label: 'public',
              kind: 'schema',
              children: <SchemaNode>[
                SchemaNode(label: 'accounts', kind: 'table'),
                SchemaNode(label: 'events', kind: 'table'),
                SchemaNode(label: 'recent_events_view', kind: 'view'),
              ],
            ),
            SchemaNode(
              label: 'analytics',
              kind: 'schema',
              children: <SchemaNode>[
                SchemaNode(label: 'fct_orders', kind: 'table'),
                SchemaNode(label: 'daily_revenue_mv', kind: 'materialized view'),
              ],
            ),
          ],
        ),
        SchemaNode(
          label: 'pg_catalog',
          kind: 'system',
          children: <SchemaNode>[
            SchemaNode(label: 'pg_tables', kind: 'view'),
            SchemaNode(label: 'pg_stat_activity', kind: 'view'),
          ],
        ),
      ],
      recentQueries: const <String>[
        'SELECT now(), current_database();',
        'SELECT * FROM pg_catalog.pg_tables LIMIT 50;',
        'SELECT pid, usename, state FROM pg_stat_activity;',
      ],
      snippets: const <String>[
        'Recent Events',
        'Activity Monitor',
        'Table Catalog',
      ],
      capabilities: const <String>[
        'PostgreSQL Driver',
        'Schema Preview',
        'pg_catalog Queries',
        'Read-Only Guard',
        'Multi-Tab Layout',
      ],
    ),
  ];
}

QueryTabModel buildScratchTab(ConnectionProfile connection, int ordinal) {
  return QueryTabModel(
    id: 'scratch-$ordinal',
    title: 'Scratch $ordinal',
    summary: '新的查询草稿',
    sql: _scratchSqlFor(connection),
    resultColumns: const <String>['preview'],
    resultRows: const <List<String>>[
      <String>['Run query to inspect live data'],
    ],
    resultCountLabel: 'Draft',
    executionLabel: 'Not run',
    updatedAtLabel: 'Now',
    resultKind: QueryResultKind.notice,
    resultNotice: '支持运行整段 SQL，也支持选中局部 SQL 后单独执行。',
    resultStatusLabel: 'Draft',
    resultHighlights: const <String>[
      '右键选区可直接运行选中的 SQL',
      '下方结果区会按查询结果或更新反馈分别展示',
    ],
    lastRunScopeLabel: 'Draft',
    dirty: true,
  );
}

String _scratchSqlFor(ConnectionProfile connection) {
  switch (connection.config.engine) {
    case DatabaseEngine.postgresql:
      return '''
SELECT *
FROM public.your_table
LIMIT 100;
''';
    case DatabaseEngine.mysql:
    case DatabaseEngine.mariadb:
      return '''
SELECT *
FROM ${connection.database}.your_table
LIMIT 100;
''';
    case DatabaseEngine.sqlite:
      return '''
SELECT *
FROM your_table
LIMIT 100;
''';
    case DatabaseEngine.sqlServer:
      return '''
SELECT TOP 100 *
FROM dbo.your_table;
''';
  }
}
