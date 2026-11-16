# Sends the Banamex statement PDF attached to this email (cuenta or tarjeta)
# to bank-app-parser. The PDF is encrypted: its password goes in
# config/statement_passwords.rb under "banamex".
Statements::Forwarder.new(gmail_client: gmail_client, message: message, bank_name: "banamex").forward!
