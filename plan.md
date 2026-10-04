# This is a learning repo for:
- a simple shoot em up "Gnarlaxx"
- language comparison


Proposed approxmimate scope:

## Game Description

** Look / Graphics **
Vertical classic upwards scrolling shoot em up in a window. Layered 2D graphis with parallax effect.
Graphics are tiled with 32x32 px tiles. Rendered in full color even if source graphics are paletted
Render to 400x500 rander target
Presented at with integer scaling. Default to 2X in a window (800x1000 px window)

** Audio / Sound **
Music plays in bakground. mp3 or ogg. 
One shot sfx mixed in. at least 8 sounds playing at any time. wavs.
Global mix setting for music, sfx and master


** Game play **

Game menu + choice of start or high scores and quit
startin fades through black and game play screen shows up, then player ship enters, classic blinking effect. Text appearing "Enemy Boss reported to prepare invasion" "you must stopp him! go!. voice over in bad english.

3 enemy types.
- "pawn":  attack in waves of 5. in pattern formation. dumb
- "kamikaze-drone": enters scene, blinks, then searches fast for the player and attacks by crashing into them
- "boss": after 10 waves and 5 drones, we meet the boss; Like a big variant of the the kamikaze drone; roams top of screen. blinks red before shooting attack: shoots a auto fire gun over an arc; second attack pattern: retracts guns and try to ram the player; the extends guns again and pattern repeats.
- player must destroy left gun holder and right gun holder, then boss opens core with a third gun and the pilot exposed. fires more intense rapid fire "stressed" but now the player can kill the boss. left gun requires 10 hit, right gun 10 hits, core: 10 hits

killing the boss will give a "level cleared" message in cool retro graphics. + a score increase and a "ready for the next mission"

keyboard wasd moves ship with pseudo physics. left and right movement should show a banking sprite
player bullets are small blueish and fast
enemy bullets are classic yellow/redish glow that move quite slow so they can be evaded


## milestones 
M0:
- choose language and frameworks that are easiest for agent to work with
- download or generate graphics sprite/tile sheets.
- download or generate title logo
- decide on the simplest fitting font rendering. perhaps a built in bitmap font


M1:
- implement in the choosen language
- measure performace and resource needs at least at a level where it is possible to understand roughly. 

iterate with user until he is satisfied

Acceptence: game is playable with graphics and sound in place.


M2a-c: port to language a,b,c. one at a time. identical look.
The purpose is to see how the same kind of application is expressed in the different languages. (idiomatic!)

M3: Evaluation of pros and cons of languages. 

M4: Post eval next step. Probable: integrating a script language to live code the enemy behaviors etc. 


## What it is not:
- not supposed to be a good, real game with polish. 