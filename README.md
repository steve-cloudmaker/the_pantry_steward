# Sously

**Know what you have. Cook what you love.**

Sously is a household pantry inventory and recipe suggestion app for **iPhone**, **iPad**, and **Mac Catalyst**, built with **SwiftUI** and **Core Data** (CloudKit sync).

## Features

### Pantry inventory
- Add items manually, via **photo**, or **barcode scan**
- Barcode lookup via free APIs (Open Food Facts, UPCitemdb, Open Library for books)
- Track quantity, unit, size, brand, storage location, expiration / best-before
- Categories, sub-categories, tags (`#weeknight`), priority, favorites
- Search by name, brand, notes, category, or tag
- Low-stock and expiration badges

### Shared shopping lists
- Multiple checklist-style lists with per-item **prices** and running totals
- Auto-populate from **low stock** and **upcoming meal plans**
- Add scaled recipe ingredients, highlighting what you already have
- CloudKit-ready shared list flag (enable iCloud container in Xcode)

### What can I make?
- Ranks recipes by **pantry match score**
- **7-day dinner plan generator** from real recipes + pantry
- `AIMealPlanProvider` protocol for future AI refinement (allergies, preferences)

### Recipe box & meal planning
- Create/edit recipes with ingredients and steps
- **Import from URL** (JSON-LD + schema.org microdata)
- Meal plans with mark-as-eaten → **automatic inventory deduction**
- Share / print meal plans

## Requirements

- Xcode 16+ (tested on Xcode 26)
- iOS 17+ / Mac Catalyst 14+
- iCloud capability for CloudKit sync (optional for local-only use)

## Getting started

```bash
# Generate Xcode project
xcodegen generate

# Open in Xcode
open Sously.xcodeproj
```

1. Select the **Sously** scheme and an iPhone or iPad simulator (or My Mac for Catalyst).
2. Set your **Development Team** in Signing & Capabilities.
3. For CloudKit: ensure container `iCloud.com.sously.app` matches your Apple Developer account (or update entitlements + `PersistenceController`).
4. Build & Run (⌘R).

## Tests

```bash
xcodebuild -scheme Sously -destination 'platform=iOS Simulator,name=iPhone 16' test
```

Unit tests cover ingredient normalization, recipe matching, import parsers, shopping list gaps, meal plan generation, and barcode lookup fallback. UI tests verify tab navigation.

## Architecture

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Project layout

```
Sously/
  App/           SouslyApp, AppState
  Persistence/   NSPersistentCloudKitContainer
  Models/        Sously.xcdatamodeld
  Repositories/  Core Data access
  Services/      Matching, import, barcode, meal plans
  Views/         SwiftUI (Pantry, Shopping, Cook, Recipes, Plan)
SouslyTests/
SouslyUITests/
```

## Tagline

Smart pantry management for busy families — built to impress, not to defer.
