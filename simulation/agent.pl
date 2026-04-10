:- module(agent, [agentSettings/5, agent/7, canKick/4, kick/7, canMove/3, moveTowards/5, rest/3, resetAgent/3, deviate/3, isColliding/3, resolveCollision/5, movementEnergyCost/3]).
:- use_module(math).
:- use_module(controller, [controller/1]).


% KickReach - Max distance an agent is able to kick
% KickMaxStrength - Max Magnitude of the velocity change of the ball after a kick
% KickMaxEnergy - Energy Expended when kick is at max strength (where any values less than max strength is linearly interpolated)
kickSettings(KickReach, KickMaxStrength, KickMaxEnergy) :-
    number(KickReach),
    KickReach > 0,
    number(KickMaxStrength),
    KickMaxStrength > 0,
    number(KickMaxEnergy),
    KickMaxEnergy >= 0.

% RunMaxDistance - Max distance an agent is able to move in 1 tick
% RunBaseEnergy - Energy Expended when an agent moves a distance of 1 unit
runSettings(RunMaxDistance, RunBaseEnergy) :-
    number(RunMaxDistance),
    RunMaxDistance > 0,
    number(RunBaseEnergy),
    RunBaseEnergy >= 0.

% MaxEnergy - Max energy an agent can have
% EnergyRegenerationPerTick - How much energy on average does the agent regenerate every update
energySettings(MaxEnergy, EnergyRegenerationPerTick) :-
    number(MaxEnergy),
    MaxEnergy > 0,
    number(EnergyRegenerationPerTick),
    EnergyRegenerationPerTick > 0.

% KickAngleDeviation - An agent's kick is deviated +- KickAngleDeviation degrees every kick
% KickStrengthDeviation - An agent's kick strength is deviated by +- KickStrengthDeviation * 100%, doesnt effect energy spent.
% RunDistanceDeviation - An agent's run distance is deviated by +- RunDistanceDeviation * 100%, doesnt effect energy spent.
% EnergyRegenerationDeviation - An agent's energy regeneration is deviated by  +- EnergyRegenerationDeviation * 100%
deviationSettings(KickAngleDeviation, KickStrengthDeviation, RunDistanceDeviation, EnergyRegenerationDeviation) :-
    number(KickAngleDeviation),
    KickAngleDeviation >= 0,
    number(KickStrengthDeviation),
    KickStrengthDeviation >= 0,
    number(RunDistanceDeviation),
    RunDistanceDeviation >= 0,
    number(EnergyRegenerationDeviation),
    EnergyRegenerationDeviation >= 0.

% AgentSettings
% shape agentSettings(KickReach, KickMaxStrength, KickMaxEnergy, RunMaxDistance, RunBaseEnergy, MaxEnergy, EnergyRegenerationPerTick, DeviationSettings)
agentSettings(kickSettings(_, _, _), runSettings(_, _), energySettings(_, _), deviationSettings(_, _, _, _), AgentRadius) :-
    number(AgentRadius),
    AgentRadius > 0.

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
canKick(AgentSettings, agent(_, _, Position, Energy, _, _, _), ball(BallPosition, _), KickStrengthFactor) :-
    AgentSettings = agentSettings(kickSettings(KickReach, _, _), _, _, _, _),
    distance(Position, BallPosition, Distance),
    Distance =< KickReach,
    kickEnergyCost(AgentSettings, KickStrengthFactor, EnergyCost),
    Energy >= EnergyCost.

% performs a kick (does not do check if the agent can actually kick the ball as that is expected to be handled by the engine)
% Adds a vector with length EffectiveKickStrength +- deviation, in the direction of KickTowardsPosition +- angle deviation
% to the velocity of the ball
% then subtracts the appropriate amount of energy and add energy regeneration
% finally applies energy regeneration
kick(AgentSettings, agent(Name, Role, Position, Energy, Team, InitialPosition, Controller), ball(BallPosition, BallVelocity), KickTowardsPosition, KickStrengthFactor, agent(Name, Role, Position, NextEnergy, Team, InitialPosition, Controller), ball(BallPosition, NextBallVelocity)) :-
    AgentSettings = agentSettings(kickSettings(_, KickMaxStrength, _), _, _, _, _),

    EffectiveKickStrength is KickMaxStrength * KickStrengthFactor,
    deviateKickStrength(AgentSettings, EffectiveKickStrength, DeviatedKickStrength),

    sub(KickTowardsPosition, Position, KickDirection),
    deviateKickAngle(AgentSettings, KickDirection, DeviatedKickDirection),
    scale(DeviatedKickDirection, DeviatedKickStrength, BallVelocityChangeVector),
    add(BallVelocity, BallVelocityChangeVector, NextBallVelocity),
    
    kickEnergyCost(AgentSettings, KickStrengthFactor, EnergyCost),
    NextEnergy_1 is Energy - EnergyCost,
    regenerateEnergy(AgentSettings, NextEnergy_1, NextEnergy).


% checks if an agent has enough energy to move with the specified distanceFactor
canMove(AgentSettings, agent(_, _, _, Energy, _, _, _), DistanceFactor) :-
    AgentSettings = agentSettings(_ , runSettings(RunMaxDistance, _), _, _, _),
    EffectiveRunDistance is RunMaxDistance * DistanceFactor,
    movementEnergyCost(AgentSettings, EffectiveRunDistance, EnergyCost),
    Energy >= EnergyCost.

% moves the agent towards the TargetPosition, using DistanceFactor to determine the max distance the agent can travel
% then applies energy regeneration
moveTowards(AgentSettings, agent(Name, Role, Position, Energy, Team, InitialPosition, Controller), TargetPosition, DistanceFactor, agent(Name, Role, NextPosition, NextEnergy, Team, InitialPosition, Controller)) :-
    moveTowards(AgentSettings, Position, TargetPosition, DistanceFactor, NextPosition, EnergyCost),
    NextEnergy_1 is Energy - EnergyCost,
    regenerateEnergy(AgentSettings, NextEnergy_1, NextEnergy).

% case distance is within max range
% move the agent directly onto TargetPosition
% and subtract energy to the distance traveled accordingly
moveTowards(AgentSettings, Position, TargetPosition, DistanceFactor, NextPosition, EnergyCost) :-
    AgentSettings = agentSettings(_ , runSettings(RunMaxDistance, _), _, _, _),
    EffectiveRunMaxDistance is DistanceFactor * RunMaxDistance,
    distance(Position, TargetPosition, Distance),
    Distance =< EffectiveRunMaxDistance,
    movementEnergyCost(AgentSettings, Distance, EnergyCost),
    NextPosition = TargetPosition.

% case distance is out of max range
% move the agent a distance of EffectiveRunMaxDistance +- deviation in the direction of TargetPosition
% and subtract energy according to the intended travel distance
moveTowards(AgentSettings, Position, TargetPosition, DistanceFactor, NextPosition, EnergyCost) :-
    AgentSettings = agentSettings(_ , runSettings(RunMaxDistance, _), _, _, _),
    EffectiveRunDistance is DistanceFactor * RunMaxDistance,
    distance(Position, TargetPosition, Distance),
    Distance > EffectiveRunDistance,
    movementEnergyCost(AgentSettings, EffectiveRunDistance, EnergyCost),
    sub(TargetPosition, Position, DifferenceVector),
    normalize(DifferenceVector, DirectionVector),
    deviateRunDistance(AgentSettings, EffectiveRunDistance, DeviatedRunDistance),
    scale(DirectionVector, DeviatedRunDistance, MovementVector),
    add(Position, MovementVector, NextPosition).

% increases energy regeneration for that turn by calling regenerateEnergy twice.
rest(AgentSettings, agent(Name, Role, Position, Energy, Team, InitialPosition, Controller), agent(Name, Role, Position, NextEnergy, Team, InitialPosition, Controller)) :-
    regenerateEnergy(AgentSettings, Energy, NextEnergy_1),
    regenerateEnergy(AgentSettings, NextEnergy_1, NextEnergy).

% adds EnergyRegenerationPerTick +- deviation to the energy
regenerateEnergy(agentSettings(_, _, energySettings(MaxEnergy, EnergyRegenerationPerTick), deviationSettings(_, _, _, EnergyRegenerationDeviation), _), Energy, NextEnergy) :-
    deviate(EnergyRegenerationDeviation, EnergyRegenerationPerTick, EnergyRegenerated),
    NextEnergy_1 is Energy + EnergyRegenerated,
    clampEnergy(agentSettings(_, _, energySettings(MaxEnergy, _), _, _), NextEnergy_1, NextEnergy).

% sets the agent position to initial position
% and also set the agent energy to MaxEnergy
resetAgent(agentSettings(_, _, energySettings(MaxEnergy, _), _, _), agent(Name, Role, _, _, Team, InitialPosition, Controller), agent(Name, Role, NextPosition, NextEnergy, Team, InitialPosition, Controller)) :-
    NextPosition = InitialPosition,
    NextEnergy = MaxEnergy.

% ensures the energy isn't above MaxEnergy
% by clamping it
clampEnergy(agentSettings(_, _, energySettings(MaxEnergy, _), _, _), Energy, NextEnergy) :-
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
movementEnergyCost(agentSettings(_, runSettings(_, RunBaseEnergy), _, _, _), Distance, EnergyCost) :-
    %so that you can just pass in X or distance or energy cost and get the answer isntead of using 2 seperate functors
    var(Distance), nonvar(EnergyCost) ->
    inverseMovementEnergyCost(agentSettings(_, runSettings(_, RunBaseEnergy), _, _, _), EnergyCost, Distance)
    ;
    Distance > 0 ->
    EnergyCost is RunBaseEnergy * (5.52626008648 ** log(Distance))
    ;
    EnergyCost = 0.

% calculates the distance traveled, given energySpent
inverseMovementEnergyCost(agentSettings(_, runSettings(_, RunBaseEnergy), _, _, _), EnergyCost, Distance) :-
    EnergyCost > 0 ->
    Distance is (1.79492367603 ** log(EnergyCost)) / RunBaseEnergy
    ;
    Distance = 0.

% lineraly interpolates between 0 and KickMaxEnergy using KickStrengthFactor
kickEnergyCost(agentSettings(kickSettings(_, _, KickMaxEnergy), _, _, _, _), KickStrengthFactor, EnergyCost) :-
    EnergyCost is KickMaxEnergy * KickStrengthFactor.

% converts the direction vector to polar coordinates, then adds in angle deviation and converts the result back into cartesian coordinates
deviateKickAngle(agentSettings(_, _, _, deviationSettings(KickAngleDeviation, _, _, _), _), DirectionVector, NextDirectionVector) :-
    toPolar(DirectionVector, polar(_, Theta)),
    FloatKickAngleDeviation is float(KickAngleDeviation),
    NegativeKickAngleDeviation is FloatKickAngleDeviation * -1.0,
    random(NegativeKickAngleDeviation, FloatKickAngleDeviation, Deviation),
    NextTheta is Theta + (Deviation * pi/180),
    toVector(polar(1, NextTheta), NextDirectionVector).

deviateKickStrength(agentSettings(_, _, _, deviationSettings(_, KickStrengthDeviation, _, _), _), KickStrength, NextKickStrength) :-
    deviate(KickStrengthDeviation, KickStrength, NextKickStrength).

deviateRunDistance(agentSettings(_, _, _, deviationSettings(_, _, RunDistanceDeviation, _), _), RunDistance, NextRunDistance) :-
    deviate(RunDistanceDeviation, RunDistance, NextRunDistance).

% deviates Value by +- MaxDeviation * 100%.
% so result is Value +- n%
deviate(MaxDeviation, Value, DeviatedValue) :-
    LowerBound is 1.0 - MaxDeviation,
    UpperBound is 1.0 + MaxDeviation,
    random(LowerBound, UpperBound, DeviationFactor),
    DeviatedValue is Value * DeviationFactor.

isColliding(agentSettings(_, _, _, _, AgentRadius), agent(_, _, Position, _, _, _, _), agent(_, _, OtherPosition, _, _, _, _)) :-
    distance(Position, OtherPosition, Distance),
    MinimumDistance is 2 * AgentRadius,
    Distance =< MinimumDistance.

% resolves collisons by moving each agent half the overlap distance away from each other
% resulting in both agents just barly touching each other
resolveCollision(agentSettings(_, _, _, _, AgentRadius),
    agent(Name, Role, Position, Energy, Team, InitialPosition, Controller),
    agent(OtherName, OtherRole, OtherPosition, OtherEnergy, OtherTeam, OtherInitialPosition, OtherController),
    agent(Name, Role, NextPosition, Energy, Team, InitialPosition, Controller),
    agent(OtherName, OtherRole, NextOtherPosition, OtherEnergy, OtherTeam, OtherInitialPosition, OtherController)
) :-
    sub(OtherPosition, Position, DifferenceVector),
    magnitude(DifferenceVector, Distance),
    Distance > 0 ->
    SeperationDistance is AgentRadius - (Distance / 2),
    normalize(DifferenceVector, DirectionVector),
    scale(DirectionVector, SeperationDistance, OffsetVector),
    sub(Position, OffsetVector, NextPosition),
    add(OtherPosition, OffsetVector, NextOtherPosition)
    ;
    NextPosition = Position,
    NextOtherPosition = OtherPosition.
    
