import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guard the UI boundaries, not every string in the program: protocol keys,
/// paths, logs and developer-inspector property identifiers are not messages.
void main() {
  test('UI text literals belong in the ARB catalog', () {
    final violations = <String>[];
    for (final file in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart') ||
          file.path.endsWith('.g.dart') ||
          file.path.endsWith('.freezed.dart') ||
          file.path.contains('/l10n/')) {
        continue;
      }
      final result = parseString(
        content: file.readAsStringSync(),
        path: file.path,
      );
      result.unit.accept(
        _UiTextVisitor((expression) {
          final line = result.lineInfo
              .getLocation(expression.offset)
              .lineNumber;
          violations.add('${file.path}:$line: ${expression.toSource()}');
        }),
      );
    }
    expect(
      violations,
      isEmpty,
      reason:
          'Extract user-facing text into lib/l10n/app_en.arb:\n${violations.join('\n')}',
    );
  });
}

class _UiTextVisitor extends RecursiveAstVisitor<void> {
  _UiTextVisitor(this.report);
  final void Function(Expression) report;

  static const textArguments = {
    'tooltip',
    'hintText',
    'labelText',
    'semanticLabel',
    'semanticsLabel',
  };

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final type = node.constructorName.type.toSource();
    if (const {'Text', 'SelectableText'}.contains(type) &&
        node.argumentList.arguments.isNotEmpty) {
      _check(node.argumentList.arguments.first.argumentExpression);
    }
    if (type == 'Tooltip') {
      for (final argument
          in node.argumentList.arguments.whereType<NamedArgument>()) {
        if (argument.name.lexeme == 'message') {
          _check(argument.argumentExpression);
        }
      }
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitNamedArgument(NamedArgument node) {
    if (textArguments.contains(node.name.lexeme)) {
      _check(node.argumentExpression);
    }
    super.visitNamedArgument(node);
  }

  void _check(Expression expression) {
    switch (expression) {
      case SimpleStringLiteral(:final value):
        // The null sentinel is a technical value shown by developer tools.
        if (value != 'null' && RegExp('[a-zA-Z]').hasMatch(value)) {
          report(expression);
        }
      case StringInterpolation(:final elements):
        if (elements.whereType<InterpolationString>().any(
          (part) => RegExp('[a-zA-Z]').hasMatch(part.value),
        )) {
          report(expression);
        }
      case AdjacentStrings(:final strings):
        strings.forEach(_check);
      case ConditionalExpression(:final thenExpression, :final elseExpression):
        _check(thenExpression);
        _check(elseExpression);
      case SwitchExpression(:final cases):
        for (final clause in cases) {
          _check(clause.expression);
        }
      case BinaryExpression(:final leftOperand, :final rightOperand):
        _check(leftOperand);
        _check(rightOperand);
      default:
        break;
    }
  }
}
