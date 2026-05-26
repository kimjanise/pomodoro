import AppKit
import Combine
import Foundation

enum TimerState: Equatable {
    case idle
    case working
    case onBreak
    case paused(previous: PausedFrom)
}

enum PausedFrom: Equatable {
    case working
    case onBreak
}

enum TimerPreset: CaseIterable, Equatable {
    case standard
    case extended

    var workDuration: Int {
        switch self {
        case .standard:
            return 25 * 60
        case .extended:
            return 50 * 60
        }
    }

    var breakDuration: Int {
        switch self {
        case .standard:
            return 5 * 60
        case .extended:
            return 10 * 60
        }
    }

    var title: String {
        switch self {
        case .standard:
            return "25/5"
        case .extended:
            return "50/10"
        }
    }

    mutating func toggle() {
        self = self == .standard ? .extended : .standard
    }
}

final class PomodoroViewModel: ObservableObject {
    @Published var state: TimerState = .idle
    @Published var remainingTime: TimeInterval
    @Published var selectedPreset: TimerPreset = .standard

    private var targetEndDate: Date?
    private var pausedRemainingTime: TimeInterval?
    private var timerCancellable: AnyCancellable?
    private var wakeCancellable: AnyCancellable?
    private var isHandlingCompletion = false
    private var currentWorkSessionDuration: Int
    private var currentBreakSessionDuration: Int

    init() {
        let initialPreset = TimerPreset.standard
        _selectedPreset = Published(initialValue: initialPreset)
        remainingTime = TimeInterval(initialPreset.workDuration)
        currentWorkSessionDuration = initialPreset.workDuration
        currentBreakSessionDuration = initialPreset.breakDuration
        subscribeToWakeNotifications()
    }

    var remainingSeconds: Int {
        max(0, Int(ceil(remainingTime)))
    }

    var menuBarTitle: String {
        switch state {
        case .idle:
            return "🍅 \(formatTime(selectedPreset.workDuration))"
        case .working, .onBreak, .paused(previous: _):
            return "🍅 \(formatTime(remainingSeconds))"
        }
    }

    var statusText: String {
        switch state {
        case .idle:
            return "Pomodoro"
        case .working:
            return "Focus Time"
        case .onBreak:
            return "Break Time"
        case .paused:
            return "Paused"
        }
    }

    var displayedTime: String {
        switch state {
        case .idle:
            return formatTime(selectedPreset.workDuration)
        case .working, .onBreak, .paused:
            return formatTime(remainingSeconds)
        }
    }

    var progress: Double {
        if case .idle = state {
            return 1
        }

        let total = Double(currentSessionDuration)
        guard total > 0 else {
            return 0
        }

        let remaining = min(max(remainingTime, 0), total)
        return max(0, min(1, remaining / total))
    }

    var presetBarLabel: String? {
        if case .idle = state {
            return selectedPreset.title
        }

        return nil
    }

    private var currentSessionDuration: Int {
        switch state {
        case .working:
            return currentWorkSessionDuration
        case .onBreak:
            return currentBreakSessionDuration
        case .paused(let previous):
            switch previous {
            case .working:
                return currentWorkSessionDuration
            case .onBreak:
                return currentBreakSessionDuration
            }
        case .idle:
            return selectedPreset.workDuration
        }
    }

    func togglePreset() {
        guard state == .idle else {
            return
        }

        selectedPreset.toggle()
        remainingTime = TimeInterval(selectedPreset.workDuration)
    }

    /// Starts a new work session if one is not already active.
    func startWork() {
        guard state != .working else {
            return
        }

        let workDuration = selectedPreset.workDuration
        isHandlingCompletion = false
        currentWorkSessionDuration = workDuration
        currentBreakSessionDuration = selectedPreset.breakDuration
        targetEndDate = Date().addingTimeInterval(TimeInterval(workDuration))
        pausedRemainingTime = nil
        remainingTime = TimeInterval(workDuration)
        state = .working
        startTimer()
    }

    /// Starts a break session if one is not already active.
    func startBreak() {
        guard state != .onBreak else {
            return
        }

        let breakDuration = currentBreakSessionDuration
        isHandlingCompletion = false
        targetEndDate = Date().addingTimeInterval(TimeInterval(breakDuration))
        pausedRemainingTime = nil
        remainingTime = TimeInterval(breakDuration)
        state = .onBreak
        startTimer()
    }

    /// Pauses the active session and stores the remaining time.
    func pause() {
        switch state {
        case .working:
            pausedRemainingTime = currentRemainingTime()
            remainingTime = pausedRemainingTime ?? remainingTime
            targetEndDate = nil
            stopTimer()
            state = .paused(previous: .working)
        case .onBreak:
            pausedRemainingTime = currentRemainingTime()
            remainingTime = pausedRemainingTime ?? remainingTime
            targetEndDate = nil
            stopTimer()
            state = .paused(previous: .onBreak)
        case .idle, .paused:
            return
        }
    }

    /// Resumes the paused session from the stored remaining time.
    func resume() {
        guard case .paused(let previous) = state else {
            return
        }

        let remaining = pausedRemainingTime ?? remainingTime
        guard remaining > 0 else {
            reset()
            return
        }

        isHandlingCompletion = false
        remainingTime = remaining
        targetEndDate = Date().addingTimeInterval(remaining)
        pausedRemainingTime = nil
        state = previous == .working ? .working : .onBreak
        startTimer()
    }

    /// Resets the timer to its idle state.
    func reset() {
        stopTimer()
        isHandlingCompletion = false
        targetEndDate = nil
        pausedRemainingTime = nil
        remainingTime = TimeInterval(selectedPreset.workDuration)
        state = .idle
    }

    /// Updates the active session from the current wall clock time.
    func timerTick() {
        switch state {
        case .working, .onBreak:
            guard let targetEndDate else {
                return
            }

            let time = max(0, targetEndDate.timeIntervalSinceNow)
            if remainingTime != time {
                remainingTime = time
            }

            if time <= 0 {
                completeSessionIfNeeded()
            }
        case .idle, .paused:
            return
        }
    }

    /// Formats seconds as MM:SS with zero padding.
    func formatTime(_ seconds: Int) -> String {
        let safeSeconds = max(0, seconds)
        let minutes = safeSeconds / 60
        let secondsPart = safeSeconds % 60
        return String(format: "%02d:%02d", minutes, secondsPart)
    }

    private func startTimer() {
        stopTimer()
        timerCancellable = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.timerTick()
            }
    }

    private func stopTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    private func subscribeToWakeNotifications() {
        wakeCancellable = NSWorkspace.shared.notificationCenter.publisher(
            for: NSWorkspace.didWakeNotification
        )
        .sink { [weak self] _ in
            self?.handleWake()
        }
    }

    private func handleWake() {
        switch state {
        case .working, .onBreak:
            timerTick()
        case .idle, .paused:
            return
        }
    }

    private func currentRemainingTime() -> TimeInterval {
        guard let targetEndDate else {
            return remainingTime
        }

        return max(0, targetEndDate.timeIntervalSinceNow)
    }

    private func completeSessionIfNeeded() {
        guard !isHandlingCompletion else {
            return
        }

        isHandlingCompletion = true
        stopTimer()
        targetEndDate = nil
        pausedRemainingTime = nil
        remainingTime = 0

        switch state {
        case .working:
            NotificationManager.shared.sendNotification(
                title: "Pomodoro Complete",
                body: "Time for a break!"
            )
            startBreak()
        case .onBreak:
            NotificationManager.shared.sendNotification(
                title: "Break Complete",
                body: "Back to focus!"
            )
            startWork()
        case .idle, .paused:
            isHandlingCompletion = false
        }
    }
}
