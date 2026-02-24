#!/bin/bash

ST_DIR="$HOME/SillyTavern"

# 获取版本
get_st_version() {
    if [[ -f "$ST_DIR/package.json" ]]; then
        jq -r .version "$ST_DIR/package.json"
    else
        echo "未安装"
    fi
}

# 检查运行状态
is_st_running() {
    if command -v pm2 &>/dev/null; then
        # Use --no-color to avoid escape codes interfering with grep
        if pm2 list --no-color | grep -q "SillyTavern.*online"; then
            return 0
        fi
    fi
    # Match server.js with any arguments (e.g. --max-old-space-size)
    if command -v pgrep &>/dev/null; then
        pgrep -f "server.js" > /dev/null
    else
        ps -ef 2>/dev/null | grep "server.js" | grep -v grep > /dev/null
    fi
}

# 状态显示文本
st_status_text() {
    local ver=$(get_st_version)
    local status
    if is_st_running; then
        status="${GREEN}运行中 (PM2/Process)${RESET}"
    else
        status="${RED}已停止${RESET}"
    fi
    echo -e "SillyTavern: ${GREEN}$ver${RESET} | $status"
}

# ==============================================================================
# 原有功能：安装
# ==============================================================================
st_install() {
    echo -e "${BLUE}开始安装 SillyTavern (Release分支)...${RESET}"
    # 使用 --depth 1 减少下载体积
    git clone --depth 1 --branch release https://github.com/SillyTavern/SillyTavern "$ST_DIR"
    cd "$ST_DIR" || return
    echo -e "${BLUE}安装 npm 依赖...${RESET}"
    npm install
    success "安装完成"
    pause
}

# ==============================================================================
# 原有功能：启动（PM2模式 - 稳定）
# ==============================================================================
st_start() {
    if is_st_running; then
        warn "SillyTavern 已经在运行中"
        pause
        return
    fi

    if [[ ! -d "$ST_DIR" ]]; then
        warn "未检测到 SillyTavern，准备安装..."
        st_install
    fi

    # 检查 node_modules
    if [[ ! -d "$ST_DIR/node_modules" ]]; then
        warn "检测到依赖缺失，正在尝试修复..."
        cd "$ST_DIR" || return
        npm install
    fi

    echo -e "${GREEN}正在启动 SillyTavern...${RESET}"
    cd "$ST_DIR" || return

    if command -v pm2 &>/dev/null; then
        # 使用 PM2 启动
        if pm2 list | grep -q "SillyTavern"; then
            pm2 restart SillyTavern
        else
            pm2 start server.js --name SillyTavern --node-args="--max-old-space-size=4096"
        fi
    else
        # 降级方案
        nohup node --max-old-space-size=4096 server.js > st_output.log 2>&1 &
    fi

    # 等待几秒检查是否启动成功
    sleep 5
    if is_st_running; then
        success "SillyTavern 启动成功"

        # 尝试打开浏览器
        if command -v termux-open-url &>/dev/null; then
            termux-open-url "http://127.0.0.1:8000"
        elif command -v xdg-open &>/dev/null; then
            xdg-open "http://127.0.0.1:8000" &>/dev/null
        fi
    else
        err "启动失败，请查看日志"
        # 如果是依赖问题，提示用户
        if grep -q "MODULE_NOT_FOUND" st_output.log 2>/dev/null || pm2 logs SillyTavern --lines 20 --nostream 2>/dev/null | grep -q "MODULE_NOT_FOUND"; then
            err "检测到模块缺失错误。请尝试在菜单中选择 '常规更新' 或手动运行 'npm install'。"
        fi
        st_logs
    fi
    pause
}

# ==============================================================================
# 新增功能：实时监控模式启动（用于查看详细启动过程）
# ==============================================================================

# 实时日志美化输出
beautify_log_line() {
    local line="$1"
    local timestamp=$(date '+%H:%M:%S')
    
    # 写入实时日志
    if [[ -n "$REALTIME_LOG" ]]; then
        echo "[$timestamp] $line" >> "$REALTIME_LOG" 2>/dev/null || true
    fi
    
    # 根据内容类型美化显示
    case "$line" in
        *"successfully"*|*"Successfully"*|*"done"*|*"Done"*)
            echo -e "${LOG_COLOR_TIME}[${timestamp}]${RESET} ${LOG_COLOR_SUCCESS}✓${RESET} ${LOG_COLOR_SUCCESS}${line}${RESET}"
            ;;
        *"error"*|*"Error"*|*"ERROR"*|*"failed"*|*"Failed"*)
            echo -e "${LOG_COLOR_TIME}[${timestamp}]${RESET} ${LOG_COLOR_ERROR}✗${RESET} ${LOG_COLOR_ERROR}${line}${RESET}"
            ;;
        *"warn"*|*"Warn"*|*"WARN"*|*"warning"*|*"Warning"*)
            echo -e "${LOG_COLOR_TIME}[${timestamp}]${RESET} ${LOG_COLOR_WARN}⚠${RESET} ${LOG_COLOR_WARN}${line}${RESET}"
            ;;
        *"Server running"*|*"listening on"*|*"SillyTavern is listening"*)
            echo -e "${LOG_COLOR_TIME}[${timestamp}]${RESET} ${LOG_COLOR_SUCCESS}🚀${RESET} ${LOG_COLOR_SUCCESS}${line}${RESET}"
            ;;
        *"http://"*|*"https://"*|*"Go to:"*)
            echo -e "${LOG_COLOR_TIME}[${timestamp}]${RESET} ${LOG_COLOR_INFO}🔗${RESET} ${LOG_COLOR_INFO}${line}${RESET}"
            ;;
        *"Compiling"*|*"webpack"*|*"compiled"*)
            echo -e "${LOG_COLOR_TIME}[${timestamp}]${RESET} ${LOG_COLOR_SYSTEM}⚙${RESET} ${LOG_COLOR_SYSTEM}${line}${RESET}"
            ;;
        *"Extensions"*|*"Extension"*|*"Loading"*|*"Loaded"*)
            echo -e "${LOG_COLOR_TIME}[${timestamp}]${RESET} ${LOG_COLOR_EMOJI}📦${RESET} ${line}"
            ;;
        *"character"*|*"Character"*|*"avatar"*|*"Avatar"*)
            echo -e "${LOG_COLOR_TIME}[${timestamp}]${RESET} ${LOG_COLOR_EMOJI}👤${RESET} ${line}"
            ;;
        *"chat"*|*"Chat"*|*"message"*|*"Message"*)
            echo -e "${LOG_COLOR_TIME}[${timestamp}]${RESET} ${LOG_COLOR_EMOJI}💬${RESET} ${line}"
            ;;
        *"Generating"*|*"generate"*|*"API"*|*"api"*|*"tokenizer"*)
            echo -e "${LOG_COLOR_TIME}[${timestamp}]${RESET} ${LOG_COLOR_INFO}🤖${RESET} ${LOG_COLOR_INFO}${line}${RESET}"
            ;;
        *"Copied"*|*"copied"*|*"Copying"*|*"copy"*)
            echo -e "${LOG_COLOR_TIME}[${timestamp}]${RESET} ${LOG_COLOR_INFO}📋${RESET} ${line}"
            ;;
        *"Image"*|*"image"*|*"background"*|*"Background"*)
            echo -e "${LOG_COLOR_TIME}[${timestamp}]${RESET} ${LOG_COLOR_EMOJI}🖼${RESET} ${line}"
            ;;
        *)
            echo -e "${LOG_COLOR_TIME}[${timestamp}]${RESET} ${LOG_COLOR_INFO}ℹ${RESET} ${line}"
            ;;
    esac
}

# 显示启动横幅
show_monitor_banner() {
    clear
    echo -e "${LOG_COLOR_SYSTEM}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║           SillyTavern 实时监控启动模式                       ║"
    echo "║           Real-time Monitor Mode                             ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
    echo -e "${LOG_COLOR_INFO}启动时间: $(date '+%Y-%m-%d %H:%M:%S')${RESET}"
    echo -e "${LOG_COLOR_INFO}日志文件: ${REALTIME_LOG:-$ST_DIR/st_output.log}${RESET}"
    echo -e "${LOG_COLOR_WARN}提示: 按 Ctrl+C 停止服务器${RESET}\\n"
    echo -e "${LOG_COLOR_SYSTEM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\\n"
}

# 显示停止摘要
show_monitor_stop() {
    local start_time="$1"
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    
    echo -e "\\n${LOG_COLOR_SYSTEM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${LOG_COLOR_WARN}SillyTavern 已停止${RESET}"
    echo -e "${LOG_COLOR_INFO}运行时长: ${minutes}分${seconds}秒${RESET}"
    echo -e "${LOG_COLOR_SYSTEM}═══════════════════════════════════════════════════════════════${RESET}\\n"
}

# 新增：实时监控模式启动
st_start_monitor() {
    if is_st_running; then
        warn "SillyTavern 已经在运行中（PM2模式）"
        echo -e "${YELLOW}请先停止当前实例，或使用常规启动模式${RESET}"
        pause
        return
    fi

    if [[ ! -d "$ST_DIR" ]]; then
        warn "未检测到 SillyTavern，准备安装..."
        st_install
    fi

    # 检查依赖
    if [[ ! -d "$ST_DIR/node_modules" ]]; then
        warn "检测到依赖缺失，正在尝试修复..."
        cd "$ST_DIR" || return
        npm install
    fi

    # 初始化日志
    if declare -f init_realtime_log > /dev/null; then
        init_realtime_log
    fi

    cd "$ST_DIR" || return
    
    show_monitor_banner
    
    local start_time=$(date +%s)
    
    echo -e "${CYAN}正在以前台模式启动 SillyTavern（实时监控）...${RESET}\\n"
    
    # 前台启动并实时美化输出
    npm start 2>&1 | while IFS= read -r line; do
        beautify_log_line "$line"
        
        # 检测启动成功
        if [[ "$line" == *"Server running"* ]] || [[ "$line" == *"SillyTavern is listening"* ]]; then
            echo -e "\\n${LOG_COLOR_SUCCESS}═══════════════════════════════════════════════════════════════${RESET}"
            echo -e "${LOG_COLOR_SUCCESS}  ✓ SillyTavern 启动成功！${RESET}"
            echo -e "${LOG_COLOR_INFO}  访问地址: http://127.0.0.1:8000/${RESET}"
            echo -e "${LOG_COLOR_SUCCESS}═══════════════════════════════════════════════════════════════${RESET}\\n"
            
            # 尝试打开浏览器
            if command -v termux-open-url &>/dev/null; then
                termux-open-url "http://127.0.0.1:8000" &
            elif command -v xdg-open &>/dev/null; then
                xdg-open "http://127.0.0.1:8000" &>/dev/null &
            fi
        fi
    done
    
    # 停止后显示摘要
    show_monitor_stop "$start_time"
    
    pause
}

# ==============================================================================
# 原有功能：查看日志
# ==============================================================================
st_logs() {
    local log_file="$ST_DIR/st_output.log"

    if command -v pm2 &>/dev/null && pm2 list | grep -q "SillyTavern"; then
        local pm2_log_out="$HOME/.pm2/logs/SillyTavern-out.log"
        local pm2_log_err="$HOME/.pm2/logs/SillyTavern-error.log"

        if [[ -f "$pm2_log_err" ]]; then
            log_file="$pm2_log_err"
        elif [[ -f "$pm2_log_out" ]]; then
            log_file="$pm2_log_out"
        fi
    fi

    if [[ -f "$log_file" ]]; then
        while true; do
            clear
            echo -e "${BLUE}=== SillyTavern 日志 ($(basename "$log_file")) ===${RESET}"
            tail -n 30 "$log_file"
            echo -e "\\n${BLUE}========================================${RESET}"
            echo -e "按 ${GREEN}Enter${RESET} 刷新日志，按 ${RED}0${RESET} 退出"
            read -rsn1 key
            if [[ "$key" == "0" ]]; then break; fi
        done
    else
        warn "暂无日志文件: $log_file"
        pause
    fi
}

# ==============================================================================
# 新增功能：查看实时监控日志
# ==============================================================================
st_monitor_logs() {
    echo -e "\\n${CYAN}==== SillyTavern 实时监控日志 ====${RESET}"
    
    if [[ -f "$REALTIME_LOG" ]]; then
        local total_lines=$(wc -l < "$REALTIME_LOG" 2>/dev/null || echo "0")
        local log_size=$(stat -c%s "$REALTIME_LOG" 2>/dev/null || stat -f%z "$REALTIME_LOG" 2>/dev/null || echo "0")
        local size_mb=$(awk "BEGIN {printf \"%.2f\", $log_size/1024/1024}")
        
        echo -e "${CYAN}日志路径: $REALTIME_LOG${RESET}"
        echo -e "${CYAN}日志大小: ${size_mb} MB | 总行数: $total_lines${RESET}\\n"
        
        echo -e "${YELLOW}最近 100 行日志:${RESET}\\n"
        tail -n 100 "$REALTIME_LOG"
        
        echo -e "\\n${CYAN}提示: 完整日志保存在手机存储的 SillyTavern/ST-Manager-Logs/ 目录${RESET}"
    else
        echo -e "${YELLOW}暂无实时监控日志${RESET}"
        echo -e "${CYAN}提示: 使用「实时监控启动」模式可生成实时日志${RESET}"
    fi
    pause
}

# ==============================================================================
# 原有功能：停止
# ==============================================================================
st_stop() {
    if command -v pm2 &>/dev/null && pm2 list | grep -q "SillyTavern"; then
        pm2 stop SillyTavern
        success "SillyTavern 已停止 (PM2)"
    elif is_st_running; then
        pkill -f "node server.js"
        success "SillyTavern 已停止 (Process)"
    else
        warn "SillyTavern 未运行"
    fi
    pause
}

# ==============================================================================
# 原有功能：重启
# ==============================================================================
st_restart() {
    st_stop
    sleep 1
    st_start
}

# ==============================================================================
# 原有功能：更新菜单
# ==============================================================================
st_update_menu() {
    while true; do
        clear
        echo -e "${BLUE}=== SillyTavern 更新管理 ===${RESET}"
        echo -e " ${GREEN}1)${RESET} 常规更新 (git pull)"
        echo -e " ${GREEN}2)${RESET} 强制修复更新 (重置到远程版本)"
        echo -e " ${GREEN}0)${RESET} 返回"
        read -rp "选择: " opt
        case "$opt" in
            1)
                cd "$ST_DIR" || return
                echo -e "${BLUE}执行 git pull...${RESET}"
                git pull
                echo -e "${BLUE}更新依赖...${RESET}"
                npm install
                success "更新完成"
                pause
                ;;
            2)
                echo -e "${RED}警告: 这将丢弃所有对核心文件的本地修改！(不影响数据)${RESET}"
                read -rp "确认执行? (y/n): " confirm
                if [[ "$confirm" == "y" ]]; then
                    cd "$ST_DIR" || return
                    echo -e "${BLUE}获取最新代码...${RESET}"
                    git fetch --all
                    # 获取当前分支名
                    local branch=$(git rev-parse --abbrev-ref HEAD)
                    echo -e "${BLUE}重置分支 $branch 到远程状态...${RESET}"
                    git reset --hard "origin/$branch"
                    echo -e "${BLUE}更新依赖...${RESET}"
                    npm install
                    success "强制更新完成"
                fi
                pause
                ;;
            0) break ;;
            *) ;;
        esac
    done
}

# ==============================================================================
# 原有功能：切换分支
# ==============================================================================
st_switch_branch() {
    cd "$ST_DIR" || return
    echo -e "${BLUE}当前分支: $(git rev-parse --abbrev-ref HEAD)${RESET}"
    echo -e " ${GREEN}1)${RESET} 切换到 Release (稳定版)"
    echo -e " ${GREEN}2)${RESET} 切换到 Staging (测试版)"
    read -rp "选择: " opt
    case "$opt" in
        1)
            git checkout release && git pull && npm install
            success "已切换到 Release"
            ;;
        2)
            git checkout staging && git pull && npm install
            success "已切换到 Staging"
            ;;
    esac
    pause
}

# ==============================================================================
# 原有功能：备份
# ==============================================================================
st_backup_menu() {
    # 设置新的备份目录
    local BACKUP_DIR="/storage/emulated/0/ST"
    local backup_file="$BACKUP_DIR/st_backup_$(date +%Y%m%d_%H%M%S).zip"

    # 创建备份目录
    mkdir -p "$BACKUP_DIR"

    echo -e "${BLUE}正在备份数据到 $backup_file ...${RESET}"
    if [[ -d "$ST_DIR" ]]; then
        cd "$ST_DIR" || return
        # 检查 zip 是否安装
        if ! command -v zip &>/dev/null; then
            pkg install zip -y
        fi

        if zip -r "$backup_file" public data config.yaml; then
            success "备份完成: $backup_file"
        else
            err "备份失败"
        fi
    else
        err "目录不存在"
    fi
    pause
}

# ==============================================================================
# 原有功能：恢复（修复版）
# ==============================================================================
st_restore_menu() {
    local BACKUP_DIR="/storage/emulated/0/ST"
    local ST_DIR="$HOME/SillyTavern"

    echo -e "${BLUE}=== SillyTavern 数据恢复 ===${RESET}"

    # 查找备份文件
    local found_backups=()
    for f in "$BACKUP_DIR"/st_backup_*.zip; do
        [[ -f "$f" ]] && found_backups+=("$f")
    done

    # 兼容旧位置
    for f in "$HOME"/st_backup_*.zip; do
        [[ -f "$f" ]] && found_backups+=("$f")
    done

    if [[ ${#found_backups[@]} -eq 0 ]]; then
        err "没有找到备份文件"
        echo -e "${YELLOW}备份文件通常位于: /storage/emulated/0/ST/${RESET}"
        pause
        return
    fi

    # 去重并显示
    echo -e "${YELLOW}可用的备份文件:${RESET}"
    local unique_backups=()
    local seen=()
    local i=1

    for backup in "${found_backups[@]}"; do
        local basename=$(basename "$backup")
        if [[ ! " ${seen[@]} " =~ " ${basename} " ]]; then
            seen+=("$basename")
            unique_backups+=("$backup")
            local size=$(du -h "$backup" 2>/dev/null | cut -f1)
            echo -e " ${GREEN}$i)${RESET} $basename ($size)"
            ((i++))
        fi
    done

    echo -e " ${RED}0)${RESET} 返回"
    echo ""

    read -rp "请选择要恢复的备份 [0-$((i-1))]: " choice

    if [[ "$choice" == "0" ]]; then
        return
    fi

    if [[ "$choice" -ge 1 && "$choice" -lt "$i" ]]; then
        local selected_backup="${unique_backups[$((choice-1))]}"
        local basename=$(basename "$selected_backup")

        echo ""
        echo -e "${YELLOW}将要恢复: $basename${RESET}"
        echo -e "${RED}警告: 这将覆盖当前的 data 目录！${RESET}"
        echo ""

        read -rp "确认恢复? (y/N): " confirm

        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            cd "$ST_DIR" || {
                err "无法进入 $ST_DIR"
                pause
                return
            }

            # 停止 SillyTavern
            echo -e "${BLUE}正在停止 SillyTavern...${RESET}"
            if command -v pm2 &>/dev/null && pm2 list | grep -q "SillyTavern"; then
                pm2 stop SillyTavern
            elif pgrep -f "server.js" > /dev/null; then
                pkill -f "node server.js"
            fi
            sleep 2

            # 强制停止
            if pgrep -f "server.js" > /dev/null; then
                pkill -9 -f "node server.js"
                sleep 1
            fi

            # 备份当前数据
            local current_backup="data.backup.$(date +%Y%m%d_%H%M%S)"
            if [[ -d "data" ]]; then
                echo -e "${BLUE}正在备份当前数据到: $current_backup${RESET}"
                mv data "$current_backup"
            fi

            # 解压恢复（关键：指定解压目录）
            echo -e "${BLUE}正在解压恢复...${RESET}"
            if unzip -o "$selected_backup" -d "$ST_DIR/"; then
                success "解压成功"

                # 验证恢复结果
                if [[ -d "data" ]]; then
                    success "数据目录已恢复"
                    echo -e "${YELLOW}恢复的文件:${RESET}"
                    ls -la data/ | head -10

                    # 检查关键文件
                    if [[ -f "data/default-user/settings.json" ]]; then
                        success "验证通过: 设置文件存在"
                    fi

                    success "恢复完成！请重新启动 SillyTavern"
                else
                    err "错误: 解压后未找到 data 目录"
                    # 恢复原数据
                    if [[ -d "$current_backup" ]]; then
                        mv "$current_backup" data
                        echo -e "${BLUE}已恢复原数据${RESET}"
                    fi
                fi
            else
                err "解压失败"
                # 恢复原数据
                if [[ -d "$current_backup" ]]; then
                    mv "$current_backup" data
                    echo -e "${BLUE}已恢复原数据${RESET}"
                fi
            fi
        fi
    else
        err "无效选择"
    fi

    pause
}
