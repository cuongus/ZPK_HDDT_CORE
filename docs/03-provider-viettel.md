# 03 — Adapter Viettel SInvoice

Lớp: `ZFIC_HDDT_PROV_VIETTEL` (kế thừa `ZFIC_HDDT_PROV_BASE`)

## 1. Nguồn tham chiếu — ĐÃ ĐỐI CHIẾU TÀI LIỆU

| Nguồn | Dùng cho |
|---|---|
| **"Tài liệu mô tả webservice hoá đơn điện tử" — V2.0 SInvoice, bản v2.44, Viettel, 11/2024, 162 trang** | Toàn bộ tên thẻ (mục 6.1–6.13), endpoint + Content-Type + tham số (mục 7.1–7.37), response mẫu |
| Postman collection Viettel | Đối chiếu chéo URL mục 7.2 → 7.37 |
| Mã ABAP đang chạy tại hệ EEMC (`ZFM_CREATE_E_INVOICES`) | Đối chiếu chéo quy tắc nghiệp vụ ĐC tăng/giảm |

Bản đầu tiên của adapter dựng theo tên component DDIC của mã cũ (mã cũ phải dùng
bảng `ZTB_JSON_REPLACE` để sửa chữ hoa/thường). Sau khi đối chiếu tài liệu v2.44:
**toàn bộ tên thẻ đã đúng**, nhưng phát hiện **4 lỗi thật** — đã sửa, xem §7.

## 2. Endpoint + Content-Type (đúng theo mục 7, đã nạp bởi `ZFIR_HDDT_SETUP`)

Base URL: `https://api-vinvoice.viettel.vn` — chỉ tới **host**, vì `/auth/login`
không cùng tiền tố với `/services/einvoiceapplication/api/…`

| ACTION | Method | API_PATH | Content-Type | Mục |
|---|---|---|---|---|
| `LOGIN` | POST | `/auth/login` | json | — |
| `CREATE_INVOICE` | POST | `…/InvoiceWS/createInvoice/{taxcode}` | json | 7.2 |
| `ADJUST_INVOICE` | POST | `…/InvoiceWS/createInvoice/{taxcode}` | json | 7.2 |
| `REPLACE_INVOICE` | POST | `…/InvoiceWS/createInvoice/{taxcode}` | json | 7.2 |
| `CREATE_DRAFT` | POST | `…/InvoiceWS/createOrUpdateInvoiceDraft/{taxcode}` | json | 7.8 |
| `PREVIEW_DRAFT` | POST | `…/InvoiceUtilsWS/createInvoiceDraftPreview/{taxcode}` | json | 7.20 |
| `GET_FILE` | POST | `…/InvoiceUtilsWS/getInvoiceRepresentationFile` | json | 7.3 |
| `CANCEL_INVOICE` | POST | `…/InvoiceWS/cancelTransactionInvoice` | **x-www-form-urlencoded** | 7.9 |
| `SEARCH_INVOICE` | POST | `…/InvoiceWS/searchInvoiceByTransactionUuid` | **x-www-form-urlencoded** | 7.21 |
| `GET_TEMPLATES` | POST | `…/InvoiceUtilsWS/getAllInvoiceTemplates` | json | 7.29 |

`…` = `/services/einvoiceapplication/api/InvoiceAPI`

Ba nghiệp vụ gốc / điều chỉnh / thay thế **dùng chung một endpoint** — phân biệt
bằng thẻ `adjustmentType`. Đây là lý do `ZFIT_HDDT_ACT` tách theo *nghiệp vụ*
chứ không theo *endpoint*: FPT thì mỗi nghiệp vụ một URL riêng.

> Ngoài ra tài liệu còn ghi form-urlencoded cho các mục 7.4 (lấy file có mã bí
> mật), 7.5 (file chuyển đổi), 7.18 / 7.19 (cập nhật / huỷ trạng thái thanh
> toán), 7.36 (gửi CQT bằng transactionUuid). Khi bổ sung các nghiệp vụ này,
> nhớ đặt `CONT_TYPE` tương ứng và dùng `BUILD_FORM( )` của lớp cha.

## 3. Payload phát hành — tên thẻ đã xác nhận từng cái

Khung chung (mục 6.1):

```
{ generalInvoiceInfo, buyerInfo, sellerInfo, payments[], itemInfo[],
  metadata[], meterReading, summarizeInfo, taxBreakdowns[] }
```

### generalInvoiceInfo (mục 6.2)

Adapter gửi: `invoiceType` · `templateCode` · `invoiceSeries` · `currencyCode` ·
`adjustmentType` · `transactionUuid` · `invoiceIssuedDate` · `exchangeRate` ·
`paymentStatus` · `cusGetInvoiceRight` · `invoiceNote` · `originalInvoiceId` ·
`originalInvoiceIssueDate` · `adjustmentInvoiceType` · `adjustedNote`

Tài liệu còn có (chưa dùng, thêm được qua `invoice-ext` không cần sửa code):
`DetailedListNo` · `DetailedListDate` · `additionalReferenceDesc` ·
`additionalReferenceDate` · `certificateSerial` · `originalInvoiceType` ·
`originalTemplateCode` · `reservationCode` · `adjustAmount20` · `validation` ·
`qrCode` · `otherTax`

Quy tắc đã cài:

- `invoiceIssuedDate` = **milliseconds since epoch** (mục 6.2 + 5.1), quy đổi
  theo tham số `TIME_ZONE` (mặc định `UTC+7` như tài liệu ghi GMT+7).
- `adjustmentType`: `1` gốc · `3` thay thế · `5` điều chỉnh · `7` xoá bỏ.
  Không truyền thì Viettel mặc định `1`.
- `adjustmentInvoiceType` **bắt buộc khi `adjustmentType = 5`**: `1` điều chỉnh
  tiền · `2` điều chỉnh thông tin.
- `adjustedNote` = **lý do sai sót**, tối đa 255 — khác `invoiceNote` (ghi chú
  in trên hoá đơn). Adapter chỉ gửi khi không phải hoá đơn gốc.
- `originalInvoiceId` / `originalInvoiceIssueDate` chỉ gửi khi thật sự có hoá
  đơn gốc; writer tự bỏ thẻ rỗng nên không cần `REPLACE` như mã cũ.
- `currencyCode = 'VND'` → `exchangeRate = 1`.
- `originalInvoiceType`: tài liệu ghi `Required: True` nhưng ghi chú ngay dưới
  nói *"không truyền hoặc truyền rỗng/0 thì không bắt buộc truyền
  `originalTemplateCode`, hệ thống xác thực như hiện trạng"* → adapter **không
  gửi**, phù hợp trường hợp hoá đơn gốc nằm trong hệ thống. Nếu điều chỉnh cho
  hoá đơn giấy / hoá đơn ngoài hệ thống thì phải gửi cặp
  `originalInvoiceType` + `originalTemplateCode` qua `invoice-ext`.

### sellerInfo (6.3) — đã xác nhận

`sellerLegalName` · `sellerTaxCode` · `sellerAddressLine` · `sellerPhoneNumber` ·
`sellerEmail` · `sellerBankName` · `sellerBankAccount`

Còn có: `sellerFaxNumber` · `sellerDistrictName` · `sellerCityName` ·
`sellerCountryCode` · `sellerWebsite` · `storeCode` · `storeName` ·
`merchantCode` · `merchantName` · `merchantCity`

### buyerInfo (6.4) — đã xác nhận

`buyerName` · `buyerCode` · `buyerLegalName` · `buyerTaxCode` ·
`buyerBudgetCode` · `buyerAddressLine` · `buyerPhoneNumber` · `buyerEmail` ·
`buyerBankName` · `buyerBankAccount` · `buyerIdNo` · `buyerNotGetInvoice`

Còn có: `buyerFaxNumber` · `buyerDistrictName` · `buyerCityName` ·
`buyerCountryCode` · `buyerIdType` · `buyerBirthDay`

### payments (6.5) — đã xác nhận

`paymentMethod` + `paymentMethodName` (đúng 2 thẻ)

### itemInfo (6.6) — đã xác nhận

Adapter gửi: `lineNumber` · **`selection`** · `itemCode` · `itemName` ·
`unitName` · `unitPrice` · `quantity` · `itemTotalAmountWithoutTax` ·
`taxPercentage` · `taxAmount` · `itemTotalAmountWithTax` · `discount` ·
`itemDiscount` · `itemNote` · `isIncreaseItem`

Còn có: `itemType` (loại hàng hoá đặc thù — bắt buộc khi `selection = 6`) ·
`unitCode` · `batchNo` · `expDate` · `discount2` ·
`itemTotalAmountAfterDiscount` · `adjustRatio` · `unitPriceWithTax`

**`selection` là thẻ quan trọng nhất của itemInfo** (mục 6.6, cột TT78):

| `selection` | Ý nghĩa | Sinh STT? | Cộng tổng tiền? |
|---|---|---|---|
| `1` (hoặc null) | Hàng hoá — **bắt buộc** số lượng + đơn giá | có | có |
| `2` | Ghi chú | không | **không** |
| `3` | Chiết khấu — **bắt buộc** `isIncreaseItem = false` | không | giảm |
| `4` | Phí khác | không | có |
| `5` | Khuyến mại — bắt buộc số lượng + đơn giá | có | có |
| `6` | Hàng hoá đặc trưng (NĐ70) — bắt buộc kèm `itemType` | có | có |

Ánh xạ `item_type` của canonical model → `selection` nằm trong
`ZFIT_HDDT_MAP` (`MAP_TYPE = ITEMTYPE`, `PROVIDER = VIETTEL`), nạp sẵn:
`0→1` hàng hoá · `1→5` khuyến mại · `2→3` chiết khấu · `3→2` ghi chú.
Sửa được bằng cấu hình, không phải sửa code.

### taxBreakdowns (6.7) — đã xác nhận

`taxPercentage` · `taxableAmount` · `taxAmount` · `taxableAmountPos` ·
`taxAmountPos` (còn có `taxExemptionReason`)

Thuế suất hợp lệ: `-2`, `-1`, `0`, `5`, `8`, `10`.

### summarizeInfo (6.8) — đã xác nhận

`sumOfTotalLineAmountWithoutTax` · `totalAmountWithoutTax` · `totalTaxAmount` ·
`totalAmountWithTax` · `discountAmount` · `totalAmountWithTaxInWords` ·
`isTotalAmountPos` · `isTotalTaxAmountPos` · `isTotalAmtWithoutTaxPos` ·
`isDiscountAmtPos`

Còn có: `totalAmountWithTaxFrn` · `settlementDiscountAmount` · `extraName` ·
`extraValue` · `totalAmountAfterDiscount`

Nhóm thẻ `is…Pos` và `isIncreaseItem` **chỉ gửi khi `adjustmentType = 5`** —
đúng như mã cũ phải dùng `REPLACE` để xoá chúng đi trên hoá đơn gốc.

## 4. Huỷ hoá đơn (mục 7.9)

`Content-Type: application/x-www-form-urlencoded`

| Tham số | Bắt buộc | Cách adapter điền |
|---|---|---|
| `supplierTaxCode` | ✔ | `ZFIT_HDDT_CRED-TAXCODE` |
| `templateCode` | | mẫu số từ request, thiếu thì đọc sổ đăng ký |
| `invoiceNo` | ✔ | ký hiệu + số; thiếu thì đọc `ZFIT_HDDT_INV`, không có thì báo lỗi rõ |
| `strIssueDate` | ✔ | **epoch millis** ngày phát hành |
| `additionalReferenceDesc` | ✔ | tên văn bản thoả thuận huỷ (max 400); trống thì dùng lý do huỷ để không bị 400 |
| `additionalReferenceDate` | ✔ | **epoch millis** ngày thoả thuận |
| `reasonDelete` | | lý do huỷ (max 255) |

Response thành công: `{"errorCode": null, "description": "CANCEL TRANSACTION INVOICE SUCCESS"}`

## 5. Lấy file hoá đơn (7.3) và tra cứu (7.21)

`GET_FILE` — JSON: `supplierTaxCode` ✔ · `invoiceNo` ✔ · `templateCode` ✔ ·
`transactionUuid` · `fileType` (**ZIP hoặc PDF**) · `paid` · `startDate` · `endDate`

> Tài liệu lưu ý: hệ thống xử lý **bất đồng bộ**, nên gọi lấy file **sau 2–5 giây**
> kể từ khi phát hành, và chỉ lấy được hoá đơn `state = 1`.

`SEARCH_INVOICE` — form-urlencoded, đúng 2 tham số: `supplierTaxCode` +
`transactionUuid` (max 36 ký tự).

## 6. Bóc response

Response phát hành (mục 7.2):

```json
{ "errorCode": null, "description": null,
  "result": { "supplierTaxCode": "...", "invoiceNo": "C23MHY3",
              "transactionID": "...", "reservationCode": "...",
              "codeOfTax": "M1-23-34567-00000000201" } }
```

| Thẻ | Đích trong `ty_result` |
|---|---|
| `errorCode` | `PROV_STATUS` — **null = thành công** |
| `description` / `message` | `MESSAGE` |
| `invoiceNo` | tách `SERIAL` + `SEQ` (xem §7 lỗi 4) |
| `codeOfTax` → nếu trống thì `reservationCode` | `MSCQT` |
| `transactionUuid` | `IDKEY` |
| `fileToBytes` | base64 → `FILE_CONTENT` |

⚠️ **Bất đồng bộ — điều phải xử lý ở vận hành.** Tài liệu mục 7.2 ghi chú 5:
nếu response trả `"invoiceNo": ""` thì **sau 30–90 giây** phải gọi lại
`SEARCH_INVOICE` (7.21) để lấy số hoá đơn. Adapter đã đặt trạng thái
`20 – Chờ cấp số` cho trường hợp này. Nên có job nền quét
`ZFIT_HDDT_INV` với `STATUS = '20'` rồi gọi `SEARCH_INVOICE` — chưa cài trong
bản này, xem việc còn lại ở [06-cai-dat.md §9](06-cai-dat.md).

`codeOfTax` chỉ có giá trị với **hoá đơn máy tính tiền**; loại khác trả `null`.

## 7. Bốn lỗi phát hiện khi đối chiếu tài liệu — đã sửa

| # | Lỗi | Hậu quả nếu không sửa | Đã sửa |
|---|---|---|---|
| 1 | Huỷ hoá đơn (7.9) và tra cứu (7.21) gửi **JSON**, tài liệu yêu cầu **form-urlencoded** | Viettel không parse được body → huỷ hoá đơn luôn thất bại | `BUILD_FORM( )` trong lớp cha; `CONT_TYPE` trong `ZFIT_HDDT_ACT` |
| 2 | `strIssueDate` / `additionalReferenceDate` gửi chuỗi `YYYY-MM-DD hh:mm:ss`, tài liệu yêu cầu **epoch millis** | Ngày sai định dạng → 400 | dùng `TO_EPOCH_MILLIS( )` |
| 3 | **Thiếu hẳn thẻ `selection`** | Dòng ghi chú bị cộng vào tổng tiền, dòng chiết khấu bị tính như hàng hoá bán → **sai số tiền trên hoá đơn thuế** | `GET_SELECTION( )` + ánh xạ `ITEMTYPE` trong `ZFIT_HDDT_MAP`; dòng chiết khấu tự gửi `isIncreaseItem = false` |
| 4 | Tách `SERIAL`/`SEQ` bằng cách đoán chữ số ở cuối `invoiceNo` | Ký hiệu TT78 kết thúc bằng số (ví dụ `K23T01`) bị cắt sai → sổ đăng ký ghi sai số hoá đơn | bỏ **tiền tố ký hiệu đã biết** từ cấu hình; chỉ khi không khớp mới quay lại cách đoán |

Thiếu sót nhỏ đã bổ sung cùng lúc: `adjustedNote` (lý do sai sót),
`buyerBudgetCode` (mã quan hệ ngân sách), `paymentMethod` (trước chỉ gửi
`paymentMethodName`).

## 8. Xác thực (mục 7.2 Headers)

Tài liệu: *"Cookie: giá trị access_token **hoặc** Authorization: username/pass
như đăng nhập trên web"*.

| `ZFIT_HDDT_CONN-AUTH_MODE` | Cách hoạt động |
|---|---|
| `B` | Basic auth — đơn giản nhất, dùng được RFC destination (an toàn nhất) |
| `T` | Bearer token: core gọi `LOGIN` → `/auth/login`, cache trong `ZFIT_HDDT_TOK` theo `TOKEN_TTL`; HTTP 401 thì đăng nhập lại đúng 1 lần |
| `H` | Gửi kèm header `username` / `password` (cách mã cũ ở hệ EEMC dùng) |

## 9. Quy tắc ngày lập hoá đơn — ảnh hưởng cấu hình `ZFIT_HDDT_DATE`

Mục 7.2 mô tả 4 trường hợp tuỳ 2 checkbox trên portal SInvoice
("Cho phép ngày lập hoá đơn khác ngày hiện tại", "Tự động đặt giá trị cho ngày
lập hoá đơn bằng ngày lập gần nhất"). Điểm chung của cả 4:

- Không truyền `invoiceIssuedDate` → Viettel lấy ngày giờ hiện tại (GMT+7).
- **Số hoá đơn sau phải có thời gian ≥ số hoá đơn trước** trong cùng ký hiệu.

Hệ quả thực tế: nếu đặt `ZFIT_HDDT_DATE-DATE_SRC = 1` (posting date) và phát
hành chứng từ cũ sau chứng từ mới, Viettel sẽ báo *ngày lập không hợp lệ*.
An toàn nhất khi phát hành theo lô là `DATE_SRC = 3` (ngày hệ thống), hoặc phát
hành đúng thứ tự thời gian chứng từ.
