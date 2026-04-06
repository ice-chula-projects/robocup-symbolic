export class Vector2D {
    x;
    y;
    /**
     *
     * @param {number} x a number representing the x coordinate of the vector
     * @param {number} y a number representing the y coordinate of the vector
     */
    constructor(x, y) {
        if (x == null || y == null)
            throw new Error("arguements cannot be null");
        this.x = x;
        this.y = y;
    }
    /**
     * returns a vector of coordinate (0,0)
     */
    static get zero() {
        return new Vector2D(0, 0);
    }
    /**
     * returns the length of the vector
     */
    get length() {
        return this.getLength();
    }
    /**
     * returns the normalized vector
     */
    get normalized() {
        return this.normalize();
    }
    /**
     * @description returns the length of the vector
     */
    getLength() {
        return Math.sqrt(this.x ** 2 + this.y ** 2);
    }
    /**
     * @description returns a new normalized vector
     */
    normalize() {
        let length = this.length;
        return new Vector2D(this.x / length, this.y / length);
    }
    add(other) {
        if (typeof other === "number") {
            return new Vector2D(this.x + other, this.y + other);
        }
        else if (other instanceof Vector2D) {
            return new Vector2D(this.x + other.x, this.y + other.y);
        }
        else
            throw new TypeError(`cannot add Vector2D with ${other.constructor.name}`);
    }
    sub(other) {
        if (typeof other === "number") {
            return this.add(other * -1);
        }
        else if (other instanceof Vector2D) {
            return this.add(other.scale(-1));
        }
        else
            throw new TypeError(`cannot subtract Vector2D with ${other.constructor.name}`);
    }
    scale(other) {
        if (typeof other === "number") {
            return new Vector2D(this.x * other, this.y * other);
        }
        else if (other instanceof Vector2D) {
            return new Vector2D(this.x * other.x, this.y * other.y);
        }
        else
            throw new TypeError(`cannot scale Vector2D with ${other.constructor.name}`);
    }
    /**
     *
     * @param vector2D
     * @returns returns the dot product between this vector and the given vector
     */
    dot(vector2D) {
        return this.x * vector2D.x + this.y * vector2D.y;
    }
    /**
     *
     * @returns a new copy of the vector
     */
    copy() {
        return new Vector2D(this.x, this.y);
    }
    /**
     *
     * @param v0
     * @param v1
     * @returns returns the euclidean distance between the two vector
     */
    static getDistance(v0, v1) {
        return v1.sub(v0).length;
    }
    /**
     *
     * @param v0
     * @param v1
     * @returns a normalized vector pointing from v0 to v1
     */
    static getDirection(v0, v1) {
        return v1.sub(v0).normalized;
    }
}
export default Vector2D;
