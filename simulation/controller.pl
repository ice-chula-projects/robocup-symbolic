:- module(controller, [action/1, action/3, controller/1, control/7, mirrorPosition/3, mirrorAgent/3, mirrorAgents/3, mirrorAction/3, mirrorBall/3]).
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

control(controller(blocker), _FieldSettings, AgentSettings, Agent, OtherAgents, Ball, Action) :-
    % Will pass the ball to the nearest ally
    canKick(AgentSettings, Agent, Ball, 1) ->
        bestPassTarget(Agent, OtherAgents, agent(_, _, BestPassTargetPosition, _, _, _, _)),
        Action = action(kick, BestPassTargetPosition, 1)
    ;
    % Move to the position between your goal and the nearest agent
    (closestDistanceToBall([Agent | OtherAgents], Ball, Agent) ->
        predictBallAdd(Ball, PredictedPosition),
        Action = action(move, PredictedPosition, 1)
    ;
    Agent = agent(_, _, CurrentPosition, _, _, _, _),
    AgentSettings = agentSettings(kickSettings(KickReach, _, _), _, _, _, _),
    predictBallPosition(Agent, Ball, PredictedBallPosition),
    distance(CurrentPosition, PredictedBallPosition, DistanceToPredictedPosition),
    chooseDestination(Agent, Ball, PredictedBallPosition, Destination),
    DistanceToPredictedPosition > KickReach ->
        Action = action(move, Destination, 1)
    ;
    Action = action(rest)
).

control(controller(topwing), fieldSettings(vector(Width, Height),_,_,_,_), AgentSettings, Agent, OtherAgents, Ball, Action) :-
    % Will kick towards the goal if given the chance
    canKick(AgentSettings, Agent, Ball, 1) ->
        GoalHeight is Height/2,
        Action = action(kick, vector(Width,GoalHeight), 1)
    ;
    % Move to the position between your goal and the nearest agent
    (closestDistanceToBall([Agent | OtherAgents], Ball, Agent) ->
        predictBallAdd(Ball, PredictedBallPosition),
        Action = action(move, PredictedBallPosition, 1)
    ;
    Ball = ball(BallPosition, _),
    ThreeQuartersWidth is Width * 3 / 4,
    middle(BallPosition, vector(ThreeQuartersWidth, 0), Middle),
    Action = action(move, Middle, 1)).

control(controller(bottomwing), fieldSettings(vector(Width, Height),_,_,_,_), AgentSettings, Agent, OtherAgents, Ball, Action) :-
    % Will kick towards the goal if given the chance
    canKick(AgentSettings, Agent, Ball, 1) ->
        GoalHeight is Height/2,
        Action = action(kick, vector(Width, GoalHeight), 1)
    ;
    % If you're closest to the ball, move to it
    (closestDistanceToBall([Agent | OtherAgents], Ball, Agent) ->
        predictBallAdd(Ball, PredictedBallPosition),
        Action = action(move, PredictedBallPosition, 1)
    ;
    % If you're far from the ball, go to a front position relative to the ball.
    Ball = ball(BallPosition, _),
    ThreeQuartersWidth is Width * 3 / 4,
    middle(BallPosition, vector(ThreeQuartersWidth, Height), Middle),
    Action = action(move, Middle, 1)).

control(controller(midfield), fieldSettings(vector(Width, Height), _, _, _, _), AgentSettings, Agent, OtherAgents, Ball, Action) :-
    % If can kick, kick towards the goal
    canKick(AgentSettings, Agent, Ball, 1) ->
        bestPassTarget(Agent, OtherAgents, agent(_, _, BestPassTargetPosition, _, _, _, _)),
        Action = action(kick, BestPassTargetPosition, 1)
    ;
    % Move to the position between your goal and the nearest agent
    (closestDistanceToBall([Agent | OtherAgents], Ball, Agent) ->
        predictBallAdd(Ball, PredictedBallPosition),
        Action = action(move, PredictedBallPosition, 1)
    ;
    Ball = ball(BallPosition, _),
    ThreeFiftsWidth is Width * 3 / 5,
    GoalHeight is Height / 2,
    middle(BallPosition, vector(ThreeFiftsWidth, GoalHeight), Middle),
    Action = action(move, Middle, 1)).

control(controller(goalkeeper), fieldSettings(vector(_, Height), GoalSize, _, _, _), AgentSettings, Agent, OtherAgents, Ball, Action) :-
    % If can kick, kick towards the goal
    canKick(AgentSettings, Agent, Ball, 1) ->
        bestPassTarget(Agent, OtherAgents, agent(_, _, BestPassTargetPosition, _, _, _, _)),
        Action = action(kick, BestPassTargetPosition, 1)
    ;
    % It can only move up and down based on goal size
    Ball = ball(BallPosition, _),
    BallPosition = vector(_, BallPositionY),
    GoalSizeScaled is GoalSize * Height / 2,
    MinPositionY is (Height / 2) - GoalSizeScaled,
    MaxPositionY is (Height / 2) + GoalSizeScaled,
    clamp(BallPositionY, MinPositionY, MaxPositionY, ClampedPositionY),
    Action = action(move, vector(0, ClampedPositionY), 1).

control(controller(pongkeeper), fieldSettings(vector(Width, Height),GoalSize,_,_,_), AgentSettings, Agent, _OtherAgents, Ball, Action) :-
    % If can kick, kick towards the goal
    canKick(AgentSettings, Agent, Ball, 1) ->
        AdjustedHeight is 1.5 * Height,
        NegativeHeight is -0.5 * Height,
        random(NegativeHeight, AdjustedHeight, RandomPositionY),
        Action = action(kick, vector(Width, RandomPositionY), 1)
    ;
    % It can only move up and down based on goal size
    predictBallAdd(Ball, PredictedPosition),
    PredictedPosition = vector(_, BallPositionY),
    GoalSizeScaled is GoalSize * Height / 2,
    MinPositionY is (Height / 2) - GoalSizeScaled,
    MaxPositionY is (Height / 2) + GoalSizeScaled,
    clamp(BallPositionY, MinPositionY, MaxPositionY, ClampedPositionY),
    Action = action(move, vector(0, ClampedPositionY), 1).

mirror(AxisPosition, Position, MirroredPosition) :-
    MirroredPosition is 2 * AxisPosition - Position.

mirrorPosition(fieldSettings(vector(Width, _),_,_,_,_), vector(PositionX, PositionY), vector(NextPositionX, PositionY)) :-
    MirrorPosition is Width / 2,
    mirror(MirrorPosition, PositionX, NextPositionX).

mirrorAction(_, action(rest), action(rest)).
mirrorAction(FieldSettings, action(Name, Position, Factor), action(Name, MirroredPosition, Factor)) :-
    mirrorPosition(FieldSettings, Position, MirroredPosition).

mirrorBall(FieldSettings, ball(Position, vector(VelocityX, VelocityY)), ball(MirroredPosition, vector(MirroredVelocityX, VelocityY))) :-
    mirrorPosition(FieldSettings, Position, MirroredPosition),
    mirror(0, VelocityX, MirroredVelocityX).

mirrorTeam(team(0), team(1)).
mirrorTeam(team(1), team(0)).

mirrorAgent(FieldSettings, agent(Name, Role, Position, Energy, Team, InitialPosition, Controller), agent(Name, Role, MirroredPosition, Energy, MirroredTeam, MirroredInitialPosition, Controller)) :-
    mirrorPosition(FieldSettings, Position, MirroredPosition),
    mirrorPosition(FieldSettings, InitialPosition, MirroredInitialPosition),
    mirrorTeam(Team, MirroredTeam).

mirrorAgents(_, [], []).
mirrorAgents(FieldSettings, [Agent | T], [MirroredAgent | MirroredAgents]) :-
    mirrorAgent(FieldSettings, Agent, MirroredAgent),
    mirrorAgents(FieldSettings, T, MirroredAgents).


agentDistance(agent(_, _, FirstPosition, _, _, _, _), agent(_, _, SecondPosition, _, _, _, _), Distance) :-
    distance(FirstPosition, SecondPosition, Distance).

bestPassTarget(Agent, OtherAgents, BestPassTarget) :-
    Agent = agent(_, _, vector(AgentPositionX, _), _, _, _, _),
    exclude(isGoalkeeper, OtherAgents, NonGoalKeepers),
    include(agentInTeam(0), NonGoalKeepers, Allies),
    findall(Score-A, (
        member(A, Allies), A = agent(_, _, vector(AX, _), _, _, _, _),
        agentDistance(A, Agent, Distance),
        Score is (AX - AgentPositionX) - Distance
    ), Pairs),

    max_member(_Score-BestPassTarget, Pairs).

agentInTeam(Team, agent(_, _, _, _, team(Team), _, _)).
isGoalkeeper(agent(_, _, _, _, _, _, controller(goalkeeper))).

clamp(X, Min, _, Min) :- X < Min, !.
clamp(X, _, Max, Max) :- X > Max, !.
clamp(X, _, _, X).

% Uses a perpendicular line intersecting the ball's trajectory and the agent's position
predictBallPosition(
    agent(_, _, vector(AgentPositionX, AgentPositionY), _, _, _, _),
    ball(vector(BallPositionX, BallPositionY), vector(BallVelocityX, BallVelocityY)),
    /* returns */ PredictedBallPosition
) :- (
    ((BallVelocityX =:= 0) ; (BallVelocityY =:= 0) ; ((BallVelocityY / BallVelocityX)**2 + 1 =:= 0)) -> (
        PredictedBallPosition = vector(AgentPositionX, AgentPositionY)
    );

    % Ball movement linear equation:
    % BallPositionY = M * BallPositionX + C
    M is BallVelocityY / BallVelocityX,
    C is BallPositionY - (M * (BallPositionX)),

    % Line perpendicular to slope intersecting the Agent:
    % Y = -(1/M) * X + (AgentPositionY + (1/M) * AgentPositionX)
    PerpendicularConstant = (AgentPositionY + (AgentPositionX / M)),
    X is M * (PerpendicularConstant - C) / ((M*M) + 1),
    Y is M * X + C,
    PredictedBallPosition = vector(X, Y)
).

closestDistanceToBall(AllAgents, ball(BallPosition, _), ClosestAgent) :-
    exclude(isGoalkeeper, AllAgents, NonGoalKeepers),
    include(agentInTeam(0), NonGoalKeepers, Allies),
    findall(D-A, (member(A, Allies), A = agent(_, _, AgentPosition, _, _, _, _), distance(BallPosition, AgentPosition, D)), Pairs),
    min_member(_Distance-ClosestAgent, Pairs).

% Decides between traveling to the computed destination or the home position depending on the direction of the movement.
chooseDestination(
    agent(_, _, AgentPosition, _, _, HomePosition, _), 
    ball(BallPosition, BallVelocity),
    ComputedDestination,
    /* returns */ Destination
) :- (
    magnitude(BallVelocity, BallVelocityMagnitude),
    BallVelocityMagnitude =:= 0 -> (
        Destination = HomePosition
    );
    sub(AgentPosition, BallPosition, RelativePositionFromBall),
    magnitude(RelativePositionFromBall, RelativePositionMagnitude),
    RelativePositionMagnitude =:= 0 -> (
        Destination = HomePosition
    );
    sub(AgentPosition, BallPosition, RelativePositionFromBall),
    normalize(RelativePositionFromBall, NormalizedRelativePosition),
    normalize(BallVelocity, NormalizedBallDirection),
    dot(NormalizedRelativePosition, NormalizedBallDirection, CosineTheta),
    
    CosineTheta < 0 -> ( % cos(90°) = 0
        Destination = HomePosition
    );
    Destination = ComputedDestination
).

predictBallAdd(ball(BallPosition, BallVelocity), PredictedPosition) :-
    scale(BallVelocity, 5, ScaledVelocity),
    add(BallPosition, ScaledVelocity, PredictedPosition).