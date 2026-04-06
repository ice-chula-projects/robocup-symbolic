export type ValidKeys = typeof KeyboardInput.ValidKeys[number];

export default class KeyboardInput{
    static readonly ValidKeys = ["KeyW", "KeyA", "KeyS", "KeyD", "KeyQ", "KeyE"];
    static #keys: Record<ValidKeys, boolean>;
    static initialized: boolean = false;

    static get keys(): Record<ValidKeys, boolean>{
        if(!this.initialized) this.initialize();
        return this.#keys;
    }

    static initialize(){
        if(this.initialized) throw new Error("Tried to initialize KeyboardInput when it was already initailized");
        this.#keys = {};

        for(const validKey of this.ValidKeys){
            this.#keys[validKey] = false;
        }

        document.addEventListener("keydown", (e:KeyboardEvent) => {
            const code = e.code;
            if(!this.ValidKeys.includes(code)) return;
            this.#keys[code] = true;
        })

        document.addEventListener("keyup", (e:KeyboardEvent) => {
            const code = e.code;
            if(!this.ValidKeys.includes(code)) return;
            this.#keys[code] = false;
        })

        this.initialized = true;
    }

}
