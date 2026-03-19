import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/connfox_theme.dart';

class BackupCenterPage extends StatefulWidget {
  const BackupCenterPage({
    super.key,
    required this.autosavePath,
    required this.initialExportJson,
    required this.onRefreshExportJson,
    required this.onWriteBackupFile,
    required this.onImportJson,
    required this.onImportPath,
  });

  final String autosavePath;
  final String initialExportJson;
  final Future<String> Function() onRefreshExportJson;
  final Future<String> Function() onWriteBackupFile;
  final Future<String> Function(String json) onImportJson;
  final Future<String> Function(String path) onImportPath;

  @override
  State<BackupCenterPage> createState() => _BackupCenterPageState();
}

class _BackupCenterPageState extends State<BackupCenterPage> {
  late final TextEditingController _exportController;
  final TextEditingController _importJsonController = TextEditingController();
  final TextEditingController _importPathController = TextEditingController();
  bool _busy = false;
  String? _lastBackupPath;

  @override
  void initState() {
    super.initState();
    _exportController = TextEditingController(text: widget.initialExportJson);
  }

  @override
  void dispose() {
    _exportController.dispose();
    _importJsonController.dispose();
    _importPathController.dispose();
    super.dispose();
  }

  Future<void> _refreshJson() async {
    setState(() {
      _busy = true;
    });

    try {
      final json = await widget.onRefreshExportJson();
      if (!mounted) {
        return;
      }
      setState(() {
        _exportController.text = json;
      });
      _showHint('导出快照已刷新。');
    } catch (error) {
      _showHint(error.toString());
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
      });
    }
  }

  Future<void> _copyJson() async {
    await Clipboard.setData(ClipboardData(text: _exportController.text));
    if (!mounted) {
      return;
    }
    _showHint('快照 JSON 已复制到剪贴板。');
  }

  Future<void> _writeBackupFile() async {
    setState(() {
      _busy = true;
    });

    try {
      final path = await widget.onWriteBackupFile();
      if (!mounted) {
        return;
      }
      setState(() {
        _lastBackupPath = path;
      });
      _showHint('备份文件已写入本地。');
    } catch (error) {
      _showHint(error.toString());
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
      });
    }
  }

  Future<void> _importJson() async {
    final raw = _importJsonController.text.trim();
    if (raw.isEmpty) {
      _showHint('先粘贴一段备份 JSON。');
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      final message = await widget.onImportJson(raw);
      if (!mounted) {
        return;
      }
      _showHint(message);
    } catch (error) {
      _showHint(error.toString());
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
      });
    }
  }

  Future<void> _importPath() async {
    final path = _importPathController.text.trim();
    if (path.isEmpty) {
      _showHint('先输入一个备份文件路径。');
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      final message = await widget.onImportPath(path);
      if (!mounted) {
        return;
      }
      _showHint(message);
    } catch (error) {
      _showHint(error.toString());
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
      });
    }
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
                  child: _BackupPanel(
                    padding: const EdgeInsets.all(20),
                    child: ListView(
                      children: <Widget>[
                        Text(
                          'Backup Center',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '把连接信息、打开的 SQL Tab、最近查询和执行结果草稿一起落到本地，并允许在重装后导回。',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: ConnFoxPalette.mutedText,
                              ),
                        ),
                        const SizedBox(height: 20),
                        _InfoCard(
                          title: '自动保存位置',
                          body: widget.autosavePath,
                        ),
                        const SizedBox(height: 14),
                        _InfoCard(
                          title: '当前包含的数据',
                          body: '连接配置、多窗口、多 Tab、SQL 草稿、最近查询、Schema 预览。',
                        ),
                        const SizedBox(height: 14),
                        _InfoCard(
                          title: '当前注意事项',
                          body: '这版导出 JSON 会包含连接密码，后面接入 macOS Keychain 后会拆开存储。',
                        ),
                        if (_lastBackupPath != null) ...<Widget>[
                          const SizedBox(height: 14),
                          _InfoCard(
                            title: '最近导出路径',
                            body: _lastBackupPath!,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _BackupPanel(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                '导出与导入',
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _busy ? null : () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close_rounded),
                              label: const Text('关闭'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: ListView(
                            children: <Widget>[
                              _SectionTitle(
                                title: '导出 JSON',
                                subtitle: '适合复制、留档或放进版本库以外的备份目录。',
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _exportController,
                                maxLines: 14,
                                readOnly: true,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                                decoration: const InputDecoration(
                                  alignLabelWithHint: true,
                                  labelText: '当前备份 JSON',
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: <Widget>[
                                  FilledButton.icon(
                                    onPressed: _busy ? null : _copyJson,
                                    icon: const Icon(Icons.copy_rounded),
                                    label: const Text('复制 JSON'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: _busy ? null : _refreshJson,
                                    icon: const Icon(Icons.refresh_rounded),
                                    label: const Text('刷新快照'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: _busy ? null : _writeBackupFile,
                                    icon: const Icon(Icons.save_alt_rounded),
                                    label: const Text('写入备份文件'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              _SectionTitle(
                                title: '从 JSON 导入',
                                subtitle: '适合重装后直接粘贴一份备份内容恢复。',
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _importJsonController,
                                maxLines: 10,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                                decoration: const InputDecoration(
                                  alignLabelWithHint: true,
                                  labelText: '粘贴备份 JSON',
                                  hintText: '把导出的 JSON 粘贴到这里，然后执行导入。',
                                ),
                              ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: _busy ? null : _importJson,
                                icon: const Icon(Icons.upload_file_rounded),
                                label: const Text('导入 JSON'),
                              ),
                              const SizedBox(height: 24),
                              _SectionTitle(
                                title: '从路径导入',
                                subtitle: '适合你把备份文件放在某个本地路径时直接恢复。',
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _importPathController,
                                decoration: const InputDecoration(
                                  labelText: '备份文件路径',
                                  hintText: '~/Documents/ConnFox Backups/xxx.json',
                                ),
                              ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: _busy ? null : _importPath,
                                icon: const Icon(Icons.drive_folder_upload_rounded),
                                label: const Text('从路径导入'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BackupPanel extends StatelessWidget {
  const _BackupPanel({
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

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

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
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: ConnFoxPalette.mutedText,
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
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
        const SizedBox(height: 4),
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
