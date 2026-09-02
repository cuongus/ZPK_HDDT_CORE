# Code_Review.md — ZPK_HDDT_CORE

Tài liệu **sống** ghi lại logic xử lý, quyết định thiết kế, và kết quả các lượt
review. Mục đích: bất kỳ ai (người hay AI) tiếp tục build lại gói này đều đọc
đúng một chỗ để biết *vì sao code như vậy* và *cái gì không được phá*.

Quy ước cập nhật: mỗi lượt review thêm một mục ở §14 và cập nhật §11–§13. Không
xoá lịch sử.

Trạng thái tại lượt review 3 (28/08/2026): commit gốc `5fd020f` + các sửa trong
lượt này. **Chưa activate trên hệ SAP nào. Không ghi code lên hệ SAP nào — chỉ
push GitHub `cuongus/ZPK_HDDT_CORE`.**

---

## 1. Bối cảnh và các quyết định gốc (decision log)

| # | Quyết định | Lý do | Hệ quả phải giữ |
|---|---|---|---|
| D1 | Đổi nhà cung cấp = **chỉ cấu hình** | Yêu cầu gốc. Code cũ (`ZPK_HDDT` ở EEMC/VJC) phải fork function group cho từng NCC | Engine + UI **không được chứa** chuỗi `VIETTEL`/`FPT`/`VNPT`. Adapter chọn bằng `CREATE OBJECT ... TYPE (classname)` đọc từ `ZFIT_HDDT_PROV` |
| D2 | Một **canonical model** duy nhất `ZFIIF_HDDT_TYPES=>ty_invoice` | SAP điền 1 cấu trúc; adapter đổi sang payload NCC | Không thêm field mang tên thẻ của một NCC cụ thể vào canonical; dùng `ext` (name/value) cho thẻ riêng |
| D3 | Tự viết JSON writer/parser (`ZFIC_HDDT_JSON`) | NCC kỹ tính chữ hoa/thường (`invoiceIssuedDate`), số phải `10450` không phải `0000010450.000000`, thẻ rỗng phải **bỏ**. Code cũ dùng `ZTB_JSON_REPLACE` + `REPLACE ALL` — dễ vỡ | Không quay lại serialize theo tên field ABAP |
| D4 | Hệ đích = **cả hai**: Private Cloud (SAP GUI) **và** CASLA Public Cloud (RAP/Fiori) | Người dùng chốt sau khi phát hiện `ZPK_HDDT_CORE` đã tồn tại trên CASLA dưới dạng ABAP Cloud | Tầng adapter + JSON + interface phải viết theo tập lệnh ABAP Cloud; tách API khác biệt qua `ZFIIF_HDDT_PLATFORM` |
| D5 | Log payload dạng **XSTRING** | Yêu cầu người dùng. Lý do kỹ thuật đúng: toàn vẹn từng byte trên đường truyền (bằng chứng thuế). *Không phải* vì giới hạn độ dài — STRING trong DDIC là LOB, không giới hạn | Luôn ghi kèm `CODEPAGE`; giải mã lại bằng platform |
| D6 | **Che secret trước khi ghi log** | Payload FPT có `"password"` trong body, VNPT có `"acpass"` → ghi nguyên văn = lộ mật khẩu API | `MASK_SECRETS` là bước bắt buộc trong `LOG_CALL`; danh sách thẻ trong `LOG_MASK_TAGS` |
| D7 | Test run **không đọc mật khẩu thật** | Payload test run hiện trên màn hình | `ZFIC_HDDT_SERVICE` gán `ls_cred-apisecret = '********'` khi `iv_test_run` |
| D8 | `EXECUTE` **không raise** ra ngoài | Job xử lý hàng loạt không được chết vì 1 chứng từ | Mọi lỗi vào `ty_result-message/status`; bắt cả `cx_root` |
| D9 | Cấu hình dùng **fallback 4 cấp** cho tham số | Đặt chung rồi ghi đè cho 1 công ty / 1 NCC | `(prov,bukrs) → (prov,'') → ('',bukrs) → ('','')` — không đổi thứ tự |
| D10 | Ánh xạ giá trị **fail-safe**: không có cấu hình → trả nguyên giá trị SAP | Không chặn nghiệp vụ; sai lệch lộ trong log/response | `MAP_VALUE` không raise |
| D11 | Đặt tên theo `fis-sap-naming-convention-cuongus`: `Z FI <T> _ HDDT _ <tên>` | Skill quy định | `ZFIC_` class, `ZFIIF_` interface, `ZFICX_` exception, `ZFIT_` bảng, `ZFIDE_`/`ZFIDO_` DE/domain, `ZFIR_` report, `ZFI_` tcode |

**Bối cảnh đã kiểm chứng (không suy đoán):**
- Code cũ EEMC (Viettel) và VJC (FPT): cùng tên `ZFM_CREATE_E_INVOICES`, khác nội dung hoàn toàn; destination hardcode `'EINVOICES'` / `'EINVOICES_FPT'`.
- `ZPK_HDDT_CORE` trên CASLA (AK3): RAP BO `ZJP_C_HDDT_H`, 9 BO cấu hình, `ZCL_MANAGE_VIETTEL_EINVOICES`, communication scenario `Z_API_VIETTEL_EINVOICE_CSCEN`, **0 interface** → không có tầng trừu tượng NCC.
- API cloud CASLA đang dùng thật (6.018 dòng): `cl_http_destination_provider=>create_by_comm_arrangement`, `cl_web_http_client_manager=>create_by_http_destination`, `/ui2/cl_json`, `cl_abap_context_info=>get_user_time_zone`, và **vẫn dùng** `sy-datum`/`sy-uname`.

---

## 2. Bất biến kiến trúc (không được phá)

```
SAP GUI / Job / Enhancement
        │
        ▼
ZFIC_HDDT_SERVICE  ── cửa vào duy nhất, không raise
        │
        ├── ZFIC_HDDT_CONFIG   (buffer toàn bộ ZFIT_HDDT_*, singleton)
        ├── ZFIC_HDDT_FACTORY  (CREATE OBJECT TYPE (classname), cache, kiểm GET_ID)
        ├── ZFIC_HDDT_HTTP     (classic) / ZFIC_HDDT_HTTP_CLOUD (chưa có)
        ├── ZFIC_HDDT_TOKEN    (cache token ZFIT_HDDT_TOK)
        ├── ZFIC_HDDT_SECRET   (vault plug-in qua ZFIIF_HDDT_SECRET)
        └── ZFIC_HDDT_LOG      (ZFIT_HDDT_LOG / _INV / _ITEM)
                │
                ▼
        ZFIIF_HDDT_PROVIDER ── hợp đồng adapter (8 method, 3 bắt buộc)
                │
   ZFIC_HDDT_PROV_BASE (abstract)
   ├── ZFIC_HDDT_PROV_VIETTEL
   ├── ZFIC_HDDT_PROV_FPT
   └── ZFIC_HDDT_PROV_TEMPLATE ── ZFIC_HDDT_PROV_VNPT
```

| Bất biến | Kiểm bằng |
|---|---|
| I1. Engine + UI không nhắc tên NCC | `grep -rniE "'(VIETTEL\|FPT\|VNPT)'" src/engine src/ui` → 0 kết quả |
| I2. Tầng dùng chung (`src/prov`, `zfic_hddt_json`, 5 interface) không dùng API classic-only | grep bảng §10 → 0 kết quả |
| I3. Mọi SELECT bảng cấu hình chỉ nằm trong `ZFIC_HDDT_CONFIG` | adapter/engine gọi `get_*`/`map_*`, không SELECT `ZFIT_HDDT_*` cấu hình |
| I4. Adapter `GET_ID( )` = `ZFIT_HDDT_PROV-PROVIDER` | factory kiểm tra, raise nếu lệch |
| I5. Mật khẩu không bao giờ đi vào `ZFIT_HDDT_LOG` | `MASK_SECRETS` chạy trước `to_raw` trong `LOG_CALL` |
| I6. Số trong JSON: `.` thập phân, `-` phía trước, không zero dẫn đầu | `FORMAT_NUMBER` dùng `NUMBER = RAW` |
| I7. `IDKEY` ổn định giữa các lần thử lại | `fill_defaults`: `bukrs+gjahr+src_docno` nếu caller không truyền |

---

## 3. Logic pipeline `ZFIC_HDDT_SERVICE=>EXECUTE`

File: `src/engine/zfic_hddt_service.clas.abap`

```
1  provider    ← is_request-provider; rỗng → CONFIG.get_active_provider(bukrs)
2  adapter     ← FACTORY.get_provider(provider, bukrs)
3  action      ← adapter.resolve_action(request) (mặc định = request-action)
   endpoint    ← CONFIG.get_action(provider, action)         [ZFIT_HDDT_ACT]
   credential  ← CONFIG.get_credential(provider,bukrs,inv_type,inv_date) [ZFIT_HDDT_CRED]
   connection  ← CONFIG.get_connection(provider, cred-connid) [ZFIT_HDDT_CONN]
4  fill_defaults: idkey, inv_type/template/serial/taxcode từ CRED,
   seller từ PARM SELLER_*, inv_date theo ZFIT_HDDT_DATE, inv_time=sy-uzeit,
   currency (LOCAL_CURRENCY|VND), exch_rate=1 nếu rỗng,
   buyer-not_get_invoice nếu không có địa chỉ & tên,
   aggregate_invoice (taxes theo thuế suất + summary, quy đổi VND)
5  secret: test_run → '********' ; ngược lại SECRET.get_secret(cred) → cred-apisecret
   payload     ← adapter.build_payload(request, action, cred)
   attempt     ← LOG.count_attempts (bỏ qua test_run)
   ── test_run: result.success=X, log nếu LOG_TEST_RUN, RETURN ──
6  token (AUTH_MODE T/O) ← TOKEN.get_token (cache ZFIT_HDDT_TOK, TTL)
   http        ← HTTP.send(conn, act, symbols=adapter.get_url_symbols,
                            headers=adapter.get_headers, payload, user, secret, bearer)
   401 + bearer → TOKEN.invalidate → get_token(force) → send lại ĐÚNG 1 LẦN
7  adapter.parse_response(request, action, http_code, body) → CHANGING result
   GET_FILE & file_content rỗng & success → result.file_content = body_x
8  derive_status: CONFIG.map_status(provider, action|'*', prov_status)
   không có → suy từ http 2xx + action (create: seq có → 40, không → 20)
9  LOG.log_call(...) → result.log_id
   src_docno có → LOG.save_invoice ; success & items → LOG.save_items
   iv_commit → COMMIT WORK AND WAIT
CATCH zficx_hddt_error → result 90/E + message; vẫn log nếu đã có conn
CATCH cx_root          → result 90/E "Lỗi không xác định"
```

Điểm dễ sai khi sửa:
- Bước 5 phải **trước** bước 6: adapter FPT/VNPT cần secret trong body.
- Thứ tự CATCH: `zficx_hddt_error` trước `cx_root`.
- `execute_many` gọi `execute(... iv_commit = abap_false)` rồi COMMIT 1 lần.

`aggregate_invoice` (public static, source class dùng lại):
- Đánh `line_no` nếu rỗng; `total = amount + tax_amount` nếu rỗng.
- Bảng thuế: gộp theo `tax_rate`, bỏ dòng `item_type = '3'` (ghi chú). **Không dùng COLLECT** vì `ty_tax` có STRING.
- Summary chỉ tính khi cả `total` và `amount_wo_tax` rỗng (caller có thể truyền sẵn).

---

## 4. Hợp đồng adapter và logic từng adapter

`ZFIIF_HDDT_PROVIDER` — 8 method; `ZFIC_HDDT_PROV_BASE` cài 5, adapter con **bắt buộc** `GET_ID`, `BUILD_PAYLOAD`, `PARSE_RESPONSE` (khai `INTERFACES ... ABSTRACT METHODS`, con dùng `REDEFINITION`).

Tiện ích trong base (protected): `map_val`, `map_val_text`, `fmt_date`, `fmt_date_vn`, `fmt_datetime` (`YYYY-MM-DD hh:mm:ss`), `to_epoch_millis` (số học ngày/giờ, TZ từ `TIME_ZONE` hoặc platform), `num`, `build_form` (form-urlencoded, bỏ field rỗng, escape qua platform), `build_adjust_note`, `platform( )`.

### 4.1 Viettel — `ZFIC_HDDT_PROV_VIETTEL` (đã đối chiếu tài liệu v2.44)

| Action | Payload | Content-Type |
|---|---|---|
| CREATE / ADJUST / REPLACE / CREATE_DRAFT / PREVIEW_DRAFT / UPDATE | `build_invoice` — JSON 7 nhóm | json |
| CANCEL / DELETE | `build_cancel` — **form-urlencoded**, `strIssueDate`/`additionalReferenceDate` = **epoch millis** | form |
| SEARCH | `build_search` — form, 2 tham số | form |
| GET_FILE | `build_get_file` — json, `fileType` ZIP/PDF | json |

Quy tắc trong `build_invoice`:
- `adjustmentType`: 1 gốc · 3 thay thế · 5 điều chỉnh · 7 xoá bỏ (`get_adjustment_type`).
- `adjustmentInvoiceType` (1 tiền / 2 thông tin) và mọi `is…Pos`, `isIncreaseItem` **chỉ khi adjustmentType = 5**.
- `adjustedNote` (lý do sai sót) chỉ khi không phải gốc.
- `originalInvoiceId` = serial+seq gốc; chỉ gửi khi có.
- **`selection`** mỗi dòng (`get_selection`): canonical `item_type` `0→1`, `1→5`, `2→3`, `3→2`; ghi đè qua `ZFIT_HDDT_MAP` ITEMTYPE (provider VIETTEL). Dòng `selection=3` **luôn** `isIncreaseItem=false`.
- `exchangeRate = 1` khi VND.
- `payments[]` gửi `paymentMethod` + `paymentMethodName`.

`parse_response`: `errorCode` null = OK; `invoiceNo` = ký hiệu+số → tách bằng **tiền tố ký hiệu đã biết**, fallback chữ số cuối; `codeOfTax`→`mscqt` (fallback `reservationCode`); `fileToBytes` base64 → `file_content`. Response không JSON → xử lý riêng, không vỡ.

### 4.2 FPT — `ZFIC_HDDT_PROV_FPT` (đã đối chiếu tài liệu v2.4.7)

- Tài khoản nằm trong **body** nút `user` (bỏ khi `FPT_USER_IN_BODY = N`).
- `inv`: `sid`(=idkey) `idt`(`YYYY-MM-DD hh:mm:ss`) `type` `form` `serial` `seq` `aun`(PARM `FPT_AUN`) `type_ref=1` `sendtype` … `sum/sumv vat/vatv total/totalv`, `items[]` (`vrt` = thuế suất nguyên hoặc -1/-2, ghi đè TAXRATE), `tax[]`, `adj{seq rdt ref rea}` + `ud` + `adj_only_add=1` khi ĐC/thay thế.
- `SEARCH_INVOICE` là **GET, tham số trong HTTP header** (`get_headers`), body rỗng.
- `CANCEL_INVOICE` TT78: nút `wrongnotice{stax noti_taxtype noti_taxnum noti_taxdt budget_relationid place items[{form serial seq idt type_ref noti_type=1 rea}]}`; `place` từ PARM `FPT_PLACE`.
- `DELETE_INVOICE`: `{user, sid, stax}`; response **text thuần**.
- `parse_response`: `status` 1/2/3/4 → 20/30/40/80; `status_received=10` → 50 + `ic`→mscqt; `sec`→sec_code; `link`→inv_link; `adt|idt`→issue_date.
- `build_login_payload` (`c_signin`) → body JWT thuần; base `extract_token` xử lý.

### 4.3 Template — `ZFIC_HDDT_PROV_TEMPLATE`

Mẫu trong `ZFIT_HDDT_TPL(provider, action)`. Cú pháp `{{group.field}}`, `{{fn.*}}`, vòng lặp `{{#items}}…{{/items}}`, `{{#taxes}}…{{/taxes}}`, escape `{{$json.x}}` / `{{$xml.x}}`. `value_of` dùng RTTI: số → `format_number`, DATS → ISO, TIMS → `hh:mm:ss`, CHAR → CONDENSE. Placeholder lạ → rỗng. **Bẫy đã sửa:** `sy-index` trong `WHILE` lồng `DO` — phải chép ra `lv_kind`.

### 4.4 VNPT — `ZFIC_HDDT_PROV_VNPT`

Kế thừa Template. Không có tài liệu API → **không hardcode payload**. `parse_response`: JSON/XML → lớp cha; text `OK:<mẫu>;<ký hiệu>-<số>` / `ERR:<n>` → `PROV_STATUS = ERR<n>` để map qua `ZFIT_HDDT_STAT`. **[Unverified]** quy ước text này.

---

## 5. Logic cấu hình — `ZFIC_HDDT_CONFIG`

- Singleton, `load_buffer` đọc **toàn bộ** 9 bảng cấu hình 1 lần (SORTED TABLE). `invalidate( )` sau khi bảo trì (`ZFIR_HDDT_CONFIG` gọi `ZFIC_HDDT_FACTORY=>reset`).
- `get_active_provider(bukrs)`: (1) PARM `ACTIVE_PROVIDER`; (2) duy nhất 1 provider active trong CRED của bukrs; >1 → lỗi yêu cầu khai PARM.
- `get_credential`: chỉ dòng active + trong hiệu lực (`VALID_FROM/TO`); **khớp `INV_TYPE` chính xác thắng**, dòng `INV_TYPE=''` là dự phòng. Duyệt bằng field-symbol (bug cũ: loop INTO rs_cred bị ghi đè bởi dòng bị skip — đã sửa).
- `get_connection`: connid → PARM `DEFAULT_CONNID` → dòng active đầu tiên; phải có `RFCDEST` **hoặc** `BASE_URL`; `TIMEOUT` mặc định 60.
- `get_action`: mặc định method POST, `application/json`, accept `*/*`.
- `map_status`: `(prov,action,rc)` rồi `(prov,'*',rc)`.
- `map_value`: không có → trả nguyên giá trị (D10).
- `get_param`: 4 cấp (D9). `get_param_bool`: X/TRUE/Y/1.
- `resolve_invoice_date`: `ZFIT_HDDT_DATE-DATE_SRC` 1 BUDAT · 2 CPUDT · 3 SY-DATUM · 4 BLDAT; mặc định SY-DATUM.

---

## 6. Logic JSON — `ZFIC_HDDT_JSON`

- **Writer** fluent: stack `mt_has_item` quyết định dấu phẩy; `add_string` bỏ giá trị rỗng trừ `iv_force`; `add_number` luôn ghi (kể cả 0) trừ `iv_force=false`; `add_bool` → `true/false`; `add_bool_text` → `"true"/"false"` (Viettel yêu cầu text).
- **`format_number`**: `round( dec )` rồi `|{ p NUMBER = RAW }|` → cắt zero cuối. Không dùng `WRITE ... TO` (cloud + không phụ thuộc user setting).
- **Parser** đệ quy tay → bảng phẳng `path → value`: `a/b`, `arr[0]/x`, `arr#count`. `get_value_by_name` tìm theo thẻ lá ở mọi độ sâu (chịu được đổi độ lồng giữa version API). Escape `\uXXXX` giải mã qua platform.
- **`pretty`**: duyệt ký tự, theo dõi trong-chuỗi + escape → dấu cấu trúc trong tên hàng hoá không làm vỡ.
- Ký tự điều khiển (`gv_cr/gv_lf/gv_tab`) lấy từ platform trong `class_constructor`.

---

## 7. Logic HTTP (classic) — `ZFIC_HDDT_HTTP`

- `resolve_path`: thay `{name}` từ symbols; placeholder sót → xoá (regex).
- `create_client`: `RFCDEST` → `create_by_destination` + `~request_uri` = path; ngược lại `create_by_url(base + path, ssl_id)`. Tắt popup logon, bật redirect.
- `apply_auth` theo `AUTH_MODE` (override bởi `ty_call-auth_mode`, dùng cho LOGIN): `B` basic · `H` header `username/password` **và** basic · `T/O` `Authorization: Bearer` · `N` không.
- Body chỉ set khi method ≠ GET/DELETE.
- Trả `req_header`/`res_header` (chưa che — LOG che), `body`, `body_x`, `duration_ms` (GET RUN TIME).
- Lỗi send/receive → `zficx_hddt_error` với `mv_http_code = 999`.

`ZFIC_HDDT_TOKEN`: cache theo `(provider, connid, bukrs, apiuser)`; TTL từ `TOKEN_TTL` (mặc định 3000s); login qua action `TOKEN_ACTION|LOGIN` với `auth_mode = B` ép; `extract_token` của adapter.

---

## 8. Logic log — `ZFIC_HDDT_LOG` + `ZFIR_HDDT_LOG`

- `log_call(request, action, provider, ty_call_info, result)`:
  1. GUID32; điền định danh, kết quả, kỹ thuật HTTP, `attempt`, `test_run`, `caller=sy-cprog`, `tcode`.
  2. `keep_payload`: mặc định **lưu**; chỉ tắt khi `LOG_PAYLOAD` khai tường minh giá trị false.
  3. **`mask_secrets`** cả 4 nội dung (req/res body + header) → `to_raw` (UTF-8 qua platform) → `REQ_SIZE/RES_SIZE = xstrlen`; `MASKED = X` nếu nội dung đổi.
  4. INSERT thất bại → không raise, chỉ trả log_id rỗng.
- `mask_secrets` (public static): thẻ từ `LOG_MASK_TAGS` hoặc mặc định; 4 regex (JSON có/không ngoặc kép, form, header), `IGNORING CASE`. Regex viết trong string template nên `\\s`, `\{`, `\|` là escape của **template**, ra runtime là `\s`, `{`, `|`.
- `read_payload(log_id)`: giải mã theo `CODEPAGE` của dòng.
- `count_attempts`: COUNT theo (bukrs, gjahr, src_type, src_docno, action) bỏ `test_run`.
- `save_invoice`: upsert `ZFIT_HDDT_INV`; **chỉ ghi đè** template/serial/seq/issue_date/mscqt/sec/link khi result có giá trị (lần lỗi không xoá số đã cấp).
- Màn hình `ZFIR_HDDT_LOG`: danh sách **không đọc** body; range ngày → timestamp; điều kiện tuỳ chọn qua RANGE (không dùng `OR @p IS INITIAL`); nút xem request/response/header (pretty nếu JSON), tải nguyên bản byte.

---

## 9. Logic đọc nguồn FI — `ZFIC_HDDT_SRC_FI`

- BKPF theo bukrs/gjahr/belnr/budat/blart, `xreversal = space`; BSEG + BSET theo range belnr; lọc `r_status` bằng `ZFIT_HDDT_INV`.
- Buyer: dòng `KOART='D'` → KNA1 (+ADRC, ADR6 email đầu tiên theo consnumber).
- Payment: `ZLSCH` → MAP PAYMENT (**provider = space** ở tầng nguồn).
- Items: BSEG `KOART='S' AND SHKZG='H'`; tên = SGTXT | MAP GLACCT ext_text | HKONT; `amount = WRBTR` (nguyên tệ); `tax_rate` = MAP TAXRATE theo MWSKZ, fallback `BSET-KBETR/10`; `tax_amount` tính theo % rồi **chốt theo BSET** — chênh lệch dồn vào dòng có amount lớn nhất cùng thuế suất.
- Taxes lấy thẳng từ BSET (`FWBAS/FWSTE` nguyên tệ, `HWBAS/HWSTE` VND).
- Cuối cùng gọi `ZFIC_HDDT_SERVICE=>aggregate_invoice`.

---

## 10. Phân tầng nền tảng

| Tầng | Object | API classic-only còn dùng | Ghi chú |
|---|---|---|---|
| **Dùng chung** (phải cloud-safe) | 5 interface, `ZFICX_HDDT_ERROR`, `ZFIC_HDDT_JSON`, `ZFIC_HDDT_PROV_*` | **không** (đã rà lượt 3) | `sy-datum/uzeit/uname` được phép (CASLA đang dùng) |
| **Classic** | `ZFIC_HDDT_HTTP` (`cl_http_client`, `MESSAGE ID`, `cl_abap_char_utilities`), `ZFIC_HDDT_PLAT_CLASSIC`, `ZFIC_HDDT_LOG` (`cl_system_uuid`, `sy-cprog`, `sy-tcode`), `ZFIC_HDDT_TOKEN` (`cl_abap_tstmp`), `ZFIC_HDDT_SRC_FI`, toàn bộ `src/ui` | có, hợp lệ | Bản cloud tương ứng chưa có |
| **Nửa chừng** | `ZFIC_HDDT_CONFIG`, `_FACTORY`, `_SECRET`, `_PLATFORM`, `_SERVICE` | không thấy classic-only | nhưng dùng DDIC `ZFIT_HDDT_*` — trên CASLA phải đối chiếu với 9 BO cấu hình sẵn có |

Bảng API tách qua `ZFIIF_HDDT_PLATFORM`:

| Method | Classic | Cloud (theo code CASLA / tài liệu SAP) |
|---|---|---|
| newline / carriage_return / tab | `cl_abap_char_utilities` | `cl_abap_conv_codepage` từ hex **[Unverified]** |
| escape_url | `cl_http_utility=>escape_url` | `cl_web_http_utility=>escape_url` |
| xstring_to_string / string_to_xstring | `cl_abap_conv_in_ce` / `_out_ce` | `cl_abap_conv_codepage=>create_in/out` |
| decode_base64 | `cl_http_utility=>decode_x_base64` | `cl_web_http_utility=>decode_x_base64` |
| get_time_zone | `sy-zonlo` | `cl_abap_context_info=>get_user_time_zone` (đã thấy trong code CASLA) |

---

## 11. Kết quả review — đã sửa

| Lượt | Mức | Vấn đề | Sửa |
|---|---|---|---|
| 1 | Cao | `get_credential` loop `INTO rs_cred` bị ghi đè bởi dòng bị `CONTINUE` | duyệt field-symbol, chỉ gán khi hợp lệ |
| 1 | Cao | `COLLECT` trên `ty_tax` có STRING → lỗi cú pháp | gộp tay bằng READ/APPEND |
| 1 | Trung | `sy-index` trong `WHILE` lồng `DO` (template adapter) | chép `lv_kind` |
| 1 | Trung | Data element `CHAR120/CHAR250/NUMC2` không chắc tồn tại | dùng `c LENGTH n` / `n LENGTH 2` |
| 2 | **Cao** | Viettel huỷ/tra cứu gửi JSON, tài liệu yêu cầu **form-urlencoded** | `build_form`, `CONT_TYPE` trong ACT |
| 2 | **Cao** | `strIssueDate`/`additionalReferenceDate` gửi chuỗi ngày, tài liệu yêu cầu epoch millis | `to_epoch_millis` |
| 2 | **Nghiêm trọng** | Thiếu thẻ `selection` → dòng ghi chú/chiết khấu bị tính như hàng hoá → **sai tiền hoá đơn thuế** | `get_selection` + MAP ITEMTYPE |
| 2 | Trung | Tách serial/seq đoán chữ số cuối sai với ký hiệu kết thúc bằng số | bỏ tiền tố ký hiệu đã biết |
| 2 | Cao | Script vá `s.index("PARSER")` khớp comment DEFINITION → nhân đôi IMPLEMENTATION `ZFIC_HDDT_JSON` | `git checkout` + vá theo `METHOD…ENDMETHOD` + assert cấu trúc |
| 2 | Trung | `WRITE ... TO` phụ thuộc dấu thập phân user, không cloud | `NUMBER = RAW` |
| 3 | **Nghiêm trọng** | Mật khẩu FPT/VNPT trong body ghi **plaintext** vào `ZFIT_HDDT_LOG` | `mask_secrets` trước khi ghi |
| 3 | Trung | `GET_HEADER_FIELDS` gọi như functional method (là CHANGING) | sửa cách gọi |
| 3 | Trung | `COND` với `s_date[ 1 ]` trên bảng rỗng → `CX_SY_ITAB_LINE_NOT_FOUND` | READ TABLE tường minh |
| 3 | Trung | `( bukrs = @p OR @p IS INITIAL )` không hợp lệ ABAP SQL | RANGE rỗng |
| 3 | Thấp | `UP TO n ROWS` / `INTO` đứng trước `WHERE` (thứ tự cũ, bị chặn strict mode) | chuyển sau `ORDER BY` (`zfic_hddt_src_fi`, `zfir_hddt_log`) |
| 3 | Thấp | `raise_sy_message` dùng `MESSAGE ID` trong exception dùng chung, không ai gọi | xoá → shared exception cloud-clean |

## 12. Còn mở / chưa kiểm chứng

| Mức | Hạng mục | Ghi chú |
|---|---|---|
| **Chặn go-live** | Chưa activate trên hệ SAP nào | lần import đầu cần 1 lượt activate + sửa cú pháp sót |
| **Chặn go-live** | Chưa gọi thật tới NCC nào | phải Test run + đối chiếu payload |
| Cao | Chưa có ABAP Unit | ưu tiên: `FORMAT_NUMBER`, `PARSE`, `PRETTY`, `MASK_SECRETS`, `AGGREGATE_INVOICE`, `RESOLVE_PATH`, `TO_EPOCH_MILLIS` |
| Cao | Chưa có reorg `ZFIT_HDDT_LOG` (~1 GB/100k HĐ/năm) | docs/08 §8 |
| Cao | Viettel bất đồng bộ: `invoiceNo` rỗng → phải `SEARCH_INVOICE` sau 30–90s | job quét `STATUS=20` chưa có |
| Trung | Bản cloud: `ZFIC_HDDT_PLAT_CLOUD`, `ZFIC_HDDT_HTTP_CLOUD`, tách `ZCL_MANAGE_VIETTEL_EINVOICES` trên CASLA thành adapter | cần cookie `Casla_Dev` (080) để ghi |
| Trung | Đối chiếu bảng cấu hình mới với 9 BO cấu hình CASLA (`ZJP_R_HD_*`) | tránh 2 bộ cấu hình song song |
| Trung | Nguồn SD / MM / hoá đơn gom | interface `ZFIIF_HDDT_SOURCE` đã có |
| Thấp | VNPT: quy ước `OK:`/`ERR:` **[Unverified]**, chưa có tài liệu | adapter template |
| Thấp | Viettel `originalInvoiceType/originalTemplateCode` cho HĐ gốc ngoài hệ thống | truyền qua `invoice-ext` |
| Thấp | Cột `Transport` trong header vẫn `abapGit` | điền TR khi release |
| Thấp | `AUTHORITY-CHECK` riêng theo nghiệp vụ (phát hành vs huỷ) | chưa có object Z |

## 13. Checklist khi build lại / thêm tính năng

**Trước khi sửa code**
- [ ] Đọc §2 bất biến và §1 quyết định liên quan.
- [ ] Sửa DDIC → sửa `tools/gen_ddic.py` rồi `python tools/gen_ddic.py`; sửa metadata → `tools/gen_meta.py`. Không sửa XML tay.
- [ ] Vá file ABAP bằng script: **cắt theo `METHOD x.` … `ENDMETHOD.`**, không dùng mốc là comment; sau vá **assert** `CLASS … IMPLEMENTATION` = 1, `ENDCLASS` = 2.

**Khi thêm nhà cung cấp**
- [ ] Kế thừa `ZFIC_HDDT_PROV_BASE` (hoặc dùng `PROV_TEMPLATE` + `ZFIT_HDDT_TPL`); cài `GET_ID/BUILD_PAYLOAD/PARSE_RESPONSE`.
- [ ] Endpoint + Content-Type vào `ZFIT_HDDT_ACT` (kiểm tra kỹ **form-urlencoded vs JSON** — Viettel đã sập ở đây).
- [ ] Thẻ secret của NCC vào `LOG_MASK_TAGS`.
- [ ] Không dùng API classic-only trong adapter (grep §10).
- [ ] Nạp mặc định vào `ZFIR_HDDT_SETUP`; viết `docs/0x-provider-<ncc>.md` với nguồn tham chiếu và mục tài liệu.

**Khi sửa engine**
- [ ] Không SELECT bảng cấu hình ngoài `ZFIC_HDDT_CONFIG`.
- [ ] Không để `EXECUTE` raise ra ngoài.
- [ ] Không log gì trước khi qua `MASK_SECRETS`.
- [ ] ABAP SQL: `WHERE/ORDER BY` trước `INTO`/`UP TO`; điều kiện tuỳ chọn qua RANGE.

**Trước khi release**
- [ ] I1–I7 (§2) pass.
- [ ] `docs/07 §5` checklist go-live.
- [ ] Cập nhật §14 tài liệu này.

## 14. Nhật ký các lượt review

| Lượt | Ngày | Phạm vi | Kết quả |
|---|---|---|---|
| 1 | 28/08/2026 | Build ban đầu 141 file; tự soát khi viết | 4 lỗi sửa ngay (§11) |
| 2 | 28/08/2026 | Đối chiếu tài liệu Viettel v2.44 (162 trang) + FPT v2.4.7; phát hiện `ZPK_HDDT_CORE` tồn tại trên CASLA; tách tầng dùng chung | 4 lỗi Viettel + 1 sự cố script; tầng chung cloud-clean |
| 3 | 28/08/2026 | Log tích hợp xstring + che secret + màn hình log; rà lại toàn bộ cú pháp SQL strict mode, API phân tầng, method thừa | 1 lỗi bảo mật nghiêm trọng, 5 lỗi cú pháp/logic; tạo tài liệu này |
