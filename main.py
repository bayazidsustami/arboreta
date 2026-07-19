import datetime
import os
import random
import time

from gemini_web2api.gemini import generate

class DummyMessage:
    def __init__(self, content):
        self.content = content

class DummyChoice:
    def __init__(self, message):
        self.message = message

class DummyResponse:
    def __init__(self, content):
        self.choices = [DummyChoice(DummyMessage(content))]

def call_api_with_retry(messages, temperature=0.7, extra_headers=None, max_retries=3):
    """Generic wrapper for Gemini API calls with exponential backoff retries."""
    
    # Convert messages list to a single prompt string
    prompt = ""
    for msg in messages:
        role = msg.get("role", "user")
        content = msg.get("content", "")
        prompt += f"{role.capitalize()}:\n{content}\n\n"
        
    for attempt in range(max_retries):
        try:
            # model_id=1 -> Gemini 1.5 Flash (default usually), model_id=2 -> Gemini 1.5 Pro
            # temperature is not directly supported by web API wrapper in the same way, so we ignore it
            content = generate(prompt, model_id=2, think_mode=0)
            if content:
                return DummyResponse(content)

            print(f"Attempt {attempt + 1}: Empty response from Gemini")
        except Exception as e:
            print(f"Attempt {attempt + 1}: API call failed: {e}")

        if attempt < max_retries - 1:
            wait_time = (2**attempt) + random.random()
            print(f"Retrying in {wait_time:.2f} seconds...")
            time.sleep(wait_time)

    return None

def generate_dynamic_prompt():
    """Asks the AI to come up with a random programming challenge."""
    recent_tasks = []
    if os.path.exists("generated_code"):
        files = sorted(os.listdir("generated_code"), reverse=True)[:5]
        recent_tasks = [
            f.split("_", 2)[-1].rsplit(".", 1)[0].replace("_", " ") for f in files
        ]

    context_msg = ""
    if recent_tasks:
        context_msg = (
            f" Avoid tasks similar to these recent ones: {', '.join(recent_tasks)}."
        )

    messages = [
        {
            "role": "system",
            "content": "You are a chaotic and imaginative software architect. You love esoteric programming, generative art, and quirky utilities.",
        },
        {
            "role": "user",
            "content": f"Generate a single, unique, and highly creative programming challenge that is unusual, artistic, or technically intriguing. Think about things like generative art, weird data visualizations, esoteric algorithms, or poetic code.{context_msg} Your response must be exactly one sentence, no markdown, no quotes.",
        },
    ]

    response = call_api_with_retry(messages, temperature=1.0)
    if response:
        return response.choices[0].message.content.strip()

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
        "4. No introductory or concluding text.\n"
        "5. Make the implementation as elegant and creative as possible."
    )

    messages = [
        {
            "role": "system",
            "content": f"You are an expert {lang} programmer with a flair for creative and efficient code.",
        },
        {"role": "user", "content": prompt},
    ]

    response = call_api_with_retry(messages, temperature=1.0)
    if response:
        return lang, response.choices[0].message.content.strip()

    return None, None


def generate_commit_message(task, lang):
    """Generates a short, creative commit message."""
    messages = [
        {
            "role": "system",
            "content": "You are a git expert who writes concise, emoji-rich commit messages.",
        },
        {
            "role": "user",
            "content": f"Write a one-line git commit message for adding a {lang} script that solves: '{task}'. Use an emoji. No markdown.",
        },
    ]

    response = call_api_with_retry(messages, temperature=0.8)
    if response:
        return response.choices[0].message.content.strip().replace('"', "")

    return f"feat: add {lang} snippet for {task[:20]}..."


def main():
    task = generate_dynamic_prompt()

    print(f"Selected Task: {task}")

    lang, code = generate_code(task)
    if not code:
        print("Failed to generate code.")
        exit(1)

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
