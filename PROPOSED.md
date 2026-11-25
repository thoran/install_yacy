# yacy/PROPOSED.md

The discrete jobs are in TODO, and the direction is in ROADMAP.md. This holds what is undecided.

## Packaging

- Whether YaCy itself is installed by a cask instead, with the script reduced to what a cask doesn't do. YaCy's disk image isn't signed, and Homebrew no longer accepts casks which fail Gatekeeper into its own repository, so such a cask would live in a tap of its own.
- Whether an .app wraps the script, so as it can be run without a terminal.

## Uninstalling

- What `yacy uninstall` removes: YaCy itself, once stopped, being YaCy.app on macOS and `yacy` in the XDG data directory on Linux; and whether also any of what follows.
- YaCy's DATA, holding its index, its settings and the peer's identity, so as a YaCy installed again is a new peer with an empty index. Kept unless asked for, as with `--data`, is the likelier. On macOS DATA is apart from YaCy.app, in `~/Library/Application Support/net.yacy.YaCy`. On Linux it's within YaCy's own directory, so keeping it means removing all but DATA, and saying what's left behind, or YaCy keeping its DATA elsewhere from the start.
- Java. Adoptium's JRE on Linux, in `yacy-jre`, is put there by nothing but yacy. On macOS Adoptium's JDK sits among any others in `~/Library/Java/JavaVirtualMachines`. The JDK's link there or in `/Library/Java/JavaVirtualMachines`, and Java from a package manager, are each something else may be relying upon.
- The disk image or tarball downloaded into `~/Downloads`.
- `brew uninstall yacy` removes the command and not YaCy, a formula having nothing which runs on its being uninstalled. Whether the formula's caveats say to run `yacy uninstall` first, and the README says which removes what.

## Platforms

- Whether Windows is supported.
