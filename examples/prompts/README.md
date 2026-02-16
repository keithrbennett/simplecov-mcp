## Example Prompts for MCP-Aware Assistants

[Back to main README](../../docs/index.md)

This directory contains example natural-language prompts that you can use with an MCP-enabled AI assistant to interact with the `cov-loupe` server and analyze your project's test coverage.

These prompts demonstrate how to request different types of coverage information. You can adapt them to your specific project and needs.

### Getting Started

1.  **Copy a prompt:** Choose a prompt from one of the `.md` files in this directory.
2.  **Paste it into your assistant:** Paste the prompt into your chat with an MCP-enabled AI assistant.
3.  **Adjust file paths:** If necessary, change the file paths in the prompt to match your project's structure.

### Example Prompts

*   **`summary.md`**: A basic prompt to get a high-level summary of your project's test coverage.
*   **`detailed_with_source.md`**: A more advanced prompt that requests a detailed breakdown of coverage, including the source code of the files.
*   **`list_lowest.md`**: A prompt to find the files with the lowest test coverage.
*   **`uncovered.md`**: A prompt to get a list of all the lines that are not covered by tests.
*   **`custom_resultset.md`**: An example of how to specify a custom SimpleCov resultset file for analysis.

### Tips for Writing Your Own Prompts

*   **Be specific:** The more specific you are in your request, the better the assistant will be able to understand you.
*   **Request JSON for machine-readable output:** If you want to process the output programmatically, ask for the results in JSON format.
*   **Specify the root directory:** If your project is not in the current working directory, you can specify the root directory in your prompt.
