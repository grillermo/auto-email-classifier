# Sends the DiDi Card statement PDF attached to this email to bank-app-parser.
Statements::Forwarder.new(gmail_client: gmail_client, message: message, bank_name: "didi").forward!
