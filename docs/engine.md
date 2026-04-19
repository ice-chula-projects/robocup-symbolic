# Engine

Below is a high-level explanation of the engine without getting too deep into implementation specifics. This is just here in case you are curious but don't want to read through all of the code.

## Overview

A game is modeled as it's settings and a series of states, starting from an `InitialState` and eventually ending on a `FinalState`.

When the simulation is ran, the program simply calls _step/4_, this predicate takes in the settings and a State and converts it into NextState by updating the State according to the rules of the simulation.

This process is done recursively until the exit condition has been reached (that being a team has a winning score). These series of states are then exported to a JSON file for use in the visualization system.

## Simulation

In the simulation, the field is modeled as a box with some width and height, where coordinates (0,0) refers to the top left of the box and (width, height) refers to the bottom right of the box. The bounds of the simulation are modeled as solid walls.

In the field, there are 2 types of objects: the **ball** and the **agents**.

### Ball Physics

- The ball is modeled as a _position_ and a _velocity_.
- Every step, the ball's velocity is added to it's position.
- Then, a check is performed to see if the ball is within a goal.
- If it is, the simulation is reset and the score is awarded. Otherwise the simulation continues.
- Every step, friction is modeled by multiplying a value to the ball's velocity. This value is part of the settings.
- When the ball collides with a wall, it loses some of it's velocity (specified in settings) and bounces in the opposite direction.

### Agents

Agents are modeled as circles on the field, each agent has a position, energy, and also a _Controller_ which is responsible for deciding what actions an agent takes every step:

- The state of the world, including things like the ball and other agents are passed into the agent's controller.
- That controller is then responsible for deciding what action the agent will take this step.
- The agent takes the action decided by the controller.
- The agent regenerates energy.
- agent collisions are resolved.

## Actions

There are 3 possible actions, `move`, `kick`, and `rest`.

### Move

```prolog
action(move, TargetPosition, MovementFactor)
```

- The agent will attempt to move towards the target position, using `MovementFactor` to determine how fast to move.
- `MovementFactor` is modeled as a number from 0 to 1, where 1 represents the maximum possible distance the agent can move (defined by the settings).
- The Agent then loses some amount of energy according to this formula.

$$(\text{Base Energy Cost}) \times 2^{\log_{1.5}(\text{Distance})}$$

The idea being, moving a distance of 1 costs some amount of energy (Base Energy Cost), then **for every 1.5x the distance, the energy cost is doubled**. If the agent doesn't have enough energy to move, the movement is canceled and the agent takes the rest action instead.

### Kick

```prolog
action(kick, KickTowardsPosition, KickStrengthFactor)
```

- The agent will attempt to kick the ball towards `KickTowardsPosition`, using `KickStrengthFactor` to determine how much power to kick the ball with. `KickStrengthFactor` is modeled as a number from 0 to 1, where 1 represents the maximum possible kick strength (defined by the settings).
- The Agent then loses energy, where kicking with max strength costs some amount of energy and the energy cost is linearly interpolated for strengths below max.
- Kick Strength is modeled as the **magnitude of velocity change of the ball**, for example a kick strength of 1 means that the kick adds a vector of length 1 to the ball's velocity.
- If the agent doesn't have enough energy to kick, or the ball is out of reach then the agent takes the rest action instead.

### Rest

```prolog
action(rest)
```

The agent will regenerate energy twice instead of only once in this step.

## Agent Collisions

- An agent can collide with the walls of the simulation or other agents
- When an agent collides with a wall, their position is simply "snapped" to the wall.
- When an agent collides with another agent, both agents are "snapped" away from each other in opposite directions until they are no longer overlapping.

## Randomness

To introduce randomness to the simulation, _agent actions are all slightly probabilistic_. Whenever an agent takes an action, some amount of randomness is applied to the result, those being:

- The angle of the direction of the kick is also deviation by ± `KickAngleDeviation`.
- When an agent kicks, the strength is deviated ± `KickStrengthDeviation`.
- When an agent moves, the distance traveled is deviated ± `RunDistanceDeviation`.
- When an agent regenerates energy, the energy regenerated is deviated ± `EnergyRegenerationDeviation`.

These values are defined within the settings.

## Step Resolution Order

1. Ball moves.
2. Goal is checked.
3. Award the points and reset the round if the ball is in a goal, else continue.
4. Ball bounces from any walls if it is colliding with a wall.
5. Ball velocity is dampened.
6. Agents take actions.
7. Agent collisions with walls/other agents are resolved.
