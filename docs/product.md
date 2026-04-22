# Product Overview

## What this product is

This repository contains a small web app for managing email automation rules for Gmail.

Its purpose is simple: help someone describe how incoming email should be handled, then apply those rules consistently without hand-sorting messages one by one.

The app is best understood as a rule editor and automation console for a personal or small-team inbox workflow.

## What people can do with it

### Connect a Gmail account

Users can connect a Gmail account through Google sign-in so the app can inspect messages and apply actions to them.

### Manage rules in plain terms

Each rule has:

- a name
- an on/off state
- a priority
- one or more conditions
- one or more actions

Conditions currently focus on common email fields:

- sender
- subject
- body

Users can choose whether a rule should match:

- all conditions
- any condition

They can also make each condition case-sensitive if needed.

### Choose what happens to matching email

When a message matches a rule, the app can:

- add a Gmail label
- remove a Gmail label
- mark the message as read
- move the message to trash
- run a local script for custom handling

### Prioritize which rules run first

Rules are shown in priority order. Active rules can be reordered with drag and drop, which matters because higher-priority rules are evaluated first.

### Keep inactive rules around

Rules can be turned off without being deleted. This makes it easy to keep draft ideas, seasonal rules, or experiments without letting them affect live email.

### Test a rule immediately

From the editor, a user can save a rule and apply it right away to inbox messages. This gives quick feedback without waiting for the background listener cycle.

### Track how often rules have been used

The app records rule applications and shows how many times each rule has run. This gives a lightweight sense of which automations are doing useful work.

## How the product works in practice

The typical workflow is:

1. Sign in.
2. Connect a Gmail account.
3. Review existing rules.
4. Edit rule logic and actions.
5. Reorder active rules so the most important ones run first.
6. Save and optionally apply a rule immediately.
7. Let the background listener continue processing matching email over time.

## Extra capabilities

### Automatic background processing

The repository includes a background job that checks connected Gmail accounts and applies active rules to incoming mail automatically.

### Suggested rule creation from labeled email

There is also a helper flow that watches for emails with a special classification label and turns them into new inactive rule drafts. In other words, the system can propose a rule based on an example email, then let a person review and activate it later.

### Push-style notifications through `ntfy`

The app uses `ntfy` for sign-in links and operational notifications. That means important events, like authentication issues or automatically created rules, can be pushed to a notification channel instead of relying on standard email delivery.

### Import from Apple Mail rules

The repository includes an import script for bringing rules from Apple Mail into this system, which helps when migrating an existing setup.

## What this is not

This is not a broad customer support platform or enterprise email suite. It is a focused automation tool for rule-based inbox handling.

Today, its scope is centered on:

- Gmail-based automation
- rule editing and prioritization
- lightweight tracking
- operational notifications

It does not appear to be positioned as a collaborative admin dashboard, advanced reporting system, or full no-code workflow builder.

## Short summary

If you need a one-sentence description:

This repo is a Gmail automation app that lets people define, prioritize, test, and run inbox rules so email can be labeled, cleaned up, or otherwise handled automatically.
