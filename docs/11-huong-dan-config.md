# 11 — Hướng dẫn cấu hình (màn hình ZPG_HDDT_CONFIG)

Màn hình cấu hình liệt kê 14 bảng. Nhấn đôi vào một dòng để mở bảo trì bảng đó.
Năm dòng đầu có dấu `X` ở cột cuối là **bắt buộc phải có dữ liệu** mới chạy được.

Thứ tự làm: nạp mẫu bằng chương trình, rồi chỉ sửa những gì thuộc về khách hàng.

## 1. Nạp mẫu trước khi gõ tay — ZPG_HDDT_SETUP

```
SE38 → ZPG_HDDT_SETUP

Lần 1: giữ tick "Chỉ mô phỏng"     → xem ALV sẽ ghi gì
Lần 2: bỏ tick "Chỉ mô phỏng"      → ghi thật

Tick chọn:
  ☑ Danh mục, tham số, nguồn chung   (p_base)   → PROV, SRC, PARM, DATE, MAP mẫu
  ☑ Viettel                          (p_prov1)  → CONN + ACT của Viettel
  ☑ FPT                              (p_prov2)  → CONN + ACT + PARM của FPT
  ☐ VNPT                             (p_prov3)  → chỉ khi dùng VNPT
  ☑ Tham số riêng theo FS MAG        (p_mag)    → xem mục 6
  ☐ Ghi đè bản ghi đã có             (p_ovwrt)  → chỉ tick khi muốn nạp lại
```

Chương trình **không** nạp `ZTB_HDDT_CRED` và **không** nạp mật khẩu. Hai thứ đó
tuỳ khách hàng, phải tự điền.

## 2. Bốn bảng phải tự điền

### 2.1 `ZTB_HDDT_CRED` — Tài khoản (bắt buộc)

Một dòng cho mỗi công ty. Đây là bảng duy nhất chứa thông tin nhận dạng người bán.

| Field | Giá trị | Ghi chú |
|---|---|---|
| `PROVIDER` | `FPT` | khoá |
| `BUKRS` | mã công ty | khoá |
| `INV_TYPE` | để trống | khoá; chỉ điền khi một công ty dùng nhiều loại hoá đơn |
| `CONNID` | `UAT` hoặc `PRD` | trỏ tới dòng trong `ZTB_HDDT_CONN` |
| `TAXCODE` | mã số thuế người bán | |
| `TEMPLATE` | mẫu số hoá đơn | nhà cung cấp cấp |
| `SERIAL` | ký hiệu hoá đơn | nhà cung cấp cấp |
| `APIUSER` | tài khoản API | thường dạng `<MST>.admin` |
| `APISECRET` | mật khẩu API | |
| `SECKEY` | khoá phụ | chỉ khi nhà cung cấp yêu cầu |
| `VALID_FROM` / `VALID_TO` | hiệu lực | để trống là luôn hiệu lực |
| `XACTIVE` | `X` | không tick thì engine bỏ qua dòng này |

### 2.2 `ZTB_HDDT_PARM` — Tham số người bán

Nạp mẫu đã điền phần kỹ thuật. Chỉ cần thêm thông tin công ty:

```
PROVIDER trống · BUKRS <công ty> · SELLER_NAME  = tên công ty trên hoá đơn
PROVIDER trống · BUKRS <công ty> · SELLER_ADDR  = địa chỉ
PROVIDER trống · BUKRS <công ty> · SELLER_TEL   = điện thoại
PROVIDER trống · BUKRS <công ty> · SELLER_MAIL  = email
PROVIDER trống · BUKRS <công ty> · SELLER_BANK  = tên ngân hàng
PROVIDER trống · BUKRS <công ty> · SELLER_ACCT  = số tài khoản
```

Muốn lấy tự động từ `T001` và `ADRC` thay vì gõ tay thì đặt
`SELLER_FROM_T001 = X` và bỏ các dòng `SELLER_*` ở trên.

### 2.3 `ZTB_HDDT_DATE` — Ngày lập hoá đơn

Một dòng cho mỗi công ty. `DATE_SRC` nhận `1` posting date, `2` entry date,
`3` ngày hệ thống, `4` document date. `TIME_CUT` là giờ cắt: chứng từ nhập sau
giờ này thì lấy ngày hôm sau (để trống là không cắt).

### 2.4 `ZTB_HDDT_MAP` — Ánh xạ giá trị

Bảng quan trọng nhất về số liệu. Nạp mẫu chỉ có ví dụ, phải sửa theo mã thuế thật.

| `MAP_TYPE` | `SAP_VALUE` | `EXT_VALUE` | Ý nghĩa |
|---|---|---|---|
| `TAXRATE` | mã thuế (`MWSKZ`) | `10`, `8`, `5`, `0` | thuế suất phần trăm |
| `TAXRATE` | mã thuế | `-1` | không chịu thuế |
| `TAXRATE` | mã thuế | `-2` | không kê khai nộp thuế |
| `TAXCODE` | mẫu mã thuế (`O*`, `**`) | `X` | mã thuế nào được coi là thuế đầu ra |
| `TAXACCT` | `3331*` | `X` | tài khoản thuế GTGT, dòng có TK này bị loại khỏi hàng hoá |
| `PAYMENT` | `ZLSCH` | mã hình thức thanh toán của NCC | |
| `CONDTYPE` | `KSCHL` | `AMT+` / `AMT-` / `TAX` | chỉ dùng cho nguồn SD |
| `BILLTYPE` | `FKART` | `X` | loại billing SD được lấy |

`EXT_TEXT` là chữ hiển thị, ví dụ `10%`.

## 3. Bảng kết nối — sửa khi lên môi trường thật

`ZTB_HDDT_CONN` nạp sẵn dòng `FPT / UAT` trỏ tới `https://api-uat.einvoice.fpt.com.vn`,
`AUTH_MODE = N`, `TOKEN_ACTION = LOGIN`, `TOKEN_TTL = 3000`, `TIMEOUT = 60`.
`AUTH_MODE = N` vì FPT nhận tài khoản trong thân payload chứ không qua header.

Lên production: thêm dòng `FPT / PRD` với `BASE_URL` thật, rồi đổi `CONNID`
trong `ZTB_HDDT_CRED` thành `PRD`. Khuyến nghị dùng RFC destination: tạo
destination loại G trong SM59, điền tên vào `RFCDEST` và để trống `BASE_URL`.
Trước đó phải import chứng chỉ SSL của nhà cung cấp vào STRUST.

`ZTB_HDDT_ACT` là đường dẫn endpoint theo từng nghiệp vụ, chỉ sửa khi nhà cung
cấp đổi API. `ZTB_HDDT_STAT` là ánh xạ mã trả về sang trạng thái trong SAP, đã
nạp đủ cho FPT. `ZTB_HDDT_TPL` chỉ dùng cho adapter dạng template như VNPT.

## 4. Nguồn dữ liệu — `ZTB_HDDT_SRC`

Một dòng cho mỗi công ty và mỗi loại nguồn.

```
BUKRS <công ty> · SRC_TYPE FI  · CLASSNAME ZCL_HDDT_SRC_FI   · XACTIVE X
BUKRS <công ty> · SRC_TYPE SD  · CLASSNAME ZCL_HDDT_SRC_SD   · XACTIVE X
BUKRS <công ty> · SRC_TYPE GOM · CLASSNAME ZCL_HDDT_SRC_GOM  · XACTIVE X
```

Nạp mẫu ghi dòng với `BUKRS` trống, có tác dụng cho mọi công ty. Chỉ thêm dòng
theo công ty khi muốn dùng lớp đọc riêng.

## 5. Bốn bảng chỉ để xem

`ZTB_HDDT_INV` sổ đăng ký hoá đơn, `ZTB_HDDT_ITEM` chi tiết hàng hoá đã phát
hành, `ZTB_HDDT_LOG` log request và response, `ZTB_HDDT_TOK` bộ đệm token.
Engine tự ghi. Chỉ nên xoá dòng trong `ZTB_HDDT_TOK` khi cần buộc đăng nhập lại.

## 6. Tham số riêng theo FS MAG (tick p_mag)

| `PARM_KEY` | Giá trị | Tác dụng |
|---|---|---|
| `ACTIVE_PROVIDER` | `FPT` | nhà cung cấp đang dùng |
| `WRITEBACK_CLASS` | `ZCL_HDDT_WRITEBACK_FI` | ghi mẫu số, ký hiệu, số hoá đơn về `BKPF-XBLNR` và `XREF2_HD` |
| `BUYER_NAME_FIELDS` | `NAME_ORG2,NAME_ORG3,NAME_ORG4` | tên tổ chức ghép từ ba field, không có thì lấy `NAME_ORG1` |
| `BUYER_PERSON_NAME` | `LAST_FIRST` | tên cá nhân ghép họ trước tên sau |
| `TAX_SOURCE` | `GLACCT` | tiền thuế lấy từ dòng có tài khoản trong map `TAXACCT` |
| `INV_TIME_DEFAULT` | `080000` | giờ phát hành mặc định |
| `MAIL_SUBJECT_DRAFT` / `MAIL_SUBJECT_FINAL` | mẫu tiêu đề email | placeholder `{SERIAL}` `{SEQ}` `{BUYER}` `{DOCNO}` `{DATE}` `{COMPANY}` |

Tham số khác đáng chú ý, đặt thêm khi cần: `API_VERSION` (`3.2` cho FPT bản mới),
`VALIDATE_REQUEST` (`X` để kiểm tra trường bắt buộc trước khi gọi API),
`INV_DATE_MAX_BACKDAYS` (chặn lập hoá đơn lùi ngày quá số ngày cho phép),
`AUTH_OBJECT` (bật kiểm tra quyền), `AUTO_APPROVE_AFTER_REPLACE`,
`MAIL_ALLOWED_STATUS`, `ITEM_TEXT_IDS`, `DEFAULT_PAYMENT`.

## 7. Kiểm tra sau khi cấu hình

```
ZPG_HDDT_INTEGRATION
  Mã công ty    : <công ty>
  Năm tài chính : <năm>
  Số chứng từ   : một chứng từ bán hàng đã ghi sổ
  Loại nguồn    : FI
  ☑ Test run

→ chọn dòng → nút "Xem payload"
→ soát: mã số thuế, mẫu số, ký hiệu, ngày, tên người mua, thuế suất, tổng tiền
→ bỏ tick Test run → nút "Tích hợp HĐ" để tạo hoá đơn nháp
→ nút "Log" xem request và response đầy đủ
```

Thiếu cấu hình thì engine trả lỗi có ghi rõ tên bảng và khoá còn thiếu, đọc ở
cột thông báo trên ALV hoặc trong `ZTB_HDDT_LOG`.

[Unverified] Toàn bộ hướng dẫn dựa trên source trong repo, chưa chạy thử trên hệ
SAP nào. Tên field và giá trị domain lấy từ `tools/gen_ddic.py`; giá trị nạp mẫu
lấy từ `src/ui/zpg_hddt_setup.prog.abap`.
