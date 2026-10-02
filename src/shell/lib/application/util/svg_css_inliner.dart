/// Resolves the embedded `<style>` cascade of an SVG document into inline
/// `style` attributes, so `flutter_svg` can render stylesheet-styled icons.
///
/// `flutter_svg`, through `vector_graphics_compiler`, understands presentation
/// attributes and the inline `style` attribute but ignores `<style>` elements
/// and `class` selectors. Freedesktop icon themes and Inkscape/Illustrator
/// exports style their geometry through those selectors, so every `fill` is
/// lost and the renderer falls back to SVG's default: black. That is the
/// "black square" an icon such as the Code - OSS one shows.
///
/// This pass implements the subset of CSS those icons use: simple and compound
/// selectors (type, `.class`, `#id`, `*`), selector lists, specificity, source
/// order and `!important`, and it gives an element's own inline style priority
/// over stylesheet rules. The winning declarations are written back into the
/// element's inline `style` attribute, which the renderer does honour.
///
/// It is deliberately not a CSS engine. At-rules, pseudo-classes, attribute
/// selectors and combinators (` `, `>`, `+`, `~`) are skipped rather than
/// guessed at. A stylesheet this pass cannot understand is returned untouched,
/// so the worst case is the previous behaviour rather than a wrong render.
String inlineSvgCss(String svg) {
  if (!svg.contains('<style')) {
    return svg;
  }

  final source = svg.replaceAll(_xmlComment, '');
  final css = StringBuffer();
  final document = source.replaceAllMapped(_styleElement, (match) {
    css.writeln(match.group(1));
    return '';
  });

  final rules = _parseRules(css.toString());
  if (rules.isEmpty) {
    // Nothing understood: leave the document exactly as it was.
    return svg;
  }

  return document.replaceAllMapped(
    _markup,
    (match) => _rewriteTag(match.group(0)!, rules),
  );
}

final _xmlComment = RegExp('<!--.*?-->', dotAll: true);

final _styleElement = RegExp(
  r'<style\b[^>]*>(.*?)</style\s*>',
  caseSensitive: false,
  dotAll: true,
);

/// One markup token: a start tag, end tag, declaration or processing
/// instruction. It tolerates quoted strings, which may contain `>`.
final _markup = RegExp('<(?:"[^"]*"|\'[^\']*\'|[^>"\'])*>', dotAll: true);

final _tagName = RegExp(r'^<\s*([A-Za-z_][\w:.-]*)');

final _attribute = RegExp('([A-Za-z_:][\\w:.-]*)\\s*=\\s*("[^"]*"|\'[^\']*\')');

final _cssComment = RegExp(r'/\*.*?\*/', dotAll: true);

/// The body of one CSS rule. Inner rules inside at-rules still match; the
/// at-rule selector itself does not, because `[^{}]*` cannot span a brace.
final _cssRule = RegExp(r'([^{}]+)\{([^{}]*)\}');

/// A compound selector: optional type (or `*`), then any run of `.class` and
/// `#id` parts. Anything else (combinators, pseudo-classes, attribute tests)
/// makes the whole selector unparseable and therefore ignored.
final _compoundSelector = RegExp(r'^(\*|[A-Za-z_][\w.-]*)?((?:[.#][\w-]+)*)$');

final _classToken = RegExp(r'[.#][\w-]+');

final _important = RegExp(r'!\s*important$', caseSensitive: false);

final _whitespace = RegExp(r'\s+');

/// Specificity of an element's own inline style. It only has to beat any
/// selector, whose maximum is a single id.
const _inlineSpecificity = _Specificity(1 << 20, 0, 0);

List<_CssRule> _parseRules(String css) {
  final clean = css
      .replaceAll(_cssComment, '')
      .replaceAll('<![CDATA[', '')
      .replaceAll(']]>', '');
  final rules = <_CssRule>[];
  var order = 0;
  for (final match in _cssRule.allMatches(clean)) {
    final selectorList = match.group(1)!.trim();
    if (selectorList.isEmpty || selectorList.startsWith('@')) {
      continue;
    }
    final declarations = _parseDeclarations(match.group(2)!);
    if (declarations.isEmpty) {
      continue;
    }
    for (final selector in selectorList.split(',')) {
      final compound = _parseCompound(selector.trim());
      if (compound != null) {
        rules.add(_CssRule(compound, declarations, order));
      }
    }
    order++;
  }
  return rules;
}

List<_Declaration> _parseDeclarations(String body) {
  final declarations = <_Declaration>[];
  for (final part in body.split(';')) {
    final trimmed = part.trim();
    if (trimmed.isEmpty) {
      continue;
    }
    final colon = trimmed.indexOf(':');
    if (colon <= 0) {
      continue;
    }
    final property = trimmed.substring(0, colon).trim().toLowerCase();
    var value = trimmed.substring(colon + 1).trim();
    if (value.isEmpty) {
      continue;
    }
    var important = false;
    final importantMatch = _important.firstMatch(value);
    if (importantMatch != null) {
      value = value.substring(0, importantMatch.start).trim();
      important = true;
    }
    if (value == 'inherit') {
      // flutter_svg drops `inherit` from inline styles anyway.
      continue;
    }
    declarations.add(_Declaration(property, value, important: important));
  }
  return declarations;
}

_CompoundSelector? _parseCompound(String selector) {
  final match = _compoundSelector.firstMatch(selector);
  if (match == null) {
    return null;
  }
  final tag = match.group(1);
  var ids = 0;
  var classes = 0;
  String? id;
  final classNames = <String>[];
  for (final token in _classToken.allMatches(match.group(2)!)) {
    final text = token.group(0)!;
    if (text.startsWith('#')) {
      ids++;
      id ??= text.substring(1);
    } else {
      classes++;
      classNames.add(text.substring(1));
    }
  }
  final types = tag != null && tag != '*' ? 1 : 0;
  return _CompoundSelector(
    tag,
    id,
    classNames,
    _Specificity(ids, classes, types),
  );
}

String _rewriteTag(String tag, List<_CssRule> rules) {
  if (tag.startsWith('</') || tag.startsWith('<!') || tag.startsWith('<?')) {
    return tag;
  }
  final nameMatch = _tagName.firstMatch(tag);
  if (nameMatch == null) {
    return tag;
  }
  final name = nameMatch.group(1)!;
  final attributes = _parseAttributes(tag);

  final values = <String, String>{};
  for (final attribute in attributes) {
    values[attribute.name] = _unquote(attribute.rawValue);
  }

  final element = _SvgElement(
    name,
    values['id'],
    _splitClasses(values['class']),
  );
  final resolved = <String, _Resolved>{};

  final inlineStyle = values['style'];
  if (inlineStyle != null) {
    for (final declaration in _parseDeclarations(inlineStyle)) {
      resolved[declaration.property] = _Resolved(
        declaration.value,
        _inlineSpecificity,
        -1,
        important: declaration.important,
      );
    }
  }

  // Track whether a stylesheet declaration actually won a property. If none
  // did, the tag is returned untouched and its formatting is preserved.
  var changed = false;
  for (final rule in rules) {
    if (!rule.selector.matches(element)) {
      continue;
    }
    for (final declaration in rule.declarations) {
      final candidate = _Resolved(
        declaration.value,
        rule.selector.specificity,
        rule.order,
        important: declaration.important,
      );
      final current = resolved[declaration.property];
      if (current == null || candidate.beats(current)) {
        resolved[declaration.property] = candidate;
        changed = true;
      }
    }
  }

  if (!changed) {
    return tag;
  }

  final style = resolved.entries
      .map((entry) => '${entry.key}:${entry.value.value}')
      .join(';');

  final buffer = StringBuffer('<$name');
  for (final attribute in attributes) {
    if (attribute.name == 'style') {
      continue;
    }
    buffer.write(' ${attribute.name}=${attribute.rawValue}');
  }
  // The inline style is appended last so the renderer, which folds attributes
  // in document order, lets it override presentation attributes.
  buffer.write(' style="${style.replaceAll('"', '&quot;')}"');
  if (tag.trimRight().endsWith('/>')) {
    buffer.write('/');
  }
  buffer.write('>');
  return buffer.toString();
}

List<_Attribute> _parseAttributes(String tag) {
  final attributes = <_Attribute>[];
  for (final match in _attribute.allMatches(tag)) {
    attributes.add(_Attribute(match.group(1)!, match.group(2)!));
  }
  return attributes;
}

List<String> _splitClasses(String? value) {
  if (value == null) {
    return const [];
  }
  return value
      .trim()
      .split(_whitespace)
      .where((entry) => entry.isNotEmpty)
      .toList();
}

String _unquote(String quoted) =>
    quoted.length >= 2 ? quoted.substring(1, quoted.length - 1) : quoted;

/// A resolved declaration: the value that won plus the priority it won with.
class _Resolved {
  const _Resolved(
    this.value,
    this.specificity,
    this.order, {
    required this.important,
  });

  final String value;
  final _Specificity specificity;
  final int order;
  final bool important;

  bool beats(_Resolved other) {
    if (important != other.important) {
      return important;
    }
    final bySpecificity = specificity.compareTo(other.specificity);
    if (bySpecificity != 0) {
      return bySpecificity > 0;
    }
    return order >= other.order;
  }
}

/// CSS specificity as the usual (id, class, type) triple.
class _Specificity implements Comparable<_Specificity> {
  const _Specificity(this.ids, this.classes, this.types);

  final int ids;
  final int classes;
  final int types;

  @override
  int compareTo(_Specificity other) {
    if (ids != other.ids) {
      return ids - other.ids;
    }
    if (classes != other.classes) {
      return classes - other.classes;
    }
    return types - other.types;
  }
}

class _CssRule {
  const _CssRule(this.selector, this.declarations, this.order);

  final _CompoundSelector selector;
  final List<_Declaration> declarations;
  final int order;
}

class _Declaration {
  const _Declaration(this.property, this.value, {required this.important});

  final String property;
  final String value;
  final bool important;
}

class _CompoundSelector {
  const _CompoundSelector(this.tag, this.id, this.classes, this.specificity);

  final String? tag;
  final String? id;
  final List<String> classes;
  final _Specificity specificity;

  bool matches(_SvgElement element) {
    if (tag != null &&
        tag != '*' &&
        tag!.toLowerCase() != element.tag.toLowerCase()) {
      return false;
    }
    if (id != null && id != element.id) {
      return false;
    }
    for (final className in classes) {
      if (!element.classes.contains(className)) {
        return false;
      }
    }
    return true;
  }
}

class _SvgElement {
  const _SvgElement(this.tag, this.id, this.classes);

  final String tag;
  final String? id;
  final List<String> classes;
}

class _Attribute {
  const _Attribute(this.name, this.rawValue);

  final String name;

  /// The value including its surrounding quotes, so it can be re-emitted
  /// verbatim without re-escaping.
  final String rawValue;
}
