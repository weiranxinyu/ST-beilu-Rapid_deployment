# ST-Manager (Termux 版)

专为 Android Termux 用户设计的 SillyTavern (酒馆) 和 gcli2api 管理工具。
本项目基于“随行”项目二次开发，精简了冗余功能，专注于核心体验与稳定性修复。

## ✨ 功能特点

### 🍷 SillyTavern (酒馆) 管理

* **一键安装/启动/停止**: 自动化环境配置，开箱即用。
* **强制更新修复**: 独家“强制修复”功能，解决因本地文件冲突导致的 `git pull` 失败问题。
* **分支切换**: 自由切换 Release (稳定版) 和 Staging (测试版)。
* **数据备份**: 一键打包备份用户数据 (public/data/config)。

### 🔗 gcli2api 集成

* **一键部署**: 自动安装 Python 环境及依赖。
* **后台运行**: 支持后台静默运行，并提供日志查看功能。

## 🚀 安装说明

### 方法 1: 一键安装 (推荐)

复制以下命令并在 Termux 中粘贴运行：

```bash
bash <(curl -sL https://raw.githubusercontent.com/beilusaiying/ST-beilu-Rapid_deployment/main/install.sh)
```

### 方法 2: 手动安装 (Git Clone)

如果你无法使用一键安装，可以尝试手动克隆仓库：

```bash
# 克隆仓库
git clone https://github.com/beilusaiying/ST-beilu-Rapid_deployment ST-Manager

# 进入目录
cd ST-Manager

# 赋予权限并安装
chmod +x install.sh && ./install.sh
```

### 启动管理菜单

安装完成后，可以通过以下命令随时启动管理菜单：

```bash
bash ~/ST-Manager/manager/core.sh
```

## 📖 使用指南

启动脚本后，你将看到交互式菜单：

1. **状态监控**: 顶部实时显示 SillyTavern 和 gcli2api 的运行状态及版本号。
2. **SillyTavern 操作**:
    * 选择 `3) 更新` -> `2) 强制修复更新` 可解决大部分更新失败问题。
3. **系统管理**:
    * 如果遇到报错，尝试使用 `10) 修复运行环境` 重装系统依赖。

## ⚠️ 注意事项

* **强制更新警告**: 使用“强制修复更新”会重置 SillyTavern 的核心代码文件，但**不会**删除你的聊天记录、角色卡和配置文件。
* **网络问题**: 请确保你的 Termux 可以正常访问 GitHub，必要时请配置代理。

## 致谢

* 原项目: [随行 (Eralink)](https://github.com/404nyaFound/eralink)
* SillyTavern: [SillyTavern](https://github.com/SillyTavern/SillyTavern)
* gcli2api: [gcli2api](https://github.com/su-kaka/gcli2api)
