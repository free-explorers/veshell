enum KeyCode {
  backspace(14),
  enter(28);

  const KeyCode(this.code);

  final int code;
}

enum KbLayerEnum {
  first,
  second,
  third,
}

typedef KbLayer = List<List<String>>;

class KbLayout {
  final KbLayer firstLayer;
  final KbLayer secondLayer;
  final KbLayer thirdLayer;

  const KbLayout({
    required this.firstLayer,
    required this.secondLayer,
    required this.thirdLayer,
  });
}

enum Case {
  lowercase,
  uppercase,
  capslock,
}

enum KbLayouts {
  en(KbLayout(
    firstLayer: [
      ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'],
      ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'],
      ['z', 'x', 'c', 'v', 'b', 'n', 'm'],
      [',', '.'],
    ],
    secondLayer: [
      ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
      ['@', '#', '\$', '%', '&', '-', '+', '(', ')'],
      ['*', '"', '\'', ':', ';', '!', '?'],
      [',', '_', '/', '.'],
    ],
    thirdLayer: [
      ['~', '`', '|', '•', '√', 'π', '÷', '×', '¶', '∆'],
      ['£', '€', '¢', '¥', '^', '°', '=', '{', '}'],
      ['\\', '©', '®', '™', '℅', '[', ']'],
      [',', '<', '>', '.'],
    ],
  ));

  const KbLayouts(this.layout);

  final KbLayout layout;
}
