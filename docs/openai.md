# Integración con OpenAI (Fase 11 — no implementada todavía)

## Cuándo se integra

Solo después de que funcionen: (1) simulación, (2) métricas, (3) motor de
carrera, (4) detección de eventos, (5) audio local. Ver roadmap en
[PROJECT_STATUS.md](../PROJECT_STATUS.md).

## Principio de diseño

```
datos crudos (HR, GPS, ritmo)
   → procesamiento local continuo (RunCoachCore)
   → Coach Decision Engine decide que hay un evento relevante
   → se arma un resumen estructurado (no las muestras crudas)
   → se consulta a OpenAI
   → se recibe una recomendación breve
   → se reproduce por AirPods (AVSpeechSynthesizer)
```

**No se envía cada muestra a OpenAI.** El volumen de llamadas está acotado
por el Coach Decision Engine (cooldown, deduplicación, prioridades) — la
red es un consultor puntual, no un stream continuo.

## Requisitos no negociables

- La red **nunca bloquea** el motor de carrera. Si OpenAI no responde a
  tiempo, el run sigue procesándose localmente sin esa recomendación.
- Timeout corto y explícito en la llamada a la API.
- Fallback offline: si falla la llamada, no se reproduce nada (o se usa un
  mensaje local genérico predefinido, a decidir en el diseño detallado de
  Fase 11) — nunca un crash ni un bloqueo de la UI.
- Reintentos prudentes (no reintentar agresivamente si la red está caída
  durante todo el run).
- Respuesta estructurada (JSON con campos esperados), no texto libre sin
  validar.
- Control de costo: al limitar la frecuencia de llamadas vía el Coach
  Decision Engine, el costo por carrera queda acotado por diseño.
- Control de latencia: preferir modelos rápidos y prompts cortos; medir
  tiempo de respuesta real cuando se implemente.

## Seguridad de la API key

- **Nunca en Git.** Ni en el código, ni en `project.yml`, ni en
  `codemagic.yaml` en texto plano.
- En el iPhone: Keychain.
- En Codemagic (si algún build automatizado la necesita): variable de
  entorno segura configurada en la plataforma, no en el repo.
- Ver reglas de `.gitignore` para `Secrets.swift` / `Config.local.*` /
  `.env`.

## Estado actual

No hay integración implementada. No se ha creado ninguna API key de OpenAI
para este proyecto — eso requiere una cuenta/pago y se hará solo con
autorización explícita de Vicente cuando lleguemos a la Fase 11.
