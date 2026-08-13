# Integración con OpenAI (Fase 11)

## Cuándo se integró

Después de que ya funcionaban: (1) simulación (Fase 3), (2) métricas
(Fase 2), (3) motor de carrera (Fase 2/8), (4) detección de eventos —
Coach Decision Engine (Fase 10), (5) audio local (Fase 9). Tal como estaba
previsto desde Fase 0/1.

## Principio de diseño (implementado tal cual estaba previsto)

```
datos crudos (HR, GPS, ritmo)
   → procesamiento local continuo (RunCoachCore: RunState)
   → CoachDecisionEngine decide que hay un evento relevante (.speak)
   → se arma un CoachEventSummary (resumen estructurado, no las muestras crudas)
   → OpenAICoachClient consulta a OpenAI (async, con timeout)
   → CoachRecommendation (texto breve) o nil si falla cualquier cosa
   → se reproduce por AudioCoachService (AVSpeechSynthesizer) — la
     recomendación de OpenAI si llegó a tiempo, si no, la frase fija en
     español de Fase 9-10 (ver docs/audio-coach.md para el manejo de
     sesión de audio y convivencia con música de otras apps)
```

**No se envía cada muestra a OpenAI.** El volumen de llamadas está acotado
por `CoachDecisionEngine` (cooldown de 90s, deduplicación por tipo de
evento) — en el escenario de referencia de 20 minutos, como máximo 2-3
llamadas en toda la carrera, no una por muestra.

## División de responsabilidades (mismo patrón que BLE, Fase 6)

- **`RunCoachCore`** (portable, testeado en Windows — 14 tests nuevos):
  - `CoachEventSummary` — snapshot estructurado del `RunState` en el
    instante de la decisión.
  - `OpenAIChatMessage`/`OpenAIChatRequest`/`OpenAIChatResponse` —
    tipos `Codable` que reflejan el formato de la API de OpenAI Chat
    Completions.
  - `OpenAICoachRequestBuilder` — arma el prompt (system + user) y el
    request completo a partir de un `CoachEventSummary`. Lógica pura de
    texto/JSON, sin red.
  - `OpenAICoachResponseParser` — decodifica la respuesta JSON en un
    `CoachRecommendation`, devolviendo `nil` ante cualquier forma
    inesperada en vez de lanzar.
- **`RunCoach-iOS`** (solo compilado, no verificado — sin API key ni Mac
  para probarlo):
  - `OpenAIAPIKeyStore` — Keychain, nunca texto plano.
  - `OpenAICoachClient` — el único lugar que usa `URLSession` de verdad.

## Requisitos no negociables — cómo se cumplió cada uno

- **La red nunca bloquea el motor de carrera.** `RunSessionViewModel`
  llama a `OpenAICoachClient` dentro de un `Task` separado, no dentro de
  `refresh()` (que es síncrono). El run sigue procesándose localmente sin
  esperar la respuesta.
- **Timeout corto y explícito**: `URLSessionConfiguration.timeoutIntervalForRequest`
  = 5 segundos (configurable).
- **Fallback offline**: `OpenAICoachClient.recommendation(for:)` nunca
  lanza — devuelve `nil` ante cualquier falla (sin API key, sin red,
  timeout, respuesta inesperada), y `RunSessionViewModel` cae de vuelta a
  la frase fija en español que ya existía desde Fase 9/10. Nunca un crash
  ni un bloqueo de la UI.
- **Reintentos prudentes**: un único reintento, con 1 segundo de espera,
  y solo ante fallas que tiene sentido reintentar (timeout/sin conexión,
  HTTP 429, HTTP 5xx) — nunca ante errores de autenticación (401) o
  respuestas mal formadas, que reintentar no arregla.
- **Respuesta estructurada**: `OpenAIChatResponse` (Codable), no texto
  libre sin validar — y aunque el campo `content` del modelo sí es texto
  libre generado por el LLM, el prompt del sistema le exige una frase
  corta y sin admiraciones/emojis (ver `OpenAICoachRequestBuilder.defaultSystemPrompt`).
- **Control de costo**: modelo `gpt-4o-mini` (económico), `max_tokens: 60`
  (respuestas cortas por diseño), y la frecuencia de llamadas ya acotada
  por `CoachDecisionEngine` — no hace falta ningún control adicional de
  cuota en esta etapa de un proyecto personal.
- **Control de latencia**: timeout de 5s + un reintento con backoff de 1s
  → peor caso, unos ~11s antes de caer al fallback. Sin medición real
  todavía (no hay API key ni forma de probarlo — ver "Estado actual").

## Seguridad de la API key

- **Nunca en Git.** Ni en el código, ni en `project.yml`, ni en
  `codemagic.yaml` en texto plano — confirmado, no hay ninguna key en el
  repo.
- En el iPhone: Keychain (`OpenAIAPIKeyStore`), con
  `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` — no viaja en backups a
  otros dispositivos. Se ingresa a mano en `SettingsView` (`SecureField`).
- En Codemagic: no hace falta ninguna key ahí — el build de CI no llama a
  OpenAI, solo compila.
- Ver reglas de `.gitignore` para `Secrets.swift` / `Config.local.*` /
  `.env` (sin uso todavía, pero la regla sigue ahí por si hiciera falta).

## Estado actual

**Implementado y testeado (la parte de `RunCoachCore`) — sin validar
contra la API real todavía.** No existe ninguna API key de OpenAI creada
para este proyecto: eso requiere una cuenta/pago de Vicente, con
autorización explícita — nunca se crea ni se paga de forma autónoma.

Cuando Vicente tenga una API key:

1. Pegarla en Ajustes → API key de OpenAI (queda en el Keychain del
   iPhone, no en ningún otro lado).
2. Con eso, `OpenAICoachClient` empieza a intentarse en cada evento que
   `CoachDecisionEngine` decida mencionar — sin key, sigue funcionando
   exactamente igual que antes (frases fijas), sin ningún cambio de
   comportamiento visible.
3. Validar de verdad (¿responde?, ¿en qué tiempo?, ¿tiene sentido lo que
   dice?) requiere correr la app en un iPhone real — Fases 12-14, no antes.
