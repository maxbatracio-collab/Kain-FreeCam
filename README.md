# Kaín FreeCam

A free camera mod for Cyberpunk 2077, written in redscript. It detaches the camera from the player character so you can fly through the world, hide the HUD for clean captures, and optionally teleport V to the camera position.

[English](#english) | [Español](#español)

---

## English

### Features

- Free-flight camera fully decoupled from V, with mouse look and six-axis movement.
- Adjustable speed at runtime (mouse wheel) and a 4x turbo modifier.
- Automatic HUD hiding while the camera is active, plus an independent HUD toggle that also works outside free camera mode.
- Anchored mode: the camera stays fixed in the world while control returns to V, useful for staged shots.
- Teleport V to the current camera position and exit in a single key press.
- While the camera is active, V is frozen, invulnerable and unarmed, and everything is restored on exit.

### Requirements

- Cyberpunk 2077 (PC)
- [RED4ext](https://github.com/WopsS/RED4ext)
- [redscript](https://github.com/jac3km4/redscript)
- [Codeware](https://github.com/psiberx/cp2077-codeware)

### Installation

1. Install the requirements above.
2. Copy the `r6` folder from this repository into your Cyberpunk 2077 installation directory, so the final path is:

   ```
   Cyberpunk 2077/r6/scripts/KainFreeCam/KainFreeCam.reds
   ```

3. Launch the game. redscript compiles the script on startup.

To uninstall, delete the `KainFreeCam` folder from `r6/scripts`.

### Controls

| Key | Action |
| --- | --- |
| F6 | Enable / disable free camera (hides the HUD automatically) |
| F7 | Show / hide the HUD (works inside and outside free camera) |
| F8 | Teleport V to the camera position and exit free camera |
| F9 | Toggle anchored mode (camera stays fixed, V can be controlled) |
| W A S D | Move |
| Space / Q | Move up |
| Left Ctrl / E | Move down |
| Left Shift | Turbo (4x speed) |
| Mouse wheel | Increase / decrease speed |
| Mouse | Look |

F6 requires a loaded save, since the camera is attached to the player entity.

### Configuration

Settings are defined as functions at the top of `KainFreeCam.reds`. Edit them and restart the game.

| Function | Default | Description |
| --- | --- | --- |
| `KFC_LookSensitivity()` | `0.05` | Degrees of rotation per mouse unit |
| `KFC_InvertY()` | `false` | Invert the vertical axis |
| `KFC_StartSpeed()` | `6.0` | Initial speed in meters per second |
| `KFC_Fov()` | `75.0` | Field of view of the free camera |

### How it works

The mod is a single `ScriptableService` (`KainFreeCamService`) that subscribes to engine events through the engine `CallbackSystem`.

**Lifecycle and callbacks.** On load the service registers four callbacks: `Input/Key`, `Input/Axis`, `Entity/Assemble` (filtered to `PlayerPuppet`) and `Session/BeforeEnd`. When the player entity is assembled, a `CameraComponent` is created with the configured FOV and attached to it. On session end the camera reference is released and any hidden HUD state is restored.

**Input.** Keyboard state is tracked as booleans updated from press and release events, and raw mouse deltas from `Input/Axis` are accumulated and consumed once per frame. Mouse wheel events adjust the speed multiplicatively (x1.25 per notch), clamped between 0.2 and 400 m/s.

**Update loop.** There is no native per-frame hook available to a pure script mod, so the loop is driven by `DelaySystem.DelayCallback` rescheduling a `KFCTick` callback every 16 ms. Delta time is computed from `EngineTime` and clamped to a sane range (values outside 0 to 0.1 s fall back to 16 ms) so pauses and hitches do not cause large jumps. Because delayed callbacks can stall, input events also call a watchdog (`EnsureLoop`) that reschedules the tick if no tick has run for more than 100 ms.

**Camera transform.** The free camera position and orientation are stored in world space (position vector, yaw, pitch). Since the `CameraComponent` is a child of the player entity, each tick converts the world pose into the player's local frame by projecting the offset onto the player's right and forward axes and subtracting the yaw. This works because the player is held stationary while the camera is active. Movement is computed from `EulerAngles` forward and right vectors, with vertical motion applied on the world Z axis, and pitch is clamped to +/-89 degrees to avoid gimbal flip.

**Player lock.** On activation the mod applies the `GameplayRestriction.NoMovement`, `NoJump`, `NoCameraControl` and `NoWeapons` status effects and registers an `Invulnerable` god mode entry through `GodModeSystem` under the source name `KainFreeCam`. All of them are removed on exit. In anchored mode only the lock is lifted, leaving the camera pose frozen while V is controllable.

**HUD hiding.** The HUD is controlled through the settings system. The mod recursively walks the `/interface/hud` config group, stores the group path, name and current value of every `ConfigVarBool`, and sets them to `false`. Restoring replays the saved values. Free camera and the manual F7 toggle track their ownership separately (`hudHiddenByCam`, `hudHiddenByUser`), so leaving the camera does not re-enable a HUD the user hid manually.

**Teleport.** F8 captures the camera position and yaw, exits free camera (restoring the player state), then calls `TeleportationFacility.Teleport` with the captured transform.

### Limitations

- The camera is attached to the player entity, so it requires a loaded game and is not available in menus or the main menu.
- The tick loop depends on the game's delay system and runs at roughly 60 Hz regardless of the display frame rate.
- Other mods that modify the same gameplay restriction status effects or the HUD settings group may conflict.

### License

Released under the MIT License. See [LICENSE](LICENSE).

---

## Español

### Características

- Cámara de vuelo libre totalmente desacoplada de V, con control de ratón y movimiento en seis ejes.
- Velocidad ajustable en tiempo real (rueda del ratón) y modificador turbo x4.
- Ocultación automática del HUD mientras la cámara está activa, además de un interruptor de HUD independiente que también funciona fuera del modo cámara libre.
- Modo anclado: la cámara permanece fija en el mundo mientras V recupera el control, útil para planos preparados.
- Teletransporte de V a la posición actual de la cámara con una sola tecla.
- Mientras la cámara está activa, V permanece inmóvil, invulnerable y sin armas; todo se restaura al salir.

### Requisitos

- Cyberpunk 2077 (PC)
- [RED4ext](https://github.com/WopsS/RED4ext)
- [redscript](https://github.com/jac3km4/redscript)
- [Codeware](https://github.com/psiberx/cp2077-codeware)

### Instalación

1. Instala los requisitos anteriores.
2. Copia la carpeta `r6` de este repositorio en el directorio de instalación de Cyberpunk 2077, de modo que la ruta final sea:

   ```
   Cyberpunk 2077/r6/scripts/KainFreeCam/KainFreeCam.reds
   ```

3. Inicia el juego. redscript compila el script al arrancar.

Para desinstalar, elimina la carpeta `KainFreeCam` de `r6/scripts`.

### Controles

| Tecla | Acción |
| --- | --- |
| F6 | Activar / desactivar la cámara libre (oculta el HUD automáticamente) |
| F7 | Mostrar / ocultar el HUD (funciona dentro y fuera de la cámara libre) |
| F8 | Teletransportar a V a la posición de la cámara y salir |
| F9 | Alternar el modo anclado (la cámara queda fija y se controla a V) |
| W A S D | Mover |
| Espacio / Q | Subir |
| Ctrl izquierdo / E | Bajar |
| Shift izquierdo | Turbo (velocidad x4) |
| Rueda del ratón | Aumentar / reducir velocidad |
| Ratón | Mirar |

F6 requiere una partida cargada, ya que la cámara se añade a la entidad del jugador.

### Configuración

Los ajustes son funciones al inicio de `KainFreeCam.reds`. Edítalos y reinicia el juego.

| Función | Valor por defecto | Descripción |
| --- | --- | --- |
| `KFC_LookSensitivity()` | `0.05` | Grados de rotación por unidad de ratón |
| `KFC_InvertY()` | `false` | Invertir el eje vertical |
| `KFC_StartSpeed()` | `6.0` | Velocidad inicial en metros por segundo |
| `KFC_Fov()` | `75.0` | Campo de visión de la cámara libre |

### Funcionamiento técnico

El mod es un único `ScriptableService` (`KainFreeCamService`) que se suscribe a eventos del motor mediante el `CallbackSystem` del motor.

**Ciclo de vida y callbacks.** Al cargar, el servicio registra cuatro callbacks: `Input/Key`, `Input/Axis`, `Entity/Assemble` (filtrado a `PlayerPuppet`) y `Session/BeforeEnd`. Cuando se ensambla la entidad del jugador se crea un `CameraComponent` con el FOV configurado y se le añade. Al terminar la sesión se libera la referencia a la cámara y se restaura el estado del HUD si estaba oculto.

**Entrada.** El estado del teclado se mantiene en variables booleanas actualizadas con los eventos de pulsación y liberación. Los deltas del ratón de `Input/Axis` se acumulan y se consumen una vez por frame. La rueda del ratón modifica la velocidad de forma multiplicativa (x1,25 por paso), limitada entre 0,2 y 400 m/s.

**Bucle de actualización.** Un mod de scripts puro no dispone de un hook nativo por frame, por lo que el bucle se implementa con `DelaySystem.DelayCallback`, reprogramando un callback `KFCTick` cada 16 ms. El delta de tiempo se calcula con `EngineTime` y se limita a un rango razonable (valores fuera de 0 a 0,1 s se sustituyen por 16 ms) para evitar saltos tras pausas o ralentizaciones. Como los callbacks diferidos pueden detenerse, los eventos de entrada invocan un vigilante (`EnsureLoop`) que reprograma el tick si han pasado más de 100 ms sin ejecutarse.

**Transformación de la cámara.** La posición y orientación de la cámara libre se almacenan en espacio mundial (vector de posición, yaw y pitch). Como el `CameraComponent` es hijo de la entidad del jugador, en cada tick se convierte la pose mundial al sistema local del jugador proyectando el desplazamiento sobre sus ejes derecho y frontal y restando el yaw. Esto es válido porque el jugador permanece inmóvil mientras la cámara está activa. El movimiento se calcula con los vectores forward y right de `EulerAngles`, con el desplazamiento vertical sobre el eje Z mundial, y el pitch se limita a +/-89 grados para evitar el giro de gimbal.

**Bloqueo del jugador.** Al activarse, el mod aplica los status effects `GameplayRestriction.NoMovement`, `NoJump`, `NoCameraControl` y `NoWeapons`, y registra una entrada de god mode `Invulnerable` en `GodModeSystem` con el origen `KainFreeCam`. Todo se elimina al salir. En modo anclado solo se levanta el bloqueo, dejando la pose de la cámara congelada mientras V es controlable.

**Ocultación del HUD.** El HUD se controla mediante el sistema de ajustes. El mod recorre recursivamente el grupo de configuración `/interface/hud`, guarda la ruta, el nombre y el valor actual de cada `ConfigVarBool` y los establece a `false`. La restauración reaplica los valores guardados. La cámara libre y el interruptor manual F7 registran su propiedad por separado (`hudHiddenByCam`, `hudHiddenByUser`), de modo que salir de la cámara no reactiva un HUD que el usuario ocultó manualmente.

**Teletransporte.** F8 captura la posición y el yaw de la cámara, sale de la cámara libre (restaurando el estado del jugador) y llama a `TeleportationFacility.Teleport` con la transformación capturada.

### Limitaciones

- La cámara se añade a la entidad del jugador, por lo que requiere una partida cargada y no está disponible en menús.
- El bucle depende del sistema de retardos del juego y se ejecuta a unos 60 Hz independientemente de la tasa de refresco de la pantalla.
- Otros mods que modifiquen los mismos status effects de restricción o el grupo de ajustes del HUD pueden generar conflictos.

### Licencia

Publicado bajo la licencia MIT. Consulta [LICENSE](LICENSE).
