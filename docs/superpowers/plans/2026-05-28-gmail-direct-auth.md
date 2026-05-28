# Gmail Direct Auth Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace devise-passwordless magic-link sign-in with Google OAuth (omniauth-google-oauth2) so that one Google sign-in simultaneously authenticates the user and creates their GmailAuthentication record.

**Architecture:** Add `omniauth-google-oauth2` + `omniauth-rails_csrf_protection`, swap `User` from `:magic_link_authenticatable` to `:omniauthable`, create a new `Users::OmniauthCallbacksController` that finds-or-creates the user and upserts their `GmailAuthentication`. Delete all magic-link code.

**Tech Stack:** Rails 8.1, Devise 4.9, omniauth-google-oauth2 ~>1.1, omniauth-rails_csrf_protection ~>1.0, PostgreSQL, Minitest

---

## File Map

| Action | File |
|--------|------|
| Create | `tmp/export_rules.rb` — one-off rules export script |
| Modify | `db/seeds.rb` — generated active-rules seed |
| Modify | `Gemfile` — add omniauth gems, remove devise-passwordless |
| Delete | `app/controllers/devise/passwordless/magic_links_controller.rb` |
| Delete | `app/controllers/devise/passwordless/sessions_controller.rb` |
| Delete | `app/controllers/users/sessions_controller.rb` |
| Delete | `app/mailers/users/devise_notifier.rb` |
| Delete | `test/mailers/users/devise_notifier_test.rb` |
| Delete | `test/integration/sign_in_test.rb` |
| Create | `db/migrate/TIMESTAMP_add_provider_uid_to_users.rb` |
| Modify | `app/models/user.rb` — new devise config + `find_or_create_from_google` |
| Modify | `app/models/gmail_authentication.rb` — add `upsert_from_google` |
| Modify | `config/initializers/devise.rb` — remove passwordless, add omniauth |
| Modify | `config/routes.rb` — new devise_for + manual session routes |
| Create | `app/controllers/users/omniauth_callbacks_controller.rb` |
| Modify | `app/views/users/sessions/new.html.erb` — Google button |
| Modify | `test/models/user_test.rb` — add `find_or_create_from_google` cases |
| Create | `test/controllers/users/omniauth_callbacks_controller_test.rb` |

---

## Task 1: Export active rules to db/seeds.rb

**Run BEFORE any schema changes** — the script reads current data.

**Files:**
- Create: `tmp/export_rules.rb`
- Modify: `db/seeds.rb`

- [ ] **Step 1: Write the export script**

Create `tmp/export_rules.rb`:
```ruby
rules = Rule.active.ordered
lines = []
lines << "# Active rules exported #{Date.today} — run AFTER first Google sign-in"
lines << "user = User.first || raise(\"No user found. Sign in with Google first, then run bin/rails db:seed\")"
lines << ""
rules.each do |r|
  lines << "Rule.find_or_create_by!("
  lines << "  user: user,"
  lines << "  definition: #{r.definition.to_json}"
  lines << ") do |rule|"
  lines << "  rule.name = #{r.name.inspect}"
  lines << "  rule.priority = #{r.priority}"
  lines << "  rule.active = #{r.active}"
  lines << "end"
  lines << ""
end
File.write("db/seeds.rb", lines.join("\n"))
puts "Exported #{rules.count} rules to db/seeds.rb"
```

- [ ] **Step 2: Run the export**

```bash
bin/rails runner tmp/export_rules.rb
```

Expected: `Exported N rules to db/seeds.rb`

- [ ] **Step 3: Verify db/seeds.rb looks correct**

```bash
cat db/seeds.rb
```

Confirm each rule has name, priority, definition. Spot-check one entry looks like valid Ruby.

- [ ] **Step 4: Commit**

```bash
git add db/seeds.rb tmp/export_rules.rb
git commit -m "chore: export active rules to db/seeds.rb for post-migration restore"
```

---

## Task 2: Update Gemfile — add omniauth gems, remove devise-passwordless

**Files:**
- Modify: `Gemfile`
- Modify: `Gemfile.lock` (via bundle install)

- [ ] **Step 1: Edit Gemfile**

Find this line in `Gemfile`:
```ruby
gem "devise-passwordless", "~> 0.2"
```

Replace with:
```ruby
gem "omniauth-google-oauth2", "~> 1.1"
gem "omniauth-rails_csrf_protection", "~> 1.0"
```

- [ ] **Step 2: Install**

```bash
bundle install
```

Expected: Gemfile.lock updated, no errors.

- [ ] **Step 3: Confirm gems present**

```bash
bundle list | grep omniauth
```

Expected output includes both `omniauth-google-oauth2` and `omniauth-rails_csrf_protection`.

- [ ] **Step 4: Commit**

```bash
git add Gemfile Gemfile.lock
git commit -m "chore: swap devise-passwordless for omniauth-google-oauth2"
```

---

## Task 3: Delete all magic-link dead code

**Files (deleted):**
- `app/controllers/devise/passwordless/magic_links_controller.rb`
- `app/controllers/devise/passwordless/sessions_controller.rb`
- `app/controllers/users/sessions_controller.rb`
- `app/mailers/users/devise_notifier.rb`
- `test/mailers/users/devise_notifier_test.rb`
- `test/integration/sign_in_test.rb`

- [ ] **Step 1: Delete files**

```bash
rm app/controllers/devise/passwordless/magic_links_controller.rb
rm app/controllers/devise/passwordless/sessions_controller.rb
rm app/controllers/users/sessions_controller.rb
rm app/mailers/users/devise_notifier.rb
rm test/mailers/users/devise_notifier_test.rb
rm test/integration/sign_in_test.rb
```

- [ ] **Step 2: Remove empty passwordless dir if empty**

```bash
rmdir app/controllers/devise/passwordless 2>/dev/null; rmdir app/controllers/devise 2>/dev/null; true
```

- [ ] **Step 3: Confirm app still boots**

```bash
bin/rails runner "puts 'ok'"
```

Expected: `ok`. If it errors, a file reference is still pointing to deleted code — check the error and remove the reference.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore: delete devise-passwordless magic-link controllers, mailer, and tests"
```

---

## Task 4: Add provider/uid columns to users

**Files:**
- Create: `db/migrate/TIMESTAMP_add_provider_uid_to_users.rb`

- [ ] **Step 1: Generate migration**

```bash
bin/rails generate migration AddProviderUidToUsers provider:string uid:string
```

- [ ] **Step 2: Edit the migration to add partial unique index**

Open the generated file in `db/migrate/` (name starts with timestamp + `add_provider_uid_to_users`). Replace its contents with:

```ruby
class AddProviderUidToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :provider, :string
    add_column :users, :uid, :string
    add_index :users, [:provider, :uid],
      unique: true,
      where: "provider IS NOT NULL AND uid IS NOT NULL",
      name: "index_users_on_provider_and_uid"
  end
end
```

- [ ] **Step 3: Run migration**

```bash
bin/rails db:migrate
```

Expected: migration runs, schema.rb updated with `provider` and `uid` columns.

- [ ] **Step 4: Verify schema**

```bash
grep -A 5 "provider\|uid" db/schema.rb | head -20
```

Expected: both columns present in `create_table "users"`.

- [ ] **Step 5: Commit**

```bash
git add db/migrate/ db/schema.rb
git commit -m "feat: add provider and uid columns to users for Google OAuth identity"
```

---

## Task 5: Write failing User model tests for find_or_create_from_google

**Files:**
- Modify: `test/models/user_test.rb`

- [ ] **Step 1: Add require for OmniAuth and new tests**

Open `test/models/user_test.rb`. Replace entire file with:

```ruby
# frozen_string_literal: true

require "test_helper"
require "omniauth"

class UserTest < ActiveSupport::TestCase
  def google_auth(email: "test@gmail.com", uid: "google-uid-123")
    OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: uid,
      info: { email: email }
    )
  end

  test "valid with email" do
    user = User.new(email: "test@example.com")
    assert user.valid?
  end

  test "invalid without email" do
    user = User.new(email: "")
    assert_not user.valid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test "invalid with duplicate email" do
    User.create!(email: "dup@example.com")
    user = User.new(email: "dup@example.com")
    assert_not user.valid?
  end

  test "find_or_create_from_google creates new user with provider and uid" do
    assert_difference "User.count", 1 do
      user = User.find_or_create_from_google(google_auth)
      assert user.persisted?
      assert_equal "test@gmail.com", user.email
      assert_equal "google_oauth2", user.provider
      assert_equal "google-uid-123", user.uid
    end
  end

  test "find_or_create_from_google finds existing user by provider and uid" do
    existing = User.create!(email: "test@gmail.com", provider: "google_oauth2", uid: "google-uid-123")
    assert_no_difference "User.count" do
      user = User.find_or_create_from_google(google_auth)
      assert_equal existing.id, user.id
    end
  end

  test "find_or_create_from_google finds legacy user by email and backfills provider uid" do
    legacy = User.create!(email: "test@gmail.com")
    assert_nil legacy.provider
    assert_nil legacy.uid

    assert_no_difference "User.count" do
      user = User.find_or_create_from_google(google_auth(uid: "new-uid-456"))
      assert_equal legacy.id, user.id
    end

    legacy.reload
    assert_equal "google_oauth2", legacy.provider
    assert_equal "new-uid-456", legacy.uid
  end
end
```

- [ ] **Step 2: Run tests — expect failures**

```bash
bin/rails test test/models/user_test.rb
```

Expected: `find_or_create_from_google` tests fail with `NoMethodError: undefined method 'find_or_create_from_google'`. Existing 3 tests may also fail if `password_required?` changed — that's expected at this stage.

---

## Task 6: Update User model — new devise config and find_or_create_from_google

**Files:**
- Modify: `app/models/user.rb`

- [ ] **Step 1: Replace user model**

Write `app/models/user.rb`:

```ruby
# frozen_string_literal: true

class User < ApplicationRecord
  devise :omniauthable, :trackable, :validatable,
         omniauth_providers: [:google_oauth2]

  has_one :ntfy_channel, dependent: :destroy
  accepts_nested_attributes_for :ntfy_channel

  has_many :gmail_authentications, dependent: :destroy
  has_many :rules, dependent: :destroy
  has_many :rule_applications, dependent: :destroy
  has_many :auto_rule_events, dependent: :destroy

  def self.find_or_create_from_google(auth)
    find_by(provider: auth.provider, uid: auth.uid) ||
      find_and_backfill_legacy(auth) ||
      create_from_google(auth)
  end

  def password_required?
    false
  end

  private_class_method def self.find_and_backfill_legacy(auth)
    user = find_by(email: auth.info.email)
    return unless user

    user.update!(provider: auth.provider, uid: auth.uid)
    user
  end

  private_class_method def self.create_from_google(auth)
    create!(email: auth.info.email, provider: auth.provider, uid: auth.uid)
  end
end
```

- [ ] **Step 2: Run user model tests — expect all pass**

```bash
bin/rails test test/models/user_test.rb
```

Expected: 6 tests, 0 failures.

- [ ] **Step 3: Commit**

```bash
git add app/models/user.rb test/models/user_test.rb
git commit -m "feat: replace magic_link_authenticatable with omniauthable and add find_or_create_from_google"
```

---

## Task 7: Write failing GmailAuthentication test for upsert_from_google

**Files:**
- Modify: `test/models/gmail_authentication_test.rb`

- [ ] **Step 1: Add upsert test**

Open `test/models/gmail_authentication_test.rb`. Append these tests (keep existing tests, add below):

```ruby
require "omniauth"

class GmailAuthenticationTest < ActiveSupport::TestCase
  # ... existing tests above ...

  def google_auth(email: "user@gmail.com", uid: "g-uid-1", refresh_token: "ref-tok")
    OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: uid,
      info: { email: email },
      credentials: OmniAuth::AuthHash.new(
        token: "access-tok",
        refresh_token: refresh_token,
        expires_at: 1.hour.from_now.to_i
      )
    )
  end

  test "upsert_from_google creates new GmailAuthentication" do
    user = User.create!(email: "user@gmail.com", provider: "google_oauth2", uid: "g-uid-1")
    auth = google_auth

    stub_method(GmailAuthentication, :fetch_and_store_labels, nil) do
      assert_difference "GmailAuthentication.count", 1 do
        ga = GmailAuthentication.upsert_from_google(user: user, auth: auth)
        assert ga.persisted?
        assert_equal "user@gmail.com", ga.email
        assert_equal "access-tok", ga.access_token
        assert_equal "ref-tok", ga.refresh_token
        assert ga.status_active?
      end
    end
  end

  test "upsert_from_google updates existing GmailAuthentication with fresh tokens" do
    user = User.create!(email: "user@gmail.com", provider: "google_oauth2", uid: "g-uid-1")
    user.gmail_authentications.create!(
      email: "user@gmail.com",
      access_token: "old-access",
      refresh_token: "old-refresh"
    )

    auth = google_auth(refresh_token: "new-refresh")
    stub_method(GmailAuthentication, :fetch_and_store_labels, nil) do
      assert_no_difference "GmailAuthentication.count" do
        ga = GmailAuthentication.upsert_from_google(user: user, auth: auth)
        assert_equal "access-tok", ga.access_token
        assert_equal "new-refresh", ga.refresh_token
      end
    end
  end

  test "upsert_from_google does not overwrite refresh_token when omitted" do
    user = User.create!(email: "user@gmail.com", provider: "google_oauth2", uid: "g-uid-1")
    user.gmail_authentications.create!(
      email: "user@gmail.com",
      access_token: "old-access",
      refresh_token: "keep-this"
    )

    auth = google_auth(refresh_token: nil)
    stub_method(GmailAuthentication, :fetch_and_store_labels, nil) do
      ga = GmailAuthentication.upsert_from_google(user: user, auth: auth)
      assert_equal "keep-this", ga.refresh_token
    end
  end
end
```

- [ ] **Step 2: Run — expect failures**

```bash
bin/rails test test/models/gmail_authentication_test.rb
```

Expected: `upsert_from_google` tests fail with `NoMethodError`.

---

## Task 8: Add GmailAuthentication.upsert_from_google

**Files:**
- Modify: `app/models/gmail_authentication.rb`

- [ ] **Step 1: Update model**

Write `app/models/gmail_authentication.rb`:

```ruby
# frozen_string_literal: true

class GmailAuthentication < ApplicationRecord
  belongs_to :user

  encrypts :access_token
  encrypts :refresh_token

  enum :status, { active: "active", needs_reauth: "needs_reauth" }, prefix: true

  validates :email, presence: true, uniqueness: { scope: :user_id }
  validates :status, presence: true

  def self.upsert_from_google(user:, auth:)
    ga = user.gmail_authentications.find_or_initialize_by(email: auth.info.email)
    creds = auth.credentials

    ga.access_token = creds.token
    ga.refresh_token = creds.refresh_token if creds.refresh_token.present?
    ga.token_expires_at = Time.at(creds.expires_at)
    ga.scopes = Gmail::Authorization::SCOPE
    ga.status = :active
    ga.save!

    fetch_and_store_labels(ga, creds.token)
    ga
  end

  def self.fetch_and_store_labels(ga, access_token)
    google_creds = Google::Auth::UserRefreshCredentials.new(
      client_id: ENV["GOOGLE_CLIENT_ID"],
      client_secret: ENV["GOOGLE_CLIENT_SECRET"],
      scope: Gmail::Authorization::SCOPE,
      access_token: access_token
    )
    service = Google::Apis::GmailV1::GmailService.new
    service.authorization = google_creds
    response = service.list_user_labels("me")
    labels = Array(response.labels).map { |l| { "id" => l.id, "name" => l.name } }
    ga.update!(labels: labels)
  rescue StandardError => e
    Rails.logger.error("[GmailAuthentication] label fetch failed: #{e.class} #{e.message}")
  end
end
```

- [ ] **Step 2: Run GmailAuthentication tests — expect all pass**

```bash
bin/rails test test/models/gmail_authentication_test.rb
```

Expected: all tests pass including the 3 new upsert tests.

- [ ] **Step 3: Commit**

```bash
git add app/models/gmail_authentication.rb test/models/gmail_authentication_test.rb
git commit -m "feat: add GmailAuthentication.upsert_from_google for OAuth sign-in flow"
```

---

## Task 9: Write failing OmniAuth callback controller tests

**Files:**
- Create: `test/controllers/users/omniauth_callbacks_controller_test.rb`

- [ ] **Step 1: Create test directory and file**

```bash
mkdir -p test/controllers/users
```

Create `test/controllers/users/omniauth_callbacks_controller_test.rb`:

```ruby
# frozen_string_literal: true

require "test_helper"
require "omniauth"

class Users::OmniauthCallbacksControllerTest < ActionDispatch::IntegrationTest
  setup do
    OmniAuth.config.test_mode = true
  end

  teardown do
    Rails.application.env_config.delete("omniauth.auth")
    OmniAuth.config.test_mode = false
  end

  def set_google_auth(email: "user@gmail.com", uid: "g-uid-123", refresh_token: "ref-tok")
    Rails.application.env_config["omniauth.auth"] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: uid,
      info: { email: email },
      credentials: OmniAuth::AuthHash.new(
        token: "access-tok",
        refresh_token: refresh_token,
        expires_at: 1.hour.from_now.to_i
      )
    )
    Rails.application.env_config["devise.mapping"] = Devise.mappings[:user]
  end

  test "creates user and gmail_authentication on first Google sign-in" do
    set_google_auth
    stub_method(GmailAuthentication, :fetch_and_store_labels, nil) do
      assert_difference ["User.count", "GmailAuthentication.count"], 1 do
        get "/users/auth/google_oauth2/callback"
      end
    end
    assert_response :redirect
    user = User.find_by(email: "user@gmail.com")
    assert user.present?
    assert_equal "google_oauth2", user.provider
    assert_equal "g-uid-123", user.uid
    assert GmailAuthentication.exists?(user: user, email: "user@gmail.com")
  end

  test "finds existing user by uid on repeat sign-in, no new records" do
    user = User.create!(email: "user@gmail.com", provider: "google_oauth2", uid: "g-uid-123")
    user.gmail_authentications.create!(
      email: "user@gmail.com",
      access_token: "old-tok",
      refresh_token: "old-ref"
    )

    set_google_auth
    stub_method(GmailAuthentication, :fetch_and_store_labels, nil) do
      assert_no_difference ["User.count", "GmailAuthentication.count"] do
        get "/users/auth/google_oauth2/callback"
      end
    end
    assert_response :redirect
  end

  test "finds legacy user by email, backfills provider and uid" do
    legacy = User.create!(email: "user@gmail.com")
    legacy.gmail_authentications.create!(
      email: "user@gmail.com",
      access_token: "old-tok",
      refresh_token: "old-ref"
    )

    set_google_auth(uid: "brand-new-uid")
    stub_method(GmailAuthentication, :fetch_and_store_labels, nil) do
      assert_no_difference "User.count" do
        get "/users/auth/google_oauth2/callback"
      end
    end

    legacy.reload
    assert_equal "google_oauth2", legacy.provider
    assert_equal "brand-new-uid", legacy.uid
  end
end
```

- [ ] **Step 2: Run — expect failures**

```bash
bin/rails test test/controllers/users/omniauth_callbacks_controller_test.rb
```

Expected: fails with routing error or `uninitialized constant Users::OmniauthCallbacksController` — routes not yet configured.

---

## Task 10: Create OmniAuth callbacks controller

**Files:**
- Create: `app/controllers/users/omniauth_callbacks_controller.rb`

- [ ] **Step 1: Create the controller**

Write `app/controllers/users/omniauth_callbacks_controller.rb`:

```ruby
# frozen_string_literal: true

class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  include Users::PostSignInRedirect

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
  rescue => e
    Rails.logger.error("[OmniauthCallbacks] sign in failed: #{e.class} #{e.message}")
    redirect_to new_user_session_path, alert: "Sign in failed. Please try again."
  end

  def failure
    redirect_to new_user_session_path, alert: "Google sign-in failed: #{failure_message}"
  end
end
```

---

## Task 11: Update devise initializer and routes

**Files:**
- Modify: `config/initializers/devise.rb`
- Modify: `config/routes.rb`

- [ ] **Step 1: Update devise initializer**

In `config/initializers/devise.rb`, remove this line:
```ruby
config.passwordless_login_within = 15.minutes
```

Add before the final `end` of `Devise.setup do |config|`:
```ruby
  config.omniauth :google_oauth2,
    ENV.fetch("GOOGLE_CLIENT_ID"),
    ENV.fetch("GOOGLE_CLIENT_SECRET"),
    scope: "openid,email,profile,#{Gmail::Authorization::SCOPE}",
    access_type: "offline",
    prompt: "consent"
```

- [ ] **Step 2: Update routes**

Replace the entire contents of `config/routes.rb` with:

```ruby
Rails.application.routes.draw do
  devise_for :users,
    controllers: { omniauth_callbacks: "users/omniauth_callbacks" },
    skip: [:registrations, :passwords, :confirmations, :unlocks, :sessions]

  devise_scope :user do
    get  "sign_in",  to: "devise/sessions#new",     as: :new_user_session
    delete "sign_out", to: "devise/sessions#destroy", as: :destroy_user_session
  end

  resources :gmail_authentications, only: [:new]

  # Gmail OAuth — used for adding secondary accounts post sign-in
  scope "/gmail/oauth" do
    get  "authorize", to: "gmail/oauth_callback#new",    as: :gmail_oauth_authorize
    get  "callback",  to: "gmail/oauth_callback#create", as: :gmail_oauth_callback
  end

  get "privacy", to: "pages#privacy", as: :privacy
  get "terms-of-service", to: "pages#terms_of_service", as: :terms_of_service

  get "up" => "rails/health#show", as: :rails_health_check
  get "health/test_google_credentials", to: "health#test_google_credentials"
  get "health/oauth_debug", to: "health#oauth_debug"

  post "rules/apply_all", to: "rules#apply_all"
  resources :rules, only: %i[index edit update destroy] do
    collection do
      patch :reorder
    end
  end

  root "rules#index"
end
```

- [ ] **Step 3: Verify app boots and routes look correct**

```bash
bin/rails runner "puts 'ok'" && bin/rails routes | grep "google_oauth2\|sign_in\|sign_out"
```

Expected: `ok`, then route lines including `user_google_oauth2_omniauth_authorize` (POST) and `user_google_oauth2_omniauth_callback` (GET).

- [ ] **Step 4: Run controller tests — expect all pass**

```bash
bin/rails test test/controllers/users/omniauth_callbacks_controller_test.rb
```

Expected: 3 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/users/omniauth_callbacks_controller.rb config/initializers/devise.rb config/routes.rb
git commit -m "feat: wire up omniauth-google-oauth2 for sign-in"
```

---

## Task 12: Update sign-in view

**Files:**
- Modify: `app/views/users/sessions/new.html.erb`

- [ ] **Step 1: Replace with Google button**

Write `app/views/users/sessions/new.html.erb`:

```erb
<div class="max-w-md mx-auto mt-12">
  <div class="bg-surface-container-lowest border border-outline-variant p-8 rounded-2xl shadow-sm text-center">
    <h2 class="text-2xl font-bold text-on-surface mb-2 font-headline">Sign in</h2>
    <p class="text-on-surface-variant mb-8 text-sm">Sign in with your Google account to connect Gmail and manage your rules.</p>
    <%= button_to "Sign in with Google",
          user_google_oauth2_omniauth_authorize_path,
          method: :post,
          class: "w-full bg-primary hover:bg-primary-dim text-on-primary font-semibold py-3 px-4 rounded-full transition-colors duration-200 cursor-pointer" %>
  </div>
</div>
```

- [ ] **Step 2: Verify app renders sign-in page**

```bash
bin/rails runner "puts Rails.application.routes.recognize_path('/sign_in', method: :get).inspect"
```

Expected: `{controller: "devise/sessions", action: "new"}` — confirms route resolves.

- [ ] **Step 3: Commit**

```bash
git add app/views/users/sessions/new.html.erb
git commit -m "feat: replace magic-link sign-in form with Google OAuth button"
```

---

## Task 13: Run full test suite

- [ ] **Step 1: Run all tests**

```bash
bin/rails test
```

Expected: all tests pass. Common failures and fixes:

- **`Devise::MissingWarden`** — Devise initializer ordering issue. Ensure `require "devise"` is not being called twice.
- **`ActionView::Template::Error: undefined method 'user_magic_link_url'`** — a view still references old routes. Search: `grep -r "magic_link" app/views/` and remove the reference.
- **`NoMethodError: undefined method 'deliver_via_ntfy'`** — a test or code still references the deleted mailer. Search and remove.

- [ ] **Step 2: Fix any failures, then re-run**

```bash
bin/rails test
```

Expected: green.

- [ ] **Step 3: Commit fixes if any**

```bash
git add -A
git commit -m "fix: resolve test failures after magic-link removal"
```

---

## Task 14: Reset database and restore rules

This is a dev-environment one-time operation.

- [ ] **Step 1: Drop and recreate database**

```bash
bin/rails db:drop db:create db:migrate
```

Expected: clean DB with schema including `provider` and `uid` columns on users.

- [ ] **Step 2: Sign in via Google in dev browser**

Start dev server: `bin/dev`

Navigate to `http://localhost:3000`. You should be redirected to `/sign_in`. Click "Sign in with Google". Complete Google OAuth. You should land on the rules index.

- [ ] **Step 3: Restore rules from seeds**

```bash
bin/rails db:seed
```

Expected: `N` rules created for the first user.

- [ ] **Step 4: Verify rules appear in browser**

Navigate to `http://localhost:3000`. Rules should be visible.

- [ ] **Step 5: Final commit**

```bash
git add -A
git commit -m "chore: confirm gmail direct auth end-to-end working"
```
