https://www.smbxgame.com/forums/viewtopic.php?t=25419
https://www.smbxgame.com/forums/viewtopic.php?t=30254

## TODO

- check if other encounters are possible (piranha plant, tanks, hands)
    - their animation is most likely not right (it's hardcoded for hammer brothers)
- make player go back to last level when losing
- inventory
- object spawning when user-defined conditions are met (very low priority, sorry)
- various fades
- castle full-screen flash animation
- figure out what to do with the castle and bowser castle levels
- airship animation stuff

## notes

### objects

755 - level beaten animation
756 - castle beaten animation
757 - encounter beaten smoke animation
758 - scenery show/hide smoke

### boat

- player state ON_BOAT.
- when the player hits a boat level, its state becomes ON_BOAT; the level is moved around (remember to save its position!).
- the player now can go on any water tile (how do you detect those?). each tile is sitll 16x16 (32x32 in smbx).
- when the player goes on the ledge, its state reverts back to normal and he leaves the boat. remember that this means we have
to check which tile the player is about to go to (but this is easy).

a possible simple way is to define the boat area with invisible levels. then you could reuse the normal code for walking around.
still needs to check for the boat and move it around.

