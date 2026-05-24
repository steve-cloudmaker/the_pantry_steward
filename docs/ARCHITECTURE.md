# Sously Architecture

## Overview

Sously follows a **layered architecture** optimized for SwiftUI and Core Data:

```
Views → AppState → Repositories / Services → Core Data (+ CloudKit)
```

| Layer | Responsibility |
|-------|----------------|
| **Views** | SwiftUI screens, navigation, user input |
| **AppState** | Composition root, dependency wiring, `@EnvironmentObject` |
| **Repositories** | CRUD + queries per aggregate (Pantry, Recipe, Shopping, MealPlan) |
| **Services** | Domain logic: matching, import, barcode lookup, plan generation |
| **Persistence** | `NSPersistentCloudKitContainer`, merge policy, background contexts |

## Core Data model

| Entity | Purpose |
|--------|---------|
| `PantryItem` | Ingredient inventory |
| `Category` / `SubCategory` | Organization |
| `Tag` | Many-to-many tags on pantry + recipes |
| `ShoppingList` / `ShoppingListItem` | Checklists with price + recipe source |
| `Recipe` / `RecipeIngredient` / `RecipeStep` | Recipe box |
| `MealPlan` / `PlannedMeal` | Scheduled meals |

All entities are **CloudKit-syncable** (`syncable="YES"`).

## Key services

### `RecipeMatchingService`
Scores each recipe’s **required** ingredients against pantry stock using `IngredientNormalizer` (fuzzy token overlap). Optional ingredients affect display only.

### `MealPlanGeneratorService`
1. Rank recipes by match score.
2. Distribute unique recipes across days/meal slots.
3. Optional `AIMealPlanProvider` hook for preference/allergy filtering.

### `ShoppingListBuilderService`
Builds shopping gaps from:
- Low stock (`quantity <= lowStockThreshold`)
- Upcoming `PlannedMeal` ingredients (scaled by servings)
- Full recipe import with `onlyMissing` mode

### `RecipeImportService`
Parses remote HTML:
1. JSON-LD `Recipe` blocks (most blogs)
2. schema.org microdata fallback
3. `IngredientLineParser` for free-text quantities

### `InventoryAdjustmentService`
When a meal is marked **eaten**, deducts scaled required ingredients from matching pantry rows.

### `BarcodeLookupService`
Multi-provider fallback (no API key): Open Food Facts (`product_type=all` across food/beauty/pet/general products), [UPCitemdb](https://www.upcitemdb.com/) trial API (100 lookups/day), then [Open Library](https://openlibrary.org/developers/api) for ISBN barcodes. Sends a `User-Agent` on all requests; tries UPC-A/EAN-13 variants when needed.

## Multi-platform UI

- **Compact** (`horizontalSizeClass != .regular`): `TabView` with five tabs.
- **Regular** (iPad / Mac Catalyst): `NavigationSplitView` sidebar.

## Extensibility

| Protocol | Use |
|----------|-----|
| `AIMealPlanProvider` | Plug in OpenAI / on-device models for menu refinement |
| CloudKit sharing | `ShoppingList.isShared` + container entitlements |

## Testing strategy

- **In-memory** `PersistenceController(inMemory: true)` for deterministic tests.
- `SeedDataService.resetSeedFlag()` between test runs.
- Parser tests use fixture HTML strings (no network).
- UI tests launch app and verify tab bar (seed data populates lists).

## Security & privacy

- Camera / photo library usage strings in `Info.plist`.
- Network: recipe import + barcode lookup only; no third-party analytics.
- User data stays in local Core Data + user's iCloud container when enabled.
