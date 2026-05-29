# Active rules exported 2026-05-29 — run AFTER first Google sign-in
user = User.first || raise("No user found. Sign in with Google first, then run bin/rails db:seed")

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"remove_label","label":"INBOX"},{"type":"add_label","label":"Finanzas"}],"conditions":[{"field":"sender","value":"contacto@klar.mx","operator":"contains","case_sensitive":false},{"field":"sender","value":"contacto@klar.mx","operator":"contains","case_sensitive":false},{"field":"subject","value":"Te compartimos tu Constancia de Ingresos y Retenciones","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Klar - Te compartimos tu Constancia de Ingresos y Retenciones"
  rule.priority = 1
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"trash"},{"type":"mark_read"}],"conditions":[{"field":"sender","value":"support@mail.xtb.com","operator":"contains","case_sensitive":false}],"match_mode":"any"}
) do |rule|
  rule.name = "XTB SPAM"
  rule.priority = 2
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"trash"}],"conditions":[{"field":"sender","value":"cfecontigo@cfe.mx","operator":"contains","case_sensitive":false},{"field":"subject","value":"Aviso de Factura","operator":"contains","case_sensitive":false},{"field":"body","value":"977080902135","operator":"contains","case_sensitive":false}],"match_mode":"any"}
) do |rule|
  rule.name = "CFE - Facturas de Alabama 54"
  rule.priority = 3
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"remove_label","label":"INBOX"},{"type":"add_label","label":"Finanzas"}],"conditions":[{"field":"sender","value":"no-reply@revolut.com","operator":"contains","case_sensitive":false},{"field":"sender","value":"no-reply@revolut.com","operator":"contains","case_sensitive":false},{"field":"subject","value":"You've been sent","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Revolut - You've been sent"
  rule.priority = 4
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"remove_label","label":"INBOX"},{"type":"add_label","label":"Finanzas"}],"conditions":[{"field":"sender","value":"no-reply@revolut.com","operator":"contains","case_sensitive":false},{"field":"sender","value":"no-reply@revolut.com","operator":"contains","case_sensitive":false},{"field":"subject","value":"Beneficiary added successfully 🤝","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Revolut - Beneficiary added successfully 🤝"
  rule.priority = 5
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"remove_label","label":"INBOX"},{"type":"add_label","label":"Finanzas"}],"conditions":[{"field":"sender","value":"no-reply@revolut.com","operator":"contains","case_sensitive":false},{"field":"sender","value":"no-reply@revolut.com","operator":"contains","case_sensitive":false},{"field":"subject","value":"You sent","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Revolut - You sent"
  rule.priority = 6
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"trash"},{"type":"mark_read"}],"conditions":[{"field":"sender","value":"news@mkt.em.carters.com.mx","operator":"contains","case_sensitive":false}],"match_mode":"any"}
) do |rule|
  rule.name = "Carters spam"
  rule.priority = 7
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"remove_label","label":"INBOX"},{"type":"add_label","label":"Finanzas"}],"conditions":[{"field":"sender","value":"noreply@openbank.mx","operator":"contains","case_sensitive":false},{"field":"subject","value":"Diferiste una compra a meses","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "OpenBank- Diferiste una compra a meses ✅"
  rule.priority = 8
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"trash"}],"conditions":[{"field":"sender","value":"support@coralogix.com","operator":"contains","case_sensitive":false}],"match_mode":"any"}
) do |rule|
  rule.name = "Coralogix report"
  rule.priority = 9
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"remove_label","label":"INBOX"},{"type":"add_label","label":"Finanzas"}],"conditions":[{"field":"sender","value":"notificaciones@notificaciones.santander.com.mx","operator":"contains","case_sensitive":false},{"field":"sender","value":"notificaciones@notificaciones.santander.com.mx","operator":"contains","case_sensitive":false},{"field":"subject","value":"Notificación Transferencia Interbancaria a través de SuperMóvil.","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Santander - Notificación Transferencia Interbancaria a través de SuperMóvil."
  rule.priority = 10
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"remove_label","label":"INBOX"},{"type":"mark_read"},{"type":"add_label","label":"Finanzas"}],"conditions":[{"field":"sender","value":"noreply@openbank.mx","operator":"contains","case_sensitive":false},{"field":"sender","value":"noreply@openbank.mx","operator":"contains","case_sensitive":false},{"field":"subject","value":"Estado de Cuenta","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "OpenBank - Estado de Cuenta"
  rule.priority = 11
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"remove_label","label":"INBOX"},{"type":"add_label","label":"Finanzas"}],"conditions":[{"field":"sender","value":"noreply@openbank.mx","operator":"contains","case_sensitive":false},{"field":"sender","value":"noreply@openbank.mx","operator":"contains","case_sensitive":false},{"field":"subject","value":"Gracias por tu pago ✅","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "OpenBank - Gracias por tu pago ✅"
  rule.priority = 12
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"remove_label","label":"INBOX"},{"type":"add_label","label":"Finanzas"}],"conditions":[{"field":"sender","value":"noreply@openbank.mx","operator":"contains","case_sensitive":false},{"field":"subject","value":"Transferencia exitosa","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "OpenBank - Transferencia exitosa"
  rule.priority = 13
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"remove_label","label":"INBOX"},{"type":"add_label","label":"Finanzas"}],"conditions":[{"field":"sender","value":"noreply@openbank.mx","operator":"contains","case_sensitive":false},{"field":"subject","value":"Retiro exitoso ✅","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "OpenBank - Retiro exitoso ✅"
  rule.priority = 14
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"remove_label","label":"INBOX"},{"type":"add_label","label":"Finanzas"}],"conditions":[{"field":"sender","value":"noreply@openbank.mx","operator":"contains","case_sensitive":false},{"field":"subject","value":"Abono exitoso","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Openbank - Abono exitoso"
  rule.priority = 15
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"remove_label","label":"INBOX"},{"type":"add_label","label":"Finanzas"}],"conditions":[{"field":"sender","value":"notificaciones@notificaciones.santander.com.mx","operator":"contains","case_sensitive":false},{"field":"sender","value":"notificaciones@notificaciones.santander.com.mx","operator":"contains","case_sensitive":false},{"field":"subject","value":"Pago de tarjeta de crédito propias.","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Santander - Pago de tarjeta de crédito propias."
  rule.priority = 16
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"remove_label","label":"INBOX"},{"type":"add_label","label":"Finanzas"}],"conditions":[{"field":"sender","value":"estadosdecuenta@banamex.com","operator":"contains","case_sensitive":false},{"field":"subject","value":"Envio de estado de cuenta","operator":"contains","case_sensitive":false},{"field":"body","value":"****818","operator":"contains","case_sensitive":false}],"match_mode":"any"}
) do |rule|
  rule.name = "Estado de cuenta Citibanamex Perfiles"
  rule.priority = 17
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"remove_label","label":"INBOX"},{"type":"add_label","label":"Finanzas"}],"conditions":[{"field":"sender","value":"notificaciones@banamex.com","operator":"contains","case_sensitive":false},{"field":"sender","value":"notificaciones@banamex.com","operator":"contains","case_sensitive":false},{"field":"subject","value":"Depósito a cuenta Banamex","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Banamex - Depósito a cuenta Banamex"
  rule.priority = 18
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"remove_label","label":"INBOX"},{"type":"add_label","label":"Finanzas"}],"conditions":[{"field":"sender","value":"notificaciones@banamex.com","operator":"contains","case_sensitive":false},{"field":"sender","value":"notificaciones@banamex.com","operator":"contains","case_sensitive":false},{"field":"subject","value":"Depósito a Cuenta o Tarjeta Banamex","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Banamex - Depósito a Cuenta o Tarjeta Banamex"
  rule.priority = 19
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"remove_label","label":"INBOX"},{"type":"add_label","label":"Finanzas"}],"conditions":[{"field":"sender","value":"notificaciones@citibanamex.com","operator":"contains","case_sensitive":false},{"field":"subject","value":"Depósito a cuenta Citibanamex","operator":"contains","case_sensitive":false}],"match_mode":"any"}
) do |rule|
  rule.name = "Banamex - Depósito a cuenta Citibanamex"
  rule.priority = 20
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"remove_label","label":"INBOX"},{"type":"add_label","label":"Finanzas"}],"conditions":[{"field":"sender","value":"notificaciones@banamex.com","operator":"contains","case_sensitive":false},{"field":"sender","value":"notificaciones@banamex.com","operator":"contains","case_sensitive":false},{"field":"subject","value":"Retiro/Compra con cuenta Banamex","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Banamex - Retiro/Compra con cuenta Banamex"
  rule.priority = 21
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"remove_label","label":"INBOX"},{"type":"add_label","label":"Finanzas"}],"conditions":[{"field":"sender","value":"info@didicuenta.com.mx","operator":"contains","case_sensitive":false},{"field":"subject","value":"Recibiste una transferencia en tu DiDi Cuenta","operator":"contains","case_sensitive":false}],"match_mode":"any"}
) do |rule|
  rule.name = "DiDi - Recibiste una transferencia en tu DiDi Cuenta"
  rule.priority = 22
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"remove_label","label":"INBOX"},{"type":"add_label","label":"Finanzas"}],"conditions":[{"field":"sender","value":"DiDi@mx.didiglobal.com","operator":"contains","case_sensitive":false},{"field":"sender","value":"DiDi@mx.didiglobal.com","operator":"contains","case_sensitive":false},{"field":"subject","value":"Tu último estado de cuenta está disponible","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "DiDi - Tu último estado de cuenta está disponible"
  rule.priority = 23
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"trash"},{"type":"mark_read"}],"conditions":[{"field":"sender","value":"alerts@coralogix.com","operator":"contains","case_sensitive":false},{"field":"subject","value":"Coralogix Alert","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Coralogix Alert"
  rule.priority = 24
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"trash"}],"conditions":[{"field":"sender","value":"billing@raygun.com","operator":"contains","case_sensitive":false},{"field":"sender","value":"billing@raygun.com","operator":"contains","case_sensitive":false},{"field":"subject","value":"Raygun tracking stopped - account usage exhausted","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Raygun tracking stopped"
  rule.priority = 25
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"trash"}],"conditions":[{"field":"sender","value":"alerts@coralogix.com","operator":"contains","case_sensitive":false},{"field":"subject","value":"Coralogix Alert on Core / tandem-api","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Coralogix Alert on Core / tandem-api"
  rule.priority = 26
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"remove_label","label":"INBOX"},{"type":"add_label","label":"Finanzas"}],"conditions":[{"field":"sender","value":"notificaciones@gbm.com.mx","operator":"contains","case_sensitive":false},{"field":"sender","value":"notificaciones@gbm.com.mx","operator":"contains","case_sensitive":false},{"field":"subject","value":"Estado de Cuenta","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "MercadoPago - Estado de Cuenta"
  rule.priority = 27
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"remove_label","label":"INBOX"},{"type":"add_label","label":"Finanzas"}],"conditions":[{"field":"sender","value":"info@mercadopago.com","operator":"contains","case_sensitive":false},{"field":"subject","value":"Tu transferencia fue enviada","operator":"contains","case_sensitive":false}],"match_mode":"any"}
) do |rule|
  rule.name = "MercadoPago - Tu transferencia fue enviada"
  rule.priority = 28
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"remove_label","label":"INBOX"},{"type":"add_label","label":"Finanzas"}],"conditions":[{"field":"sender","value":"no-responder@mercadopago.com","operator":"contains","case_sensitive":false},{"field":"sender","value":"no-responder@mercadopago.com","operator":"contains","case_sensitive":false},{"field":"subject","value":"Recibimos un pago en tu tarjeta de crédito","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "MercadoPago- Recibimos un pago en tu tarjeta de crédito"
  rule.priority = 29
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"remove_label","label":"INBOX"},{"type":"add_label","label":"Finanzas"}],"conditions":[{"field":"sender","value":"notificaciones@mifel.com.mx","operator":"contains","case_sensitive":false},{"field":"sender","value":"notificaciones@mifel.com.mx","operator":"contains","case_sensitive":false},{"field":"subject","value":"Notificación.","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Mifel- Notificación."
  rule.priority = 30
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"remove_label","label":"INBOX"},{"type":"add_label","label":"Finanzas"}],"conditions":[{"field":"sender","value":"bancamovil@mifel.com.mx","operator":"contains","case_sensitive":false},{"field":"subject","value":"Realizaste una transferencia en Mifel","operator":"contains","case_sensitive":false}],"match_mode":"any"}
) do |rule|
  rule.name = "Mifel - Realizaste una transferencia en Mifel"
  rule.priority = 31
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"remove_label","label":"INBOX"},{"type":"add_label","label":"Finanzas/cetesdirecto"}],"conditions":[{"field":"sender","value":"notificaciones@cetesdirecto.com","operator":"contains","case_sensitive":false},{"field":"subject","value":"Instruccion de Compra desde Dispositivo Movil","operator":"contains","case_sensitive":false}],"match_mode":"any"}
) do |rule|
  rule.name = "CetesDirecto - Instruccion de Compra desde Dispositivo Movil"
  rule.priority = 32
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"trash"},{"type":"mark_read"}],"conditions":[{"field":"sender","value":"o365mc@microsoft.com","operator":"contains","case_sensitive":false},{"field":"sender","value":"o365mc@microsoft.com","operator":"contains","case_sensitive":false}],"match_mode":"any"}
) do |rule|
  rule.name = "Microsoft spam"
  rule.priority = 33
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"remove_label","label":"INBOX"},{"type":"add_label","label":"Finanzas"},{"type":"add_label","label":"classify"}],"conditions":[{"field":"sender","value":"no-reply@revolut.com","operator":"contains","case_sensitive":false},{"field":"subject","value":"You sent MX","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Auto: no-reply@revolut.com | You sent MX"
  rule.priority = 34
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"remove_label","label":"INBOX"},{"type":"remove_label","label":"classify"}],"conditions":[{"field":"sender","value":"noreply@openbank.mx","operator":"contains","case_sensitive":false},{"field":"subject","value":"Diferiste una compra a meses ✅","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Auto: noreply@openbank.mx | Diferiste una compra a meses ✅"
  rule.priority = 35
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"remove_label","label":"INBOX"}],"conditions":[{"field":"sender","value":"noreply@openbank.mx","operator":"contains","case_sensitive":false},{"field":"subject","value":"Gracias por tu pago ✅","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Auto: noreply@openbank.mx | Gracias por tu pago ✅"
  rule.priority = 36
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"trash"},{"type":"remove_label","label":"classify"}],"conditions":[{"field":"sender","value":"no-reply@vifaru.com.mx","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Vifaru Casa de Bolsa"
  rule.priority = 37
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"remove_label","label":"INBOX"},{"type":"remove_label","label":"classify"}],"conditions":[{"field":"sender","value":"noreply@amie.so","operator":"contains","case_sensitive":false},{"field":"subject","value":"Summary shared with you:","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Auto: noreply@amie.so | Summary shared with you: sync Guillermo"
  rule.priority = 38
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"remove_label","label":"INBOX"},{"type":"remove_label","label":"classify"}],"conditions":[{"field":"sender","value":"estadodecuenta@uala.mx","operator":"contains","case_sensitive":false},{"field":"subject","value":"estado de cuenta","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Auto: estadodecuenta@uala.mx | ¡Conoce tu estado de cuenta aquí!"
  rule.priority = 39
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"remove_label","label":"INBOX"},{"type":"remove_label","label":"classify"}],"conditions":[{"field":"sender","value":"DiDi@mx.didiglobal.com","operator":"contains","case_sensitive":false},{"field":"subject","value":"Tu último estado de cuenta está disponible","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Auto: DiDi@mx.didiglobal.com | Tu último estado de cuenta está disponible"
  rule.priority = 40
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"remove_label","label":"INBOX"},{"type":"remove_label","label":"classify"}],"conditions":[{"field":"sender","value":"no-responder@mercadopago.com","operator":"contains","case_sensitive":false},{"field":"subject","value":"Ya puedes descargar tu estado de cuenta","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Auto: no-responder@mercadopago.com | Ya puedes descargar tu estado de cuenta"
  rule.priority = 41
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"remove_label","label":"INBOX"},{"type":"remove_label","label":"classify"},{"type":"add_label","label":"Finanzas"}],"conditions":[{"field":"sender","value":"notificaciones@santander.com.mx","operator":"contains","case_sensitive":false},{"field":"subject","value":"Estado de Cuenta Santander Integral (PDF y XML)","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Auto: notificaciones@santander.com.mx | Estado de Cuenta Santander Integral (PDF y XML)"
  rule.priority = 42
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"remove_label","label":"INBOX"},{"type":"remove_label","label":"classify"}],"conditions":[{"field":"sender","value":"SPEI_Abono_Credito@hsbc.com.mx","operator":"contains","case_sensitive":false},{"field":"subject","value":"Abono a tu Crédito HSBC México","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Auto: SPEI_Abono_Credito@hsbc.com.mx | Abono a tu Crédito HSBC México"
  rule.priority = 43
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"remove_label","label":"INBOX"},{"type":"remove_label","label":"classify"}],"conditions":[{"field":"sender","value":"Plata@platacard.mx","operator":"contains","case_sensitive":false},{"field":"subject","value":"Your statement is ready, you can pay now in the app","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Auto: Plata@platacard.mx | Your statement is ready, you can pay now in the app"
  rule.priority = 44
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"trash"},{"type":"remove_label","label":"INBOX"},{"type":"remove_label","label":"classify"}],"conditions":[{"field":"sender","value":"comunicaciones@legal.mercadopago.com.mx","operator":"contains","case_sensitive":false},{"field":"subject","value":"Tu contrato se ha actualizado","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Auto: comunicaciones@legal.mercadopago.com.mx | Tu contrato se ha actualizado"
  rule.priority = 45
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"trash"},{"type":"remove_label","label":"classify"}],"conditions":[{"field":"sender","value":"usuarios@mueveciudad.com","operator":"contains","case_sensitive":false},{"field":"subject","value":"Realizaste un pago Mueve Ciudad","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Auto: usuarios@mueveciudad.com | Realizaste un pago Mueve Ciudad"
  rule.priority = 46
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"trash"}],"conditions":[{"field":"sender","value":"notificaciones-openbank@","operator":"contains","case_sensitive":false},{"field":"subject","value":"¿Cómo te atendimos?","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Auto: notificaciones-openbank@express.smf1.medallia.com | ¿Cómo te atendimos?"
  rule.priority = 47
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"trash"},{"type":"mark_read"}],"conditions":[{"field":"sender","value":"hello@leaddev.com","operator":"contains","case_sensitive":false},{"field":"subject","value":"Broadcasts","operator":"contains","case_sensitive":true},{"field":"sender","value":"Recent Recordings","operator":"contains","case_sensitive":true}],"match_mode":"all"}
) do |rule|
  rule.name = "LeadDev Broadcasts <hello@leaddev.com>"
  rule.priority = 48
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"trash"},{"type":"mark_read"}],"conditions":[{"field":"sender","value":"geb@hola.geb.mx","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "geb@hola.geb.mx Futura"
  rule.priority = 49
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"trash"},{"type":"mark_read"}],"conditions":[{"field":"sender","value":"memories@facebookmail.com","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Auto: memories@facebookmail.com | Hoy tienes recuerdos para rememorar."
  rule.priority = 50
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"trash"}],"conditions":[{"field":"sender","value":"noreply@business.facebook.com","operator":"contains","case_sensitive":false},{"field":"subject","value":"Revisa los parámetros bloqueados por Meta","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Auto: noreply@business.facebook.com | Revisa los parámetros bloqueados por Meta"
  rule.priority = 51
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"trash"}],"conditions":[{"field":"sender","value":"memories@facebookmail.com","operator":"contains","case_sensitive":false},{"field":"subject","value":"Hoy tienes recuerdos para rememorar.","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Auto: memories@facebookmail.com | Hoy tienes recuerdos para rememorar."
  rule.priority = 52
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"trash"}],"conditions":[{"field":"sender","value":"jobs-noreply@linkedin.com","operator":"contains","case_sensitive":false},{"field":"subject","value":"Guillermo, looking for a new job?","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Auto: jobs-noreply@linkedin.com | Guillermo, looking for a new job?"
  rule.priority = 53
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"remove_label","label":"INBOX"},{"type":"remove_label","label":"classify"},{"type":"add_label","label":"Finanzas"}],"conditions":[{"field":"sender","value":"contacto@klar.mx","operator":"contains","case_sensitive":false},{"field":"subject","value":"Realizaste una transferencia","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Auto: contacto@klar.mx | Realizaste una transferencia"
  rule.priority = 54
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"trash"}],"conditions":[{"field":"sender","value":"decimoalbat@substack.com","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Auto: decimoalbat@substack.com | No. 93"
  rule.priority = 55
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"remove_label","label":"INBOX"},{"type":"remove_label","label":"classify"},{"type":"add_label","label":"Finanzas"}],"conditions":[{"field":"sender","value":"santander@envio.santander.com.mx","operator":"contains","case_sensitive":false},{"field":"subject","value":"Pago/Compra con Tarjeta Santander","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Auto: santander@envio.santander.com.mx | Pago/Compra con Tarjeta Santander"
  rule.priority = 56
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"remove_label","label":"INBOX"},{"type":"remove_label","label":"classify"}],"conditions":[{"field":"sender","value":"noreply@openbank.mx","operator":"contains","case_sensitive":false},{"field":"subject","value":"Diste de alta un destinatario","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Auto: noreply@openbank.mx | Diste de alta un destinatario"
  rule.priority = 57
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"remove_label","label":"INBOX"},{"type":"remove_label","label":"classify"}],"conditions":[{"field":"sender","value":"clientes@envios.santander.com.mx","operator":"contains","case_sensitive":false},{"field":"subject","value":"Tu seguridad es primero.","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Auto: clientes@envios.santander.com.mx | Tu seguridad es primero."
  rule.priority = 58
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"remove_label","label":"INBOX"},{"type":"remove_label","label":"classify"},{"type":"add_label","label":"Finanzas"}],"conditions":[{"field":"sender","value":"plataforma@briq.mx","operator":"contains","case_sensitive":false},{"field":"subject","value":"Transferencia realizada a tu cuenta bancaria","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Auto: plataforma@briq.mx | Transferencia realizada a tu cuenta bancaria"
  rule.priority = 59
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"remove_label","label":"INBOX"},{"type":"remove_label","label":"classify"}],"conditions":[{"field":"sender","value":"corte@vexi.mx","operator":"contains","case_sensitive":false},{"field":"subject","value":"📨 Tu Tarjeta Vexi ha realizado su corte mensual","operator":"contains","case_sensitive":false},{"field":"body","value":"Pago mínimo: $ 0.00 MXN","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Auto: corte@vexi.mx | 📨 Tu Tarjeta Vexi ha realizado su corte mensual"
  rule.priority = 60
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"remove_label","label":"INBOX"},{"type":"remove_label","label":"classify"}],"conditions":[{"field":"sender","value":"comunicaciones@legal.mercadolibre.com.mx","operator":"contains","case_sensitive":false},{"field":"subject","value":"Meli+: Más envíos gratis que nunca","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Auto: comunicaciones@legal.mercadolibre.com.mx | Meli+: Más envíos gratis que nunca"
  rule.priority = 61
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"remove_label","label":"INBOX"},{"type":"remove_label","label":"classify"}],"conditions":[{"field":"sender","value":"notificaciones@yotepresto.com","operator":"contains","case_sensitive":false},{"field":"subject","value":"Estado de Cuenta yotepresto.com","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Auto: notificaciones@yotepresto.com | Estado de Cuenta yotepresto.com"
  rule.priority = 62
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"remove_label","label":"INBOX"},{"type":"remove_label","label":"classify"}],"conditions":[{"field":"sender","value":"corte@vexi.mx","operator":"contains","case_sensitive":false},{"field":"subject","value":"📨 Tu Tarjeta Vexi ha realizado su corte mensual","operator":"contains","case_sensitive":false},{"field":"body","value":"$ 0.00 MXN","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Auto: corte@vexi.mx | 📨 Tu Tarjeta Vexi ha realizado su corte mensual"
  rule.priority = 63
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"remove_label","label":"INBOX"},{"type":"remove_label","label":"classify"},{"type":"add_label","label":"Finanzas"}],"conditions":[{"field":"sender","value":"Plata@platacard.mx","operator":"contains","case_sensitive":false},{"field":"subject","value":"Your statement is ready","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Auto: Plata@platacard.mx | Your statement is ready"
  rule.priority = 64
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"remove_label","label":"INBOX"},{"type":"remove_label","label":"classify"}],"conditions":[{"field":"sender","value":"corte@vexi.mx","operator":"contains","case_sensitive":false},{"field":"subject","value":"📨 Tu Tarjeta Vexi ha realizado su corte mensual","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Auto: corte@vexi.mx | 📨 Tu Tarjeta Vexi ha realizado su corte mensual"
  rule.priority = 65
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"remove_label","label":"INBOX"},{"type":"remove_label","label":"classify"}],"conditions":[{"field":"sender","value":"ayuda@briq.mx","operator":"contains","case_sensitive":false},{"field":"subject","value":"🔴 Ya estamos en vivo - Únete aquí","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Auto: ayuda@briq.mx | 🔴 Ya estamos en vivo - Únete aquí"
  rule.priority = 66
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"remove_label","label":"INBOX"},{"type":"remove_label","label":"classify"}],"conditions":[{"field":"sender","value":"team@mg.dynamitejobs.com","operator":"contains","case_sensitive":false},{"field":"subject","value":"New Remote Job for you [Senior QA Engineer]","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Auto: team@mg.dynamitejobs.com | New Remote Job for you [Senior QA Engineer]"
  rule.priority = 67
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"remove_label","label":"INBOX"},{"type":"remove_label","label":"classify"}],"conditions":[{"field":"sender","value":"notificaciones@notificaciones.santander.com.mx","operator":"contains","case_sensitive":false},{"field":"subject","value":"Notificación Transferencia Interbancaria a través de SuperMóvil.","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Auto: notificaciones@notificaciones.santander.com.mx | Notificación Transferencia Interbancaria a través de SuperMóvil."
  rule.priority = 68
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"remove_label","label":"INBOX"},{"type":"remove_label","label":"classify"}],"conditions":[{"field":"sender","value":"no-reply@revolut.com","operator":"contains","case_sensitive":false},{"field":"subject","value":"Your latest credit card statement is here","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Auto: no-reply@revolut.com | Your latest credit card statement is here"
  rule.priority = 69
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"remove_label","label":"INBOX"},{"type":"remove_label","label":"classify"},{"type":"mark_read"}],"conditions":[{"field":"sender","value":"factura@factel.telcel.com","operator":"contains","case_sensitive":false},{"field":"subject","value":"Facturación Telcel","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Auto: factura@factel.telcel.com | Facturación Telcel"
  rule.priority = 70
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"remove_label","label":"INBOX"},{"type":"remove_label","label":"classify"},{"type":"add_label","label":"Finanzas"}],"conditions":[{"field":"sender","value":"noreply@openbank.mx","operator":"contains","case_sensitive":false},{"field":"subject","value":"Tu Estado de Cuenta ya está disponible","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Auto: noreply@openbank.mx | Tu Estado de Cuenta ya está disponible"
  rule.priority = 71
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"mark_read"},{"type":"trash"}],"conditions":[{"field":"sender","value":"soyacnur@unhcr.org","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Auto: soyacnur@unhcr.org | La infancia nunca debe ser arrebatada."
  rule.priority = 72
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"remove_label","label":"INBOX"},{"type":"remove_label","label":"classify"},{"type":"add_label","label":"Finanzas"}],"conditions":[{"field":"sender","value":"notificaciones@banamex.com","operator":"contains","case_sensitive":false},{"field":"subject","value":"Retiro/Compra con tarjeta Banamex","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Auto: notificaciones@banamex.com | Retiro/Compra con tarjeta Banamex"
  rule.priority = 73
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"trash"}],"conditions":[{"field":"sender","value":"soyacnur@unhcr.org","operator":"contains","case_sensitive":false},{"field":"subject","value":"La infancia nunca debe ser arrebatada.","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Auto: soyacnur@unhcr.org | La infancia nunca debe ser arrebatada."
  rule.priority = 74
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"remove_label","label":"INBOX"},{"type":"remove_label","label":"classify"},{"type":"trash"}],"conditions":[{"field":"sender","value":"notificaciones@banamex.com","operator":"contains","case_sensitive":false},{"field":"subject","value":"Alta de cuenta","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Auto: notificaciones@banamex.com | Alta de cuenta"
  rule.priority = 102
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"remove_label","label":"INBOX"},{"type":"remove_label","label":"classify"},{"type":"trash"}],"conditions":[{"field":"sender","value":"estadodecuenta@uala.mx","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Auto: estadodecuenta@uala.mx | ¡Conoce tu estado de cuenta aquí!"
  rule.priority = 103
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"remove_label","label":"INBOX"},{"type":"remove_label","label":"classify"}],"conditions":[{"field":"sender","value":"hola+ventas@tiendanube.com","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "hola+ventas@tiendanube.com"
  rule.priority = 105
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"remove_label","label":"INBOX"},{"type":"remove_label","label":"classify"},{"type":"add_label","label":"Finanzas"}],"conditions":[{"field":"sender","value":"hola@fintual.com","operator":"contains","case_sensitive":false},{"field":"subject","value":"Tu estado de cuenta de marzo","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Auto: hola@fintual.com | Tu estado de cuenta de marzo"
  rule.priority = 108
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"trash"}],"conditions":[{"field":"sender","value":"Retoactinver@actinver.com.mx","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Reto Actinver "
  rule.priority = 109
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"remove_label","label":"INBOX"},{"type":"remove_label","label":"classify"},{"type":"trash"}],"conditions":[{"field":"sender","value":"noreply@mailer2.okx.com","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Auto: noreply@mailer2.okx.com"
  rule.priority = 110
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"trash"}],"conditions":[{"field":"sender","value":"bot@notifications.heroku.com","operator":"contains","case_sensitive":false},{"field":"subject","value":"Remember to Register a Backup MFA Verification Method","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Auto: bot@notifications.heroku.com | Remember to Register a Backup MFA Verification Method"
  rule.priority = 112
  rule.active = true
end

Rule.find_or_create_by!(
  user: user,
  definition: {"actions":[{"type":"mark_read"},{"type":"trash"}],"conditions":[{"field":"sender","value":"operatividadpatitaspeluditas@gmail.com","operator":"contains","case_sensitive":false}],"match_mode":"all"}
) do |rule|
  rule.name = "Auto: operatividadpatitaspeluditas@gmail.com | Hoy puedes hacer la diferencia | ¡Llamado Peludo! 🐾"
  rule.priority = 114
  rule.active = true
end
