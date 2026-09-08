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
| D1 | Đổi nhà cung cấp = **chỉ cấu hình** | Yêu cầu gốc. Code cũ (`ZPK_HDDT` ở EEMC/VJC) phải fork function group cho từng NCC | Engine + UI **không được chứa** chuỗi `VIETTEL`/`FPT`/`VNPT`. Adapter chọn bằng `CREATE OBJECT ... TYPE (classname)` đọc từ `ZTB_HDDT_PROV` |
| D2 | Một **canonical model** duy nhất `ZIF_HDDT_TYPES=>ty_invoice` | SAP điền 1 cấu trúc; adapter đổi sang payload NCC | Không thêm field mang tên thẻ của một NCC cụ thể vào canonical; dùng `ext` (name/value) cho thẻ riêng |
| D3 | Tự viết JSON writer/parser (`ZCL_HDDT_JSON`) | NCC kỹ tính chữ hoa/thường (`invoiceIssuedDate`), số phải `10450` không phải `0000010450.000000`, thẻ rỗng phải **bỏ**. Code cũ dùng `ZTB_JSON_REPLACE` + `REPLACE ALL` — dễ vỡ | Không quay lại serialize theo tên field ABAP |
| D4 | Hệ đích = **cả hai**: Private Cloud (SAP GUI) **và** CASLA Public Cloud (RAP/Fiori) | Người dùng chốt sau khi phát hiện `ZPK_HDDT_CORE` đã tồn tại trên CASLA dưới dạng ABAP Cloud | Tầng adapter + JSON + interface phải viết theo tập lệnh ABAP Cloud; tách API khác biệt qua `ZIF_HDDT_PLATFORM` |
| D5 | Log payload dạng **XSTRING** | Yêu cầu người dùng. Lý do kỹ thuật đúng: toàn vẹn từng byte trên đường truyền (bằng chứng thuế). *Không phải* vì giới hạn độ dài — STRING trong DDIC là LOB, không giới hạn | Luôn ghi kèm `CODEPAGE`; giải mã lại bằng platform |
| D6 | **Che secret trước khi ghi log** | Payload FPT có `"password"` trong body, VNPT có `"acpass"` → ghi nguyên văn = lộ mật khẩu API | `MASK_SECRETS` là bước bắt buộc trong `LOG_CALL`; danh sách thẻ trong `LOG_MASK_TAGS` |
| D7 | Test run **không đọc mật khẩu thật** | Payload test run hiện trên màn hình | `ZCL_HDDT_SERVICE` gán `ls_cred-apisecret = '********'` khi `i_test_run` |
| D8 | `EXECUTE` **không raise** ra ngoài | Job xử lý hàng loạt không được chết vì 1 chứng từ | Mọi lỗi vào `ty_result-message/status`; bắt cả `cx_root` |
| D9 | Cấu hình dùng **fallback 4 cấp** cho tham số | Đặt chung rồi ghi đè cho 1 công ty / 1 NCC | `(prov,bukrs) → (prov,'') → ('',bukrs) → ('','')` — không đổi thứ tự |
| D10 | Ánh xạ giá trị **fail-safe**: không có cấu hình → trả nguyên giá trị SAP | Không chặn nghiệp vụ; sai lệch lộ trong log/response | `MAP_VALUE` không raise |
| D11 | ~~Đặt tên theo `fis-sap-naming-convention-cuongus` (`Z FI <T> _ HDDT _`)~~ **Thay bằng D18** | | Lượt 1–4 dùng prefix `ZFIC_/ZFIIF_/ZFICX_/ZFIT_/ZFIDE_/ZFIDO_/ZFIR_/ZFIE_/ZFI_`; đã đổi tên toàn bộ ở lượt 5 |
| D18 | Đặt tên theo **chuẩn Private Cloud 03.09.2026** (`fis-sap-private-cloud-naming`, một prefix cho mỗi loại): `ZCL_HDDT_*`, `ZIF_HDDT_*`, `ZCX_HDDT_ERROR`, `ZTB_HDDT_*`, `ZDE_HDDT_*`, `ZDO_HDDT_*`, `ZPG_HDDT_*` (+`_TOP/_F01`), `ZMS_HDDT`, tcode `ZFI001–ZFI003`; `HDDT` là mã dự án | Người dùng chốt 03/09/2026 sau khi rà §15; package chưa import nên đổi tên còn rẻ | Biến: `<FS_…>`, scalar `I_/E_/C_/R_`, table/structure `IT_/IS_/RT_/RS_`; object ref `IO_/RO_` giữ nguyên **[Inference]** (chuẩn chưa định nghĩa); text người dùng thấy (DE label, domain text, selection text, T100, ALV) **có dấu**; biến nhận giá trị `cl_gui_frontend_services` là toàn cục |
| D12 | Tầng đọc nguồn **port từ dự án HĐĐT private cloud** (`ZPG_INT_E_INVOICE` trong `zhddt.docx` + FUGR `ZFG_E_INVOICES` trên EEMC), viết lại theo canonical model | Người dùng xác nhận logic FI/Billing của dự án đó là chuẩn (03/09/2026) | **Giữ logic, bỏ hằng số**: `O*`/`**`, `3331*`, `ZPR0/ZC04/ZC05/ZMST`, `ZBT`, `VATRU`, `FS0001`, `ZI03/GRUN` → MAP/PARM, seed trong SETUP ghi rõ *VÍ DỤ*. Chi tiết: docs/09 |
| D13 | Chênh lệch làm tròn thuế dồn vào **dòng cuối** cùng thuế suất | Theo dự án tham chiếu (lượt 3 dùng dòng có amount lớn nhất) | `ZCL_HDDT_SRC_BASE=>RECONCILE_TAX` |
| D14 | Kiểm tra nghiệp vụ theo trạng thái nằm trong **engine** (`CHECK_ACTION`, bước 4b), không ở UI | Job/BAPI cũng phải bị chặn; dự án cũ để trong FORM `get_data_integration` của report | Áp cả Test run; tắt bằng `STATUS_CHECK = N` |
| D15 | **Huỷ** HĐĐT yêu cầu chứng từ SAP đã đảo; **thay thế** yêu cầu chứng từ gốc đã đảo | Quy tắc kế toán của dự án tham chiếu (`ZCANCELINV` chỉ khi `xreversed`; `type_dc = 2` yêu cầu `stblg`) | `CANCEL_REQUIRES_REVERSAL = N` để tắt huỷ; thay thế không có công tắc |
| D16 | Lớp nguồn là nơi **duy nhất** đọc bảng nghiệp vụ SAP → thêm `GET_DOC_STATE` vào `ZIF_HDDT_SOURCE` | Engine cần biết đảo/huỷ nhưng không được `SELECT bkpf/vbrk` | Lớp nguồn cloud cài bằng CDS released; `ty_request-src_info` mang thông tin sẵn để không SELECT lại |
| D17 | `ZTB_HDDT_INV-REF_DOCNO` lưu **số chứng từ SAP** của HĐ gốc (+ `REF_GJAHR`), không lưu idkey | Cần đọc lại sổ/ trạng thái đảo của HĐ gốc | `adjust-org_docno/org_gjahr/org_src_type`; fallback idkey cho bản ghi cũ |
| D19 | Luồng FS MAG v0.5 **nháp → phát hành trên chính bản nháp** (`CREATE_DRAFT` → `ISSUE_INVOICE`), `create-appr-inv` chỉ cho job tự động | FS 3.6 + 3.7.3 (issue-invoice); tránh xoá nháp tạo lại làm nhảy số | `ISSUE_INVOICE` action mới; adapter FPT không gửi `aun` cho CREATE_DRAFT |
| D20 | Khôi phục khi lỗi (90/45): **tra cứu trước** rồi chọn API (1 → issue, 2 → apprs, 3 → đồng bộ, không có → về 00) | FS 3.6.10: tuyệt đối không tạo lại / cấp số lại HĐ đã cấp số | `ZCL_HDDT_SERVICE->ISSUE_INVOICE`, `DELETE_DRAFT`; heuristic `IS_NOT_FOUND` **[Unverified]** |
| D21 | Ghi ngược chứng từ nguồn qua interface `ZIF_HDDT_WRITEBACK` + tham số `WRITEBACK_CLASS`; engine không SELECT/UPDATE BKPF | FS 3.6.3/3.6.5 yêu cầu XBLNR/XREF2_HD; giữ I8 (engine không biết bảng SAP) | `ZCL_HDDT_WRITEBACK_FI` dùng `FI_DOCUMENT_CHANGE`, chỉ ghi khi khác; XREF2_HD 12 ký tự → cắt (docs/10 §8) |
| D22 | Log dùng chung của khách hàng qua `ZIF_HDDT_LOG_SINK` + `LOG_SINK_CLASS`; `ZTB_HDDT_LOG` thêm trường khớp `ZTB_INT_LOG` | Bảng `ZTB_INT_LOG` thuộc khung tích hợp MAG, không thuộc package | sink không được raise; lỗi sink bị nuốt |
| D23 | `IDKEY` (sid/FKEY) = **Company code + Số chứng từ + Năm** | FS 3.7.1 | đổi I7; package chưa import nên không có dữ liệu cũ |
| D24 | Gom hoá đơn không dùng number range object; cấp số bằng `SELECT MAX` + `ENQUEUE_E_TABLE` | package tự đủ qua abapGit | `ZCL_HDDT_GOM=>NEXT_NUMBER`; `ZTB_HDDT_GOM` + `INV-GOM_NO` |
| D25 | Giữ bộ mã trạng thái package (00–90, thêm 45 CQT từ chối) thay cho mã FS 01–99 | Domain đã có, ALV đọc DD07T; bảng ánh xạ docs/10 §5 | đổi mã chỉ ở `ZDO_HDDT_STATUS` + `gc_status` nếu MAG bắt buộc |

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
ZCL_HDDT_SERVICE  ── cửa vào duy nhất, không raise
        │
        ├── ZCL_HDDT_CONFIG   (buffer toàn bộ ZTB_HDDT_*, singleton)
        ├── ZCL_HDDT_FACTORY  (CREATE OBJECT TYPE (classname), cache, kiểm GET_ID)
        ├── ZCL_HDDT_HTTP     (classic) / ZCL_HDDT_HTTP_CLOUD (chưa có)
        ├── ZCL_HDDT_TOKEN    (cache token ZTB_HDDT_TOK)
        ├── ZCL_HDDT_SECRET   (vault plug-in qua ZIF_HDDT_SECRET)
        └── ZCL_HDDT_LOG      (ZTB_HDDT_LOG / _INV / _ITEM)
                │
                ▼
        ZIF_HDDT_PROVIDER ── hợp đồng adapter (8 method, 3 bắt buộc)
                │
   ZCL_HDDT_PROV_BASE (abstract)
   ├── ZCL_HDDT_PROV_VIETTEL
   ├── ZCL_HDDT_PROV_FPT
   └── ZCL_HDDT_PROV_TEMPLATE ── ZCL_HDDT_PROV_VNPT

        ZIF_HDDT_SOURCE ── hợp đồng đọc nguồn (SELECT_DOCUMENTS, GET_DOC_STATE)
                │
   ZCL_HDDT_SRC_BASE (abstract: buyer/seller/thuế/tên hàng/sổ đăng ký)
   ├── ZCL_HDDT_SRC_FI   BKPF/BSEG/BSET (+VBRP/ACDOCA khi AWTYP = VBRK)
   └── ZCL_HDDT_SRC_SD   VBRK/VBRP/PRCD_ELEMENTS chưa có FI
```

| Bất biến | Kiểm bằng |
|---|---|
| I1. Engine + UI không nhắc tên NCC | `grep -rniE "'(VIETTEL\|FPT\|VNPT)'" src/engine src/ui` → 0 kết quả |
| I2. Tầng dùng chung (`src/prov`, `zcl_hddt_json`, 5 interface) không dùng API classic-only | grep bảng §10 → 0 kết quả |
| I3. Mọi SELECT bảng cấu hình chỉ nằm trong `ZCL_HDDT_CONFIG` | adapter/engine gọi `get_*`/`map_*`, không SELECT `ZTB_HDDT_*` cấu hình |
| I4. Adapter `GET_ID( )` = `ZTB_HDDT_PROV-PROVIDER` | factory kiểm tra, raise nếu lệch |
| I5. Mật khẩu không bao giờ đi vào `ZTB_HDDT_LOG` | `MASK_SECRETS` chạy trước `to_raw` trong `LOG_CALL` |
| I6. Số trong JSON: `.` thập phân, `-` phía trước, không zero dẫn đầu | `FORMAT_NUMBER` dùng `NUMBER = RAW` |
| I7. `IDKEY` ổn định giữa các lần thử lại | `fill_defaults`: `bukrs+src_docno+gjahr` (FS 3.7.1) nếu caller không truyền |
| I8. Engine không SELECT bảng nghiệp vụ SAP (BKPF/BSEG/VBRK/BUT000…) — chỉ lớp nguồn | `grep -rliE "FROM (bkpf|bseg|bset|vbrk|vbrp|but000|kna1)" src/engine` → chỉ `zcl_hddt_src_*` và `zcl_hddt_writeback_fi` (lớp ghi ngược, tầng classic, cắm qua tham số) |
| I9. Hằng số nghiệp vụ **riêng của khách hàng** (mã thuế, tài khoản, loại điều kiện, text ID Z) không nằm trong code; mặc định trong code chỉ được là giá trị chuẩn SAP (`VATRU`, `GRUN`, `MWAS`) | `grep -rnE "(3331|ZPR0|ZMST|ZBT|FS0001|ZI03|ZC0[45])" src/engine \| grep -vE '^[^:]+:[0-9]+:\s*[*"]'` → 0 dòng lệnh (comment nhắc dự án tham chiếu được phép; seed chỉ trong `ZPG_HDDT_SETUP`) |

---

## 3. Logic pipeline `ZCL_HDDT_SERVICE=>EXECUTE`

File: `src/engine/zcl_hddt_service.clas.abap`

```
1  provider    ← is_request-provider; rỗng → CONFIG.get_active_provider(bukrs)
2  adapter     ← FACTORY.get_provider(provider, bukrs)
3  action      ← adapter.resolve_action(request) (mặc định = request-action)
   endpoint    ← CONFIG.get_action(provider, action)         [ZTB_HDDT_ACT]
   credential  ← CONFIG.get_credential(provider,bukrs,inv_type,inv_date) [ZTB_HDDT_CRED]
   connection  ← CONFIG.get_connection(provider, cred-connid) [ZTB_HDDT_CONN]
4  fill_defaults: idkey, inv_type/template/serial/taxcode từ CRED,
   seller từ PARM SELLER_*, inv_date theo ZTB_HDDT_DATE, inv_time=sy-uzeit,
   currency (LOCAL_CURRENCY|VND), exch_rate=1 nếu rỗng,
   buyer-not_get_invoice nếu không có địa chỉ & tên,
   aggregate_invoice (taxes theo thuế suất + summary, quy đổi VND)
5  secret: test_run → '********' ; ngược lại SECRET.get_secret(cred) → cred-apisecret
   payload     ← adapter.build_payload(request, action, cred)
   attempt     ← LOG.count_attempts (bỏ qua test_run)
   ── test_run: result.success=X, log nếu LOG_TEST_RUN, RETURN ──
6  token (AUTH_MODE T/O) ← TOKEN.get_token (cache ZTB_HDDT_TOK, TTL)
   http        ← HTTP.send(conn, act, symbols=adapter.get_url_symbols,
                            headers=adapter.get_headers, payload, user, secret, bearer)
   401 + bearer → TOKEN.invalidate → get_token(force) → send lại ĐÚNG 1 LẦN
7  adapter.parse_response(request, action, http_code, body) → CHANGING result
   GET_FILE & file_content rỗng & success → result.file_content = body_x
8  derive_status: CONFIG.map_status(provider, action|'*', prov_status)
   không có → suy từ http 2xx + action (create: seq có → 40, không → 20)
9  LOG.log_call(...) → result.log_id
   src_docno có → LOG.save_invoice ; success & items → LOG.save_items
   i_commit → COMMIT WORK AND WAIT
CATCH zcx_hddt_error → result 90/E + message; vẫn log nếu đã có conn
CATCH cx_root          → result 90/E "Lỗi không xác định"
```

Điểm dễ sai khi sửa:
- Bước 5 phải **trước** bước 6: adapter FPT/VNPT cần secret trong body.
- Thứ tự CATCH: `zcx_hddt_error` trước `cx_root`.
- `execute_many` gọi `execute(... i_commit = abap_false)` rồi COMMIT 1 lần.

`aggregate_invoice` (public static, source class dùng lại):
- Đánh `line_no` nếu rỗng; `total = amount + tax_amount` nếu rỗng.
- Bảng thuế: gộp theo `tax_rate`, bỏ dòng `item_type = '3'` (ghi chú). **Không dùng COLLECT** vì `ty_tax` có STRING.
- Summary chỉ tính khi cả `total` và `amount_wo_tax` rỗng (caller có thể truyền sẵn).

---

## 4. Hợp đồng adapter và logic từng adapter

`ZIF_HDDT_PROVIDER` — 8 method; `ZCL_HDDT_PROV_BASE` cài 5, adapter con **bắt buộc** `GET_ID`, `BUILD_PAYLOAD`, `PARSE_RESPONSE` (khai `INTERFACES ... ABSTRACT METHODS`, con dùng `REDEFINITION`).

Tiện ích trong base (protected): `map_val`, `map_val_text`, `fmt_date`, `fmt_date_vn`, `fmt_datetime` (`YYYY-MM-DD hh:mm:ss`), `to_epoch_millis` (số học ngày/giờ, TZ từ `TIME_ZONE` hoặc platform), `num`, `build_form` (form-urlencoded, bỏ field rỗng, escape qua platform), `build_adjust_note`, `platform( )`.

### 4.1 Viettel — `ZCL_HDDT_PROV_VIETTEL` (đã đối chiếu tài liệu v2.44)

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
- **`selection`** mỗi dòng (`get_selection`): canonical `item_type` `0→1`, `1→5`, `2→3`, `3→2`; ghi đè qua `ZTB_HDDT_MAP` ITEMTYPE (provider VIETTEL). Dòng `selection=3` **luôn** `isIncreaseItem=false`.
- `exchangeRate = 1` khi VND.
- `payments[]` gửi `paymentMethod` + `paymentMethodName`.

`parse_response`: `errorCode` null = OK; `invoiceNo` = ký hiệu+số → tách bằng **tiền tố ký hiệu đã biết**, fallback chữ số cuối; `codeOfTax`→`mscqt` (fallback `reservationCode`); `fileToBytes` base64 → `file_content`. Response không JSON → xử lý riêng, không vỡ.

### 4.2 FPT — `ZCL_HDDT_PROV_FPT` (đã đối chiếu tài liệu v2.4.7)

- Tài khoản nằm trong **body** nút `user` (bỏ khi `FPT_USER_IN_BODY = N`).
- `inv`: `sid`(=idkey) `idt`(`YYYY-MM-DD hh:mm:ss`) `type` `form` `serial` `seq` `aun`(PARM `FPT_AUN`) `type_ref=1` `sendtype` … `sum/sumv vat/vatv total/totalv`, `items[]` (`vrt` = thuế suất nguyên hoặc -1/-2, ghi đè TAXRATE), `tax[]`, `adj{seq rdt ref rea}` + `ud` + `adj_only_add=1` khi ĐC/thay thế.
- `SEARCH_INVOICE` là **GET, tham số trong HTTP header** (`get_headers`), body rỗng.
- `CANCEL_INVOICE` TT78: nút `wrongnotice{stax noti_taxtype noti_taxnum noti_taxdt budget_relationid place items[{form serial seq idt type_ref noti_type=1 rea}]}`; `place` từ PARM `FPT_PLACE`.
- `DELETE_INVOICE`: `{user, sid, stax}`; response **text thuần**.
- `parse_response`: `status` 1/2/3/4 → 20/30/40/80; `status_received=10` → 50 + `ic`→mscqt; `sec`→sec_code; `link`→inv_link; `adt|idt`→issue_date.
- `build_login_payload` (`c_signin`) → body JWT thuần; base `extract_token` xử lý.

### 4.3 Template — `ZCL_HDDT_PROV_TEMPLATE`

Mẫu trong `ZTB_HDDT_TPL(provider, action)`. Cú pháp `{{group.field}}`, `{{fn.*}}`, vòng lặp `{{#items}}…{{/items}}`, `{{#taxes}}…{{/taxes}}`, escape `{{$json.x}}` / `{{$xml.x}}`. `value_of` dùng RTTI: số → `format_number`, DATS → ISO, TIMS → `hh:mm:ss`, CHAR → CONDENSE. Placeholder lạ → rỗng. **Bẫy đã sửa:** `sy-index` trong `WHILE` lồng `DO` — phải chép ra `lv_kind`.

### 4.4 VNPT — `ZCL_HDDT_PROV_VNPT`

Kế thừa Template. Không có tài liệu API → **không hardcode payload**. `parse_response`: JSON/XML → lớp cha; text `OK:<mẫu>;<ký hiệu>-<số>` / `ERR:<n>` → `PROV_STATUS = ERR<n>` để map qua `ZTB_HDDT_STAT`. **[Unverified]** quy ước text này.

---

## 5. Logic cấu hình — `ZCL_HDDT_CONFIG`

- Singleton, `load_buffer` đọc **toàn bộ** 9 bảng cấu hình 1 lần (SORTED TABLE). `invalidate( )` sau khi bảo trì (`ZPG_HDDT_CONFIG` gọi `ZCL_HDDT_FACTORY=>reset`).
- `get_active_provider(bukrs)`: (1) PARM `ACTIVE_PROVIDER`; (2) duy nhất 1 provider active trong CRED của bukrs; >1 → lỗi yêu cầu khai PARM.
- `get_credential`: chỉ dòng active + trong hiệu lực (`VALID_FROM/TO`); **khớp `INV_TYPE` chính xác thắng**, dòng `INV_TYPE=''` là dự phòng. Duyệt bằng field-symbol (bug cũ: loop INTO rs_cred bị ghi đè bởi dòng bị skip — đã sửa).
- `get_connection`: connid → PARM `DEFAULT_CONNID` → dòng active đầu tiên; phải có `RFCDEST` **hoặc** `BASE_URL`; `TIMEOUT` mặc định 60.
- `get_action`: mặc định method POST, `application/json`, accept `*/*`.
- `map_status`: `(prov,action,rc)` rồi `(prov,'*',rc)`.
- `map_value`: không có → trả nguyên giá trị (D10).
- `get_param`: 4 cấp (D9). `get_param_bool`: X/TRUE/Y/1.
- `resolve_invoice_date`: `ZTB_HDDT_DATE-DATE_SRC` 1 BUDAT · 2 CPUDT · 3 SY-DATUM · 4 BLDAT; mặc định SY-DATUM.

---

## 6. Logic JSON — `ZCL_HDDT_JSON`

- **Writer** fluent: stack `mt_has_item` quyết định dấu phẩy; `add_string` bỏ giá trị rỗng trừ `i_force`; `add_number` luôn ghi (kể cả 0) trừ `i_force=false`; `add_bool` → `true/false`; `add_bool_text` → `"true"/"false"` (Viettel yêu cầu text).
- **`format_number`**: `round( dec )` rồi `|{ p NUMBER = RAW }|` → cắt zero cuối. Không dùng `WRITE ... TO` (cloud + không phụ thuộc user setting).
- **Parser** đệ quy tay → bảng phẳng `path → value`: `a/b`, `arr[0]/x`, `arr#count`. `get_value_by_name` tìm theo thẻ lá ở mọi độ sâu (chịu được đổi độ lồng giữa version API). Escape `\uXXXX` giải mã qua platform.
- **`pretty`**: duyệt ký tự, theo dõi trong-chuỗi + escape → dấu cấu trúc trong tên hàng hoá không làm vỡ.
- Ký tự điều khiển (`gv_cr/gv_lf/gv_tab`) lấy từ platform trong `class_constructor`.

---

## 7. Logic HTTP (classic) — `ZCL_HDDT_HTTP`

- `resolve_path`: thay `{name}` từ symbols; placeholder sót → xoá (regex).
- `create_client`: `RFCDEST` → `create_by_destination` + `~request_uri` = path; ngược lại `create_by_url(base + path, ssl_id)`. Tắt popup logon, bật redirect.
- `apply_auth` theo `AUTH_MODE` (override bởi `ty_call-auth_mode`, dùng cho LOGIN): `B` basic · `H` header `username/password` **và** basic · `T/O` `Authorization: Bearer` · `N` không.
- Body chỉ set khi method ≠ GET/DELETE.
- Trả `req_header`/`res_header` (chưa che — LOG che), `body`, `body_x`, `duration_ms` (GET RUN TIME).
- Lỗi send/receive → `zcx_hddt_error` với `mv_http_code = 999`.

`ZCL_HDDT_TOKEN`: cache theo `(provider, connid, bukrs, apiuser)`; TTL từ `TOKEN_TTL` (mặc định 3000s); login qua action `TOKEN_ACTION|LOGIN` với `auth_mode = B` ép; `extract_token` của adapter.

---

## 8. Logic log — `ZCL_HDDT_LOG` + `ZPG_HDDT_LOG`

- `log_call(request, action, provider, ty_call_info, result)`:
  1. GUID32; điền định danh, kết quả, kỹ thuật HTTP, `attempt`, `test_run`, `caller=sy-cprog`, `tcode`.
  2. `keep_payload`: mặc định **lưu**; chỉ tắt khi `LOG_PAYLOAD` khai tường minh giá trị false.
  3. **`mask_secrets`** cả 4 nội dung (req/res body + header) → `to_raw` (UTF-8 qua platform) → `REQ_SIZE/RES_SIZE = xstrlen`; `MASKED = X` nếu nội dung đổi.
  4. INSERT thất bại → không raise, chỉ trả log_id rỗng.
- `mask_secrets` (public static): thẻ từ `LOG_MASK_TAGS` hoặc mặc định; 4 regex (JSON có/không ngoặc kép, form, header), `IGNORING CASE`. Regex viết trong string template nên `\\s`, `\{`, `\|` là escape của **template**, ra runtime là `\s`, `{`, `|`.
- `read_payload(log_id)`: giải mã theo `CODEPAGE` của dòng.
- `count_attempts`: COUNT theo (bukrs, gjahr, src_type, src_docno, action) bỏ `test_run`.
- `save_invoice`: upsert `ZTB_HDDT_INV`; **chỉ ghi đè** template/serial/seq/issue_date/mscqt/sec/link khi result có giá trị (lần lỗi không xoá số đã cấp).
- Màn hình `ZPG_HDDT_LOG`: danh sách **không đọc** body; range ngày → timestamp; điều kiện tuỳ chọn qua RANGE (không dùng `OR @p IS INITIAL`); nút xem request/response/header (pretty nếu JSON), tải nguyên bản byte.

---

## 9. Logic tầng đọc nguồn — `ZCL_HDDT_SRC_BASE` / `_FI` / `_SD`

Chi tiết đối chiếu từng bước với dự án tham chiếu: **docs/09-nguon-du-lieu.md**. Tóm tắt để review:

**Chọn chứng từ FI** — `BKPF JOIN BSEG (KOART='D')`; `XREVERSING = space`; chứng từ bị đảo chỉ giữ khi sổ đã có số HĐ hoặc `xreversed` tick; mã thuế dòng KH khớp MAP `TAXCODE`; BLART theo range → MAP `DOCTYPE`; range mới `BLDAT/VBELN(AWKEY)/KUNNR/USNAM`; một chứng từ = dòng KH đầu tiên.

**Dòng hàng FI** — `KOART='S' AND MWSKZ<>space`; MAP `GLACCT` (nếu khai) và **không** thuộc MAP `TAXACCT`; dấu `H → +WRBTR`, `S → −WRBTR` (nguyên tệ); tên: SGTXT → GLACCT text → MAKT → số TK; CT từ SD (AWTYP=VBRK): nối `ACDOCA (AWREF/AWITEM) → VBRP`, tên theo `ITEM_TEXT_IDS` (long text) → MAKT → ARKTX; thuế suất MAP `TAXRATE` → `BSET-KBETR/10` → `A003/KONP`; tiền thuế dòng `line_tax` (VND 0 lẻ) rồi **chốt theo BSET** (`taxes_from_bset`, dấu `S → âm`; `reconcile_tax` dồn chênh lệch vào **dòng cuối** cùng thuế suất — D13).

**Header** — `exch_rate_of` (VND → 1, else `abs(KURSF) × EXCH_RATE_FACTOR`); `resolve_invoice_date` có cap `INV_DATE_MAX_BACKDAYS`; thanh toán `BSEG-ZLSCH → VBRK-ZLSCH → DEFAULT_PAYMENT` qua MAP `PAYMENT`; `contract_no = VBKD-BSTKD`; `src_info` điền đủ cho engine.

**Người mua** — BSEC (khách lẻ, không cache) → `CVI_CUST_LINK/BUT000` (cá nhân: first+last; tổ chức: `BUYER_NAME_FIELDS`) → `BUT020` addrnumber lớn nhất → `ADRC` + `clean_address` (regex gộp `, ,`, hậu tố `ADDR_COUNTRY_SUFFIX`/`T005T`) → `BUT0ID` (`BUYER_TAX_IDTYPE`, `BUYER_ID_IDTYPE`) → `ADR6`/`ADR2` nối `;` → `BUT0BK/BNKA` theo BVTYP → fallback `KNA1`. Cache theo KUNNR.

**Người bán** — `T001 → ADRC → ADR6`, cache theo BUKRS, bật bằng `SELLER_FROM_T001`; `SELLER_*` chỉ điền chỗ trống.

**Nguồn SD chưa có FI** — MAP `BILLTYPE` bắt buộc; loại billing đã có BKPF; `FKSTO` như đảo; GJAHR = năm dương lịch FKDAT; dòng hàng theo MAP `CONDTYPE` (`AMT+/AMT-/TAX`) hoặc `NETWR/MWSBP`.

**Kết thúc** — `finalize_request`: `ITEM_QTY_ABS`, người bán, `ext TAX_RATE_SUMMARY`, `ZCL_HDDT_SERVICE=>aggregate_invoice`.

**Kiểm tra nghiệp vụ (engine, bước 4b)** — `CHECK_ACTION`/`CHECK_ORIGINAL` theo bảng ở docs/09 §5; sau thành công `MARK_ORIGINAL` đổi HĐ gốc sang 60/70. UI hỏi HĐ gốc bằng `POPUP_GET_VALUES` khi sổ chưa có `REF_DOCNO`.

---

## 10. Phân tầng nền tảng

| Tầng | Object | API classic-only còn dùng | Ghi chú |
|---|---|---|---|
| **Dùng chung** (phải cloud-safe) | 5 interface, `ZCX_HDDT_ERROR`, `ZCL_HDDT_JSON`, `ZCL_HDDT_PROV_*` | **không** (đã rà lượt 3) | `sy-datum/uzeit/uname` được phép (CASLA đang dùng) |
| **Classic** | `ZCL_HDDT_HTTP` (`cl_http_client`, `MESSAGE ID`, `cl_abap_char_utilities`), `ZCL_HDDT_PLAT_CLASSIC`, `ZCL_HDDT_LOG` (`cl_system_uuid`, `sy-cprog`, `sy-tcode`), `ZCL_HDDT_TOKEN` (`cl_abap_tstmp`), **`ZCL_HDDT_SRC_BASE/_FI/_SD`** (SELECT bảng SAP trực tiếp, `READ_TEXT`, `A003/KONP`), toàn bộ `src/ui` (`POPUP_GET_VALUES`) | có, hợp lệ | Bản cloud tương ứng chưa có; lớp nguồn cloud khai qua `ZTB_HDDT_SRC` |
| **Nửa chừng** | `ZCL_HDDT_CONFIG`, `_FACTORY`, `_SECRET`, `_PLATFORM`, `_SERVICE` | không thấy classic-only | nhưng dùng DDIC `ZTB_HDDT_*` — trên CASLA phải đối chiếu với 9 BO cấu hình sẵn có |

Bảng API tách qua `ZIF_HDDT_PLATFORM`:

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
| 2 | Cao | Script vá `s.index("PARSER")` khớp comment DEFINITION → nhân đôi IMPLEMENTATION `ZCL_HDDT_JSON` | `git checkout` + vá theo `METHOD…ENDMETHOD` + assert cấu trúc |
| 2 | Trung | `WRITE ... TO` phụ thuộc dấu thập phân user, không cloud | `NUMBER = RAW` |
| 3 | **Nghiêm trọng** | Mật khẩu FPT/VNPT trong body ghi **plaintext** vào `ZTB_HDDT_LOG` | `mask_secrets` trước khi ghi |
| 3 | Trung | `GET_HEADER_FIELDS` gọi như functional method (là CHANGING) | sửa cách gọi |
| 3 | Trung | `COND` với `s_date[ 1 ]` trên bảng rỗng → `CX_SY_ITAB_LINE_NOT_FOUND` | READ TABLE tường minh |
| 3 | Trung | `( bukrs = @p OR @p IS INITIAL )` không hợp lệ ABAP SQL | RANGE rỗng |
| 3 | Thấp | `UP TO n ROWS` / `INTO` đứng trước `WHERE` (thứ tự cũ, bị chặn strict mode) | chuyển sau `ORDER BY` (`zcl_hddt_src_fi`, `zpg_hddt_log`) |
| 3 | Thấp | `raise_sy_message` dùng `MESSAGE ID` trong exception dùng chung, không ai gọi | xoá → shared exception cloud-clean |
| 4 | Trung | `BSEC-TELF1` không chắc tồn tại (dự án tham chiếu không dùng) | bỏ TELF1, dùng `BANKS/BANKL/BANKN/INTAD` |
| 4 | Trung | `ALPHA = IN` trên `SVAL-VALUE` (CHAR132) đệm số 0 sai độ dài | gán vào `belnr_d` trước rồi ALPHA |
| 4 | Thấp | Host expression `@( \|...\| )` trong `UPDATE ... SET` (cần 7.50+) | tính vào biến trước |
| 4 | Thấp | `SHIFT ... DELETING TRAILING` trên STRING không cắt độ dài; `CO` với CHAR có blank đuôi | `replace( regex )`; thêm blank vào tập `CO` |
| 4 | Thấp | `RAISE EXCEPTION lx` trong CATCH để ném lại lỗi của chính TRY (đọc `mv_text CS`) | tách TRY chỉ bao `get_doc_state`, kiểm tra ngoài TRY |
| 4 | Thấp | `CATCH cx_sy_conversion_no_number` cho `CONV posnr( char )` (không raise) | bỏ |
| 4 | Trung | Lượt 3 dồn chênh lệch thuế vào dòng lớn nhất, dự án tham chiếu dùng dòng cuối | theo tham chiếu (D13) |

## 12. Còn mở / chưa kiểm chứng

| Mức | Hạng mục | Ghi chú |
|---|---|---|
| **Chặn go-live** | Chưa activate trên hệ SAP nào | lần import đầu cần 1 lượt activate + sửa cú pháp sót |
| **Chặn go-live** | Chưa gọi thật tới NCC nào | phải Test run + đối chiếu payload |
| Cao | Chưa có ABAP Unit | ưu tiên: `FORMAT_NUMBER`, `PARSE`, `PRETTY`, `MASK_SECRETS`, `AGGREGATE_INVOICE`, `RESOLVE_PATH`, `TO_EPOCH_MILLIS` |
| Cao | Chưa có reorg `ZTB_HDDT_LOG` (~1 GB/100k HĐ/năm) | docs/08 §8 |
| Cao | Viettel bất đồng bộ: `invoiceNo` rỗng → phải `SEARCH_INVOICE` sau 30–90s | job quét `STATUS=20` chưa có |
| Trung | Bản cloud: `ZCL_HDDT_PLAT_CLOUD`, `ZCL_HDDT_HTTP_CLOUD`, tách `ZCL_MANAGE_VIETTEL_EINVOICES` trên CASLA thành adapter | cần cookie `Casla_Dev` (080) để ghi |
| Trung | Đối chiếu bảng cấu hình mới với 9 BO cấu hình CASLA (`ZJP_R_HD_*`) | tránh 2 bộ cấu hình song song |
| Cao | FS MAG docs/10 §8: XREF2_HD 12 ký tự, `aun` cho adjust/replace, URL prod issue-invoice, response "không tìm thấy", màn hình sửa dòng gom | cần MAG / FPT xác nhận trước khi test |
| Trung | Nguồn MM, hoá đơn **gom** (`ZGOM_INV`, `ztb_e_gomh/goml/map_gom`), **phiếu xuất kho** (`get_pxk` MKPF/MSEG), ghi ngược `BKPF` (`XREF1_HD/XBLNR/XREF2_HD`) | chưa port từ dự án tham chiếu — docs/09 §7 |
| Trung | **[Unverified]** trên hệ thật: `BSEC-BANKS/BANKL/BANKN/INTAD`, `ACDOCA-BUZEI = BSEG-BUZEI` với CT billing, `PRCD_ELEMENTS-KINAK`, `KONP-LOEVM_KO`, `INTERFACES … ABSTRACT METHODS` + `REDEFINITION` ở lớp con | activate lần đầu sẽ lộ |
| Thấp | Nguồn SD: GJAHR = năm dương lịch FKDAT — lệch với công ty có năm tài chính khác | dùng `T009` nếu cần |
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
- [ ] Kế thừa `ZCL_HDDT_PROV_BASE` (hoặc dùng `PROV_TEMPLATE` + `ZTB_HDDT_TPL`); cài `GET_ID/BUILD_PAYLOAD/PARSE_RESPONSE`.
- [ ] Endpoint + Content-Type vào `ZTB_HDDT_ACT` (kiểm tra kỹ **form-urlencoded vs JSON** — Viettel đã sập ở đây).
- [ ] Thẻ secret của NCC vào `LOG_MASK_TAGS`.
- [ ] Không dùng API classic-only trong adapter (grep §10).
- [ ] Nạp mặc định vào `ZPG_HDDT_SETUP`; viết `docs/0x-provider-<ncc>.md` với nguồn tham chiếu và mục tài liệu.

**Khi sửa tầng đọc nguồn**
- [ ] Hằng số nghiệp vụ mới (mã thuế, tài khoản, loại điều kiện, text ID) → MAP/PARM + seed *VÍ DỤ* trong SETUP, không hardcode (I9).
- [ ] Điền đủ `ty_request-src_info` (đảo/huỷ) và cài `GET_DOC_STATE` — engine dựa vào đó để kiểm tra.
- [ ] Gọi `finalize_request` cuối `build_one`.
- [ ] Đối chiếu bước tương ứng trong docs/09 và ghi khác biệt vào đó.

**Khi sửa engine**
- [ ] Không SELECT bảng cấu hình ngoài `ZCL_HDDT_CONFIG`.
- [ ] Không để `EXECUTE` raise ra ngoài.
- [ ] Không log gì trước khi qua `MASK_SECRETS`.
- [ ] Nghiệp vụ mới -> thêm nhánh `CHECK_ACTION` (bảng điều kiện trạng thái) và `DERIVE_STATUS`; UI không tự kiểm trạng thái.
- [ ] Không SELECT/UPDATE bảng nghiệp vụ SAP trong service: ghi ngược qua `ZIF_HDDT_WRITEBACK`.
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
| 6 | 07/09/2026 | Đối chiếu FS MAG_SAP_2026_PM_FS_Tich hop HDDT v0.5 (docs/10): `ISSUE_INVOICE`, `apprs` riêng, `adjtype/ref` (API 3.2), trạng thái 45, `CHECK_ACTION` theo bảng FS, khôi phục theo tra cứu, gắn HĐ gốc + loại ĐC, validate trường bắt buộc, ghi ngược BKPF, email BCS, gom/gỡ gom, phát hành tự động (job), sửa ngày/giờ/tên hàng, phân quyền theo nút, log khớp ZTB_INT_LOG; 6 DE + 1 bảng + 33 message mới | D19–D25; 9 điểm chờ MAG xác nhận (docs/10 §8) |
| 5 | 03/09/2026 | Rà + đổi tên toàn bộ theo chuẩn Private Cloud 03.09.2026 (§15): ~100 object, gộp include, 270 text có dấu, 415 field-symbol `<FS_>`, 223+ tham số scalar `I_/E_/C_/R_`, biến GUI toàn cục | 0 tên cũ còn lại trong `src`/`tools`; regenerate DDIC/meta; cấu trúc class/FORM kiểm bằng script |
| 4 | 03/09/2026 | Port tầng đọc nguồn FI/Billing từ dự án private cloud (`zhddt.docx` + `ZFG_E_INVOICES` EEMC): `SRC_BASE` mới, `SRC_FI` viết lại, `SRC_SD` mới, `CHECK_ACTION` trong engine, `GET_DOC_STATE`, popup HĐ gốc, 13 PARM + 4 MAP_TYPE mới; tự rà cú pháp | 8 điểm sửa (§11 lượt 4); D12–D17; I8–I9; docs/09 |

## 15. Rà naming convention Private Cloud (chuẩn 03.09.2026) — ĐÃ THỰC HIỆN (lượt 5)

Rà theo skill `fis-sap-private-cloud-naming` (tài liệu `QUY_UOC_DAT_TEN_SAP_PRIVATE_CLOUD_v1.0.docx`, 03.09.2026). Package lượt 1–4 đặt tên theo skill cũ (D11) nên **100 object** không khớp; người dùng chọn đổi toàn bộ (D18). Điều khoản §11 của chuẩn (giữ tên object cũ) không áp dụng vì package chưa import lên hệ nào.

| Hạng mục | Trước | Sau | Trạng thái |
|---|---|---|---|
| 14 bảng | `ZFIT_HDDT_*` | `ZTB_HDDT_*` (dài nhất 13/16) | ✓ |
| 47 DE / 10 domain | `ZFIDE_` / `ZFIDO_` | `ZDE_HDDT_*` / `ZDO_HDDT_*` | ✓ |
| 19 class / 5 interface / exception | `ZFIC_` / `ZFIIF_` / `ZFICX_` | `ZCL_HDDT_*` / `ZIF_HDDT_*` / `ZCX_HDDT_ERROR` | ✓ |
| 4 report | `ZFIR_HDDT_*` | `ZPG_HDDT_*` | ✓ |
| Include `_INT_TOP/_SEL/_CL1/_EVT/_F01` | 5 include | `ZPG_HDDT_INTEGRATION_TOP` (khai báo + màn hình chọn), `_F01` (lớp local ALV + FORM), sự kiện trong chương trình chính | ✓ |
| Message class | `ZFIE_HDDT` | `ZMS_HDDT` | ✓ |
| Tcode | `ZFI_HDDT`, `_CFG`, `_LOG` | `ZFI001`, `ZFI002`, `ZFI003` | ✓ — **[Unverified]** số còn trống trên hệ đích, kiểm SE93 trước khi import |
| Package `ZPK_HDDT_CORE` + `_DDIC/_ENGINE/_PROV/_UI` | | giữ (đúng `ZPK_<dự án>[_<lớp>]`, gốc không chứa object) | ✓ |
| Selection text / text element 3 report | không dấu | có dấu, ≤ 30 ký tự | ✓ |
| Label 47 DE (short/medium/long/heading) | không dấu | có dấu, trong giới hạn 10/20/40/55 | ✓ |
| Fixed value text domain (STATUS, AUTH, ADJTYPE, MAPTYPE, SRCTYPE, ITEMTYPE) | không dấu | có dấu | ✓ |
| Message class T100, tiêu đề cột ALV trong code, popup | có dấu | | ✓ |
| Mô tả object / package / comment | không dấu | giữ (được phép) | ✓ |
| Field-symbol `<ls_/<lv_>` (415) | | `<fs_…>` (không xung đột tên) | ✓ |
| Scalar `iv_/ev_/cv_/rv_` | | `i_/e_/c_/r_`; `it_/is_/rt_/rs_` giữ | ✓ |
| Object ref `io_/ro_/lo_/mo_` | | giữ **[Inference]** — chuẩn không định nghĩa; đổi `io_provider`→`i_provider` sẽ trùng `iv_provider` cùng file | ghi nhận |
| Thuộc tính class `mo_/mv_/mt_` | | giữ **[Inference]** — chuẩn không định nghĩa | ghi nhận |
| Biến nhận `cl_gui_frontend_services` | cục bộ trong `save_file` | `gv_file_name/_path/_full/_action` toàn cục trong `_TOP` | ✓ |
| Tên A–Z 0–9 _, viết hoa, tự mô tả, không `$TMP` | ✓ | | ✓ |
| Mô tả TR `TEAM\\ACCOUNT\\mô tả` | | ghi vào docs/06 §10 cho lần import đầu | ✓ |

Kiểm sau đổi: `grep -rniE "zfi(t|de|do|cx|c|if|r|e)_hddt|\bzfi_hddt" src tools` → 0; `grep -rhoE '\biv_|\brv_|<l[sv]_' src` → 0; số `METHOD` = `ENDMETHOD`, 1 `IMPLEMENTATION`, 2 `ENDCLASS` mỗi class; DE label và selection text trong giới hạn độ dài (script). Chưa activate trên hệ SAP — như mọi lượt trước.

## 16. Lỗi gặp khi dán code vào Eclipse ADT (S25/100) — ĐÃ SỬA (lượt 7, 08/09/2026)

Người dùng tạo tay từng object trên hệ MAG S25 client 100. Bảng dưới ghi đúng thông báo lỗi
của ADT, nguyên nhân và cách sửa đã áp dụng vào `src/` (repo không ghi lên hệ SAP nào).

| # | Thông báo ADT | Object / dòng | Nguyên nhân | Sửa |
|---|---------------|---------------|-------------|-----|
| 1 | `Invalid expression limiter '}' in string template` | `ZCL_HDDT_JSON` method `p_object` | `}` là dấu đóng biểu thức trong string template `\|...\|`, muốn in chữ phải escape | `'\}'` trong thông báo lỗi |
| 2 | `"CLASS_CONSTRUCTOR" must always be PUBLIC` | `ZCL_HDDT_JSON` | `CLASS-METHODS class_constructor` khai báo ở PRIVATE SECTION | chuyển sang PUBLIC SECTION, ngay sau `constructor` |
| 3 | `A RETURNING parameter must be fully typed` | `ZCL_HDDT_JSON~cur`, `ZIF_HDDT_PLATFORM` (`newline` / `carriage_return` / `tab`) | `TYPE c` không có độ dài là kiểu generic, RETURNING không nhận kiểu generic | `TYPE char1` |
| 4 | `The class contains unknown comments which can't be stored` | `ZCL_HDDT_JSON`, `ZCL_HDDT_SERVICE`, `ZCL_HDDT_SRC_BASE`, `ZCL_HDDT_SRC_FI` | comment thường (`*----*` banner, `" chú thích`) trong phần DEFINITION không gắn được vào component nào | chuyển hết thành ABAP Doc `"!` liền trước khai báo; banner thành `"! ---- TIÊU ĐỀ ----` |
| 5 | `Too long for activation of 'not null' flag (>255)` | `ZTB_HDDT_LOG` (REQ_HEADER, RES_HEADER, REQ_BODY, RES_BODY), `ZTB_HDDT_TOK` (TOKEN), `ZTB_HDDT_TPL` (TPL_BODY) | cột `Init` (Initial Values) trong SE11 bị tích ở field kiểu `STRG` / `RSTR`; DDIC không đặt được cờ NOT NULL cho field dài quá 255 | bỏ tích `Init` ở 6 field đó (XML abapGit chỉ đặt NOT NULL cho field khoá nên không bị) |
| 6 | `Unknown column name "DATBI"` + `"LT_KONP[" is not a field name` | `ZCL_HDDT_SRC_BASE~tax_rate_of` | `ORDER BY a~datbi` trong khi DATBI không có trong danh sách SELECT; lỗi thứ hai chỉ là hệ quả vì `lt_konp` khai báo nội dòng không sinh ra được | lấy kèm `a~datbi AS datbi`, `ORDER BY datbi DESCENDING`, đổi `sy-subrc` thành `IF lt_konp IS NOT INITIAL` |
| 7 | `ABAP Doc comment is in the wrong position` (cảnh báo) | `ZCL_HDDT_SRC_BASE` 40, `ZCL_HDDT_SRC_FI` 57/118/131, `ZCL_HDDT_PROV_FPT` 45 | `"!` đặt trước khai báo chuỗi `TYPES: BEGIN OF` / `CONSTANTS: BEGIN OF`; ADT chỉ nhận ABAP Doc trước một câu lệnh khai báo đơn hoặc trước từng thành phần bên trong khối | chuyển doc xuống dòng khai báo kiểu bảng `TYPES ty_t_*`; chỗ không có thì đưa lên khối header của class |
| 8 | `For the result of a computation with type P, the type P(8,0) is used here implicitly` (cảnh báo, nhưng sai kết quả) | `ZCL_HDDT_SRC_BASE~line_tax` | `DATA(lv_tax) = i_amount * i_rate / 100` suy ra P(8,0) nên thuế bị làm tròn về số nguyên trước khi `round( dec = 2 )` | khai báo `DATA lv_tax TYPE decfloat34` rồi mới gán |
| 9 | `The regex standard POSIX is deprecated` (cảnh báo) | `ZCL_HDDT_SRC_BASE` 719/720, `ZCL_HDDT_LOG` 4 chỗ, `ZCL_HDDT_HTTP` 1 chỗ | dùng `REGEX` / `regex =` | đổi sang `PCRE` / `pcre =`; các mẫu hiện có tương thích PCRE |
| 10 | `Redundant conversion for type AWREF` (cảnh báo) | `ZCL_HDDT_WRITEBACK_FI` 187 | `CONV awref( i_belnr )` trong khi BELNR_D và AWREF cùng CHAR10 | gán trực tiếp `i_awref = i_belnr`; giữ `CONV aworg( )` vì nguồn là string |
| 11 | `Unknown column name` ở mọi câu `ORDER BY` dùng cột không có trong `SELECT` | `ZCL_HDDT_SRC_BASE` (ADR6 ×3, ADR2, VBKD, A003/KONP), `ZCL_HDDT_SRC_FI` (BKPF-BSEG, BSEG) | ABAP SQL chỉ cho `ORDER BY` theo tên cột của tập kết quả; không nhận cột chỉ có trong bảng nguồn, cũng không nhận tiền tố bảng dạng `k~belnr` | thêm cột sắp xếp vào danh sách SELECT (`consnumber`, `posnr`, `buzei`), dùng tên cột kết quả (`belnr`, `cust_buzei`) |
| 12 | Cột `DATBI` không có trong `A003` trên hệ MAG S25 | `ZCL_HDDT_SRC_BASE~tax_rate_of` | khoá A003 ở hệ này chỉ gồm KAPPL / KSCHL / ALAND / MWSKZ + KNUMH, không có khoảng hiệu lực, nên không thể sắp xếp theo DATBI như dự án tham chiếu | mỗi khoá A003 chỉ có một KNUMH, nên sắp xếp theo `KOPOS` của KONP cho xác định; nếu cần kiểm tra hiệu lực thì phải join thêm KONH (DATAB/DATBI) |
| 13 | `Method "GET_ID" is unknown or PROTECTED or PRIVATE` | `ZCL_HDDT_FACTORY~get_provider` dòng 94/96 | KHÔNG phải lỗi source: `ZIF_HDDT_PROVIDER` khai `get_id` là public. Khi tạo object mới, ADT sinh sẵn bản ACTIVE rỗng (`INTERFACE ... PUBLIC. ENDINTERFACE.`); mới Save mà chưa Activate thì syntax check của class vẫn đọc bản active rỗng nên không thấy method nào | Activate `ZIF_HDDT_TYPES` trước, rồi các interface còn lại, xong mới activate class. Không sửa gì trong source |

Quy tắc rút ra cho phần DEFINITION của class:

- Chỉ dùng `"!` (ABAP Doc) và phải nằm **liền ngay trước** khai báo, không chen dòng trống.
- Không đặt banner `*---------*` hay comment `"` tự do giữa các khai báo.
- Không dùng `<tag` trong `"!` vì ABAP Doc hiểu là thẻ HTML.
- `CLASS_CONSTRUCTOR` bắt buộc PUBLIC; RETURNING phải có kiểu đầy đủ (`char1`, `string`, `abap_bool`…).
- Bảng có field `STRG` / `RSTR`: cột `Init` trong SE11 phải để trống, xem bảng trên.
- Trong string template, `{` `}` phải escape thành `\{` `\}` nếu muốn in ra chữ.
- `ORDER BY` chỉ dùng tên cột có trong danh sách `SELECT`, không dùng tiền tố bảng.
- Activate ngay từng object theo thứ tự DDIC → interface → class; bản ACTIVE rỗng do wizard sinh ra là nguyên nhân của phần lớn lỗi "unknown method" giả.

Phần INTERFACE (`ZIF_*`) giữ nguyên comment banner vì các interface đã lưu được trên S25;
nếu về sau gặp cùng lỗi #4 thì áp dụng đúng cách sửa trên.

[Unverified] Nguyên nhân lỗi #4 là suy luận từ thông báo của ADT: trình biên tập class lưu
comment theo từng component nên comment không gắn được component sẽ bị từ chối. Chưa
kiểm chứng bằng tài liệu SAP.

Bộ kiểm tra tĩnh `tools/check_abap.py` chạy lại được mọi lúc (`python tools/check_abap.py`),
soát 9 nhóm lỗi: method khai báo nhưng chưa hiện thực, method interface chưa hiện thực trong
cây thừa kế, khối lệnh không khớp, kiểu generic ở tham số trả về, comment thường trong
DEFINITION, `CLASS_CONSTRUCTOR` không PUBLIC, `{` `}` chưa escape trong string template,
tham chiếu hằng số / kiểu của interface không tồn tại, gọi method tĩnh không tồn tại.
Kết quả trên commit hiện tại: 0 phát hiện (7 interface, 23 class). Đã kiểm chứng bộ kiểm tra
bằng cách chèn lỗi giả rồi hoàn nguyên — cả 5 lỗi chèn vào đều bị bắt đúng số dòng.

[Unverified] Bộ kiểm tra chạy ngoài SAP nên không thay được syntax check của ADT: không biết
bảng / data element đã tồn tại trên hệ hay chưa, không kiểm tra kiểu của API SAP chuẩn.
