;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;; GLOBALS ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

globals [
  turn   ; active player: 0, 1, 2, ... , player-count - 1
  rounds ; number of times each player has had a turn

  wincount-sheriff-deputies ; number of sheriff/deputy wins for this "go" session
  wincount-outlaws          ; number of outlaw wins for this "go" session
  wincount-a-renegade       ; number of renegade wins for this "go" session

  in-between-game? ; used to ensure game starts at an even tick (else player positioning gets messed up)
]

breed [ sheriff   a-sheriff ]
breed [ deputies  deputy    ]
breed [ outlaws   outlaw    ]
breed [ renegades renegade  ]

undirected-link-breed [ alignments alignment ] ; connections between players showing allies/enemies
directed-link-breed   [ bullets    bullet ]    ; visual effect of BANG! card

turtles-own [
  name        ; description of player
  health      ; number of health points, 0 == dead
  max-health  ; healing limit
  alive?      ; if alive and still playing
  card-weight ; abstract representation of more-than- or less-than-average-number-of-cards
  opinion     ; list representing this player's confidence on other players' roles
              ; index is [who] of player, value is percentage, 0 == 100% not an enemy, 100 == 100% an enemy
]

patches-own [
  rr      ; current color red component
  gg      ; current color green component
  bb      ; current color blue component
  rr-base ; starting color red component
  gg-base ; starting color green component
  bb-base ; starting color blue component
]

bullets-own [
  alpha ; rgbA, opacity
]

;;;;; ROLE "ENUM" ;;;;;
; mostly used for setup, because breeds are used

to-report role-sheriff
  report 0
end
to-report role-deputy
  report 1
end
to-report role-outlaw
  report 2
end
to-report role-renegade
  report 3
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;; SETUP ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup
  clear-all
  setup-patches
  setup-game
  set wincount-sheriff-deputies 0
  set wincount-outlaws 0
  set wincount-a-renegade 0
  set in-between-game? false
  reset-ticks
end

to setup-game
  clear-turtles
  setup-check-role-ratios
  setup-players
  setup-player-links
  ask patches [ reset-ground ]
  set turn [ who ] of the-sheriff
  set rounds 0
end

to setup-patches
  ask patches [
    ; this rgb combination is brown-ish
    set rr (77 + random(20) - 10)
    set gg (51 + random(10) - 10)
    set bb (0 + random(10))
    set rr-base rr
    set gg-base gg
    set bb-base bb
    recolor-ground
  ]
end

to setup-players
  let role-list []
  set role-list (add-n-copies-to-list role-list number-sheriff  role-sheriff)
  set role-list (add-n-copies-to-list role-list number-deputy   role-deputy)
  set role-list (add-n-copies-to-list role-list number-outlaw   role-outlaw)
  set role-list (add-n-copies-to-list role-list number-renegade role-renegade)
  set role-list shuffle(role-list)

  let name-counter-deputy 0
  let name-counter-outlaw 0
  let name-counter-renegade 0

  create-ordered-turtles player-count [
    forward (max-pxcor * 0.8)
    set size 3

    let role (item who role-list)
    if (role = role-sheriff)  [
      set color green
      set breed sheriff
      set name "the sheriff"
    ]
    if (role = role-deputy)   [
      set color blue
      set breed deputies
      set name (word "deputy " name-counter-deputy)
      set name-counter-deputy (name-counter-deputy + 1)
    ]
    if (role = role-outlaw)   [
      set color red
      set breed outlaws
      set name (word "outlaw " name-counter-outlaw)
      set name-counter-outlaw (name-counter-outlaw + 1)
    ]
    if (role = role-renegade) [
      set color (yellow - 2) ; slightly darker so label is readable
      set breed renegades
      set name (word "renegade " name-counter-renegade)
      set name-counter-renegade (name-counter-renegade + 1)
    ]

    set health starting-health ; random
    if (role = role-sheriff) [
      set health (health + 1)
    ]
    set max-health health
    set alive? true
    set card-weight 1
  ]
  ask turtles [
    set shape "person"
    set label breed

    let i 0
    set opinion []
    while [ i < count turtles ] [
      set opinion (lput 50 opinion) ; 50% == hesitant with everyone as roles are hidden
      set i (i + 1)
    ]
    ; since sheriff is revealed, determine relationship to sheriff
    if (breed = deputies) [
      ; deputies have 0% chance of sheriff being an enemy
      adjust-opinion ([who] of the-sheriff) -50 ; 0%
    ]
    if (breed = renegades) [
      ; renegade "acts" like a deputy at the start, but is still wants to kill the sheriff
      adjust-opinion ([who] of the-sheriff) -40 ; 10%
    ]
    ; outlaws will start at 50% enemy to sheriff and then increase to 100% as turns go by
    ; this represents the outlaws kind of "waiting" for the opportunity to strike
  ]
end

to setup-player-links
  ask turtles [
    create-alignments-with other turtles
  ]
  ask alignments [
    set thickness 0.2
  ]
  ask turtles [
    recolor-alignments
  ]
end

; make sure roles sum up to 100%
to setup-check-role-ratios
  set %-role-deputy   min list %-role-deputy   (100 - %-role-outlaw)
  set %-role-renegade min list %-role-renegade (100 - (%-role-outlaw + %-role-deputy))
  set %-role-renegade max list %-role-renegade (100 - (%-role-outlaw + %-role-deputy))
end

;;;;; SETUP FUNCTIONS ;;;;;

to-report number-sheriff
  report 1
end

to-report number-outlaw
  report round((player-count - number-sheriff) * (%-role-outlaw / 100))
end

to-report number-deputy
  report round((player-count - number-sheriff) * (%-role-deputy / 100))
end

to-report number-renegade
  report player-count - (number-sheriff + number-outlaw + number-deputy)
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;; GAME LOOPS ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to single
  if (is-game-done?) [ stop ]
  play-game
end

to go
  if (is-game-done?) [ set in-between-game? true ]
  play-game
end

to play-game
  ifelse (in-between-game?) [
    in-between-game
  ] [
    ifelse (ticks mod 2 = 0) [
      do-take-turn
    ] [
      do-switch-turn
    ]
    manage-effects
  ]
  tick
end

; make sure ticks line up, else players get stuck in the center
to in-between-game
  if (ticks mod 2 = 1) [
    set in-between-game? false
    setup-game
  ]
end

to do-take-turn
  ask active-player [
    position-player
    take-turn
  ]
end

to do-switch-turn
  ask active-player [ position-player ]
  increment-turn
  while [ not [ alive? ] of active-player ][
    increment-turn
  ]
end

to manage-effects
  ask patches [
    soak-up-blood
    recolor-ground
  ]
  ask bullets [
    fadeout-bullets
  ]
  ask turtles [
    set label (word health "/" max-health)
    if (alive?) [
      recolor-alignments
    ]
  ]
  if (model-speed < 100) [ wait 1 / model-speed ]
end

to increment-turn
  set turn ((turn + 1) mod (count turtles))
  if (turn = [ who ] of one-of sheriff) [
    set rounds (rounds + 1)
  ]
end

to position-player ; turtle procedure
  right 180
  forward (max-pxcor * 0.4)
end

;;;;; EFFECTS ;;;;;

to fadeout-bullets
  set alpha max (list 0 (alpha - effect-bullet-fadeout-speed))
  set color (list 255 179 179 alpha) ; rgb == pinkish
  if (alpha < 1) [ die ]
end

to recolor-alignments
  ask my-alignments [
    ; since this will be calculated twice (once for each turtle for each link), should be and is communitive
    let diff ( (item ([who] of other-end) ([opinion] of myself)) + (item ([who] of myself) ([opinion] of other-end)) ) / 2
    set diff (diff / 100) ; scale to 0-1
    set diff (diff * 255) ; scale to rgb range
    set diff min(list max(list diff 0) 255)
    set color (list diff (255 - diff) 0) ; red if enemies, green if allies
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;; PLAYER TURN PROCEDURES ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to take-turn
  ; adjust opinions of others
  if (phase-2? and breed = renegades) [
    ; become enemies with everyone
    let i 0
    while [ i < count turtles ] [
      set opinion (replace-item i opinion 100)
      set i (i + 1)
    ]
  ]
  if (breed = outlaws) [
    ; become more willing to attack the sheriff
    adjust-opinion ([who] of the-sheriff) 20
  ]

  ; dynamite is triggered from a spade 2-9, half of spades are in the range 2-9
  if (got-card? chance-card-dynamite and random 4 = 0 and random 2 = 0) [
    say (word "dynamite")
    hurt
    hurt
    hurt
    spray-blood effect-blood-amount-dynamite
  ]
  ; must pick a non-heart for jail
  ifelse (got-card? chance-card-jail and random 4 > 0) [
    say (word "in jail") ; lose turn
  ] [
    ; normal turn
    test-event-bang
    test-event-beer
    test-event-stagecoach
    test-event-generalstore
    test-event-panic
    test-event-catbalou
  ]
end

to test-event-bang
  ; shoot(target, shooter, attack-all?)
  if (got-card? chance-card-bang) [
    shoot get-target self false
  ]
  if (got-card? chance-card-gatling) [
    ask other alive-players [
      shoot self myself true
    ]
  ]
end

to test-event-beer
  if (got-card? chance-card-beer) [
    heal
  ]
  if (got-card? chance-card-saloon) [
    ask alive-players [
      heal
    ]
  ]
end

to test-event-stagecoach
  if (got-card? chance-card-stagecoach) [
    let num-cards stagecoach-gain-amount ; random
    say (word "gain " num-cards " cards")
    change-card-amount num-cards
  ]
end

to test-event-generalstore
  if (got-card? chance-card-generalstore) [
    say (word "general store")
    ask alive-players [
      change-card-amount 1
    ]
  ]
end

to test-event-panic
  if (got-card? chance-card-panic) [
    let target get-target
    if (target != nobody) [
      say (word "steal card from " ([name] of target))
      ask target [
        change-card-amount -1
      ]
      change-card-amount 1
      ; adjust-opinions-on-event(attacker, target, bang?, attack-all?)
      adjust-opinions-on-event self target false false
    ]
  ]
end

to test-event-catbalou
  ; force-discard(target, attacker, attack-all?)
  if (got-card? chance-card-catbalou) [
    force-discard get-target self false
  ]
  if (got-card? chance-card-brawl) [
    ask other alive-players [
      force-discard self myself true
    ]
  ]
end

;;;;; EVENTS ;;;;;

to shoot [ target shooter spread? ]
  if (target != nobody and shooter != nobody) [
    ask shooter [
      say (word "shoot " ([name] of target))
      ask target [
        ; test missing bullet
        ; also drawing a heart with a barrel is a miss
        ifelse (got-card? chance-card-miss or (got-card? chance-card-barrel and random 4 = 0)) [
          say (word "dodge bullet from " ([name] of myself))
        ] [
          create-bullet myself self
          hurt
        ]
      ]
    ]
    adjust-opinions-on-event shooter target true spread?
  ]
end

to heal
  if (health < max-health) [
    say "heal"
    set health (health + 1)
  ]
end

to hurt
  set health (health - 1)
  ifelse (health <= 0) [
    be-killed
  ] [
    spray-blood effect-blood-amount-shot
  ]
end

to force-discard [ target attacker spread? ]
  if (target != nobody and attacker != nobody) [
    ask attacker [
      say (word "force discard on " ([name] of target))
    ]
    ask target [
      change-card-amount -1
    ]
    adjust-opinions-on-event attacker target false spread?
  ]
end

to change-card-amount [ multiple ]
  set card-weight (card-weight + (card-weight-unit * multiple))
end

to be-killed
  set alive? false
  set color black
  ask my-alignments [
    set hidden? true
  ]
  spray-blood effect-blood-amount-dead
end

;;;;; HELPER FUNCTIONS ;;;;;

to-report got-card? [ chance ]
  report random card-count < chance * card-weight
end

to-report get-gun-range
  let r gun-range ; random based on guns
  ; modifiers are duplicated since they stay out
  if (got-card? (chance-card-mustang * 2)) [
    set r (r - 1) ; target is viewed at farther distance
  ]
  if (got-card? (chance-card-scope * 2)) [
    set r (r + 1) ; see target at closer distance
  ]
  report r
end

; smallest number of alive player of seats away a player is
to-report view-distance [ other-player ]
  let inc -1
  let diff-list []
  while [ inc <= 1 ] [ ; loop for each direction
    let current who
    let target ([ who ] of other-player )
    let diff 0
    while [ current != target ] [
      set current ((current + inc) mod (count turtles))
      if ([ alive? ] of turtle current) [
        set diff (diff + 1)
      ]
    ]
    set diff-list lput diff diff-list
    set inc (inc + 2)
  ]
  report min diff-list
end

; considers a target list, and range, and picks the one best target
to-report target-in-range [ targets max-range ]
  set targets filter [ t -> alive? ] targets
  set targets filter [ t -> (view-distance t) <= max-range ] targets
  ifelse (breed = outlaws) [
    ; attack more hated enemies (preferrably sheriff) first
    set targets sort-by [ [x y] -> item ([ who ] of x) opinion > item ([ who ] of y) opinion ] targets
  ] [
    ; attack weaker targets first
    set targets sort-by [ [x y] -> [ health ] of x < [ health ] of y ] targets
  ]
  ifelse (length targets > 0) [
    report first targets
  ] [
    report nobody
  ]
end

; pick a target from a list that likely enemies are more likely to be in
to-report get-target
  let target-set []
  let i 0
  while [ i < count turtles ] [
    if (i != who and ([ alive? ] of turtle i)) [
      if (random 100 < item i opinion) [
        set target-set (lput (turtle i) target-set)
      ]
    ]
    set i (i + 1)
  ]
  report target-in-range target-set get-gun-range
end

to adjust-opinion [ index change ]
  set opinion (replace-item index opinion (change + item index opinion))
end

to adjust-opinion-percent [ index percent ]
  set opinion (replace-item index opinion ((1 + (percent / 100)) * item index opinion))
end

to adjust-opinions-on-event [ attacker target bang? spread? ]
  let scale 1
  ; discard/draw from is less severe than shooting
  ; or if the attack attacks everyone, less personal and thus less severe
  if (not bang? or spread?) [ set scale 0.1 ]
  let attacker-index ([who] of attacker)
  let target-index  ([who] of target)
  ifelse ([breed] of target = sheriff) [
    ask outlaws [
      ; ally with the outlaw who shot the sheriff
      adjust-opinion attacker-index (-150 * scale)
    ]
    ask (turtle-set sheriff deputies) [
      ; know the shooter is an outlaw
      adjust-opinion attacker-index (150 * scale)
    ]
    ask renegades [
      ; cautiously know the shooter is an outlaw
      if (not phase-2?) [
        adjust-opinion attacker-index (50 * scale)
      ]
    ]
  ] [
    ; if you like the target then you hate the shooter,
    ; and if you hate the target then you like the shooter,
    ; but the amount of like/hate towards the shooter is proportional
    ; to the like/hate towards the target.
    let attacker-preference ((item attacker-index opinion) - 50)
    adjust-opinion-percent target-index ((0 - attacker-preference) * scale)
  ]
end

;;;;; EFFECTS ;;;;;

to spray-blood [ amount ]
  ask patches in-radius effect-blood-dist [
    spread-blood-around myself amount
  ]
end

to create-bullet [ shooter target ]
  ask shooter [
    create-bullet-to target [
      set color (red + 1)
      set thickness 0.5
      set alpha 255
    ]
  ]
end

; print event message to console
to say [ str ]
  if (print-events?) [
    print (word name ": " str)
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;; FUNCTIONS ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;; OBSERVER ;;;;;

to-report active-player
  report first ( [ self ] of turtles with [ who = turn ] )
end

to-report alive-players
  report turtles with [ alive? ]
end

to-report the-sheriff
  ; `one-of` to have agent instead of agentset, and there will always be one sheriff
  report one-of sheriff with [ alive? ]
end

; phase 2 == outlaws are dead and renegades try to kill everyone
to-report phase-2?
  report count outlaws with [ alive? ] = 0
end

to-report winner ; updates globals
  let alive-sheriff?  (any? sheriff   with [ alive? ])
  let alive-outlaw?   (any? outlaws   with [ alive? ])
  let alive-renegade? (any? renegades with [ alive? ])
  if (alive-outlaw? and not alive-sheriff?) [
    set wincount-outlaws (wincount-outlaws + 1)
    if (print-events?) [ print "-- OUTLAWS WIN --" ]
    report role-outlaw
  ]
  if (alive-sheriff? and (not alive-renegade?) and (not alive-outlaw?)) [
    set wincount-sheriff-deputies (wincount-sheriff-deputies + 1)
    if (print-events?) [ print "-- SHERIFF WIN --" ]
    report role-sheriff
  ]
  if ((count alive-players) = 1 and (count renegades with [ alive? ]) = 1) [
    set wincount-a-renegade (wincount-a-renegade + 1)
    if (print-events?) [ print "-- RENEGADE WIN --" ]
    report role-renegade
  ]
  if ((any? deputies with [ alive? ]) and (not alive-renegade?) and (not alive-outlaw?)) [
    set wincount-sheriff-deputies (wincount-sheriff-deputies + 1)
    if (print-events?) [ print "-- SHERIFF WIN --" ]
    report role-sheriff
  ]
  report -1
end

to-report is-game-done?
  report winner != -1 or (count alive-players) = 0
end

;;;;; GAME PROBABILITIES ;;;;;

to-report card-count
  report 120
end

; how much to adjust card-weight
to-report card-weight-unit
  report 10 / card-count
end

to-report starting-health
  ; 8 characters with 3 health, 34 total
  ; 8 / 34 = 23.529%
  ifelse (random 1000 < 235) [ report 3 ] [ report 4 ]
end

to-report stagecoach-gain-amount
  ; 2 stagecoach (2), 1 wells fargo (3), 1 pony express (3)
  report one-of [2 2 3 3]
end

to-report gun-range
  ; 2 for default no gun (1), 2 for volcanic (1), 3 for schofield (2), 2 for remington (3), 2 for rev. carbine (4), 1 for winchester (5)
  report one-of [1 1 1 1 2 2 2 3 3 4 4 5]
end

to-report chance-card-bang
  ; 29 bang + 3 duel + punch, springfield, buffalo rifle, derringer, knife, pepperbox
  report 29 + 3 + 6
end

to-report chance-card-gatling
  ; 3 indians + gatling, howitzer
  report 3 + 2
end

to-report chance-card-beer
  ; 8 beer + tequila, whisky, canteen
  report 8 + 3
end

to-report chance-card-saloon
  ; saloon
  report 1
end

to-report chance-card-miss
  ; 13 missed + 2 dodge + 2 iron plate + bible, sombrero, ten gallon hat
  report 13 + 2 + 2 + 3
end

to-report chance-card-jail
  ; 3 jail
  report 3
end

to-report chance-card-stagecoach
  ; 2 stagecoach + wells fargo, pony express
  report 2 + 2
end

to-report chance-card-generalstore
  ; 3 general store
  report 3
end

to-report chance-card-panic
  ; 5 panic + rag time, contestoga
  report 5 + 2
end

to-report chance-card-catbalou
  ; 5 cat balou + 1 can can
  report 5 + 1
end

to-report chance-card-brawl
  ; brawl
  report 1
end

to-report chance-card-barrel
  ; 3 barrel
  report 3
end

to-report chance-card-dynamite
  ; 2 dynamite
  ; but reduced slightly because people are hesitant to use dynamite
  report one-of [ 1 2 ]
end

to-report chance-card-mustang
  ; 3 mustang, 1 hideout
  report 4
end

to-report chance-card-scope
  ; scope, binocular
  report 2
end

;;;;; UTILITY FUNCTIONS ;;;;;

to-report add-n-copies-to-list [ list-to-add-to number-to-add value-to-add ]
  let i 0
  while [i < number-to-add][
    set list-to-add-to (lput value-to-add list-to-add-to)
    set i (i + 1)
  ]
  report list-to-add-to
end

to-report sign [ n ]
  if (n > 0) [ report 1 ]
  if (n < 0) [ report -1 ]
  report 0
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;; PATCH PROCEDURES ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to reset-ground
  set rr rr-base
  set gg gg-base
  set bb bb-base
  recolor-ground
end

to recolor-ground
  set rr max(list 0 min(list 255 rr))
  set gg max(list 0 min(list 255 gg))
  set bb max(list 0 min(list 255 bb))
  set pcolor (list rr gg bb)
end

to spread-blood-around [ player amount ]
  set rr ( rr + min list 255 (amount * (effect-blood-dist - distance player)) )
  set gg ( gg - max list 0   (amount * (effect-blood-dist - distance player)) )
  set bb ( bb - max list 0   (amount * (effect-blood-dist - distance player)) )
end

to soak-up-blood
  set rr ( rr + (sign(rr-base - rr) * 2) )
  set gg ( gg + (sign(gg-base - gg) * 2) )
  set bb ( bb + (sign(bb-base - bb) * 2) )
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;; PRESETS ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup-4-players ; 1 sheriff, 1 renegade, 2 outlaws
  set player-count 4
  set %-role-outlaw 67
  set %-role-renegade 33
  set %-role-deputy 0
  setup
end

to setup-5-players ; 1 sheriff, 1 renegade, 2 outlaws, 1 deputy
  set player-count 5
  set %-role-outlaw 50
  set %-role-renegade 25
  set %-role-deputy 25
  setup
end

to setup-6-players ; 1 sheriff, 1 renegade, 3 outlaws, 1 deputy
  set player-count 6
  set %-role-outlaw 60
  set %-role-renegade 20
  set %-role-deputy 20
  setup
end

to setup-7-players ; 1 sheriff, 1 renegade, 3 outlaws, 2 deputy
  set player-count 7
  set %-role-outlaw 50
  set %-role-renegade 17
  set %-role-deputy 33
  setup
end

to setup-8-players ; 1 sheriff, 2 renegade, 3 outlaws, 2 deputy
  set player-count 8
  set %-role-outlaw 43
  set %-role-renegade 29
  set %-role-deputy 29
  setup
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;; EFFECT VARIABLES ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; radius around turtles for blood spread on patches
to-report effect-blood-dist
  report 5
end

; bullet alpha change
to-report effect-bullet-fadeout-speed
  report 25
end

to-report effect-blood-amount-dynamite
  report 100
end

to-report effect-blood-amount-shot
  report 10
end

to-report effect-blood-amount-dead
  report 35
end
@#$#@#$#@
GRAPHICS-WINDOW
570
10
1007
448
-1
-1
13.0
1
10
1
1
1
0
0
0
1
-16
16
-16
16
1
1
1
ticks
30.0

SLIDER
20
20
550
53
player-count
player-count
4
100
5.0
1
1
players
HORIZONTAL

BUTTON
20
225
85
265
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
170
225
235
265
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
325
70
410
115
# sheriff
count sheriff with [ alive? ]
17
1
11

MONITOR
325
130
410
175
# deputy
count deputies with [ alive? ]
17
1
11

MONITOR
325
190
410
235
# outlaw
count outlaws with [ alive? ]
17
1
11

MONITOR
325
250
410
295
# renegade
count renegades with [ alive? ]
17
1
11

SLIDER
20
70
265
103
%-role-outlaw
%-role-outlaw
0
100
50.0
1
1
%
HORIZONTAL

SLIDER
20
170
265
203
%-role-renegade
%-role-renegade
0
100
25.0
1
1
%
HORIZONTAL

SLIDER
20
120
265
153
%-role-deputy
%-role-deputy
0
100
25.0
1
1
%
HORIZONTAL

BUTTON
20
290
75
323
4
setup-4-players
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
80
290
135
323
5
setup-5-players
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
140
290
195
323
6
setup-6-players
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
200
290
255
323
7
setup-7-players
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
260
290
315
323
8
setup-8-players
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
20
340
355
490
average health
time
health
0.0
10.0
0.0
5.0
false
true
"" "set-plot-x-range max(list 0 (ticks - 500)) (ticks + 1)"
PENS
"sheriff" 1.0 0 -10899396 true "" "plot mean [ health ] of sheriff"
"deputy" 1.0 0 -13345367 true "" "plot mean [ health ] of deputies"
"outlaw" 1.0 0 -2674135 true "" "plot mean [ health ] of outlaws"
"renegade" 1.0 0 -4079321 true "" "plot mean [ health ] of renegades"

TEXTBOX
25
275
175
293
presets:
11
0.0
1

MONITOR
770
455
827
500
NIL
turn
17
1
11

PLOT
355
340
565
490
rounds
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" "set-plot-x-range max(list 0 (ticks - 500)) (ticks + 1)"
PENS
"default" 1.0 0 -16777216 true "" "plot rounds"

BUTTON
95
225
160
265
NIL
single
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
570
460
755
493
model-speed
model-speed
1
100
30.0
1
1
NIL
HORIZONTAL

MONITOR
845
455
902
500
round
rounds
17
1
11

MONITOR
425
130
540
175
sheriff/deputy wins
wincount-sheriff-deputies
17
1
11

MONITOR
425
190
540
235
outlaw wins
wincount-outlaws
17
1
11

MONITOR
425
250
540
295
renegade wins
wincount-a-renegade
17
1
11

SWITCH
910
455
1037
488
print-events?
print-events?
0
1
-1000

BUTTON
245
225
317
265
go once
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

@#$#@#$#@
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
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.0.3
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
1
@#$#@#$#@
