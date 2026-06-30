# TiMidity++ Windows 汉化修改版

本仓库为 [TiMidity++](https://timidity.sourceforge.net) 的 Windows 构建版，提供中文界面及全部文档汉化，并修复使用中的一些问题。

![示意图](pic.png)

## 基本使用

在软件根目录创建 `timidity.cfg` 配置文件，用 `soundfont` 指定音色文件（支持 GUS Patch、SoundFont 2 和独立 PCM 采样），用 `opt` 设置启动参数。配置文件具体参考 `timidity.cfg.5.html`，命令行参数参考 `timidity.1.html`（汉化版本位于 `man/zh` 目录）。启动软件时会创建其他 `.ini` 配置文件。

本次构建提供命令行、播放器 GUI、合成器 GUI、合成器服务四种使用方法（驱动形式不适配现代系统，未参与构建）。

| **类型**      | **二进制文件** | **特点**                                 | **基础用法**                                                 |
| ------------- | -------------- | ---------------------------------------- | ------------------------------------------------------------ |
| 命令行（CLI） | `timidity.exe` | 命令行程序，无图形界面；基础功能最全面   | `-i` 或 `--interface` 参数指定控制台界面<br /> `-O` 或 `--output-mode` 参数指定输出方式 |
| 播放器 GUI    | `timw32g.exe`  | 有图形界面；支持 Tracer、WRD、DOC 等功能 | 略                                                           |
| 合成器 GUI    | `twsyng.exe`   | 托盘程序，有图形界面；支持设置输入端口   | 托盘右键设置选择输入端口，点击“合成器开始”                   |
| 合成器服务    | `twsynsrv.exe` | 用于注册/卸载合成器服务，无图形界面      | 终端 `twsynsrv /INSTALL` 安装服务，启动服务后主动监听<br />`twsynsrv /UNINSTALL` 卸载服务 |



## 修改内容

### 汉化

- 提供汉化界面支持
- 汉化所有内置文档

### 修复叠音

- 修正叠音条件，现在所有情况都允许叠音

### 输出方式

- 添加 PortAudio WASAPI 输出方式
- 为 PortAudio ASIO 添加简单的选项面板
- 添加 MP3 LAME 输出方式并提供选项面板

### 编码

- 修改界面部分源码编码为 GBK，解决中文系统环境下日文字符乱码问题
- 替换 CP936 不支持的字符和未预装的日文字体
- 修改默认设置，现在默认使用中文界面，编码设置为 nocnv
- 修复 DOC、WRD 中仅日文环境下正常显示的问题

### WRD 显示

- 修复 MAG 文件的 r4g4b4 颜色编码被错误解析为 g4r4b4 的问题
- 修复 WRD 命令未完整匹配字符串导致误识别的问题
- 补全 @GCIRCLE() 命令（绘制圆）的未完成代码
- 修复暂停时 WRD 画面提前的问题
- WRD 窗口适应标题栏和边框大小，确保显示区域为 640×400
- 修改默认设置，WRD 窗口默认开始绘制，打开文件时允许后台绘制

## 构建启用

### 界面

- `timw32g.exe` Windows GUI 界面
- `twsyng.exe` Windows 合成器 GUI 界面
- `timidity.exe` 命令行界面
  - dumb 界面（默认） `-id`
  - ncurses 界面 `-in`
  - vt100 界面 `-iT`
  - Windows 合成器界面 `-iW`


### 音频输出

- w32 (Windows MMS)（默认）
- PortAudio MME / DirectSound / ASIO / + WASAPI (新增)
- Vorbis OGG
- FLAC
- MP3 GOGO
  > 注：Gogo-No-Coda（午後のこ～だ），日本人写的 LAME 分支，是当时最快的 MP3 编码器；现早已停止维护
- \+ MP3 LAME (新增)
