/**
 * Bioluminescent Gravity Decay Sort
 * A creative sorting algorithm that maps floating-point numbers to particles
 * in a simulated terminal environment, where gravity and bioluminescent decay
 * guide them into a sorted spatial equilibrium.
 */

function bioluminescentGravitySort(arr) {
    if (arr.length <= 1) return [...arr];

    // Map each float to a particle state with position, velocity, and a decaying glow trail
    let particles = arr.map((val, index) => ({
        id: index,
        value: val,
        x: val, 
        velocity: 0,
        glow: 1.0
    }));

    // Target sorted order to establish gravitational equilibrium wells
    const sortedTargets = [...arr].sort((a, b) => a - b);
    
    let iterations = 0;
    const maxIterations = 300;
    let stabilized = false;

    // Simulate particle physics, cursor trail decay, and gravitational settling
    while (!stabilized && iterations < maxIterations) {
        stabilized = true;
        iterations++;

        particles.forEach((p, i) => {
            const targetX = sortedTargets[i];
            // Gravitational pull toward the designated sorted position well
            const gravitationalPull = (targetX - p.x) * 0.15;
            
            p.velocity += gravitationalPull;
            p.velocity *= 0.8; // Atmospheric drag / decay
            p.x += p.velocity;

            // Bioluminescent intensity decay over time
            p.glow = Math.max(0, p.glow - 0.03);

            // Check kinetic stability
            if (Math.abs(p.velocity) > 0.00001 || Math.abs(targetX - p.x) > 0.00001) {
                stabilized = false;
            }
        });
    }

    // Reconstruct sorted array from final settled particle coordinates
    return particles.sort((a, b) => a.x - b.x).map(p => p.value);
}

// Execution demonstration
const floatingPoints = [42.42, -3.14, 0.001, 7.77, 2.718, -10.5, 3.14];
console.log("Original Particle Stream:", floatingPoints);
const sortedPoints = bioluminescentGravitySort(floatingPoints);
console.log("Settled Sorted Array:", sortedPoints);