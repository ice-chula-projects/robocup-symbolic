export default class UserInterface {
    checkBoxElements;
    colorElements;
    speedSliderElements;
    fileInputElements;
    pauseButton;
    camera;
    playBack;
    constructor(camera, checkBoxElements, colorElements, speedSliderElements, fileInputElements, pauseButton) {
        this.camera = camera;
        this.playBack = camera.playback;
        this.checkBoxElements = checkBoxElements;
        this.colorElements = colorElements;
        this.speedSliderElements = speedSliderElements;
        this.fileInputElements = fileInputElements;
        this.pauseButton = pauseButton;
    }
}
