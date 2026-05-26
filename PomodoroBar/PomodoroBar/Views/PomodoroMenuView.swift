import AppKit
import SwiftUI

struct PomodoroMenuView: View {
    @EnvironmentObject private var viewModel: PomodoroViewModel
    @State private var displayedProgress: Double = 1
    private let panelBackground = Color(red: 0.978, green: 0.956, blue: 0.919)
    private let panelShadow = Color(red: 0.494, green: 0.341, blue: 0.220).opacity(0.16)
    private let primaryTextColor = Color(red: 0.290, green: 0.204, blue: 0.145)
    private let secondaryTextColor = Color(red: 0.514, green: 0.431, blue: 0.345)
    private let warmOrange = Color(red: 0.973, green: 0.703, blue: 0.259)
    private let softOlive = Color(red: 0.639, green: 0.737, blue: 0.380)
    private let softBrown = Color(red: 0.463, green: 0.314, blue: 0.224)
    private let trackColor = Color(red: 0.900, green: 0.871, blue: 0.824)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 10) {
                    Text(viewModel.sessionEmoji)
                        .font(.system(size: 24))

                    Text(viewModel.statusText)
                        .font(.custom("Chalkboard SE", size: 20))
                        .foregroundStyle(primaryTextColor)

                    Spacer()

                    Button {
                        NSApplication.shared.terminate(nil)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(secondaryTextColor)
                            .frame(width: 24, height: 24)
                            .background(
                                Circle()
                                    .fill(.white.opacity(0.72))
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Quit PomodoroBar")
                }

                Text(viewModel.displayedTime)
                    .font(.custom("Chalkboard SE", size: 34))
                    .foregroundStyle(primaryTextColor)
                    .padding(.vertical, -4)
            }

            interactiveProgressBar

            controls
        }
        .frame(width: 260)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(panelBackground)
                .shadow(color: panelShadow, radius: 16, x: 0, y: 10)
        )
    }

    private var isIdle: Bool {
        if case .idle = viewModel.state {
            return true
        }

        return false
    }

    @ViewBuilder
    private var controls: some View {
        HStack(spacing: 12) {
            switch viewModel.state {
            case .idle:
                controlButton("Start", systemImage: "play.fill", action: viewModel.startWork)
            case .working, .onBreak:
                controlButton("Pause", systemImage: "pause.fill", action: viewModel.pause)
                controlButton("Reset", systemImage: "arrow.counterclockwise", action: viewModel.reset)
            case .paused:
                controlButton("Resume", systemImage: "play.fill", action: viewModel.resume)
                controlButton("Reset", systemImage: "arrow.counterclockwise", action: viewModel.reset)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var interactiveProgressBar: some View {
        timerBar(label: viewModel.presetBarLabel)
            .overlay {
                if isIdle {
                    Button {
                        viewModel.togglePreset()
                    } label: {
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .help(isIdle ? "Toggle between \(viewModel.selectedPreset.title) and the other preset" : "")
    }

    private func timerBar(label: String?) -> some View {
        GeometryReader { geometry in
            let fillWidth = geometry.size.width * displayedProgress

            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(trackColor)

                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(barFillColor)
                        .frame(width: fillWidth)

                    Spacer(minLength: 0)
                }

                if let label {
                    Text(label)
                        .font(.custom("Chalkboard SE", size: 13))
                        .foregroundStyle(primaryTextColor)
                }
            }
        }
        .frame(height: 20)
        .onAppear {
            displayedProgress = clampedProgress
        }
        .onChange(of: viewModel.progress) { newValue in
            let nextProgress = min(max(newValue, 0), 1)
            let animation = nextProgress > displayedProgress
                ? Animation.easeOut(duration: 0.35)
                : Animation.linear(duration: 0.1)

            withAnimation(animation) {
                displayedProgress = nextProgress
            }
        }
        .contentShape(Rectangle())
    }

    private var clampedProgress: Double {
        min(max(viewModel.progress, 0), 1)
    }

    private var barFillColor: LinearGradient {
        let colors: [Color]

        switch viewModel.state {
        case .idle:
            colors = [softOlive, Color(red: 0.746, green: 0.818, blue: 0.482)]
        case .working:
            colors = [warmOrange, Color(red: 0.980, green: 0.624, blue: 0.337)]
        case .onBreak:
            colors = [softOlive, Color(red: 0.746, green: 0.818, blue: 0.482)]
        case .paused:
            colors = [softBrown, Color(red: 0.576, green: 0.420, blue: 0.322)]
        }

        return LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
    }

    private func controlButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.custom("Chalkboard SE", size: 14))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .contentShape(Capsule(style: .continuous))
                .background(
                    Capsule(style: .continuous)
                        .fill(buttonFillColor(for: title))
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(buttonTextColor(for: title))
    }

    private func buttonFillColor(for title: String) -> Color {
        switch title {
        case "Start", "Resume":
            return warmOrange
        case "Pause":
            return softOlive
        case "Reset":
            return softBrown
        default:
            return warmOrange
        }
    }

    private func buttonTextColor(for title: String) -> Color {
        switch title {
        case "Pause", "Reset":
            return Color.white
        default:
            return primaryTextColor
        }
    }
}
