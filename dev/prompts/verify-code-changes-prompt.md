# Verify Code Changes

I need you to test that the intention of a code change was accomplished successfully, i.e. that the change is:

- correct
- complete
- concise
- conforms to best practices
- as simple as possible
- is not more easily accomplished using tools available that might not have been considered, especially since coding tools do not generally search the web
- is adequately tested (for Ruby Simplecov coverage, use the cov-loupe MCP server)

### Parameters (I Will Give You...)

- Comparison Specification (an argument to `git diff`) - the point of reference from which you can do a git diff to see the changes. Examples:
  - a commit (e.g. HEAD, HEAD~~, HEAD~4, 45076963221647d724b9b52faa3690a6d83ae8d1)
  - a branch name
  - a tag
  - anything else that can be passed to `git diff`
- A description of the intended change. Examples of changes:
  - Implemented feature
  - Fixed bug
  - Test code added
  - Documentation task

If I do not give you the arguments in this prompt, ask me for them:

----

> Sure, I can verify the code changes for you. I will need you to give me:
> - the commit, branch, etc. for me to use as the starting point of the comparison
> - a description of the code change intention to verify
----

### Your Response

Examine the diff thoroughly. In your response, be balanced, fair, organized, and thorough.

Write your response as markdown text and save it to a file whose name is:

- today's date/time in UTC YYYY-MM-DD-hh-mm format +
- your name (e.g. 'codex, claude, gemini, etc.)
- "-code-review-#{change_intention_phrase}.md"



