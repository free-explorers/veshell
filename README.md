# veshell-prototype

This is the current Proof of concept of the [Veshell](https://github.com/free-explorers/veshell) project.

It's a custom Flutter Embedder used to provide a Wayland compositor for linux.

The project responsibility will be splitted into parts: 
- the front-end will be handled by the Flutter renderer and it will be responsible of displaying all the UI, organizing the Spatial Layout and render the applications windows.
- the back-end which will be the Wayland Server will be made using Smithay in Rust and will be responsible to handle the relation between the renderer and the wayland windows.

# Veshell CLI

You can activate our internal CLI

```shell
dart pub global activate --source path .
```

then get access to `veshell` command-line
```shell
This CLI help install and develop Veshell

Usage: veshell <command> [arguments]

Global options:
-h, --help            Print this usage information.
    --[no-]verbose    Noisy logging, including all shell commands executed.
-t, --target          Specify the build target
                      [debug (default), profile, release]

Available commands:
  build     Build and package Veshell
  clean     Clean the project and restore it to a fresh state
  dev       Start a build_runner watch and run flutter shell
  install   Build and install Veshell localy
  run       run veshell

Run "veshell help <command>" for more information about a command.
```

# Special thanks

Special thanks to [**roscale**](https://github.com/roscale) for his work on [Zenith](https://github.com/roscale/zenith) and [Wayvern](https://github.com/roscale/wayvern) which are the foundation of this prototype 
