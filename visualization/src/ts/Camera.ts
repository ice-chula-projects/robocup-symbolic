import Color from "./Color.js";
import KeyboardInput from "./KeyboardInput.js";
import Vector2D from "./lib/Vector2D.js"
import Playback, { Agent, AgentProcessed, BallProcessed, GameStateProcessed } from "./Playback.js";

export enum CameraFollowTarget {
    none,
    ball,
    agent
}

export default class Camera {
    canvas: HTMLCanvasElement;
    playback: Playback;

    position: Vector2D = Vector2D.zero;
    zoom: number = 1;

    cameraSpeed: number = 15;
    zoomSpeed: number = .1;
    zoomBounds: { min: number, max: number } = { min: 0.1, max: 10 };

    backgroundColor: string = "darkgreen";

    ballRadius: number = 5;
    ballColor: string = "white";
    ballStrokeColor: string = "black";
    ballStrokeWidth: number = 1;
    ballVelocityLineScale: number = 5;
    ballVelocityLineColor: string = "red";


    borderWidth: number = 3;
    borderColor: string = "lightgrey";

    team0Color: string = "blue";
    team1Color: string = "red";

    goalWidth: number = 25;

    
    font: string = "arial";
    textColor: string = "white";
    
    agentFontSize: number = 12;
    agentTextMargin: number = 5;
    
    infoTextSize: number = 30;
    infoTextMargin: number = 2;
    
    // agentVelocityFastThreshold: number = 5;
    // agentVelocityLineLength: number = 20;
    // agentVelocityLineSlowColor: string = "green";
    // agentVelocityLineFastColor: string = "red";

    agentVelocityLineScale: number = 5;
    agentVelocityLineColor: string = "white";

    energyBarColor: string = "lime";
    energyBarPersistance: number = 32;
    energyBarDepletedColor: string = "red";
    energyBarMargin: number = 1;
    energyBarThickness: number = 2;

    // how far away something can be (+ it's radius) to still be considered when selecting follow target
    followMargin: number = 50;
    followTarget: CameraFollowTarget = CameraFollowTarget.none;
    followedAgentId: number;
    
    rendering: {
        energyBar: boolean,
        agentName: boolean,
        agentRole: boolean,
        ballVelocityLine: boolean,
        agentVelocityLine: boolean,
        infoText: boolean
    } = {
            energyBar: true,
            agentName: true,
            agentRole: true,
            ballVelocityLine: false,
            agentVelocityLine: false,
            infoText: true
        }

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

        window.addEventListener("wheel", this.handleScroll.bind(this), { passive: false });
        window.addEventListener("mousemove", this.handleMouseDrag.bind(this));
        window.addEventListener("mousedown", this.handleMouseMiddleClick.bind(this));
        window.addEventListener("keydown", this.handleKeyboardInput.bind(this));

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
        const gameState: GameStateProcessed = this.playback.getCurrentState();
        if (gameState == null) return;

        this.handleMovementInput()
        if (this.followTarget != CameraFollowTarget.none) this.updateFollow(gameState);
        this.render(gameState);
    }

    updateFollow(gameState: GameStateProcessed): void {
        switch (this.followTarget) {
            case CameraFollowTarget.ball:
                this.position = gameState.ball.position.copy();
                break;
            case CameraFollowTarget.agent:
                this.position = gameState.agents[this.followedAgentId].position.copy();
                break;
        }
    }

    render(gameState: GameStateProcessed) {
        this.clear();
        this.drawField();
        this.drawBall(gameState);
        this.drawAgents(gameState);
        if(this.rendering.infoText) this.drawInfoText(gameState);
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
        context.lineWidth = borderWidth

        //value to nudge the by so that the ball appears to bounce when it's edge hits instead of it's center
        const nudge = this.ballRadius * this.zoom;
        context.beginPath();
        context.rect(topLeft.x - nudge, topLeft.y - nudge, fieldDimensions.width * this.zoom + 2 * nudge, fieldDimensions.height * this.zoom + 2 * nudge);
        context.closePath();
        context.stroke();

        //draw goals
        const goalHeight = this.playback.currentGameLog.fieldSettings.goalSize * fieldDimensions.height;
        const team0GoalTopLeft = this.project(new Vector2D(-this.goalWidth, -goalHeight / 2 + fieldDimensions.height / 2))
        const team1GoalTopLeft = this.project(new Vector2D(fieldDimensions.width, -goalHeight / 2 + fieldDimensions.height / 2))
        context.beginPath();
        context.rect(team0GoalTopLeft.x, team0GoalTopLeft.y, this.goalWidth * this.zoom - nudge, goalHeight * this.zoom);
        context.rect(team1GoalTopLeft.x + nudge, team1GoalTopLeft.y, this.goalWidth * this.zoom, goalHeight * this.zoom);
        context.closePath();

        context.fill();

    }

    drawBall(gameState: GameStateProcessed) {
        const context = this.canvas.getContext("2d");
        const position = this.project(gameState.ball.position);

        //draw stroke
        context.beginPath();
        context.fillStyle = this.ballStrokeColor;
        context.arc(position.x, position.y, (this.ballRadius + this.ballStrokeWidth) * this.zoom, 0, 2 * Math.PI);
        context.closePath();
        context.fill();

        //draw ball
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

    //previous Agents is used for rendering energy bar
    drawAgent(agent: AgentProcessed, previousAgents: AgentProcessed[][], gameState: GameStateProcessed) {
        const context = this.canvas.getContext("2d");
        let agentRadius = this.playback.currentGameLog.agentSettings.agentRadius;
        //backwards compatability
        if (agentRadius == null) agentRadius = 10;

        context.fillStyle = agent.team == 0 ? this.team0Color : this.team1Color;

        context.beginPath();
        const position = this.project(agent.position);
        context.moveTo(position.x, position.y);
        context.arc(position.x, position.y, agentRadius * this.zoom, 0, 2 * Math.PI);
        context.closePath();
        context.fill();

        if (this.rendering.agentVelocityLine) {
            const nextGameState = this.playback.getRelativeState(1);
            let velocity: Vector2D;
            
            if(nextGameState.round == gameState.round){
                // fake velocity by just getting the difference between next and current position
                const nextAgent = nextGameState.agents[agent.id];
                velocity = nextAgent.position.sub(agent.position);
            }
            else{
                // fake velocity during round transitions by pretending the agent continued traveling in the same direction as the previous frame
                const previousAgent = this.playback.getRelativeState(-1).agents[agent.id];
                velocity = agent.position.sub(previousAgent.position);
            }

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

            let highestPreviousEnergy = -Infinity;
            for(const previousAgent of previousAgents.map(x => x[agent.id])){
                if(previousAgent.energy > highestPreviousEnergy) highestPreviousEnergy = previousAgent.energy;
            }
            
            const energyFraction = agent.energy / this.playback.currentGameLog.agentSettings.energySettings.maxEnergy;
            const persistedEnergyFraction = highestPreviousEnergy / this.playback.currentGameLog.agentSettings.energySettings.maxEnergy;
            const radius = (agentRadius + this.energyBarMargin + this.energyBarThickness / 2) * this.zoom;
            context.lineWidth = this.energyBarThickness * this.zoom;


            context.strokeStyle = this.energyBarDepletedColor;
            context.beginPath();
            if (persistedEnergyFraction == 1) context.arc(position.x, position.y, radius, 0, 2 * Math.PI);
            else context.arc(position.x, position.y, radius, -Math.PI / 2, (-Math.PI / 2) + 2 * Math.PI * (1 - persistedEnergyFraction), true);
            context.stroke();
            context.closePath();

            context.strokeStyle = this.energyBarColor;
            context.beginPath();
            if (energyFraction == 1) context.arc(position.x, position.y, radius, 0, 2 * Math.PI);
            else context.arc(position.x, position.y, radius, -Math.PI / 2, (-Math.PI / 2) + 2 * Math.PI * (1 - energyFraction), true);
            context.stroke();
            context.closePath();
        }

        //draw text
        context.font = `${Math.round(this.agentFontSize * this.zoom)}px ${this.font}`;
        context.textAlign = "center";
        context.fillStyle = this.textColor;
        
        const textStack = [];
        if(this.rendering.agentName) textStack.push(`Name: ${agent.name}`);
        if(this.rendering.agentRole) textStack.push(`Role: ${agent.role}`);
        
        //technically no longer a stack because im not popping but effectively the same
        let yOffset = agentRadius + this.agentTextMargin;
        for(let i = textStack.length - 1; i >= 0; i--){
            const text = textStack[i];
            context.fillText(text, position.x, position.y - yOffset * this.zoom);
            yOffset += this.agentFontSize;
        }

    }

    drawInfoText(gameState: GameStateProcessed): void {
        const context = this.canvas.getContext("2d");
        context.font = `${this.infoTextSize}px ${this.font}`;
        context.fillStyle = this.textColor;

        // round and score display
        // display the next frame's score during transitions since the transition frame is technically 1 frame
        // before the ball enters the goal
        const score = this.playback.isRoundTransition ? this.playback.getRelativeState(1).score : gameState.score;
        
        context.textAlign = "center";
        context.fillText(`Round ${gameState.round}`, this.canvas.width/2, this.infoTextSize + this.infoTextMargin);
        context.fillText(`${score.team0}-${score.team1}`, this.canvas.width/2, 2*this.infoTextSize + this.infoTextMargin);

        //show follow target
        if (this.followTarget != CameraFollowTarget.none) {
            const name = this.followTarget == CameraFollowTarget.ball ? "Ball" : gameState.agents[this.followedAgentId].name;
            context.textAlign = "left";
            context.fillText(`Currently Following: ${name}`, this.infoTextMargin, this.canvas.height - this.infoTextMargin);
        }

        //show if currently paused
        if (this.playback.running == false){
            context.textAlign = "right";
            context.fillText("Paused", this.canvas.width - this.infoTextMargin, this.canvas.height - this.infoTextMargin);
        }

                //show who scored during transiton
        if(this.playback.isRoundTransition){
            context.font = `${2*this.infoTextSize}px ${this.font}`;

            let scoreText: string;
            //score during transition frame is 1 frame ahead
            if(score.team0 > gameState.score.team0) scoreText = "Team 0 Scores!";
            else scoreText = "Team 1 Scores!";

            context.textAlign = "center";
            context.fillText(scoreText, this.canvas.width/2, this.canvas.height/2);

            // reset the font size incase i ever add anything else below this
            context.font = `${this.infoTextSize}px ${this.font}`;
        }
    }

    drawAgents(gameState: GameStateProcessed) {
        const previousAgents: AgentProcessed[][] = []
        for(let i = 1; i <= this.energyBarPersistance; i++){
            previousAgents.push(this.playback.getRelativeState(-i).agents);
        }

        for (const agent of gameState.agents) {
            this.drawAgent(agent, previousAgents, gameState);
        }
    }

    // sets the follow target to an agent or ball if they are close enough
    followNearby(position: Vector2D) {
        const gameState = this.playback.getCurrentState();

        //ball checking
        if (Vector2D.getDistance(position, gameState.ball.position) <= this.ballRadius + this.followMargin) this.followTarget = CameraFollowTarget.ball;

        //agents
        for (const agent of gameState.agents) {
            if (Vector2D.getDistance(position, agent.position) <= this.playback.currentGameLog.agentSettings.agentRadius + this.followMargin) {
                this.followTarget = CameraFollowTarget.agent;
                this.followedAgentId = agent.id;
                break;
            }
        }
    }

    stopFollowing(): void{
        this.followTarget = CameraFollowTarget.none;
        this.followedAgentId = null;
    }

    handleKeyboardInput(e: KeyboardEvent): void {
        switch (e.code) {
            // follow ball
            case "KeyB":
                if (this.followTarget != CameraFollowTarget.ball) this.followTarget = CameraFollowTarget.ball;
                else this.stopFollowing();
                break;

            //cycle through agents
            case "Tab":
                e.preventDefault();
                if (this.followTarget != CameraFollowTarget.agent) {
                    this.followTarget = CameraFollowTarget.agent
                    this.followedAgentId = 0;
                }

                else {
                    if (e.shiftKey == false) this.followedAgentId++;
                    else this.followedAgentId--;

                    if (this.followedAgentId >= this.playback.agentsLength) this.followedAgentId = 0;
                    else if (this.followedAgentId < 0) this.followedAgentId = this.playback.agentsLength - 1;
                }
                break;

            //same as middleclick
            case "KeyF":
                if (this.followTarget != CameraFollowTarget.none) this.stopFollowing();
                else this.followNearby(this.position);
                break;
            
            //stops follow
            case "Space":
                this.stopFollowing();
                break;
            
            case "KeyP":
                this.playback.toggleRunning();
                break;
            
            case "KeyV":
                this.rendering.infoText = !this.rendering.infoText;
                break;
            
            // for debugging
            // steps forwards/backwards if currently paused
            case "KeyG":
                if(this.playback.running) return;
                
                if(e.shiftKey) this.playback.currentStateIndex--;
                else this.playback.currentStateIndex++;
                break;
            
        }
    }

    handleMovementInput(): void {
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
        e.preventDefault();
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

    handleMouseMiddleClick(e: MouseEvent): void {
        if (e.target != this.canvas || e.buttons != 4) return;
        e.preventDefault();

        if (this.followTarget != CameraFollowTarget.none) {
            this.stopFollowing();
            return;
        }

        const position = this.mouseCoordinatesToWorldCoordinates(new Vector2D(e.x, e.y))
        this.followNearby(position);
    }

    mouseCoordinatesToWorldCoordinates(mouseCoordinates: Vector2D) {
        let bounding = this.canvas.getBoundingClientRect();
        let offsetVector = new Vector2D(bounding.left, bounding.top);

        //convert screen coordinates into canvas coordinates
        let projectedCoordinates = mouseCoordinates.sub(offsetVector);

        return this.reverseProject(projectedCoordinates)
    }


    project(position: Vector2D): Vector2D {
        return position.sub(this.position).scale(this.zoom).add(new Vector2D(this.canvas.width / 2, this.canvas.height / 2));
    }

    reverseProject(position: Vector2D): Vector2D {
        return position.sub(new Vector2D(this.canvas.width / 2, this.canvas.height / 2)).scale(1 / this.zoom).add(this.position);
    }

    clear(): void {
        const context = this.canvas.getContext("2d");
        context.clearRect(0, 0, this.canvas.width, this.canvas.height);
    }
}