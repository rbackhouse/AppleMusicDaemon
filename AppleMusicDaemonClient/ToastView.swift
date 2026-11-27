//
//  ToastView.swift
//  AppleMusicDaemonClient
//
//  Created by Richard Backhouse on 12/28/25.
//

import SwiftUI

// MARK: - Toast Level
enum ToastLevel {
    case error
    case warning
    case success
    case info
    
    var icon: String {
        switch self {
        case .error: return "xmark.octagon.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .success: return "checkmark.circle.fill"
        case .info: return "info.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .error: return .red
        case .warning: return .orange
        case .success: return .green
        case .info: return .blue
        }
    }
    
    /// Problems stay up longer so there's time to read them.
    var defaultDuration: TimeInterval {
        switch self {
        case .error: return 6
        case .warning: return 5
        case .success, .info: return 3
        }
    }
}

// MARK: - Toast Item
struct ToastItem: Identifiable, Equatable {
    let id = UUID()
    let level: ToastLevel
    let title: String
    let message: String
    /// Overrides the level's default duration.
    var duration: TimeInterval? = nil
}

// MARK: - Toast View
struct ToastView: View {
    let item: ToastItem
    /// Fraction of display time remaining (1 → 0). Pass nil to hide the bar.
    var progress: Double? = nil
    let onDismiss: () -> Void
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var iconBounce = false
    
    private let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.level.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(item.level.color.gradient)
                .symbolEffect(.bounce, value: iconBounce)
                .frame(width: 36, height: 36)
                .background(item.level.color.opacity(0.15), in: Circle())
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                if !item.message.isEmpty {
                    Text(item.message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
            .accessibilityElement(children: .combine)
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .background(Color.primary.opacity(0.07), in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
            .help("Dismiss")
        }
        .padding(14)
        .background {
            ZStack {
                Rectangle().fill(.regularMaterial)
                // Soft tint that fades out from the icon side
                LinearGradient(
                    colors: [item.level.color.opacity(0.14), .clear],
                    startPoint: .leading,
                    endPoint: .center
                )
            }
        }
        .overlay(alignment: .bottom) {
            if let progress {
                Rectangle()
                    .fill(item.level.color.gradient)
                    .frame(height: 3)
                    .scaleEffect(x: max(progress, 0), anchor: .leading)
                    .animation(.linear(duration: 0.05), value: progress)
                    .accessibilityHidden(true)
            }
        }
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(item.level.color.opacity(0.25), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 8)
        .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
        .frame(maxWidth: 400)
        .padding(.horizontal)
        .onAppear {
            if !reduceMotion { iconBounce.toggle() }
        }
    }
}

// MARK: - Toast Presenter
/// Handles the countdown, pause-on-hover and swipe-to-dismiss for one toast.
private struct ToastPresenter: View {
    let item: ToastItem
    let onDismiss: () -> Void
    
    @State private var remaining: Double = 1
    @State private var isHovering = false
    @GestureState private var dragOffset: CGFloat = 0
    
    private var isPaused: Bool {
        isHovering || dragOffset != 0
    }
    
    var body: some View {
        ToastView(item: item, progress: remaining, onDismiss: onDismiss)
            .offset(y: min(dragOffset, 0))
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation.height
                    }
                    .onEnded { value in
                        if value.translation.height < -30 {
                            onDismiss()
                        }
                    }
            )
            .onHover { isHovering = $0 }
            .task { await runCountdown() }
    }
    
    @MainActor
    private func runCountdown() async {
        let total = Duration.seconds(max(item.duration ?? item.level.defaultDuration, 0.1))
        let clock = ContinuousClock()
        var lastTick = clock.now
        
        while remaining > 0 {
            do {
                try await Task.sleep(for: .milliseconds(50))
            } catch {
                return // Cancelled: the toast has already gone away
            }
            let now = clock.now
            if !isPaused {
                remaining -= lastTick.duration(to: now) / total
            }
            lastTick = now
        }
        onDismiss()
    }
}

// MARK: - Toast Modifier
struct ToastModifier: ViewModifier {
    @Binding var toast: ToastItem?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                ZStack(alignment: .top) {
                    if let current = toast {
                        ToastPresenter(item: current) {
                            dismiss(current.id)
                        }
                        .id(current.id) // Each new toast gets a fresh timer
                        .padding(.top, 12)
                        .transition(transition)
                    }
                }
                .animation(
                    reduceMotion
                        ? .easeInOut(duration: 0.2)
                        : .spring(response: 0.4, dampingFraction: 0.78),
                    value: toast
                )
            }
            .onChange(of: toast) { _, newValue in
                if let newValue {
                    AccessibilityNotification
                        .Announcement("\(newValue.title). \(newValue.message)")
                        .post()
                }
            }
    }
    
    private var transition: AnyTransition {
        reduceMotion
            ? .opacity
            : .move(edge: .top)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 0.92, anchor: .top))
    }
    
    private func dismiss(_ id: ToastItem.ID) {
        // An outgoing toast must never dismiss its replacement
        guard toast?.id == id else { return }
        toast = nil
    }
}

// MARK: - View Extension
extension View {
    func toast(_ toast: Binding<ToastItem?>) -> some View {
        modifier(ToastModifier(toast: toast))
    }
}

// MARK: - Demo View
struct ToastDemoView: View {
    @State private var currentToast: ToastItem?
    
    var body: some View {
        VStack(spacing: 20) {
            Button("Show Error Toast") {
                currentToast = ToastItem(
                    level: .error,
                    title: "Error",
                    message: "Something went wrong. Please try again."
                )
            }
            
            Button("Show Warning Toast") {
                currentToast = ToastItem(
                    level: .warning,
                    title: "Warning",
                    message: "This action cannot be undone."
                )
            }
            
            Button("Show Success Toast") {
                currentToast = ToastItem(
                    level: .success,
                    title: "Success",
                    message: "Your changes have been saved successfully."
                )
            }
            
            Button("Show Info Toast") {
                currentToast = ToastItem(
                    level: .info,
                    title: "Information",
                    message: "This feature is currently in beta testing."
                )
            }
        }
        .buttonStyle(.bordered)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toast($currentToast)
    }
}

// MARK: - Preview
struct ToastDemoView_Previews: PreviewProvider {
    static var previews: some View {
        ToastDemoView()
    }
}
