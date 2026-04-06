import Camera from "./Camera.js";
import Playback from "./Playback.js";

const playback = new Playback(document.getElementById("gameLogFileInput") as HTMLInputElement, document.getElementById("loadButton") as HTMLButtonElement);
const camera = new Camera(document.getElementById("canvas") as HTMLCanvasElement, playback);

playback.start();
camera.start();
//@ts-ignore
window.playback = playback;
//@ts-ignore
window.camera = camera;