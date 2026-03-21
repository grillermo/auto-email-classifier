# Multi-User & Multi-Gmail Account Support

**Date:** 2026-03-21
**Status:** Approved

## Overview

Extend the auto-email-classifier Rails app from a single-user, file-based OAuth setup to a multi-user system where each user can connect multiple Gmail accounts. Authentication uses Devise with passwordless magic links delivered via ntfy. The mail listener is migrated from a standalone script into a solid_queue recurring ActiveJob.

---

## Section 1: Authentication, User & NtfyChannel Models

### Dependencies

Add to Gemfile:
- `devise (~> 4.9)`
- `devise-passwordless (~> 0.2)` — email magic link + OTP support

### User Model

```
users: id (uuid), email (string, unique, not null), created_at, updated_at
```

Devise modules: `:magic_link_authenticatable`, `:trackable`, `:validatable`

No `password_digest` column. Passwordless only.

### NtfyChannel Model

```
ntfy_channels: id, user_id (fk → users), channel (string), server_url (string, default: "https://ntfy.sh"), created_at, updated_at
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

### User Creation

New users are created via rake task or rails console — no self-registration:

```ruby
User.create!(email: "...", ntfy_channel_attributes: { channel: "...", server_url: "https://ntfy.sh" })
```

Seed task creates the first user from env vars `ADMIN_EMAIL`, `NTFY_CHANNEL`, `NTFY_SERVER` (optional, defaults to `https://ntfy.sh`).

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
- Existing token from `~/.credentials/gmail-modify-token.yaml` migrated into the seed user's `gmail_authentication` record at deploy time

### OAuth Manager Refactor

Current `Gmail::OauthManager` reads from a YAML file and uses `USER_ID = "default"`.

New behaviour: initialized with a `GmailAuthentication` record:

```ruby
Gmail::OauthManager.new(gmail_authentication: gmail_auth_record)
```

- Reads `access_token`, `refresh_token`, `token_expires_at` from the DB record
- Calls `fetch_access_token!` to auto-refresh via `googleauth` gem (uses stored `refresh_token`)
- On success: updates `access_token`, `token_expires_at`, `last_refreshed_at` in DB
- On `Signet::AuthorizationError`: marks `status = needs_reauth`, sends ntfy notification, raises so the caller can skip this account

### Token Validation on Login

After magic link is consumed and session is created, `ApplicationController` runs `Gmail::Authorization.validate_tokens!(current_user)` via `after_sign_in_path_for` or a `before_action`. This iterates the user's `gmail_authentications`, attempts a token refresh on any expiring/expired ones, and marks failures as `needs_reauth`. If any are in `needs_reauth` state, the user sees a banner prompting re-authorization.

---

## Section 3: User-Scoped Data & Migrations

### Schema Changes

Add `user_id (uuid, not null, fk → users)` to:
- `rules`
- `rule_applications`
- `auto_rule_events`

### Migration Order

1. Create `users` table
2. Create `ntfy_channels` table
3. Create `gmail_authentications` table
4. Add **nullable** `user_id` to `rules`, `rule_applications`, `auto_rule_events`
5. Data migration:
   - Create seed user from `ADMIN_EMAIL` env var
   - Assign all existing `rules`, `rule_applications`, `auto_rule_events` to seed user
   - Migrate file-based Gmail token (`~/.credentials/gmail-modify-token.yaml`) to seed user's `gmail_authentication`
   - Migrate `NTFY_CHANNEL` env var to seed user's `ntfy_channel`
6. Make `user_id` **NOT NULL** with FK constraint

### Model Changes

`Rule`, `RuleApplication`, `AutoRuleEvent` all gain `belongs_to :user`.

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
3. `CycleProcessor` refactored to accept a `gmail_authentication` record instead of reading from env/file
4. Ntfy notifications for errors sent to the record's `user.ntfy_channel` (replacing `ENV["NTFY_CHANNEL"]` lookup)

**Scheduling** via `config/recurring.yml` (solid_queue):

```yaml
mail_listener:
  class: MailListener::ProcessCycleJob
  schedule: every 1 minute
```

This replaces the standalone listener process entirely.

### Token Handling in the Job

Before each cycle per `gmail_authentication`:

1. Build `Signet::OAuth2::Client` credentials from stored `access_token` + `refresh_token`
2. Call `fetch_access_token!` — auto-refreshes using `refresh_token` if access token is expired (`googleauth` gem handles this natively)
3. On success: update `access_token`, `token_expires_at`, `last_refreshed_at` in DB
4. On `Signet::AuthorizationError` (refresh token revoked / consent removed):
   - Set `gmail_authentication.status = needs_reauth`
   - Send ntfy notification: "Gmail account [email] needs re-authorization"
   - Skip account until user re-authorizes via web UI

The job only processes accounts where `status = active`.

### Error Handling

- Auth failures per account are isolated — one bad account doesn't block others
- `solid_queue` handles job-level retry/error tracking for unexpected failures
- Standalone `mail_listener/` script can be removed once the job is confirmed working

---

## Out of Scope

- Per-user `GMAIL_POLL_INTERVAL_SECONDS`, `GMAIL_PRIMARY_QUERY`, and `AUTO_RULE_*` config — these remain global env vars for now
- Admin UI for user management — users created via console/rake task only
- Multiple OAuth app credentials — `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` remain shared env vars across all users
