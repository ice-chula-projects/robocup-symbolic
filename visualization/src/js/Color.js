export default class Color {
    r;
    g;
    b;
    a;
    static fromCssString(cssString) {
        const div = document.createElement("div");
        div.style.color = cssString;
        document.body.appendChild(div);
        const computed = getComputedStyle(div).color;
        document.body.removeChild(div);
        const values = computed.match(/[\d.]+/g).map(Number);
        let [r, g, b, a] = values;
        if (a === undefined)
            a = 1;
        return new Color(r, g, b, Math.round(255 * a));
    }
    static lerp(colorA, colorB, t) {
        if (t > 1)
            t = 1;
        if (t < 0)
            t = 0;
        const r = (1 - t) * colorA.r + t * colorB.r;
        const g = (1 - t) * colorA.g + t * colorB.g;
        const b = (1 - t) * colorA.b + t * colorB.b;
        const a = (1 - t) * colorA.a + t * colorB.a;
        return new Color(Math.round(r), Math.round(g), Math.round(b), Math.round(a));
    }
    constructor(r, g, b, a) {
        this.r = r;
        this.g = g;
        this.b = b;
        this.a = a == null ? 1 : a;
    }
    toCssString() {
        return `#${this.r.toString(16).padStart(2, "0")}${this.g.toString(16).padStart(2, "0")}${this.b.toString(16).padStart(2, "0")}${this.a.toString(16).padStart(2, "0")}`;
    }
    copy() {
        return new Color(this.r, this.g, this.b, this.a);
    }
}
