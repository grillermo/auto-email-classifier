# Google OAuth Verification — Gmail Scope Justifications

Use these answers in the Google Cloud Console OAuth verification form under
**"How will the scopes be used?"**.

## Note on scope set

The application code (`app/services/gmail/authorization.rb`) requests only
`https://www.googleapis.com/auth/gmail.modify`. That scope already includes
everything `gmail.readonly` and `gmail.metadata` grant. Google often flags
redundant scope sets and slows verification. Prefer requesting only
`gmail.modify` in the OAuth consent screen unless a narrower-only path is added
later.

If only `gmail.modify` is requested, skip the other two sections below.

---

## `https://www.googleapis.com/auth/gmail.modify`

Email Classifier executes user-defined automation rules against the user's
Gmail inbox. The `gmail.modify` scope is required for the core feature of the
app: applying labels, marking messages read/unread, archiving (removing the
INBOX label), and moving messages to Trash, based on conditions the user
configures (sender, subject, body keywords, age, etc.).

Specifically the app uses:

- `users.messages.list` to discover candidate messages matching a query
- `users.messages.get` to read sender, subject, snippet, and body so rules can
  evaluate text-based conditions the user wrote
- `users.messages.modify` to add or remove labels (including INBOX/UNREAD)
  chosen by the user
- `users.messages.trash` when a user's rule explicitly chooses to trash a
  matching message
- `users.labels.list` and `users.labels.create` so users can target labels by
  name

The app never permanently deletes mail (no `messages.delete`), never sends mail
without explicit user action, and only modifies messages that satisfy rules
the user has configured and enabled.

---

## `https://www.googleapis.com/auth/gmail.readonly`

Used to evaluate user-defined rules against full message content (subject,
From/To headers, body) when a rule's conditions require reading text beyond
what `gmail.metadata` exposes. Without `gmail.readonly` (or `gmail.modify`),
the app cannot determine whether a message matches body- or subject-based
conditions the user wrote.

> Note: If only `gmail.modify` is approved, `gmail.readonly` is redundant for
> this app and can be removed.

---

## `https://www.googleapis.com/auth/gmail.metadata`

Used to enumerate the user's existing Gmail labels so the rule editor can
present them as targets for label actions, and to display label and header
information in the management UI without loading full bodies. This keeps body
access minimized when only metadata is needed for a given operation.

> Note: Also covered by `gmail.modify`; only needed if narrower-scope-only
> paths are exposed.

---

## Limited Use affirmation (paste into the general "How scopes are used" box)

All Gmail access is initiated by the signed-in user, scoped to the user's own
mailbox via OAuth, and used solely to execute the automation rules the user
defines. The app stores rule definitions, OAuth refresh tokens (encrypted at
rest), and operational logs. The app does not store full message bodies, does
not transfer Gmail data to third parties, does not use Gmail data for
advertising or training AI/ML models, and does not allow humans to read Gmail
content. Use complies with the Google API Services User Data Policy, including
Limited Use.

---

## Verification checklist

Other items Google asks for during verification:

1. Homepage publicly accessible, describes the app and shows branding.
2. Privacy Policy publicly accessible — served at `/privacy`.
3. Terms of Service publicly accessible — served at `/terms-of-service`.
4. Privacy Policy explicitly references the Google API Services User Data
   Policy and Limited Use requirements (already present in
   `app/views/pages/privacy.html.erb`).
5. App domain verified in Google Search Console and listed under "Authorized
   domains" in the OAuth consent screen.
6. Demo video for sensitive/restricted Gmail scopes showing the OAuth consent
   flow and how Gmail data is used in the app.
7. Per-scope justification for every scope requested (see sections above).
