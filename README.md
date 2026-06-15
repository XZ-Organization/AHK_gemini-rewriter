# AHK Gemini Rewriter

Windows AutoHotkey v2 macro that sends clean clipboard text to a dedicated Chrome Gemini profile and fills the Gemini prompt.

## Hotkey

- `Ctrl+Alt+\`: fill the Gemini prompt only.
- `Ctrl+Alt+Shift+\`: fill the Gemini prompt and press the send button.

## Workflow

1. Copy text to the clipboard.
2. Press `Ctrl+Alt+\`, or press `Ctrl+Alt+Shift+\` to submit immediately.
3. The script normalizes the clipboard to plain text.
4. Gemini opens in the dedicated automation Chrome profile.
5. The prompt is filled. The send button is pressed only on `Ctrl+Alt+Shift+\`.

## Prompt Template

```text
아래 초안 퇴고해줘.
###초안
{clipboard text}
```

## Files

- `gemini_rewrite_selection.ahk`: AutoHotkey v2 hotkey, clipboard handling, Node helper launch, and browser foreground activation.
- `gemini_fill_prompt.mjs`: Node CDP helper that waits for Gemini composer readiness and fills the prompt.
- `package.json`: local dependency manifest for `playwright-core`.

## Setup

Install dependencies:

```powershell
npm install
```

Run the AHK script:

```powershell
"C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" "C:\Retention_Dev\GEMINI_rewriter\gemini_rewrite_selection.ahk"
```

Optional environment variables:

- `GEMINI_PROMPT_BROWSER_EXE`: Chrome executable path.
- `GEMINI_PROMPT_PROFILE_DIR`: dedicated Chrome user data directory.
- `GEMINI_PROMPT_NODE_EXE`: Node executable path.
- `GEMINI_PROMPT_PLAYWRIGHT_DIR`: Playwright or Playwright Core module path.

Default profile:

```text
%USERPROFILE%\.codex\gemini-relay-browser-profile-2
```
