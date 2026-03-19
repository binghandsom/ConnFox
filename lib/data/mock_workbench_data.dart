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
  ];
}

QueryTabModel buildScratchTab(ConnectionProfile connection, int ordinal) {
  return QueryTabModel(
    id: 'scratch-$ordinal',
    title: 'Scratch $ordinal',
    summary: '新的查询草稿',
    sql: '''
SELECT *
FROM ${connection.database}.your_table
LIMIT 100;
''',
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
