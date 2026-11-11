# install_yacy/PROPOSED.md

The discrete jobs are to go in TODO, and the direction in ROADMAP.md, neither of which there is yet. This holds what is undecided.

## Packaging

- Whether install_yacy is installed by a Homebrew formula, the formula carrying `bin`, `lib` and the gems, so as `brew install` gives the script and the script still chooses which YaCy to fetch.
- Whether YaCy itself is installed by a cask instead, with the script reduced to what a cask doesn't do. YaCy's disk image isn't signed, and Homebrew no longer accepts casks which fail Gatekeeper into its own repository, so such a cask would live in a tap of its own.
- Whether the script uses Homebrew only optionally, installing the JDK some other way where Homebrew isn't wanted.
- Whether an .app wraps the script, so as it can be run without a terminal.

## Commands

- Whether install_yacy becomes `yacy-install`, alongside `yacy-start` and `yacy-uninstall`, YaCy itself having no command called `yacy`.

## Uninstalling

- What an uninstaller removes: YaCy.app, and whether also YaCy's data in `~/Library/Application Support/net.yacy.YaCy`, the JDK's link in `/Library/Java/JavaVirtualMachines`, and OpenJDK, each of which something else may be relying upon.

## Platforms

- Whether Windows is supported.
