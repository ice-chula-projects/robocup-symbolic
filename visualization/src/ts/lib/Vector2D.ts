export class Vector2D {
    x: number;
    y: number;

    /**
     * 
     * @param {number} x a number representing the x coordinate of the vector
     * @param {number} y a number representing the y coordinate of the vector
     */
    constructor(x: number, y: number) {
        if (x == null || y == null) throw new Error("arguements cannot be null");
        this.x = x;
        this.y = y;
    }

    /**
     * returns a vector of coordinate (0,0)
     */
    static get zero(): Vector2D {
        return new Vector2D(0, 0);
    }

    /**
     * returns the length of the vector
     */
    get length(): number {
        return this.getLength();
    }

    /**
     * returns the normalized vector
     */
    get normalized(): Vector2D {
        return this.normalize();
    }

    /**
     * @description returns the length of the vector
     */
    getLength(): number {
        return Math.sqrt(this.x ** 2 + this.y ** 2);
    }

    /**
     * @description returns a new normalized vector 
     */
    normalize(): Vector2D {
        let length = this.length;
        return new Vector2D(this.x / length, this.y / length);
    }

    /**
     * 
     * @param scalar
     * @description returns a new vector, performs vector scalar addition
     */
    add(scalar: number): Vector2D;

    /**
     * 
     * @param vector2D
     * @description returns a new vector, performs vector addition
     */
    add(vector2D: Vector2D): Vector2D;

    add(other: any): Vector2D {
        if (typeof other === "number") {
            return new Vector2D(this.x + other, this.y + other);
        } else if (other instanceof Vector2D) {
            return new Vector2D(this.x + other.x, this.y + other.y);
        } else throw new TypeError(`cannot add Vector2D with ${other.constructor.name}`)
    }

    /**
     * 
     * @param scalar
     * @description returns a new vector, performs vector scalar subtraction
     */
    sub(scalar: number): Vector2D;

    /**
     * 
     * @param vector2D 
     * @description returns a new vector, performs vector subtraction
     */
    sub(vector2D: Vector2D): Vector2D;

    sub(other: any): Vector2D {
        if (typeof other === "number") {
            return this.add(other * -1);
        } else if (other instanceof Vector2D) {
            return this.add(other.scale(-1));
        } else throw new TypeError(`cannot subtract Vector2D with ${other.constructor.name}`)
    }

    /**
     * 
     * @param scalar 
     * @description returns a new vector, scales by the scalar value
     */
    scale(scalar: number): Vector2D;

    /**
     * 
     * @param vector2D 
     * @description returns a new vector, scales by the vector value
     */
    scale(vector2D: Vector2D): Vector2D;

    scale(other: any): Vector2D {
        if (typeof other === "number") {
            return new Vector2D(this.x * other, this.y * other);
        } else if (other instanceof Vector2D) {
            return new Vector2D(this.x * other.x, this.y * other.y)
        } else throw new TypeError(`cannot scale Vector2D with ${other.constructor.name}`)
    }

    /**
     * 
     * @param vector2D 
     * @returns returns the dot product between this vector and the given vector
     */
    dot(vector2D: Vector2D): number{
        return this.x * vector2D.x + this.y * vector2D.y;
    }
    
    /**
     * 
     * @returns a new copy of the vector
     */
    copy(){
        return new Vector2D(this.x,this.y)
    }
    
    /**
     * 
     * @param v0 
     * @param v1 
     * @returns returns the euclidean distance between the two vector
     */
    static getDistance(v0:Vector2D, v1:Vector2D): number{
        return v1.sub(v0).length;
    }

    /**
     * 
     * @param v0 
     * @param v1 
     * @returns a normalized vector pointing from v0 to v1
     */
    static getDirection(v0:Vector2D, v1:Vector2D): Vector2D{
        return v1.sub(v0).normalized;
    }
}

export default Vector2D;

