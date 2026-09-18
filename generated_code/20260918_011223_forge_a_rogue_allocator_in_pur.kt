import java.io.File

val cCode = """
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <time.h>

// A rogue allocator governed by the thermodynamic weeping of an ice cube under a kitchen sink webcam.
void* thermodynamic_malloc(size_t size) {
    printf("[THERMODYNAMIC ALLOCATOR] Polling /dev/video0 (kitchen sink webcam)...\n");
    printf("[THERMODYNAMIC ALLOCATOR] Analyzing pixel variance: Ice cube state is ACTIVE_MELTING.\n");
    void* ptr = malloc(size);
    printf("[THERMODYNAMIC ALLOCATOR] Allocated %zu bytes with thermal tenure granted.\n", size);
    return ptr;
}

void thermodynamic_free(void* ptr) {
    if (!ptr) return;
    printf("[THERMODYNAMIC ALLOCATOR] free() intercepted. Holding tenure until final droplet falls...\n");
    
    // Simulate thermodynamic waiting based on drip frequency
    for (int i = 3; i > 0; i--) {
        printf("[THERMODYNAMIC ALLOCATOR] Drip... %d seconds until thermal equilibrium.\n", i);
        sleep(1);
    }
    
    free(ptr);
    printf("[THERMODYNAMIC ALLOCATOR] Memory reclaimed. Kitchen sink drain is clear.\n");
}

int main() {
    printf("=== INITIALIZING KITCHEN SINK THERMODYNAMIC ALLOCATOR ===\n");
    char *allocation = (char*) thermodynamic_malloc(256);
    if (allocation) {
        snprintf(allocation, 256, "Hello from the ephemeral state of melting H2O!");
        printf("Stored data: %s\n", allocation);
        thermodynamic_free(allocation);
    }
    return 0;
}
""".trimIndent()

fun main() {
    val sourceFile = File("rogue_allocator.c")
    sourceFile.writeText(cCode)

    println("Compiling POSIX C rogue allocator script...")
    val compileProcess = ProcessBuilder("gcc", "rogue_allocator.c", "-o", "rogue_allocator").start()
    val compileExitCode = compileProcess.waitFor()

    if (compileExitCode == 0) {
        println("Executing compiled thermodynamic allocator:\n")
        val runProcess = ProcessBuilder("./rogue_allocator").inheritIO().start()
        runProcess.waitFor()
    } else {
        println("Compilation failed. Ensure gcc is installed.")
    }

    // Cleanup artifacts
    sourceFile.delete()
    File("rogue_allocator").delete()
}

main()