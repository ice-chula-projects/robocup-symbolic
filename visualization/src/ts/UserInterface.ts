import Camera from "./Camera.js";
import Playback from "./Playback.js";

export type CheckBoxElements = {
    nameDisplay: HTMLInputElement,
    roleDisplay: HTMLInputElement,
    energyDisplay: HTMLInputElement,
    agentVelocityDisplay: HTMLInputElement,
    ballVelocityDisplay: HTMLInputElement,
}

export type ColorElements = {
    team0Color: HTMLInputElement,
    team1Color: HTMLInputElement
}

export type SpeedSliderElements = {
    speedSlider: HTMLInputElement;
    speedDisplay: HTMLSpanElement;
}

export type FileInputElements = {
    fileInput: HTMLInputElement;
    fileNameDisplay: HTMLSpanElement;
}

export default class UserInterface {
    checkBoxElements: CheckBoxElements;
    colorElements: ColorElements;
    speedSliderElements: SpeedSliderElements;
    fileInputElements: FileInputElements;
    pauseButton: HTMLButtonElement

    camera: Camera;
    playBack: Playback;

    baseSpeed: number = 60;

    constructor(camera: Camera, checkBoxElements: CheckBoxElements, colorElements: ColorElements, speedSliderElements: SpeedSliderElements, fileInputElements: FileInputElements, pauseButton: HTMLButtonElement) {
        this.camera = camera;
        this.playBack = camera.playback;

        this.checkBoxElements = checkBoxElements;
        this.colorElements = colorElements;
        this.speedSliderElements = speedSliderElements;
        this.fileInputElements = fileInputElements;
        this.pauseButton = pauseButton;

        this.setupElements();

        //sometimes browsers cache the values
        this.synchronizeSettings();

        //since pause button can also be changed via camera controls
        //we manually check every now and then to update the value

        setInterval(this.updatePauseButtonDisplay.bind(this), 1000/24)
    }

    synchronizeSettings(): void {
        this.camera.rendering.agentName = this.checkBoxElements.nameDisplay.checked;
        this.camera.rendering.agentRole = this.checkBoxElements.roleDisplay.checked;
        this.camera.rendering.energyBar = this.checkBoxElements.energyDisplay.checked;
        this.camera.rendering.agentVelocityLine = this.checkBoxElements.agentVelocityDisplay.checked;
        this.camera.rendering.ballVelocityLine = this.checkBoxElements.ballVelocityDisplay.checked;

        this.camera.team0Color = this.colorElements.team0Color.value;
        this.camera.team1Color = this.colorElements.team1Color.value;

        this.updatePlaybackSpeed();
        this.updateFileInputDisplay();
    }

    setupElements() {
        this.checkBoxElements.nameDisplay.addEventListener("change", () => {
            this.camera.rendering.agentName = this.checkBoxElements.nameDisplay.checked;
        })

        this.checkBoxElements.roleDisplay.addEventListener("change", () => {
            this.camera.rendering.agentRole = this.checkBoxElements.roleDisplay.checked;
        })

        this.checkBoxElements.energyDisplay.addEventListener("change", () => {
            this.camera.rendering.energyBar = this.checkBoxElements.energyDisplay.checked;
        })

        this.checkBoxElements.agentVelocityDisplay.addEventListener("change", () => {
            this.camera.rendering.agentVelocityLine = this.checkBoxElements.agentVelocityDisplay.checked;
        })

        this.checkBoxElements.ballVelocityDisplay.addEventListener("change", () => {
            this.camera.rendering.ballVelocityLine = this.checkBoxElements.ballVelocityDisplay.checked;
        })

        this.colorElements.team0Color.addEventListener("change", () => {
            this.camera.team0Color = this.colorElements.team0Color.value;
        })

        this.colorElements.team1Color.addEventListener("change", () => {
            this.camera.team1Color = this.colorElements.team1Color.value;
        })

        this.speedSliderElements.speedSlider.addEventListener("change", this.updatePlaybackSpeed.bind(this));
        this.fileInputElements.fileInput.addEventListener("change", this.updateFileInputDisplay.bind(this));

        this.pauseButton.addEventListener("click", this.playBack.toggleRunning.bind(this.playBack));
    }

    updatePlaybackSpeed() {
        const speedSlider = this.speedSliderElements.speedSlider;
        const speedDisplay = this.speedSliderElements.speedDisplay;
        const speedMultiplier = 2 ** parseInt(speedSlider.value);

        if (parseInt(speedSlider.value) >= parseInt(speedSlider.max)) {
            this.playBack.targetTps = 1000000000000;
            speedDisplay.innerText = "🔥As Fast As Possible🔥";
        }
        else {
            this.playBack.targetTps = this.baseSpeed * speedMultiplier;
            speedDisplay.innerText = speedMultiplier.toString() + "x";
        };
    }

    updateFileInputDisplay() {
        const fileInput = this.fileInputElements.fileInput;
        const fileNameDisplay = this.fileInputElements.fileNameDisplay;

        if (fileInput.files.length > 0) {
            fileNameDisplay.textContent = fileInput.files[0].name;
        } else {
            fileNameDisplay.textContent = "No file selected";
        }
    }

    updatePauseButtonDisplay() {
        if(this.playBack.running) this.pauseButton.innerText = "Pause";
        else this.pauseButton.innerText = "Play";
    }
}