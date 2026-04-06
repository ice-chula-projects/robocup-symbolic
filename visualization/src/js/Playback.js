import Vector2D from "./lib/Vector2D.js";
export default class Playback {
    fileInput;
    loadButton;
    currentGameLog;
    currentStateIndex = 0;
    get gameLength() {
        if (this.currentGameLog == null)
            return null;
        return this.currentGameLog.gameStates.length;
    }
    #loaded = false;
    get loaded() {
        return this.#loaded;
    }
    #lastGameStateProcessed = null;
    #targetTps = 60;
    #intervalId;
    get running() {
        return this.#intervalId != null;
    }
    get targetTps() {
        return this.#targetTps;
    }
    set targetTps(targetTps) {
        this.#targetTps = targetTps;
        if (this.running) {
            this.stop();
            this.start();
        }
    }
    constructor(fileInput, loadButton) {
        this.fileInput = fileInput;
        this.loadButton = loadButton;
        this.loadButton.addEventListener("click", this.load.bind(this));
    }
    start() {
        if (this.running)
            throw new Error("Tried to start playback that is already running");
        this.#intervalId = setInterval(this.update.bind(this), 1000 / this.targetTps);
    }
    stop() {
        if (!this.running)
            throw new Error("Tried to stop playback that isn't running");
        clearInterval(this.#intervalId);
        this.#intervalId = null;
    }
    update() {
        if (this.currentGameLog == null)
            return;
        this.currentStateIndex += 1;
        if (this.currentStateIndex >= this.gameLength)
            this.currentStateIndex = 0;
    }
    getCurrentState() {
        if (!this.#loaded)
            return this.#lastGameStateProcessed;
        const gameState = this.currentGameLog.gameStates[this.currentStateIndex];
        const agentsProcessed = gameState.agents.map(agent => ({
            ...agent,
            position: new Vector2D(agent.position.x, agent.position.y)
        }));
        const ball = gameState.ball;
        const GameStateProcessed = {
            ...gameState,
            ball: {
                position: new Vector2D(ball.position.x, ball.position.y),
                velocity: new Vector2D(ball.velocity.x, ball.velocity.y)
            },
            agents: agentsProcessed
        };
        this.#lastGameStateProcessed = GameStateProcessed;
        return GameStateProcessed;
    }
    async load() {
        this.#loaded = false;
        this.currentGameLog = JSON.parse(await this.fileInput.files[0].text());
        this.#loaded = true;
        this.currentStateIndex = 0;
    }
}
