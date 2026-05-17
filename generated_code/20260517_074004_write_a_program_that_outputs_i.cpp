#include <bits/stdc++.h>
#include <unistd.h>
using namespace std;

// Simple map for printable ASCII to their Unicode names (partial)
static const unordered_map<char,string> asciiNames = {
    {' ', "SPACE"}, {'\n',"LINE_FEED"}, {'\t',"CHARACTER_TABULATION"},
    {'!',"EXCLAMATION_MARK"}, {'"', "QUOTATION_MARK"}, {'#',"NUMBER_SIGN"},
    {'$',"DOLLAR_SIGN"}, {'%',"PERCENT_SIGN"}, {'&',"AMPERSAND"},
    {'\'',"APOSTROPHE"}, {'(', "LEFT_PARENTHESIS"}, {')',"RIGHT_PARENTHESIS"},
    {'*',"ASTERISK"}, {'+', "PLUS_SIGN"}, {',',"COMMA"},
    {'-',"HYPHEN_MINUS"}, {'.',"FULL_STOP"}, {'/',"SOLIDUS"},
    {'0',"DIGIT_ZERO"}, {'1',"DIGIT_ONE"}, {'2',"DIGIT_TWO"},
    {'3',"DIGIT_THREE"}, {'4',"DIGIT_FOUR"}, {'5',"DIGIT_FIVE"},
    {'6',"DIGIT_SIX"}, {'7',"DIGIT_SEVEN"}, {'8',"DIGIT_EIGHT"},
    {'9',"DIGIT_NINE"}, {':',"COLON"}, {';',"SEMICOLON"},
    {'<',"LESS_THAN_SIGN"}, {'=',"EQUALS_SIGN"}, {'>',"GREATER_THAN_SIGN"},
    {'?', "QUESTION_MARK"}, {'@',"COMMERCIAL_AT"},
    {'A',"LATIN_CAPITAL_LETTER_A"}, {'B',"LATIN_CAPITAL_LETTER_B"},
    {'C',"LATIN_CAPITAL_LETTER_C"}, {'D',"LATIN_CAPITAL_LETTER_D"},
    {'E',"LATIN_CAPITAL_LETTER_E"}, {'F',"LATIN_CAPITAL_LETTER_F"},
    {'G',"LATIN_CAPITAL_LETTER_G"}, {'H',"LATIN_CAPITAL_LETTER_H"},
    {'I',"LATIN_CAPITAL_LETTER_I"}, {'J',"LATIN_CAPITAL_LETTER_J"},
    {'K',"LATIN_CAPITAL_LETTER_K"}, {'L',"LATIN_CAPITAL_LETTER_L"},
    {'M',"LATIN_CAPITAL_LETTER_M"}, {'N',"LATIN_CAPITAL_LETTER_N"},
    {'O',"LATIN_CAPITAL_LETTER_O"}, {'P',"LATIN_CAPITAL_LETTER_P"},
    {'Q',"LATIN_CAPITAL_LETTER_Q"}, {'R',"LATIN_CAPITAL_LETTER_R"},
    {'S',"LATIN_CAPITAL_LETTER_S"}, {'T',"LATIN_CAPITAL_LETTER_T"},
    {'U',"LATIN_CAPITAL_LETTER_U"}, {'V',"LATIN_CAPITAL_LETTER_V"},
    {'W',"LATIN_CAPITAL_LETTER_W"}, {'X',"LATIN_CAPITAL_LETTER_X"},
    {'Y',"LATIN_CAPITAL_LETTER_Y"}, {'Z',"LATIN_CAPITAL_LETTER_Z"},
    {'[',"LEFT_SQUARE_BRACKET"}, {'\\',"REVERSE_SOLIDUS"},
    {']',"RIGHT_SQUARE_BRACKET"}, {'^',"CIRCUMFLEX_ACCENT"},
    {'_',"LOW_LINE"}, {'`',"GRAVE_ACCENT"},
    {'a',"LATIN_SMALL_LETTER_A"}, {'b',"LATIN_SMALL_LETTER_B"},
    {'c',"LATIN_SMALL_LETTER_C"}, {'d',"LATIN_SMALL_LETTER_D"},
    {'e',"LATIN_SMALL_LETTER_E"}, {'f',"LATIN_SMALL_LETTER_F"},
    {'g',"LATIN_SMALL_LETTER_G"}, {'h',"LATIN_SMALL_LETTER_H"},
    {'i',"LATIN_SMALL_LETTER_I"}, {'j',"LATIN_SMALL_LETTER_J"},
    {'k',"LATIN_SMALL_LETTER_K"}, {'l',"LATIN_SMALL_LETTER_L"},
    {'m',"LATIN_SMALL_LETTER_M"}, {'n',"LATIN_SMALL_LETTER_N"},
    {'o',"LATIN_SMALL_LETTER_O"}, {'p',"LATIN_SMALL_LETTER_P"},
    {'q',"LATIN_SMALL_LETTER_Q"}, {'r',"LATIN_SMALL_LETTER_R"},
    {'s',"LATIN_SMALL_LETTER_S"}, {'t',"LATIN_SMALL_LETTER_T"},
    {'u',"LATIN_SMALL_LETTER_U"}, {'v',"LATIN_SMALL_LETTER_V"},
    {'w',"LATIN_SMALL_LETTER_W"}, {'x',"LATIN_SMALL_LETTER_X"},
    {'y',"LATIN_SMALL_LETTER_Y"}, {'z',"LATIN_SMALL_LETTER_Z"},
    {'{',"LEFT_CURLY_BRACKET"}, {'|',"VERTICAL_LINE"},
    {'}',"RIGHT_CURLY_BRACKET"}, {'~',"TILDE"}
};

string unicodeName(char c){
    auto it = asciiNames.find(c);
    if(it!=asciiNames.end()) return it->second;
    // Fallback: generic U+XXXX notation
    char buf[10];
    snprintf(buf,sizeof(buf),"U+%04X",(unsigned char)c);
    return string(buf);
}

int main(){
    ios::sync_with_stdio(false);
    cin.tie(nullptr);

    // read own source
    string selfPath = argv[0];
    ifstream in(selfPath, ios::binary);
    if(!in){ cerr<<"Cannot open source.\n"; return 1; }
    string source((istreambuf_iterator<char>(in)), {});
    size_t length = source.size();

    cout<<"How many characters are in my source? ";
    size_t guess;
    if(!(cin>>guess)){
        cerr<<"Invalid input.\n";
        return 1;
    }

    if(guess==length){
        // correct: output Unicode names
        for(char c: source){
            cout<<unicodeName(c)<<" ";
        }
        cout<<"\n";
        // delete self
        if(remove(selfPath.c_str())!=0){
            perror("Failed to delete self");
        }
    }else{
        // wrong: haiku about recursion
        cout<<"Infinite loops descend\n"
            "Calling selves till dawn breaks\n"
            "Base case never found\n";
    }
    return 0;
}