# Phase 1: Domain Message Catalog

## Requirements

This phase delivers a RefCounted domain class holding a const Dictionary message pool keyed by WeatherState.Condition (SUNNY, CLOUDY, RAINY, STORM), with 2-3 Vietnamese messages per condition and a random-selection helper. The catalog is pure domain (no Node, no autoload imports), following TipCatalog.gd's const-data pattern, enabling easy UI separation and message maintenance.

## Steps

1. Create `domain/WeatherNpcMessageCatalog.gd` as RefCounted with class_name declaration.

2. Define const Dictionary `_message_pool` keyed by WeatherState.Condition, each entry an Array of 2-3 Vietnamese message strings (e.g., SUNNY → ["Nắng nóng quá, nhớ tưới nước cho cây...", "Mặt trời gay gắt, cây dễ bị khô — hãy chăm sóc đấy!"] etc.).

3. Implement static function `get_random_message(condition: WeatherState.Condition) -> String` that selects and returns a random message from the pool for the given condition.

4. Add error handling: push_error() if condition maps to empty array or null; return fallback message if array access fails (never return null).

5. Test message pool by reading the created file and verifying all 4 conditions are present with at least 2 messages each.

## Success Criteria

- File `domain/WeatherNpcMessageCatalog.gd` exists with `class_name WeatherNpcMessageCatalog extends RefCounted`.
- Const Dictionary `_message_pool` covers SUNNY, CLOUDY, RAINY, STORM conditions; each holds Array[String] with 2-3 Vietnamese messages.
- Function `get_random_message(condition: WeatherState.Condition) -> String` callable and returns non-empty string for valid conditions.
- Invalid condition or empty array logs push_error() and returns sensible fallback (e.g., "Thời tiết thay đổi rồi!").
- All messages are in Vietnamese, contextually appropriate to condition (e.g., RAINY mentions risk of overwatering, SUNNY suggests watering, CLOUDY/STORM provide fitting advice).
- No Node imports, no autoload imports — pure domain.

## Risks

- Invalid condition passed to get_random_message() → **Mitigation:** Validate condition against enum before pool access; push_error() and return fallback.
- Message string too long causing bubble layout issues later → **Mitigation:** Keep messages concise (1-2 sentences, ~50-80 characters), verify visually in Phase 2 when bubble scene is integrated.
- Duplicate messages across conditions cause repetitive feel → **Mitigation:** Vary content per condition (mưa/úng, nắng/tưới, mây/ẩm, bão/sơ tán).
