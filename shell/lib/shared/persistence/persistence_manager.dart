import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

Directory persistenceDirectory = Directory(
  path.join(
    Platform.environment['XDG_CONFIG_HOME'] ??
        '${Platform.environment['HOME']!}/.config',
    'veshell',
    'persistence',
  ),
);

final _log = Logger('PersistenceManager');

class PersistenceManager {
  /// Load all models from the persistence directory
  /// by grouping them by folder then by id.
  static Future<Map<String, Map<String, Map<String, dynamic>>>>
      loadAllModelsJson() async {
    final persistentFolder = Directory(path.join(persistenceDirectory.path));
    final folderToModelMap = <String, Map<String, Map<String, dynamic>>>{};
    if (!persistentFolder.existsSync()) {
      return folderToModelMap;
    }
    final modelFolders = persistentFolder.listSync();
    for (final modelFolder in modelFolders) {
      if (modelFolder is Directory) {
        final modelFolderName = path.basename(modelFolder.path);
        final modelFiles = modelFolder.listSync();
        final modelMap = <String, Map<String, dynamic>>{};
        for (final modelFile in modelFiles) {
          if (modelFile is File) {
            final modelId = path.basenameWithoutExtension(modelFile.path);
            final fileString = modelFile.readAsStringSync();
            try {
              final modelJson = jsonDecode(fileString) as Map<String, dynamic>;
              modelMap[modelId] = modelJson;
            } catch (e, stack) {
              _log.severe(
                'Error loading model $modelId \n $e \n in \n $fileString',
                e,
                stack,
              );
            }
          }
        }
        folderToModelMap[modelFolderName] = modelMap;
      }
    }
    return folderToModelMap;
  }

  static Future<void> _storeModelJson(
    String modelFolder,
    String modelId,
    Map<String, dynamic> json,
  ) async {
    _log.info('start storeModelJson for $modelFolder-$modelId');
    final tempFile = File(
      path.join(persistenceDirectory.path, modelFolder, '$modelId.temp'),
    );
    if (!tempFile.existsSync()) {
      await tempFile.create(recursive: true);
    }
    await tempFile.writeAsString(jsonEncode(json));

    final targetFile = File(
      path.join(persistenceDirectory.path, modelFolder, '$modelId.json'),
    );
    await tempFile.rename(targetFile.path);
    final stack = StackTrace.current;
    _log.info(
      'end storeModelJson for $modelFolder-$modelId',
    );
  }

  static final _fileQueues = <String, Queue<Future<void> Function()>>{};

  static Future<void> queueStoreModelJson(
    String modelFolder,
    String modelId,
    Map<String, dynamic> json,
  ) async {
    final filePath =
        path.join(persistenceDirectory.path, modelFolder, '$modelId.json');

    _fileQueues.putIfAbsent(filePath, Queue.new);

    final completer = Completer<void>();

    _fileQueues[filePath]!.add(() async {
      try {
        await _storeModelJson(modelFolder, modelId, json);
        completer.complete();
      } catch (e) {
        completer.completeError(e);
      } finally {
        _fileQueues[filePath]!.removeFirst();
        if (_fileQueues[filePath]!.isNotEmpty) {
          _fileQueues[filePath]!.first();
        }
      }
    });

    if (_fileQueues[filePath]!.length == 1) {
      _fileQueues[filePath]!.first();
    }

    return completer.future;
  }

  static Future<void> deleteModelJson(
    String modelFolder,
    String modelId,
  ) async {
    final file = File(
      path.join(persistenceDirectory.path, modelFolder, '$modelId.json'),
    );
    if (file.existsSync()) {
      await file.delete();
    }
  }
}
