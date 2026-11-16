# Sends the Santander statement to bank-app-parser. Santander attaches a ZIP
# holding the PDF; the ZIP is encrypted, and its password goes in
# config/statement_passwords.rb under "santander".
Statements::Forwarder.new(gmail_client: gmail_client, message: message, bank_name: "santander").forward!
