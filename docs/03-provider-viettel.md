# 03 — Adapter Viettel SInvoice

Lớp: `ZFIC_HDDT_PROV_VIETTEL` (kế thừa `ZFIC_HDDT_PROV_BASE`)

## 1. Nguồn tham chiếu đã dùng

| Nguồn | Dùng cho |
|---|---|
| Postman collection `New Collection.postman_collection.json` (Viettel cấp) | Danh sách endpoint mục 7.2 → 7.37, phương thức xác thực |
| `read me.txt` kèm bộ tài liệu | Quy tắc URL = link hệ thống (mục 7.1) + link theo chức năng (7.2–7.37); 2 cách xác thực: basicAuth hoặc accessToken từ `/auth/login` |
| Mã ABAP đang chạy tại hệ **EEMC**, `ZPK_HDDT`, `ZFM_CREATE_E_INVOICES` | Cấu trúc payload (`ZST_JSON_E_INVOICE`), quy tắc `adjustmentType`, `taxBreakdowns`, xử lý ĐC tăng/giảm |

> **[Unverified]** File `tailieu_mo_ta_webservice_hoadondientu_doitac_v2.44_public.doc`
> không đọc được trong phiên làm việc (chuyển đổi .doc thất bại). Tên thẻ JSON
> dưới đây dựng theo **tên component của cấu trúc DDIC trong mã đang chạy thật**.
> Mã cũ còn phải dùng bảng `ZTB_JSON_REPLACE` để sửa lại chữ hoa/thường, nên có
> khả năng một vài thẻ khác so với tài liệu. **Bắt buộc đối chiếu mục 7.2 của tài
> liệu v2.44 trước khi go-live.** Sửa tên thẻ chỉ ảnh hưởng duy nhất lớp này.

## 2. Endpoint (đã nạp bởi `ZFIR_HDDT_SETUP`)

Base URL: `https://api-vinvoice.viettel.vn` (chỉ tới host, vì `/auth/login`
không cùng tiền tố với `/services/einvoiceapplication/api/...`)

| ACTION | Method | API_PATH |
|---|---|---|
| `LOGIN` | POST | `/auth/login` |
| `CREATE_INVOICE` | POST | `…/InvoiceAPI/InvoiceWS/createInvoice/{taxcode}` |
| `ADJUST_INVOICE` | POST | `…/InvoiceWS/createInvoice/{taxcode}` |
| `REPLACE_INVOICE` | POST | `…/InvoiceWS/createInvoice/{taxcode}` |
| `CREATE_DRAFT` | POST | `…/InvoiceWS/createOrUpdateInvoiceDraft/{taxcode}` |
| `PREVIEW_DRAFT` | POST | `…/InvoiceUtilsWS/createInvoiceDraftPreview/{taxcode}` |
| `CANCEL_INVOICE` | POST | `…/InvoiceWS/cancelTransactionInvoice` |
| `SEARCH_INVOICE` | POST | `…/InvoiceWS/searchInvoiceByTransactionUuid` |
| `GET_FILE` | POST | `…/InvoiceUtilsWS/getInvoiceRepresentationFile` |
| `GET_TEMPLATES` | POST | `…/InvoiceUtilsWS/getAllInvoiceTemplates` |

`…` = `/services/einvoiceapplication/api`

Ba nghiệp vụ gốc / điều chỉnh / thay thế **dùng chung một endpoint** — adapter
phân biệt bằng thẻ `adjustmentType`.

## 3. Payload phát hành

```
{
  "generalInvoiceInfo": {
    "invoiceType", "templateCode", "invoiceSeries", "currencyCode",
    "adjustmentType",        1 gốc · 3 thay thế · 5 điều chỉnh · 7 xoá bỏ
    "transactionUuid",       = khoá đối chiếu SAP (idkey)
    "invoiceIssuedDate",     epoch millis, quy đổi theo tham số TIME_ZONE
    "exchangeRate", "paymentStatus", "cusGetInvoiceRight", "invoiceNote",
    "originalInvoiceId", "originalInvoiceIssueDate",   chỉ khi ĐC/thay thế
    "adjustmentInvoiceType"                            1 tiền · 2 thông tin
  },
  "buyerInfo":  { buyerName, buyerLegalName, buyerTaxCode, buyerAddressLine,
                  buyerPhoneNumber, buyerEmail, buyerBankName, buyerBankAccount,
                  buyerCode, buyerIdNo, buyerNotGetInvoice },
  "sellerInfo": { sellerLegalName, sellerTaxCode, sellerAddressLine,
                  sellerPhoneNumber, sellerEmail, sellerBankName,
                  sellerBankAccount },
  "itemInfo":   [ { lineNumber, itemCode, itemName, unitName, unitPrice,
                    quantity, itemTotalAmountWithoutTax, taxPercentage,
                    taxAmount, itemTotalAmountWithTax, discount, itemDiscount,
                    itemNote, isIncreaseItem } ],
  "summarizeInfo": { sumOfTotalLineAmountWithoutTax, totalAmountWithoutTax,
                     totalTaxAmount, totalAmountWithTax, discountAmount,
                     totalAmountWithTaxInWords,
                     isTotalAmountPos, isTotalTaxAmountPos,
                     isTotalAmtWithoutTaxPos, isDiscountAmtPos },
  "taxBreakdowns": [ { taxPercentage, taxableAmount, taxAmount,
                       taxableAmountPos, taxAmountPos } ],
  "payments": [ { paymentMethodName } ]
}
```

Quy tắc đã cài trong adapter:

- Các thẻ `is…Pos` và `isIncreaseItem` **chỉ gửi khi là hoá đơn điều chỉnh**
  (`adjustmentType = 5`), theo đúng cách mã cũ phải `REPLACE` để xoá chúng đi.
- `originalInvoiceId` / `originalInvoiceIssueDate` **chỉ gửi khi có** hoá đơn
  gốc — writer tự bỏ thẻ rỗng nên không cần `REPLACE`.
- `currencyCode = 'VND'` → `exchangeRate = 1`.
- `invoiceNote`: hoá đơn gốc dùng `idkey` để tra soát; ĐC/thay thế dùng câu
  "Điều chỉnh/Thay thế cho hóa đơn <ký hiệu><số> ngày dd/mm/yyyy".

## 4. Huỷ hoá đơn

```
{ "supplierTaxCode", "templateCode", "invoiceNo", "strIssueDate",
  "additionalReferenceDesc", "additionalReferenceDate" }
```

`invoiceNo` = ký hiệu + số. Nếu caller không truyền, adapter tự đọc từ sổ đăng
ký `ZFIT_HDDT_INV`; không có thì báo lỗi rõ ràng thay vì gửi rỗng.

## 5. Bóc response

| Thẻ trong response | Đích trong `ty_result` |
|---|---|
| `errorCode` | `PROV_STATUS`; **null = thành công** |
| `description` / `message` | `MESSAGE` |
| `invoiceNo` | tách phần chữ số ở cuối → `SEQ`, phần đầu → `SERIAL` |
| `codeOfTax` / `reservationCode` | `MSCQT` |
| `transactionUuid` | `IDKEY` |
| `fileToBytes` | base64 → `FILE_CONTENT` |

Response không phải JSON (file nhị phân, trang lỗi HTML của gateway) được xử lý
riêng, không làm vỡ luồng.

## 6. Xác thực

Hai lựa chọn, đặt trong `ZFIT_HDDT_CONN-AUTH_MODE`:

| `AUTH_MODE` | Cách hoạt động |
|---|---|
| `B` | Basic auth — đơn giản nhất, `read me.txt` gọi là "phương thức 1" |
| `T` | Bearer token: core gọi `LOGIN` → `/auth/login`, cache token trong `ZFIT_HDDT_TOK` theo `TOKEN_TTL`, HTTP 401 thì đăng nhập lại đúng 1 lần |
| `H` | Gửi kèm header `username` / `password` (cách mã cũ dùng) |

## 7. Tài khoản UAT trong tài liệu

`read me.txt` của Viettel ghi 2 tài khoản test (`…-507` kiểm tra dữ liệu đầu vào,
`…-509` đã bỏ kiểm tra). Khai vào `ZFIT_HDDT_CRED`:

```
PROVIDER=VIETTEL  BUKRS=1000  INV_TYPE=(trống)
CONNID=UAT  TAXCODE=0100109106-507  TEMPLATE=1  SERIAL=<theo thông báo phát hành>
APIUSER=0100109106-507
```

Mật khẩu: xem [02-cau-hinh.md §7](02-cau-hinh.md) — **không** điền vào tài liệu
hay commit vào Git.
