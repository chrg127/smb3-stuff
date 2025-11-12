## TODO

- inventory
    - twister warp
- object spawning when user-defined conditions are met
    - airship animation
- castle full-screen flash animation (low priority)
- figure out invisible warps and their interaction with area names
    - possibly something like this: check if we came to an area through inv. warp, if we did then simply do not play the animation
    - pipes would still play the animation, i think? they need to to implement the warp world
- fix shenanigans with lastLevelBeaten
    - currently if you restart while on a level only reachable by boat, go away with the boat, and lose another level,
      you'll get back to the island and get stranded there
    - probably fixable by putting lastLevelBeaten on savedata, but i'm not able to figure out if the player
      has just lost a level or restarted the game
    - above is maybe fixable with a savedata/gamedata variable pair
    - another way could be only saving after beating a level, but then how do you encounters?
        - possibly just use gamedata to alter the player's position when he gets back?
    - good god this saving shit is wrecking my head
- bridges stopped disallowing the player going into water tiles without boats
- no smoke sceneries disappear weirdly

- bug with lastmovement and warps (use the warps in world 3)
    - same stuff with encounters?
    - seems to be fixed now???
- fix stuff with saved levels
    - save levels only on win, not on changing them every time
    - this is because when the game starts it throws the player to the last level beaten
        - need to check if it does so even in main game

## other

https://www.smbxgame.com/forums/viewtopic.php?t=25419
https://www.smbxgame.com/forums/viewtopic.php?t=30254

