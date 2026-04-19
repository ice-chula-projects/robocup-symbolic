:- use_module(simulation, [runSimulation/3]).

% runs the simulation with predefined default settings
runSimulation :- 
    FieldSettings = fieldSettings(
        vector(1200,1000), % field size
        0.2,   % goal size (0.2 means 20% of the height of the field)
        0.987, % ball dampening (the ball's velocity is multiplied by this every tick)
        0.9,   % ball wall dampening (the ball's velocity is multiplied by this on wall collision)
        3      % winning score
    ),
    
    AgentSettings = agentSettings(
        kickSettings(
            15,   % kick reach, the max distance an agent is able to kick the ball
            13,   % kick max strength, the max strength an agent is able to kick (13 meaning the agent can change the velocity of the ball by 13 units/s)
            50    % kick max energy, the amount of energy expended upon kicking with max strength, kicking with lower strength will interpolate the energy cost using this value
        ),
        runSettings(
            11,   % run max distance, the max distance an agent is able to run in 1 simulation tick
            75    % run max energy, the energy spent upon running the max distance, running at slower speeds will interpolate the energy cost. Running faster will always be less energy efficient
        ),
        energySettings(
            500,  % max energy, the max energy an agent is able to store
            10,   % energy regeneration per tick, how much energy on average does the agent regenerate every simulation tick
        ),
        deviationSettings(
            3,    % kick angle deviation, when an agent kicks in a direction, the actual kick direction is deviated by +/- this many degrees 
            0.2,  % kick strength deviation, when an agent kicks at some strength, the actual strength is +/- this many percent (where 0.2 means 20%)
            0.25, % run distance deviation, when an agent runs some distance, the actual distance ran is deviated by +/- this many percent (where 0.2 means 20%)
            0.25  % energy regeneration deviation, when an agent regenerates energy, the actual energy regenerated is deviated by +/- this many percent (where 0.2 means 20%)
        ),
        10        % agent radius, the radius of the circles that the agents are modeled as for collision detection.
    ),

    % agents are defined as:
    % agent(Name, Role, CurrentPosition, CurrentEnergy, Team, InitialPosition, Controller)
    % Name and Role are only used in the visualization system
    % CurrentPosition and CurrentEnergy are only used internally by the simulation and do not have to be manually initialized
    % Team determines which team the agent is in, with team(0) being left and team(1) being right
    % InitialPosition is in percentages
    % for example (0.4, 0.45) means 40% away from your team's goal, 45% away from the top of the field
    % on a field that is 100x100:
    % a team(0) agent would start at (40, 45)
    % while a team(1) agent would start at (60,45)
    % Controller determines which strategy the agent will employ, those strategies are defined in controller.pl
    Agents = [
        agent('Alice', 'Striker',           _, _, team(0), vector(0.40, 0.45), controller(striker)),
        agent('Bob', 'Striker',             _, _, team(1), vector(0.40, 0.55), controller(striker)),
        agent('Charlie', 'Center Back',     _, _, team(0), vector(0.05, 0.50), controller(back)),
        agent('David', 'Center Back',       _, _, team(1), vector(0.05, 0.50), controller(back)),
        agent('Ellie', 'Top Back',          _, _, team(0), vector(0.20, 0.20), controller(back)),
        agent('Fiyero', 'Top Back',         _, _, team(1), vector(0.20, 0.20), controller(back)),
        agent('Gabriel', 'Bottom Back',     _, _, team(0), vector(0.20, 0.80), controller(back)),
        agent('Holson', 'Bottom Back',      _, _, team(1), vector(0.20, 0.80), controller(back)),
        agent('Igris', 'Goalkeeper',        _, _, team(0), vector(0.00, 0.50), controller(goalkeeper)),
        agent('Joe',  'Goalkeeper',         _, _, team(1), vector(0.00, 0.50), controller(goalkeeper)),
        % Kira and L where removed in the process of development
        % may they rest in peace
        agent('Mario', 'Top Midfield',      _, _, team(0), vector(0.35, 0.15), controller(topdynamic)),
        agent('Nessa', 'Top Midfield',      _, _, team(1), vector(0.35, 0.15), controller(topdynamic)),
        agent('Orpheus', 'Bottom Midfield', _, _, team(0), vector(0.35, 0.85), controller(bottomdynamic)),
        agent('Penny', 'Bottom Midfield',   _, _, team(1), vector(0.35, 0.85), controller(bottomdynamic))
    ],
    runSimulation(FieldSettings, AgentSettings, Agents).