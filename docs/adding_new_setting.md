## Adding a New Setting to the Project

To add a new setting to the project, follow these detailed steps:

### 1. Define the Setting Schema

First, you need to define the setting path and type in the settings schema file. This ensures that the setting has a well-defined structure and type.

1. Open the [extra/settings/schemas/settings.schema.json](../extra/settings/schemas/settings.schema.json) file.
2. Add a new entry for your setting, specifying its path and type.

```json extra/settings/schemas/settings.schema.json
{
  // ... existing schema ...

  "newSettingPath": {
    "type": "string", // or any other appropriate type
    "description": "Description of the new setting"
  }

  // ... rest of schema ...
}
```

### 2. Assign the Default Value

Next, assign a default value to the new setting. This value will be used if the setting is not explicitly configured by the user.

1. Open the [extra/settings/default/settings.json](../extra/settings/default/settings.json) file.
2. Add the default value for your setting.

```json extra/settings/default/settings.json
{
  // ... existing defaults ...

  "newSettingPath": "defaultValue"

  // ... rest of defaults ...
}
```

### 3. Make the Setting Configurable

To make the setting configurable, you need to add it to the settings properties provider. This allows the setting to be exposed and modified through the application's settings interface.

1. Open the [src/shell/lib/settings/provider/settings_properties.dart](../src/shell/lib/settings/provider/settings_properties.dart) file.
2. Add the new setting to the appropriate group or create a new group if necessary.

```dart src/shell/lib/settings/provider/settings_properties.dart
// ... existing code ...

class SettingsProperties extends _$SettingsProperties {
  @override
  Map<String, SettingGroup> build() {
    // ... existing groups ...

    return {
      // ... existing groups ...

      'newGroup': SettingGroup(
        name: 'New Group',
        description: 'Description of the new group',
        children: {
          'newSettingPath': SettingProperty<String>(
            name: 'New Setting',
            description: 'Description of the new setting',
          ),
        },
      ),
    };
  }
}

// ... rest of file ...
```

### 4. Listen to the New Setting in Dart

To listen to the new setting in Dart, create a new provider that exposes the configured value. This provider will allow other parts of the application to react to changes in the setting.

1. Create a new file for the setting provider, similar to [src/shell/lib/settings/provider/state/icon_theme_setting.dart](../src/shell/lib/settings/provider/state/icon_theme_setting.dart).
2. Implement the provider to listen to the new setting.

```dart src/shell/lib/settings/provider/state/new_setting.dart
@riverpod
String iconThemeSetting(Ref ref) {
  const path = 'theme.iconTheme';
  const fallback = 'Adwaita';

  final property = ref.watch(settingDefinitionByPathProvider(path));
  final jsonValue = ref.watch(jsonValueByPathProvider(path));
  if (property == null ||
      property is! SettingProperty<String> ||
      jsonValue == null) {
    return fallback;
  }
  try {
    return property.castValue(jsonValue);
  } on Exception catch (e) {
    print('Failed to parse theme iconTheme: $e');
    return fallback;
  }
}
```

### 5. Get the New Setting in Rust

Finally, to get the new setting in Rust, add it to the appropriate struct in the settings module. This allows the Rust part of the application to access and use the setting.

1. Open the [src/embedder/settings/mod.rs](../src/embedder/settings/mod.rs) file.
2. Add the new setting to the appropriate struct.

```rust src/embedder/settings/mod.rs
// ... existing code ...

pub struct Settings {
    // ... existing settings ...

    pub new_setting: String,
}

// ... rest of file ...
```

By following these steps, you can successfully add a new setting to the project, making it configurable and accessible from both the Dart and Rust parts of the application.
