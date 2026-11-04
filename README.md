# WorkBuddy 账号一键切换

Windows 桌面版 WorkBuddy 的当前登录账号保存在一个**全局唯一**的认证文件里：

```
%LOCALAPPDATA%\CodeBuddyExtension\Data\Public\auth\workbuddy-desktop.info
```

因此无法通过独立配置目录或伪造用户目录实现「双账号并行」：新实例必然复用同一个登录态（伪造 `USERPROFILE` 还会导致程序直接退出）。

但该文件内同时保存了历史登录过账号的凭据（`account` / `accounts` / `allAccounts`），并且程序会监听文件的外部变更并实时应用。本工具利用这一点，在多个账号的登录态之间一键切换，**不需要重新扫码或登录**。

## 前提条件

- 桌面版 WorkBuddy（默认安装路径 `C:\Program Files\WorkBuddy\WorkBuddy.exe`，其他路径请修改脚本中的 `$exe`）
- 至少登录过两个账号（每个账号都需完整登录一次，之后才会被缓存）

## 使用方法

```powershell
# 1. 查看已缓存的账号
.\switch-workbuddy.ps1 -List

# 2. 切换到指定账号（用 uid 前缀即可）
.\switch-workbuddy.ps1 -Account 4ce247bd

# 3. 为每个账号创建桌面快捷方式（可选）
.\install-shortcuts.ps1
```

双击桌面上的 `WorkBuddy 账号N` 图标：

- WorkBuddy 已运行 → 账号实时切换（几秒内生效）
- WorkBuddy 未运行 → 先切换登录态，再自动启动

首次使用 `install-shortcuts.ps1` 或 `switch-workbuddy.ps1` 前，Windows 可能提示执行策略限制，可使用：

```powershell
powershell -ExecutionPolicy Bypass -File .\switch-workbuddy.ps1 -List
```

## 工作原理

1. 启动时扫描认证目录中的 `workbuddy-desktop.info` 和历史备份 `workbuddy-desktop.*.info`，按 `account.uid` 去重，取最新文件。
2. 每个账号的登录态被保存为 `%LOCALAPPDATA%\WorkBuddySwitch\account-<uid前8位>.info` 快照。
3. 切换时：
   - 先把当前账号的最新认证文件覆盖回自己的快照（避免 token 刷新丢失）；
   - 再把目标账号的快照原子替换到 `workbuddy-desktop.info`；
   - 删除可能残留的 `workbuddy-desktop.info.logged-out` 标记；
   - 若 WorkBuddy 未运行则启动它。
4. WorkBuddy 检测到认证文件变化后会自动应用新会话。

## 注意事项

- **非官方用法**：依赖 WorkBuddy 内部文件格式，客户端大版本更新后可能失效。
- 不要删除 `%LOCALAPPDATA%\WorkBuddySwitch` 目录，否则已缓存的登录态会丢失，需要重新登录。
- 快照中保存的是本机加密的登录凭据，**仅限本机使用**，不要上传或分发。
- 某个账号 token 过期时会被要求重新登录，登录完成后再切走一次，脚本会自动保存新的登录态。
- 同一时刻只能有一个账号生效（所有窗口共享同一个登录态）。
- 请自行评估风险，使用本工具造成的账号登出、数据异常等情况由使用者自行承担。

## 卸载

1. 删除桌面上的 `WorkBuddy 账号N.lnk`
2. 删除 `%LOCALAPPDATA%\WorkBuddySwitch` 目录
3. 需要把某个账号设为默认时，直接在 WorkBuddy 内正常登录即可

## 相关：Trae CN 双账号

Trae CN（VS Code 内核）支持 `--user-data-dir` 独立配置目录，可以真正实现两个账号的独立窗口，无需切换脚本：

```
"Trae CN.exe" --user-data-dir="<独立目录>"
```

为每个账号分别创建一个指向上述命令的快捷方式即可。
