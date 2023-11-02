# veshell-prototype

This is the current Proof of concept of the [Veshell](https://github.com/free-explorers/veshell) project.

It's a custom Flutter Embedder used to provide a Wayland compositor for linux.

The project responsibility will be splitted into parts: 
- the front-end will be handled by the Flutter renderer and it will be responsible of displaying all the UI, organizing the Spatial Layout and render the applications windows.
- the back-end which will be the Wayland Server will be made using Smithay in Rust and will be responsible to handle the relation between the renderer and the wayland windows.

# run
```shell
make debug_bundle && cargo run
```

# Special thanks

Special thanks to [**roscale**](https://github.com/roscale) for his work on [Zenith](https://github.com/roscale/zenith) and [Wayvern](https://github.com/roscale/wayvern) which are the foundation of this prototype 
