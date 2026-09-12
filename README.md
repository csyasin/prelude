# Prelude 0.4

原生 macOS Leader 键启动器。配置为无扩展名的 **`~/.config/prelude/preluderc`**，不使用 TOML。激活后，Prelude 从 Mac 刘海或屏幕顶部展开为灵动岛，只显示当前路径和下一步可用按键。

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

macOS 14+，Xcode / Swift 5.9+，当前构建为 Apple Silicon。应用本身没有第三方包依赖，已移除 TOMLKit。

```sh
swift test
./scripts/build.sh
open dist/Prelude.app
```

Xcode 打开 `Package.swift`。`--check-config /path/preluderc` 仅校验后退出；`--config /path/preluderc` 使用独立配置；`--preview` 不注册全局键也不执行动作。

主要源码：`PreludeRC.swift` 解析 DSL；`Configuration.swift` 构造树和导航索引；`IslandView.swift` 绘制灵动岛和纵向按键列表；`OverlayController.swift` 负责刘海检测与顶部定位；`AppModel.swift` 管理输入/重载；`ActionRunner.swift` 执行 shell。

本地 ad-hoc 签名，无 Developer ID 公证、自动更新、开机自启。具体验证范围见 VALIDATION.md。

### 交互效果

在菜单栏「偏好设置…」或激活后的 `⌘,` 中选择交互效果，自动保存并在下次激活时使用。默认「灵动岛」；可切换为「HUD」，两种交互效果激活时均显示全局彩色呼吸灯，多束柔光沿四边交错流动；靠近屏幕右下角并留出间距，显示无整体背景的单列实色动作条，以动作名称为主、小号快捷键为辅；多项向上展开，边缘光降低亮度。使用鼠标所在屏幕；支持主题色、退格返回、Esc 退出及系统减少动态效果设置。

偏好设置中的「显示呼吸灯」开关全局控制灵动岛和 HUD的边缘光，默认开启，修改自动保存。关闭后停止光效动画。
