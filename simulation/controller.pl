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

control(controller(blocker), fieldSettings(vector(Width, Height),_,_,_,_), AgentSettings, Agent, OtherAgents, Ball, Action) :-
    % If can kick, kick towards the goal
    canKick(AgentSettings, Agent, Ball, 1) ->
        GoalHeight is Height/2,
        Action = action(kick, vector(Width, GoalHeight), 1)
    ;
    % Move to the position between your goal and the nearest agent
    Ball = ball(BallPosition, _),
    Agent = agent(_, _, CurrentPosition, _, _, _, _),
    distance(BallPosition, CurrentPosition, DistanceToBall),
    AgentSettings = agentSettings(kickSettings(KickReach, _, _), _, _, _, _),
    MoveToBallReach is KickReach * 5,
    (DistanceToBall < MoveToBallReach ->
        Action = action(move, BallPosition, 1)
    ;
    nearestAgent(Agent, OtherAgents, NearestAgent, _Distance),
    NearestAgent = agent(_, _, NearestAgentPosition, _, _, _, _),
    GoalHeight is Height/2,
    middle(NearestAgentPosition, vector(0, GoalHeight), Middle),
    Action = action(move, Middle, 1)).

mirrorPosition(fieldSettings(vector(Width, _),_,_,_,_), vector(PositionX, PositionY), vector(NextPositionX, PositionY)) :-
    NextPositionX is Width - PositionX.

mirrorAction(FieldSettings, action(Name, Position, Factor), action(Name, MirroredPosition, Factor)) :-
    mirrorPosition(FieldSettings, Position, MirroredPosition).

mirrorBall(FieldSettings, ball(Position, Velocity), ball(MirroredPosition, MirroredVelocity)) :-
    mirrorPosition(FieldSettings, Position, MirroredPosition),
    mirrorPosition(FieldSettings, Velocity, MirroredVelocity).

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

nearestAgent(Agent, OtherAgents, NearestAgent, Distance) :-
    findall(D-A, (member(A, OtherAgents), agentDistance(Agent, A, D)), Pairs),
    min_member(Distance-NearestAgent, Pairs).