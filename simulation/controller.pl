:- module(controller, [action/1, action/3, controller/1, control/6]).
:- use_module(math).

action(move, vector(TargetPositionX, TargetPositionY), MovementFactor) :-
    withinRange(0, 1, MovementFactor).
action(kick, vector(DirectionX, DirectionY), KickStrengthFactor) :-
    withinRange(0, 1, KickStrengthFactor).
action(rest).

controller(_).
control(controller(_), AgentSettings, Agent, OtherAgents, Ball, Action) :-
    Action = action(kick, vector(100,50), 1).