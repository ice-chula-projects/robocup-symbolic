import Vector2D from "./lib/Vector2D.js"

export type GameLog = {
    fieldSettings: FieldSettings,
    agentSettings: AgentSettings,
    gameStates: GameState[]
}

export type FieldSettings = {
    dimensions: {
        width: number,
        height: number
    },
    goalSize: number,
    ballDampening: number,
    ballWallDampening: number,
    winningScore: number
}

export type AgentSettings = {
    kickSettings: {
        kickReach: number,
        kickMaxStrength: number,
        kickMaxEnergy: number,
    
    },
    runSettings: {
        runMaxDistance: number,
        runBaseEnergy: number,
    },
    energySettings: {
        maxEnergy: number,
        energyRegenerationPerTick: number,
    },
    deviationSettings: {
        kickAngleDeviation: number,
        kickStrengthDeviation: number,
        runDistanceDeviation: number,
        energyRegenerationDeviation: number
    },
    agentRadius: number
}

export type GameState = {
    ball: {
        position: {
            x: number,
            y: number
        },
        velocity: {
            x: number,
            y: number
        }
    },
    agents: Agent[],
    round: number,
    score: {
        team0: number,
        team1: number
    }
}

export type Agent = {
    name: string,
    role: string,
    position: {
        x: number,
        y: number
    },
    energy: number,
    team: number
}

export type GameStateProcessed = {
    ball: {
        position: Vector2D,
        velocity: Vector2D
    },
    agents: AgentProcessed[],
    round: number,
    score: {
        team0: number,
        team1: number
    }
}

export type AgentProcessed = {
    name: string,
    role: string,
    position: Vector2D,
    energy: number,
    team: number
}

export default class Playback {
    fileInput: HTMLInputElement;
    loadButton: HTMLButtonElement;

    currentGameLog: GameLog;
    currentStateIndex: number = 0;
    get gameLength(): number {
        if (this.currentGameLog == null) return null;
        return this.currentGameLog.gameStates.length;
    }
    #loaded = false;

    get loaded(): boolean{
        return this.#loaded;
    }

    #lastGameStateProcessed = null;

    #targetTps: number = 60;
    #intervalId: number;

    get running(): boolean {
        return this.#intervalId != null;
    }

    get targetTps(): number {
        return this.#targetTps;
    }

    set targetTps(targetTps: number) {
        this.#targetTps = targetTps;
        if (this.running) {
            this.stop();
            this.start();
        }
    }

    constructor(fileInput: HTMLInputElement, loadButton: HTMLButtonElement) {
        this.fileInput = fileInput;
        this.loadButton = loadButton;

        this.loadButton.addEventListener("click", this.load.bind(this));
    }

    start(): void {
        if (this.running) throw new Error("Tried to start playback that is already running");
        this.#intervalId = setInterval(this.update.bind(this), 1000 / this.targetTps);
    }

    stop(): void {
        if (!this.running) throw new Error("Tried to stop playback that isn't running");
        clearInterval(this.#intervalId);
        this.#intervalId = null;
    }

    update(): void {
        if (this.currentGameLog == null) return;

        this.currentStateIndex += 1;
        if (this.currentStateIndex >= this.gameLength) this.currentStateIndex = 0;
    }

    getCurrentState(): GameStateProcessed {
        if (!this.#loaded) return this.#lastGameStateProcessed;
        const gameState = this.currentGameLog.gameStates[this.currentStateIndex];

        const agentsProcessed: AgentProcessed[] = gameState.agents.map(agent => ({
            ...agent,
            position: new Vector2D(agent.position.x, agent.position.y)
        }))

        const ball = gameState.ball;
        const GameStateProcessed = {
            ...gameState,
            ball: {
                position: new Vector2D(ball.position.x, ball.position.y),
                velocity: new Vector2D(ball.velocity.x, ball.velocity.y)
            },
            agents: agentsProcessed
        }

        this.#lastGameStateProcessed = GameStateProcessed;
        return GameStateProcessed;
    }


    async load(): Promise<void> {
        this.#loaded = false;
        this.currentGameLog = JSON.parse(await this.fileInput.files[0].text());
        this.#loaded = true;
        this.currentStateIndex = 0;
    }
}