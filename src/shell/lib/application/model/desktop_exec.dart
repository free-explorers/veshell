/// A parsed desktop-entry `Exec` line.
///
/// The desktop-entry specification describes `Exec` as an argument vector with
/// quoting, not as a shell script. Parsing it up front lets a resume launch pass
/// saved documents as argv elements, instead of interpolating user paths into a
/// shell command.
class DesktopExec {
  const DesktopExec(this.tokens);

  final List<String> tokens;

  /// Parses `Exec` according to the desktop-entry quoting rules.
  ///
  /// Both `"..."` and `'...'` are accepted because entries in the wild use
  /// both; backslash escapes the next character outside single quotes.
  static DesktopExec parse(String exec) {
    final tokens = <String>[];
    final current = StringBuffer();
    var tokenStarted = false;
    var inSingle = false;
    var inDouble = false;

    void finishToken() {
      if (tokenStarted) {
        tokens.add(current.toString());
        current.clear();
        tokenStarted = false;
      }
    }

    for (var i = 0; i < exec.length; i++) {
      final char = exec[i];
      if (inSingle) {
        if (char == "'") {
          inSingle = false;
        } else {
          current.write(char);
        }
        tokenStarted = true;
        continue;
      }
      if (inDouble) {
        if (char == r'\' && i + 1 < exec.length) {
          i++;
          current.write(exec[i]);
        } else if (char == '"') {
          inDouble = false;
        } else {
          current.write(char);
        }
        tokenStarted = true;
        continue;
      }

      switch (char) {
        case '\\' when i + 1 < exec.length:
          i++;
          current.write(exec[i]);
          tokenStarted = true;
        case '"':
          inDouble = true;
          tokenStarted = true;
        case "'":
          inSingle = true;
          tokenStarted = true;
        case ' ' || '\t' || '\n':
          finishToken();
        default:
          current.write(char);
          tokenStarted = true;
      }
    }
    finishToken();
    return DesktopExec(tokens);
  }

  /// Field codes this `Exec` line consumes with a document argument.
  bool get hasFileFieldCode => tokens.any(isFileFieldCode);
}

/// Whether [token] is a standalone document field code.
bool isFileFieldCode(String token) =>
    token == '%f' || token == '%F' || token == '%u' || token == '%U';

/// Quotes [argument] for a POSIX shell command line.
///
/// Used only when appending to an already shell-form custom exec. Resume
/// launches built from a desktop entry use argv directly and never need this.
String shellQuoteArgument(String argument) {
  if (argument.isEmpty) {
    return "''";
  }
  if (RegExp(r'^[A-Za-z0-9_@%+=:,./-]+$').hasMatch(argument)) {
    return argument;
  }
  return "'${argument.replaceAll("'", "'\\''")}'";
}

/// Appends [arguments] as safely quoted shell arguments.
String appendShellArguments(String command, Iterable<String> arguments) {
  final quoted = arguments.map(shellQuoteArgument).join(' ');
  return quoted.isEmpty ? command : '$command $quoted';
}
