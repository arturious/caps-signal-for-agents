import Foundation

func printUsage() {
    print("""
    Usage: capsig <command>

      working     Claude сейчас работает — медленное мигание (0.75s)
      done        Claude закончил задачу — 2 коротких + 1 длинное мигание
      attention   Claude требует внимания — 5 быстрых миганий
      stop        Погасить индикатор и остановить текущий цикл
      overlay       Запустить floating-индикатор поверх fullscreen (блокирует)
      overlay-stop  Остановить floating-индикатор
      config          Показать настройки (led/overlay on|off)
      config <led|overlay> <on|off>   Включить/выключить один из каналов
      install-hooks    Прописать вызовы capsig в ~/.claude/settings.json
      uninstall-hooks  Убрать записи capsig из ~/.claude/settings.json
    """)
}

guard CommandLine.arguments.count > 1 else {
    printUsage()
    exit(1)
}

let config = loadConfig()

switch CommandLine.arguments[1] {
case "working":
    stopRunningLoop()
    if config.overlayEnabled {
        ensureOverlayRunning()
        postOverlayState(.working)
    }
    if config.ledEnabled {
        spawnDetachedLoop("_loop-working")
    }

case "done":
    stopRunningLoop()
    if config.overlayEnabled {
        postOverlayState(.done)
    }
    if config.ledEnabled {
        runDonePattern()
    }

case "attention":
    stopRunningLoop()
    if config.overlayEnabled {
        ensureOverlayRunning()
        postOverlayState(.attention)
    }
    if config.ledEnabled {
        runAttentionPattern()
    }

case "status":
    if let connect = openHIDConnection() {
        print(getCapsLock(connect) ? "on" : "off")
    } else {
        print("error: could not open HID connection")
        exit(1)
    }

case "stop":
    stopRunningLoop()
    if config.overlayEnabled {
        postOverlayState(.idle)
    }
    if config.ledEnabled, let connect = openHIDConnection() {
        setCapsLock(connect, false)
    }

case "config":
    handleConfigCommand(Array(CommandLine.arguments.dropFirst(2)))

case "overlay":
    runOverlayApp()

case "overlay-stop":
    stopOverlay()

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
