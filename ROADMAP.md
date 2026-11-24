# install_yacy/ROADMAP.md

The discrete jobs are to go in TODO, of which there is none yet, and what is undecided is in PROPOSED.md. This holds the direction.

## Commands

install_yacy becomes `yacy`, a command with subcommands.

`yacy` on its own does what's needed for YaCy to be running and its search page open, each step skipped where it's done already: YaCy is installed, with Java for it, unless it's installed; started, unless it's running; and its page opened. On Linux the page is opened once YaCy answers, and where there's no display its address is printed instead. Where download.yacy.net has a newer YaCy than is installed, it says so, and leaves the upgrade to `yacy upgrade`, so as YaCy isn't replaced and restarted when all that was wanted was the page. Were anything of YaCy's to be configured, it would be a step here too.

Each subcommand is one of those steps alone, or one which `yacy` doesn't take:

- `yacy install`: The newest YaCy, and Java for it where it's wanted.
- `yacy start` and `yacy stop`.
- `yacy upgrade`: Replaces YaCy where download.yacy.net has a newer one than is installed.
- `yacy uninstall`: What it removes is under Uninstalling in PROPOSED.md.

`--java`, `--install-homebrew` and the config file are shared by the subcommands. YaCy itself has no command called `yacy`.

YaCy is fetched when the command runs, rather than pinned by a release of this one, so as the newest YaCy is installed without a new release here. The command stays installed for that, and so manages YaCy rather than only installing it once. Nor can it run from within a formula's install, which can't write outside the formula's own prefix, as into ~/Applications.
