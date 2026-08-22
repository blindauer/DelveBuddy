# Agent Instructions for WoW Addon Development

## Project Overview
- **Name:** DelveBuddy
- **Type:** World of Warcraft Addon (Retail Patch 12.1.0+)
- **Language:** Lua 5.1 (WoW custom implementation)
- **Core Functionality:** Tracks delve activity activity across all characters in a warband. Tooltip UI with DataBroker module.

## Technology Stack & Environment
- **API:** World of Warcraft API (latest Retail version)
- **UI:** Ace3, LibQTip

## Deployment & Release
- **Deployment:** Run /tools/deploy.sh to install into WoW addons folder
- **Versioning:** Run /tools/prepare_release.sh <version> to set the addon's version. This sets the version in the TOC (committing it), and creates a git tag with that version. Do this in order to prepare a release.
- **Release:** Run /tools/make_release to create and archive a release build, suitable for uploading to CurseForge.

## Documentation Resources
- Utilize WoW API documentation from reputable sources (e.g., Wowpedia).
