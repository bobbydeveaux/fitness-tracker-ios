import SwiftUI
import SwiftData

// MARK: - DashboardView

/// Main dashboard view shown after onboarding is complete.
///
/// This is a placeholder that will be fully implemented in a subsequent sprint
/// task. It confirms routing away from the onboarding flow is working and that
/// the user's profile has been persisted.
struct DashboardView: View {

    @Environment(AppEnvironment.self) private var env
    @Query private var profiles: [UserProfile]

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let profile {
                        WelcomeBannerView(profile: profile)
                        DailyTargetsView(profile: profile)
                    } else {
                        ContentUnavailableView(
                            "No Profile Found",
                            systemImage: "person.slash",
                            description: Text("Complete onboarding to set up your profile.")
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await env.healthKitService.requestAuthorisationIfNeeded()
            }
        }
    }
}

// MARK: - WelcomeBannerView

private struct WelcomeBannerView: View {
    let profile: UserProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Welcome back,")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(profile.name)
                        .font(.title.bold())
                }
                Spacer()
                Image(systemName: "figure.strengthtraining.traditional")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .foregroundStyle(.tint)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - DailyTargetsView

private struct DailyTargetsView: View {
    let profile: UserProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Daily Targets")
                .font(.headline)

            HStack(spacing: 12) {
                TargetTile(
                    label: "Calories",
                    value: String(format: "%.0f", profile.tdeeKcal),
                    unit: "kcal",
                    icon: "flame.fill",
                    color: .orange
                )
                TargetTile(
                    label: "Protein",
                    value: String(format: "%.0f", profile.proteinTargetG),
                    unit: "g",
                    icon: "p.circle.fill",
                    color: .red
                )
            }
            HStack(spacing: 12) {
                TargetTile(
                    label: "Carbs",
                    value: String(format: "%.0f", profile.carbTargetG),
                    unit: "g",
                    icon: "c.circle.fill",
                    color: .blue
                )
                TargetTile(
                    label: "Fat",
                    value: String(format: "%.0f", profile.fatTargetG),
                    unit: "g",
                    icon: "f.circle.fill",
                    color: .yellow
                )
            }
        }
    }
}

// MARK: - TargetTile

private struct TargetTile: View {
    let label: String
    let value: String
    let unit: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.title2.bold())
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Preview

#Preview {
    DashboardView()
        .environment(AppEnvironment.makeProductionEnvironment())
}
