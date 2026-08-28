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
      SAP GUI (ZFI_HDDT)            Job nền / BAPI / Enhancement
               │                                │
               └───────────────┬────────────────┘
                               ▼
                    ZFIC_HDDT_SERVICE            ← CỬA VÀO DUY NHẤT
                               │
        ┌──────────────────────┼────────────────────────┐
        ▼                      ▼                        ▼
 ZFIC_HDDT_CONFIG      ZFIC_HDDT_FACTORY         ZFIC_HDDT_HTTP
 (đọc bảng cấu hình)   (CREATE OBJECT động)      (REST theo cấu hình)
                               │
                               ▼
                    ZFIIF_HDDT_PROVIDER          ← HỢP ĐỒNG
                               │
      ┌────────────────┬───────┴────────┬──────────────────┐
      ▼                ▼                ▼                  ▼
 PROV_VIETTEL      PROV_FPT       PROV_TEMPLATE        PROV_VNPT
 (SInvoice)      (FPT eInvoice)  (theo mẫu cấu hình)  (kế thừa TEMPLATE)
```

**Điểm cốt lõi:** trong toàn bộ `ZFIC_HDDT_SERVICE`, `ZFIC_HDDT_HTTP`,
`ZFIC_HDDT_CONFIG`, `ZFIC_HDDT_LOG` và chương trình SAP GUI **không có một chuỗi
`'VIETTEL'` / `'FPT'` / `'VNPT'` nào**. Tên lớp adapter được đọc từ
`ZFIT_HDDT_PROV-CLASSNAME` rồi `CREATE OBJECT ... TYPE (lv_class)`.

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
1. ZFI_HDDT_CFG → bảng ZFIT_HDDT_CRED
   Thêm dòng:  PROVIDER=FPT, BUKRS=1000, TAXCODE, TEMPLATE, SERIAL,
               APIUSER, CONNID=PRD, VALID_FROM = ngày cắt chuyển
   Sửa dòng Viettel: VALID_TO = ngày cắt chuyển - 1

2. Bảng ZFIT_HDDT_PARM
   PROVIDER='' BUKRS=1000 PARM_KEY=ACTIVE_PROVIDER PARM_VAL=FPT

3. SM59 → tạo destination cho FPT (hoặc điền BASE_URL trong ZFIT_HDDT_CONN)

4. Xong. Chạy lại ZFI_HDDT.
```

Hoá đơn đã phát hành bằng Viettel vẫn tra cứu / huỷ / điều chỉnh được, vì
`ZFIT_HDDT_INV` lưu `PROVIDER` của từng hoá đơn.

Runbook đầy đủ (kể cả rollback): [docs/07-doi-nha-cung-cap.md](docs/07-doi-nha-cung-cap.md)

---

## 4. Cài đặt

```
1. abapGit → New Online → https://github.com/cuongus/ZPK_HDDT_CORE.git
   Package: ZPK_HDDT_CORE   (tạo trước, gán transport layer)
2. Pull → Activate all (DDIC trước, code sau)
3. SE11: sinh Table Maintenance Generator cho 14 bảng ZFIT_HDDT_*
4. SE38 → ZFIR_HDDT_SETUP → bỏ tick "Chi mo phong" → nạp cấu hình khởi tạo
5. SM59: tạo RFC destination loại G cho nhà cung cấp
6. ZFI_HDDT_CFG: khai ZFIT_HDDT_CRED + ACTIVE_PROVIDER
7. ZFI_HDDT: chạy với tick "Test run" để xem payload trước khi gửi thật
```

Chi tiết + phân quyền + STRUST: [docs/06-cai-dat.md](docs/06-cai-dat.md)

---

## 5. Nội dung package

| Subpackage | Nội dung |
|---|---|
| `ZPK_HDDT_CORE_DDIC` | 10 domain, 42 data element, 14 bảng (cấu hình + log + sổ hoá đơn) |
| `ZPK_HDDT_CORE_ENGINE` | 4 interface, 10 class, message class `ZFIE_HDDT` |
| `ZPK_HDDT_CORE_PROV` | 5 class adapter (base, Viettel, FPT, Template, VNPT) |
| `ZPK_HDDT_CORE_UI` | 3 report (tích hợp / cấu hình / setup), 5 include, 2 transaction |

### Bảng cấu hình

| Bảng | Vai trò |
|---|---|
| `ZFIT_HDDT_PROV` | Danh mục nhà cung cấp → **tên lớp adapter** |
| `ZFIT_HDDT_CONN` | RFC destination / base URL / cách xác thực / timeout / SSL |
| `ZFIT_HDDT_ACT` | Đường dẫn API theo từng nghiệp vụ, hỗ trợ placeholder `{taxcode}` |
| `ZFIT_HDDT_CRED` | Tài khoản API, MST, mẫu số, ký hiệu theo công ty + hiệu lực |
| `ZFIT_HDDT_STAT` | Mã trả về của NCC → trạng thái trong SAP |
| `ZFIT_HDDT_MAP` | Thuế suất, hình thức thanh toán, tài khoản doanh thu |
| `ZFIT_HDDT_PARM` | Tham số chung (nhà cung cấp đang dùng, thông tin bên bán…) |
| `ZFIT_HDDT_DATE` | Nguồn ngày lập hoá đơn theo công ty |
| `ZFIT_HDDT_SRC` | Lớp đọc chứng từ nguồn (FI/SD/MM/GOM/CUST) |
| `ZFIT_HDDT_TPL` | Mẫu payload cho adapter dạng template |
| `ZFIT_HDDT_TOK` | Bộ đệm access token |
| `ZFIT_HDDT_INV` | Sổ đăng ký hoá đơn đã tích hợp |
| `ZFIT_HDDT_ITEM` | Chi tiết hàng hoá đã phát hành |
| `ZFIT_HDDT_LOG` | Log request/response từng lần gọi API |

Mô tả trường: [docs/02-cau-hinh.md](docs/02-cau-hinh.md)

---

## 6. Gọi từ code khác

```abap
DATA(lo_svc) = zfic_hddt_service=>get_instance( ).

DATA(ls_req) = VALUE zfiif_hddt_types=>ty_request(
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
| Adapter **Viettel** | Endpoint đã đối chiếu Postman collection (mục 7.2–7.37). **Tên thẻ JSON** dựng theo mã ABAP đang chạy thật ở hệ EEMC — cần đối chiếu lại tài liệu Viettel v2.44 mục 7.2 trước khi go-live |
| Adapter **VNPT/Vinaphone** | **Chưa có tài liệu API** trong bộ tài liệu được cung cấp. Adapter kế thừa `ZFIC_HDDT_PROV_TEMPLATE`: dán mẫu payload vào `ZFIT_HDDT_TPL` là chạy, không phải viết ABAP |
| Lớp đọc dữ liệu nguồn FI | Cài đặt mặc định hợp lý (BKPF/BSEG/BSET). Nghiệp vụ từng khách hàng khác nhau → copy `ZFIC_HDDT_SRC_FI`, sửa, trỏ lại `ZFIT_HDDT_SRC` |
| Nguồn SD / MM / hoá đơn gom | Chưa cài đặt — điểm mở rộng đã có (`ZFIIF_HDDT_SOURCE` + `ZFIT_HDDT_SRC`) |

**Chưa được kích hoạt trên hệ SAP nào.** Package được viết ngoài hệ thống và
đưa lên Git; lần import đầu tiên cần một lượt activate + sửa lỗi cú pháp còn sót.
Xem [docs/06-cai-dat.md](docs/06-cai-dat.md) §5.

---

## 8. Bảo mật

- **Không lưu mật khẩu trong bảng Z** nếu tránh được: khai user/password ngay
  trong RFC destination loại G (SM59) và đặt `AUTH_MODE = 'N'`.
- Cần vault riêng (CyberArk/Vault/SSFS): implement `ZFIIF_HDDT_SECRET`, khai tên
  lớp vào tham số `SECRET_CLASS`. Core sẽ gọi lớp đó thay vì đọc `APISECRET`.
- Trường `APISECRET` chỉ là phương án dự phòng — hãy đặt authorization group
  cho bảng `ZFIT_HDDT_CRED` (SE54 → Authorization group).
- Nút "Xem payload" chạy ở chế độ test run và **che mật khẩu** trước khi hiển thị.
- Log lưu request/response là **nghĩa vụ đối chiếu thuế**; tắt bằng
  `LOG_PAYLOAD = ''` chỉ khi đã có nơi lưu khác.

Chi tiết: [docs/02-cau-hinh.md](docs/02-cau-hinh.md) §7

---

## 9. Chuẩn đặt tên & chú thích

Toàn bộ package theo `fis-sap-naming-convention-cuongus`:

```
Z <MOD=FI> <T> _ HDDT _ <TÊN NGHIỆP VỤ>
```

| Loại | Prefix | Ví dụ |
|---|---|---|
| Report | `ZFIR_` | `ZFIR_HDDT_INTEGRATION` |
| Include | `ZFIR_..._TOP/_SEL/_CL1/_EVT/_F01` | `ZFIR_HDDT_INT_F01` |
| Class | `ZFIC_` | `ZFIC_HDDT_SERVICE` |
| Interface | `ZFIIF_` | `ZFIIF_HDDT_PROVIDER` |
| Exception | `ZFICX_` | `ZFICX_HDDT_ERROR` |
| Table | `ZFIT_` | `ZFIT_HDDT_CONN` |
| Data element | `ZFIDE_` | `ZFIDE_HDDT_TAXCODE` |
| Domain | `ZFIDO_` | `ZFIDO_HDDT_AUTH` |
| Message class | `ZFIE_` | `ZFIE_HDDT` |
| Transaction | `ZFI_` | `ZFI_HDDT`, `ZFI_HDDT_CFG` |

Mọi object có header **Tên/Mã – Mô tả chung – Tham Số** + khối changelog.
Cột `Transport` hiện ghi `abapGit` (đưa vào bằng Git, chưa qua TR);
**điền mã TR thật khi release lần đầu**.

---

## 10. Sinh lại lớp DDIC

DDIC được sinh từ đặc tả gọn trong `tools/`:

```bash
python tools/gen_ddic.py    # domain / data element / bảng
python tools/gen_meta.py    # class / interface / program / message / tcode
```

Thêm trường vào bảng cấu hình = sửa `tools/gen_ddic.py` rồi chạy lại, thay vì
sửa XML bằng tay.
