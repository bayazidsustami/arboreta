// RefractiveEsotericInterpreter.js
// A 3D Light-Ray Refraction Interpreter for Photo-Reactive Logic Gates

class Vector3 {
    constructor(x = 0, y = 0, z = 0) {
        this.x = x; this.y = y; this.z = z;
    }

    add(v) { return new Vector3(this.x + v.x, this.y + v.y, this.z + v.z); }
    sub(v) { return new Vector3(this.x - v.x, this.y - v.y, this.z - v.z); }
    multiply(scalar) { return new Vector3(this.x * scalar, this.y * scalar, this.z * scalar); }
    dot(v) { return this.x * v.x + this.y * v.y + this.z * v.z; }
    
    length() { return Math.sqrt(this.dot(this)); }
    normalize() {
        const len = this.length();
        return len > 0 ? this.multiply(1 / len) : new Vector3();
    }
}

class SphereGlassPrism {
    constructor(center, radius, ior = 1.5) {
        this.center = center;
        this.radius = radius;
        this.ior = ior; // Index of Refraction (e.g. Glass ~ 1.5)
    }

    // Intersects ray (origin, dir) with sphere; returns distance t or null
    intersect(origin, direction) {
        const oc = origin.sub(this.center);
        const b = oc.dot(direction);
        const c = oc.dot(oc) - this.radius * this.radius;
        const discriminant = b * b - c;

        if (discriminant < 0) return null;
        
        const sqrtD = Math.sqrt(discriminant);
        let t = -b - sqrtD;
        if (t < 0.0001) t = -b + sqrtD;
        return t > 0.0001 ? t : null;
    }

    getNormalAt(point) {
        return point.sub(this.center).normalize();
    }
}

class PhotoReactiveGate {
    constructor(id, position, radius, logicOperation) {
        this.id = id;
        this.position = position;
        this.radius = radius;
        this.logicOperation = logicOperation; // e.g. (intensity) => op
        this.intensityHits = 0;
    }

    checkHit(hitPoint, intensity) {
        if (hitPoint.sub(this.position).length() <= this.radius) {
            this.intensityHits += intensity;
            return true;
        }
        return false;
    }

    evaluate() {
        return this.logicOperation(this.intensityHits);
    }
}

class LightRayInterpreter {
    constructor() {
        this.prisms = [];
        this.gates = [];
    }

    addPrism(prism) { this.prisms.push(prism); }
    addGate(gate) { this.gates.push(gate); }

    // Calculates Snell's Law Refraction
    refract(dir, normal, ior1, ior2) {
        let eta = ior1 / ior2;
        let cosI = -normal.dot(dir);

        if (cosI < 0) {
            // Ray is exiting the volume
            normal = normal.multiply(-1);
            cosI = -normal.dot(dir);
        }

        const k = 1.0 - eta * eta * (1.0 - cosI * cosI);
        if (k < 0) {
            // Total Internal Reflection
            return dir.sub(normal.multiply(2 * dir.dot(normal)));
        }

        return dir.multiply(eta).add(normal.multiply(eta * cosI - Math.sqrt(k))).normalize();
    }

    // Trace ray through the 3D optical assembly
    traceRay(origin, direction, intensity = 1.0, depth = 0, maxDepth = 10) {
        if (depth >= maxDepth || intensity < 0.01) return;

        let closestT = Infinity;
        let hitPrism = null;

        // Find nearest glass prism intersection
        for (const prism of this.prisms) {
            const t = prism.intersect(origin, direction);
            if (t !== null && t < closestT) {
                closestT = t;
                hitPrism = prism;
            }
        }

        if (hitPrism) {
            const hitPoint = origin.add(direction.multiply(closestT));
            const normal = hitPrism.getNormalAt(hitPoint);
            
            // Determine refraction indices (air vs glass)
            const inside = direction.dot(normal) > 0;
            const ior1 = inside ? hitPrism.ior : 1.0;
            const ior2 = inside ? 1.0 : hitPrism.ior;

            const refractedDir = this.refract(direction, normal, ior1, ior2);
            
            // Recurse along the refracted light ray path
            const offsetOrigin = hitPoint.add(refractedDir.multiply(0.001));
            this.traceRay(offsetOrigin, refractedDir, intensity * 0.9, depth + 1, maxDepth);
        } else {
            // Ray travels into space and checks if it activates photo-reactive logic gates
            for (const gate of this.gates) {
                // Ray-plane / distance proximity check
                const toGate = gate.position.sub(origin);
                const proj = toGate.dot(direction);
                if (proj > 0) {
                    const closestPoint = origin.add(direction.multiply(proj));
                    gate.checkHit(closestPoint, intensity);
                }
            }
        }
    }

    executeProgram(rayEmitters) {
        // Fire all light rays into the 3D sculpture
        for (const ray of rayEmitters) {
            this.traceRay(ray.origin, ray.direction.normalize(), ray.intensity || 1.0);
        }

        // Evaluate photo-reactive logic gates hit by light
        const results = {};
        for (const gate of this.gates) {
            results[gate.id] = gate.evaluate();
        }
        return results;
    }
}

// --- Demo & Execution ---
const interpreter = new LightRayInterpreter();

// Assemble 3D Glass Sculpture
interpreter.addPrism(new SphereGlassPrism(new Vector3(0, 0, 5), 2.0, 1.5));
interpreter.addPrism(new SphereGlassPrism(new Vector3(1.5, 1.0, 8), 1.5, 1.8));

// Set up Photo-Reactive Logic Gate Array
interpreter.addGate(new PhotoReactiveGate("Gate_ADD", new Vector3(-2, 0, 12), 1.0, (intensity) => intensity > 0.5 ? "EXEC_ADD" : "SKIP"));
interpreter.addGate(new PhotoReactiveGate("Gate_SUB", new Vector3(2, 2, 12), 1.0, (intensity) => intensity > 0.2 ? "EXEC_SUB" : "SKIP"));
interpreter.addGate(new PhotoReactiveGate("Gate_HALT", new Vector3(0, -3, 12), 1.0, (intensity) => intensity > 0.0 ? "HALT" : "CONTINUE"));

// Define Laser Emitters (Instruction/Data Input Rays)
const inputRays = [
    { origin: new Vector3(-1, 0, 0), direction: new Vector3(0.2, 0.1, 1), intensity: 1.0 },
    { origin: new Vector3(1, 0.5, 0), direction: new Vector3(-0.1, 0.2, 1), intensity: 1.0 }
];

// Run the optical esoteric script
const executionState = interpreter.executeProgram(inputRays);
console.log("Esoteric Light Script Execution State:", executionState);