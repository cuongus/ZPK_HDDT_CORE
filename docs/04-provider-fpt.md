# 04 — Adapter FPT eInvoice

Lớp: `ZFIC_HDDT_PROV_FPT` (kế thừa `ZFIC_HDDT_PROV_BASE`)

## 1. Nguồn tham chiếu đã dùng

| Nguồn | Dùng cho |
|---|---|
| `FPT_eInvoice_API_UAT_V2.4.7.pdf` — "Tài liệu đặc tả API giao tiếp với hệ thống khách hàng" v2.4.7 | Endpoint và cấu trúc payload các mục 3.1, 3.3, 3.5, 3.7, 3.8, 3.9, 3.10, 3.11, Phụ lục I & II |
| Mã ABAP đang chạy tại hệ **VJC**, `ZPK_HDDT` (`ZST_CR_EINV_JSON_FPT`, `ZST_DC_EINV_JSON_FPT`) | Đối chiếu chéo tên thẻ, quy tắc `ud` / `adj_only_add` |

Các phần dưới đây **đã đối chiếu tài liệu**, không phải suy đoán.

## 2. Endpoint (đã nạp bởi `ZFIR_HDDT_SETUP`)

Base URL UAT: `https://api-uat.einvoice.fpt.com.vn`

| ACTION | Method | API_PATH | Mục tài liệu |
|---|---|---|---|
| `LOGIN` | POST | `/c_signin` | 3.11 |
| `CREATE_DRAFT` | POST | `/create-invoice` | 3.1 |
| `UPDATE_INVOICE` | POST | `/update-invoice` | 3.2 |
| `CREATE_INVOICE` | POST | `/create-appr-inv` | 3.3 (tạo + cấp số + ký duyệt) |
| `APPROVE_INVOICE` | POST | `/apprs` | 3.4 |
| `REPLACE_INVOICE` | POST | `/replace-invoice` | 3.5 |
| `CANCEL_INVOICE` | POST | `/cancel-invoice` | 3.7 (TT78) |
| `ADJUST_INVOICE` | POST | `/adjust-invoice` | 3.8 |
| `SEARCH_INVOICE` | **GET** | `/search-invoice` | 3.9 |
| `DELETE_INVOICE` | POST | `/del-invoice` | 3.10 |
| `WRONG_NOTICE` | POST | `/create-wno-list` | 3.20 |

> Nếu quy trình của bạn muốn **lưu nháp rồi duyệt sau** thay vì phát hành ngay:
> đổi `API_PATH` của `CREATE_INVOICE` từ `/create-appr-inv` sang
> `/create-invoice`, và đặt tham số `FPT_AUN` phù hợp. Không cần sửa code.

## 3. Payload phát hành / điều chỉnh (mục 3.1, 3.8)

```
{
  "lang": "vi",
  "user": { "username", "password" },          ← bỏ khi FPT_USER_IN_BODY = 'N'
  "inv": {
    "sid",  "idt",  "type", "form", "serial", "seq", "aun",
    "type_ref": "1",       hoá đơn theo NĐ123/2020 (TT78)
    "sendtype": "0",       0 gửi CQT ngay · 1 gửi theo bảng tổng hợp
    "bcode","bname","buyer","btax","baddr","btel","bmail","bacc","bbank",
    "stax","sname","saddr","stel","smail","sacc","sbank",
    "curr","exrt","paym","note",
    "sum","sumv","vat","vatv","total","totalv","word",
    "items": [ { "line","type","code","name","unit","vrt",
                 "price","quantity","amount","vat","total",
                 "perdiscount","amtdiscount" } ],
    "tax":   [ { "vrt","vrn","amt","amtv","vat","vatv" } ],
    "adj":   { "seq","rdt","ref","rea" },      chỉ khi ĐC / thay thế
    "ud",                  1 điều chỉnh tăng · 0 điều chỉnh giảm
    "adj_only_add": "1"    điều chỉnh kiểu mới (chỉ ghi phần chênh lệch)
  }
}
```

Quy tắc đã cài:

- `idt` định dạng `YYYY-MM-DD hh:mm:ss` (tài liệu mục 3.1.3 thẻ số 9).
- Cặp `sum`/`sumv`, `vat`/`vatv`, `total`/`totalv` = nguyên tệ / quy đổi VND;
  core tính sẵn cả hai từ tỷ giá.
- `vrt` = mã thuế suất; số nguyên phần trăm, hoặc `-1` (KCT) / `-2` (không kê
  khai). Ghi đè được bằng ánh xạ `TAXRATE`.
- `adj.seq` theo định dạng `1-<ký hiệu>-<số>` như mã đang chạy ở hệ VJC.
- `curr = 'VND'` → `exrt = 1`.

## 4. Tra cứu — tham số nằm trong HTTP HEADER (mục 3.9.3)

Đây là điểm khác biệt lớn nhất so với Viettel. Tài liệu ghi rõ:

> *"Restful Api method GET => parameter được đẩy lên trong headers của request"*

Adapter cài trong `GET_HEADERS( )`, chỉ khi `ACTION = SEARCH_INVOICE`:

| Header | Nguồn |
|---|---|
| `stax` | `ZFIT_HDDT_CRED-TAXCODE` |
| `form` / `serial` / `seq` / `sid` | header hoá đơn trong request |
| `type` | `ty_request-params['type']`, mặc định `json`; các giá trị khác: `xml`, `pdf`, `cvt`, `base64xml` |
| `fd` / `td` / `btax` / `api` / `lang` | do caller truyền trong `ty_request-params` |

Header rỗng bị xoá để FPT không hiểu là điều kiện lọc trống.

## 5. Huỷ hoá đơn TT78 (mục 3.7.3)

```
{
  "lang": "vi",
  "user": { … },
  "wrongnotice": {
    "stax", "noti_taxtype", "noti_taxnum", "noti_taxdt",
    "budget_relationid", "place",
    "items": [ { "form","serial","seq","idt","type_ref","noti_type","rea" } ]
  }
}
```

| Thẻ | Cách adapter điền |
|---|---|
| `noti_taxtype` | `2` nếu có số văn bản CQT (`adjust-doc_ref_no`), ngược lại `1` |
| `noti_taxnum` / `noti_taxdt` | số / ngày thông báo CQT — bắt buộc khi `noti_taxtype = 2` |
| `place` | tham số `FPT_PLACE` theo công ty, hoặc `header-place`. **Bắt buộc** |
| `noti_type` | `1` = Huỷ |
| `type_ref` | `1` = HĐ theo NĐ123/2020 |
| `form`/`serial`/`seq`/`idt` | lấy từ request; nếu trống thì đọc sổ đăng ký `ZFIT_HDDT_INV` |

## 6. Xoá hoá đơn chờ cấp số (mục 3.10.3)

```
{ "user": { … }, "sid": "<idkey>", "stax": "<MST>" }
```

Response là **text thuần** (`Delete complete` / `There are no invoices to delete`),
không phải JSON — adapter nhận biết và xử lý.

## 7. Bóc response

| Thẻ | Đích |
|---|---|
| `serial`, `seq`, `form` | `SERIAL`, `SEQ`, `TEMPLATE` |
| `sec` | `SEC_CODE` (mã tra cứu) |
| `link` | `INV_LINK` (link tra cứu, nhấn được trên ALV) |
| `sid` | `IDKEY` |
| `adt` / `idt` | `ISSUE_DATE` |
| `status` (Phụ lục I) | `PROV_STATUS` → trạng thái SAP: 1 chờ cấp số · 2 chờ duyệt · 3 đã duyệt · 4 đã huỷ |
| `status_received` = `10` (Phụ lục II) | trạng thái `50` đã được CQT cấp mã, `ic` → `MSCQT` |
| `error` / `message` / `mess` | `MESSAGE` |

## 8. Xác thực — ba cách, chọn bằng cấu hình

| Cách | `AUTH_MODE` | `FPT_USER_IN_BODY` | Ghi chú |
|---|---|---|---|
| Tài khoản trong payload | `N` | `X` | Mặc định `ZFIR_HDDT_SETUP` nạp. Đơn giản nhất, nhưng mật khẩu phải nằm trong `APISECRET` hoặc vault |
| Basic auth (mục 3.10.5.2) | `B` | `N` | Dùng được RFC destination → **an toàn nhất** |
| JWT (mục 3.11) | `T` | `N` | Core gọi `/c_signin`, body trả về là chuỗi JWT thuần; cache theo `TOKEN_TTL` |

## 9. Tài khoản UAT trong tài liệu

Tài liệu dùng ví dụ `0100100008.admin`. Định dạng tài khoản FPT là
`<MST>.<tên đăng nhập>`, khai vào `ZFIT_HDDT_CRED-APIUSER`;
`TAXCODE` chỉ điền phần MST.
