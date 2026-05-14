import datetime
import os
import random

from openai import OpenAI

# Configure the API key from environment variables
api_key = os.environ.get("OPENAI_API_KEY")
base_url = os.environ.get("OPENAI_BASE_URL", "https://api.openai.com/v1")
model_name = os.environ.get("OPENAI_MODEL_NAME", "gpt-4o-mini")

if not api_key:
    print("Error: OPENAI_API_KEY environment variable not set.")
    exit(1)

client = OpenAI(api_key=api_key, base_url=base_url)


def generate_dynamic_prompt():
    """Asks the AI to come up with a random programming challenge."""
    try:
        response = client.chat.completions.create(
            extra_headers={
                "HTTP-Referer": "https://github.com/bayazidsustami/arboreta",
                "X-OpenRouter-Title": "Arboreta",
            },
            model=model_name,
            messages=[
                {
                    "role": "system",
                    "content": "You are a creative brainstorming assistant.",
                },
                {
                    "role": "user",
                    "content": "Give me a short, one-sentence description of a random, creative, or obscure programming task. It could be a specific algorithm, a tiny utility, a mathematical simulation, or a quirky text manipulation. Be specific but concise. Do not use markdown.",
                },
            ],
            temperature=1.0,
        )
        return response.choices[0].message.content.strip()
    except Exception as e:
        print(f"Error generating meta-prompt: {e}")
        return "Write a script that simulates a simple cellular automaton."


def generate_code(task):
    """Generates code for the given task in a random language."""
    languages = [
        "Python",
        "JavaScript",
        "TypeScript",
        "Go",
        "Rust",
        "Ruby",
        "C",
        "C++",
        "Kotlin",
        "Swift",
        "Lua",
        "Haskell",
        "Bash",
    ]
    lang = random.choice(languages)

    prompt = (
        f"Write a complete, working {lang} script that solves this task: '{task}'.\n"
        "Requirements:\n"
        "1. The code must be self-contained and runnable.\n"
        "2. Include brief comments explaining what it does.\n"
        "3. Return ONLY the raw code. DO NOT include markdown code blocks (like ```python ... ```).\n"
        "4. No introductory or concluding text."
    )

    try:
        response = client.chat.completions.create(
            extra_headers={
                "HTTP-Referer": "https://github.com/bayazidsustami/arboreta",
                "X-OpenRouter-Title": "Arboreta",
            },
            model=model_name,
            messages=[
                {"role": "system", "content": f"You are an expert {lang} programmer."},
                {"role": "user", "content": prompt},
            ],
            temperature=0.7,
        )
        return lang, response.choices[0].message.content.strip()
    except Exception as e:
        print(f"Error generating code: {e}")
        return None, None


def generate_commit_message(task, lang):
    """Generates a short, creative commit message."""
    try:
        response = client.chat.completions.create(
            model=model_name,
            messages=[
                {
                    "role": "system",
                    "content": "You are a git expert who writes concise, emoji-rich commit messages.",
                },
                {
                    "role": "user",
                    "content": f"Write a one-line git commit message for adding a {lang} script that solves: '{task}'. Use an emoji. No markdown.",
                },
            ],
            temperature=0.8,
        )
        return response.choices[0].message.content.strip().replace('"', "")
    except Exception as e:
        print(f"Error generating commit message: {e}")
        return f"feat: add {lang} snippet for {task[:20]}..."


def main():
    task = generate_dynamic_prompt()

    print(f"Selected Task: {task}")

    lang, code = generate_code(task)
    if not code:
        print("Failed to generate code.")
        return

    commit_msg = generate_commit_message(task, lang)
    print(f"Suggested Commit Message: {commit_msg}")

    # Map languages to extensions
    extensions = {
        "Python": "py",
        "JavaScript": "js",
        "TypeScript": "ts",
        "Go": "go",
        "Rust": "rs",
        "Ruby": "rb",
        "C": "c",
        "C++": "cpp",
        "Kotlin": "kt",
        "Swift": "swift",
        "Lua": "lua",
        "Haskell": "hs",
        "Bash": "sh",
    }
    ext = extensions.get(lang, "txt")

    # Create a unique filename
    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    safe_task = (
        "".join(c for c in task[:30] if c.isalnum() or c == " ")
        .replace(" ", "_")
        .lower()
    )
    filename = f"generated_code/{timestamp}_{safe_task}.{ext}"

    # Save the code file
    os.makedirs("generated_code", exist_ok=True)
    with open(filename, "w") as f:
        f.write(code)

    # Save the commit message to a temp file for the GitHub Action to read
    with open("commit_msg.txt", "w") as f:
        f.write(commit_msg)

    print(f"Successfully generated {filename}")


if __name__ == "__main__":
    main()
