### Resumen de Trabajo Realizado (13 de Octubre de 2025)

1.  **Configuración Inicial de Notificaciones:**
    *   Se añadió la dependencia `firebase_messaging` al proyecto.
    *   Se resolvieron conflictos de versiones entre las librerías de Firebase, ajustando `cloud_firestore` a una versión compatible.
    *   Se creó un `NotificationService` para centralizar la lógica de notificaciones.
    *   Se configuró el lado nativo de Android (`build.gradle.kts`, `AndroidManifest.xml`) para registrar los plugins, canales y permisos necesarios.

2.  **Prueba de Concepto:**
    *   Se implementó y se probó con éxito una **notificación local** que se disparaba al iniciar la aplicación, confirmando que la configuración base es correcta.
    *   Se eliminó la notificación de prueba para continuar con la implementación real.

3.  **Análisis del Flujo de Notificaciones:**
    *   Se discutió la diferencia entre **notificaciones locales** (generadas en el mismo dispositivo) y **notificaciones push** (enviadas desde un servidor a otro dispositivo).
    *   Se concluyó que la "aceptación de pacientes" requiere **notificaciones push** (vía FCM) para que el paciente sea notificado aunque su app esté cerrada, mientras que los "recordatorios" pueden ser implementados con **notificaciones locales programadas**.

### Próximos Pasos

A continuación, se detalla el plan para implementar las notificaciones funcionales en el proyecto.

#### Tarea 1: Implementar Notificaciones Push para Aceptación de Invitaciones (FCM)

*   **Objetivo:** Notificar al **paciente** en tiempo real cuando un **cuidador** acepta su invitación.
*   **Pasos:**
    1.  **Modificar la App para Guardar el Token de FCM:**
        *   En `notification_service.dart`, modificar `initNotifications` para que, después de obtener el `fcmToken`, se guarde en el documento del usuario actual en la colección `users` de Firestore.
    2.  **Configurar Firebase Cloud Functions:**
        *   Inicializar Firebase Functions en el proyecto. Esto creará una nueva carpeta `functions` donde vivirá el código de nuestro backend.
    3.  **Escribir la Cloud Function:**
        *   Crear una función (en TypeScript/JavaScript) que se dispare automáticamente cada vez que un documento de la colección `invitaciones_cuidador` sea actualizado (`onUpdate`).
    4.  **Lógica de la Función:**
        *   Dentro de la función, comprobar si el campo `estado` cambió de `pendiente` a `aceptada`.
        *   Si es así, obtener el `pacienteId` del documento de la invitación.
        *   Buscar el documento de ese paciente en la colección `users` para recuperar su `fcmToken`.
        *   Usar el Admin SDK de Firebase para construir y enviar una notificación push a ese token. El mensaje será algo como: `"[Nombre del Cuidador] ha aceptado tu invitación."`.
    5.  **Desplegar la Cloud Function:**
        *   Subir la función a los servidores de Firebase para que quede activa.

#### Tarea 2: Implementar Notificaciones Locales para Recordatorios

*   **Objetivo:** Programar recordatorios (de medicación, citas, etc.) que se muestren como una notificación local en el dispositivo del **cuidador** a la hora especificada.
*   **Pasos:**
    1.  **Identificar el Punto de Creación:**
        *   Analizar `cuidador_crear_recordatorio.dart` y `cuidador_service.dart` para encontrar el método exacto donde se guarda un nuevo recordatorio en Firestore (ej. `crearRecordatorio`).
    2.  **Ampliar el `NotificationService`:**
        *   Añadir un nuevo método: `scheduleLocalNotification(id, title, body, scheduledTime)`.
        *   Este método usará la función `zonedSchedule` de `flutter_local_notifications` para programar una notificación en una fecha y hora futuras, manejando correctamente las zonas horarias.
    3.  **Integrar la Programación de Notificaciones:**
        *   Justo después de que un recordatorio se guarde con éxito en Firestore, llamar al nuevo método `scheduleLocalNotification`.
        *   Se le pasará un ID único para la notificación (podemos usar el ID del recordatorio), el título, el cuerpo y la fecha/hora del recordatorio.
    4.  **Gestionar Actualizaciones y Eliminaciones:**
        *   **Al editar un recordatorio:** Cancelar la notificación programada anteriormente (usando su ID) y crear una nueva con la hora actualizada.
        *   **Al eliminar un recordatorio:** Cancelar la notificación programada para que ya no se muestre.

