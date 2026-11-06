# agent-bar-custom

Customized fork of [agent-bar](https://github.com/chenjingdev/agent-bar): a local macOS menu bar app for monitoring **Codex and Claude Code subscription limits across multiple accounts**.

The app is called **Limi**. Its name is one setting, `app_name` in `scripts/build-app.sh` (or `AGENTBAR_APP_NAME`), and the code reads it from the app bundle, so renaming needs no code change. Internal names stay as they were — the bundle ID `dev.chenjing.agent-bar`, the `~/.agentbar` data folder, the `agent-bar` module and `AGENTBAR_` variables — so a rename keeps settings and accounts.

This fork follows upstream (currently through v0.1.0 and later) and only changes the look and feel. Build it from source (see [Build and install](#build-and-install)); the prebuilt app on upstream's Releases page has the original UI.

## Changes from Original

- Popover attaches directly under the menu bar item with no arrow, on the system menu material, sized to its content (closes on outside click or Escape)
- Popover uses native macOS system colors and semantic typography (`.headline`/`.subheadline`/`.callout`/`.caption`), native progress bars and dividers
- Limit cards are distinguished by SF Symbols (clock for 5-hour, calendar for weekly, cpu for model weeklies) instead of color
- Menu bar items drop the dark capsule background; text and tracks follow the light/dark menu bar appearance and re-render when it changes
- Bars and rings use the deeper account color on light menu bars; Capsule Fill keeps a self-contained dark pill for legibility
- Text Only shows a five-step gauge symbol (`gauge.with.dots.needle.X`) before each percentage

Upstream's features (multiple accounts, groups, styles, drag reordering, Settings) are unchanged and documented below.

## Accounts and menu bar

**Settings › Menu Bar** is the editor for every menu bar group. The **Menu bar preview** at the top draws the groups as they will appear; click one to edit it, or pick its tab under **Groups**. Groups use clickable tabs, styles use illustrated buttons, and limits use direct selection buttons; the selected option is highlighted. A group is one clickable menu bar item; its ordered usage lines can mix Claude and Codex accounts and limits freely.

Opening Settings from a menu bar group's popover selects that exact group, including when several groups use the same account. The selected group remains selected while switching settings tabs or reopening the window within the running app. Empty menu bar items open their own group's editor directly. Settings opens centered on the display under the pointer, in the area the menu bar and Dock leave free; a window that is already open stays where it is.

- **Add Group** creates another independent group, without a fixed group-count limit. **Show in menu bar** hides a group without deleting its configuration. **Delete Group…** in the group's … menu removes only that display group, never its accounts. Drag an Limi badge onto another badge, or drag the group buttons in Settings, to reorder without a modifier key. The app reuses its existing menu bar positions and saves the new group-to-position mapping. Native ⌘-drag remains available for positioning items among other apps.
- **Three fixed slots** show existing lines or a centered **+** in each empty slot. Clicking **+** adds an editable line in that slot, initially using the last account in the group (or the first available account) and its weekly limit. Each compact line keeps its drag handle, account with its provider mark, direct limit buttons, and remove button on one row; the provider's name is added to an account only when the account's name does not already say it. Dropping onto an occupied slot swaps the two lines. To put a line in another group, add it there and remove the old line. **Show name** puts the group's name once at its left as a common badge; the name is the badge text, so the two cannot drift apart. Older settings with separate badge text take it as the group name when it was shown, so the menu bar reads the same. Bar and gauge colors follow each account. The same account can appear in several lines or groups. Missing data remains `--` for the selected limit, never a substitute limit or a false zero.
- Each group independently chooses its style, common badge visibility, percentage visibility and **up to three usage lines in one column**. Full groups cannot receive another line once all three slots are occupied; there are no overflow columns. Multi Bar always shows its equal-thickness bars and optionally shows one large percentage for the line chosen in the group's **Percentage** menu, or none with **Hidden**. Dragging that line keeps the selection, and deleting it falls back to the first line.
- Four styles are available: **Multi Bar** (stacked bars with one full-size representative percentage), **Ring Gauge** (a high-contrast progress ring with a full-size percentage beside it), **Capsule Fill** (up to three capsules matching the Multi Bar width, stacked in one column), and **Text Only**. Text Only has no line limit and lays every percentage out horizontally in configured order, without labels. Remove values until three remain before switching an unlimited Text Only group to another style. Ring Gauge always edits, refreshes, and displays only the first configured usage line. Legacy Individual mode becomes None; legacy Both mode becomes Common. The old Name Badge style maps to Multi Bar. Changes appear immediately in the actual menu bar. Usage at 90% or more turns the gauge red.
- **Settings › Accounts** manages login, reconnect, deletion, and account names. Drag the handle beside an account to reorder the list; every usage-line account picker immediately uses that saved order without changing its selected account. All accounts can be moved. New accounts append to the list, and the order survives restart. Use a group’s Show switch or remove a usage line to control what is displayed and refreshed. **Add Account…** below the account list opens an agent picker populated from the supported providers. Click any account name to rename it. Every account has the same three menu actions: Rename, Reconnect, and Delete. Each account shows its provider mark and plan, the login email and organization (a personal organization named after the email is not repeated), and when its usage last refreshed. An account that needs sign-in offers Reconnect on its row, and one no visible group uses says it is not shown in the menu bar. Full details are also available in the rename sheet. Older rows that followed a CLI login require a separate Limi sign-in; their names and layout selections are preserved. Deleted accounts stay removed after restart. Automatic email names appear as provider names with an account number and can be replaced by a custom name. New accounts receive a distinct palette color when possible and are initially added to their own group.
- **Settings › General** controls the refresh interval and Open at Login, and shows the app version. Clicking a group opens a popover with one tab per account, even if that account has several lines. An empty group's `+` opens the Menu Bar editor. Reopening Limi opens Settings, including when every group is hidden.
- All three Settings tabs use the same titled sections, drawn like the system's grouped settings. The window fits each tab's content and scrolls only past the room its display allows; errors and warnings appear in one banner under the tab picker.
- **Editions.** `./scripts/build-app.sh` builds Limi Pro; `--edition free` builds the free edition, which registers one account and shows the menu bar editor read-only. The edition is compiled in, since the two ship through different channels, and Settings › General shows it. Both use the same app ID and data, so moving from Free to Pro keeps every account and layout; accounts already registered stay in Free even past its limit. In Free the locked features stay visible: Add Account… and the menu bar groups are disabled with a **PRO** badge, and the menu shows **Get Limi Pro…**. They open the purchase page given at build time (`AGENTBAR_PURCHASE_URL=https://… ./scripts/build-app.sh --edition free`); without one the link shows but waits. The free edition's icon wears a FREE ribbon; `./scripts/make-app-icons.sh` redraws both icons.
- The interface is English by default, whatever the Mac's language. **Settings › General › Language** switches it to Korean (한국어); **Restart Now** applies it everywhere at once and reopens Settings in the new language. The Korean text lives in `assets/ko.lproj/Localizable.strings`, which the build copies into the app. Text in the code is the English and also the key; new user-visible text needs its Korean line there, and a test checks every line keeps its placeholders.
- A non-blocking notice appears when Limi's combined width exceeds 40% of its display width; this is a heuristic, not a measurement of remaining menu bar space.
- **Every account is monitored independently** using its own Limi credential directory. A new installation starts with no accounts; use Add Account to sign in separately. Limi never imports or follows the login used by Claude, Codex, or another app. Legacy rows without an Limi credential show Sign-in required and are excluded from polling until reconnected.

Dragging accounts, groups, and usage lines lifts a translucent copy with a shadow. The destination is previewed before dropping; dropping outside the list returns the item to its original position. Account and group moves insert at the destination, while usage lines swap occupied slots or move into empty slots.

Existing account-based `display-v2.json` preferences remain readable. The first group edit saves explicit ordered layouts and first backs up the previous file as `display-before-layouts-<UUID>.json`. Account visibility, names and colors are retained.

For an original item-based `display-v1.json`, migration preserves every group (including hidden and empty groups), account order, exact selected limits, and each group's component toggles. Groups with more than three lines keep their first three visible; extra selections are preserved in hidden “saved lines” groups. The original file stays untouched. If v2 settings already exist, **Settings › General › Recovery › Restore Original Groups…** restores the original v1 layout while retaining current names and colors, and saves a `display-before-restore-<UUID>.json` backup first.

## Requirements

- macOS 14 or later; Swift 6.2 or later to build.
- `/usr/bin/python3` for isolated CLI process-group startup and cleanup.
- Official Codex and/or Claude Code CLI installed. Homebrew installations are preferred over user launch wrappers.
- A supported subscription login for every account to monitor. API keys and API billing usage are outside this app's scope.

The implementation was developed against Codex CLI 0.154.0 and Claude Code 2.1.263. Provider interfaces can change with CLI releases.

## How authentication and usage work

**Codex:** Limi launches the official `codex app-server` in a separate `CODEX_HOME` for each managed account. It uses managed ChatGPT OAuth login, `account/read`, and `account/rateLimits/read`. Managed accounts use the CLI's file credential storage in a private directory. Existing CLI launch wrappers and routing configuration are not modified.

**Claude:** A private per-login browser-opener helper captures the CLI's automatic OAuth URL before opening it in the selected browser. The URL is validated and immediately removed from disk. The CLI keeps ownership of its PKCE state, local callback, and initial token exchange. Limi launches `claude auth login --claudeai` with a separate `CLAUDE_CONFIG_DIR`. It verifies the JSON login status during login and uses that directory's OAuth credential to query Anthropic's usage endpoint. Usage reads require an explicit account directory and prefer its private credential file. Existing account-owned Keychain entries can be read without authorization dialogs. There is no fallback to the external CLI directory, inherited authentication environment, or shared default Keychain entry.

Expired Claude credentials owned by Limi are renewed with the existing refresh token before loading usage. Refreshes for the same credential file share one exchange, rotated tokens are saved atomically, and revoked credentials still require Reconnect. External CLI credentials are not renewed by Limi. No model prompts are sent to refresh or verify authentication.

The old shared Claude status-line bridge is not used by the multi-account reader because its samples do not identify their owning account. The optional legacy script remains in the repository but is not installed or reconfigured by this app.

Sign-in opens the usual default browser. For Codex, Limi adds `prompt=login` to show saved accounts and **Sign in with another account**, preserving the original encoded PKCE, state and callback parameters. Claude uses its official approval page; **Switch account** there changes the Claude website login as well. Limi never forces a website logout. Completing browser sign-in still writes only to the separate Limi credential directory.

**Use Private Window Instead** is available during sign-in if a separate browser session is needed. It uses an incognito window in a temporary profile in a supported Chromium browser (Chrome, Edge, Brave or Chromium), with [ASWebAuthenticationSession ephemeral browsing](https://developer.apple.com/documentation/authenticationservices/aswebauthenticationsession/prefersephemeralwebbrowsersession) as a fallback. Only an owned private session is closed on completion/cancellation; tabs in the usual browser remain under the user's control. Cancel in Limi to stop a normal-browser sign-in. Late private-window callbacks cannot cancel a later attempt.

The browser/account boundary follows the patterns reviewed in [Orca's Claude login session](https://github.com/stablyai/orca/blob/4aaa6c7fb48513e1e1e037eb648f0ab81826aeb3/src/main/claude-accounts/claude-login-session.ts) and [OpenCodex's ChatGPT OAuth flow](https://github.com/lidge-jun/opencodex/blob/7c625fc9755c9824653ab944190e243091a2c85c/src/oauth/chatgpt.ts). Like Orca, Claude launches explicitly set both `CLAUDE_CONFIG_DIR` and `CLAUDE_SECURESTORAGE_CONFIG_DIR` to the account-owned directory.

Completing a Claude connection saves its credential into the account's private file before reporting success. Limi reads it through `/usr/bin/security`, the tool Claude Code used to store it, so no Keychain dialog appears. Periodic usage refreshes never read the Keychain. If the credential cannot be read, Limi reports the connection failure instead of registering an account it cannot read. A reconnect is registered without another review when the account ID recorded by the sign-in matches the account being reconnected; otherwise the signed-in account is shown for review first.

## Data, refresh, and privacy

Account data lives under `~/.agentbar/multi-account-v1/`:

- `accounts.json`: versioned account metadata, representative selections, and pending cleanup records. No passwords or tokens.
- `display-v2.json`: account metadata and explicit groups with ordered account/limit lines, per-group styles, component toggles, visibility and row counts. Legacy v2 fields are retained for migration. No credentials. An original `display-v1.json` and layout backups may remain alongside it.
- `credentials/<UUID>/`: per-login CLI authentication/configuration directory. Its path remains fixed after login because Keychain storage may depend on it.
- `usage/<account UUID>/<credential UUID>/`: isolated usage cache and last-known-good snapshot.

Directories use mode `0700`; app-written files use `0600`. For managed Claude accounts, connecting copies the credential Claude Code saved in the Keychain into that account’s private `.credentials.json` once. Usage refreshes read and renew only this file, because the Keychain copy keeps the sign-in refresh token, which stops working after the first renewal. The file stays readable while the Mac is locked so refreshes continue. OAuth tokens stay in these private credential stores; they are never written to usage caches or app logs. Treat credential directories and local backups as private.

Provider detection checks only whether the official CLI executable is installed. Startup cleanup suppresses Keychain authorization UI. If an account's credential file is missing or can no longer be renewed, the account shows a sign-in-required state and retains available cached usage as stale. Routine identity checks read local account metadata without spawning Claude, and credentials are rechecked after each usage request to discard results from a changed login.

The existing refresh interval is preserved (60, 120, 300, or 600 seconds). Accounts unused by any visible group are excluded from both automatic and manual refresh. Legacy paused accounts stay paused until reenabled from a usage line. An account used by several groups is polled once per refresh. Selected limits keep polling even when they have no data so they can appear later. Showing an account again schedules its refresh while respecting retry cooldowns. Requests are serialized per provider. Changing the refresh interval applies immediately. Provider retry deadlines are preserved even if a response arrives after an account is hidden; manual refresh does not bypass a cooldown. Failures are isolated to the affected account.

Unknown usage is `--`, not `0%`. Old values retain their original timestamp and are marked stale. Existing global cache files are not imported into managed accounts. Legacy caches from externally signed-in CLI accounts are never read. Both usage providers and CLI launchers require an explicit account-owned directory.

No backend, telemetry, browser-cookie extraction, or session-log scanning is added. Authentication and usage requests go to the relevant provider through its CLI or usage endpoint.

## Build and install

```bash
swift test
./scripts/build-app.sh
```

To install, first quit the existing Limi, then run:

```bash
./scripts/build-app.sh --install
open ~/Applications/Limi.app
```

The installer copies the previous app, its preferences, and existing multi-account data to:

`~/Library/Application Support/AgentBar/Backups/<timestamp>/`

It verifies the staged app's signature before replacement and refuses to replace a running app. For stable macOS Keychain authorization across local rebuilds, the script uses `AGENTBAR_CODE_SIGN_IDENTITY` when set, otherwise a recognized local code-signing identity already installed on this Mac, with ad-hoc signing only as a fallback. The local bundle is not notarized for public distribution.

To roll back, quit Limi, restore `Limi.app` from the selected backup, and restore the corresponding Limi preferences if needed. Preserve the newer multi-account data separately before restoring its backup. Never restore over external `~/.codex`, `~/.claude`, or unrelated Keychain entries.

## Validation

`swift test` covers original-group migration and restoration backups, mixed-provider line order and missing data, per-group display options, duplicate-account popover routing, more than four groups, hidden-account refresh suspension/resumption, upstream preference migration, CLI process-tree cleanup, account storage and permissions, representative persistence, cache isolation, unknown-versus-zero values, credential mismatches, delayed-result rejection, process cancellation/timeouts, and SwiftUI rendering.

An explicit installed-CLI probe can exercise Codex OAuth startup and cancellation **without opening a browser or signing in**:

```bash
AGENTBAR_LIVE_AUTH_PROBE=1 swift test --filter isolatedCodexLoginCancellation
```

Real OAuth completion, multiple-account usage, and native UI interaction are separate manual acceptance checks. Passing unit tests or receiving an OAuth URL does not establish those results.

See [validation coverage and manual acceptance limits](docs/validation/multi-account/README.md).

## Credits

Original project by [chenjingdev](https://github.com/chenjingdev/agent-bar). Upstream documentation above is kept as-is.
