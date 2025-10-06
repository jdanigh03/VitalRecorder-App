# Funcionalidad de Perfil de Usuario

## Descripción
Se ha implementado una pantalla completa de perfil de usuario que permite editar toda la información personal y configuraciones usando datos de ejemplo (placeholder). Los datos se manejan localmente sin conexión a Cloud Firestore para propósitos de demostración.

## Archivos Creados/Modificados

### Nuevos Archivos:
1. **`lib/models/user.dart`** - Modelo de datos para el usuario
2. **`lib/services/user_service.dart`** - Servicio para operaciones con Firestore
3. **`lib/screens/perfil_usuario.dart`** - Pantalla de edición de perfil

### Archivos Modificados:
1. **`lib/screens/ajustes.dart`** - Integración de navegación al perfil
2. **`lib/screens/welcome.dart`** - Muestra el nombre real del usuario

## Estructura de Datos

La estructura de datos implementada sigue exactamente el formato especificado:

```json
{
  "email": "usuario@gmail.com",
  "persona": {
    "nombres": "Usuario",
    "apellidos": "",
    "fecha_nac": "2003-12-15T04:00:00.000Z",
    "sexo": null
  },
  "role": "user",
  "settings": {
    "familiar_email": null,
    "intensidad_vibracion": 2,
    "modo_silencio": false,
    "notificar_a_familiar": false,
    "telefono": "78822909"
  },
  "createdAt": "2025-09-02T21:14:49.000Z"
}
```

## Funcionalidades Implementadas

### Información Personal
- **Nombres**: Campo requerido para nombres del usuario
- **Apellidos**: Campo opcional para apellidos
- **Fecha de nacimiento**: Selector de fecha con calendario
- **Sexo**: Dropdown con opciones: Masculino, Femenino, Otro, Prefiero no decir

### Información de Contacto  
- **Teléfono**: Campo requerido con validación de longitud mínima
- **Email del familiar/cuidador**: Campo opcional con validación de formato email

### Configuraciones
- **Intensidad de vibración**: Slider de 0 a 5 niveles
- **Modo silencio**: Switch para desactivar sonidos
- **Notificar a familiar**: Switch para enviar notificaciones al familiar

### Información de Cuenta
- Display del email de la cuenta
- Fecha de creación de la cuenta
- Información de solo lectura

## Características Técnicas

### Validaciones
- Campos requeridos: nombres y teléfono
- Validación de formato email para familiar
- Validación de longitud mínima para teléfono (8 dígitos)

### UI/UX
- Diseño consistente con el tema de la aplicación
- Secciones organizadas en cards
- Estados de loading y guardado
- Mensajes de éxito y error con SnackBars
- Botón flotante para guardar cambios
- Icono de guardado en la AppBar

### Manejo de Datos
- Carga automática de datos de ejemplo al abrir la pantalla
- Simulación de guardado con delay realista
- Los datos se imprimen en consola al guardar (para debug)
- Validación completa de formularios sin dependencia externa

### Navegación
- Integrada en la pantalla de Ajustes
- Reemplaza el mensaje "Función en desarrollo"
- Navegación con `Navigator.push()` para mantener el stack

## Flujo de Usuario

1. **Acceso**: Usuario navega a Ajustes → Perfil de usuario
2. **Carga**: La pantalla carga datos de ejemplo con animación de loading
3. **Edición**: Usuario modifica campos según necesite
4. **Validación**: Sistema valida datos antes de guardar
5. **Guardado**: Simulación de guardado con feedback visual
6. **Confirmación**: Usuario recibe confirmación de éxito y datos se muestran en consola

## Manejo de Estados

### Loading States
- Pantalla completa de loading al cargar datos iniciales
- Indicador en botones durante guardado
- Deshabilitación de controles durante operaciones async

### Error Handling
- Manejo de errores de red
- Validación de formularios
- Mensajes de error específicos para cada tipo de problema

### Success States
- Confirmación visual al guardar exitosamente
- Actualización del estado local tras guardado exitoso
- Reflexión de cambios en otras pantallas (welcome screen)

## Datos de Ejemplo Soportados

El sistema maneja todos los campos del ejemplo proporcionado:
- Timestamps para fechas (createdAt, fecha_nac)
- Campos anidados (persona, settings)
- Valores null para campos opcionales
- Diferentes tipos de datos (string, number, boolean, timestamp)

## Consideraciones de Desarrollo

### Dependencias Utilizadas
- `intl` para formateo de fechas
- Flutter material design para UI components
- Datos locales de ejemplo (sin dependencias externas)

### Patrones Implementados
- Separación de modelos, servicios y UI
- Patrón Repository con UserService
- Manejo asíncrono con Future/async-await
- State management con StatefulWidget

### Buenas Prácticas
- Validación tanto en cliente como preparación para servidor
- Manejo de memoria con dispose() de controladores
- Optimización de rebuilds con estado local
- Accesibilidad con labels descriptivos
