# Gmail Direct Auth Design

**Date:** 2026-05-28
**Status:** Approved

## Goal

Replace devise-passwordless magic-link sign-in with Google OAuth via `omniauth-google-oauth2`. Single click signs user in AND connects their Gmail account (gmail.modify scope). Multi-account add flow remains for secondary Gmail accounts post sign-in.

## Data Migration

1. Export all active rules to `db/seeds.rb` (one `Rule.create!` per rule, no user FK — caller supplies user after fresh sign-in).
2. Truncation migration: `TRUNCATE users, gmail_authentications, rules, rule_applications, auto_rule_events, ntfy_channels RESTART IDENTITY CASCADE`. Safe because app is pre-production.
3. Add `provider` (string) and `uid` (string) columns to `users`. Unique index on `[provider, uid]`.

## Dependencies

**Add gems:**
- `omniauth-google-oauth2` (~> 1.1)
- `omniauth-rails_csrf_protection` (~> 1.0)

**Remove gems:**
- `devise-passwordless`

## User Model

```ruby
devise :omniauthable, :trackable, :validatable,
       omniauth_providers: [:google_oauth2]
```

Add class method `find_or_create_from_google(auth)`:
- Primary lookup: `find_or_create_by(provider: auth.provider, uid: auth.uid)`
- On uid miss: fall back to `find_by(email: auth.info.email)` and backfill `provider`/`uid` (handles existing users)
- On create: set `email` from `auth.info.email`

## Routes

```ruby
devise_for :users,
  controllers: { omniauth_callbacks: "users/omniauth_callbacks" },
  skip: [:registrations, :passwords, :confirmations, :unlocks, :sessions]

devise_scope :user do
  get  "sign_in",  to: "devise/sessions#new",     as: :new_user_session
  delete "sign_out", to: "devise/sessions#destroy", as: :destroy_user_session
end
```

Remove magic_link routes and old `devise_scope` block.

## Devise Initializer

Remove `config.passwordless_login_within`.

Add:
```ruby
config.omniauth :google_oauth2,
  ENV.fetch("GOOGLE_CLIENT_ID"),
  ENV.fetch("GOOGLE_CLIENT_SECRET"),
  scope: "openid,email,profile,https://www.googleapis.com/auth/gmail.modify",
  access_type: "offline",
  prompt: "consent"
```

## OmniAuth Callbacks Controller

`app/controllers/users/omniauth_callbacks_controller.rb`:

```ruby
class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def google_oauth2
    auth = request.env["omniauth.auth"]
    user = User.find_or_create_from_google(auth)

    if user.persisted?
      GmailAuthentication.upsert_from_google(user: user, auth: auth)
      sign_in_and_redirect user, event: :authentication
      set_flash_message(:notice, :success, kind: "Google") if is_navigational_format?
    else
      session["devise.google_data"] = auth.except(:extra)
      redirect_to root_path, alert: "Sign in failed."
    end
  end

  def failure
    redirect_to root_path, alert: "Google sign-in failed: #{failure_message}"
  end
end
```

## GmailAuthentication.upsert_from_google

New class method:
- `find_or_initialize_by(user: user, email: auth.info.email)`
- Sets `access_token`, `refresh_token` (only if present — Google omits on repeat without prompt:consent), `token_expires_at`, `scopes`, `status: :active`
- Fetches and stores labels via Gmail API (logic extracted from `OauthCallbackController`)

## Sign-in View

Replace email form in `app/views/users/sessions/new.html.erb` with:
```erb
<%= button_to "Sign in with Google", user_google_oauth2_omniauth_authorize_path, method: :post %>
```

## Deletions

- `app/controllers/devise/passwordless/` (both controllers)
- `app/controllers/users/sessions_controller.rb`
- `app/mailers/users/devise_notifier.rb`
- `test/mailers/users/devise_notifier_test.rb`
- `test/integration/sign_in_test.rb`

## Tests

**Add:**
- `test/controllers/users/omniauth_callbacks_controller_test.rb`
  - Mock OmniAuth hash with valid Google data
  - Assert user created, GmailAuthentication created, session established
  - Assert existing user matched by uid
  - Assert existing user matched by email fallback (backfills provider/uid)
- `test/models/user_test.rb` additions
  - `find_or_create_from_google` — new user path
  - `find_or_create_from_google` — existing by uid
  - `find_or_create_from_google` — email fallback

## Out of Scope

- Multi-provider support (GitHub, etc.)
- Passwordless fallback
- Google Workspace domain restriction
