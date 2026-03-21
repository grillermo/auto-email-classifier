# Minitest Full Coverage Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Achieve 100% line coverage of all backend Ruby logic (models, services, controllers), measured by SimpleCov.

**Architecture:** Minitest is already installed via Rails. We add SimpleCov for measurement, then write focused unit tests using inline fake objects (no mocking library needed) and integration tests using ActionDispatch::IntegrationTest. Gmail API calls are always stubbed — never real HTTP.

**Critical mocking rules (read before writing any test):**

1. **`Gmail::Client.new` must never be called in tests.** `Authorization#validate_environment` raises immediately when `GOOGLE_CLIENT_ID` is not set. Even when errors are caught gracefully, we still waste time and assert on error-path behaviour. Always inject a fake client.
2. **`GmailAffectedEmailsLoader` in controller tests:** The `show` action instantiates this loader with the default `gmail_client_factory`. Stub the entire loader class in controller tests that hit the `show` route.
3. **`OneOffApplier` in AutoRulesCreator:** `AutoRulesCreator#apply_rule` calls `OneOffApplier.new(rule: rule)` with no `gmail_client`, so it defaults to `Gmail::Client.new`. Stub `Rules::OneOffApplier` in any test that exercises the live path of `AutoRulesCreator`.
4. **`CycleProcessor` FakeGmailClient must be query-aware:** `CycleProcessor#process!` calls `AutoRulesCreator` (with the classify query) and `RuleEngine` (with the inbox query) using the same fake client. Return an empty list for classify queries so `AutoRulesCreator` does nothing and never triggers `apply_rule` → `OneOffApplier` → `Gmail::Client.new`.

**Tech Stack:** Rails 8.1, Minitest, SimpleCov, PostgreSQL, inline fake objects for Gmail client stubbing.

---

## Coverage gaps (what this plan adds)

| File | Gap |
|---|---|
| `app/models/rule.rb` | `next_priority`, `version_digest`, accessors, scopes, all `validate_definition` branches |
| `app/services/rules/matcher.rb` | `case_sensitive: true`, body field, any-mode all-fail |
| `app/services/rules/rule_engine.rb` | no-match path, multiple-rules stops at first, live `add_label` |
| `app/services/rules/action_executor.rb` | all 4 action types, dry vs live |
| `app/services/rules/definition_builder.rb` | all normalization paths |
| `app/services/rules/forwarded_content_parser.rb` | all parsing cases |
| `app/services/rules/one_off_applier.rb` | by_message_id, by_query, ArgumentError |
| `app/services/rules/matching_emails_loader.rb` | empty, dedup, truncation, Gmail fallback |
| `app/services/rules/auto_rules_creator.rb` | live run creates Rule + AutoRuleEvent, skip-already-processed, save failure |
| `app/services/mail_listener/cycle_processor.rb` | full process!, dry-run, error handling, auth error ntfy |
| `app/controllers/rules_controller.rb` | save_and_apply, apply failure path, index serialization |

---

## Chunk 1: SimpleCov setup + baseline

### Task 1: Add SimpleCov and measure baseline

**Files:**
- Modify: `rules_editor/Gemfile`
- Modify: `rules_editor/test/test_helper.rb`

All commands run from inside `rules_editor/`.

- [ ] **Step 1: Add simplecov to Gemfile**

In `rules_editor/Gemfile`, add to the `group :development, :test` block:

```ruby
group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "bundler-audit", require: false
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
  gem "simplecov", require: false   # ADD THIS LINE
end
```

- [ ] **Step 2: Install gem**

```bash
cd rules_editor && bundle install
```

Expected: `Bundle complete!` (simplecov installed)

- [ ] **Step 3: Configure SimpleCov in test_helper**

Edit `rules_editor/test/test_helper.rb` — add the SimpleCov require/start block as the very first lines, before any other require:

```ruby
require "simplecov"
SimpleCov.start "rails" do
  add_filter "/test/"
  add_filter "/config/"
  add_filter "/db/"
end

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)
    fixtures :all
  end
end
```

- [ ] **Step 4: Run test suite and check baseline**

```bash
cd rules_editor && bin/rails test 2>&1 | tail -5
```

Expected: All existing tests pass. `open coverage/index.html` will show current baseline (expect ~50-60%).

- [ ] **Step 5: Commit**

```bash
cd rules_editor && git add Gemfile Gemfile.lock test/test_helper.rb
git commit -m "Add SimpleCov for coverage tracking"
```

---

## Chunk 2: Model and Matcher gaps

### Task 2: Rule model gap tests

**Files:**
- Modify: `rules_editor/test/models/rule_test.rb`

- [ ] **Step 1: Read the current test file to understand existing tests**

Open `test/models/rule_test.rb` and append the following tests at the bottom (before the final `end`):

```ruby
  test "next_priority returns one more than the highest existing priority" do
    Rule.create!(name: "A", priority: 5, definition: valid_definition)
    Rule.create!(name: "B", priority: 10, definition: valid_definition(value: "b@"))
    assert_equal 11, Rule.next_priority
  end

  test "next_priority returns 1 when no rules exist" do
    assert_equal 1, Rule.next_priority
  end

  test "version_digest changes when updated_at changes" do
    rule = Rule.create!(name: "R", priority: 1, definition: valid_definition)
    digest_before = rule.version_digest
    rule.update!(name: "R updated")
    assert_not_equal digest_before, rule.version_digest
  end

  test "conditions returns array with indifferent access" do
    rule = Rule.new(definition: valid_definition)
    cond = rule.conditions.first
    assert_equal "sender", cond[:field]
    assert_equal "sender", cond["field"]
  end

  test "actions returns array with indifferent access" do
    rule = Rule.new(definition: valid_definition)
    action = rule.actions.first
    assert_equal "mark_read", action[:type]
    assert_equal "mark_read", action["type"]
  end

  test "match_mode returns all by default when missing from definition" do
    rule = Rule.new(definition: { "conditions" => [], "actions" => [] })
    assert_equal "all", rule.match_mode
  end

  test "active scope excludes inactive rules" do
    Rule.create!(name: "Active", priority: 1, active: true, definition: valid_definition)
    Rule.create!(name: "Inactive", priority: 2, active: false, definition: valid_definition(value: "b@"))
    assert_equal ["Active"], Rule.active.map(&:name)
  end

  test "ordered scope sorts by priority ascending" do
    Rule.create!(name: "Second", priority: 2, definition: valid_definition)
    Rule.create!(name: "First", priority: 1, definition: valid_definition(value: "b@"))
    assert_equal ["First", "Second"], Rule.ordered.map(&:name)
  end

  test "ensure_definition_hash coerces nil definition to empty hash" do
    rule = Rule.new(name: "R", priority: 1)
    rule.valid?  # triggers before_validation
    assert_equal({}, rule.definition)
  end

  test "invalid match_mode fails validation" do
    rule = Rule.new(name: "R", priority: 1, definition: valid_definition.merge("match_mode" => "invalid"))
    assert_not rule.valid?
    assert_includes rule.errors[:definition], "match_mode must be 'all' or 'any'"
  end

  test "condition with invalid field fails validation" do
    defn = valid_definition
    defn["conditions"] = [{ field: "invalid_field", operator: "contains", value: "x" }]
    rule = Rule.new(name: "R", priority: 1, definition: defn)
    assert_not rule.valid?
    assert_includes rule.errors[:definition], "condition field is invalid"
  end

  test "condition with invalid operator fails validation" do
    defn = valid_definition
    defn["conditions"] = [{ field: "sender", operator: "equals", value: "x" }]
    rule = Rule.new(name: "R", priority: 1, definition: defn)
    assert_not rule.valid?
    assert_includes rule.errors[:definition], "condition operator is invalid"
  end

  test "condition with blank value fails validation" do
    defn = valid_definition
    defn["conditions"] = [{ field: "sender", operator: "contains", value: "   " }]
    rule = Rule.new(name: "R", priority: 1, definition: defn)
    assert_not rule.valid?
    assert_includes rule.errors[:definition], "condition value cannot be blank"
  end

  test "action with invalid type fails validation" do
    defn = valid_definition
    defn["actions"] = [{ type: "teleport" }]
    rule = Rule.new(name: "R", priority: 1, definition: defn)
    assert_not rule.valid?
    assert_includes rule.errors[:definition], "action type is invalid"
  end

  test "add_label action without label fails validation" do
    defn = valid_definition
    defn["actions"] = [{ type: "add_label", label: "" }]
    rule = Rule.new(name: "R", priority: 1, definition: defn)
    assert_not rule.valid?
    assert_includes rule.errors[:definition], "label action requires a label"
  end

  test "remove_label action without label fails validation" do
    defn = valid_definition
    defn["actions"] = [{ type: "remove_label", label: "  " }]
    rule = Rule.new(name: "R", priority: 1, definition: defn)
    assert_not rule.valid?
    assert_includes rule.errors[:definition], "label action requires a label"
  end

  private

  def valid_definition(value: "billing@")
    {
      "match_mode" => "all",
      "conditions" => [{ "field" => "sender", "operator" => "contains", "value" => value }],
      "actions" => [{ "type" => "mark_read" }]
    }
  end
```

Note: if `valid_definition` is already defined in the file, rename it or merge the helper. Check the existing file first.

- [ ] **Step 2: Run only this test file**

```bash
cd rules_editor && bin/rails test test/models/rule_test.rb
```

Expected: All tests pass (including existing 4 + new ~15).

- [ ] **Step 3: Commit**

```bash
cd rules_editor && git add test/models/rule_test.rb
git commit -m "Add Rule model gap tests for full coverage"
```

---

### Task 3: Rules::Matcher gap tests

**Files:**
- Modify: `rules_editor/test/services/rules/matcher_test.rb`

Append to the existing test class (before the final `end`):

- [ ] **Step 1: Add missing test cases**

```ruby
  test "case_sensitive true requires exact case to match" do
    rule = Rule.new(
      name: "CS",
      priority: 1,
      definition: {
        match_mode: "all",
        conditions: [{ field: "sender", operator: "contains", value: "Billing@", case_sensitive: true }],
        actions: [{ type: "mark_read" }]
      }
    )
    message_wrong_case = { from: "billing@example.com", subject: "", body: "" }
    message_right_case = { from: "Billing@example.com", subject: "", body: "" }

    assert_not Rules::Matcher.new(rule: rule, message: message_wrong_case).matches?
    assert     Rules::Matcher.new(rule: rule, message: message_right_case).matches?
  end

  test "body field is matched against message body" do
    rule = Rule.new(
      name: "Body",
      priority: 1,
      definition: {
        match_mode: "all",
        conditions: [{ field: "body", operator: "contains", value: "unsubscribe" }],
        actions: [{ type: "mark_read" }]
      }
    )
    assert     Rules::Matcher.new(rule: rule, message: { from: "", subject: "", body: "Click here to Unsubscribe" }).matches?
    assert_not Rules::Matcher.new(rule: rule, message: { from: "", subject: "", body: "Hello friend" }).matches?
  end

  test "any mode returns false when all conditions fail" do
    rule = Rule.new(
      name: "Any fail",
      priority: 1,
      definition: {
        match_mode: "any",
        conditions: [
          { field: "sender", operator: "contains", value: "alpha@" },
          { field: "subject", operator: "contains", value: "beta" }
        ],
        actions: [{ type: "mark_read" }]
      }
    )
    message = { from: "nope@example.com", subject: "nothing", body: "" }
    assert_not Rules::Matcher.new(rule: rule, message: message).matches?
  end
```

- [ ] **Step 2: Run the test file**

```bash
cd rules_editor && bin/rails test test/services/rules/matcher_test.rb
```

Expected: All tests pass.

- [ ] **Step 3: Commit**

```bash
cd rules_editor && git add test/services/rules/matcher_test.rb
git commit -m "Add Matcher gap tests (case_sensitive, body field, any-all-fail)"
```

---

## Chunk 3: RuleEngine + ActionExecutor

### Task 4: Rules::RuleEngine gap tests

**Files:**
- Modify: `rules_editor/test/services/rules/rule_engine_test.rb`

Append to the existing test class:

- [ ] **Step 1: Add missing test cases**

```ruby
  test "returns matched: false when no rule matches the message" do
    rule = Rule.create!(
      name: "Specific",
      priority: 1,
      definition: {
        match_mode: "all",
        conditions: [{ field: "sender", operator: "contains", value: "vip@" }],
        actions: [{ type: "mark_read" }]
      }
    )

    result = Rules::RuleEngine.new(gmail_client: Object.new).process_message!(
      message: { id: "msg-1", from: "nobody@example.com", subject: "hi", body: "" },
      rules_scope: [rule]
    )

    assert_equal false, result[:matched]
  end

  test "stops at the first matching rule and does not evaluate later rules" do
    rule_one = Rule.create!(
      name: "First",
      priority: 1,
      definition: {
        match_mode: "all",
        conditions: [{ field: "sender", operator: "contains", value: "billing@" }],
        actions: [{ type: "mark_read" }]
      }
    )

    rule_two = Rule.create!(
      name: "Second",
      priority: 2,
      definition: {
        match_mode: "all",
        conditions: [{ field: "sender", operator: "contains", value: "billing@" }],
        actions: [{ type: "trash" }]
      }
    )

    gmail_client = Class.new do
      attr_reader :mark_read_ids, :trash_ids
      def initialize = (@mark_read_ids = [], @trash_ids = [])
      def mark_message_read(id) = @mark_read_ids << id
      def trash_message(id) = @trash_ids << id
    end.new

    Rules::RuleEngine.new(gmail_client: gmail_client).process_message!(
      message: { id: "msg-1", from: "billing@example.com", subject: "inv", body: "" },
      rules_scope: [rule_one, rule_two]
    )

    assert_equal ["msg-1"], gmail_client.mark_read_ids
    assert_empty gmail_client.trash_ids
  end

  test "live run with add_label action calls Gmail client and records application" do
    rule = Rule.create!(
      name: "Labels",
      priority: 1,
      definition: {
        match_mode: "all",
        conditions: [{ field: "sender", operator: "contains", value: "billing@" }],
        actions: [{ type: "add_label", label: "Finance" }]
      }
    )

    gmail_client = Class.new do
      attr_reader :ensured_labels, :modifications
      def initialize = (@ensured_labels = [], @modifications = [])
      def ensure_label_id(name) = @ensured_labels << name and "label-id-#{name}"
      def modify_message(message_id:, add_label_ids: [], remove_label_ids: [])
        @modifications << { message_id: message_id, add: add_label_ids, remove: remove_label_ids }
      end
    end.new

    assert_difference "RuleApplication.count", 1 do
      Rules::RuleEngine.new(gmail_client: gmail_client).process_message!(
        message: { id: "msg-2", from: "billing@example.com", subject: "Invoice", body: "" },
        rules_scope: [rule]
      )
    end

    assert_includes gmail_client.ensured_labels, "Finance"
    assert_equal "msg-2", gmail_client.modifications.first[:message_id]
  end
```

- [ ] **Step 2: Run the test file**

```bash
cd rules_editor && bin/rails test test/services/rules/rule_engine_test.rb
```

Expected: All 6 tests pass.

- [ ] **Step 3: Commit**

```bash
cd rules_editor && git add test/services/rules/rule_engine_test.rb
git commit -m "Add RuleEngine gap tests (no match, first-rule-wins, live add_label)"
```

---

### Task 5: Rules::ActionExecutor tests (new file)

**Files:**
- Create: `rules_editor/test/services/rules/action_executor_test.rb`

- [ ] **Step 1: Write failing test**

```ruby
# frozen_string_literal: true

require "test_helper"

class RulesActionExecutorTest < ActiveSupport::TestCase
  class FakeGmailClient
    attr_reader :mark_read_ids, :trash_ids, :modifications, :ensured_labels

    def initialize
      @mark_read_ids = []
      @trash_ids = []
      @modifications = []
      @ensured_labels = []
    end

    def mark_message_read(id)
      @mark_read_ids << id
    end

    def trash_message(id)
      @trash_ids << id
    end

    def ensure_label_id(name)
      @ensured_labels << name
      "label-id-#{name}"
    end

    def modify_message(message_id:, add_label_ids: [], remove_label_ids: [])
      @modifications << { message_id: message_id, add: add_label_ids, remove: remove_label_ids }
    end
  end

  def rule_with_actions(actions)
    Rule.new(
      name: "Test",
      priority: 1,
      definition: {
        match_mode: "all",
        conditions: [{ field: "sender", operator: "contains", value: "x@" }],
        actions: actions
      }
    )
  end

  MESSAGE = { id: "msg-1" }.freeze

  # --- mark_read ---

  test "mark_read in live mode calls mark_message_read on gmail client" do
    rule = rule_with_actions([{ type: "mark_read" }])
    client = FakeGmailClient.new

    result = Rules::ActionExecutor.new(rule: rule, message: MESSAGE, gmail_client: client).execute!

    assert_equal ["msg-1"], client.mark_read_ids
    assert_equal [{ type: "mark_read" }], result
  end

  test "mark_read in dry_run mode does not call gmail client" do
    rule = rule_with_actions([{ type: "mark_read" }])
    client = FakeGmailClient.new

    result = Rules::ActionExecutor.new(rule: rule, message: MESSAGE, gmail_client: client, dry_run: true).execute!

    assert_empty client.mark_read_ids
    assert_equal [{ type: "mark_read" }], result
  end

  # --- trash ---

  test "trash in live mode calls trash_message on gmail client" do
    rule = rule_with_actions([{ type: "trash" }])
    client = FakeGmailClient.new

    result = Rules::ActionExecutor.new(rule: rule, message: MESSAGE, gmail_client: client).execute!

    assert_equal ["msg-1"], client.trash_ids
    assert_equal [{ type: "trash" }], result
  end

  test "trash in dry_run mode does not call gmail client" do
    rule = rule_with_actions([{ type: "trash" }])
    client = FakeGmailClient.new

    Rules::ActionExecutor.new(rule: rule, message: MESSAGE, gmail_client: client, dry_run: true).execute!

    assert_empty client.trash_ids
  end

  # --- add_label ---

  test "add_label in live mode ensures label and modifies message" do
    rule = rule_with_actions([{ type: "add_label", label: "Finance" }])
    client = FakeGmailClient.new

    result = Rules::ActionExecutor.new(rule: rule, message: MESSAGE, gmail_client: client).execute!

    assert_includes client.ensured_labels, "Finance"
    assert_equal "msg-1", client.modifications.first[:message_id]
    assert_includes client.modifications.first[:add], "label-id-Finance"
    assert_equal [{ type: "add_label", label: "Finance" }], result
  end

  test "add_label in dry_run mode skips all gmail calls" do
    rule = rule_with_actions([{ type: "add_label", label: "Finance" }])
    client = FakeGmailClient.new

    result = Rules::ActionExecutor.new(rule: rule, message: MESSAGE, gmail_client: client, dry_run: true).execute!

    assert_empty client.ensured_labels
    assert_empty client.modifications
    assert_equal [{ type: "add_label", label: "Finance" }], result
  end

  # --- remove_label ---

  test "remove_label in live mode ensures label and removes it from message" do
    rule = rule_with_actions([{ type: "remove_label", label: "INBOX" }])
    client = FakeGmailClient.new

    result = Rules::ActionExecutor.new(rule: rule, message: MESSAGE, gmail_client: client).execute!

    assert_includes client.ensured_labels, "INBOX"
    assert_includes client.modifications.first[:remove], "label-id-INBOX"
    assert_equal [{ type: "remove_label", label: "INBOX" }], result
  end

  test "remove_label in dry_run mode skips all gmail calls" do
    rule = rule_with_actions([{ type: "remove_label", label: "INBOX" }])
    client = FakeGmailClient.new

    Rules::ActionExecutor.new(rule: rule, message: MESSAGE, gmail_client: client, dry_run: true).execute!

    assert_empty client.ensured_labels
    assert_empty client.modifications
  end

  # --- multiple actions ---

  test "multiple actions are all executed and returned" do
    rule = rule_with_actions([
      { type: "mark_read" },
      { type: "add_label", label: "Done" },
      { type: "trash" }
    ])
    client = FakeGmailClient.new

    result = Rules::ActionExecutor.new(rule: rule, message: MESSAGE, gmail_client: client).execute!

    assert_equal 3, result.length
    assert_equal "mark_read", result[0][:type]
    assert_equal "add_label", result[1][:type]
    assert_equal "trash", result[2][:type]
    assert_equal ["msg-1"], client.mark_read_ids
    assert_equal ["msg-1"], client.trash_ids
    assert_includes client.ensured_labels, "Done"
  end
end
```

- [ ] **Step 2: Run the test to verify it fails first (file is new, so running it should work once written)**

```bash
cd rules_editor && bin/rails test test/services/rules/action_executor_test.rb
```

Expected: All 9 tests pass.

- [ ] **Step 3: Commit**

```bash
cd rules_editor && git add test/services/rules/action_executor_test.rb
git commit -m "Add ActionExecutor tests covering all 4 action types in dry and live modes"
```

---

## Chunk 4: DefinitionBuilder + ForwardedContentParser

### Task 6: Rules::DefinitionBuilder tests (new file)

**Files:**
- Create: `rules_editor/test/services/rules/definition_builder_test.rb`

- [ ] **Step 1: Write the test file**

```ruby
# frozen_string_literal: true

require "test_helper"

class RulesDefinitionBuilderTest < ActiveSupport::TestCase
  test "builds definition with match_mode, conditions and actions" do
    params = {
      match_mode: "any",
      conditions_attributes: [
        { field: "subject", operator: "contains", value: "Invoice", case_sensitive: "false" }
      ],
      actions_attributes: [
        { type: "mark_read", label: "" }
      ]
    }

    result = Rules::DefinitionBuilder.new(params).build

    assert_equal "any", result[:match_mode]
    assert_equal 1, result[:conditions].length
    assert_equal "subject", result[:conditions].first[:field]
    assert_equal "Invoice", result[:conditions].first[:value]
    assert_equal false, result[:conditions].first[:case_sensitive]
    assert_equal 1, result[:actions].length
    assert_equal "mark_read", result[:actions].first[:type]
  end

  test "match_mode defaults to 'all' for invalid value" do
    params = { match_mode: "whatever", conditions_attributes: [], actions_attributes: [] }
    result = Rules::DefinitionBuilder.new(params).build
    assert_equal "all", result[:match_mode]
  end

  test "strips whitespace from condition values" do
    params = {
      match_mode: "all",
      conditions_attributes: [{ field: "sender", operator: "contains", value: "  billing@  ", case_sensitive: false }],
      actions_attributes: [{ type: "mark_read" }]
    }
    result = Rules::DefinitionBuilder.new(params).build
    assert_equal "billing@", result[:conditions].first[:value]
  end

  test "skips conditions with blank value" do
    params = {
      match_mode: "all",
      conditions_attributes: [
        { field: "sender", operator: "contains", value: "", case_sensitive: false },
        { field: "subject", operator: "contains", value: "Invoice", case_sensitive: false }
      ],
      actions_attributes: [{ type: "mark_read" }]
    }
    result = Rules::DefinitionBuilder.new(params).build
    assert_equal 1, result[:conditions].length
    assert_equal "Invoice", result[:conditions].first[:value]
  end

  test "case_sensitive as array uses last element (checkbox quirk)" do
    params = {
      match_mode: "all",
      conditions_attributes: [
        { field: "sender", operator: "contains", value: "x@", case_sensitive: ["0", "1"] }
      ],
      actions_attributes: [{ type: "mark_read" }]
    }
    result = Rules::DefinitionBuilder.new(params).build
    assert_equal true, result[:conditions].first[:case_sensitive]
  end

  test "skips actions with empty type" do
    params = {
      match_mode: "all",
      conditions_attributes: [{ field: "sender", operator: "contains", value: "x@", case_sensitive: false }],
      actions_attributes: [
        { type: "", label: "" },
        { type: "mark_read", label: "" }
      ]
    }
    result = Rules::DefinitionBuilder.new(params).build
    assert_equal 1, result[:actions].length
    assert_equal "mark_read", result[:actions].first[:type]
  end

  test "label included for add_label action" do
    params = {
      match_mode: "all",
      conditions_attributes: [{ field: "sender", operator: "contains", value: "x@", case_sensitive: false }],
      actions_attributes: [{ type: "add_label", label: "Finance" }]
    }
    result = Rules::DefinitionBuilder.new(params).build
    action = result[:actions].first
    assert_equal "add_label", action[:type]
    assert_equal "Finance", action[:label]
  end

  test "label not included for mark_read action" do
    params = {
      match_mode: "all",
      conditions_attributes: [{ field: "sender", operator: "contains", value: "x@", case_sensitive: false }],
      actions_attributes: [{ type: "mark_read", label: "ignored" }]
    }
    result = Rules::DefinitionBuilder.new(params).build
    assert_not result[:actions].first.key?(:label)
  end

  test "handles conditions_attributes as a Hash (ActionController::Parameters style)" do
    # Simulates how Rails submits nested params: {"0" => {...}, "1" => {...}}
    params = {
      match_mode: "all",
      conditions_attributes: { "0" => { field: "sender", operator: "contains", value: "x@", case_sensitive: false } },
      actions_attributes: { "0" => { type: "mark_read" } }
    }
    result = Rules::DefinitionBuilder.new(params).build
    assert_equal 1, result[:conditions].length
    assert_equal 1, result[:actions].length
  end
end
```

- [ ] **Step 2: Run the test file**

```bash
cd rules_editor && bin/rails test test/services/rules/definition_builder_test.rb
```

Expected: All 8 tests pass.

- [ ] **Step 3: Commit**

```bash
cd rules_editor && git add test/services/rules/definition_builder_test.rb
git commit -m "Add DefinitionBuilder tests covering all normalization paths"
```

---

### Task 7: Rules::ForwardedContentParser tests (new file)

**Files:**
- Create: `rules_editor/test/services/rules/forwarded_content_parser_test.rb`

- [ ] **Step 1: Write the test file**

```ruby
# frozen_string_literal: true

require "test_helper"

class RulesForwardedContentParserTest < ActiveSupport::TestCase
  def parser
    Rules::ForwardedContentParser.new
  end

  test "parses From and Subject from a forwarded email body" do
    body = <<~TEXT
      Begin forwarded message:

      From: Billing Team <billing@example.com>
      Subject: Invoice #1234
      Date: March 2026
    TEXT

    result = parser.parse(body)

    assert_equal "billing@example.com", result[:sender]
    assert_equal "Invoice #1234", result[:subject]
  end

  test "parses De and Asunto (Spanish forwarded format)" do
    body = <<~TEXT
      De: facturacion@empresa.com
      Asunto: Factura Marzo
    TEXT

    result = parser.parse(body)

    assert_equal "facturacion@empresa.com", result[:sender]
    assert_equal "Factura Marzo", result[:subject]
  end

  test "extracts bare email address when no angle brackets" do
    body = "From: plain@example.com\nSubject: Hello"
    result = parser.parse(body)
    assert_equal "plain@example.com", result[:sender]
  end

  test "extracts email from Name <email> format" do
    body = "From: John Doe <john@doe.com>\nSubject: Hi"
    result = parser.parse(body)
    assert_equal "john@doe.com", result[:sender]
  end

  test "returns nil when From line is missing" do
    body = "Subject: Hello\nSome body text"
    assert_nil parser.parse(body)
  end

  test "returns nil when Subject line is missing" do
    body = "From: someone@example.com\nSome body text"
    assert_nil parser.parse(body)
  end

  test "returns nil for blank body" do
    assert_nil parser.parse("")
    assert_nil parser.parse(nil)
  end

  test "uses first From and Subject when multiple appear" do
    body = <<~TEXT
      From: first@example.com
      Subject: First Subject
      From: second@example.com
      Subject: Second Subject
    TEXT
    result = parser.parse(body)
    assert_equal "first@example.com", result[:sender]
    assert_equal "First Subject", result[:subject]
  end
end
```

- [ ] **Step 2: Run the test file**

```bash
cd rules_editor && bin/rails test test/services/rules/forwarded_content_parser_test.rb
```

Expected: All 8 tests pass.

- [ ] **Step 3: Commit**

```bash
cd rules_editor && git add test/services/rules/forwarded_content_parser_test.rb
git commit -m "Add ForwardedContentParser tests covering all parsing paths"
```

---

## Chunk 5: OneOffApplier + MatchingEmailsLoader

### Task 8: Rules::OneOffApplier tests (new file)

**Files:**
- Create: `rules_editor/test/services/rules/one_off_applier_test.rb`

- [ ] **Step 1: Write the test file**

```ruby
# frozen_string_literal: true

require "test_helper"

class RulesOneOffApplierTest < ActiveSupport::TestCase
  def billing_rule
    Rule.create!(
      name: "Billing",
      priority: 1,
      active: true,
      definition: {
        match_mode: "all",
        conditions: [{ field: "sender", operator: "contains", value: "billing@" }],
        actions: [{ type: "mark_read" }]
      }
    )
  end

  class FakeGmailClient
    attr_reader :mark_read_ids

    def initialize(messages)
      @messages = messages
      @mark_read_ids = []
    end

    def fetch_normalized_message(id)
      @messages.fetch(id)
    end

    def list_message_ids(query:, max_results:)
      @messages.keys.take(max_results)
    end

    def mark_message_read(id)
      @mark_read_ids << id
    end
  end

  test "apply! with message_id applies rule to that single message" do
    rule = billing_rule
    client = FakeGmailClient.new({
      "msg-1" => { id: "msg-1", from: "billing@example.com", subject: "Invoice", body: "" }
    })

    result = Rules::OneOffApplier.new(rule: rule, gmail_client: client).apply!(message_id: "msg-1")

    assert_equal 1, result[:matched_count]
    assert_equal 1, result[:applied_count]
    assert_includes client.mark_read_ids, "msg-1"
  end

  test "apply! with message_id returns applied_count 0 when already applied" do
    rule = billing_rule
    RuleApplication.create!(
      rule: rule,
      gmail_message_id: "msg-1",
      rule_version: rule.version_digest,
      result: {},
      applied_at: Time.current
    )
    client = FakeGmailClient.new({
      "msg-1" => { id: "msg-1", from: "billing@example.com", subject: "Invoice", body: "" }
    })

    result = Rules::OneOffApplier.new(rule: rule, gmail_client: client).apply!(message_id: "msg-1")

    assert_equal 1, result[:matched_count]
    assert_equal 0, result[:applied_count]
  end

  test "apply! with query processes all matching messages" do
    rule = billing_rule
    client = FakeGmailClient.new({
      "msg-1" => { id: "msg-1", from: "billing@example.com", subject: "A", body: "" },
      "msg-2" => { id: "msg-2", from: "noreply@example.com", subject: "B", body: "" },
      "msg-3" => { id: "msg-3", from: "billing@example.com", subject: "C", body: "" }
    })

    result = Rules::OneOffApplier.new(rule: rule, gmail_client: client).apply!(query: "in:inbox")

    assert_equal 2, result[:matched_count]
    assert_equal 2, result[:applied_count]
  end

  test "apply! with neither message_id nor query raises ArgumentError" do
    rule = billing_rule
    applier = Rules::OneOffApplier.new(rule: rule, gmail_client: Object.new)
    assert_raises(ArgumentError) { applier.apply! }
  end
end
```

- [ ] **Step 2: Run the test file**

```bash
cd rules_editor && bin/rails test test/services/rules/one_off_applier_test.rb
```

Expected: All 4 tests pass.

- [ ] **Step 3: Commit**

```bash
cd rules_editor && git add test/services/rules/one_off_applier_test.rb
git commit -m "Add OneOffApplier tests covering by_message_id, by_query, and ArgumentError"
```

---

### Task 9: Rules::MatchingEmailsLoader tests (new file)

**Files:**
- Create: `rules_editor/test/services/rules/matching_emails_loader_test.rb`

- [ ] **Step 1: Write the test file**

```ruby
# frozen_string_literal: true

require "test_helper"

class RulesMatchingEmailsLoaderTest < ActiveSupport::TestCase
  def create_rule
    Rule.create!(
      name: "Billing",
      priority: 1,
      definition: {
        match_mode: "all",
        conditions: [{ field: "sender", operator: "contains", value: "billing@" }],
        actions: [{ type: "mark_read" }]
      }
    )
  end

  def create_application(rule:, message_id:, subject: "Invoice", from: "billing@example.com", date: "Mon, 10 Mar 2026 09:00:00 +0000", thread_id: nil)
    RuleApplication.create!(
      rule: rule,
      gmail_message_id: message_id,
      rule_version: rule.version_digest,
      applied_at: Time.current,
      result: {
        message: {
          subject: subject,
          from: from,
          date: date,
          thread_id: thread_id
        }.compact
      }
    )
  end

  test "returns empty result when rule has no applications" do
    rule = create_rule
    result = Rules::MatchingEmailsLoader.new(rule: rule).load

    assert_equal 0, result[:total_count]
    assert_equal [], result[:emails]
    assert_equal false, result[:truncated]
    assert_nil result[:error]
  end

  test "loads emails from rule_applications with complete metadata" do
    rule = create_rule
    create_application(rule: rule, message_id: "msg-1", thread_id: "thread-1")

    result = Rules::MatchingEmailsLoader.new(rule: rule).load

    assert_equal 1, result[:total_count]
    email = result[:emails].first
    assert_equal "Invoice", email[:subject]
    assert_equal "billing@example.com", email[:from]
    assert_equal "https://mail.google.com/mail/u/0/#all/thread-1", email[:gmail_url]
  end

  test "gmail_url falls back to message_id when thread_id is absent" do
    rule = create_rule
    create_application(rule: rule, message_id: "msg-2")

    result = Rules::MatchingEmailsLoader.new(rule: rule).load
    email = result[:emails].first

    assert_equal "https://mail.google.com/mail/u/0/#all/msg-2", email[:gmail_url]
  end

  test "deduplicates by gmail_message_id" do
    rule = create_rule
    create_application(rule: rule, message_id: "msg-dup")
    # Apply same message again with different rule version
    RuleApplication.create!(
      rule: rule,
      gmail_message_id: "msg-dup",
      rule_version: "different-version",
      applied_at: 1.hour.ago,
      result: { message: { subject: "Old", from: "billing@example.com", date: "Mon, 01 Jan 2024 00:00:00 +0000" } }
    )

    result = Rules::MatchingEmailsLoader.new(rule: rule).load

    assert_equal 1, result[:emails].length
    assert_equal 1, result[:total_count]
  end

  test "fetches missing metadata from Gmail when subject or from is blank" do
    rule = create_rule
    RuleApplication.create!(
      rule: rule,
      gmail_message_id: "msg-no-meta",
      rule_version: rule.version_digest,
      applied_at: Time.current,
      result: { message: {} }  # no subject/from/date stored
    )

    fake_gmail = Class.new do
      def fetch_normalized_message(id)
        { subject: "From Gmail", from: "billing@example.com", date: "Tue, 01 Apr 2025 12:00:00 +0000", thread_id: nil }
      end
    end.new

    result = Rules::MatchingEmailsLoader.new(rule: rule, gmail_client_factory: -> { fake_gmail }).load
    email = result[:emails].first

    assert_equal "From Gmail", email[:subject]
  end

  test "captures Gmail fetch error and continues with placeholder text" do
    rule = create_rule
    RuleApplication.create!(
      rule: rule,
      gmail_message_id: "msg-broken",
      rule_version: rule.version_digest,
      applied_at: Time.current,
      result: { message: {} }
    )

    failing_gmail = Class.new do
      def fetch_normalized_message(_id)
        raise StandardError, "Gmail unavailable"
      end
    end.new

    result = Rules::MatchingEmailsLoader.new(rule: rule, gmail_client_factory: -> { failing_gmail }).load

    assert_equal "Gmail unavailable", result[:error]
    email = result[:emails].first
    assert_equal "(subject unavailable)", email[:subject]
    assert_equal "(sender unavailable)", email[:from]
  end

  test "truncated is true when unique message count exceeds MAX_DISPLAYED_EMAILS" do
    rule = create_rule
    # Create 51 unique applications
    51.times do |i|
      create_application(rule: rule, message_id: "msg-#{i}")
    end

    result = Rules::MatchingEmailsLoader.new(rule: rule).load

    assert_equal true, result[:truncated]
    assert_equal 50, result[:emails].length
    assert_equal 51, result[:total_count]
  end
end
```

- [ ] **Step 2: Run the test file**

```bash
cd rules_editor && bin/rails test test/services/rules/matching_emails_loader_test.rb
```

Expected: All 7 tests pass.

- [ ] **Step 3: Commit**

```bash
cd rules_editor && git add test/services/rules/matching_emails_loader_test.rb
git commit -m "Add MatchingEmailsLoader tests covering empty, dedup, truncation, Gmail fallback"
```

---

## Chunk 6: AutoRulesCreator + CycleProcessor

### Task 10: AutoRulesCreator live-run tests

**Files:**
- Modify: `rules_editor/test/services/rules/auto_rule_creator_test.rb`

Append to the existing test class (the FakeGmailClient defined there already covers the methods we need):

- [ ] **Step 1: Add live-run and edge case tests**

```ruby
  # FakeOneOffApplier is used to prevent AutoRulesCreator#apply_rule from calling
  # OneOffApplier.new(rule:) without a gmail_client, which would default to Gmail::Client.new
  # and raise "GOOGLE_CLIENT_ID is not set".
  FakeOneOffApplierResult = Struct.new(:matched_count, :applied_count)
  class FakeOneOffApplier
    def initialize(rule:, gmail_client: nil); end
    def apply!(**) = { matched_count: 1, applied_count: 1 }
  end

  test "live run creates a Rule and AutoRuleEvent for each classify message" do
    gmail_client = FakeGmailClient.new
    processor = Rules::AutoRulesCreator.new(gmail_client: gmail_client, dry_run: false)

    ENV.delete("NTFY_CHANNEL")  # ensure no ntfy HTTP call

    result = nil
    # Stub OneOffApplier so apply_rule never calls Gmail::Client.new
    Rules::OneOffApplier.stub(:new, ->(rule:, **) { FakeOneOffApplier.new(rule: rule) }) do
      capture_io do
        assert_difference "Rule.count", 1 do
          assert_difference "AutoRuleEvent.count", 1 do
            result = processor.process!
          end
        end
      end
    end

    assert_equal 1, result[:created]
    rule = Rule.last
    assert_equal false, rule.active  # auto rules are inactive by default
    assert_match "Auto:", rule.name

    event = AutoRuleEvent.last
    assert_equal "msg-1", event.source_gmail_message_id
    assert_equal rule, event.created_rule
  end

  test "live run skips message if AutoRuleEvent already exists for it" do
    AutoRuleEvent.create!(
      source_gmail_message_id: "msg-1",
      created_rule: Rule.create!(
        name: "Existing",
        priority: 1,
        definition: {
          match_mode: "all",
          conditions: [{ field: "sender", operator: "contains", value: "x@" }],
          actions: [{ type: "mark_read" }]
        }
      )
    )

    gmail_client = FakeGmailClient.new
    processor = Rules::AutoRulesCreator.new(gmail_client: gmail_client, dry_run: false)

    result = nil
    capture_io do
      assert_no_difference "Rule.count" do
        result = processor.process!
      end
    end

    assert_equal 0, result[:created]
  end

  test "returns zero counts when gmail returns no classify messages" do
    empty_client = Class.new do
      def list_message_ids(query:, max_results:) = []
      def profile = Struct.new(:email_address).new("owner@example.com")
    end.new

    result = nil
    capture_io do
      result = Rules::AutoRulesCreator.new(gmail_client: empty_client, dry_run: false).process!
    end

    assert_equal 0, result[:inspected]
    assert_equal 0, result[:created]
  end
```

- [ ] **Step 2: Run the full auto_rule_creator test file**

```bash
cd rules_editor && bin/rails test test/services/rules/auto_rule_creator_test.rb
```

Expected: All 4 tests pass (1 existing + 3 new).

- [ ] **Step 3: Commit**

```bash
cd rules_editor && git add test/services/rules/auto_rule_creator_test.rb
git commit -m "Add AutoRulesCreator live-run tests"
```

---

### Task 11: MailListener::CycleProcessor tests (new file)

**Files:**
- Create: `rules_editor/test/services/mail_listener/cycle_processor_test.rb`

- [ ] **Step 1: Create test directory and write test file**

```bash
mkdir -p rules_editor/test/services/mail_listener
```

```ruby
# frozen_string_literal: true

require "test_helper"

class MailListenerCycleProcessorTest < ActiveSupport::TestCase
  class FakeGmailClient
    attr_reader :fetched_ids, :mark_read_ids

    def initialize(messages: {}, message_ids: [])
      @messages = messages
      @message_ids_list = message_ids
      @fetched_ids = []
      @mark_read_ids = []
    end

    def list_message_ids(query:, max_results:)
      # Return empty for classify queries so AutoRulesCreator does nothing and
      # never calls apply_rule → OneOffApplier.new(rule:) → Gmail::Client.new.
      return [] if query.start_with?("label:")
      @message_ids_list.take(max_results)
    end

    def fetch_normalized_message(id)
      @fetched_ids << id
      @messages.fetch(id, { id: id, from: "", subject: "", body: "" })
    end

    def mark_message_read(id)
      @mark_read_ids << id
    end

    def profile
      Struct.new(:email_address).new("owner@example.com")
    end
  end

  def create_rule(value: "billing@")
    Rule.create!(
      name: "Billing",
      priority: 1,
      active: true,
      definition: {
        match_mode: "all",
        conditions: [{ field: "sender", operator: "contains", value: value }],
        actions: [{ type: "mark_read" }]
      }
    )
  end

  test "process! fetches messages and applies matching rules" do
    rule = create_rule
    client = FakeGmailClient.new(
      message_ids: ["msg-1"],
      messages: { "msg-1" => { id: "msg-1", from: "billing@example.com", subject: "inv", body: "" } }
    )
    # FakeGmailClient returns [] for the classify query (label:*) so AutoRulesCreator
    # does nothing. The inbox query returns ["msg-1"] which gets processed by RuleEngine.

    capture_io do
      MailListener::CycleProcessor.new(gmail_client: client).process!
    end

    assert RuleApplication.exists?(gmail_message_id: "msg-1", rule_id: rule.id)
  end

  test "dry_run mode does not create rule applications" do
    create_rule
    client = FakeGmailClient.new(
      message_ids: ["msg-1"],
      messages: { "msg-1" => { id: "msg-1", from: "billing@example.com", subject: "inv", body: "" } }
    )

    assert_no_difference "RuleApplication.count" do
      capture_io do
        MailListener::CycleProcessor.new(gmail_client: client, dry_run: true).process!
      end
    end
  end

  test "process! catches and logs StandardError without raising" do
    exploding_client = Class.new do
      def list_message_ids(query:, max_results:) = raise StandardError, "connection refused"
      def profile = Struct.new(:email_address).new("x@example.com")
    end.new

    # Should not raise
    output = capture_io do
      assert_nothing_raised do
        MailListener::CycleProcessor.new(gmail_client: exploding_client).process!
      end
    end.first

    assert_includes output, "cycle failed"
  end

  test "process! sends ntfy notification on authorization error when channel is configured" do
    auth_error_client = Class.new do
      def list_message_ids(query:, max_results:)
        raise RuntimeError, "Authorization failed — please re-authenticate"
      end
      def profile = Struct.new(:email_address).new("x@example.com")
    end.new

    ntfy_called = false
    ENV["NTFY_CHANNEL"] = "test-channel"

    HTTP.stub(:post, ->(_url, **_opts) { ntfy_called = true }) do
      capture_io do
        MailListener::CycleProcessor.new(gmail_client: auth_error_client).process!
      end
    end

    assert ntfy_called, "Expected HTTP.post to be called for ntfy notification"
  ensure
    ENV.delete("NTFY_CHANNEL")
  end

  test "skips ntfy notification when NTFY_CHANNEL is not set" do
    auth_error_client = Class.new do
      def list_message_ids(query:, max_results:)
        raise RuntimeError, "Authorization failed"
      end
      def profile = Struct.new(:email_address).new("x@example.com")
    end.new

    ENV.delete("NTFY_CHANNEL")
    ntfy_called = false

    HTTP.stub(:post, ->(_url, **_opts) { ntfy_called = true }) do
      capture_io do
        MailListener::CycleProcessor.new(gmail_client: auth_error_client).process!
      end
    end

    assert_not ntfy_called
  end
end
```

- [ ] **Step 2: Run the test file**

```bash
cd rules_editor && bin/rails test test/services/mail_listener/cycle_processor_test.rb
```

Expected: All 5 tests pass.

- [ ] **Step 3: Commit**

```bash
cd rules_editor && git add test/services/mail_listener/cycle_processor_test.rb
git commit -m "Add CycleProcessor tests covering process!, dry-run, error handling, ntfy"
```

---

## Chunk 7: Controller integration gaps

### Task 12a: Fix existing rules_show_test to stub GmailAffectedEmailsLoader

**Files:**
- Modify: `rules_editor/test/integration/rules_show_test.rb`

**Why:** `RulesController#show` calls `Rules::GmailAffectedEmailsLoader.new(rule: @rule).load` with the default `gmail_client_factory: -> { Gmail::Client.new }`. In test, `Gmail::Client.new` calls `Authorization#validate_environment` which raises `"GOOGLE_CLIENT_ID is not set"`. The loader's outer `rescue StandardError` catches this, so the test passes — but we're relying on error-path behavior and doing unnecessary work. Stub the loader to return a clean empty result.

- [ ] **Step 1: Replace the existing test body with a stubbed version**

```ruby
# frozen_string_literal: true

require "test_helper"

class RulesShowTest < ActionDispatch::IntegrationTest
  EMPTY_GMAIL_PREVIEW = {
    emails: [], total_count: 0, scanned_count: 0, truncated: false, error: nil
  }.freeze

  test "shows matching emails with subject, from, date, and gmail link" do
    rule = Rule.create!(
      name: "Invoices",
      active: true,
      priority: 1,
      definition: {
        match_mode: "all",
        conditions: [{ field: "sender", operator: "contains", value: "billing@" }],
        actions: [{ type: "mark_read" }]
      }
    )

    RuleApplication.create!(
      rule: rule,
      gmail_message_id: "gmail-1",
      rule_version: "v1",
      applied_at: Time.current,
      result: {
        message: {
          subject: "Invoice March",
          from: "billing@example.com",
          date: "Fri, 07 Mar 2026 13:20:00 +0000",
          thread_id: "thread-1"
        }
      }
    )

    fake_loader = Object.new.tap { |obj| obj.define_singleton_method(:load) { EMPTY_GMAIL_PREVIEW } }

    Rules::GmailAffectedEmailsLoader.stub(:new, ->(**) { fake_loader }) do
      get rule_path(rule), headers: inertia_headers

      assert_response :success

      payload = JSON.parse(response.body)
      matching_email = payload.dig("props", "matchingEmails", "emails", 0)

      assert_equal "Rules/Show", payload["component"]
      assert_equal 1, payload.dig("props", "matchingEmails", "totalCount")
      assert_equal "Invoice March", matching_email.fetch("subject")
      assert_equal "billing@example.com", matching_email.fetch("from")
      assert_equal "https://mail.google.com/mail/u/0/#all/thread-1", matching_email.fetch("gmailUrl")
    end
  end

  private

  def inertia_headers
    { "X-Inertia" => "true" }
  end
end
```

- [ ] **Step 2: Run the updated test**

```bash
cd rules_editor && bin/rails test test/integration/rules_show_test.rb
```

Expected: 1 test passes. No `GOOGLE_CLIENT_ID` errors in output.

- [ ] **Step 3: Commit**

```bash
cd rules_editor && git add test/integration/rules_show_test.rb
git commit -m "Stub GmailAffectedEmailsLoader in show integration test to avoid Gmail::Client.new"
```

---

### Task 12: Controller integration gap tests

**Files:**
- Modify: `rules_editor/test/integration/rules_edit_test.rb`
- Create: `rules_editor/test/integration/rules_index_test.rb`

#### Part A: save_and_apply in rules_edit_test.rb

Append to the existing `RulesEditTest` class:

- [ ] **Step 1: Add save_and_apply and apply-failure tests**

Note: `update` with `commit_action: "save_and_apply"` calls `apply_now` then redirects (does NOT render the show action), so `GmailAffectedEmailsLoader` is not called here. Only `OneOffApplier` needs stubbing.

```ruby
  test "save_and_apply applies rule to inbox and shows matched/applied in flash" do
    # Stub OneOffApplier so no real Gmail call is made
    fake_applier = Object.new.tap { |obj|
      obj.define_singleton_method(:apply!) { |**_| { matched_count: 3, applied_count: 2 } }
    }
    Rules::OneOffApplier.stub(:new, ->(**_) { fake_applier }) do
      patch rule_path(@rule),
        params: valid_rule_params.merge(commit_action: "save_and_apply"),
        headers: inertia_headers

      assert_response :conflict
      assert_equal rule_path(@rule), response.headers["X-Inertia-Location"]
      assert_match "matched: 3", flash[:notice]
      assert_match "applied: 2", flash[:notice]
    end
  end

  test "save_and_apply sets alert flash when OneOffApplier raises" do
    fake_applier = Object.new.tap { |obj|
      obj.define_singleton_method(:apply!) { |**_| raise StandardError, "Gmail error" }
    }
    Rules::OneOffApplier.stub(:new, ->(**_) { fake_applier }) do
      patch rule_path(@rule),
        params: valid_rule_params.merge(commit_action: "save_and_apply"),
        headers: inertia_headers

      assert_response :conflict
      assert_match "Gmail error", flash[:alert]
    end
  end
```

#### Part B: Index serialization test (new file)

```ruby
# frozen_string_literal: true

require "test_helper"

class RulesIndexTest < ActionDispatch::IntegrationTest
  test "index returns serialized active and inactive rules" do
    active = Rule.create!(
      name: "Active Rule",
      active: true,
      priority: 1,
      definition: {
        match_mode: "all",
        conditions: [{ field: "sender", operator: "contains", value: "a@" }],
        actions: [{ type: "mark_read" }, { type: "trash" }]
      }
    )

    Rule.create!(
      name: "Inactive Rule",
      active: false,
      priority: 2,
      definition: {
        match_mode: "all",
        conditions: [{ field: "subject", operator: "contains", value: "b@" }],
        actions: [{ type: "mark_read" }]
      }
    )

    get rules_path, headers: { "X-Inertia" => "true" }

    assert_response :success
    payload = JSON.parse(response.body)

    active_rules = payload.dig("props", "activeRules")
    inactive_rules = payload.dig("props", "inactiveRules")

    assert_equal 1, active_rules.length
    assert_equal "Active Rule", active_rules.first["name"]
    assert_equal 1, active_rules.first["conditionsCount"]
    assert_equal 2, active_rules.first["actionsCount"]

    assert_equal 1, inactive_rules.length
    assert_equal "Inactive Rule", inactive_rules.first["name"]
  end
end
```

- [ ] **Step 2: Run the updated edit test and new index test**

```bash
cd rules_editor && bin/rails test test/integration/rules_edit_test.rb test/integration/rules_index_test.rb
```

Expected: All tests pass.

- [ ] **Step 3: Commit**

```bash
cd rules_editor && git add test/integration/rules_edit_test.rb test/integration/rules_index_test.rb
git commit -m "Add controller integration gap tests (save_and_apply, apply failure, index serialization)"
```

---

## Chunk 8: Verify 100% coverage

### Task 13: Run full suite and check coverage

- [ ] **Step 1: Run complete test suite**

```bash
cd rules_editor && bin/rails test 2>&1
```

Expected: All tests pass. Zero failures.

- [ ] **Step 2: Open coverage report**

```bash
open rules_editor/coverage/index.html
```

Review SimpleCov report. Any file below 100% that should be covered will be highlighted.

- [ ] **Step 3: Address any remaining uncovered lines**

If SimpleCov shows uncovered lines:
- Identify the file and line number
- Add a focused test that exercises that exact path
- Re-run the suite

Common remaining gaps and how to handle them:
- `rescue` branches in services: raise the expected error in a test and assert the result
- `ENV.fetch` branches: set/unset the env var in a test using `ENV["KEY"] = "value"` and `ensure ENV.delete("KEY")`
- Log output methods (`puts`): wrap with `capture_io` — the method just needs to be called, not asserted

- [ ] **Step 4: Final commit**

```bash
cd rules_editor && git add -A
git commit -m "Achieve 100% backend test coverage with Minitest"
```

---

## Files created/modified summary

| Action | File |
|---|---|
| Modify | `rules_editor/Gemfile` |
| Modify | `rules_editor/test/test_helper.rb` |
| Modify | `rules_editor/test/models/rule_test.rb` |
| Modify | `rules_editor/test/services/rules/matcher_test.rb` |
| Modify | `rules_editor/test/services/rules/rule_engine_test.rb` |
| Modify | `rules_editor/test/services/rules/auto_rule_creator_test.rb` |
| Modify | `rules_editor/test/integration/rules_show_test.rb` |
| Modify | `rules_editor/test/integration/rules_edit_test.rb` |
| Create | `rules_editor/test/services/rules/action_executor_test.rb` |
| Create | `rules_editor/test/services/rules/definition_builder_test.rb` |
| Create | `rules_editor/test/services/rules/forwarded_content_parser_test.rb` |
| Create | `rules_editor/test/services/rules/one_off_applier_test.rb` |
| Create | `rules_editor/test/services/rules/matching_emails_loader_test.rb` |
| Create | `rules_editor/test/services/mail_listener/cycle_processor_test.rb` |
| Create | `rules_editor/test/integration/rules_index_test.rb` |
