:- module(agent, [agentSettings/9, agent/7, canKick/4, kick/7, canMove/3, moveTowards/5, rest/3, resetAgent/3, deviateKick/3]).
:- use_module(math).
:- use_module(controller, [controller/1]).

% AgentSettings
% KickReach - Max distance an agent is able to kick
% KickMaxStrength - Max Magnitude of the velocity change of the ball after a kick
% KickMaxEnergy - Energy Expended when kick is at max strength (where any values less than max strength is linearly interpolated)
% RunMaxDistance - Max distance an agent is able to move in 1 tick
% RunBaseEnergy - Energy Expended when an agent moves a distance of 1 unit
% RestFactor - How many times faster to regenerate energy while resting
% KickDeviation - Kick angles are deviated up to +- KickDeviation degrees.
% shape agentSettings(KickReach, KickMaxStrength, KickMaxEnergy, RunMaxDistance, RunBaseEnergy, RestFactor)
agentSettings(KickReach, KickMaxStrength, KickMaxEnergy, RunMaxDistance, RunBaseEnergy, MaxEnergy, EnergyRegenerationPerTick, RestFactor, KickDeviation) :-
    number(KickReach),
    KickReach > 0,
    number(KickMaxStrength),
    KickMaxStrength > 0,
    number(KickMaxEnergy),
    KickMaxEnergy > 0,
    number(RunMaxDistance),
    RunMaxDistance > 0,
    number(RunBaseEnergy),
    RunBaseEnergy > 0,
    number(MaxEnergy),
    MaxEnergy > 0,
    number(EnergyRegenerationPerTick),
    EnergyRegenerationPerTick > 0,
    number(RestFactor),
    RestFactor > 1,
    number(KickDeviation),
    KickDeviation > 0.

% Agent
% Name - a name to identify the agent by (not used in simulation logic)
% Role - a role to identify the agent by (not used in simulation logic)
% Position - current Position
% Energy - current Energy
% team - which team the agent is on
% IntialPosition - where the agent starts on round reset
% Controller - the id to the agent's controller
% shape: agent(Name, Role, vector(PositionX, PositionY), Energy, team(Team), InitialPosition, controller(Controller)).
agent(_, _, vector(_, _), _, team(_), vector(_, _), controller(_)).

% checks if an agent can kick
% first checks if the ball is within the reach of the kick
% then also checks if the agent has enough energy to kick with the desired KickStrengthFactor
% takes into account energy regeneration
canKick(AgentSettings, agent(_, _, Position, Energy, _, _, _), ball(BallPosition, _), KickStrengthFactor) :-
    AgentSettings = agentSettings(KickReach, _, _, _, _, _, EnergyRegenerationPerTick, _, _),
    distance(Position, BallPosition, Distance),
    Distance =< KickReach,
    kickEnergyCost(AgentSettings, KickStrengthFactor, EnergyCost),
    EffectiveEnergy is Energy + EnergyRegenerationPerTick,
    EffectiveEnergy >= EnergyCost.

% performs a kick (does not do check if the agent can actually kick the ball as that is expected to be handled by the engine)
% Adds a vector with length EffetiveKickStrength, in the direction of KickTowardsPosition
% to the velocity of the ball
% then subtracts the appropriate amount of energy and add energy regeneration
% finally calls clampEnergy() to ensure energy is not above max  
kick(AgentSettings, agent(Name, Role, Position, Energy, Team, InitialPosition, Controller), ball(BallPosition, BallVelocity), KickTowardsPosition, KickStrengthFactor, agent(Name, Role, Position, NextEnergy, Team, InitialPosition, Controller), ball(BallPosition, NextBallVelocity)) :-
    AgentSettings = agentSettings(_, KickMaxStrength, _, _, _, _, EnergyRegenerationPerTick, _, _),

    EffetiveKickStrength is KickMaxStrength * KickStrengthFactor,
    sub(KickTowardsPosition, Position, KickDirection),
    deviateKick(AgentSettings, KickDirection, DeviatedKickDirection),
    scale(DeviatedKickDirection, EffetiveKickStrength, BallVelocityChangeVector),
    add(BallVelocity, BallVelocityChangeVector, NextBallVelocity),
    
    kickEnergyCost(AgentSettings, KickStrengthFactor, EnergyCost),
    NextEnergy_1 is Energy - EnergyCost + EnergyRegenerationPerTick,
    clampEnergy(AgentSettings, NextEnergy_1, NextEnergy).


% checks if an agent has enough energy to move with the specified distanceFactor
% takes into account energy regeneration
canMove(AgentSettings, agent(_, _, _, Energy, _, _, _), DistanceFactor) :-
    AgentSettings = agentSettings(_, _, _, RunMaxDistance, _, _, EnergyRegenerationPerTick, _, _),
    EffectiveRunDistance is RunMaxDistance * DistanceFactor,
    movementEnergyCost(AgentSettings, EffectiveRunDistance, EnergyCost),
    EffectiveEnergy is Energy + EnergyRegenerationPerTick,
    EffectiveEnergy >= EnergyCost.

% moves the agent towards the TargetPosition, using DistanceFactor to determine the max distance the agent can travel
% then applies energy regeneration
% and calls clampEnergy to ensure energy is not above max
moveTowards(AgentSettings, agent(Name, Role, Position, Energy, Team, InitialPosition, Controller), TargetPosition, DistanceFactor, agent(Name, Role, NextPosition, NextEnergy, Team, InitialPosition, Controller)) :-
    AgentSettings = agentSettings(_, _, _, _, _, _, EnergyRegenerationPerTick, _, _),
    moveTowards(AgentSettings, Position, TargetPosition, DistanceFactor, NextPosition, EnergyCost),
    NextEnergy_1 is Energy - EnergyCost + EnergyRegenerationPerTick,
    clampEnergy(AgentSettings, NextEnergy_1, NextEnergy).

% case distance is within max range
% move the agent directly onto TargetPosition
% and subtract energy to the distance traveled accordingly
moveTowards(AgentSettings, Position, TargetPosition, DistanceFactor, NextPosition, EnergyCost) :-
    AgentSettings = agentSettings(_, _, _, RunMaxDistance, _, _, _, _, _),
    EffectiveRunMaxDistance is DistanceFactor * RunMaxDistance,
    distance(Position, TargetPosition, Distance),
    Distance =< EffectiveRunMaxDistance,
    movementEnergyCost(AgentSettings, Distance, EnergyCost),
    NextPosition = TargetPosition.

% case distance is out of max range
% move the agent a distance of EffectiveRunMaxDistance in the direction of TargetPosition
% and subtract energy to the distance traveled accordingly
moveTowards(AgentSettings, Position, TargetPosition, DistanceFactor, NextPosition, EnergyCost) :-
    AgentSettings = agentSettings(_, _, _, RunMaxDistance, _, _, _, _, _),
    EffectiveRunMaxDistance is DistanceFactor * RunMaxDistance,
    distance(Position, TargetPosition, Distance),
    Distance > EffectiveRunMaxDistance,
    movementEnergyCost(AgentSettings, EffectiveRunMaxDistance, EnergyCost),
    sub(TargetPosition, Position, DifferenceVector),
    normalize(DifferenceVector, DirectionVector),
    scale(DirectionVector, EffectiveRunMaxDistance, MovementVector),
    add(Position, MovementVector, NextPosition).

% increases energy regeneration by restFactor for that turn
% then calls clampEnergy() to make sure energy isnt above max
rest(agentSettings(_, _, _, _, _, MaxEnergy, EnergyRegenerationPerTick, RestFactor, _), agent(Name, Role, Position, Energy, Team, InitialPosition, Controller), agent(Name, Role, Position, NextEnergy, Team, InitialPosition, Controller)) :-
    NextEnergy_1 is Energy + (EnergyRegenerationPerTick * RestFactor),
    clampEnergy(agentSettings(_, _, _, _, _, MaxEnergy, _, _, _), NextEnergy_1, NextEnergy).

% sets the agent position to initial position
% and also set the agent energy to MaxEnergy
resetAgent(agentSettings(_, _, _, _, _, MaxEnergy, _, _, _), agent(Name, Role, _, _, Team, InitialPosition, Controller), agent(Name, Role, NextPosition, NextEnergy, Team, InitialPosition, Controller)) :-
    NextPosition = InitialPosition,
    NextEnergy = MaxEnergy.

% ensures the energy isn't above MaxEnergy
% by clamping it
clampEnergy(agentSettings(_, _, _, _, _, MaxEnergy, _, _, _), Energy, NextEnergy) :-
    Energy > MaxEnergy ->
        NextEnergy = MaxEnergy
        ;
        NextEnergy = Energy.

% formula: https://www.desmos.com/calculator/2th08sixr7
% the logic is that moving a distance of 1 takes RunBaseEnergy of Energy
% then for every doubling of RunBaseEnergy the distance is multiplied by 1.5
% ex. RunBaseEnergy = 1
% EnergyCost = 1 when distance = 1
% EnergyCost = 2 when distance = 1.5
% EnergyCost = 4 when distance = 1.5 * 1.5
movementEnergyCost(agentSettings(_, _, _, _, RunBaseEnergy, _, _, _, _), Distance, EnergyCost) :-
    EnergyCost is RunBaseEnergy * (5.52626008648 ** log(Distance)).

% lineraly interpolates between 0 and KickMaxEnergy using KickStrengthFactor
kickEnergyCost(agentSettings(_, _, KickMaxEnergy, _, _, _, _, _, _), KickStrengthFactor, EnergyCost) :-
    EnergyCost is KickMaxEnergy * KickStrengthFactor.

deviateKick(agentSettings(_, _, _, _, _, _, _, _, KickDeviation), DirectionVector, NextDirectionVector) :-
    toPolar(DirectionVector, polar(_, Theta)),
    FloatKickDeviation is float(KickDeviation),
    NegativeKickDeviation is FloatKickDeviation * -1.0,
    random(NegativeKickDeviation, FloatKickDeviation, Deviation),
    NextTheta is Theta + (Deviation * pi/180),
    toVector(polar(1, NextTheta), NextDirectionVector).