import SwiftUI

struct BottleListView: View {
    var viewModel: FP82FixerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("CrossOver Bottles", systemImage: "cube.box")
                .font(.headline)
                .foregroundStyle(.primary)

            if viewModel.bottles.isEmpty {
                Text("No bottles found")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(viewModel.bottles) { bottle in
                            BottleRow(
                                bottle: bottle,
                                isSelected: viewModel.selectedBottleID == bottle.id
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.selectedBottleID = bottle.id
                            }
                            .id(bottle.id)
                        }
                    }
                    .padding(4)
                }
                .frame(minHeight: 80, maxHeight: 140)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }

            HStack(spacing: 10) {
                Button {
                    viewModel.createBottle()
                } label: {
                    Label("Create", systemImage: "plus")
                }

                Button {
                    viewModel.removeSelectedBottle()
                } label: {
                    Label("Remove", systemImage: "trash")
                }
                .disabled(viewModel.selectedBottleID == nil)

                Spacer()

                Button {
                    viewModel.refreshBottles()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
            .controlSize(.small)
        }
        .glassCard()
    }
}

// MARK: - Bottle Row

private struct BottleRow: View {
    let bottle: Bottle
    let isSelected: Bool

    var body: some View {
        HStack {
            Image(systemName: isSelected ? "cube.box.fill" : "cube.box")
                .foregroundStyle(isSelected ? .blue : .secondary)
            Text(bottle.name)
                .foregroundStyle(.primary)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(.blue)
                    .font(.caption)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            isSelected
                ? AnyShapeStyle(.blue.opacity(0.15))
                : AnyShapeStyle(.clear),
            in: RoundedRectangle(cornerRadius: 6)
        )
    }
}
