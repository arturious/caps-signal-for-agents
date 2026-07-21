import Foundation

func printUsage() {
    print("""
    Usage: capsig <command>

      working     Claude сейчас работает — медленное мигание (0.75s)
      done        Claude закончил задачу — 2 коротких + 1 длинное мигание
      attention   Claude требует внимания — 5 быстрых миганий
      stop        Погасить индикатор и остановить текущий цикл
      install-hooks    Прописать вызовы capsig в ~/.claude/settings.json
      uninstall-hooks  Убрать записи capsig из ~/.claude/settings.json
    """)
}

guard CommandLine.arguments.count > 1 else {
    printUsage()
    exit(1)
}

switch CommandLine.arguments[1] {
case "working":
    stopRunningLoop()
    spawnDetachedLoop("_loop-working")

case "done":
    stopRunningLoop()
    runDonePattern()

case "attention":
    stopRunningLoop()
    runAttentionPattern()

case "status":
    if let connect = openHIDConnection() {
        print(getCapsLock(connect) ? "on" : "off")
    } else {
        print("error: could not open HID connection")
        exit(1)
    }

case "stop":
    stopRunningLoop()
    if let connect = openHIDConnection() {
        setCapsLock(connect, false)
    }

case "install-hooks":
    installHooks()

case "uninstall-hooks":
    uninstallHooks()

// Internal: only ever invoked by spawnDetachedLoop, as a detached child.
case "_loop-working":
    runWorkingLoop()

default:
    printUsage()
    exit(1)
}
