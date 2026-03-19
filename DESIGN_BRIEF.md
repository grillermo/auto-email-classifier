# Auto Email Classifier — Design Brief

## What the App Does

A personal tool that automatically manages your Gmail inbox using customizable rules. You define conditions (e.g. "sender contains newsletter@example.com") and actions (e.g. "mark as read + add label"), and the app continuously watches your inbox in the background and applies those rules automatically.

There are three core surfaces:
1. **Rules list** — overview and prioritization
2. **Rule detail** — inspect a rule and see its real-world impact
3. **Rule editor** — create or modify a rule

---

## Screens

### 1. Rules List (Home Page `/`)

The landing page. Shows all rules at a glance.

**What's displayed:**
- Table of active rules with columns: Name, Conditions (count), Actions (count), Times Applied (count)
- Separate section below for inactive/disabled rules (visually muted)
- Flash messages at the top for success or error feedback

**What users can do:**
- **Drag and drop rows** to reorder rules — priority is determined by position (top = runs first). Changes save automatically.
- **Click a row** (via show/edit icons) to navigate to the rule detail or edit page
- See at a glance how many times each rule has been applied to emails

**Design notes:**
- Order matters — rules run top-to-bottom and each email only matches one rule
- Inactive rules should feel clearly secondary, not just a toggle state

---

### 2. Rule Detail (`/rules/:id`)

Shows the full definition and historical impact of a single rule.

**Sections:**

**Header:** Rule name, priority number, active/inactive badge

**Conditions panel:**
A list of conditions that must match for the rule to trigger. Each condition has:
- Field: `sender`, `subject`, or `body`
- Operator: `contains`
- Value: the text to match
- Case-sensitive: yes/no flag

Match mode indicator: whether **all** conditions must match (AND) or **any** (OR).

**Actions panel:**
A list of what happens when the rule matches. Possible actions:
- `add_label` — apply a Gmail label (label name shown)
- `remove_label` — remove a Gmail label (label name shown)
- `mark_read` — mark the email as read
- `trash` — move to trash

**Gmail Impact Preview (live):**
Shows emails in the inbox *right now* that would match this rule. Scans up to 200 recent messages, displays up to 25 matches. Each row shows:
- Subject
- Sender
- Date
- Link to open in Gmail

Includes total match count and a note if results are truncated. Shows a graceful error if Gmail is unreachable.

**Match History:**
Emails that have already been processed by this rule. Up to 50 most recent entries. Same columns as above plus the actions that were applied.

**Navigation:** Edit button, Back button

---

### 3. Rule Editor (`/rules/:id/edit`)

Form for creating or updating a rule.

**Fields:**

**Basics:**
- Name (text input, required)
- Priority (number input, required — lower = higher priority)
- Active (checkbox)

**Match Mode:**
Radio/toggle between:
- "Match all conditions" (AND)
- "Match any condition" (OR)

**Conditions builder:**
A dynamic list of condition rows. Each row:
- Field dropdown: sender / subject / body
- Operator: contains (fixed for now)
- Value: text input
- Case-sensitive: toggle/checkbox
- Remove button (disabled if only 1 condition remains)

Add Condition button at the bottom.

**Actions builder:**
A dynamic list of action rows. Each row:
- Action type dropdown: add_label / remove_label / mark_read / trash
- Label input: text field, enabled only when action is add_label or remove_label
- Remove button (disabled if only 1 action remains)

Add Action button at the bottom.

**Form submission:**
Two submit options:
- **Save** — saves the rule
- **Save and Apply Now** — saves and immediately applies the rule to the inbox, then shows a count of how many emails were matched and acted on

Validation errors display in a banner at the top.

---

## Key Concepts for the Designer

### Rules & Priority
Rules are processed in priority order. Each email stops at the first rule it matches — no email gets processed by two rules. Priority is set by position in the list (drag to reorder) or by a numeric priority field.

### Active vs Inactive
Rules can be toggled active/inactive. Inactive rules are stored but never run by the background listener.

### Conditions
Each condition checks one part of an email (sender address, subject line, or body text). Multiple conditions on a rule use either AND or OR logic.

### Actions
What the rule does when matched. A rule can have multiple actions (e.g. "add label Newsletters AND mark as read"). Supported actions: add label, remove label, mark as read, move to trash.

### Background Processing
The app runs a background process that polls Gmail every 60 seconds and automatically applies rules. Users don't need to do anything after setup — the rules just run.

### Auto-Rule Generation
When an email is tagged with a special "classify" label in Gmail, the app automatically creates a draft rule for that email. The user gets a push notification and can review/activate the rule in the UI.

---

## What the UI Does NOT Currently Have

These features do not exist yet but may be relevant for scoping future design:
- No bulk rule management (delete, enable/disable multiple)
- No rule creation from scratch via the list page (must go through edit flow)
- No search/filter on the rules list
- No user accounts — single-user personal tool
- No mobile-first considerations in the current implementation

---

## Tech Stack (for context)

- **Frontend:** React + Inertia.js (SPA-like navigation, server-rendered props)
- **Styling:** Tailwind CSS
- **Backend:** Ruby on Rails
- **Data:** PostgreSQL (rules, rule application history)
- **Gmail integration:** Gmail API via OAuth 2.0

---

## Current Visual Style

- Light background: slate-100
- Text: slate-900
- Status colors: emerald (success), rose (error)
- Max content width: ~72rem (6xl)
- No sidebar — single column layout
- Drag handle icons on list rows
- Show/Edit icon buttons (not text links)
