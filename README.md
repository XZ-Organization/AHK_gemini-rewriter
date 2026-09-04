# AHK Prompt Hotkeys

Windows AutoHotkey v2 hotkey collection for Gemini prompt drafting and prompt-writing snippets.

## Hotkey

- `Ctrl+Alt+\`: fill the Gemini prompt only.
- `Ctrl+Alt+Shift+\`: fill the Gemini prompt and press the send button.
- `Ctrl+Alt+[`: paste parent-thread prompt guidance into the active input field.
- `Ctrl+Alt+Shift+[`: paste finalized side-chat takeaways guidance into the active input field.
- `Ctrl+Alt+]`: paste prompt-writing exclusion guidance into the active input field.
- `Ctrl+Alt+'`: paste broad diagnosis and boundary verification guidance into the active input field.
- `Ctrl+Alt+Shift+/`: paste the production/release implementation review prompt into the active input field.
- `Ctrl+Alt+/`: paste the staged review-and-modify procedure into the active input field.

## Gemini Workflow

1. Copy text to the clipboard.
2. Press `Ctrl+Alt+\`, or press `Ctrl+Alt+Shift+\` to submit immediately.
3. The script normalizes the clipboard to plain text.
4. Gemini opens in the dedicated automation Chrome profile.
5. The prompt is filled. The send button is pressed only on `Ctrl+Alt+Shift+\`.

## Snippet Workflow

1. Focus any text input field.
2. Press `Ctrl+Alt+[`, `Ctrl+Alt+Shift+[`, `Ctrl+Alt+]`, `Ctrl+Alt+'`, `Ctrl+Alt+Shift+/`, or `Ctrl+Alt+/`.
3. The script temporarily registers the snippet to the clipboard, sends `Ctrl+V`, then restores the previous clipboard.

`Ctrl+Alt+[` snippet:

```text
Create a prompt to deliver to the parent thread so that work can proceed using the summary from the side chat.

Exclude the following from the prompt:
- Redundant or duplicate content
- Unnecessary details
- Information that is irrelevant to the context or leads to hyper-fixation on minor points
- Tasks that can be performed autonomously without explicit instructions
```

`Ctrl+Alt+]` snippet:

```text
When writing the prompt, exclude the following:
- Redundant or duplicate content
- Unnecessary details
- Information that is irrelevant to the context or leads to hyper-fixation on minor points
- Tasks that can be performed autonomously without explicit instructions
```

`Ctrl+Alt+Shift+[` snippet:

```text
Please proceed with the main task using the key takeaways finalized in the side chat.

Requirements:
- Focus exclusively on essential updates, final decisions, and actionable next steps.
- Exclude duplicate or redundant information.
- Omit unnecessary background details or context that could lead to over-fixation on minor points.
- Omit standard tasks or workflows that can be executed autonomously without explicit direction.
```

`Ctrl+Alt+'` snippet:

```text
Diagnose broadly. Modify within the owning boundary. Verify across affected boundaries.
```

`Ctrl+Alt+Shift+/` snippet:

```text
현재 코드와 실제 production/release 경로를 기준으로 {{Codebase}} 구현 수준을 독립적으로 검토하세요.

**Diagnose broadly. Modify within the owning boundary. Verify across affected boundaries.**

## 작업

1. 기존 `main` 브랜치와 메인 worktree는 변경하지 말고, 기준 커밋에서 별도 브랜치와 격리된 worktree를 생성하세요.
2. 모듈 경계, 의존성 방향, composition root, public contract 및 production/release 진입점이 실제로 일관되게 적용되어 있는지 검토하세요.
3. 운영 중단, 데이터 무결성 훼손, 보안 경계 우회 또는 복구 불가능한 상태를 초래할 수 있는 P0 후보를 식별하고 우선순위를 정하세요.
4. 실제 P0가 확인되면 최우선 후보 1건만 소유 경계 내에서 수정하고 회귀 테스트를 추가하세요. P0가 없으면 P1을 임의로 승격하지 말고 `P0 없음`으로 판정하세요.
5. 테스트와 실행은 격리된 자원을 사용하며, 운영 데이터·공유 서비스·worktree 외부 산출물을 변경하지 마세요.

## 완료 보고

- 기준 커밋, 작업 브랜치 및 격리 worktree 경로
- 구현 수준 판정
- P0 후보와 최종 선정 근거
- 근본 원인, 수정 경계 및 변경 커밋
- 수정 전후 재현·테스트 결과
- production/release 경로 검증 결과
- 기존 `main`과 메인 worktree가 변경되지 않았다는 확인
- 잔여 위험
```

`Ctrl+Alt+/` snippet:

```text
아래 순서로 진행해줘.

1. [$stale-code-auditor](C:\Users\jaekw\.codex\skills\stale-code-auditor\SKILL.md) 점검 및 안전한 stale 정리
2. 사고 실험에 따라 각 경로가 정상인지 점검 후 수정
3. [$impl-validator](C:\Users\jaekw\.codex\skills\impl-validator\SKILL.md) fail 요소 수정
4. [$imply-2-validator](C:\Users\jaekw\.codex\skills\imply-2-validator\SKILL.md)fail 요소 수정
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
