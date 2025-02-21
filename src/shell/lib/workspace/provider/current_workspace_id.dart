import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/workspace/provider/workspace_state.dart';

part 'current_workspace_id.g.dart';

/// Provide the current Screen to all his childrens
@Riverpod(dependencies: [])
WorkspaceId currentWorkspaceId(CurrentWorkspaceIdRef ref) {
  // This provider is instentatied in Children Scope
  throw Exception('currentWorkspaceId was not initialized');
}
