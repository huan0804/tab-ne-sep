# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

"TAB: Né Sếp" — a Vietnamese-language browser mini-game (office comedy: switch between fake work/personal screens to avoid being caught by a wandering "Boss"). Single-page HTML games, no build step, no package manager, no test suite.

Production: `https://tab-ne-sep.vercel.app/play` (Vercel rewrites `/play` and `/play-3d` → `/game/TAB-Ne-Sep_v2-perspective.html`, `/play-2d` → `/game/TAB-Ne-Sep.html`, root `/` redirects to `/play`; see [vercel.json](vercel.json)).

## Commands

There is no build/lint/test tooling in this repo. Development loop is: edit the HTML file directly, open it in a browser (or push to Vercel, which auto-deploys on push to the connected branch).

- Local preview: open `game/TAB-Ne-Sep_v2-perspective.html` directly in a browser (`file://`) — Supabase-backed leaderboard/multiplayer/analytics will fail gracefully and the game falls back to solo mode with `localStorage`.
- Deploy: push to the git remote; Vercel builds automatically. **Always ask for confirmation before `git push`** — this is a standing rule for this repo, not just a one-off preference.
- DB schema changes: run [supabase/schema.sql](supabase/schema.sql) in the Supabase SQL editor. It is idempotent (`create table if not exists`, `create or replace function`, existence checks before adding to publications) — safe to re-run in full after edits.

## Architecture

### Three HTML variants, one actively maintained (v2-perspective)

- [game/TAB-Ne-Sep_v2-perspective.html](game/TAB-Ne-Sep_v2-perspective.html) — **current/production version** (served at `/play`, alias `/play-3d`). `UI_VARIANT = 'perspective'`: distance rings drawn in-scene with a real pinhole projection (`cameraDist`/`cameraFH`) — far rings compress, Boss/colleague desks shrink with depth. Gameplay is unchanged because `dist` is computed in real metres. Includes room multiplayer ("1 Sếp chung"), streak system, challenge links, mobile UX fixes, daily/weekly analytics. This is the only file that receives new features.
- [game/TAB-Ne-Sep.html](game/TAB-Ne-Sep.html) — previous production version with flat ellipse rings (served at `/play-2d`). Kept as fallback; shares no code with v2, so only port bug fixes (Boss algorithm fixes were applied to both), not new features, unless asked.
- [game/TAB-Ne-Sep_v1-radar.html](game/TAB-Ne-Sep_v1-radar.html) — original version with a separate corner radar HUD instead of in-scene rings. Kept only for bug fixes/icon/mobile parity — **do not port new features here** unless explicitly asked; it is intentionally behind.


The ellipse version (`TAB-Ne-Sep.html`) also randomizes each player's view per match (`pickViewAngle()`: `viewRatio` ∈ [1.4, 2.4] ring flatness + `viewRot` rotation of Boss/colleague positions; the first tutorial match keeps the original angle). This only changes rendering (`worldToScreenPx`); `dist` is view-invariant, so nothing needs syncing between clients in a room.

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
- `sanitize_player_name()` is applied server-side inside the player-writing RPCs, in addition to client-side `escapeHtml()`.
- **Security model (schema.sql mục 5, 2026-10).** Reads are public (leaderboard, rooms) but there is NO direct write path: anon has no INSERT/UPDATE/DELETE on any table (revoked + RLS), and `sessions`/`player_secrets`/`rate_limits` are not readable. All writes go through `security definer` RPCs. Because there is no Supabase Auth and `players.id` is public, ownership is proven with a per-player secret: the client keeps a 256-bit random `atd_playerSecret` in localStorage and sends it as `p_secret` on every write RPC (`ensure_player`, `submit_match_result`, `create_room`, `start_room_match`, `claim_room_host`); the server stores only its SHA-256 in `player_secrets` (first caller claims an id). Any new write RPC must call `player_auth()` and take `p_secret`. Rate limits (`rate_limit`/`rate_limit_ip`, IP from PostgREST headers, skipped if no IP) and input validation (date/week keys, heatmap JSON, durations) guard the analytics RPCs; scores are capped by real elapsed time (`play_time <= time since last submit/visit + 5s`) and streaks are clamped server-side. Old RPC signatures were dropped, so the client and schema.sql must be deployed together (push → Vercel, then run schema.sql promptly).
- **Untrusted network data.** Anything received over Realtime Broadcast/Presence (player_state, boss_state, match_start, player_finished, replay_request) can be forged by anyone who knows the room code — there is no auth at that layer. Always pass it through the `sanitize*`/`isSafeId`/`remote*` helpers in the game script before use; never put remote strings into `innerHTML` or CSS selectors. (A real XSS via `player_state.workData` was fixed this way.)
- **Deploy surface.** [vercel.json](vercel.json) sets CSP/frame/nosniff/referrer/permissions headers; the CSP keeps `'unsafe-inline'` for scripts/styles because the game is single-file inline, so the supabase-js CDN tag is pinned to an exact version with SRI (update the `integrity` hash when bumping it). [.vercelignore](.vercelignore) keeps schema.sql, docs, *.md, `.claude/` and the old radar variant off the public domain. Known residual risk: Realtime channels are unauthenticated, so a griefer who knows a room code can forge host messages (cannot run code or touch scores).

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
