== DelveBuddy TODO ==

=== Midnight ===
* TODO put up beta build?
* Notes
  * On a L90 char right now, it shows *all* bountiful delves... TWW, and Midnight. Should probably only show the most relevant? Auto-detect?
  * It looks like L80 delves on Beta are closed (you physically can't enter them), though they show as bountiful
* Appears to work
  * Restored Coffer Key count
  * Showing of GV rewards
  * Bounty Looted appears to work (same quest ID?)
  * Bounty item detected, show in tooltip, warning displayed
  * Flash Bounty on action bar
* Definitely busted
  * Woldsoul memories - are those a thing at all in Midnight??
  * Doing TWW events (Awakening the Machine, e.g.), shows 50 shards earned (but not owned)
    * You do get the old shard item from that (not currencey)
    * Double-clicking the old shard item does give you a key (it does show under TWW S3)
    * Maybe this'll all change post-beta?
  * New Shreiking Quartz item not working
  * Fix LibQTip LUA error 
    * `HookScript is not allowed on LibQTip tooltips`
    * ([Titan/libs/Ace/LibQTip-1.0-49/LibQTip-1.0.lua]:706: in function 'HookScript'
    * [DelveBuddy/DataBroker.lua]:690: in function 'PopulateDelveSection')
* Maybe busted
  * Bountiful delves show in list even when no longer bountiful? (once completed, i.e.)
    * OH, because delves still bountiful after completion - maybe b/c beta?
√ Add all new Delves
* Fix items/currencies/quests
  √ Coffer Key Shards (?)
  - Make no longer clickable - no longer items
  √ Coffer Keys (?)
  √ Delver's Bounty
  √ Nemesis lure
  * Keys/shards earned
  * Stashes looted
√ Show new Delves
* Only show delves for L90 chars?
* Don't show TWW delves?

* Feature: detect if companion has no role, show warning
* Only show nemesis item if don't have bounty item or buff?
* Bug: delver's bounty reminder happens on every inventory update (should just be 1 minute)
    * Would be good to refactor some of that stuff, too.
* Enhancement: Only show Shrieking Quartz if not used/have bounty?)
* Feature: reminder for Shrieking Quartz?
* Feature: show changelog on first login after update?
