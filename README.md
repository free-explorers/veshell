# veshell-prototype

In order to help us decide which technical stack to choose for Veshell we need to build some prototypes:

The project responsibility will be splitted into two softwares: 
- the front-end which will be responsible of displaying all the UI from the panels to menus and persistences placeholders
- the back-end which will handle all the Windows management process

Thoses two software will work in tandem and both requires each other. They will need to have special interactions using custom Wayland protocols.

For the front-end we need to create:
- A Flutter lib that bridge Flutter with Wayland - **[Repository](https://github.com/free-explorers/veshell-prototype-flutter-wayland-lib)**
- A Flutter App using [flutter-elinux](https://github.com/sony/flutter-elinux) platform to display a system panel listing all opened windows - **[Repository](https://github.com/free-explorers/veshell-prototype-flutter)**

As Backend we need to make:
- A custom wayland protocol to provide all the opened windows
- A basic wayland server displaying windows as Maximized state and allowing keyboard navigation using: [Smithay (Rust)](https://github.com/free-explorers/veshell-prototype-smithay) and [Mir (C++)](https://github.com/free-explorers/veshell-prototype-mir) toolkits
