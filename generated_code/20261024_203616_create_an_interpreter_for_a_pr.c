#include <stdio.h>
#include <stdlib.h>
#include <math.h>

#define G 1.0
#define DT 0.05
#define MAX_STEPS 500

// Represents a celestial body acting as a variable and program actor
typedef struct {
    double x, y;     // Position in 2D space
    double vx, vy;   // Velocity vector (momentum)
    double mass;     // Mass of the body (influences gravitational pull)
    double value;    // Stored variable value
    int id;          // Variable identifier
    int alive;       // Active state
} Body;

int main() {
    // Initialize program variables as orbiting bodies
    // Body 1: Accumulator star at center
    // Body 2 & 3: Operand planets with initial velocities forming orbits
    Body bodies[3] = {
        {0.0, 0.0, 0.0, 0.0, 50.0, 10.0, 1, 1},
        {12.0, 0.0, 0.0, 2.0, 1.0, 42.0, 2, 1},
        {-15.0, 0.0, 0.0, -1.8, 1.0, 100.0, 3, 1}
    };
    int n = 3;

    printf("--- Orbit-Lang Interpreter Initialized ---\n");

    // Main execution loop driven by physics simulation
    for (int step = 0; step < MAX_STEPS; step++) {
        // Compute gravitational forces and detect momentum collisions
        for (int i = 0; i < n; i++) {
            if (!bodies[i].alive) continue;
            for (int j = i + 1; j < n; j++) {
                if (!bodies[j].alive) continue;

                double dx = bodies[j].x - bodies[i].x;
                double dy = bodies[j].y - bodies[i].y;
                double distSq = dx * dx + dy * dy + 1e-4;
                double dist = sqrt(distSq);

                // Collision event: execution of an arithmetic operation (fusion)
                if (dist < 1.5) {
                    bodies[i].value += bodies[j].value;
                    printf("[STEP %d] Collision! Body %d absorbed Body %d. New value [%d] = %.2f\n", 
                           step, bodies[i].id, bodies[j].id, bodies[i].id, bodies[i].value);
                    bodies[j].alive = 0;
                    continue;
                }

                // Universal gravitation update
                double force = G * bodies[i].mass * bodies[j].mass / distSq;
                double fx = force * (dx / dist);
                double fy = force * (dy / dist);

                bodies[i].vx += (fx / bodies[i].mass) * DT;
                bodies[i].vy += (fy / bodies[i].mass) * DT;
                bodies[j].vx -= (fx / bodies[j].mass) * DT;
                bodies[j].vy -= (fy / bodies[j].mass) * DT;
            }
        }

        // Update positions based on velocity (momentum flow)
        for (int i = 0; i < n; i++) {
            if (!bodies[i].alive) continue;
            bodies[i].x += bodies[i].vx * DT;
            bodies[i].y += bodies[i].vy * DT;
        }
    }

    printf("--- Execution Terminated ---\n");
    printf("Final Program Output (Accumulator Value): %.2f\n", bodies[0].value);
    return 0;
}