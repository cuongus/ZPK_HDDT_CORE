# ZPK_HDDT_CORE — Tích hợp hoá đơn điện tử Việt Nam cho SAP

Package ABAP tích hợp hoá đơn điện tử (HĐĐT) cho **SAP S/4HANA Private Cloud /
on-premise**, ứng dụng **SAP GUI**.

Mục tiêu thiết kế duy nhất, và mọi quyết định trong package đều phục vụ nó:

> **Đổi nhà cung cấp Viettel ↔ FPT ↔ VNPT chỉ bằng CẤU HÌNH, không sửa một dòng code.**

---

## 1. Vì sao code hiện tại không làm được điều đó

Package `ZPK_HDDT` đang chạy ở hai hệ thống được đưa vào phân tích:

| | Hệ EEMC (Viettel) | Hệ VJC (FPT) |
|---|---|---|
| Function phát hành | `ZFM_CREATE_E_INVOICES` | `ZFM_CREATE_E_INVOICES` (cùng tên, **khác nội dung**) |
| Cấu trúc payload | `ZST_JSON_E_INVOICE` | `ZST_CR_EINV_JSON_FPT` |
| RFC destination | `'EINVOICES'` hardcode trong code | `'EINVOICES_FPT'` hardcode trong code |
| Sửa tên thẻ JSON | bảng `ZTB_JSON_REPLACE` + `REPLACE ALL OCCURRENCES` | không dùng |
| Ngày lập hoá đơn | epoch millis | chuỗi `YYYY-MM-DD hh:mm:ss` |

Hệ quả: đổi nhà cung cấp = **fork lại toàn bộ function group**, chỉnh sửa và test
lại từ đầu. Đó chính xác là vấn đề mà package này giải quyết.

---

## 2. Kiến trúc

```
      SAP GUI (ZFI001)            Job nền / BAPI / Enhancement
               │                                │
               └───────────────┬────────────────┘
                               ▼
                    ZCL_HDDT_SERVICE            ← CỬA VÀO DUY NHẤT
                               │
        ┌──────────────────────┼────────────────────────┐
        ▼                      ▼                        ▼
 ZCL_HDDT_CONFIG      ZCL_HDDT_FACTORY         ZCL_HDDT_HTTP
 (đọc bảng cấu hình)   (CREATE OBJECT động)      (REST theo cấu hình)
                               │
                               ▼
                    ZIF_HDDT_PROVIDER          ← HỢP ĐỒNG
                               │
      ┌────────────────┬───────┴────────┬──────────────────┐
      ▼                ▼                ▼                  ▼
 PROV_VIETTEL      PROV_FPT       PROV_TEMPLATE        PROV_VNPT
 (SInvoice)      (FPT eInvoice)  (theo mẫu cấu hình)  (kế thừa TEMPLATE)
```

**Điểm cốt lõi:** trong toàn bộ `ZCL_HDDT_SERVICE`, `ZCL_HDDT_HTTP`,
`ZCL_HDDT_CONFIG`, `ZCL_HDDT_LOG` và chương trình SAP GUI **không có một chuỗi
`'VIETTEL'` / `'FPT'` / `'VNPT'` nào**. Tên lớp adapter được đọc từ
`ZTB_HDDT_PROV-CLASSNAME` rồi `CREATE OBJECT ... TYPE (lv_class)`.

Kiểm chứng nhanh sau khi import:

```abap
" Grep phải trả về 0 kết quả trong 2 subpackage engine + ui
" (chỉ có trong ZPK_HDDT_CORE_PROV và bảng cấu hình)
```

Chi tiết: [docs/01-kien-truc.md](docs/01-kien-truc.md)

---

## 3. Đổi nhà cung cấp — thao tác thực tế

Từ Viettel sang FPT, trên hệ PRD, **không cần transport**:

```
1. ZFI002 → bảng ZTB_HDDT_CRED
   Thêm dòng:  PROVIDER=FPT, BUKRS=1000, TAXCODE, TEMPLATE, SERIAL,
               APIUSER, CONNID=PRD, VALID_FROM = ngày cắt chuyển
   Sửa dòng Viettel: VALID_TO = ngày cắt chuyển - 1

2. Bảng ZTB_HDDT_PARM
   PROVIDER='' BUKRS=1000 PARM_KEY=ACTIVE_PROVIDER PARM_VAL=FPT

3. SM59 → tạo destination cho FPT (hoặc điền BASE_URL trong ZTB_HDDT_CONN)

4. Xong. Chạy lại ZFI001.
```

Hoá đơn đã phát hành bằng Viettel vẫn tra cứu / huỷ / điều chỉnh được, vì
`ZTB_HDDT_INV` lưu `PROVIDER` của từng hoá đơn.

Runbook đầy đủ (kể cả rollback): [docs/07-doi-nha-cung-cap.md](docs/07-doi-nha-cung-cap.md)

---

## 4. Cài đặt

```
1. abapGit → New Online → https://github.com/cuongus/ZPK_HDDT_CORE.git
   Package: ZPK_HDDT_CORE   (tạo trước, gán transport layer)
2. Pull → Activate all (DDIC trước, code sau)
3. SE11: sinh Table Maintenance Generator cho 11 bảng ZTB_HDDT_* (trừ _TPL / _TOK / _LOG vì có field STRING — xem docs/06 §3)
4. SE38 → ZPG_HDDT_SETUP → bỏ tick "Chi mo phong" → nạp cấu hình khởi tạo
5. SM59: tạo RFC destination loại G cho nhà cung cấp
6. ZFI002: khai ZTB_HDDT_CRED + ACTIVE_PROVIDER
7. ZFI001: chạy với tick "Test run" để xem payload trước khi gửi thật
```

Chi tiết + phân quyền + STRUST: [docs/06-cai-dat.md](docs/06-cai-dat.md)

---

## 5. Nội dung package

| Subpackage | Nội dung |
|---|---|
| `ZPK_HDDT_CORE_DDIC` | 10 domain, 42 data element, 14 bảng (cấu hình + log + sổ hoá đơn) |
| `ZPK_HDDT_CORE_ENGINE` | 4 interface, 10 class, message class `ZMS_HDDT` |
| `ZPK_HDDT_CORE_PROV` | 5 class adapter (base, Viettel, FPT, Template, VNPT) |
| `ZPK_HDDT_CORE_UI` | 4 report (tích hợp / cấu hình / setup / log), 5 include, 3 transaction |

### Bảng cấu hình

| Bảng | Vai trò |
|---|---|
| `ZTB_HDDT_PROV` | Danh mục nhà cung cấp → **tên lớp adapter** |
| `ZTB_HDDT_CONN` | RFC destination / base URL / cách xác thực / timeout / SSL |
| `ZTB_HDDT_ACT` | Đường dẫn API theo từng nghiệp vụ, hỗ trợ placeholder `{taxcode}` |
| `ZTB_HDDT_CRED` | Tài khoản API, MST, mẫu số, ký hiệu theo công ty + hiệu lực |
| `ZTB_HDDT_STAT` | Mã trả về của NCC → trạng thái trong SAP |
| `ZTB_HDDT_MAP` | Thuế suất, hình thức thanh toán, tài khoản doanh thu |
| `ZTB_HDDT_PARM` | Tham số chung (nhà cung cấp đang dùng, thông tin bên bán…) |
| `ZTB_HDDT_DATE` | Nguồn ngày lập hoá đơn theo công ty |
| `ZTB_HDDT_SRC` | Lớp đọc chứng từ nguồn (FI/SD/MM/GOM/CUST) |
| `ZTB_HDDT_TPL` | Mẫu payload cho adapter dạng template |
| `ZTB_HDDT_TOK` | Bộ đệm access token |
| `ZTB_HDDT_INV` | Sổ đăng ký hoá đơn đã tích hợp |
| `ZTB_HDDT_ITEM` | Chi tiết hàng hoá đã phát hành |
| `ZTB_HDDT_LOG` | Log request/response từng lần gọi API — payload lưu dạng **xstring** (byte-exact), secret được che lúc ghi |

Hướng dẫn cấu hình từng bảng trên màn hình ZPG_HDDT_CONFIG: [docs/11-huong-dan-config.md](docs/11-huong-dan-config.md) · Mô tả trường: [docs/02-cau-hinh.md](docs/02-cau-hinh.md) · Log tích hợp: [docs/08-log-tich-hop.md](docs/08-log-tich-hop.md) · Tầng đọc nguồn FI/SD và kiểm tra nghiệp vụ: [docs/09-nguon-du-lieu.md](docs/09-nguon-du-lieu.md) · Đối chiếu FS MAG v0.5: [docs/10-doi-chieu-fs-mag.md](docs/10-doi-chieu-fs-mag.md)

> **Đọc trước khi sửa code:** [Code_Review.md](Code_Review.md) — decision log, bất biến
> kiến trúc, logic từng bước pipeline, phân tầng classic/cloud, kết quả các lượt
> review và checklist build lại. Đây là tài liệu sống, mỗi lượt sửa phải cập nhật.

---

## 6. Gọi từ code khác

```abap
DATA(lo_svc) = zcl_hddt_service=>get_instance( ).

DATA(ls_req) = VALUE zif_hddt_types=>ty_request(
  bukrs     = '1000'
  gjahr     = '2026'
  src_type  = 'FI'
  src_docno = '1800000123'
  invoice   = VALUE #(
    buyer = VALUE #( legal_name = 'Công ty TNHH ABC'
                     tax_code   = '0100100008'
                     address    = 'Hà Nội'
                     email      = 'ketoan@abc.vn' )
    items = VALUE #(
      ( item_name = 'Dịch vụ tư vấn' unit = 'lần' quantity = 1
        price = 10000000 amount = 10000000
        tax_rate = 10 tax_amount = 1000000 ) ) ) ).

DATA(ls_res) = lo_svc->create_invoice( ls_req ).

IF ls_res-success = abap_true.
  WRITE: / |Số hoá đơn: { ls_res-serial }{ ls_res-seq }|.
ELSE.
  WRITE: / |Lỗi: { ls_res-message }|.
ENDIF.
```

`execute( )` **không bao giờ raise exception** — mọi lỗi nằm trong
`ls_res-message` / `ls_res-status`, để job xử lý hàng loạt không bị dừng giữa
danh sách. Xem thêm `execute_many( )`.

---

## 7. Trạng thái hoàn thiện — đọc trước khi go-live

| Thành phần | Trạng thái |
|---|---|
| Kiến trúc, engine, cấu hình, log, SAP GUI | Hoàn chỉnh |
| Adapter **FPT** | Endpoint và cấu trúc payload **đã đối chiếu** tài liệu FPT.eInvoice v2.4.7 (mục 3.1, 3.3, 3.5, 3.7, 3.8, 3.9, 3.10, 3.11) |
| Adapter **Viettel** | Endpoint, Content-Type và **toàn bộ tên thẻ đã đối chiếu** tài liệu SInvoice v2.44 (11/2024, 162 trang): mục 6.1–6.8 (tên thẻ), 7.2 / 7.3 / 7.8 / 7.9 / 7.20 / 7.21. Đối chiếu này tìm ra **4 lỗi thật** — đã sửa, xem [docs/03 §7](docs/03-provider-viettel.md) |
| Adapter **VNPT/Vinaphone** | **Chưa có tài liệu API** trong bộ tài liệu được cung cấp. Adapter kế thừa `ZCL_HDDT_PROV_TEMPLATE`: dán mẫu payload vào `ZTB_HDDT_TPL` là chạy, không phải viết ABAP |
| Lớp đọc dữ liệu nguồn FI | Port từ dự án HĐĐT private cloud đang chạy (BKPF/BSEG/BSET, FI sinh từ billing SD qua ACDOCA/VBRP, khách lẻ BSEC, BP/CVI, chốt thuế theo BSET) — xem `docs/09`. Hằng số của dự án cũ đã thành MAP/PARM; seed trong SETUP là **ví dụ**, cần rà theo hệ thống của bạn |
| Lớp đọc billing SD chưa có FI | `ZCL_HDDT_SRC_SD` (VBRK/VBRP/PRCD_ELEMENTS); cần cấu hình MAP `BILLTYPE` |
| Kiểm tra nghiệp vụ theo trạng thái | Trong engine (`CHECK_ACTION`) theo bảng điều kiện của FS MAG v0.5 (docs/10 §3): nháp / phát hành / huỷ nháp / điều chỉnh / gom |
| Luồng FS MAG v0.5 | Tích hợp HĐ (nháp) → Phát hành HĐ (issue-invoice trên chính bản nháp) → Cập nhật HĐ; khôi phục khi lỗi bằng tra cứu; HĐ Điều chỉnh gắn HĐ gốc; Send Email (BCS); Gom / Huỷ Gom; phát hành tự động bằng job; ghi ngược BKPF-XBLNR/XREF2_HD — 9 điểm chờ MAG xác nhận ở docs/10 §8 |
| Nguồn MM / phiếu xuất kho | Chưa cài đặt — điểm mở rộng đã có (`ZIF_HDDT_SOURCE` + `ZTB_HDDT_SRC`); xem `docs/09 §7` |
| Chương trình reorg bảng log | **Chưa có.** `ZTB_HDDT_LOG` lớn nhanh (~1 GB / 100.000 hoá đơn / năm) — 3 hướng xử lý ở [docs/08 §8](docs/08-log-tich-hop.md) |
| Job lấy lại số hoá đơn (Viettel bất đồng bộ) | **Chưa cài.** Viettel có thể trả `invoiceNo` rỗng; sau 30–90 giây phải gọi `SEARCH_INVOICE` để lấy số. Core đã đặt trạng thái `20 – Chờ cấp số`; cần job nền quét `ZTB_HDDT_INV` theo trạng thái này |

**Chưa được kích hoạt trên hệ SAP nào.** Package được viết ngoài hệ thống và
đưa lên Git; lần import đầu tiên cần một lượt activate + sửa lỗi cú pháp còn sót.
Xem [docs/06-cai-dat.md](docs/06-cai-dat.md) §5. Dynpro 0100 + GUI status: [docs/12-dynpro-alv-grid.md](docs/12-dynpro-alv-grid.md). Đưa luồng qua CPI: [docs/13-cpi-iflow-fpt.md](docs/13-cpi-iflow-fpt.md).

---

## 8. Bảo mật

- **Không lưu mật khẩu trong bảng Z** nếu tránh được: khai user/password ngay
  trong RFC destination loại G (SM59) và đặt `AUTH_MODE = 'N'`.
- Cần vault riêng (CyberArk/Vault/SSFS): implement `ZIF_HDDT_SECRET`, khai tên
  lớp vào tham số `SECRET_CLASS`. Core sẽ gọi lớp đó thay vì đọc `APISECRET`.
- Trường `APISECRET` chỉ là phương án dự phòng — hãy đặt authorization group
  cho bảng `ZTB_HDDT_CRED` (SE54 → Authorization group).
- Nút "Xem payload" chạy ở chế độ test run và **che mật khẩu** trước khi hiển thị.
- Log lưu request/response là **nghĩa vụ đối chiếu thuế**; tắt bằng
  `LOG_PAYLOAD = ''` chỉ khi đã có nơi lưu khác.

Chi tiết: [docs/02-cau-hinh.md](docs/02-cau-hinh.md) §7

---

## 9. Chuẩn đặt tên & chú thích

Toàn bộ package theo **chuẩn SAP Private Cloud / on-premise 03.09.2026**
(skill `fis-sap-private-cloud-naming`) — mỗi loại object đúng một prefix,
`HDDT` là mã dự án:

```
Z<PREFIX loại object>_HDDT_<CHỨC NĂNG>[_hậu tố]
```

| Loại | Prefix | Ví dụ |
|---|---|---|
| Report | `ZPG_` | `ZPG_HDDT_INTEGRATION` |
| Include | `ZIN_<mã>_TOP` / `_F01` | `ZIN_HDDT_INTEGRATION_TOP`, `ZIN_HDDT_INTEGRATION_F01` (prefix `ZIN_` theo yêu cầu dự án MAG, khác chuẩn `<report>_TOP` trong docs) |
| Class | `ZCL_` | `ZCL_HDDT_SERVICE` |
| Interface | `ZIF_` | `ZIF_HDDT_PROVIDER` |
| Exception | `ZCX_` | `ZCX_HDDT_ERROR` |
| Table | `ZTB_` | `ZTB_HDDT_CONN` |
| Data element | `ZDE_` | `ZDE_HDDT_TAXCODE` |
| Domain | `ZDO_` | `ZDO_HDDT_AUTH` |
| Message class | `ZMS_` | `ZMS_HDDT` |
| Transaction | `Z<MOD><3 số>` | `ZFI001` (tích hợp), `ZFI002` (cấu hình), `ZFI003` (log) |
| Package | `ZPK_` | `ZPK_HDDT_CORE` → `_DDIC/_ENGINE/_PROV/_UI` |

Biến: `LV_/LT_/LS_/LO_/LR_` cục bộ, `GV_/GT_/GS_/GO_/GC_` toàn cục, tham số
`I_/IT_/IS_`, `E_/ET_/ES_`, `C_/CT_/CS_`, `R_/RT_/RS_`, field-symbol `<FS_…>`,
màn hình chọn `P_/S_`. Text người dùng nhìn thấy (message, selection text, label
DE, text domain, cột ALV) viết tiếng Việt **có dấu**; mô tả object và comment
được phép không dấu.

Mọi object có header **Tên/Mã – Mô tả chung – Tham Số** + khối changelog.
Cột `Transport` hiện ghi `abapGit` (đưa vào bằng Git, chưa qua TR);
**điền mã TR thật khi release lần đầu**, mô tả TR dạng `DEV\<account>\<mô tả>`.

---

## 10. Sinh lại lớp DDIC

DDIC được sinh từ đặc tả gọn trong `tools/`:

```bash
python tools/gen_ddic.py    # domain / data element / bảng
python tools/gen_meta.py    # class / interface / program / message / tcode
```

Thêm trường vào bảng cấu hình = sửa `tools/gen_ddic.py` rồi chạy lại, thay vì
sửa XML bằng tay.
