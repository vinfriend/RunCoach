# Audio Coach: convivencia con música de otras apps

> **Requisito permanente del producto**, no de una fase puntual. Registrado
> el 2026-08-12 a pedido explícito de Vicente. Aplica a todo trabajo de
> audio futuro, incluida la prueba real en iPhone (Fase 13+).

## Requisito

Durante una carrera, el usuario debe poder escuchar música normalmente
desde Spotify, YouTube Music, Apple Music o cualquier otra app de audio
compatible con iOS — RunCoach debe seguir monitoreando FC/GPS/ritmo/
distancia/tiempo/eventos sin interrupción, y solo debe tocar el audio
cuando el coach realmente tiene algo que decir:

```
música normal
  → el coach detecta que debe hablar
  → la música de otras apps baja de volumen (duck)
  → RunCoach dice el mensaje, claro, por la salida activa (incluye AirPods)
  → termina el mensaje
  → la música vuelve a su volumen normal
  → RunCoach sigue monitoreando la carrera sin cortes
```

Es, a propósito, el mismo patrón que usan las apps de navegación GPS
(Google Maps, Waze) al dar indicaciones sobre música — Apple documenta
exactamente esta combinación de APIs para ese caso de uso (ver
"Fuentes" más abajo).

**Explícitamente fuera de alcance**: pausar/reanudar Spotify u otras apps
de forma directa, controlarlas mediante SDKs propios, o cualquier
integración específica de proveedor. La solución es genérica a nivel de
sistema operativo (`AVAudioSession`), no depende de qué app esté sonando.

## Arquitectura

```
CoachDecisionEngine (RunCoachCore)
  → CoachEvent                          [sin idioma, sin audio]
  → texto en español                     (RunSessionViewModel)
  → CoachMessage                         (RunCoach-iOS/App/Audio/)
  → AudioCoachService                    (RunCoach-iOS/App/Audio/)
  → AVAudioSession + AVSpeechSynthesizer
  → salida de audio activa (altavoz, AirPods, lo que iOS elija)
```

`RunCoachCore` (`CoachDecisionEngine`, `CoachEventDetector`, `RunState`)
sigue sin saber absolutamente nada de audio — el límite de responsabilidad
no cambió respecto a la Fase 9/10 original, solo se hizo explícito con el
tipo `CoachMessage` como frontera entre "qué evento pasó" y "cómo se dice y
se reproduce".

**El Run Data Engine nunca depende del estado del audio.** `AudioCoachService.speak(_:)`
no devuelve ningún valor que `RunSessionViewModel` necesite para seguir
funcionando, y toda llamada a `AVAudioSession`/`AVSpeechSynthesizer` está
envuelta en `try?` — si la sesión de audio falla por cualquier motivo (otra
app la tiene tomada de forma incompatible, un estado raro del sistema), la
frase simplemente no se dice, pero GPS, frecuencia cardíaca, métricas y la
lógica del coach siguen corriendo exactamente igual. Nunca hay una ruta de
código donde una falla de audio interrumpa o bloquee la carrera.

## Diseño de `AudioCoachService`

Implementado en
[`RunCoach-iOS/App/Audio/AudioCoachService.swift`](../RunCoach-iOS/App/Audio/AudioCoachService.swift)
(reemplaza al `AudioCoach` de Fase 9).

### Categoría, modo y opciones de `AVAudioSession`

```swift
try? session.setCategory(.playback, mode: .voicePrompt, options: [.duckOthers])
try? session.setActive(true)
```

- **`.playback`**: categoría que permite sonar con la pantalla bloqueada y
  el switch de silencio activado — necesaria para que el coach se escuche
  en cualquier momento de la carrera.
- **`.voicePrompt`**: modo documentado por Apple específicamente para apps
  que "reproducen audio usando texto a voz" en el contexto de indicaciones
  cortas sobre otro audio en reproducción (el caso de uso textual de
  navegación GPS, aplicable acá sin cambios).
- **`.duckOthers`**: baja el volumen de otras apps mientras nuestro audio
  suena. Solo se puede usar con categoría `.playback`, `.playAndRecord` o
  `.multiRoute` (documentado), y **activa `.mixWithOthers` implícitamente**
  — no hace falta agregarlo aparte.
- **A propósito NO se usa** `.interruptSpokenAudioAndMixWithOthers`: esa
  opción *pausa* contenido hablado de otras apps (podcasts, audiolibros) en
  vez de solo bajarle el volumen — más invasivo de lo que el requisito
  pide ("no interrumpir salvo razón técnica muy fuerte"). `.duckOthers`
  solo, sin esa opción, alcanza para música (Spotify/YouTube Music/Apple
  Music), que es el caso de uso descrito.

### Activar y desactivar solo alrededor de cada frase

**El hallazgo más importante de la investigación**: `AVSpeechSynthesizer`
activa la sesión de audio por su cuenta al hablar, pero **no la desactiva
sola** al terminar — es un comportamiento documentado, no un bug de este
proyecto. Si no se desactiva la sesión a mano, la música de otras apps
quedaría "duckeada" (a volumen bajo) para siempre después de la primera
frase, nunca recuperando su volumen normal.

Por eso `AudioCoachService` lleva la cuenta de cuántas frases están en cola
o hablándose (`pendingUtterances`) usando el delegate de
`AVSpeechSynthesizer` (`didFinish`/`didCancel`), y solo cuando ese contador
llega a cero desactiva la sesión:

```swift
try? session.setActive(false, options: [.notifyOthersOnDeactivation])
```

`.notifyOthersOnDeactivation` es lo que le avisa al sistema (y de ahí a la
app de música bien portada) que puede volver a subir su volumen. Llevar la
cuenta de frases pendientes (en vez de desactivar después de cada
`didFinish` individual) evita que la sesión "parpadee" (desactivar y
reactivar) si dos mensajes llegan casi juntos — por ejemplo, un split
completado justo cuando el Coach Decision Engine también decide hablar.

### Interrupciones (llamada, Siri, alarma, otra app)

Una interrupción real (llamada entrante, Siri, alarma) hace que **iOS
desactive nuestra sesión por su cuenta**, sin pasar por nuestro código de
desactivación normal. `AudioCoachService` escucha
`AVAudioSession.interruptionNotification`: al recibir `.began`, resetea
`pendingUtterances` a cero para no quedar con el contador desincronizado
(cualquier frase en curso ya fue cortada por el sistema, y su callback
`didFinish`/`didCancel` puede no llegar de forma confiable).

**No hace falta reintentar la frase interrumpida ni reactivar nada a
mano**: el diseño no mantiene la sesión activa de forma permanente — cada
`speak(_:)` la reactiva desde cero. Así que el próximo evento real del
coach (el próximo split, la próxima decisión de `CoachDecisionEngine`)
simplemente vuelve a activar la sesión y habla con normalidad, sin ningún
estado especial de "recuperación" que mantener.

### Cambios de ruta de audio (AirPods)

`AudioCoachService` también escucha `AVAudioSession.routeChangeNotification`
(conectar/desconectar AirPods, cambiar a altavoz, etc.). El handler existe
para dejar documentado que el caso se consideró, pero **no hace nada
activamente**: `AVSpeechSynthesizer` sigue hablando por la salida que iOS
elija en cada momento, que es exactamente el comportamiento correcto (no
hay ninguna razón para que la app intervenga manualmente en el enrutamiento
de audio del sistema).

## `CoachMessage`

```swift
struct CoachMessage: Equatable {
    let text: String
}
```

Tipo mínimo a propósito — el único dato que `AudioCoachService` necesita
hoy es el texto ya armado en español. Si en el futuro hiciera falta
prioridad explícita entre mensajes o más metadata, se extiende acá sin
tocar `RunCoachCore` ni `AudioCoachService` por dentro.

## Qué NO cambia

- `RunCoachCore` (`CoachEvent`, `CoachEventDetector`, `CoachDecisionEngine`)
  no se toca — el arbitraje de prioridad entre eventos (Fase post-19,
  `.deteriorating`) sigue viviendo ahí, sin ninguna relación con cómo se
  reproduce el audio.
- La traducción de `CoachEvent` a texto en español sigue en
  `RunSessionViewModel.spokenText(for:)` — no se movió.
- El cooldown/deduplicación de *cuándo* vale la pena hablar sigue siendo
  responsabilidad exclusiva de `CoachDecisionEngine`; `AudioCoachService`
  no decide nada, solo reproduce lo que se le pasa.

## Testing

### Lo que se puede testear sin iOS real

Muy poco: toda la lógica nueva depende de `AVAudioSession`/
`AVSpeechSynthesizer`, exclusivos de Apple — no compilan en Windows, así
que no hay tests de `swift test` para `AudioCoachService` (igual que ya
pasaba con `AudioCoach` desde Fase 9, y con `BLEHeartRateSource`/
`GPSLocationSource`). `RunCoachCore` no cambió en este trabajo, así que sus
93 tests existentes siguen siendo la cobertura automática relevante — ver
[docs/testing.md](testing.md).

Lo único verificable sin hardware es que el código **compile** en CI
(Codemagic) y que la lógica de conteo (`pendingUtterances`, cuándo
desactivar) sea correcta por inspección — no hay forma de simular
`AVAudioSession` ni sus notificaciones sin un runtime de iOS real.

### Checklist de pruebas reales en iPhone (pendiente — requiere hardware, Fase 13+)

Ninguno de estos escenarios se puede confirmar sin un iPhone físico. Quedan
documentados acá como criterio de aceptación para cuando exista hardware
real, no como algo ya validado.

1. **Spotify reproduciendo** → el coach habla → la música baja de volumen
   → el mensaje se escucha claro → la música vuelve a su volumen normal
   al terminar.
2. **YouTube Music reproduciendo** → mismo comportamiento que el escenario 1.
3. **Apple Music reproduciendo** → mismo comportamiento que el escenario 1.
4. **AirPods conectados**: música y voz del coach salen por los AirPods sin
   diferencia audible de calidad respecto al altavoz del iPhone.
5. **AirPods desconectados durante una carrera en curso**: el audio pasa al
   altavoz del iPhone (o a donde iOS decida) sin que la app se rompa ni dejen
   de registrarse FC/GPS.
6. **Llamada entrante (o Siri/alarma) durante una carrera**: la interrupción
   se resuelve sin que la app quede en un estado raro; después de colgar,
   el coach vuelve a poder hablar con normalidad en su próxima intervención.
7. **Pantalla bloqueada**: el coach sigue hablando y el ducking de música
   sigue funcionando igual que con la pantalla desbloqueada.
8. **Varias intervenciones del coach separadas por cooldown** (por ejemplo,
   un split completado seguido poco después de un evento
   `.effortRising`/`.deteriorating`): la música no debería "parpadear"
   (bajar y subir de volumen en un flash) entre una intervención y la
   siguiente si están muy próximas, y debe volver a su volumen normal una
   sola vez al final, no entre frase y frase.

## Fuentes (documentación oficial de Apple, consultada 2026-08-12)

- [`AVAudioSession.Mode.voicePrompt`](https://developer.apple.com/documentation/avfaudio/avaudiosession/mode/2962803-voiceprompt) —
  modo para apps que reproducen audio usando texto a voz.
- [`AVAudioSession.CategoryOptions.duckOthers`](https://developer.apple.com/documentation/avfaudio/avaudiosession/categoryoptions/1616618-duckothers) —
  reduce el volumen de otras sesiones de audio mientras suena la propia;
  solo válido con `.playback`/`.playAndRecord`/`.multiRoute`; activa
  `.mixWithOthers` implícitamente.
- Guía de Apple para apps de navegación en CarPlay: categoría `.playback`,
  modo `.voicePrompt`, `.duckOthers` (+ `.interruptSpokenAudioAndMixWithOthers`
  en el caso específico de CarPlay, no usado acá — ver la nota en la
  sección de opciones más arriba sobre por qué se dejó afuera).
- Comportamiento documentado (Apple Developer Forums, confirmado contra
  código fuente de apps reales) de que `AVSpeechSynthesizer` activa la
  sesión de audio automáticamente pero no la desactiva — de ahí la
  necesidad del manejo explícito de `pendingUtterances` +
  `setActive(false, options: .notifyOthersOnDeactivation)` en
  `AudioCoachService`.
