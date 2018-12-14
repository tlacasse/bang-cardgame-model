*This readme is a duplicate of the Info Tab*

## WHAT IS IT?

*Bang!* is a wild-western themed card game of 4-8 players (the model allows more than 8 players). Each player gets assigned a random **role**, and these **roles** are *hidden* to other players. Each player has a certain amount of **health**. The goal is to *shoot* and *kill* (when **health** is 0) other players. Who to kill is determined by **roles**, forming teams. Because the **roles** are hidden, players have to discover the teams on their own.

The **roles** are as follows:

- **The Sheriff** - There is only one **sheriff**, and is the exception to the *hidden* rule, as the **sheriff** is revealed to everyone. The **sheriff** also gains one extra **health** point. The role of the **sheriff** is to kill the **outlaws** and **renegades**.

- **Deputies** - The **deputies** protect the **sheriff** and help kill the **outlaws** and the **renegades**.

- **Outlaws** - The **outlaws** try to kill the **sheriff**.

- **Renegades** - The **renegades** try to kill *everyone* else, including other **renegades**. If the **sheriff** dies first, the **outlaws** win, so the **renegades** want to act like **deputies** and help kill the **outlaws**. Once the **outlaws** are dead, the **renegades** can turn on the **sheriff** and others.

If the **sheriff** dies and there is at least one **outlaw** alive, the **outlaws** win. If the **outlaws** *all* die, the fight continues until *only one* **renegade** remains, and that lone **renegade** wins. At any point if *all* **outlaws** and **renegades** are dead, the **sheriff** and the **deputies** win.

Play starts with the **sheriff**. On each turn, the active player draws 2 **cards**, and then plays any number of **cards** in their hand. Each **card** has effect such as shooting another player, healing, stealing cards, etc. Another player can only be shot if the **distance** to them is less than or equal to the **range** of your gun. **Distance** is the number of players seats away from you (excluding dead players). The default **range** is 1, and can be increase by gun cards.

In this model, the role assignment, health/death, and distance is accurately represented, but the main gameplay - cards, card distribution, gun range, role discovery - is simplified ("modeled").


The simplified card groupings are as follows:

- *Bang!* - a target in **range** loses 1 **health**.
- *Gatling* - *all* other players lose 1 **health**.
- *Beer* - regain 1 **health** up to **starting health**.
- *Saloon* - *all* players regain 1 **health** up to their **starting health**.
- *Missed!* - a shot from a *Bang!* misses and no **health** is lost.
- *Jail* - at the beginning of your turn, draw a **card**, if not a *heart**, lose a turn.
- *Stagecoach* - draw 2 or 3 **cards**.
- *General Store* - every player gains a **card**.
- *Panic!* - draw a **card** from another player in **range**.
- *Cat Balou* - force another player in **range** to discard a **card**.
- *Brawl* - *all* other players are forced to discard a **card**.
- *Barrel* - when shot from a *Bang!*, draw a **card**, if a *heart*, the shot *misses*.
- *Dynamite* - at the beginning of your turn, draw a **card**, if a *spade 2-9**, lose 3 **health**.
- *Mustang* - other players view you at a **distance** +1.
- *Scope* - view other players at a **distance** -1.
- *~Various Guns~* - increase **range**.

.......
* All cards have a suit and a number.

## HOW IT WORKS

Each player takes a turn one at a time in a circle until there is a winner. If the game ends, another one is setup and begun. Each **card** has a random chance of being played that is proportional to the number of that type of **card** in the entire deck. Each player has a number of **health** points, that decrease if shot and increase if healed. The player is killed if the **health** drops to 0. Whenever a target is needed, the gun **range** is randomly determined based on the actual distribution of guns. The number of **cards** being draw or discarded is repesent by some abstract value that increases or decreases the chance of a **card** being played.

Players determine who to target by some abstract *opinion* of other players. Most all have a neutral *opinion* on other players, meaning they are neither allies nor enemies, because **roles** are hidden, except the **deputies** will know to ally with the **sheriff** and the **outlaws** will know to find the **sheriff** as an enemy. When the **outlaws** attack the **sheriff**, the **sheriff** and **deputies** will know who the **outlaws** are that they need to kill. The **sheriff** will figure out who the **deputies** because they attack the **outlaws**. The behavior with the **sheriff** is clear because it is the unhidden role, but otherwise, in general, players find a *shot* person favorable if the *shooter* is unfavorable, and find a *shot* person unfavorable if the *shooter* is favorable. **renegades** fit somewhere in between. The teams emerge through this behavior.

## HOW TO USE IT

### Parameters
- `PLAYER-COUNT` - number of players in the game.
- `%-ROLE-OUTLAW` - percentage of non-sheriff players that are **outlaws**.
- `%-ROLE-DEPUTY` - percentage of non-sheriff players that are **deputies**.
- `%-ROLE-RENEGADE` - percentage of non-sheriff players that are **renegades**. This slider can not be controlled by the observer, as it just adjusts to the remaining percentage so that the total percentage is 100.
- `MODEL-SPEED` - lower numbers introduce a delay between ticks, to slow down play but not effects.
- `PRINT-EVENTS?` - if *on*, print all game events to the *Command Center*.

All parameters can be changed at any time. The first four sliders will apply when the next game starts. The last two inputs apply instantaneously.

### Buttons
- `SETUP` - randomly set up the game world and players with the appropriate `PLAYER-COUNT` and `%-ROLE-*`.
- `SINGLE` - simulates a single game, and stops when that game is complete.
- `GO` - simulates multiple games, will setup and play a new game after each is complete.
- `GO ONCE` - advance a single tick for each press.
- `PRESET X` - will adjust sliders and `SETUP` with the role distribution of *X* players according to the actual rules. 

### Monitors and Plots

- `# ROLE` - displays the number of *alive* players with *ROLE*.
- `ROLE WINS` - displays the number of wins for a *ROLE* in this GO session.
- `TURN` - displays whose turn it is, staring at 0, who is the top-most player.
- `ROUND` - displays the round, starting at 0, that is how many times play has gone around the circle and back to the sheriff.
- `ROUNDS` - plots `ROUND`.
- `AVERAGE HEALTH` - plots the average health for each role.

### The World

The **sheriff** is green, **deputies** are blue, **outlaws** are red, and **renegades** are yellow. The lines between each player represent how they view each other. A *greener* line means the two players are closer to being allies and will not attack each other. A *redder* line means the two players are closer to being enemies and will try to attack each other. A *brownish* in-between color line is players unsure of other roles (as they are initially hidden except the **sheriff**). (for example: the **sheriff** and a **deputy** will generally have a green line, and the **sheriff** and an **outlaw** will generally have a red line.)

A *x/y* near the player is their current health out of their maximum health.

For visual effects, the reddened ground is blood from players being shot or dying, and the pink lines are the *Bang!* shots.

## THINGS TO NOTICE

At setup, most lines between players are *brownish*, but some are *greener*.

With the presets, the ratio of roles that are *actually used while playing the game*, certain roles have an advantage, and the number of wins is unbalanced.

At higher numbers of players, multiple gatlings with no chance to heal causes many mass-deaths.

## THINGS TO TRY

Can you create some combination of sliders, where all the different roles *are* balanced?

What happens to the fairness of roles as the number of players increases?

Is there a point where a certain role has a high enough percentage of members so that no one else can win? Where is this tipping point?

## EXTENDING THE MODEL

There are no characters in the model. These can add more variety to the game, and better represent the game. 

Expansions can be included, such as *High Noon* and *Fistful of Cards* which applies a different unique card to each round that causes some event to happen or changes the basic rules for just that round.

## NETLOGO FEATURES

The built-in turtle property `who` can conveniently be used for indices in a list, where each element is related to a turtle.

A `to-report` can report a constant value, and then be used as a constant global without crowding `globals`.

Also, immutable lists are awful. Also no `for` loops is unfortunate.

## CREDITS AND REFERENCES

*Bang!* game created by Emiliano Sciarra in 2002.

*for the idea of using `create-ordered-turtles`:*
Wilensky, U. (1997).  NetLogo Turtles Circling model.  http://ccl.northwestern.edu/netlogo/models/TurtlesCircling.  Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

*for the idea of using presets:*
Stonedahl, F., Wilensky, U., Rand, W. (2014).  NetLogo Heroes and Cowards model.  http://ccl.northwestern.edu/netlogo/models/HeroesandCowards.  Center for Connected Learning and Computer-Based Modeling, Northwestern Institute on Complex Systems, Northwestern University, Evanston, IL.
