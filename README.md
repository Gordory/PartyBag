# Party Bag

A WoW Forever addon (`Interface: 16001`). Every group member broadcasts the contents of their bags
(`itemID → count`) via hidden addon messages. Hovering an item shows who in the group carries it and how many,
which makes it easy to gather half-stacks on one player.

Everyone whose bags you want to see must have the addon installed.

## How it works

- Scans the backpack, equipped bags and the reagent bag (bank is not included).
- After bags change (debounced by 2 s), sends a full snapshot if it differs from the last one sent.
  Snapshots are split into chunks of ≤ 255 bytes (`S;ver;seq;idx;total;id:n,...`).
- On joining a group or `/reload`, broadcasts a request `R;ver`; everyone replies with their snapshot.
- Data for a player is dropped when they leave the group; all data is dropped when you leave.

## Settings

Options → AddOns → Party Bag (stored in `PartyBagDB`):

- **Show header** (off by default) — the "Party bags:" title above the tooltip list.
- **Show my items** (off by default) — adds your own count to the list.
- **Mode** — *Short* (default) lists only players who carry the item; *Full* lists everyone who shared their bags,
  with 0 for those without it. Players without the addon are never listed.

The list keeps one order on every item: your own row first, then everyone else by name.

## Commands

- `/partybag` or `/pbag` — list players whose data has been received
- `/partybag sync` — request data again
- `/partybag debug` — toggle debug output of incoming messages and tooltip rows (saved between sessions)

## Localization

Strings use [AceLocale-3.0](https://www.wowace.com/projects/ace3): `Locales/enUS.lua` is the default, other
`Locales/<locale>.lua` files override it, and missing keys fall back to English. To add a language, copy
`enUS.lua`, change the locale code (drop the `true`), translate, and list the file in `PartyBag.toc`.

## Libraries

`Libs/` is not tracked: the packager fetches LibStub and AceLocale-3.0 from the `externals` in `.pkgmeta`.
For a local checkout, download the same paths into `Libs/`.

## Lint

```sh
brew install luacheck
luacheck .
```

`.luacheckrc` targets Lua 5.1 (the WoW runtime) and whitelists the client API the addon uses;
add new API globals there when the code starts using them.

Pure modules (`Names.lua`, `Rows.lua`, `Bags.lua`, no WoW API calls) have plain-`assert` tests, run from the repo root:

```sh
lua tests/names_test.lua
lua tests/rows_test.lua
lua tests/bags_test.lua
```

## Releasing to CurseForge

CurseForge Automatic Packaging builds and publishes the addon on a GitHub webhook, following `.pkgmeta`.
A release is a pushed tag:

```sh
git tag v0.1.0
git push origin v0.1.0
```

A tag containing `alpha` becomes an Alpha, `beta` a Beta, anything else a Release.
Push tags with git: a tag created through the GitHub API or web UI may not trigger the webhook.

## Icon

`Media/Icon.tga` (64×64) is the addon-list icon, `curseforge/avatar.png` (400×400) is the CurseForge project avatar.
Source art: `art/icon-source.png`.

## CurseForge page

`curseforge/` holds the project page sources: `summary.txt` (short summary), `description.md` (full description), `avatar.png`.
CurseForge has no API for project descriptions, so copy them to authors.curseforge.com by hand after editing.
