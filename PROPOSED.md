# yacy/PROPOSED.md

The discrete jobs are in TODO, and the direction is in ROADMAP.md. This holds what is undecided.

## Packaging

- Whether YaCy itself is installed by a cask instead, with the script reduced to what a cask doesn't do. YaCy's disk image isn't signed, and Homebrew no longer accepts casks which fail Gatekeeper into its own repository, so such a cask would live in a tap of its own.
- Whether an .app wraps the script, so as it can be run without a terminal.

## Uninstalling

- What an uninstaller removes: YaCy.app, and whether also YaCy's data in `~/Library/Application Support/net.yacy.YaCy`, the JDK's link in `/Library/Java/JavaVirtualMachines` or `~/Library/Java/JavaVirtualMachines`, Adoptium's JRE, and Java from a package manager, each of which something else may be relying upon.

## Platforms

- Whether Windows is supported.
