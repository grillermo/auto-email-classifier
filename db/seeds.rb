# Active rules exported 2026-05-28 — run AFTER first Google sign-in
user = User.first || raise("No user found. Sign in with Google first, then run bin/rails db:seed")
