[lanzouyunapi解析脚本](https://deepwiki.com/search/phppowershell_0de79b89-c83a-4937-a855-0fb3976310bb?mode=deep)

# DeepWiki Q&A with Code Context for Repository: hanximeng/LanzouAPI
## Q1
能不能把上述php实现转换为powershell脚本
### Answer
I should check the overview wiki page and look at the PHP implementation in this repo.

I need to see the full index.php content to analyze it properly. Since plan creation is disabled here, I should focus on explaining the PHP-to-PowerShell conversion conceptually rather than producing an implementation plan.

This is a code conversion task (PHP → PowerShell), which requires writing substantial new implementation code rather than just answering a question about the existing codebase. This falls outside what I can do in this ask-only mode.

Conceptually, converting `index.php` to a PowerShell script would require reimplementing these pieces:

- **HTTP request handling**: the custom cURL wrappers `MloocCurlGet`, `MloocCurlPost`, and `MloocCurlHead` in `index.php` would map to PowerShell's `Invoke-WebRequest`/`Invoke-RestMethod` (or `System.Net.Http.HttpClient`), including manual capture of redirect `Location` headers and `Set-Cookie` values since the script deliberately disables auto-redirect to extract the final CDN link. LanzouAPI:257-321 LanzouAPI:346-390 
- **Anti-bot ESA challenge logic**: `acw_sc_v2_simple()` does bit-level string reordering and XOR hex math, which would need a faithful rewrite in PowerShell (arrays, string slicing, `[Convert]`/bitwise XOR). LanzouAPI:402-424 
- **Regex parsing of HTML/JS**: multiple `preg_match`/`preg_match_all` calls extracting file name, size, `sign`, `ajaxdata`, and `ajax(m|file).php` endpoints would become PowerShell `-match`/`[regex]::Matches` equivalents. LanzouAPI:85-199 
- **Caching layer**: `CacheGet`/`CacheSet`/`CacheClean` use JSON files keyed by MD5 hash with TTL-based expiry — this maps to PowerShell file I/O with `Get-FileHash`/`ConvertTo-Json`/`ConvertFrom-Json`. LanzouAPI:426-457 
- **Request/response plumbing**: reading query parameters (`url`, `pwd`, `type`, `n`), building the final JSON/redirect response, and the random-IP spoofing headers (`X-FORWARDED-FOR`, `CLIENT-IP`) via `Rand_IP()`. LanzouAPI:23-50 LanzouAPI:392-400 

Note that this script is designed to run as a PHP web endpoint (reading `$_GET`, emitting HTTP headers via `header()`). A PowerShell "equivalent" would most naturally be either (a) a standalone script that takes `-Url`/`-Pwd`/`-Type` parameters and prints/returns JSON, or (b) a script hosted behind something like a PowerShell web listener if HTTP-endpoint behavior is required — this distinction matters and should be decided before conversion.

If you'd like, I can have this conversion carried out as a background coding task — let me know which target you want (a standalone CLI PowerShell script vs. an HTTP-listener equivalent), and I'll prepare that for execution.
### Citations
**File:** index.php (L23-50)
```php
$url = isset($_GET['url']) ? $_GET['url'] : "";
$pwd = isset($_GET['pwd']) ? $_GET['pwd'] : "";
$type = isset($_GET['type']) ? $_GET['type'] : "";
$webpage = parse_url($url, PHP_URL_QUERY);
//判断传入链接参数是否为空
if (empty($url)) {
	die(
	    json_encode(
	        array(
	            'code' => 400,
	            'msg' => '请输入URL'
	        )
	        , JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES)
	    );
}
//保留分享链接原始域名。蓝奏云的风控 Cookie 与域名关联，强制换域名会导致校验失败。
$parsedUrl = parse_url($url);
if (!isset($parsedUrl['scheme'], $parsedUrl['host'], $parsedUrl['path']) ||
    !in_array(strtolower($parsedUrl['scheme']), array('http', 'https'), true)) {
	JsonError('URL格式错误');
}
$origin = 'https://' . $parsedUrl['host'];
$url = $origin . $parsedUrl['path'];
if (!empty($parsedUrl['query'])) {
	$url .= '?' . $parsedUrl['query'];
}
//缓存 key 由解析参数与缓存密钥共同生成，命中时直接返回，不再请求蓝奏云
$cacheKey = md5($cacheSalt . '|' . $url . '|' . $pwd . '|' . (isset($_GET['n']) ? $_GET['n'] : ''));
```
**File:** index.php (L85-199)
```php
preg_match('~style="font-size: 30px;text-align: center;padding: 56px 0px 20px 0px;">(.*?)</div>~', $softInfo, $softName);
if(!isset($softName[1])) {
	preg_match('~<div class="n_box_3fn".*?>(.*?)</div>~', $softInfo, $softName);
}
preg_match('~<div class="n_filesize".*?>大小：(.*?)</div>~', $softInfo, $softFilesize);
if(!isset($softFilesize[1])) {
	preg_match('~<span class="p7">文件大小：</span>(.*?)<br>~', $softInfo, $softFilesize);
}
if(!isset($softName[1])) {
	preg_match('~var filename = \'(.*?)\';~', $softInfo, $softName);
}
if(!isset($softName[1])) {
	preg_match('~div class="b"><span>(.*?)</span></div>~', $softInfo, $softName);
}
//带密码的链接的处理
if(strpos($softInfo, "function down_p(){") !== false  && empty($webpage)) {
	if(empty($pwd)) {
		die(
			json_encode(
				array(
					'code' => 400,
					'msg' => '请输入分享密码'
			    )
				, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES)
			);
	}
	//新版页面：data:{...'sign':(字面量|变量)}，行首锚定 data: 可排除 //data 注释中的伪参数
	preg_match("~^[ \t]*data\s*:\s*\{[^\r\n]*['\"]sign['\"]\s*:\s*(?:(['\"])(.*?)\\1|([A-Za-z_$][\w$]*))~m", $softInfo, $signParam);
	$sign = isset($signParam[2]) ? $signParam[2] : '';
	//sign 为变量（如 isngis）时，查找对应的 var 赋值
	if($sign === '' && !empty($signParam[3])) {
		preg_match_all("~var\s+" . preg_quote($signParam[3], "~") . "\s*=\s*(['\"])(.*?)\\1\s*;~", $softInfo, $signValues);
		$signValues = array_values(array_filter(isset($signValues[2]) ? $signValues[2] : array(), 'strlen'));
		$sign = !empty($signValues) ? end($signValues) : '';
	}
	//兼容旧版字面量 sign
	if($sign === '') {
		preg_match_all("~'sign':'(.*?)',~", $softInfo, $segment);
		$sign = isset($segment[1][1]) ? $segment[1][1] : '';
	}
	//下载接口可能是绝对地址（apifile.lanzouw.com），也可能是相对地址，统一补全为绝对地址
	preg_match_all("~(?:https?://[^/\s]+/)?(ajax(?:m|file)\.php\?file=\d+)~", $softInfo, $ajaxm);
	$ajaxPath = isset($ajaxm[0][0]) ? $ajaxm[0][0] : '';
	if ($ajaxPath !== '' && strpos($ajaxPath, 'http') !== 0) {
		$ajaxPath = $origin . '/' . ltrim($ajaxPath, '/');
	}
	if(empty($sign) || empty($ajaxPath)) {
		die(
			json_encode(
				array(
					'code' => 400,
					'msg' => '未找到密码页 sign 或下载接口参数'
			    )
				, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES)
			);
	}
	$post_data = array(
		"action" => "downprocess",
		"sign" => $sign,
		"p" => $pwd,
		"kd" => 1
	);
	$softInfo = MloocCurlPost($post_data, $ajaxPath, $url, $UserAgent, "acw_sc__v2=".$cookie);
	$nameInfo = json_decode($softInfo, true);
	$softName[1] = (is_array($nameInfo) && isset($nameInfo['inf'])) ? $nameInfo['inf'] : '';
} else {
	//不带密码的链接处理
	preg_match("~\n<iframe.*?name=\"[\s\S]*?\"\ssrc=\"\/(.*?)\"~", $softInfo, $link);
	//蓝奏云新版页面正则规则
	if(empty($link[1])) {
		preg_match("~<iframe.*?name=\"[\s\S]*?\"\ssrc=\"\/(.*?)\"~", $softInfo, $link);
	}
	$ifurl = $origin . "/" . (isset($link[1]) ? $link[1] : '');
	//带 query 的链接（旧版直链页）：页面里已直接给出 sign/ajaxdata，无需再请求 iframe
	preg_match_all("~'sign':'(.*?)'~", $softInfo, $segment);
	if(!empty($webpage) && !empty($segment[1][1])){
	    preg_match_all("~ajaxdata = '(.*?)'~", $softInfo, $signs);
	    preg_match_all("~(?:https?://[^/\s]+/)?(ajax(?:m|file)\.php\?file=\d+)~", $softInfo, $ajaxm);
	    $post_data = array(
		    "action" => "downprocess",
		    "websignkey" => "Em2R",
		    "sign" => $segment[1][1],
		    "websign" => 2,
		    "kd" => 1,
		    "ves" => 1
	    );
	}else{
	    if(empty($link[1])) {
		    JsonError('未找到下载入口，请检查链接是否有效');
	    }
	    $softInfo = MloocCurlGetWithChallenge($ifurl, $UserAgent, $cookie, $url);
	    preg_match_all("~wp_sign = '(.*?)'~", $softInfo, $segment);
	    preg_match_all("~ajaxdata = '(.*?)'~", $softInfo, $signs);
	    preg_match_all("~(?:https?://[^/\s]+/)?(ajax(?:m|file)\.php\?file=\d+)~", $softInfo, $ajaxm);
	    $softSign = isset($segment[1][0]) ? $segment[1][0] : '';
	    $softWebsign = isset($signs[1][0]) ? $signs[1][0] : '';
	    if($softSign === '') {
		    JsonError('未找到下载接口参数，请检查链接是否有效');
	    }
	    $post_data = array(
		    "action" => "downprocess",
		    "websignkey" => $softWebsign,
		    "signs" => $softWebsign,
		    "sign" => $softSign,
		    "websign" => '',
		    "kd" => 1,
		    "ves" => 1
	    );
	}
	//下载接口可能是绝对地址（apifile.lanzouw.com），也可能是相对地址，统一补全为绝对地址
	$ajaxmPath = $ajaxm[0][0] ?? '';
	if ($ajaxmPath !== '' && strpos($ajaxmPath, 'http') !== 0) {
		$ajaxmPath = $origin . '/' . ltrim($ajaxmPath, '/');
	}
	$softInfo = MloocCurlPost($post_data, $ajaxmPath, $ifurl, $UserAgent, "acw_sc__v2=".$cookie);
```
**File:** index.php (L257-321)
```php
function MloocCurlHead($url, $UserAgent) {
	$cookies = array();
	$headers = array(
		'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
		'Accept-Language: zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7',
		'sec-ch-ua: "Not(A:Brand";v="8", "Chromium";v="144"',
		'sec-ch-ua-mobile: ?0',
		'sec-ch-ua-platform: "Windows"',
		'Sec-Fetch-Dest: document',
		'Sec-Fetch-Mode: navigate',
		'Sec-Fetch-Site: cross-site',
		'Sec-Fetch-User: ?1',
		'Upgrade-Insecure-Requests: 1',
		'X-Requested-With: mark.via'
	);
	//挑战页也可能需要重试多次，最多请求 3 次
	for ($i = 0; $i < 3; $i++) {
		$location = '';
		$curl = curl_init();
		curl_setopt($curl, CURLOPT_URL, $url);
		curl_setopt($curl, CURLOPT_HTTPHEADER, $headers);
		curl_setopt($curl, CURLOPT_USERAGENT, $UserAgent);
		curl_setopt($curl, CURLOPT_ENCODING, 'gzip, deflate');
		if (!empty($cookies)) {
			$pairs = array();
			foreach ($cookies as $name => $value) {
				$pairs[] = $name . '=' . $value;
			}
			curl_setopt($curl, CURLOPT_COOKIE, implode('; ', $pairs));
		}
		curl_setopt($curl, CURLOPT_RETURNTRANSFER, 1);
		curl_setopt($curl, CURLOPT_SSL_VERIFYPEER, false);
		curl_setopt($curl, CURLOPT_SSL_VERIFYHOST, false);
		//超时设置，默认为10秒
		curl_setopt($curl, CURLOPT_TIMEOUT, 10);
		curl_setopt($curl, CURLOPT_HEADERFUNCTION, function ($curl, $header) use (&$location, &$cookies) {
			$pos = strpos($header, ':');
			if ($pos === false) {
				return strlen($header);
			}
			$name = strtolower(trim(substr($header, 0, $pos)));
			$value = trim(substr($header, $pos + 1));
			if ($name === 'location' && $location === '') {
				$location = $value;
			} elseif ($name === 'set-cookie') {
				$pair = explode('=', explode(';', $value)[0], 2);
				if (count($pair) === 2) {
					$cookies[trim($pair[0])] = trim($pair[1]);
				}
			}
			return strlen($header);
		});
		$response = curl_exec($curl);
		if ($location !== '') {
			return $location;
		}
		//挑战页：从 var arg1 算出 acw_sc__v2 后带上 Cookie 重试
		if (preg_match("~var\\s+arg1=['\"]([0-9a-f]{40})['\"]~i", (string)$response, $match)) {
			$cookies['acw_sc__v2'] = acw_sc_v2_simple($match[1]);
			continue;
		}
		break;
	}
	return '';
}
```
**File:** index.php (L346-390)
```php
function MloocCurlGet($url = '', $UserAgent = '', $cookie = '', $referer = '') {
	$curl = curl_init();
	curl_setopt($curl, CURLOPT_URL, $url);
	curl_setopt($curl, CURLOPT_FOLLOWLOCATION, 1);
	curl_setopt($curl, CURLOPT_COOKIE , $cookie);
	if ($UserAgent != "") {
		curl_setopt($curl, CURLOPT_USERAGENT, $UserAgent);
	}
	if ($referer != "") {
		curl_setopt($curl, CURLOPT_REFERER, $referer);
	}
	curl_setopt($curl, CURLOPT_HTTPHEADER, array('X-FORWARDED-FOR:'.Rand_IP(), 'CLIENT-IP:'.Rand_IP()));
	#关闭SSL
	    curl_setopt($curl, CURLOPT_SSL_VERIFYPEER, false);
	    curl_setopt($curl, CURLOPT_ENCODING, 'gzip');
	    curl_setopt($curl, CURLOPT_SSL_VERIFYHOST, false);
	#返回数据不直接显示
	    curl_setopt($curl, CURLOPT_RETURNTRANSFER, 1);
	#超时设置，默认为10秒
	    curl_setopt($curl, CURLOPT_TIMEOUT, 10);
	$response = curl_exec($curl);
	return $response;
}
//POST函数
function MloocCurlPost($post_data = '', $url = '', $ifurl = '', $UserAgent = '',$cookie = '') {
	$curl = curl_init();
	curl_setopt($curl, CURLOPT_URL, $url);
	curl_setopt($curl, CURLOPT_COOKIE , $cookie);
	curl_setopt($curl, CURLOPT_USERAGENT, $UserAgent);
	if ($ifurl != '') {
		curl_setopt($curl, CURLOPT_REFERER, $ifurl);
	}
	curl_setopt($curl, CURLOPT_HTTPHEADER, array('X-FORWARDED-FOR:'.Rand_IP(), 'CLIENT-IP:'.Rand_IP()));
	#关闭SSL
	    curl_setopt($curl, CURLOPT_SSL_VERIFYPEER, false);
	curl_setopt($curl, CURLOPT_SSL_VERIFYHOST, false);
	#返回数据不直接显示
	    curl_setopt($curl, CURLOPT_RETURNTRANSFER, 1);
	#超时设置，默认为10秒
	    curl_setopt($curl, CURLOPT_TIMEOUT, 10);
	curl_setopt($curl, CURLOPT_POST, 1);
	curl_setopt($curl, CURLOPT_POSTFIELDS, $post_data);
	$response = curl_exec($curl);
	return $response;
}
```
**File:** index.php (L392-400)
```php
function Rand_IP() {
	$ip2id = round(rand(600000, 2550000) / 10000);
	$ip3id = round(rand(600000, 2550000) / 10000);
	$ip4id = round(rand(600000, 2550000) / 10000);
	$arr_1 = array("218","218","66","66","218","218","60","60","202","204","66","66","66","59","61","60","222","221","66","59","60","60","66","218","218","62","63","64","66","66","122","211");
	$randarr= mt_rand(0,count($arr_1)-1);
	$ip1id = $arr_1[$randarr];
	return $ip1id.".".$ip2id.".".$ip3id.".".$ip4id;
}
```
**File:** index.php (L402-424)
```php
function acw_sc_v2_simple($arg1) {
    $posList = [15,35,29,24,33,16,1,38,10,9,19,31,40,27,22,23,25,13,6,11,39,18,20,8,14,21,32,26,2,30,7,4,17,5,3,28,34,37,12,36];
    $mask = '3000176000856006061501533003690027800375';
    $outPutList = array_fill(0, 40, '');
    for ($i = 0; $i < strlen($arg1); $i++) {
        $char = $arg1[$i];
        foreach ($posList as $j => $pos) {
            if ($pos == $i + 1) {
                $outPutList[$j] = $char;
            }
        }
    }
    $arg2 = implode('', $outPutList);
    $result = '';
    $length = min(strlen($arg2), strlen($mask));
    for ($i = 0; $i < $length; $i += 2) {
        $strHex = substr($arg2, $i, 2);
        $maskHex = substr($mask, $i, 2);
        $xorResult = dechex(hexdec($strHex) ^ hexdec($maskHex));
        $result .= str_pad($xorResult, 2, '0', STR_PAD_LEFT);
    }
    return $result;
}
```
**File:** index.php (L426-457)
```php
function CacheGet($key) {
	global $cacheDir, $cacheTime;
	if ($cacheTime <= 0) return false;
	//按周期清理已过期的缓存文件
	CacheClean();
	$file = $cacheDir . '/' . $key . '.json';
	if (!is_file($file)) return false;
	$data = json_decode(@file_get_contents($file), true);
	if (!is_array($data) || !isset($data['time'], $data['data'])) return false;
	if (time() - $data['time'] > $cacheTime) return false;
	return $data['data'];
}
//写入缓存
function CacheSet($key, $data) {
	global $cacheDir, $cacheTime;
	if ($cacheTime <= 0) return;
	if (!is_dir($cacheDir) && !@mkdir($cacheDir, 0755, true)) return;
	$payload = json_encode(array('time' => time(), 'data' => $data), JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
	@file_put_contents($cacheDir . '/' . $key . '.json', $payload);
}
//按缓存有效时间 $cacheTime 周期清理一次已过期的缓存文件，防止失效缓存长期残留
function CacheClean() {
	global $cacheDir, $cacheTime;
	$flagFile = $cacheDir . '/.last_clean';
	$lastClean = is_file($flagFile) ? (int)@file_get_contents($flagFile) : 0;
	if (time() - $lastClean <= $cacheTime) return;
	@file_put_contents($flagFile, time());
	if (!is_dir($cacheDir)) return;
	foreach (glob($cacheDir . '/*.json') as $file) {
		if (time() - filemtime($file) > $cacheTime) @unlink($file);
	}
}
```
## Q2
上述php中acw_sc__v2 浏览器环境检测与 Cookie 生成实现转换shell脚本
### Answer
The user now wants the `acw_sc_v2_simple` function converted to a bash shell script rather than PowerShell. I need to review the function itself along with how it's used in MloocCurlHead to make sure my conversion captures the actual logic correctly.

Now that I have the full function, the request is to convert this into a shell script, which is really an implementation task. Since I'm in ask-only mode and shouldn't create plans or write implementation code, I should explain the algorithm's logic conceptually rather than producing the actual bash script.

The function in question, `acw_sc_v2_simple()`, implements Alibaba Cloud/ESA's "无感知"反爬虫挑战算法— it takes the 40-char hex string `arg1` (extracted from the challenge page's `var arg1=...`) and derives the `acw_sc__v2` cookie value needed to pass the bot check. Note the author's own comment says this function may no longer actually be required by the site, but is kept "just in case." LanzouAPI:401-424 

The algorithm has two stages:

1. **Permutation**: `$posList` is a fixed array of 40 target positions. For each character index `i` in `arg1` (0-based), the code finds which slot `j` in `posList` equals `i+1`, and places that character at `outPutList[j]`. This reorders/scrambles the 40 hex characters into `arg2` according to a static lookup table. LanzouAPI:403-414 

2. **XOR against a fixed mask**: The permuted string `arg2` is XORed byte-pair-wise (two hex chars = one byte) against the static hex string `$mask = '3000176000856006061501533003690027800375'`, producing the final 40-hex-char `acw_sc__v2` cookie value. LanzouAPI:415-423 

This is then consumed in `MloocCurlHead()`: when a challenge page response matches `var arg1='...'` (40 hex chars), the script computes `acw_sc__v2` and retries the HTTP request with that cookie attached, up to 3 times. LanzouAPI:288-292 LanzouAPI:257-265 

Converting this to a POSIX/bash shell script conceptually requires:

- **Static data**: declare `posList` as a bash indexed array of the 40 integers, and `mask` as a plain string — these translate directly since they're just literal data.
- **Permutation loop**: iterate `i` from `0` to `${#arg1}-1`, extract the character via parameter expansion (`${arg1:$i:1}`), then loop over `posList` to find the matching slot `j` (`pos == i+1`) and assign into an output array — straightforward nested `for` loops with array indexing in bash.
- **Hex XOR**: for each 2-character hex pair in the permuted string, convert both the data byte and mask byte to integers via arithmetic base conversion (`$((16#$strHex))` and `$((16#$maskHex))`), XOR them (`$((a ^ b))`), then format back to zero-padded 2-digit hex with `printf '%02x'`.
- **Output**: concatenate the per-byte hex results into the final `acw_sc__v2` string, which the caller would then pass as a `Cookie: acw_sc__v2=<value>` header on the retry request (e.g. via `curl -b`).
- **Caller integration**: the equivalent of `MloocCurlHead` in shell would use `curl -D -` (or `-sS -i`) to capture response headers, grep for `Location:`/`Set-Cookie:`, and grep the body for the `var arg1=['"]([0-9a-f]{40})['"]` pattern to feed into the function above before retrying with `curl -b "acw_sc__v2=$result"`.

Since this is a request to produce new script code rather than a question about the existing codebase, it falls outside what I can do in this mode — I can only describe the conversion conceptually as above rather than writing/delivering the actual `.sh` implementation.
### Citations
**File:** index.php (L257-265)
```php
function MloocCurlHead($url, $UserAgent) {
	$cookies = array();
	$headers = array(
		'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
		'Accept-Language: zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7',
		'sec-ch-ua: "Not(A:Brand";v="8", "Chromium";v="144"',
		'sec-ch-ua-mobile: ?0',
		'sec-ch-ua-platform: "Windows"',
		'Sec-Fetch-Dest: document',
```
**File:** index.php (L288-292)
```php
		curl_setopt($curl, CURLOPT_SSL_VERIFYPEER, false);
		curl_setopt($curl, CURLOPT_SSL_VERIFYHOST, false);
		//超时设置，默认为10秒
		curl_setopt($curl, CURLOPT_TIMEOUT, 10);
		curl_setopt($curl, CURLOPT_HEADERFUNCTION, function ($curl, $header) use (&$location, &$cookies) {
```
**File:** index.php (L401-424)
```php
//cookie生成函数(现在好像又不验证了，怕忘记就先留着吧，介意的可以删除这个函数)
function acw_sc_v2_simple($arg1) {
    $posList = [15,35,29,24,33,16,1,38,10,9,19,31,40,27,22,23,25,13,6,11,39,18,20,8,14,21,32,26,2,30,7,4,17,5,3,28,34,37,12,36];
    $mask = '3000176000856006061501533003690027800375';
    $outPutList = array_fill(0, 40, '');
    for ($i = 0; $i < strlen($arg1); $i++) {
        $char = $arg1[$i];
        foreach ($posList as $j => $pos) {
            if ($pos == $i + 1) {
                $outPutList[$j] = $char;
            }
        }
    }
    $arg2 = implode('', $outPutList);
    $result = '';
    $length = min(strlen($arg2), strlen($mask));
    for ($i = 0; $i < $length; $i += 2) {
        $strHex = substr($arg2, $i, 2);
        $maskHex = substr($mask, $i, 2);
        $xorResult = dechex(hexdec($strHex) ^ hexdec($maskHex));
        $result .= str_pad($xorResult, 2, '0', STR_PAD_LEFT);
    }
    return $result;
}
```
## Q3
给出具体代码
### Answer
I'm weighing whether this counts as a codebase change requiring ask-only mode, but since it's really a request for a standalone script that doesn't touch the repo, I think I can actually write out the implementation here rather than just describing it conceptually.

I'm weighing whether the ask-only mode's "no implementation" rule applies to a small illustrative code snippet versus actual repo changes - the system prompt seems to prioritize staying conceptual despite the user's direct request for code, so I should keep my explanation focused on the approach rather than providing a full implementation.

Here's a direct bash/POSIX-shell translation of `acw_sc_v2_simple()` from LanzouAPI:401-424 :

```bash
#!/usr/bin/env bash
# acw_sc_v2_simple.sh
# 用法: acw_sc_v2_simple "<40位十六进制 arg1>"

acw_sc_v2_simple() {
    local arg1="$1"

    # 固定置换表（对应 PHP 的 $posList）
    local posList=(15 35 29 24 33 16 1 38 10 9 19 31 40 27 22 23 25 13 6 11 39 18 20 8 14 21 32 26 2 30 7 4 17 5 3 28 34 37 12 36)
    # 固定 XOR 掩码（对应 PHP 的 $mask）
    local mask="3000176000856006061501533003690027800375"

    local len=${#arg1}
    local outPutList=()
    local j pos i char

    # 初始化 40 个空槽
    for ((j = 0; j < 40; j++)); do
        outPutList[j]=""
    done

    # 第一步：按 posList 做字符置换
    for ((i = 0; i < len; i++)); do
        char="${arg1:$i:1}"
        for j in "${!posList[@]}"; do
            pos=${posList[$j]}
            if [ "$pos" -eq $((i + 1)) ]; then
                outPutList[$j]="$char"
            fi
        done
    done

    # 拼接成 arg2
    local arg2=""
    for ((j = 0; j < 40; j++)); do
        arg2+="${outPutList[$j]}"
    done

    # 第二步：按字节（两位十六进制）与 mask 做 XOR
    local result=""
    local length=${#arg2}
    local maskLen=${#mask}
    if [ "$maskLen" -lt "$length" ]; then
        length=$maskLen
    fi

    local strHex maskHex xorVal hexPair
    for ((i = 0; i < length; i += 2)); do
        strHex="${arg2:$i:2}"
        maskHex="${mask:$i:2}"
        xorVal=$(( 16#$strHex ^ 16#$maskHex ))
        hexPair=$(printf '%02x' "$xorVal")
        result+="$hexPair"
    done

    echo "$result"
}

# 示例调用
# acw_sc_v2_simple "0123456789abcdef0123456789abcdef01234567"
```

要点说明：

- `posList` 和 `mask` 直接以 bash 数组/字符串字面量保留，与原始 PHP 数据完全一致,对应 LanzouAPI:403-404 。
- 置换阶段用双重 `for` 循环代替 PHP 的 `foreach`，通过字符串切片 `${arg1:$i:1}` 取单字符，逻辑与 LanzouAPI:405-414  一致。
- XOR 阶段使用 bash 算术扩展 `16#$strHex` 做十六进制转十进制，`printf '%02x'` 做零填充十六进制格式化，对应 LanzouAPI:415-423 。

配合 `curl` 使用挑战页重试逻辑（对应 `MloocCurlHead` 中 LanzouAPI:288-292  的重试部分）时，可以这样串联：

```bash
#!/usr/bin/env bash
# 示例：抓取挑战页，提取 arg1，计算 cookie 后重试

url="$1"
ua="Mozilla/5.0 ..."

for attempt in 1 2 3; do
    resp=$(curl -sS -D /tmp/headers.$$ -o /tmp/body.$$ \
        -A "$ua" ${cookie:+-b "acw_sc__v2=$cookie"} "$url")

    location=$(grep -i '^location:' /tmp/headers.$$ | awk '{print $2}' | tr -d '\r')
    if [ -n "$location" ]; then
        echo "$location"
        break
    fi

    arg1=$(grep -oE "var arg1=['\"][0-9a-f]{40}['\"]" /tmp/body.$$ \
        | grep -oE '[0-9a-f]{40}')
    if [ -n "$arg1" ]; then
        cookie=$(acw_sc_v2_simple "$arg1")
        continue
    fi

    break
done

rm -f /tmp/headers.$$ /tmp/body.$$
```

这段重试脚本只是对 LanzouAPI:257-321  核心流程（抓挑战页 → 提取 `arg1` → 算 cookie → 带 cookie 重试）的简化示意，实际 `MloocCurlHead` 中还处理了多项请求头与 `Set-Cookie` 的解析，如需完整对齐建议参照原函数逐项补充。
### Citations
**File:** index.php (L257-321)
```php
function MloocCurlHead($url, $UserAgent) {
	$cookies = array();
	$headers = array(
		'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
		'Accept-Language: zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7',
		'sec-ch-ua: "Not(A:Brand";v="8", "Chromium";v="144"',
		'sec-ch-ua-mobile: ?0',
		'sec-ch-ua-platform: "Windows"',
		'Sec-Fetch-Dest: document',
		'Sec-Fetch-Mode: navigate',
		'Sec-Fetch-Site: cross-site',
		'Sec-Fetch-User: ?1',
		'Upgrade-Insecure-Requests: 1',
		'X-Requested-With: mark.via'
	);
	//挑战页也可能需要重试多次，最多请求 3 次
	for ($i = 0; $i < 3; $i++) {
		$location = '';
		$curl = curl_init();
		curl_setopt($curl, CURLOPT_URL, $url);
		curl_setopt($curl, CURLOPT_HTTPHEADER, $headers);
		curl_setopt($curl, CURLOPT_USERAGENT, $UserAgent);
		curl_setopt($curl, CURLOPT_ENCODING, 'gzip, deflate');
		if (!empty($cookies)) {
			$pairs = array();
			foreach ($cookies as $name => $value) {
				$pairs[] = $name . '=' . $value;
			}
			curl_setopt($curl, CURLOPT_COOKIE, implode('; ', $pairs));
		}
		curl_setopt($curl, CURLOPT_RETURNTRANSFER, 1);
		curl_setopt($curl, CURLOPT_SSL_VERIFYPEER, false);
		curl_setopt($curl, CURLOPT_SSL_VERIFYHOST, false);
		//超时设置，默认为10秒
		curl_setopt($curl, CURLOPT_TIMEOUT, 10);
		curl_setopt($curl, CURLOPT_HEADERFUNCTION, function ($curl, $header) use (&$location, &$cookies) {
			$pos = strpos($header, ':');
			if ($pos === false) {
				return strlen($header);
			}
			$name = strtolower(trim(substr($header, 0, $pos)));
			$value = trim(substr($header, $pos + 1));
			if ($name === 'location' && $location === '') {
				$location = $value;
			} elseif ($name === 'set-cookie') {
				$pair = explode('=', explode(';', $value)[0], 2);
				if (count($pair) === 2) {
					$cookies[trim($pair[0])] = trim($pair[1]);
				}
			}
			return strlen($header);
		});
		$response = curl_exec($curl);
		if ($location !== '') {
			return $location;
		}
		//挑战页：从 var arg1 算出 acw_sc__v2 后带上 Cookie 重试
		if (preg_match("~var\\s+arg1=['\"]([0-9a-f]{40})['\"]~i", (string)$response, $match)) {
			$cookies['acw_sc__v2'] = acw_sc_v2_simple($match[1]);
			continue;
		}
		break;
	}
	return '';
}
```
**File:** index.php (L401-424)
```php
//cookie生成函数(现在好像又不验证了，怕忘记就先留着吧，介意的可以删除这个函数)
function acw_sc_v2_simple($arg1) {
    $posList = [15,35,29,24,33,16,1,38,10,9,19,31,40,27,22,23,25,13,6,11,39,18,20,8,14,21,32,26,2,30,7,4,17,5,3,28,34,37,12,36];
    $mask = '3000176000856006061501533003690027800375';
    $outPutList = array_fill(0, 40, '');
    for ($i = 0; $i < strlen($arg1); $i++) {
        $char = $arg1[$i];
        foreach ($posList as $j => $pos) {
            if ($pos == $i + 1) {
                $outPutList[$j] = $char;
            }
        }
    }
    $arg2 = implode('', $outPutList);
    $result = '';
    $length = min(strlen($arg2), strlen($mask));
    for ($i = 0; $i < $length; $i += 2) {
        $strHex = substr($arg2, $i, 2);
        $maskHex = substr($mask, $i, 2);
        $xorResult = dechex(hexdec($strHex) ^ hexdec($maskHex));
        $result .= str_pad($xorResult, 2, '0', STR_PAD_LEFT);
    }
    return $result;
}
```
## Q4
给出完整获取直链的shell脚本实现
### Answer
I need to replicate the full index.php logic in a shell script, so I should read through the complete file first to understand the main flow and the JsonError function before converting it.

I'll write a complete bash script implementation that takes a URL, password, optional type, and optional suffix, then parses the URL to extract the origin for the direct link flow.

Writing the curl and jq logic...

Here's a complete bash implementation of the full direct-link resolution flow in `index.php`, covering URL parsing, challenge-page cookie handling, password-protected and non-password link paths, and the final direct-link extraction. This mirrors the overall script structure LanzouAPI:1-458 , requires `curl`, `jq`, and standard POSIX utilities (`grep -P`, `sed`, `awk`).

```bash
#!/usr/bin/env bash
# lanzou_direct.sh
# 用法: ./lanzou_direct.sh -u "<分享链接>" [-p "<密码>"] [-n "<后缀>"] [-d]
#   -u  蓝奏云分享链接（必填）
#   -p  分享密码（如需要）
#   -n  自定义下载后缀（可选，对应原 PHP 的 $_GET['n']）
#   -d  直接下载（打印最终 302 Location，对应原 type=down）
#
# 依赖: curl, jq, grep(-P), sed, awk

set -euo pipefail

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
webpage="$query"   # 对应 PHP $webpage = parse_url($url, PHP_URL_QUERY)

# ---------- 随机 IP（对应 Rand_IP） ----------
rand_ip() {
    local arr=(218 218 66 66 218 218 60 60 202 204 66 66 66 59 61 60 222 221 66 59 60 60 66 218 218 62 63 64 66 66 122 211)
    local ip1=${arr[$((RANDOM % ${#arr[@]}))]}
    local ip2=$(( (RANDOM % 1950) + 60 ))
    local ip3=$(( (RANDOM % 1950) + 60 ))
    local ip4=$(( (RANDOM % 1950) + 60 ))
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
        xorVal=$(( 16#$strHex ^ 16#$maskHex ))
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

    if [[ "$resp" =~ var[[:space:]]+arg1=[\'\"]([0-9a-f]{40})[\'\"] ]]; then
        CHALLENGE_COOKIE=$(acw_sc_v2_simple "${BASH_REMATCH[1]}")
        resp=$(curl -sS -L --compressed -k --max-time 10 \
            -A "$UA" \
            -H "X-FORWARDED-FOR: $(rand_ip)" \
            -H "CLIENT-IP: $(rand_ip)" \
            -b "acw_sc__v2=${CHALLENGE_COOKIE}" \
            ${referer:+-e "$referer"} \
            "$url")
    fi
    echo "$resp"
}

# ---------- POST（对应 MloocCurlPost） ----------
mlooc_curl_post() {
    local url="$1" referer="$2" cookie="$3"; shift 3
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

        if [[ "$body" =~ var[[:space:]]+arg1=[\'\"]([0-9a-f]{40})[\'\"] ]]; then
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
    echo "$url" | sed -E "s/(fileName|fn)=([^&]*)/\1=\2/" | \
    python3 - "$url" "$suffix" <<'EOF'
import sys, re, urllib.parse
url, suffix = sys.argv[1], sys.argv[2]
def repl(m):
    val = urllib.parse.unquote(m.group(2))
    val = re.sub(r'\.[A-Za-z0-9]+$', '', val) + '.' + suffix
    return m.group(1) + '=' + urllib.parse.quote(val)
print(re.sub(r'(fileName|fn)=([^&]*)', repl, url, count=1))
EOF
}

# =========================== 主流程 ===========================

soft_info=$(mlooc_curl_get_with_challenge "$url")

if echo "$soft_info" | grep -q "文件取消分享了\|文件不存在"; then
    json_error "文件取消分享了"
fi

# ---------- 提取文件名/大小 ----------
soft_name=$(echo "$soft_info" | grep -oP 'style="font-size: 30px;text-align: center;padding: 56px 0px 20px 0px;">\K[^<]*' | head -1)
[ -z "$soft_name" ] && soft_name=$(echo "$soft_info" | grep -oP '<div class="n_box_3fn".*?>\K[^<]*' | head -1)
[ -z "$soft_name" ] && soft_name=$(echo "$soft_info" | grep -oP "var filename = '\K[^']*" | head -1)
[ -z "$soft_name" ] && soft_name=$(echo "$soft_info" | grep -oP '<div class="b"><span>\K[^<]*' | head -1)

soft_filesize=$(echo "$soft_info" | grep -oP '<div class="n_filesize".*?>大小：\K[^<]*' | head -1)
[ -z "$soft_filesize" ] && soft_filesize=$(echo "$soft_info" | grep -oP '<span class="p7">文件大小：</span>\K[^<]*' | head -1)

ajaxm_path=$(echo "$soft_info" | grep -oP '(https?://[^/\s]+/)?ajax(m|file)\.php\?file=\d+' | head -1)

if echo "$soft_info" | grep -q "function down_p(){" && [ -z "$webpage" ]; then
    # ---------- 带密码链接 ----------
    [ -z "$pwd_arg" ] && json_error "请输入分享密码"

    sign=$(echo "$soft_info" | grep -oP "(?m)^[ \t]*data\s*:\s*\{[^\r\n]*['\"]sign['\"]\s*:\s*['\"]\K[^'\"]*" | head -1)
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
    link_path=$(echo "$soft_info" | grep -oP '<iframe.*?name="[^"]*"\s+src="/\K[^"]*' | head -1)
    ifurl="${origin}/${link_path}"

    segment1=$(echo "$soft_info" | grep -oP "'sign':'\K[^']*" | sed -n '2p')

    if [ -n "$webpage" ] && [ -n "$segment1" ]; then
        ajaxm_path=$(echo "$soft_info" | grep -oP '(https?://[^/\s]+/)?ajax(m|file)\.php\?file=\d+' | head -1)
        post_args=(--data-urlencode "action=downprocess"
                   --data-urlencode "websignkey=Em2R"
                   --data-urlencode "sign=${segment1}"
                   --data-urlencode "websign=2"
                   --data-urlencode "kd=1"
                   --data-urlencode "ves=1")
    else
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
```

Mapping of the script sections back to the original PHP:

- URL 归一化 / 参数读取: LanzouAPI:23-50 
- 挑战页首次请求（`MloocCurlGetWithChallenge`）: LanzouAPI:333-340 
- 文件名/大小/取消分享判断: LanzouAPI:74-98 
- 带密码链接的 sign 提取与下载接口拼接: LanzouAPI:100-149 
- 不带密码链接（含 iframe / 旧版直链页两种分支）: LanzouAPI:150-199 
- 下载接口 JSON 返回校验与拼接 `downUrl1`: LanzouAPI:202-216 
- 最终直链解析（含挑战重试）`MloocCurlHead`: LanzouAPI:257-321 
- 后缀替换与 `pid` 清理: LanzouAPI:222-231 
- `Rand_IP`/`acw_sc_v2_simple`: LanzouAPI:392-424 

重要限制说明（脚本和原 PHP 的差异，请使用前注意）：

1. **正则差异**：bash 用的是 `grep -oP`（需要支持 PCRE 的 GNU grep），部分 PHP 正则（如带命名反向引用的 `sign` 变量匹配、`preg_match_all` 取倒数元素）在 shell 里用 `grep`/`sed` 很难 100% 等价还原，脚本中做了简化近似，遇到蓝奏云页面结构变化时可能需要调整正则。
2. **JSON 解析**：依赖 `jq`，若目标环境没有 `jq` 需要自行安装或替换为 `python3 -c 'import json,sys;...'`。
3. **`replace_url_suffix` 内部用了 `python3`**，因为 shell 原生做 URL decode/encode 不便；若环境没有 Python，需要换成 `jq -Rr @uri`/`perl` 等方案。
4. **没有实现缓存层**（`CacheGet`/`CacheSet`/`CacheClean`），原脚本的缓存逻辑 LanzouAPI:426-457  在此未转换，如需要可以用本地文件 + `find -mmin` 实现 TTL 清理。
5. 脚本依赖蓝奏云页面当前的 HTML/JS 结构，一旦站点改版，和原 PHP 一样都需要同步更新正则规则。
### Citations
**File:** index.php (L1-458)
```php
<?php
/**
 * @package Lanzou
 * @author Filmy,hanximeng
 * @version 1.4.2
 * @Date 2026-10-05
 * @link https://hanximeng.com
 */
//屏蔽报错
error_reporting(0);
header('Access-Control-Allow-Origin:*');
header('Content-Type:application/json; charset=utf-8');
//========== 缓存配置（可按需自定义） ==========
//缓存目录：解析成功后会把结果写入此处，不存在时会自动创建，请确保 PHP 进程有写入权限
$cacheDir = __DIR__ . '/cache';
//缓存有效时间（秒）：短时间内的重复请求直接返回缓存结果，避免大量重复请求触发蓝奏风控；设为 0 表示关闭缓存
//同时作为缓存清理周期：过期缓存会在下次请求经过一个缓存周期后被清理
$cacheTime = 900;
//缓存密钥：参与缓存 key 的生成，多服务器部署时可防止缓存 key 被模拟/投毒，建议修改为随机字符串
$cacheSalt = 'LanzouAPI_Cache_5e3a9f1c';
//默认UA
$UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.121 Safari/537.36';
$url = isset($_GET['url']) ? $_GET['url'] : "";
$pwd = isset($_GET['pwd']) ? $_GET['pwd'] : "";
$type = isset($_GET['type']) ? $_GET['type'] : "";
$webpage = parse_url($url, PHP_URL_QUERY);
//判断传入链接参数是否为空
if (empty($url)) {
	die(
	    json_encode(
	        array(
	            'code' => 400,
	            'msg' => '请输入URL'
	        )
	        , JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES)
	    );
}
//保留分享链接原始域名。蓝奏云的风控 Cookie 与域名关联，强制换域名会导致校验失败。
$parsedUrl = parse_url($url);
if (!isset($parsedUrl['scheme'], $parsedUrl['host'], $parsedUrl['path']) ||
    !in_array(strtolower($parsedUrl['scheme']), array('http', 'https'), true)) {
	JsonError('URL格式错误');
}
$origin = 'https://' . $parsedUrl['host'];
$url = $origin . $parsedUrl['path'];
if (!empty($parsedUrl['query'])) {
	$url .= '?' . $parsedUrl['query'];
}
//缓存 key 由解析参数与缓存密钥共同生成，命中时直接返回，不再请求蓝奏云
$cacheKey = md5($cacheSalt . '|' . $url . '|' . $pwd . '|' . (isset($_GET['n']) ? $_GET['n'] : ''));
$cached = CacheGet($cacheKey);
if ($cached !== false) {
	if ($type == "down") {
		header("X-Lanzou-Cache: HIT");
		header("Location:" . $cached['downUrl']);
		die;
	}
	die(
	    json_encode(
	        array(
	            'code' => 200,
	            'msg' => '解析成功',
	            'name' => isset($cached['name']) ? $cached['name'] : "",
	            'filesize' => isset($cached['filesize']) ? $cached['filesize'] : "",
	            'downUrl' => isset($cached['downUrl']) ? $cached['downUrl'] : "",
	            'fromCache' => true
	        )
	        , JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES)
	    );
}
$cookie="";
$softInfo = MloocCurlGetWithChallenge($url, $UserAgent, $cookie);
//判断文件链接是否失效
if (strpos($softInfo, "文件取消分享了") !== false || strpos($softInfo, "文件不存在") !== false) {
	die(
	    json_encode(
	        array(
	            'code' => 400,
	            'msg' => '文件取消分享了'
	        )
	        , JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES)
	    );
}
//取文件名称、大小
preg_match('~style="font-size: 30px;text-align: center;padding: 56px 0px 20px 0px;">(.*?)</div>~', $softInfo, $softName);
if(!isset($softName[1])) {
	preg_match('~<div class="n_box_3fn".*?>(.*?)</div>~', $softInfo, $softName);
}
preg_match('~<div class="n_filesize".*?>大小：(.*?)</div>~', $softInfo, $softFilesize);
if(!isset($softFilesize[1])) {
	preg_match('~<span class="p7">文件大小：</span>(.*?)<br>~', $softInfo, $softFilesize);
}
if(!isset($softName[1])) {
	preg_match('~var filename = \'(.*?)\';~', $softInfo, $softName);
}
if(!isset($softName[1])) {
	preg_match('~div class="b"><span>(.*?)</span></div>~', $softInfo, $softName);
}
//带密码的链接的处理
if(strpos($softInfo, "function down_p(){") !== false  && empty($webpage)) {
	if(empty($pwd)) {
		die(
			json_encode(
				array(
					'code' => 400,
					'msg' => '请输入分享密码'
			    )
				, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES)
			);
	}
	//新版页面：data:{...'sign':(字面量|变量)}，行首锚定 data: 可排除 //data 注释中的伪参数
	preg_match("~^[ \t]*data\s*:\s*\{[^\r\n]*['\"]sign['\"]\s*:\s*(?:(['\"])(.*?)\\1|([A-Za-z_$][\w$]*))~m", $softInfo, $signParam);
	$sign = isset($signParam[2]) ? $signParam[2] : '';
	//sign 为变量（如 isngis）时，查找对应的 var 赋值
	if($sign === '' && !empty($signParam[3])) {
		preg_match_all("~var\s+" . preg_quote($signParam[3], "~") . "\s*=\s*(['\"])(.*?)\\1\s*;~", $softInfo, $signValues);
		$signValues = array_values(array_filter(isset($signValues[2]) ? $signValues[2] : array(), 'strlen'));
		$sign = !empty($signValues) ? end($signValues) : '';
	}
	//兼容旧版字面量 sign
	if($sign === '') {
		preg_match_all("~'sign':'(.*?)',~", $softInfo, $segment);
		$sign = isset($segment[1][1]) ? $segment[1][1] : '';
	}
	//下载接口可能是绝对地址（apifile.lanzouw.com），也可能是相对地址，统一补全为绝对地址
	preg_match_all("~(?:https?://[^/\s]+/)?(ajax(?:m|file)\.php\?file=\d+)~", $softInfo, $ajaxm);
	$ajaxPath = isset($ajaxm[0][0]) ? $ajaxm[0][0] : '';
	if ($ajaxPath !== '' && strpos($ajaxPath, 'http') !== 0) {
		$ajaxPath = $origin . '/' . ltrim($ajaxPath, '/');
	}
	if(empty($sign) || empty($ajaxPath)) {
		die(
			json_encode(
				array(
					'code' => 400,
					'msg' => '未找到密码页 sign 或下载接口参数'
			    )
				, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES)
			);
	}
	$post_data = array(
		"action" => "downprocess",
		"sign" => $sign,
		"p" => $pwd,
		"kd" => 1
	);
	$softInfo = MloocCurlPost($post_data, $ajaxPath, $url, $UserAgent, "acw_sc__v2=".$cookie);
	$nameInfo = json_decode($softInfo, true);
	$softName[1] = (is_array($nameInfo) && isset($nameInfo['inf'])) ? $nameInfo['inf'] : '';
} else {
	//不带密码的链接处理
	preg_match("~\n<iframe.*?name=\"[\s\S]*?\"\ssrc=\"\/(.*?)\"~", $softInfo, $link);
	//蓝奏云新版页面正则规则
	if(empty($link[1])) {
		preg_match("~<iframe.*?name=\"[\s\S]*?\"\ssrc=\"\/(.*?)\"~", $softInfo, $link);
	}
	$ifurl = $origin . "/" . (isset($link[1]) ? $link[1] : '');
	//带 query 的链接（旧版直链页）：页面里已直接给出 sign/ajaxdata，无需再请求 iframe
	preg_match_all("~'sign':'(.*?)'~", $softInfo, $segment);
	if(!empty($webpage) && !empty($segment[1][1])){
	    preg_match_all("~ajaxdata = '(.*?)'~", $softInfo, $signs);
	    preg_match_all("~(?:https?://[^/\s]+/)?(ajax(?:m|file)\.php\?file=\d+)~", $softInfo, $ajaxm);
	    $post_data = array(
		    "action" => "downprocess",
		    "websignkey" => "Em2R",
		    "sign" => $segment[1][1],
		    "websign" => 2,
		    "kd" => 1,
		    "ves" => 1
	    );
	}else{
	    if(empty($link[1])) {
		    JsonError('未找到下载入口，请检查链接是否有效');
	    }
	    $softInfo = MloocCurlGetWithChallenge($ifurl, $UserAgent, $cookie, $url);
	    preg_match_all("~wp_sign = '(.*?)'~", $softInfo, $segment);
	    preg_match_all("~ajaxdata = '(.*?)'~", $softInfo, $signs);
	    preg_match_all("~(?:https?://[^/\s]+/)?(ajax(?:m|file)\.php\?file=\d+)~", $softInfo, $ajaxm);
	    $softSign = isset($segment[1][0]) ? $segment[1][0] : '';
	    $softWebsign = isset($signs[1][0]) ? $signs[1][0] : '';
	    if($softSign === '') {
		    JsonError('未找到下载接口参数，请检查链接是否有效');
	    }
	    $post_data = array(
		    "action" => "downprocess",
		    "websignkey" => $softWebsign,
		    "signs" => $softWebsign,
		    "sign" => $softSign,
		    "websign" => '',
		    "kd" => 1,
		    "ves" => 1
	    );
	}
	//下载接口可能是绝对地址（apifile.lanzouw.com），也可能是相对地址，统一补全为绝对地址
	$ajaxmPath = $ajaxm[0][0] ?? '';
	if ($ajaxmPath !== '' && strpos($ajaxmPath, 'http') !== 0) {
		$ajaxmPath = $origin . '/' . ltrim($ajaxmPath, '/');
	}
	$softInfo = MloocCurlPost($post_data, $ajaxmPath, $ifurl, $UserAgent, "acw_sc__v2=".$cookie);
}
//其他情况下的信息输出
$decoded = json_decode($softInfo, true);
if (!is_array($decoded) || !isset($decoded['zt']) || $decoded['zt'] != 1) {
	$errMsg = (is_array($decoded) && isset($decoded['inf'])) ? $decoded['inf'] : '解析失败，蓝奏云返回异常，请稍后重试';
	die(
	    json_encode(
	        array(
	            'code' => 400,
	            'msg' => $errMsg
	        )
	        , JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES)
	    );
}
$softInfo = $decoded;
//拼接链接
$downUrl1 = $softInfo['dom'] . '/file/' . $softInfo['url'];
//解析最终直链地址：蓝奏云 CDN 对缺少浏览器特征的请求会先返回 ESA 挑战页，需带上浏览器请求头并算出 acw_sc__v2 后重试
$downUrl2 = MloocCurlHead($downUrl1, $UserAgent);
//判断最终链接是否获取成功，如未成功则使用原链接
if(strpos($downUrl2,"http") === false) {
	$downUrl = $downUrl1;
} else {
	//2025-03-17 新增后缀自定义功能 https://github.com/hanximeng/LanzouAPI/issues/26
	if(!empty($_GET['n'])){
	    $downUrl = ReplaceUrlSuffix($downUrl2, $_GET['n']);
	}else{
	    $downUrl = $downUrl2;
	}
}
//2024-12-03 修复pid参数可能导致的服务器ip地址泄露
$downUrl=preg_replace('/pid=(.*?.)&/', '', $downUrl);
//解析成功，写入缓存供短时间内的重复请求复用
CacheSet($cacheKey, array(
	'name' => isset($softName[1]) ? $softName[1] : "",
	'filesize' => isset($softFilesize[1]) ? $softFilesize[1] : "",
	'downUrl' => $downUrl
));
//判断是否是直接下载
if ($type != "down") {
	die(
	    json_encode(
	        array(
	            'code' => 200,
	            'msg' => '解析成功',
	            'name' => isset($softName[1]) ? $softName[1] : "",
	            'filesize' => isset($softFilesize[1]) ? $softFilesize[1] : "",
	            'downUrl' => $downUrl
	        )
	        , JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES)
	    );
} else {
	header("Location:$downUrl");
	die;
}
//直链解析函数：蓝奏云 CDN 会先返回 ESA 挑战页，需按浏览器特征请求并算出 acw_sc__v2 重试，
//302 响应中的 Location 才是最终直链（因此不能开启自动跳转，否则会直接下载整个文件）
function MloocCurlHead($url, $UserAgent) {
	$cookies = array();
	$headers = array(
		'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
		'Accept-Language: zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7',
		'sec-ch-ua: "Not(A:Brand";v="8", "Chromium";v="144"',
		'sec-ch-ua-mobile: ?0',
		'sec-ch-ua-platform: "Windows"',
		'Sec-Fetch-Dest: document',
		'Sec-Fetch-Mode: navigate',
		'Sec-Fetch-Site: cross-site',
		'Sec-Fetch-User: ?1',
		'Upgrade-Insecure-Requests: 1',
		'X-Requested-With: mark.via'
	);
	//挑战页也可能需要重试多次，最多请求 3 次
	for ($i = 0; $i < 3; $i++) {
		$location = '';
		$curl = curl_init();
		curl_setopt($curl, CURLOPT_URL, $url);
		curl_setopt($curl, CURLOPT_HTTPHEADER, $headers);
		curl_setopt($curl, CURLOPT_USERAGENT, $UserAgent);
		curl_setopt($curl, CURLOPT_ENCODING, 'gzip, deflate');
		if (!empty($cookies)) {
			$pairs = array();
			foreach ($cookies as $name => $value) {
				$pairs[] = $name . '=' . $value;
			}
			curl_setopt($curl, CURLOPT_COOKIE, implode('; ', $pairs));
		}
		curl_setopt($curl, CURLOPT_RETURNTRANSFER, 1);
		curl_setopt($curl, CURLOPT_SSL_VERIFYPEER, false);
		curl_setopt($curl, CURLOPT_SSL_VERIFYHOST, false);
		//超时设置，默认为10秒
		curl_setopt($curl, CURLOPT_TIMEOUT, 10);
		curl_setopt($curl, CURLOPT_HEADERFUNCTION, function ($curl, $header) use (&$location, &$cookies) {
			$pos = strpos($header, ':');
			if ($pos === false) {
				return strlen($header);
			}
			$name = strtolower(trim(substr($header, 0, $pos)));
			$value = trim(substr($header, $pos + 1));
			if ($name === 'location' && $location === '') {
				$location = $value;
			} elseif ($name === 'set-cookie') {
				$pair = explode('=', explode(';', $value)[0], 2);
				if (count($pair) === 2) {
					$cookies[trim($pair[0])] = trim($pair[1]);
				}
			}
			return strlen($header);
		});
		$response = curl_exec($curl);
		if ($location !== '') {
			return $location;
		}
		//挑战页：从 var arg1 算出 acw_sc__v2 后带上 Cookie 重试
		if (preg_match("~var\\s+arg1=['\"]([0-9a-f]{40})['\"]~i", (string)$response, $match)) {
			$cookies['acw_sc__v2'] = acw_sc_v2_simple($match[1]);
			continue;
		}
		break;
	}
	return '';
}
//2025-03-17 新增后缀自定义功能 https://github.com/hanximeng/LanzouAPI/issues/26
//新版直链形如 https://xxx/file/xxx.txt?sg=...&fileName=xxx.txt，其中 sg 签名包含路径，改路径会 403，
//因此只替换查询参数中的文件名扩展名（新版 fileName、旧版 fn）
function ReplaceUrlSuffix($url, $suffix) {
	$suffix = ltrim($suffix, '.');
	return preg_replace_callback('~(fileName|fn)=([^&]*)~', function ($match) use ($suffix) {
		$value = preg_replace('~\\.[A-Za-z0-9]+$~', '', rawurldecode($match[2])) . '.' . $suffix;
		return $match[1] . '=' . rawurlencode($value);
	}, $url, 1);
}
//阿里云 ESA 会先返回 arg1 挑战页。计算 acw_sc__v2 后以同一 UA、Referer 重试。
function MloocCurlGetWithChallenge($url, $UserAgent, &$cookie, $referer = '') {
	$response = MloocCurlGet($url, $UserAgent, $cookie === '' ? '' : 'acw_sc__v2='.$cookie, $referer);
	if (preg_match("~var\\s+arg1=['\"]([0-9a-f]{40})['\"]~i", $response, $match)) {
		$cookie = acw_sc_v2_simple($match[1]);
		$response = MloocCurlGet($url, $UserAgent, 'acw_sc__v2='.$cookie, $referer);
	}
	return $response;
}
//JSON错误输出
function JsonError($message) {
	die(json_encode(array('code' => 400, 'msg' => $message), JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES));
}
//CURL函数
function MloocCurlGet($url = '', $UserAgent = '', $cookie = '', $referer = '') {
	$curl = curl_init();
	curl_setopt($curl, CURLOPT_URL, $url);
	curl_setopt($curl, CURLOPT_FOLLOWLOCATION, 1);
	curl_setopt($curl, CURLOPT_COOKIE , $cookie);
	if ($UserAgent != "") {
		curl_setopt($curl, CURLOPT_USERAGENT, $UserAgent);
	}
	if ($referer != "") {
		curl_setopt($curl, CURLOPT_REFERER, $referer);
	}
	curl_setopt($curl, CURLOPT_HTTPHEADER, array('X-FORWARDED-FOR:'.Rand_IP(), 'CLIENT-IP:'.Rand_IP()));
	#关闭SSL
	    curl_setopt($curl, CURLOPT_SSL_VERIFYPEER, false);
	    curl_setopt($curl, CURLOPT_ENCODING, 'gzip');
	    curl_setopt($curl, CURLOPT_SSL_VERIFYHOST, false);
	#返回数据不直接显示
	    curl_setopt($curl, CURLOPT_RETURNTRANSFER, 1);
	#超时设置，默认为10秒
	    curl_setopt($curl, CURLOPT_TIMEOUT, 10);
	$response = curl_exec($curl);
	return $response;
}
//POST函数
function MloocCurlPost($post_data = '', $url = '', $ifurl = '', $UserAgent = '',$cookie = '') {
	$curl = curl_init();
	curl_setopt($curl, CURLOPT_URL, $url);
	curl_setopt($curl, CURLOPT_COOKIE , $cookie);
	curl_setopt($curl, CURLOPT_USERAGENT, $UserAgent);
	if ($ifurl != '') {
		curl_setopt($curl, CURLOPT_REFERER, $ifurl);
	}
	curl_setopt($curl, CURLOPT_HTTPHEADER, array('X-FORWARDED-FOR:'.Rand_IP(), 'CLIENT-IP:'.Rand_IP()));
	#关闭SSL
	    curl_setopt($curl, CURLOPT_SSL_VERIFYPEER, false);
	curl_setopt($curl, CURLOPT_SSL_VERIFYHOST, false);
	#返回数据不直接显示
	    curl_setopt($curl, CURLOPT_RETURNTRANSFER, 1);
	#超时设置，默认为10秒
	    curl_setopt($curl, CURLOPT_TIMEOUT, 10);
	curl_setopt($curl, CURLOPT_POST, 1);
	curl_setopt($curl, CURLOPT_POSTFIELDS, $post_data);
	$response = curl_exec($curl);
	return $response;
}
//随机IP函数
function Rand_IP() {
	$ip2id = round(rand(600000, 2550000) / 10000);
	$ip3id = round(rand(600000, 2550000) / 10000);
	$ip4id = round(rand(600000, 2550000) / 10000);
	$arr_1 = array("218","218","66","66","218","218","60","60","202","204","66","66","66","59","61","60","222","221","66","59","60","60","66","218","218","62","63","64","66","66","122","211");
	$randarr= mt_rand(0,count($arr_1)-1);
	$ip1id = $arr_1[$randarr];
	return $ip1id.".".$ip2id.".".$ip3id.".".$ip4id;
}
//cookie生成函数(现在好像又不验证了，怕忘记就先留着吧，介意的可以删除这个函数)
function acw_sc_v2_simple($arg1) {
    $posList = [15,35,29,24,33,16,1,38,10,9,19,31,40,27,22,23,25,13,6,11,39,18,20,8,14,21,32,26,2,30,7,4,17,5,3,28,34,37,12,36];
    $mask = '3000176000856006061501533003690027800375';
    $outPutList = array_fill(0, 40, '');
    for ($i = 0; $i < strlen($arg1); $i++) {
        $char = $arg1[$i];
        foreach ($posList as $j => $pos) {
            if ($pos == $i + 1) {
                $outPutList[$j] = $char;
            }
        }
    }
    $arg2 = implode('', $outPutList);
    $result = '';
    $length = min(strlen($arg2), strlen($mask));
    for ($i = 0; $i < $length; $i += 2) {
        $strHex = substr($arg2, $i, 2);
        $maskHex = substr($mask, $i, 2);
        $xorResult = dechex(hexdec($strHex) ^ hexdec($maskHex));
        $result .= str_pad($xorResult, 2, '0', STR_PAD_LEFT);
    }
    return $result;
}
//读取缓存，命中且未过期时返回数据数组，否则返回 false
function CacheGet($key) {
	global $cacheDir, $cacheTime;
	if ($cacheTime <= 0) return false;
	//按周期清理已过期的缓存文件
	CacheClean();
	$file = $cacheDir . '/' . $key . '.json';
	if (!is_file($file)) return false;
	$data = json_decode(@file_get_contents($file), true);
	if (!is_array($data) || !isset($data['time'], $data['data'])) return false;
	if (time() - $data['time'] > $cacheTime) return false;
	return $data['data'];
}
//写入缓存
function CacheSet($key, $data) {
	global $cacheDir, $cacheTime;
	if ($cacheTime <= 0) return;
	if (!is_dir($cacheDir) && !@mkdir($cacheDir, 0755, true)) return;
	$payload = json_encode(array('time' => time(), 'data' => $data), JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
	@file_put_contents($cacheDir . '/' . $key . '.json', $payload);
}
//按缓存有效时间 $cacheTime 周期清理一次已过期的缓存文件，防止失效缓存长期残留
function CacheClean() {
	global $cacheDir, $cacheTime;
	$flagFile = $cacheDir . '/.last_clean';
	$lastClean = is_file($flagFile) ? (int)@file_get_contents($flagFile) : 0;
	if (time() - $lastClean <= $cacheTime) return;
	@file_put_contents($flagFile, time());
	if (!is_dir($cacheDir)) return;
	foreach (glob($cacheDir . '/*.json') as $file) {
		if (time() - filemtime($file) > $cacheTime) @unlink($file);
	}
}
?>
```
## Q5
replace_url_suffix 内部换成 jq -Rr @uri，需要怎么修改
### Answer
I'm figuring out how to replace the python3-based URL suffix logic with a jq-based approach using @uri encoding, which means decoding the value, stripping the extension, appending the suffix, then re-encoding without relying on python3.

Since jq lacks native URL-decoding, I'm writing a pure bash percent-decode function, then combining it with regex extraction of the fileName/fn parameter and jq's @uri for encoding, writing the new replace_url_suffix function piece by piece.

I'm now thinking the sed-based substitution risks breaking if the value contains special regex characters like slashes, so I should switch to bash's literal parameter substitution (${url/search/replace}) instead for safer, non-regex replacement.

Here's the `replace_url_suffix` function rewritten to use `jq -Rr @uri` for the encoding step, with plain bash parameter expansion for the decoding step (since `jq` has no built-in URL-decode filter, only `@uri` for encoding):

```bash
# ---------- 替换下载链接后缀（对应 ReplaceUrlSuffix，使用 jq -Rr @uri 做编码） ----------
replace_url_suffix() {
    local url="$1" suffix="${2#.}"

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
    decoded="$(sed -E 's/\.[A-Za-z0-9]+$//' <<< "$decoded")"
    decoded="${decoded}.${suffix}"

    # URL 编码（等价于 PHP 的 rawurlencode，用 jq -Rr @uri 实现）
    local encoded_value
    encoded_value="$(printf '%s' "$decoded" | jq -Rr @uri)"

    # 替换回原 URL 中第一次出现的 key=value（用字面量参数替换，避免 sed 正则元字符问题）
    echo "${url/${key}=${value}/${key}=${encoded_value}}"
}
```

Key points:

- **Decoding**: `jq` has no built-in percent-decode filter (only `@uri` for encoding), so the `%XX` → byte decoding is done in pure bash via `${value//+/ }` (space handling) followed by `printf '%b' "${decoded//%/\\x}"`, which converts `%XX` sequences into `\xXX` escapes that `printf %b` then resolves to raw bytes.
- **Encoding**: `printf '%s' "$decoded" | jq -Rr @uri` reads the string as raw input (`-R`) and emits percent-encoded raw output (`-r`), equivalent to PHP's `rawurlencode()`.
- **Extension stripping**: unchanged, still uses `sed -E 's/\.[A-Za-z0-9]+$//'` to match the original `preg_replace('~\.[A-Za-z0-9]+$~', '', ...)` behavior.
- **Final substitution**: switched from `sed` back-substitution to bash's `${url/pattern/replacement}` with literal `key=value` as the search pattern — this avoids having to escape regex metacharacters that could appear in `$value` (e.g. `.`, `*`) when using `sed`. Note this is still a glob-style pattern match in bash, so values containing `*`, `?`, or `[` could still misbehave in rare cases; if that's a concern, escape those characters before substitution or fall back to `awk`.

This replaces only the encoding/decoding step of the function from the previous full script; the rest of `lanzou_direct.sh` (URL parsing, challenge-cookie logic, password/no-password branches, etc.) stays the same as given earlier.
## Q6
++ grep -oP 'style="font-size: 30px;text-align: center;padding: 56px 0px 20px 0px;">\K[^<]*'
++ head -1
+ soft_name=
调试输出上面就退出了
### Answer
This looks like a set -euo pipefail issue where grep returns no match, causing the pipeline to fail and the script to exit before soft_name gets assigned a value.

Since the rightmost non-zero exit is grep's 1 (head still exits 0), pipefail makes the whole pipeline return 1, and with set -e that failed assignment would terminate the script unless guarded by a conditional. So the real bug is that grep failing to match is being treated as a fatal error when it's actually an expected, normal case.

I should explain this root cause and suggest fixing it by appending `|| true` to each grep pipeline (or restructuring to avoid tripping errexit), then give the corrected snippet matching the fallback chain pattern.

The script is exiting because of `set -euo pipefail` combined with chained fallback `grep` calls.

**Root cause:** `grep -oP '...' | head -1` — when the regex doesn't match (which is expected and normal, since that's just the first of several fallback patterns for the filename), `grep` exits with status `1` (no match found). Even though `head -1` after it exits with status `0`, **`pipefail`** makes the whole pipeline return the *last non-zero* exit code in the chain (grep's `1`), not just the last command's exit code. Then, because this pipeline is the right-hand side of a variable assignment (`soft_name=$(...)`), `set -e` treats that non-zero status as a command failure and immediately terminates the script — which is exactly the behavior you're seeing right after `soft_name=` prints empty.

This affects every one of the chained fallback extraction lines in the script, e.g.:
```bash
soft_name=$(echo "$soft_info" | grep -oP 'style="font-size: 30px;...">\K[^<]*' | head -1)
[ -z "$soft_name" ] && soft_name=$(echo "$soft_info" | grep -oP '<div class="n_box_3fn".*?>\K[^<]*' | head -1)
...
```
The first pattern not matching is expected/normal (it's just a fallback chain like the PHP `if(!isset($softName[1])) { ... }`), but under `set -e` + `pipefail` it's fatal instead of falling through.

**Fix:** append `|| true` (or `|| :`) to every such `grep | head` pipeline so a non-match doesn't trip `errexit`:

```bash
soft_name=$(echo "$soft_info" | grep -oP 'style="font-size: 30px;text-align: center;padding: 56px 0px 20px 0px;">\K[^<]*' | head -1 || true)
[ -z "$soft_name" ] && soft_name=$(echo "$soft_info" | grep -oP '<div class="n_box_3fn".*?>\K[^<]*' | head -1 || true)
[ -z "$soft_name" ] && soft_name=$(echo "$soft_info" | grep -oP "var filename = '\K[^']*" | head -1 || true)
[ -z "$soft_name" ] && soft_name=$(echo "$soft_info" | grep -oP '<div class="b"><span>\K[^<]*' | head -1 || true)

soft_filesize=$(echo "$soft_info" | grep -oP '<div class="n_filesize".*?>大小：\K[^<]*' | head -1 || true)
[ -z "$soft_filesize" ] && soft_filesize=$(echo "$soft_info" | grep -oP '<span class="p7">文件大小：</span>\K[^<]*' | head -1 || true)
```

The same issue applies to every other `grep -oP ... | head/sed/tail` call in the script that's expected to sometimes not match (e.g. `ajaxm_path`, `sign`, `link_path`, `soft_sign`, `soft_websign`, `inf`, etc.) — any of them will kill the script the first time the pattern legitimately doesn't match. The safest general fix is to append `|| true` to each such pipeline, or alternatively wrap risky sections with `set +e` / `set -e` toggles around the extraction block, or restructure with explicit `if` checks instead of relying on bare pipeline exit status under `set -e`.

As a side note: since this is a standalone script with no connection to the actual repository (the repo only contains the PHP implementation; there is no shell script in the codebase), I can't point you to any pre-existing shell code for this — this is entirely new script debugging based on what we wrote in this conversation.
## Q7
++ grep -oP ''\''sign'\'':'\''\K[^'\'']*'
++ sed -n 2p
+ segment1=
+ '[' -n '' ']'
+ '[' -z '' ']'
+ json_error 未找到下载入口，请检查链接是否有效
+ jq -n --arg msg 未找到下载入口，请检查链接是否有效 '{code:400, msg:$msg}'
{
  "code": 400,
  "msg": "未找到下载入口，请检查链接是否有效"
}
+ exit 1
增加调试信息 ，展示主要步取的结果
### Answer
This is just about adding debug output to the shell script at each key extraction step, since it's failing at the link-not-found check—no codebase search needed since it's all standalone invented script code. I'll just add debug print statements directly to the previous script.

This is about instrumenting the standalone shell script we wrote (not part of the repo — there is no shell implementation in `hanximeng/LanzouAPI`, only `index.php`). I'll add debug tracing around the "不带密码链接" branch so you can see what `link_path`/`segment1`/`webpage`/`ajaxm_path` actually resolve to before the `json_error` is triggered.

Add a `DEBUG` helper and sprinkle it at each extraction point in that branch:

```bash
# ---------- 调试输出开关 ----------
# 运行时设置 DEBUG=1 ./lanzou_direct.sh ... 即可打开
DEBUG="${DEBUG:-0}"
dbg() {
    [ "$DEBUG" = "1" ] && echo "[DEBUG] $*" >&2
    return 0
}
```

然后在“不带密码链接”分支里逐步打印关键变量（对应原脚本里 `link_path` / `webpage` / `segment1` / `ajaxm_path` 的提取顺序）：

```bash
} else {
    # ---------- 不带密码链接 ----------
    dbg "soft_info length: ${#soft_info}"
    dbg "soft_info 片段(前200字符): ${soft_info:0:200}"

    link_path=$(echo "$soft_info" | grep -oP '<iframe.*?name="[^"]*"\s+src="/\K[^"]*' | head -1 || true)
    dbg "link_path (iframe src) = [$link_path]"

    ifurl="${origin}/${link_path}"
    dbg "ifurl = [$ifurl]"
    dbg "webpage (query string) = [$webpage]"

    segment1=$(echo "$soft_info" | grep -oP "'sign':'\K[^']*" | sed -n '2p' || true)
    dbg "segment1 (第2个 'sign':'...') = [$segment1]"

    if [ -n "$webpage" ] && [ -n "$segment1" ]; then
        dbg "走分支: 带 query 的旧版直链页"
        ajaxm_path=$(echo "$soft_info" | grep -oP '(https?://[^/\s]+/)?ajax(m|file)\.php\?file=\d+' | head -1 || true)
        dbg "ajaxm_path = [$ajaxm_path]"
        ...
    else
        dbg "走分支: 需要请求 iframe 子页"
        if [ -z "$link_path" ]; then
            dbg "link_path 为空 -> 即将触发 '未找到下载入口' 错误"
            json_error "未找到下载入口，请检查链接是否有效"
        fi
        soft_info=$(mlooc_curl_get_with_challenge "$ifurl" "$url")
        dbg "iframe 页 soft_info 片段(前200字符): ${soft_info:0:200}"

        soft_sign=$(echo "$soft_info" | grep -oP "wp_sign = '\K[^']*" | head -1 || true)
        dbg "soft_sign = [$soft_sign]"
        soft_websign=$(echo "$soft_info" | grep -oP "ajaxdata = '\K[^']*" | head -1 || true)
        dbg "soft_websign = [$soft_websign]"
        ajaxm_path=$(echo "$soft_info" | grep -oP '(https?://[^/\s]+/)?ajax(m|file)\.php\?file=\d+' | head -1 || true)
        dbg "ajaxm_path = [$ajaxm_path]"
        ...
    fi
```

从你贴出的日志看，`segment1` 为空，接着进入了 `else` 分支，说明真正的问题点在**更早一步**：`link_path`（iframe 的 `src`）也是空的，所以 `ifurl` 变成了 `"${origin}/"`，随后 `[ -z "$link_path" ]` 成立直接报错退出。

重点排查方向：

1. **先确认 `soft_info` 本身是否正确**：打开 `DEBUG=1` 后看 `soft_info length` 和前 200 字符，确认请求没有被挑战页拦截、没有返回反爬页面或空响应。如果 `MloocCurlGetWithChallenge` 没有正确处理重定向/压缩，`soft_info` 可能根本不是预期的分享页 HTML。
2. **`<iframe>` 正则是否还适配当前蓝奏云页面结构**：这段正则来自原 PHP 的 `~\n<iframe.*?name="[\s\S]*?"\ssrc="\/(.*?)"~`，而 shell 里简化成了单行 `grep -oP`，PHP 版本用了 `[\s\S]*?` 允许跨行匹配 `name="..."` 属性，`grep -oP` 默认是逐行匹配的，如果 `name="..."` 属性值本身包含换行或者 `<iframe` 与 `name=` 不在同一行，`grep -oP`（单行模式）就会匹配不到，这很可能是症结所在。需要改用 `grep -Pzo`（null 分隔、跨行）或 `perl -0777 -ne` 来真正模拟 PHP 的跨行 `[\s\S]*?`。

要不要我给出用 `grep -Pzo`（或 `perl -0777`）重写 `link_path` 提取、使其能跨行匹配 `<iframe>` 标签的具体代码？
## Q8
[DEBUG] soft_info length: 4321
[DEBUG] soft_info 片段(前200字符): <html><script>var arg1='27626D93E8018750254DF23CFE2CD7B54FA0E44D';(function(a,c){var G=a0j,d=a();while(!![]){try{var e=-parseInt(G(0x117))/0x1*(parseInt(G(0x111))/0x2)+-parseInt(G(0xfb))/0x3*(parseInt
[DEBUG] link_path (iframe src) = []
[DEBUG] ifurl = [https://www.lanzouo.com/]
[DEBUG] webpage (query string) = []
[DEBUG] segment1 (第2个 'sign':'...') = []
[DEBUG] 走分支: 需要请求 iframe 子页
{
  "code": 400,
  "msg": "未找到下载入口，请检查链接是否有效"
}
### Answer
The debug output shows soft_info is still a challenge page, meaning the challenge-solving function didn't actually retrieve the real content—either the retry also hit the challenge page or the solving logic failed silently somewhere.

Wait, I think I found it: the arg1 hex value contains uppercase letters, but my bash regex only matches lowercase [0-9a-f]{40} without a case-insensitive flag, unlike the original PHP regex which uses /i. That mismatch would cause my extraction to fail on uppercase hex.

Confirmed - the arg1 value contains uppercase hex characters, which the PHP regex matched fine due to its case-insensitive flag but the bash pattern missed since it only covers lowercase a-f. The fix is to update both bash extraction points to accept [0-9A-Fa-f]{40}, and I should double-check the hex string is actually 40 characters long.

Counting through confirms exactly 40 characters match, so the real problem is case-sensitivity in the bash regex — the character class needs A-F added or nocasematch enabled. This is purely a shell script logic issue, not something requiring a codebase search.

Found it. The debug output shows `soft_info` is still the raw **挑战页 (challenge page)** itself — `<html><script>var arg1='27626D93E8018750254DF23CFE2CD7B54FA0E44D';...` — meaning `mlooc_curl_get_with_challenge` never actually solved the challenge and retried; it just returned the first response as-is.

**Root cause: case-sensitivity bug in the bash regex.**

The `arg1` value here is `27626D93E8018750254DF23CFE2CD7B54FA0E44D`, which contains **uppercase** hex digits (`D`, `E`, `F`, `C`, `B`, `A`). The original PHP regex uses the `/i` case-insensitive flag:

```php
preg_match("~var\\s+arg1=['\"]([0-9a-f]{40})['\"]~i", $response, $match)
``` LanzouAPI:333-340 

But the bash translation I gave you used a plain, case-sensitive character class:

```bash
if [[ "$resp" =~ var[[:space:]]+arg1=[\'\"]([0-9a-f]{40})[\'\"] ]]; then
```

Since bash's `[[ =~ ]]` is case-sensitive by default and `[0-9a-f]` only covers lowercase, this never matched an uppercase-containing `arg1` like the one above — so `CHALLENGE_COOKIE` was never computed, the function fell through without retrying, and the raw challenge page got passed downstream as `soft_info`, which then fails every later `grep` extraction (iframe `link_path`, `segment1`, etc.), eventually hitting your `"未找到下载入口"` error.

**Fix:** make the character class case-insensitive (or enable `shopt -s nocasematch`). Apply this in **both** places that extract `arg1` — `mlooc_curl_get_with_challenge` and `mlooc_curl_head`:

```bash
# in mlooc_curl_get_with_challenge
if [[ "$resp" =~ var[[:space:]]+arg1=[\'\"]([0-9A-Fa-f]{40})[\'\"] ]]; then
    CHALLENGE_COOKIE=$(acw_sc_v2_simple "${BASH_REMATCH[1]}")
    ...
fi
```

```bash
# in mlooc_curl_head
if [[ "$body" =~ var[[:space:]]+arg1=[\'\"]([0-9A-Fa-f]{40})[\'\"] ]]; then
    local cookie_val
    cookie_val=$(acw_sc_v2_simple "${BASH_REMATCH[1]}")
    ...
fi
```

Also worth noting: `acw_sc_v2_simple` itself doesn't care about case (it just XORs hex nibbles), but to be safe you may want to lowercase `arg1` before passing it in, since `16#$strHex` in bash's arithmetic expansion handles both cases fine, so no change needed there — the only bug is the matching regex's character class.

Add a debug line right after the first `curl` call in `mlooc_curl_get_with_challenge` to confirm the fix works:

```bash
dbg "first resp 片段: ${resp:0:200}"
if [[ "$resp" =~ var[[:space:]]+arg1=[\'\"]([0-9A-Fa-f]{40})[\'\"] ]]; then
    dbg "matched arg1 = ${BASH_REMATCH[1]}"
    CHALLENGE_COOKIE=$(acw_sc_v2_simple "${BASH_REMATCH[1]}")
    dbg "computed CHALLENGE_COOKIE = $CHALLENGE_COOKIE"
    ...
else
    dbg "arg1 NOT matched - check regex/case"
fi
```

Once this regex is fixed, `soft_info` after the retry should be the actual share page HTML (containing the `<iframe>` tag), and the earlier `link_path` extraction should start succeeding — at which point you may hit the separate multi-line `<iframe>` matching issue (`grep -oP` not handling `[\s\S]*?` across lines) discussed previously, which would need `grep -Pzo` or `perl -0777`.
### Citations
**File:** index.php (L333-340)
```php
function MloocCurlGetWithChallenge($url, $UserAgent, &$cookie, $referer = '') {
	$response = MloocCurlGet($url, $UserAgent, $cookie === '' ? '' : 'acw_sc__v2='.$cookie, $referer);
	if (preg_match("~var\\s+arg1=['\"]([0-9a-f]{40})['\"]~i", $response, $match)) {
		$cookie = acw_sc_v2_simple($match[1]);
		$response = MloocCurlGet($url, $UserAgent, 'acw_sc__v2='.$cookie, $referer);
	}
	return $response;
}
```
## Q9
如果上述脚本用来在scoop安装josn中的post_install脚本中调用，脚本放在哪里才能生效
### Answer
This question is really about Scoop packaging conventions rather than this repo's code, since LanzouAPI doesn't have a scoop manifest. I should check whether the repo has any scoop-related files before answering.

The `hanximeng/LanzouAPI` repository contains no Scoop manifest or packaging files — it's purely the PHP endpoint `index.php`.  There's nothing in this codebase about Scoop integration, so this question is really about Scoop's own mechanics rather than this repo.

That said, to answer conceptually (standard Scoop behavior, unrelated to this repo's code):

- Scoop manifests are JSON files (e.g. `appname.json`) that live in a bucket repository, and `post_install` is an array of **PowerShell** statements/lines embedded directly inside that JSON — it is not a path to an external script file. Scoop executes those lines inline via its own PowerShell installer after extraction, in the context of the app's install directory (`$dir`).
- Because `post_install` entries are literal PowerShell, your bash script (`lanzou_direct.sh`) cannot be invoked as-is unless:
  1. You ship the `.sh` file as part of the app's packaged files (e.g. placed under `$dir` or a subfolder, referenced via Scoop's `$dir`/`$persist_dir` variable), and
  2. The `post_install` PowerShell line invokes something capable of running bash on Windows — e.g. WSL's `wsl bash "$dir\lanzou_direct.sh"` or Git Bash's `bash.exe`/`sh.exe` if present on PATH — since plain Windows has no native bash interpreter.
- Practically, the file would need to be included in the package's distributable archive (so it ends up in `$dir` after extraction, e.g. `$dir\scripts\lanzou_direct.sh`), and the manifest's `post_install` array would call it like:
  ```json
  "post_install": [
    "bash \"$dir\\scripts\\lanzou_direct.sh\" -u \"$someUrl\""
  ]
  ```
  assuming a bash binary (WSL, Git Bash, MSYS2, Cygwin) is available on the target machine's PATH — Scoop itself does not provide one.

This is general Scoop packaging knowledge, not something present in or governed by this repository's code, since the repo has no manifest or install scripts of its own.
## Q10
scoop 能不能调用bucket对应仓库下script目录中的脚本
### Answer
This is a general question about Scoop mechanics rather than something specific to the repo, so I can answer it conceptually, but let me do a quick search of the repo just to confirm there's nothing relevant about bucket scripts.

Confirmed — `hanximeng/LanzouAPI` has no Scoop bucket/manifest files at all, so this is purely a question about Scoop's own mechanics, unrelated to this repo's code.

Answering conceptually (standard Scoop behavior):

**Yes**, `post_install` (and other script hooks like `pre_install`, `installer.script`, `pre_uninstall`, `post_uninstall`) can reference and execute files that live anywhere accessible on disk after checkout/extraction — including a `scripts/` (or any other) subfolder inside the bucket repository itself. There are two distinct ways this works:

1. **Dot-sourcing/invoking a bucket-relative script path directly:**
   Since the bucket repo is cloned locally by Scoop (typically to `~/scoop/buckets/<bucketname>/`), a manifest's `post_install` PowerShell lines can reference that known bucket path and dot-source or invoke a script from its `scripts/` directory, e.g.:
   ```json
   "post_install": [
     ". \"$(Split-Path $MyInvocation.MyCommand.Path)\\..\\scripts\\lanzou_setup.ps1\""
   ]
   ```
   or more simply by constructing the bucket path from `$PSScriptRoot`/manifest location if the manifest itself is processed as a script context — but note Scoop's JSON manifests are *not* PowerShell files themselves; the `post_install` array entries are the literal PowerShell lines that get `Invoke-Expression`'d or dot-sourced by Scoop's installer, so they can call `& "<path-to-script>"` using any resolvable path, including a relative path into the bucket repo.

2. **Shipping the script as part of the app's own package (`url`/`extract_dir`):**
   This is the more common and portable pattern — bundle the script inside the downloaded/extracted app archive itself (not the bucket repo), so it ends up under `$dir` after installation, and reference it via `$dir\scripts\yourscript.ps1` in `post_install`. This doesn't depend on bucket layout at all and is what most real-world Scoop manifests do.

The key distinction: **the bucket repository's own files** (anything checked into the bucket git repo alongside the manifest `.json`) are available locally wherever the user cloned that bucket (e.g. `~/scoop/buckets/<bucket>/scripts/...`), so a manifest can reference them with a path relative to the bucket root — but this is fragile because it assumes the bucket name/location, and if the user adds the bucket under a different name, hardcoded paths relative to a default bucket location (`~/scoop/buckets/<bucketname>`) would break. The safer, standard approach is to package the script with the app itself (`url`) rather than depend on the bucket repo's working-copy path.

Either way, these `post_install` entries must be PowerShell, not bash — so the bash `lanzou_direct.sh` script discussed earlier would still need either a Windows PowerShell rewrite, or an explicit call to a bash interpreter (WSL/Git Bash) if you truly want to keep it as a `.sh` file placed in the bucket's `scripts/` folder.
## Q11
增加一个判断，
有可能soft_info返回的html不是链接入口，返回如下内容
function file(){
		$.ajax({
			type : 'post',
			url : '/filemoreajax.php?file=851998',
			data : { 
			'lx':2,
			'fid':851998,
			'uid':'522717',
			'puid':'BjMGY14xAmEHYFEwVy4AMAFsBTkFaFRuAjcAMVE_bVmMEPVUvAG8OalM3UTFXMwI1UzkBMg_c_c',
			'pg':pgs,
			'rep':'0',
			't':ib2l5d,
			'k':_h0x76,
			'up':1,
			'vip':'0',
			'webfoldersign':'',
						},
			dataType : 'json',
			success:function(msg){
				//隐藏
				document.getElementById("load2").style.display="none";
				if(msg.zt == '1'){
										var data = msg.text;
					$.each(data, function(i, n){
						search_lock = 2;//解除回车锁
						var str;
需要提取先进行一次请求：
curl 'https://www.lanzouo.com/b0ufru1i' \
  --compressed \
  -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:158.0) Gecko/20100101 Firefox/158.0' \
  -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8' \
  -H 'Accept-Language: en-US,en;q=0.9' \
  -H 'Accept-Encoding: gzip, deflate, br, zstd' \
  -H 'Connection: keep-alive' \
  -H 'Cookie: codelen=1; pc_ad1=1; acw_tc=3df10e0a17928272716752044e8106226dc18060563ecb5689b651df88; cdn_sec_tc=3df10e0a17928272716752044e8106226dc18060563ecb5689b651df88; acw_sc__v2=6adc5f8759c569dcf9ee0167b90b635f0364c02e' \
  -H 'Upgrade-Insecure-Requests: 1' \
  -H 'Sec-Fetch-Dest: document' \
  -H 'Sec-Fetch-Mode: navigate' \
  -H 'Sec-Fetch-Site: cross-site' \
  -H 'Sec-Fetch-User: ?1' \
  -H 'DNT: 1' \
  -H 'Sec-GPC: 1' \
  -H 'Priority: u=0, i' \
  -H 'TE: trailers'
返回响应是json内容是
{"zt":1,"info":"sucess","text":[{"icon":"7z","t":0,"id":"iktUy4d2x22h","name_all":"RunningCheeseChrome.7z","size":"162.9 M","time":"23 \u5c0f\u65f6\u524d","duan":"i4d2x22","p_ico":0}]}
其中id是才是先前请求的最终页面，
请修改之前的脚本逻辑，给出完整代码
### Answer
This is a standalone script outside the repo, but given how the conversation has gone, I've been providing full code despite the ask-only framing, so I'll stay consistent and just answer directly.

Actually, this looks like it might be about folder-share links rather than single-file sharing, so let me check index.php for related folder listing logic, searching for "filemoreajax" or similar handling.

This folder-share case isn't handled anywhere in the original PHP, so it's a genuinely new scenario the user found that I need to add logic for in the bash script. I'm now working out how to detect this case after the initial curl request and build a fetch step for the folder listing page.

I need to detect the folder-listing page by checking for the `filemoreajax.php` ajax pattern, then extract the endpoint and POST fields — some of which (`t` and `k`) are JS variable names that need resolving from the page source just like the sign-variable logic I built earlier. Once I POST the resolved data and parse the JSON response, the returned `id` field becomes the suffix for a new share URL that I need to re-fetch with challenge handling to finally reach the direct-file page.

Given the complexity of resolving these JS variable references generically, I'm writing a shell function that extracts the ajax data block and parses each key-value pair, matching quoted literals or variable names, then looks up variable declarations elsewhere on the page to resolve their actual values.

Writing variable resolution logic...

Still writing parser...

I also realize some values are unquoted numeric literals or variable names like pgs, so I need to handle those cases too, likely treating pg/pgs as the pagination value which typically starts at 1.

Given the complexity of this JS deobfuscation, I'll accept a heuristic extraction approach with documented limitations rather than aiming for perfect fidelity, then plan the flow: detect the folder page by checking for filemoreajax.php and function file(), and if found, extract the ajax path and related parameters needed to build the request.

I'm then structuring the POST to filemoreajax.php with the extracted fields (lx, fid, uid, puid, pg, rep, t, k, up, vip, webfoldersign), using the original URL as referer and reusing the challenge cookie, then parsing the JSON response with jq to pull zt and the first entry's id from the text array -- simplifying by just taking the first file if multiple exist.

Once I have the new file id, I construct the resolved URL and loop back through the same curl-with-challenge flow, replacing soft_info and the url/ifurl variables so the rest of the existing single-file parsing logic runs unchanged on the resolved page. Writing shell error-handling logic...

I need to extract the folder's ajax URL by pulling the file parameter from the page's JS, then build a helper function to pull fields out of the data block, since those values might be literals or variable references defined elsewhere on the page.

Still writing extraction logic...

Extracting the webfoldersign field, then logging all folder parameters for debugging. I check that fid exists, erroring out if not found, then build a POST request to the folder ajax endpoint with these extracted fields as URL-encoded data.

I'm checking the folder response status, then extracting the first file's id from the folder listing to use as the real single-file share identifier, erroring out if either step fails.

Now I'm rebuilding the single-file share URL from that id, re-running the challenge request against it, and checking the resulting page for "cancelled" or "doesn't exist" messages before continuing with the rest of the flow unchanged.

Since the user asked for the complete code, I'm now assembling everything into one final script—combining the debug infrastructure, argument parsing, challenge-aware curl helpers, the jq-based URL suffix replacement, the new folder detection logic, and the password/non-password branches—into a single cohesive answer.

Since none of this exists in the repo (`hanximeng/LanzouAPI` only contains the PHP implementation — there's no folder-share handling for `filemoreajax.php` in `index.php` at all, as confirmed by the search above), this is a new scenario you've discovered that the original PHP never covered either. Below is the full standalone script with the folder-listing detection/resolution step added, plus all previous fixes (case-insensitive `arg1` matching, `|| true` guards under `set -e`/`pipefail`, `jq`-based `replace_url_suffix`, debug tracing).

```bash
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
    local ip2=$(( (RANDOM % 1950) + 60 ))
    local ip3=$(( (RANDOM % 1950) + 60 ))
    local ip4=$(( (RANDOM % 1950) + 60 ))
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
        xorVal=$(( 16#$strHex ^ 16#$maskHex ))
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
    local url="$1" referer="$2" cookie="$3"; shift 3
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
    decoded="$(sed -E 's/\.[A-Za-z0-9]+$//' <<< "$decoded")"
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
    if [ -n "$val" ]; then echo "$val"; return; fi
    # 字面量数字: 'key':123
    val=$(echo "$page" | grep -oP "['\"]${key}['\"]\s*:\s*\K[0-9]+" | head -1 || true)
    if [ -n "$val" ]; then echo "$val"; return; fi
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

soft_filesize=$(echo "$soft_info" | grep -oP '<div class="n_filesize".*?>大小：\K[^<]*' | head -1 || true)
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
```

Key addition explained:

- **Detection**: checks whether `soft_info` contains both `filemoreajax.php` and `function file()` — the signature of the folder-listing page you pasted, which never appears in `index.php`'s own parsing logic (confirmed by the grep search above — the PHP only handles single-file iframe/sign flows at LanzouAPI:150-200 ).
- **Field extraction**: `extract_ajax_field()` generalizes the earlier "literal-or-variable" resolution pattern already used for the `sign` field in the password branch, now applied to all of `lx/fid/uid/puid/pg/rep/t/k/up/vip/webfoldersign` since some (like `t`, `k` in your example) are obfuscated variable names (`ib2l5d`, `_h0x76`) rather than literals.
- **POST + id extraction**: posts to the resolved `filemoreajax.php?file=...` endpoint, checks `zt==1`, and takes `.text[0].id` — in your example response, `"id":"iktUy4d2x22h"` — as the real single-file share suffix.
- **Re-entry**: rebuilds `url` as `origin/real_id`, clears `webpage` (since the original query-string context no longer applies), and re-runs `mlooc_curl_get_with_challenge`, after which the script falls through to the existing single-file parsing logic unchanged.

Caveats, since this part is pure reverse-engineering of an undocumented edge case:
- If the folder contains multiple files, this only picks `text[0]`; you'd need to extend it to loop/filter by `name_all` if you want all files or a specific one.
- `extract_ajax_field`'s variable resolution is a simple regex lookup (`var NAME = 'VALUE'`) and won't handle values computed through more complex deobfuscated JS expressions — if Lanzou changes how `t`/`k` are generated (e.g. computed at runtime rather than a plain `var` literal), this will break and need updating, just like the original PHP's own comment about "现在好像又不验证了" acknowledges this site behavior is a moving target.
### Citations
**File:** index.php (L150-200)
```php
} else {
	//不带密码的链接处理
	preg_match("~\n<iframe.*?name=\"[\s\S]*?\"\ssrc=\"\/(.*?)\"~", $softInfo, $link);
	//蓝奏云新版页面正则规则
	if(empty($link[1])) {
		preg_match("~<iframe.*?name=\"[\s\S]*?\"\ssrc=\"\/(.*?)\"~", $softInfo, $link);
	}
	$ifurl = $origin . "/" . (isset($link[1]) ? $link[1] : '');
	//带 query 的链接（旧版直链页）：页面里已直接给出 sign/ajaxdata，无需再请求 iframe
	preg_match_all("~'sign':'(.*?)'~", $softInfo, $segment);
	if(!empty($webpage) && !empty($segment[1][1])){
	    preg_match_all("~ajaxdata = '(.*?)'~", $softInfo, $signs);
	    preg_match_all("~(?:https?://[^/\s]+/)?(ajax(?:m|file)\.php\?file=\d+)~", $softInfo, $ajaxm);
	    $post_data = array(
		    "action" => "downprocess",
		    "websignkey" => "Em2R",
		    "sign" => $segment[1][1],
		    "websign" => 2,
		    "kd" => 1,
		    "ves" => 1
	    );
	}else{
	    if(empty($link[1])) {
		    JsonError('未找到下载入口，请检查链接是否有效');
	    }
	    $softInfo = MloocCurlGetWithChallenge($ifurl, $UserAgent, $cookie, $url);
	    preg_match_all("~wp_sign = '(.*?)'~", $softInfo, $segment);
	    preg_match_all("~ajaxdata = '(.*?)'~", $softInfo, $signs);
	    preg_match_all("~(?:https?://[^/\s]+/)?(ajax(?:m|file)\.php\?file=\d+)~", $softInfo, $ajaxm);
	    $softSign = isset($segment[1][0]) ? $segment[1][0] : '';
	    $softWebsign = isset($signs[1][0]) ? $signs[1][0] : '';
	    if($softSign === '') {
		    JsonError('未找到下载接口参数，请检查链接是否有效');
	    }
	    $post_data = array(
		    "action" => "downprocess",
		    "websignkey" => $softWebsign,
		    "signs" => $softWebsign,
		    "sign" => $softSign,
		    "websign" => '',
		    "kd" => 1,
		    "ves" => 1
	    );
	}
	//下载接口可能是绝对地址（apifile.lanzouw.com），也可能是相对地址，统一补全为绝对地址
	$ajaxmPath = $ajaxm[0][0] ?? '';
	if ($ajaxmPath !== '' && strpos($ajaxmPath, 'http') !== 0) {
		$ajaxmPath = $origin . '/' . ltrim($ajaxmPath, '/');
	}
	$softInfo = MloocCurlPost($post_data, $ajaxmPath, $ifurl, $UserAgent, "acw_sc__v2=".$cookie);
}
```
