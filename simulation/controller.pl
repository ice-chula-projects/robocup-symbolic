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
(TODO: Condense topwing and bottomwing into one role)
*/

/* WINGS

'topwing' refers to the AI used for the 'Top Wing' role. They dominate the top side of the field
by having an adaptive default position that's always situated above the ball.
(The middle of the ball's current position and a spot on the top of the opposite side)
If they are the nearest agent from the ball, they will attempt to chase it.
*/
control(controller(topwing), FieldSettings, AgentSettings, Agent, OtherAgents, Ball, Action) :- (
    canKick(AgentSettings, Agent, Ball, 1) -> 
        kickToGoal(FieldSettings, Action);

    closestDistanceToBall([Agent | OtherAgents], Ball, Agent) ->
        moveToBall(adaptive(Agent), Ball, AgentSettings, Action);

    anchorAt(3/4, 0, Ball, FieldSettings, TargetPosition),
    moveToPosition(TargetPosition, AgentSettings, Action)
).

% 'bottomwing' is the same thing but at the bottom. (TODO: condense the roles to wing(0) and wing(1))
control(controller(bottomwing), FieldSettings, AgentSettings, Agent, OtherAgents, Ball, Action) :- (
    canKick(AgentSettings, Agent, Ball, 1) -> 
        kickToGoal(FieldSettings, Action);

    closestDistanceToBall([Agent | OtherAgents], Ball, Agent) -> 
        moveToBall(adaptive(Agent), Ball, AgentSettings, Action);
 
    anchorAt(3/4, 1, Ball, FieldSettings, TargetPosition),
    moveToPosition(TargetPosition, AgentSettings, Action)
).

/* STRIKERS

'striker' refers to the AI used for the 'Striker' role. They are the biggest threat on the field,
attempting to score a goal around the center area. 
If they are nearest to the ball, they will attempt to pursue it.
*/
control(controller(striker), FieldSettings, AgentSettings, Agent, OtherAgents, Ball, Action) :- (
    canKick(AgentSettings, Agent, Ball, 1) -> 
        kickToGoal(FieldSettings, Action);

    closestDistanceToBall([Agent | OtherAgents], Ball, Agent) -> 
        moveToBall(adaptive(Agent), Ball, AgentSettings, Action);
 
    anchorAt(4/5, 1/2, Ball, FieldSettings, TargetPosition),
    moveToPosition(TargetPosition, AgentSettings, Action)
).

/* MIDFIELDERS

Midfielders stay in the middle of the field, their priority is to send the ball
they recieve from defenders forward to the attackers. They don't naturally
score goals.

There is only one midfielder controller, aptly named 'midfield' for the "Central Midfield" role.
(TODO: Instead of 1 midfield, make that two)
*/
control(controller(midfield), FieldSettings, AgentSettings, Agent, OtherAgents, Ball, Action) :- (
    canKick(AgentSettings, Agent, Ball, 1) ->
        bestPassTarget(Agent, OtherAgents, agent(_, _, BestPassTargetPosition, _, _, _, _)),
        Action = action(kick, BestPassTargetPosition, 0.5);

    closestDistanceToBall([Agent | OtherAgents], Ball, Agent) -> 
        moveToBall(adaptive(Agent), Ball, AgentSettings, Action);

    anchorAt(3/5, 1/2, Ball, FieldSettings, TargetPosition),
    moveToPosition(TargetPosition, AgentSettings, Action)
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
control(controller(blocker /*TODO: change blocker to back*/), FieldSettings, AgentSettings, Agent, OtherAgents, Ball, Action) :- (
    % Will pass the ball to the best (nearest and in front) ally
    canKick(AgentSettings, Agent, Ball, 1) ->
        bestPassTarget(Agent, OtherAgents, agent(_, _, BestPassTargetPosition, _, _, _, _)),
        Action = action(kick, BestPassTargetPosition, 0.75)
    ;
    
    closestDistanceToBall([Agent | OtherAgents], Ball, Agent) -> 
        moveToBall(adaptive(Agent), Ball, AgentSettings, Action);

    Agent = agent(_, _, CurrentPosition, _, _, _, _),
    AgentSettings = agentSettings(kickSettings(KickReach, _, _), _, _, _, _),
    predictBallPosition(FieldSettings, Agent, Ball, PredictedBallPosition),
    distance(CurrentPosition, PredictedBallPosition, DistanceToPredictedPosition),
    DistanceToPredictedPosition > KickReach ->
        moveToPosition(PredictedBallPosition, AgentSettings, Action);
    
    Action = action(rest)
).

/* GOALKEEPER

'goalkeeper' refers to the AI used for 'Goalkeeper', roles. Goalkeepers are restricted
to moving up and down in a straight line, they will try to approach the ball and pass
it to one of the three backs. Even if they are the closest to the ball, agents of
other roles will ignore that and continue to pursue the ball, since the goalkeeper cannot
move in the X-axis to catch it.
(TODO: Goalkeepers should stay in the middle and only move up and down when necessary
to conserve energy)
*/
control(controller(goalkeeper), fieldSettings(vector(Width, Height), GoalSize, _, _, _), AgentSettings, Agent, OtherAgents, Ball, Action) :-
    % Will pass the ball to the best (nearest and in front) ally
    canKick(AgentSettings, Agent, Ball, 1) ->
        bestPassTarget(Agent, OtherAgents, agent(_, _, BestPassTargetPosition, _, _, _, _)),
        Action = action(kick, BestPassTargetPosition, 0.65)
    ;
    % The goalkeeper can only move up and down based on goal size
    findYIntercept(Height, Ball, YIntercept),
    GoalSizeScaled is GoalSize * Height / 2,
    MinPositionY is (Height / 2) - GoalSizeScaled,
    MaxPositionY is (Height / 2) + GoalSizeScaled,
    clamp(YIntercept, MinPositionY, MaxPositionY, ClampedPositionY),
    sustainableMovementFactor(AgentSettings, SustainableMovementFactor),
    distanceToBall(Agent, Ball, DistanceToBall),
    GoalSizeTimesHeight is GoalSize * Height,
    DistanceToBall < GoalSizeTimesHeight ->
        DashingMovementFactor is SustainableMovementFactor * 3,
        chooseDestination(Agent, Ball, fieldSettings(vector(Width, Height), _, _, _, _), vector(0, ClampedPositionY), Destination),
        Action = action(move, Destination, DashingMovementFactor);
    
    distanceToBall(Agent, Ball, DistanceToBall),
    AgentSettings = agentSettings(kickSettings(KickReach, _, _), _, _, _, _),
    DashReach = KickReach * 5,
    DistanceToBall < DashReach ->
        moveToBall(instant, Ball, AgentSettings, Action);

    GoalHeight is Height / 2,
    Agent = agent(_, _, Position, _, _, _, _),
    distance(Position, vector(0, GoalHeight), DistanceFromTarget),
    AgentSettings = agentSettings(kickSettings(KickReach, _, _), _, _, _, _),
    DistanceFromTarget > KickReach ->
        moveToPosition(vector(0, GoalHeight), AgentSettings, Action);

    Action = action(rest).

/* DYNAMIC ROLES
TODO: Add dynamic roles for backs, when backs enter the front, they become wings.
*/

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

% TODO: move this to math
clamp(X, Min, _, Min) :- X < Min, !.
clamp(X, _, Max, Max) :- X > Max, !.
clamp(X, _, _, X).

% Predicates for filtering
agentInTeam(Team, agent(_, _, _, _, team(Team), _, _)).
isGoalkeeper(agent(_, _, _, _, _, _, controller(goalkeeper))).

/* Move action utils */
% Uses a dot product projection to intersect the ball's trajectory with the agent's position
predictBallPosition(
    FieldSettings,
    agent(_, _, AgentPosition, _, _, HomePositionRelative, _),
    ball(BallPosition, BallVelocity),
    PredictedBallPosition
) :- (
    magnitude(BallVelocity, BallVelocityMagnitude), BallVelocityMagnitude =:= 0 -> (
        relativeToAbsolute(HomePositionRelative, FieldSettings, HomePosition),
        PredictedBallPosition = HomePosition
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
    relativeToAbsolute(HomePositionRelative, FieldSettings, HomePosition),
    PredictedBallPosition = HomePosition
).

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

% Finds the movement factor that allows the agent to move using the same energy as it decays
sustainableMovementFactor(AgentSettings, SustainableMovementFactor) :-
    AgentSettings = agentSettings(_, runSettings(RunMaxDistance, _), energySettings(_, EnergyRegenerationPerTick), _, _),
    movementEnergyCost(AgentSettings, SustainableDistance, EnergyRegenerationPerTick),
    SustainableMovementFactor is SustainableDistance / RunMaxDistance.

moveToBall(dash, Ball, AgentSettings, Action) :-
    naiveFutureBallPosition(Ball, PredictedBallPosition),
    sustainableMovementFactor(AgentSettings, SustainableMovementFactor),
    DashingMovementFactor is SustainableMovementFactor * 2,
    clamp(DashingMovementFactor, 0, 1, ClampedMovementFactor),
    Action = action(move, PredictedBallPosition, ClampedMovementFactor).

moveToBall(sustainable, Ball, AgentSettings, Action) :-
    naiveFutureBallPosition(Ball, PredictedBallPosition),
    sustainableMovementFactor(AgentSettings, SustainableMovementFactor),
    Action = action(move, PredictedBallPosition, SustainableMovementFactor).

moveToBall(instant, Ball, AgentSettings, Action) :-
    naiveFutureBallPosition(Ball, PredictedBallPosition),
    sustainableMovementFactor(AgentSettings, SustainableMovementFactor),
    DashingMovementFactor is SustainableMovementFactor * 4,
    clamp(DashingMovementFactor, 0, 1, ClampedMovementFactor),
    Action = action(move, PredictedBallPosition, ClampedMovementFactor).

moveToBall(adaptive(Agent), Ball, AgentSettings, Action) :- (
    AgentSettings = agentSettings(_, _, energySettings(MaxEnergy, _), _, _),
    Agent = agent(_, _, _, Energy, _, _, _),
    EnergyThreshold is MaxEnergy * 2 / 5,
    Energy < EnergyThreshold -> 
        moveToBall(sustainable, Ball, AgentSettings, Action);

    AgentSettings = agentSettings(kickSettings(KickReach, _, _), _, _, _, _),
    distanceToBall(Agent, Ball, DistanceToBall),
    DashReach is KickReach * 6,
    DistanceToBall < DashReach ->
        moveToBall(dash, Ball, AgentSettings, Action);

    moveToBall(sustainable, Ball, AgentSettings, Action)
).

moveToPosition(TargetPosition, AgentSettings, Action) :-
    sustainableMovementFactor(AgentSettings, SustainableMovementFactor),
    Action = action(move, TargetPosition, SustainableMovementFactor).

anchorAt(WidthPercentage, HeightPercentage, ball(BallPosition, _), fieldSettings(vector(Width, Height), _, _, _, _), TargetPosition) :-
    CalculatedWidth is Width * WidthPercentage,
    CalculatedHeight is Height * HeightPercentage,
    middle(BallPosition, vector(CalculatedWidth, CalculatedHeight), TargetPosition).

/* Kick action utils */

kickToGoal(fieldSettings(vector(Width, Height), _, _, _, _), Action) :-
    GoalHeight is Height/2,
    Action = action(kick, vector(Width,GoalHeight), 1).

agentDistance(agent(_, _, FirstPosition, _, _, _, _), agent(_, _, SecondPosition, _, _, _, _), Distance) :-
    distance(FirstPosition, SecondPosition, Distance).

bestPassTarget(Agent, OtherAgents, BestPassTarget) :-
    Agent = agent(_, _, vector(AgentPositionX, _), _, _, _, _),
    exclude(isGoalkeeper, OtherAgents, NonGoalKeepers),
    include(agentInTeam(0), NonGoalKeepers, Allies),
    findall(Score-A, (
        member(A, Allies), A = agent(_, _, vector(AX, _), _, _, _, _),
        agentDistance(A, Agent, Distance),
        Score is 3*(AX - AgentPositionX) - Distance
    ), Pairs),

    max_member(_Score-BestPassTarget, Pairs).
