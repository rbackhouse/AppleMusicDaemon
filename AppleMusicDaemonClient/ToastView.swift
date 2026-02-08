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
        case .error: return "xmark.circle.fill"
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
}

// MARK: - Toast Item
struct ToastItem: Identifiable, Equatable {
    let id = UUID()
    let level: ToastLevel
    let title: String
    let message: String
}

// MARK: - Toast View
struct ToastView: View {
    let item: ToastItem
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.level.icon)
                .font(.title2)
                .foregroundColor(item.level.color)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(item.message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                #if os(iOS)
                .fill(Color(.systemBackground))
                #elseif os(macOS)
                .fill(Color(nsColor: .controlBackgroundColor))
                #endif
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .padding(.horizontal)
    }
}

// MARK: - Toast Modifier
struct ToastModifier: ViewModifier {
    @Binding var toast: ToastItem?
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if let toast = toast {
                VStack {
                    ToastView(item: toast) {
                        withAnimation {
                            self.toast = nil
                        }
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation {
                                self.toast = nil
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding(.top, 50)
            }
        }
        .animation(.spring(), value: toast)
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
        NavigationView {
            VStack(spacing: 20) {
                Button("Show Error Toast") {
                    currentToast = ToastItem(
                        level: .error,
                        title: "Error",
                        message: "Something went wrong. Please try again."
                    )
                }
                .buttonStyle(.bordered)
                
                Button("Show Warning Toast") {
                    currentToast = ToastItem(
                        level: .warning,
                        title: "Warning",
                        message: "This action cannot be undone."
                    )
                }
                .buttonStyle(.bordered)
                
                Button("Show Success Toast") {
                    currentToast = ToastItem(
                        level: .success,
                        title: "Success",
                        message: "Your changes have been saved successfully."
                    )
                }
                .buttonStyle(.bordered)
                
                Button("Show Info Toast") {
                    currentToast = ToastItem(
                        level: .info,
                        title: "Information",
                        message: "This feature is currently in beta testing."
                    )
                }
                .buttonStyle(.bordered)
            }
            .navigationTitle("Toast Demo")
        }
        .toast($currentToast)
    }
}

// MARK: - Preview
struct ToastDemoView_Previews: PreviewProvider {
    static var previews: some View {
        ToastDemoView()
    }
}
