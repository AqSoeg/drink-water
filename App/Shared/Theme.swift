import SwiftUI
import HydrationCore

#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum WaterTheme {
    static let accent = Color(red: 73.0 / 255, green: 171.0 / 255, blue: 1)

    static var background: Color {
        #if os(macOS)
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.05, green: 0.07, blue: 0.11, alpha: 1)
                : NSColor(red: 0.94, green: 0.97, blue: 1, alpha: 1)
        })
        #else
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.05, green: 0.07, blue: 0.11, alpha: 1)
                : UIColor(red: 0.94, green: 0.97, blue: 1, alpha: 1)
        })
        #endif
    }

    static var surface: Color {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(uiColor: .secondarySystemGroupedBackground)
        #endif
    }
}

struct WaterBackdrop: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack {
            WaterTheme.background
            if !reduceTransparency {
                LinearGradient(
                    colors: [WaterTheme.accent.opacity(0.16), .clear, WaterTheme.accent.opacity(0.06)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

enum WaterDate {
    static func full(_ date: Date) -> String {
        date.formatted(.dateTime.locale(Locale(identifier: "zh_CN")).year().month(.wide).day())
    }

    static func short(_ date: Date) -> String {
        date.formatted(.dateTime.locale(Locale(identifier: "zh_CN")).month().day())
    }

    static func time(_ date: Date) -> String {
        date.formatted(.dateTime.locale(Locale(identifier: "zh_CN")).hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    }

    static func weekday(_ date: Date) -> String {
        date.formatted(.dateTime.locale(Locale(identifier: "zh_CN")).weekday(.wide))
    }
}

private struct WaterGlass: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var cornerRadius: CGFloat
    var tint: Color?
    var interactive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if reduceTransparency {
            content
                .background(WaterTheme.surface, in: shape)
                .overlay(shape.strokeBorder(.primary.opacity(0.08), lineWidth: 1))
        } else if #available(macOS 26.0, iOS 26.0, *) {
            content.glassEffect(.regular.tint(tint).interactive(interactive), in: shape)
        } else {
            content
                .background(.regularMaterial, in: shape)
                .overlay(shape.strokeBorder(.white.opacity(0.3), lineWidth: 1))
        }
    }
}

struct WaterCard: ViewModifier {
    var padding: CGFloat = 22
    var tint: Color? = nil

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .waterGlass(cornerRadius: 24, tint: tint)
    }
}

extension View {
    func waterCard(padding: CGFloat = 22, tint: Color? = nil) -> some View {
        modifier(WaterCard(padding: padding, tint: tint))
    }

    func waterGlass(cornerRadius: CGFloat = 16, tint: Color? = nil, interactive: Bool = false) -> some View {
        modifier(WaterGlass(cornerRadius: cornerRadius, tint: tint, interactive: interactive))
    }
}

struct WaterGlassGroup<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    @ViewBuilder
    var body: some View {
        if #available(macOS 26.0, iOS 26.0, *) {
            GlassEffectContainer(spacing: 6) { content }
        } else {
            content
        }
    }
}

struct WaterPrimaryButton: PrimitiveButtonStyle {
    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        if #available(macOS 26.0, iOS 26.0, *) {
            Button(configuration)
                .font(.headline)
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.roundedRectangle(radius: 18))
                .controlSize(.large)
                .tint(WaterTheme.accent)
        } else {
            Button(configuration)
                .font(.headline)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 18))
                .controlSize(.large)
                .tint(WaterTheme.accent)
        }
    }
}
