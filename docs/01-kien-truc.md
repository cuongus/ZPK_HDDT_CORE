# 01 — Kiến trúc ZPK_HDDT_CORE

## 1. Vấn đề cần giải

Ba nhà cung cấp HĐĐT khác nhau ở gần như mọi tầng:

| | Viettel SInvoice | FPT eInvoice | VNPT/Vinaphone |
|---|---|---|---|
| Base URL | `api-vinvoice.viettel.vn` | `api-uat.einvoice.fpt.com.vn` | (theo hợp đồng) |
| Nghiệp vụ ↔ endpoint | 1 endpoint `createInvoice` dùng cho gốc/ĐC/thay thế, phân biệt bằng `adjustmentType` | mỗi nghiệp vụ 1 endpoint riêng (`create-appr-inv`, `adjust-invoice`, `replace-invoice`…) | thường ít endpoint, phân biệt bằng tham số |
| MST trong URL | có: `…/createInvoice/{mst}` | không | không |
| Xác thực | Basic auth **hoặc** Bearer token qua `/auth/login` | user/pass trong **payload**, hoặc Basic, hoặc JWT qua `/c_signin` | Basic auth |
| Tên thẻ | camelCase dài (`invoiceIssuedDate`) | viết tắt 3–6 ký tự (`idt`, `stax`, `vrt`) | thường XML |
| Ngày lập | epoch millis | `YYYY-MM-DD hh:mm:ss` | tuỳ |
| Trạng thái | `errorCode` null = OK | `status` 1/2/3/4 | `OK:` / `ERR:n` |

Nếu để những khác biệt này nằm rải rác trong code nghiệp vụ (như package
`ZPK_HDDT` hiện tại) thì đổi nhà cung cấp = viết lại.

## 2. Nguyên tắc thiết kế

### 2.1 Chỉ một model dữ liệu

`ZIF_HDDT_TYPES=>ty_invoice` là **canonical model** — hình dạng hoá đơn theo
nghiệp vụ Việt Nam, không theo bất kỳ nhà cung cấp nào:

```
ty_invoice
 ├── header   (idkey, inv_type, template, serial, seq, inv_date, currency, exch_rate…)
 ├── seller   (tax_code, name, address, bank…)
 ├── buyer    (code, tax_code, legal_name, person_name, address, email…)
 ├── items[]  (line_no, item_name, unit, quantity, price, amount, tax_rate, tax_amount…)
 ├── taxes[]  (tax_rate, taxable_amt, tax_amt, + bản quy đổi VND)
 ├── payments[]
 ├── summary  (amount_wo_tax, tax_amount, total, + bản quy đổi VND)
 ├── adjust   (adj_type, org_serial, org_seq, org_inv_date, reason…)
 └── ext[]    ← name/value tự do cho thẻ riêng của NCC, KHÔNG cần sửa type
```

SAP luôn điền vào đúng một cấu trúc này. Việc đổi sang payload riêng là của
adapter.

### 2.2 Khác biệt về **dữ liệu** → bảng cấu hình

Không phải mọi khác biệt đều cần code. Ba loại sau chỉ là dữ liệu:

| Khác biệt | Nơi khai |
|---|---|
| URL, timeout, chứng chỉ SSL, proxy | `ZTB_HDDT_CONN` (hoặc SM59) |
| Nghiệp vụ nào gọi endpoint nào, method gì | `ZTB_HDDT_ACT` |
| MST phải nối vào URL hay không | placeholder `{taxcode}` trong `API_PATH` |
| Mã trả về nào nghĩa là gì | `ZTB_HDDT_STAT` |
| Thuế suất / hình thức thanh toán / tài khoản | `ZTB_HDDT_MAP` |

### 2.3 Khác biệt về **hình dạng payload** → adapter

Chỉ phần này cần ABAP. `ZIF_HDDT_PROVIDER` có 8 method, trong đó adapter con
bắt buộc chỉ 3:

| Method | Bắt buộc | Việc |
|---|---|---|
| `get_id` | ✔ | trả về mã nhà cung cấp |
| `build_payload` | ✔ | canonical model → payload |
| `parse_response` | ✔ | payload trả về → `ty_result` |
| `resolve_action` | | đổi action nghiệp vụ sang action kỹ thuật |
| `get_url_symbols` | | giá trị thay placeholder trong URL |
| `get_headers` | | header HTTP đặc thù (FPT dùng cho tra cứu) |
| `build_login_payload` | | payload cho endpoint đăng nhập |
| `extract_token` | | bóc token khỏi response |

`ZCL_HDDT_PROV_BASE` đã cài đặt 5 method còn lại một cách hợp lý.

### 2.4 Chọn adapter bằng cấu hình, không bằng `CASE`

```abap
" ZCL_HDDT_FACTORY
DATA(lv_class) = lo_config->get_provider_class( lv_provider ).  " từ bảng
CREATE OBJECT ro_object TYPE (lv_class).                        " động
ro_provider ?= ro_object.
IF ro_provider->get_id( ) <> lv_provider.  " chặn cấu hình sai
```

Đây là lý do engine không cần biết tên nhà cung cấp nào. Thêm nhà cung cấp thứ
tư = 1 lớp mới + 1 dòng bảng, engine không đổi, không cần test hồi quy engine.

## 3. Luồng xử lý `ZCL_HDDT_SERVICE=>EXECUTE`

```
 1. provider   ← ZTB_HDDT_PARM.ACTIVE_PROVIDER  hoặc suy từ ZTB_HDDT_CRED
 2. adapter    ← ZCL_HDDT_FACTORY (CREATE OBJECT động)
 3. action     ← adapter->resolve_action( )
    endpoint   ← ZTB_HDDT_ACT
    tài khoản  ← ZTB_HDDT_CRED (có kiểm tra hiệu lực theo ngày)
    kết nối    ← ZTB_HDDT_CONN
 4. điền mặc định + tính bảng thuế + tổng cộng          [core]
 5. secret     ← ZCL_HDDT_SECRET (vault hoặc bảng); test run → '********'
    payload    ← adapter->build_payload( )
    ── nếu Test run: DỪNG, trả payload ──
 6. token      ← ZCL_HDDT_TOKEN (cache trong ZTB_HDDT_TOK) nếu AUTH_MODE=T/O
    gọi HTTP   ← ZCL_HDDT_HTTP (destination hoặc URL, method/header từ cấu hình)
    HTTP 401   → đăng nhập lại đúng 1 lần rồi gọi lại
 7. result     ← adapter->parse_response( )
 8. trạng thái ← ZTB_HDDT_STAT, không có thì suy từ mã HTTP + action
 9. log        → ZTB_HDDT_LOG (request + response)
    sổ HĐ      → ZTB_HDDT_INV + ZTB_HDDT_ITEM
```

`EXECUTE` bắt cả `zcx_hddt_error` và `cx_root` — job xử lý 5.000 hoá đơn
không được chết vì 1 chứng từ lỗi.

## 4. Vì sao tự viết JSON writer/parser

`ZCL_HDDT_JSON` không dùng serializer theo tên field ABAP, vì:

1. **Chữ hoa/thường**: tên field ABAP luôn về chữ thường khi serialize, nên mã
   cũ phải chạy `REPLACE ALL OCCURRENCES` với 40+ dòng trong bảng
   `ZTB_JSON_REPLACE` để dựng lại `invoiceIssuedDate`. Rất dễ vỡ khi một tên
   thẻ là chuỗi con của tên thẻ khác.
2. **Định dạng số**: field packed serialize ra `0000010450.000000`, và dấu trừ
   nằm ở cuối. Nhà cung cấp cần `10450` và `-500`.
3. **Thẻ rỗng**: nhiều API báo lỗi validate khi nhận `""`. Writer tự bỏ thẻ rỗng
   (bật/tắt bằng tham số constructor), thay vì phải `REPLACE` để xoá.

Parser trả về bảng phẳng `path → value`, cộng `get_value_by_name( )` tìm theo
tên thẻ lá ở bất kỳ độ sâu nào — nhờ đó nhà cung cấp thay đổi độ lồng giữa các
phiên bản API cũng không làm vỡ adapter.

## 5. Điểm mở rộng

| Cần làm gì | Cách làm | Có phải sửa core? |
|---|---|---|
| Đổi nhà cung cấp | đổi `ACTIVE_PROVIDER` + `ZTB_HDDT_CRED` | không |
| Đổi URL / môi trường | `ZTB_HDDT_CONN` | không |
| NCC thêm/đổi endpoint | `ZTB_HDDT_ACT` | không |
| NCC đổi tên một thẻ JSON | sửa 1 dòng trong lớp adapter tương ứng | không |
| Thêm nhà cung cấp thứ 4 (JSON/XML đơn giản) | mẫu payload trong `ZTB_HDDT_TPL` + dòng `ZTB_HDDT_PROV` trỏ `ZCL_HDDT_PROV_TEMPLATE` | không |
| Thêm nhà cung cấp phức tạp | 1 lớp kế thừa `ZCL_HDDT_PROV_BASE` + 1 dòng `ZTB_HDDT_PROV` | không |
| Nghiệp vụ đọc dữ liệu khác | lớp implement `ZIF_HDDT_SOURCE` + `ZTB_HDDT_SRC` | không |
| Lấy mật khẩu từ vault | lớp implement `ZIF_HDDT_SECRET` + tham số `SECRET_CLASS` | không |
| Nguồn SD / MM / hoá đơn gom | lớp mới implement `ZIF_HDDT_SOURCE` | không |
