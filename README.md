# Arboreta: The Fully Autonomous Repo

This repository is an experiment in autonomous code generation. Every day, a GitHub Action triggers an AI to:
1. Come up with a completely random and creative programming task.
2. Choose a random programming language.
3. Solve that task.
4. **Generate a creative git commit message for the change.**
5. Commit and push the code back to this repository.

## How it works
- **The Brain:** `main.py` uses any OpenAI-standard API. It first "meta-prompts" the AI to get a random task, then prompts it again to write the solution and a commit message.
- **The Schedule:** GitHub Actions runs this script daily via a CRON job.
- **The Collection:** All generated code lives in the `generated_code/` directory.


## Setup
If you want to run this yourself:
1. Fork this repo.
2. Add your API credentials as Repository Secrets/Variables in your GitHub repo settings (**Settings > Secrets and variables > Actions**):
   - `OPENAI_API_KEY` (Secret): Your API key.
   - `OPENAI_BASE_URL` (Variable, Optional): Custom base URL (e.g., for DeepSeek, Local LLMs). Defaults to OpenAI.
   - `OPENAI_MODEL_NAME` (Variable, Optional): The model to use. Defaults to `gpt-4o-mini`.
