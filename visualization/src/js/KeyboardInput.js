export default class KeyboardInput {
    static ValidKeys = ["KeyW", "KeyA", "KeyS", "KeyD", "KeyQ", "KeyE"];
    static #keys;
    static initialized = false;
    static get keys() {
        if (!this.initialized)
            this.initialize();
        return this.#keys;
    }
    static initialize() {
        if (this.initialized)
            throw new Error("Tried to initialize KeyboardInput when it was already initailized");
        this.#keys = {};
        for (const validKey of this.ValidKeys) {
            this.#keys[validKey] = false;
        }
        document.addEventListener("keydown", (e) => {
            const code = e.code;
            if (!this.ValidKeys.includes(code))
                return;
            this.#keys[code] = true;
        });
        document.addEventListener("keyup", (e) => {
            const code = e.code;
            if (!this.ValidKeys.includes(code))
                return;
            this.#keys[code] = false;
        });
        this.initialized = true;
    }
}
