# Gmail OAuth 2.0 Setup (Terminal Flow)

Use these exact steps before starting `run.api`.

1. Open [Google Cloud Console](https://console.cloud.google.com/) and create/select a project.
2. Go to `Menu -> APIs & Services -> Library` and enable **Gmail API**.
3. Go to `Menu -> Google Auth Platform -> Branding` and complete app branding details.
4. Go to `Audience` and set app type:
   - `External` for personal/testing.
   - `Internal` only for Workspace org-only usage.
5. Add your Gmail account in `Audience -> Test users`.
6. Go to `Data Access` and add scopes:
   - `https://www.googleapis.com/auth/gmail.modify`
   - `https://www.googleapis.com/auth/gmail.send`
   - `https://www.googleapis.com/auth/gmail.readonly`
7. Go to `Google Auth Platform -> Clients` and click **Create client**.
8. Choose **Desktop app** as application type.
9. Download the OAuth client JSON file.
10. Save it at `/Users/grillermo/c/email-classifier/rules_editor/config/google_oauth_client.json`.
11. Create `.env` from `.env.example` and verify:
    - `GOOGLE_OAUTH_CLIENT_PATH` points to the downloaded JSON.
    - `GOOGLE_OAUTH_TOKEN_PATH` points to `rules_editor/tmp/gmail_token.json`.
12. Start the supervisor with `./run.api`.
13. On first startup, copy the printed URL, approve access, then paste the authorization code (or the full redirect URL) in terminal.
14. On success, refresh token is stored in `rules_editor/tmp/gmail_token.json`.

## Notes

- If the token is revoked, delete `rules_editor/tmp/gmail_token.json` and run `./run.api` again.
- Keep OAuth client JSON and token files out of version control.

## References

- [Configure OAuth consent screen](https://developers.google.com/workspace/guides/configure-oauth-consent)
- [Create OAuth credentials](https://developers.google.com/workspace/guides/create-credentials)
