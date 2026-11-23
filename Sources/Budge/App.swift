import AppKit
import BudgeCore
import ServiceManagement
import SwiftUI

@main
@MainActor
enum BudgeApp {
    static func main() {
        let args = CommandLine.arguments
        let dark = args.contains("--dark")
        if let i = args.firstIndex(of: "--render"), i + 1 < args.count {
            let avatar = args.firstIndex(of: "--avatar").flatMap { Avatar(rawValue: args[$0 + 1]) } ?? .waddle
            let path = args[i + 1]
            switch args.firstIndex(of: "--screen").map({ args[$0 + 1] }) {
            case "log":
                render(LogPromptView(avatar: avatar, previewText: "Fixed the onboarding status bug, reviewed 2 PRs"),
                       to: path, dark: dark)
            case "week":
                render(WeekView(avatar: avatar, days: WorkLog(markdown: sampleWeek).days, slideIn: false),
                       to: path, dark: dark)
            default:
                let prompt = args.firstIndex(of: "--prompt").flatMap { Int(args[$0 + 1]) }.map { Prompts.all[$0] }
                render(NudgeView(avatar: avatar, prompt: prompt ?? Prompts.all[14], caption: "32 min at the keyboard",
                                 slideIn: false),
                       to: path, dark: dark)
            }
            return
        }
        if let i = args.firstIndex(of: "--lineup"), i + 1 < args.count {
            render(Lineup(), to: args[i + 1], dark: dark)
            return
        }
        if let i = args.firstIndex(of: "--icon"), i + 1 < args.count {
            writePNG(AppIconView(), to: args[i + 1], scale: 1) // transparent corners
            return
        }
        if let i = args.firstIndex(of: "--open-at-login") {
            setOpenAtLogin(i + 1 < args.count ? args[i + 1] : "")
            return
        }
        if args.contains("--status") {
            print("idle seconds:   \(Int(Signals.idleSeconds()))")
            print("apps using mic: \(Signals.appsUsingMic())")
            print("camera in use:  \(Signals.cameraInUse())")
            return
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory) // menu bar only, no Dock icon
        app.run()
    }

    /// Made-up week for the `--render --screen week` preview.
    static let sampleWeek = """
        ## 2026-11-16 Monday
        - Fixed the onboarding status bug
        - Reviewed 2 PRs
        ## 2026-11-17 Tuesday
        - Shipped ticket search in the support tool
        ## 2026-11-18 Wednesday
        - Planning for next cycle, 3 support calls
        ## 2026-11-19 Thursday
        - Built Budge
        ## 2026-11-20 Friday
        - Wrote release notes, cleaned up old branches
        """

    /// `--open-at-login on|off` does the same as the menu toggle; any other value just prints the state.
    /// Run it from the installed app: /Applications/Budge.app/Contents/MacOS/Budge --open-at-login on
    static func setOpenAtLogin(_ value: String) {
        let service = SMAppService.mainApp
        do {
            if value == "on" { try service.register() }
            if value == "off" { try service.unregister() }
        } catch {
            print("Could not change Open at login: \(error.localizedDescription)")
            exit(1)
        }
        switch service.status {
        case .enabled: print("Open at login: on")
        case .requiresApproval: print("Open at login: waiting for approval in System Settings > General > Login Items")
        case .notRegistered: print("Open at login: off")
        default: print("Open at login: unknown (\(service.status.rawValue))")
        }
    }

    /// Writes a PNG of a view so the look can be checked without waiting 30 minutes.
    static func render(_ content: some View, to path: String, dark: Bool) {
        let view = content
            .background(dark ? Color(white: 0.10) : Color(white: 0.90))
            .environment(\.colorScheme, dark ? .dark : .light)
        writePNG(view, to: path, scale: 2)
    }

    static func writePNG(_ view: some View, to path: String, scale: CGFloat) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        guard let image = renderer.cgImage,
              let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]),
              (try? png.write(to: URL(fileURLWithPath: path))) != nil else {
            print("Could not render preview")
            exit(1)
        }
        print("Wrote \(path)")
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let defaults = UserDefaults.standard
    private let tickEvery: TimeInterval = 15
    private let snoozeFor: TimeInterval = 10 * 60

    private lazy var clock = BreakClock(interval: TimeInterval(intervalMinutes * 60),
                                        pausedUntil: defaults.object(forKey: "pausedUntil") as? Date)
    private var prompts = Prompts()
    private let nudge = NudgePanel()
    /// Drawn once, the first time the menu opens.
    private lazy var menuImages: [Avatar: NSImage] = Dictionary(
        uniqueKeysWithValues: Avatar.allCases.compactMap { avatar in avatar.menuImage().map { (avatar, $0) } })
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private var lastTick = Date()
    /// Why nudges are on hold right now ("You're on a call"), or nil.
    private var busyReason: String?

    /// Done vs snoozed today, kept across restarts.
    private var tally: DayTally {
        get { defaults.data(forKey: "tally").flatMap { try? JSONDecoder().decode(DayTally.self, from: $0) } ?? DayTally() }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: "tally") }
    }

    private var avatar: Avatar {
        get { Avatar(rawValue: defaults.string(forKey: "avatar") ?? "") ?? .waddle }
        set { defaults.set(newValue.rawValue, forKey: "avatar") }
    }

    private var intervalMinutes: Int {
        get { defaults.integer(forKey: "intervalMinutes").nonZero ?? 30 }
        set {
            defaults.set(newValue, forKey: "intervalMinutes")
            clock.interval = TimeInterval(newValue * 60)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        updateIcon()

        timer = Timer.scheduledTimer(withTimeInterval: tickEvery, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer?.tolerance = 3

        if CommandLine.arguments.contains("--demo") { nudgeNow() }
        if CommandLine.arguments.contains("--demo-log") { askForLog() }
    }

    private func tick() {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastTick)
        lastTick = now
        let idle = Signals.idleSeconds()
        refreshBusy()

        let decision = clock.tick(elapsed: elapsed, idle: idle, busy: busyReason != nil, now: now)
        if idle >= clock.breakResetsAfter, nudge.isShowing {
            nudge.hide() // you walked away: that was the break (an unanswered log question comes back later)
        }
        if !nudge.isShowing, idle < clock.stillWorkingIdle, busyReason == nil, !clock.isPaused(now: now),
           EndOfDay.isDue(now: now, lastAsked: defaults.string(forKey: "logAskedDay")) {
            askForLog()
        }
        if decision == .nudge, !nudge.isShowing {
            showNudge(caption: "\(Int(clock.activeTime / 60)) min at the keyboard")
        }
        updateIcon()
    }

    private func refreshBusy() {
        busyReason = Signals.inCall() ? "You're on a call" : nil
    }

    /// `counted: false` for the hello when you pick an avatar, so it doesn't skew today's tally.
    private func showNudge(caption: String, counted: Bool = true) {
        nudge.show(
            avatar: avatar, prompt: prompts.next(), caption: caption,
            onDone: { [weak self] in
                guard let self else { return }
                clock.tookBreak()
                if counted { tally.record(done: true, at: Date()) }
            },
            onSnooze: { [weak self] in
                guard let self else { return }
                clock.snooze(for: snoozeFor, now: Date())
                if counted { tally.record(done: false, at: Date()) }
            })
    }

    private func updateIcon() {
        let paused = clock.isPaused(now: Date())
        let image = NSImage(systemSymbolName: paused ? "pause.circle" : "figure.walk",
                            accessibilityDescription: "Budge")
        image?.isTemplate = true
        statusItem.button?.image = image
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let now = Date()
        let paused = clock.isPaused(now: now)

        refreshBusy() // live, so you can check it during a call
        let status: String
        if paused, let until = clock.pausedUntil {
            status = "Paused until \(Self.describe(until))"
        } else if let busyReason {
            status = "\(busyReason), nudges wait"
        } else {
            status = "Next nudge in ~\(clock.minutesLeft(now: now)) min"
        }
        menu.addItem(NSMenuItem(title: status, action: nil, keyEquivalent: ""))
        let today = tally.counts(on: now)
        if today.done + today.snoozed > 0 {
            menu.addItem(NSMenuItem(title: "Today: \(today.done) done · \(today.snoozed) snoozed",
                                    action: nil, keyEquivalent: ""))
        }
        menu.addItem(.separator())

        menu.addItem(item("Nudge me now", #selector(nudgeNow)))
        menu.addItem(item("Write today's log…", #selector(askForLog)))
        menu.addItem(item("This week's log…", #selector(showWeek)))
        if paused {
            menu.addItem(item("Resume", #selector(resume)))
        } else {
            menu.addItem(item("Pause for 1 hour", #selector(pauseHour)))
            menu.addItem(item("Pause until tomorrow", #selector(pauseTomorrow)))
        }
        menu.addItem(.separator())

        let every = NSMenuItem(title: "Nudge every", action: nil, keyEquivalent: "")
        let choices = NSMenu()
        for minutes in [20, 30, 45, 60] {
            let choice = item("\(minutes) min", #selector(setInterval(_:)))
            choice.tag = minutes
            choice.state = minutes == intervalMinutes ? .on : .off
            choices.addItem(choice)
        }
        every.submenu = choices
        menu.addItem(every)

        let pick = NSMenuItem(title: "Avatar", action: nil, keyEquivalent: "")
        let cast = NSMenu()
        for option in Avatar.allCases {
            let choice = item("\(option.name): \(option.tagline)", #selector(setAvatar(_:)))
            choice.representedObject = option.rawValue
            choice.state = option == avatar ? .on : .off
            choice.image = menuImages[option]
            cast.addItem(choice)
        }
        pick.submenu = cast
        menu.addItem(pick)

        let login = item("Open at login", #selector(toggleLogin))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Budge", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    // MARK: End-of-day log

    /// Plain Markdown, so you can open and edit it anywhere. Stays on this Mac.
    private let logURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Budge/work-log.md")

    private func loadLog() -> WorkLog {
        WorkLog(markdown: (try? String(contentsOf: logURL, encoding: .utf8)) ?? "")
    }

    private func saveLog(_ log: WorkLog) throws {
        try FileManager.default.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try log.markdown.write(to: logURL, atomically: true, encoding: .utf8)
    }

    @objc private func askForLog() {
        nudge.present(LogPromptView(
            avatar: avatar,
            onSave: { [weak self] text in self?.finishLog(saving: text) },
            onSkip: { [weak self] in self?.finishLog(saving: nil) }))
    }

    private func finishLog(saving text: String?) {
        nudge.hide()
        let now = Date()
        defaults.set(WorkLog.dayKey(now, .current), forKey: "logAskedDay")
        guard let text else { return }
        var log = loadLog()
        log.add(text, on: now)
        do {
            try saveLog(log)
        } catch {
            NSApp.activate()
            NSAlert(error: error).runModal()
            return
        }
        if EndOfDay.isFriday(now) { showWeek() }
    }

    @objc private func showWeek() {
        nudge.present(WeekView(
            avatar: avatar, days: loadLog().week(of: Date()),
            onOpenLog: { [weak self] in self?.openLog() },
            onClose: { [weak self] in self?.nudge.hide() }))
    }

    private func openLog() {
        if !FileManager.default.fileExists(atPath: logURL.path) { try? saveLog(WorkLog()) }
        NSWorkspace.shared.open(logURL)
    }

    @objc private func nudgeNow() {
        showNudge(caption: "Quick break")
    }

    @objc private func pauseHour() {
        pause(until: Date().addingTimeInterval(3600))
    }

    @objc private func pauseTomorrow() {
        let morning = Calendar.current.nextDate(after: Date(), matching: DateComponents(hour: 6),
                                                matchingPolicy: .nextTime) ?? Date().addingTimeInterval(12 * 3600)
        pause(until: morning)
    }

    private func pause(until date: Date) {
        clock.pause(until: date)
        defaults.set(date, forKey: "pausedUntil")
        nudge.hide()
        updateIcon()
    }

    @objc private func resume() {
        clock.resume()
        defaults.removeObject(forKey: "pausedUntil")
        updateIcon()
    }

    @objc private func setInterval(_ sender: NSMenuItem) {
        intervalMinutes = sender.tag
    }

    @objc private func setAvatar(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let picked = Avatar(rawValue: raw) else { return }
        avatar = picked
        showNudge(caption: "Hi, I'm new here", counted: false) // say hello so you see who you picked
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSApp.activate()
            NSAlert(error: error).runModal()
        }
    }

    private static func describe(_ date: Date) -> String {
        let time = date.formatted(date: .omitted, time: .shortened)
        return Calendar.current.isDateInToday(date) ? time : "tomorrow \(time)"
    }
}

private extension Int {
    var nonZero: Int? { self == 0 ? nil : self }
}
