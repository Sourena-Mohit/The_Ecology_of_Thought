;; ==================================================================
;;  The Ecology of Thought (Final, Definitive Version 5.0)
;;  By Sourena Mohit Tabatabaie
;;  DSTI (Agent Based Modeling Course)
;;  Prof : Dr Georgiy Bobashev
;; ==================================================================

extensions [nw]

;; ------------------------------------------------------------------
;;  AGENT AND WORLD PROPERTIES
;; ------------------------------------------------------------------

patches-own [
  solution-quality
  is-discovered?
]

turtles-own [
  innovation-propensity
  imitation-propensity
  current-prestige
  best-idea-I-know
  best-quality-I-know
]

globals [
  ;; Metrics from Version 4.0
  innovator-count
  imitator-count
  balanced-count
  innovator-prestige-mean
  imitator-prestige-mean
  agents-on-poor-ideas
  agents-on-good-ideas
  agents-on-excellent-ideas
  previous-peak-prestige
  stagnation-timer

  ;; <<-- NEW: The metric for the Innovation Rate plot -->>
  innovations-this-tick
]

;; ------------------------------------------------------------------
;;  SETUP PROCEDURE
;; ------------------------------------------------------------------

to setup
  clear-all
  ask patches [ set pcolor gray - 2 ]

  ask patches [
    set solution-quality random-float 101
    set is-discovered? false
  ]

  create-turtles population-size [
    setxy random-xcor random-ycor
    set shape "person"
    set innovation-propensity random 11
    set imitation-propensity random 11
    update-state-and-memory
  ]

  if network-style = "Scale-Free" [
    nw:generate-preferential-attachment turtles links 2 2
  ]

  set previous-peak-prestige 0
  set stagnation-timer 0
  set innovations-this-tick 0 ;; <<-- NEW: Initialize the counter

  update-metrics
  update-visuals
  reset-ticks
end

to update-state-and-memory ;; turtle procedure
  set current-prestige [solution-quality] of patch-here
  ask patch-here [ set is-discovered? true ]

  if current-prestige > best-quality-I-know [
    set best-quality-I-know current-prestige
    set best-idea-I-know patch-here
  ]
end

;; ------------------------------------------------------------------
;;  GO PROCEDURE (THE MAIN LOOP)
;; ------------------------------------------------------------------

to go
  check-for-stop-conditions
  if not any? turtles [ stop ]

  set innovations-this-tick 0 ;; <<-- NEW: Reset the counter each tick

  ask turtles [ think ]

  update-metrics
  update-visuals

  tick
end

;; ------------------------------------------------------------------
;;  METRICS CALCULATION PROCEDURE
;; ------------------------------------------------------------------

to update-metrics
  let innovators turtles with [innovation-propensity > imitation-propensity]
  let imitators turtles with [imitation-propensity > innovation-propensity]

  set innovator-count count innovators
  set imitator-count count imitators
  set balanced-count (count turtles - innovator-count - imitator-count)

  ifelse any? innovators
    [ set innovator-prestige-mean mean [current-prestige] of innovators ]
    [ set innovator-prestige-mean 0 ]

  ifelse any? imitators
    [ set imitator-prestige-mean mean [current-prestige] of imitators ]
    [ set imitator-prestige-mean 0 ]

  set agents-on-poor-ideas count turtles with [current-prestige < 40]
  set agents-on-good-ideas count turtles with [current-prestige >= 40 and current-prestige <= 75]
  set agents-on-excellent-ideas count turtles with [current-prestige > 75]
end

;; ------------------------------------------------------------------
;;  STOPPING CONDITIONS
;; ------------------------------------------------------------------
to check-for-stop-conditions
  if not any? turtles [ stop ]
  if stop-on-time? and ticks >= max-ticks [ stop ]
  if stop-on-consensus? and (length remove-duplicates ([patch-here] of turtles)) <= 1 [ stop ]
  if stop-on-stagnation? [
    if ticks mod 50 = 0 [
      let current-peak max [current-prestige] of turtles
      ifelse current-peak <= previous-peak-prestige [
        set stagnation-timer stagnation-timer + 50
      ][
        set stagnation-timer 0
        set previous-peak-prestige current-peak
      ]
    ]
    if stagnation-timer >= 500 [ stop ]
  ]
end

;; ------------------------------------------------------------------
;;  CORE AGENT LOGIC
;; ------------------------------------------------------------------

to think ;; turtle procedure
  if random-float 20 > (innovation-propensity + imitation-propensity) [ stop ]
  if current-prestige < best-quality-I-know [
    if random 10 < conservatism [
      move-to best-idea-I-know
      update-state-and-memory
      stop
    ]
  ]
  ifelse innovation-propensity > imitation-propensity [ innovate ] [ imitate ]
  update-state-and-memory
end

;; ------------------------------------------------------------------
;;  BEHAVIOR SUBMODELS
;; ------------------------------------------------------------------

to innovate ;; turtle procedure
  let potential-idea one-of patches in-radius 3
  if [solution-quality] of potential-idea > current-prestige [
    move-to potential-idea
    set innovations-this-tick innovations-this-tick + 1 ;; <<-- NEW: Increment on success
  ]
end

to imitate ;; turtle procedure
  let potential-partners no-turtles
  if network-style = "Proximity" [ set potential-partners other turtles in-radius interaction-radius ]
  if network-style = "Scale-Free" [ if any? my-out-links [ set potential-partners [end2] of my-out-links ] ]
  if not any? potential-partners [ stop ]

  if imitation-rule = "Imitate Success" [
    let target-agent max-one-of potential-partners [current-prestige]
    if target-agent != nobody [
      move-to ([patch-here] of target-agent)
      if network-style = "Proximity" [ create-link-with target-agent [ set hidden? true die ] ]
      if network-style = "Scale-Free" [ ask out-link-to target-agent [ set color white set thickness 0.2 wait 0.1 set color gray - 2 set thickness 0.1 ] ]
    ]
  ]

  if imitation-rule = "Imitate Conformity" [
    let patches-of-others [patch-here] of potential-partners
    if not empty? patches-of-others [
      let most-popular-patches-list (modes patches-of-others)
      let target-patch one-of most-popular-patches-list
      move-to target-patch
    ]
  ]
end

;; ------------------------------------------------------------------
;;  VISUALIZATION
;; ------------------------------------------------------------------

to update-visuals
  ask patches with [is-discovered?] [
    set pcolor quality-to-color solution-quality
  ]

  ask turtles [
    let personality-score (innovation-propensity - imitation-propensity)
    ifelse personality-score >= 0
      [ set color scale-color red personality-score 0 10 ]
      [ set color scale-color blue personality-score -10 0 ]
    set size (current-prestige / 50) + 1
  ]

  ifelse network-style = "Scale-Free" [
    ask links [ set hidden? false set color gray - 2 set thickness 0.1 ]
  ] [
    ask links [ set hidden? true ]
  ]
end

;; ------------------------------------------------------------------
;;  HELPERS
;; ------------------------------------------------------------------
to-report quality-to-color [quality]
  if quality > 100 [ report white ]
  if quality > 75  [ report scale-color yellow (quality - 75) 0 25 ]
  if quality > 50  [ report scale-color green (quality - 50) 0 25 ]
  if quality > 25  [ report scale-color cyan (quality - 25) 0 25 ]
  report scale-color blue quality 0 25
end
@#$#@#$#@
GRAPHICS-WINDOW
545
56
982
494
-1
-1
13.0
1
10
1
1
1
0
1
1
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

BUTTON
49
64
113
97
Setup
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
125
65
188
98
Go
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

SLIDER
48
107
220
140
population-size
population-size
1
500
200.0
1
1
NIL
HORIZONTAL

SLIDER
48
146
220
179
interaction-radius
interaction-radius
1
20
3.0
1
1
NIL
HORIZONTAL

SLIDER
48
183
220
216
conservatism
conservatism
0
10
2.0
1
1
NIL
HORIZONTAL

CHOOSER
47
233
185
278
network-style
network-style
"Proximity" "Scale Free"
0

CHOOSER
206
233
358
278
imitation-rule
imitation-rule
"Imitate Success" "Imitate Conformity"
0

PLOT
48
287
497
449
Progress
Time
Prestige
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Average Prestige" 1.0 0 -10899396 true "" "plot mean [current-prestige] of turtles"
"Peak Prestige" 1.0 0 -1184463 true "" "plot max [current-prestige] of turtles"

PLOT
47
477
496
627
Knowledge & Diversity
Time
Count / Percent
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"% Discovered" 1.0 0 -7500403 true "" "plot (100 * count patches with [is-discovered?] / count patches)"
"Unique Ideas" 1.0 0 -11221820 true "" "plot length remove-duplicates ([patch-here] of turtles)"

MONITOR
545
502
650
547
Innovator Count
innovator-count
3
1
11

MONITOR
662
501
756
546
Imitator Count
imitator-count
17
1
11

MONITOR
769
502
869
547
Balanced Count
balanced-count
3
1
11

PLOT
44
642
431
792
Population Dynamics
NIL
Count / Prestige
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Innovator Prestige" 1.0 0 -7500403 true "" "plot innovator-prestige-mean"
"Imitator Prestige" 1.0 0 -6459832 true "" "plot imitator-prestige-mean"

PLOT
452
643
719
793
Idea Landscape Analysis
NIL
Agent Count
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Agents on Poor Ideas" 1.0 0 -6459832 true "" "plot agents-on-poor-ideas"
"Agents on Good Ideas" 1.0 0 -13791810 true "" "plot agents-on-good-ideas"
"Agents on Excellent Ideas" 1.0 0 -2674135 true "" "plot agents-on-excellent-ideas"

MONITOR
544
561
612
606
Poor Ideas 
count turtles with [current-prestige < 40]
17
1
11

SLIDER
494
98
527
248
max-ticks
max-ticks
500
10000
2000.0
1
1
NIL
VERTICAL

SWITCH
729
652
861
685
stop-on-time?
stop-on-time?
0
1
-1000

SWITCH
729
730
896
763
stop-on-stagnation?
stop-on-stagnation?
0
1
-1000

SWITCH
729
691
895
724
stop-on-consensus?
stop-on-consensus?
0
1
-1000

MONITOR
627
563
704
608
Good Ideas
count turtles with [current-prestige >= 40 and current-prestige <= 75]
17
1
11

MONITOR
717
563
814
608
Excellent Ideas
count turtles with [current-prestige > 75]
17
1
11

PLOT
999
58
1199
208
Innovation Rate
NIL
Successful Innovations
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"Innovation Rate" 1.0 0 -16777216 true "" "plot innovations-this-tick"

PLOT
999
222
1199
372
Memory Quality
NIL
Average Quality
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"Memory Quality" 1.0 0 -16777216 true "" "plot mean [best-quality-I-know] of turtles"

@#$#@#$#@
# WHAT IS IT?

This model is a simulation of how a society of "thinkers" makes progress by exploring a complex "problem space." It is a thought experiment designed to explore the dynamic relationship and fundamental tension between two cognitive strategies: Innovation (the risky process of creating or discovering new ideas) and Imitation (the safer process of copying the successful ideas of others).

The world is represented by a "fitness landscape"—a terrain where elevation corresponds to idea quality. Some ideas are mediocre "valleys," while a few are brilliant "peaks of genius." Agents, representing individual thinkers, must navigate this landscape. Some are risky Innovators (explorers), venturing into the unknown. Others are safer Imitators (settlers), who wait to copy what has already been proven successful.

The central question is: What is the optimal balance between imitation and innovation for a society to achieve sustainable progress? The model reveals how different social learning rules and network structures can lead to rapid breakthroughs, complete stagnation in "good enough" ideas, or pluralistic ignorance, demonstrating the complex and often surprising dynamics of collective intelligence.

# HOW IT WORKS

The model operates on a set of simple, local rules that produce complex emergent behavior:

## The "Idea" Landscape

- The world of patches represents a "problem space." Each patch is a unique "idea."
- Each patch has a hidden solution-quality from 0 to 100.
- Patches are initially "undiscovered" (dark gray). When an agent lands on a patch, it "lights up" with a heatmap color (from dark blue/green to bright white), revealing its quality to the world.

## The "Thinkers"

Each agent (a turtle) has a "personality" defined by its innovation-propensity and imitation-propensity:

- **Innovators** (red agents) are explorers driven to discover new ideas.
- **Imitators** (blue agents) are settlers driven to copy the success of others.
- **Balanced thinkers** (purple agents) employ a mix of both strategies.

## The Core Loop

At each time step, an agent decides whether to reconsider its current idea based on its personality and its memory.

### Cognitive Reinforcement

- First, the agent checks its memory for the best idea it has ever personally encountered.
- If its current idea is worse than this "personal best," it has a strong chance (controlled by the conservatism slider) to be risk-averse and simply revert to the idea it knows works.

### Innovate or Imitate

- If the agent doesn't revert to memory, it chooses its next action based on its personality.

#### Innovation (High Risk, High Reward)

- The agent examines a random nearby idea.
- If this new idea's quality is higher than its current one, it moves there, representing a successful innovation. Otherwise, the attempt fails, and it stays put.

#### Imitation (Low Risk, Social Learning)

- The agent identifies a set of "peers" based on the chosen network-style.
- It then copies one of them according to the active imitation-rule, abandoning its old idea in favor of the socially transmitted one.

# HOW TO USE IT

- Press the **SETUP** button to create the world and the population of thinkers.
- Press the **GO** button to run the simulation.
- Adjust the sliders and choosers **BEFORE** pressing SETUP to run different experiments.

# INTERFACE ITEMS

- **population-size**: Sets the number of agents in the world.
- **interaction-radius**: (Only in "Proximity" mode) Sets how far an agent can see to imitate its neighbors.
- **conservatism**: Controls "cognitive inertia." A high value means agents are very likely to revert to their best-remembered idea.

## network-style (Chooser)

- **Proximity**: Agents imitate others who are physically nearby. Models local knowledge transfer.
- **Scale-Free**: Agents are connected by a fixed social network with "hubs." Models knowledge transfer through influential "thought leaders."

## imitation-rule (Chooser)

- **Imitate Success**: Agents copy the agent with the highest prestige (the best idea).
- **Imitate Conformity**: Agents copy the most popular idea, regardless of its quality.

- **Stopping Switches**: You can turn on/off the automatic stopping conditions for the simulation.


# DECODING THE VISUALS

The model uses a rich visual system to make the abstract concepts of "ideas," "personalities," and "success" easy to see and understand at a glance. Here is your guide to what the colors and sizes represent.

## The Patches: The "Idea Landscape"

The background of the world represents the entire space of possible ideas. Each patch's color shows the quality of the idea at that location, but only after it has been discovered.

- **Dark Gray**: This is the default color for the "undiscovered country." These are ideas that no agent has yet explored. Their quality is unknown.
- **Heatmap Colors (Blue → Cyan → Green → Yellow → White)**: When an agent lands on a patch, the patch "lights up" with a color corresponding to its solution-quality.
  - **Dark Blue/Cyan**: Poor to mediocre ideas.
  - **Green**: Good, solid ideas. These are often the "local optima" where societies can get stuck.
  - **Yellow to Bright White**: Excellent to "genius" level ideas. The bright white patches are the highest-quality peaks in the landscape that agents strive to find.

## The Agents: The "Thinkers"

The agents are all "person" shapes, but their color and size are dynamic and meaningful.

### Agent Color (Represents Personality)

An agent's color is static and represents its innate tendency to innovate or imitate. It is a spectrum from pure blue to pure red.

- **Bright Red**: A pure Innovator. This agent has a high innovation-propensity and will almost always choose to explore for new ideas.
- **Bright Blue**: A pure Imitator. This agent has a high imitation-propensity and will almost always choose to copy others.
- **Purple / Dark Red / Dark Blue**: A Balanced Thinker. This agent has a mix of both traits and its behavior is less predictable.

### Agent Size (Represents Success)

An agent's size is dynamic and represents its current-prestige. Since prestige is determined by the quality of its current idea, this means:

- **Bigger agents have better ideas**. An agent standing on a bright white "genius" patch will be very large, while an agent on a dark blue "poor" idea patch will be small.
- Watch an agent's size change instantly when it moves to a new patch—this represents its immediate gain or loss in success.

## Dynamic Changes to Notice

- **The "Lighting Up" of the World**: As the simulation runs, watch the dark gray landscape get progressively filled in with the heatmap colors. This visualizes the growth of collective knowledge.
- **The "Disappearing" Agents**: Sometimes, a large group of agents will seem to suddenly shrink or disappear. They are not being destroyed. This is a visual representation of consensus. Many agents have chosen to imitate the exact same idea, and they are now stacked perfectly on top of each other on a single patch.


# PLOTS

- **Progress**: Tracks the average and peak idea quality in the society.
- **Knowledge & Diversity**: Shows how much of the "idea landscape" has been discovered and how many unique ideas are currently being considered.
- **Innovation Rate**: Shows the number of successful new ideas discovered each tick. This is a key measure of exploration.
- **Memory Quality**: Tracks the average quality of the "personal best" ideas remembered by all agents, representing the growth of collective wisdom.

# THINGS TO NOTICE

- **Stagnation is a Result, Not a Bug**: Watch the "Innovation Rate" plot. It will often plummet to zero after an initial burst. This is the model's key finding: societies often find a "good enough" solution and prematurely stop exploring for a great one.
- **The "Eureka!" and the Cascade**: In "Imitate Success" mode, watch what happens when a single red innovator stumbles upon a bright white "genius" peak. You will often see a cascade of flashing white lines shoot towards it as the blue imitators instantly abandon their mediocre ideas to copy this new, brilliant one.
- **The "Conformity" Trap**: Run the model with "Imitate Conformity." Notice how the society often gets stuck on a mediocre (green) idea, even if much better (white) ideas have been discovered nearby. This demonstrates how social pressure and the fear of being different can stifle progress.
- **Clustering and Echo Chambers**: In "Proximity" mode, notice how distinct "thought clusters" form. These are like intellectual villages, often unaware that a better discovery has been made just over the horizon by another, disconnected group.

# THINGS TO TRY

- **The Power of Memory**: Run experiments with conservatism at 0 (no memory) versus 10 (perfect memory). How does an agent's loyalty to its own past success affect its willingness to adopt a new, objectively better idea from society?
- **Conformity vs. Success**: Set conservatism to a low value. Which imitation rule, "Conformity" or "Success," consistently leads to a higher "Peak Prestige"? Which one leads to a higher final "Unique Ideas" count?
- **Network Effects**: Is the conformity trap stronger and harder to escape in a "Scale-Free" network where a few hubs can dictate the popular idea to everyone else?
- **The Value of Stubbornness**: Modify the code to make innovators have conservatism = 0 (always risk-taking) and imitators have conservatism = 10 (very risk-averse). How does this division of cognitive labor change the society's overall performance?

# EXTENDING THE MODEL

- **Evolving Personalities**: Make innovation-propensity and imitation-propensity heritable traits. When an agent reproduces (e.g., upon reaching a high prestige), its offspring could inherit its parent's personality with a chance of mutation. This would allow the model to discover the optimal personality type, not just the optimal idea.
- **Cost of Innovation**: Add an "energy" or "resource" component. Innovation could cost energy, while imitation could be free or even grant a small amount of energy. This would create a more realistic economic trade-off.
- **Landscape Dynamics**: Make the solution-quality of patches change over time. A "genius" idea might become obsolete, forcing the agents to abandon old peaks and start exploring again, breaking the stagnation.

# NETLOGO FEATURES

- **nw Extension**: Uses `nw:generate-preferential-attachment` to create a realistic, non-random social network with hubs for the "Scale-Free" mode.
- **Dynamic Visualization**: A custom reporter, `quality-to-color`, is used to create a vibrant "heatmap" of the idea landscape, making the abstract concept of "idea quality" visually intuitive.
- **Data Type Precision**: The code carefully distinguishes between agentsets (which work with `any?` and `max-one-of`) and lists (which work with `empty?` and `modes`), a common source of bugs in complex models that this project has overcome.
- **Temporary Links**: The visualization for imitation in "Scale-Free" mode uses a clever trick—`ask out-link-to ... [ ... wait 0.1 ...]`—to temporarily change a link's color and thickness, creating a clean "cascade" effect without permanent clutter.

# RELATED MODELS

- **Team Assembly**: (Models Library → Social Science) Explores how agents search a "problem space" for optimal solutions, similar to this model's fitness landscape.
- **Rumor Mill**: (Models Library → Social Science) Models information spreading through a network, which relates to the "Imitate Conformity" rule.
- **Cooperation**: (Models Library → Biology) Explores how individual strategies (like cooperate or defect) can spread through a population, similar to how ideas spread here.

# CREDITS AND REFERENCES

This model was developed by **Sourena Mohit Tabatabaie** for the **Agent Based Modeling** course at **Data ScienceTech Institute, France** in **June, 2025**.

## Model Origin

The initial idea for this project grew from a personal interest in cognitive philosophy and epistemology. The core concept was refined during a conversation with my cousin, a philosopher based in England, about how societies seem to balance between adopting established norms and creating disruptive new paradigms. This model is an attempt to explore that dynamic computationally.

## Development Note

This model was developed with the assistance of an AI programming partner (**ChatGPT**, a large language model from OpenAI) for debugging NetLogo code and drafting documentation.

## Key Concepts and Related Reading

- **Exploration-Exploitation Trade-off**:  
  A fundamental concept in reinforcement learning and organizational science. A good starting point is James G. March's 1991 paper:  
  *March, J. G. (1991). Exploration and Exploitation in Organizational Learning. Organization Science, 2(1), 71–87.*

- **Fitness Landscapes**:  
  A concept originating in evolutionary biology, introduced by Sewall Wright:  
  *Wright, S. (1932). The roles of mutation, inbreeding, crossbreeding and selection in evolution. Proceedings of the Sixth International Congress of Genetics, 1, 356–366.*

- **Preferential Attachment (Scale-Free Networks)**:  
  The model for generating the social network is based on the work of Barabási and Albert:  
  *Barabási, A.-L., & Albert, R. (1999). Emergence of Scaling in Random Networks. Science, 286(5439), 509–512.*
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
NetLogo 6.4.0
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
