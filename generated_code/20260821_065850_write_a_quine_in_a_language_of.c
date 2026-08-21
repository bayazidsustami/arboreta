#include <stdio.h>

/*
 * A Quine in C that generates a self-contained SVG image.
 * The SVG renders a maze where the walls are formed by the source code characters.
 */

int main(void) {
    // Source code template with %s used to insert the string representation of itself
    char *s = "#include <stdio.h>%c%c/*%c * A Quine in C that generates a self-contained SVG image.%c * The SVG renders a maze where the walls are formed by the source code characters.%c */%c%cint main(void) {%c    // Source code template with %%s used to insert the string representation of itself%c    char *s = %c%s%c;%c    char buf[8000];%c    int len = sprintf(buf, s, 10, 10, 10, 10, 10, 10, 10, 10, 10, 34, s, 34, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10);%c%c    // Simple maze generator using a deterministic pseudo-random layout based on character indices%c    printf(%c<svg xmlns=%c[http://www.w3.org/2000/svg%c](http://www.w3.org/2000/svg%c) width=%c800%c height=%c600%c viewBox=%c0 0 800 600%c>%c, 34, 34, 34, 34, 34, 34, 34, 34, 10);%c    printf(%c<rect width=%c100%%25%c height=%c100%%25%c fill=%c#1e1e2e%c/>%c, 34, 34, 34, 34, 34, 34, 10);%c    printf(%c<g font-family=%cmonospace%c font-size=%c12%c fill=%c#a6e3a1%c text-anchor=%cmiddle%c>%c, 34, 34, 34, 34, 34, 34, 34, 34, 10);%c%c    int cols = 50;%c    int idx = 0;%c    for (int y = 30; y < 580 && idx < len; y += 16) {%c        for (int x = 20; x < 780 && idx < len; x += 15) {%c            char c = buf[idx++];%c            if (c == 10) c = ' '; // Replace newlines with spaces for wall rendering%c            // Deterministic offset to twist grid into a maze-like path%c            int shift_x = ((idx * 13 + y * 7) %% 5) - 2;%c            int shift_y = ((idx * 17 + x * 3) %% 5) - 2;%c            %c            // Render character as part of maze wall%c            if (c == '&') printf(%c<text x=%c%d%c y=%c%d%c>&amp;</text>%c, 34, x + shift_x, 34, 34, y + shift_y, 34, 10);%c            else if (c == '<') printf(%c<text x=%c%d%c y=%c%d%c>&lt;</text>%c, 34, x + shift_x, 34, 34, y + shift_y, 34, 10);%c            else if (c == '>') printf(%c<text x=%c%d%c y=%c%d%c>&gt;</text>%c, 34, x + shift_x, 34, 34, y + shift_y, 34, 10);%c            else if (c == '"') printf(%c<text x=%c%d%c y=%c%d%c>&quot;</text>%c, 34, x + shift_x, 34, 34, y + shift_y, 34, 10);%c            else printf(%c<text x=%c%d%c y=%c%d%c>%c</text>%c, 34, x + shift_x, 34, 34, y + shift_y, 34, c, 10);%c        }%c    }%c    printf(%c</g></svg>%c, 10);%c    return 0;%c}%c";
    char buf[8000];
    int len = sprintf(buf, s, 10, 10, 10, 10, 10, 10, 10, 10, 10, 34, s, 34, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10);

    // Simple maze generator using a deterministic pseudo-random layout based on character indices
    printf("<svg xmlns=\"[http://www.w3.org/2000/svg](http://www.w3.org/2000/svg)\" width=\"800\" height=\"600\" viewBox=\"0 0 800 600\">\n");
    printf("<rect width=\"100%%\" height=\"100%%\" fill=\"#1e1e2e\"/>\n");
    printf("<g font-family=\"monospace\" font-size=\"12\" fill=\"#a6e3a1\" text-anchor=\"middle\">\n");

    int cols = 50;
    int idx = 0;
    for (int y = 30; y < 580 && idx < len; y += 16) {
        for (int x = 20; x < 780 && idx < len; x += 15) {
            char c = buf[idx++];
            if (c == 10) c = ' '; // Replace newlines with spaces for wall rendering
            // Deterministic offset to twist grid into a maze-like path
            int shift_x = ((idx * 13 + y * 7) % 5) - 2;
            int shift_y = ((idx * 17 + x * 3) % 5) - 2;
            
            // Render character as part of maze wall
            if (c == '&') printf("<text x=\"%d\" y=\"%d\">&amp;</text>\n", x + shift_x, y + shift_y);
            else if (c == '<') printf("<text x=\"%d\" y=\"%d\">&lt;</text>\n", x + shift_x, y + shift_y);
            else if (c == '>') printf("<text x=\"%d\" y=\"%d\">&gt;</text>\n", x + shift_x, y + shift_y);
            else if (c == '"') printf("<text x=\"%d\" y=\"%d\">&quot;</text>\n", x + shift_x, y + shift_y);
            else printf("<text x=\"%d\" y=\"%d\">%c</text>\n", x + shift_x, y + shift_y, c);
        }
    }
    printf("</g></svg>\n");
    return 0;
}