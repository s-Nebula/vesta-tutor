# ⚠️ Código heredado: no desplegar

Estas Cloud Functions son una versión antigua del backend. **No deben
desplegarse**:

- `createChild` y `linkDevice` crean y vinculan perfiles **sin** el bloque
  `privacyAuthorization`, saltándose el modelo de consentimiento.
- Toda su funcionalidad está hoy en la API (`vesta-build/backend/vesta-api`):
  perfiles, vinculación y desvinculación, y notificaciones push
  (`src/services/alert_dispatcher.js`).

Por eso la entrada `functions` se quitó de `firebase.json`: un
`firebase deploy` desde `vesta_app` ya no las publica.

Pendiente de migrar a la API antes de borrar este directorio: las invitaciones
de segundo tutor (`createParentInvitation`, `acceptParentInvitation`,
`revokeParentInvitation`).
