import { createRequire } from "node:module";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);

const GEMINI_URL = "https://gemini.google.com/app?hl=ko&pli=1";
const RUNTIME_PORT_FILE = join(homedir(), ".codex", "gemini-prompt-visible-cdp-port.txt");
const PROMPT_SELECTORS = [
  ".ql-editor.textarea.new-input-ui",
  '.ql-editor[contenteditable="true"]',
  '[aria-label*="Gemini 프롬프트 입력"]',
  '[aria-label*="Enter a prompt for Gemini"]',
  "textarea",
  '[contenteditable="true"][role="textbox"]',
  '[contenteditable="true"]',
  '[role="textbox"]',
];

function argValue(name) {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : "";
}

function hasArg(name) {
  return process.argv.includes(name);
}

function loadPlaywright() {
  const scriptDir = dirname(fileURLToPath(import.meta.url));
  const candidates = [
    process.env.GEMINI_PROMPT_PLAYWRIGHT_DIR,
    join(scriptDir, "node_modules", "playwright-core"),
    join(scriptDir, "node_modules", "playwright"),
    join(homedir(), ".cache", "codex-runtimes", "codex-primary-runtime", "dependencies", "node", "node_modules", "playwright"),
    join(homedir(), ".codex", "skills", "codex-app-gemini-relay", "scripts", "node_modules", "playwright"),
    "playwright-core",
    "playwright",
  ].filter(Boolean);

  for (const candidate of candidates) {
    try {
      return require(candidate);
    } catch {
      // Try the next configured location.
    }
  }

  throw new Error("Playwright dependency not found");
}

function writeStatus(path, status) {
  if (!path) {
    return;
  }
  writeFileSync(path, `${JSON.stringify(status, null, 2)}\n`, "utf8");
}

async function endpointReady(port) {
  try {
    const response = await fetch(`http://127.0.0.1:${port}/json/version`, { signal: AbortSignal.timeout(500) });
    return response.ok;
  } catch {
    return false;
  }
}

async function pickPort() {
  for (let port = 56841; port <= 56850; port += 1) {
    if (!(await endpointReady(port))) {
      return port;
    }
  }
  throw new Error("No free Gemini CDP port in 56841-56850");
}

async function findExistingEndpoint() {
  const ports = [9222, ...Array.from({ length: 20 }, (_, index) => 56831 + index)];
  const profileDir = preferredChromeProfileDir();
  for (const port of ports) {
    if (await endpointReady(port) && await endpointMatchesProfile(port, profileDir)) {
      return `http://127.0.0.1:${port}`;
    }
  }
  return "";
}

async function findExistingVisiblePromptEndpoint(profileDir) {
  if (existsSync(RUNTIME_PORT_FILE)) {
    const savedPort = Number(readFileSync(RUNTIME_PORT_FILE, "utf8").trim());
    if (
      Number.isInteger(savedPort)
      && savedPort >= 56841
      && savedPort <= 56850
      && await endpointReady(savedPort)
      && await endpointMatchesProfile(savedPort, profileDir, { allowUnknownCommandLine: true })
    ) {
      return `http://127.0.0.1:${savedPort}`;
    }
  }

  for (let port = 56841; port <= 56850; port += 1) {
    if (!(await endpointReady(port))) {
      continue;
    }

    try {
      if (await endpointMatchesProfile(port, profileDir, { allowUnknownCommandLine: true })) {
        return `http://127.0.0.1:${port}`;
      }
    } catch {
      // Keep probing.
    }
  }
  return "";
}

async function endpointMatchesProfile(port, profileDir, options = {}) {
  try {
    const response = await fetch(`http://127.0.0.1:${port}/json/version`, { signal: AbortSignal.timeout(1000) });
    const info = await response.json();
    const commandLine = String(info["Command Line"] || "");
    const userDataDir = extractUserDataDir(commandLine);
    if (!userDataDir) {
      return Boolean(options.allowUnknownCommandLine);
    }
    return normalizePathForCompare(userDataDir) === normalizePathForCompare(profileDir);
  } catch {
    return false;
  }
}

function extractUserDataDir(commandLine) {
  const match = String(commandLine).match(/--user-data-dir=(?:"([^"]+)"|([^\s"]+))/i);
  return match ? match[1] || match[2] || "" : "";
}

function normalizePathForCompare(value) {
  return String(value)
    .replaceAll("\\", "/")
    .replaceAll('"', "")
    .replace(/\/+$/u, "")
    .toLowerCase();
}

async function waitForEndpoint(port, timeoutMs) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (await endpointReady(port)) {
      return `http://127.0.0.1:${port}`;
    }
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  throw new Error(`CDP endpoint did not start on port ${port}`);
}

function preferredChromeProfileDir() {
  return process.env.GEMINI_PROMPT_PROFILE_DIR
    || join(homedir(), ".codex", "gemini-relay-browser-profile-2");
}

function browserCandidates() {
  const configured = process.env.GEMINI_PROMPT_BROWSER_EXE;
  const visibleChromeProfile = preferredChromeProfileDir();

  return [
    configured ? { exe: configured, profileDir: visibleChromeProfile } : null,
    { exe: "C:/Program Files/Google/Chrome/Application/chrome.exe", profileDir: visibleChromeProfile },
  ].filter((candidate) => candidate && existsSync(candidate.exe));
}

async function startBrowser(port) {
  const candidates = browserCandidates();
  if (candidates.length === 0) {
    throw new Error("Chrome/Edge executable not found");
  }

  const errors = [];
  for (const candidate of candidates) {
    try {
      startBrowserProcess(candidate.exe, candidate.profileDir, port);
      const endpoint = await waitForEndpoint(port, 10000);
      writeFileSync(RUNTIME_PORT_FILE, String(port), "utf8");
      return { ...candidate, browserFamily: "chrome", endpoint };
    } catch (error) {
      errors.push(`${candidate.exe}: ${error.message}`);
    }
  }

  throw new Error(`Could not start a CDP browser. ${errors.join(" | ")}`);
}

function startBrowserProcess(exe, profileDir, port) {
  const args = [
    `--remote-debugging-port=${port}`,
    `--user-data-dir=${profileDir}`,
    "--profile-directory=Default",
    "--disable-features=DiceWebSigninInterception,SigninInterception,ProfilePickerOnStartup",
    "--no-first-run",
    "--force-renderer-accessibility",
    "--new-window",
    GEMINI_URL,
  ];

  const child = spawn(exe, args, {
    detached: true,
    stdio: "ignore",
    windowsHide: false,
  });
  child.unref();
}

async function setPromptInPage(page, promptText, timeoutMs) {
  const deadline = Date.now() + timeoutMs;
  let lastResult = null;

  while (Date.now() < deadline) {
    lastResult = await page.evaluate(({ selectors, text }) => {
      const visibleCandidates = selectors
        .flatMap((selector) => Array.from(document.querySelectorAll(selector)).map((element) => ({ selector, element })))
        .filter(({ element }) => {
          const rect = element.getBoundingClientRect();
          const style = window.getComputedStyle(element);
          return rect.width > 0
            && rect.height > 0
            && style.visibility !== "hidden"
            && style.display !== "none"
            && !element.closest("[aria-hidden='true']");
        })
        .sort((a, b) => b.element.getBoundingClientRect().bottom - a.element.getBoundingClientRect().bottom);

      for (const { selector, element } of visibleCandidates) {
        element.focus();

        if (element instanceof HTMLTextAreaElement || element instanceof HTMLInputElement) {
          const descriptor = Object.getOwnPropertyDescriptor(Object.getPrototypeOf(element), "value");
          if (descriptor?.set) {
            descriptor.set.call(element, text);
          } else {
            element.value = text;
          }
          element.dispatchEvent(new Event("input", { bubbles: true }));
          element.dispatchEvent(new Event("change", { bubbles: true }));

          const actual = element.value || "";
          if (actual.includes("###초안")) {
            window.__geminiRewritePromptText = text;
            return {
              ok: true,
              selector,
              tag: element.tagName,
              placeholder: element.getAttribute("placeholder") || "",
              actual,
            };
          }
        }

        if (element.isContentEditable) {
          element.textContent = text;
          element.dispatchEvent(new InputEvent("input", {
            bubbles: true,
            inputType: "insertText",
            data: text,
          }));

          const actual = element.innerText || element.textContent || "";
          if (actual.includes("###초안")) {
            window.__geminiRewritePromptText = text;
            return {
              ok: true,
              selector,
              tag: element.tagName,
              placeholder: element.getAttribute("placeholder") || "",
              actual,
            };
          }
        }
      }

      return {
        ok: false,
        candidateCount: visibleCandidates.length,
        firstCandidate: visibleCandidates[0]
          ? {
            selector: visibleCandidates[0].selector,
            tag: visibleCandidates[0].element.tagName,
            placeholder: visibleCandidates[0].element.getAttribute("placeholder") || "",
            text: visibleCandidates[0].element.value || visibleCandidates[0].element.innerText || visibleCandidates[0].element.textContent || "",
          }
          : null,
      };
    }, { selectors: PROMPT_SELECTORS, text: promptText });

    if (lastResult.ok) {
      return lastResult;
    }
    await page.waitForTimeout(500);
  }

  throw new Error(`Prompt fill verification failed; diagnostics=${JSON.stringify(lastResult)}`);
}

async function clickSendButton(page, promptText, timeoutMs) {
  const deadline = Date.now() + timeoutMs;
  let lastResult = null;

  while (Date.now() < deadline) {
    lastResult = await page.evaluate((text) => {
      const composerCandidates = Array.from(document.querySelectorAll("textarea,[contenteditable='true'],[role='textbox']"))
        .filter((element) => (element.value || element.innerText || element.textContent || "").includes(text));
      const composer = composerCandidates
        .sort((a, b) => b.getBoundingClientRect().bottom - a.getBoundingClientRect().bottom)[0];

      if (!composer) {
        return { ok: false, reason: "composer_not_found" };
      }

      const composerRect = composer.getBoundingClientRect();
      const buttons = Array.from(document.querySelectorAll("button"))
        .filter((button) => {
          const rect = button.getBoundingClientRect();
          const style = window.getComputedStyle(button);
          const label = [
            button.getAttribute("aria-label") || "",
            button.getAttribute("data-test-id") || "",
            button.title || "",
            button.innerText || "",
            button.textContent || "",
          ].join(" ");

          return rect.width > 0
            && rect.height > 0
            && style.visibility !== "hidden"
            && style.display !== "none"
            && !button.disabled
            && rect.bottom >= composerRect.top - 80
            && rect.top <= composerRect.bottom + 180
            && /send|submit|전송|보내기|메시지 보내기/i.test(label);
        })
        .sort((a, b) => {
          const aRect = a.getBoundingClientRect();
          const bRect = b.getBoundingClientRect();
          return Math.abs(aRect.top - composerRect.top) - Math.abs(bRect.top - composerRect.top);
        });

      const button = buttons[0];
      if (!button) {
        return { ok: false, reason: "send_button_not_found" };
      }

      const label = button.getAttribute("aria-label") || button.title || button.innerText || button.textContent || "";
      button.click();
      return { ok: true, label };
    }, promptText);

    if (lastResult.ok) {
      await page.waitForTimeout(700);
      const stillHasPrompt = await page.evaluate((text) => {
        return Array.from(document.querySelectorAll("textarea,[contenteditable='true'],[role='textbox']"))
          .some((element) => (element.value || element.innerText || element.textContent || "").includes(text));
      }, promptText).catch(() => false);

      if (!stillHasPrompt) {
        return lastResult;
      }
    }

    await page.waitForTimeout(300);
  }

  throw new Error(`Gemini send button click failed; diagnostics=${JSON.stringify(lastResult)}`);
}

async function waitForGeminiComposerReady(page, timeoutMs) {
  const deadline = Date.now() + timeoutMs;
  let lastResult = null;

  while (Date.now() < deadline) {
    lastResult = await page.evaluate((selectors) => {
      const candidates = selectors
        .flatMap((selector) => Array.from(document.querySelectorAll(selector)).map((element) => ({ selector, element })))
        .filter(({ element }) => {
          const rect = element.getBoundingClientRect();
          const style = window.getComputedStyle(element);
          return rect.width > 0
            && rect.height > 0
            && style.visibility !== "hidden"
            && style.display !== "none"
            && !element.disabled
            && !element.closest("[aria-hidden='true']");
        });

      const first = candidates[0];
      return {
        ready: candidates.length > 0,
        candidateCount: candidates.length,
        firstCandidate: first
          ? {
            selector: first.selector,
            tag: first.element.tagName,
            placeholder: first.element.getAttribute("placeholder") || "",
            ariaLabel: first.element.getAttribute("aria-label") || "",
          }
          : null,
        title: document.title,
        bodyText: document.body?.innerText?.slice(0, 300) || "",
      };
    }, PROMPT_SELECTORS).catch((error) => ({ ready: false, error: error.message }));

    if (lastResult.ready) {
      return lastResult;
    }

    await page.waitForTimeout(500);
  }

  throw new Error(`Gemini composer not ready; diagnostics=${JSON.stringify(lastResult)}`);
}

async function getOrCreateGeminiPage(context) {
  const pages = context.pages();
  const existingGeminiPage = [...pages]
    .reverse()
    .find((candidate) => candidate.url().startsWith("https://gemini.google.com/"));

  if (existingGeminiPage) {
    await existingGeminiPage.bringToFront();
    await existingGeminiPage.goto(GEMINI_URL, { waitUntil: "domcontentloaded", timeout: 60000 });
    return { page: existingGeminiPage, reused: true };
  }

  const page = await context.newPage();
  await page.goto(GEMINI_URL, { waitUntil: "domcontentloaded", timeout: 60000 });
  await page.bringToFront();
  return { page, reused: false };
}

async function main() {
  const promptFile = argValue("--prompt-file");
  const statusFile = argValue("--status-file");
  if (!promptFile) {
    throw new Error("--prompt-file is required");
  }

  const promptText = readFileSync(promptFile, "utf8").replace(/^\uFEFF/u, "");
  if (!promptText.trim()) {
    throw new Error("Prompt file is empty");
  }
  const submitPrompt = hasArg("--submit");

  const { chromium } = loadPlaywright();
  const visibleProfileDir = preferredChromeProfileDir();
  const existingEndpoint = process.env.GEMINI_PROMPT_REUSE_EXISTING_CDP === "1"
    ? await findExistingEndpoint()
    : await findExistingVisiblePromptEndpoint(visibleProfileDir);
  const browserInfo = existingEndpoint
    ? { exe: "existing-visible-cdp-browser", profileDir: visibleProfileDir, browserFamily: "chrome", endpoint: existingEndpoint }
    : await startBrowser(await pickPort());
  const endpoint = browserInfo.endpoint;
  const browser = await chromium.connectOverCDP(endpoint, { timeout: 30000 });

  try {
    const context = browser.contexts()[0] || await browser.newContext();
    const { page, reused } = await getOrCreateGeminiPage(context);
    await waitForGeminiComposerReady(page, 45000);

    const fillResult = await setPromptInPage(page, promptText, 30000);
    const sendResult = submitPrompt
      ? await clickSendButton(page, promptText, 10000)
      : null;

    writeStatus(statusFile, {
      ok: true,
      browser: browserInfo.exe,
      profile: browserInfo.profileDir,
      browserFamily: browserInfo.browserFamily,
      endpoint,
      url: page.url(),
      selector: fillResult.selector,
      placeholder: fillResult.placeholder,
      filled: true,
      submitted: submitPrompt,
      send: sendResult,
      reusedTab: reused,
    });
  } finally {
    // Disconnect from CDP while leaving the visible browser window open for the user.
    if (typeof browser._connection?.close === "function") {
      browser._connection.close();
    }
  }
}

main().then(() => {
  process.exit(0);
}).catch((error) => {
  const payload = classifyError(error);
  writeStatus(argValue("--status-file"), {
    ok: false,
    ...payload,
  });
  process.exit(1);
});

function classifyError(error) {
  const message = String(error?.message || error || "");
  if (/Chrome\/Edge executable not found|Could not start a CDP browser/i.test(message)) {
    return {
      errorCode: "BROWSER_START_FAILED",
    };
  }
  if (/Playwright dependency not found/i.test(message)) {
    return {
      errorCode: "PLAYWRIGHT_NOT_FOUND",
    };
  }
  if (/Prompt fill verification failed|Gemini composer not ready/i.test(message)) {
    return {
      errorCode: "GEMINI_COMPOSER_NOT_FOUND",
    };
  }
  if (/Gemini send button click failed/i.test(message)) {
    return {
      errorCode: "GEMINI_SEND_FAILED",
    };
  }
  return {
    errorCode: "GEMINI_AUTOMATION_FAILED",
  };
}
