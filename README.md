# AHK Prompt Hotkeys

Windows AutoHotkey v2 hotkey collection for Gemini prompt drafting and prompt-writing snippets.

## Hotkey

- `Ctrl+Alt+\`: fill the Gemini prompt only.
- `Ctrl+Alt+Shift+\`: fill the Gemini prompt and press the send button.
- `Ctrl+Alt+]`: paste prompt-writing exclusion guidance into the active input field.

## Gemini Workflow

1. Copy text to the clipboard.
2. Press `Ctrl+Alt+\`, or press `Ctrl+Alt+Shift+\` to submit immediately.
3. The script normalizes the clipboard to plain text.
4. Gemini opens in the dedicated automation Chrome profile.
5. The prompt is filled. The send button is pressed only on `Ctrl+Alt+Shift+\`.

## Snippet Workflow

1. Focus any text input field.
2. Press `Ctrl+Alt+]`.
3. The script temporarily registers the snippet to the clipboard, sends `Ctrl+V`, then restores the previous clipboard.

Snippet:

```text
한편, 프롬프트 작성 시 아래 내용은 포함하지마.
- 중복
- 불필요한 내용
- 특정 맥락에 불필요하거나 지나치게 집착하게 만드는 내용
- 별도 지시가 없어도 자율적으로 수행할 내용
```

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
- `scripts/start_hotkeys.ps1`: starts the resident AutoHotkey process from PowerShell.

## Setup

Install dependencies:

```powershell
npm install
```

Run the AHK script:

```powershell
"C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" "C:\Retention_Dev\GEMINI_rewriter\gemini_rewrite_selection.ahk"
```

Or use the helper:

```powershell
pwsh -NoProfile -File scripts\start_hotkeys.ps1
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
