:- use_module(math).
:- use_module(agent).
:- use_module(controller).

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
    sleep(0.04166666666),
    runSimulation(NextState).

% round order:
% ball moves
% goal checking
% if goal:
% award points and reset round
% if no goal:
% ball bounces from any walls
% ball velocity is dampened
% agents take actions
step(state(FieldSettings, AgentSettings, Ball, Agents, Score), state(FieldSettings, AgentSettings, NextBall, NextAgents, NextScore)) :-
    % update ball and check goal
    updateBallPosition(Ball, NextBall_1),
    checkGoal(FieldSettings, NextBall_1, Score, NextScore) ->
        resetRound(FieldSettings, Agents, NextAgents, NextBall)
        ;
        % ball needs to be reupdated in branch because the branch doesn't recognize NextBall_1 for some reason
        % TODO: maybe look into a cleaner way to do this part
        NextScore = Score,
        updateBallPosition(Ball, NextBall_1),
        updateBallWallBounce(FieldSettings, NextBall_1, NextBall_2),
        dampenBall(FieldSettings, NextBall_2, NextBall_3),
        updateAgents(AgentSettings, Agents, NextBall_3, NextAgents, NextBall).

% returns all agents to initial poition (defined within the agent itself)
% and returns the ball to the center with 0 velocity
resetRound(fieldSettings(vector(Width, Height), _, _, _, _), AgentSettings, Agents, NextAgents, NextBall) :-
    resetAgents(AgentSettings, Agents, NextAgents),
    BallStartX is Width / 2,
    BallStartY is Height / 2,
    NextBall = ball(vector(BallStartX, BallStartY), vector(0,0)).

% recursively calls resetAgent on all agents 
% resetAgent is defined within agent.pl
resetAgents(_, [], []).
resetAgents(AgentSettings, [Agent | T], [NextAgent | Agents]) :-
    resetAgent(AgentSettings, Agent, NextAgent),
    resetAgents(AgentSettings, T, Agents).

% moves ball according to it's velocity
updateBallPosition(ball(Position, Velocity), ball(NextPosition, Velocity)) :-
    add(Position, Velocity, NextPosition).

% checks if ball is in goal and increments the corresponding score if true
% otherwise fails
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

% snaps ball to the wall and reverse the appropriate velocity along with applying dampening 
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

% applies "drag" to the ball by multiplying a value in [0,1] to the ball's velocity
dampenBall(fieldSettings(_, _, BallDampening, _, _), ball(Position, Velocity), ball(Position, NextVelocity)) :-
    scale(Velocity, BallDampening, NextVelocity).


% recursively calls updateAgent() on all agents in agents
% also returns the NextBall, which is a result of
% calling updateAgent(Ball, NextBall_1)
% calling updateAgent(NextBall_1, NextBall_2)
% ...
% calling updateAgent(NextBall_n, NextBall)
updateAgents(_, [], Ball, [], Ball).
updateAgents(AgentSettings, [Agent | T], Ball, [NextAgent | Agents], NextBall) :-
    append(T, Agents, OtherAgents),
    updateAgent(AgentSettings, OtherAgents, Agent, Ball, NextAgent, NextBall_1),
    updateAgents(AgentSettings, T, NextBall_1, Agents, NextBall).

% sends information about the game to the agent's controller
% then calls takeAction() on the action to process tat action
updateAgent(AgentSettings, OtherAgents, Agent, Ball, NextAgent, NextBall) :-
    Agent = agent(_, _, _, _, _, _, Controller),
    control(Controller, AgentSettings, Agent, OtherAgents, Ball, Action),
    takeAction(Action, AgentSettings, Agent, Ball, NextAgent, NextBall).

% handle the move command
% if agent doesn't have enough energy to do so defaults to the rest command
takeAction(action(move, TargetPosition, DistanceFactor), AgentSettings, Agent, Ball, NextAgent, NextBall) :-
    canMove(AgentSettings, Agent, DistanceFactor) ->
        moveTowards(AgentSettings, Agent, TargetPosition, DistanceFactor, NextAgent),
        NextBall = Ball
        ;
        rest(AgentSettings, Agent, NextAgent),
        NextBall = Ball.

%handle the kick command
% if agent doesn't have enough energy to do so or the ball is'nt within range defaults to the rest command
takeAction(action(kick, KickDirection, KickStrengthFactor), AgentSettings, Agent, Ball, NextAgent, NextBall) :-
    canKick(AgentSettings, Agent, Ball, KickStrengthFactor) ->
        kick(AgentSettings, Agent, Ball, KickDirection, KickStrengthFactor, NextAgent, NextBall)
        ;
        rest(AgentSettings, Agent, NextAgent),
        NextBall = Ball.

%handle the rest command
takeAction(action(rest), AgentSettings, Agent, Ball, NextAgent, NextBall) :-
    rest(AgentSettings, Agent, NextAgent),
    NextBall = Ball.
