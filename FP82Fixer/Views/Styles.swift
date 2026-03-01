import SwiftUI

// MARK: - Glass Card

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 14

    func body(content: Content) -> some View {
        content
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.25), .white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 14) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }
}

// MARK: - Glass Text Field

struct GlassTextField: ViewModifier {
    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .padding(8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            )
    }
}

extension View {
    func glassTextField() -> some View {
        modifier(GlassTextField())
    }
}

// MARK: - Gradient Button Style

struct GradientButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var result: FP82FixerViewModel.FixResult = .none

    private var gradientColors: [Color] {
        if !isEnabled && result == .none {
            return [Color.gray.opacity(0.4), Color.gray.opacity(0.3)]
        }
        switch result {
        case .none: return [.blue, .cyan]
        case .success: return [.green, .mint]
        case .failed: return [.orange, .red]
        }
    }

    private var glowColor: Color {
        switch result {
        case .none: return isEnabled ? .cyan.opacity(0.3) : .clear
        case .success: return .green.opacity(0.3)
        case .failed: return .red.opacity(0.3)
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .shadow(
                color: glowColor,
                radius: configuration.isPressed ? 4 : 8,
                y: configuration.isPressed ? 1 : 3
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.3), value: result)
    }
}

// MARK: - Glass Progress Bar

struct GlassProgressBar: View {
    var value: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.ultraThinMaterial)

                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, geo.size.width * CGFloat(value)))
                    .shadow(color: .cyan.opacity(0.4), radius: 6)
            }
        }
        .frame(height: 8)
    }
}

// MARK: - App Background

struct AppBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(nsColor: .windowBackgroundColor)

                backgroundImage(size: geo.size)

                LinearGradient(
                    stops: [
                        .init(color: .blue.opacity(opacity(0.12)), location: 0),
                        .init(color: .purple.opacity(opacity(0.08)), location: 0.35),
                        .init(color: .indigo.opacity(opacity(0.10)), location: 0.65),
                        .init(color: .teal.opacity(opacity(0.06)), location: 1.0),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: [.blue.opacity(opacity(0.08)), .clear],
                    center: .topTrailing,
                    startRadius: 100,
                    endRadius: 500
                )

                RadialGradient(
                    colors: [.purple.opacity(opacity(0.06)), .clear],
                    center: .bottomLeading,
                    startRadius: 80,
                    endRadius: 400
                )
            }
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func backgroundImage(size: CGSize) -> some View {
        if let url = Bundle.module.url(forResource: "background", withExtension: "png", subdirectory: "Images"),
           let nsImage = NSImage(contentsOf: url) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size.width, height: size.height)
                .clipped()
                .opacity(colorScheme == .dark ? 0.07 : 0.04)
                .allowsHitTesting(false)
        }
    }

    private func opacity(_ base: Double) -> Double {
        colorScheme == .dark ? base : base * 0.6
    }
}

// MARK: - Status Indicator

struct StatusDot: View {
    var isOK: Bool

    var body: some View {
        Circle()
            .fill(isOK ? Color.green : Color.red)
            .frame(width: 10, height: 10)
    }
}
