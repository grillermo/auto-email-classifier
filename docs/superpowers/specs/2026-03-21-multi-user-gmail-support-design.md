# Multi-User & Multi-Gmail Account Support

**Date:** 2026-03-21
**Status:** Approved

## Overview

Extend the auto-email-classifier Rails app from a single-user, file-based OAuth setup to a multi-user system where each user can connect multiple Gmail accounts. Authentication uses Devise with passwordless magic links delivered via ntfy. The mail listener is migrated from a standalone script into a solid_queue recurring ActiveJob.

---

## Section 1: Authentication, User & NtfyChannel Models

### Prerequisites

Before any authentication work:

1. **Enable ActionMailer** — uncomment `require "action_mailer/railtie"` in `config/application.rb` (currently commented out). Devise's mailer system requires it.
2. **Add gems** to Gemfile: `devise (~> 4.9)`, `devise-passwordless (~> 0.2)`
3. **Generate encryption keys** — run `rails db:encryption:init` and commit the updated `credentials.yml.enc`

### ActiveRecord Encryption Setup

Rails 8.1 built-in encryption requires three keys in `credentials.yml.enc` (generated via `rails db:encryption:init`):

```yaml
active_record_encryption:
  primary_key: ...
  deterministic_key: ...
  key_derivation_salt: ...
```

This is required before the `GmailAuthentication` model can encrypt tokens. The implementation step must include generating and committing these credentials.

### User Model

```
users: id (uuid), email (string, unique, not null), created_at, updated_at
```

Devise modules: `:magic_link_authenticatable`, `:trackable`, `:validatable`

No `password_digest` column. Passwordless only.

### NtfyChannel Model

```
ntfy_channels: id, user_id (fk → users, not null), channel (string, not null), server_url (string, default: "https://ntfy.sh"), created_at, updated_at
```

- `belongs_to :user` / `user has_one :ntfy_channel`
- `channel` maps to the current `NTFY_CHANNEL` env var
- `server_url` defaults to `https://ntfy.sh` (currently hardcoded)
- Seed migration reads `NTFY_CHANNEL` env var and stores it in the seed user's `ntfy_channel`

### Auth Flow

1. User visits `/users/sign_in`, enters email
2. Devise generates a signed magic link token (15-minute TTL)
3. Custom Devise mailer override: instead of SMTP email, posts the magic link to the user's `ntfy_channel` via HTTP (same ntfy HTTP client already used in the app)
4. User taps the ntfy push notification → magic link → session created

**Devise mailer override:** Create `app/mailers/users/magic_link_mailer.rb` subclassing `Devise::Mailer`. Override the `magic_link` method (the method `devise-passwordless` calls to deliver the link). Instead of calling `super` (which sends email), extract the magic link URL from the template variables and POST it to `user.ntfy_channel` via HTTP. Configure in `config/initializers/devise.rb`: `config.mailer = "Users::MagicLinkMailer"`.

**Token validation hook:** Override `Users::SessionsController < Devise::SessionsController` and call `Gmail::TokenValidator.call(user: current_user)` inside `after_sign_in_path_for(resource)` before returning the redirect path.

**Guard:** Before sending, check that the user has an `ntfy_channel` with a non-blank `channel`. If not, the mailer renders a flash error: "This account is not configured to receive notifications. Contact your administrator." (HTTP 422 on the sign-in form). This prevents silent lockout.

### User Creation

New users are created via rake task or rails console — no self-registration:

```ruby
User.create!(email: "...", ntfy_channel_attributes: { channel: "...", server_url: "https://ntfy.sh" })
```

A rake task `users:create` is provided:

```
rails users:create EMAIL=you@example.com NTFY_CHANNEL=your-topic NTFY_SERVER=https://ntfy.sh
```

Seed task creates the first user from env vars `ADMIN_EMAIL`, `NTFY_CHANNEL`, `NTFY_SERVER` (optional, defaults to `https://ntfy.sh`). The seed task raises with a clear message if `ADMIN_EMAIL` or `NTFY_CHANNEL` are not set — both are required.

---

## Section 2: GmailAuthentication Model & OAuth Refactor

### GmailAuthentication Model

```
gmail_authentications:
  id (uuid)
  user_id (fk → users, not null)
  email (string, not null)           -- the Gmail address
  access_token (text, encrypted)
  refresh_token (text, encrypted)
  token_expires_at (datetime)
  last_refreshed_at (datetime)
  status (string, default: "active") -- enum: active | needs_reauth
  scopes (string)
  created_at, updated_at
```

- `belongs_to :user` / `user has_many :gmail_authentications`
- Tokens encrypted at rest using Rails built-in `ActiveRecord::Encryption` (configured in `config/application.rb`)
- Existing token from `~/.credentials/gmail-modify-token.yaml` migrated into the seed user's `gmail_authentication` during data migration (see Section 3)

### OAuth Manager Refactor

Current `Gmail::OauthManager` reads from a YAML file and uses `USER_ID = "default"`.

New behaviour: initialized with a `GmailAuthentication` record:

```ruby
Gmail::OauthManager.new(gmail_authentication: gmail_auth_record)
```

- Reads `access_token`, `refresh_token`, `token_expires_at` from the DB record
- Calls `fetch_access_token!` to auto-refresh via `googleauth` gem (uses stored `refresh_token`)
- On success: updates `access_token`, `token_expires_at`, `last_refreshed_at` in DB
- On `Signet::AuthorizationError`: marks `status = needs_reauth`, sends ntfy notification to `gmail_auth_record.user.ntfy_channel`, raises so the caller can skip this account

### Adding New Gmail Accounts (Web OAuth Flow)

A web-based OAuth flow replaces the existing terminal interactive flow. The app already has `APP_BASE_URL` configured; the OAuth redirect URI will be `#{APP_BASE_URL}/gmail/oauth/callback`.

Flow:
1. Logged-in user clicks "Add Gmail account" in the web UI
2. App redirects to Google OAuth consent screen with `access_type=offline&prompt=consent` (ensures refresh token is always returned)
3. Google redirects to `/gmail/oauth/callback?code=...`
4. `Gmail::OauthCallbackController#create` exchanges the code for tokens, creates a `GmailAuthentication` record for `current_user`
5. User is redirected to the Gmail accounts list page

This replaces `OauthManager#perform_authentication` (the `$stdin` terminal flow) which is removed.

### Token Validation on Login

After the magic link is consumed and the session is created, a `Gmail::TokenValidator` service is called from `ApplicationController#after_sign_in`:

```ruby
Gmail::TokenValidator.call(user: current_user)
```

`Gmail::TokenValidator.call(user:)`:
- Iterates `user.gmail_authentications.where(status: :active)`
- For each, builds credentials and calls `fetch_access_token!`
- On success: updates `access_token`, `token_expires_at`, `last_refreshed_at`
- On `Signet::AuthorizationError`: sets `status = needs_reauth`
- Returns a list of accounts needing re-authorization

If any accounts are in `needs_reauth` state, a flash banner is shown: "Gmail account [email] needs re-authorization."

---

## Section 3: User-Scoped Data & Migrations

### Schema Changes

Add `user_id (uuid, fk → users)` to: `rules`, `rule_applications`, `auto_rule_events`

Drop the existing unique index on `rules.definition` (currently a GIN unique index). Replace with a composite unique index on `(user_id, definition)` to allow different users to have rules with identical definitions.

### Migration Order (separate migration files)

**Migration 1:** Create `users` table

**Migration 2:** Create `ntfy_channels` table

**Migration 3:** Create `gmail_authentications` table

**Migration 4:** Add nullable `user_id` to `rules`, `rule_applications`, `auto_rule_events`. Drop the existing global unique index on `rules.definition` (added by `20260310060100_add_unique_index_to_rules_definition.rb`). This must happen in Migration 4, before the data migration, to avoid conflicts with the composite index added in Migration 6.

**Migration 5 (data migration):**
- Reads `ADMIN_EMAIL` from env — raises `RuntimeError` with clear message if not set
- Reads `NTFY_CHANNEL` from env — raises `RuntimeError` with clear message if not set (required for auth to work)
- Creates seed user + ntfy_channel
- Assigns all existing `rules`, `rule_applications`, `auto_rule_events` to seed user via bulk UPDATE
- Migrates Gmail token file (`~/.credentials/gmail-modify-token.yaml`) to seed user's `gmail_authentication` — if file does not exist or is unreadable, logs a warning and skips (creates no `gmail_authentication` record; the seed user must then add a Gmail account via the web OAuth flow after first login)

**Migration 6:** Make `user_id` NOT NULL on `rules`, `rule_applications`, `auto_rule_events`. Add composite unique index on `rules (user_id, definition)`.

**Note on duplicate definitions:** Before adding the composite unique index, migration 6 must check for and deduplicate any existing `rules` rows with identical `definition` values (possible if the old global unique index was somehow bypassed). Deduplication strategy: keep the most recently updated record, delete the older duplicates. Add a log line if any duplicates are removed.

**Note on deploy order:** Migrations 4 → 5 → 6 must run as a single deploy step. Running migration 6 without first running migration 5 (data migration) will fail if any existing rows have `user_id = NULL`. The data migration guards against this by assigning all rows before migration 6 runs. This is safe as long as Rails runs all pending migrations sequentially (the default behaviour).

### Model Changes

`Rule`, `RuleApplication`, `AutoRuleEvent` all gain `belongs_to :user`.

`AutoRulesCreator` updated to accept and pass through `user:` parameter so new `Rule` and `AutoRuleEvent` records are created with `user_id` set:

```ruby
Rules::AutoRulesCreator.new(gmail_authentication: auth, user: auth.user).call
```

All controller and service queries scoped through the current user:

```ruby
current_user.rules.active
current_user.gmail_authentications.where(status: :active)
```

---

## Section 4: Mail Listener as Recurring ActiveJob

### Current State

`mail_listener/` is a standalone Ruby script (`mail_listener/listener.rb`) that runs in an infinite loop with a configurable poll interval. It lives outside the Rails app.

### New Design

Replace with a Rails ActiveJob: `MailListener::ProcessCycleJob`

`solid_queue` is already configured — no new infrastructure needed.

**Job behaviour:**

1. Loads all `GmailAuthentication` records where `status = active`
2. For each record, calls `CycleProcessor.new(gmail_authentication: auth).process!`
3. `CycleProcessor` constructor signature changes from `(dry_run:, gmail_client:)` to `(gmail_authentication:, dry_run: false)`. It builds its own `Gmail::Client` internally from the authentication credentials. `dry_run:` is retained for testing.
4. `AutoRulesCreator` constructor changes from `(gmail_client:, dry_run:)` to `(gmail_authentication:, dry_run: false)`. It derives `gmail_client` and `user` from the `gmail_authentication` record internally.
5. All `Rule` queries inside `CycleProcessor` (and `AutoRulesCreator`) scoped to `auth.user`:
   ```ruby
   auth.user.rules.active.ordered
   ```
5. Ntfy notifications for errors sent to `auth.user.ntfy_channel` (replacing `ENV["NTFY_CHANNEL"]` lookup)
6. If a user has no active `gmail_authentications`, the job silently skips them (no notification needed)

**Scheduling** via `config/recurring.yml` (solid_queue):

```yaml
mail_listener:
  class: MailListener::ProcessCycleJob
  schedule: every 1 minute
```

`solid_queue` is the sole scheduling mechanism — the job does **not** re-enqueue itself. `solid_queue` prevents overlapping runs of the same recurring job by default. The `GMAIL_POLL_INTERVAL_SECONDS` env var is no longer used for scheduling (the `recurring.yml` cron is the source of truth); it can be removed.

This replaces the standalone listener process entirely. The `mail_listener/` directory can be removed after the job is confirmed working in production.

### Token Handling in the Job

Before each cycle per `gmail_authentication`:

1. Build `Signet::OAuth2::Client` credentials from stored `access_token` + `refresh_token`
2. Call `fetch_access_token!` — auto-refreshes using `refresh_token` if access token is expired (`googleauth` gem handles this natively via `Signet::OAuth2::Client`)
3. On success: update `access_token`, `token_expires_at`, `last_refreshed_at` in DB
4. On `Signet::AuthorizationError` (refresh token revoked / consent removed):
   - Set `gmail_authentication.status = needs_reauth`
   - Send ntfy notification to `user.ntfy_channel`: "Gmail account [email] needs re-authorization"
   - Skip this account; continue with remaining accounts

The job only processes accounts where `status = active`. Auth failures are isolated — one bad account does not block others.

**Re-authorization flow:** When a `gmail_authentication` is in `needs_reauth` state, the user sees a "Re-authorize" button in the Gmail accounts UI. Clicking it starts the web OAuth flow. `Gmail::OauthCallbackController#create` checks for an existing `GmailAuthentication` record matching `current_user` + the returned Gmail address. If found, it updates `access_token`, `refresh_token`, `token_expires_at` and sets `status = :active`. If not found, it creates a new record. The job picks it up on the next cycle.

### Error Handling

- `solid_queue` handles job-level retry/error tracking for unexpected failures
- If a user has no `ntfy_channel` configured, ntfy notification is skipped (logged instead)

---

## Out of Scope

- Per-user `GMAIL_POLL_INTERVAL_SECONDS`, `GMAIL_PRIMARY_QUERY`, and `AUTO_RULE_*` config — these remain global env vars for now
- Admin UI for user management — users created via rake task / console only
- Multiple OAuth app credentials — `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` remain shared env vars across all users
