import Foundation
import Darwin

/// One capsig loop (working/attention) runs at a time; its pid lives here so
/// a new command can stop the old loop before starting its own pattern.
private var pidFilePath: String {
    NSTemporaryDirectory() + "capsig-\(NSUserName()).pid"
}

func currentExecutablePath() -> String {
    var size: UInt32 = 1024
    var buffer = [Int8](repeating: 0, count: Int(size))
    if _NSGetExecutablePath(&buffer, &size) != 0 {
        buffer = [Int8](repeating: 0, count: Int(size))
        _ = _NSGetExecutablePath(&buffer, &size)
    }
    return String(cString: buffer)
}

/// Stops any previously running working/attention loop, if one is alive.
func stopRunningLoop() {
    guard let content = try? String(contentsOfFile: pidFilePath, encoding: .utf8),
          let pid = Int32(content.trimmingCharacters(in: .whitespacesAndNewlines))
    else { return }
    if kill(pid, 0) == 0 {
        kill(pid, SIGTERM)
        // Give the loop a moment to turn the LED off before we drive it ourselves.
        usleep(50_000)
    }
    try? FileManager.default.removeItem(atPath: pidFilePath)
}

@discardableResult
func spawnDetachedLoop(_ subcommand: String) -> Int32 {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: currentExecutablePath())
    task.arguments = [subcommand]
    task.standardOutput = FileHandle.nullDevice
    task.standardError = FileHandle.nullDevice
    task.standardInput = FileHandle.nullDevice
    try? task.run()
    let pid = task.processIdentifier
    try? "\(pid)".write(toFile: pidFilePath, atomically: true, encoding: .utf8)
    return pid
}

func clearPidFile() {
    try? FileManager.default.removeItem(atPath: pidFilePath)
}
