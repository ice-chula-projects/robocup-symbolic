:- use_module(math).

% fieldSettings contains any settings not related to the agents
% vector(Width, Height) - width and height of the field
% GoalSize - a number from 0 to 1 representing the % of the wall area that the goal takes up
% BallDampening - a factor to multiply the ball's velocity by every step
% BallWallDampening - a factor to multiple the ball's velocity by every time the ball hits the wall
% WinningScore - a team will win if they reach this score
% shape: fieldSettings(vector(Width, Height), GoalSize, BallDampening, BallWallDampening, WinningScore)
fieldSettings(vector(Width,Height), GoalSize, BallDampening, BallWallDampening, WinningScore) :-
    number(Width),
    Width > 0,
    number(Height),
    Height > 0,
    number(GoalSize),
    withinRange(0, 1, GoalSize),
    number(BallDampening),
    withinRange(0, 1, BallDampening),
    number(BallWallDampening),
    withinRange(0, 1, BallWallDampening),
    integer(WinningScore),
    WinningScore > 0.


% ball stores position and velocity of the ball
% shape: ball(vector(PositionX, PositionY), vector(VelocityX, VelocityY))
ball(vector(_, _), vector(_, _)).

% state stores the state of the game
% shape: state(FieldSettings, AgentSettings, Ball, Agents, Score)
state(fieldSettings(_, _, _, _, _), _, ball(_, _), _, score(_, _)).

% Score
% shape score(Team0, Team1)
score(Team0, Team1) :-
    number(Team0, Team1).
% team 0 is left
% team 1 is right
team(0).
team(1).

runSimulation(state(fieldSettings(_, _, _, _, WinningScore), _, _, _, score(Team0, Team1))) :-
    Team0 >= WinningScore,
    write("Team0 won");
    Team1 >= WinningScore,
    write("Team1 won").

runSimulation(InitialState) :-
    step(InitialState, NextState),
    NextState = state(_, _, ball(vector(X,Y), vector(Vx, Vy)), _, _),
    format('ball is at (~w, ~w) with velocity (~w, ~w)~n', [X, Y, Vx, Vy]),
    sleep(0.1),
    runSimulation(NextState).
% round order:
% ball moves
% goal checking
% ball bounces from any walls
% ball velocity is dampened
% agents moves
% agents kick ball
step(state(FieldSettings, AgentSettings, Ball, Agents, Score), state(FieldSettings, AgentSettings, NextBall, Agents, NextScore)) :-
    % update ball and check goal
    updateBallPosition(Ball, NextBall_1),
    checkGoal(FieldSettings, NextBall_1, Score, NextScore) ->
        % TODO: reset state
        true
        ;
        % ball needs to be reupdated in branch because the branch doesn't recognize NextBall_1 for some reason
        % TODO: maybe look into a cleaner way to do this part
        NextScore = Score,
        updateBallPosition(Ball, NextBall_1),
        updateBallWallBounce(FieldSettings, NextBall_1, NextBall_2),
        dampenBall(FieldSettings, NextBall_2, NextBall).



updateBallPosition(ball(Position, Velocity), ball(NextPosition, Velocity)) :-
    add(Position, Velocity, NextPosition).

checkGoal(FieldSettings, Ball, score(Team0, Team1), NextScore) :-
    ballInGoal(FieldSettings, Ball, team(0)) ->
        NextTeam1Score is Team1 + 1,
        NextScore = score(Team0, NextTeam1Score)
        ;
        ballInGoal(FieldSettings, Ball, team(1)) ->
        NextTeam0Score is Team0 + 1,
        NextScore = score(NextTeam0Score, Team1)
        ;
        fail.


% snaps ball to the wall and reverse the appropriate velocity along with dampening 
updateBallWallBounce(fieldSettings(vector(Width, Height), _, _, BallWallDampening, _), ball(vector(BallX, BallY), vector(VelocityX, VelocityY)), ball(vector(NextBallX, NextBallY), vector(NextVelocityX, NextVelocityY))) :-
    %bounce in x axis
    updateBounce(Width, BallWallDampening, BallX, VelocityX, NextBallX, NextVelocityX),
    %bounce in y axis
    updateBounce(Height, BallWallDampening, BallY, VelocityY, NextBallY, NextVelocityY).

%bounces along an axis (assumes there is a wall at 0 and wallposition)
updateBounce(WallPosition, BallWallDampening, Position, Velocity, NextPosition, NextVelocity) :-
    Position < 0 -> 
    NextVelocity is -1 * BallWallDampening * Velocity,
    NextPosition = 0
    ;
    Position > WallPosition ->
    NextVelocity is -1 * BallWallDampening * Velocity,
    NextPosition = WallPosition
    ;
    NextPosition = Position,
    NextVelocity = Velocity.

dampenBall(fieldSettings(_, _, BallDampening, _, _), ball(Position, Velocity), ball(Position, NextVelocity)) :-
    scale(Velocity, BallDampening, NextVelocity).

% is true if the ball is in the specified team's goal
ballInGoal(fieldSettings(vector(_, Height), GoalSize, _, _, _), ball(vector(BallX, BallY), _), team(0)) :-
    BallX =< 0,
    ballWithinYThreshold(Height, GoalSize, BallY).

ballInGoal(fieldSettings(vector(Width, Height), GoalSize, _, _, _), ball(vector(BallX, BallY), _), team(1)) :-
    BallX >= Width,
    ballWithinYThreshold(Height, GoalSize, BallY).

%checks if ball is within the Y threshold of the goal
ballWithinYThreshold(FieldHeight, GoalSize, BallY) :-
    ShiftedBallY is abs(BallY - (FieldHeight/2)),
    Threshold is FieldHeight * (GoalSize / 2),
    ShiftedBallY =< Threshold.