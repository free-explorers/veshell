import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/display/monitor/screen/workspace/tileable/persistent_application_launcher/app_drawer/app_grid.dart';
import 'package:shell/manager/application/app_drawer.provider.dart';

class AppDrawer extends HookConsumerWidget {
  const AppDrawer({required this.onSelect, super.key});
  final DesktopEntrySelectedCallback onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: 600,
      height: 600,
      child: AppGrid(
        onSelect: onSelect,
      ),
    );
  }
}

class _AppDrawerTextField extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AppDrawerTextField> createState() =>
      _AppDrawerTextFieldState();
}

class _AppDrawerTextFieldState extends ConsumerState<_AppDrawerTextField> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      ref.read(appDrawerFilterProvider.notifier).state = _searchController.text;
    });
    _searchFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      autofocus: true,
      decoration: InputDecoration(
        prefixIcon: const Padding(
          padding: EdgeInsets.fromLTRB(15, 0, 10, 0),
          child: Icon(Icons.search),
        ),
        prefixIconColor: Colors.grey,
        hintText: 'Search apps',
        hintStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
}
