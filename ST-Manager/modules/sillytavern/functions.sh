#!/bin/bash

# ==============================================================================
# SillyTavern 管理模块 - 带实时日志监控
# ==============================================================================

# 检查 SillyTavern 运行状态
st_status_text() {
    if pgrep -f "node.*server.js" > /dev/null 2>&1; then
        echo -e "${GREEN}● SillyTavern 运行中${RESET} | 地址: http://127.0.0.1:8000/"
    else
        echo -e "${RED}● SillyTavern 未运行${RESET}"
    fi
}

# 实时日志美化输出
beautify_log_line() {
    local line="$1"
    local timestamp=$(date '+%H:%M:%S')
    
    # 写入原始日志
    echo "[$timestamp] $line" >> "$REALTIME_LOG" 2>/dev/null || true
    
    # 根据内容类型美化显示
    case "$line" in
        # 成功信息
        *"successfully"*|*"Successfully"*|*"done"*|*"Done"*)
            echo -e "${LOG_COLOR_TIME}[${timestamp}]${RESET} ${LOG_COLOR_SUCCESS}✓${RESET} ${LOG_COLOR_SUCCESS}${line}${RESET}"
            ;;
        # 错误信息
        *"error"*|*"Error"*|*"ERROR"*|*"failed"*|*"Failed"*)
            echo -e "${LOG_COLOR_TIME}[${timestamp}]${RESET} ${LOG_COLOR_ERROR}✗${RESET} ${LOG_COLOR_ERROR}${line}${RESET}"
            ;;
        # 警告信息
        *"warn"*|*"Warn"*|*"WARN"*|*"warning"*|*"Warning"*)
            echo -e "${LOG_COLOR_TIME}[${timestamp}]${RESET} ${LOG_COLOR_WARN}⚠${RESET} ${LOG_COLOR_WARN}${line}${RESET}"
            ;;
        # 服务器启动
        *"Server running"*|*"listening on"*|*"SillyTavern is listening"*)
            echo -e "${LOG_COLOR_TIME}[${timestamp}]${RESET} ${LOG_COLOR_SUCCESS}🚀${RESET} ${LOG_COLOR_SUCCESS}${line}${RESET}"
            write_log "INFO" "SillyTavern 服务器已启动"
            ;;
        # URL 地址
        *"http://"*|*"https://"*|*"Go to:"*)
            echo -e "${LOG_COLOR_TIME}[${timestamp}]${RESET} ${LOG_COLOR_INFO}🔗${RESET} ${LOG_COLOR_INFO}${line}${RESET}"
            ;;
        # 编译信息
        *"Compiling"*|*"webpack"*|*"compiled"*)
            echo -e "${LOG_COLOR_TIME}[${timestamp}]${RESET} ${LOG_COLOR_SYSTEM}⚙${RESET} ${LOG_COLOR_SYSTEM}${line}${RESET}"
            ;;
        # 扩展/插件加载
        *"Extensions"*|*"Extension"*|*"Loading"*|*"Loaded"*)
            echo -e "${LOG_COLOR_TIME}[${timestamp}]${RESET} ${LOG_COLOR_EMOJI}📦${RESET} ${line}"
            ;;
        # 角色卡相关
        *"character"*|*"Character"*|*"avatar"*|*"Avatar"*)
            echo -e "${LOG_COLOR_TIME}[${timestamp}]${RESET} ${LOG_COLOR_EMOJI}👤${RESET} ${line}"
            ;;
        # 聊天相关
        *"chat"*|*"Chat"*|*"message"*|*"Message"*)
            echo -e "${LOG_COLOR_TIME}[${timestamp}]${RESET} ${LOG_COLOR_EMOJI}💬${RESET} ${line}"
            ;;
        # API 请求
        *"Generating"*|*"generate"*|*"API"*|*"api"*|*"tokenizer"*)
            echo -e "${LOG_COLOR_TIME}[${timestamp}]${RESET} ${LOG_COLOR_INFO}🤖${RESET} ${LOG_COLOR_INFO}${line}${RESET}"
            ;;
        # 数据复制/移动
        *"Copied"*|*"copied"*|*"Copying"*|*"copy"*)
            echo -e "${LOG_COLOR_TIME}[${timestamp}]${RESET} ${LOG_COLOR_INFO}📋${RESET} ${line}"
            ;;
        # 图片/背景
        *"Image"*|*"image"*|*"background"*|*"Background"*)
            echo -e "${LOG_COLOR_TIME}[${timestamp}]${RESET} ${LOG_COLOR_EMOJI}🖼${RESET} ${line}"
            ;;
        # 默认信息
        *)
            echo -e "${LOG_COLOR_TIME}[${timestamp}]${RESET} ${LOG_COLOR_INFO}ℹ${RESET} ${line}"
            ;;
    esac
}

# 显示启动横幅
show_start_banner() {
    clear
    echo -e "${LOG_COLOR_SYSTEM}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║           SillyTavern 实时运行监控                           ║"
    echo "║           Real-time Runtime Monitor                          ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
    echo -e "${LOG_COLOR_INFO}启动时间: $(date '+%Y-%m-%d %H:%M:%S')${RESET}"
    echo -e "${LOG_COLOR_INFO}日志文件: $REALTIME_LOG${RESET}"
    echo -e "${LOG_COLOR_WARN}提示: 按 Ctrl+C 停止服务器${RESET}\\n"
    echo -e "${LOG_COLOR_SYSTEM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\\n"
}

# 显示停止摘要
show_stop_summary() {
    local start_time="$1"
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    
    echo -e "\\n${LOG_COLOR_SYSTEM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${LOG_COLOR_WARN}SillyTavern 已停止${RESET}"
    echo -e "${LOG_COLOR_INFO}运行时长: ${minutes}分${seconds}秒${RESET}"
    echo -e "${LOG_COLOR_INFO}日志保存至: $REALTIME_LOG${RESET}"
    echo -e "${LOG_COLOR_SYSTEM}═══════════════════════════════════════════════════════════════${RESET}\\n"
    
    write_log "INFO" "SillyTavern 停止，运行时长: ${minutes}分${seconds}秒"
}

# 启动 SillyTavern（带实时监控）
st_start() {
    # 检查是否已在运行
    if pgrep -f "node.*server.js" > /dev/null 2>&1; then
        warn "SillyTavern 已经在运行中"
        echo -e "${CYAN}访问地址: http://127.0.0.1:8000/${RESET}"
        pause
        return
    fi
    
    # 依赖检查
    if ! command -v node &>/dev/null; then
        err "Node.js 未安装，请先修复环境"
        pause
        return
    fi
    
    # 检查目录
    local sillytavern_dir="$HOME/SillyTavern"
    if [[ ! -d "$sillytavern_dir" ]]; then
        err "SillyTavern 未安装"
        pause
        return
    fi
    
    cd "$sillytavern_dir" || return
    
    # 检查 node_modules
    if [[ ! -d "node_modules" ]]; then
        warn "未检测到依赖，正在安装..."
        npm install --no-audit --no-fund --loglevel=error --omit=dev
    fi
    
    # 初始化日志
    init_realtime_log
    
    # 显示启动横幅
    show_start_banner
    
    local start_time=$(date +%s)
    
    # 启动 SillyTavern 并实时处理输出
    npm start 2>&1 | while IFS= read -r line; do
        beautify_log_line "$line"
        
        # 检测服务器启动完成
        if [[ "$line" == *"Server running"* ]] || [[ "$line" == *"SillyTavern is listening"* ]]; then
            echo -e "\\n${LOG_COLOR_SUCCESS}═══════════════════════════════════════════════════════════════${RESET}"
            echo -e "${LOG_COLOR_SUCCESS}  ✓ SillyTavern 启动成功！${RESET}"
            echo -e "${LOG_COLOR_INFO}  访问地址: http://127.0.0.1:8000/${RESET}"
            echo -e "${LOG_COLOR_SUCCESS}═══════════════════════════════════════════════════════════════${RESET}\\n"
        fi
    done
    
    # SillyTavern 停止
    show_stop_summary "$start_time"
    
    pause
}

# 停止 SillyTavern
st_stop() {
    log "正在停止 SillyTavern..."
    
    local pids=$(pgrep -f "node.*server.js" || true)
    if [[ -n "$pids" ]]; then
        echo "$pids" | while read pid; do
            kill -TERM "$pid" 2>/dev/null || true
        done
        sleep 2
        
        # 强制终止
        pids=$(pgrep -f "node.*server.js" || true)
        if [[ -n "$pids" ]]; then
            echo "$pids" | while read pid; do
                kill -KILL "$pid" 2>/dev/null || true
            done
        fi
        
        success "SillyTavern 已停止"
        write_log "INFO" "SillyTavern 已手动停止"
    else
        warn "SillyTavern 未在运行"
    fi
    pause
}

# 重启 SillyTavern
st_restart() {
    st_stop
    sleep 1
    st_start
}

# 查看 SillyTavern 日志
st_logs() {
    echo -e "\\n${CYAN}${BOLD}==== SillyTavern 实时运行日志 ====${RESET}"
    
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
        echo -e "${YELLOW}暂无运行日志${RESET}"
    fi
    pause
}

# 清理 SillyTavern 日志
st_clear_logs() {
    echo -e "\\n${CYAN}${BOLD}==== 清理实时日志 ====${RESET}"
    
    if [[ -f "$REALTIME_LOG" ]]; then
        local log_size=$(stat -c%s "$REALTIME_LOG" 2>/dev/null || stat -f%z "$REALTIME_LOG" 2>/dev/null || echo "0")
        local size_mb=$(awk "BEGIN {printf \"%.2f\", $log_size/1024/1024}")
        
        echo -e "${YELLOW}当前日志大小: ${size_mb} MB${RESET}"
        echo -ne "${YELLOW}确认清空? (y/n): ${RESET}"
        read -n1 confirm; echo
        
        if [[ "$confirm" =~ [yY] ]]; then
            > "$REALTIME_LOG"
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] 日志已清空" >> "$REALTIME_LOG"
            success "日志已清空"
        fi
    else
        echo -e "${YELLOW}暂无日志${RESET}"
    fi
    pause
}

# 打开 SillyTavern 目录
st_open_dir() {
    local st_dir="$HOME/SillyTavern"
    if [[ -d "$st_dir" ]]; then
        echo -e "${CYAN}SillyTavern 目录: $st_dir${RESET}"
        echo -e "${CYAN}数据目录: $st_dir/data${RESET}"
        echo -e "${CYAN}角色卡目录: $st_dir/public/characters${RESET}"
        echo -e "${CYAN}聊天记录: $st_dir/public/chats${RESET}"
        
        # 尝试打开文件管理器
        if command -v termux-open &>/dev/null; then
            termux-open "$st_dir" 2>/dev/null || true
        fi
    else
        err "SillyTavern 目录不存在"
    fi
    pause
}
