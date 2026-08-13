# Audio Coach: convivencia con música de otras apps y salida de audio genérica

> **Dos requisitos permanentes del producto**, no de una fase puntual.
> Registrados el 2026-08-12 a pedido explícito de Vicente. Aplican a todo
> trabajo de audio futuro, incluida la prueba real en iPhone (Fase 13+).
>
> 1. La música de otras apps sigue sonando con normalidad; el coach solo
>    la baja de volumen mientras habla (ver "Requisito: ducking" abajo).
> 2. RunCoach no depende de AirPods ni de ninguna marca/modelo de
>    auricular — funciona con cualquier salida de audio que iOS tenga
>    activa (ver "Requisito: salida de audio genérica" abajo).

## Requisito: ducking, no interrupción

Durante una carrera, el usuario debe poder escuchar música normalmente
desde Spotify, YouTube Music, Apple Music o cualquier otra app de audio
compatible con iOS — RunCoach debe seguir monitoreando FC/GPS/ritmo/
distancia/tiempo/eventos sin interrupción, y solo debe tocar el audio
cuando el coach realmente tiene algo que decir:

```
música normal
  → el coach detecta que debe hablar
  → la música de otras apps baja de volumen (duck)
  → RunCoach dice el mensaje, claro, por la salida de audio activa
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

## Requisito: salida de audio genérica, no AirPods

RunCoach **no debe depender específicamente de AirPods**. Debe funcionar
con cualquier salida de audio que iOS tenga activa en cada momento —
AirPods, auriculares Bluetooth de cualquier marca, auriculares con cable,
adaptadores compatibles, parlantes Bluetooth, o el altavoz del propio
iPhone si no hay nada conectado.

**Principio de diseño**: la arquitectura NO es

```
RunCoach → AirPods
```

sino

```
RunCoach → AVAudioSession → ruta de audio activa administrada por iOS
```

`AudioCoachService` nunca controla, detecta ni asume un dispositivo de
audio específico — no hay lógica de marca/modelo salvo que exista una
limitación técnica concreta que lo justifique (hoy no existe ninguna). Toda
decisión de "qué salida física usar en este momento" queda exclusivamente
en manos de iOS.

**Fallback**: si no hay ningún auricular conectado, el coach se reproduce
igual por la salida normal disponible del iPhone (el altavoz integrado),
salvo que iOS indique otra cosa — no hace falta ningún código especial
para esto, es el comportamiento por defecto de `AVAudioSession` cuando no
se fuerza una ruta.

**Cambios de ruta no detienen nada del Run Data Engine**: conectar,
desconectar o cambiar de dispositivo de audio en medio de una carrera
nunca pausa ni interrumpe la carrera, el GPS, la frecuencia cardíaca, el
Run Data Engine ni el Coach Decision Engine — esos cuatro son
completamente independientes del estado del audio (ver "El Run Data
Engine nunca depende del estado del audio" más abajo, ya cierto desde el
diseño original de `AudioCoachService`).

## Arquitectura

```
CoachDecisionEngine (RunCoachCore)
  → CoachEvent                          [sin idioma, sin audio]
  → texto en español                     (RunSessionViewModel)
  → CoachMessage                         (RunCoach-iOS/App/Audio/)
  → AudioCoachService                    (RunCoach-iOS/App/Audio/)
  → AVAudioSession + AVSpeechSynthesizer
  → ruta de audio activa administrada por iOS
     (altavoz, AirPods, otro Bluetooth, cable — lo que esté conectado)
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

### Cambios de ruta de audio (cualquier dispositivo, no solo AirPods)

`AudioCoachService` también escucha `AVAudioSession.routeChangeNotification`
— cubre conectar/desconectar AirPods, cualquier otro auricular Bluetooth,
un parlante Bluetooth, auriculares con cable, o pasar al altavoz del
iPhone. El handler existe para dejar documentado que el caso se consideró
(incluyendo los motivos que expone `AVAudioSession.RouteChangeReason`:
`.newDeviceAvailable`, `.oldDeviceUnavailable`, `.categoryChange`,
`.override`, `.wakeFromSleep`, `.noSuitableRouteForCategory`,
`.routeConfigurationChange`), pero **no hace nada activamente** para
ninguno de esos casos: `AVSpeechSynthesizer` sigue hablando por la salida
que iOS elija en cada momento, que es exactamente el comportamiento
correcto — no hay ninguna razón técnica para que la app fuerce una ruta
concreta o intervenga manualmente en el enrutamiento del sistema. Esto
incluye el caso de pérdida temporal de conexión Bluetooth y su
reconexión: iOS reenruta solo, sin que `AudioCoachService` ni el resto de
la app necesiten reaccionar.

**Nada de esto detiene la carrera.** Ni una interrupción ni un cambio de
ruta tocan `RunState`, `CoachDecisionEngine` ni las fuentes de datos
(`BLEHeartRateSource`/`GPSLocationSource`) — esas piezas ni se enteran de
que el audio cambió de ruta, porque nunca dependieron de él (ver "El Run
Data Engine nunca depende del estado del audio" arriba). Si en algún
momento fallara la reproducción de una frase por un problema de audio, el
error queda contenido en `AudioCoachService` (el `try?` ya lo absorbe) y
la próxima intervención del coach simplemente lo vuelve a intentar desde
cero — no hace falta ningún mecanismo de reintento explícito porque cada
`speak(_:)` ya parte de cero.

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
real, no como algo ya validado. AirPods aparece como **un caso de prueba
entre varios**, nunca como el único escenario válido — la lista cubre
deliberadamente auriculares de otras marcas, cable, parlante Bluetooth, y
"sin nada conectado", para confirmar que no hay ninguna dependencia oculta
de una marca en particular.

**Ducking / convivencia con música:**

1. **Spotify reproduciendo** → el coach habla → la música baja de volumen
   → el mensaje se escucha claro → la música vuelve a su volumen normal
   al terminar.
2. **YouTube Music reproduciendo** → mismo comportamiento que el escenario 1.
3. **Apple Music reproduciendo** → mismo comportamiento que el escenario 1.

**Salida de audio (A–J, independencia de AirPods):**

- **A — AirPods**: música y voz del coach salen por los AirPods sin
  diferencia audible de calidad respecto al altavoz del iPhone.
- **B — Auriculares Bluetooth de otra marca** (no Apple): mismo
  comportamiento que el escenario A — confirma que no hay ninguna ruta de
  código que asuma AirPods específicamente.
- **C — Altavoz del iPhone** (sin nada conectado): el coach se escucha con
  normalidad por el altavoz integrado, sin necesidad de ninguna
  configuración especial.
- **D — Auriculares Bluetooth se desconectan durante una carrera en
  curso**: el audio pasa al altavoz del iPhone (o a donde iOS decida) sin
  que la app se rompa ni dejen de registrarse FC/GPS/splits/eventos del
  coach.
- **E — Los auriculares se reconectan durante la misma carrera**: el
  coach vuelve a hablar por ellos con normalidad en su próxima
  intervención, sin necesidad de reiniciar la carrera ni la app.
- **F — Cambio de una salida Bluetooth a otra** (por ejemplo, de AirPods a
  un parlante Bluetooth, o a otro auricular) en medio de la carrera: iOS
  reenruta solo, sin que la app intervenga ni se rompa.
- **G — Spotify + auriculares Bluetooth genéricos (no AirPods) + coach**:
  ducking y voz del coach funcionan igual que con AirPods.
- **H — YouTube Music + auriculares Bluetooth genéricos (no AirPods) +
  coach**: mismo comportamiento que el escenario G.
- **I — Música reproduciéndose y cambio de ruta de audio durante una
  intervención del coach** (por ejemplo, se desconectan los auriculares
  mientras el coach está hablando): el mensaje no debería dejar a la app
  en un estado roto — en el peor caso, el mensaje se corta y la próxima
  intervención del coach vuelve a funcionar con normalidad por la nueva
  ruta.
- **J — Sin auriculares conectados desde el inicio de la carrera**: el
  coach usa el altavoz del iPhone sin ningún error ni comportamiento
  distinto al resto de los escenarios.

**Interrupciones y contexto del sistema:**

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
- [`AVAudioSession.RouteChangeReason`](https://developer.apple.com/documentation/avfaudio/avaudiosession/routechangereason) —
  los motivos documentados por los que cambia la ruta de audio
  (`.newDeviceAvailable`, `.oldDeviceUnavailable`, `.categoryChange`,
  `.override`, `.wakeFromSleep`, `.noSuitableRouteForCategory`,
  `.routeConfigurationChange`); ninguno requiere acción manual de la app
  en este diseño — es la base de por qué `handleRouteChange` es
  intencionalmente un no-op.
