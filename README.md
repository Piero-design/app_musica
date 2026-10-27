# 🎵 app_musica (Flutter)

Experiencia demo inspirada en **Apple Music (dark mode)** con catálogo amplio, filtros en sticky header, mini-reproductor, favoritos, cola, **DJ Mix** y **Radio IA** local sin credenciales externas.

## ✅ Qué está implementado

- Navegación principal: **Escuchar, DJ Mix, Radio IA, Biblioteca, Buscar**.
- **Mediator Pattern** (`MusicPlaybackMediator`) para coordinar reproducción, cola, mix y radio.
- Catálogo demo de **120 canciones** con metadata (género, BPM, segmentos).
- Filtros rápidos + búsqueda por **título, artista, álbum y BPM**.
- Favoritos en sesión (`Set<String>`).
- Mini-player y reproductor completo con:
  - play/pause, next/previous
  - seek y volumen
  - **shuffle**
  - **repeat** (`off` → `all` → `one`)
- Cola demo visible en Biblioteca (vista “up next”).
- DJ Mix con bucles por segmento y repetición configurable.
- Radio IA demo con locutor virtual y cápsulas temporizadas por duración real de cada cápsula.

## 🧱 Arquitectura breve

- `QueueHandler`: biblioteca, cola, favoritos, shuffle/repeat y entidades derivadas (artistas/álbumes/géneros).
- `SnippetLoopHandler`: lógica de mix por segmentos y bucles.
- `AiRadioHostHandler`: emisoras, cápsulas del locutor y temporización.
- `MusicPlaybackMediator`: punto único de orquestación por eventos (`PlaybackEvent`) + `ChangeNotifier` para UI.

## 🚀 Ejecutar

```bash
flutter pub get
flutter run
```

## 🧪 Calidad

```bash
flutter analyze
flutter test
```

En este entorno de automatización puede no existir Flutter SDK (`flutter: command not found`), por lo que esos comandos deben correrse localmente o en CI con Flutter instalado.

## ⚠️ Limitaciones actuales (sin backend/audio real)

- Reproducción **simulada** (sin streaming real ni archivos de audio externos).
- Radio IA y DJ Mix son experiencias demo locales.
- No se usan APIs externas ni credenciales.

## 🔜 Próximos pasos recomendados

- Persistencia local opcional de favoritos/cola (por ejemplo `shared_preferences`).
- Integrar motor de audio real (p. ej. `just_audio`) con archivos/licencias válidas.
- Expandir pruebas unitarias de handlers y mediator para casos edge adicionales.
