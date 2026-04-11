import Camera from "./Camera.js";
import Playback from "./Playback.js";
const playback = new Playback(document.getElementById("gameLogFileInput"), document.getElementById("loadButton"));
const camera = new Camera(document.getElementById("canvas"), playback);
const fileInput = document.getElementById("gameLogFileInput");
const fileName = document.getElementById("fileName");

playback.start();
camera.start();
//@ts-ignore
window.playback = playback;
//@ts-ignore
window.camera = camera;

// Display file name in UI
fileInput.addEventListener("change", () => {
    if (fileInput.files.length > 0) {
        fileName.textContent = fileInput.files[0].name;
    } else {
        fileName.textContent = "No file selected";
    }
});