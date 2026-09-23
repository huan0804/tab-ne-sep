# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

"TAB: Né Sếp" — a Vietnamese-language browser mini-game (office comedy: switch between fake work/personal screens to avoid being caught by a wandering "Boss"). Single-page HTML games, no build step, no package manager, no test suite.

Production: `https://tab-ne-sep.vercel.app/play` (Vercel rewrites `/play` → `/game/TAB-Ne-Sep.html`, root `/` redirects to `/play`; see [vercel.json](vercel.json)).

## Commands

There is no build/lint/test tooling in this repo. Development loop is: edit the HTML file directly, open it in a browser (or push to Vercel, which auto-deploys on push to the connected branch).

- Local preview: open `game/TAB-Ne-Sep.html` directly in a browser (`file://`) — Supabase-backed leaderboard/multiplayer/analytics will fail gracefully and the game falls back to solo mode with `localStorage`.
- Deploy: push to the git remote; Vercel builds automatically. **Always ask for confirmation before `git push`** — this is a standing rule for this repo, not just a one-off preference.
- DB schema changes: run [supabase/schema.sql](supabase/schema.sql) in the Supabase SQL editor. It is idempotent (`create table if not exists`, `create or replace function`, existence checks before adding to publications) — safe to re-run in full after edits.

## Architecture

### Two HTML variants, one actively maintained

- [game/TAB-Ne-Sep.html](game/TAB-Ne-Sep.html) — **current/production version**. Concentric ellipse distance rings drawn in-scene, room multiplayer ("1 Sếp chung"), streak system, challenge links, mobile UX fixes, daily/weekly analytics. This is the only file that receives new features.
- [game/TAB-Ne-Sep_v1-radar.html](game/TAB-Ne-Sep_v1-radar.html) — original version with a separate corner radar HUD instead of in-scene rings. Kept only for bug fixes/icon/mobile parity — **do not port new features here** unless explicitly asked; it is intentionally behind.

Each file is a single self-contained HTML document (inline CSS/JS, no framework, no bundler). Only external dependencies are Google Fonts and the Supabase JS UMD build via CDN `<script>` tag. When editing, work directly in the inline `<script>`/`<style>` blocks — there is no source-map indirection to worry about.

### Backend: Supabase (Postgres), not Claude Artifact `db`

**Important doc staleness:** [README.md](README.md) and [docs/GAME_SPEC.md](docs/GAME_SPEC.md) still describe an older architecture built on Claude Artifact's `db` capability (40-shard document model). The game has since migrated to Supabase — see [supabase/schema.sql](supabase/schema.sql) and the `SUPABASE_URL`/`createClient` setup near the top of the `<script>` block in `TAB-Ne-Sep.html`. [WORK_LOG.md](WORK_LOG.md) is the accurate, up-to-date source for current architecture and decisions; prefer it over README/GAME_SPEC when they conflict. Treat GAME_SPEC.md's game-design/rules content (win/lose conditions, Boss AI tuning, screen content, UX flow) as still accurate — only its persistence/leaderboard section (§8) is outdated.

Schema highlights ([supabase/schema.sql](supabase/schema.sql)):
- `players` — one row per player (no sharding needed; Postgres has no per-artifact document cap), leaderboard via real `ORDER BY avg_score DESC`.
- `sessions` — one row per match, for A/B analysis between the two UI variants.
- `rooms` — multiplayer room membership/state. Boss position during a room match is **not** persisted here — the host computes it and broadcasts via Supabase Realtime (~15Hz) to avoid write-per-frame load; `rooms` only tracks slow-changing state (host, waiting/playing) via Postgres Changes so late subscribers still get the "start" event.
- `analytics_access_hours` / `analytics_screen_time` / `analytics_heatmap` — all-time cumulative anonymous analytics, fixed single-row(s) tables.
- `analytics_*_daily` / `analytics_heatmap_weekly` — parallel time-bucketed analytics added later (kept alongside the all-time tables, not a replacement) to answer DAU/MAU/cohort/funnel questions. Day/week keys are computed **client-side in fixed Vietnam time (UTC+7)** via `vnDateKeyPadded()`/`vnWeekKey()` and passed to RPCs as text — never derived from Postgres server timestamp, to avoid timezone drift if the server isn't UTC+7.
- `increment_*` RPCs (`increment_access_hour[_daily]`, `increment_screen_time[_daily]`, `increment_heatmap[_weekly]`) — atomic counter increments (`x = x + n` inside one `UPDATE`, row-locked by Postgres) replacing an earlier select-then-update pattern from the client that had a real race condition (concurrent writers silently clobbering each other's increments under load). These are `security definer`; the client can no longer `UPDATE` the analytics tables directly, only call the RPCs via `supabase-js` `.rpc(...)`.
- RLS: public read/write by design (anon/publishable key) — this is a client-only game with no backend server, accepted tradeoff for a public mini-game with no sensitive data.

### Player identity & known constraints

- `playerId` is bound to a (browser, domain) pair via `localStorage` — switching browsers on the same device is treated as a different player. Known limitation, not yet solved, affects streak accuracy.
- Streak logic always uses fixed Vietnam time (UTC+7), never client machine time.
- Player-supplied names (`players.name`) are attacker-controlled and rendered via `innerHTML` in several places (leaderboard, room player list, invite/challenge banners, room results) — server only enforces a length cap, not HTML-safety. Always route any new name interpolation through the shared `escapeHtml()` helper; never concatenate a name into `innerHTML` directly (see stored-XSS fix in WORK_LOG.md).
- `?challenge=<id>` friend-challenge links are a **separate feature from multiplayer rooms** — don't conflate them when working on either.
- Supabase free tier auto-pauses the project after ~7 days with no traffic; a DB connection error after a long quiet period likely means the project needs a manual resume from the Supabase dashboard.
- All Supabase feature usage (Broadcast/Presence/Postgres Changes/new columns) must fail gracefully (try/catch, no UI crash) if a table/column doesn't exist yet in a given environment.

### Game rules reference

Full game design spec (win/lose conditions, Boss AI wander/approach timing, screen content variants, UX flow, sharing) is in [docs/GAME_SPEC.md](docs/GAME_SPEC.md) — read it before making gameplay/balance changes, but ignore its §8 persistence model (superseded by Supabase, see above).

## Working notes from WORK_LOG.md

- When parallelizing verified changes (e.g. DB/algorithm fixes) against unverified/untested changes (e.g. mobile UX not yet confirmed on real devices) in the same session, split commits by confidence level: extract each concern onto a clean copy of HEAD (`git show HEAD:file > scratch`, apply one part at a time, diff to confirm no bleed-through), then commit separately — so verified work can ship to production without dragging along untested changes.
- [WORK_LOG.md](WORK_LOG.md) is the project's running status log across sessions — check it first when resuming work, and update it (trim stale sections rather than letting it grow unbounded) after major progress. It is also the current source of truth for pending/in-flight work (e.g. whether the latest schema.sql has actually been run on production) — CLAUDE.md only covers stable architecture, not day-to-day status.
- There is an unmerged `canvas-poc` branch exploring a canvas-based render for the distance rings (perf gain was negligible; not recommended to merge per WORK_LOG.md). Don't rediscover or redo this — check WORK_LOG.md's "Việc dở" section for current recommendation before touching ring rendering.
