# 06 — Cài đặt và triển khai

## 1. Yêu cầu hệ thống

| Hạng mục | Yêu cầu |
|---|---|
| Nền tảng | SAP S/4HANA **Private Cloud** hoặc on-premise (ABAP cổ điển) |
| Release ABAP tối thiểu | 7.50 — code dùng `NEW`, table expression ghi, `COND`/`VALUE`/`CONV`, inline declaration |
| abapGit | bản báo cáo độc lập `ZABAPGIT` (SE38) hoặc plugin ADT |
| Giao diện | SAP GUI (`CL_SALV_TABLE`, `CL_GUI_FRONTEND_SERVICES`) |
| Kết nối ra ngoài | HTTPS ra Internet, hoặc qua proxy / reverse proxy của doanh nghiệp |

> Package **không dùng** ABAP Cloud / RAP / CDS. Chủ ý: mục tiêu là SAP GUI trên
> Private Cloud, và `CL_HTTP_CLIENT` + `WRITE ... TO` không được phép trong ABAP
> Cloud. Nếu sau này cần chạy trên Public Cloud thì phải thay
> `ZCL_HDDT_HTTP` (dùng `CL_WEB_HTTP_CLIENT_MANAGER`) và bỏ `WRITE ... TO`
> trong `ZCL_HDDT_JSON=>FORMAT_NUMBER` — các lớp khác giữ nguyên.

## 2. Import từ Git

```
1. SE80 → tạo package ZPK_HDDT_CORE
   - Software component: HOME
   - Transport layer: layer của khách hàng
   - Package type: development

2. SE38 → ZABAPGIT → + New Online
   URL     : https://github.com/cuongus/ZPK_HDDT_CORE.git
   Package : ZPK_HDDT_CORE
   Branch  : main

3. Pull. abapGit tự tạo 4 subpackage con:
   ZPK_HDDT_CORE_DDIC / _ENGINE / _PROV / _UI
```

## 3. Kích hoạt — theo đúng thứ tự

DDIC phải hoạt động trước, vì code tham chiếu tới bảng và data element.

```
Bước 1 — Domain      : 10 object ZDO_HDDT_*
Bước 2 — Data element: 42 object ZDE_HDDT_*
Bước 3 — Bảng        : 14 object ZTB_HDDT_*
Bước 4 — Message class ZMS_HDDT
Bước 5 — Interface   : ZIF_HDDT_TYPES → _PROVIDER → _SOURCE → _SECRET
Bước 6 — Class engine: ZCX_HDDT_ERROR → ZCL_HDDT_JSON → _CONFIG →
                       _SECRET → _HTTP → _TOKEN → _LOG → _FACTORY →
                       _SERVICE → _SRC_FI
Bước 7 — Class adapter: ZCL_HDDT_PROV_BASE → _VIETTEL / _FPT /
                        _TEMPLATE → _VNPT
Bước 8 — Program + transaction
```

Trong ADT/SE80 dùng **mass activation** (chọn tất cả object inactive → Activate)
để hệ thống tự giải quyết thứ tự phụ thuộc vòng (interface ↔ exception class).

### Dynpro 0100 + GUI status ZGRID_HDDT (bắt buộc để 12 nút hiện ra)

Màn hình danh sách dùng `CL_GUI_ALV_GRID` trên docking container, 12 nút khai
trong code qua event `TOOLBAR`. Phải tạo tay hai object:

```
SE51 → dynpro 0100 của ZPG_HDDT_INTEGRATION
  Layout để RỖNG; flow logic:
    PROCESS BEFORE OUTPUT.  MODULE status_0100.
    PROCESS AFTER INPUT.    MODULE user_command_0100.

SE41 → status ZGRID_HDDT, type Normal screen
  Bấm Display Standards; chỉ cần BACK / EXIT / CANC
  Application Toolbar để trống
```

Chi tiết và cách kiểm tra: [docs/12-dynpro-alv-grid.md](12-dynpro-alv-grid.md).

### Table Maintenance Generator (bắt buộc để `ZFI002` chạy)

Với **từng bảng** `ZTB_HDDT_*`: SE11 → nhập tên bảng → Display →
menu **Utilities → Table Maintenance Generator**

```
Authorization group : &NC&  (hoặc nhóm riêng — xem 02-cau-hinh.md §7 cho CRED)
Function group      : ZFG_HDDT_VIEWS
Maintenance type    : one step
Overview screen     : 100, 200, 300, ... (tăng dần cho từng bảng)
```

Bảng chỉ để xem (`ZTB_HDDT_INV`, `_ITEM`, `_LOG`, `_TOK`) vẫn nên sinh để tra
cứu bằng SM30, nhưng đặt authorization group hạn chế hơn.

> Nếu chưa sinh maintenance dialog, `ZFI002` báo lỗi
> *"Bảng &1 chưa sinh Table Maintenance Generator"* — đúng thông điệp, không dump.

**Ngoại lệ — 3 bảng có field kiểu STRING / RAWSTRING không sinh được TMG.**
SE54 báo `Data type STRING in field <tên> is not supported`. Đây là hạn chế của
Table Maintenance Generator, không phải lỗi bảng.

| Bảng | Field | Cách bảo trì / tra cứu thay thế |
|---|---|---|
| `ZTB_HDDT_TPL` | `TPL_BODY` (STRING) | nhấn đôi dòng "Mẫu payload" trong `ZFI002` → nhập nhà cung cấp + mã nghiệp vụ → nạp file JSON từ máy trạm |
| `ZTB_HDDT_TOK` | `TOKEN` (STRING) | nhấn đôi dòng "Token" trong `ZFI002` → xem bộ đệm bằng ALV, hỏi xoá để buộc đăng nhập lại |
| `ZTB_HDDT_LOG` | `REQ_HEADER`, `RES_HEADER`, `REQ_BODY`, `RES_BODY` (RAWSTRING) | nhấn đôi dòng "Log API" trong `ZFI002` → mở `ZPG_HDDT_LOG` |

Vậy chỉ sinh TMG cho 11 bảng còn lại. Mẫu payload nạp trực tiếp vào bảng nên
**không đi theo transport**, phải nạp lại trên từng hệ QAS và PRD.

### Object phân quyền theo chức năng (FS MAG 3.10)

Tạo bằng SU21 (không đi qua abapGit): object `Z_FI_HDDT` (hoặc tên khác), field
`BUKRS` và `ACTVT` với 01 (tạo/huỷ nháp), 02 (phát hành, điều chỉnh, gom), 03
(xem, tra cứu, email, lấy file). Khai tên object vào tham số `AUTH_OBJECT`.

### Gửi email

`ZCL_HDDT_MAIL` dùng BCS → cần SCOT cấu hình SMTP và job `SOST`/`RSCONN01`.

## 4. Nạp cấu hình khởi tạo

```
SE38 → ZPG_HDDT_SETUP

Lần 1: giữ tick "Chi mo phong"  → xem ALV kết quả sẽ ghi gì
Lần 2: bỏ tick                   → ghi thật
```

Chương trình nạp: danh mục 4 nhà cung cấp, kết nối UAT, toàn bộ endpoint
Viettel + FPT, tham số mặc định, ánh xạ trạng thái FPT, lớp đọc FI.

**Không nạp mật khẩu** và **không nạp `ZTB_HDDT_CRED`** — hai thứ đó tuỳ khách
hàng.

## 5. Kết nối ra ngoài

### 5.1 Chứng chỉ SSL — STRUST

```
STRUST → SSL client SSL Client (Anonymous)
  → Import certificate của api-vinvoice.viettel.vn (và/hoặc
    api-uat.einvoice.fpt.com.vn) cùng toàn bộ chain CA
  → Add to Certificate List → Save
Restart ICM: SMICM → Administration → ICM → Exit Soft → Global
```

Thiếu bước này thì mọi lời gọi HTTPS trả `SSL handshake failed` /
`ICM_HTTP_SSL_ERROR`.

### 5.2 RFC destination — SM59 (khuyến nghị)

```
SM59 → Connection type G (HTTP Connection to External Server) → Create
  Name          : ZHDDT_VIETTEL   (hoặc ZHDDT_FPT)
  Target host   : api-vinvoice.viettel.vn
  Service No.   : 443
  Path prefix   : (để trống — core tự set qua ~request_uri)
  Tab Logon & Security:
    SSL         : Active,  SSL Certificate = DFAULT SSL Client (Anonymous)
    Basic Authentication + user/password (nếu dùng AUTH_MODE = 'N')
  Tab Special Options: HTTP proxy nếu doanh nghiệp bắt đi qua proxy
```

Rồi trong `ZTB_HDDT_CONN` điền `RFCDEST = ZHDDT_VIETTEL`.

### 5.3 Không dùng destination

Điền `BASE_URL` và `SSL_ID` (thường `ANONYM`) trong `ZTB_HDDT_CONN`.
Cách này không dùng được proxy có xác thực.

## 6. Cấu hình nghiệp vụ tối thiểu để chạy

```
ZFI002 →

1. ZTB_HDDT_CRED
   PROVIDER=FPT  BUKRS=1000  INV_TYPE=(trống)  CONNID=UAT
   TAXCODE=0100100008  TEMPLATE=1  SERIAL=K26TAA
   APIUSER=0100100008.admin  APISECRET=<mật khẩu>  XACTIVE=X

2. ZTB_HDDT_PARM
   PROVIDER=(trống) BUKRS=1000 PARM_KEY=ACTIVE_PROVIDER PARM_VAL=FPT
   PROVIDER=(trống) BUKRS=1000 PARM_KEY=SELLER_NAME     PARM_VAL=<tên công ty>
   PROVIDER=(trống) BUKRS=1000 PARM_KEY=SELLER_ADDR     PARM_VAL=<địa chỉ>

3. ZTB_HDDT_DATE
   BUKRS=1000  DATE_SRC=1   (lấy posting date làm ngày lập hoá đơn)

4. ZTB_HDDT_MAP — ánh xạ mã thuế của bạn sang thuế suất
   MAP_TYPE=TAXRATE  SAP_VALUE=<MWSKZ>  EXT_VALUE=10  EXT_TEXT=10%
```

## 7. Chạy thử

```
ZFI001
  Mã công ty     : 1000
  Năm tài chính  : 2026
  Số chứng từ    : <1 chứng từ bán hàng đã ghi sổ>
  Loại nguồn     : FI
  ☑ Test run

→ Chọn dòng → nút "Xem payload"
→ Kiểm tra: MST, mẫu số, ký hiệu, ngày, tổng tiền, thuế suất, tên hàng hoá
→ Bỏ tick Test run → nút "Phát hành" → xác nhận
→ Xem kết quả trên ALV; nút "Log" để xem request/response đầy đủ
```

## 8. Phân quyền

| Object | Dùng cho |
|---|---|
| `S_TCODE` | `ZFI001`, `ZFI002` |
| `F_BKPF_BUK` (`BUKRS`, `ACTVT=03`) | chương trình kiểm tra ở `AT SELECTION-SCREEN ON p_bukrs` |
| `S_RFC` / `S_ICF` | gọi RFC destination loại G |
| `S_TABU_DIS` / `S_TABU_NAM` | bảo trì bảng cấu hình — tách nhóm riêng cho `ZTB_HDDT_CRED` |
| `S_GUI` | tải file hoá đơn về máy trạm |

> Package chưa có authorization object riêng cho từng nghiệp vụ (phát hành / huỷ).
> Nếu cần tách quyền "được phát hành" và "được huỷ", tạo object `Z_HDDT_ACT`
> (field: `BUKRS`, `ZHDDT_ACT`) và thêm `AUTHORITY-CHECK` trong
> `LCL_APP->EXECUTE_ACTION`.

## 9. Trạng thái kiểm chứng — quan trọng

Package được viết **ngoài hệ thống SAP** rồi đưa lên Git. Tại thời điểm commit
đầu tiên:

- **Chưa activate trên bất kỳ hệ SAP nào** → lần import đầu phải dành thời gian
  cho một lượt activate và sửa lỗi cú pháp còn sót.
- **Chưa gọi thật tới API nhà cung cấp nào** → phải chạy Test run và đối chiếu
  payload với tài liệu trước khi phát hành hoá đơn thật.
- **Chưa có ABAP Unit test.** Ứng viên nên viết trước:
  `ZCL_HDDT_JSON=>FORMAT_NUMBER` (số âm, số thập phân, làm tròn),
  `ZCL_HDDT_JSON=>PARSE` (JSON lồng, mảng, ký tự escape),
  `ZCL_HDDT_SERVICE=>AGGREGATE_INVOICE` (nhiều thuế suất, dòng ghi chú),
  `ZCL_HDDT_HTTP=>RESOLVE_PATH` (placeholder thiếu giá trị).

Xem checklist go-live ở [07-doi-nha-cung-cap.md](07-doi-nha-cung-cap.md) §5.

## 10. Release transport

Mô tả Transport Request theo chuẩn nội bộ: `TEAM\ACCOUNT\mô tả` — ví dụ
`DEV\CUONGUS\Tich hop hoa don dien tu ZPK_HDDT_CORE` (`DEV` team phát triển,
`BA` team nghiệp vụ; mô tả ngắn, phần quan trọng lên đầu vì một số màn hình cắt
còn 60 ký tự). Tcode `ZFI001`–`ZFI003`: kiểm SE93 xem số còn trống trước khi
import, nếu trùng thì đổi số trong `tools/gen_meta.py` (TRANS) và tài liệu.

Trước khi release TR đầu tiên, cập nhật cột **Transport** trong khối changelog ở
header của **mọi** object: đổi `abapGit` thành mã TR thật (ví dụ `PRDK900123`).
Đây là yêu cầu của chuẩn `fis-sap-naming-convention-cuongus` §4.
