### Naming convention

The new naming convention is the following:

**File naming convention**

In order to speed-up the build process of the generated code by `build_runner` I specified those 3 extensions:

- `.model.dart` for Freezed class models
- `.provider.dart` for Riverpod related files
- `.model.serializable.dart` for Freezed class with JSON serialization enabled (which need both generation)
- Bonus `.widget.dart` for the flutter widget files for consistency with the others

**Variable naming convention**

For variable related to models always use **singular** and add verbose descriptor for collection of items.

```dart
final widget = Widget();
final List<Widget> widgetList = [];
final Map<String, Widget> widgetMap = {};
final widgetSet = <Widget>{};
```

Boolean variable should start by **is**

```dart
final bool isReady = false;
final bool isDrawn = false;
final bool isMapped = isReady && isDrawn;
final bool isParent = true;
```

Number and String should combine **subject** and **descriptor**

```dart
final int widgetListLength = 12;
final int taskCount = 5;
final String menuTitle = 'Variables';
final String categoryDescription = 'The naming convention';
```

### Consistent Formating

For pull-request reviews it's mandatory to have a consistent code formatting.

That's why I enforce a systematic formatting on file saves.

*For vscode*
```json
{
    "editor.codeActionsOnSave": {
        "source.organizeImports": "always",
        "source.fixAll": "always"
    },
    "editor.formatOnSave": true
}
```