import 'package:flutter/cupertino.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'root_overlay.provider.g.dart';

@Riverpod(keepAlive: true)
GlobalKey<OverlayState> rootOverlayKey(RootOverlayKeyRef ref) => GlobalKey();
