# 🎵 Apple Music Experience (Flutter)

Aplicación móvil de música de alto rendimiento inspirada en el diseño moderno de **Apple Music (Dark Mode)**, desarrollada en **Flutter** con arquitectura desacoplada basada en el **Patrón Mediador (Mediator Pattern)**.

---

## ✨ Características Principales

1. **Patrón Mediador (`MusicPlaybackMediator`)**:
   - Desacoplamiento total entre componentes:
     - `QueueHandler`: Gestión de catálogo, cola de reproducción y favoritos.
     - `SnippetLoopHandler`: Motor de mezcla DJ, segmentación de fragmentos virales y bucles 3x con sincronización de BPM.
     - `AiRadioHostHandler`: Emisora de Radio continua con locutor virtual inteligente (Turing DJ) que introduce reflexiones y cápsulas técnicas para Ingeniería de Sistemas.

2. **Buscador y Filtro Inteligente en Playlist (Sticky Header)**:
   - Cabecera fija con efecto vidrio esmerilado (*glassmorphism blur*) que se mantiene visible al scrollear.
   - Protección dinámica frente al notch, Dynamic Island (iOS) y barra de estado / punch-hole (Android) mediante `MediaQuery.paddingOf(context).top`.
   - Filtro instantáneo por texto (título, artista, álbum, BPM) y chips de categorías (`Todas`, `Favoritas ⭐`, `Focus Tech`, `Electrónica`, `Synthwave`, `Pop`, `Rock`, `Urbano`, `Hip-Hop`, `BPM > 120`).
   - Botón flotante de retorno rápido al inicio `[ 🔍 Buscar en lista | ⬆️ ]`.

3. **Catálogo Extendido (120+ Canciones)**:
   - Conjunto realista y diverso de más de 120 canciones de prueba distribuidas en múltiples géneros musicales para verificar el comportamiento de listas extensas.

4. **Navegación Flotante Moderna**:
   - Barra de menú inferior estilo pastilla flotante (*floating pill dock*) con micro-animaciones, sombras y desenfoque translúcido.
   - Mini-reproductor interactivo flotante con controles rápidos y acceso directo.

---

## 🚀 Cómo Ejecutar el Proyecto

### Requisitos
- Flutter SDK (3.x o superior)
- Xcode (para simulador / dispositivo iOS)
- Android Studio / Android SDK (para emulador o dispositivo Android)

### Comandos

```bash
# Obtener dependencias
flutter pub get

# Ejecutar pruebas unitarias y de widgets
flutter test

# Ejecutar análisis de código
flutter analyze

# Iniciar la aplicación
flutter run
```

---

## 🛠️ Tecnologías y Arquitectura
- **Framework**: Flutter / Dart
- **Arquitectura**: Mediator Pattern (Event-driven notification system)
- **UI/UX**: Custom sliver headers, BackdropFilter, Cupertino & Material Design tokens.
