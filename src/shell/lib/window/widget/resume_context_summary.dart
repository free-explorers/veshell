import 'package:path/path.dart' as path;
import 'package:shell/window/model/resume_context.serializable.dart';

/// Describes what clicking a placeholder will resume.
///
/// The summary only names facts that describe resumable work: a terminal's
/// directory and foreground program, an opened document, or the last window
/// title. A non-terminal application's working directory is deliberately not
/// used: most applications ignore it on a fresh launch, and applications such
/// as IDEs restore their own workspace instead.
///
/// Examples: `~/src/veshell — nvim`, `report.pdf`, or the last window title.
String? resumeContextSummary(
  ResumeContext? context, {
  String? title,
  String? homeDirectory,
}) {
  if (context != null) {
    final terminal = context.terminal;
    if (terminal != null) {
      final directory = _abbreviate(
        terminal.workingDirectory ?? context.workingDirectory,
        homeDirectory,
      );
      final foreground = terminal.foreground;
      final program = foreground == null
          ? null
          : path.basename(foreground.program);
      if (directory != null && program != null) {
        return '$directory — $program';
      }
      if (program != null) {
        return program;
      }
      if (directory != null) {
        return directory;
      }
    }

    final document = _firstDocument(context);
    if (document != null) {
      return path.basename(document);
    }
  }

  final lastTitle = title;
  if (lastTitle != null && lastTitle.isNotEmpty) {
    return lastTitle;
  }
  return null;
}

String? _firstDocument(ResumeContext context) {
  for (final argument in context.arguments) {
    if (argument.startsWith('-')) {
      continue;
    }
    final uri = Uri.tryParse(argument);
    if (uri != null && uri.hasScheme && uri.scheme == 'file') {
      return uri.toFilePath();
    }
    if (uri != null && uri.hasScheme) {
      return argument;
    }
    if (path.isAbsolute(argument) || path.extension(argument).isNotEmpty) {
      return argument;
    }
  }
  return null;
}

String? _abbreviate(String? directory, String? homeDirectory) {
  if (directory == null || directory.isEmpty) {
    return null;
  }
  if (homeDirectory == null || homeDirectory.isEmpty) {
    return directory;
  }
  if (directory == homeDirectory) {
    return '~';
  }
  if (directory.startsWith('$homeDirectory/')) {
    return '~${directory.substring(homeDirectory.length)}';
  }
  return directory;
}
