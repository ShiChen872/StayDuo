import SwiftUI

@main
enum StayDuoMain {
    static func main() {
        if CommandLine.arguments.contains("--smoke-test") {
            SmokeTest.run()
            return
        }

        StayDuoApp.main()
    }
}

struct StayDuoApp: App {
    @State private var store = StayStore()

    var body: some Scene {
        MenuBarExtra {
            StayPanelView(store: store)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    store.release()
                }
        } label: {
            MenuBarLabel(store: store)
                .task {
                    store.start()
                }
        }
        .menuBarExtraStyle(.window)
    }
}

enum SmokeTest {
    static func run() {
        print("StayDuo smoke test")
        print("------------------")
        let keeper = AssertionKeeper()
        do {
            try keeper.apply(mode: .screenOn, enabled: true)
            print("[screenOn] assertion created")
            dumpAssertions()

            try keeper.apply(mode: .screenOffKeepNet, enabled: true)
            print("[screenOffKeepNet] assertion created")
            dumpAssertions()

            keeper.releaseAll()
            print("[release] OK")
        } catch {
            print("FAIL: \(error.localizedDescription)")
            exit(1)
        }
    }

    private static func dumpAssertions() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-g", "assertions"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let text = String(data: data, encoding: .utf8) ?? ""
            let hits = text.split(separator: "\n").filter { $0.contains("StayDuo") }
            if hits.isEmpty {
                print("  pmset: no StayDuo lines (may still be held; check manually)")
            } else {
                for line in hits {
                    print("  \(line.trimmingCharacters(in: .whitespaces))")
                }
            }
        } catch {
            print("  pmset failed: \(error.localizedDescription)")
        }
    }
}
