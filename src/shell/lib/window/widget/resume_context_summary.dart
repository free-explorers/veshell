import 'package:path/path.dart' as path;
import 'package:shell/window/model/resume_context.serializable.dart';

/// Describes what clicking a placeholder will resume.
///
/// Examples: `~/src/veshell — nvim`, `~/Documents`, `report.pdf`, or the last
/// window title when the context has no more specific fact.
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

    final directory = _abbreviate(context.workingDirectory, homeDirectory);
    if (directory != null) {
      return directory;
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
