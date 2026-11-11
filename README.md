# install_yacy

## Description

Installs [YaCy](https://yacy.net), the peer-to-peer search engine, on macOS, and starts it.

YaCy runs on Java and ships for macOS as a disk image, so getting it going by hand means installing a JDK, telling macOS where it is, and copying the app out of the image. `install_yacy` does each of these, and skips any which is already done:

1. Installs [Homebrew](https://brew.sh) where there is no `brew`. On Apple silicon Homebrew goes into `/opt/homebrew`, which isn't on `PATH` until the shell is set up, so `brew` is looked for there and in `/usr/local` as well as on `PATH`.
2. Installs OpenJDK with Homebrew.
3. Links OpenJDK into `/Library/Java/JavaVirtualMachines`, so as macOS finds it. This is the step which asks for a password.
4. Downloads the latest YaCy disk image for macOS from [download.yacy.net](https://download.yacy.net) into `~/Downloads`, unless it is there already, mounts it, copies `YaCy.app` into `~/Applications` where that exists and `/Applications` otherwise, and unmounts it.
5. Opens `YaCy.app`, which opens YaCy's search page at http://localhost:8090 in the default browser.

Run again once everything is installed, it only starts YaCy.

## Installation

### 0. Have Ruby installed

### 1. Clone the repository

```shell
$ git clone https://github.com/thoran/install_yacy.git
```

The script puts its own `../lib` on the load path, so a clone kept whole is all it needs.

## Dependencies

Two gems, each installed by the script where it can't be required:

1. [macos.rb](https://github.com/thoran/macos.rb), to mount and unmount the disk image.
2. [nokogiri](https://nokogiri.org), to read the name of the latest disk image off download.yacy.net.

## Usage

```shell
$ ruby install_yacy/bin/install_yacy
```

There is nothing to configure and no arguments to give. Each command it runs is printed as it runs.

1. Where asked, enter the password you log in to your computer with.
2. YaCy's disk image isn't signed, so the first time, macOS may say it could not verify "YaCy.app". Click Done and run `install_yacy` again, which will then only start YaCy. If it is still blocked, open System Settings > Privacy & Security, click Open Anyway beside the message about "YaCy.app", and run `install_yacy` again.
3. Where asked whether to allow "java" to find devices on local networks, Don't Allow is fine, unless YaCy is to index or find peers on your own network.
4. To stop YaCy, quit it from its Dock icon.

## Notes

1. macOS only, on Apple silicon or Intel.
2. YaCy is found to be installed where `YaCy.app` is in `~/Applications` or `/Applications`, wherever it came from.
3. There is no uninstaller. YaCy keeps its index and settings in `~/Library/Application Support/net.yacy.YaCy`, apart from the app.
4. The disk image is left in `~/Downloads`, so as a second install doesn't download it again.

## Tests

```shell
$ bundle install
$ bundle exec ruby test/install_yacy.rb
```

download.yacy.net is stubbed, and nothing is installed.

## Contributing

1. Fork it: `https://github.com/thoran/install_yacy/fork`
2. Create your feature branch: `git checkout -b my-new-feature`
3. Commit your changes: `git commit -am 'Add some feature'`
4. Push to the branch: `git push origin my-new-feature`
5. Create a new pull request
