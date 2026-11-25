# yacy/ROADMAP.md

The discrete jobs are in TODO, and what is undecided is in PROPOSED.md. This holds the direction.

## Commands

`yacy` has `install`, `start` and `stop` as subcommands, and on its own does each of what's needed for YaCy to be running and its page open. Still to come:

- `yacy upgrade`: Replaces YaCy where download.yacy.net has a newer one than is installed.
- `yacy` on its own says where download.yacy.net has a newer YaCy than is installed, and leaves the upgrade to `yacy upgrade`, so as YaCy isn't replaced and restarted when all that was wanted was the page.
- `yacy uninstall`: What it removes is under Uninstalling in PROPOSED.md.

Were anything of YaCy's to be configured, it would be a step of `yacy` on its own too.

YaCy is fetched when the command runs, rather than pinned by a release of this one, so as the newest YaCy is installed without a new release here. The command stays installed for that, and so manages YaCy rather than only installing it once. Nor can it run from within a formula's install, which can't write outside the formula's own prefix, as into ~/Applications.
