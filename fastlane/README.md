fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios prepare

```sh
[bundle exec] fastlane ios prepare
```

Check the simulator inventory and generate the Xcode project

### ios verify

```sh
[bundle exec] fastlane ios verify
```

Run logic and user-flow tests on every required simulator

### ios screenshots

```sh
[bundle exec] fastlane ios screenshots
```

Run acceptance before capturing localized App Store screenshots

### ios prepare_release

```sh
[bundle exec] fastlane ios prepare_release
```

Verify, capture screenshots, and archive the committed release

### ios release

```sh
[bundle exec] fastlane ios release
```

Upload the inspected, verified release and request App Store review

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
