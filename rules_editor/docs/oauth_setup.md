# Gmail OAuth 2.0 Setup

This app now follows the same Gmail auth pattern as the scripts in `/Users/grillermo/c/email-classifier/example`.

1. Open [Google Cloud Console](https://console.cloud.google.com/) and create or select a project.
2. Enable **Gmail API**.
3. Configure the OAuth consent screen and add your Gmail account as a test user if the app is still in testing.
4. Create an OAuth 2.0 client with application type **Desktop app**.
5. Copy the client ID and client secret.
6. Create `rules_editor/.env` from `rules_editor/.env.example` if you have not already.
7. Set these values in `rules_editor/.env`:
   - `GOOGLE_CLIENT_ID`
   - `GOOGLE_CLIENT_SECRET`
8. Start the app from `/Users/grillermo/c/email-classifier` with `./run.api`.
9. On first startup, the app prints the authorization URL, opens it in your browser, and prompts for the authorization code.
10. Paste the code back into the terminal.
11. On success, the refresh token is stored at `~/.credentials/gmail-modify-token.yaml`.

## Notes

- This is the same default token path used by the example Gmail scripts, so both can share the same Gmail modify token.
- If you need a different token file, set `GOOGLE_OAUTH_TOKEN_PATH`.
- If the token is revoked or you want to re-authenticate, delete `~/.credentials/gmail-modify-token.yaml` and run `./run.api` again.

## References

- [Configure OAuth consent screen](https://developers.google.com/workspace/guides/configure-oauth-consent)
- [Create OAuth credentials](https://developers.google.com/workspace/guides/create-credentials)
