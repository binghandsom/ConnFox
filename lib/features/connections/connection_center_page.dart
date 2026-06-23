import 'package:flutter/material.dart';

import '../../app/connfox_theme.dart';
import '../../domain/database/connection_models.dart';
import '../../domain/database/query_execution_service.dart';
import '../../models/workbench_models.dart';

class ConnectionCenterPage extends StatefulWidget {
  const ConnectionCenterPage({
    super.key,
    required this.queryExecutionService,
  });

  final QueryExecutionService queryExecutionService;

  @override
  State<ConnectionCenterPage> createState() => _ConnectionCenterPageState();
}

class _ConnectionCenterPageState extends State<ConnectionCenterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: 'My Local MySQL');
  final _hostController = TextEditingController(text: '127.0.0.1');
  final _portController = TextEditingController(text: '3306');
  final _databaseController = TextEditingController(text: 'app_db');
  final _usernameController = TextEditingController(text: 'root');
  final _passwordController = TextEditingController();
  final _sshHostController = TextEditingController();
  final _sshPortController = TextEditingController(text: '22');
  final _notesController = TextEditingController();

  DatabaseEngine _engine = DatabaseEngine.mysql;
  String _environment = 'DEV';
  bool _useTls = false;
  bool _readOnly = false;
  bool _useSshTunnel = false;
  bool _testing = false;
  ConnectionTestResult? _testResult;

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _databaseController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _sshHostController.dispose();
    _sshPortController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  DatabaseConnectionConfig _buildConfig() {
    final port = int.tryParse(_portController.text.trim()) ?? _engine.defaultPort;
    final sshPort = int.tryParse(_sshPortController.text.trim());

    return DatabaseConnectionConfig(
      id: 'conn-${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      engine: _engine,
      host: _hostController.text.trim(),
      port: port,
      database: _databaseController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      environment: _environment,
      useTls: _useTls,
      readOnly: _readOnly,
      useSshTunnel: _useSshTunnel,
      sshHost: _useSshTunnel ? _sshHostController.text.trim() : null,
      sshPort: _useSshTunnel ? sshPort : null,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _testing = true;
      _testResult = null;
    });

    try {
      final result = await widget.queryExecutionService.testConnection(_buildConfig());
      if (!mounted) {
        return;
      }

      setState(() {
        _testing = false;
        _testResult = result;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _testing = false;
        _testResult = ConnectionTestResult(
          success: false,
          message: error.toString(),
          latency: const Duration(milliseconds: 0),
        );
      });
    }
  }

  void _saveAndOpen() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final config = _buildConfig();
    Navigator.of(context).pop(
      ConnectionProfile.fromConfig(
        config: config,
        accentColor: _accentColorFor(config.engine, config.environment),
        latencyLabel: _testResult?.latencyLabel ?? 'Not tested',
        statusLabel: _testResult?.success == true ? 'Ready' : 'Draft',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              Color(0xFFF7F2E8),
              Color(0xFFE7E5DE),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(
                  width: 320,
                  child: _buildGuidePanel(context),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildFormPanel(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGuidePanel(BuildContext context) {
    return _ConnectionPanel(
      padding: const EdgeInsets.all(20),
      child: ListView(
        children: <Widget>[
          Text(
            'Connection Center',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '先把 MySQL / PostgreSQL 的连接配置和测试链路做顺，后面接真实驱动、Keychain 和 SSH 就会轻松很多。',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: ConnFoxPalette.mutedText,
                ),
          ),
          const SizedBox(height: 18),
          _GuideBadge(
            label: 'Ready',
            value: 'MySQL / PostgreSQL',
          ),
          const SizedBox(height: 10),
          _GuideBadge(
            label: 'Later',
            value: 'MariaDB / SQLite / SQL Server',
          ),
          const SizedBox(height: 22),
          _ChecklistCard(
            title: '这页要承担什么',
            items: const <String>[
              '连接信息录入与校验',
              '测试连接与结果反馈',
              '环境标识与只读保护',
              'SSL / SSH 的配置入口',
              '后续 Keychain 持久化接入点',
            ],
          ),
          const SizedBox(height: 16),
          _ChecklistCard(
            title: '你后面优先接的能力',
            items: const <String>[
              '保存到本地配置仓库',
              '密码写入 macOS Keychain',
              '真实 MySQL / PostgreSQL 握手和超时处理',
              'Schema 首屏懒加载',
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormPanel(BuildContext context) {
    return _ConnectionPanel(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            Row(
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
                        '新建数据库连接',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '这版先把 MySQL 和 PostgreSQL 主链路打通，表单结构继续为更多数据库预留。',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: ConnFoxPalette.mutedText,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: _buildBasicSection(context)),
                const SizedBox(width: 16),
                Expanded(child: _buildSecuritySection(context)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: _buildBehaviorSection(context)),
                const SizedBox(width: 16),
                Expanded(child: _buildResultSection(context)),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: _testing ? null : _testConnection,
                  icon: _testing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.network_check_rounded),
                  label: Text(_testing ? '测试中' : '测试连接'),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: _saveAndOpen,
                  icon: const Icon(Icons.rocket_launch_rounded),
                  label: const Text('保存并打开工作台'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicSection(BuildContext context) {
    return _SectionCard(
      title: 'Basic',
      subtitle: '连接名称、数据库类型和基础连接参数',
      child: Column(
        children: <Widget>[
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Connection Name',
              hintText: '例如：Orders Production',
            ),
            validator: _requiredValidator('连接名称'),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: DropdownButtonFormField<DatabaseEngine>(
                  value: _engine,
                  decoration: const InputDecoration(
                    labelText: 'Engine',
                  ),
                  items: DatabaseEngine.values
                      .map(
                        (engine) => DropdownMenuItem<DatabaseEngine>(
                          value: engine,
                          child: Text(engine.label),
                        ),
                      )
                      .toList(),
                  onChanged: (engine) {
                    if (engine == null) {
                      return;
                    }
                    setState(() {
                      _engine = engine;
                      _applyEngineDefaults(engine);
                      if (!_engine.isFileBased) {
                        _portController.text = '${engine.defaultPort}';
                      }
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _environment,
                  decoration: const InputDecoration(
                    labelText: 'Environment',
                  ),
                  items: const <String>['DEV', 'STG', 'PROD']
                      .map(
                        (value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _environment = value;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _hostController,
                  decoration: InputDecoration(
                    labelText: _engine.isFileBased ? 'Database File' : 'Host',
                    hintText: _engine.isFileBased ? '/path/to/database.db' : '127.0.0.1',
                  ),
                  validator: _requiredValidator(_engine.isFileBased ? '数据库文件' : 'Host'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _portController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Port',
                  ),
                  validator: (value) {
                    if (_engine.isFileBased) {
                      return null;
                    }
                    final port = int.tryParse(value?.trim() ?? '');
                    if (port == null || port <= 0) {
                      return '请输入有效端口';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _databaseController,
            decoration: const InputDecoration(
              labelText: 'Database',
              hintText: '例如：orders',
            ),
            validator: _requiredValidator('Database'),
          ),
        ],
      ),
    );
  }

  Widget _buildSecuritySection(BuildContext context) {
    return _SectionCard(
      title: 'Security',
      subtitle: '账户、TLS 和后续 SSH Tunnel 配置入口',
      child: Column(
        children: <Widget>[
          TextFormField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: 'Username',
            ),
            validator: _requiredValidator('Username'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              hintText: '后续建议写入 macOS Keychain',
            ),
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            value: _useTls,
            contentPadding: EdgeInsets.zero,
            title: const Text('启用 TLS / SSL'),
            subtitle: const Text('下一步接证书文件、CA 校验与严格模式。'),
            onChanged: (value) {
              setState(() {
                _useTls = value;
              });
            },
          ),
          SwitchListTile(
            value: _useSshTunnel,
            contentPadding: EdgeInsets.zero,
            title: const Text('通过 SSH Tunnel'),
            subtitle: const Text('这一层先预留字段，后面接真实 tunnel 管理。'),
            onChanged: (value) {
              setState(() {
                _useSshTunnel = value;
              });
            },
          ),
          if (_useSshTunnel) ...<Widget>[
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextFormField(
                    controller: _sshHostController,
                    decoration: const InputDecoration(
                      labelText: 'SSH Host',
                    ),
                    validator: _requiredValidator('SSH Host'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _sshPortController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'SSH Port',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBehaviorSection(BuildContext context) {
    return _SectionCard(
      title: 'Behavior',
      subtitle: '环境标签、只读保护和备注信息',
      child: Column(
        children: <Widget>[
          SwitchListTile(
            value: _readOnly,
            contentPadding: EdgeInsets.zero,
            title: const Text('只读模式'),
            subtitle: const Text('默认拦截 update / delete / alter / drop 等写入语句。'),
            onChanged: (value) {
              setState(() {
                _readOnly = value;
              });
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _notesController,
            minLines: 4,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Notes',
              hintText: '例如：生产环境仅用于巡检，禁止写入。',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultSection(BuildContext context) {
    final result = _testResult;

    return _SectionCard(
      title: 'Test Result',
      subtitle: '先用对应的 mock driver 跑通链路，后面替换成真实网络连接',
      child: result == null
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ConnFoxPalette.panelMuted,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '还没有测试连接。建议先点一次“测试连接”，再保存到工作台。',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: ConnFoxPalette.mutedText,
                    ),
              ),
            )
          : Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: result.success
                    ? ConnFoxPalette.accentSoft
                    : const Color(0xFFFDE7E7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    result.success ? '连接测试成功' : '连接测试失败',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(result.message),
                  const SizedBox(height: 6),
                  Text(
                    'Latency: ${result.latencyLabel}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
    );
  }

  String? Function(String?) _requiredValidator(String field) {
    return (value) {
      if ((value ?? '').trim().isEmpty) {
        return '$field 不能为空';
      }
      return null;
    };
  }

  Color _accentColorFor(DatabaseEngine engine, String environment) {
    switch (environment) {
      case 'PROD':
        return ConnFoxPalette.accent;
      case 'STG':
        return ConnFoxPalette.warning;
      default:
        switch (engine) {
          case DatabaseEngine.mysql:
          case DatabaseEngine.mariadb:
            return const Color(0xFF0E7490);
          case DatabaseEngine.postgresql:
            return const Color(0xFF1D4ED8);
          case DatabaseEngine.sqlite:
            return const Color(0xFF6D28D9);
          case DatabaseEngine.sqlServer:
            return const Color(0xFFBE123C);
        }
    }
  }

  void _applyEngineDefaults(DatabaseEngine engine) {
    switch (engine) {
      case DatabaseEngine.postgresql:
        if (_nameController.text == 'My Local MySQL') {
          _nameController.text = 'My Local PostgreSQL';
        }
        if (_usernameController.text == 'root') {
          _usernameController.text = 'postgres';
        }
        if (_databaseController.text == 'app_db') {
          _databaseController.text = 'postgres';
        }
        break;
      case DatabaseEngine.mysql:
      case DatabaseEngine.mariadb:
        if (_nameController.text == 'My Local PostgreSQL') {
          _nameController.text = 'My Local MySQL';
        }
        if (_usernameController.text == 'postgres') {
          _usernameController.text = 'root';
        }
        if (_databaseController.text == 'postgres') {
          _databaseController.text = 'app_db';
        }
        break;
      case DatabaseEngine.sqlite:
        if (_nameController.text == 'My Local MySQL' ||
            _nameController.text == 'My Local PostgreSQL') {
          _nameController.text = 'Local SQLite File';
        }
        _databaseController.text = _databaseController.text.trim().isEmpty
            ? '/path/to/database.db'
            : _databaseController.text;
        break;
      case DatabaseEngine.sqlServer:
        if (_nameController.text == 'My Local MySQL' ||
            _nameController.text == 'My Local PostgreSQL') {
          _nameController.text = 'My Local SQL Server';
        }
        break;
    }
  }
}

class _ConnectionPanel extends StatelessWidget {
  const _ConnectionPanel({
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
  });

  final String title;
  final String subtitle;
  final Widget child;

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
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _GuideBadge extends StatelessWidget {
  const _GuideBadge({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: ConnFoxPalette.accentSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _ChecklistCard extends StatelessWidget {
  const _ChecklistCard({
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
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
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
