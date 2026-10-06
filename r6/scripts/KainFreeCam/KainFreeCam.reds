// KainFreeCam - camara libre desacoplada del personaje, HUD toggle y teletransporte.
// Requiere: RED4ext + redscript + Codeware.
//
// Controles:
//   F6  -> activar / desactivar camara libre (oculta el HUD automaticamente)
//   F7  -> ocultar / mostrar HUD (funciona dentro y fuera de la camara libre)
//   F8  -> (en camara libre) teletransportar a V a la posicion de la camara y salir
//   W A S D          mover | Espacio / Q = subir | Ctrl izq / E = bajar
//   Shift izq        turbo x4 | Rueda del raton = velocidad
//   Ratón            mirar
module KainFreeCam

// ----------------------------- AJUSTES -----------------------------------
public func KFC_LookSensitivity() -> Float { return 0.05; }   // grados por unidad de raton
public func KFC_InvertY() -> Bool { return false; }           // true si el eje vertical sale al reves
public func KFC_StartSpeed() -> Float { return 6.0; }         // metros por segundo
public func KFC_Fov() -> Float { return 75.0; }
// --------------------------------------------------------------------------

public class KFCTick extends DelayCallback {
  public func Call() -> Void {
    let svc = GameInstance.GetScriptableServiceContainer().GetService(n"KainFreeCam.KainFreeCamService") as KainFreeCamService;
    if IsDefined(svc) {
      svc.Tick();
    } else {
      FTLog("[KainFreeCam] ERROR: servicio no encontrado en el tick");
    };
  }
}

public class KainFreeCamService extends ScriptableService {
  private let active: Bool;
  private let anchored: Bool;
  private let hudHiddenByUser: Bool;
  private let hudHiddenByCam: Bool;
  private let camComp: ref<CameraComponent>;

  private let savedPaths: array<CName>;
  private let savedNames: array<CName>;
  private let savedValues: array<Bool>;

  private let pos: Vector4;
  private let yaw: Float;
  private let pitch: Float;
  private let speed: Float;
  private let lastTime: Float;
  private let mouseDX: Float;
  private let mouseDY: Float;

  private let kW: Bool;
  private let kA: Bool;
  private let kS: Bool;
  private let kD: Bool;
  private let kUp: Bool;
  private let kDown: Bool;
  private let kFast: Bool;
  private let tickCount: Int32;
  private let dbgKeys: Int32;
  private let lastTickTime: Float;
  private let dbgAxis: Int32;

  // ---- registro de callbacks ----
  private cb func OnLoad() -> Void {
    let cbs = GameInstance.GetCallbackSystem();
    cbs.RegisterCallback(n"Input/Key", this, n"OnKeyInput");
    cbs.RegisterCallback(n"Input/Axis", this, n"OnAxisInput");
    cbs.RegisterCallback(n"Entity/Assemble", this, n"OnPlayerAssemble")
      .AddTarget(EntityTarget.Type(n"PlayerPuppet"));
    cbs.RegisterCallback(n"Session/BeforeEnd", this, n"OnSessionEnd");
    this.speed = KFC_StartSpeed();
  }

  // Anade la camara al jugador cuando se ensambla la entidad.
  private cb func OnPlayerAssemble(event: ref<EntityLifecycleEvent>) -> Void {
    let entity = event.GetEntity();
    if !IsDefined(entity) {
      return;
    };
    let comp = new CameraComponent();
    comp.fov = KFC_Fov();
    entity.AddComponent(comp);
    this.camComp = comp;
    this.active = false;
    FTLog("[KainFreeCam] camara anadida al jugador");
  }

  private cb func OnSessionEnd(event: ref<GameSessionEvent>) -> Void {
    if this.active {
      this.active = false;
    };
    if this.hudHiddenByUser || this.hudHiddenByCam {
      this.RestoreHud();
    };
    this.camComp = null;
  }

  // ---- entrada ----
  private cb func OnKeyInput(evt: ref<KeyInputEvent>) -> Void {
    let key = evt.GetKey();
    let action = evt.GetAction();
    if this.active && this.dbgKeys < 40 {
      this.dbgKeys += 1;
    };
    this.EnsureLoop();
    let pressed = Equals(action, EInputAction.IACT_Press);
    let released = Equals(action, EInputAction.IACT_Release);
    if !pressed && !released {
      return;
    };

    if pressed {
      if Equals(key, EInputKey.IK_F6) {
        this.ToggleFreeCam();
        return;
      };
      if Equals(key, EInputKey.IK_F7) {
        this.ToggleHudByUser();
        return;
      };
      if Equals(key, EInputKey.IK_F9) {
        if this.active {
          this.SetAnchored(!this.anchored);
        };
        return;
      };
      if Equals(key, EInputKey.IK_F8) {
        if this.active && !this.anchored {
          this.TeleportPlayerToCamera();
        };
        return;
      };
      if this.active {
        if Equals(key, EInputKey.IK_MouseWheelUp) {
          this.speed = MinF(this.speed * 1.25, 400.0);
        };
        if Equals(key, EInputKey.IK_MouseWheelDown) {
          this.speed = MaxF(this.speed / 1.25, 0.2);
        };
      };
    };

    if Equals(key, EInputKey.IK_W) { this.kW = pressed; };
    if Equals(key, EInputKey.IK_A) { this.kA = pressed; };
    if Equals(key, EInputKey.IK_S) { this.kS = pressed; };
    if Equals(key, EInputKey.IK_D) { this.kD = pressed; };
    if Equals(key, EInputKey.IK_Space) || Equals(key, EInputKey.IK_Q) { this.kUp = pressed; };
    if Equals(key, EInputKey.IK_LControl) || Equals(key, EInputKey.IK_Ctrl) || Equals(key, EInputKey.IK_E) { this.kDown = pressed; };
    if Equals(key, EInputKey.IK_LShift) || Equals(key, EInputKey.IK_Shift) { this.kFast = pressed; };
  }

  private cb func OnAxisInput(evt: ref<AxisInputEvent>) -> Void {
    if !this.active {
      return;
    };
    this.EnsureLoop();
    let key = evt.GetKey();
    if Equals(key, EInputKey.IK_MouseX) {
      this.mouseDX += evt.GetValue();
    };
    if Equals(key, EInputKey.IK_MouseY) {
      this.mouseDY += evt.GetValue();
    };
  }

  // ---- camara libre ----
  private func ToggleFreeCam() -> Void {
    if this.active {
      this.StopFreeCam();
    } else {
      this.StartFreeCam();
    };
  }

  private func StartFreeCam() -> Void {
    let game = GetGameInstance();
    let player = GetPlayer(game);
    if !IsDefined(player) || !IsDefined(this.camComp) {
      FTLog("[KainFreeCam] no hay jugador/camara disponible (carga una partida)");
      return;
    };

    this.pos = player.GetWorldPosition();
    this.pos.Z += 1.6;
    this.yaw = player.GetWorldYaw();
    this.pitch = 0.0;
    this.mouseDX = 0.0;
    this.mouseDY = 0.0;
    this.lastTime = EngineTime.ToFloat(GameInstance.GetEngineTime(game));
    this.tickCount = 0;
    this.lastTickTime = this.lastTime;
    this.dbgKeys = 0;
    this.dbgAxis = 0;

    // El jugador queda quieto, invulnerable y sin armas mientras dura la camara.
    this.anchored = false;
    this.LockPlayer(true);

    if !this.hudHiddenByUser {
      this.HideHud();
      this.hudHiddenByCam = true;
    };

    this.active = true;
    this.ApplyCameraTransform();
    this.camComp.Activate(0.0, true);
    this.ScheduleTick();
    FTLog("[KainFreeCam] activada");
  }

  private func StopFreeCam() -> Void {
    let game = GetGameInstance();
    let player = GetPlayer(game);
    this.active = false;
    this.anchored = false;
    this.kW = false; this.kA = false; this.kS = false; this.kD = false;
    this.kUp = false; this.kDown = false; this.kFast = false;

    if IsDefined(this.camComp) {
      this.camComp.Deactivate(0.0, true);
    };
    if IsDefined(player) {
      let fpp = player.GetFPPCameraComponent();
      if IsDefined(fpp) {
        fpp.Activate(0.0, true);
      };
      this.LockPlayer(false);
    };

    if this.hudHiddenByCam {
      this.RestoreHud();
      this.hudHiddenByCam = false;
    };
    FTLog("[KainFreeCam] desactivada");
  }

  // Si el bucle por frame se detuvo, lo reinicia desde un evento de entrada.
  private func EnsureLoop() -> Void {
    if !this.active {
      return;
    };
    let now = EngineTime.ToFloat(GameInstance.GetEngineTime(GetGameInstance()));
    if now - this.lastTickTime > 0.1 {
      this.lastTickTime = now;
      this.ScheduleTick();
    };
  }

  // Bloquea / libera al jugador (movimiento, camara, armas, invulnerabilidad).
  private func LockPlayer(lock: Bool) -> Void {
    let game = GetGameInstance();
    let player = GetPlayer(game);
    if !IsDefined(player) {
      return;
    };
    if lock {
      StatusEffectHelper.ApplyStatusEffect(player, t"GameplayRestriction.NoMovement");
      StatusEffectHelper.ApplyStatusEffect(player, t"GameplayRestriction.NoJump");
      StatusEffectHelper.ApplyStatusEffect(player, t"GameplayRestriction.NoCameraControl");
      StatusEffectHelper.ApplyStatusEffect(player, t"GameplayRestriction.NoWeapons");
      GameInstance.GetGodModeSystem(game).AddGodMode(player.GetEntityID(), gameGodModeType.Invulnerable, n"KainFreeCam");
    } else {
      StatusEffectHelper.RemoveStatusEffect(player, t"GameplayRestriction.NoMovement");
      StatusEffectHelper.RemoveStatusEffect(player, t"GameplayRestriction.NoJump");
      StatusEffectHelper.RemoveStatusEffect(player, t"GameplayRestriction.NoCameraControl");
      StatusEffectHelper.RemoveStatusEffect(player, t"GameplayRestriction.NoWeapons");
      GameInstance.GetGodModeSystem(game).RemoveGodMode(player.GetEntityID(), gameGodModeType.Invulnerable, n"KainFreeCam");
    };
  }

  // Modo camara anclada: la camara se queda fija en el mundo y V recupera el control.
  private func SetAnchored(on: Bool) -> Void {
    if Equals(on, this.anchored) {
      return;
    };
    this.anchored = on;
    this.kW = false; this.kA = false; this.kS = false; this.kD = false;
    this.kUp = false; this.kDown = false; this.kFast = false;
    this.mouseDX = 0.0;
    this.mouseDY = 0.0;
    this.LockPlayer(!on);
    if on {
      FTLog("[KainFreeCam] camara anclada: controlas a V");
    } else {
      FTLog("[KainFreeCam] camara libre de nuevo");
    };
  }

  private func ScheduleTick() -> Void {
    let cb = new KFCTick();
    GameInstance.GetDelaySystem(GetGameInstance()).DelayCallback(cb, 0.016, false);
  }

  public func Tick() -> Void {
    if !this.active {
      return;
    };
    let game = GetGameInstance();
    let player = GetPlayer(game);
    if !IsDefined(player) || !IsDefined(this.camComp) {
      this.active = false;
      return;
    };

    let now = EngineTime.ToFloat(GameInstance.GetEngineTime(game));
    let dt = now - this.lastTime;
    this.lastTime = now;
    this.lastTickTime = now;
    if dt < 0.0 || dt > 0.1 {
      dt = 0.016;
    };

    if this.anchored {
      this.mouseDX = 0.0;
      this.mouseDY = 0.0;
      this.ApplyCameraTransform();
      this.ScheduleTick();
      return;
    };

    // Mirada
    let sens = KFC_LookSensitivity();
    this.yaw -= this.mouseDX * sens;
    if KFC_InvertY() {
      this.pitch -= this.mouseDY * sens;
    } else {
      this.pitch += this.mouseDY * sens;
    };
    this.mouseDX = 0.0;
    this.mouseDY = 0.0;
    this.pitch = ClampF(this.pitch, -89.0, 89.0);

    // Movimiento
    let angles: EulerAngles;
    angles.Roll = 0.0;
    angles.Pitch = this.pitch;
    angles.Yaw = this.yaw;
    let forward = EulerAngles.GetForward(angles);
    let right = EulerAngles.GetRight(angles);

    let move = new Vector4(0.0, 0.0, 0.0, 0.0);
    if this.kW { move += forward; };
    if this.kS { move -= forward; };
    if this.kD { move += right; };
    if this.kA { move -= right; };
    if this.kUp { move.Z += 1.0; };
    if this.kDown { move.Z -= 1.0; };

    let speed = this.speed;
    if this.kFast {
      speed *= 4.0;
    };
    this.pos += move * (speed * dt);

    this.tickCount += 1;
    this.ApplyCameraTransform();
    this.ScheduleTick();
  }

  // Convierte la pose mundial de la camara a coordenadas locales del jugador
  // (el jugador esta inmovil mientras dura la camara libre).
  private func ApplyCameraTransform() -> Void {
    let player = GetPlayer(GetGameInstance());
    if !IsDefined(player) || !IsDefined(this.camComp) {
      return;
    };
    let origin = player.GetWorldPosition();
    let pFwd = player.GetWorldForward();
    let pRight = player.GetWorldRight();
    let d = this.pos - origin;

    let localPos = new Vector4(Vector4.Dot(d, pRight), Vector4.Dot(d, pFwd), d.Z, 0.0);

    let local: EulerAngles;
    local.Roll = 0.0;
    local.Pitch = this.pitch;
    local.Yaw = this.yaw - player.GetWorldYaw();
    this.camComp.SetLocalTransform(localPos, EulerAngles.ToQuat(local));
  }

  private func TeleportPlayerToCamera() -> Void {
    let game = GetGameInstance();
    let player = GetPlayer(game);
    if !IsDefined(player) {
      return;
    };
    let target = this.pos;
    let rot: EulerAngles;
    rot.Roll = 0.0;
    rot.Pitch = 0.0;
    rot.Yaw = this.yaw;
    this.StopFreeCam();
    GameInstance.GetTeleportationFacility(game).Teleport(player, target, rot);
    FTLog("[KainFreeCam] teletransporte a la camara");
  }

  // ---- HUD ----
  private func ToggleHudByUser() -> Void {
    if this.hudHiddenByUser {
      this.RestoreHud();
      this.hudHiddenByUser = false;
    } else {
      if this.hudHiddenByCam {
        // el HUD ya esta oculto por la camara: pasa a ser ocultacion manual
        this.hudHiddenByCam = false;
        this.hudHiddenByUser = true;
      } else {
        this.HideHud();
        this.hudHiddenByUser = true;
      };
    };
  }

  private func HideHud() -> Void {
    ArrayClear(this.savedPaths);
    ArrayClear(this.savedNames);
    ArrayClear(this.savedValues);
    let settings = GameInstance.GetSettingsSystem(GetGameInstance());
    if !settings.HasGroup(n"/interface/hud") {
      return;
    };
    this.HideGroup(settings.GetGroup(n"/interface/hud"));
  }

  private func HideGroup(group: ref<ConfigGroup>) -> Void {
    let vars = group.GetVars(false);
    let i = 0;
    while i < ArraySize(vars) {
      let b = vars[i] as ConfigVarBool;
      if IsDefined(b) {
        ArrayPush(this.savedPaths, b.GetGroupPath());
        ArrayPush(this.savedNames, b.GetName());
        ArrayPush(this.savedValues, b.GetValue());
        b.SetValue(false);
      };
      i += 1;
    };
    let subs = group.GetGroups(false);
    let j = 0;
    while j < ArraySize(subs) {
      this.HideGroup(subs[j]);
      j += 1;
    };
  }

  private func RestoreHud() -> Void {
    let settings = GameInstance.GetSettingsSystem(GetGameInstance());
    let i = 0;
    while i < ArraySize(this.savedPaths) {
      let b = settings.GetVar(this.savedPaths[i], this.savedNames[i]) as ConfigVarBool;
      if IsDefined(b) {
        b.SetValue(this.savedValues[i]);
      };
      i += 1;
    };
    ArrayClear(this.savedPaths);
    ArrayClear(this.savedNames);
    ArrayClear(this.savedValues);
  }
}
