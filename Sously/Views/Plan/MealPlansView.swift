import SwiftUI

struct MealPlansView: View {
    @EnvironmentObject private var appState: AppState
    @State private var plans: [MealPlan] = []
    @State private var showingNewPlan = false

    var body: some View {
        NavigationStack {
            Group {
                if plans.isEmpty {
                    ContentUnavailableView(
                        "No meal plans",
                        systemImage: "calendar",
                        description: Text("Generate a plan from Cook or create one here.")
                    )
                } else {
                    List {
                        ForEach(plans, id: \.objectID) { plan in
                            NavigationLink {
                                MealPlanDetailView(plan: plan)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(plan.safeName)
                                        .font(.headline)
                                    Text("\((plan.startDate ?? Date()).formatted(date: .abbreviated, time: .omitted)) – \((plan.endDate ?? Date()).formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete(perform: deletePlans)
                    }
                }
            }
            .navigationTitle("Meal Plans")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewPlan = true
                    } label: {
                        Label("New Plan", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewPlan) {
                NewMealPlanSheet { reload() }
            }
            .onAppear(perform: reload)
        }
    }

    private func reload() {
        plans = (try? appState.mealPlanRepository.fetchPlans()) ?? []
    }

    private func deletePlans(at offsets: IndexSet) {
        for index in offsets {
            try? appState.mealPlanRepository.deletePlan(plans[index])
        }
        reload()
    }
}

struct NewMealPlanSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    var onCreate: () -> Void

    @State private var name = ""
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 6, to: Date()) ?? Date()

    var body: some View {
        NavigationStack {
            Form {
                TextField("Plan name", text: $name)
                DatePicker("Start", selection: $startDate, displayedComponents: .date)
                DatePicker("End", selection: $endDate, displayedComponents: .date)
            }
            .navigationTitle("New Meal Plan")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        _ = try? appState.mealPlanRepository.createPlan(
                            name: name.isEmpty ? "Meal Plan" : name,
                            startDate: startDate,
                            endDate: endDate
                        )
                        onCreate()
                        dismiss()
                    }
                }
            }
        }
    }
}

struct MealPlanDetailView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var plan: MealPlan
    @State private var shareText = ""

    private var meals: [PlannedMeal] {
        ((plan.meals as? Set<PlannedMeal>) ?? []).sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
    }

    var body: some View {
        List {
            Section {
                ShareLink(item: MealPlanExportService.plainText(for: plan)) {
                    Label("Share meal plan", systemImage: "square.and.arrow.up")
                }
                #if canImport(UIKit)
                Button {
                    MealPlanExportService.printPlan(plan)
                } label: {
                    Label("Print", systemImage: "printer")
                }
                #endif
            }

            Section("Meals") {
                ForEach(meals, id: \.objectID) { meal in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(meal.recipe?.name ?? "Recipe")
                                .font(.headline)
                            Text("\((meal.date ?? Date()).formatted(date: .abbreviated, time: .omitted)) · \(meal.mealTypeEnum.displayName)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if meal.isEaten {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Button("Ate it") {
                                markEaten(meal)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
        }
        .navigationTitle(plan.safeName)
    }

    private func markEaten(_ meal: PlannedMeal) {
        do {
            try appState.inventoryAdjuster.markMealEaten(meal, mealPlanRepository: appState.mealPlanRepository)
        } catch {
            try? appState.mealPlanRepository.markEaten(meal)
        }
    }
}
