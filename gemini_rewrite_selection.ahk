#Requires AutoHotkey v2.0
#SingleInstance Force
SendMode "Input"
SetTitleMatchMode 2

if (A_Args.Length >= 1 && A_Args[1] = "--run") {
    SendClipboardToGemini()
    ExitApp
}

; Ctrl+Alt+\: clipboard plain text -> visible Chrome Gemini prompt.
^!vkDC::SendClipboardToGemini()
^!sc02B::SendClipboardToGemini()

SendClipboardToGemini() {
    try {
        SendClipboardToGeminiImpl()
    } catch as err {
        Log("exception: " err.Message)
        MsgBox "Gemini 프롬프트 실행 중 오류가 발생했습니다.`n" err.Message, "Gemini 프롬프트", "Icon!"
    }
}

SendClipboardToGeminiImpl() {
    Log("started")

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

    command := Format('"{1}" "{2}" --prompt-file "{3}" --status-file "{4}"', nodeExe, nodeScript, promptFile, statusFile)
    Log("run node visible: " command)
    try {
        exitCode := RunWait(command, A_ScriptDir, "Hide")
        Log("node exitCode: " exitCode)

        if (exitCode != 0) {
            Log("node failed; open profile and retry")
            OpenGeminiBrowserProfile()
            Sleep 2500
            DeleteIfExists(statusFile)
            Log("retry node visible: " command)
            exitCode := RunWait(command, A_ScriptDir, "Hide")
            Log("retry node exitCode: " exitCode)
        }
    } finally {
        DeleteIfExists(promptFile)
    }

    if (exitCode != 0) {
        Log("node failed")
        MsgBox "Gemini 프롬프트 입력에 실패했습니다.`n자동화가 사용하는 Chrome 프로필을 열고 재시도했지만 입력하지 못했습니다.`nGemini 로그인 상태와 입력창을 확인하세요.", "Gemini 프롬프트", "Icon!"
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
