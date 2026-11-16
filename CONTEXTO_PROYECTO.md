# CONTEXTO COMPLETO DEL PROYECTO: APP_MUSICA (FLUTTER)

> **Documento de Traspaso Técnico de Contexto**  
> **Fecha:** 16 de Noviembre de 2026  
> **Autor / Estudiante:** Piero (4to año de Ingeniería de Sistemas - EPIS UNSA)  
> **Repositorio Oficial:** [https://github.com/Piero-design/app_musica](https://github.com/Piero-design/app_musica)  
> **Branch Principal:** `main`

---

## 1. PROPÓSITO Y OBJETIVO ACADÉMICO

El proyecto está preparado para presentarse en la **Feria de Proyectos EPIS - UNSA (Categoría II - Intermedio)** para el curso **"Introducción al Desarrollo de Nuevas Plataformas" (Android)**.

* **Título Formal para el Paper IEEE / Presentación:**  
  *"Implementación del Patrón Mediador para la Coordinación Asíncrona de Flujos Multimedia y Locución Inteligente en la Plataforma Android"*
* **Enfoque de Ingeniería:**  
  No es un simple clon de Apple Music. Es una solución de arquitectura de software para evitar el antipatrón *God Object* y condiciones de carrera al mezclar múltiples fuentes de eventos concurrentes (reproducción normal, bucles rítmicos DJ, cápsulas de voz IA e indexación de listas de alta densidad).

---

## 2. ARQUITECTURA DE SOFTWARE (PATRÓN MEDIATOR GoF)

Toda la lógica central reside en `lib/main.dart` y está estructurada en capas desacopladas mediante el **Patrón Mediador**:

```
                          +-----------------------------------+
                          |         IPlaybackMediator         |
                          |   notify(PlaybackEvent, payload)  |
                          +-----------------------------------+
                                            ^
                                            | implements
                          +-----------------------------------+
                          |       MusicPlaybackMediator       |
                          | (ChangeNotifier, Audio Sync, UI)  |
                          +-----------------------------------+
                               /            |             \
                              v             v              v
               +------------------+ +----------------+ +---------------------+
               |   QueueHandler   | |SnippetLoopHandl| | AiRadioHostHandler  |
               +------------------+ +----------------+ +---------------------+
               | - library (120)  | | - snippetLoops | | - radioStations     |
               | - queue & favs   | | - loopCount=3x | | - capsules (Tech)   |
               | - shuffle/repeat | | - beatmatch    | | - voice speechTimer |
               +------------------+ +----------------+ +---------------------+
```

### Componentes Clave:
1. **`MusicPlaybackMediator`**: Centro de coordinación único. Maneja el estado global (`isPlaying`, `mode`, `currentProgressSeconds`), sincroniza el motor de audio real (`audioplayers`) y notifica a los listeners.
2. **`QueueHandler`**: Gestiona el catálogo de 120 canciones, cálculo de listas de artistas/álbumes únicos, favoritos y modos *Repeat* (`off`, `all`, `one`) y *Shuffle*.
3. **`SnippetLoopHandler` (DJ Mix Studio)**: Permite segmentar fragmentos específicos de pistas (por ejemplo, el coro o los últimos 20 segundos) y repetir en bucle $N=3$ veces antes de orquestar la transición armónica al siguiente tema.
4. **`AiRadioHostHandler` (Radio IA)**: Simula una emisora de radio con locutor virtual inteligente (*Turing DJ* y *Ada Host*) que introduce reflexiones técnicas y de ingeniería de sistemas sin colapsar el hilo de UI ni interrumpir abruptamente el reproductor.

---

## 3. UI/UX Y ADAPTACIÓN ERGONÓMICA EN ANDROID

1. **Buscador Sticky con Safe Area Dinámico**:  
   Implementado con `_PlaylistSearchStickyHeaderDelegate` usando `MediaQuery.paddingOf(context).top`.  
   * **Ventaja crítica en Android**: Evita que la barra de estado, el reloj (`9:25`) y el corte de cámara frontal (*punch-hole*) tapen la barra de búsqueda y bloqueen los toques (problema que se resolvió y validó en Android 13 Funtouch OS).
2. **Búsqueda Dual**:
   * *Búsqueda Local en Playlist (Sticky Header)*: Filtro en tiempo real por título, artista, BPM y chips de categorías sobre las 120 canciones sin salir de la vista.
   * *Búsqueda Global (Tab Buscar)*: Búsqueda independiente con chips de filtro adicionales.
3. **Barra de Navegación Flotante**: Estilo *floating pill dock* con desenfoque de vidrio esmerilado (*glassmorphism*) y mini-reproductor interactivo.

---

## 4. ESTADO ACTUAL DEL CÓDIGO Y ASSETS

### Dependencias (`pubspec.yaml`):
* `audioplayers: ^6.8.1` (integrado y funcionando para audio real).
* `shared_preferences: ^2.5.6` (para persistencia).
* `cupertino_icons: ^1.0.8`.

### Assets de Audio Locales (`assets/audio/`):
* `assets/audio/synthwave_beat.wav`: Música real a 120 BPM con bombo, arpegios y bajo.
* `assets/audio/host_speech.wav`: Audio real de locución con voz humana sintetizada en español (*"Hola ingenieros de sistemas. Bienvenidos a Radio Dev..."*).

### Documentación Académica Creada:
* `ARTICULO_IEEE_FERIA_EPIS.md`: Paper completo de 4 páginas en formato IEEE con Resumen, Abstract, Introducción, Estado del Arte, Arquitectura, Pruebas y Referencias bibliográficas, listo para presentar a la comisión de la EPIS - UNSA.

### Pruebas de Software:
* `test/widget_test.dart`: 2 baterías de tests automatizados que cubren el Mediador, el locutor IA, el DJ Mix y la búsqueda/reproducción completa.

---

## 5. HISTORIAL DE COMMITS Y SINCRONIZACIÓN

Todo está respaldado y sincronizado con el repositorio GitHub:
* **`806d7ca`**: *feat: integrate real audio assets and audioplayers into Mediator with IEEE paper*
* **`f7b0d10`**: *fix: resolve syntax error on search tab filter chips return statement*
* **`4f01f3b`**: *Merge pull request #1 from Piero-design/copilot/complete-functional-music-app*

---

## 6. COMANDOS BÁSICOS PARA EL NUEVO IDE / TERMINAL

```bash
# 1. Verificar estado de dependencias
flutter pub get

# 2. Correr análisis de código (debe dar 0 issues)
flutter analyze

# 3. Correr las pruebas unitarias y de widgets (debe pasar 100%)
flutter test

# 4. Ver dispositivos disponibles (Android / iOS / macOS)
flutter devices

# 5. Ejecutar en tu Android físico (vivo V2057 / Funtouch OS):
flutter run -d <ID_DEL_DISPOSITIVO>
# o en modo release:
flutter run --release
```

---

## 7. DISPOSITIVOS PROBADOS

* **Android Físico:** vivo V2057 (Android 13 / Funtouch OS 13 Global, API 33).
* **Emulador Android:** Pixel 8a (API 34/37).
* **iOS:** iPhone de Piero (iOS 17/18 con Developer Mode y firma de equipo personal).
