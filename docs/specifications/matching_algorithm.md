# Matching Algorithm

## Goal
Having persistent windows is a key feature of Veshell. It allows users to have a consistent experience across reboots and app restarts.
To do so we need to be able to assign a new application session to an already existing window placeholder.

## Considered Scenarios
The challenge come from the fact that there is no way to predict how an application will behave while starting and therefore we need to be able to detect and handle different scenarios.

### Single Window: Application that start a fresh session and create a single window
This is the most common scenario. The application starts and creates a new Wayland or XWayland Surface.
In this simple case we want to assign the new surface to the persistent window.

### Sequential Windows: Application that when launched create multiple windows sequentially
For applications that have a splash screen or a loading screen. The application starts and creates a new Wayland or XWayland window, then it creates another window.
Here we don't want to create two different Persistent window but instead display them sequentially in the same Persistent window.
The difficulty here is that the lifetime of each windows can overlap.

### Parallel Windows: Application that when launched create multiple windows in parallel to restore a session
Applications that create several windows when launched to restore previously opened windows. Typically for browsers or IDEs or documents viewers.
In this case however we want to restore each surfaces in its own Persistent window.

## Informations available
In order to help us match the surfaces and the persistent windows use the following datas:

* **The application ID** (appId): this is the application ID as defined in the desktop entry file.
    * This is the primary information we use to match the application and the persistent window and should be an exact match.
* **The window title** (title): this is the title of the window as defined by the application.
  * The title can change a lot during while application initialize but it's one of the most reliable information we have to identify a [parallel windows](#parallel-windows).
* **The X11 window** classes (windowClass): this is the X11 window class as defined by the application.
    * Additionnal informations but only usable for XWayland windows.
* **The process ID** (pid): this is the process ID of the application.
    * Since we start the application ourselves we can collect the PID of the starting application.

Thoses datas are both evaluated for the running surfaces but also stored on the persistent window in order to be able to match against them when the application is launched again.

## Matching Algorithm

When a new Surface is created we try to match it against the existing persistent windows sharing the same application ID.

If no matching is found we create a new persistent window for the surface.

Else we assign the surface to the matching persistent window with the best matching score.

For cases like [sequential windows](#sequential-windows) and [parallel windows](#parallel-windows) we can have multiple surfaces assigned to the same persistent window. Since we can display only one surface at a time we we compare their matching score and display the one with the best matches.

In order to handle the [sequential windows](#sequential-windows) we expect that the extra surface close itself after a short delay which we leave us with a single surface to display.

And to distinguish between the [sequential windows](#sequential-windows) and for the [parallel windows](#parallel-windows) we use the extra delay awaited to listen for any changes in the surface properties to match thoses surfaces against other persistent windows sharing the same Application ID.

After a fixed delay a single surface is kept for each persistent window and a new persistent window is created for each extra surface.


