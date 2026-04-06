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