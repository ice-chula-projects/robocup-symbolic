import Camera from "./Camera.js";
import Color from "./Color.js";
import Playback from "./Playback.js";
import UserInterface, { ButtonElements, CheckBoxElements, ColorElements, FileInputElements, SpeedSliderElements } from "./UserInterface.js";

const playback = new Playback(document.getElementById("gameLogFileInput") as HTMLInputElement, document.getElementById("loadButton") as HTMLButtonElement);
const camera = new Camera(document.getElementById("canvas") as HTMLCanvasElement, playback);

const checkBoxElements: CheckBoxElements = {} as CheckBoxElements; 
checkBoxElements.nameDisplay = document.getElementById("nameDisplay") as HTMLInputElement;
checkBoxElements.roleDisplay = document.getElementById("roleDisplay") as HTMLInputElement;
checkBoxElements.energyDisplay = document.getElementById("energyDisplay") as HTMLInputElement;
checkBoxElements.agentVelocityDisplay = document.getElementById("agentVelocityDisplay") as HTMLInputElement;
checkBoxElements.ballVelocityDisplay = document.getElementById("ballVelocityDisplay") as HTMLInputElement;

const colorElements: ColorElements = {} as ColorElements;
colorElements.team0Color = document.getElementById("team0Color") as HTMLInputElement;
colorElements.team1Color = document.getElementById("team1Color") as HTMLInputElement;

const speedSliderElements: SpeedSliderElements = {} as SpeedSliderElements;
speedSliderElements.speedSlider = document.getElementById("speedSlider") as HTMLInputElement;
speedSliderElements.speedDisplay = document.getElementById("speedValue") as HTMLSpanElement;

const fileInputElements: FileInputElements = {} as FileInputElements;
fileInputElements.fileInput = document.getElementById("gameLogFileInput") as HTMLInputElement;
fileInputElements.fileNameDisplay = document.getElementById("fileName") as HTMLSpanElement;

const pauseButton = document.getElementById("pauseButton") as HTMLButtonElement;

const userInterface = new UserInterface(camera, checkBoxElements, colorElements, speedSliderElements, fileInputElements, pauseButton);
playback.start();
camera.start();


//@ts-ignore
window.playback = playback;
//@ts-ignore
window.camera = camera;
//@ts-ignore
window.color = Color;