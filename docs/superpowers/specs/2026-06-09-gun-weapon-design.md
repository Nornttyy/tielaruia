# 枪械（手枪 pistol）设计

受用户（10 岁）要求："增加枪械"。游戏已有近战（剑）、远程抛物（弓）、魔法（法杖）。
枪 = 第四种武器：**笔直、快、准、狠**，跟弓形成对比，不是换皮。

## 与弓的区别（关键：真不同，不偷懒换色）

| 维度 | 弓 wood_bow（已有） | 枪 pistol（新） |
|------|--------------------|-----------------|
| 弹道 | 抛物线（GRAVITY=200 下坠） | 笔直（无重力） |
| 弹速 | 260 | 560 |
| 射速 cooldown | 0.4s | 0.22s（连发） |
| 基础伤害 | 5 | 9 |
| 弹药 | wood_arrow（木板做，便宜，4/次） | bullet（铁锭做，贵，8/次） |
| 音效 | 借 "break" | 新 "gunshot"（短促"砰"） |
| 投射物贴图 | 木箭+绿尾羽 | 黄铜子弹+速度线 |

## 物件清单

### item_db.gd 新增
- `"pistol": {placeable_tile_id:-1, tool_kind:"gun", tool_tier:1, max_stack:1, damage_mult:1.0}`
- `"bullet": {placeable_tile_id:-1, tool_kind:"", tool_tier:0, max_stack:99}`

### crafting_panel.gd `_ZH_NAMES`
- `"pistol": "手枪"`, `"bullet": "子弹"`

### recipe_db.gd（形状跟现有不撞，靠 test_recipe_db 把关）
- pistol 3×2：上排 3 铁锭(枪管)，下排左 1 木板(握把) → 1 把。`mirror_ok:false`
- bullet 1×2：2 铁锭 → 8 发。`mirror_ok:false`

### 投射物
- `scripts/entities/bullet.gd` + `scenes/entities/bullet.tscn`：照 arrow.gd，但 **无重力 / SPEED 560 / LIFETIME 1.2s**，命中逻辑（扫 slimes+animals、melee_hit_radius、联机权威）完全照 arrow。
- `scripts/art/bullet_proj_art.gd`：16×16 横向黄铜子弹 + 速度线。
- ArtCache：`bullet_proj_frames`。

### 发射逻辑 player_action.gd
- `const GunBulletScene`、`GUN_COOLDOWN:=0.22`、`GUN_BULLET_DAMAGE:=9`
- 分发加 `elif kind == "gun":` → `_try_fire_gun()` + `_flash_held()`
- `_try_fire_gun()`：照 `_try_fire_bow`，消耗 `"bullet"`，spawn 子弹，`SfxBank.play("gunshot")`，联机 `send_projectile("bullet",...)`

### 联机 world.gd `_on_remote_projectile`
- 加 `kind == "bullet"` → BulletScene 视觉副本（dmg=0），照 arrow 分支。

### 音效 sfx_bank.gd
- `_sfx["gunshot"]` = 短促爆破"砰"（比 break 更尖更短）。

## 任务拆分（每个 T 完成给用户简报 + commit SHA + 累计测试数）
- **T1** 物件层：item_db + 中文名 + 2 配方 + 2 个 icon（pistol/bullet）→ test_recipe_db 仍绿
- **T2** 投射物：bullet.gd + bullet.tscn + bullet_proj_art + ArtCache + gunshot SFX + 单测（直线无下坠、比箭快）
- **T3** 发射 + 联机：player_action gun 分支 + _try_fire_gun + world remote bullet + 集成测试（装枪有子弹→射出1发并扣1子弹；没子弹→不射）

## 验收（无 GUI，全靠 GUT）
- test_recipe_db 通过（无配方冲突）
- bullet 直线测试：水平发射后 y 基本不变（对比 arrow 明显下坠）
- gun 发射测试：有子弹消耗1+生成1个 bullet 节点；无子弹不生成
