import SwiftUI
import AppKit
import ServiceManagement

// MARK: - Onboarding Host

struct OnboardingView: View {
    @ObservedObject var settings: AppSettings
    var onDone: () -> Void

    @State private var step = 0

    var body: some View {
        ZStack {
            // Background
            Color(NSColor.windowBackgroundColor).ignoresSafeArea()

            VStack(spacing: 0) {
                // Content area
                Group {
                    switch step {
                    case 0:  WelcomeStep()
                    case 1:  PermissionsStep(settings: settings)
                    default: FinishStep()
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal:   .move(edge: .leading).combined(with: .opacity)
                ))
                .id(step)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Nav bar
                OnboardingNavBar(step: $step, totalSteps: 3, onDone: {
                    settings.hasCompletedOnboarding = true
                    onDone()
                })
            }
        }
        .frame(width: 680, height: 520)
    }
}

// MARK: - Nav bar

private struct OnboardingNavBar: View {
    @Binding var step: Int
    let totalSteps: Int
    let onDone: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            // Dot indicators
            HStack(spacing: 6) {
                ForEach(0..<totalSteps, id: \.self) { i in
                    Capsule()
                        .fill(i == step ? Color.accentColor : Color.secondary.opacity(0.25))
                        .frame(width: i == step ? 22 : 7, height: 7)
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: step)
                }
            }

            Spacer()

            if step > 0 {
                Button("Back") {
                    withAnimation(.easeInOut(duration: 0.22)) { step -= 1 }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.system(size: 13))
            }

            Button(step < totalSteps - 1 ? "Continue" : "Get Started") {
                withAnimation(.easeInOut(duration: 0.22)) {
                    if step < totalSteps - 1 { step += 1 }
                    else { onDone() }
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.return)
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 28)
        .background(
            Divider()
                .frame(maxWidth: .infinity, maxHeight: 1)
                .opacity(0.4),
            alignment: .top
        )
    }
}

// MARK: - Step 0: Welcome

private struct WelcomeStep: View {
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 32) {
            // App icon + glow
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 130, height: 130)
                    .blur(radius: 20)
                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor.opacity(0.9), Color.accentColor],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .shadow(color: Color.accentColor.opacity(0.4), radius: 20, y: 8)
                    Image(systemName: "doc.on.clipboard.fill")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(.white)
                        .symbolRenderingMode(.hierarchical)
                }
            }
            .scaleEffect(appeared ? 1 : 0.6)
            .opacity(appeared ? 1 : 0)

            VStack(spacing: 12) {
                Text("Welcome to Recall")
                    .font(.system(size: 34, weight: .bold))
                    .offset(y: appeared ? 0 : 12)
                    .opacity(appeared ? 1 : 0)

                Text("Your clipboard history, always within reach.\nSearch, pin, and paste anything you've copied — instantly.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .offset(y: appeared ? 0 : 8)
                    .opacity(appeared ? 1 : 0)
            }

            // Feature pills
            HStack(spacing: 12) {
                FeaturePill(icon: "magnifyingglass", label: "Search history")
                FeaturePill(icon: "pin.fill", label: "Pin items")
                FeaturePill(icon: "bolt.fill", label: "Instant paste")
            }
            .offset(y: appeared ? 0 : 8)
            .opacity(appeared ? 1 : 0)
        }
        .padding(.horizontal, 80)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.05)) {
                appeared = true
            }
        }
    }
}

private struct FeaturePill: View {
    let icon: String
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.accentColor)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color.primary.opacity(0.06), in: Capsule())
    }
}

// MARK: - Step 1: Permissions

private struct PermissionsStep: View {
    @ObservedObject var settings: AppSettings

    @State private var hasAccessibility = AXIsProcessTrusted()
    @State private var screenshotEnabled = ScreenshotCapture.isEnabled
    @State private var launchAtLogin = (SMAppService.mainApp.status == .enabled)

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Set Up Recall")
                    .font(.system(size: 26, weight: .bold))
                Text("Grant the permissions Recall needs to work best.\nRequired items must be enabled; optional ones are up to you.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
            }
            .padding(.horizontal, 44)
            .padding(.top, 36)
            .padding(.bottom, 28)

            // Permission rows
            VStack(spacing: 10) {
                PermissionRow(
                    icon: "doc.on.clipboard.fill",
                    iconColor: .blue,
                    title: "Clipboard History",
                    description: "Recall monitors your clipboard and saves everything you copy.",
                    badge: .required,
                    isGranted: true,   // always available — no permission needed
                    actionLabel: nil,
                    onAction: nil
                )

                PermissionRow(
                    icon: "hand.raised.fill",
                    iconColor: .orange,
                    title: "Accessibility Access",
                    description: "Needed to paste items directly into other apps for you.",
                    badge: .required,
                    isGranted: hasAccessibility,
                    actionLabel: hasAccessibility ? nil : "Open Settings",
                    onAction: {
                        NSWorkspace.shared.open(
                            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                        )
                    }
                )

                PermissionRow(
                    icon: "camera.viewfinder",
                    iconColor: .purple,
                    title: "Screenshot Capture",
                    description: "Redirects ⌘⇧3 / ⌘⇧4 screenshots to your clipboard history.",
                    badge: .optional,
                    isGranted: screenshotEnabled,
                    actionLabel: screenshotEnabled ? "Disable" : "Enable",
                    onAction: {
                        screenshotEnabled.toggle()
                        ScreenshotCapture.setEnabled(screenshotEnabled)
                    }
                )

                PermissionRow(
                    icon: "power",
                    iconColor: .green,
                    title: "Launch at Login",
                    description: "Recall starts automatically so your history is always ready.",
                    badge: .optional,
                    isGranted: launchAtLogin,
                    actionLabel: launchAtLogin ? "Disable" : "Enable",
                    onAction: {
                        launchAtLogin.toggle()
                        settings.launchAtLogin = launchAtLogin
                        try? launchAtLogin
                            ? SMAppService.mainApp.register()
                            : SMAppService.mainApp.unregister()
                    }
                )
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .onReceive(timer) { _ in
            hasAccessibility = AXIsProcessTrusted()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            hasAccessibility = AXIsProcessTrusted()
        }
    }
}

// MARK: - Permission Row

private enum PermissionBadge {
    case required, optional
}

private struct PermissionRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let badge: PermissionBadge
    let isGranted: Bool
    let actionLabel: String?
    let onAction: (() -> Void)?

    @State private var hovered = false

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(iconColor)
                    .symbolRenderingMode(.hierarchical)
            }

            // Text
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))

                    // Required / optional badge
                    if badge == .required {
                        Text("REQUIRED")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.85), in: Capsule())
                    } else {
                        Text("OPTIONAL")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15), in: Capsule())
                    }
                }

                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            // Status / action
            if isGranted {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.green)
                    Text("Enabled")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.green)
                }
                .transition(.scale.combined(with: .opacity))
            } else if let label = actionLabel, let action = onAction {
                Button(label, action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(iconColor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(hovered ? 0.06 : 0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            isGranted ? Color.green.opacity(0.3) : Color.primary.opacity(0.07),
                            lineWidth: 1
                        )
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isGranted)
        .onHover { hovered = $0 }
    }
}

// MARK: - Step 2: Finish

private struct FinishStep: View {
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 32) {
            // Checkmark animation
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 130, height: 130)
                    .blur(radius: 20)
                ZStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 96, height: 96)
                        .shadow(color: Color.green.opacity(0.4), radius: 20, y: 8)
                    Image(systemName: "checkmark")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .scaleEffect(appeared ? 1 : 0.4)
                .opacity(appeared ? 1 : 0)
            }

            VStack(spacing: 12) {
                Text("You're All Set!")
                    .font(.system(size: 32, weight: .bold))
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)

                Text("Recall is running in your menu bar.\nPress the shortcut below anytime to open it.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 8)
            }

            // Shortcut display
            HStack(spacing: 8) {
                ForEach(["⌘", "⇧", "V"], id: \.self) { key in
                    Text(key)
                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                        .frame(width: 48, height: 48)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.85)

            Text("Copy something now, then press ⌘⇧V to see it in Recall.")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .opacity(appeared ? 1 : 0)
        }
        .padding(.horizontal, 80)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.72).delay(0.05)) {
                appeared = true
            }
        }
    }
}
