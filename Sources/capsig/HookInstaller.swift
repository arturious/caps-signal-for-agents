import Foundation

private let settingsPath = NSHomeDirectory() + "/.claude/settings.json"

private let managedEvents: [(event: String, subcommand: String)] = [
    ("UserPromptSubmit", "working"),
    ("Stop", "done"),
    ("Notification", "attention"),
    ("SessionEnd", "stop"),
]

func installHooks() {
    var root = loadSettings()
    var hooks = (root["hooks"] as? [String: Any]) ?? [:]

    for (event, subcommand) in managedEvents {
        var entries = (hooks[event] as? [[String: Any]]) ?? []
        removeOwnEntries(from: &entries)
        entries.append([
            "matcher": "",
            "hooks": [
                ["type": "command", "command": "\"\(currentExecutablePath())\" \(subcommand)"]
            ]
        ])
        hooks[event] = entries
    }

    root["hooks"] = hooks
    saveSettings(root)

    print("Hooks installed into \(settingsPath):")
    for (event, subcommand) in managedEvents {
        print("  \(event) -> capsig \(subcommand)")
    }
}

func uninstallHooks() {
    var root = loadSettings()
    guard var hooks = root["hooks"] as? [String: Any] else {
        print("No hooks configured.")
        return
    }

    for (event, _) in managedEvents {
        guard var entries = hooks[event] as? [[String: Any]] else { continue }
        removeOwnEntries(from: &entries)
        if entries.isEmpty {
            hooks.removeValue(forKey: event)
        } else {
            hooks[event] = entries
        }
    }

    root["hooks"] = hooks
    saveSettings(root)
    print("capsig hooks removed from \(settingsPath)")
}

/// Strips any hook entries whose command references this binary, so
/// re-running install-hooks (e.g. after moving the binary) doesn't
/// accumulate duplicate entries.
private func removeOwnEntries(from entries: inout [[String: Any]]) {
    let ownPath = currentExecutablePath()
    entries.removeAll { entry in
        guard let inner = entry["hooks"] as? [[String: Any]] else { return false }
        return inner.contains { ($0["command"] as? String)?.contains(ownPath) == true }
    }
}

private func loadSettings() -> [String: Any] {
    guard let data = FileManager.default.contents(atPath: settingsPath),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return [:] }
    return json
}

private func saveSettings(_ dict: [String: Any]) {
    let dir = (settingsPath as NSString).deletingLastPathComponent
    try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

    if FileManager.default.fileExists(atPath: settingsPath) {
        let backupPath = settingsPath + ".bak"
        try? FileManager.default.removeItem(atPath: backupPath)
        try? FileManager.default.copyItem(atPath: settingsPath, toPath: backupPath)
    }

    guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]) else {
        print("error: failed to serialize settings.json")
        exit(1)
    }
    try? data.write(to: URL(fileURLWithPath: settingsPath))
}
