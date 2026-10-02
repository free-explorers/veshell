import 'dart:io';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shell/application/util/normalizing_svg_file_loader.dart';
import 'package:shell/application/util/svg_css_inliner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('inlineSvgCss', () {
    test('leaves an SVG without an embedded stylesheet untouched', () {
      const svg = '<svg><path fill="red"/></svg>';
      expect(inlineSvgCss(svg), svg);
    });

    test('leaves a stylesheet it cannot understand untouched', () {
      const svg = '<svg><style>g > path{fill:red}</style><path/></svg>';
      expect(inlineSvgCss(svg), svg);
    });

    test('inlines class selectors into the inline style', () {
      const svg = '''
<svg><style>.a{fill:#167abf}.b{fill:#fff}</style>
<path class="a"/><path class="b"/></svg>''';
      final result = inlineSvgCss(svg);
      expect(result, contains('style="fill:#167abf"'));
      expect(result, contains('style="fill:#fff"'));
      expect(result, isNot(contains('<style')));
    });

    test('resolves the code-oss icon to its intended fills', () {
      // The real hicolor file styles its geometry with class selectors, which
      // flutter_svg ignores, so it rendered as an opaque black square.
      const svg = '''
<svg id="Layer_1" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
<style>.st0{fill:#f6f6f6;fill-opacity:0}.st1{fill:#fff}.st2{fill:#167abf}</style>
<path class="st0" d="M1024 1024H0V0h1024v1024z"/>
<path class="st1" d="M1024 85.333v853.333H0V85.333h1024z"/>
<path class="st2" d="M0 85.333h298.667v853.333H0V85.333z"/>
</svg>''';
      final result = inlineSvgCss(svg);
      expect(result, contains('style="fill:#f6f6f6;fill-opacity:0"'));
      expect(result, contains('style="fill:#fff"'));
      expect(result, contains('style="fill:#167abf"'));
    });

    test('expands selector lists', () {
      const svg = '<svg><style>.a, .b{fill:red}</style><path class="b"/></svg>';
      expect(inlineSvgCss(svg), contains('style="fill:red"'));
    });

    test('matches type, universal and multiple classes', () {
      const svg = '''
<svg><style>path{fill:red}.a{fill-opacity:.5}*{stroke:none}</style>
<path class="a"/></svg>''';
      final result = inlineSvgCss(svg);
      expect(result, contains('fill:red'));
      expect(result, contains('fill-opacity:.5'));
      expect(result, contains('stroke:none'));
    });

    test('gives id selectors priority over class selectors', () {
      const svg = '''
<svg><style>#x{fill:red}.a{fill:blue}</style>
<path id="x" class="a"/></svg>''';
      expect(inlineSvgCss(svg), contains('style="fill:red"'));
    });

    test('lets a later rule win at equal specificity', () {
      const svg = '''
<svg><style>.a{fill:red}.a{fill:blue}</style>
<path class="a"/></svg>''';
      expect(inlineSvgCss(svg), contains('style="fill:blue"'));
    });

    test('honours !important across specificity', () {
      const svg = '''
<svg><style>.a{fill:red !important}#x{fill:blue}</style>
<path id="x" class="a"/></svg>''';
      expect(inlineSvgCss(svg), contains('style="fill:red"'));
    });

    test("keeps an element's inline style over a stylesheet rule", () {
      const svg = '''
<svg><style>.a{fill:red}</style>
<path class="a" style="fill:green"/></svg>''';
      final result = inlineSvgCss(svg);
      expect(result, contains('style="fill:green"'));
      expect(result, isNot(contains('fill:red')));
    });

    test('appends the resolved style after presentation attributes', () {
      const svg = '''
<svg><style>.a{fill:red}</style>
<path class="a" fill="black"/></svg>''';
      final result = inlineSvgCss(svg);
      expect(result, contains('fill="black"'));
      expect(result, matches(RegExp('fill="black"[^>]*style="fill:red"')));
    });

    test('survives comments and CDATA in the stylesheet', () {
      const svg = '''
<svg><style><![CDATA[/* c */.a{fill:red}]]></style>
<path class="a"/></svg>''';
      expect(inlineSvgCss(svg), contains('style="fill:red"'));
    });
  });

  group('NormalizingSvgFileLoader', () {
    test('compiles the code-oss icon through vector_graphics', () async {
      const svg = '''
<svg id="Layer_1" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
<style>.st0{fill:#f6f6f6;fill-opacity:0}.st1{fill:#fff}.st2{fill:#167abf}</style>
<path class="st0" d="M1024 1024H0V0h1024v1024z"/>
<path class="st1" d="M1024 85.333v853.333H0V85.333h1024z"/>
<path class="st2" d="M0 85.333h298.667v853.333H0V85.333z"/>
</svg>''';
      final directory = await Directory.systemTemp.createTemp('svg-inliner');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/code-oss.svg')
        ..writeAsStringSync(svg);

      // `vg.loadPicture` runs the real parser/compiler, so this fails if the
      // inlined document is not valid vector_graphics input.
      final info = await vg.loadPicture(NormalizingSvgFileLoader(file), null);
      addTearDown(info.picture.dispose);
      expect(info.size.width, greaterThan(0));
    });

    test('compares equal for the same file and differs by path', () {
      final first = NormalizingSvgFileLoader(File('/tmp/a.svg'));
      final second = NormalizingSvgFileLoader(File('/tmp/a.svg'));
      final other = NormalizingSvgFileLoader(File('/tmp/b.svg'));
      expect(first, equals(second));
      expect(first.hashCode, second.hashCode);
      expect(first, isNot(equals(other)));
    });
  });
}
