---@meta

---@class GB_Math
---@field AngleFov fun(vFrom: EulerAngles, vTo: EulerAngles): number
---@field PositionAngles fun(source: Vector3, dest: Vector3): EulerAngles

---@class GB_Settings_Aimbot
---@field key integer
---@field enabled boolean
---@field fov number
---@field autoshoot boolean
---@field m_flPredictionTime number The number of max seconds the projectile prediction should run

---@class GB_Settings_AntiAim
---@field m_flPitch number
---@field m_flFakeyaw number
---@field m_flRealyaw number
---@field m_bEnabled boolean

---@class GB_Settings_FakeLag
---@field m_iGoal integer How many commands do we want to choke
---@field m_bEnabled boolean

---@class GB_Settings_Warp
---@field m_bEnabled boolean
---@field m_iWarpKey integer
---@field m_iRechargeKey integer
---@field m_bPassiveRecharge boolean
---@field m_iTogglePassiveRechargeKey integer

---@class GB_Settings
---@field version number
---@field aimbot GB_Settings_Aimbot
---@field antiaim GB_Settings_AntiAim
---@field fakelag GB_Settings_FakeLag
---@field warp GB_Settings_Warp

---@class GB_Utils
---@field math GB_Math
---@field settings table

--- Global state of GB
---@class GB_State
---@field aimbot_running boolean If the aimbot is running this tick
---@field aimbot_target integer? The aimbot target index
---@field shooting boolean If we are shooting this tick
---@field stored_ticks integer How many stored ticks we have for warp
---@field choked_cmds integer How many choked commands we have this tick

---@class GB_EntUtils
---@field GetShootPosition fun(plocal: Entity): Vector3
---@field GetBones fun(entity: Entity): table<integer, Vector3>
---@field FindVisibleBodyPart fun(player: Entity, shootpos: Vector3, utils: GB_Utils, viewangle: EulerAngles, PREFERRED_BONES: table): PlayerInfo

---@class GB_WepUtils
---@field CanShoot fun(): boolean

---@class PlayerInfo
---@field angle EulerAngles? The angle from positions
---@field fov number? The fov from the crosshair
---@field index integer? The player's index
---@field center Vector3?
---@field pos Vector3?
