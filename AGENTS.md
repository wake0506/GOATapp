# GOAT Engineering Rules

GOAT is a production-oriented fitness and nutrition tracking app.

- Preserve the current nutrition, training, statistics, account, and visual behavior while refactoring.
- Keep the existing Mars Green `#008C8C` and page background `#F4F5F7`.
- New business logic belongs in focused models, services, repositories, or feature modules, not in `lib/main.dart`.
- Read the documents under `docs/` before changing architecture or UI.
- Run tests before and after changes. Treat data correctness, account isolation, and user data safety as higher priority than new features.
- All asynchronous UI callbacks must check `mounted`, use timeouts for network requests, and release controllers, timers, and platform resources.
- Never use `SharedPreferences.clear()` for user data. Use an explicit namespace and key list.
- Do not commit directly to `main` for feature or refactor work.

