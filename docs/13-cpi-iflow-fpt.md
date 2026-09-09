# 13 — Đưa luồng qua CPI: SAP → Integration Suite → FPT eInvoice

Package CPI: `MAG_Global_EInvoicing`. iFlow dựng ở đây làm **proxy mỏng**: ABAP
đã dựng đúng payload FPT rồi (`ZCL_HDDT_PROV_FPT`), nên iFlow không mapping,
chỉ chuyển tiếp và thêm log, chứng chỉ, IP egress cố định, retry.

Bật hay tắt CPI là việc **cấu hình, không sửa code**: chỉ đổi `ZTB_HDDT_CONN`
và `ZTB_HDDT_ACT`.

## 1. Cách ABAP gọi CPI

`ZCL_HDDT_HTTP` dựng URL theo hai đường:

| Cách khai `ZTB_HDDT_CONN` | URL cuối |
|---|---|
| `RFCDEST` (khuyến nghị) | destination cấp host + xác thực, path lấy từ `ZTB_HDDT_ACT-API_PATH` đặt vào pseudo-header `~request_uri` |
| `BASE_URL` | `BASE_URL` + `API_PATH` |

**Mã nghiệp vụ phải đi bằng query parameter, không đi bằng sub-path.** Sender
HTTPS của CPI có tenant không nhận sub-path: gọi `/<urlPath>/create-invoice` ra
404 và `CamelHttpPath` luôn rỗng. Vì vậy `API_PATH` khai dạng:

```
/http/hddt_fpt?api=create-invoice
/http/hddt_fpt?api=issue-invoice
/http/hddt_fpt?api=del-invoice
/http/hddt_fpt?api=adjust-invoice
/http/hddt_fpt?api=replace-invoice
/http/hddt_fpt?api=apprs
/http/hddt_fpt?api=search-invoice
```

Nếu tenant của bạn nhận sub-path thì dùng `/http/hddt_fpt/create-invoice` cũng
được, nhưng phải thử trước một lần.

## 2. Dựng iFlow — 7 step

Thứ tự step trên canvas:

```
Sender (HTTPS /hddt_fpt)
   |
   v
[Integration Process]
   Start                     nhận request từ ABAP
     |
   GV_Route (Groovy)         đọc ?api rồi đặt CamelHttpUri
     |
   Router 1 (Non-XML)  --- Route 2 (api sai) ---> End Message (HTTP 400)
     |  Route 1
   Request Reply  <---->  Receiver: FPT eInvoice (REST API)
     |
   GV_Response (Groovy)      giữ nguyên JSON của FPT
     |
   End                       trả response về ABAP

[Exception Subprocess]  Error Start -> GV_Error -> End Message (HTTP 502)
```

Design → Integrations and APIs → `MAG_Global_EInvoicing` → Edit → Add →
Integration Flow, tên `HDDT_FPT_Proxy`.

### Step 1 — Sender

```
Participant Sender (không dấu cách trong tên) → nối message flow vào Start
Adapter: HTTPS
  Address        : /hddt_fpt          ← path endpoint CPI, KHÔNG phải URL của FPT
  Authorization  : User Role
  User Role      : ESBMessaging.send
  CSRF Protected : bỏ tick
```

Start event còn hiện tam giác cam là do thiếu Address hoặc chưa nối message flow.

### Step 2 — Groovy `GV_Route`

Đọc `api` từ query, kiểm tra nằm trong danh sách cho phép, rồi dựng URL đích.
Dùng `CamelHttpUri` vì ô Address của receiver không nhận `${property}`.

```groovy
import com.sap.gateway.ip.core.customdev.util.Message

def Message processData(Message message) {
    def query = message.getHeaders().get('CamelHttpQuery') ?: ''
    def api = ''
    query.split('&').each { p ->
        def kv = p.split('=')
        if (kv.length == 2 && kv[0] == 'api') { api = kv[1] }
    }

    def allowed = ['create-invoice', 'issue-invoice', 'del-invoice',
                   'adjust-invoice', 'replace-invoice', 'apprs',
                   'search-invoice', 'create-appr-inv']
    if (!allowed.contains(api)) {
        message.setHeader('CamelHttpResponseCode', 400)
        message.setBody('{"error":"api khong hop le: ' + api + '"}')
        message.setProperty('p_stop', 'X')
        return message
    }

    def base = message.getProperty('p_fpt_base')      // {{FPT_BaseURL}}
    message.setHeader('CamelHttpUri', base + '/' + api)
    message.setProperty('p_api', api)
    return message
}
```

Không dùng ký tự escape trong `.groovy`: mất một dấu gạch chéo khi copy là cả
script không compile. Tránh regex, dùng `split`, `indexOf`, `substring`.

`p_fpt_base` lấy từ Content Modifier đứng trước, gán từ externalized param
`{{FPT_BaseURL}}` (giá trị UAT `https://api-uat.einvoice.fpt.com.vn`).

### Step 3 — Router `RT_Stop`

Hai nhánh, Expression Type **Non-XML** cho mọi nhánh dùng `${property}`:

```
Nhánh 1 (Default) : đi tiếp Request Reply
Nhánh 2           : ${property.p_stop} = 'X'  → End Message (trả lỗi 400)
```

Để Expression Type là XML sẽ ra `XPathException: expected "<name>", found "{"`
vì body là JSON.

### Step 4 — Request Reply → Receiver `FPT_eInvoice`

```
Adapter: HTTP
  Address                    : {{FPT_BaseURL}}     ← bị CamelHttpUri ghi đè
  Method                     : POST
  Content-Type               : application/json
  Request Headers            : Content-Type,Authorization
  Authentication             : None       ← FPT nhận tài khoản trong thân payload
  Timeout                    : 90000
  Throw Exception on Failure : BỎ TICK
```

Bật `Throw Exception on Failure` thì lỗi từ FPT thành exception, client nhận
`500 ... The MPL ID for the failed message is ...` và mất nội dung lỗi thật.

`Authentication = Basic` sẽ ghi đè header `Authorization`; để `None` khi hệ đích
tự lo xác thực.

### Step 5 — Groovy `GV_Response`

Chuyển nguyên văn response về ABAP, giữ mã HTTP của FPT:

```groovy
import com.sap.gateway.ip.core.customdev.util.Message

def Message processData(Message message) {
    def code = message.getHeaders().get('CamelHttpResponseCode')
    if (code == null) { code = 200 }
    message.setHeader('CamelHttpResponseCode', code)
    message.setHeader('Content-Type', 'application/json')
    return message
}
```

Engine HĐĐT tự bóc response bằng `ZCL_HDDT_PROV_FPT~parse_response`, nên iFlow
tuyệt đối **không đổi cấu trúc JSON**.

### Step 6 — Exception Subprocess

```
Error Start → Groovy GV_Error (ghi log + set CamelHttpResponseCode = 502
              + body {"error":"..."} ) → End Message
```

### Step 7 — Runtime Configuration

```
Allowed Header(s) : Content-Type,Accept,Authorization
```

Thiếu dòng này thì header không tới được receiver.

Save → Deploy. Trạng thái thật xem ở **Monitor → Manage Integration Content**,
không tin tab Deployment Status của bản draft đang mở.

## 3. Cấu hình phía SAP

```
1. STRUST → SSL client (Anonymous) → import chứng chỉ của host CPI + chain CA
   → Save → SMICM restart ICM (Exit Soft, Global)

2. SM59 → Connection type G → ZHDDT_CPI
     Target host : mag-sub-dev-....hana.ondemand.com
     Service No. : 443
     Path prefix : để trống
     Logon & Security: SSL Active, SSL Certificate = DFAULT
                       Basic Authentication, user = clientid, password = clientsecret
                       (service key của instance Process Integration Runtime)

3. ZFI002 → ZTB_HDDT_CONN → thêm dòng
     PROVIDER FPT · CONNID CPI · RFCDEST ZHDDT_CPI · AUTH_MODE N
     TOKEN_TTL 3000 · TIMEOUT 60 · XACTIVE X

4. ZFI002 → ZTB_HDDT_CRED → đổi CONNID của công ty sang CPI

5. ZFI002 → ZTB_HDDT_ACT → đổi API_PATH của provider FPT sang dạng
     /http/hddt_fpt?api=<mã nghiệp vụ>
```

`AUTH_MODE = N` vì destination đã lo xác thực với CPI. Không lưu clientsecret
trong bảng nào của package.

Muốn quay lại gọi FPT trực tiếp: đổi `CONNID` trong `ZTB_HDDT_CRED` về `UAT` và
trả `API_PATH` về `/create-invoice`, `/issue-invoice`... Giữ hai bộ giá trị
trong file để đổi qua lại nhanh.

## 4. Kiểm tra

1. Postman: `POST https://<cpi-host>/http/hddt_fpt?api=create-invoice`, Basic
   Auth bằng clientid/clientsecret, body là payload FPT thật. Phải nhận đúng
   response của FPT.
2. `ZFI001` → chọn chứng từ → tick Test run → nút `Xem payload` để soát nội dung.
3. Bỏ tick Test run → `Tích hợp HĐ`. Xem `ZTB_HDDT_LOG` qua nút `Log`: `FULL_URL`
   phải trỏ CPI, `HTTP_CODE` và `RES_BODY` là của FPT.
4. Lỗi thì bật Trace: Manage Integration Content → iFlow → Log Configuration →
   Trace → gửi lại → Monitor Message Processing → message → Logs → Trace, xem
   Payload từng step. Trace tự hết sau 10 đến 15 phút.

## 5. Bẫy đã biết

| Triệu chứng | Nguyên nhân | Xử lý |
|---|---|---|
| Gọi sub-path ra 404, `CamelHttpPath` rỗng | Sender HTTPS không nhận sub-path | truyền mã nghiệp vụ bằng query `?api=` |
| Client nhận `500 ... MPL ID for the failed message` | Request Reply bật Throw Exception on Failure | bỏ tick, trả lỗi qua Router hoặc Groovy |
| `XPathException: expected "<name>", found "{"` | Router để Expression Type XML | đổi Non-XML |
| Receiver báo "You cannot configure dynamic parameters" | dùng `${property}` trong ô Address | dùng externalized `{{...}}` hoặc header `CamelHttpUri` |
| FPT trả 401 dù Groovy đã set header | ô `Request Headers` của adapter thiếu `Authorization` | điền `Content-Type,Authorization` |
| Groovy báo `unexpected char: \` | mất dấu gạch chéo khi copy | bỏ escape, dùng `split` / `indexOf` |
| Deploy xong endpoint vẫn vào iFlow cũ | hai iFlow trùng `urlPath` | đổi Address của một bản trước khi deploy |
| `401 invalid_client` khi lấy token | lỗi client authentication, không phải grant hay scope | Basic Auth đúng cặp clientid/secret, body `x-www-form-urlencoded`, secret có `$` phải nháy đơn |
| `consumed the assigned subaccount quota for integration flows` | hết quota iFlow | undeploy iFlow khác hoặc xin tăng quota |

## 6. Chi phí và giới hạn

Ngưỡng tính phí một message là 250 KB. Payload hoá đơn nhiều dòng hàng nên đo
thử trước: hoá đơn 200 dòng khoảng vài chục KB, còn xa ngưỡng. File PDF trả về
từ `search-invoice` là base64 nên phình 4/3, file gốc chỉ được tới khoảng 187 KB
trước khi vượt ngưỡng.

[Unverified] Hướng dẫn dựa trên kinh nghiệm dự án SInvoice và cấu trúc code
trong repo, chưa dựng thật iFlow này trên tenant MAG. Ba chỗ cần thử đầu tiên:
sender có nhận sub-path hay không, tenant có lọc header hay không, và tên
externalized param sau khi Configure.
