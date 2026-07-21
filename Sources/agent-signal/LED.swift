import CIOHID
import IOKit
import Darwin

// Selector values match <IOKit/hidsystem/IOHIDParameter.h>.
private let kIOHIDParamConnectType: UInt32 = 1
private let kIOHIDCapsLockStateSelector: Int32 = 1

/// Opens a connection to the system's HID event driver. The connection stays
/// open for the lifetime of the process (closing/reopening per toggle is
/// unnecessary overhead for a blink loop).
func openHIDConnection() -> io_connect_t? {
    let matching = IOServiceMatching("IOHIDSystem")
    let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
    guard service != 0 else { return nil }
    defer { IOObjectRelease(service) }

    var connect: io_connect_t = 0
    let kr = IOServiceOpen(service, mach_task_self_, kIOHIDParamConnectType, &connect)
    guard kr == KERN_SUCCESS else { return nil }
    return connect
}

func setCapsLock(_ connect: io_connect_t, _ on: Bool) {
    IOHIDSetModifierLockState(connect, kIOHIDCapsLockStateSelector, on)
}

func getCapsLock(_ connect: io_connect_t) -> Bool {
    var state = false
    IOHIDGetModifierLockState(connect, kIOHIDCapsLockStateSelector, &state)
    return state
}
