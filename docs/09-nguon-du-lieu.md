# 09 — Tầng đọc dữ liệu nguồn FI / Billing SD

Tài liệu này mô tả **cách package lấy dữ liệu từ SAP** để dựng hoá đơn
(canonical model) và **các kiểm tra nghiệp vụ theo trạng thái** trước khi
gọi nhà cung cấp. Logic được port từ một dự án HĐĐT đang chạy trên SAP
Private Cloud mà người dùng đánh giá phần FI/Billing là chuẩn:

| Nguồn tham chiếu | Đã đọc |
|---|---|
| `zhddt.docx` — chương trình `ZPG_INT_E_INVOICE` (5.426 đoạn) | FORM `get_data`, `get_data_integration`, `process_status_inv`, `dieu_chinh_e_invoices`, `get_pxk`, `int_e_invoices`, `save_zgom`… |
| EEMC (DS4) — FUGR `ZFG_E_INVOICES`, package `ZPK_HDDT` | `ZFM_GET_ITEMDOC` (+ `proccess_fi`, `proccess_sd`, `process_type_EXCL`, `process_sd_no_refer_fi`), `ZFM_GET_BUYER` (+ `get_customer_detail`), `ZFM_GET_SELLER`; bảng `ZTB_E_*`, cấu trúc `ZST_*` |

Nguyên tắc khi port: **giữ logic, bỏ hằng số**. Mọi giá trị đặc thù của dự án
cũ (mã thuế `O*`, tài khoản `3331*`, loại điều kiện `ZPR0/ZC04/ZC05/ZMST`,
loại billing `ZBT`, loại số định danh `VATRU`/`FS0001`, text ID `ZI03`/`GRUN`)
đều chuyển thành bản ghi `ZTB_HDDT_MAP` / `ZTB_HDDT_PARM`. Chương trình
`ZPG_HDDT_SETUP` nạp chúng làm **ví dụ** — phải rà lại theo hệ thống của bạn.

---

## 1. Kiến trúc tầng nguồn

```
ZIF_HDDT_SOURCE            select_documents( ty_selection ) -> ty_t_request
        │                    get_doc_state( bukrs gjahr docno ) -> ty_doc_state
        ▼
ZCL_HDDT_SRC_BASE (abstract) người bán, người mua, thuế suất, chốt thuế,
        │                     tên hàng, đơn vị, thanh toán, tỷ giá, sổ đăng ký
        ├── ZCL_HDDT_SRC_FI  BKPF/BSEG/BSET (+ VBRP/ACDOCA khi AWTYP = VBRK)
        └── ZCL_HDDT_SRC_SD  VBRK/VBRP/PRCD_ELEMENTS chưa có chứng từ FI
```

- Lớp nguồn được chọn bằng `ZTB_HDDT_SRC (BUKRS, SRC_TYPE) → CLASSNAME`.
  Mặc định: `('', 'FI') → ZCL_HDDT_SRC_FI`, `('', 'SD') → ZCL_HDDT_SRC_SD`.
- Lớp nguồn là nơi **duy nhất** đọc bảng nghiệp vụ SAP. Engine cần biết chứng
  từ đã đảo/huỷ hay chưa thì gọi `get_doc_state` — không `SELECT bkpf` trong
  `ZCL_HDDT_SERVICE`.
- Tầng này thuộc **nền tảng cổ điển** (đọc bảng trực tiếp, `READ_TEXT`,
  `POPUP_GET_VALUES`). Trên Public Cloud khai lớp nguồn khác trong
  `ZTB_HDDT_SRC` (đọc CDS released) — engine/adapter không đổi.

---

## 2. Nguồn FI — `ZCL_HDDT_SRC_FI`

### 2.1 Chọn chứng từ (port từ `FORM get_data`)

| Dự án tham chiếu | Package |
|---|---|
| `BKPF INNER JOIN BSEG` với `koart = 'D'` | như cũ — một chứng từ = dòng khách hàng đầu tiên |
| `bkpf~xreversing NE 'X'` | `k~xreversing = space` — không lấy chứng từ **đảo** |
| `xreversed NE 'X' OR ( xreversed = 'X' AND serial NE '' )` | `keep_document`: chứng từ **bị đảo** chỉ giữ khi sổ `ZTB_HDDT_INV` đã có số HĐ (để huỷ) hoặc người dùng tick *Lấy cả CT đã đảo* |
| `mwskz LIKE 'O%' OR mwskz = '**'` | MAP `TAXCODE` (mẫu CP) trên mã thuế dòng khách hàng; seed `O*`, `**` |
| `ztb_e_doctype` | range `BLART` màn hình, trống → MAP `DOCTYPE`, trống nữa → mọi loại |
| `awkey IN s_vbeln`, `usnam IN s_usnam`, `s_kunnr`, `s_bldat` | các range mới của `ty_selection` |
| `status_sap IN s_status` | `r_status` so với sổ đăng ký (mặc định `00` chưa tích hợp) |

### 2.2 Header

| Trường canonical | Nguồn | Ghi chú |
|---|---|---|
| `currency` | `BKPF-WAERS` | |
| `exch_rate` | `exch_rate_of`: VND/tiền ghi sổ → 1; khác → `abs(KURSF) × EXCH_RATE_FACTOR` | dự án cũ nhân cứng 1000 → thành tham số, mặc định 1 |
| `inv_date` | `ZTB_HDDT_DATE` (1 BUDAT / 2 CPUDT / 3 SY-DATUM / 4 BLDAT) rồi **cap** `INV_DATE_MAX_BACKDAYS` | dự án cũ: `IF sy-datum - date > 1 THEN sy-datum - 1` → tham số, seed `1` |
| `note` | `BKPF-BKTXT` | |
| `contract_no` | `VBKD-BSTKD` của đơn bán (khi có billing) | dự án cũ đưa vào `bstkd` |
| `payments` | `BSEG-ZLSCH` dòng khách → không có thì `VBRK-ZLSCH` → không có thì `DEFAULT_PAYMENT` | MAP `PAYMENT` |
| `src_info` | BLART/BUDAT/BLDAT/CPUDT/USNAM/XBLNR/KUNNR/AWTYP/AWKEY/XREVERSED/STBLG/STJAH | engine dùng để kiểm tra |

### 2.3 Dòng hàng (port từ `proccess_fi` / `process_type_EXCL`)

| Bước | Dự án tham chiếu | Package |
|---|---|---|
| Lọc dòng | `koart = 'S' AND mwskz <> ''`, `hkont IN ztb_e_glaccount`, trừ `3331020000/3331010000/3331001000` | `koart = 'S' AND mwskz <> space`; MAP `GLACCT` (nếu khai); MAP `TAXACCT` (seed `3331*`) |
| Dấu | `H → +dmbtr`, `S → −dmbtr` (×100 vì kiểu chuỗi) | `H → +WRBTR`, `S → −WRBTR` — **nguyên tệ**; VND quy đổi qua `exch_rate` |
| Số lượng | `menge`; user yêu cầu **luôn dương** (`abs`) | `MENGE`; `ITEM_QTY_ABS = X` |
| Đơn giá | `dmbtr / menge` | `amount / quantity` |
| Tên hàng FI | `zlongtext` → `sgtxt` | `SGTXT` → `MAP GLACCT ext_text` → `MAKT` → số TK |
| Tên hàng CT từ SD | text `ZI03/VBBP` → `GRUN/MATERIAL` → `MAKT`; nối qua `ACDOCA` (kdauf/kdpos hoặc awref/awitem) | `ITEM_TEXT_IDS` = `ZI03:VBBP;GRUN:MATERIAL` → `MAKT` → `VBRP-ARKTX`; nối `ACDOCA (AWREF, AWITEM) → VBRP` |
| Đơn vị | `T006A-MSEHL spras 'E'` | `unit_text` theo `TEXT_LANGU` (seed `E`), fallback ngôn ngữ đăng nhập |
| Thuế suất | `OX → -2`, `OG → -1`, còn lại `RECP_FI_TAX_CALCULATE` | MAP `TAXRATE` (seed `OX → -2`, `OG → -1`) → `BSET-KBETR/10` → `A003/KONP` (`TAX_COND_TYPE`, mặc định `MWAS`) |
| Tiền thuế dòng | `round( dmbtr × rate / 100, 0 )` | `line_tax`: VND 0 lẻ, ngoại tệ 2 lẻ |
| Chốt theo sổ | tổng `vat_dmbtr` theo `mwskz` so `BSET-HWSTE` (S → âm), chênh lệch cộng vào **dòng cuối** cùng mã thuế | `taxes_from_bset` (FWSTE/HWSTE, dấu S → âm) + `reconcile_tax` — chênh lệch vào **dòng cuối** cùng thuế suất |
| `tax_t` "Nhiều loại" | so `taxpercentage` các dòng | `rate_summary` → `invoice-ext TAX_RATE_SUMMARY`, cột *Thuế suất* trên ALV |

Bỏ qua có chủ ý: nhánh `ZO02` đọc service entry sheet BOQ (`/SAPBOQ/SES3`
qua `CALL TRANSACTION` + `ESLH/ESLL`) — đặc thù một khách hàng, không port.

---

## 3. Nguồn Billing SD chưa có FI — `ZCL_HDDT_SRC_SD`

Port từ nhánh *Billing No FI* (`vbrk~fkart IN ('FP','ZBT')`, `vbeln NOT IN
acdoca`) và `process_sd_no_refer_fi`.

| Bước | Dự án tham chiếu | Package |
|---|---|---|
| Chọn | `VBRK` theo `fkdat`, `kunrg`, `fkart IN (…)`, `fksto = '' OR (fksto = 'X' AND seq NE '')` | MAP `BILLTYPE` **bắt buộc** (không có → báo lỗi rõ); `keep_document` với `FKSTO` |
| Loại billing đã có FI | `vbeln NOT IN lt_acdoca` | `BKPF AWTYP = 'VBRK' AND AWKEY IN (…)` → bỏ (nguồn FI xử lý) |
| Năm | không có | `GJAHR` sổ đăng ký = năm dương lịch của `FKDAT` (ghi rõ để tránh nhầm với năm tài chính lệch) |
| Dòng hàng | `PRCD_ELEMENTS` với `ZPR0 (+)`, `ZC04/ZC05 (−)`, `ZMST (thuế, kbetr = thuế suất)` | MAP `CONDTYPE` `SAP_VALUE = KSCHL`, `EXT_VALUE = AMT+ / AMT- / TAX`; **không cấu hình** → `VBRP-NETWR` + `MWSBP`, thuế suất từ MAP `TAXRATE` theo `VBRP-MWSKZ`, fallback tỷ lệ |
| Người mua | `kunrg` | `read_buyer( KUNRG, aubel )` — không có BSEC |
| Thuế | không có BSET | `AGGREGATE_INVOICE` gộp từ dòng hàng |

---

## 4. Người bán / người mua — `ZCL_HDDT_SRC_BASE`

### Người bán (`ZFM_GET_SELLER`)
`T001 (BUTXT, STCEG, ADRNR)` → `ADRC` (NAME1+NAME2, địa chỉ ghép
`street str_suppl1, str_suppl2, str_suppl3, location, city2, city1`, điện
thoại) → `ADR6` email đầu tiên. Cache theo `BUKRS`. Bật bằng
`SELLER_FROM_T001 = X` (mặc định); tham số `SELLER_*` chỉ điền chỗ trống.

### Người mua (`ZFM_GET_BUYER` + `get_customer_detail`)

| Trường hợp | Nguồn | Ghi chú |
|---|---|---|
| **Khách lẻ** (có `BSEC` cho chứng từ) | NAME1..4, STRAS + ORT01, STCD1/STCD3, INTAD, BANKS/BANKL/BANKN → BNKA | `one_time = X`, **không cache** |
| Khách có mã | `CVI_CUST_LINK → BUT000` (không có link → `BUT000-PARTNER = KUNNR`) | cache theo `KUNNR` |
| Tên | `TYPE = 1` cá nhân: `NAME_FIRST NAME_LAST`; tổ chức: ghép các trường trong `BUYER_NAME_FIELDS` (seed `NAME_ORG1..4`; dự án cũ dùng `ORG2..4` rồi fallback `ORG1`) | |
| Địa chỉ | `BUT020` số địa chỉ **lớn nhất** → `ADRC` | ghép rồi `clean_address` (gộp `, ,`, cắt đầu/cuối), hậu tố `ADDR_COUNTRY_SUFFIX` cho VN (seed `Việt Nam`, `-` = không), nước khác lấy `T005T` |
| MST | `BUT0ID TYPE = BUYER_TAX_IDTYPE` (seed `VATRU`) → fallback `KNA1-STCD1/STCD3` | |
| CCCD | `BUT0ID TYPE = BUYER_ID_IDTYPE` (seed `FS0001`) → `buyer-id_number` | |
| Email / điện thoại | tất cả `ADR6` / `ADR2`, nối bằng `;` | như dự án cũ |
| Ngân hàng | `BSEG-BVTYP` → `BUT0BK (BKVID)` → `BNKA-BANKA` | |
| Số tham chiếu KH | `VBKD-BSTKD` của đơn bán | `buyer-ref_no`, đưa vào `header-contract_no` |
| Không có BP | `KNA1 + ADRC + ADR6` | fallback cho hệ chưa CVI |

---

## 5. Kiểm tra nghiệp vụ theo trạng thái — `ZCL_HDDT_SERVICE=>CHECK_ACTION`

Port từ `get_data_integration` và `dieu_chinh_e_invoices`, chạy ở **engine**
(bước 4b, sau `fill_defaults`, áp cả Test run) để job/BAPI cũng bị chặn.
Tắt bằng `STATUS_CHECK = N`.

Ánh xạ trạng thái dự án cũ → package:

| Cũ | Ý nghĩa | Package `ZDO_HDDT_STATUS` |
|---|---|---|
| 01 | chưa tích hợp | 00 |
| 02 | đã lập nháp | 30 (chờ duyệt) |
| 03 | lỗi | 90 |
| 04 / 05 | huỷ / huỷ gom | 80 |
| 06 | bị điều chỉnh | 60 |
| 07 | bị thay thế | 70 |
| 98 | phát hành, chưa gửi CQT | 40 |
| 99 | phát hành thành công | 50 |
| 09 / 10 | đang xử lý | 10 / 20 |

| Nghiệp vụ | Điều kiện (lỗi nếu vi phạm) |
|---|---|
| Phát hành / nháp / xem trước | trạng thái sổ ∈ {00, 90}; chứng từ **chưa** đảo/huỷ |
| Điều chỉnh / thay thế | chứng từ hiện tại ∈ {00, 90} và chưa đảo; **HĐ gốc**: phải có (ký hiệu/số hoặc chứng từ SAP); trong sổ; trạng thái ∈ {40, 50, 60, 10, 20}; không phải 70/80; cùng khách hàng; cùng loại tiền; **thay thế** thêm: chứng từ gốc đã đảo (`get_doc_state`) |
| Huỷ / xoá / thông báo sai sót | đã có trong sổ và trạng thái ∉ {00, 90, 80}; chứng từ SAP **đã đảo** (`CANCEL_REQUIRES_REVERSAL`, `N` để tắt) |
| Tra cứu / lấy file / gửi mail | đã có trong sổ |

Sau khi HĐ điều chỉnh / thay thế thành công, `ZCL_HDDT_LOG=>MARK_ORIGINAL`
đổi trạng thái HĐ gốc thành 60 / 70 (dự án cũ ghi `XREF2_HD = 06/07`).

Chọn HĐ gốc trên màn hình: nếu sổ chưa có `REF_DOCNO`, `FORM fill_original`
hỏi số chứng từ / năm gốc bằng `POPUP_GET_VALUES` (như popup `TYPE_DC / BELNR /
GJAHR` của dự án cũ) rồi truyền `adjust-org_docno/org_gjahr/org_src_type`
cho engine.

---

## 6. Tham số và ánh xạ mới

| `PARM_KEY` | Seed | Ý nghĩa |
|---|---|---|
| `INV_DATE_MAX_BACKDAYS` | `1` | ngày lập HĐ lùi tối đa N ngày; trống = không giới hạn |
| `BUYER_TAX_IDTYPE` / `BUYER_ID_IDTYPE` | `VATRU` / `FS0001` | loại số định danh BP chứa MST / CCCD (mặc định trong code: `VATRU` / trống = không lấy CCCD) |
| `BUYER_NAME_FIELDS` | `NAME_ORG1,NAME_ORG2,NAME_ORG3,NAME_ORG4` | trường BUT000 ghép tên tổ chức |
| `ADDR_COUNTRY_SUFFIX` | `Việt Nam` | hậu tố địa chỉ VN; `-` = không thêm |
| `EXCH_RATE_FACTOR` | `1` | hệ số nhân KURSF |
| `SELLER_FROM_T001` | `X` | người bán từ T001/ADRC |
| `TEXT_LANGU` | `E` | ngôn ngữ MSEHL / MAKTX |
| `ITEM_TEXT_IDS` | `ZI03:VBBP;GRUN:MATERIAL` | long text lấy tên hàng, theo thứ tự (mặc định trong code: `GRUN:MATERIAL`) |
| `ITEM_QTY_ABS` | `X` | số lượng luôn dương |
| `DEFAULT_PAYMENT` | `TM/CK` | hình thức thanh toán khi không có ZLSCH |
| `TAX_COND_TYPE` | `MWAS` | loại điều kiện thuế đầu ra (A003/KONP) |
| `STATUS_CHECK` | `X` | `N` = tắt kiểm tra nghiệp vụ |
| `CANCEL_REQUIRES_REVERSAL` | `X` | `N` = cho huỷ HĐĐT khi chứng từ chưa đảo |

| `MAP_TYPE` | `SAP_VALUE` | `EXT_VALUE` | Seed ví dụ |
|---|---|---|---|
| `TAXCODE` | mẫu MWSKZ (CP) | `X` | `O*`, `**` |
| `TAXACCT` | mẫu tài khoản | `X` | `3331*` |
| `BILLTYPE` | `VBRK-FKART` | `X` | `ZBT` |
| `CONDTYPE` | `KSCHL` | `AMT+` / `AMT-` / `TAX` | `ZPR0`, `ZC04`, `ZC05`, `ZMST` |
| `TAXRATE` | `MWSKZ` | thuế suất (`-1`, `-2`, `10`) | `OX → -2`, `OG → -1` |

---

## 7. Chưa port (còn mở)

| Hạng mục dự án cũ | Lý do / hướng |
|---|---|
| Hoá đơn **gom** (`ZGOM_INV`, `ztb_e_gomh/goml/map_gom`, `NUMBER_GET_NEXT`) | nghiệp vụ riêng; cần lớp nguồn `GOM` + bảng gom — interface đã có |
| **Phiếu xuất kho** (`get_pxk`: MKPF/MSEG, `ztb_e_bwart`, RESB) | lớp nguồn `MM`/`PXK` riêng |
| Ghi ngược `BKPF` (`XREF1_HD` ngày, `XBLNR` ký hiệu#số, `XREF2_HD` 04/06/07) | UPDATE trực tiếp BKPF — cân nhắc BAPI/`FI_DOCUMENT_CHANGE`; hiện trạng thái nằm ở `ZTB_HDDT_INV` |
| `ZLONGTEXT` trên BSEG | trường Z của khách hàng |
| Service entry sheet BOQ (`ZO02`) | đặc thù |
| `ztb_e_status` (mã NCC → trạng thái + `gom_flag`) | đã có `ZTB_HDDT_STAT` |

**[Unverified]** trên hệ thật: tên trường `BSEC-BANKS/BANKL/BANKN/INTAD`,
`ACDOCA-BUZEI = BSEG-BUZEI` cho chứng từ billing, `PRCD_ELEMENTS-KINAK`,
`KONP-LOEVM_KO`. Cần activate + syntax check ở lần import đầu.

## Chọn nhiều loại nguồn trên màn hình

`s_srct` là SELECT-OPTIONS, không phải tham số đơn:

- để trống: đọc mọi loại nguồn đang hoạt động trong `ZTB_HDDT_SRC` của công ty
  (dòng có `BUKRS` trống áp cho mọi công ty);
- chọn nhiều loại: đọc lần lượt từng loại rồi gộp vào một danh sách, cột
  `Loại nguồn` trên ALV cho biết dòng đến từ đâu;
- một loại lỗi cấu hình thì các loại còn lại vẫn hiện, lỗi báo dạng cảnh báo.

Chứng từ gom (`GOM`) gom được thành viên thuộc **nhiều loại nguồn khác nhau**.
`ZCL_HDDT_SRC_GOM` nhóm thành viên theo `SRC_TYPE`, gọi đúng lớp đọc của từng
loại rồi mới trộn dòng hàng. Trước đây lớp này cố định đọc FI nên thành viên SD
bị bỏ lặng lẽ.

[Unverified] Ghi ngược số hoá đơn về chứng từ nguồn vẫn chỉ áp dụng cho thành
viên FI, vì `ZCL_HDDT_WRITEBACK_FI` ghi vào `BKPF`; billing SD không có BKPF nên
bị bỏ qua có chủ đích.
