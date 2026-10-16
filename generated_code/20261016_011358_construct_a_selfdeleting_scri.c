#include <stdio.h>
#include <stdlib.h>
#include <dirent.h>
#include <sys/stat.h>
#include <unistd.h>
#include <time.h>

/* Melancholic haikus about fading files and digital ephemera */
const char *haikus[] = {
    "Data fades away,\nSilent bytes drift in the dark,\nNothing stays at last.",
    "Timestamps turn to dust,\nFolders empty in the wind,\nEchoes of a name.",
    "Constellations shift,\nStorage clears its heavy heart,\nEmpty space remains."
};

int main(int argc, char *argv[]) {
    DIR *dir = opendir(".");
    if (!dir) return 1;

    struct dirent *entry;
    struct stat st;
    
    /* Clear terminal screen and prepare canvas */
    printf("\033[2J\033[H");
    srand(time(NULL));

    int count = 0;
    /* Read local directory metadata and render shifting ASCII stars */
    while ((entry = readdir(dir)) != NULL && count < 35) {
        if (entry->d_name[0] == '.') continue;
        if (stat(entry->d_name, &st) == 0) {
            int x = (st.st_size % 70) + 2;
            int y = (st.st_mtime % 18) + 2;
            
            printf("\033[%d;%dH*", y, x);
            fflush(stdout);
            usleep(80000);
        }
        count++;
    }
    closedir(dir);

    /* Display a melancholic haiku at the bottom */
    printf("\n\n\033[22;2H--- Whispers from the Void ---\n\033[23;2H%s\n", haikus[time(NULL) % 3]);

    /* Attempt to vocalize via system speech synthesizer if available */
    system("which say > /dev/null 2>&1 && say 'Data fades away into the silent dark.' &");

    /* Self-deletion mechanism: remove executable from the file system */
    if (argv[0]) {
        usleep(1500000); // Brief pause before vanishing
        remove(argv[0]);
    }

    return 0;
}