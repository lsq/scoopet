#!/usr/bin/env bash
# lanzou_direct.sh
# 用法: ./lanzou_direct.sh -u "<分享链接>" [-p "<密码>"] [-n "<后缀>"] [-d]
# DEBUG=1 ./lanzou_direct.sh ... 打开调试输出
#
# 依赖: curl, jq, grep(-P), sed

set -euo pipefail

UA='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.121 Safari/537.36'

url=""
pwd_arg=""
suffix=""
do_down=0
DEBUG="${DEBUG:-0}"

dbg() {
    [ "$DEBUG" = "1" ] && echo "[DEBUG] $*" >&2
    return 0
}

while getopts "u:p:n:d" opt; do
    case "$opt" in
    u) url="$OPTARG" ;;
    p) pwd_arg="$OPTARG" ;;
    n) suffix="$OPTARG" ;;
    d) do_down=1 ;;
    esac
done

json_error() {
    jq -n --arg msg "$1" '{code:400, msg:$msg}'
    exit 1
}

[ -z "$url" ] && json_error "请输入URL"

# ---------- URL 规范化 ----------
if [[ "$url" =~ ^(https?)://([^/]+)(/[^?]*)?(\?(.*))?$ ]]; then
    scheme="${BASH_REMATCH[1]}"
    host="${BASH_REMATCH[2]}"
    path="${BASH_REMATCH[3]:-/}"
    query="${BASH_REMATCH[5]:-}"
else
    json_error "URL格式错误"
fi

origin="https://${host}"
url="${origin}${path}"
if [ -n "$query" ]; then
    url="${url}?${query}"
fi
webpage="$query"

# ---------- 随机 IP ----------
rand_ip() {
    local arr=(218 218 66 66 218 218 60 60 202 204 66 66 66 59 61 60 222 221 66 59 60 60 66 218 218 62 63 64 66 66 122 211)
    local ip1=${arr[$((RANDOM % ${#arr[@]}))]}
    local ip2=$(((RANDOM % 1950) + 60))
    local ip3=$(((RANDOM % 1950) + 60))
    local ip4=$(((RANDOM % 1950) + 60))
    echo "${ip1}.${ip2}.${ip3}.${ip4}"
}

# ---------- acw_sc_v2_simple ----------
acw_sc_v2_simple() {
    local arg1="$1"
    local posList=(15 35 29 24 33 16 1 38 10 9 19 31 40 27 22 23 25 13 6 11 39 18 20 8 14 21 32 26 2 30 7 4 17 5 3 28 34 37 12 36)
    local mask="3000176000856006061501533003690027800375"
    local outPutList=()
    local j pos i char

    for ((j = 0; j < 40; j++)); do outPutList[j]=""; done
    for ((i = 0; i < ${#arg1}; i++)); do
        char="${arg1:$i:1}"
        for j in "${!posList[@]}"; do
            pos=${posList[$j]}
            if [ "$pos" -eq $((i + 1)) ]; then
                outPutList[$j]="$char"
            fi
        done
    done

    local arg2=""
    for ((j = 0; j < 40; j++)); do arg2+="${outPutList[$j]}"; done

    local result="" length=${#arg2} maskLen=${#mask}
    [ "$maskLen" -lt "$length" ] && length=$maskLen
    local strHex maskHex xorVal
    for ((i = 0; i < length; i += 2)); do
        strHex="${arg2:$i:2}"
        maskHex="${mask:$i:2}"
        xorVal=$((16#$strHex ^ 16#$maskHex))
        result+=$(printf '%02x' "$xorVal")
    done
    echo "$result"
}

# ---------- GET + 挑战页重试 ----------
CHALLENGE_COOKIE=""
mlooc_curl_get_with_challenge() {
    local url="$1" referer="${2:-}"
    local cookie_hdr=""
    [ -n "$CHALLENGE_COOKIE" ] && cookie_hdr="acw_sc__v2=${CHALLENGE_COOKIE}"

    local resp
    resp=$(curl -sS -L --compressed -k --max-time 10 \
        -A "$UA" \
        -H "X-FORWARDED-FOR: $(rand_ip)" \
        -H "CLIENT-IP: $(rand_ip)" \
        ${cookie_hdr:+-b "$cookie_hdr"} \
        ${referer:+-e "$referer"} \
        "$url")

    dbg "mlooc_curl_get_with_challenge 首次响应片段: ${resp:0:200}"

    # 注意：arg1 可能包含大写十六进制字符，必须大小写不敏感匹配（对应 PHP /i 修饰符）
    if [[ "$resp" =~ var[[:space:]]+arg1=[\'\"]([0-9A-Fa-f]{40})[\'\"] ]]; then
        dbg "匹配到 arg1 = ${BASH_REMATCH[1]}"
        CHALLENGE_COOKIE=$(acw_sc_v2_simple "${BASH_REMATCH[1]}")
        dbg "计算得到 CHALLENGE_COOKIE = $CHALLENGE_COOKIE"
        resp=$(curl -sS -L --compressed -k --max-time 10 \
            -A "$UA" \
            -H "X-FORWARDED-FOR: $(rand_ip)" \
            -H "CLIENT-IP: $(rand_ip)" \
            -b "acw_sc__v2=${CHALLENGE_COOKIE}" \
            ${referer:+-e "$referer"} \
            "$url")
        dbg "mlooc_curl_get_with_challenge 重试响应片段: ${resp:0:200}"
    fi
    echo "$resp"
}

# ---------- POST ----------
mlooc_curl_post() {
    local url="$1" referer="$2" cookie="$3"
    shift 3
    curl -sS -k --max-time 10 \
        -A "$UA" \
        -H "X-FORWARDED-FOR: $(rand_ip)" \
        -H "CLIENT-IP: $(rand_ip)" \
        ${referer:+-e "$referer"} \
        ${cookie:+-b "$cookie"} \
        "$@" \
        "$url"
}

# ---------- 带 302 Location 提取 + 挑战页重试 ----------
mlooc_curl_head() {
    local target_url="$1"
    local cookies_jar=""
    local location="" resp body attempt

    for attempt in 1 2 3; do
        local headers_file body_file
        headers_file=$(mktemp)
        body_file=$(mktemp)

        curl -sS -k --max-time 10 \
            -A "$UA" \
            -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8' \
            -H 'Accept-Language: zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7' \
            -H 'Upgrade-Insecure-Requests: 1' \
            --compressed \
            ${cookies_jar:+-b "$cookies_jar"} \
            -D "$headers_file" -o "$body_file" \
            "$target_url"

        location=$(grep -i '^location:' "$headers_file" | tail -1 | sed -E 's/^[Ll]ocation:[[:space:]]*//; s/\r$//' || true)
        if [ -n "$location" ]; then
            rm -f "$headers_file" "$body_file"
            echo "$location"
            return 0
        fi

        body=$(cat "$body_file")
        rm -f "$headers_file" "$body_file"

        if [[ "$body" =~ var[[:space:]]+arg1=[\'\"]([0-9A-Fa-f]{40})[\'\"] ]]; then
            local cookie_val
            cookie_val=$(acw_sc_v2_simple "${BASH_REMATCH[1]}")
            cookies_jar="acw_sc__v2=${cookie_val}"
            continue
        fi
        break
    done
    echo ""
}

# ---------- 替换下载链接后缀（jq -Rr @uri 编码） ----------
replace_url_suffix() {
    local url="$1" suffix="${2#.}"

    local key value
    if [[ "$url" =~ (fileName|fn)=([^&]*) ]]; then
        key="${BASH_REMATCH[1]}"
        value="${BASH_REMATCH[2]}"
    else
        echo "$url"
        return
    fi

    local decoded="${value//+/ }"
    decoded="$(printf '%b' "${decoded//%/\\x}")"
    decoded="$(sed -E 's/\.[A-Za-z0-9]+$//' <<<"$decoded")"
    decoded="${decoded}.${suffix}"

    local encoded_value
    encoded_value="$(printf '%s' "$decoded" | jq -Rr @uri)"

    echo "${url/${key}=${value}/${key}=${encoded_value}}"
}

# ---------- 从 JS 片段中解析 ajax data 字段（字面量或变量名） ----------
extract_ajax_field() {
    local page="$1" key="$2" val var_name
    # 字面量字符串: 'key':'value'
    val=$(echo "$page" | grep -oP "['\"]${key}['\"]\s*:\s*['\"]\K[^'\"]*" | head -1 || true)
    if [ -n "$val" ]; then
        echo "$val"
        return
    fi
    # 字面量数字: 'key':123
    val=$(echo "$page" | grep -oP "['\"]${key}['\"]\s*:\s*\K[0-9]+" | head -1 || true)
    if [ -n "$val" ]; then
        echo "$val"
        return
    fi
    # 变量名: 'key':varName -> 到页面里查找 var varName = 'value'/123;
    var_name=$(echo "$page" | grep -oP "['\"]${key}['\"]\s*:\s*\K[A-Za-z_\$][\w\$]*" | head -1 || true)
    if [ -n "$var_name" ]; then
        val=$(echo "$page" | grep -oP "var\s+${var_name}\s*=\s*['\"]\K[^'\"]*" | tail -1 || true)
        [ -z "$val" ] && val=$(echo "$page" | grep -oP "var\s+${var_name}\s*=\s*\K[0-9]+" | tail -1 || true)
        echo "$val"
        return
    fi
    echo ""
}

# =========================== 主流程 ===========================

soft_info=$(mlooc_curl_get_with_challenge "$url")

if echo "$soft_info" | grep -q "文件取消分享了\|文件不存在"; then
    json_error "文件取消分享了"
fi

# ---------- 新增：文件夹分享页判断与解析 ----------
# 蓝奏云的“文件夹”分享链接返回的页面不是单文件下载入口，而是通过
# filemoreajax.php 异步拉取文件列表（function file(){ $.ajax({url:'/filemoreajax.php?file=xxx', data:{...lx,fid,uid,puid,pg,rep,t,k,up,vip,webfoldersign}}) }）。
# 需要先 POST 这个接口，取响应 JSON 里 text[].id 作为真正单文件的分享后缀，
# 再用 origin+id 重新拼出单文件分享链接并重新走一次整个解析流程。
if echo "$soft_info" | grep -q "filemoreajax\.php" && echo "$soft_info" | grep -q "function file()"; then
    dbg "检测到文件夹分享页，开始解析 filemoreajax.php"

    folder_ajax_path=$(echo "$soft_info" | grep -oP "url\s*:\s*['\"]\K/filemoreajax\.php\?file=\d+" | head -1 || true)
    [ -z "$folder_ajax_path" ] && json_error "未找到文件夹列表接口参数"
    folder_ajax_url="${origin}${folder_ajax_path}"
    dbg "folder_ajax_url = [$folder_ajax_url]"

    f_lx=$(extract_ajax_field "$soft_info" "lx")
    f_fid=$(extract_ajax_field "$soft_info" "fid")
    f_uid=$(extract_ajax_field "$soft_info" "uid")
    f_puid=$(extract_ajax_field "$soft_info" "puid")
    f_pg=$(extract_ajax_field "$soft_info" "pg")
    f_rep=$(extract_ajax_field "$soft_info" "rep")
    f_t=$(extract_ajax_field "$soft_info" "t")
    f_k=$(extract_ajax_field "$soft_info" "k")
    f_up=$(extract_ajax_field "$soft_info" "up")
    f_vip=$(extract_ajax_field "$soft_info" "vip")
    f_webfoldersign=$(extract_ajax_field "$soft_info" "webfoldersign")

    dbg "folder fields: lx=$f_lx fid=$f_fid uid=$f_uid puid=$f_puid pg=$f_pg rep=$f_rep t=$f_t k=$f_k up=$f_up vip=$f_vip webfoldersign=$f_webfoldersign"

    [ -z "$f_fid" ] && json_error "未找到文件夹文件参数 fid"

    folder_resp=$(mlooc_curl_post "$folder_ajax_url" "$url" "acw_sc__v2=${CHALLENGE_COOKIE}" \
        --data-urlencode "lx=${f_lx}" \
        --data-urlencode "fid=${f_fid}" \
        --data-urlencode "uid=${f_uid}" \
        --data-urlencode "puid=${f_puid}" \
        --data-urlencode "pg=${f_pg:-1}" \
        --data-urlencode "rep=${f_rep:-0}" \
        --data-urlencode "t=${f_t}" \
        --data-urlencode "k=${f_k}" \
        --data-urlencode "up=${f_up:-1}" \
        --data-urlencode "vip=${f_vip:-0}" \
        --data-urlencode "webfoldersign=${f_webfoldersign}")

    dbg "folder_resp 片段: ${folder_resp:0:300}"

    folder_zt=$(echo "$folder_resp" | jq -r '.zt // empty' 2>/dev/null || true)
    [ "$folder_zt" != "1" ] && json_error "文件夹列表接口返回异常"

    # 取列表第一个文件的 id 作为真正单文件分享后缀；若文件夹内有多个文件，默认取第一个，
    # 如需按文件名选择，可改成按 .text[] | select(.name_all=="xxx") 过滤
    real_id=$(echo "$folder_resp" | jq -r '.text[0].id // empty' 2>/dev/null || true)
    [ -z "$real_id" ] && json_error "未能从文件夹列表中取得文件 id"
    dbg "real_id = [$real_id]"
    soft_filesize=$(echo "$folder_resp" | jq -r '.text[0].size // empty' 2>/dev/null || true)

    # 用解析出的 id 重新拼出单文件分享链接，重走一次挑战页请求，后续流程保持不变
    url="${origin}/${real_id}"
    webpage=""
    dbg "重新请求单文件分享页: $url"
    soft_info=$(mlooc_curl_get_with_challenge "$url")

    if echo "$soft_info" | grep -q "文件取消分享了\|文件不存在"; then
        json_error "文件取消分享了"
    fi
fi

# ---------- 提取文件名/大小 ----------
soft_name=$(echo "$soft_info" | grep -oP 'style="font-size: 30px;text-align: center;padding: 56px 0px 20px 0px;">\K[^<]*' | head -1 || true)
[ -z "$soft_name" ] && soft_name=$(echo "$soft_info" | grep -oP '<div class="n_box_3fn".*?>\K[^<]*' | head -1 || true)
[ -z "$soft_name" ] && soft_name=$(echo "$soft_info" | grep -oP "var filename = '\K[^']*" | head -1 || true)
[ -z "$soft_name" ] && soft_name=$(echo "$soft_info" | grep -oP '<div class="b"><span>\K[^<]*' | head -1 || true)

# soft_filesize=$(echo "$soft_info" | grep -oP '<div class=.*?>文件大小：\K[^<]*' | head -1 || true)
[ -z "$soft_filesize" ] && soft_filesize=$(echo "$soft_info" | grep -oP '<span class="p7">文件大小：</span>\K[^<]*' | head -1 || true)

dbg "soft_name = [$soft_name] soft_filesize = [$soft_filesize]"

ajaxm_path=$(echo "$soft_info" | grep -oP '(https?://[^/\s]+/)?ajax(m|file)\.php\?file=\d+' | head -1 || true)

if echo "$soft_info" | grep -q "function down_p(){" && [ -z "$webpage" ]; then
    # ---------- 带密码链接 ----------
    [ -z "$pwd_arg" ] && json_error "请输入分享密码"

    sign=$(echo "$soft_info" | grep -oP "(?m)^[ \t]*data\s*:\s*\{[^\r\n]*['\"]sign['\"]\s*:\s*['\"]\K[^'\"]*" | head -1 || true)
    if [ -z "$sign" ]; then
        var_name=$(echo "$soft_info" | grep -oP "(?m)^[ \t]*data\s*:\s*\{[^\r\n]*['\"]sign['\"]\s*:\s*\K[A-Za-z_\$][\w\$]*" | head -1 || true)
        if [ -n "$var_name" ]; then
            sign=$(echo "$soft_info" | grep -oP "var\s+${var_name}\s*=\s*['\"]\K[^'\"]*" | tail -1 || true)
        fi
    fi
    [ -z "$sign" ] && sign=$(echo "$soft_info" | grep -oP "'sign':'\K[^']*" -m2 | sed -n '2p' || true)

    if [ -z "$ajaxm_path" ]; then
        ajaxm_path=$(echo "$soft_info" | grep -oP '(https?://[^/\s]+/)?ajax(m|file)\.php\?file=\d+' | head -1 || true)
    fi
    [[ "$ajaxm_path" != http* ]] && ajaxm_path="${origin}/${ajaxm_path#/}"

    { [ -z "$sign" ] || [ -z "$ajaxm_path" ]; } && json_error "未找到密码页 sign 或下载接口参数"

    soft_info=$(mlooc_curl_post "$ajaxm_path" "$url" "acw_sc__v2=${CHALLENGE_COOKIE}" \
        --data-urlencode "action=downprocess" \
        --data-urlencode "sign=${sign}" \
        --data-urlencode "p=${pwd_arg}" \
        --data-urlencode "kd=1")

    inf=$(echo "$soft_info" | jq -r '.inf // empty' 2>/dev/null || true)
    [ -n "$inf" ] && soft_name="$inf"
else
    # ---------- 不带密码链接 ----------
    link_path=$(echo "$soft_info" | grep -oP '<iframe.*?name="[^"]*"\s+src="/\K[^"]*' | head -1 || true)
    dbg "link_path = [$link_path]"
    ifurl="${origin}/${link_path}"

    segment1=$(echo "$soft_info" | grep -oP "'sign':'\K[^']*" | sed -n '2p' || true)
    dbg "segment1 = [$segment1]"

    if [ -n "$webpage" ] && [ -n "$segment1" ]; then
        ajaxm_path=$(echo "$soft_info" | grep -oP '(https?://[^/\s]+/)?ajax(m|file)\.php\?file=\d+' | head -1 || true)
        post_args=(--data-urlencode "action=downprocess"
            --data-urlencode "websignkey=Em2R"
            --data-urlencode "sign=${segment1}"
            --data-urlencode "websign=2"
            --data-urlencode "kd=1"
            --data-urlencode "ves=1")
    else
        [ -z "$link_path" ] && json_error "未找到下载入口，请检查链接是否有效"
        soft_info=$(mlooc_curl_get_with_challenge "$ifurl" "$url")

        soft_sign=$(echo "$soft_info" | grep -oP "wp_sign = '\K[^']*" | head -1 || true)
        soft_websign=$(echo "$soft_info" | grep -oP "ajaxdata = '\K[^']*" | head -1 || true)
        ajaxm_path=$(echo "$soft_info" | grep -oP '(https?://[^/\s]+/)?ajax(m|file)\.php\?file=\d+' | head -1 || true)

        [ -z "$soft_sign" ] && json_error "未找到下载接口参数，请检查链接是否有效"

        post_args=(--data-urlencode "action=downprocess"
            --data-urlencode "websignkey=${soft_websign}"
            --data-urlencode "signs=${soft_websign}"
            --data-urlencode "sign=${soft_sign}"
            --data-urlencode "websign="
            --data-urlencode "kd=1"
            --data-urlencode "ves=1")
    fi

    [[ "$ajaxm_path" != http* ]] && ajaxm_path="${origin}/${ajaxm_path#/}"

    soft_info=$(mlooc_curl_post "$ajaxm_path" "$ifurl" "acw_sc__v2=${CHALLENGE_COOKIE}" "${post_args[@]}")
fi

# ---------- 解析下载接口返回 ----------
zt=$(echo "$soft_info" | jq -r '.zt // empty' 2>/dev/null || true)
if [ "$zt" != "1" ]; then
    err_msg=$(echo "$soft_info" | jq -r '.inf // empty' 2>/dev/null || true)
    [ -z "$err_msg" ] && err_msg="解析失败，蓝奏云返回异常，请稍后重试"
    json_error "$err_msg"
fi

dom=$(echo "$soft_info" | jq -r '.dom')
furl=$(echo "$soft_info" | jq -r '.url')
down_url1="${dom}/file/${furl}"

down_url2=$(mlooc_curl_head "$down_url1")

if [[ "$down_url2" != http* ]]; then
    down_url="$down_url1"
else
    if [ -n "$suffix" ]; then
        down_url=$(replace_url_suffix "$down_url2" "$suffix")
    else
        down_url="$down_url2"
    fi
fi

down_url=$(echo "$down_url" | sed -E 's/pid=[^&]*&//')

if [ "$do_down" -eq 1 ]; then
    echo "$down_url"
else
    jq -n \
        --arg name "$soft_name" \
        --arg filesize "$soft_filesize" \
        --arg downUrl "$down_url" \
        '{code:200, msg:"解析成功", name:$name, filesize:$filesize, downUrl:$downUrl}'
fi
