# 10 — Đối chiếu FS MAG (Tích hợp HĐĐT v0.5) với package

Tài liệu nguồn: `MAG_SAP_2026_PM_FS_Tich hop HDDT_v0.1.docx` (phiên bản nội dung
0.5, ngày 05/09/2026; nhà cung cấp FPT eInvoice onCloud, API NĐ70 v3.2, hoá đơn
**có mã** của Cơ quan thuế; quy trình AR.10). Bảng dưới ghi từng yêu cầu của FS,
chỗ tương ứng trong package và trạng thái sau lượt bổ sung 07/09/2026.

Quy ước: ✓ đã có · ➕ bổ sung lượt này · ⚠ khác FS có chủ ý (ghi lý do) · ✗ chưa làm.

---

## 1. Màn hình tham số (FS 3.3)

| STT FS | Tham số | Package | TT |
|---|---|---|---|
| 1 | Company code | `P_BUKRS` (bắt buộc, MEMORY ID BUK) | ✓ |
| 2–4 | Ngày hạch toán / ngày chứng từ / ngày nhập | `S_BUDAT`, `S_BLDAT`, `S_CPUDT` | ➕ CPUDT |
| 5 | Số chứng từ | `S_BELNR` | ✓ |
| 6 | Khách hàng | `S_KUNNR` | ✓ |
| 7 | Số hoá đơn | `S_SEQ` (lọc theo sổ `ZTB_HDDT_INV-SEQ`) | ➕ |
| 8 | Số chứng từ FI gom | `S_GOM` (`ZTB_HDDT_INV-GOM_NO`) | ➕ |
| 9 | Trạng thái hoá đơn | `S_STAT` (bộ mã package, xem §5) | ✓ |
| 10 | Người tạo | `S_USNAM` | ✓ |
| 11 | Loại chứng từ huỷ | `P_REVER` — lấy cả chứng từ đã đảo | ✓ |
| 12 | Mẫu hoá đơn phát hành | `P_ITYP` → `header-inv_type` → chọn dòng `ZTB_HDDT_CRED` | ➕ (không bắt buộc: trống = dòng mặc định) |
| 13 | Selection Option (button) | dùng SELECT-OPTIONS chuẩn | ⚠ không cần nút riêng |
| 14 | Test | `P_TEST` — không gọi API, pop-up JSON | ✓ (pop-up khi bấm Tích hợp HĐ / Phát hành HĐ) |
| 15 | Phát hành tự động | `P_AUTO` — chỉ hiệu lực khi `SY-BATCH = X`, mặc định không tích | ➕ |

Thêm ngoài FS: `P_SRCT` (FI / SD / GOM), `P_PROV` (đổi nhà cung cấp bằng cấu hình).

## 2. Cột ALV (FS 3.5)

| Cột FS | Package | TT |
|---|---|---|
| Status EInvoices (icon) | `LIGHT` | ✓ |
| Status Email | `MAIL_LIGHT` (từ `ZTB_HDDT_INV-MAIL_STATUS`) | ➕ |
| Company Code / Fiscal Year / Số chứng từ | `BUKRS / GJAHR / SRC_DOCNO` | ✓ |
| Số FI gom | `GOM_NO` | ➕ |
| Giờ phát hành (sửa được, mặc định 08:00:00) | `INV_TIME` — nút *Sửa ngày/giờ/tên hàng*, tham số `INV_TIME_DEFAULT` | ➕ ⚠ sửa qua pop-up (SALV không edit trực tiếp) |
| Ngày phát hành (sửa được, truyền `inv.idt`) | `INV_DATE` — như trên; mặc định theo `ZTB_HDDT_DATE` | ➕ |
| Customer / Tên đơn vị / Địa chỉ / MST / Email | `BUYER_CODE/NAME/ADDR/TAX/MAIL` | ✓ (+ADDR, MAIL) |
| Item Text (ưu tiên 1 → SGTXT → mô tả billing) | `ITEM_TEXT` (`ZTB_HDDT_INV-ITEM_TEXT`, ghi đè `item_name` mọi dòng) | ➕ |
| Thành tiền / Tiền thuế / Tổng tiền | `AMOUNT / VAT_AMOUNT / TOTAL` | ✓ |
| Kí hiệu mẫu / Ký hiệu / Số / Mã tra cứu | `TEMPLATE / SERIAL / SEQ / SEC_CODE` | ✓ |
| Document Date / Ngày tích hợp | `BLDAT / ISSUE_DATE` | ✓ |
| Trạng thái inv / Thông báo | `STATUS`, `STATUS_TXT`, `MESSAGE` | ✓ |
| Payment Method | `PAYM` | ➕ |
| Loại tiền / Thuế suất / Tỷ giá | `WAERS / TAX_SUMM / EXCH_RATE` | ✓ (+EXCH_RATE) |
| Loại điều chỉnh (2/3/4/5) | `ADJ_CODE` | ➕ |
| Số / Năm chứng từ gốc | `REF_DOCNO / REF_GJAHR` | ✓ (+GJAHR) |
| — | `TAX_STATUS` (status_received của CQT) | ➕ thêm |

## 3. Nút chức năng (FS 3.6) ↔ engine

| Nút FS | Nút package | API / method | TT |
|---|---|---|---|
| Tích hợp HĐ (3.6.1) | `ZDRAFT` | `ZCL_HDDT_SERVICE->CREATE_DRAFT` → `CREATE_DRAFT` = FPT `create-invoice` **không aun** | ➕ |
| Hủy HĐ nháp (3.6.2) | `ZDELDRF` (pop-up xác nhận) | `DELETE_DRAFT`: 20 → `del-invoice`; 90 → tra cứu trước (status 1 → xoá; không tìm thấy → về 00; đã cấp số → lỗi 018) | ➕ |
| Phát hành HĐ (3.6.3, 3.6.10) | `ZISSUE` | `ISSUE_INVOICE`: 20 → `issue-invoice`; 30 → `apprs`; 90/45 → `search-invoice` rồi 1→issue, 2→apprs, 3→đồng bộ, không có → về 00; 00 đã gắn HĐ gốc → `adjust/replace-invoice` | ➕ |
| Cập nhật HĐ (3.6.5) | `ZUPDATE` | `SEARCH_INVOICE` type=json → `derive_status` (status/status_received) → sổ; ghi ngược BKPF qua `WRITEBACK_CLASS` | ✓ + ➕ ghi ngược |
| HĐ Điều chỉnh (3.6.4) | `ZADJREF` | pop-up Số CT gốc / Năm / Loại ĐC (2,3,4,5) → `ATTACH_ORIGINAL` (không gọi API); lúc phát hành `RESOLVE_ADJUST` đổi CREATE → ADJUST/REPLACE | ➕ |
| Send Email (3.6.6) | `ZMAIL` | `GET_INVOICE_FILE` type=pdf → `ZCL_HDDT_MAIL` (CL_BCS); chỉ trạng thái `MAIL_ALLOWED_STATUS` = 20, 50; nháp ghi rõ "MẪU HOÁ ĐƠN NHÁP" | ➕ |
| Gom HĐ (3.6.7) | `ZGOM` | `ZCL_HDDT_GOM->CREATE`: ≥2 CT, cùng KH / năm / loại tiền, chưa gom, trạng thái 00/45; số `G000000001..` theo công ty+năm; bảng `ZTB_HDDT_GOM` + `INV-GOM_NO` | ➕ ⚠ chưa có màn hình sửa dòng gom |
| Huỷ Gom HĐ (3.6.8) | `ZUNGOM` | `ZCL_HDDT_GOM->CANCEL`: chỉ khi HĐ gom chưa phát hành | ➕ |
| Phát hành tự động (3.6.9) | `P_AUTO` + job | `LCL_APP->RUN_AUTO`: 00 → `CREATE_INVOICE` (`create-appr-inv`, aun 2), 20/30/90 → `ISSUE_INVOICE`; commit từng chứng từ | ➕ |
| Xử lý cấp số nhưng ký lỗi (3.6.10) | trong `ISSUE_INVOICE` | tuyệt đối không gọi lại create/issue cho HĐ đã cấp số: status 2 → `apprs` | ➕ |
| — | `ZEDIT`, `ZFILE`, `ZJSON`, `ZLOG` | tiện ích | ✓ |

Nút "Huỷ hoá đơn đã phát hành" (kế thừa FS VJC) FS xác nhận **ngoài phạm vi** →
đã bỏ khỏi thanh công cụ; method `CANCEL_INVOICE` (TBSS) vẫn có trong engine.

Điều kiện trạng thái theo từng nút nằm ở `ZCL_HDDT_SERVICE->CHECK_ACTION`
(áp cho cả job, cả Test run) và `ATTACH_ORIGINAL`.

## 4. API FPT (FS 3.7) ↔ adapter `ZCL_HDDT_PROV_FPT`

| API FS | Action package | Payload | TT |
|---|---|---|---|
| 3.7.1 create-invoice (nháp, không aun) | `CREATE_DRAFT` | `build_invoice`, **không** `aun` khi CREATE_DRAFT | ➕ |
| 3.7.2 del-invoice | `DELETE_INVOICE` | `{ user?, sid, stax }` | ✓ |
| 3.7.3 issue-invoice | `ISSUE_INVOICE` | `{ lang, user?, inv:{ stax, sid } }` | ➕ |
| 3.7.4 create-appr-inv (aun = 2) | `CREATE_INVOICE` | `build_invoice` + `aun` (`FPT_AUN` = 2), `notsendmail`/`sendfile` qua `params` | ✓ |
| 3.7.5 apprs | `APPROVE_INVOICE` | `{ inv:{ stax, sid \| form+serial+seq, notsendmail, sendfile } }` | ➕ (trước dùng nhầm build_invoice) |
| 3.7.6 adjust-invoice | `ADJUST_INVOICE` | `API_VERSION` ≥ 3: `adjtype` (2/3/4) + `ref{rform,rserial,rseq,ridt}` + `class`; < 3: `adj{}` + `ud` (v2.4.7) | ➕ |
| 3.7.7 replace-invoice (+ apprs) | `REPLACE_INVOICE` | như trên, không `adjtype`; `AUTO_APPROVE_AFTER_REPLACE = X` → gọi `apprs` ngay sau | ➕ |
| 3.7.8 search-invoice (GET, header) | `SEARCH_INVOICE` / `GET_FILE` | tham số trong header; `type` json/pdf/xml | ✓ (+GET_FILE) |
| Basic Authentication | `ZTB_HDDT_CONN-AUTH_MODE = B` + `FPT_USER_IN_BODY = N` | seed hiện để `N` (user trong body) — MAG đổi theo tài khoản được cấp | ⚠ cấu hình |

`sid` = **Company code + Số chứng từ + Năm** (FS 3.7.1) — `FILL_DEFAULTS` đã đổi
thứ tự (trước: bukrs + gjahr + docno). Hoá đơn gom: Số chứng từ = số gom.

## 5. Trạng thái (FS 3.8) ↔ `ZDO_HDDT_STATUS`

| FS | Ý nghĩa | Package | status FPT | status_received |
|---|---|---|---|---|
| 01 | Lập (chưa tích hợp) | `00` | — | — |
| 02 | Hoá đơn nháp | `20` (chờ cấp số) | 1 | — |
| — | Đã cấp số, chờ duyệt (ký lỗi) | `30` | 2 | — |
| 03 | Đã phát hành | `40` | 3 | 0, 1 |
| 04 | Lỗi tích hợp | `90` | 1 / 2 | — |
| 05 | Đã huỷ | `80` | 4 | — |
| 06 | Đã huỷ hoá đơn gom | `80` với `SRC_TYPE = GOM` | 4 | — |
| 07 | Bị điều chỉnh | `60` | 3 | 10 |
| 08 | Bị thay thế | `70` | 4 | — |
| 10 | CQT từ chối | `45` ➕ | 3 | 9 |
| 99 | CQT đã cấp mã | `50` | 3 | 10 |

`ZTB_HDDT_INV` lưu đồng thời `STATUS` (mã package), `PROV_STATUS` (status FPT) và
`TAX_STATUS` ➕ (status_received) — tương ứng `STATUS_INV` / `ST_EINV_RECEI` của
`ZTLOG_EINVOICE`.

## 6. Bảng dữ liệu (FS 3.2) ↔ package

| Bảng FS | Package | Ghi chú |
|---|---|---|
| `ZTLOG_EINVOICE` (dữ liệu HĐ) | `ZTB_HDDT_INV` (+ `ZTB_HDDT_ITEM`) | thêm `ADJ_DIR, REF_SRCTYPE, TAX_STATUS, GOM_NO, ITEM_TEXT, MAIL_STATUS, MAIL_DATE`; `FKEY` ≙ `IDKEY`, `ZLOAIDC` ≙ `ADJ_TYPE+ADJ_DIR`, `ZHDGOC/ZNAMGOC` ≙ `REF_DOCNO/REF_GJAHR`, `ZTRACUU` ≙ `SEC_CODE`, `DECRIP` ≙ `MESSAGE`, `DATE_IDT` ≙ `ISSUE_DATE`, `ST_EINV_RECEI` ≙ `TAX_STATUS`, `STATUS_MAIL` ≙ `MAIL_STATUS` |
| `ZTB_INT_LOG` (30 trường, dùng chung) | `ZTB_HDDT_LOG` + `ZIF_HDDT_LOG_SINK` | log chi tiết vẫn ở `ZTB_HDDT_LOG` (payload byte-exact); thêm `DIRECTION, OBJECT_TYPE, API_VERSION, ERROR_CODE, SUCCESS, HAS_REQ, HAS_RES, HOSTNAME`. Ánh xạ: `LOG_ID`≙`LOG_ID`, `SYSTEM_ID`≙`PROVIDER`, `API_NAME`≙`ACTION`, `TSTAMP_UTC`≙`CREATED_AT`, `DURATION`≙`DURATION_MS`, `HTTP_STATUS`≙`HTTP_CODE`, `RETRY_CNT`≙`ATTEMPT`, `ORIG_LOG_ID`≙`IDKEY` (FKEY), `UNAME`≙`CREATED_BY`. Ghi vào bảng `ZTB_INT_LOG` của MAG bằng lớp sink của dự án (khai `LOG_SINK_CLASS`) — bảng đó thuộc khung tích hợp MAG, không nằm trong package |
| `ZEINV_URL` | `ZTB_HDDT_ACT` | endpoint theo action |
| `ZVM_MAPINV` (type/form/serial/stax theo BUKRS) | `ZTB_HDDT_CRED` | |
| `ZVM_MAPUSER` (user/password) | `ZTB_HDDT_CRED` + secure store (`SECKEY`) | FS 3.10 yêu cầu mã hoá mật khẩu → dùng `ZIF_HDDT_SECRET` |
| `ZEINVCONFITYPE` (BLART) | MAP `DOCTYPE` | |
| `ZEINVCONFITIME` (khung giờ) | — | ✗ chưa (không có nút/luồng dùng trong FS v0.5) |
| `ZEINVCONFITKGL` (TK doanh thu) | MAP `GLACCT`; TK thuế 3331* → MAP `TAXACCT` + `TAX_SOURCE = GLACCT` | ✓ |
| `ZEINV_DATES` | `ZTB_HDDT_DATE` | |
| `ZEINV_PAY_MAP` | MAP `PAYMENT` | |
| `ZEINV_INV_GOM` | `ZTB_HDDT_GOM` ➕ | cờ `ZHUY` ≙ `XCANCEL` |

## 7. Quy tắc dựng dữ liệu (FS 3.5) đã cài

- **Tên đơn vị**: tổ chức `NAME_ORG2+3+4`, trống → `NAME_ORG1` (`BUYER_NAME_FIELDS`, seed MAG); cá nhân `NAME_LAST + NAME_FIRST` (`BUYER_PERSON_NAME = LAST_FIRST`) ➕; khách vãng lai từ `BSEC` ✓.
- **Địa chỉ / MST / Email**: ADRC, BUT0ID `VATRU`, BSEC `STCD1`/`INTAD`, ADR6 nối `;` ✓.
- **Thành tiền / Tiền thuế**: tổng dòng TK doanh thu (MAP `GLACCT`) / tổng dòng TK `3331*` (MAP `TAXACCT`, `TAX_SOURCE = GLACCT`) ➕; mặc định package vẫn chốt theo BSET.
- **Thuế suất** từ mã thuế (FTXP) → `A003/KONP`; nhiều mức → "Nhiều loại" ✓.
- **Tỷ giá** VND = 1, khác → `KURSF` ✓. **Payment** `ZLSCH` → MAP ✓.
- **Trường bắt buộc trước khi gọi API** (FS 3.6.1) → `VALIDATE_REQUEST` ➕ (`VALIDATE_REQUEST = N` để tắt).
- **Ghi ngược BKPF** (FS 3.6.3/3.6.5): `XBLNR = Mẫu + Ký hiệu # Số`; HĐ điều chỉnh ghi thêm chuỗi HĐ gốc vào `XREF2_HD`; không ghi `BKTXT`; chỉ ghi khi khác giá trị cũ; FM `FI_DOCUMENT_CHANGE` — `ZCL_HDDT_WRITEBACK_FI` ➕.
- **Phân quyền theo chức năng** (FS 3.10): tham số `AUTH_OBJECT` (object có field `BUKRS`, `ACTVT`; 01 tạo/huỷ nháp, 02 phát hành/điều chỉnh/gom, 03 xem/tra cứu/email) ➕ — object tạo tay bằng SU21 (docs/06).

## 8. Điểm cần MAG xác nhận / khác FS có chủ ý

| # | Nội dung | Đề xuất |
|---|---|---|
| 1 | `BKPF-XREF2_HD` chỉ **12 ký tự**, chuỗi "Mẫu + Ký hiệu # Số" của HĐ gốc dài 16 → không chứa hết | package ghi 12 ký tự cuối (giữ `#` + số HĐ). MAG chọn: giữ vậy, hay ghi `XREF1_HD` (12) + `XREF2_HD`, hay dùng `BKTXT` (25) |
| 2 | Chứng từ **đã gắn HĐ gốc** không đi qua nháp (FS chỉ nói API adjust/replace được gọi lúc phát hành) | `CREATE_DRAFT` báo lỗi hướng dẫn bấm "Phát hành HĐ"; adjust/replace gọi với `aun = 2` **[Inference]** — cần FPT xác nhận adjust-invoke có nhận `aun` |
| 3 | issue-invoice: tài liệu FPT chỉ có URL test; có truyền nút `user` khi dùng Basic không | seed `/issue-invoice`; `FPT_USER_IN_BODY` quyết định nút `user` |
| 4 | Trạng thái 10 (CQT từ chối) bấm "Phát hành HĐ": FS ghi "chuyển 03 nếu thành công" | package tra cứu trước; NCC trả status 3 → chỉ đồng bộ, không phát hành lại (tránh cấp số trùng) |
| 5 | Màn hình gom (sửa header/dòng, thêm bớt dòng, giới hạn tổng tiền) | chưa có; gom hiện lấy nguyên dòng các chứng từ thành viên. Cần FS chi tiết màn hình |
| 6 | Nhận diện "không tìm thấy hoá đơn" khi tra cứu | heuristic: HTTP 404 / thông điệp "không tồn tại", "not found" / 200 rỗng — **[Unverified]** với v3.2, cần response mẫu |
| 7 | Email gửi từ SAP (SCOT) hay để FPT tự gửi (`notsendmail`) | package gửi từ SAP bằng BCS; tham số `notsendmail`/`sendfile` truyền qua `params` nếu muốn FPT gửi |
| 8 | Mã trạng thái nội bộ FS (01–99) khác mã package (00–90) | giữ mã package (đã có domain, ALV đọc DD07T); bảng ánh xạ §5; nếu MAG bắt buộc mã 01–99 → đổi fixed values của `ZDO_HDDT_STATUS` và hằng `gc_status` (một chỗ) |
| 9 | `ZEINVCONFITIME` (khung giờ phát hành) | không có luồng dùng trong FS v0.5 → chưa cài |

## 9. Kiểm chứng

Chưa activate trên hệ SAP nào (ràng buộc: chỉ push GitHub). Rủi ro cú pháp cần
lần import đầu: `FI_DOCUMENT_CHANGE` (tên/tham số FM), `CL_BCS` với
`xstring_to_solix`, `POPUP_GET_VALUES` với field `ZTB_HDDT_INV-ITEM_TEXT` (255 >
132 ký tự nhập), `AUTHORITY-CHECK OBJECT` với tên object trong biến.
