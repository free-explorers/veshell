import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zenith/ui/common/state/app_drawer.dart';
import 'package:zenith/ui/desktop/app_drawer/app_drawer_button.dart';
import 'package:zenith/ui/desktop/app_drawer/app_grid.dart';

class AppDrawer extends ConsumerStatefulWidget {
  const AppDrawer({super.key});

  @override
  ConsumerState<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends ConsumerState<AppDrawer> with TickerProviderStateMixin {
  late var controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
  late var slideAnimation = Tween(begin: 50.0, end: 0.0).animate(
    CurvedAnimation(
      parent: controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ),
  );
  late var opacityAnimation = Tween(begin: 0.0, end: 1.0).animate(
    CurvedAnimation(
      parent: controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ),
  );
  var focusScopeNode = FocusScopeNode();

  @override
  void initState() {
    super.initState();
    controller.forward();
  }

  @override
  void dispose() {
    controller.dispose();
    focusScopeNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appDrawerVisibleProvider, (_, bool next) async {
      if (next) {
        controller.forward();
        focusScopeNode.requestFocus();
      } else {
        controller.reverse();
        WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
          focusScopeNode.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
        });
      }
    });

    return FocusScope(
      node: focusScopeNode,
      // canRequestFocus: ref.watch(appDrawerVisibleProvider),
      child: AnimatedBuilder(
        animation: slideAnimation,
        builder: (BuildContext context, Widget? child) {
          return AnimatedBuilder(
            animation: opacityAnimation,
            builder: (BuildContext context, Widget? child) {
              return Opacity(
                opacity: opacityAnimation.value,
                child: Transform.translate(
                  offset: Offset(0.0, slideAnimation.value),
                  transformHitTests: false,
                  child: child,
                ),
              );
            },
            child: child,
          );
        },
        child: SizedBox(
          width: 600,
          height: 600,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 10,
                sigmaY: 10,
              ),
              child: Container(
                color: Colors.white54,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(30, 30, 30, 10),
                      child: _AppDrawerTextField(),
                    ),
                    const Expanded(
                      child: AppGrid(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppDrawerTextField extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AppDrawerTextField> createState() => _AppDrawerTextFieldState();
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
        hintText: "Search apps",
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
