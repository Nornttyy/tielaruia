# 搭一个自己的免费联机服务器 (让联机变稳)

游戏现在联机靠"大家都在蹭"的公共服务器，所以经常连不上。
搭个**只给自己人用**的免费服务器，联机就稳了。**搭一次，以后永远不用管。**

> 💡 难只难在"注册账号 + 确认邮箱"那几下 —— **建议让爸爸妈妈/大人帮忙点一下**（5 分钟，免费、安全、不绑卡）。
> 服务器代码我已经写好放在仓库 `peer-server/` 里，配置也设好了，基本是点几下按钮。

---

## 一键部署（推荐，省去手填表单）

### 第 1 步：点这个按钮
打开这个网址（这就是"一键部署"按钮）：

```
https://render.com/deploy?repo=https://github.com/Nornttyy/tielaruia
```

### 第 2 步：登录 Render
- 它会让你登录。点 **「GitHub」** 登录（用有游戏仓库的那个账号 Nornttyy）。
- 第一次会发一封**确认邮件**到你的 Gmail：去邮箱（gmail.com）打开 Render 发来的邮件，点里面的 **「Verify / 确认」** 按钮，再回来。
- （找不到邮件就看"垃圾邮件 Spam"文件夹。）

### 第 3 步：确认部署
- 登录后它会自动读好配置，显示一个要建的服务，名字 **teilaruia-peer**。
- 直接点 **「Apply」** 或 **「Create」 / 「Deploy」** 大按钮。
- 等它转圈 1-3 分钟，变成绿色 **「Live」** = 成了 ✅

### 第 4 步：拿网址 + 发给我
- 页面顶上会有个网址，像 `https://teilaruia-peer.onrender.com`。
- **点开它**，看到一行 `teilaruia peer server OK ✓` 就对了 🎉
- 把网址中间那段（`teilaruia-peer.onrender.com`，不要 `https://` 和末尾 `/`）**发给我**，我填进游戏推送上线。

---

## 小事项
- **第一次连会慢几秒**：免费服务器没人用时会"睡觉"，有人连时要 30-60 秒"叫醒"。叫醒后就正常。
- **免费、不绑卡、不用维护。**
- 卡哪一步就截图问我。

---

## 备选：手动建 (如果一键按钮没认出配置)

去 render.com → 登录 → 右上 **New + → Web Service** → 选仓库 `tielaruia` → 表单里填：
**Root Directory** = `peer-server`，**Build Command** = `npm install`，**Start Command** = `npm start`，**Instance Type** = `Free` → **Create Web Service**。其余同上。
