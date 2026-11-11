# install_yacy

## Description

Installs [YaCy](https://yacy.net), the peer-to-peer search engine, on macOS or Linux, and starts it.

YaCy runs on Java and ships for macOS as a disk image, so getting it going by hand means installing a JDK, telling macOS where it is, and copying the app out of the image. On macOS `install_yacy` does each of these, and skips any which is already done:

1. Installs [Homebrew](https://brew.sh) where there is no `brew`. On Apple silicon Homebrew goes into `/opt/homebrew`, which isn't on `PATH` until the shell is set up, so `brew` is looked for there and in `/usr/local` as well as on `PATH`.
2. Installs OpenJDK with Homebrew.
3. Links OpenJDK into `/Library/Java/JavaVirtualMachines`, so as macOS finds it. This is the step which asks for a password.
4. Downloads the latest YaCy disk image for macOS from [download.yacy.net](https://download.yacy.net) into `~/Downloads`, unless it is there already, mounts it, copies `YaCy.app` into `~/Applications` where that exists and `/Applications` otherwise, and unmounts it.
5. Opens `YaCy.app`, which opens YaCy's search page at http://localhost:8090 in the default browser.

On Linux, YaCy ships as a tarball, and `install_yacy`:

1. Puts Homebrew on `PATH` where it is installed, in `/home/linuxbrew/.linuxbrew`, but isn't on `PATH`.
2. Installs Java, where there is no `java` on `PATH`: OpenJDK with Homebrew where Homebrew is installed, and otherwise a headless Java, 17 or later, with whichever of `apt-get`, `dnf`, `yum`, `pacman`, `zypper` or `apk` there is. This last is the step which asks for a password, unless run as root.
3. Downloads the latest YaCy tarball from [download.yacy.net](https://download.yacy.net) into `~/Downloads`, unless it is there already, and unpacks it into `~/.local/share/yacy`, or `$XDG_DATA_HOME/yacy` where `XDG_DATA_HOME` is set.
4. Runs YaCy's `startYACY.sh`, which starts YaCy in the background, serving its search page at http://localhost:8090, unless YaCy is running already.

Run again once everything is installed, it only starts YaCy.

## Installation

### 0. Have Ruby installed

On Linux, install nokogiri from the distribution too, since installing it as a gem builds native extensions where it isn't run as root. For instance:

```shell
$ sudo apt-get install ruby ruby-nokogiri
```

```shell
$ sudo dnf install ruby rubygem-nokogiri
```

```shell
$ sudo zypper install ruby 'rubygem(nokogiri)'
```

```shell
$ sudo apk add ruby ruby-nokogiri
```

### 1. Clone the repository

```shell
$ git clone https://github.com/thoran/install_yacy.git
```

The script puts its own `../lib` on the load path, so a clone kept whole is all it needs. On Linux, `lib/Linux` holds `Linux::PackageManager`, and `lib/Tarball.rb` holds `Tarball`, which need nothing beyond Ruby's standard library.

## Dependencies

Two gems, each installed by the script where it can't be required:

1. [macos.rb](https://github.com/thoran/macos.rb), on macOS only, to mount and unmount the disk image.
2. [nokogiri](https://nokogiri.org), to read the name of the latest disk image or tarball off download.yacy.net.

## Usage

```shell
$ ruby install_yacy/bin/install_yacy
```

There is nothing to configure and no arguments to give. Each command it runs is printed as it runs.

On macOS:

1. Where asked, enter the password you log in to your computer with.
2. YaCy's disk image isn't signed, so the first time, macOS may say it could not verify "YaCy.app". Click Done and run `install_yacy` again, which will then only start YaCy. If it is still blocked, open System Settings > Privacy & Security, click Open Anyway beside the message about "YaCy.app", and run `install_yacy` again.
3. Where asked whether to allow "java" to find devices on local networks, Don't Allow is fine, unless YaCy is to index or find peers on your own network.
4. To stop YaCy, quit it from its Dock icon.

On Linux:

1. Where asked by sudo, enter your password.
2. Open http://localhost:8090 once YaCy has had a few seconds to start.
3. To stop YaCy, run `~/.local/share/yacy/stopYACY.sh`.

## Notes

1. macOS, on Apple silicon or Intel, and Linux with `apt-get`, `dnf`, `yum`, `pacman`, `zypper` or `apk`. It has been run on Debian, Fedora, openSUSE Tumbleweed and Alpine, and on Debian with Homebrew. Homebrew isn't installed on Linux where it isn't there already, and isn't used as root, which Homebrew refuses. Elsewhere on Linux, install Java 17 or later first, and `install_yacy` does the rest.
2. YaCy needs Java 17 or later. With `apt-get`, the distribution's default Java is installed, which is that on Debian 12 and later and Ubuntu 24.04 and later, but is Java 11 on Ubuntu 22.04. With `pacman`, the package database isn't synchronised first, so as not to upgrade only in part.
3. On macOS, YaCy is found to be installed where `YaCy.app` is in `~/Applications` or `/Applications`, wherever it came from. On Linux, where `startYACY.sh` is in `~/.local/share/yacy`, and to be running where YaCy's own `DATA/yacy.running` is there, as YaCy's own scripts take it to be.
4. `startYACY.sh` needs `getopt`, from util-linux, which all but the most minimal Linux installs have.
5. There is no uninstaller. On macOS, YaCy keeps its index and settings in `~/Library/Application Support/net.yacy.YaCy`, apart from the app. On Linux, it keeps them in `DATA` within `~/.local/share/yacy`.
6. The disk image or tarball is left in `~/Downloads`, so as a second install doesn't download it again. On Linux, `~/Downloads` is made where there isn't one.

## Tests

```shell
$ bundle install
$ bundle exec ruby test/install_yacy.rb
$ bundle exec ruby test/Linux/PackageManager_test.rb
$ bundle exec ruby test/Tarball_test.rb
```

download.yacy.net and the package managers are stubbed, so they run on macOS too, and nothing is installed, apart from stand-in tarballs unpacked into temporary directories.

## Contributing

1. Fork it: `https://github.com/thoran/install_yacy/fork`
2. Create your feature branch: `git checkout -b my-new-feature`
3. Commit your changes: `git commit -am 'Add some feature'`
4. Push to the branch: `git push origin my-new-feature`
5. Create a new pull request


## License

MIT
