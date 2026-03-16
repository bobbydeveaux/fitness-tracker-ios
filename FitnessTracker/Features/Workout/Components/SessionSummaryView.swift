import SwiftUI

// MARK: - SessionSummaryView

/// A post-session recap screen displayed after the user taps "Finish Workout".
///
/// Shows:
/// - Total volume lifted (kg)
/// - Session duration (formatted as `h mm ss`)
/// - PR highlights — a list of every set that set a new personal record
/// - A "Done" button to dismiss the summary and return to the idle state.
///
/// Receives an immutable `SessionSummary` value; no direct dependency on
/// `SessionViewModel` so it can be driven by any data source (e.g. a preview stub).
struct SessionSummaryView: View {

    // MARK: - Input

    let summary: SessionSummary
    let onDone: () -> Void

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    statsSection
                    if !summary.prSets.isEmpty {
                        prSection
                    }
                    Spacer(minLength: 32)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .navigationTitle("Session Complete")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: onDone)
                        .bold()
                }
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            Text("Great work!")
                .font(.title.bold())
            Text("Your session has been saved.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    private var statsSection: some View {
        HStack(spacing: 0) {
            StatCard(
                value: String(format: "%.0f kg", summary.totalVolumeKg),
                label: "Total Volume",
                icon: "scalemass.fill",
                color: .blue
            )
            Divider()
                .frame(height: 64)
            StatCard(
                value: formattedDuration,
                label: "Duration",
                icon: "clock.fill",
                color: .orange
            )
            if !summary.prSets.isEmpty {
                Divider()
                    .frame(height: 64)
                StatCard(
                    value: "\(summary.prSets.count)",
                    label: summary.prSets.count == 1 ? "New PR" : "New PRs",
                    icon: "trophy.fill",
                    color: .yellow
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var prSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Personal Records", systemImage: "trophy.fill")
                .font(.headline)
                .foregroundStyle(.orange)

            ForEach(summary.prSets.indices, id: \.self) { idx in
                let pr = summary.prSets[idx]
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                    Text(pr.exerciseName)
                        .font(.subheadline.bold())
                    Spacer()
                    Text(String(format: "%.1f kg × %d", pr.weightKg, pr.reps))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.tertiarySystemBackground))
                )
            }
        }
    }

    // MARK: - Helpers

    private var formattedDuration: String {
        let h = summary.durationSeconds / 3600
        let m = (summary.durationSeconds % 3600) / 60
        let s = summary.durationSeconds % 60
        if h > 0 {
            return String(format: "%dh %02dm", h, m)
        }
        return String(format: "%dm %02ds", m, s)
    }
}

// MARK: - StatCard

private struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.title3.bold())
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

// MARK: - Preview

#Preview {
    SessionSummaryView(
        summary: SessionSummary(
            totalVolumeKg: 4320,
            durationSeconds: 3720,
            prSets: [
                ("Barbell Bench Press", 102.5, 5),
                ("Back Squat", 140, 3)
            ]
        ),
        onDone: {}
    )
}
