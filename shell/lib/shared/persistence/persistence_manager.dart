import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

Directory persistenceDirectory = Directory(
  path.join(
    Platform.environment['XDG_CONFIG_HOME']!,
    'veshell',
    'persistence',
  ),
);

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
            final modelJson = jsonDecode(await modelFile.readAsString())
                as Map<String, dynamic>;
            modelMap[modelId] = modelJson;
          }
        }
        folderToModelMap[modelFolderName] = modelMap;
      }
    }
    return folderToModelMap;
  }

  static Future<void> storeModelJson(
    String modelFolder,
    String modelId,
    Map<String, dynamic> json,
  ) async {
    final file = File(
      path.join(persistenceDirectory.path, modelFolder, '$modelId.json'),
    );
    if (!file.existsSync()) {
      await file.create(recursive: true);
    }
    await file.writeAsString(jsonEncode(json));
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
