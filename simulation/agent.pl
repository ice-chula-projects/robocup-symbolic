:- module(agent, [agentSettings/7, agent/6, canKick/4, kick/7, canMove/4 moveTowards/6]).
:- use_module(math).

% AgentSettings
% KickReach - Max distance an agent is able to kick
% KickMaxStrength - Max Magnitude of the velocity change of the ball after a kick
% KickMaxEnergy - Energy Expended when kick is at max strength (where any values less than max strength is linearly interpolated)
% RunMaxDistance - Max distance an agent is able to move in 1 tick
% RunBaseEnergy - Energy Expended when an agent moves a distance of 1 unit
% shape agentSettings(KickReach, KickMaxStrength, KickMaxEnergy, RunMaxDistance, RunBaseEnergy)
agentSettings(KickReach, KickMaxStrength, KickMaxEnergy, RunMaxDistance, RunBaseEnergy, MaxEnergy, EnergyRegenerationPerTick) :-
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

% Agent
% Name - a name to identify the agent by (not used in simulation logic)
% Role - a role to identify the agent by (not used in simulation logic)
% Position - current Position
% Energy - current Energy
% team - which team the agent is on
% Controller - the id to the agent's controller
% shape: agent(Name, Role, vector(PositionX, PositionY), Energy, team(Team), controller(Controller)).
agent(_, _, Position, Energy, team(0), Controller).

canKick(AgentSettings, agent(_, _, AgentPosition, Energy, _, _), ball(BallPosition, _), KickStrengthFactor) :-
    AgentSettings = agentSettings(KickReach, _, _, _, _, _, _),
    distance(AgentPosition, BallPosition, Distance),
    Distance =< KickReach,
    withinRange(0,1,KickStrengthFactor),
    kickEnergyCost(AgentSettings, KickStrengthFactor, EnergyCost),
    Energy >= EnergyCost.

kick(AgentSettings, agent(Name, Role, Position, Energy, Team, Controller), ball(BallPosition, BallVelocity), KickDirection, KickStrengthFactor, agent(Name, Role, Position, NextEnergy, Team, Controller), ball(BallPosition, NextBallVelocity)) :-
    canKick(AgentSettings, agent(Name, Role, Position, Energy, Team, Controller), Ball, KickStrengthFactor),
    AgentSettings = agentSettings(_, KickMaxStrength, _, _, _, _, _),
    EffetiveKickStrength is KickMaxStrength * KickStrengthFactor,
    normalize(KickDirection, KickDirectionNormalized),
    scale(KickDirectionNormalized, EffetiveKickStrength, BallVelocityChangeVector),
    add(BallVelocity, BallVelocityChangeVector, NextBallVelocity),
    kickEnergyCost(AgentSettings, KickStrengthFactor, EnergyCost),
    NextEnergy is Energy - EnergyCost.


canMove(AgentSettings, agent(_, _, Position, Energy, _, _), TargetPosition, DistanceFactor) :-
    distance(AgentPosition, TargetPosition, Distance),
    withinRange(0, 1, DistanceFactor),
    EffectiveDistance is Distance * DistanceFactor,
    movementEnergyCost(AgentSettings, EffectiveDistance, EnergyCost),
    Energy >= EnergyCost.

moveTowards(AgentSettings, agent(Name, Role, Position, Energy, Team, Controller), TargetPosition, DistanceFactor, agent(Name, Role, NextPosition, NextEnergy, Team, Controller)) :-
    canMove(AgentSettings, agent(_, _, Position, Energy, _, _), TargetPosition, DistanceFactor),
    moveTowards(AgentSettings, Position, TargetPosition, DistanceFactor, NextPosition, EnergyCost),
    NextEnergy is Energy - EnergyCost.

moveTowards(AgentSettings, Position, TargetPosition, DistanceFactor, NextPosition, EnergyCost) :-
    AgentSettings = agentSettings(_, _, _, RunMaxDistance, _, _, _),
    withinRange(0, 1, DistanceFactor),
    EffectiveRunMaxDistance is DistanceFactor * RunMaxDistance,
    distance(Position, TargetPosition, Distance),
    %case distance is within range
    Distance =< EffectiveRunMaxDistance,
    movementEnergyCost(AgentSettings, Distance, EnergyCost),
    NextPosition = TargetPosition.

moveTowards(AgentSettings, Position, TargetPosition, DistanceFactor, NextPosition, EnergyCost) :-
    AgentSettings = agentSettings(_, _, _, RunMaxDistance, _, _, _),
    withinRange(0, 1, DistanceFactor),
    EffectiveRunMaxDistance is DistanceFactor * RunMaxDistance,
    distance(Position, TargetPosition, Distance),
    %case distance is out of max range
    Distance > EffectiveRunMaxDistance,
    AgentSettings = agentSettings(_, _, _, RunMaxDistance, _, _, _),
    EffectiveRunMaxDistance is DistanceFactor * RunMaxDistance,
    distance(Position, TargetPosition, Distance),

    movementEnergyCost(AgentSettings, EffectiveRunMaxDistance, EnergyCost),
    sub(TargetPosition, Position, DifferenceVector),
    normalize(DifferenceVector, DirectionVector),
    scale(DirectionVector, EffectiveRunMaxDistance, MovementVector),
    add(Position, MovementVector, NextPosition).



% formula: https://www.desmos.com/calculator/2th08sixr7
% the logic is that moving a distance of 1 takes RunBaseEnergy of Energy
% then for every doubling of RunBaseEnergy the distance is multiplied by 1.5
% ex. RunBaseEnergy = 1
% EnergyCost = 1 when distance = 1
% EnergyCost = 2 when distance = 1.5
% EnergyCost = 4 when distance = 1.5 * 1.5
movementEnergyCost(agentSettings(_, _, _, _, RunBaseEnergy, _, _), Distance, EnergyCost) :-
    EnergyCost is RunBaseEnergy * (5.52626008648 ** log(Distance)).

kickEnergyCost(agentSettings(_, _, KickMaxEnergy, _, _, _), KickStrengthFactor, EnergyCost) :-
    withinRange(0,1, StrengthFactor),
    EnergyCost is KickMaxEnergy * KickStrengthFactor.