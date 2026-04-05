:- module(agent, [agentSettings/8, agent/7, canKick/4, kick/7, canMove/4, moveTowards/6, rest/3, resetAgent/3]).
:- use_module(math).

% AgentSettings
% KickReach - Max distance an agent is able to kick
% KickMaxStrength - Max Magnitude of the velocity change of the ball after a kick
% KickMaxEnergy - Energy Expended when kick is at max strength (where any values less than max strength is linearly interpolated)
% RunMaxDistance - Max distance an agent is able to move in 1 tick
% RunBaseEnergy - Energy Expended when an agent moves a distance of 1 unit
% RestFactor - How many times faster to regenerate energy while resting 
% shape agentSettings(KickReach, KickMaxStrength, KickMaxEnergy, RunMaxDistance, RunBaseEnergy, RestFactor)
agentSettings(KickReach, KickMaxStrength, KickMaxEnergy, RunMaxDistance, RunBaseEnergy, MaxEnergy, EnergyRegenerationPerTick, RestFactor) :-
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
    RestFactor > 1.

% Agent
% Name - a name to identify the agent by (not used in simulation logic)
% Role - a role to identify the agent by (not used in simulation logic)
% Position - current Position
% Energy - current Energy
% team - which team the agent is on
% IntialPosition - where the agent starts on round reset
% Controller - the id to the agent's controller
% shape: agent(Name, Role, vector(PositionX, PositionY), Energy, team(Team), controller(Controller)).
agent(_, _, Position, Energy, team(0), InitialPosition, Controller).

canKick(AgentSettings, agent(_, _, Position, Energy, _, _, _), ball(BallPosition, _), KickStrengthFactor) :-
    AgentSettings = agentSettings(KickReach, _, _, _, _, _, EnergyRegenerationPerTick, _),
    distance(Position, BallPosition, Distance),
    Distance =< KickReach,
    withinRange(0,1,KickStrengthFactor),
    kickEnergyCost(AgentSettings, KickStrengthFactor, EnergyCost),
    EffectiveEnergy is Energy + EnergyRegenerationPerTick,
    EffectiveEnergy >= EnergyCost.

kick(AgentSettings, agent(Name, Role, Position, Energy, Team, InitialPosition, Controller), ball(BallPosition, BallVelocity), KickDirection, KickStrengthFactor, agent(Name, Role, Position, NextEnergy, Team, InitialPosition, Controller), ball(BallPosition, NextBallVelocity)) :-
    canKick(AgentSettings, agent(_, _, Position, Energy, _, _, _), ball(BallPosition, BallVelocity), KickStrengthFactor),
    AgentSettings = agentSettings(_, KickMaxStrength, _, _, _, _, EnergyRegenerationPerTick, _),
    EffetiveKickStrength is KickMaxStrength * KickStrengthFactor,
    normalize(KickDirection, KickDirectionNormalized),
    scale(KickDirectionNormalized, EffetiveKickStrength, BallVelocityChangeVector),
    add(BallVelocity, BallVelocityChangeVector, NextBallVelocity),
    kickEnergyCost(AgentSettings, KickStrengthFactor, EnergyCost),
    NextEnergy_1 is Energy - EnergyCost + EnergyRegenerationPerTick,
    clampEnergy(AgentSettings, NextEnergy_1, NextEnergy).

canMove(AgentSettings, agent(_, _, Position, Energy, _, _, _), TargetPosition, DistanceFactor) :-
    AgentSettings = agentSettings(_, _, _, _, _, _, EnergyRegenerationPerTick, _),
    distance(Position, TargetPosition, Distance),
    withinRange(0, 1, DistanceFactor),
    EffectiveDistance is Distance * DistanceFactor,
    movementEnergyCost(AgentSettings, EffectiveDistance, EnergyCost),
    EffectiveEnergy is Energy + EnergyRegenerationPerTick,
    EffectiveEnergy >= EnergyCost.

moveTowards(AgentSettings, agent(Name, Role, Position, Energy, Team, InitialPosition, Controller), TargetPosition, DistanceFactor, agent(Name, Role, NextPosition, NextEnergy, Team, InitialPosition, Controller)) :-
    AgentSettings = agentSettings(_, _, _, _, _, _, EnergyRegenerationPerTick, _),
    canMove(AgentSettings, agent(_, _, Position, Energy, _, _, _), TargetPosition, DistanceFactor),
    moveTowards(AgentSettings, Position, TargetPosition, DistanceFactor, NextPosition, EnergyCost),
    NextEnergy_1 is Energy - EnergyCost + EnergyRegenerationPerTick,
    clampEnergy(AgentSettings, NextEnergy_1, NextEnergy).

%case distance is within range 
moveTowards(AgentSettings, Position, TargetPosition, DistanceFactor, NextPosition, EnergyCost) :-
    AgentSettings = agentSettings(_, _, _, RunMaxDistance, _, _, _, _),
    withinRange(0, 1, DistanceFactor),
    EffectiveRunMaxDistance is DistanceFactor * RunMaxDistance,
    distance(Position, TargetPosition, Distance),
    Distance =< EffectiveRunMaxDistance,
    movementEnergyCost(AgentSettings, Distance, EnergyCost),
    NextPosition = TargetPosition.

%case distance is out of max range
moveTowards(AgentSettings, Position, TargetPosition, DistanceFactor, NextPosition, EnergyCost) :-
    AgentSettings = agentSettings(_, _, _, RunMaxDistance, _, _, _, _),
    withinRange(0, 1, DistanceFactor),
    EffectiveRunMaxDistance is DistanceFactor * RunMaxDistance,
    distance(Position, TargetPosition, Distance),
    Distance > EffectiveRunMaxDistance,
    AgentSettings = agentSettings(_, _, _, RunMaxDistance, _, _, _, _),
    EffectiveRunMaxDistance is DistanceFactor * RunMaxDistance,
    distance(Position, TargetPosition, Distance),

    movementEnergyCost(AgentSettings, EffectiveRunMaxDistance, EnergyCost),
    sub(TargetPosition, Position, DifferenceVector),
    normalize(DifferenceVector, DirectionVector),
    scale(DirectionVector, EffectiveRunMaxDistance, MovementVector),
    add(Position, MovementVector, NextPosition).

rest(agentSettings(_, _, _, _, _, MaxEnergy, EnergyRegenerationPerTick, RestFactor), agent(Name, Role, Position, Energy, Team, InitialPosition, Controller), agent(Name, Role, Position, NextEnergy, Team, InitialPosition, Controller)) :-
    NextEnergy_1 is Energy + (EnergyRegenerationPerTick * RestFactor),
    clampEnergy(agentSettings(_, _, _, _, _, MaxEnergy, _, _), NextEnergy_1, NextEnergy).

resetAgent(agentSettings(_, _, _, _, _, MaxEnergy, _, _), agent(Name, Role, _, _, Team, InitialPosition, Controller), agent(Name, Role, NextPosition, NextEnergy, Team, InitialPosition, Controller)) :-
    NextPosition = InitialPosition,
    NextEnergy = MaxEnergy.

clampEnergy(agentSettings(_, _, _, _, _, MaxEnergy, _, _), Energy, NextEnergy) :-
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
movementEnergyCost(agentSettings(_, _, _, _, RunBaseEnergy, _, _, _), Distance, EnergyCost) :-
    EnergyCost is RunBaseEnergy * (5.52626008648 ** log(Distance)).

kickEnergyCost(agentSettings(_, _, KickMaxEnergy, _, _, _, _, _), KickStrengthFactor, EnergyCost) :-
    withinRange(0,1, KickStrengthFactor),
    EnergyCost is KickMaxEnergy * KickStrengthFactor.