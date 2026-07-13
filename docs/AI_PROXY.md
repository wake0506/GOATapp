# Nutrition AI Proxy

The production path is:

`Flutter -> Supabase Edge Function nutrition-ai -> DeepSeek`

The Edge Function validates the Supabase JWT, derives the user ID from the JWT, enforces a request size limit and daily per-user quota, deduplicates `clientRequestId`, applies a 20-second upstream timeout, validates the returned JSON, and returns a small stable response.

The DeepSeek key is read only from the server-side `DEEPSEEK_API_KEY` function secret. It is never accepted from the request body, Flutter release configuration, logs, or the repository. Debug-only direct provider access remains an explicit local flag; the production default is the Edge Function.

The function does not log complete diet text, tokens, keys, full profiles, or upstream raw errors. AI failure is non-fatal to local food search and manual recording.

Legacy daily-tip, food-search, and coach-chat HTTP calls are disabled in Release unless the explicit debug-only direct flag is enabled in a local debug build. The nutrition entry flow uses the Edge Function adapter by default.
