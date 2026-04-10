import KeyboardInput from "./KeyboardInput.js";
import Vector2D from "./lib/Vector2D.js";
export default class Camera {
    canvas;
    playback;
    position = Vector2D.zero;
    zoom = 1;
    cameraSpeed = 10;
    zoomSpeed = .1;
    zoomBounds = { min: 0.1, max: 10 };
    backgroundColor = "darkgreen";
    ballRadius = 5;
    ballColor = "white";
    borderWidth = 3;
    borderColor = "white";
    team0Color = "blue";
    team1Color = "red";
    goalWidth = 25;
    agentTextMargin = 2;
    font = "arial";
    fontSize = 12;
    textColor = "white";
    energyBarColor = "lime";
    energyBarMargin = 1;
    energyBarThickness = 2;
    rendering = {
        energyBar: true,
        agentNameAndRole: true
    };
    lastMouseData = {};
    #targetFps = 60;
    #intervalId;
    get running() {
        return this.#intervalId != null;
    }
    get targetFps() {
        return this.#targetFps;
    }
    set targetFps(targetFps) {
        this.#targetFps = targetFps;
        if (this.running) {
            this.stop();
            this.start();
        }
    }
    constructor(canvas, playback) {
        this.canvas = canvas;
        this.canvas.width = this.canvas.clientWidth;
        this.canvas.height = this.canvas.clientHeight;
        this.playback = playback;
        window.addEventListener("wheel", this.handleScroll.bind(this));
        window.addEventListener("mousemove", this.handleMouseDrag.bind(this));
        window.addEventListener("resize", () => {
            this.canvas.width = this.canvas.clientWidth;
            this.canvas.height = this.canvas.clientHeight;
        });
        window.addEventListener("mouseup", () => {
            this.lastMouseData = {};
        });
    }
    start() {
        if (this.running)
            throw new Error("Tried to start camera that is already running");
        this.#intervalId = setInterval(this.update.bind(this), 1000 / this.targetFps);
    }
    stop() {
        if (!this.running)
            throw new Error("Tried to stop camera that isn't running");
        clearInterval(this.#intervalId);
        this.#intervalId = null;
    }
    update() {
        this.handleInput();
        this.clear();
        this.render();
    }
    render() {
        const gameState = this.playback.getCurrentState();
        if (gameState == null)
            return;
        this.drawField();
        this.drawBall(gameState);
        this.drawAgents(gameState);
    }
    drawField() {
        const context = this.canvas.getContext("2d");
        //draw background
        context.fillStyle = this.backgroundColor;
        context.fillRect(0, 0, this.canvas.width, this.canvas.height);
        const topLeft = this.project(Vector2D.zero);
        const fieldDimensions = this.playback.currentGameLog.fieldSettings.dimensions;
        context.fillStyle = this.borderColor;
        context.strokeStyle = this.borderColor;
        const borderWidth = this.borderWidth * this.zoom;
        context.lineWidth = borderWidth;
        //value to nudge the by so that the ball appears to bounce when it's edge hits instead of it's center
        const nudge = this.ballRadius * this.zoom;
        context.beginPath();
        context.rect(topLeft.x - nudge, topLeft.y - nudge, fieldDimensions.width * this.zoom + 2 * nudge, fieldDimensions.height * this.zoom + 2 * nudge);
        context.closePath();
        context.stroke();
        //draw goals
        const goalHeight = this.playback.currentGameLog.fieldSettings.goalSize * fieldDimensions.height;
        const team0GoalTopLeft = this.project(new Vector2D(-this.goalWidth, -goalHeight / 2 + fieldDimensions.height / 2));
        const team1GoalTopLeft = this.project(new Vector2D(fieldDimensions.width, -goalHeight / 2 + fieldDimensions.height / 2));
        context.beginPath();
        context.rect(team0GoalTopLeft.x, team0GoalTopLeft.y, this.goalWidth * this.zoom - nudge, goalHeight * this.zoom);
        context.rect(team1GoalTopLeft.x + nudge, team1GoalTopLeft.y, this.goalWidth * this.zoom, goalHeight * this.zoom);
        context.closePath();
        context.fill();
    }
    drawBall(gameState) {
        const context = this.canvas.getContext("2d");
        const position = this.project(gameState.ball.position);
        context.fillStyle = this.ballColor;
        context.beginPath();
        context.arc(position.x, position.y, this.ballRadius * this.zoom, 0, 2 * Math.PI);
        context.closePath();
        context.fill();
    }
    drawAgent(agent) {
        const context = this.canvas.getContext("2d");
        let agentRadius = this.playback.currentGameLog.agentSettings.agentRadius;
        //backwards compatability
        if (agentRadius == null)
            agentRadius = 10;
        context.fillStyle = agent.team == 0 ? this.team0Color : this.team1Color;
        context.font = `${Math.round(this.fontSize * this.zoom)}px ${this.font}`;
        context.textAlign = "center";
        context.beginPath();
        const position = this.project(agent.position);
        context.moveTo(position.x, position.y);
        context.arc(position.x, position.y, agentRadius * this.zoom, 0, 2 * Math.PI);
        context.closePath();
        context.fill();
        //draw energy bar
        if (this.rendering.energyBar) {
            // const energyBarFullWidth = this.energyBarRelativeWidthFactor * agentRadius * this.zoom;
            // const energyFraction = agent.energy / this.playback.currentGameLog.agentSettings.energySettings.maxEnergy;
            // const energyBarWidth = energyBarFullWidth * energyFraction;
            // context.fillStyle = this.energyBarColor;
            // context.strokeStyle = "white";
            // context.lineWidth = this.energyBarOutlineThickness * this.zoom;
            // context.fillRect(position.x - energyBarFullWidth/2, position.y + (agentRadius + this.agentInformationMargin) * this.zoom, energyBarWidth, this.energyBarHeight * this.zoom)
            // context.strokeRect(position.x - energyBarFullWidth/2, position.y + (agentRadius + this.agentInformationMargin) * this.zoom, energyBarFullWidth, this.energyBarHeight * this.zoom);
            const energyFraction = agent.energy / this.playback.currentGameLog.agentSettings.energySettings.maxEnergy;
            const radius = (agentRadius + this.energyBarMargin + this.energyBarThickness / 2) * this.zoom;
            context.strokeStyle = this.energyBarColor;
            context.lineWidth = this.energyBarThickness * this.zoom;
            context.beginPath();
            if (energyFraction == 1)
                context.arc(position.x, position.y, radius, 0, 2 * Math.PI);
            else
                context.arc(position.x, position.y, radius, -Math.PI / 2, (-Math.PI / 2) + 2 * Math.PI * (1 - energyFraction), true);
            context.stroke();
            context.closePath();
        }
        //draw text
        if (this.rendering.agentNameAndRole) {
            context.fillStyle = this.textColor;
            context.fillText(`Role: ${agent.role}`, position.x, position.y - (agentRadius + this.agentTextMargin) * this.zoom);
            context.fillText(`Name: ${agent.name}`, position.x, position.y - (agentRadius + this.fontSize + this.agentTextMargin) * this.zoom);
        }
    }
    drawAgents(gameState) {
        for (const agent of gameState.agents) {
            this.drawAgent(agent);
        }
    }
    handleInput() {
        //zooming
        const relativeZoomSpeed = this.zoomSpeed * this.zoom;
        if (KeyboardInput.keys.KeyQ)
            this.zoom += relativeZoomSpeed;
        if (KeyboardInput.keys.KeyE)
            this.zoom -= relativeZoomSpeed;
        if (this.zoom > this.zoomBounds.max)
            this.zoom = this.zoomBounds.max;
        if (this.zoom < this.zoomBounds.min)
            this.zoom = this.zoomBounds.min;
        //movement
        const relativeSpeed = this.cameraSpeed / this.zoom;
        if (KeyboardInput.keys.KeyS)
            this.position.y += relativeSpeed;
        if (KeyboardInput.keys.KeyW)
            this.position.y -= relativeSpeed;
        if (KeyboardInput.keys.KeyA)
            this.position.x -= relativeSpeed;
        if (KeyboardInput.keys.KeyD)
            this.position.x += relativeSpeed;
    }
    handleScroll(e) {
        if (e.target != this.canvas)
            return;
        let zoomChange = KeyboardInput.keys.ShiftLeft ? -e.deltaY / 2000 : (-e.deltaY / 2000) * 5;
        this.zoom += zoomChange * this.zoom;
        if (this.zoom > this.zoomBounds.max)
            this.zoom = this.zoomBounds.max;
        if (this.zoom < this.zoomBounds.min)
            this.zoom = this.zoomBounds.min;
    }
    handleMouseDrag(e) {
        if (e.target != this.canvas || e.buttons == 0 || e.buttons == 4)
            return;
        e.preventDefault();
        if (this.lastMouseData.x == null || this.lastMouseData.y == null) {
            this.lastMouseData.x = e.x;
            this.lastMouseData.y = e.y;
        }
        else {
            let dx = e.x - this.lastMouseData.x;
            let dy = e.y - this.lastMouseData.y;
            this.position.x -= dx / this.zoom;
            this.position.y -= dy / this.zoom;
            this.lastMouseData.x = e.x;
            this.lastMouseData.y = e.y;
        }
    }
    project(position) {
        return position.sub(this.position).scale(this.zoom).add(new Vector2D(this.canvas.width / 2, this.canvas.height / 2));
    }
    clear() {
        const context = this.canvas.getContext("2d");
        context.clearRect(0, 0, this.canvas.width, this.canvas.height);
    }
}
