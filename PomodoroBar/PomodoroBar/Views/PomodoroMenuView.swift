import AppKit
import SwiftUI

struct PomodoroMenuView: View {
    @EnvironmentObject private var viewModel: PomodoroViewModel

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

            ProgressView(value: viewModel.progress)
                .progressViewStyle(.linear)

            if isIdle {
                presetToggle
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            }

            controls
        }
        .frame(width: 260)
        .padding()
        .animation(.easeInOut(duration: 0.2), value: isIdle)
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

    private var presetToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                viewModel.togglePreset()
            } label: {
                HStack {
                    Text("Preset")
                    Spacer()
                    Text(viewModel.selectedPreset.title)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private func controlButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
    }
}
