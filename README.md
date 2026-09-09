# Prelude 0.3

原生 macOS Leader 键启动器。配置为无扩展名的 **`~/.config/prelude/preluderc`**，不使用 TOML。按键图保持完整展开，使用公共主干与大圆角连接线。

## 使用

双击 `dist/Prelude.app`。默认 **Control + Space** 激活，连续输入按键选择动作，退格返回，Esc 退出。所有动作通过 `/bin/zsh -f -c` 执行，不等待动画。菜单栏琴键图标提供编辑配置、重载和退出。

菜单栏的“偏好设置…”可以在两组视觉之间切换：默认的“轨道光束”和附加的“四块切面光束”。选择会立即更新 App 图标与菜单栏图标，并保存到下次启动。

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

不写设置时仍用 Control + Space。为保留自定义激活键能力，可选写一行：

```text
!leader option+space
```

也支持 `!leader f12`。修饰键使用 `control`、`option`、`shift`、`command`，普通键至少配一个修饰键；功能键 F1–F20 可单独使用。这一设置独立于分组上下文，只能出现一次。

## 保存和执行

保存后自动重载；正在导航时暂时保留本次树，退出后采用新配置。语法错误包含行号，保留上次有效配置。支持 UTF-8、BOM、LF/CRLF。

脚本工作目录为用户主目录，PATH 包含 `/opt/homebrew/bin`、`/usr/local/bin` 和进程原有路径。为避免启动延迟不读取用户 `.zprofile` / `.zshrc`；需要环境时显式 source。输出默认丢弃，非零退出码会提示；调试可重定向到自己的日志。脚本需要的系统权限由 macOS 提示。

## 迁移

本次升级将旧配置转换为 preluderc，保留原按键、名称、动作和顺序，编辑配置动作改为新路径。旧 TOML 保存为同目录带时间戳的备份，不再加载。不要在 shell 中粘贴 Markdown 链接，应写 `open https://github.com`。

如需转换其他旧的 0.2 TOML，使用 Python 3.11+：

```sh
python3 scripts/migrate_to_preluderc.py /path/old.toml /path/preluderc
./dist/Prelude.app/Contents/MacOS/Prelude --check-config /path/preluderc
```

转换器不覆盖已存在的目标，不执行脚本。旧多行脚本通过 zsh 字符串包装，保留换行语义。含 DSL 保留按键或名称分隔符的旧节点会要求手动处理，不会静默丢弃。

## 开发

macOS 14+，Xcode / Swift 5.9+，当前构建为 Apple Silicon。应用本身没有第三方包依赖，已移除 TOMLKit。

```sh
swift test
./scripts/build.sh
open dist/Prelude.app
```

Xcode 打开 `Package.swift`。`--check-config /path/preluderc` 仅校验后退出；`--config /path/preluderc` 使用独立配置；`--preview` 不注册全局键也不执行动作。

主要源码：`PreludeRC.swift` 解析 DSL；`Configuration.swift` 构造树和导航索引；`BranchRouting.swift` 生成公共主干；`TreeView.swift` 绘制；`AppModel.swift` 管理输入/重载；`ActionRunner.swift` 执行 shell。

本地 ad-hoc 签名，无 Developer ID 公证、自动更新、开机自启。具体验证范围见 VALIDATION.md。
