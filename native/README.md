# Physics core

C++ through GDExtension, from DESIGN.md, "Tech". The source is in `src/` and it builds into `../bin/`, which isn't committed. Rebuild after pulling or changing anything in `src/`.

First time, fetch godot-cpp:

```bash
git submodule update --init
```

Mac, needed to run the game from the editor:

```bash
scons -C native platform=macos arch=arm64 target=template_debug
```

Phone, needed before exporting to Android:

```bash
scons -C native platform=android arch=arm64 target=template_debug
```

Android builds need NDK 28.1.13356709 and `ANDROID_HOME` set.

Test the core after a Mac build:

```bash
godot --headless --path . --script tests/test_gravity_model.gd
```
