# Passwords for encrypted bank statements, used by the send_*_statement.rb
# action scripts. Copy this file to config/statement_passwords.rb (gitignored:
# the repo is public) on the machine that runs the listener, and fill them in.
# The file is read on every use, so an edit takes effect on the next listener
# cycle without a restart. A value left as "CHANGE_ME" counts as unset.
{
  "banamex" => "CHANGE_ME",   # the PDF's password
  "santander" => "CHANGE_ME"  # the ZIP's password ("Indicaciones importantes" email)
}
