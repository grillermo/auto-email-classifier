# Gmail OAuth Setup

This app uses a browser-based Google OAuth flow.

- Users sign in to the app with a magic link first.
- Then they connect Gmail from the browser flow at `/gmail_authentications/new`.
- Google redirects back to `/gmail/oauth/callback`.

Use a **Web application** OAuth client in Google Cloud. Do not use a Desktop app client for this flow.

## What The App Expects

Set these values in `rules_editor/.env`:

- `APP_BASE_URL`
- `GOOGLE_CLIENT_ID`
- `GOOGLE_CLIENT_SECRET`

The app reads the Google client credentials from:

- [`.env.example`](/Users/grillermo/c/auto-email-classifier/rules_editor/.env.example#L11)
- [`gmail/oauth_callback_controller.rb`](/Users/grillermo/c/auto-email-classifier/rules_editor/app/controllers/gmail/oauth_callback_controller.rb#L44)
- [`oauth_manager.rb`](/Users/grillermo/c/auto-email-classifier/rules_editor/app/services/gmail/oauth_manager.rb#L7)

The Gmail OAuth callback route is defined here:

- [`routes.rb`](/Users/grillermo/c/auto-email-classifier/rules_editor/config/routes.rb#L17)

## Google Cloud Setup

1. Open [Google Cloud Console](https://console.cloud.google.com/) and create or select a project.

2. Enable the **Gmail API**.
   Open [API Library](https://console.cloud.google.com/apis/library), search for `Gmail API`, open it, and click `Enable`.

3. Open the [Google Auth Platform](https://console.developers.google.com/auth/overview) for the same project.

4. Configure the consent screen basics.
   Click `Get started`, then set:
   - App name
   - User support email
   - Developer contact email

5. Choose the app audience.
   - Use `Internal` if only users in your Google Workspace organization will connect Gmail.
   - Use `External` if personal Gmail accounts or users outside your Workspace org will connect Gmail.

6. Add the Gmail scope this app uses.
   Open `Data Access`, click `Add or remove scopes`, and add:
   - `https://www.googleapis.com/auth/gmail.modify`

7. Create the OAuth client.
   Open `Clients`, click `Create client`, and choose:
   - Application type: `Web application`

8. Add the authorized redirect URI.
   The value must match your app exactly.

   For local development with the default env values, add:

   - `http://localhost:3000/gmail/oauth/callback`

   For any deployed environment, also add its exact callback URL, for example:

   - `https://your-domain.example/gmail/oauth/callback`

9. Create the client, then copy:
   - Client ID
   - Client secret

10. Create `rules_editor/.env` from `rules_editor/.env.example` if you have not already:

```bash
cp rules_editor/.env.example rules_editor/.env
```

11. Set the Google credentials in `rules_editor/.env`:

```bash
APP_BASE_URL=http://localhost:3000
GOOGLE_CLIENT_ID=your-client-id
GOOGLE_CLIENT_SECRET=your-client-secret
```

12. Start the app.

```bash
cd /Users/grillermo/c/auto-email-classifier
./run.api
```

13. Test the browser flow.
   - Sign in to the app with the magic link flow.
   - If the signed-in user has no `gmail_authentications`, the app redirects them to the Gmail connect page.
   - Otherwise, click `Add Gmail Auth` in the header.
   - Click `Continue with Google`.

## Important Notes

- The app requests `https://www.googleapis.com/auth/gmail.modify`. Google classifies this as a **restricted** Gmail scope.
- If your OAuth app is `External` and still in `Testing`, Google states that test-user authorizations expire after 7 days. For offline access flows, refresh tokens also expire in that mode.
- Redirect URIs must match exactly. If you see `redirect_uri_mismatch`, check the scheme, host, port, path, and trailing slash.

## Local Development Checklist

1. `APP_BASE_URL` is `http://localhost:3000`
2. The OAuth client type is `Web application`
3. `http://localhost:3000/gmail/oauth/callback` is listed as an authorized redirect URI
4. `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` are set in `rules_editor/.env`
5. Gmail API is enabled in the same GCP project as the OAuth client

## References

- [Choose Gmail API scopes](https://developers.google.com/workspace/gmail/api/auth/scopes)
- [OAuth 2.0 for Web Server Applications](https://developers.google.com/identity/protocols/oauth2/web-server)
- [Manage App Audience](https://support.google.com/cloud/answer/15549945?hl=en)
- [Manage App Data Access](https://support.google.com/cloud/answer/15549135?hl=en)
- [Submitting your app for verification](https://support.google.com/cloud/answer/13461325?hl=en)
