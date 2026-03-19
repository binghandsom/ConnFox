import '../../models/workbench_models.dart';

class PersistedWorkbenchState {
  const PersistedWorkbenchState({
    required this.schemaVersion,
    required this.exportedAt,
    required this.activeWorkspaceIndex,
    required this.workspaces,
  });

  final int schemaVersion;
  final DateTime exportedAt;
  final int activeWorkspaceIndex;
  final List<WindowWorkspace> workspaces;

  int get connectionCount {
    return workspaces
        .map((workspace) => workspace.connection.id)
        .toSet()
        .length;
  }

  int get tabCount {
    return workspaces.fold<int>(
      0,
      (sum, workspace) => sum + workspace.tabs.length,
    );
  }

  PersistedWorkbenchState copyWith({
    int? schemaVersion,
    DateTime? exportedAt,
    int? activeWorkspaceIndex,
    List<WindowWorkspace>? workspaces,
  }) {
    return PersistedWorkbenchState(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      exportedAt: exportedAt ?? this.exportedAt,
      activeWorkspaceIndex: activeWorkspaceIndex ?? this.activeWorkspaceIndex,
      workspaces: workspaces ?? this.workspaces,
    );
  }
}
