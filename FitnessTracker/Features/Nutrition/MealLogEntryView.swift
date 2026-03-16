import SwiftUI

// MARK: - MealLogEntryTab

private enum MealLogEntryTab: String, CaseIterable {
    case search = "Search"
    case scan = "Barcode"
    case templates = "Templates"
    case custom = "Custom"

    var systemImage: String {
        switch self {
        case .search:    return "magnifyingglass"
        case .scan:      return "barcode.viewfinder"
        case .templates: return "list.star"
        case .custom:    return "plus.circle"
        }
    }
}

// MARK: - MealLogEntryView

/// Sheet that allows the user to log a food item into a meal. The user picks
/// a food via one of four methods (search, barcode scan, templates, custom),
/// selects a meal type and serving size, then taps "Add to Log".
///
/// After adding the entry `onAdd` is called so `NutritionViewModel` can
/// refresh and the sheet can be dismissed.
struct MealLogEntryView: View {

    // MARK: - Properties

    let repository: any NutritionRepository
    let onAdd: (FoodItem, Double, MealType) -> Void

    // MARK: - State

    @State private var selectedTab: MealLogEntryTab = .search
    @State private var selectedFood: FoodItem?
    @State private var servingText: String = "100"
    @State private var mealType: MealType = .breakfast
    @State private var showBarcodeScanner: Bool = false
    @State private var barcodeError: String?
    @State private var isLookingUpBarcode: Bool = false

    @Environment(\.dismiss) private var dismiss

    private let barcodeService = BarcodeLookupService()

    // MARK: - Computed

    private var servingGrams: Double { Double(servingText) ?? 100 }
    private var canAdd: Bool { selectedFood != nil && servingGrams > 0 }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab picker
                Picker("Method", selection: $selectedTab) {
                    ForEach(MealLogEntryTab.allCases, id: \.self) { tab in
                        Label(tab.rawValue, systemImage: tab.systemImage).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 8)

                // Tab content
                tabContent
                    .frame(maxHeight: .infinity)

                // Selected food + meal config panel
                if let food = selectedFood {
                    foodConfigPanel(food: food)
                }
            }
            .navigationTitle("Add Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { confirmAdd() }
                        .disabled(!canAdd)
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showBarcodeScanner) {
                barcodeScannerSheet
            }
        }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .search:
            FoodSearchView(repository: repository) { food in
                selectedFood = food
                servingText = "100"
            }

        case .scan:
            barcodeTabView

        case .templates:
            MealTemplatesView(repository: repository) { food in
                selectedFood = food
                servingText = "100"
            }

        case .custom:
            NavigationStack {
                CustomFoodFormView(repository: repository) { food in
                    selectedFood = food
                    servingText = "100"
                    selectedTab = .search
                }
            }
        }
    }

    // MARK: - Barcode Tab

    private var barcodeTabView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 60))
                .foregroundStyle(.tint)

            Text("Scan a product barcode to look up its nutritional information.")
                .multilineTextAlignment(.center)
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)

            if let barcodeError {
                Label(barcodeError, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button {
                barcodeError = nil
                showBarcodeScanner = true
            } label: {
                Label("Open Camera", systemImage: "camera")
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLookingUpBarcode)

            if isLookingUpBarcode {
                ProgressView("Looking up barcode…")
            }

            Spacer()
        }
    }

    // MARK: - Barcode Scanner Sheet

    private var barcodeScannerSheet: some View {
        BarcodeScannerView { barcode in
            showBarcodeScanner = false
            Task { await handleBarcode(barcode) }
        } onError: { message in
            showBarcodeScanner = false
            barcodeError = message
        }
        .ignoresSafeArea()
    }

    // MARK: - Food Config Panel

    private func foodConfigPanel(food: FoodItem) -> some View {
        VStack(spacing: 0) {
            Divider()
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(food.name)
                            .font(.headline)
                        Text("Selected food")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        selectedFood = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 16) {
                    // Serving size
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Serving (g)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("100", text: $servingText)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }

                    // Meal type
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Meal")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("Meal", selection: $mealType) {
                            Text("Breakfast").tag(MealType.breakfast)
                            Text("Lunch").tag(MealType.lunch)
                            Text("Dinner").tag(MealType.dinner)
                            Text("Snack").tag(MealType.snack)
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }

                    Spacer()

                    // Computed macros
                    let factor = servingGrams / 100.0
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.0f kcal", food.kcalPer100g * factor))
                            .font(.subheadline.bold())
                            .foregroundStyle(.orange)
                        Text(String(format: "P %.0fg  C %.0fg  F %.0fg",
                                    food.proteinG * factor,
                                    food.carbG * factor,
                                    food.fatG * factor))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemBackground))
        }
    }

    // MARK: - Actions

    private func confirmAdd() {
        guard let food = selectedFood else { return }
        onAdd(food, servingGrams, mealType)
        dismiss()
    }

    private func handleBarcode(_ barcode: String) async {
        isLookingUpBarcode = true
        barcodeError = nil
        defer { isLookingUpBarcode = false }
        do {
            if let food = try await barcodeService.lookup(barcode: barcode, in: repository) {
                selectedFood = food
                servingText = "100"
                selectedTab = .search
            } else {
                barcodeError = "No food found for barcode \(barcode). Try adding it as a custom food."
            }
        } catch {
            barcodeError = error.localizedDescription
        }
    }
}
