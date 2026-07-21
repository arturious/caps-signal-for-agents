import Darwin
import IOKit

/// "Claude сейчас работает": slow, steady blink, full cycle every 0.75s.
/// Normally killed by the next hook event (SIGTERM from stopRunningLoop),
/// but self-terminates after maxCycles as a safety net in case the "Stop"
/// hook never fires — otherwise the LED (and real Caps Lock state) would
/// stay stuck on indefinitely.
func runWorkingLoop() -> Never {
    guard let connect = openHIDConnection() else { exit(1) }
    installShutdownHandler(connect)
    let maxCycles = 400 // ~5 minutes at 0.75s/cycle
    var cycles = 0
    while cycles < maxCycles {
        setCapsLock(connect, true)
        usleep(375_000)
        setCapsLock(connect, false)
        usleep(375_000)
        cycles += 1
    }
    setCapsLock(connect, false)
    clearPidFile()
    exit(0)
}

/// "Claude закончил задачу": two short blinks + one long blink, then off.
/// One-shot — runs to completion in the foreground.
func runDonePattern() {
    guard let connect = openHIDConnection() else { exit(1) }
    for _ in 0..<2 {
        setCapsLock(connect, true)
        usleep(120_000)
        setCapsLock(connect, false)
        usleep(120_000)
    }
    setCapsLock(connect, true)
    usleep(500_000)
    setCapsLock(connect, false)
}

/// "Claude требует внимания": 5 fast blinks, then off.
/// One-shot — runs to completion in the foreground, like runDonePattern.
func runAttentionPattern() {
    guard let connect = openHIDConnection() else { exit(1) }
    for _ in 0..<5 {
        setCapsLock(connect, true)
        usleep(80_000)
        setCapsLock(connect, false)
        usleep(80_000)
    }
}

/// Ensures a killed loop leaves the LED off instead of stuck mid-blink.
private func installShutdownHandler(_ connect: io_connect_t) {
    shutdownConnect = connect
    signal(SIGTERM) { _ in
        if let connect = shutdownConnect {
            setCapsLock(connect, false)
        }
        exit(0)
    }
}

private var shutdownConnect: io_connect_t?
