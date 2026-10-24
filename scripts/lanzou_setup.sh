#!/usr/bin/env bash
# lanzou_direct.sh
# 用法: ./lanzou_direct.sh -u "<分享链接>" [-p "<密码>"] [-n "<后缀>"] [-d]
#   -u  蓝奏云分享链接（必填）
#   -p  分享密码（如需要）
#   -n  自定义下载后缀（可选，对应原 PHP 的 $_GET['n']）
#   -d  直接下载（打印最终 302 Location，对应原 type=down）
#
# 依赖: curl, jq, grep(-P), sed, awk

# set -euo pipefail
set -uo pipefail

UA='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.121 Safari/537.36'

url=""
pwd_arg=""
suffix=""
do_down=0

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

# ---------- 调试输出开关 ----------
# 运行时设置 DEBUG=1 ./lanzou_direct.sh ... 即可打开
DEBUG="${DEBUG:-1}"
dbg() {
    [ "$DEBUG" = "1" ] && echo "[DEBUG] $*" >&2
    return 0
}

[ -z "$url" ] && json_error "请输入URL"

# ---------- URL 规范化（对应 PHP parse_url 处理，保留原始域名） ----------
# 提取 scheme/host/path/query
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
webpage="$query" # 对应 PHP $webpage = parse_url($url, PHP_URL_QUERY)

# ---------- 随机 IP（对应 Rand_IP） ----------
rand_ip() {
    local arr=(218 218 66 66 218 218 60 60 202 204 66 66 66 59 61 60 222 221 66 59 60 60 66 218 218 62 63 64 66 66 122 211)
    local ip1=${arr[$((RANDOM % ${#arr[@]}))]}
    local ip2=$(((RANDOM % 1950) + 60))
    local ip3=$(((RANDOM % 1950) + 60))
    local ip4=$(((RANDOM % 1950) + 60))
    echo "${ip1}.${ip2}.${ip3}.${ip4}"
}

# ---------- acw_sc_v2_simple（对应挑战页 cookie 生成） ----------
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

# ---------- GET + 挑战页重试（对应 MloocCurlGetWithChallenge） ----------
# 返回响应体，同时通过全局变量 CHALLENGE_COOKIE 传出算出的 cookie
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

    dbg "first resp 片段: ${resp:0:200}"
    if [[ "$resp" =~ var[[:space:]]+arg1=[\'\"]([0-9A-Fa-f]{40})[\'\"] ]]; then
        dbg "matched arg1 = ${BASH_REMATCH[1]}"
        CHALLENGE_COOKIE=$(acw_sc_v2_simple "${BASH_REMATCH[1]}")
        dbg "computed CHALLENGE_COOKIE = $CHALLENGE_COOKIE"
        resp=$(curl -sS -L --compressed -k --max-time 10 \
            -A "$UA" \
            -H "X-FORWARDED-FOR: $(rand_ip)" \
            -H "CLIENT-IP: $(rand_ip)" \
            -b "acw_sc__v2=${CHALLENGE_COOKIE}" \
            ${referer:+-e "$referer"} \
            "$url")
    else
        dbg "arg1 NOT matched - check regex/case"
    fi
    echo "$resp"
}

# ---------- POST（对应 MloocCurlPost） ----------
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

# ---------- 带 302 Location 提取 + 挑战页重试（对应 MloocCurlHead） ----------
mlooc_curl_head() {
    local target_url="$1"
    local cookies_jar=""
    local location="" resp headers body attempt

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

        location=$(grep -i '^location:' "$headers_file" | tail -1 | sed -E 's/^[Ll]ocation:[[:space:]]*//; s/\r$//')
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

# ---------- 替换下载链接后缀（对应 ReplaceUrlSuffix） ----------
replace_url_suffix() {
    local url="$1" suffix="${2#.}"
    # 仅替换 query 中的 fileName= 或 fn= 参数
    echo "$url" | sed -E "s/(fileName|fn)=([^&]*)/\1=\2/" |
        #     python3 - "$url" "$suffix" <<'EOF'
        # import sys, re, urllib.parse
        # url, suffix = sys.argv[1], sys.argv[2]
        # def repl(m):
        #     val = urllib.parse.unquote(m.group(2))
        #     val = re.sub(r'\.[A-Za-z0-9]+$', '', val) + '.' + suffix
        #     return m.group(1) + '=' + urllib.parse.quote(val)
        # print(re.sub(r'(fileName|fn)=([^&]*)', repl, url, count=1))
        # EOF
        # 提取 fileName= 或 fn= 参数（只处理第一次出现，对应 PHP preg_replace_callback(..., 1)）
        local key value
    if [[ "$url" =~ (fileName|fn)=([^&]*) ]]; then
        key="${BASH_REMATCH[1]}"
        value="${BASH_REMATCH[2]}"
    else
        echo "$url"
        return
    fi

    # URL 解码（纯 bash，等价于 PHP 的 rawurldecode）
    local decoded="${value//+/ }"
    decoded="$(printf '%b' "${decoded//%/\\x}")"

    # 去掉原扩展名，拼接新后缀（对应 preg_replace('~\.[A-Za-z0-9]+$~', '', ...) . '.' . $suffix）
    decoded="$(sed -E 's/\.[A-Za-z0-9]+$//' <<<"$decoded")"
    decoded="${decoded}.${suffix}"

    # URL 编码（等价于 PHP 的 rawurlencode，用 jq -Rr @uri 实现）
    local encoded_value
    encoded_value="$(printf '%s' "$decoded" | jq -Rr @uri)"

    # 替换回原 URL 中第一次出现的 key=value（用字面量参数替换，避免 sed 正则元字符问题）
    echo "${url/${key}=${value}/${key}=${encoded_value}}"
}

# =========================== 主流程 ===========================

soft_info=$(mlooc_curl_get_with_challenge "$url")

if echo "$soft_info" | grep -q "文件取消分享了\|文件不存在"; then
    json_error "文件取消分享了"
fi

# ---------- 提取文件名/大小 ----------
soft_name=$(echo "$soft_info" | grep -oP 'style="font-size: 30px;text-align: center;padding: 56px 0px 20px 0px;">\K[^<]*' | head -1 || true)
[ -z "$soft_name" ] && soft_name=$(echo "$soft_info" | grep -oP '<div class="n_box_3fn".*?>\K[^<]*' | head -1 || true)
[ -z "$soft_name" ] && soft_name=$(echo "$soft_info" | grep -oP "var filename = '\K[^']*" | head -1 || true)
[ -z "$soft_name" ] && soft_name=$(echo "$soft_info" | grep -oP '<div class="b"><span>\K[^<]*' | head -1 || true)

soft_filesize=$(echo "$soft_info" | grep -oP '<div class="n_filesize".*?>大小：\K[^<]*' | head -1 || true)
[ -z "$soft_filesize" ] && soft_filesize=$(echo "$soft_info" | grep -oP '<span class="p7">文件大小：</span>\K[^<]*' | head -1 || true)

ajaxm_path=$(echo "$soft_info" | grep -oP '(https?://[^/\s]+/)?ajax(m|file)\.php\?file=\d+' | head -1 || true)

if echo "$soft_info" | grep -q "function down_p(){" && [ -z "$webpage" ]; then
    # ---------- 带密码链接 ----------
    [ -z "$pwd_arg" ] && json_error "请输入分享密码"

    sign=$(echo "$soft_info" | grep -oP "(?m)^[ \t]*data\s*:\s*\{[^\r\n]*['\"]sign['\"]\s*:\s*['\"]\K[^'\"]*" | head -1 || true)
    if [ -z "$sign" ]; then
        var_name=$(echo "$soft_info" | grep -oP "(?m)^[ \t]*data\s*:\s*\{[^\r\n]*['\"]sign['\"]\s*:\s*\K[A-Za-z_\$][\w\$]*" | head -1)
        if [ -n "$var_name" ]; then
            sign=$(echo "$soft_info" | grep -oP "var\s+${var_name}\s*=\s*['\"]\K[^'\"]*" | tail -1)
        fi
    fi
    [ -z "$sign" ] && sign=$(echo "$soft_info" | grep -oP "'sign':'\K[^']*'" -m2 | sed -n '2p' | tr -d "'")

    if [ -z "$ajaxm_path" ]; then
        ajaxm_path=$(echo "$soft_info" | grep -oP '(https?://[^/\s]+/)?ajax(m|file)\.php\?file=\d+' | head -1)
    fi
    [[ "$ajaxm_path" != http* ]] && ajaxm_path="${origin}/${ajaxm_path#/}"

    [ -z "$sign" ] || [ -z "$ajaxm_path" ] && json_error "未找到密码页 sign 或下载接口参数"

    soft_info=$(mlooc_curl_post "$ajaxm_path" "$url" "acw_sc__v2=${CHALLENGE_COOKIE}" \
        --data-urlencode "action=downprocess" \
        --data-urlencode "sign=${sign}" \
        --data-urlencode "p=${pwd_arg}" \
        --data-urlencode "kd=1")

    inf=$(echo "$soft_info" | jq -r '.inf // empty' 2>/dev/null || true)
    [ -n "$inf" ] && soft_name="$inf"
else
    # ---------- 不带密码链接 ----------
    dbg "soft_info length: ${#soft_info}"
    dbg "soft_info 片段(前200字符): ${soft_info:0:200}"
    link_path=$(echo "$soft_info" | grep -oP '<iframe.*?name="[^"]*"\s+src="/\K[^"]*' | head -1)
    dbg "link_path (iframe src) = [$link_path]"

    ifurl="${origin}/${link_path}"
    dbg "ifurl = [$ifurl]"
    dbg "webpage (query string) = [$webpage]"

    segment1=$(echo "$soft_info" | grep -oP "'sign':'\K[^']*" | sed -n '2p')
    dbg "segment1 (第2个 'sign':'...') = [$segment1]"

    if [ -n "$webpage" ] && [ -n "$segment1" ]; then
        dbg "走分支: 带 query 的旧版直链页"
        ajaxm_path=$(echo "$soft_info" | grep -oP '(https?://[^/\s]+/)?ajax(m|file)\.php\?file=\d+' | head -1)
        dbg "ajaxm_path = [$ajaxm_path]"
        post_args=(--data-urlencode "action=downprocess"
            --data-urlencode "websignkey=Em2R"
            --data-urlencode "sign=${segment1}"
            --data-urlencode "websign=2"
            --data-urlencode "kd=1"
            --data-urlencode "ves=1")
    else
        dbg "走分支: 需要请求 iframe 子页"
        [ -z "$link_path" ] && json_error "未找到下载入口，请检查链接是否有效"
        soft_info=$(mlooc_curl_get_with_challenge "$ifurl" "$url")

        soft_sign=$(echo "$soft_info" | grep -oP "wp_sign = '\K[^']*" | head -1)
        soft_websign=$(echo "$soft_info" | grep -oP "ajaxdata = '\K[^']*" | head -1)
        ajaxm_path=$(echo "$soft_info" | grep -oP '(https?://[^/\s]+/)?ajax(m|file)\.php\?file=\d+' | head -1)

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

# 去除 pid 参数，避免服务器 IP 泄露
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
