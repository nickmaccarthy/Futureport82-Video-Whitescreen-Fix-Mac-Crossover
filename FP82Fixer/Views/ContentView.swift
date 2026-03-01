import SwiftUI

@MainActor
struct ContentView: View {
    @State private var viewModel = FP82FixerViewModel()

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 14) {
                headerSection
                BottleListView(viewModel: viewModel)
                ExecutablePickerView(viewModel: viewModel)
                OutputLogView(outputLines: viewModel.outputLines)
                applyButton
            }
            .padding(20)
        }
        .frame(minWidth: 700, minHeight: 700)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Futureport82 CrossOver Bottle Fixer")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.primary)

                Text("v\(viewModel.appVersion)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            HStack(spacing: 6) {
                StatusDot(isOK: viewModel.crossOverStatusOK)
                Text(viewModel.crossOverStatusOK ? "CrossOver Ready" : "CrossOver Not Found")
                    .font(.callout)
                    .foregroundStyle(viewModel.crossOverStatusOK ? Color.secondary : Color.red)
            }
        }
    }

    // MARK: - Apply Button

    private var applyButton: some View {
        Button {
            viewModel.applyFix()
        } label: {
            HStack(spacing: 8) {
                switch (viewModel.isFixRunning, viewModel.fixResult) {
                case (true, _):
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                    Text("Applying Fix...")
                case (false, .success):
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Done — Fix Applied Successfully")
                case (false, .failed):
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Fix Failed — Check Output Log")
                default:
                    Text("Apply Media Foundation Fix")
                }
            }
            .frame(maxWidth: .infinity)
            .animation(.easeInOut(duration: 0.3), value: viewModel.fixResult)
            .animation(.easeInOut(duration: 0.3), value: viewModel.isFixRunning)
        }
        .buttonStyle(GradientButtonStyle(result: viewModel.fixResult))
        .disabled(!viewModel.canApplyFix)
    }
}
