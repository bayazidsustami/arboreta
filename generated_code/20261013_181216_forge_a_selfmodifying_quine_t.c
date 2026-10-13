#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>
/* Self-modifying dying quine weeping colorful ASCII art into silence */
char *s="#include <stdio.h>%c#include <stdlib.h>%c#include <time.h>%c#include <unistd.h>%c/* Self-modifying dying quine weeping colorful ASCII art into silence */%cchar *s=%c%s%c;%cint main(){char b[2048];sprintf(b,s,10,10,10,10,10,34,s,34,10,10,34,34,10,10);srand(time(NULL));while(1){printf(%c\\033[36m .·° (T_T) °·. \\033[0m\\n%c);int a=0;for(int i=0;b[i];i++){if(b[i]!=' '&&(rand()%%100<8))b[i]=' ';if(b[i]!=' ')a++;putchar(b[i]); }putchar(10);if(a==0)break;usleep(150000);}%creturn 0;}%c";
int main(){char b[2048];sprintf(b,s,10,10,10,10,10,34,s,34,10,10,34,34,10,10);srand(time(NULL));while(1){printf("\033[36m .·° (T_T) °·. \033[0m\n");int a=0;for(int i=0;b[i];i++){if(b[i]!=' '&&(rand()%100<8))b[i]=' ';if(b[i]!=' ')a++;putchar(b[i]); }putchar(10);if(a==0)break;usleep(150000);}return 0;}