# Hardware — sensor de frecuencia cardíaca

Estado: **investigación completada (Fase 1)**. No se ha comprado ningún
dispositivo — eso queda pendiente de decisión de Vicente y no se autoriza
ninguna compra automáticamente.

## Requisito técnico no negociable

El sensor debe exponer el **Bluetooth Heart Rate Service estándar**:

- Service UUID `0x180D` (Heart Rate)
- Characteristic UUID `0x2A37` (Heart Rate Measurement, con notificaciones)

Cualquier dispositivo que cumpla esto es compatible con `BLEHeartRateSource`
sin código específico de marca, gracias a la abstracción `HeartRateSource`
(ver [docs/architecture.md](architecture.md)).

## Hallazgos por dispositivo

### WHOOP (pulsera sin pantalla)

- **Sí soporta** el Bluetooth Heart Rate Service estándar (0x180D), pero
  **no por defecto**: hay que activar "HR Broadcast" en Device Settings
  dentro de la app de WHOOP.
- Con Broadcast activado, cualquier app de terceros que hable BLE HR
  estándar (incluida una app propia con CoreBluetooth) puede leer el BPM en
  vivo — es el mismo mecanismo que usan Peloton, Zwift, Wahoo, Garmin.
- Encaja con el requisito de "pulsera sin pantalla".
- Pendiente de validar en la práctica (Fase 14): latencia real, estabilidad
  de la conexión, comportamiento si la app WHOOP no está abierta en
  background.
- Fuente: [WHOOP Support — Heart Rate Broadcast](https://support.whoop.com/s/article/Heart-Rate-Broadcast).

### Polar H10 (banda de pecho) / Polar Verity Sense (brazalete, sin pantalla)

- Cumplen el perfil BLE HR estándar de forma nativa, sin necesidad de activar
  nada — es su modo de fábrica.
- Verity Sense es brazalete óptico sin pantalla, coincide con "pulsera sin
  pantalla"; H10 es banda de pecho (más precisión, menos cómodo).
- Ampliamente compatibles con apps de terceros en iOS (Strava, Nike, etc.),
  no solo con el ecosistema Polar.

### Garmin HRM-Dual / HRM-Pro

- Soportan Bluetooth + ANT+ simultáneo, perfil BLE HR estándar.
- Banda de pecho, no brazalete/pulsera.

### Scosche Rhythm24 / Rhythm+ 2.0 (brazalete, sin pantalla)

- Brazalete óptico, dual ANT+ / Bluetooth Smart, perfil estándar.
- Encaja con "pulsera sin pantalla"; alternativa más económica a Polar
  Verity Sense.

## Comparación rápida (según lo investigado, sin pruebas propias todavía)

| Dispositivo | Forma | BLE HR estándar | Requiere activar broadcast | Notas |
|---|---|---|---|---|
| WHOOP (4.0 / MG) | Pulsera sin pantalla | Sí | Sí (toggle en la app) | Ya la tenés en el radar del usuario; validar antes de confiar en ella |
| Polar Verity Sense | Brazalete sin pantalla | Sí | No | Referencia de la industria en precisión óptica |
| Scosche Rhythm24 | Brazalete sin pantalla | Sí | No | Opción más económica |
| Polar H10 | Banda de pecho | Sí | No | Mayor precisión (ECG), menos cómoda para uso diario |
| Garmin HRM-Dual/Pro | Banda de pecho | Sí | No | Buena si ya hay ecosistema Garmin |

## Decisión pendiente

No se recomienda comprar hardware todavía. El plan es:

1. Terminar RunCoachCore + Simulation Engine (Fases 2–3) usando
   `MockHeartRateSource`.
2. Cuando el proyecto llegue a Fase 6 (BLE), implementar `BLEHeartRateSource`
   contra el perfil estándar y probarlo primero con cualquier sensor BLE HR
   disponible (si Vicente ya tiene WHOOP, activar Broadcast y probar ahí
   primero — costo cero).
3. Solo si WHOOP resulta insuficiente en la práctica (latencia, estabilidad,
   requiere la app de WHOOP abierta), evaluar comprar un Polar Verity Sense o
   Scosche Rhythm24 como sensor dedicado.

## Acción necesaria de Vicente (no ahora, más adelante)

Cuando lleguemos a Fase 14 (sensor físico), si corresponde comprar hardware,
se te va a pedir confirmación explícita antes de cualquier compra — esto no
se hace de forma autónoma bajo ninguna circunstancia.
