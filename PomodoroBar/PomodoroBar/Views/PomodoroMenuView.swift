import AppKit
import SwiftUI

struct PomodoroMenuView: View {
    @EnvironmentObject private var viewModel: PomodoroViewModel
    @State private var displayedProgress: Double = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                Text(viewModel.statusText)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Quit PomodoroBar")
            }

            Text(viewModel.displayedTime)
                .font(.system(.largeTitle, design: .monospaced))
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            interactiveProgressBar

            controls
        }
        .frame(width: 260)
        .padding()
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
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color(nsColor: .quaternaryLabelColor))

                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.accentColor)
                        .frame(width: fillWidth)

                    Spacer(minLength: 0)
                }

                if let label {
                    Text(label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(height: 16)
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

    private func controlButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
    }
}
