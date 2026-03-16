import XCTest
import SwiftData
@testable import FitnessTracker

// MARK: - FallbackPlanProviderTests

@MainActor
final class FallbackPlanProviderTests: XCTestCase {

    // MARK: - Properties

    private var sut: FallbackPlanProvider!

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        sut = FallbackPlanProvider()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeProfile(
        goal: FitnessGoal = .maintain,
        activityLevel: ActivityLevel = .moderatelyActive
    ) throws -> UserProfile {
        let container = try AppSchema.makeContainer(inMemory: true)
        _ = container // keep alive
        return UserProfile(
            name: "Fallback Test User",
            age: 30,
            gender: .female,
            heightCm: 165,
            weightKg: 65,
            activityLevel: activityLevel,
            goal: goal,
            tdeeKcal: 2200,
            proteinTargetG: 150,
            carbTargetG: 230,
            fatTargetG: 65
        )
    }

    // MARK: - Non-empty plan

    func test_generatePlan_returnsNonEmptyWorkoutPlan() async throws {
        let profile = try makeProfile()
        let plan = try await sut.generatePlan(profile: profile)
        XCTAssertFalse(plan.days.isEmpty, "Fallback plan must have at least one workout day")
    }

    func test_generatePlan_planHasExpectedDayCount() async throws {
        let profile = try makeProfile()
        let plan = try await sut.generatePlan(profile: profile)
        XCTAssertEqual(plan.daysPerWeek, 3)
        XCTAssertEqual(plan.days.count, 3)
    }

    func test_generatePlan_isFullBodySplit() async throws {
        let profile = try makeProfile()
        let plan = try await sut.generatePlan(profile: profile)
        XCTAssertEqual(plan.splitType, .fullBody)
    }

    // MARK: - Days structure

    func test_generatePlan_eachDayHasExercises() async throws {
        let profile = try makeProfile()
        let plan = try await sut.generatePlan(profile: profile)

        for day in plan.days {
            XCTAssertFalse(
                day.plannedExercises.isEmpty,
                "Day '\(day.dayLabel)' must have at least one planned exercise"
            )
        }
    }

    func test_generatePlan_dayLabelsAreNonEmpty() async throws {
        let profile = try makeProfile()
        let plan = try await sut.generatePlan(profile: profile)

        for day in plan.days {
            XCTAssertFalse(day.dayLabel.isEmpty, "Day label must not be empty")
        }
    }

    func test_generatePlan_weekdayIndicesAreValid() async throws {
        let profile = try makeProfile()
        let plan = try await sut.generatePlan(profile: profile)

        for day in plan.days {
            XCTAssertTrue(
                (1...7).contains(day.weekdayIndex),
                "weekdayIndex \(day.weekdayIndex) for '\(day.dayLabel)' must be in range 1-7"
            )
        }
    }

    func test_generatePlan_daysHaveDistinctWeekdayIndices() async throws {
        let profile = try makeProfile()
        let plan = try await sut.generatePlan(profile: profile)

        let indices = plan.days.map { $0.weekdayIndex }
        let uniqueIndices = Set(indices)
        XCTAssertEqual(indices.count, uniqueIndices.count, "All workout days must fall on different weekdays")
    }

    // MARK: - PlannedExercise structure

    func test_generatePlan_exercisesHavePositiveSets() async throws {
        let profile = try makeProfile()
        let plan = try await sut.generatePlan(profile: profile)

        for day in plan.days {
            for exercise in day.plannedExercises {
                XCTAssertGreaterThan(exercise.targetSets, 0, "targetSets must be positive")
            }
        }
    }

    func test_generatePlan_exercisesHaveNonEmptyReps() async throws {
        let profile = try makeProfile()
        let plan = try await sut.generatePlan(profile: profile)

        for day in plan.days {
            for exercise in day.plannedExercises {
                XCTAssertFalse(exercise.targetReps.isEmpty, "targetReps must not be empty")
            }
        }
    }

    func test_generatePlan_exerciseSortOrderIsSequential() async throws {
        let profile = try makeProfile()
        let plan = try await sut.generatePlan(profile: profile)

        for day in plan.days {
            let sortOrders = day.plannedExercises
                .sorted { $0.sortOrder < $1.sortOrder }
                .map { $0.sortOrder }

            for (index, order) in sortOrders.enumerated() {
                XCTAssertEqual(order, index, "sortOrder must be sequential starting at 0")
            }
        }
    }

    // MARK: - No network call

    func test_generatePlan_doesNotThrow() async throws {
        // FallbackPlanProvider must never throw — verify for different profiles.
        let profiles: [UserProfile] = try [
            makeProfile(goal: .cut, activityLevel: .sedentary),
            makeProfile(goal: .maintain, activityLevel: .moderatelyActive),
            makeProfile(goal: .bulk, activityLevel: .extraActive),
        ]

        for profile in profiles {
            XCTAssertNoThrow(try await sut.generatePlan(profile: profile))
        }
    }

    // MARK: - UserProfile association

    func test_generatePlan_planIsAssociatedWithProfile() async throws {
        let profile = try makeProfile()
        let plan = try await sut.generatePlan(profile: profile)
        XCTAssertTrue(plan.userProfile === profile, "Plan must be associated with the provided UserProfile")
    }
}
