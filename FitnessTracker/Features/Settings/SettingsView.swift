import SwiftUI

// MARK: - SettingsView

/// Root settings screen providing appearance toggling, notification management,
/// and iCloud sync status.
///
/// The view is driven by `SettingsViewModel` which persists all preferences to
/// `UserDefaults` so they survive app termination and are restored on next launch.
///
/// The preferred colour scheme from `viewModel.appearanceMode` is applied to the
/// entire window via `.preferredColorScheme(_:)` and defaults to `.dark` on first
/// launch, satisfying the acceptance criterion.
struct SettingsView: View {

    // MARK: - Dependencies

    @State var viewModel: SettingsViewModel

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                appearanceSection
                notificationsSection
                iCloudSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await viewModel.onAppear()
            }
        }
        .preferredColorScheme(viewModel.appearanceMode.colorScheme)
    }

    // MARK: - Sections

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Theme", selection: $viewModel.appearanceMode) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var notificationsSection: some View {
        Section("Workout Reminders") {
            Toggle("Enable Reminders", isOn: $viewModel.notificationsEnabled)

            if viewModel.notificationsEnabled {
                NavigationLink("Manage Schedule") {
                    NotificationSettingsView(viewModel: viewModel)
                }
            }
        }
    }

    private var iCloudSection: some View {
        Section {
            HStack {
                Label("iCloud Sync", systemImage: "icloud")

                Spacer()

                syncStatusView
            }

            if case .error(let message) = viewModel.syncState {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("iCloud")
        }
    }

    @ViewBuilder
    private var syncStatusView: some View {
        switch viewModel.syncState {
        case .synced:
            Label("On", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.subheadline)
        case .syncing:
            Label("Syncing…", systemImage: "arrow.triangle.2.circlepath")
                .foregroundStyle(.blue)
                .font(.subheadline)
        case .error:
            Label("Error", systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
                .font(.subheadline)
        case .unknown:
            ProgressView()
                .controlSize(.small)
        }
    }
}

// MARK: - AppearanceMode + ColorScheme

private extension AppearanceMode {
    var colorScheme: ColorScheme? {
        switch self {
        case .dark:   return .dark
        case .light:  return .light
        case .system: return nil
        }
    }
}

// MARK: - Preview

#Preview("Settings – Dark (default)") {
    SettingsView(viewModel: SettingsViewModel())
}

#Preview("Settings – iCloud Error") {
    let vm = SettingsViewModel(
        cloudSyncService: PreviewCloudSyncService(state: .error("Sign in to iCloud to enable sync."))
    )
    return SettingsView(viewModel: vm)
}

// MARK: - Preview Helpers

private final class PreviewCloudSyncService: CloudSyncServiceProtocol {
    private(set) var syncState: CloudSyncState
    var iCloudAvailable: Bool { true }
    var isSyncEnabled: Bool { false }
    init(state: CloudSyncState) { syncState = state }
    func checkAvailability() async { /* no-op in preview */ }
    func enableSync() {}
    func disableSync() {}
}
