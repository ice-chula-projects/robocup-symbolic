import Camera from "./Camera.js";
import Vector2D from "./lib/Vector2D.js";
export default class Playback {
    fileInput;
    loadButton;
    camera;
    currentGameLog;
    #currentStateIndex = 0;
    //how many ticks to wait on round transition
    roundTransitionBuffer = 120;
    #roundTransitionTimer = null;
    get currentStateIndex() {
        return this.#currentStateIndex;
    }
    set currentStateIndex(nextIndex) {
        if (nextIndex >= this.gameLength)
            nextIndex = this.gameLength - 1;
        if (nextIndex < 0)
            nextIndex = 0;
        this.#currentStateIndex = nextIndex;
    }
    get isRoundTransition() {
        return this.#roundTransitionTimer > 0;
    }
    get gameLength() {
        if (this.currentGameLog == null)
            return null;
        return this.currentGameLog.gameStates.length;
    }
    get agentsLength() {
        if (this.currentGameLog == null)
            return null;
        return this.currentGameLog.gameStates[0].agents.length;
    }
    get currentRound() {
        if (this.currentGameLog == null)
            return null;
        return this.currentGameLog.gameStates[this.currentStateIndex].round;
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
    constructor(fileInput, loadButton, canvas) {
        this.fileInput = fileInput;
        this.loadButton = loadButton;
        this.camera = new Camera(canvas, this);
        this.camera.start();
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
    toggleRunning() {
        if (this.running)
            this.stop();
        else
            this.start();
    }
    update() {
        if (this.currentGameLog == null)
            return;
        if (this.isRoundTransition) {
            this.#roundTransitionTimer--;
            if (this.#roundTransitionTimer == 0)
                this.incrementStateIndex();
            return;
        }
        //if next frame is a different round, enable the round transition
        if (this.currentGameLog.gameStates[this.currentStateIndex + 1].round != this.currentRound) {
            this.#roundTransitionTimer = this.roundTransitionBuffer;
            return;
        }
        this.incrementStateIndex();
    }
    incrementStateIndex() {
        let nextStateIndex = this.currentStateIndex + 1;
        //due to a quirk of the simulation, the very last frame of a fully completed game is actually the beginning of a round that is never played
        //since the round is reset before the simulation exits 
        if (nextStateIndex >= this.gameLength - 1) {
            this.#roundTransitionTimer = Infinity;
            nextStateIndex = this.currentStateIndex;
        }
        ;
        this.currentStateIndex = nextStateIndex;
    }
    processGameState(gameState) {
        const agents = gameState.agents;
        const agentsProcessed = [];
        for (let i = 0; i < agents.length; i++) {
            const agent = agents[i];
            agentsProcessed.push({
                ...agent,
                position: new Vector2D(agent.position.x, agent.position.y),
                id: i
            });
        }
        const ball = gameState.ball;
        const ballProcessed = {
            position: new Vector2D(ball.position.x, ball.position.y),
            velocity: new Vector2D(ball.velocity.x, ball.velocity.y)
        };
        // since the round transition tick is the tick before the ball enters the goal
        // during a round transition we fake the ball's position by 1 frame so that
        // the ball appears to be inside of the goal 
        if (this.isRoundTransition)
            ballProcessed.position = ballProcessed.position.add(ballProcessed.velocity);
        return {
            ...gameState,
            ball: ballProcessed,
            agents: agentsProcessed
        };
    }
    //returns a gamestate n steps ahead/behind the current state
    getRelativeState(n) {
        if (!this.#loaded)
            return this.#lastGameStateProcessed;
        let index = this.currentStateIndex + n;
        if (index < 0)
            index = 0;
        if (index >= this.gameLength)
            index = this.gameLength - 1;
        const gameState = this.currentGameLog.gameStates[index];
        return this.processGameState(gameState);
    }
    getCurrentState() {
        if (!this.#loaded)
            return this.#lastGameStateProcessed;
        const gameState = this.currentGameLog.gameStates[this.currentStateIndex];
        const GameStateProcessed = this.processGameState(gameState);
        this.#lastGameStateProcessed = GameStateProcessed;
        return GameStateProcessed;
    }
    async load() {
        this.#loaded = false;
        this.currentGameLog = JSON.parse(await this.fileInput.files[0].text());
        this.#loaded = true;
        this.#roundTransitionTimer = null;
        this.currentStateIndex = 0;
        this.camera.position = new Vector2D(this.currentGameLog.fieldSettings.dimensions.width / 2, this.currentGameLog.fieldSettings.dimensions.height / 2);
        this.camera.zoom = 1;
    }
}
