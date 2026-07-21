import Foundation

struct CapsigConfig: Codable {
    var ledEnabled: Bool = true
    var overlayEnabled: Bool = true
}

private var configPath: String {
    NSHomeDirectory() + "/.config/capsig/config.json"
}

func loadConfig() -> CapsigConfig {
    guard let data = FileManager.default.contents(atPath: configPath),
          let config = try? JSONDecoder().decode(CapsigConfig.self, from: data)
    else { return CapsigConfig() }
    return config
}

private func saveConfig(_ config: CapsigConfig) {
    let dir = (configPath as NSString).deletingLastPathComponent
    try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    guard let data = try? JSONEncoder().encode(config) else { return }
    try? data.write(to: URL(fileURLWithPath: configPath))
}

private enum OnOff: String {
    case on, off
    var boolValue: Bool { self == .on }
}

/// `capsig config` (show current settings) or `capsig config <led|overlay> <on|off>`.
func handleConfigCommand(_ args: [String]) {
    var config = loadConfig()

    guard args.count == 2, let onOff = OnOff(rawValue: args[1]) else {
        print("""
        Текущие настройки (\(configPath)):
          led:     \(config.ledEnabled ? "on" : "off")
          overlay: \(config.overlayEnabled ? "on" : "off")

        Usage: capsig config <led|overlay> <on|off>
        """)
        return
    }

    switch args[0] {
    case "led":
        config.ledEnabled = onOff.boolValue
        if !config.ledEnabled, let connect = openHIDConnection() {
            setCapsLock(connect, false)
        }
    case "overlay":
        config.overlayEnabled = onOff.boolValue
        if !config.overlayEnabled {
            stopOverlay()
        }
    default:
        print("Неизвестная настройка: \(args[0]). Используйте 'led' или 'overlay'.")
        return
    }

    saveConfig(config)
    print("\(args[0]) -> \(onOff.rawValue)")
}
