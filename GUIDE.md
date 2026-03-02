# Piano Godot Keyboard - 使用与配置指南

## 一、电脑键盘按键对照表（测试用）

没有 MIDI 键盘时，可用电脑键盘代替。布局模仿真实钢琴的两排结构：

### 低八度 (C3 ~ B3)

```
黑键:   S       D           G       H       J
        C#3     D#3         F#3     G#3     A#3

白键: Z       X       C       V       B       N       M
      C3      D3      E3      F3      G3      A3      B3
```

### 高八度 (C4 ~ B4) + C5

```
黑键:   2       3           5       6       7
        C#4     D#4         F#4     G#4     A#4

白键: Q       W       E       R       T       Y       U       I
      C4      D4      E4      F4      G4      A4      B4      C5
```

### 完整按键表

| 电脑键 | 音符 | Key ID |
|--------|------|--------|
| Z | C3 | 0 |
| S | C#3 | 1 |
| X | D3 | 2 |
| D | D#3 | 3 |
| C | E3 | 4 |
| V | F3 | 5 |
| G | F#3 | 6 |
| B | G3 | 7 |
| H | G#3 | 8 |
| N | A3 | 9 |
| J | A#3 | 10 |
| M | B3 | 11 |
| Q | C4 | 12 |
| 2 | C#4 | 13 |
| W | D4 | 14 |
| 3 | D#4 | 15 |
| E | E4 | 16 |
| R | F4 | 17 |
| 5 | F#4 | 18 |
| T | G4 | 19 |
| 6 | G#4 | 20 |
| Y | A4 | 21 |
| 7 | A#4 | 22 |
| U | B4 | 23 |
| I | C5 | 24 |

### 当前密码测试

密码是小星星前 9 个音：C C G G A A G F F

电脑键盘输入：**Z Z B B N N B V V**

---

## 二、如何修改密码

打开 `scripts/config.gd`，找到第 91 行：

```gdscript
var password_sequence: Array[int] = [0, 0, 7, 7, 9, 9, 7, 5, 5]
```

将数组中的数字替换为你想要的音符 Key ID。Key ID 对照表：

```
 0=C3    1=C#3   2=D3    3=D#3   4=E3    5=F3    6=F#3
 7=G3    8=G#3   9=A3   10=A#3  11=B3   12=C4   13=C#4
14=D4   15=D#4  16=E4   17=F4   18=F#4  19=G4   20=G#4
21=A4   22=A#4  23=B4   24=C5
```

### 示例

**改为 "生日快乐" 前 6 个音 (G G A G C5 B)：**

```gdscript
var password_sequence: Array[int] = [7, 7, 9, 7, 24, 23]
```

**改为简单 3 音密码 (C E G)：**

```gdscript
var password_sequence: Array[int] = [0, 4, 7]
```

密码长度不限，可以是 3 个音也可以是 20 个音。

---

## 三、如何修改密码揭示的图片

当前密码揭示使用灰色圆形。如需改回图片显示：

1. 在项目根目录创建 `images/password/` 文件夹
2. 放入图片，命名规则：`password_01.png`、`password_02.png`、...
3. 编号对应密码中每个**不重复**的琴键（按首次出现顺序）
4. 修改 `scripts/password_image.gd`，将 `_draw()` 圆形绘制替换为加载图片

当前灰色圆形的视觉参数在 `scripts/password_image.gd` 中：

```gdscript
const CIRCLE_RADIUS: float = 25.0                     # 圆形半径
const CIRCLE_COLOR: Color = Color(0.5, 0.5, 0.5, 1.0) # 灰色
```

---

## 四、系统整体逻辑

### 游戏流程

```
启动游戏
    |
    v
初始化 MIDI 连接 (OS.open_midi_inputs)
    |
    +-- 检测到 MIDI 设备 --> 使用 MIDI 输入
    +-- 未检测到 ----------> 降级为电脑键盘输入
    |
    v
显示 25 键钢琴 (15 白键 + 10 黑键，对应 LPK25)
    |
    v
【密码检测阶段】
    |  玩家弹奏任意键 --> 发出声音 + 视觉反馈
    |  同时将 key_id 送入 SequenceDetector
    |
    |  SequenceDetector 逐步比对:
    |    弹对当前步骤的音 --> 前进一步
    |    弹错 --> 静默重置到第 0 步
    |    (如果弹错的音恰好是密码第一个音，则从第 1 步开始)
    |
    |  全部步骤完成 --> 触发密码揭示
    |
    v
【密码揭示】
    |  按密码中每个不重复琴键的首次出现顺序
    |  每隔 0.5 秒在对应琴键上方淡入一个灰色圆形
    |  圆形永久停留
    |
    v
【自由演奏阶段】
    密码检测停用 (password_solved = true)
    玩家可以自由弹奏，只有声音和视觉反馈，不再触发任何检测
```

---

## 五、技术实现详解

### 文件结构

```
scripts/
  config.gd            # 全局配置单例 (Autoload)
  piano_manager.gd     # 钢琴管理器：创建琴键、处理输入、密码揭示
  piano_key.gd         # 单个琴键：视觉、音频、按下/释放
  sequence_detector.gd # 密码序列检测器
  password_image.gd    # 密码揭示的灰色圆形
  floating_character.gd# 浮动文字（保留，未使用）
  main.gd              # 主场景协调器
  video_player_overlay.gd # 视频播放（final stage 用）

scenes/
  main.tscn            # 主场景
  piano_key.tscn       # 琴键模板
  password_image.tscn  # 密码圆形模板
  floating_character.tscn
  video_player_overlay.tscn
```

### 核心模块说明

#### 1. Config (config.gd) - 全局配置

作为 Godot Autoload 单例，所有脚本通过 `Config.xxx` 访问。包含：
- 25 个音符的名称和 ID 映射
- MIDI 基准音设置 (`midi_base_note = 48`)
- 密码序列 (`password_sequence`)
- 琴键尺寸、音频路径、视觉参数
- 电脑键盘映射表

#### 2. PianoManager (piano_manager.gd) - 钢琴管理器

**职责：** 创建所有琴键、分发输入事件、管理密码揭示

**输入处理流程：**
```
_input(event)
    |
    +-- InputEventMIDI --> _handle_midi()
    |     将 MIDI pitch 转为 key_id
    |     NOTE_ON (velocity > 0) --> key.press() + 记录音符
    |     NOTE_OFF --> key.release()
    |
    +-- InputEventKey --> _handle_keyboard()
          将物理按键码转为 key_id（查 KEYBOARD_TO_KEY_ID 表）
          pressed --> key.press() + 记录音符
          released --> key.release()
```

**琴键创建：**
- 先创建 15 个白键，等间距排列
- 再创建 10 个黑键，叠在白键之间（通过 BLACK_KEY_AFTER_WHITE 查表定位）
- 黑键的 x 坐标 = 前一个白键右边缘 - 黑键宽度/2

#### 3. SequenceDetector (sequence_detector.gd) - 密码检测

**状态机逻辑：**
```
current_step = 0

record_note(key_id):
    if key_id == password_sequence[current_step]:
        current_step += 1
        if current_step == password_sequence.size():
            emit password_completed  # 密码完成！
    else:
        current_step = 0
        if key_id == password_sequence[0]:
            current_step = 1  # 这个音是密码开头，从第 1 步开始
```

这种设计的好处：
- 玩家不需要知道密码长度
- 弹错了不会有提示（静默重置）
- 可以无缝从错误中恢复（如果错误的音恰好是密码开头）

#### 4. PianoKey (piano_key.gd) - 单个琴键

每个琴键包含：
- `KeyVisual` (ColorRect) - 琴键外观
- `PressedOverlay` (ColorRect) - 按下时的蓝色半透明覆盖层
- `NotePlayer` (AudioStreamPlayer) - 音频播放
- `KeyLabel` (Label) - 底部显示音符名

按下时：改变颜色 + 播放音频 + 启动 4 秒音量渐弱 Tween
释放时：恢复颜色 + 停止音频 + 停止 Tween

#### 5. MIDI 连接

Godot 4.x 内置 MIDI 支持：
```gdscript
OS.open_midi_inputs()  # 在 _ready() 中调用，打开所有 MIDI 输入
```
之后 MIDI 事件自动通过 `_input()` 以 `InputEventMIDI` 类型传入。
关键属性：`event.pitch`（MIDI 音高 0-127）、`event.velocity`（力度）、`event.message`（消息类型）

MIDI 音高转 Key ID：`key_id = pitch - 48`（48 = C3 的 MIDI 编号）

---

## 六、可调参数速查

| 参数 | 文件位置 | 当前值 | 说明 |
|------|----------|--------|------|
| `password_sequence` | config.gd:91 | [0,0,7,7,9,9,7,5,5] | 密码序列 |
| `midi_base_note` | config.gd:23 | 48 | MIDI 最低音编号 |
| `PASSWORD_REVEAL_DELAY` | config.gd:107 | 0.5s | 圆形出现间隔 |
| `CIRCLE_RADIUS` | password_image.gd:5 | 25.0 | 圆形大小 |
| `CIRCLE_COLOR` | password_image.gd:6 | 灰色 | 圆形颜色 |
| `WHITE_KEY_WIDTH` | config.gd:118 | 80 | 白键宽度 |
| `WHITE_KEY_HEIGHT` | config.gd:119 | 300 | 白键高度 |
| `BLACK_KEY_WIDTH` | config.gd:120 | 44 | 黑键宽度 |
| `BLACK_KEY_HEIGHT` | config.gd:121 | 185 | 黑键高度 |
| `FADE_DURATION` | config.gd:127 | 4.0s | 按住键时音量渐弱时间 |

---

## 七、Android USB-C MIDI 键盘（AKAI LPK25）

### MIDI 音符范围与八度校准

本项目已针对 AKAI LPK25 配置。键盘默认音域：C4（MIDI 60）到 C6（MIDI 84），共 25 键。

若按键完全无响应，请先确认键盘八度：LPK25 上有 OCT- / OCT+ 按钮。默认状态下 C4=60。
若偏移，在 `scripts/config.gd` 中调整：

```gdscript
var midi_base_note: int = 60  # 若键盘显示偏低一格，改为 48；偏高一格改为 72
```

### 修改 Java 插件后必须重新编译 AAR

> **每次修改 `android/plugins/GodotMidiUSB/src/` 下的 Java 源码后，
> 必须重新编译 AAR，否则 APK 中仍是旧代码。**

**Windows 快速重建：**

```bat
cd android
plugins\rebuild_plugin.bat
```

**手动步骤：**

```bat
cd android
gradlew.bat :plugins:GodotMidiUSB:assembleRelease
copy plugins\GodotMidiUSB\build\outputs\aar\GodotMidiUSB-release.aar plugins\GodotMidiUSB-release.aar
```

完成后在 Godot 中重新导出 APK。

### 首次连接授权流程

1. 用 USB-C OTG 数据线连接 LPK25 到手机
2. Android 系统弹窗：**"Piano Keyboard 是否可以访问 USB 设备？"**
3. 勾选 **"始终允许此应用"** 并点确定
4. App 自动打开 MIDI 端口并开始接收音符

> 若无弹窗：请先打开 App，再插入键盘。
