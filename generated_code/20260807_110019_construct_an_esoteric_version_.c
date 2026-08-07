/*
 * EvoVCS: An Esoteric Genetic Version Control System
 * Commits are stored as digital DNA sequences (A, C, G, T).
 * Merging is achieved through cross-breeding, random mutation,
 * and fitness-based natural selection across generations.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define DNA_LEN 64
#define POP_SIZE 50
#define GENERATIONS 100

typedef struct {
    char dna[DNA_LEN + 1];
    int fitness;
} Organism;

// Translate text byte into a 4-base DNA sequence
void text_to_dna(const char *text, char *dna) {
    const char bases[] = "ACGT";
    int i;
    for (i = 0; i < DNA_LEN / 4 && text[i] != '\0'; i++) {
        unsigned char c = (unsigned char)text[i];
        dna[i * 4 + 0] = bases[(c >> 6) & 3];
        dna[i * 4 + 1] = bases[(c >> 4) & 3];
        dna[i * 4 + 2] = bases[(c >> 2) & 3];
        dna[i * 4 + 3] = bases[c & 3];
    }
    for (; i * 4 < DNA_LEN; i++) {
        dna[i * 4 + 0] = 'A'; dna[i * 4 + 1] = 'A';
        dna[i * 4 + 2] = 'A'; dna[i * 4 + 3] = 'A';
    }
    dna[DNA_LEN] = '\0';
}

// Decode DNA sequence back to readable text
void dna_to_text(const char *dna, char *text) {
    for (int i = 0; i < DNA_LEN / 4; i++) {
        unsigned char c = 0;
        for (int b = 0; b < 4; b++) {
            char base = dna[i * 4 + b];
            int val = (base == 'C') ? 1 : (base == 'G') ? 2 : (base == 'T') ? 3 : 0;
            c = (c << 2) | val;
        }
        text[i] = (c >= 32 && c <= 126) ? (char)c : '.';
    }
    text[DNA_LEN / 4] = '\0';
}

// Random base substitution mutation
void mutate(char *dna, float rate) {
    const char bases[] = "ACGT";
    for (int i = 0; i < DNA_LEN; i++) {
        if ((float)rand() / RAND_MAX < rate) {
            dna[i] = bases[rand() % 4];
        }
    }
}

// Cross-breed two parent commit organisms at a random locus
void cross_breed(const Organism *p1, const Organism *p2, Organism *child) {
    int crossover_point = rand() % DNA_LEN;
    for (int i = 0; i < DNA_LEN; i++) {
        child->dna[i] = (i < crossover_point) ? p1->dna[i] : p2->dna[i];
    }
    child->dna[DNA_LEN] = '\0';
}

// Fitness metric based on trait survival alignment
int evaluate_fitness(const char *dna, const char *target_dna) {
    int score = 0;
    for (int i = 0; i < DNA_LEN; i++) {
        if (dna[i] == target_dna[i]) score++;
    }
    return score;
}

// Resolve merge conflicts through simulated natural selection
void natural_selection_merge(const Organism *commit_a, const Organism *commit_b, Organism *merged_commit) {
    Organism population[POP_SIZE];
    
    // Ideal consensus genome targeted by the environment
    char target[DNA_LEN + 1];
    for (int i = 0; i < DNA_LEN; i++) {
        target[i] = (i % 2 == 0) ? commit_a->dna[i] : commit_b->dna[i];
    }
    target[DNA_LEN] = '\0';

    // Seed population with ancestor commit DNA
    for (int i = 0; i < POP_SIZE; i++) {
        if (i % 2 == 0) strcpy(population[i].dna, commit_a->dna);
        else strcpy(population[i].dna, commit_b->dna);
        mutate(population[i].dna, 0.05f);
        population[i].fitness = evaluate_fitness(population[i].dna, target);
    }

    // Evolve population over generations
    for (int gen = 0; gen < GENERATIONS; gen++) {
        // Sort population by fitness (descending)
        for (int i = 0; i < POP_SIZE - 1; i++) {
            for (int j = i + 1; j < POP_SIZE; j++) {
                if (population[j].fitness > population[i].fitness) {
                    Organism tmp = population[i];
                    population[i] = population[j];
                    population[j] = tmp;
                }
            }
        }

        // Fittest survival & re-breeding
        for (int i = POP_SIZE / 2; i < POP_SIZE; i++) {
            int p1 = rand() % (POP_SIZE / 2);
            int p2 = rand() % (POP_SIZE / 2);
            cross_breed(&population[p1], &population[p2], &population[i]);
            mutate(population[i].dna, 0.02f);
            population[i].fitness = evaluate_fitness(population[i].dna, target);
        }
    }

    // Apex predator organism becomes the merged commit
    *merged_commit = population[0];
}

int main(void) {
    srand((unsigned int)time(NULL));

    Organism commit_a, commit_b, resolved_commit;
    char text_out[DNA_LEN / 4 + 1];

    text_to_dna("Feature_Branch_Alpha", commit_a.dna);
    text_to_dna("Feature_Branch_Beta!", commit_b.dna);

    printf("=== ESOTERIC GENETIC VERSION CONTROL SYSTEM ===\n\n");
    
    dna_to_text(commit_a.dna, text_out);
    printf("Commit A DNA : %s\nText Content : %s\n\n", commit_a.dna, text_out);

    dna_to_text(commit_b.dna, text_out);
    printf("Commit B DNA : %s\nText Content : %s\n\n", commit_b.dna, text_out);

    printf("Simulating Natural Selection Merge across 100 generations...\n\n");
    natural_selection_merge(&commit_a, &commit_b, &resolved_commit);

    dna_to_text(resolved_commit.dna, text_out);
    printf("Resolved Merge DNA    : %s\n", resolved_commit.dna);
    printf("Resolved Text Content : %s\n", text_out);
    printf("Evolutive Fitness Score: %d/%d\n", resolved_commit.fitness, DNA_LEN);

    return 0;
}