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

    constructor(camera: Camera, checkBoxElements: CheckBoxElements, colorElements: ColorElements, speedSliderElements: SpeedSliderElements, fileInputElements: FileInputElements, pauseButton: HTMLButtonElement) {
        this.camera = camera;
        this.playBack = camera.playback;

        this.checkBoxElements = checkBoxElements;
        this.colorElements = colorElements;
        this.speedSliderElements = speedSliderElements;
        this.fileInputElements = fileInputElements;
        this.pauseButton = pauseButton;
    }
}