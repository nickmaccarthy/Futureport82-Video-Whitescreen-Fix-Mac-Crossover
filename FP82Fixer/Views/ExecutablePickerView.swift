import SwiftUI

struct ExecutablePickerView: View {
    @Bindable var viewModel: FP82FixerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Futureport82 Executable", systemImage: "doc.badge.gearshape")
                .font(.headline)
                .foregroundStyle(.primary)

            HStack(spacing: 8) {
                TextField("Select the Futureport82 executable...", text: $viewModel.executablePath)
                    .glassTextField()

                Button("Browse...") {
                    viewModel.browseForExecutable()
                }
                .controlSize(.regular)
            }

            Toggle("Add Futureport82.exe to bottle as application (recommended)", isOn: $viewModel.addToBottle)
                .toggleStyle(.checkbox)
                .foregroundStyle(.secondary)
                .font(.callout)
        }
        .glassCard()
    }
}
