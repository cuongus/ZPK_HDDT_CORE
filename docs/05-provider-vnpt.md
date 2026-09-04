# 05 — Adapter VNPT / Vinaphone (theo mẫu payload)

Lớp: `ZCL_HDDT_PROV_VNPT` → kế thừa `ZCL_HDDT_PROV_TEMPLATE`

## 1. Trạng thái — đọc trước

**Không có tài liệu đặc tả API VNPT/Vinaphone trong bộ tài liệu được cung cấp.**
Bộ tài liệu chỉ gồm Viettel v2.44 và FPT v2.4.7.

Vì vậy adapter VNPT **không hardcode** cấu trúc payload — nếu tự suy đoán thì
gần như chắc chắn sai và tệ hơn là *trông như đúng*. Thay vào đó nó dựng payload
từ **mẫu (template)** khai trong bảng `ZTB_HDDT_TPL`.

Khi có tài liệu VNPT, việc cần làm:

1. Dán mẫu payload vào `ZTB_HDDT_TPL` (một dòng cho mỗi nghiệp vụ).
2. Khai endpoint vào `ZTB_HDDT_ACT`.
3. Khai URL / xác thực vào `ZTB_HDDT_CONN`, bật `XACTIVE`.

**Không phải viết một dòng ABAP nào.**

Lợi ích phụ: cùng cơ chế này dùng được cho bất kỳ nhà cung cấp thứ tư nào
(MISA, BKAV, Wintech, M-Invoice…) mà payload đủ đơn giản để mô tả bằng mẫu — kể
cả payload **XML**.

## 2. Cú pháp mẫu

### Giá trị đơn

| Placeholder | Nguồn |
|---|---|
| `{{header.<field>}}` | `ty_invoice-header` (idkey, inv_type, template, serial, seq, currency, exch_rate, note, place, send_type…) |
| `{{seller.<field>}}` | `ty_invoice-seller` (tax_code, name, address, phone, email, bank_name, bank_acct) |
| `{{buyer.<field>}}` | `ty_invoice-buyer` (code, tax_code, legal_name, person_name, address, phone, email, bank_name, bank_acct, id_number, budget_code) |
| `{{summary.<field>}}` | `ty_invoice-summary` (amount_wo_tax, amount_wo_tax_l, tax_amount, tax_amount_l, total, total_l, disc_amount, amount_in_words) |
| `{{adjust.<field>}}` | `ty_invoice-adjust` (adj_type, adj_direction, org_serial, org_seq, org_inv_date, doc_ref_no, doc_ref_date, reason) |
| `{{cred.<field>}}` | `ZTB_HDDT_CRED` (taxcode, template, serial, apiuser, apisecret) |
| `{{req.<field>}}` | `ty_request` (bukrs, gjahr, src_type, src_docno, provider, action) |
| `{{parm.<TEN_THAM_SO>}}` | `ZTB_HDDT_PARM` của chính nhà cung cấp này |

### Hàm dựng sẵn

| Placeholder | Kết quả |
|---|---|
| `{{fn.invoice_datetime}}` | `YYYY-MM-DD hh:mm:ss` |
| `{{fn.invoice_date}}` | `YYYY-MM-DD` |
| `{{fn.invoice_date_vn}}` | `DD/MM/YYYY` |
| `{{fn.invoice_millis}}` | epoch millis (theo tham số `TIME_ZONE`) |
| `{{fn.now_datetime}}` | thời điểm hiện tại |
| `{{fn.item_count}}` | số dòng hàng hoá |

### Vòng lặp

```
{{#items}}  … {{item.<field>}} …  {{/items}}
{{#taxes}}  … {{tax.<field>}}  …  {{/taxes}}
```

`item.*`: line_no, item_type, item_code, item_name, unit, quantity, price,
amount, tax_rate, tax_rate_txt, tax_amount, total, disc_percent, disc_amount, note
`tax.*`: tax_rate, tax_rate_txt, taxable_amt, taxable_amt_l, tax_amt, tax_amt_l

### Escape

| Dạng | Khi nào |
|---|---|
| `{{$json.buyer.legal_name}}` | mẫu là JSON — escape `"` `\` và ký tự điều khiển |
| `{{$xml.buyer.legal_name}}` | mẫu là XML — escape `& < > " '` |
| `{{buyer.legal_name}}` | không escape (dùng cho số, mã, ngày) |

**Luôn dùng `$json.` / `$xml.` cho mọi giá trị do người dùng nhập** (tên, địa chỉ,
ghi chú) — nếu không, một dấu `"` trong tên khách hàng sẽ làm vỡ payload.

### Quy tắc định dạng tự động

- Field số (packed / integer) → chuẩn JSON: `10450`, `-500`, không zero dẫn đầu.
- Field `DATS` → `YYYY-MM-DD`.
- Field `TIMS` → `hh:mm:ss`.
- Field CHAR trong DDIC được `CONDENSE` (bỏ khoảng trắng đệm bên phải).
- Placeholder không nhận dạng được → **rỗng**, không gửi chuỗi `{{…}}` lên NCC
  (nhìn thấy ngay khi bấm "Xem payload").

## 3. Ví dụ mẫu JSON

`ZTB_HDDT_TPL`: `PROVIDER = VNPT`, `ACTION = CREATE_INVOICE`, `XACTIVE = X`

```json
{
  "account": "{{cred.apiuser}}",
  "acpass": "{{cred.apisecret}}",
  "pattern": "{{header.template}}",
  "serial": "{{header.serial}}",
  "invoice": {
    "key": "{{header.idkey}}",
    "date": "{{fn.invoice_datetime}}",
    "sellerTax": "{{cred.taxcode}}",
    "buyerName": "{{$json.buyer.legal_name}}",
    "buyerTax": "{{buyer.tax_code}}",
    "buyerAddr": "{{$json.buyer.address}}",
    "currency": "{{header.currency}}",
    "rate": {{header.exch_rate}},
    "amountNoTax": {{summary.amount_wo_tax}},
    "vatAmount": {{summary.tax_amount}},
    "total": {{summary.total}},
    "products": [
      {{#items}}
      {
        "line": {{item.line_no}},
        "name": "{{$json.item.item_name}}",
        "unit": "{{$json.item.unit}}",
        "qty": {{item.quantity}},
        "price": {{item.price}},
        "amount": {{item.amount}},
        "vatRate": {{item.tax_rate}},
        "vatAmount": {{item.tax_amount}}
      },
      {{/items}}
      {}
    ]
  }
}
```

> Thủ thuật `{}` ở cuối mảng: mẫu là chuỗi văn bản nên không tự bỏ dấu phẩy sau
> phần tử cuối. Nếu nhà cung cấp không chấp nhận phần tử rỗng, hãy dùng adapter
> chuyên biệt (kế thừa `ZCL_HDDT_PROV_BASE`, dùng `ZCL_HDDT_JSON` writer — nó
> quản lý dấu phẩy tự động).

## 4. Ví dụ mẫu XML

API VNPT cổ điển nhận một chuỗi XML trong tham số `xmlInvData`:

```xml
<Invoices><Inv><Invoice>
  <CusCode>{{$xml.buyer.code}}</CusCode>
  <CusName>{{$xml.buyer.legal_name}}</CusName>
  <CusAddress>{{$xml.buyer.address}}</CusAddress>
  <CusTaxCode>{{buyer.tax_code}}</CusTaxCode>
  <PaymentMethod>{{$xml.parm.VNPT_PAYM}}</PaymentMethod>
  <ArisingDate>{{fn.invoice_date_vn}}</ArisingDate>
  <CurrencyUnit>{{header.currency}}</CurrencyUnit>
  <ExchangeRate>{{header.exch_rate}}</ExchangeRate>
  <Products>
    {{#items}}
    <Product>
      <Code>{{$xml.item.item_code}}</Code>
      <ProdName>{{$xml.item.item_name}}</ProdName>
      <ProdUnit>{{$xml.item.unit}}</ProdUnit>
      <ProdQuantity>{{item.quantity}}</ProdQuantity>
      <ProdPrice>{{item.price}}</ProdPrice>
      <Amount>{{item.amount}}</Amount>
      <VATAmount>{{item.tax_amount}}</VATAmount>
      <VATRate>{{item.tax_rate}}</VATRate>
    </Product>
    {{/items}}
  </Products>
  <Total>{{summary.amount_wo_tax}}</Total>
  <VATAmount>{{summary.tax_amount}}</VATAmount>
  <Amount>{{summary.total}}</Amount>
  <AmountInWords>{{$xml.summary.amount_in_words}}</AmountInWords>
</Invoice></Inv></Invoices>
```

Nhớ đặt `ZTB_HDDT_ACT-CONT_TYPE` phù hợp (`text/xml` hoặc
`application/soap+xml`).

## 5. Bóc response

`ZCL_HDDT_PROV_VNPT~PARSE_RESPONSE` xử lý:

| Dạng response | Cách xử lý |
|---|---|
| JSON / XML (bắt đầu `{`, `[`, `<`) | chuyển cho lớp cha `ZCL_HDDT_PROV_TEMPLATE`: parse JSON, bóc `serial`, `seq`, `sec`, `link`, `message` |
| Text `OK:<mẫu>;<ký hiệu>-<số>` | `SUCCESS = X`, tách `TEMPLATE` / `SERIAL` / `SEQ` |
| Text `ERR:<n>` | `PROV_STATUS = 'ERR<n>'`, tra `ZTB_HDDT_STAT` để ra thông điệp tiếng Việt |

> **[Unverified]** Quy ước `OK:` / `ERR:n` là quy ước phổ biến của API VNPT cổ
> điển, **chưa đối chiếu tài liệu**. Nếu hợp đồng của bạn dùng REST/JSON thì
> nhánh JSON của lớp cha đã xử lý sẵn, không cần sửa gì.

Khai bảng mã lỗi VNPT vào `ZTB_HDDT_STAT` để có thông điệp tiếng Việt:

```
PROVIDER=VNPT  ACTION=*  RC_CODE=ERR1  SAP_STATUS=90  MSGTY=E  MSG_TEXT=Tai khoan khong hop le
PROVIDER=VNPT  ACTION=*  RC_CODE=ERR7  SAP_STATUS=90  MSGTY=E  MSG_TEXT=Du lieu XML khong dung dinh dang
PROVIDER=VNPT  ACTION=*  RC_CODE=OK    SAP_STATUS=40  MSGTY=S  MSG_TEXT=Da phat hanh
```

## 6. Khi nào nên viết adapter chuyên biệt thay vì dùng mẫu

| Dùng mẫu (`ZTB_HDDT_TPL`) | Viết lớp riêng |
|---|---|
| Payload dạng "phẳng", ánh xạ 1-1 với canonical model | Cần logic điều kiện (thẻ này chỉ gửi khi điều chỉnh tăng…) |
| Không phải bỏ thẻ rỗng | Phải bỏ thẻ rỗng theo từng trường hợp |
| Ít nghiệp vụ (phát hành + huỷ) | Nhiều nghiệp vụ với payload khác nhau hẳn |
| Muốn key user tự sửa được, không cần transport | Cần đơn vị test ABAP Unit cho phần dựng payload |
