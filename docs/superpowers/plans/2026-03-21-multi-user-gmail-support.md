# Multi-User & Multi-Gmail Account Support Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add multi-user support with Devise passwordless authentication (magic links via ntfy), per-user Gmail account connections, and a recurring solid_queue ActiveJob replacing the standalone mail listener.

**Architecture:** Incrementally extend the existing Rails 8.1 app — enable ActionMailer, add Devise + NtfyChannel/GmailAuthentication models, scope all data per user via incremental migrations, refactor OAuth to be DB-backed with auto-refresh, and replace the standalone listener with a recurring ActiveJob.

**Tech Stack:** Rails 8.1, PostgreSQL, Devise 4.9 + devise-passwordless 0.2, googleauth gem, solid_queue, Minitest

**Spec:** `docs/superpowers/specs/2026-03-21-multi-user-gmail-support-design.md`

All commands run from `rules_editor/` unless noted.

---

## Chunk 1: Prerequisites & Devise Authentication

### Task 1: Enable ActionMailer & Add Devise Gems

**Files:**
- Modify: `config/application.rb:10`
- Modify: `Gemfile`
- Modify: `.env` (project root) and `rules_editor/.env.example`

- [ ] **Step 1.1: Uncomment ActionMailer in config/application.rb**

Change line 10 from:
```ruby
# require "action_mailer/railtie"
```
to:
```ruby
require "action_mailer/railtie"
```

- [ ] **Step 1.2: Add Devise gems to Gemfile**

In `rules_editor/Gemfile`, add after the `gem "pg"` line:
```ruby
gem "devise", "~> 4.9"
gem "devise-passwordless", "~> 0.2"
```

- [ ] **Step 1.3: Install gems**

```bash
bundle install
```

Expected: Gemfile.lock updated with devise and devise-passwordless.

- [ ] **Step 1.4: Generate Devise initializer**

```bash
bundle exec rails generate devise:install
```

Expected: Creates `config/initializers/devise.rb` and `config/locales/devise.en.yml`. Ignore the printed instructions about mailer defaults — we override the mailer.

- [ ] **Step 1.5: Set ActionMailer default URL in config/environments/development.rb**

Add inside `Rails.application.configure do`:
```ruby
config.action_mailer.default_url_options = { host: "localhost", port: 3000 }
```

Also add to `config/environments/production.rb`:
```ruby
config.action_mailer.default_url_options = { host: URI.parse(ENV.fetch("APP_BASE_URL")).host }
```

- [ ] **Step 1.6: Add ActiveRecord Encryption keys to .env**

Run the following once to generate keys (stdout only, not written to files):
```bash
bundle exec rails db:encryption:init
```

Copy the three output values into the project root `.env`:
```
AR_ENCRYPTION_PRIMARY_KEY=<generated>
AR_ENCRYPTION_DETERMINISTIC_KEY=<generated>
AR_ENCRYPTION_KEY_DERIVATION_SALT=<generated>
```

Add placeholders to `rules_editor/.env.example`:
```
AR_ENCRYPTION_PRIMARY_KEY=
AR_ENCRYPTION_DETERMINISTIC_KEY=
AR_ENCRYPTION_KEY_DERIVATION_SALT=
```

- [ ] **Step 1.7: Configure encryption in application.rb**

In `config/application.rb`, inside `class Application < Rails::Application`:
```ruby
config.active_record.encryption.primary_key = ENV.fetch("AR_ENCRYPTION_PRIMARY_KEY", nil)
config.active_record.encryption.deterministic_key = ENV.fetch("AR_ENCRYPTION_DETERMINISTIC_KEY", nil)
config.active_record.encryption.key_derivation_salt = ENV.fetch("AR_ENCRYPTION_KEY_DERIVATION_SALT", nil)
```

- [ ] **Step 1.8: Commit**

```bash
git add config/application.rb Gemfile Gemfile.lock config/initializers/devise.rb config/locales/devise.en.yml config/environments/development.rb config/environments/production.rb rules_editor/.env.example
git commit -m "feat: enable ActionMailer, add Devise gems, configure AR encryption"
```

---

### Task 2: Create User Model with Devise Passwordless

**Files:**
- Create: `app/models/user.rb`
- Create: `db/migrate/TIMESTAMP_create_users.rb` (generated)
- Create: `test/models/user_test.rb`

- [ ] **Step 2.1: Generate Devise User model**

```bash
bundle exec rails generate devise User
```

Expected: Creates `app/models/user.rb` and `db/migrate/TIMESTAMP_devise_create_users.rb`.

- [ ] **Step 2.2: Update the generated User model**

Replace the contents of `app/models/user.rb` with:
```ruby
# frozen_string_literal: true

class User < ApplicationRecord
  devise :magic_link_authenticatable, :trackable, :validatable

  has_one :ntfy_channel, dependent: :destroy
  accepts_nested_attributes_for :ntfy_channel

  has_many :gmail_authentications, dependent: :destroy

  # Associations for rules/rule_applications/auto_rule_events are added in Task 11
  # (after the user_id columns are created in Chunk 3 migrations).
end
```

- [ ] **Step 2.3: Update the Devise migration to use UUID**

Open the generated migration file `db/migrate/TIMESTAMP_devise_create_users.rb`. Change the `create_table` call to:
```ruby
create_table :users, id: :uuid do |t|
  ## Magic link authenticatable
  t.string :email, null: false, default: ""

  ## Trackable
  t.integer  :sign_in_count, default: 0, null: false
  t.datetime :current_sign_in_at
  t.datetime :last_sign_in_at
  t.string   :current_sign_in_ip
  t.string   :last_sign_in_ip

  t.timestamps null: false
end

add_index :users, :email, unique: true
```

(Remove the `:database_authenticatable`, `:recoverable`, `:rememberable` sections — not needed for passwordless.)

- [ ] **Step 2.4: Write User model test**

Create `test/models/user_test.rb`:
```ruby
# frozen_string_literal: true

require "test_helper"

class UserTest < ActiveSupport::TestCase
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
end
```

- [ ] **Step 2.5: Run migration**

```bash
bundle exec rails db:migrate
```

Expected: `create_table(:users)` in output.

- [ ] **Step 2.6: Run tests**

```bash
bundle exec rails test test/models/user_test.rb
```

Expected: 3 runs, 0 failures.

- [ ] **Step 2.7: Commit**

```bash
git add app/models/user.rb db/migrate/ test/models/user_test.rb db/schema.rb
git commit -m "feat: add User model with Devise passwordless"
```

---

### Task 3: Create NtfyChannel Model

**Files:**
- Create: `app/models/ntfy_channel.rb`
- Create: `db/migrate/TIMESTAMP_create_ntfy_channels.rb`
- Create: `test/models/ntfy_channel_test.rb`

- [ ] **Step 3.1: Generate migration**

```bash
bundle exec rails generate migration CreateNtfyChannels user:references:uuid channel:string server_url:string
```

- [ ] **Step 3.2: Edit the migration**

Open `db/migrate/TIMESTAMP_create_ntfy_channels.rb` and update:
```ruby
class CreateNtfyChannels < ActiveRecord::Migration[8.1]
  def change
    create_table :ntfy_channels, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :channel, null: false
      t.string :server_url, null: false, default: "https://ntfy.sh"

      t.timestamps
    end
  end
end
```

- [ ] **Step 3.3: Create NtfyChannel model**

Create `app/models/ntfy_channel.rb`:
```ruby
# frozen_string_literal: true

class NtfyChannel < ApplicationRecord
  belongs_to :user

  validates :channel, presence: true
  validates :server_url, presence: true

  def notification_url
    "#{server_url}/#{channel}"
  end
end
```

- [ ] **Step 3.4: Write NtfyChannel model test**

Create `test/models/ntfy_channel_test.rb`:
```ruby
# frozen_string_literal: true

require "test_helper"

class NtfyChannelTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "test@example.com")
  end

  test "valid with channel and user" do
    ntfy = NtfyChannel.new(user: @user, channel: "my-topic")
    assert ntfy.valid?
  end

  test "invalid without channel" do
    ntfy = NtfyChannel.new(user: @user, channel: "")
    assert_not ntfy.valid?
  end

  test "notification_url returns full ntfy URL" do
    ntfy = NtfyChannel.new(user: @user, channel: "my-topic", server_url: "https://ntfy.sh")
    assert_equal "https://ntfy.sh/my-topic", ntfy.notification_url
  end
end
```

- [ ] **Step 3.5: Run migration and tests**

```bash
bundle exec rails db:migrate
bundle exec rails test test/models/ntfy_channel_test.rb
```

Expected: 3 runs, 0 failures.

- [ ] **Step 3.6: Commit**

```bash
git add app/models/ntfy_channel.rb db/migrate/ test/models/ntfy_channel_test.rb db/schema.rb
git commit -m "feat: add NtfyChannel model"
```

---

### Task 4: Custom Magic Link Mailer (ntfy delivery)

**Files:**
- Create: `app/mailers/application_mailer.rb`
- Create: `app/mailers/users/magic_link_mailer.rb`
- Modify: `config/initializers/devise.rb`
- Create: `test/mailers/users/magic_link_mailer_test.rb`

- [ ] **Step 4.1: Create ApplicationMailer**

Create `app/mailers/application_mailer.rb`:
```ruby
# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: "noreply@auto-email-classifier.local"
  layout "mailer"
end
```

- [ ] **Step 4.2: Add NotConfiguredError to NtfyChannel**

Add inside the `NtfyChannel` class body in `app/models/ntfy_channel.rb`:
```ruby
class NotConfiguredError < StandardError; end
```

This must be done **before** creating the mailer that raises it.

- [ ] **Step 4.3: Create the ntfy magic link mailer**

Create `app/mailers/users/magic_link_mailer.rb`:
```ruby
# frozen_string_literal: true

module Users
  class MagicLinkMailer < Devise::Mailer
    # Called by devise-passwordless to deliver the magic link.
    # Instead of sending email, we POST the link to the user's ntfy channel.
    def magic_link(record, token, opts = {})
      @token = token
      @resource = record

      ntfy_channel = record.ntfy_channel
      unless ntfy_channel&.channel.present?
        raise NtfyChannel::NotConfiguredError,
              "User #{record.email} has no ntfy_channel configured"
      end

      magic_link_url = generate_magic_link_url(record, token)
      deliver_via_ntfy(ntfy_channel, magic_link_url)

      # Return a mail object with deliveries disabled — Devise expects a mail object back
      mail(to: record.email, subject: "Sign in link") do |format|
        format.text { render plain: "Sent via ntfy" }
      end.tap { |m| m.perform_deliveries = false }
    end

    private

    # devise-passwordless 0.2 generates the URL via the route helper.
    # The route is named `user_magic_link` (or `{resource_name}_magic_link`).
    # We use the route helper with host from ActionMailer default_url_options.
    def generate_magic_link_url(record, token)
      resource_name = record.class.model_name.singular_route_key
      opts = Rails.application.config.action_mailer.default_url_options.merge(token: token)
      Rails.application.routes.url_helpers.public_send(
        "#{resource_name}_magic_link_url",
        opts
      )
    end

    def deliver_via_ntfy(ntfy_channel, magic_link_url)
      body = <<~BODY
        Sign in to Auto Email Classifier

        Tap or click this link to sign in (valid 15 minutes):
        #{magic_link_url}
      BODY

      HTTP.post(
        ntfy_channel.notification_url,
        body: body,
        headers: { "Title" => "Sign in link", "Priority" => "high" }
      )
    rescue StandardError => e
      Rails.logger.error("[MagicLinkMailer] ntfy delivery failed: #{e.class} #{e.message}")
      raise
    end
  end
end
```

- [ ] **Step 4.4: Configure Devise to use the custom mailer**

In `config/initializers/devise.rb`, find the mailer config section and set:
```ruby
config.mailer = "Users::MagicLinkMailer"
```

Also set the magic link expiry:
```ruby
# devise-passwordless config
config.passwordless_expire_after = 15.minutes
```

- [ ] **Step 4.5: Write mailer test**

Create `test/mailers/users/magic_link_mailer_test.rb`:
```ruby
# frozen_string_literal: true

require "test_helper"

module Users
  class MagicLinkMailerTest < ActionMailer::TestCase
    setup do
      @user = User.create!(email: "test@example.com")
    end

    test "raises NotConfiguredError when user has no ntfy_channel" do
      # ActionMailer methods must be called as class methods; .message returns the Mail::Message
      assert_raises(NtfyChannel::NotConfiguredError) do
        MagicLinkMailer.magic_link(@user, "fake-token").message
      end
    end

    test "posts to ntfy when ntfy_channel is configured" do
      @user.create_ntfy_channel!(channel: "test-topic")
      ntfy_called = false
      fake_response = Struct.new(:status).new(200)

      HTTP.stub(:post, ->(_url, **_opts) { ntfy_called = true; fake_response }) do
        MagicLinkMailer.magic_link(@user, "fake-token").message
      end

      assert ntfy_called
    end
  end
end
```

- [ ] **Step 4.6: Run tests**

```bash
bundle exec rails test test/mailers/users/magic_link_mailer_test.rb
```

Expected: 2 runs, 0 failures.

- [ ] **Step 4.7: Commit**

```bash
git add app/mailers/ config/initializers/devise.rb app/models/ntfy_channel.rb test/mailers/
git commit -m "feat: custom magic link mailer delivering via ntfy"
```

---

### Task 5: Devise Routes & Sessions Controller Override

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/users/sessions_controller.rb`
- Modify: `app/controllers/application_controller.rb`

- [ ] **Step 5.1: Add Devise routes**

Replace `config/routes.rb` with:
```ruby
Rails.application.routes.draw do
  # devise-passwordless 0.2 automatically mounts the magic link confirmation route
  # (GET /users/magic_link?token=...) when :magic_link_authenticatable is in the model.
  # This generates the `user_magic_link_url` route helper used by the mailer.
  # Handled by Devise::Passwordless::SessionsController#show internally.
  devise_for :users,
    controllers: { sessions: "users/sessions" },
    skip: [:registrations, :passwords, :confirmations, :unlocks, :omniauth_callbacks]

  devise_scope :user do
    get "users/sign_in", to: "users/sessions#new", as: :new_user_session
    post "users/sign_in", to: "users/sessions#create", as: :user_session
    delete "users/sign_out", to: "users/sessions#destroy", as: :destroy_user_session
  end

  # Gmail OAuth
  scope "/gmail/oauth" do
    get  "authorize", to: "gmail/oauth_callback#new",    as: :gmail_oauth_authorize
    get  "callback",  to: "gmail/oauth_callback#create", as: :gmail_oauth_callback
  end

  get "up" => "rails/health#show", as: :rails_health_check
  get "health/test_google_credentials", to: "health#test_google_credentials"

  post "rules/apply_all", to: "rules#apply_all"
  resources :rules, only: %i[index show edit update] do
    collection do
      patch :reorder
    end
  end

  root "rules#index"
end
```

- [ ] **Step 5.2: Create sessions controller**

Create `app/controllers/users/sessions_controller.rb`:
```ruby
# frozen_string_literal: true

module Users
  class SessionsController < Devise::SessionsController
    # after_sign_in_path_for override with Gmail::TokenValidator is added in Task 8,
    # after the TokenValidator service is implemented.
  end
end
```

- [ ] **Step 5.3: Add authentication to ApplicationController**

Replace `app/controllers/application_controller.rb`:
```ruby
# frozen_string_literal: true

class ApplicationController < ActionController::Base
  before_action :authenticate_user!

  # Only allow modern browsers supporting webp images, web push, badges, CSS nesting, and CSS :has.
  allow_browser versions: :modern
end
```

- [ ] **Step 5.4: Commit**

```bash
git add config/routes.rb app/controllers/users/ app/controllers/application_controller.rb
git commit -m "feat: Devise routes, sessions controller with token validation hook"
```

---

## Chunk 2: GmailAuthentication Model & OAuth Refactor

### Task 6: Create GmailAuthentication Model

**Files:**
- Create: `app/models/gmail_authentication.rb`
- Create: `db/migrate/TIMESTAMP_create_gmail_authentications.rb`
- Create: `test/models/gmail_authentication_test.rb`

- [ ] **Step 6.1: Generate migration**

```bash
bundle exec rails generate migration CreateGmailAuthentications
```

- [ ] **Step 6.2: Write the migration**

Edit the generated file:
```ruby
class CreateGmailAuthentications < ActiveRecord::Migration[8.1]
  def change
    create_table :gmail_authentications, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string  :email,               null: false
      t.text    :access_token
      t.text    :refresh_token
      t.datetime :token_expires_at
      t.datetime :last_refreshed_at
      t.string  :status,              null: false, default: "active"
      t.string  :scopes

      t.timestamps
    end

    add_index :gmail_authentications, [ :user_id, :email ], unique: true
  end
end
```

- [ ] **Step 6.3: Create the model**

Create `app/models/gmail_authentication.rb`:
```ruby
# frozen_string_literal: true

class GmailAuthentication < ApplicationRecord
  belongs_to :user

  encrypts :access_token
  encrypts :refresh_token

  enum :status, { active: "active", needs_reauth: "needs_reauth" }, prefix: true

  validates :email, presence: true, uniqueness: { scope: :user_id }
  validates :status, presence: true
end
```

- [ ] **Step 6.4: Write model tests**

Create `test/models/gmail_authentication_test.rb`:
```ruby
# frozen_string_literal: true

require "test_helper"

class GmailAuthenticationTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "test@example.com")
  end

  test "valid with required fields" do
    auth = GmailAuthentication.new(user: @user, email: "gmail@example.com")
    assert auth.valid?
  end

  test "invalid without email" do
    auth = GmailAuthentication.new(user: @user, email: "")
    assert_not auth.valid?
  end

  test "invalid with duplicate email for same user" do
    GmailAuthentication.create!(user: @user, email: "gmail@example.com")
    auth = GmailAuthentication.new(user: @user, email: "gmail@example.com")
    assert_not auth.valid?
  end

  test "same email allowed for different users" do
    other_user = User.create!(email: "other@example.com")
    GmailAuthentication.create!(user: @user, email: "shared@gmail.com")
    auth = GmailAuthentication.new(user: other_user, email: "shared@gmail.com")
    assert auth.valid?
  end

  test "status defaults to active" do
    auth = GmailAuthentication.create!(user: @user, email: "gmail@example.com")
    assert auth.status_active?
  end

  test "encrypts access_token and refresh_token" do
    auth = GmailAuthentication.create!(
      user: @user,
      email: "gmail@example.com",
      access_token: "secret-access",
      refresh_token: "secret-refresh"
    )
    # Raw DB value should not be the plain-text token
    raw = ActiveRecord::Base.connection.execute(
      "SELECT access_token FROM gmail_authentications WHERE id = '#{auth.id}'"
    ).first["access_token"]
    assert_not_equal "secret-access", raw
    # Model returns decrypted value
    assert_equal "secret-access", auth.reload.access_token
  end
end
```

- [ ] **Step 6.5: Run migration and tests**

```bash
bundle exec rails db:migrate
bundle exec rails test test/models/gmail_authentication_test.rb
```

Expected: 5 runs, 0 failures.

- [ ] **Step 6.6: Commit**

```bash
git add app/models/gmail_authentication.rb db/migrate/ test/models/gmail_authentication_test.rb db/schema.rb
git commit -m "feat: add GmailAuthentication model with encrypted tokens"
```

---

### Task 7: Refactor Gmail::OauthManager to use GmailAuthentication

**Files:**
- Modify: `app/services/gmail/oauth_manager.rb`
- Create: `test/services/gmail/oauth_manager_test.rb`

- [ ] **Step 7.1: Write failing tests first**

Create `test/services/gmail/oauth_manager_test.rb`:
```ruby
# frozen_string_literal: true

require "test_helper"

module Gmail
  class OauthManagerTest < ActiveSupport::TestCase
    setup do
      @user = User.create!(email: "test@example.com")
      @auth = GmailAuthentication.create!(
        user: @user,
        email: "gmail@example.com",
        access_token: "old-access",
        refresh_token: "valid-refresh",
        token_expires_at: 1.hour.from_now
      )
    end

    test "ensure_credentials! returns credentials when token is valid" do
      mock_credentials = Minitest::Mock.new
      mock_credentials.expect(:fetch_access_token!, nil)
      mock_credentials.expect(:access_token, "new-access")
      mock_credentials.expect(:expires_at, 2.hours.from_now)

      OauthManager.stub_any_instance(:build_credentials, mock_credentials) do
        manager = OauthManager.new(gmail_authentication: @auth)
        result = manager.ensure_credentials!
        assert_equal mock_credentials, result
      end

      @auth.reload
      assert_equal "new-access", @auth.access_token
    end

    test "ensure_credentials! marks needs_reauth on AuthorizationError" do
      mock_credentials = Minitest::Mock.new
      mock_credentials.expect(:fetch_access_token!, nil) { raise Signet::AuthorizationError.new("revoked") }

      OauthManager.stub_any_instance(:build_credentials, mock_credentials) do
        manager = OauthManager.new(gmail_authentication: @auth)
        assert_raises(Signet::AuthorizationError) { manager.ensure_credentials! }
      end

      assert @auth.reload.status_needs_reauth?
    end

    test "ensure_credentials! sends ntfy notification on auth error when channel configured" do
      @user.create_ntfy_channel!(channel: "test-topic")
      mock_credentials = Minitest::Mock.new
      mock_credentials.expect(:fetch_access_token!, nil) { raise Signet::AuthorizationError.new("revoked") }

      ntfy_called = false
      HTTP.stub(:post, ->(_url, **_opts) { ntfy_called = true; Struct.new(:status).new(200) }) do
        OauthManager.stub_any_instance(:build_credentials, mock_credentials) do
          manager = OauthManager.new(gmail_authentication: @auth)
          assert_raises(Signet::AuthorizationError) { manager.ensure_credentials! }
        end
      end

      assert ntfy_called
    end
  end
end
```

- [ ] **Step 7.2: Run tests to confirm they fail**

```bash
bundle exec rails test test/services/gmail/oauth_manager_test.rb
```

Expected: 3 errors (OauthManager doesn't accept gmail_authentication yet).

- [ ] **Step 7.3: Rewrite Gmail::OauthManager**

Replace `app/services/gmail/oauth_manager.rb`:
```ruby
# frozen_string_literal: true

module Gmail
  class OauthManager
    SCOPE = Gmail::Authorization::SCOPE

    def initialize(
      gmail_authentication:,
      client_id: ENV["GOOGLE_CLIENT_ID"],
      client_secret: ENV["GOOGLE_CLIENT_SECRET"]
    )
      @gmail_authentication = gmail_authentication
      @client_id = client_id
      @client_secret = client_secret
    end

    def ensure_credentials!
      credentials = build_credentials
      credentials.fetch_access_token!

      gmail_authentication.update!(
        access_token: credentials.access_token,
        token_expires_at: credentials.expires_at,
        last_refreshed_at: Time.current
      )

      credentials
    rescue Signet::AuthorizationError => e
      gmail_authentication.update!(status: :needs_reauth)
      send_reauth_ntfy_notification
      raise
    end

    private

    attr_reader :gmail_authentication, :client_id, :client_secret

    def build_credentials
      Google::Auth::UserRefreshCredentials.new(
        client_id: client_id,
        client_secret: client_secret,
        scope: SCOPE,
        access_token: gmail_authentication.access_token,
        refresh_token: gmail_authentication.refresh_token,
        expires_at: gmail_authentication.token_expires_at
      )
    end

    def send_reauth_ntfy_notification
      ntfy_channel = gmail_authentication.user.ntfy_channel
      return unless ntfy_channel&.channel.present?

      body = <<~BODY
        Gmail Re-Authorization Required

        The Gmail account #{gmail_authentication.email} needs to be re-authorized.
        Please sign in and click "Re-authorize" next to the account.
      BODY

      HTTP.post(ntfy_channel.notification_url, body: body)
    rescue StandardError => e
      Rails.logger.error("[OauthManager] ntfy notification failed: #{e.class} #{e.message}")
    end
  end
end
```

- [ ] **Step 7.4: Update Gmail::Client to support DB-backed credentials**

The existing `Client#initialize` is:
```ruby
def initialize(user_id: "me", token_path: Gmail::Authorization.default_token_path)
  @user_id = user_id
  @authorization = Gmail::Authorization.new(token_path: token_path)
  @service = Google::Apis::GmailV1::GmailService.new
  @service.client_options.application_name = APPLICATION_NAME
  @service.authorization = authorization.required_credentials(user_id: AUTHORIZATION_USER_ID)
  @label_name_to_id = nil
end
```

Add an alternative initializer path for DB-backed credentials. Add a private `initialize` that accepts a pre-built `credentials:` object, and a class factory method:

```ruby
def self.for_authentication(gmail_authentication)
  manager = Gmail::OauthManager.new(gmail_authentication: gmail_authentication)
  credentials = manager.ensure_credentials!
  allocate.tap { |c| c.send(:initialize_with_credentials, credentials) }
end
```

Add a private `initialize_with_credentials` method:
```ruby
def initialize_with_credentials(credentials)
  @user_id = "me"
  @service = Google::Apis::GmailV1::GmailService.new
  @service.client_options.application_name = APPLICATION_NAME
  @service.authorization = credentials
  @label_name_to_id = nil
end
```

The existing `initialize(user_id:, token_path:)` is kept unchanged — it is still used by `HealthController` and any code that hasn't been migrated. `CycleProcessor` and `AutoRulesCreator` will call `Client.for_authentication(gmail_authentication)` instead.

- [ ] **Step 7.5: Run tests**

```bash
bundle exec rails test test/services/gmail/oauth_manager_test.rb
```

Expected: 3 runs, 0 failures.

- [ ] **Step 7.6: Commit**

```bash
git add app/services/gmail/oauth_manager.rb app/services/gmail/client.rb test/services/gmail/oauth_manager_test.rb
git commit -m "feat: refactor OauthManager to use GmailAuthentication DB record"
```

---

### Task 8: Gmail::TokenValidator Service

**Files:**
- Create: `app/services/gmail/token_validator.rb`
- Create: `test/services/gmail/token_validator_test.rb`

- [ ] **Step 8.1: Write failing test**

Create `test/services/gmail/token_validator_test.rb`:
```ruby
# frozen_string_literal: true

require "test_helper"

module Gmail
  class TokenValidatorTest < ActiveSupport::TestCase
    setup do
      @user = User.create!(email: "test@example.com")
      @auth = GmailAuthentication.create!(
        user: @user,
        email: "gmail@example.com",
        access_token: "tok",
        refresh_token: "ref",
        token_expires_at: 1.hour.from_now
      )
    end

    test "refreshes active tokens and returns needs_reauth list" do
      mock_creds = Minitest::Mock.new
      mock_creds.expect(:fetch_access_token!, nil)
      mock_creds.expect(:access_token, "new-tok")
      mock_creds.expect(:expires_at, 2.hours.from_now)

      OauthManager.stub_any_instance(:build_credentials, mock_creds) do
        result = TokenValidator.call(user: @user)
        assert_empty result[:needs_reauth]
      end
    end

    test "returns needs_reauth when token refresh fails" do
      mock_creds = Minitest::Mock.new
      mock_creds.expect(:fetch_access_token!, nil) { raise Signet::AuthorizationError.new("revoked") }

      OauthManager.stub_any_instance(:build_credentials, mock_creds) do
        result = TokenValidator.call(user: @user)
        assert_includes result[:needs_reauth], @auth.email
      end
    end

    test "skips needs_reauth accounts" do
      @auth.update!(status: :needs_reauth)
      result = TokenValidator.call(user: @user)
      assert_empty result[:needs_reauth]
    end
  end
end
```

- [ ] **Step 8.2: Run test to confirm failure**

```bash
bundle exec rails test test/services/gmail/token_validator_test.rb
```

Expected: 3 errors.

- [ ] **Step 8.3: Implement TokenValidator**

Create `app/services/gmail/token_validator.rb`:
```ruby
# frozen_string_literal: true

module Gmail
  class TokenValidator
    def self.call(user:)
      new(user: user).call
    end

    def initialize(user:)
      @user = user
    end

    def call
      needs_reauth = []

      user.gmail_authentications.status_active.each do |auth|
        Gmail::OauthManager.new(gmail_authentication: auth).ensure_credentials!
      rescue Signet::AuthorizationError
        needs_reauth << auth.email
      end

      { needs_reauth: needs_reauth }
    end

    private

    attr_reader :user
  end
end
```

- [ ] **Step 8.4: Run tests**

```bash
bundle exec rails test test/services/gmail/token_validator_test.rb
```

Expected: 3 runs, 0 failures.

- [ ] **Step 8.5: Wire TokenValidator into Sessions Controller**

Now that `Gmail::TokenValidator` exists, update `app/controllers/users/sessions_controller.rb`:
```ruby
# frozen_string_literal: true

module Users
  class SessionsController < Devise::SessionsController
    protected

    def after_sign_in_path_for(resource)
      Gmail::TokenValidator.call(user: resource)
      super
    end
  end
end
```

- [ ] **Step 8.6: Commit**

```bash
git add app/services/gmail/token_validator.rb test/services/gmail/token_validator_test.rb app/controllers/users/sessions_controller.rb
git commit -m "feat: Gmail::TokenValidator service for login token refresh"
```

---

### Task 9: Gmail OAuth Web Callback Controller

**Files:**
- Create: `app/controllers/gmail/oauth_callback_controller.rb`
- Create: `test/integration/gmail/oauth_callback_test.rb`

- [ ] **Step 9.1: Create the controller**

Create `app/controllers/gmail/oauth_callback_controller.rb`:
```ruby
# frozen_string_literal: true

module Gmail
  class OauthCallbackController < ApplicationController
    OOB_URI = Gmail::Authorization::OOB_URI
    SCOPE   = Gmail::Authorization::SCOPE

    def new
      authorizer = build_authorizer
      url = authorizer.get_authorization_url(base_url: gmail_oauth_callback_url)
      redirect_to url, allow_other_host: true
    end

    def create
      code = params.require(:code)
      authorizer = build_authorizer

      credentials = authorizer.get_and_store_credentials_from_code(
        user_id: current_user.id.to_s,
        code: code,
        base_url: gmail_oauth_callback_url
      )

      gmail_email = fetch_gmail_email(credentials)

      auth = current_user.gmail_authentications.find_or_initialize_by(email: gmail_email)
      auth.update!(
        access_token: credentials.access_token,
        refresh_token: credentials.refresh_token,
        token_expires_at: credentials.expires_at,
        last_refreshed_at: Time.current,
        status: :active,
        scopes: SCOPE
      )

      redirect_to root_path, notice: "Gmail account #{gmail_email} connected."
    rescue ActionController::ParameterMissing, Google::Auth::AuthorizationError => e
      redirect_to root_path, alert: "Gmail authorization failed: #{e.message}"
    end

    private

    def build_authorizer
      client_id = Google::Auth::ClientId.new(
        ENV.fetch("GOOGLE_CLIENT_ID"),
        ENV.fetch("GOOGLE_CLIENT_SECRET")
      )
      token_store = Google::Auth::Stores::NullTokenStore.new
      Google::Auth::UserAuthorizer.new(client_id, SCOPE, token_store)
    end

    def fetch_gmail_email(credentials)
      service = Google::Apis::GmailV1::GmailService.new
      service.authorization = credentials
      service.get_user_profile("me").email_address
    end
  end
end
```

Note: `Google::Auth::Stores::NullTokenStore` — tokens are stored in the DB, not in a file. If `NullTokenStore` doesn't exist in the gem, use a minimal in-memory store:
```ruby
token_store = Class.new do
  def load(_id) = nil
  def store(_id, _token) = nil
  def delete(_id) = nil
end.new
```

- [ ] **Step 9.2: Commit**

```bash
git add app/controllers/gmail/oauth_callback_controller.rb
git commit -m "feat: Gmail OAuth web callback controller"
```

---

## Chunk 3: Data Migrations & User Scoping

### Task 10: Migrations to Add user_id to Existing Tables

**Files:**
- Create: `db/migrate/TIMESTAMP_add_user_id_to_rules_etc.rb`
- Create: `db/migrate/TIMESTAMP_seed_initial_user.rb`
- Create: `db/migrate/TIMESTAMP_make_user_id_not_null.rb`

- [ ] **Step 10.1: Generate Migration 4 — add nullable user_id**

```bash
bundle exec rails generate migration AddUserIdToRulesEtc
```

Edit the file:
```ruby
class AddUserIdToRulesEtc < ActiveRecord::Migration[8.1]
  def up
    # Drop existing global unique index on rules.definition
    remove_index :rules, name: "index_rules_on_definition", if_exists: true

    add_column :rules,             :user_id, :uuid, null: true
    add_column :rule_applications, :user_id, :uuid, null: true
    add_column :auto_rule_events,  :user_id, :uuid, null: true

    add_foreign_key :rules,             :users, column: :user_id
    add_foreign_key :rule_applications, :users, column: :user_id
    add_foreign_key :auto_rule_events,  :users, column: :user_id

    add_index :rules,             :user_id
    add_index :rule_applications, :user_id
    add_index :auto_rule_events,  :user_id
  end

  def down
    remove_column :rules,             :user_id
    remove_column :rule_applications, :user_id
    remove_column :auto_rule_events,  :user_id
    add_index :rules, :definition, unique: true, using: :gin, name: "index_rules_on_definition"
  end
end
```

- [ ] **Step 10.2: Generate Migration 5 — data migration**

```bash
bundle exec rails generate migration SeedInitialUser
```

Edit the file:
```ruby
class SeedInitialUser < ActiveRecord::Migration[8.1]
  def up
    admin_email   = ENV.fetch("ADMIN_EMAIL")  { raise "ADMIN_EMAIL env var required for migration" }
    ntfy_channel  = ENV.fetch("NTFY_CHANNEL") { raise "NTFY_CHANNEL env var required for migration" }
    ntfy_server   = ENV.fetch("NTFY_SERVER", "https://ntfy.sh")

    # Use parameterized queries to avoid SQL injection
    now = Time.current

    # Create seed user (idempotent)
    execute(
      sanitize_sql_array([
        "INSERT INTO users (id, email, sign_in_count, created_at, updated_at) VALUES (?, ?, 0, ?, ?) ON CONFLICT (email) DO NOTHING",
        SecureRandom.uuid, admin_email, now, now
      ])
    )

    # Fetch actual user id (handles ON CONFLICT DO NOTHING case)
    user_id = execute(
      sanitize_sql_array(["SELECT id FROM users WHERE email = ?", admin_email])
    ).first["id"]

    execute(
      sanitize_sql_array([
        "INSERT INTO ntfy_channels (id, user_id, channel, server_url, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?) ON CONFLICT DO NOTHING",
        SecureRandom.uuid, user_id, ntfy_channel, ntfy_server, now, now
      ])
    )

    # Assign all existing records to seed user (parameterized)
    execute(sanitize_sql_array(["UPDATE rules             SET user_id = ? WHERE user_id IS NULL", user_id]))
    execute(sanitize_sql_array(["UPDATE rule_applications SET user_id = ? WHERE user_id IS NULL", user_id]))
    execute(sanitize_sql_array(["UPDATE auto_rule_events  SET user_id = ? WHERE user_id IS NULL", user_id]))

    # Migrate file-based Gmail token if it exists
    token_path = ENV.fetch("GOOGLE_OAUTH_TOKEN_PATH",
                           File.join(Dir.home, ".credentials", "gmail-modify-token.yaml"))

    if File.exist?(token_path)
      require "yaml"
      token_data   = YAML.safe_load(File.read(token_path), permitted_classes: [Symbol])
      default_data = token_data["default"] || token_data

      execute(
        sanitize_sql_array([
          "INSERT INTO gmail_authentications (id, user_id, email, access_token, refresh_token, token_expires_at, status, scopes, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, 'active', ?, ?, ?)",
          SecureRandom.uuid, user_id, "migrated@unknown.com",
          default_data["access_token"], default_data["refresh_token"],
          (default_data["expiry_time"] || now + 1.hour),
          "https://www.googleapis.com/auth/gmail.modify",
          now, now
        ])
      )

      say "Migrated Gmail token from #{token_path}"
    else
      say "No Gmail token file found at #{token_path} — skipping. Add a Gmail account via web UI after first login."
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
```

- [ ] **Step 10.3: Generate Migration 6 — NOT NULL + composite index**

```bash
bundle exec rails generate migration MakeUserIdNotNull
```

Edit the file:
```ruby
class MakeUserIdNotNull < ActiveRecord::Migration[8.1]
  def up
    # Deduplicate rules with same definition before adding composite unique index
    execute <<~SQL
      DELETE FROM rules
      WHERE id NOT IN (
        SELECT DISTINCT ON (user_id, definition::text) id
        FROM rules
        ORDER BY user_id, definition::text, updated_at DESC
      )
    SQL

    change_column_null :rules,             :user_id, false
    change_column_null :rule_applications, :user_id, false
    change_column_null :auto_rule_events,  :user_id, false

    add_index :rules, [ :user_id, :definition ], unique: true, using: :gin,
              name: "index_rules_on_user_id_and_definition"
  end

  def down
    remove_index :rules, name: "index_rules_on_user_id_and_definition", if_exists: true
    change_column_null :rules,             :user_id, true
    change_column_null :rule_applications, :user_id, true
    change_column_null :auto_rule_events,  :user_id, true
  end
end
```

- [ ] **Step 10.4: Run all migrations**

```bash
bundle exec rails db:migrate
```

Expected: All three migrations complete without errors.

- [ ] **Step 10.5: Commit migrations**

```bash
git add db/migrate/ db/schema.rb
git commit -m "feat: migrations to add user scoping to rules, rule_applications, auto_rule_events"
```

---

### Task 11: Update Models for User Scoping

**Files:**
- Modify: `app/models/rule.rb`
- Modify: `app/models/rule_application.rb`
- Modify: `app/models/auto_rule_event.rb`

- [ ] **Step 11.1: Update Rule model**

In `app/models/rule.rb`:
- Add `belongs_to :user` after the class declaration
- Change `validates :definition, uniqueness: true` to:
  ```ruby
  validates :definition, uniqueness: { scope: :user_id }
  ```

- [ ] **Step 11.2: Update RuleApplication model**

In `app/models/rule_application.rb`, add:
```ruby
belongs_to :user
```

- [ ] **Step 11.3: Update AutoRuleEvent model**

In `app/models/auto_rule_event.rb`, add:
```ruby
belongs_to :user
```

- [ ] **Step 11.4: Run existing model tests to check for regressions**

```bash
bundle exec rails test test/models/
```

Expected: All model tests pass.

- [ ] **Step 11.5: Commit**

```bash
git add app/models/rule.rb app/models/rule_application.rb app/models/auto_rule_event.rb
git commit -m "feat: scope Rule, RuleApplication, AutoRuleEvent to user"
```

---

### Task 12: Update Controllers to Scope by current_user

**Files:**
- Modify: `app/controllers/rules_controller.rb`
- Modify: `app/controllers/health_controller.rb` (if present)

- [ ] **Step 12.1: Scope all Rule queries in RulesController**

In `app/controllers/rules_controller.rb`, change all `Rule.` queries to use `current_user.rules`:

```ruby
# index action:
active_rules   = current_user.rules.active.ordered.preload(:rule_applications)
inactive_rules = current_user.rules.where(active: false).ordered.preload(:rule_applications)

# set_rule (before_action):
@rule = current_user.rules.find(params[:id])
```

- [ ] **Step 12.2: Run existing controller/integration tests**

```bash
bundle exec rails test test/integration/
```

Expected: Tests pass (may require fixtures to have user_id — update as needed).

- [ ] **Step 12.3: Commit**

```bash
git add app/controllers/rules_controller.rb
git commit -m "feat: scope RulesController queries to current_user"
```

---

### Task 13: Seed File & User Creation Rake Task

**Files:**
- Modify: `db/seeds.rb`
- Create: `lib/tasks/users.rake`

- [ ] **Step 13.1: Update db/seeds.rb**

Replace `db/seeds.rb`:
```ruby
# Seeds are used for initial setup only.
# The data migration (SeedInitialUser) handles migrating existing records.
# This seed file can be used to create additional test users in development.

if Rails.env.development?
  email = ENV.fetch("ADMIN_EMAIL", "admin@example.com")
  ntfy  = ENV.fetch("NTFY_CHANNEL", "test-topic")

  unless User.exists?(email: email)
    User.create!(
      email: email,
      ntfy_channel_attributes: { channel: ntfy, server_url: "https://ntfy.sh" }
    )
    puts "Created dev user: #{email}"
  end
end
```

- [ ] **Step 13.2: Create users rake task**

Create `lib/tasks/users.rake`:
```ruby
namespace :users do
  desc "Create a new user. Required: EMAIL=you@example.com NTFY_CHANNEL=topic. Optional: NTFY_SERVER=https://ntfy.sh"
  task create: :environment do
    email       = ENV.fetch("EMAIL")        { abort "EMAIL is required" }
    ntfy_channel = ENV.fetch("NTFY_CHANNEL") { abort "NTFY_CHANNEL is required" }
    ntfy_server  = ENV.fetch("NTFY_SERVER", "https://ntfy.sh")

    user = User.create!(
      email: email,
      ntfy_channel_attributes: { channel: ntfy_channel, server_url: ntfy_server }
    )
    puts "Created user: #{user.email} (id: #{user.id})"
  end
end
```

- [ ] **Step 13.3: Test rake task**

```bash
bundle exec rails users:create EMAIL=test@example.com NTFY_CHANNEL=my-topic
```

Expected: "Created user: test@example.com (id: ...)".

- [ ] **Step 13.4: Commit**

```bash
git add db/seeds.rb lib/tasks/users.rake
git commit -m "feat: seed file and users:create rake task"
```

---

## Chunk 4: Mail Listener as Recurring ActiveJob

### Task 14: Refactor Rules::AutoRulesCreator

**Files:**
- Modify: `app/services/rules/auto_rules_creator.rb`
- Modify: `test/services/rules/auto_rule_creator_test.rb`

- [ ] **Step 14.1: Read the existing tests**

```bash
cat test/services/rules/auto_rule_creator_test.rb
```

Note which tests will need to change when we update the constructor.

- [ ] **Step 14.2: Update the constructor signature**

In `app/services/rules/auto_rules_creator.rb`, change:
```ruby
def initialize(gmail_client: Gmail::Client.new, dry_run: false)
  @gmail_client = gmail_client
  @dry_run = dry_run
end
```
to:
```ruby
def initialize(gmail_authentication:, dry_run: false)
  @gmail_authentication = gmail_authentication
  @gmail_client = Gmail::Client.for_authentication(gmail_authentication)
  @user = gmail_authentication.user
  @dry_run = dry_run
end
```

Add `attr_reader :gmail_authentication, :user` to the private section.

- [ ] **Step 14.3: Scope AutoRuleEvent and Rule queries to user**

Find all uses of `Rule` and `AutoRuleEvent` in `auto_rules_creator.rb` and scope them:
- `AutoRuleEvent.exists?(source_gmail_message_id: ...)` → `user.auto_rule_events.exists?(...)`
- `AutoRuleEvent.create!(...)` → `user.auto_rule_events.create!(...)`
- Any `Rule.create!` or `Rule.new` calls → `user.rules.create!` or `user.rules.new`

- [ ] **Step 14.4: Update ntfy notification to use user's ntfy_channel**

Find `send_ntfy_notification` and `channel = ENV.fetch("NTFY_CHANNEL")`:
```ruby
def send_ntfy_notification(rule:)
  ntfy_channel = user.ntfy_channel
  return unless ntfy_channel&.channel.present?

  # ... rest of notification code, using ntfy_channel.notification_url
  HTTP.post(ntfy_channel.notification_url, body: body)
end
```

Also update the dry_run log line that references `ENV.fetch('NTFY_CHANNEL', ...)`:
```ruby
log_dry_run("message=#{message_id} would send ntfy notification to channel=#{user.ntfy_channel&.channel.inspect}")
```

- [ ] **Step 14.5: Update existing AutoRulesCreator tests**

In `test/services/rules/auto_rule_creator_test.rb`, update all `AutoRulesCreator.new(gmail_client: ...)` calls to use `gmail_authentication:`. You'll need a fixture or factory for `GmailAuthentication`.

Add to the test `setup` block:
```ruby
@user = User.create!(email: "test@example.com")
@gmail_auth = GmailAuthentication.new(user: @user, email: "gmail@example.com")
@gmail_client = # existing mock client
# Stub Gmail::Client.for_authentication to return the existing mock
Gmail::Client.stub(:for_authentication, @gmail_client) do
  # tests that need the creator
end
```

Or restructure using `stub_any_instance` on `Gmail::Client`.

- [ ] **Step 14.6: Run AutoRulesCreator tests**

```bash
bundle exec rails test test/services/rules/auto_rule_creator_test.rb
```

Expected: All tests pass.

- [ ] **Step 14.7: Commit**

```bash
git add app/services/rules/auto_rules_creator.rb test/services/rules/auto_rule_creator_test.rb
git commit -m "feat: scope AutoRulesCreator to gmail_authentication and user"
```

---

### Task 15: Refactor MailListener::CycleProcessor

**Files:**
- Modify: `app/services/mail_listener/cycle_processor.rb`
- Modify: `test/services/mail_listener/cycle_processor_test.rb`

- [ ] **Step 15.1: Update the constructor signature**

In `app/services/mail_listener/cycle_processor.rb`, change:
```ruby
def initialize(dry_run: false, gmail_client: Gmail::Client.new)
  @dry_run = dry_run
  @gmail_client = gmail_client
end
```
to:
```ruby
def initialize(gmail_authentication:, dry_run: false)
  @gmail_authentication = gmail_authentication
  @user = gmail_authentication.user
  @gmail_client = Gmail::Client.for_authentication(gmail_authentication)
  @dry_run = dry_run
end
```

- [ ] **Step 15.2: Scope Rule queries to user**

Change:
```ruby
rules = Rule.active.ordered.to_a
```
to:
```ruby
rules = user.rules.active.ordered.to_a
```

- [ ] **Step 15.3: Scope AutoRulesCreator call**

Change:
```ruby
forward_result = Rules::AutoRulesCreator.new(gmail_client: gmail_client, dry_run: dry_run?).process!
```
to:
```ruby
forward_result = Rules::AutoRulesCreator.new(gmail_authentication: gmail_authentication, dry_run: dry_run?).process!
```

- [ ] **Step 15.4: Update ntfy notification to use user's ntfy_channel**

Change `send_auth_error_ntfy_notification`:
```ruby
def send_auth_error_ntfy_notification
  ntfy_channel = user.ntfy_channel
  return unless ntfy_channel&.channel.present?

  body = <<~BODY
    Gmail Authorization Failed.

    The automatic email listener cycle failed because it could not authorize with Google.
    Please sign in and re-authorize the Gmail account #{gmail_authentication.email}.
  BODY

  HTTP.post(ntfy_channel.notification_url, body: body)
rescue StandardError => e
  puts "[listener] failed to send ntfy notification: #{e.class} #{e.message}"
end
```

Add `attr_reader :gmail_authentication, :user` to private section.

- [ ] **Step 15.5: Update CycleProcessor tests**

In `test/services/mail_listener/cycle_processor_test.rb`, update setup to use `gmail_authentication:` and add fixtures.

- [ ] **Step 15.6: Run CycleProcessor tests**

```bash
bundle exec rails test test/services/mail_listener/cycle_processor_test.rb
```

Expected: All tests pass.

- [ ] **Step 15.7: Commit**

```bash
git add app/services/mail_listener/cycle_processor.rb test/services/mail_listener/cycle_processor_test.rb
git commit -m "feat: scope CycleProcessor to gmail_authentication and user"
```

---

### Task 16: MailListener::ProcessCycleJob

**Files:**
- Create: `app/jobs/mail_listener/process_cycle_job.rb`
- Create: `test/jobs/mail_listener/process_cycle_job_test.rb`
- Modify: `config/recurring.yml`

- [ ] **Step 16.1: Write failing test**

Create `test/jobs/mail_listener/process_cycle_job_test.rb`:
```ruby
# frozen_string_literal: true

require "test_helper"

module MailListener
  class ProcessCycleJobTest < ActiveJob::TestCase
    setup do
      @user = User.create!(email: "test@example.com")
      @auth = GmailAuthentication.create!(
        user: @user,
        email: "gmail@example.com",
        access_token: "tok",
        refresh_token: "ref",
        status: :active
      )
    end

    test "calls CycleProcessor for each active gmail_authentication" do
      processed = []

      CycleProcessor.stub(:new, ->(gmail_authentication:, **) {
        processed << gmail_authentication.email
        Minitest::Mock.new.tap { |m| m.expect(:process!, nil) }
      }) do
        ProcessCycleJob.new.perform
      end

      assert_includes processed, "gmail@example.com"
    end

    test "skips needs_reauth accounts" do
      @auth.update!(status: :needs_reauth)
      processed = []

      CycleProcessor.stub(:new, ->(**) { processed << true; Minitest::Mock.new.tap { |m| m.expect(:process!, nil) } }) do
        ProcessCycleJob.new.perform
      end

      assert_empty processed
    end

    test "continues processing remaining accounts when one raises" do
      second_auth = GmailAuthentication.create!(
        user: @user, email: "second@gmail.com",
        access_token: "tok", refresh_token: "ref", status: :active
      )
      processed = []
      call_count = 0

      CycleProcessor.stub(:new, ->(gmail_authentication:, **) {
        call_count += 1
        mock = Minitest::Mock.new
        if call_count == 1
          mock.expect(:process!, nil) { raise StandardError, "boom" }
        else
          mock.expect(:process!, nil)
          processed << gmail_authentication.email
        end
        mock
      }) do
        ProcessCycleJob.new.perform
      end

      assert_equal 1, processed.size
    end
  end
end
```

- [ ] **Step 16.2: Run tests to confirm failure**

```bash
bundle exec rails test test/jobs/mail_listener/process_cycle_job_test.rb
```

Expected: 3 errors (class doesn't exist).

- [ ] **Step 16.3: Implement the job**

Create `app/jobs/mail_listener/process_cycle_job.rb`:
```ruby
# frozen_string_literal: true

module MailListener
  class ProcessCycleJob < ApplicationJob
    queue_as :default

    def perform
      auths = GmailAuthentication.status_active.includes(user: :ntfy_channel)

      if auths.empty?
        Rails.logger.info("[ProcessCycleJob] no active gmail_authentications, skipping")
        return
      end

      Rails.logger.info("[ProcessCycleJob] processing #{auths.count} active account(s)")

      auths.each do |auth|
        begin
          CycleProcessor.new(gmail_authentication: auth).process!
        rescue StandardError => e
          Rails.logger.error("[ProcessCycleJob] account=#{auth.email} error=#{e.class} #{e.message}")
        end
      end
    end
  end
end
```

- [ ] **Step 16.4: Run tests**

```bash
bundle exec rails test test/jobs/mail_listener/process_cycle_job_test.rb
```

Expected: 3 runs, 0 failures.

- [ ] **Step 16.5: Configure recurring job**

In `config/recurring.yml`, add to the `production:` section (and add a `development:` section):
```yaml
development:
  mail_listener:
    class: MailListener::ProcessCycleJob
    schedule: every 1 minute

production:
  clear_solid_queue_finished_jobs:
    command: "SolidQueue::Job.clear_finished_in_batches(sleep_between_batches: 0.3)"
    schedule: every hour at minute 12
  mail_listener:
    class: MailListener::ProcessCycleJob
    schedule: every 1 minute
```

- [ ] **Step 16.6: Run full test suite**

```bash
bundle exec rails test
```

Expected: All tests pass, 0 failures.

- [ ] **Step 16.7: Commit**

```bash
git add app/jobs/mail_listener/process_cycle_job.rb test/jobs/ config/recurring.yml
git commit -m "feat: MailListener::ProcessCycleJob as recurring solid_queue job"
```

---

### Task 17: Remove Standalone Listener (Cleanup)

**Files:**
- Remove: `mail_listener/listener.rb` and `mail_listener/` directory (after job confirmed working)

- [ ] **Step 17.1: Verify the job works in development**

Start the Rails server and solid_queue:
```bash
bundle exec rails server
bundle exec rails solid_queue:start
```

Confirm `ProcessCycleJob` runs every minute in the solid_queue logs.

- [ ] **Step 17.2: Remove the standalone listener**

```bash
git rm -r mail_listener/
```

- [ ] **Step 17.3: Remove GMAIL_POLL_INTERVAL_SECONDS from .env.example**

The interval is now controlled by `recurring.yml`. Remove or comment out `GMAIL_POLL_INTERVAL_SECONDS` from `.env.example`.

- [ ] **Step 17.4: Final test run**

```bash
bundle exec rails test
```

Expected: All tests pass.

- [ ] **Step 17.5: Final commit**

```bash
git add -A
git commit -m "feat: remove standalone mail_listener script (replaced by ProcessCycleJob)"
```

---

## Summary of Files Changed

### New Files
| Path | Purpose |
|------|---------|
| `app/models/user.rb` | Devise User model |
| `app/models/ntfy_channel.rb` | Per-user ntfy config |
| `app/models/gmail_authentication.rb` | Per-user Gmail OAuth tokens |
| `app/mailers/users/magic_link_mailer.rb` | Delivers magic links via ntfy |
| `app/controllers/users/sessions_controller.rb` | Token validation on sign-in |
| `app/controllers/gmail/oauth_callback_controller.rb` | Web OAuth flow for Gmail |
| `app/services/gmail/token_validator.rb` | Refreshes tokens on login |
| `app/jobs/mail_listener/process_cycle_job.rb` | Recurring job for all accounts |
| `lib/tasks/users.rake` | `users:create` rake task |

### Modified Files
| Path | What Changes |
|------|-------------|
| `config/application.rb` | Enable ActionMailer, add AR encryption config |
| `Gemfile` | Add devise + devise-passwordless |
| `config/initializers/devise.rb` | Set custom mailer, magic link TTL |
| `config/routes.rb` | Devise routes + Gmail OAuth routes |
| `config/recurring.yml` | Add mail_listener recurring job |
| `app/controllers/application_controller.rb` | Add `authenticate_user!` |
| `app/controllers/rules_controller.rb` | Scope all queries to `current_user` |
| `app/models/rule.rb` | `belongs_to :user`, scoped uniqueness |
| `app/models/rule_application.rb` | `belongs_to :user` |
| `app/models/auto_rule_event.rb` | `belongs_to :user` |
| `app/services/gmail/oauth_manager.rb` | Accept `gmail_authentication:` |
| `app/services/gmail/client.rb` | Add `for_authentication` factory |
| `app/services/rules/auto_rules_creator.rb` | Accept `gmail_authentication:`, scope to user |
| `app/services/mail_listener/cycle_processor.rb` | Accept `gmail_authentication:`, scope to user |

### Deleted Files
| Path | Reason |
|------|--------|
| `mail_listener/` (entire directory) | Replaced by `ProcessCycleJob` |
