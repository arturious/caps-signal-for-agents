import Darwin
import CoreGraphics

/// Seconds since the last keyboard/mouse activity, system-wide.
/// Reads the HID idle timer — no Accessibility permission required.
func secondsSinceLastInput() -> Double {
    CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .null)
}

/// "Claude сейчас работает": slow, steady blink, full cycle every 0.75s.
/// Runs forever until killed (SIGTERM from stopRunningLoop).
func runWorkingLoop() -> Never {
    guard let connect = openHIDConnection() else { exit(1) }
    installShutdownHandler(connect)
    while true {
        setCapsLock(connect, true)
        usleep(375_000)
        setCapsLock(connect, false)
        usleep(375_000)
    }
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

/// "Claude требует внимания": bursts of 5 fast blinks, repeating until the
/// user touches the keyboard or mouse (acknowledging the alert).
func runAttentionLoop() -> Never {
    guard let connect = openHIDConnection() else { exit(1) }
    installShutdownHandler(connect)
    while true {
        let idleBefore = secondsSinceLastInput()
        for _ in 0..<5 {
            setCapsLock(connect, true)
            usleep(80_000)
            setCapsLock(connect, false)
            usleep(80_000)
        }
        usleep(700_000)
        // If idle time didn't grow with the cycle, real input reset it —
        // the user has acknowledged the alert.
        if secondsSinceLastInput() < idleBefore {
            break
        }
    }
    setCapsLock(connect, false)
    clearPidFile()
    exit(0)
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
