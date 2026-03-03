# Email Classifier Automation

Ruby + Rails automation that applies Gmail rules in priority order.

## Project structure

- `/Users/grillermo/c/email-classifier/run.api` - supervisor script that bootstraps OAuth, then runs Rails server and mail listener.
- `/Users/grillermo/c/email-classifier/mail_listener` - long-running Gmail polling listener.
- `/Users/grillermo/c/email-classifier/rules_editor` - Rails web UI, models, migrations, and services.

## Quick start

Use Ruby 3.4+ (the project was developed with 3.4.7).

1. Configure environment:

```bash
cp /Users/grillermo/c/email-classifier/rules_editor/.env.example /Users/grillermo/c/email-classifier/rules_editor/.env
```

The app loads environment variables from `rules_editor/.env` automatically via `bkeepers/dotenv`.

2. Configure OAuth 2.0 in Google Cloud UI:

- Follow `/Users/grillermo/c/email-classifier/rules_editor/docs/oauth_setup.md`.

3. Prepare database:

```bash
cd /Users/grillermo/c/email-classifier/rules_editor
bundle install
bundle exec rails db:create db:migrate
```

4. Start everything:

```bash
cd /Users/grillermo/c/email-classifier
./run.api
```

## Import existing Apple Mail rules

```bash
cd /Users/grillermo/c/email-classifier/rules_editor
bundle exec ruby import_from_mail_app.rb /Users/grillermo/c/email-classifier/SyncedRules.plist
```


**What Codex implemented**
- Built the full Gmail rule automation scaffold:
  - Supervisor + dual-process startup in [run.api](/Users/grillermo/c/email-classifier/run.api:1)
  - Forever listener loop in [listener.rb](/Users/grillermo/c/email-classifier/mail_listener/listener.rb:1)
  - Rails rules editor (`index`, `show`, `edit`, `update`, `save_and_apply`, `reorder`) in [rules_controller.rb](/Users/grillermo/c/email-classifier/rules_editor/app/controllers/rules_controller.rb:1) and [routes.rb](/Users/grillermo/c/email-classifier/rules_editor/config/routes.rb:1)
  - JSONB rule model and rule-application/idempotency models in [rule.rb](/Users/grillermo/c/email-classifier/rules_editor/app/models/rule.rb:1)
  - Gmail OAuth + REST client in [oauth_manager.rb](/Users/grillermo/c/email-classifier/rules_editor/app/services/gmail/oauth_manager.rb:1) and [client.rb](/Users/grillermo/c/email-classifier/rules_editor/app/services/gmail/client.rb:1)
  - Rule engine + matcher + actions + forwarded auto-rule flow in [rule_engine.rb](/Users/grillermo/c/email-classifier/rules_editor/app/services/rules/rule_engine.rb:1) and [forwarded_rule_processor.rb](/Users/grillermo/c/email-classifier/rules_editor/app/services/rules/forwarded_rule_processor.rb:1)
  - Apple Mail importer in [import_from_mail_app.rb](/Users/grillermo/c/email-classifier/rules_editor/import_from_mail_app.rb:1)
  - Tailwind-based UI + plain JS drag/drop reorder and dynamic edit form in [index.html.erb](/Users/grillermo/c/email-classifier/rules_editor/app/views/rules/index.html.erb:1), [edit.html.erb](/Users/grillermo/c/email-classifier/rules_editor/app/views/rules/edit.html.erb:1), [rules_index.js](/Users/grillermo/c/email-classifier/rules_editor/app/javascript/rules_index.js:1), [rules_form.js](/Users/grillermo/c/email-classifier/rules_editor/app/javascript/rules_form.js:1)
- Applied your requested cleanup changes:
  - Replaced manual `.env` parsing with `bkeepers/dotenv`:
    - Gem changed to `dotenv` in [Gemfile](/Users/grillermo/c/email-classifier/rules_editor/Gemfile:17)
    - Auto-load via Rails boot in [boot.rb](/Users/grillermo/c/email-classifier/rules_editor/config/boot.rb:1)
    - Removed custom loader file `mail_listener/env_loader.rb`
  - Removed pgcrypto dependency:
    - Deleted migration `rules_editor/db/migrate/20260303000100_enable_pgcrypto.rb`
  - Removed CI/Dependabot:
    - Deleted `rules_editor/.github/workflows/ci.yml`
    - Deleted `rules_editor/.github/dependabot.yml`
  - Removed Kamal:
    - Removed gem/dependency references in [Gemfile](/Users/grillermo/c/email-classifier/rules_editor/Gemfile:1) and [Gemfile.lock](/Users/grillermo/c/email-classifier/rules_editor/Gemfile.lock:302)
    - Deleted `rules_editor/config/deploy.yml`, `rules_editor/bin/kamal`, and `.kamal/`
    - Cleaned Docker comment in [Dockerfile](/Users/grillermo/c/email-classifier/rules_editor/Dockerfile:4)
  - Forwarded emails now create inactive rules by default:
    - `active: false` in [forwarded_rule_processor.rb](/Users/grillermo/c/email-classifier/rules_editor/app/services/rules/forwarded_rule_processor.rb:74)
- Kept `.env.example` and updated docs:
  - [.env.example](/Users/grillermo/c/email-classifier/rules_editor/.env.example:1)
  - OAuth setup guide in [oauth_setup.md](/Users/grillermo/c/email-classifier/rules_editor/docs/oauth_setup.md:1)
  - README notes that dotenv auto-loads env files in [README.md](/Users/grillermo/c/email-classifier/README.md:1) and [rules_editor/README.md](/Users/grillermo/c/email-classifier/rules_editor/README.md:1)

**Validation done**
- Ruby syntax checks passed for key entrypoints/services:
  - `ruby -c run.api`
  - `ruby -c mail_listener/listener.rb`
  - `ruby -c rules_editor/config/boot.rb`
  - `ruby -c rules_editor/app/services/rules/forwarded_rule_processor.rb`
- Verified removals:
  - No remaining grep matches for `kamal|pgcrypto|env_loader|dependabot|ci.yml`
  - Confirmed `.github`, `.kamal`, `config/deploy.yml`, and `bin/kamal` are removed.

**Validation blocked**
- `bundle check` cannot complete due network restriction (`index.rubygems.org` unreachable), so I could not run full Rails test suite or dependency-resolution checks in this environment.

**Next steps**
1. Run `bundle install` in `/Users/grillermo/c/email-classifier/rules_editor`.
2. Run `bundle exec rails db:create db:migrate`.
3. Start everything with `./run.api`.
