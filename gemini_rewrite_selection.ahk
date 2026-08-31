#Requires AutoHotkey v2.0
#SingleInstance Force
SendMode "Input"
SetTitleMatchMode 2

if (A_Args.Length >= 1 && A_Args[1] = "--run") {
    SendClipboardToGemini(false)
    ExitApp
}

; Ctrl+Alt+\: fill prompt only.
^!sc02B::SendClipboardToGemini(false)

; Ctrl+Alt+Shift+\: fill prompt and submit.
^!+sc02B::SendClipboardToGemini(true)

; Ctrl+Alt+]: paste prompt-writing exclusion guidance.
^!sc01B::PastePromptExclusionGuidance()

; Ctrl+Alt+[: paste parent-thread prompt guidance.
^!sc01A::PasteParentThreadPromptGuidance()

; Ctrl+Alt+Shift+[: paste finalized side-chat takeaways guidance.
^!+sc01A::PasteFinalizedSideChatGuidance()

; Ctrl+Alt+': paste broad diagnosis and boundary verification guidance.
^!sc028::PasteBoundaryGuidance()

; Ctrl+Alt+Shift+/: paste the production/release implementation review prompt.
^!+sc035::PasteProductionReviewPrompt()

; Ctrl+Alt+/: paste the staged review-and-modify procedure.
^!sc035::PasteReviewModifyProcedure()

PastePromptExclusionGuidance() {
    text := "When writing the prompt, exclude the following:`n- Redundant or duplicate content`n- Unnecessary details`n- Information that is irrelevant to the context or leads to hyper-fixation on minor points`n- Tasks that can be performed autonomously without explicit instructions"
    PasteTextPreservingClipboard(text)
}

PasteParentThreadPromptGuidance() {
    text := "Create a prompt to deliver to the parent thread so that work can proceed using the summary from the side chat.`n`nExclude the following from the prompt:`n- Redundant or duplicate content`n- Unnecessary details`n- Information that is irrelevant to the context or leads to hyper-fixation on minor points`n- Tasks that can be performed autonomously without explicit instructions"
    PasteTextPreservingClipboard(text)
}

PasteFinalizedSideChatGuidance() {
    text := "Please proceed with the main task using the key takeaways finalized in the side chat.`n`nRequirements:`n- Focus exclusively on essential updates, final decisions, and actionable next steps.`n- Exclude duplicate or redundant information.`n- Omit unnecessary background details or context that could lead to over-fixation on minor points.`n- Omit standard tasks or workflows that can be executed autonomously without explicit direction."
    PasteTextPreservingClipboard(text)
}

PasteBoundaryGuidance() {
    text := "Diagnose broadly.`nModify within the owning boundary.`nVerify across affected boundaries."
    PasteTextPreservingClipboard(text)
}

PasteProductionReviewPrompt() {
    text := "현재 코드와 실제 production/release 경로를 기준으로 {{Codebase}} 구현 수준을 독립적으로 검토하세요.`n`n**Diagnose broadly. Modify within the owning boundary. Verify across affected boundaries.**`n`n## 작업`n`n1. 기존 `main` 브랜치와 메인 worktree는 변경하지 말고, 기준 커밋에서 별도 브랜치와 격리된 worktree를 생성하세요.`n2. 모듈 경계, 의존성 방향, composition root, public contract 및 production/release 진입점이 실제로 일관되게 적용되어 있는지 검토하세요.`n3. 운영 중단, 데이터 무결성 훼손, 보안 경계 우회 또는 복구 불가능한 상태를 초래할 수 있는 P0 후보를 식별하고 우선순위를 정하세요.`n4. 실제 P0가 확인되면 최우선 후보 1건만 소유 경계 내에서 수정하고 회귀 테스트를 추가하세요. P0가 없으면 P1을 임의로 승격하지 말고 `P0 없음`으로 판정하세요.`n5. 테스트와 실행은 격리된 자원을 사용하며, 운영 데이터·공유 서비스·worktree 외부 산출물을 변경하지 마세요.`n`n## 완료 보고`n`n- 기준 커밋, 작업 브랜치 및 격리 worktree 경로`n- 구현 수준 판정`n- P0 후보와 최종 선정 근거`n- 근본 원인, 수정 경계 및 변경 커밋`n- 수정 전후 재현·테스트 결과`n- production/release 경로 검증 결과`n- 기존 `main`과 메인 worktree가 변경되지 않았다는 확인`n- 잔여 위험"
    PasteTextPreservingClipboard(text)
}

PasteReviewModifyProcedure() {
    text := "아래 순서로 [검토-수정]을 단계별로 적용해줘.`n`n1. stale 점검`n2. 사고 실험에 따라 각 경로가 정상인지 점검`n3. [$impl-validator](C:\Users\jaekw\.codex\skills\impl-validator\SKILL.md)`n4. [$imply-2-validator](C:\Users\jaekw\.codex\skills\imply-2-validator\SKILL.md)"
    PasteTextPreservingClipboard(text)
}

PasteTextPreservingClipboard(text) {
    clipSaved := ClipboardAll()
    try {
        A_Clipboard := text
        if !ClipWait(1) {
            MsgBox "붙여넣을 문구를 클립보드에 등록하지 못했습니다.", "단축키 모음", "Icon!"
            return
        }

        KeyWait "LControl"
        KeyWait "RControl"
        KeyWait "LAlt"
        KeyWait "RAlt"
        Send "^v"
        Sleep 200
    } finally {
        A_Clipboard := clipSaved
    }
}

SendClipboardToGemini(submitPrompt := false) {
    static running := false

    if running {
        Log("ignored hotkey while running")
        return
    }

    running := true
    try {
        try {
            SendClipboardToGeminiImpl(submitPrompt)
        } catch as err {
            Log("exception: " err.Message)
            MsgBox "Gemini 프롬프트 실행 중 오류가 발생했습니다.`n" err.Message, "Gemini 프롬프트", "Icon!"
        }
    } finally {
        running := false
    }
}

SendClipboardToGeminiImpl(submitPrompt := false) {
    Log("started submit=" (submitPrompt ? "true" : "false"))

    draftText := GetClipboardPlainText()
    if (draftText = "") {
        Log("empty clipboard")
        MsgBox "클립보드에서 텍스트를 가져오지 못했습니다.`n텍스트를 복사한 뒤 다시 실행하세요.", "Gemini 프롬프트", "Icon!"
        return
    }

    ; User-requested behavior: keep clipboard as clean plain text after the run.
    A_Clipboard := draftText
    ClipWait 1

    prompt := "아래 초안 퇴고해줘.`n###초안`n" draftText

    promptFile := A_Temp "\gemini_rewrite_prompt_" A_TickCount ".txt"
    statusFile := A_Temp "\gemini_rewrite_status.json"
    nodeExe := ResolveNodeExe()
    nodeScript := A_ScriptDir "\gemini_fill_prompt.mjs"

    if !FileExist(nodeScript) {
        Log("missing node script: " nodeScript)
        MsgBox "Gemini 입력 스크립트를 찾지 못했습니다.`n" nodeScript, "Gemini 프롬프트", "Icon!"
        return
    }

    DeleteIfExists(promptFile)
    DeleteIfExists(statusFile)
    FileAppend prompt, promptFile, "UTF-8"

    command := Format('"{1}" "{2}" --prompt-file "{3}" --status-file "{4}"{5}', nodeExe, nodeScript, promptFile, statusFile, submitPrompt ? " --submit" : "")
    Log("run node visible: " command)
    try {
        exitCode := RunWait(command, A_ScriptDir, "Hide")
        Log("node exitCode: " exitCode)

        errorCode := ReadStatusErrorCode(statusFile)
        if (exitCode != 0 && !submitPrompt && CanRetryWithVisibleProfile(errorCode)) {
            Log("node failed; open profile and retry; errorCode=" errorCode)
            OpenGeminiBrowserProfile()
            Sleep 2500
            DeleteIfExists(statusFile)
            Log("retry node visible: " command)
            exitCode := RunWait(command, A_ScriptDir, "Hide")
            Log("retry node exitCode: " exitCode)
        } else if (exitCode != 0) {
            Log("node failed; no retry; submit=" (submitPrompt ? "true" : "false") "; errorCode=" errorCode)
        }
    } finally {
        DeleteIfExists(promptFile)
    }

    if (exitCode != 0) {
        Log("node failed")
        if submitPrompt {
            MsgBox "Gemini 프롬프트 전송에 실패했습니다.`n입력창에 프롬프트가 남아 있으면 직접 전송하세요.", "Gemini 프롬프트", "Icon!"
        } else {
            MsgBox "Gemini 프롬프트 입력에 실패했습니다.`n자동화 Chrome 프로필의 Gemini 입력창을 확인하세요.", "Gemini 프롬프트", "Icon!"
        }
        return
    }

    ActivateGeminiBrowser()
    Log("success")
}

GetClipboardPlainText() {
    if (A_Clipboard = "") {
        ClipWait 1
    }

    return Trim(A_Clipboard, "`r`n `t")
}

DeleteIfExists(path) {
    if FileExist(path) {
        FileDelete path
    }
}

ReadStatusErrorCode(statusFile) {
    if !FileExist(statusFile) {
        return ""
    }

    try {
        statusText := FileRead(statusFile, "UTF-8")
        if RegExMatch(statusText, '"errorCode"\s*:\s*"([^"]+)"', &match) {
            return match[1]
        }
    } catch as err {
        Log("status read failed: " err.Message)
    }

    return ""
}

CanRetryWithVisibleProfile(errorCode) {
    return errorCode = "BROWSER_START_FAILED" || errorCode = "GEMINI_COMPOSER_NOT_FOUND"
}

ResolveNodeExe() {
    configured := EnvGet("GEMINI_PROMPT_NODE_EXE")
    if (configured != "") {
        return configured
    }

    defaultNode := "C:\Program Files\nodejs\node.exe"
    if FileExist(defaultNode) {
        return defaultNode
    }

    bundledNode := EnvGet("USERPROFILE") "\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe"
    if FileExist(bundledNode) {
        return bundledNode
    }

    return "node.exe"
}

ResolveChromeExe() {
    configured := EnvGet("GEMINI_PROMPT_BROWSER_EXE")
    if (configured != "") {
        return configured
    }

    defaultChrome := "C:\Program Files\Google\Chrome\Application\chrome.exe"
    if FileExist(defaultChrome) {
        return defaultChrome
    }

    return "chrome.exe"
}

GeminiProfileDir() {
    configured := EnvGet("GEMINI_PROMPT_PROFILE_DIR")
    if (configured != "") {
        return configured
    }

    return EnvGet("USERPROFILE") "\.codex\gemini-relay-browser-profile-2"
}

GeminiDebugPort() {
    portFile := EnvGet("USERPROFILE") "\.codex\gemini-prompt-visible-cdp-port.txt"
    if FileExist(portFile) {
        try {
            savedPort := Trim(FileRead(portFile, "UTF-8"))
            if RegExMatch(savedPort, "^\d+$") {
                return savedPort
            }
        }
    }

    return "56841"
}

OpenGeminiBrowserProfile() {
    chromeExe := ResolveChromeExe()
    profileDir := GeminiProfileDir()
    port := GeminiDebugPort()
    geminiUrl := "https://gemini.google.com/app?hl=ko&pli=1"

    command := Format('"{1}" --remote-debugging-port={2} --user-data-dir="{3}" --profile-directory=Default --disable-features=DiceWebSigninInterception,SigninInterception,ProfilePickerOnStartup --no-first-run --force-renderer-accessibility --new-window "{4}"', chromeExe, port, profileDir, geminiUrl)
    Log("open browser profile: " command)

    try {
        Run command
        Sleep 1500
        ActivateGeminiBrowser()
        return true
    } catch as err {
        Log("open browser profile failed: " err.Message)
        return false
    }
}

ActivateGeminiBrowser() {
    targets := [
        "Google Gemini ahk_exe chrome.exe",
        "Gemini ahk_exe chrome.exe"
    ]

    for target in targets {
        hwnd := WinExist(target)
        if hwnd {
            try {
                WinRestore hwnd
                WinActivate hwnd
                WinWaitActive hwnd, , 3
                Log("activated browser: " target)
                return true
            } catch as err {
                Log("activate failed: " target " / " err.Message)
            }
        }
    }

    Log("activate failed: no chrome window")
    return false
}

Log(message) {
    logFile := A_Temp "\gemini_rewrite_ahk.log"
    if FileExist(logFile) {
        try {
            if FileGetSize(logFile) > 65536 {
                FileDelete logFile
            }
        }
    }
    FileAppend FormatTime(, "yyyy-MM-dd HH:mm:ss") " " message "`n", logFile, "UTF-8"
}
