# GymProgress (Flutter, Android)

## Compilar el APK — opción A (sin instalar nada): GitHub Actions
1. Crea un repositorio en github.com y sube TODO el contenido de esta carpeta (incluida `.github/`).
2. Pestaña **Actions** → "Build APK" → **Run workflow** (también corre solo al hacer push).
3. Al terminar (~5 min), abre la ejecución y descarga el artefacto **GymProgress-APK** (zip con `app-release.apk`).

## Compilar — opción B (local)
```
flutter create --platforms=android --project-name gymprogress --org com.gymprogress .
flutter pub get
flutter test
flutter build apk --release
```
APK: `build/app/outputs/flutter-apk/app-release.apk`

## Instalar en el teléfono
Copia el APK al móvil → ábrelo → permite "instalar apps desconocidas" para el gestor de archivos → Instalar.
O por USB: `adb install app-release.apk`.

## Uso rápido
Inicio: crea perfil y elige usuario (o Ajustes → datos de demostración) → Entrenar: añade ejercicio, series (reps/kg/descanso independientes), Guardar → Historial: toca para ver detalle, papelera para borrar → Progreso: elige ejercicio y mira las gráficas (toca un punto para ver el valor).

## Permisos Android
Ninguno. Sin Internet. "Compartir" usa el menú nativo de Android.

## Implementado
Perfiles locales, biblioteca de 20 ejercicios + creación de ejercicios, sesiones con series independientes, validación (sin negativos, 0 kg permitido), duplicar/eliminar series, series sugeridas editables, temporizador de descanso con alerta sonora/vibración, historial con detalle y borrado con confirmación, dashboard, 3 gráficas por ejercicio, exportar CSV y JSON, datos demo, SQLite con FK/índices/CHECK, tests de volumen.

## Pendiente (no implementado)
Editar sesiones guardadas, reordenar series/ejercicios, calendario, filtros por fechas/grupo muscular, gráficas de frecuencia semanal y comparación entre usuarios, exportar .xlsx, importar JSON, editar ejercicios/grupo al crearlos, notificación con la app en segundo plano, tests de persistencia en BD.
