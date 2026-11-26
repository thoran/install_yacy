# yacy

## Description

Installs [YaCy](https://yacy.net), the peer-to-peer search engine, on macOS or Linux, starts it, and opens its page, with the command `yacy`.

YaCy runs on Java 17 or later, and ships for macOS as a disk image and for Linux as a tarball. `yacy` gets Java where there isn't one already, installs YaCy, starts it, and opens its page, skipping whatever is already done:

1. Puts [Homebrew](https://brew.sh) on `PATH` where it's installed but not on `PATH`, as on Apple silicon until the shell is set up. `brew` is looked for in `/opt/homebrew` and `/usr/local` on macOS, and in `/home/linuxbrew/.linuxbrew` and `~/.linuxbrew` on Linux.
2. Gets Java, from wherever `--java` says, as under Java below.
3. Downloads the latest YaCy disk image or tarball from [download.yacy.net](https://download.yacy.net) into `~/Downloads`, unless it is there already. On macOS it mounts the image, copies `YaCy.app` into `~/Applications` where that exists and `/Applications` otherwise, and unmounts it. On Linux it unpacks the tarball into `~/.local/share/yacy`, or `$XDG_DATA_HOME/yacy` where `XDG_DATA_HOME` is set.
4. Starts YaCy, unless it's running already, and waits until YaCy answers on its port, for up to two minutes. On macOS it opens `YaCy.app`. On Linux it runs YaCy's `startYACY.sh`, which starts YaCy in the background. YaCy opens its page, `browserPopUpPage` in its `DATA/SETTINGS/yacy.conf`, in the default browser as it starts, unless `browserPopUpTrigger` there is `false`.
5. Where YaCy was running already, or doesn't open its own page, opens the same page, http://localhost:8090/index.html unless YaCy's settings give another port or page: with `open` on macOS, and with `xdg-open` on Linux. Where the page couldn't be seen, on Linux with no display, as on a server, or on a Mac reached over SSH, whose page would open on the Mac's own screen, it gives YaCy's address instead, whether or not YaCy opens its own page.

Run again once YaCy is running, it only opens its page. Installing, starting, stopping and uninstalling may each be done alone, as under Usage.

### Java

`--java` chooses where Java comes from:

| `--java=` | Java from |
|---|---|
| `auto`, the default | The first of: a Java 17 or later already installed; a package manager already installed, Homebrew first, then MacPorts on macOS or the distribution's on Linux; Adoptium. |
| `existing` | A Java 17 or later already installed, and nowhere else. It stops where there isn't one. |
| `homebrew` | Homebrew's `openjdk`. |
| `macports` | On macOS, MacPorts' `openjdk25`, installed with sudo. |
| `system` | On Linux, the distribution's headless Java, with whichever of `apt-get`, `dnf`, `yum`, `pacman`, `zypper` or `apk` there is, and sudo unless run as root. |
| `adoptium` | [Adoptium](https://adoptium.net)'s Temurin JRE of the latest long-term release, checked against Adoptium's checksum, and unpacked without sudo into `~/Library/Java/JavaVirtualMachines` on macOS, or `~/.local/share/yacy-jre` on Linux. |
| a path to a `java` | That java, where it's 17 or later. |

A package manager isn't installed unasked. `auto` only uses one which is there already. `--java=homebrew`, where Homebrew isn't installed, asks before installing it, and stops where the answer isn't yes, or where there's no terminal to ask at, unless `--install-homebrew` is given too. `--java=macports` stops where MacPorts isn't installed, rather than installing it. Whatever is installed is said before it's installed.

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
$ git clone https://github.com/thoran/yacy.git
```

The script puts its own `../lib` on the load path, so a clone kept whole is all it needs. `lib/YaCy` holds the steps, those for macOS in `YaCy::MacOS` and those for Linux in `YaCy::Linux`, each with the same steps, and what both share in `YaCy::Download`, `YaCy::Homebrew`, `YaCy::Java`, `YaCy::Adoptium` and `YaCy::Process`. On Linux, `lib/Linux` holds `Linux::PackageManager`, and `lib/Tarball.rb` holds `Tarball`, which need nothing beyond Ruby's standard library.

### Or, via Homebrew

```shell
$ brew tap thoran/tap
$ brew install yacy
```

`brew uninstall yacy` removes the command, and leaves YaCy, which the command installed rather than Homebrew. Run `yacy uninstall` first to remove YaCy too.

## Dependencies

Three gems, each installed by the script where it can't be required:

1. [macos.rb](https://github.com/thoran/macos.rb), on macOS only, to mount and unmount the disk image.
2. [nokogiri](https://nokogiri.org), to read the name of the latest disk image or tarball off download.yacy.net.
3. [switches.rb](https://github.com/thoran/switches.rb), to read the options.

## Usage

```shell
$ yacy/bin/yacy
$ yacy/bin/yacy --java=adoptium
$ yacy/bin/yacy --java=homebrew --install-homebrew
$ yacy/bin/yacy --java=/opt/jdk-21/bin/java
$ yacy/bin/yacy install
$ yacy/bin/yacy stop
$ yacy/bin/yacy uninstall
$ yacy/bin/yacy uninstall --data
$ yacy/bin/yacy uninstall --jre=remove
```

Subcommands:

```
(none)     Install YaCy unless it's installed, start it unless it's running, and open its page
install    Install YaCy, and Java for it, unless they're installed
start      Start YaCy, unless it's running
stop       Stop YaCy, where it's running
uninstall  Stop YaCy and remove it, keeping its DATA unless --data, and Adoptium's JRE on Linux unless --jre=keep
```

Options:

```
--java=SOURCE       Where Java comes from: auto, existing, homebrew, macports (macOS), system (Linux), adoptium, or a path to a java (default: auto)
--install-homebrew  Install Homebrew without asking, where --java=homebrew and it isn't installed
--data              With uninstall, remove YaCy's DATA too: its index, settings and identity as a peer
--jre=keep|remove   With uninstall, keep or remove Adoptium's JRE (default: remove on Linux, keep on macOS)
-h, --help          Show the options
```

`--java` and `--install-homebrew` may each be set in `~/.config/yacy/config.yaml` instead, the switch winning where both are given:

```yaml
java: adoptium
install_homebrew: false
```

Each command it runs is printed as it runs.

On macOS:

1. Where asked, enter the password you log in to your computer with. Only `--java=macports` asks, `sudo` installing MacPorts' Java.
2. YaCy's disk image isn't signed, so the first time, macOS may say it could not verify "YaCy.app". Click Done and run `yacy` again, which will then only start YaCy. If it is still blocked, open System Settings > Privacy & Security, click Open Anyway beside the message about "YaCy.app", and run `yacy` again.
3. Where asked whether to allow "java" to find devices on local networks, Don't Allow is fine, unless YaCy is to index or find peers on your own network.
4. To stop YaCy, run `yacy stop`.

On Linux:

1. Where asked by sudo, enter your password. Only `--java=system`, or `auto` where it comes to the distribution's package manager, asks.
2. To stop YaCy, run `yacy stop`.
3. `startYACY.sh` finds Java with `which`, so to start YaCy with Adoptium's JRE other than by `yacy`, put `~/.local/share/yacy-jre/<the JRE>/bin` on `PATH` first.

## Notes

1. macOS, on Apple silicon or Intel, and Linux with `apt-get`, `dnf`, `yum`, `pacman`, `zypper` or `apk`, or with none of them by way of Adoptium. Homebrew isn't used as root on Linux, which Homebrew refuses.
2. YaCy needs Java 17 or later, and a Java older than that counts as none. With `apt-get`, the distribution's default Java is installed, which is that on Debian 12 and later and Ubuntu 24.04 and later, but is Java 11 on Ubuntu 22.04. With `pacman`, the package database isn't synchronised first, so as not to upgrade only in part.
3. On macOS, `YaCy.app` is started by `open`, and so finds Java by way of `java_home`, which looks in `/Library/Java/JavaVirtualMachines` and `~/Library/Java/JavaVirtualMachines`, and takes the newest Java there, whichever `--java` installed it. Homebrew's `openjdk` is linked into `~/Library/Java/JavaVirtualMachines`, without sudo, where it isn't linked into either already. A path given to `--java` on macOS has to be within a Java bundle, ending in `Contents/Home/bin/java`, which is linked there likewise.
4. A JRE from Adoptium gets no updates other than by running `yacy` again once it's removed, where Java from a package manager is updated along with the rest of what the package manager installed.
5. On macOS, YaCy is found to be installed where `YaCy.app` is in `~/Applications` or `/Applications`, wherever it came from. On Linux, where `startYACY.sh` is in `~/.local/share/yacy`. On either, YaCy is found to be running where the process named in its own `yacy.running`, in its `DATA`, is running, a `yacy.running` being left behind where YaCy didn't shut down cleanly. It's stopped as YaCy's own `stopYACY.sh` stops it, by asking it through its API, which YaCy lets do from the same computer without a password unless its settings say otherwise, when the password is asked for.
6. `startYACY.sh` needs `getopt`, from util-linux, which all but the most minimal Linux installs have.
7. The disk image or tarball is left in `~/Downloads`, so as a second install doesn't download it again. On Linux, `~/Downloads` is made where there isn't one.
8. `yacy uninstall` stops YaCy, where it's running, and removes:
   1. YaCy: `YaCy.app` on macOS, and all of `~/.local/share/yacy` but its `DATA` on Linux.
   2. YaCy's `DATA`, holding its index, its settings and the peer's identity, only with `--data`. Otherwise it's kept, and said where, so as YaCy installed again is the same peer, with the same index. On macOS it's `~/Library/Application Support/net.yacy.YaCy`, apart from the app. On Linux it's `DATA` within `~/.local/share/yacy`.
   3. Adoptium's JRE, with its download, unless `--jre=keep` on Linux, and only with `--jre=remove` on macOS. On Linux it's in `~/.local/share/yacy-jre`, which nothing but `yacy` puts there, and isn't on `PATH`. On macOS it's in `~/Library/Java/JavaVirtualMachines`, where `java_home` offers it to every other program wanting Java, and where a JRE may not be one `yacy` put there. Where it's kept, it's said where. Java from a package manager is left on either, since something else may be relying upon it.
   4. The YaCy disk images or tarballs in `~/Downloads`, named `yacy_v`, whichever versions they are.

## Tests

```shell
$ bundle install
$ bundle exec ruby test/YaCy/MacOS_test.rb
$ bundle exec ruby test/YaCy/Linux_test.rb
$ bundle exec ruby test/YaCy/Process_test.rb
$ bundle exec ruby test/Linux/PackageManager_test.rb
$ bundle exec ruby test/Tarball_test.rb
```

download.yacy.net and the package managers are stubbed, so they run on macOS too, and nothing is installed, apart from stand-in tarballs unpacked into temporary directories.

## Contributing

1. Fork it: `https://github.com/thoran/yacy/fork`
2. Create your feature branch: `git checkout -b my-new-feature`
3. Commit your changes: `git commit -am 'Add some feature'`
4. Push to the branch: `git push origin my-new-feature`
5. Create a new pull request


## License

MIT
