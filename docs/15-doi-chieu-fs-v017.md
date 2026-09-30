# 15 — Đối chiếu FS Tích hợp HĐĐT bản 16/09/2026 với code ZPK_INT_HDDT

Nguồn:

- `MAG_SAP_2026_PM_FS_Tich hop HDDT_v0.1 (1).docx` (16/09/2026) so với bản 05/09/2026
- `MAG_SAP_2026_PM_FS_Tich hop HDDT_TomTatThayDoi_14-16.09.2026 (1).xlsx` — 32 thay đổi, chủ đề A–H
- Code đọc từ bridge MAG_S25_300 ngày 22/09/2026 (136 object). Source ABAP độc lập
  client nên bản đọc từ client 300 trùng bản đang chạy ở client 100.

Tài liệu này **chỉ phân tích**, chưa sửa dòng code nào.

### Quyết định đã chốt (22/09/2026)

| # | Vấn đề | Chốt |
|---|---|---|
| 1 | Sáu bảng cấu hình kỹ thuật (`PROV`, `CONN`, `ACT`, `TPL`, `MAP`, `STAT`) | **Không thêm BUKRS.** Phân quyền bằng lớp quyền T-code |
| 2 | Nguồn tên / MST / địa chỉ nhà cung cấp (Nhóm 2) | **LFA1**, cùng cách đang lấy customer |
| 3 | Kiểu `buyer_code` | **Đổi** để chứa được cả KUNNR và LIFNR |
| 4 | Chuyển `ZPG_HDDT_CONFIG` sang view cluster | **Không nên** — xem mục M |
| 5 | Gọi VF11 / MR8M / FB08 bằng BAPI có lấy được lỗi không | **Có** — xem mục F |

### Trạng thái triển khai (23/09/2026, MAG_S25_100, TR S25K900131)

Đã deploy và kích hoạt cả 14 mục A–N, 0 object inactive.

| Mục | Object chính |
|---|---|
| A | `ZIN_HDDT_INTEGRATION_TOP` (fcode `ZREPL`), `_F01` (nút Thay thế, 13 nút) |
| B | `ZCL_HDDT_SRC_FI` đọc `REBZG`/`REBZJ`; ALV 2 cột cuối Source Accounting doc / Source Fiscal year; bỏ `FORM popup_original` |
| C | `SRC_FI=>ADJUST_DIR` (cộng ròng TK doanh thu); bỏ adjtype 4 ở SERVICE / PROV_FPT / F01 |
| D | `PROV_BASE=>BUILD_ADJUST_NOTE` đúng cú pháp FS; `ADJUST_REASON` cắt 100 cho `inv.adj.rea` |
| E | `PROV_FPT` không truyền `aun` cho adjust/replace; `SERVICE` gỡ 3 chỗ chặn theo FS cũ (`resolve_adjust`, `create_draft`, `issue_invoice`); HĐ gốc chỉ chuyển 07/08 khi issue |
| F | Class mới `ZCL_HDDT_REVERSAL` (VF11/MR8M/FB08 qua BAPI); `SERVICE=>DELETE_DRAFT` 2 phương án, huỷ SAP trước; pop-up `POPUP_TO_DECIDE` + Lý do/Ngày huỷ |
| G | `SERVICE=>REPLACE_WITH_REVERSAL`, `CANCEL_SOURCE_DOCS`, `ORIGINAL_OF`, `MARK_GOM_REPLACED`; `GOM=>MARK_REPLACED`; `LOG=>SET_STATUS`, `RETIRE_INVOICE`; pop-up liệt kê chứng từ sẽ bị huỷ |
| H | `GOM=>CHECK_STATUS` chặn gỡ gom ở 03/99/10 |
| I | Bảng `ZTB_HDDT_PO`, class mới `ZCL_HDDT_SRC_PO` (kế thừa SRC_FI, 3 điểm móc), `SRC_BASE=>READ_VENDOR` (LFA1), domain `ZDO_HDDT_SRCTYPE` thêm `PO`, `buyer_code` → `ZDE_HDDT_PARTNER` |
| J | `SRC_SD` kiểm `SFAKN`, mang số Billing sang VF11; `s_vbeln FOR vbrk-vbeln` |
| K | `SRC_FI=>DROP_REVERSED_PAIRS`; `SRC_BASE=>KEEP_DOCUMENT` loại mọi chứng từ đã huỷ trừ trạng thái Lỗi tích hợp |
| L | `ZTB_HDDT_CRED` khoá + `GJAHR` + `TEMPLATE`; `CONFIG` chọn dải số theo năm, `CHECK_DEFAULT`; event 01 SM30 chặn lưu 2 Default |
| M | `ZPG_HDDT_CONFIG` pop-up Company Code + `F_BKPF_BUK` 02, lọc BUKRS bằng `DBA_SELLIST` |
| N | Message 054–071 (thêm 070, 071 ngoài danh sách FS); sửa 018 bị cắt cụt |

**Việc phải làm tay trên SAP GUI** (ADT không có endpoint):

1. SE54 — **sinh lại** table maintenance cho `ZTB_HDDT_CRED` (khoá đã đổi).
2. SE54 — sinh table maintenance cho bảng mới `ZTB_HDDT_PO` trong `ZFG_VM_HDDT`, khai event 01 = `ZALV_SET_AUDIT`.
3. Chạy `ZPG_HDDT_SETUP` với `p_base` + `p_mag`, bỏ `p_test` (tích `p_ovwrt` để ghi đè `AUTO_APPR_REPL`) — nạp dòng nguồn `PO`, cấu hình ZPO6 / I\* / 1331\*, Billing ZF04 / ZF05.

**Chỗ FS tự mâu thuẫn — đã chọn:**

- Mục 3.6.2 bắt buộc huỷ SAP trước, nhưng test 3d mô tả xoá nháp trước → theo thứ tự bắt buộc.
- Nhóm 3 "FKSTO trống chỉ áp dụng lần đầu" ngược với "chứng từ đã huỷ không lấy lên" → theo quy tắc sau (chặt hơn, thống nhất với FI).
- HĐ gom bị thay thế: test 10e ghi 08 ngay khi huỷ, thân mục 3.6.5 ghi 08 sau khi phát hành → theo thân mục (sau phát hành).

**Chưa làm theo FS:** cột Document Number để trống với bản ghi Nhóm 3 — `src_docno` là khoá đang được logic gom / log / sửa ngày dùng, làm trống sẽ gãy các chức năng đó.

---

## 0. Bảng tổng hợp mức độ ảnh hưởng

| # | Thay đổi FS | Object phải sửa | Mức |
|---|---|---|---|
| A | Tách nút "Thay thế" khỏi "Điều chỉnh" (8 → 9 nút) | TOP, F01, SERVICE | Trung bình |
| B | Bỏ pop-up chứng từ gốc, đọc `BSEG-REBZG` / `REBZJ` | TYPES, SRC_FI, F01, SERVICE | Lớn |
| C | `adjtype` tự suy theo chiều ghi sổ TK 5\* | SRC_FI, SERVICE, PROV_FPT, DOMA | Lớn |
| D | `inv.note` 255 tự dựng + `inv.adj.rea` cắt 100 | PROV_BASE, PROV_FPT | Nhỏ |
| E | Điều chỉnh / Thay thế đi qua bước NHÁP (`inv.aun` trống) | PROV_FPT, SERVICE, STAT | Lớn |
| F | "Hủy HĐ nháp" 2 phương án, huỷ chứng từ SAP TRƯỚC | F01, SERVICE, class mới | **Rất lớn** |
| G | "Thay thế" huỷ chứng từ gốc trước; HĐ gom huỷ cả cụm | SERVICE, GOM, class mới | **Rất lớn** |
| H | "Huỷ Gom HĐ" chặn khi HĐ gom đã phát hành | GOM | Nhỏ |
| I | Nhóm 2 — hoá đơn đầu vào trả lại hàng NCC (ZPO6 / I\* / 1331\*) | Bảng + class nguồn mới | **Rất lớn** |
| J | Nhóm 3 — Billing SD chưa có FI (ZF04 / ZF05) | SRC_SD, TOP | Nhỏ (phần lớn đã có) |
| K | Loại cặp chứng từ đảo theo `BKPF-AWREF_REV` | SRC_FI | Trung bình |
| L | Dải số: thêm GJAHR vào khoá, Default theo BUKRS+GJAHR | CRED, CONFIG, F01, gen_ddic | Trung bình |
| M | Màn hình cấu hình: pop-up BUKRS + phân quyền (giữ report, không view cluster) | ZPG_HDDT_CONFIG, SE54 event | Trung bình |
| N | ~12 message mới | ZMS_HDDT | Nhỏ |

---

## A. Tách nút "Thay thế" — ALV lên 09 nút

FS 3.6.4 (Điều chỉnh) và 3.6.5 (Thay thế) nay là hai mục, hai luồng độc lập. Các
mục sau bị đánh số lại: Cập nhật HĐ 3.6.5→3.6.6, Send Email →3.6.7, Gom HĐ
→3.6.8, Huỷ Gom →3.6.9, phát hành tự động →3.6.10, xử lý lỗi →3.6.11.

Code hiện tại gộp cả hai vào một nút `ZADJREF` nhãn "HĐ Điều chỉnh":

- `src/ui/zin_hddt_integration_top.prog.abap` — `gc_fcode` chỉ có `adjref`.
  Thêm hằng `repl TYPE salv_de_function VALUE 'ZREPL'`.
- `src/ui/zin_hddt_integration_f01.prog.abap`
  - `on_toolbar` — thêm một dòng `stb_button`, đổi nhãn `'HĐ Điều chỉnh'` → `'Điều chỉnh'`.
  - `dispatch` — thêm `WHEN gc_fcode-repl. do_replace( ).`
  - `do_adjust_ref` — đổi tên thành `do_adjust`, viết lại (xem mục B).
  - thêm `do_replace` mới.
- Comment "12 nút nghiệp vụ" trong `on_toolbar` phải sửa thành 13.

Thanh công cụ hiện có 12 nút (8 nút FS + Sửa ngày/giờ + Lấy file + Xem payload +
Log), thêm nút thứ 13. Đây là toolbar tự vẽ trong code nên không đụng GUI status.

## B. Bỏ pop-up chứng từ gốc — đọc thẳng BSEG-REBZG / REBZJ

FS mới: kế toán điền số/năm chứng từ gốc vào `BSEG-REBZG` / `BSEG-REBZJ` trên
dòng công nợ ngay khi hạch toán. Chương trình bốc hai trường này lên ALV thành
hai cột **Source Accounting doc** / **Source Fiscal year**, chỉ đọc. Hai nút
Điều chỉnh / Thay thế đọc thẳng hai cột đó, không bắn màn hình.

Code hiện tại làm ngược lại: người dùng nhập tay qua pop-up rồi mới ghi vào sổ.

| Hiện tại | Phải đổi |
|---|---|
| `FORM popup_original` (F01, ~dòng 2417) — pop-up 3 trường: số CT gốc, năm, loại ĐC | Bỏ hẳn, không còn caller |
| `do_adjust_ref` gọi `popup_original` rồi `mo_service->attach_original(...)` | Đọc `gt_alv[]-ref_docno` / `-ref_gjahr` do tầng nguồn đã điền |
| `ZCL_HDDT_SERVICE=>attach_original` / `attach_original_locked` | Không còn là "gắn theo nhập tay"; giữ lại làm hàm tra cứu HĐ gốc hoặc bỏ |
| `ZIF_HDDT_TYPES=>ty_src_info` — không có `rebzg` / `rebzj` | Thêm hai trường |
| `ZCL_HDDT_SRC_FI` — SELECT `bkpf` + `bseg` (~dòng 200) đã lấy `s~kunnr`, `s~mwskz` từ dòng công nợ | Lấy thêm `s~rebzg`, `s~rebzj` cùng dòng `koart = 'D'` |
| `gty_alv-ref_docno` / `-ref_gjahr` (TOP, dòng 69-70) | Giữ nguyên trường, đổi nhãn sang "Source Accounting doc" / "Source Fiscal year", set không cho sửa trong `build_fcat` |
| `ZTB_HDDT_INV-ref_docno` / `ref_gjahr` | Giữ, nhưng nay điền lúc đọc dữ liệu chứ không phải lúc người dùng bấm nút |

Việc suy hoá đơn gốc (`ZCL_HDDT_SERVICE=>resolve_adjust`, ~dòng 1507) đã đọc
`read_invoice( ref_docno / ref_gjahr )` rồi — phần này **giữ nguyên được**, chỉ
đổi nguồn của `ref_docno`.

Điều kiện lỗi mới cần thêm: trống một trong hai cột, không có bản ghi trên sổ,
hoặc bản ghi không ở trạng thái 40/50 (FS 03/99) → message "Không có hóa đơn gốc
để điều chỉnh" / "...để thay thế".

## C. adjtype tự suy theo chiều ghi sổ tài khoản doanh thu

FS: chỉ còn hai giá trị — 2 (tăng) khi dòng TK 5\* ghi **Có** (`SHKZG = 'H'`),
3 (giảm) khi ghi **Nợ** (`SHKZG = 'S'`). Chứng từ có cả hai chiều thì tính **tổng
ròng** (Có +, Nợ −). Bỏ hẳn adjtype 4 (điều chỉnh thông tin) — làm trên cổng FPT.
Người dùng không chọn, không sửa được; giá trị hiển thị read-only.

| Hiện tại | Phải đổi |
|---|---|
| `ZCL_HDDT_SERVICE=>resolve_adjust` — `fs_code` suy ra 2/3/4/5 từ `adj_direction`, mặc định `'4'` | Bỏ nhánh `'4'` và `'5'`; `adj_direction` do tầng nguồn tính |
| `ZIN_HDDT_INTEGRATION_F01=>adj_code_of` (~dòng 487) | Bỏ nhánh 4/5 |
| `ZCL_HDDT_PROV_FPT` (~dòng 403-411) — `COND string( ... ELSE '4' )` | Chỉ còn 2/3 |
| Domain của `ZDE_HDDT_ADJTYPE` / `ZDE_HDDT_ADJDIR` | Rà lại fixed values |
| `ZCL_HDDT_SRC_FI` — đã đọc BSEG có `shkzg`, `hkont`, phân loại dòng theo MAP `GLACCT` | **Mới**: cộng ròng các dòng TK doanh thu → `adj_dir` |
| `gty_alv-adj_code` | Đổi sang read-only |

Danh sách tài khoản doanh thu đã có sẵn: `ZTB_HDDT_MAP` với `map_type = 'GLACCT'`.
Không phải tạo bảng mới cho phần này.

## D. Câu mô tả trên hoá đơn điều chỉnh

FS chốt cú pháp cố định:

> Hóa đơn điều chỉnh \<tăng|giảm\> cho hóa đơn điện tử mẫu số \<mẫu số\>, ký hiệu
> \<ký hiệu\>, số \<số hóa đơn\> lập ngày \<dd/mm/yyyy\>

Truyền vào `inv.note` (255 ký tự); `inv.adj.rea` truyền **chính câu đó cắt còn 100**.

- `ZCL_HDDT_PROV_BASE=>build_adjust_note` (~dòng 353) đang sinh
  `"Điều chỉnh cho hóa đơn <serial><seq> ngày <dd.mm.yyyy>"` → viết lại đúng cú
  pháp, tách mẫu số / ký hiệu (code đã có logic tách ký tự đầu của serial ở
  `PROV_FPT` ~dòng 415).
- `ZCL_HDDT_PROV_FPT` ~dòng 342: `note` đã dùng `build_adjust_note` — đúng hướng.
- `ZCL_HDDT_PROV_FPT` nhánh API v3 (~dòng 403-435) **chưa gửi `adj.rea`** → phải
  thêm, cắt 100 ký tự. Nhánh v2 (~dòng 446) có gửi `rea` nhưng chưa cắt.

## E. Điều chỉnh / Thay thế đi qua bước nháp (inv.aun để trống)

Đây là thay đổi làm gãy giả định hiện tại của engine.

| Hiện tại | FS mới |
|---|---|
| `ZCL_HDDT_PROV_FPT` ~dòng 283: comment ghi rõ "create-appr-inv / điều chỉnh / thay thế truyền aun = 2" | Điều chỉnh / thay thế **không truyền `aun`** |
| `ZCL_HDDT_SERVICE=>resolve_adjust` ~dòng 1568: nhánh `create_draft` gọi `raise_text( 'Chứng từ đã gắn hoá đơn gốc ... phát hành trực tiếp bằng nút "Phát hành HĐ", không qua nháp.' )` | Phải **cho phép** tạo nháp |
| Sau `adjust_invoice` / `replace_invoice` thành công → trạng thái 40 (FS 03) | → **20 / wait_seq (FS 02 – Hoá đơn nháp)** |
| `post_success` chuyển HĐ gốc sang 60/70 (FS 07/08) ngay khi gọi adjust/replace | Chỉ chuyển khi **issue-invoice** thành công (test 9i: huỷ nháp thì HĐ gốc giữ 03/99) |
| `issue_invoice` (~dòng 1257) chỉ xử lý nháp thường | Phải nhận cả nháp điều chỉnh / thay thế (cùng `idkey`, không gọi lại adjust) |

Kéo theo:

- `ZCL_HDDT_SERVICE=>check_action` (~dòng 904) — bảng điều kiện trạng thái cho hai nút mới.
- `ZTB_HDDT_STAT` — dòng map `rc_code` của action `adjust_invoice` / `replace_invoice`
  phải trả `sap_status = '20'` thay vì `'40'`. Sửa dữ liệu khởi tạo trong
  `src/ui/zpg_hddt_setup.prog.abap`.
- `derive_status` (~dòng 1730).

## F. "Hủy HĐ nháp" — pop-up hai phương án, huỷ chứng từ SAP TRƯỚC

Hạng mục nặng nhất: **hiện tại package không có một dòng nào gọi VF11 / MR8M /
FB08** — grep toàn bộ 136 object cho cả ba chuỗi đều 0 kết quả.

FS yêu cầu:

1. Pop-up radio: "Hủy nháp" / "Hủy nháp đồng thời hủy chứng từ"; kèm hai trường
   **Lý do huỷ** (mặc định 01, cho sửa) và **Ngày huỷ** — làm mờ khi nguồn là Billing.
2. Chọn chức năng chuẩn theo `BKPF-AWTYP`: `VBRK` → VF11, `RMRP` → MR8M,
   `BKPF` → FB08. Bản ghi Nhóm 3 (chưa có FI, có Billing Document) → VF11.
3. **Thứ tự bắt buộc: huỷ trên SAP trước, gọi `del-invoice` sau.** Bước 1 lỗi →
   dừng, trả nguyên văn message chuẩn, giữ trạng thái 02. Bước 2 lỗi → trạng thái
   04 và bản ghi vẫn hiện trên ALV (ngoại lệ của quy tắc ẩn chứng từ đã huỷ).

Code phải đụng:

- `ZIN_HDDT_INTEGRATION_F01=>do_delete_draft` (~dòng 1148) — thay `confirm( )` bằng pop-up mới.
- `FORM` mới cho pop-up (mẫu `popup_edit` ~dòng 2480 dùng lại được).
- **Class mới** `ZCL_HDDT_REVERSAL` (tên đề xuất) bọc ba chức năng chuẩn — xem
  "Giao diện BAPI" ngay dưới.

### Giao diện BAPI — đã đọc `FUPARAREF` trên MAG_S25_300 ngày 22/09/2026

| Chức năng | BAPI | Bảng lỗi trả về | Tham số đáng chú ý |
|---|---|---|---|
| VF11 | `BAPI_BILLINGDOC_CANCEL1` | `RETURN` kiểu **BAPIRETURN1** + `SUCCESS` kiểu BAPIVBRKSUCCESS | `TESTRUN`, `NO_COMMIT`, `BILLINGDATE`. **Không có tham số lý do huỷ** |
| MR8M | `BAPI_INCOMINGINVOICE_CANCEL` | `RETURN` kiểu **BAPIRET2** | `REASONREVERSAL`, `POSTINGDATE`, `SIMULATION` |
| FB08 | `BAPI_ACC_DOCUMENT_REV_POST` | `RETURN` kiểu **BAPIRET2** | `REVERSAL` kiểu BAPIACREV, `BUS_ACT`; kèm `BAPI_ACC_DOCUMENT_REV_CHECK` cùng giao diện để kiểm trước |

Kết luận cho yêu cầu "trả lại nguyên văn message lỗi chuẩn" của FS: **đạt**.
BAPIRET2 / BAPIRETURN1 mang sẵn `MESSAGE` (text đã dựng) và `ID` / `NUMBER` /
`MESSAGE_V1..V4` nên vừa hiện được nguyên văn, vừa phát lại được bằng
`MESSAGE ID ... TYPE ... NUMBER ...` nếu muốn.

Ba điểm phải lường trước:

- Hai kiểu bảng lỗi khác nhau (BAPIRETURN1 vs BAPIRET2) → wrapper cần hai nhánh ánh xạ.
- `BAPI_BILLINGDOC_CANCEL1` không có tham số lý do huỷ — **khớp đúng** FS
  ("VF11 chạy ngầm, không truyền lý do huỷ"), và pop-up phải làm mờ trường Lý do
  huỷ khi nguồn là Billing, đúng như test case 3f.
- `BAPI_ACC_DOCUMENT_REV_POST` định danh chứng từ bằng `OBJ_TYPE` / `OBJ_KEY`
  (tức AWTYP / AWKEY) chứ không phải BUKRS / BELNR / GJAHR.
  [Inference] Với chứng từ hạch toán thẳng trong FI, AWTYP = 'BKPF' và
  AWKEY = BELNR + BUKRS + GJAHR nên định danh được — nhưng **chưa kiểm chứng
  được trên hệ này vì BKPF không có dòng nào ở cả ba client**. Phải test thật
  trên DEV có dữ liệu trước khi chốt.
  FM `FI_DOCUMENT_REVERSE` cũng tồn tại nhưng báo lỗi bằng EXCEPTION
  `REVERSE_IMPOSSIBLE`, không có bảng BAPIRET2 → kém hơn cho yêu cầu "nguyên văn".

Cả ba BAPI đều cần `BAPI_TRANSACTION_COMMIT` sau khi thành công.
[Unverified] BAPI không phải lúc nào cũng chạy đủ mọi kiểm tra mà giao dịch dialog
chạy — cần đối chiếu kết quả BAPI với VF11 / MR8M / FB08 thủ công ở vòng test.
- `ZCL_HDDT_SERVICE=>delete_draft` (~dòng 1338) — thêm tham số phương án + đảo thứ tự.
- `ZIF_HDDT_SOURCE` — hợp lý nhất là thêm method `cancel_document` để mỗi lớp
  nguồn (FI / SD / PO) tự biết gọi chức năng chuẩn nào; đúng với kiến trúc
  strategy đang có.

## G. "Thay thế" — huỷ chứng từ gốc trước khi gọi API

- Thứ tự: xác định HĐ gốc → huỷ chứng từ **gốc** trên SAP → `replace-invoice` tạo
  nháp → người dùng bấm "Phát hành HĐ".
- Lý do FS đưa ra: `replace-invoice` làm HĐ gốc "Đã huỷ" **ngay lúc gọi API**.
- Bước huỷ lỗi → dừng, trạng thái 04, không gọi API.
- Pop-up cảnh báo liệt kê chứng từ sẽ bị huỷ (bukrs, số CT, năm, số tiền) kèm câu
  "Chứng từ kế toán gốc sẽ bị huỷ ngay và KHÔNG khôi phục lại được kể cả khi huỷ
  hoá đơn thay thế nháp".
- **Hoá đơn gom**: huỷ **toàn bộ** chứng từ thành phần, set
  `ZTB_HDDT_GOM-xcancel = 'X'` cho mọi dòng, chuyển tất cả sang trạng thái 70
  (FS 08), xoá thông tin hoá đơn (form/serial/seq/mã tra cứu/link) trên các chứng
  từ thành phần.

Code: `ZCL_HDDT_SERVICE` thêm method `replace_with_reversal`; `ZCL_HDDT_GOM` bổ
sung hàm đọc danh sách thành phần + đánh dấu huỷ hàng loạt. Bảng `ZTB_HDDT_GOM`
đã có sẵn cột `xcancel` nên **không phải sửa DDIC**.

## H. "Huỷ Gom HĐ" chỉ khi HĐ gom chưa phát hành

FS cũ cho gỡ gom ở trạng thái 06 và 10; FS mới **chặn** cả hai với message "Hoá
đơn gom đã phát hành, không thể gỡ gom. Vui lòng dùng chức năng thay thế hoá
đơn". Đây là sửa nhỏ trong bảng điều kiện `ZCL_HDDT_GOM=>check_status` — đã viết
theo per-status ở lần sửa trước nên chỉ đổi hai nhánh và hai message.

## I. Nhóm 2 — hoá đơn đầu vào, trả lại hàng nhà cung cấp

Hoàn toàn mới. Grep `RSEG`, `EKKO`, `BSART`, `LIFNR`: **0 kết quả** trong package.

FS:

- Lấy thêm chứng từ có `BSEG-MWSKZ` khớp `I*` và bắt nguồn từ PO loại `ZPO6`.
- Đường đi PO: `BSEG-EBELN`; nếu `BKPF-AWTYP = 'RMRP'` thì qua `RSEG` (BELNR/GJAHR)
  → `EBELN`; rồi `EKKO-BSART` phải nằm trong bảng cấu hình.
- Người mua = **nhà cung cấp** (`BSEG-LIFNR`); tên / MST / địa chỉ lấy từ **LFA1**
  (`NAME1`, `STCD1`, `STRAS` / `ORT01`), đối xứng với cách đang lấy customer.
- Tiền thuế lấy từ dòng `HKONT = 1331*` thay cho `3331*`.
- Dùng **chung dải số** với hoá đơn bán hàng của cùng pháp nhân.
- ALV thêm cột "Loại nghiệp vụ" (Bán hàng / Trả lại hàng NCC).

Code:

- **Bảng cấu hình mới** (tương đương `ZEINVCONFIPO`): BUKRS + BSART, `MWSKZ_PAT`,
  `HKONT_TAX`. Đề xuất `ZTB_HDDT_PO`. Có thể nhét vào `ZTB_HDDT_MAP` với
  `map_type = 'POTYPE'` nếu không muốn thêm bảng, nhưng cần hai giá trị phụ nên
  bảng riêng sạch hơn.
- **Class nguồn mới** `ZCL_HDDT_SRC_PO` — kiến trúc hiện tại đã hỗ trợ sẵn:
  `ZTB_HDDT_SRC` map `src_type` → `classname`, `ZCL_HDDT_FACTORY` nạp động. Chỉ
  cần kế thừa `ZCL_HDDT_SRC_BASE` như `ZCL_HDDT_SRC_FI` đang làm. Đây là chỗ
  kiến trúc cũ trả cổ tức: không phải sửa engine, chỉ thêm một lớp.
- `ZCL_HDDT_SRC_BASE` — logic tách dòng thuế đang gắn với MAP `TAXACCT` giá trị
  `3331*` (khai trong `ZPG_HDDT_SETUP` ~dòng 347). Thêm dòng `1331*` cho src_type
  mới, hoặc để `HKONT_TAX` của bảng PO quyết định.
- Người mua: `ZTB_HDDT_INV-buyer_code` và `gty_alv-buyer_code` đang kiểu `KUNNR`.
  **Đã chốt đổi kiểu** sang data element riêng `ZDE_HDDT_PARTNER` (CHAR 10, không
  gắn check table) để chứa được cả KUNNR lẫn LIFNR mà không kéo theo search help
  và foreign key sai. Chỗ phải sửa: `tools/gen_ddic.py`,
  `src/ddic/ztb_hddt_inv.tabl.xml`, `gty_alv` trong `ZIN_HDDT_INTEGRATION_TOP`,
  và `SELECT-OPTIONS s_kunnr FOR bseg-kunnr` trên màn hình tham số (nay phải nhận
  cả mã NCC).
- Cột "Loại nghiệp vụ": `src_type` đã có trên ALV, chỉ cần thêm cột text.

## J. Nhóm 3 — Billing SD chưa có chứng từ FI

Phần lớn **đã có sẵn** trong `ZCL_HDDT_SRC_SD`:

- Đọc `VBRK` theo `FKART` (lấy từ MAP `BILLTYPE`) — FS chốt ZF04/ZF05, chỉ là dữ liệu config.
- Đã loại billing có `FKSTO = 'X'` (~dòng 174) và đã loại billing đã sinh BKPF
  (`SELECT awkey FROM bkpf`, ~dòng 156).

Còn thiếu:

- `VBRK-SFAKN` chưa được kiểm (grep `SFAKN` = 0 kết quả) → thêm vào điều kiện loại.
- Tham số lọc **Billing Document** riêng (FS 3.3 STT 15). Hiện chỉ có
  `SELECT-OPTIONS s_vbeln FOR bkpf-awkey` — lọc theo AWKEY chứ không theo `VBRK-VBELN`.
- FS nói cột Document Number để trống với Nhóm 3; cần xác nhận `gty_alv-src_docno`
  đang điền gì cho nguồn SD.
- Điều kiện `FKSTO` trống chỉ áp dụng ở lần lấy chứng từ lên ALV **lần đầu**.

## K. Loại cặp chứng từ đảo theo AWREF_REV

Quy tắc mới, chưa có trong code (grep `AWREF_REV` = 0):

- `BKPF-AWTYP = 'VBRK'`: `AWREF_REV` = 08 ký tự **cuối** của `AWKEY` và `BUDAT`
  trùng nhau → loại **cả cặp**.
- `AWTYP <> 'VBRK'`: `AWREF_REV` = 10 ký tự **đầu** của `AWKEY` và `BUDAT` trùng
  nhau → loại cả cặp.

Hiện `ZCL_HDDT_SRC_FI` chỉ đọc `xreversed` / `stblg` / `stjah` (~dòng 347) và có
hàm `keep_document`. Phải mở rộng hàm đó, không phải viết lại vòng đọc.

## L. Dải số hoá đơn — thêm GJAHR vào khoá

`ZTB_HDDT_CRED` là bảng tương ứng `ZVM_MAPINV`:

```
key provider + bukrs + inv_type + serial ; valid_from / valid_to ; xdefault
```

FS mới yêu cầu khoá **BUKRS + GJAHR + TYPE + FORM + SERIAL** và cờ Default duy
nhất theo **BUKRS + GJAHR**.

| Việc | Chỗ sửa |
|---|---|
| Thêm key `gjahr` (và cân nhắc `template` vào khoá) | `tools/gen_ddic.py`, `src/ddic/ztb_hddt_cred.tabl.xml` |
| Chọn dòng theo năm thay cho `valid_from` / `valid_to` | `ZCL_HDDT_CONFIG` (~dòng 423, 448, 473) |
| Validate "mỗi BUKRS+GJAHR đúng một Default" — hiện đang check theo BUKRS+INV_TYPE | `ZCL_HDDT_CONFIG` ~dòng 498, đổi message thành "Company code &1 năm &2 đã có dải số mặc định" |
| Năm lấy theo `s_budat-low`, trống thì `sy-datum` | `ZIN_HDDT_INTEGRATION_F01` (~dòng 2534-2558, chỗ tự điền `p_seri`) |
| F4 dải số lọc thêm theo năm | `FORM f4_serial` (~dòng 2528) |

Phần "một pháp nhân nhiều dải số + checkbox Default" **đã làm ở lần sửa trước**;
lần này chỉ thêm chiều năm.

## M. Màn hình cấu hình — T-code riêng, view cluster, phân quyền company code

FS mới mô tả một thứ hiện chưa có:

- **T-code cấu hình tách khỏi T-code chương trình** (FS tạm ký hiệu Z\*, tên chưa chốt).
- Toàn bộ bảng cấu hình gom vào **một view cluster (SM34)**.
- Pop-up "Input Parameters" nhập Company Code ở màn hình đầu tiên, kiểm
  `F_BKPF_BUK` (BUKRS, ACTVT = 02).
- Mọi view chỉ hiện và chỉ cho sửa dòng có BUKRS đúng; thêm dòng mới thì BUKRS
  điền sẵn và khoá.
- **Tất cả bảng cấu hình đều phải có Company Code ở header** — FS nói rõ "không
  có bảng nào là ngoại lệ".

### M.1 — BUKRS trên bảng cấu hình: đã chốt KHÔNG thêm

Đối chiếu DDIC hiện tại:

| Bảng | Có BUKRS? | Xử lý |
|---|---|---|
| `ZTB_HDDT_CRED`, `ZTB_HDDT_PARM`, `ZTB_HDDT_SRC`, `ZTB_HDDT_DATE` | có | Lọc và khoá theo BUKRS người dùng nhập ở pop-up |
| `ZTB_HDDT_PROV`, `ZTB_HDDT_CONN`, `ZTB_HDDT_ACT`, `ZTB_HDDT_TPL`, `ZTB_HDDT_MAP`, `ZTB_HDDT_STAT` | không | **Giữ nguyên**, không thêm BUKRS |

Lý do: sáu bảng này là cấu hình kỹ thuật cấp hệ thống — endpoint, mẫu payload,
ánh xạ mã trả về của nhà cung cấp — không phải dữ liệu nghiệp vụ theo pháp nhân.
Thêm BUKRS vào khoá sẽ nhân bản dữ liệu theo số pháp nhân mà không thêm ý nghĩa
nghiệp vụ nào, đồng thời phá mọi `SELECT` trong `ZCL_HDDT_CONFIG`,
`ZCL_HDDT_FACTORY`, `ZCL_HDDT_TOKEN`, `ZCL_HDDT_PROV_*` và toàn bộ dữ liệu khởi
tạo trong `ZPG_HDDT_SETUP`.

Phân quyền cho sáu bảng này dựa vào lớp 1 (quyền T-code cấu hình). Điểm này
**lệch với câu chữ FS** ("không có bảng nào là ngoại lệ") nên cần ghi rõ trong
biên bản trao đổi với MAG.

### M.2 — View cluster: KHÔNG chuyển, giữ ZPG_HDDT_CONFIG

Hiện trạng đã kiểm trên MAG_S25_300 ngày 22/09/2026:

- **T-code đã tách sẵn** đúng như FS muốn: `ZHD001` → `ZPG_HDDT_INTEGRATION`,
  `ZHD002` → `ZPG_HDDT_CONFIG`, `ZHD003` → `ZPG_HDDT_LOG`.
  (Comment đầu file `ZPG_HDDT_CONFIG` còn ghi nhầm "transaction ZFI002" — sửa lại.)
- **Chín bảng đã sinh table maintenance** trong function group `ZFG_VM_HDDT`,
  màn hình 0001–0009, `TVDIR-TYPE = 1`, `BASTAB = 'X'` (bảo trì thẳng trên bảng
  gốc, không qua maintenance view), sinh lại ngày 22/09/2026 lúc 14:02–14:06.
- `ZPG_HDDT_CONFIG` **đã là bàn điều khiển gom đầu mối**: liệt kê toàn bộ bảng
  cấu hình, nhấn đôi gọi `VIEW_MAINTENANCE_CALL` (~dòng 185) — tức đúng cái mà
  view cluster mang lại.

**Chặn kỹ thuật, không phải chuyện sở thích**: view cluster chỉ chứa được object
đã sinh được maintenance dialog. Ba bảng của package **SE54 từ chối sinh** vì có
field STRING / RAWSTRING ("Data type STRING is not supported"):

| Bảng | Field chặn | Đường bảo trì hiện tại |
|---|---|---|
| `ZTB_HDDT_TPL` | `tpl_body` (`ZDE_HDDT_JSON`) | `MAINTAIN_TPL` — nạp mẫu payload từ file JSON |
| `ZTB_HDDT_TOK` | bộ đệm token | `MAINTAIN_TOK` — xem + xoá để buộc đăng nhập lại |
| `ZTB_HDDT_LOG` | — | mở `ZPG_HDDT_LOG` |

Chuyển sang SM34 sẽ được view cluster cho 9 bảng nhưng **vẫn phải giữ một đường
riêng cho 3 bảng kia** — tức là có hai đầu mối thay vì một, ngược đúng mục tiêu
FS đặt ra.

Việc cần làm là **bổ sung vào `ZPG_HDDT_CONFIG`**, không phải thay nó:

1. Pop-up "Input Parameters" nhập Company Code ở màn hình đầu tiên
   (`POPUP_GET_VALUES` hoặc selection screen riêng, search help theo `T001`).
2. `AUTHORITY-CHECK OBJECT 'F_BKPF_BUK' ID 'BUKRS' FIELD lv_bukrs
   ID 'ACTVT' FIELD '02'` → không đạt thì message "Bạn không có quyền cấu hình
   hoá đơn điện tử cho company code &1" và ở lại màn hình đầu.
3. Lọc / khoá BUKRS cho 4 bảng có BUKRS. Vì `VIEW_MAINTENANCE_CALL` bảo trì
   thẳng trên bảng gốc, phần này làm bằng **SE54 event** giống `ZALV_SET_AUDIT`
   đang có trong `LZFG_VM_HDDTF01`: event 01 (BEFORE_SAVE) chặn ghi sai BUKRS,
   event 21 / 23 lọc dòng hiển thị. Truyền BUKRS sang bằng biến toàn cục của
   `ZFG_VM_HDDT` hoặc SET/GET parameter `BUK`.

> **Ràng buộc công cụ**: ADT discovery trên hệ này **không có** endpoint nào cho
> view cluster (`vcls`), maintenance view hay sinh table maintenance — chỉ có
> `/sap/bc/adt/ddic/views` cho DDIC view thường. Nghĩa là dù chọn phương án view
> cluster thì phần SE54 / SM34 vẫn phải làm tay trên SAP GUI, tôi không tự động
> hoá qua bridge được. Phần ABAP (pop-up, authority-check, routine event) thì
> viết và deploy qua bridge bình thường.

Tham khảo nếu sau này vẫn muốn view cluster: hệ đã có sẵn một mẫu chạy được là
`ZVC_INT_CFG` (tạo 14/09/2026, tác giả F-DUBV) — 4 object phẳng `OBJLEVEL = 00`,
một object gốc `ZV_INT_SYS` (`DEPENDENCY = 'R'`, `STARTOBJ = 'X'`) và 3 object
con `DEPENDENCY = 'S'`.

## N. Message mới cần khai trong ZMS_HDDT

FS liệt kê ở mục 3.9:

1. Không có hóa đơn gốc để điều chỉnh
2. Không có hóa đơn gốc để thay thế
3. Chỉ chọn 1 chứng từ điều chỉnh / Chỉ chọn 1 chứng từ thay thế
4. Hoá đơn gom đã phát hành, không thể gỡ gom. Vui lòng dùng chức năng thay thế hoá đơn
5. Hoá đơn gom này gồm &1 chứng từ thành phần, tất cả sẽ bị huỷ. Bạn có chắc chắn không?
6. Chứng từ gốc &1-&2 sẽ bị huỷ bằng &3 trước khi phát hành hoá đơn thay thế. Xác nhận?
7. Không huỷ được chứng từ gốc &1-&2: &3
8. Đã huỷ hoá đơn nháp và huỷ chứng từ kế toán
9. Đã huỷ hoá đơn nháp nhưng không huỷ được chứng từ: &1
10. Kỳ kế toán của chứng từ gốc đã đóng, vui lòng chọn lại Lý do huỷ và Ngày huỷ
11. Company code &1 năm &2 đã có dải số mặc định
12. Bạn không có quyền cấu hình hoá đơn điện tử cho company code &1

`ZMS_HDDT` đang dùng đến số 053 — cấp tiếp từ 054.

---

## Thay đổi FS KHÔNG ảnh hưởng code

- Đổi số mục 3.6.5 → 3.6.6 v.v. chỉ là tham chiếu trong tài liệu (code có nhắc
  số mục trong comment, sửa hay không tuỳ).
- Tên T-code đổi thành Z\* trong tài liệu: code đang có `ZHDDT` / `ZHDDT02` thật,
  chờ MAG chốt tên chính thức.
- Ghi chú "chưa chốt" về `user.username`, lịch chạy job phát hành tự động, phạm
  vi pháp nhân — chưa phải yêu cầu code.

## Điểm còn phải chốt với MAG / FPT IS

1. **ZF04 / ZF05** — FS ghi rõ là tạm mượn của dự án EEMC, MAG sẽ cấp giá trị sau.
2. **Tên chính thức hai T-code** — FS còn để ký hiệu Z\*; hệ đang chạy `ZHD001`
   và `ZHD002`. Nếu quy ước đặt tên MAG khác thì phải đổi.
3. **Lệch câu chữ FS ở mục M.1**: FS viết "tất cả bảng cấu hình đều có Company
   Code, không có bảng nào ngoại lệ"; ta chốt sáu bảng kỹ thuật không thêm BUKRS.
   Cần MAG xác nhận bằng văn bản.
4. **`BAPI_ACC_DOCUMENT_REV_POST` với chứng từ FI hạch toán dialog** — phải test
   trên hệ có dữ liệu BKPF thật (mục F).
