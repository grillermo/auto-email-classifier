# Rules Editor

Rails application for managing Gmail automation rules.

## Features

- Rules stored in PostgreSQL using JSONB (`conditions` + `actions`).
- Priority-ordered list (`1` is highest) with drag-and-drop reordering.
- `index`, `show`, `edit`, `update` views.
- `Save and apply rule` action that immediately runs one rule against inbox-labeled messages.
- Tailwind-powered UI with plain JavaScript behavior (no frontend framework).

## Environment

Use Ruby 3.4+.

Copy `.env.example` to `.env` and adjust values.

```bash
cp .env.example .env
```

Environment values are loaded automatically with `bkeepers/dotenv`.

Set `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` in `.env` using the same Desktop OAuth client you use for the scripts in `/Users/grillermo/c/email-classifier/example`. The app stores the Gmail modify token in `~/.credentials/gmail-modify-token.yaml` unless `GOOGLE_OAUTH_TOKEN_PATH` overrides it.

## OAuth Setup

See [docs/oauth_setup.md](/Users/grillermo/c/email-classifier/rules_editor/docs/oauth_setup.md).

## Database

```bash
bundle exec rails db:create
bundle exec rails db:migrate
```

## Run only Rails app

```bash
bundle exec rails server -p 3000
```

## Import Apple Mail rules

```bash
bundle exec ruby import_from_mail_app.rb ../SyncedRules.plist
```
