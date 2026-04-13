import Camera from "./Camera.js";
import Color from "./Color.js";
import Playback from "./Playback.js";
import UserInterface from "./UserInterface.js";
const playback = new Playback(document.getElementById("gameLogFileInput"), document.getElementById("loadButton"));
const camera = new Camera(document.getElementById("canvas"), playback);
const checkBoxElements = {};
checkBoxElements.nameDisplay = document.getElementById("nameDisplay");
checkBoxElements.roleDisplay = document.getElementById("roleDisplay");
checkBoxElements.energyDisplay = document.getElementById("energyDisplay");
checkBoxElements.agentVelocityDisplay = document.getElementById("agentVelocityDisplay");
checkBoxElements.ballVelocityDisplay = document.getElementById("ballVelocityDisplay");
const colorElements = {};
colorElements.team0Color = document.getElementById("team0Color");
colorElements.team1Color = document.getElementById("team1Color");
const speedSliderElements = {};
speedSliderElements.speedSlider = document.getElementById("speedSlider");
speedSliderElements.speedDisplay = document.getElementById("speedValue");
const fileInputElements = {};
fileInputElements.fileInput = document.getElementById("gameLogFileInput");
fileInputElements.fileNameDisplay = document.getElementById("fileName");
const pauseButton = document.getElementById("pauseButton");
const userInterface = new UserInterface(camera, checkBoxElements, colorElements, speedSliderElements, fileInputElements, pauseButton);
camera.start();
//@ts-ignore
window.playback = playback;
//@ts-ignore
window.camera = camera;
//@ts-ignore
window.color = Color;
