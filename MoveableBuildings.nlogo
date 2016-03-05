extensions [csv  bitmap]
__includes ["worldview.nls" "building-code.nls" "navigation.nls" "workers.nls" ]


globals [
  clr-path
  clr-mud
  clr-road
  clr-danger
  clr-moveable-facility
  clr-fixed-facility
  clr-fixed-facility2
  clr-void
  building-list
  mouse-was-down?
  breadcrumb-trails
]


to setup ; linked with setup button on interface
  clear-all
  set-default-shape turtles "person"
  set breadcrumb-trails []
  set building-list []
  setup-patches "moveablebuildings.bmp" "colours.csv"
  create-buildinglist
  make-buildings-from-list
  create-breadcrumbs-from_buildinglist

  ;; diagnostic - show the breadcrumb trails for a moment.
  ;; note that these trails are invisible to the workers, and do not affect worker movement.
  foreach breadcrumb-trails [
    draw-breadcrumb-trail ?
  ]

  setup-workers

  reset-ticks
end





to go  ;; forever button

  if group-14-slow-in-mud
  [
    ask workers with [home-building = 14]
     [
       check-goal         ;; when we reach our goal, set a new goal
       move-worker self
     ]
  ]

  if group-18-tired-in-mud
  [
    ask workers with [home-building = 18]
     [
       check-goal         ;; when we reach our goal, set a new goal
       move-worker self
     ]
  ]

  if group-15-faces-danger
  [

    ask workers with [home-building = 15]
     [
       check-goal         ;; when we reach our goal, set a new goal
       move-worker self
     ]
  ]


  tick

  if ticks > total-ticks
  [ write-results
    stop
  ]

end

to write-results
  ;; start with column headers
  let myheaders ["building number" "x" "y" "width" "height" "number of avoiders" "number of bold workers" "average trips for avoiders" "average trips for bold" "average time per trip avoiders" "average time per trip bold" "average ticks mudders get tired"]
  let myout (list myheaders)


  foreach building-list [
    let buildnum  item 0 ?
    if buildnum != "facility" [
      let mystats building-stats  buildnum
      set myout lput mystats myout
    ]
  ]
  csv:to-file "results.csv" myout

  ask workers [ die ]  ;; we don't want them to show in the bitmap
  bitmap:export bitmap:from-view "results-bitmap.bmp"

end





;; used if a building moves after "go" is pressed.
to redirect-workers
         ;; some workers were heading to this building, redirect them to the new destination
         ask workers with [destination-building = building-to-move and searching? = true][
           set-new-destination destination-building searching? 0
         ]
         ask workers with [home-building = building-to-move and searching? = false][
           set-new-destination home-building searching? 0
         ]
end

to-report possible-path-list [little-dude theradius show-test-msgs]
  let path-list []

  ;; if we are already hugging an edge, keep doing that.
  if hugging-edges-steps > 0 [
    report path-list
  ]

  let currentheading [heading] of little-dude
  no-display

  ;; site the goal, adjust direction toward it.
  set heading towards-nowrap goal
  ;;face min-one-of patches with [ building-number = [destination-building] of myself ] [ distance myself ]

  ;; testing
  ;;ifelse pxcor > 64 and pxcor < 80 [ pen-down display set color red][ pen-up ]

  let steps-to-check random (25) + 150            ;; a little variety in how far ahead we look
  let totalangle  0
  let goingright  [go-right?] of little-dude


;; changing this angle will keep most dudes from hopping back and forth in a small space
;; 200 degrees failed on 27th attempt  going from building 14 to 1
;; 210 degrees failed on 49 going from building 14 to 1
;; 210 is really bad for going from 15 to 14
  while [totalangle < 190]
  [

      let path-info []
;;      if show-test-msgs [
;;        show heading
;;        hatch 1 [
  ;;        set size 0.01
;;          pen-down fd 15
;;          wait 1
;;          pen-erase bk 15
;;          die
;;        ]
;;      ]
      ifelse heading = towards-nowrap goal
      [ set path-info test-path 1000 theradius]
      [ set path-info test-path steps-to-check theradius]

      if length path-info > 1 [
        ;; is this direct to destination?
        if item 2 path-info = true [
          set hugging-edges-steps 0
          set blue-sky-steps item 0 path-info + 3
          set path-list []  ;; throw out any other paths
          set path-list lput (list heading item 0 path-info) path-list
          set totalangle 350 ;; breaks the loop
        ]

        ;; path ahead is clear, this is the only path we need to consider
        if item 1 path-info = true [
          set path-list []  ;; throw out any other paths
          set path-list lput (list heading item 0 path-info) path-list
          set totalangle 350 ;; breaks the loop
        ]


        set path-list lput (list heading item 0 path-info) path-list
      ]

      ;; next angle
      let newangle random (5) + 3               ;; turn between 3 and 8 degrees
      set totalangle (totalangle + newangle)  ;; increase the angle a little
      ifelse (goingright = true) [
        right newangle
      ][
        left newangle
      ]
  ]


  display
  set heading currentheading
  report path-list
end


;;  test-path
;;  test for length of clear path, and if destination is on this path
;;
;;  returns list of [path-length all-clear dest-ahead]
;;  path-length will be the length of clear path, up to a max of the input max-steps
;;  all clear means the path never found an obsticle.
;;  dest-ahead means we are pointed the right way, path-length will show distance to destination.
to-report test-path [max-steps theradius]

  let step-counter 0

    ;; testing
  ;;if pxcor > 72 and pxcor < 76 and max-steps = 1000 [  show "turned towards it" ]

  while [step-counter < max-steps] [
    set step-counter step-counter + 1

    ;; is the destination ahead?
    if [building-number] of  patch-ahead step-counter  = destination-building
    [
      ;;if pxcor > 72 and pxcor < 76 and max-steps = 1000 [  show (word "looking right at it " pxcor pycor) ]
      report (list step-counter true true)
    ]

    ;; what is the colour of the next patch in the path we are checking?
    let nextpatch [pcolor] of patch-ahead step-counter

    ;; see if we hit the end of the open path
    if (not is-allowed-patch patch-ahead step-counter theradius )
    [
      if step-counter = 1 [
        report (list 0 false false)
      ]  ;  totally dead end, don't return this path at all
      report (list step-counter false false)
    ]
  ]

  ;; we checked far enough, didn't encounter obsticles or destination
  report (list step-counter true false)
end

;; when checking if the next patch is a permitted colour, this function lets you check the buffer as well
;;
;; returns:  true/false
;;
to-report is-allowed-patch [thepatch theradius]
  let permitted true
  let debug-mode false
  let allowedpatchclrs allowed-patches
 ;; if who = 3815 or who = 3647
  set debug-mode false

  ifelse theradius <= 1 [
    if (not member? [pcolor] of thepatch  allowedpatchclrs) [ set permitted false ]
;;    if debug-mode = true [ show ( word "color: " pcolor " allowed: "  allowedpatchclrs " permitted?: " permitted " should be: " member? pcolor  allowedpatchclrs)  ]
  ][
    ask thepatch [
       ask patches in-radius theradius [

         if not member? pcolor allowedpatchclrs [ set permitted false ]
       ]
    ]
  ]
  report permitted
end

to face-longest-path [little-dude path-list]

    ;; we are already hugging an edge, keep doing that.
    if hugging-edges-steps > 0 [
      stop
    ]

    ;; check for no open path, and start hugging edges
    if length path-list = 0 [
       set hugging-edges-steps 10;
       set color red;
       stop
    ]

    ;;no-display

    ;; look for the longest path, grab that angle
    let myheading  heading
    let step-count  0
    foreach path-list [
      if  item 1 ? > step-count [
         set myheading  item 0 ?
         set step-count  item 1 ?
         if item 1 ? > 23 [
           set blue-sky-steps 20

         ]
      ]
    ]

    ;;display

    ;; turn to the longest path
    set heading myheading

    if blue-sky-steps > 0 and avoid-mud? = 1 and 1 = 0 [
    hatch 1 [
    ;;  set size 0.01
      pen-down fd blue-sky-steps
      wait 1
      pen-erase bk blue-sky-steps
      die
   ]]


end



to move-worker [little-dude]

    if working-ticks > 0 [
      set working-ticks working-ticks - 1
      stop
    ]

    without-interruption
     [

         if energy < 1
         [ set color black
           pen-up
           move-to center-of-building 1  ;; get out of the way, but don't die and lose the info
           stop
         ]

         ;;set-direction little-dude
         follow-the-yellow-brick-road
         let step-size 1

         let nextpatch [pcolor] of patch-ahead 1

         if not member? nextpatch  allowed-patches [
           set hugging-edges-steps 10
;;           show "course correction"
;;           stop;
         ]

         ;; check for sticky situations
         if pcolor = clr-mud or pcolor = clr-danger
         [
;;            if avoid-mud? = 1 [ show "how did this guy get here?" ]
            if slow-in-mud? = 1 [ set step-size .5 ]
            if tired-in-mud? = 1 [set energy energy - 1]
            if risk-danger? = 1 and pcolor = clr-danger and dice-tossed? = 0
            [
                if random 100 < chance-of-injury-percent
                [ set color black
                    set energy 0
                ]
                set dice-tossed? 1

            ]
         ]


         ;; check for someone on that patch, step to the right (unless we are already hugging an edge)
;;         if (count (turtles-on (patch-ahead 1)) >= max-turtles-per-square
;;            and [building-number] of patch-ahead 1 = 0)
;         [
 ;          ;; patch-right-and-ahead angle distance
;           if (hugging-edges-steps < 1) [
;             set nextpatch [pcolor] of patch-right-and-ahead 45 1
;
;             ifelse ( member? nextpatch  allowed-patches and count (turtles-on (patch-right-and-ahead 45 1)) < max-turtles-per-square)
;             [
;               move-to patch-right-and-ahead 45 step-size
;               set blue-sky-steps 0
;               show "bump"
;
;             ]
;             [
;               set nextpatch [pcolor] of patch-right-and-ahead 90 1
;               if ( member? nextpatch  allowed-patches and count (turtles-on (patch-right-and-ahead 90 1)) < max-turtles-per-square)
;               [
;                 move-to patch-right-and-ahead 90 step-size
;                 set blue-sky-steps 0
;                 show "bump"
;               ]
;             ]
;           ]
;           set energy energy - 1
;           stop
;         ]


         ;; everyone!
         set energy energy - 1
         forward step-size
         if energy < 1  [
           set color black
           set no-energy-tick  ticks
           pen-up
           move-to patch 1 1
         ]

    ]
end


to check-goal  ;; worker procedure - if they have reached the goal, set a new one

  ;; did we reach the destination?  return to home!
  if building-number = destination-building and searching? = 1 [
    set-new-destination  home-building 0 0
    set working-ticks  (work-time destination-building)
  ]

  ;; did we reach the home?  go to destination
  if building-number = home-building and searching? = 0 [
    set-new-destination  destination-building 1 1
  ]
end


@#$#@#$#@
GRAPHICS-WINDOW
214
8
646
459
-1
-1
2.0
1
10
1
1
1
0
1
1
1
0
210
0
209
0
0
1
ticks
30.0

BUTTON
14
17
77
50
setup
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
144
17
207
50
go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

TEXTBOX
17
90
167
108
Click a square to make more:
11
0.0
1

CHOOSER
11
105
119
150
new-path-type
new-path-type
"mud" "path" "danger"
1

BUTTON
118
106
197
149
Add Blocks
add-blocks
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
643
15
1036
165
Productivity of Building 14
ticks
average trips
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Avoiding Mud" 1.0 0 -5825686 true "" "plot mean [trips-completed] of  turtles with [avoid-mud? = 1 and home-building = 14]"
"Slow in Mud" 1.0 0 -13791810 true "" "plot mean [trips-completed] of  turtles with [avoid-mud? = 0 and home-building = 14]"

PLOT
643
163
1036
313
Productivity of Building 18
ticks
average trips
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Avoid Mud" 1.0 0 -5825686 true "" "plot mean [trips-completed] of  turtles with [avoid-mud? = 1 and home-building = 18]"
"Tired in Mud" 1.0 0 -13791810 true "" "plot mean [trips-completed] of  turtles with [avoid-mud? = 0 and home-building = 18]"

PLOT
643
313
1038
463
Productivity of Building 15
ticks
average trips
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Laughs in face of Danger" 1.0 0 -13791810 true "" "plot mean [trips-completed] of  turtles with [avoid-mud? = 0 and home-building = 15]"
"Avoids Danger" 1.0 0 -5825686 true "" "plot mean [trips-completed] of  turtles with [avoid-mud? = 1 and home-building = 15]"

MONITOR
956
256
1045
301
# Out of energy
count  turtles with [energy <= 0 and avoid-mud? = 0 and home-building = 18]
0
1
11

MONITOR
903
407
1020
452
Ambulance Rides
count  turtles with [color = black and avoid-mud? = 0 and home-building = 15]
17
1
11

INPUTBOX
78
10
146
70
total-ticks
2000
1
0
Number

INPUTBOX
11
249
166
309
chance-of-injury-percent
7
1
0
Number

SWITCH
12
365
173
398
group-14-slow-in-mud
group-14-slow-in-mud
0
1
-1000

SWITCH
12
396
173
429
group-18-tired-in-mud
group-18-tired-in-mud
0
1
-1000

SWITCH
12
428
173
461
group-15-faces-danger
group-15-faces-danger
0
1
-1000

MONITOR
950
66
1039
111
# of Avoiders
count turtles with [avoid-mud? = 1 and home-building = 14]
17
1
11

MONITOR
950
110
1038
155
# of mudders
count turtles with [avoid-mud? = 0 and home-building = 14]
17
1
11

MONITOR
957
211
1045
256
# of mudders
count turtles with [avoid-mud? = 0 and home-building = 18]
17
1
11

MONITOR
903
362
1020
407
# of danger lovers
count turtles with [avoid-mud? = 0 and home-building = 15]
17
1
11

MONITOR
1066
225
1243
270
average time when mudders tired
mean  [no-energy-tick] of workers with [no-energy-tick > 0]
0
1
11

CHOOSER
10
198
106
243
building-to-move
building-to-move
14 15 18
1

TEXTBOX
11
184
196
212
Click a square to move the building
11
0.0
1

BUTTON
106
198
194
243
Move Building
move-building
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
10
315
194
348
max-turtles-per-square
max-turtles-per-square
1
10
10
1
1
dudes
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

Demonstration of traffic on a worksite, with obsticles that can cause energy loss, low speed, or chance of injury.

## HOW IT WORKS



## HOW TO USE IT



## THINGS TO NOTICE


## THINGS TO TRY


## EXTENDING THE MODEL
It would be possible to create two "buildings" for workers who are out of energy, and workers who are injured.  Workers move to empty spots in these buildings, so that we can see the rate that they land there.

## NETLOGO FEATURES

Created algorithms for looking ahead for a possible path, and creeping around edges when the path isn't clear.

## RELATED MODELS


## CREDITS AND REFERENCES
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
NetLogo 5.3
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
0
@#$#@#$#@
