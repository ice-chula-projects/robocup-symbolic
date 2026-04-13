import KeyboardInput from "./KeyboardInput.js";
import Vector2D from "./lib/Vector2D.js";
export var CameraFollowTarget;
(function (CameraFollowTarget) {
    CameraFollowTarget[CameraFollowTarget["none"] = 0] = "none";
    CameraFollowTarget[CameraFollowTarget["ball"] = 1] = "ball";
    CameraFollowTarget[CameraFollowTarget["agent"] = 2] = "agent";
})(CameraFollowTarget || (CameraFollowTarget = {}));
export default class Camera {
    canvas;
    playback;
    position = Vector2D.zero;
    zoom = 1;
    cameraSpeed = 15;
    zoomSpeed = .1;
    zoomBounds = { min: 0.1, max: 10 };
    backgroundColor = "darkgreen";
    ballRadius = 5;
    ballColor = "white";
    ballVelocityLineScale = 5;
    ballVelocityLineColor = "red";
    borderWidth = 3;
    borderColor = "white";
    team0Color = "blue";
    team1Color = "red";
    goalWidth = 25;
    agentTextMargin = 5;
    font = "arial";
    fontSize = 12;
    textColor = "white";
    // agentVelocityFastThreshold: number = 5;
    // agentVelocityLineLength: number = 20;
    // agentVelocityLineSlowColor: string = "green";
    // agentVelocityLineFastColor: string = "red";
    agentVelocityLineScale = 5;
    agentVelocityLineColor = "white";
    energyBarColor = "lime";
    energyBarPersistance = 32;
    energyBarDepletedColor = "red";
    energyBarMargin = 1;
    energyBarThickness = 2;
    // how far away something can be (+ it's radius) to still be considered when selecting follow target
    followMargin = 50;
    followTarget = CameraFollowTarget.none;
    followedAgentId;
    infoTextSize = 30;
    rendering = {
        energyBar: true,
        agentName: true,
        agentRole: true,
        ballVelocityLine: false,
        agentVelocityLine: false
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
        window.addEventListener("mousedown", this.handleMouseMiddleClick.bind(this));
        window.addEventListener("keydown", this.handleKeyboardInput.bind(this));
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
        const gameState = this.playback.getCurrentState();
        if (gameState == null)
            return;
        this.handleMovementInput();
        if (this.followTarget != CameraFollowTarget.none)
            this.updateFollow(gameState);
        this.render(gameState);
    }
    updateFollow(gameState) {
        switch (this.followTarget) {
            case CameraFollowTarget.ball:
                this.position = gameState.ball.position.copy();
                break;
            case CameraFollowTarget.agent:
                this.position = gameState.agents[this.followedAgentId].position.copy();
                break;
        }
    }
    render(gameState) {
        this.clear();
        this.drawField();
        this.drawBall(gameState);
        this.drawAgents(gameState);
        this.drawText(gameState);
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
        //ball velocity line
        if (this.rendering.ballVelocityLine) {
            const predictedPosition = this.project(gameState.ball.position.add(gameState.ball.velocity.scale(this.ballVelocityLineScale)));
            context.strokeStyle = this.ballVelocityLineColor;
            context.beginPath();
            context.moveTo(position.x, position.y);
            context.lineTo(predictedPosition.x, predictedPosition.y);
            context.closePath();
            context.stroke();
        }
    }
    drawAgent(agent) {
        const context = this.canvas.getContext("2d");
        let agentRadius = this.playback.currentGameLog.agentSettings.agentRadius;
        //backwards compatability
        if (agentRadius == null)
            agentRadius = 10;
        context.fillStyle = agent.team == 0 ? this.team0Color : this.team1Color;
        context.beginPath();
        const position = this.project(agent.position);
        context.moveTo(position.x, position.y);
        context.arc(position.x, position.y, agentRadius * this.zoom, 0, 2 * Math.PI);
        context.closePath();
        context.fill();
        if (this.rendering.agentVelocityLine) {
            const nextAgent = this.playback.getRelativeState(1).agents[agent.id];
            const velocity = nextAgent.position.sub(agent.position);
            // const predictedPosition = this.project(agent.position.add(velocity.normalize().scale(this.agentVelocityLineLength)));
            // context.strokeStyle = Color.lerp(Color.fromCssString(this.agentVelocityLineSlowColor), Color.fromCssString(this.agentVelocityLineFastColor), velocity.length / this.agentVelocityFastThreshold).toCssString();
            const predictedPosition = this.project(agent.position.add(velocity.scale(this.agentVelocityLineScale)));
            context.strokeStyle = this.agentVelocityLineColor;
            context.beginPath();
            context.moveTo(position.x, position.y);
            context.lineTo(predictedPosition.x, predictedPosition.y);
            context.closePath();
            context.stroke();
        }
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
            const previousAgent = this.playback.getRelativeState(-this.energyBarPersistance).agents[agent.id];
            const energyFraction = agent.energy / this.playback.currentGameLog.agentSettings.energySettings.maxEnergy;
            const previousEnergyFraction = previousAgent.energy / this.playback.currentGameLog.agentSettings.energySettings.maxEnergy;
            const radius = (agentRadius + this.energyBarMargin + this.energyBarThickness / 2) * this.zoom;
            context.lineWidth = this.energyBarThickness * this.zoom;
            context.strokeStyle = this.energyBarDepletedColor;
            context.beginPath();
            if (previousEnergyFraction == 1)
                context.arc(position.x, position.y, radius, 0, 2 * Math.PI);
            else
                context.arc(position.x, position.y, radius, -Math.PI / 2, (-Math.PI / 2) + 2 * Math.PI * (1 - previousEnergyFraction), true);
            context.stroke();
            context.closePath();
            context.strokeStyle = this.energyBarColor;
            context.beginPath();
            if (energyFraction == 1)
                context.arc(position.x, position.y, radius, 0, 2 * Math.PI);
            else
                context.arc(position.x, position.y, radius, -Math.PI / 2, (-Math.PI / 2) + 2 * Math.PI * (1 - energyFraction), true);
            context.stroke();
            context.closePath();
        }
        //draw text
        context.font = `${Math.round(this.fontSize * this.zoom)}px ${this.font}`;
        context.textAlign = "center";
        context.fillStyle = this.textColor;
        const textStack = [];
        if (this.rendering.agentName)
            textStack.push(`Name: ${agent.name}`);
        if (this.rendering.agentRole)
            textStack.push(`Role: ${agent.role}`);
        //technically no longer a stack because im not popping but effectively the same
        let yOffset = agentRadius + this.agentTextMargin;
        for (let i = textStack.length - 1; i >= 0; i--) {
            const text = textStack[i];
            context.fillText(text, position.x, position.y - yOffset * this.zoom);
            yOffset += this.fontSize;
        }
    }
    drawText(gameState) {
        const context = this.canvas.getContext("2d");
        context.font = `${this.infoTextSize}px ${this.font}`;
        context.fillStyle = this.textColor;
        //show follow target
        if (this.followTarget != CameraFollowTarget.none) {
            const name = this.followTarget == CameraFollowTarget.ball ? "Ball" : gameState.agents[this.followedAgentId].name;
            context.textAlign = "left";
            context.fillText(`Currently Following: ${name}`, 0, this.canvas.height - this.fontSize);
        }
        //show if currently paused
        if (this.playback.running == false) {
            context.textAlign = "right";
            context.fillText("Paused", this.canvas.width, this.canvas.height - this.fontSize);
        }
    }
    drawAgents(gameState) {
        for (const agent of gameState.agents) {
            this.drawAgent(agent);
        }
    }
    // sets the follow target to an agent or ball if they are close enough
    followNearby(position) {
        const gameState = this.playback.getCurrentState();
        //ball checking
        if (Vector2D.getDistance(position, gameState.ball.position) <= this.ballRadius + this.followMargin)
            this.followTarget = CameraFollowTarget.ball;
        //agents
        for (const agent of gameState.agents) {
            if (Vector2D.getDistance(position, agent.position) <= this.playback.currentGameLog.agentSettings.agentRadius + this.followMargin) {
                this.followTarget = CameraFollowTarget.agent;
                this.followedAgentId = agent.id;
                break;
            }
        }
    }
    stopFollowing() {
        this.followTarget = CameraFollowTarget.none;
        this.followedAgentId = null;
    }
    handleKeyboardInput(e) {
        switch (e.code) {
            // follow ball
            case "KeyB":
                if (this.followTarget != CameraFollowTarget.ball)
                    this.followTarget = CameraFollowTarget.ball;
                else
                    this.stopFollowing();
                break;
            //cycle through agents
            case "Tab":
                e.preventDefault();
                if (this.followTarget != CameraFollowTarget.agent) {
                    this.followTarget = CameraFollowTarget.agent;
                    this.followedAgentId = 0;
                }
                else {
                    if (e.shiftKey == false)
                        this.followedAgentId++;
                    else
                        this.followedAgentId--;
                    if (this.followedAgentId >= this.playback.agentsLength)
                        this.followedAgentId = 0;
                    else if (this.followedAgentId < 0)
                        this.followedAgentId = this.playback.agentsLength - 1;
                }
                break;
            //same as middleclick
            case "KeyF":
                if (this.followTarget != CameraFollowTarget.none)
                    this.stopFollowing();
                else
                    this.followNearby(this.position);
                break;
            //stops follow
            case "Space":
                this.stopFollowing();
                break;
            case "KeyP":
                this.playback.toggleRunning();
                break;
        }
    }
    handleMovementInput() {
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
    handleMouseMiddleClick(e) {
        if (e.target != this.canvas || e.buttons != 4)
            return;
        if (this.followTarget != CameraFollowTarget.none) {
            this.stopFollowing();
            return;
        }
        const position = this.mouseCoordinatesToWorldCoordinates(new Vector2D(e.x, e.y));
        this.followNearby(position);
    }
    mouseCoordinatesToWorldCoordinates(mouseCoordinates) {
        let bounding = this.canvas.getBoundingClientRect();
        let offsetVector = new Vector2D(bounding.left, bounding.top);
        //convert screen coordinates into canvas coordinates
        let projectedCoordinates = mouseCoordinates.sub(offsetVector);
        return this.reverseProject(projectedCoordinates);
    }
    project(position) {
        return position.sub(this.position).scale(this.zoom).add(new Vector2D(this.canvas.width / 2, this.canvas.height / 2));
    }
    reverseProject(position) {
        return position.sub(new Vector2D(this.canvas.width / 2, this.canvas.height / 2)).scale(1 / this.zoom).add(this.position);
    }
    clear() {
        const context = this.canvas.getContext("2d");
        context.clearRect(0, 0, this.canvas.width, this.canvas.height);
    }
}
