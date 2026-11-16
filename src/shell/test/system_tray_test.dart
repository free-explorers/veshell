import 'dart:typed_data';

import 'package:dbus/dbus.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/status_bar/provider/status_bar_settings.dart';
import 'package:shell/status_bar/widget/status_bar_items.dart';
import 'package:shell/system_tray/model/tray_item.dart';
import 'package:shell/system_tray/model/tray_menu.dart';
import 'package:shell/system_tray/model/tray_properties.dart';
import 'package:shell/system_tray/provider/system_tray_manager.dart';
import 'package:shell/system_tray/widget/tray_item_button.dart';
import 'package:shell/system_tray/widget/tray_item_icon.dart';

/// An `a(iiay)` entry of [width]×[height] ARGB pixels, all [argb].
DBusStruct _pixmap(int width, int height, List<int> argb) => DBusStruct([
  DBusInt32(width),
  DBusInt32(height),
  DBusArray.byte([for (var i = 0; i < width * height; i++) ...argb]),
]);

DBusStruct _menuNode(
  int id,
  Map<String, DBusValue> properties, [
  List<DBusStruct> children = const [],
]) => DBusStruct([
  DBusInt32(id),
  DBusDict.stringVariant(properties),
  DBusArray.variant(children),
]);

const _base = TrayItem(
  id: ':1.7/StatusNotifierItem',
  busName: ':1.7',
  objectPath: '/StatusNotifierItem',
);

class _FakeSystemTrayManager extends SystemTrayManager {
  _FakeSystemTrayManager(this.items);

  final List<TrayItem> items;

  @override
  IList<TrayItem> build() => items.lock;
}

void main() {
  group('tray item properties', () {
    test('pixmaps are reordered from network ARGB to RGBA', () {
      final pixmaps = trayPixmapsFrom(
        DBusArray(DBusSignature('(iiay)'), [
          _pixmap(2, 1, [0x80, 0x11, 0x22, 0x33]),
        ]),
      );
      expect(pixmaps, hasLength(1));
      expect(pixmaps.single.width, 2);
      expect(pixmaps.single.rgba, [
        0x11,
        0x22,
        0x33,
        0x80,
        0x11,
        0x22,
        0x33,
        0x80,
      ]);
    });

    test('a pixmap whose data does not match its size is dropped', () {
      final pixmaps = trayPixmapsFrom(
        DBusArray(DBusSignature('(iiay)'), [
          DBusStruct([
            const DBusInt32(4),
            const DBusInt32(4),
            DBusArray.byte([1, 2, 3, 4]),
          ]),
          _pixmap(1, 1, [255, 0, 0, 0]),
        ]),
      );
      expect(pixmaps.map((pixmap) => pixmap.width), [1]);
    });

    test('the best pixmap is the smallest one at least as large', () {
      final pixmaps = [
        for (final size in [64, 16, 32])
          TrayPixmap(width: size, height: size, rgba: Uint8List(0)),
      ];
      expect(bestTrayPixmap(pixmaps, 24)?.width, 32);
      expect(bestTrayPixmap(pixmaps, 16)?.width, 16);
      // Nothing is large enough: the largest there is.
      expect(bestTrayPixmap(pixmaps, 128)?.width, 64);
      expect(bestTrayPixmap(const [], 16), isNull);
    });

    test('GetAll builds the item, tolerating missing properties', () {
      final item = trayItemWithProperties(_base, {
        'Id': const DBusString('nm-applet'),
        'Title': const DBusString('Network'),
        'Status': const DBusString('NeedsAttention'),
        'IconName': const DBusString('network-wireless'),
        'AttentionIconName': const DBusString('network-error'),
        'ItemIsMenu': const DBusBoolean(true),
        'Menu': DBusObjectPath('/MenuBar'),
        'ToolTip': DBusStruct([
          const DBusString(''),
          DBusArray(DBusSignature('(iiay)')),
          const DBusString('Wi-Fi'),
          const DBusString('Connected to <b>home</b>'),
        ]),
        // Wrongly typed: ignored.
        'Category': const DBusInt32(3),
      });
      expect(item.itemId, 'nm-applet');
      expect(item.label, 'Network');
      expect(item.status, TrayItemStatus.needsAttention);
      expect(item.currentIcon.name, 'network-error');
      expect(item.itemIsMenu, isTrue);
      expect(item.menuPath, '/MenuBar');
      expect(item.toolTip?.title, 'Wi-Fi');
      expect(item.category, '');
    });

    test('the root path means no menu', () {
      final item = trayItemWithProperties(_base, {'Menu': DBusObjectPath('/')});
      expect(item.menuPath, isNull);
    });

    test('an item without a title is named by its tooltip, then its id', () {
      expect(
        _base
            .copyWith(
              itemId: 'app',
              toolTip: const TrayToolTip(title: 'From tooltip'),
            )
            .label,
        'From tooltip',
      );
      expect(_base.copyWith(itemId: 'app').label, 'app');
    });

    test('the normal icon is kept when there is no attention icon', () {
      final item = _base.copyWith(
        status: TrayItemStatus.needsAttention,
        iconName: 'normal',
      );
      expect(item.currentIcon.name, 'normal');
    });

    test('tooltip markup is reduced to plain text', () {
      expect(
        plainToolTipText('Line <b>one</b><br/>Tom &amp; Jerry &lt;3'),
        'Line one\nTom & Jerry <3',
      );
    });
  });

  group('raster tray icon size', () {
    test('an icon with enough pixels fills its box', () {
      final drawn = crispRasterSize(pixels: 64, box: 24, devicePixelRatio: 2);
      expect(drawn.size, 24);
      expect(drawn.upscaled, isFalse);
    });

    test('a 24 px icon is drawn at its own size at 1x', () {
      final drawn = crispRasterSize(pixels: 24, box: 24, devicePixelRatio: 1);
      expect(drawn.size, 24);
      expect(drawn.upscaled, isFalse);
    });

    test('a 24 px icon is doubled at 2x, not stretched', () {
      final drawn = crispRasterSize(pixels: 24, box: 32, devicePixelRatio: 2);
      // 64 physical pixels hold 2 whole copies of 24: 48 px, 24 logical.
      expect(drawn.size, 24);
      expect(drawn.upscaled, isTrue);
    });

    test('a fractional scale keeps the icon at its own pixels', () {
      final drawn = crispRasterSize(
        pixels: 24,
        box: 24,
        devicePixelRatio: 1.25,
      );
      expect(drawn.size, 24 / 1.25);
      expect(drawn.upscaled, isFalse);
    });

    test('an unknown size fills the box', () {
      expect(
        crispRasterSize(pixels: null, box: 24, devicePixelRatio: 1).size,
        24,
      );
    });
  });

  group('tray menu layout', () {
    test('a layout becomes entries with their toggles and submenus', () {
      final root = trayMenuEntryFrom(
        _menuNode(
          0,
          {'children-display': const DBusString('submenu')},
          [
            _menuNode(1, {
              'label': const DBusString('_Open'),
              'icon-name': const DBusString('document-open'),
            }),
            _menuNode(2, {'type': const DBusString('separator')}),
            _menuNode(3, {
              'label': const DBusString('Mute'),
              'toggle-type': const DBusString('checkmark'),
              'toggle-state': const DBusInt32(1),
              'enabled': const DBusBoolean(false),
            }),
            _menuNode(4, {
              'label': const DBusString('More'),
              'children-display': const DBusString('submenu'),
            }),
            _menuNode(5, {
              'label': const DBusString('Hidden'),
              'visible': const DBusBoolean(false),
            }),
          ],
        ),
      )!;
      final entries = root.visibleChildren.toList();
      expect(entries.map((entry) => entry.id), [1, 2, 3, 4]);
      expect(entries[0].label, 'Open');
      expect(entries[0].iconName, 'document-open');
      expect(entries[1].isSeparator, isTrue);
      expect(entries[2].toggle, TrayMenuToggle.checkmark);
      expect(entries[2].toggled, isTrue);
      expect(entries[2].enabled, isFalse);
      // Announced, to be populated on AboutToShow.
      expect(entries[3].isSubmenu, isTrue);
      expect(entries[3].children, isEmpty);
    });

    test('a malformed node is skipped', () {
      expect(trayMenuEntryFrom(const DBusString('nope')), isNull);
    });

    test('mnemonic markers are removed and doubled ones kept', () {
      expect(trayMenuLabel('_File'), 'File');
      expect(trayMenuLabel('snake__case'), 'snake_case');
      expect(trayMenuLabel('trailing_'), 'trailing');
    });
  });

  group('status bar tray', () {
    TrayItem item(int index, [TrayItemStatus status = TrayItemStatus.active]) =>
        _base.copyWith(id: 'item$index', title: 'Item $index', status: status);

    Future<void> pump(WidgetTester tester, List<TrayItem> items) =>
        tester.pumpWidget(
          ProviderScope(
            overrides: [
              systemTrayManagerProvider.overrideWith(
                () => _FakeSystemTrayManager(items),
              ),
              statusBarSettingsProvider.overrideWithValue(
                statusBarSettingsFallback,
              ),
            ],
            child: const MaterialApp(
              home: Scaffold(body: StatusBarSystemTray()),
            ),
          ),
        );

    List<String> shownIds(WidgetTester tester) => tester
        .widgetList<TrayItemButton>(find.byType(TrayItemButton))
        .map((button) => button.item.id)
        .toList();

    testWidgets('every item shows but the passive ones, left to the Helm', (
      tester,
    ) async {
      await pump(tester, [item(0), item(1, TrayItemStatus.passive), item(2)]);
      expect(shownIds(tester), ['item0', 'item2']);
    });
  });
}
