## caseopening 1.0.1012pre
### THIS IS JUST A PRE_ RELEASE! UNEXPECTED THINGS COULD HAPPEN!
### YOU CAN GIVE CASES, KEYS TO THE PLAYERS THROUGH DB. (case_players and case_inventory table)
### THE POINT OF THIS RELEASE IS TO REPORT AS MUCH BUGS AS POSSIBLE AND FIX THEM
# THIS IS NOT READY FOR LIVE SERVERS! TEST PURPOSES ONLY! You have been warned.

# Before asking "how-to" questions, please take a look on the wiki: https://github.com/KillStr3aK/caseopening/wiki

### Stock modules:
* Store Support ( Core included ) - Players can open anything from the Store plugin (Based on item unique_id)
* VIP Support ( Core included ) - Currently only my own vipsystem is supported, but you can create your own module.
* Admin commands ( Core included ) - Commands will be listed below
* Endgame drops ( Core included ) - A random player will be picked for the case drop
* Place cases to the map ( Core included ) - You can place cases
* Ban system ( Core included ) - Admins can ban players from using the system.

### Commands:
* **sm_cases** - Opens the menu

* **sm_drop** - Giving out a crate like in the endgame drop
* **sm_caseban** - Banning a player

* **sm_refreshcases** - Refresh the cases from db (This will refresh the items && grades too.)
* **sm_loadinv** - Load inventory for the given player

### Known bugs:
* Sometimes the drop command is not works as intented
* Not precached models can crash the server && players

## What will be added after the first release?
* Spawning the case in front of the player and play the open animation
* New modules, based on feedbacks
* Better menu, the current one is for test purposes.
* More options for how could the players get cases, keys.

Preview:
![Stock cases, filled with store items](https://i.imgur.com/U7MSz8s.png)

Custom case:

![Custom case, filled with store items](https://i.imgur.com/YLWIIrP.png)

Pickup:

![Pickup](https://i.imgur.com/PeOwdm3.png)
