# 枪与法杖打磨（Gun & Staff Polish）设计

日期：2026-06-12
状态：用户已确认（全选 + 美术"都要"），按 T1→T7 顺序执行

## 背景

游戏现有 23 把枪 + 20 根法杖，机制数据驱动（`item_db.gd` 的 `gun_*` / `spell_*` 字段），
投射物统一走 `bullet.gd`（穿透/追踪/连锁/弹跳/爆炸/减速/中毒）。
本次不加新武器，专注打磨手感、修不一致、升级视听表现。

## 范围（用户确认的 5 件事）

1. 修两个小毛病（追踪目标优先级 + 魔法枪魔力折扣）
2. 每把枪有自己的声音 + 法杖专属施法音
3. 枪口火光 + 大威力枪震屏
4. 闪电链电弧视觉
5. 强力枪命中特效
6. 美术全家桶：枪/法杖图标（=手持外观）+ 投射物贴图全部重画

## 任务分解

### T1 修小毛病（bug 级，先做）

**1a. 追踪/连锁优先打敌对怪**
- `bullet.gd::_nearest_enemy()`：先扫 `slimes` 组（敌对怪），有合法目标直接取最近的；
  一只敌对怪都没有时才考虑 `animals` 组。修复"僵尸咬你、追踪弹去打小猪"。
- `bullet.gd::_do_chain()`：候选排序改为（敌对优先，再按距离）。动物只在敌对怪
  填不满 chain 数时垫底。
- 其余行为不变（枪主动瞄准动物仍能打中——只改"自动选目标"的优先级）。

**1b. 魔法枪魔力享受法杖同款折扣**
- `player_action.gd::_try_fire_gun()` 魔力路径改用现成纯函数
  `staff_mana_cost(base, in_combat)`（正常局 ×0.5、对战房 ×0.2、至少 1 点）。
- 现状：法杖打折、魔法枪全价，不一致。

**测试**：
- integration：场景里放一只远的敌对怪 + 一只近的动物，断言 `_nearest_enemy()` 返回敌对怪；
  全是动物时返回动物。`_do_chain` 同思路。
- integration：魔法枪开火后 mana 扣减 == `staff_mana_cost(def.mana_cost, false)`。

### T2 声音套餐

**SfxBank 新增程序合成音**（照 `_thunk`/`_lip_pop` 的写法加生成器）：

| 名字 | 描述 | 用在 |
|---|---|---|
| `gunshot_heavy` | 低频长"轰" | sniper / railgun / rocket_gun |
| `gunshot_laser` | 下滑正弦"啾" | laser_gun / beam 类 |
| `gunshot_ice` | 高频短"叮" | freeze_ray / frost_gun / cryo_gun |
| `gunshot_magic` | 柔和"嗖" | arcane_gun / twin_magic_gun / star_gun / slime_gun / leaf_gun |
| `gunshot_rapid` | 更轻更短"哒" | smg / minigun / flamethrower |
| `cast` | 魔法上扬"嗖~" | 所有攻击法杖施法（替换现在的 `break` 挖土声） |

- `item_db.gd` 枪 def 加可选字段 `gun_sfx`（缺省 `"gunshot"`），`_try_fire_gun` 播
  `def.get("gun_sfx", "gunshot")`。法杖施法音直接在 `_try_cast_staff` 把 `break` 换 `cast`
  （治疗/护盾保持 `pickup` 不动）。
- 音量沿用现有 SFX 约定（~0dB，play 的第二参 0.08~0.12 抖动）。

**测试**：SfxBank 加 `has_sound(name) -> bool`；unit 测试遍历所有枪 def 的 `gun_sfx`
值，断言每个都已注册（防手滑写错名）。

### T3 枪口火光 + 震屏

- `effects.gd` 新增 `spawn_muzzle_flash(pos, dir, color)`：枪口处 3~5 颗亮色火花
  （复用 `_spell_chips` 基建）+ 一记短促亮闪，寿命 ~0.1s。
  遵守 FX 可见性规矩：alpha ≥ 0.8、颗粒尺寸够大。
- `_try_fire_gun` 出弹后调用一次（多弹丸也只闪一次），位置 `start + base_dir * 10`，
  颜色按 `gun_visual` 走现成 `_spell_fx_color` 映射；普通子弹枪用暖黄白。
- `item_db.gd` 加可选字段 `gun_shake`（float）：sniper 2.5 / railgun 3.0 /
  rocket_gun 2.0 / shotgun 1.5。开火时若有此字段调 `player_controller.shake(amount)`。
- 联机：枪口光为本地视效，不同步（远端只看到投射物，可接受）。

**测试**：integration 调 `spawn_muzzle_flash` 不报错且有子节点生成；unit 遍历
`gun_shake` 值断言在 (0, 4] 区间。

### T4 闪电链电弧

- `effects.gd` 新增 `spawn_lightning_arc(from, to)`：锯齿折线（4~8 个中点垂直随机偏移），
  双层 Line2D（外层宽 4px 半透明辉光 + 内核宽 2.5px 亮黄白 Color8(255,245,160)），
  tween 0.18s 淡出后 free。
- `bullet.gd::_do_chain()` 改为"接力式"：第一只 → 最近 → 次近 依次跳，每跳画一道电弧
  （现在是从第一只向外发散打，改接力更像真闪电链；伤害判定不变，只改跳跃顺序与视觉）。
- 联机：本地视效不同步。

**测试**：integration 调 `spawn_lightning_arc`，断言节点生成、~0.3s 后自动释放。

### T5 强力枪命中特效（含小重构）

- **重构**：`_try_fire_gun` 里手搓 opts 的 25 行（与 `_proj_opts_from_def` 重复）删掉，
  改调 `_proj_opts_from_def(def)`。一处维护，枪/法杖共用。
- `item_db.gd` 枪 def 加可选布尔 `gun_impact`：sniper / railgun 设 true。
- `_try_fire_gun`：若 `gun_impact`，往 opts 塞 `impact_fx` / `impact_color`
  （复用法杖的 `_spell_impact_fx` / `_spell_fx_color` 映射；纯 `bullet` 视觉给默认
  `spark` + 暖金白）。快枪不设 → 维持现在"枪不喷特效防刷屏"的设计。

**测试**：unit 直接 new player_action 脚本调 `_proj_opts_from_def`，断言字段映射；
含 `gun_impact` 的 def 生成的 opts 带 impact_fx。

### T6 图标重画（枪一批、法杖一批）

- `items_art.gd` 的 16×16 字符画全部重画：23 把枪 + 20 根法杖。
  手持外观 = 背包图标（`held_item.gd` 直接用 icon），重画一次两处生效。
- 原则（按既有美术规矩）：
  - 每把武器轮廓差异化：长度/枪管数/配件（狙击=细长+瞄准镜、加特林=多管转轮、
    火焰喷射器=粗管+背罐、电磁炮=方正双轨道…）；法杖=杖头宝石/形状跟属性走
    （闪电=锯齿黄晶、冰=蓝菱晶、治疗=绿十字…）。
  - 暖色基调；金属可用冷灰但点缀色跟属性元素走；要可识别形状，不要随机散点。
- **验收**：扩展/复用 `scripts/tools/render_art_sheet.gd` 渲染"枪法杖总表"PNG，
  发图给用户过目；不满意的单独返工。分两批 commit（枪、法杖）。

### T7 投射物重画

- 重画 `ArtCache` 里的投射物帧：bullet / laser / fire(fireball) / ice / magic /
  poison(nature) / lightning / star / slimeblob / leaf / wind。
- 方向同 T6：形状更明确 + 辉光层次（核心亮 + 边缘淡），别只是色块。
- 同样渲染预览图给用户过目。

## 不做（明确排除）

- 换弹/弹夹系统、多种弹药、瞄准镜变焦（复杂度高，本次不碰）
- 枪口光/电弧的联机同步（本地视效足够）
- 新枪新法杖（本次只打磨存量）

## 验收总则

- 每个 T：GUT 全绿（unit + integration）→ 给用户 3-5 行中文报告 + commit SHA → 下一个 T
- 美术 T：额外附渲染预览图
- commit 信息照仓库惯例中文、`feat(gun)/fix(gun)/art(...)` 风格前缀
