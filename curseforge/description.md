# Party Bag

**See what your party is carrying — right in the item tooltip.**

Ever finished a dungeon with three half-stacks of the same meat spread across three bags? Party Bag shares bag contents between group members, so when you hover over any item you instantly see who else has it and how many. Hand them over, merge the stacks, free up slots.

## Features

- **Party counts in the tooltip** — hover any item (bags, loot window, chat links) to see how many each party member carries, class-colored and sorted by amount.
- **Automatic sync** — bags are shared when you join a group or `/reload`, and re-sent a moment after your bags change. No buttons to press.
- **Lightweight** — sends only when something actually changed, as hidden addon messages to your party or raid. No saved variables, no UI clutter.
- **Clean up after itself** — data for players who leave the group is dropped right away.

## Usage

Just install it — and make sure your groupmates install it too. Only players who run Party Bag share their bags.

| Command | What it does |
|---|---|
| `/pbag` | Shows whose data you have received |
| `/pbag sync` | Asks the group to resend their bags |

## Notes

- Counts cover backpack and equipped bags only — bank contents are not shared.
- Built for **WoW Forever**. Works in party, raid and instance groups.
- Localized: English, Russian.

This is an early version — bug reports and ideas are welcome on [GitHub](https://github.com/Gordory/PartyBag/issues).
