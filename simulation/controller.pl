:- module(controller, [action/1, action/3, controller/1, control/7]).
:- use_module(math).
:- use_module(agent).

% moves towards the target position using MovementFactor to determine
% how far to attempt to move from [0, RunMaxDistance]
% if it fails (not enough energy) will default to resting
% shape: action(move, TargetPosition, MovementFactor)
action(move, vector(_, _), MovementFactor) :-
    withinRange(0, 1, MovementFactor).

% kicks the ball towards the KickTowardsPosition
% using KickStrengthFactor to determine how strength to kick the ball with from [0, KickMaxStrength]
% if it fails (ball not in range, not enough energy) will default to resting
% shape: action(kick, KickTowardsPosition, KickStrengthFactor)
action(kick, vector(_, _), KickStrengthFactor) :-
    withinRange(0, 1, KickStrengthFactor).

% increases energy regeneration for this tick by
% RestFactor
action(rest).

controller(_).

% example controller named "simple"
% if it can kick the ball, kicks it with max strength towards the enemy's goal
% if it can't attempt to move towards the ball at max speed
% shape: control(controller(Name), FieldSettings, AgentSettings, Agent, OtherAgents, Ball, Action)
control(controller(simple), fieldSettings(vector(Width, Height),_,_,_,_), AgentSettings, Agent, _, Ball, Action) :-
    canKick(AgentSettings, Agent, Ball, 1) ->
        GoalHeight is Height/2,
        Action = action(kick, vector(Width,GoalHeight), 1);
        Ball = ball(BallPosition, _),
        Action = action(move, BallPosition, 1).

/* ATTACKERS

Attackers make up the offense of the game. When they get the ball, they will attempt to score
by shooting at the goal.

There are three types of defender controllers in this project: 'topwing', 'bottomwing', and 'striker'.
*/

/* WINGS

'topwing' refers to the AI used for the 'Top Wing' role. They dominate the top side of the field
by having an adaptive default position that's always situated above the ball.
(The middle of the ball's current position and a spot on the top of the opposite side)
If they are the nearest agent from the ball, they will attempt to chase it.
*/
control(controller(topwing), FieldSettings, AgentSettings, Agent, OtherAgents, Ball, Action) :- (
    canKick(AgentSettings, Agent, Ball, 1) -> (
        shouldKickToGoal(FieldSettings, AgentSettings, Agent, OtherAgents) -> (
            kickToGoal(FieldSettings, AgentSettings, Ball, Action)
        );
        passToBestTarget(AgentSettings, 0.65, Agent, OtherAgents, Ball, Action)
    );

    closestDistanceToBall([Agent | OtherAgents], Ball, Agent) ->
        moveToBall(movement(adaptive), Agent, Ball, AgentSettings, Action);

    anchorAt(3/4, 0, Ball, FieldSettings, TargetPosition),
    moveToPosition(movement(sustainable), TargetPosition, AgentSettings, Action)
).

% 'bottomwing' has the sane AI as the top wing but will always situate themselves below the ball. 
control(controller(bottomwing), FieldSettings, AgentSettings, Agent, OtherAgents, Ball, Action) :- (
    canKick(AgentSettings, Agent, Ball, 1) -> (
        shouldKickToGoal(FieldSettings, AgentSettings, Agent, OtherAgents) -> (
            kickToGoal(FieldSettings, AgentSettings, Ball, Action)
        );
        passToBestTarget(AgentSettings, 0.65, Agent, OtherAgents, Ball, Action)
    );

    closestDistanceToBall([Agent | OtherAgents], Ball, Agent) -> 
        moveToBall(movement(adaptive), Agent, Ball, AgentSettings, Action);
 
    anchorAt(3/4, 1, Ball, FieldSettings, TargetPosition),
    moveToPosition(movement(sustainable), TargetPosition, AgentSettings, Action)
).

/* STRIKERS

'striker' refers to the AI used for the 'Striker' role. They are the biggest threat on the field,
attempting to score a goal around the center area. However, if they find themselves in the middle
(e.g. the start of the game), they would instead pass the ball because at that point, if they shot
at the goal it would just keep deflecting each other.
When their energy is high enough after resting, they will move to a designated area around the center.
If they are nearest to the ball, they will attempt to pursue it.
*/
control(controller(striker), FieldSettings, AgentSettings, Agent, OtherAgents, Ball, Action) :- (
    canKick(AgentSettings, Agent, Ball, 1) -> (
        FieldSettings = fieldSettings(vector(Width, Height), _, _, _, _),
        GoalHeight is Height / 2,
        (\+ isEnemyAgentBlockingTrajectory(AgentSettings, Agent, OtherAgents, vector(Width, GoalHeight))) -> (
            kickToGoal(FieldSettings, AgentSettings, Ball, Action)
        );
        passToBestTarget(AgentSettings, 0.65, Agent, OtherAgents, Ball, Action)
    );

    closestDistanceToBall([Agent | OtherAgents], Ball, Agent) -> 
        moveToBall(movement(adaptive), Agent, Ball, AgentSettings, Action);

    predictBallPosition(fallbackPosition(current), Agent, Ball, PredictedBallPosition),
    isDistanceOverReach(kickReachMultiplier(1.0), AgentSettings, Agent, PredictedBallPosition) ->
        moveToPosition(movement(adaptive), Agent, PredictedBallPosition, AgentSettings, Action);

    % Go to designated spot if there's nothing to do
    relativeToAbsolute(vector(3/4, 1/2), FieldSettings, DesignatedSpot),
    (isDistanceOverReach(kickReachMultiplier(1.0), AgentSettings, Agent, DesignatedSpot)) -> (
        moveToPosition(movement(sustainable), DesignatedSpot, AgentSettings, Action)
    );
    
    Action = action(rest)
).

/* MIDFIELDERS

Midfielders stay in the middle of the field, their priority is to send the ball
they recieve from defenders forward to the attackers. They don't naturally
score goals.

There is only one midfielder controller, aptly named 'midfield' for the "Top Midfield" and "Bottom Midfield" roles.
*/
control(controller(topmidfield), FieldSettings, AgentSettings, Agent, OtherAgents, Ball, Action) :- (
    canKick(AgentSettings, Agent, Ball, 1) -> (
        passToBestTarget(AgentSettings, 0.65, Agent, OtherAgents, Ball, Action)
    );

    closestDistanceToBall([Agent | OtherAgents], Ball, Agent) -> 
        moveToBall(movement(adaptive), Agent, Ball, AgentSettings, Action);

    anchorAt(3/5, 1/3, Ball, FieldSettings, TargetPosition),
    moveToPosition(movement(sustainable), TargetPosition, AgentSettings, Action)
).

control(controller(bottommidfield), FieldSettings, AgentSettings, Agent, OtherAgents, Ball, Action) :- (
    canKick(AgentSettings, Agent, Ball, 1) -> (
        passToBestTarget(AgentSettings, 0.65, Agent, OtherAgents, Ball, Action)
    );

    closestDistanceToBall([Agent | OtherAgents], Ball, Agent) -> 
        moveToBall(movement(adaptive), Agent, Ball, AgentSettings, Action);

    anchorAt(3/5, 2/3, Ball, FieldSettings, TargetPosition),
    moveToPosition(movement(sustainable), TargetPosition, AgentSettings, Action)
).


/* DEFENDERS

Defenders will focus on intercepting the ball from attackers kicking at the goal.
If they recieve a ball, they will kick it to the nearest ally in front of them 
(or just the nearest if nobody's in front of them)

There are two types of defender controllers in this project: 'back' and 'goalkeeper'.
*/

/* BACKS

'back' refers to the AI used for 'Top Back', 'Bottom Back', and 'Center Back' roles. They use a perpendicular 
pathfinding algorithm to find a spot where they can move to that intercepts the ball's trajectory.
If they are far enough from the ball, they will return to their home position (initialPosition) and rest
If they are the nearest agent from the ball, they will attempt to chase it.
*/
control(controller(back), FieldSettings, AgentSettings, Agent, OtherAgents, Ball, Action) :- (
    % Will pass the ball to the best (nearest and in front) ally
    canKick(AgentSettings, Agent, Ball, 1) ->
        passToBestTarget(AgentSettings, 0.75, Agent, OtherAgents, Ball, Action)
    ;
    
    closestDistanceToBall([Agent | OtherAgents], Ball, Agent) -> 
        moveToBall(movement(adaptive), Agent, Ball, AgentSettings, Action);

    predictBallPosition(fallbackPosition(home(FieldSettings)), Agent, Ball, PredictedBallPosition),
    isDistanceOverReach(kickReachMultiplier(1.0), AgentSettings, Agent, PredictedBallPosition) ->
        moveToPosition(movement(sustainable), PredictedBallPosition, AgentSettings, Action);
    
    Action = action(rest)
).

/* GOALKEEPER

'goalkeeper' refers to the AI used for 'Goalkeeper', roles. Goalkeepers are restricted
to moving up and down in a straight line, they will try to approach the ball and pass
it to one of the three backs. Even if they are the closest to the ball, agents of
other roles will ignore that and continue to pursue the ball, since the goalkeeper cannot
move in the X-axis to catch it.
*/
control(controller(goalkeeper), fieldSettings(vector(Width, Height), GoalSize, _, _, _), AgentSettings, Agent, OtherAgents, Ball, Action) :-
    % Will pass the ball to the best (nearest and in front) ally
    canKick(AgentSettings, Agent, Ball, 1) -> (
        passToBestTarget(AgentSettings, 0.65, Agent, OtherAgents, Ball, Action)
    );

    % Immediately move back if the ball isn't in reach anymore
    Agent = agent(_, _, vector(AgentPositionX, AgentPositionY), _, _, _, _),
    (AgentPositionX > 0) ->
        moveToPosition(movement(sustainable), vector(0, AgentPositionY), AgentSettings, Action);

    findYIntercept(Height, Ball, YIntercept),
    GoalSizeScaled is GoalSize * Height / 2,

    MinPositionY is (Height / 2) - GoalSizeScaled,
    MaxPositionY is (Height / 2) + GoalSizeScaled,

    clamp(YIntercept, MinPositionY, MaxPositionY, ClampedPositionY),
    distanceToBall(Agent, Ball, DistanceToBall),
    GoalSizeReach is GoalSize * Height * 2,
    DistanceToBall < GoalSizeReach ->
        chooseDestination(Agent, Ball, fieldSettings(vector(Width, Height), _, _, _, _), vector(0, ClampedPositionY), Destination),
        moveToPosition(movement(adaptive), Agent, Destination, AgentSettings, Action);

    GoalHeight is Height / 2,
    isDistanceOverReach(kickReachMultiplier(1), AgentSettings, Agent, vector(0, GoalHeight)) ->
        moveToPosition(movement(sustainable), vector(0, GoalHeight), AgentSettings, Action);

    Action = action(rest).

/* DYNAMIC ROLES

In a 3-2-1 7v7 Football position, the agents focus a lot on defense, passing the ball
to the only attacker in the field (the striker). But the midfielder on the other side
that isn't doing anything can dash forward and become a wing. For these dynamic roles,
a quadrant system has been implemented so that if the ball is in a specific quadrant
(Q1 = top right, Q2 = top left, Q3 = bottom left, Q4 = bottom right just like in maths),
the roles of the midfielders can change into a wing.
*/

/* TOP DYNAMIC

This role will be rendered as "Top Midfield" to the interface when they are using midfielder AI,
and a "Top Wing" when they are using wing AI (TODO: Await "NextRole" feature).
*/
control(controller(topdynamic), FieldSettings, AgentSettings, Agent, OtherAgents, Ball, Action) :- (
    % When the ball is in quadrant 1 or 3, be a top wing
    ballQuadrant(FieldSettings, Ball, Quadrant),
    (Quadrant = 1 ; Quadrant = 3) -> (
        control(controller(topwing), FieldSettings, AgentSettings, Agent, OtherAgents, Ball, Action)    
    );

    % When the ball us in quadrant 2 or 4, be a top midfield
    control(controller(topmidfield), FieldSettings, AgentSettings, Agent, OtherAgents, Ball, Action)
).

/* BOTTOM DYNAMIC

This role will be rendered as "Bottom Midfield" to the interface when they are using midfielder AI,
and a "Bottom Wing" when they are using wing AI (TODO: Await "NextRole" feature).
*/
control(controller(bottomdynamic), FieldSettings, AgentSettings, Agent, OtherAgents, Ball, Action) :- (
    % When the ball is in quadrant 4 or 2, be a bottom wing
    ballQuadrant(FieldSettings, Ball, Quadrant),
    (Quadrant = 4 ; Quadrant = 2) -> (
        control(controller(bottomwing), FieldSettings, AgentSettings, Agent, OtherAgents, Ball, Action)    
    );

    % When the ball us in quadrant 3 or 1, be a bottom midfield
    control(controller(bottommidfield), FieldSettings, AgentSettings, Agent, OtherAgents, Ball, Action)
).

% TODO: Implement Pong mode (2 Goalkeepers fighting for the ball)
control(controller(pongkeeper), fieldSettings(vector(Width, Height),GoalSize,_,_,_), AgentSettings, Agent, _OtherAgents, Ball, Action) :-
    % If can kick, kick towards the goal
    canKick(AgentSettings, Agent, Ball, 1) ->
        AdjustedHeight is 1.5 * Height,
        NegativeHeight is -0.5 * Height,
        random(NegativeHeight, AdjustedHeight, RandomPositionY),
        Action = action(kick, vector(Width, RandomPositionY), 1)
    ;
    % It can only move up and down based on goal size
    naiveFutureBallPosition(Ball, PredictedPosition),
    PredictedPosition = vector(_, BallPositionY),
    GoalSizeScaled is GoalSize * Height / 2,
    MinPositionY is (Height / 2) - GoalSizeScaled,
    MaxPositionY is (Height / 2) + GoalSizeScaled,
    clamp(BallPositionY, MinPositionY, MaxPositionY, ClampedPositionY),
    Action = action(move, vector(0, ClampedPositionY), 1).

% TODO: move these to math.pl
clamp(X, Min, _, Min) :- X < Min, !.
clamp(X, _, Max, Max) :- X > Max, !.
clamp(X, _, _, X).

sign(X, -1) :- X < 0, !.
sign(X, 0) :- X =:= 0, !.
sign(_, +1).

% Predicates for filtering
agentInTeam(Team, agent(_, _, _, _, team(Team), _, _)).
isGoalkeeper(agent(_, _, _, _, _, _, controller(goalkeeper))).

/* Move action utils */
% Uses a dot product projection to intersect the ball's trajectory with the agent's position
findBallTrajectoryIntercept(
    agent(_, _, AgentPosition, _, _, _, _),
    ball(BallPosition, BallVelocity),
    FallbackPosition,
    PredictedBallPosition
) :- (
    magnitude(BallVelocity, BallVelocityMagnitude), BallVelocityMagnitude =:= 0 -> (
        PredictedBallPosition = FallbackPosition
    );

    sub(AgentPosition, BallPosition, DistanceVector),
    normalize(BallVelocity, NormalizedBallVelocity),
    dot(NormalizedBallVelocity, DistanceVector, DotProduct),

    % Ball is moving towards player
    DotProduct > 0 -> (
        /*
        PredictedBallPosition = BallPosition + \
        NormalizedBallVelocity * dot(NormalizedBallVelocity, DistanceVector)
        */
        scale(NormalizedBallVelocity, DotProduct, ScaledVelocity),
        add(BallPosition, ScaledVelocity, PredictedBallPosition)
    );

    % Ball is moving away from player
    PredictedBallPosition = FallbackPosition
).

% Used alongside predictBallPosition to mark the fallback value if the ball is moving away
fallbackPosition(current).  % Do nothing, this will be caught by any distance check and get converted into a rest action
fallbackPosition(home(fieldSettings(_, _, _, _, _))).  % Return to the "home" position as defined by the initialPosition of the agent

predictBallPosition(fallbackPosition(home(FieldSettings)), Agent, Ball, PredictedBallPosition) :-
    Agent = agent(_, _, _, _, _, HomePositionRelative, _),
    relativeToAbsolute(HomePositionRelative, FieldSettings, HomePosition),
    findBallTrajectoryIntercept(Agent, Ball, HomePosition, PredictedBallPosition).

predictBallPosition(fallbackPosition(current), Agent, Ball, PredictedBallPosition) :-
    Agent = agent(_, _, CurrentPosition, _, _, _, _),
    findBallTrajectoryIntercept(Agent, Ball, CurrentPosition, PredictedBallPosition).

findYIntercept(
    Height,
    ball(vector(BallPositionX, BallPositionY), vector(BallVelocityX, BallVelocityY)),
    YIntercept
) :- (
    ((BallVelocityX =:= 0) ; (BallVelocityY =:= 0)) -> 
        YIntercept is Height / 2;
    
    % Ball movement linear equation:
    % BallPositionY = M * BallPositionX + C
    M is BallVelocityY / BallVelocityX,
    YIntercept is BallPositionY - (M * (BallPositionX))
).

% Simulates the ball moving for 5 steps and retuns its position, used for accurate ball-chasing
naiveFutureBallPosition(ball(BallPosition, BallVelocity), PredictedPosition) :-
    scale(BallVelocity, 5, ScaledVelocity),
    add(BallPosition, ScaledVelocity, PredictedPosition).

distanceToBall(agent(_, _, AgentPosition, _, _, _, _), ball(BallPosition, _), DistanceToBall) :-
    distance(AgentPosition, BallPosition, DistanceToBall).

relativeToAbsolute(vector(PositionXRelative, PositionYRelative), fieldSettings(vector(Width, Height),_,_,_,_), vector(ResultX, ResultY)) :-
    ResultX is PositionXRelative * Width,
    ResultY is PositionYRelative * Height.
    
closestDistanceToBall(AllAgents, Ball, ClosestAgent) :-
    exclude(isGoalkeeper, AllAgents, NonGoalKeepers),
    include(agentInTeam(0), NonGoalKeepers, Allies),
    findall(DistanceToBall-A, (member(A, Allies), distanceToBall(A, Ball, DistanceToBall)), Pairs),
    min_member(_Distance-ClosestAgent, Pairs).

closestDistanceToGoal(AllAgents, ClosestAgent) :-
    include(agentInTeam(0), AllAgents, Allies),
    findall(PositionX-A, (member(A, Allies), A = agent(_, _, vector(PositionX, _), _, _, _, _)), Pairs),
    max_member(_PositionX-ClosestAgent, Pairs).

% Decides between traveling to the computed destination or the home position depending on the direction of the movement.
chooseDestination(
    agent(_, _, AgentPosition, _, _, HomePositionRelative, _), 
    ball(BallPosition, BallVelocity),
    FieldSettings,
    ComputedDestination,
    /* returns */ Destination
) :- (
    magnitude(BallVelocity, BallVelocityMagnitude),
    BallVelocityMagnitude =:= 0 -> (
        relativeToAbsolute(HomePositionRelative, FieldSettings, HomePosition),
        Destination = HomePosition
    );
    sub(AgentPosition, BallPosition, RelativePositionFromBall),
    magnitude(RelativePositionFromBall, RelativePositionMagnitude),
    RelativePositionMagnitude =:= 0 -> (
        relativeToAbsolute(HomePositionRelative, FieldSettings, HomePosition),
        Destination = HomePosition
    );
    sub(AgentPosition, BallPosition, RelativePositionFromBall),
    normalize(RelativePositionFromBall, NormalizedRelativePosition),
    normalize(BallVelocity, NormalizedBallDirection),
    dot(NormalizedRelativePosition, NormalizedBallDirection, CosineTheta),
    
    CosineTheta < 0 -> ( % cos(90°) = 0
        relativeToAbsolute(HomePositionRelative, FieldSettings, HomePosition),
        Destination = HomePosition
    );
    Destination = ComputedDestination
).

kickReachMultiplier(Multiplier) :- float(Multiplier), Multiplier >= 1.0.

% Calculates the distance from an agent to a position and sees if it's in reach of a specific range (KickReach * Multiplier)
isDistanceOverReach(
    kickReachMultiplier(Multiplier),
    agentSettings(kickSettings(KickReach, _, _), _, _, _, _),
    agent(_, _, CurrentPosition, _, _, _, _),
    Position
) :-
    distance(CurrentPosition, Position, DistanceToPredictedPosition),
    ScaledReach is KickReach * Multiplier,
    DistanceToPredictedPosition > ScaledReach.

% Overload for ball distance
isDistanceOverReach(kickReachMultiplier(Multiplier), AgentSettings, Agent, ball(BallPosition, _)) :-
    isDistanceOverReach(kickReachMultiplier(Multiplier), AgentSettings, Agent, BallPosition).

isBallMovingTowardsAgent(
    agent(_, _, AgentPosition, _, _, _, _),
    ball(BallPosition, BallVelocity)
) :- (
    (magnitude(BallVelocity, BallVelocityMagnitude), BallVelocityMagnitude =:= 0) -> (
        false
    );
    
    sub(AgentPosition, BallPosition, DistanceVector),
    (magnitude(DistanceVector, DistanceVectorMagnitude), DistanceVectorMagnitude =\= 0) -> (
        normalize(BallVelocity, NormalizedBallVelocity),
        normalize(DistanceVector, NormalizedDistanceVector),
        dot(NormalizedBallVelocity, NormalizedDistanceVector, CosineTheta),
        CosineTheta > 0.99144  % cos(7.5°) for margin
    );

    false
).

isEnemyAgentBlockingTrajectory(AgentSettings, Agent, OtherAgents, TargetPosition) :-
    AgentSettings = agentSettings(_, _, _, _, AgentRadius),
    Agent = agent(_, _, AgentPosition, _, _, _, _),
    
    % Find nearest enemy
    exclude(isGoalkeeper, OtherAgents, NonGoalKeepers),
    include(agentInTeam(1), NonGoalKeepers, Opponents),
    findall(Distance-A, (
        member(A, Opponents),
        agentDistance(A, Agent, Distance)
    ), Pairs),

    min_member(_Distance-NearestOpponent, Pairs),
    NearestOpponent = agent(_, _, NearestOpponentPosition, _, _, _, _),
    
    % Check if enemy is between agent and target
    sub(TargetPosition, AgentPosition, TrajectoryVector),
    sub(NearestOpponentPosition, AgentPosition, ToEnemyVector),
    
    % Enemy must be between agent and target (dot product > 0 and not past target)
    magnitude(TrajectoryVector, TrajectoryLength),
    normalize(TrajectoryVector, NormalizedTrajectory),
    dot(NormalizedTrajectory, ToEnemyVector, ProjectionLength),
    ProjectionLength > 0,
    ProjectionLength < TrajectoryLength,
    
    % Enemy must be within AgentRadius of the trajectory line
    scale(NormalizedTrajectory, ProjectionLength, ProjectionVector),
    sub(ToEnemyVector, ProjectionVector, PerpendicularVector),
    magnitude(PerpendicularVector, PerpendicularDistance),
    PerpendicularDistance < AgentRadius.

shouldKickToGoal(fieldSettings(vector(Width, Height), _, _, _, _), AgentSettings, Agent, OtherAgents) :-
    GoalHeight is Height/2,
    (
        closestDistanceToGoal([Agent | OtherAgents], Agent) ,
        \+ isEnemyAgentBlockingTrajectory(AgentSettings, Agent, OtherAgents, vector(Width, GoalHeight))
    ).

% (Width, 0) is top right (Q1)
ballQuadrant(fieldSettings(vector(Width, Height), _, _, _, _), ball(vector(BallPositionX, BallPositionY), _), 1) :-
    HalfWidth is Width / 2,
    HalfHeight is Height / 2,
    BallPositionX >= HalfWidth,
    BallPositionY < HalfHeight.

% (0, 0) is top left (Q2)
ballQuadrant(fieldSettings(vector(Width, Height), _, _, _, _), ball(vector(BallPositionX, BallPositionY), _), 2) :-
    HalfWidth is Width / 2,
    HalfHeight is Height / 2,
    BallPositionX < HalfWidth,
    BallPositionY < HalfHeight.

% (0, Height) is bottom left (Q3)
ballQuadrant(fieldSettings(vector(Width, Height), _, _, _, _), ball(vector(BallPositionX, BallPositionY), _), 3) :-
    HalfWidth is Width / 2,
    HalfHeight is Height / 2,
    BallPositionX < HalfWidth,
    BallPositionY >= HalfHeight.

% (Width, Height) is bottom right (Q4)
ballQuadrant(fieldSettings(vector(Width, Height), _, _, _, _), ball(vector(BallPositionX, BallPositionY), _), 4) :-
    HalfWidth is Width / 2,
    HalfHeight is Height / 2,
    BallPositionX >= HalfWidth,
    BallPositionY >= HalfHeight.

% Finds the movement factor that allows the agent to move using the same energy as it decays
sustainableMovementFactor(AgentSettings, SustainableMovementFactor) :-
    AgentSettings = agentSettings(_, runSettings(RunMaxDistance, _), energySettings(_, EnergyRegenerationPerTick), _, _),
    movementEnergyCost(AgentSettings, SustainableDistance, EnergyRegenerationPerTick),
    SustainableMovementFactor is SustainableDistance / RunMaxDistance.

movement(sustainable).
movement(dash).
movement(instant).
movement(adaptive).

movementFactorMultiplier(sustainable, 1.0).
movementFactorMultiplier(dash, 2.0).
movementFactorMultiplier(instant, 4.0).

moveToPosition(movement(adaptive), agent(_, _, _, Energy, _, _, _), TargetPosition, AgentSettings, Action) :- (
    AgentSettings = agentSettings(_, _, energySettings(MaxEnergy, _), _, _),
    EnergyThreshold is MaxEnergy * 3 / 5,
    Energy < EnergyThreshold ->
        moveToPosition(movement(sustainable), TargetPosition, AgentSettings, Action);

    moveToPosition(movement(dash), TargetPosition, AgentSettings, Action)
).

moveToPosition(movement(MovementType), TargetPosition, AgentSettings, Action) :-
    MovementType \= adaptive,
    sustainableMovementFactor(AgentSettings, SustainableMovementFactor),
    movementFactorMultiplier(MovementType, Multiplier),
    MovementFactor is SustainableMovementFactor * Multiplier,
    clamp(MovementFactor, 0.0, 1.0, ClampedMovementFactor),
    Action = action(move, TargetPosition, ClampedMovementFactor).

% Moving to the ball uses a different algorithm that dashes when close to the ball.
moveToBall(movement(adaptive), Agent, Ball, AgentSettings, Action) :- (
    AgentSettings = agentSettings(_, _, energySettings(MaxEnergy, _), _, _),
    Agent = agent(_, _, _, Energy, _, _, _),
    EnergyThreshold is MaxEnergy * 2 / 5,
    Energy < EnergyThreshold ->
        moveToBall(movement(sustainable), Agent, Ball, AgentSettings, Action);

    AgentSettings = agentSettings(kickSettings(KickReach, _, _), _, _, _, _),
    distanceToBall(Agent, Ball, DistanceToBall),
    DashReach is KickReach * 6,
    DistanceToBall < DashReach ->
        moveToBall(movement(dash), Agent, Ball, AgentSettings, Action);

    moveToBall(movement(sustainable), Agent, Ball, AgentSettings, Action)
).

moveToBall(movement(MovementType), Agent, Ball, AgentSettings, Action) :-
    MovementType \= adaptive,
    isBallMovingTowardsAgent(Agent, Ball) -> (
        Ball = ball(BallPosition, _),
        moveToPosition(movement(MovementType), BallPosition, AgentSettings, Action)
    );

    naiveFutureBallPosition(Ball, PredictedBallPosition),
    moveToPosition(movement(MovementType), PredictedBallPosition, AgentSettings, Action).


anchorAt(WidthPercentage, HeightPercentage, ball(BallPosition, _), fieldSettings(vector(Width, Height), _, _, _, _), TargetPosition) :-
    CalculatedWidth is Width * WidthPercentage,
    CalculatedHeight is Height * HeightPercentage,
    middle(BallPosition, vector(CalculatedWidth, CalculatedHeight), TargetPosition).

/* Kick action utils */

kickToGoal(fieldSettings(vector(Width, Height), _, _, _, _), AgentSettings, Ball, Action) :-
    GoalHeight is Height/2,
    accountKickTargetForBallVelocity(AgentSettings, 1, vector(Width,GoalHeight), Ball, AdjustedGoalPosition),
    Action = action(kick, AdjustedGoalPosition, 1).

agentDistance(agent(_, _, FirstPosition, _, _, _, _), agent(_, _, SecondPosition, _, _, _, _), Distance) :-
    distance(FirstPosition, SecondPosition, Distance).

topTwoMembers(Max1, Max2, List) :-
    max_member(Max1, List),
    select(Max1, List, Rest),
    max_member(Max2, Rest).

topTwoBestPassTargets(Agent, OtherAgents, BestPassTarget, SecondBestPassTarget) :-
    Agent = agent(_, _, vector(AgentPositionX, _), _, _, _, _),
    exclude(isGoalkeeper, OtherAgents, NonGoalKeepers),
    include(agentInTeam(0), NonGoalKeepers, Allies),
    findall(Score-A, (
        member(A, Allies), A = agent(_, _, vector(AX, _), _, _, _, _),
        agentDistance(A, Agent, Distance),
        DeltaX is AX - AgentPositionX,
        sign(DeltaX, ForwardFactor),
        Score is ForwardFactor * Distance
    ), Pairs),

    topTwoMembers(_BestScore-BestPassTarget, _SecondBestScore-SecondBestPassTarget, Pairs).

% Calculates the time it would take for the ball to reach the target position based on the kicking strength factor
predictTime(agentSettings(kickSettings(_, KickMaxStrength, _), _, _, _, _), KickStrengthFactor, TargetPosition, ball(BallPosition, _), PredictedTravelTime) :-
    EffectiveKickStrength is KickMaxStrength * KickStrengthFactor,
    distance(BallPosition, TargetPosition, Distance),
    PredictedTravelTime is Distance / EffectiveKickStrength.

accountKickTargetForBallVelocity(AgentSettings, KickStrengthFactor, TargetPosition, Ball, AdjustedTargetPosition) :-
  % Kick Strength is the magnitude of the velocity change of the ball on kick
  predictTime(AgentSettings, KickStrengthFactor, TargetPosition, Ball, PredictedTravelTime),

  % pretend the ball is still by acting like the target has velocity of BallVe locity in the negative direction
  % then kick towards where the target would be
  Ball = ball(_, BallVelocity),
  scale(BallVelocity, -1, TargetVelocity),
  scale(TargetVelocity, PredictedTravelTime, TargetDisplacement),
  add(TargetPosition, TargetDisplacement, AdjustedTargetPosition). 

chooseBestPassTarget(AgentSettings, Agent, OtherAgents, BestPosition, SecondBestPosition, TargetPosition) :-
    (\+ isEnemyAgentBlockingTrajectory(AgentSettings, Agent, OtherAgents, BestPosition)) -> (
        TargetPosition = BestPosition
    );
    TargetPosition = SecondBestPosition.

% Kicks towards the target position by predicting where the ball will be when it reaches the target and kicking towards that point
passToBestTarget(AgentSettings, KickStrengthFactor, Agent, OtherAgents, Ball, Action) :-
    topTwoBestPassTargets(Agent, OtherAgents, agent(_, _, BestPosition, _, _, _, _), agent(_, _, SecondBestPosition, _, _, _, _)),
    chooseBestPassTarget(AgentSettings, Agent, OtherAgents, BestPosition, SecondBestPosition, TargetPosition),
    accountKickTargetForBallVelocity(AgentSettings, KickStrengthFactor, TargetPosition, Ball, AdjustedTargetPosition),
    Action = action(kick, AdjustedTargetPosition, KickStrengthFactor).