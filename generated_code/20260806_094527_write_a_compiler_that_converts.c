#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#define MAX_NAME 64
#define MAX_TEXT 256
#define MAX_ROWS 100
#define MAX_COLS 10
#define MAX_TABLES 10

typedef enum { TYPE_INT, TYPE_TEXT } DataType;

typedef struct {
    char name[MAX_NAME];
    DataType type;
} Column;

typedef struct {
    char data[MAX_TEXT];
} Cell;

typedef struct {
    char name[MAX_NAME];
    Column columns[MAX_COLS];
    int col_count;
    Cell data[MAX_ROWS][MAX_COLS];
    int row_count;
    
    // Foreign key relationship definition
    int fk_col;
    char target_table[MAX_NAME];
    int target_col;
} Table;

typedef struct {
    Table tables[MAX_TABLES];
    int table_count;
    int migration_version;
} Database;

// Helper to create or find a table
Table* get_or_create_table(Database *db, const char *name) {
    for (int i = 0; i < db->table_count; i++) {
        if (strcmp(db->tables[i].name, name) == 0) {
            return &db->tables[i];
        }
    }
    Table *t = &db->tables[db->table_count++];
    memset(t, 0, sizeof(Table));
    strncpy(t->name, name, MAX_NAME - 1);
    t->fk_col = -1;
    return t;
}

// Add column to table schema
int add_column(Table *t, const char *col_name, DataType type) {
    for (int i = 0; i < t->col_count; i++) {
        if (strcmp(t->columns[i].name, col_name) == 0) return i;
    }
    int idx = t->col_count++;
    strncpy(t->columns[idx].name, col_name, MAX_NAME - 1);
    t->columns[idx].type = type;
    return idx;
}

// Find character ID by name, creating record if absent
int get_or_create_character(Database *db, const char *char_name) {
    Table *chars = get_or_create_table(db, "characters");
    if (chars->col_count == 0) {
        add_column(chars, "id", TYPE_INT);
        add_column(chars, "name", TYPE_TEXT);
    }
    
    for (int i = 0; i < chars->row_count; i++) {
        if (strcmp(chars->data[i][1].data, char_name) == 0) {
            return atoi(chars->data[i][0].data);
        }
    }
    
    int new_id = chars->row_count + 1;
    snprintf(chars->data[chars->row_count][0].data, MAX_TEXT, "%d", new_id);
    strncpy(chars->data[chars->row_count][1].data, char_name, MAX_TEXT - 1);
    chars->row_count++;
    return new_id;
}

// Execute automated schema migration upon narrative twist
void trigger_schema_migration(Database *db, const char *twist_keyword) {
    db->migration_version++;
    printf("\n=== [MIGRATION v%d TRIGGERED BY TWIST: '%s'] ===\n", db->migration_version, twist_keyword);
    
    Table *chars = get_or_create_table(db, "characters");
    
    if (db->migration_version == 1) {
        int col = add_column(chars, "allegiance", TYPE_TEXT);
        printf("Schema Alteration: Added column 'allegiance' to table 'characters'\n");
        for (int i = 0; i < chars->row_count; i++) {
            strncpy(chars->data[i][col].data, "Suspect", MAX_TEXT - 1);
        }
    } else if (db->migration_version == 2) {
        int col = add_column(chars, "secret_identity", TYPE_TEXT);
        printf("Schema Alteration: Added column 'secret_identity' to table 'characters'\n");
        for (int i = 0; i < chars->row_count; i++) {
            strncpy(chars->data[i][col].data, "Unrevealed", MAX_TEXT - 1);
        }
    } else {
        char col_name[MAX_NAME];
        snprintf(col_name, MAX_NAME, "twist_flag_%d", db->migration_version);
        add_column(chars, col_name, TYPE_TEXT);
        printf("Schema Alteration: Added column '%s' to table 'characters'\n", col_name);
    }
    printf("===================================================\n\n");
}

// Process a line of novella text
void compile_line(Database *db, const char *line) {
    // Check for Plot Twists (trigering migrations)
    if (strstr(line, "TWIST:") || strstr(line, "SUDDENLY:") || strstr(line, "REVEAL:")) {
        char keyword[MAX_NAME];
        sscanf(line, "%63s", keyword);
        trigger_schema_migration(db, keyword);
        return;
    }

    // Parse Dialogue: "Character: Message"
    const char *colon = strchr(line, ':');
    if (colon != NULL) {
        char speaker[MAX_NAME];
        size_t name_len = colon - line;
        if (name_len >= MAX_NAME) name_len = MAX_NAME - 1;
        strncpy(speaker, line, name_len);
        speaker[name_len] = '\0';

        // Trim whitespaces
        char *s = speaker;
        while(isspace(*s)) s++;
        
        const char *dialogue_text = colon + 1;
        while(isspace(*dialogue_text)) dialogue_text++;

        if (strlen(s) > 0 && strlen(dialogue_text) > 0) {
            int char_id = get_or_create_character(db, s);

            Table *dialogues = get_or_create_table(db, "dialogues");
            if (dialogues->col_count == 0) {
                add_column(dialogues, "id", TYPE_INT);
                add_column(dialogues, "character_id", TYPE_INT); // FOREIGN KEY -> characters.id
                add_column(dialogues, "line", TYPE_TEXT);
                
                // Define Foreign Key metadata
                dialogues->fk_col = 1;
                strncpy(dialogues->target_table, "characters", MAX_NAME - 1);
                dialogues->target_col = 0;
            }

            int row = dialogues->row_count;
            snprintf(dialogues->data[row][0].data, MAX_TEXT, "%d", row + 1);
            snprintf(dialogues->data[row][1].data, MAX_TEXT, "%d", char_id);
            strncpy(dialogues->data[row][2].data, dialogue_text, MAX_TEXT - 1);
            dialogues->row_count++;
        }
    }
}

// Print full relational database state
void print_database(Database *db) {
    printf("\n=========================================\n");
    printf("       FINAL RELATIONAL DATABASE         \n");
    printf("=========================================\n");

    for (int t = 0; t < db->table_count; t++) {
        Table *tbl = &db->tables[t];
        printf("\nTABLE: %s\n", tbl->name);
        
        if (tbl->fk_col != -1) {
            printf("[FOREIGN KEY: %s -> %s(id)]\n", 
                   tbl->columns[tbl->fk_col].name, tbl->target_table);
        }

        // Print header
        for (int c = 0; c < tbl->col_count; c++) {
            printf("| %-18s ", tbl->columns[c].name);
        }
        printf("|\n");

        for (int c = 0; c < tbl->col_count; c++) {
            printf("|--------------------");
        }
        printf("|\n");

        // Print rows
        for (int r = 0; r < tbl->row_count; r++) {
            for (int c = 0; c < tbl->col_count; c++) {
                char *val = tbl->data[r][c].data;
                printf("| %-18s ", strlen(val) > 0 ? val : "NULL");
            }
            printf("|\n");
        }
    }
    printf("=========================================\n");
}

int main(void) {
    // Sample Plain-Text Novella Input
    const char *novella[] = {
        "Alice: The weather is curiously calm tonight.",
        "Bob: Indeed, but the atmosphere feels heavy.",
        "TWIST: The power goes out completely.",
        "Alice: Who turned off the lights?",
        "Charlie: It wasn't me, I just arrived!",
        "REVEAL: Charlie was the mastermind all along.",
        "Bob: I knew we couldn't trust you!",
        "Charlie: It is too late now."
    };

    int num_lines = sizeof(novella) / sizeof(novella[0]);
    Database db;
    memset(&db, 0, sizeof(Database));

    printf("Compiling Novella into Relational Database...\n\n");

    for (int i = 0; i < num_lines; i++) {
        printf("[Reading Line %d]: %s\n", i + 1, novella[i]);
        compile_line(&db, novella[i]);
    }

    print_database(&db);

    return 0;
}