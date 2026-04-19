:- module(simulation, [runSimulation/3, runSimulationWithTimeLimit/4]).


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
% shape: gameState(ball, agents, round, score)
gameState(ball(_, _), _, _, score(_,_)).

% state stores the state of the game with settings
% shape: state(FieldSettings, AgentSettings, GameState)
state(fieldSettings(_, _, _, _, _), agentSettings(_, _, _, _), gameState(_,_,_,_)).

% Score
% shape score(Team0, Team1)
score(Team0, Team1) :-
    number(Team0),
    number(Team1).

% team 0 is left
% team 1 is right
team(0).
team(1).

% runs the simulation from the given settings and agents and exports it when resolved
runSimulation(FieldSettings, AgentSettings, Agents) :-
    resetRound(FieldSettings, AgentSettings, Agents, InitialAgents, InitialBall),
    InitialState = state(FieldSettings, AgentSettings, gameState(InitialBall, InitialAgents, 1, score(0,0))),
    runSimulation(InitialState, GameStates, 0, inf),
    exportState(FieldSettings, AgentSettings, GameStates),
    !.

runSimulationWithTimeLimit(FieldSettings, AgentSettings, Agents, TimeLimit) :-
    resetRound(FieldSettings, AgentSettings, Agents, InitialAgents, InitialBall),
    InitialState = state(FieldSettings, AgentSettings, gameState(InitialBall, InitialAgents, 1, score(0,0))),
    runSimulation(InitialState, GameStates, 0, TimeLimit),
    exportState(FieldSettings, AgentSettings, GameStates),
    !.

% same as runSimulation but takes in the initialState predicate directly
% meant for debugging and testing purposes only
runSimulationFromInitialState(InitialState) :-
    runSimulation(InitialState, GameStates, 0, inf),
    InitialState = state(FieldSettings, AgentSettings, _),
    exportState(FieldSettings, AgentSettings, GameStates),
    !.

runSimulationFromInitialState(InitialState, TimeLimit) :-
    runSimulation(InitialState, GameStates, 0, TimeLimit),
    InitialState = state(FieldSettings, AgentSettings, _),
    exportState(FieldSettings, AgentSettings, GameStates),
    !.

% base case, a game is "over" when any team has more score than WinningScore
runSimulation(state(fieldSettings(_, _, _, _, WinningScore), _, gameState(_, _, _, score(Team0, Team1))), [], Time, TimeLimit) :-
    Team0 >= WinningScore;
    Team1 >= WinningScore;
    Time >= TimeLimit.

runSimulation(InitialState, [NextGameState | GameStates], Time, TimeLimit) :-
    step(InitialState, NextState),
    NextState = state(_, _, NextGameState),
    NextTime is Time + 1,
    runSimulation(NextState, GameStates, NextTime, TimeLimit).

exportState(fieldSettings(vector(Width,Height), GoalSize, BallDampening, BallWallDampening, WinningScore), agentSettings(kickSettings(KickReach, KickMaxStrength, KickMaxEnergy), runSettings(RunMaxDistance, RunMaxEnergy), energySettings(MaxEnergy, EnergyRegenerationPerTick), deviationSettings(KickAngleDeviation, KickStrengthDeviation, RunDistanceDeviation, EnergyRegenerationDeviation), AgentRadius), GameStates) :-
    gameStatesToJson(GameStates, GameStateJsons),
    GameJson = json{
        fieldSettings: json{
            dimensions: json{
                width: Width,
                height: Height
            },
            goalSize: GoalSize,
            ballDampening: BallDampening,
            ballWallDampening: BallWallDampening,
            winningScore: WinningScore
        },
        agentSettings: json{
           kickSettings: json{
                kickReach: KickReach,
                kickMaxStrength: KickMaxStrength,
                kickMaxEnergy: KickMaxEnergy
           },
           runSettings: json{
                runMaxDistance: RunMaxDistance,
                runMaxEnergy: RunMaxEnergy
           },
           energySettings: json{
                maxEnergy: MaxEnergy,
                energyRegenerationPerTick: EnergyRegenerationPerTick
           },
           deviationSettings: json{
                kickAngleDeviation: KickAngleDeviation,
                kickStrengthDeviation: KickStrengthDeviation,
                runDistanceDeviation: RunDistanceDeviation,
                energyRegenerationDeviation: EnergyRegenerationDeviation
           },
           agentRadius: AgentRadius
        },
        gameStates: GameStateJsons
    },
    ensureDirectoryExists("../gamelogs"),
    get_time(Time),
    TimeInt is round(Time),
    number_string(TimeInt, TimeString),
    string_concat("../gamelogs/game_", TimeString, Path_1),
    string_concat(Path_1, ".json", Path),
    open(Path, write, Stream),
    json_write_dict(Stream, GameJson, [width(0)]),
    close(Stream).

gameStatesToJson([], []).
gameStatesToJson([gameState(ball(vector(BallPositionX, BallPositionY), vector(BallVelocityX, BallVelocityY)), Agents, Round, score(Team0, Team1)) | T], [GameStateJson | GameStateJsons]) :-
    agentsToJson(Agents, AgentsJson),
    GameStateJson = json{
        ball: json{
            position: json{
                x: BallPositionX,
                y: BallPositionY
            },
            velocity: json{
                x: BallVelocityX,
                y: BallVelocityY
            }
        },
        agents: AgentsJson,
        round: Round,
        score: json{
            team0: Team0,
            team1: Team1
        }
    },
    gameStatesToJson(T, GameStateJsons).

agentsToJson([], []).
agentsToJson([agent(Name, Role, vector(PositionX, PositionY), Energy, team(Team), _, _) | T], [AgentJson | AgentJsons]) :-
    AgentJson = json{
        name: Name,
        role: Role,
        position: json{
            x: PositionX,
            y: PositionY
        },
        energy: Energy,
        team: Team
    },
    agentsToJson(T, AgentJsons).

%creates a directory if it doesnt exist
ensureDirectoryExists(Dir) :-
    exists_directory(Dir)->
    true
    ;
    make_directory(Dir).

% round order:
% ball moves
% goal checking
% if goal:
% award points and reset round
% if no goal:
% ball bounces from any walls
% ball velocity is dampened
% agents take actions
% agent collisions with walls/other agents are resolved
step(state(FieldSettings, AgentSettings, gameState(Ball, Agents, Round, Score)), state(FieldSettings, AgentSettings, gameState(NextBall, NextAgents, NextRound, NextScore))) :-
    % update ball and check goal
    updateBallPosition(Ball, NextBall_1),
    checkGoal(FieldSettings, NextBall_1, Score, NextScore) ->
        NextRound is Round + 1,
        resetRound(FieldSettings, AgentSettings, Agents, NextAgents, NextBall)
        ;
        % ball needs to be reupdated in branch because the branch doesn't recognize NextBall_1 for some reason
        % TODO: maybe look into a cleaner way to do this part
        NextRound = Round,
        NextScore = Score,
        updateBallPosition(Ball, NextBall_1),
        updateBallWallBounce(FieldSettings, NextBall_1, NextBall_2),
        dampenBall(FieldSettings, NextBall_2, NextBall_3),
        updateAgents(FieldSettings, AgentSettings, Agents, NextBall_3, NextAgents_1, NextBall),
        updateAgentCollisions(FieldSettings, AgentSettings, NextAgents_1, NextAgents).

% returns all agents to initial poition (defined within the agent itself)
% and returns the ball to the center with 0 velocity
resetRound(FieldSettings, AgentSettings, Agents, NextAgents, NextBall) :-
    resetAgents(FieldSettings, AgentSettings, Agents, NextAgents),
    FieldSettings = fieldSettings(vector(Width, Height), _, _, _, _),
    BallStartX is Width / 2,
    BallStartY is Height / 2,
    NextBall = ball(vector(BallStartX, BallStartY), vector(0,0)).

% recursively calls resetAgent on all agents 
% then mirrors only the position of the agent if they are on team(1)
% resetAgent is defined within agent.pl
resetAgents(_, _, [], []).
resetAgents(FieldSettings, AgentSettings, [Agent | T], [NextAgent | Agents]) :-
    resetAgent(FieldSettings, AgentSettings, Agent, NextAgent_1),
    mirrorAgentPositionIfTeam1(FieldSettings, NextAgent_1, NextAgent),
    resetAgents(FieldSettings, AgentSettings, T, Agents).

% idk what to call this predicate, i cant put it in resetAgents directly because NextAgent would not be available in the branch
mirrorAgentPositionIfTeam1(FieldSettings, Agent, NextAgent) :-
    Agent = agent(Name, Role, Position, Energy, team(1), RelativeInitialPosition, Controller) ->
    mirrorPosition(FieldSettings, Position, MirroredPosition),
    NextAgent = agent(Name, Role, MirroredPosition, Energy, team(1), RelativeInitialPosition, Controller)
    ;
    NextAgent = Agent.
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

%boeunces along an axis (assumes there is a wall at 0 and wallposition)
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
updateAgents(FieldSettings, AgentSettings, Agents, Ball, NextAgents, NextBall) :-
    updateAgents(FieldSettings, AgentSettings, Agents, [], Ball, NextAgents, NextBall).

updateAgents(_, _, [], _, Ball, [], Ball).
updateAgents(FieldSettings, AgentSettings, [Agent | T], ProcessedAgents, Ball, [NextAgent | Agents], NextBall) :-
    append(T, ProcessedAgents, OtherAgents),
    updateAgent(FieldSettings, AgentSettings, OtherAgents, Agent, Ball, NextAgent, NextBall_1),
    append([NextAgent], ProcessedAgents, NextProcessedAgents),
    updateAgents(FieldSettings, AgentSettings, T, NextProcessedAgents, NextBall_1, Agents, NextBall).

% sends information about the game to the agent's controller
% then calls takeAction() on the action to process that action
updateAgent(FieldSettings, AgentSettings, OtherAgents, Agent, Ball, NextAgent, NextBall) :-
    Agent = agent(_, _, _, _, team(0), _, Controller),
    control(Controller, FieldSettings, AgentSettings, Agent, OtherAgents, Ball, Action),
    takeAction(Action, AgentSettings, Agent, Ball, NextAgent, NextBall), !.

% team(1) agents are "mirrored" so that from their controller's perspective, they appear to be team(0),
% this is so that when programming the ai you only need to program for team(0) and the ai will still
% work when applied to team(1)
updateAgent(FieldSettings, AgentSettings, OtherAgents, Agent, Ball, NextAgent, NextBall) :-
    Agent = agent(_, _, _, _, team(1), _, Controller),
    mirrorAgent(FieldSettings, Agent, MirroredAgent),
    mirrorAgents(FieldSettings, OtherAgents, MirroredOtherAgents),
    mirrorBall(FieldSettings, Ball, MirroredBall),
    control(Controller, FieldSettings, AgentSettings, MirroredAgent, MirroredOtherAgents, MirroredBall, Action),
    mirrorAction(FieldSettings, Action, MirroredAction),
    takeAction(MirroredAction, AgentSettings, Agent, Ball, NextAgent, NextBall), !.

% handle the move command
% if agent doesn't have enough energy to do so (or the DistanceFactor is invalid) defaults to the rest command
takeAction(action(move, TargetPosition, DistanceFactor), AgentSettings, Agent, Ball, NextAgent, NextBall) :-
    % checks if the action is valid (no cheating) (if the predicate evaluates to true then the action is valid)
    % then also checks if agent actually has enough energy to move that far
    (call(action(move, TargetPosition, DistanceFactor)),
    canMove(AgentSettings, Agent, DistanceFactor)) ->
        moveTowards(AgentSettings, Agent, TargetPosition, DistanceFactor, NextAgent),
        NextBall = Ball
        ;
        rest(AgentSettings, Agent, NextAgent),
        NextBall = Ball.

% handle the kick command
% if agent doesn't have enough energy to do so or the ball isn't within range defaults to the rest command
takeAction(action(kick, KickTowardsPosition, KickStrengthFactor), AgentSettings, Agent, Ball, NextAgent, NextBall) :-
    % checks if the action is valid (no cheating) (if the predicate evaluates to true then the action is valid)
    % then also checks if agent can actually kick
    (call(action(kick, KickTowardsPosition, KickStrengthFactor)),
    canKick(AgentSettings, Agent, Ball, KickStrengthFactor)) ->
        kick(AgentSettings, Agent, Ball, KickTowardsPosition, KickStrengthFactor, NextAgent, NextBall)
        ;
        rest(AgentSettings, Agent, NextAgent),
        NextBall = Ball.

%handle the rest command
takeAction(action(rest), AgentSettings, Agent, Ball, NextAgent, NextBall) :-
    rest(AgentSettings, Agent, NextAgent),
    NextBall = Ball.

% checks and resolves for all agent collisions
% notably only passes in OtherUnresolvedAgents for agent - agent collision detection
% since any agent already processed by resolveAgentCollision would have already checked
% for it's collision with all the other agents so they do not need to be checked for again
updateAgentCollisions(_, _, [], []).
updateAgentCollisions(FieldSettings, AgentSettings, [Agent | OtherUnresolvedAgents], [NextAgent | Agents]) :-
    resolveAgentWallCollision(FieldSettings, Agent, NextAgent_1),
    resolveAgentCollision(AgentSettings, NextAgent_1, OtherUnresolvedAgents, NextAgent, NextOtherAgents),
    updateAgentCollisions(FieldSettings, AgentSettings, NextOtherAgents, Agents).

% check Agent against every agent in OtherAgents
% if Agent is colliding with the other agent resolve it
resolveAgentCollision(_, Agent, [], Agent, []).
resolveAgentCollision(AgentSettings, Agent, [OtherAgent | T], NextAgent, [NextOtherAgent | NextOtherAgents]) :-
    isColliding(AgentSettings, Agent, OtherAgent) ->
    resolveCollision(AgentSettings, Agent, OtherAgent, NextAgent_1, NextOtherAgent),
    resolveAgentCollision(AgentSettings, NextAgent_1, T, NextAgent, NextOtherAgents)
    ;
    NextOtherAgent = OtherAgent,
    resolveAgentCollision(AgentSettings, Agent, T, NextAgent, NextOtherAgents).


resolveAgentWallCollision(fieldSettings(vector(Width, Height), _, _, _, _), agent(Name, Role, vector(PositionX, PositionY), Energy, Team, RelativeInitialPosition, Controller), agent(Name, Role, vector(NextPositionX, NextPositionY), Energy, Team, RelativeInitialPosition, Controller)) :-
    resolveAgentWallCollision(Width, PositionX, NextPositionX),
    resolveAgentWallCollision(Height, PositionY, NextPositionY).

% snaps agent to wall (assuming there is a wall at 0 and WallPosition)
resolveAgentWallCollision(WallPosition, Position, NextPosition) :-
    Position < 0 ->
    NextPosition = 0
    ;
    Position > WallPosition ->
    NextPosition = WallPosition
    ;
    NextPosition = Position.

% mirroring, basically mirrors all the variables such that from the controller's perspective the game is always from team(0)'s perpective
% so that the ai only needs to be implemented for team(0)
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

mirrorAgent(FieldSettings, agent(Name, Role, Position, Energy, Team, RelativeInitialPosition, Controller), agent(Name, Role, MirroredPosition, Energy, MirroredTeam, RelativeInitialPosition, Controller)) :-
    mirrorPosition(FieldSettings, Position, MirroredPosition),
    mirrorTeam(Team, MirroredTeam).

mirrorAgents(_, [], []).
mirrorAgents(FieldSettings, [Agent | T], [MirroredAgent | MirroredAgents]) :-
    mirrorAgent(FieldSettings, Agent, MirroredAgent),
    mirrorAgents(FieldSettings, T, MirroredAgents).