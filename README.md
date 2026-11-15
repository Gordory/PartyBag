# Party Bag

A WoW Forever addon (`Interface: 16001`). Every group member broadcasts the contents of their bags
(`itemID → count`) via hidden addon messages. Hovering an item shows who in the group carries it and how many,
which makes it easy to gather half-stacks on one player.

Everyone whose bags you want to see must have the addon installed.

## How it works

- Scans bags 0–4 (bank is not included).
- After bags change (debounced by 2 s), sends a full snapshot if it differs from the last one sent.
  Snapshots are split into chunks of ≤ 255 bytes (`S;ver;seq;idx;total;id:n,...`).
- On joining a group or `/reload`, broadcasts a request `R;ver`; everyone replies with their snapshot.
- Data for a player is dropped when they leave the group; all data is dropped when you leave.

## Commands

- `/partybag` or `/pbag` — list players whose data has been received
- `/partybag sync` — request data again

## Local deploy

```sh
./deploy.sh                # → /Volumes/Data/Games/World of Warcraft/_forever_/Interface/AddOns/PartyBag
DRY_RUN=1 ./deploy.sh      # only show what would change
./deploy.sh _classic_era_  # a different client flavor
```

The local copy keeps `@project-version@` in the `.toc`; the version is substituted only when CurseForge packages a release.

## Releasing to CurseForge

CurseForge Automatic Packaging builds and publishes the addon on a GitHub webhook, following `.pkgmeta`.
A release is a pushed tag:

```sh
git tag v0.1.0
git push origin v0.1.0
```

A tag containing `alpha` becomes an Alpha, `beta` a Beta, anything else a Release.
Push tags with git: a tag created through the GitHub API or web UI may not trigger the webhook.

One-time setup:
1. CurseForge project settings: Source — GitHub, `https://github.com/Gordory/PartyBag`;
   Automatic Packaging — package tags only.
2. API token: https://www.curseforge.com/account/api-tokens (e.g. "Webhooks").
3. GitHub → Settings → Webhooks → Add webhook, Payload URL:
   `https://www.curseforge.com/api/projects/<projectID>/package?token=<token>`,
   everything else at defaults. `<projectID>` is in the "About This Project" block on the project page.

## Icon

`Media/Icon.tga` (64×64) is the addon-list icon, `curseforge/avatar.png` (400×400) is the CurseForge project avatar.
Source art: `art/icon-source.png`.

## CurseForge page

`curseforge/` holds the project page sources: `summary.txt` (short summary), `description.md` (full description), `avatar.png`.
CurseForge has no API for project descriptions, so copy them to authors.curseforge.com by hand after editing.
