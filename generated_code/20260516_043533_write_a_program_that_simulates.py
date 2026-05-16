#!/usr/bin/env python3
# Lost Sock vs Washing Machine: Emoji Haiku Conversation
# The sock expresses existential dread in haiku (three lines),
# the washing machine replies with a troubleshooting tip.
# All dialogue is rendered using only emojis.

def main():
    # Haiku lines for the lost sock (three lines per haiku)
    haikus = [
        ["🧦🌫️💔", "🌀🔍🕳️", "🕰️💭🔚"],
        ["🧦🪳🥶", "🫥🔍🕳️", "⏳💭🔚"],
        ["🧦🫧🫧", "🌀🔍🕳️", "🌑💭🔚"]
    ]
    # Washing machine troubleshooting tips (one line per tip)
    tips = ["🧺🧼✅", "🔧🧩🔍", "🚿🔄🧹"]
    
    # Print the conversation: each haiku followed by its corresponding tip
    for haiku, tip in zip(haikus, tips):
        for line in haiku:
            print(line)
        print(tip)

if __name__ == "__main__":
    main()