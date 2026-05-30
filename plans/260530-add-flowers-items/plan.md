# Plan: Add 20 Flower Templates and 20 Items
Status: 🟡 In Progress
Date: 2026-05-30
Mode: Fast

## Overview
Populate the eco-backend database with 20 flower templates (7 base + 13 variants) and 20 tiered items (WATER/FERTILIZER/PESTICIDE), then update two Godot files so the client resolves icons and stage data for all 20 flowers and 20 items correctly.

## Phases
- [ ] Phase 1: BE Seeder — Seed 3 synergies, 20 FlowerTemplates, and 20 Items into Seeder.cs
- [ ] Phase 2: Godot Data Mapping — Extend GardenManager and ReferenceDataService to cover all 20 flowers and all item icon tiers

## Research Summary
N/A

## Dependencies
- eco-backend must be running and connected to a live PostgreSQL instance for seeding to apply
- `/api/admin/inventory/grant` endpoint must exist for post-seeding verification

## Risks
- HIGH: Duplicate-key error if Seeder runs more than once — Mitigation: guard each block with `if (!context.FlowerTemplates.Any())` / `if (!context.Items.Any())`
- MEDIUM: Item icon lookup silently fails for new tier prefixes — Mitigation: Phase 2 replaces strip-logic with keyword-contains loop covering all tier words
- LOW: Variant flower names not in `_FLOWER_DEFAULTS` emit a push_warning and show no growth stages — Mitigation: Phase 2 adds all 13 variant entries to that dict
