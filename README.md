# Prelude

原生 macOS Leader 键启动器。配置为无扩展名的 **`~/.config/prelude/preluderc`**，不使用 TOML。激活后，Prelude 从 Mac 刘海或屏幕顶部展开为灵动岛，只显示当前路径和下一步可用按键。

[下载 macOS 版（DMG）](https://github.com/csyasin/prelude/releases/latest/download/Prelude.dmg) · macOS 14+ · Apple Silicon（M 系列芯片）。下载链接在首次正式 Release 发布后生效。

## 使用

双击 `dist/Prelude.app`。默认 **Control + Space** 激活，连续输入按键选择动作；退格返回上一级，在顶层继续退格会取消激活，Esc 可随时退出。可用按键按纵向列表显示，超过 6 项时均衡拆成两列；选中项会迁移为顶部路径。所有动作通过 `/bin/zsh -f -c` 立即执行，完成反馈独立收回。菜单栏丝带环图标提供偏好设置、重载和退出；“偏好设置…”绑定 **Command + ,**，Prelude 激活时也可直接使用。

App 图标与菜单栏图标使用同一套 Prelude 丝带环标志。

## preluderc 语法

```text
# Applications
@ a - 应用

s - Safari : open -b com.apple.Safari
t - 终端 : open -b com.apple.Terminal
f - 访达 : open -b com.apple.finder
n - 备忘录 : open -b com.apple.Notes

@ g - 前往

h - GitHub : open https://github.com
d - 下载 : open "$HOME/Downloads"
c - 编辑配置 : open -t "$HOME/.config/prelude/preluderc"

@ s - 系统

p - 系统设置 : open -b com.apple.systempreferences

@@ c - 截屏

a - 截取全屏 : screencapture -x "$HOME/Desktop/screen.png"
s - 选择区域 : screencapture -i "$HOME/Desktop/selection.png"
```

- `@ key - 名称` 声明一级分组，`@@` 声明二级，`@@@` 声明三级，以此类推。
- `key - 名称 : shell` 定义动作，挂到当前分组下。分隔符前后按示例加空格；名称可含空格或连字符，动作名称不能含冒号。
- `@` 数量**设置当前层级**。切换到较浅层级时，清除更深层上下文；不能跳过尚未存在的父层级。
- `@ s` 切回已声明的一级 s 分组；`@@ c` 切回当前一级分组下的 c。引用不重复创建节点，也不改变原有顺序。
- 单独的 `@` 回到根上下文。文件开头、首个分组之前也可直接定义根动作。
- 空行忽略。以 `#` 开头的整行是配置注释，允许前置空格。不要在分组行尾追加注释。
- 冒号后的脚本不解析：URL、引号、`#`、反斜杠和后续冒号原样保留。脚本内的 `#` 由 shell 自己解释。
- 按键为单个小写英文字母、数字或 ASCII 符号，`@`、`#` 为保留符号。同级按键不能重复，分组不能为空。
- 空格键写作 `<space>`，例如 `<space> - 终端 : open -a Ghostty`；也可用 `@ <space> - 常用` 声明分组、用 `@ <space>` 切回。界面显示为 `␣`。
- 单行定义一段脚本。需要多行逻辑时，调用自己的 `.sh` 文件；也可使用 shell 的 `$'...\n...'` 字符串。加载配置不会运行脚本。

### 从子分组返回

```text
@ s - 系统
@@ c - 截屏
a - 截取全屏 : screencapture -x "$HOME/Desktop/screen.png"

@ s
p - 系统设置 : open -b com.apple.systempreferences
```

这里 `p` 属于 `s`，不属于 `s → c`。

### 激活键

激活快捷键只在菜单栏的“偏好设置…”中管理，不属于 `preluderc`。默认是 Control + Space；点按快捷键录入框后可直接输入新组合，修改会即时生效并保存。普通键至少搭配一个修饰键，F1–F20 可以单独使用，也可随时恢复默认值。

`preluderc` 只配置激活后使用的按键序列、名称和 shell 动作，不支持 `!leader` 或其他应用偏好。

## 保存和执行

保存后自动重载；正在导航时暂时保留本次路径，退出后采用新配置。语法错误包含行号，保留上次有效配置。支持 UTF-8、BOM、LF/CRLF。

脚本工作目录为用户主目录，PATH 包含 `/opt/homebrew/bin`、`/usr/local/bin` 和进程原有路径。为避免启动延迟不读取用户 `.zprofile` / `.zshrc`；需要环境时显式 source。输出默认丢弃，非零退出码会提示；调试可重定向到自己的日志。脚本需要的系统权限由 macOS 提示。

## 迁移

本次升级将旧配置转换为 preluderc，保留原按键、名称、动作和顺序，编辑配置动作改为新路径。旧 TOML 保存为同目录带时间戳的备份，不再加载。不要在 shell 中粘贴 Markdown 链接，应写 `open https://github.com`。

如需转换其他旧的 0.2 TOML，使用 Python 3.11+：

```sh
python3 scripts/migrate_to_preluderc.py /path/old.toml /path/preluderc
./dist/Prelude.app/Contents/MacOS/Prelude --check-config /path/preluderc
```

转换器不覆盖已存在的目标，不执行脚本。旧多行脚本通过 zsh 字符串包装，保留换行语义。含 DSL 保留按键或名称分隔符的旧节点会要求手动处理，不会静默丢弃。

## URL 通知

使用 `prelude://toast` 从脚本、快捷指令或其他应用显示灵动岛通知。应用未运行时会自动启动；先打开一次 `dist/Prelude.app`，让 macOS 注册 URL Scheme。命令行推荐 `open -g`，避免调用方主动切换前台应用。

```sh
# 成功图标，显示 2 秒
open -g 'prelude://toast?message=Saved&duration=2&type=success'

# 失败图标，显示 3 秒
open -g 'prelude://toast?message=Build%20failed&duration=3&type=error'

# 纯文本，无图标，默认显示 1 秒
open -g 'prelude://toast?message=Copied'
```

| 参数 | 含义 |
| --- | --- |
| `message` | 必填，1–200 个字符；换行和连续空白合并为空格。通知内容左对齐；长消息自动加宽，最多占当前屏幕宽度的 50%，超出后换行完整显示。 |
| `duration` | 可选，单位秒，默认 `1`，允许 `0.5`–`10`，支持小数。 |
| `type` | 可选：`success`（对勾）、`error`（叉号）、`warning`（感叹号）、`info`（信息）；省略或 `type=` 时不显示图标及占位。 |

成功图标使用独立绿色，失败、警告、信息分别使用红、橙、蓝色，不受主题色影响。参数值需要 URL 编码，尤其是中文、空格、`&`、`#`、`%`。例如在 Python 中生成并发送：

```python
from urllib.parse import urlencode, quote
import subprocess

query = urlencode({"message": "文件已保存", "duration": 2, "type": "success"}, quote_via=quote)
subprocess.run(["open", "-g", "prelude://toast?" + query], check=True)
```

通知不获取键盘焦点。连续通知更新为最新内容并重新计时；按键导航期间暂存最新通知，退出后显示。无效 URL 被忽略并写入系统日志，不弹错误窗口。URL 只接收消息参数，不执行命令或访问消息中的路径。

动作触发后的名称提示直接复用内部 `showToast(ToastRequest(...))`，使用成功图标、1 秒停留时间，沿用此前的触发反馈语义（不代表脚本已退出）。内部调用不经过 URL 或 `open`。

## 开发

运行需要 macOS 14+；源码构建需要 Xcode 26+（包含 macOS 26 SDK），当前发布为 Apple Silicon。应用内更新使用 Sparkle 2.10.0，由 SwiftPM 下载并校验；不再使用 TOMLKit。第三方许可证见 THIRD_PARTY_NOTICES.md，并随应用一起打包。

```sh
swift test
./scripts/build.sh
open dist/Prelude.app
```

Xcode 打开 `Package.swift`。`--check-config /path/preluderc` 仅校验后退出；`--config /path/preluderc` 使用独立配置；`--preview` 不注册全局键也不执行动作。

主要源码：`PreludeRC.swift` 解析 DSL；`Configuration.swift` 构造树和导航索引；`IslandView.swift` 绘制灵动岛和纵向按键列表；`OverlayController.swift` 负责刘海检测与顶部定位；`AppModel.swift` 管理输入/重载；`ActionRunner.swift` 执行 shell。

本地 ad-hoc 签名，尚未进行 Developer ID 签名与 Apple 公证。开发构建默认关闭应用更新；GitHub 发布构建开启 Sparkle 更新。具体验证范围见 VALIDATION.md。

### DMG 打包与 GitHub 发布

本地构建并打包：

```sh
./scripts/build.sh
./scripts/package-dmg.sh
```

输出为 `dist/Prelude.dmg` 和 `dist/Prelude.dmg.sha256`。DMG 内含 `Prelude.app` 与指向 `/Applications` 的快捷方式；校验文件记录 DMG 的 SHA-256。仅打包已构建的应用，不把本机用户配置放入安装包。

发布采用[语义版本号](https://semver.org/lang/zh-CN/)：修复问题递增 `patch`，功能迭代递增 `minor`，主版本迭代递增 `major`。`0.x` 表示初期开发阶段。你选择本次递增类型，`scripts/release.py` 自动更新 `Info.plist` 的产品版本，版本变化时提交 `chore: release vX.Y.Z`，创建对应标签，再原子推送当前分支和标签到 `origin`。

`.github/workflows/release.yml` 收到标签后，校验标签与提交中的版本一致，使用 macOS 26 的 Apple Silicon runner 执行核心及发布脚本测试、Release 构建、架构与配置校验、DMG 打包、更新包签名和更新清单生成，最后创建 GitHub Release 并上传 DMG、SHA-256 文件和 `appcast.xml`。仅支持正式 `vX.Y.Z` 标签；产品版本从标签写入应用包，「关于 Prelude」从应用包读取版本和构建号。

构建号 `CFBundleVersion` 由 CI 按「运行编号.重试编号」生成，例如第 12 次发布工作流首次尝试为 `12.1`，重跑为 `12.2`，下一次工作流为 `13.1`。[GitHub 编号规则](https://docs.github.com/en/actions/reference/workflows-and-actions/contexts)。源文件中的构建号只是模板，不需要维护。直接本地构建默认使用「Git 提交数量.0」，同一提交重复构建保持相同编号；无 Git 历史的源码使用 `1.0`。如需复现特定版本，可通过 `APP_VERSION`、`APP_BUILD_NUMBER` 显式覆盖产物。

首次启用：

1. 在仓库 **Settings → Actions → General** 确认 GitHub Actions 已启用，并允许 `actions/checkout`。工作流已声明 `contents: write`，上传使用 GitHub 自动提供的 `GITHUB_TOKEN`，无需个人访问令牌。更新签名需要一次性配置 `SPARKLE_PRIVATE_KEY`，见下方「应用内更新」。组织策略若限制工作流写权限，需要仓库管理员调整。
2. 确认要发布的应用代码和发布脚本已保存，提交本次改动。发布命令要求工作区干净，并使用 Git 当前分支；需要 macOS、Git 和 Python 3。首次准备可以执行：

   ```sh
   git add .
   git commit -m "feat: prepare initial release"
   ```

3. 发布 `Info.plist` 中当前已配置的版本（仅适用于该版本尚未发布时）：

   ```sh
   ./scripts/release.py current
   ```

在仓库 **Actions → Release** 查看构建日志；全部成功后，安装包出现在 **Releases → 对应版本 → Assets**，README 中的最新版下载链接继续有效。

以后先照常提交功能改动，再执行一条发布命令。以下均以当前版本 `0.1.0` 为起点：

| 命令 | 下个版本 | 用途 |
| --- | --- | --- |
| `./scripts/release.py patch` | `0.1.1` | 问题修复、小调整 |
| `./scripts/release.py minor` | `0.2.0` | 功能迭代 |
| `./scripts/release.py major` | `1.0.0` | 主版本迭代 |
| `./scripts/release.py 0.3.0` | `0.3.0` | 明确指定一个更高版本 |

想先查看计划，可使用 `./scripts/release.py patch --dry-run`；它只读取本地数据，不修改文件、提交、标签或远端。真正发布时脚本会同步远端信息，检查工作区、分支和版本标签，拒绝重复版本与版本回退。远端分支领先或发生分叉时，先同步代码再发布。

若 Git 推送失败，版本提交和标签留在本地，修复连接或权限后执行 `./scripts/release.py current` 继续推送。若 Actions 因临时网络或服务问题失败，在 GitHub 重跑失败任务，构建号自动增加；上传中断留下的 Release 草稿可以继续完成。

若失败需要修改应用代码或工作流，先提交修复，再执行 `./scripts/release.py patch` 创建新版本标签。[重跑使用原任务的提交和引用](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/re-run-workflows-and-jobs)，不会读取分支上的新修复。已发布的版本及资产保持不变。

本地需要指定版本时可运行 `APP_VERSION=0.1.0 APP_BUILD_NUMBER=12.1 ./scripts/build.sh`，只改构建产物中的版本信息。当前自动发布沿用 ad-hoc 签名，尚未进行 Developer ID 签名与 Apple 公证；下载到其他 Mac 后可能被系统安全检查拦截。若需要正式公证分发，应另外配置 Developer ID 证书、Apple 公证凭据及签名流程。

### 应用内更新

正式发布版支持菜单栏「检查更新…」，偏好设置中的「应用更新」显示当前版本、上次检查时间，以及「自动检查更新」开关。默认每天在后台检查；发现更新后显示更新说明，由用户点击安装并重新启动。不会静默安装，也不会为检查更新打开偏好设置。菜单栏在发现新版本时显示「更新到 X.Y.Z…」。关闭自动检查后仍可手动检查。

首次需要手动安装一个包含 Sparkle 的新版，并将应用从 DMG 拖到 `/Applications` 等可写的固定位置；早期不含更新功能的版本无法自行升级到这个版本。更新只替换应用包，`~/.config/prelude/preluderc`、主题色及快捷键偏好保持原位置。开发构建默认不检查更新，以免本地构建号与 CI 构建号混用。

发布所需的更新公钥保存在 `Info.plist` 的 `SUPublicEDKey`，私钥保存在当前 Mac 登录钥匙串的 Sparkle 服务中，账号为 `dev.yasin.prelude`。GitHub Actions 使用仓库 Secret `SPARKLE_PRIVATE_KEY` 签名。首次在保存这个私钥的 Mac 上运行：

```sh
brew install gh
gh auth login
./scripts/setup-updates.py --github
```

设置脚本核对钥匙串中的公钥与项目一致，临时导出私钥并直接交给 GitHub CLI，上传后删除临时文件，不在终端打印私钥。使用仓库 `csyasin/prelude` 的管理账号登录 GitHub CLI。迁移电脑时需备份并恢复原更新密钥，不能直接换一个新公钥，否则已安装的应用无法验证后续更新。备份可以用 Sparkle 的 `generate_keys --account dev.yasin.prelude -x <安全备份文件路径>`；工具在 `.build/artifacts/sparkle/Sparkle/bin/` 中。

macOS 可能弹出钥匙串授权窗口，询问是否允许 `generate_keys`、`generate_appcast` 或 `sign_update` 读取上述更新密钥。这把私钥用于给更新包和更新清单签名，应用内置的公钥用于核验发布者；GitHub Actions 也需要同一把私钥。确认是你主动运行这些脚本后，可以允许此次访问。如需密码，请在系统窗口自行输入。拒绝只会取消本次操作，不影响已安装应用，也不要因此重新生成密钥。

完成这次配置并提交代码后，继续使用 `./scripts/release.py patch`、`minor`、`major` 发布。Actions 开启 `APP_ENABLE_UPDATES=1`，生成带 EdDSA 签名的 DMG 和已签名的 `appcast.xml`，同时验证签名、公钥、版本、文件大小及固定下载地址。缺少私钥或密钥不匹配时停止发布。应用从 `https://github.com/csyasin/prelude/releases/latest/download/appcast.xml` 读取更新清单，清单内使用每个标签对应的固定 DMG 地址，不会把某个版本的签名与另一个版本的下载包混用。无需额外服务器或 GitHub Pages。

如需本地模拟正式构建并生成更新清单，指定产品版本和递增的正式构建号：

```sh
APP_ENABLE_UPDATES=1 APP_VERSION=0.1.2 APP_BUILD_NUMBER=100.1 ./scripts/build.sh
./scripts/package-dmg.sh
./scripts/generate-appcast.py v0.1.2
```

本地签名默认使用上述钥匙串账号；CI 从 Secret 读取私钥，通过标准输入传给 Sparkle，私钥不进入命令参数或产物。Sparkle 更新签名与 Apple Developer ID 签名独立；此流程尚未替代 Apple 公证。

### 开机自启

普通启动或重新打开应用时显示导航面板，保留激活快捷键与「打开 Prelude」入口。偏好设置不会随启动自动打开，只通过「偏好设置…」或导航中的 `⌘,` 打开。

在菜单栏「偏好设置…」中开启「开机自启」，Prelude 会在登录 Mac 后自动在菜单栏运行，不主动展开导航面板。关闭开关即可移除登录项，不影响当前运行。

开关读取 macOS 的实际登录项状态；若需要系统批准，会显示提示和「打开系统设置」入口。从系统设置返回 Prelude 后状态自动刷新。此设置由系统保存，不属于 `preluderc`，首次使用不会自动启用。

请从构建后的 `Prelude.app` 设置开机自启，建议先将应用放到 `/Applications` 等固定位置再开启。

### 交互效果

在菜单栏「偏好设置…」或激活后的 `⌘,` 中选择交互效果，自动保存并在下次激活时使用。默认「灵动岛」；可切换为「HUD」，两种交互效果激活时均显示全局彩色呼吸灯，多束柔光沿四边交错流动；靠近屏幕右下角并留出间距，显示无整体背景的单列实色动作条，以动作名称为主、小号快捷键为辅；多项向上展开，边缘光降低亮度。使用鼠标所在屏幕；支持主题色、退格返回、Esc 退出及系统减少动态效果设置。

偏好设置中的「显示呼吸灯」开关全局控制所有交互效果的边缘光，默认开启，修改自动保存。关闭后停止光效动画。

「无形」模式不显示按键列表或 Toast 通知，激活后直接输入按键序列执行动作。呼吸灯仍由独立的「显示呼吸灯」开关控制。退格返回、Esc 退出和 `⌘,` 打开偏好设置照常可用。

### 主题色

主题色选择在同一行依次显示预设颜色、竖线分隔后的「跟随系统」圆形色块，以及再次分隔后的「自定义」圆形控件。点击任一选项直接应用颜色；「自定义」独立记住上次选色，点击旁边的铅笔打开系统选色面板，修改即时生效并保存。首次使用自定义时，点击色块或文案直接打开选色面板。选中的选项显示勾选与外圈，即使自定义色与预设相同也按所选来源显示；不提供独立的系统开关或自定义重置按钮。
