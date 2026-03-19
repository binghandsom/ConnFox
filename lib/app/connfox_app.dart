import 'package:flutter/material.dart';

import '../features/workbench/workbench_page.dart';
import 'connfox_theme.dart';

class ConnFoxApp extends StatelessWidget {
  const ConnFoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ConnFox',
      debugShowCheckedModeBanner: false,
      theme: buildConnFoxTheme(),
      home: const WorkbenchPage(),
    );
  }
}
