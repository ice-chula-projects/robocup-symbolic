import KeyboardInput from "./KeyboardInput.js";
import Vector2D from "./lib/Vector2D.js"
import Playback, { GameStateProcessed } from "./Playback.js";

export default class Camera {
    canvas: HTMLCanvasElement;
    playback: Playback;

    position: Vector2D = Vector2D.zero;
    zoom: number = 1;

    cameraSpeed: number = 10;
    zoomSpeed: number = .1;
    zoomBounds: { min: number, max: number } = { min: 0.1, max: 10 };

    ballRadius: number = 5;
    ballColor: string = "white";
    borderWidth: number = 3;
    borderColor: string = "white";
    team0Color: string = "blue";
    team1Color: string = "red";
    playerRadius: number = 10;
    goalWidth: number = 25;
    
    lastMouseData: {
        x: number | null
        y: number | null
    } = {} as typeof this.lastMouseData;

    #targetFps: number = 60;
    #intervalId: number;

    get running(): boolean {
        return this.#intervalId != null;
    }

    get targetFps(): number {
        return this.#targetFps;
    }

    set targetFps(targetFps: number) {
        this.#targetFps = targetFps;
        if (this.running) {
            this.stop();
            this.start();
        }
    }

    constructor(canvas: HTMLCanvasElement, playback: Playback) {
        this.canvas = canvas;
        this.canvas.width = this.canvas.clientWidth;
        this.canvas.height = this.canvas.clientHeight;
        
        this.playback = playback;

        window.addEventListener("wheel", this.handleScroll.bind(this))
        window.addEventListener("mousemove", this.handleMouseDrag.bind(this))

        window.addEventListener("resize", () => {
            this.canvas.width = this.canvas.clientWidth;
            this.canvas.height = this.canvas.clientHeight;
        })
        window.addEventListener("mouseup", () => {
            this.lastMouseData = {} as typeof this.lastMouseData;
        })
    }

    start(): void {
        if (this.running) throw new Error("Tried to start camera that is already running");
        this.#intervalId = setInterval(this.update.bind(this), 1000 / this.targetFps);
    }

    stop(): void {
        if (!this.running) throw new Error("Tried to stop camera that isn't running");
        clearInterval(this.#intervalId);
        this.#intervalId = null;
    }

    update() {
        this.handleInput()

        this.clear();
        this.render();
    }

    render() {
        const gameState: GameStateProcessed = this.playback.getCurrentState();
        if (gameState == null) return;
        this.drawField();
        this.drawBall(gameState);
        this.drawAgents(gameState);
    }

    drawField() {
        const context = this.canvas.getContext("2d");

        const topLeft = this.project(Vector2D.zero);
        const fieldDimensions = this.playback.currentGameLog.fieldSettings.dimensions;

        context.fillStyle = this.borderColor;
        context.strokeStyle = this.borderColor;
        const borderWidth = this.borderWidth * this.zoom;
        context.lineWidth = borderWidth
        
        //value to nudge the by so that the ball appears to bounce when it's edge hits instead of it's center
        const nudge = this.ballRadius * this.zoom;
        context.beginPath();
        context.rect(topLeft.x - nudge, topLeft.y - nudge, fieldDimensions.width * this.zoom + 2 * nudge,  fieldDimensions.height * this.zoom + 2 * nudge);
        context.closePath();
        context.stroke();

        //draw goals
        const goalHeight = this.playback.currentGameLog.fieldSettings.goalSize * fieldDimensions.height;
        const team0GoalTopLeft = this.project(new Vector2D(-this.goalWidth, -goalHeight/2 + fieldDimensions.height/2))
        const team1GoalTopLeft = this.project(new Vector2D(fieldDimensions.width, -goalHeight/2 + fieldDimensions.height/2))
        context.beginPath();
        context.rect(team0GoalTopLeft.x, team0GoalTopLeft.y, this.goalWidth * this.zoom - nudge, goalHeight * this.zoom);
        context.rect(team1GoalTopLeft.x + nudge, team1GoalTopLeft.y, this.goalWidth * this.zoom, goalHeight * this.zoom);
        context.closePath();

        context.fill();
    
    }

    drawBall(gameState: GameStateProcessed) {
        const context = this.canvas.getContext("2d");
        const position = this.project(gameState.ball.position);

        context.fillStyle = this.ballColor;
        context.beginPath();
        context.arc(position.x, position.y, this.ballRadius * this.zoom, 0, 2 * Math.PI);
        context.closePath();
        context.fill();
    }

    drawAgents(gameState: GameStateProcessed){
        const context = this.canvas.getContext("2d");
        const agents = gameState.agents;

        //draw team 0
        context.fillStyle = this.team0Color;
        context.beginPath();
        for(const agent of agents.filter(agent => agent.team == 0)){
            const position = this.project(agent.position);
            const radius = this.playerRadius * this.zoom;

            context.arc(position.x, position.y, radius, 0, 2 * Math.PI);
        }
        context.closePath();
        context.fill();
    
        
        //draw team 0
        context.fillStyle = this.team1Color;
        context.beginPath();
        for(const agent of agents.filter(agent => agent.team == 1)){
            const position = this.project(agent.position);
            const radius = this.playerRadius * this.zoom;

            context.arc(position.x, position.y, radius, 0, 2 * Math.PI);
        }
        context.closePath();
        context.fill();
    }

    handleInput(): void {
        //zooming
        const relativeZoomSpeed = this.zoomSpeed * this.zoom;
        if (KeyboardInput.keys.KeyQ) this.zoom += relativeZoomSpeed;
        if (KeyboardInput.keys.KeyE) this.zoom -= relativeZoomSpeed;
        if (this.zoom > this.zoomBounds.max) this.zoom = this.zoomBounds.max;
        if (this.zoom < this.zoomBounds.min) this.zoom = this.zoomBounds.min;

        //movement
        const relativeSpeed = this.cameraSpeed / this.zoom;
        if (KeyboardInput.keys.KeyS) this.position.y += relativeSpeed;
        if (KeyboardInput.keys.KeyW) this.position.y -= relativeSpeed;
        if (KeyboardInput.keys.KeyA) this.position.x -= relativeSpeed;
        if (KeyboardInput.keys.KeyD) this.position.x += relativeSpeed;
    }

    handleScroll(e: WheelEvent) {
        if (e.target != this.canvas) return;
        let zoomChange = KeyboardInput.keys.ShiftLeft ? -e.deltaY / 2000 : (-e.deltaY / 2000) * 5;

        this.zoom += zoomChange * this.zoom;
        if (this.zoom > this.zoomBounds.max) this.zoom = this.zoomBounds.max;
        if (this.zoom < this.zoomBounds.min) this.zoom = this.zoomBounds.min;
    }

    handleMouseDrag(e: MouseEvent) {
        if (e.target != this.canvas || e.buttons == 0 || e.buttons == 4) return;
        e.preventDefault();

        if (this.lastMouseData.x == null || this.lastMouseData.y == null) {
            this.lastMouseData.x = e.x;
            this.lastMouseData.y = e.y;
        } else {
            let dx = e.x - this.lastMouseData.x;
            let dy = e.y - this.lastMouseData.y;

            this.position.x -= dx / this.zoom;
            this.position.y -= dy / this.zoom;

            this.lastMouseData.x = e.x;
            this.lastMouseData.y = e.y;
        }
    }

    project(position: Vector2D): Vector2D {
        return position.sub(this.position).scale(this.zoom).add(new Vector2D(this.canvas.width/2, this.canvas.height/2));
    }

    clear(): void {
        const context = this.canvas.getContext("2d");
        context.clearRect(0, 0, this.canvas.width, this.canvas.height);
    }
}