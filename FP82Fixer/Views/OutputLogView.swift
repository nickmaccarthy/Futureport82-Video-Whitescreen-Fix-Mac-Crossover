import SwiftUI

struct OutputLogView: View {
    var outputLines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Output", systemImage: "terminal")
                .font(.headline)
                .foregroundStyle(.primary)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(outputLines.enumerated()), id: \.offset) { index, line in
                            Text(line)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.primary.opacity(0.85))
                                .textSelection(.enabled)
                                .id(index)
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: 100)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                )
                .onChange(of: outputLines.count) { _, _ in
                    if let last = outputLines.indices.last {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(last, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .glassCard()
        .frame(maxHeight: .infinity)
    }
}
