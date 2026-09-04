# 02 — Hướng dẫn cấu hình

Transaction: **`ZFI002`** (nhấn đôi vào bảng để bảo trì).

Thứ tự cấu hình khi triển khai mới đúng bằng thứ tự các mục dưới đây.

---

## 1. `ZTB_HDDT_PROV` — Danh mục nhà cung cấp

| Trường | Ý nghĩa |
|---|---|
| `PROVIDER` | Mã tự đặt: `VIETTEL`, `FPT`, `VNPT`, `TEMPLATE`… |
| `CLASSNAME` | **Tên lớp adapter**. Phải implement `ZIF_HDDT_PROVIDER` và `GET_ID( )` phải trả về đúng `PROVIDER` (engine kiểm tra và báo lỗi rõ nếu lệch) |
| `DESCR` | Mô tả |
| `XACTIVE` | Bỏ tick = khoá nhà cung cấp, không gọi được |

`ZPG_HDDT_SETUP` nạp sẵn 4 dòng.

---

## 2. `ZTB_HDDT_CONN` — Kết nối

| Trường | Ý nghĩa |
|---|---|
| `PROVIDER` / `CONNID` | Khoá. `CONNID` phân biệt môi trường: `UAT`, `PRD` |
| `RFCDEST` | **Ưu tiên dùng.** RFC destination loại G (SM59). Basis quản chứng chỉ, proxy, user/password |
| `BASE_URL` | Dùng khi không muốn tạo destination. Chỉ tới **host** (`https://api-vinvoice.viettel.vn`), phần đường dẫn nằm trong `ZTB_HDDT_ACT` |
| `AUTH_MODE` | `B` Basic · `H` user/pass trong header · `T` Bearer token · `O` OAuth2 · `N` không (destination tự lo, hoặc tài khoản nằm trong payload như FPT) |
| `TOKEN_ACTION` | Action của endpoint đăng nhập, mặc định `LOGIN` |
| `TOKEN_TTL` | Số giây token sống, mặc định 3000 |
| `TIMEOUT` | Giây, mặc định 60 |
| `SSL_ID` | SSL client identity trong STRUST khi dùng `BASE_URL` (thường `ANONYM`) |

> Chỉ cần điền **một trong hai**: `RFCDEST` **hoặc** `BASE_URL`. Nếu điền cả hai,
> `RFCDEST` thắng.

---

## 3. `ZTB_HDDT_ACT` — Endpoint theo nghiệp vụ

| Trường | Ý nghĩa |
|---|---|
| `PROVIDER` / `ACTION` | Khoá. `ACTION` là mã nghiệp vụ của core (xem bảng dưới) |
| `HTTP_METHOD` | `GET` / `POST` / `PUT` / `PATCH` / `DELETE` |
| `API_PATH` | Đường dẫn tương đối, hỗ trợ placeholder |
| `CONT_TYPE` / `ACCEPT_TYPE` | mặc định `application/json` / `*/*` |

### Mã nghiệp vụ (`ACTION`)

`LOGIN` · `CREATE_INVOICE` · `CREATE_DRAFT` · `PREVIEW_DRAFT` ·
`APPROVE_INVOICE` · `UPDATE_INVOICE` · `REPLACE_INVOICE` · `ADJUST_INVOICE` ·
`CANCEL_INVOICE` · `DELETE_INVOICE` · `SEARCH_INVOICE` · `GET_FILE` ·
`SEND_MAIL` · `GET_TEMPLATES` · `WRONG_NOTICE`

### Placeholder trong `API_PATH`

| Placeholder | Giá trị |
|---|---|
| `{taxcode}` | `ZTB_HDDT_CRED-TAXCODE` (MST người bán) |
| `{template}` | Mẫu số hoá đơn |
| `{serial}` | Ký hiệu hoá đơn |
| `{seq}` | Số hoá đơn |
| `{idkey}` | Khoá đối chiếu (`transactionUuid` / `sid`) |
| `{bukrs}` | Mã công ty |
| `{apiuser}` | Tài khoản API |
| bất kỳ tên trong `ty_request-params` | do caller truyền |

Placeholder không có giá trị bị **xoá khỏi URL**, không gửi chuỗi `{taxcode}`
lên nhà cung cấp.

Ví dụ Viettel:
```
/services/einvoiceapplication/api/InvoiceAPI/InvoiceWS/createInvoice/{taxcode}
```

---

## 4. `ZTB_HDDT_CRED` — Tài khoản và dải số

| Trường | Ý nghĩa |
|---|---|
| `PROVIDER` / `BUKRS` / `INV_TYPE` | Khoá. `INV_TYPE` để trống = dòng mặc định cho mọi loại hoá đơn |
| `CONNID` | Trỏ tới `ZTB_HDDT_CONN`. Để trống → lấy kết nối active đầu tiên |
| `TAXCODE` | **Bắt buộc.** MST người bán, ví dụ `0100109106-507` |
| `TEMPLATE` | Mẫu số hoá đơn đã đăng ký, ví dụ `1` |
| `SERIAL` | Ký hiệu hoá đơn, ví dụ `K26TAA` |
| `APIUSER` | Tài khoản API |
| `SECKEY` | Khoá tra cứu trong vault (nếu dùng `SECRET_CLASS`) |
| `APISECRET` | Mật khẩu — **phương án dự phòng**, xem §7 |
| `VALID_FROM` / `VALID_TO` | Hiệu lực. Đây là cơ chế **cắt chuyển nhà cung cấp theo ngày** |
| `XACTIVE` | Bỏ tick = không dùng dòng này |

Cách chọn dòng: khớp chính xác `INV_TYPE` được ưu tiên; nếu không có thì dùng
dòng `INV_TYPE` rỗng. Dòng ngoài khoảng hiệu lực bị bỏ qua.

---

## 5. `ZTB_HDDT_SRC` — Lớp đọc dữ liệu nguồn

| Trường | Ý nghĩa |
|---|---|
| `BUKRS` | Để trống = áp cho mọi công ty |
| `SRC_TYPE` | `FI` / `SD` / `MM` / `GOM` / `CUST` |
| `CLASSNAME` | Lớp implement `ZIF_HDDT_SOURCE` |

Mặc định: `('', 'FI') → ZCL_HDDT_SRC_FI` (chứng từ FI, kể cả FI sinh từ
billing SD) và `('', 'SD') → ZCL_HDDT_SRC_SD` (billing SD **chưa** có chứng từ
FI). Cả hai kế thừa `ZCL_HDDT_SRC_BASE`. Logic chi tiết: [09-nguon-du-lieu.md](09-nguon-du-lieu.md).

Công ty có nghiệp vụ riêng: copy `ZCL_HDDT_SRC_FI` thành
`ZCL_HDDT_SRC_FI_1000`, sửa, rồi thêm dòng `(1000, 'FI')` trỏ lớp mới. Dòng
theo công ty thắng dòng chung.

---

## 6. `ZTB_HDDT_PARM` — Tham số

Tìm theo thứ tự: `(provider, bukrs)` → `(provider, '')` → `('', bukrs)` → `('', '')`.
Nhờ vậy đặt được giá trị chung rồi ghi đè cho một công ty.

| `PARM_KEY` | Ý nghĩa |
|---|---|
| `ACTIVE_PROVIDER` | **Nhà cung cấp đang dùng.** Không khai thì core suy từ `ZTB_HDDT_CRED` nếu công ty chỉ có 1 nhà cung cấp active |
| `DEFAULT_CONNID` | Kết nối mặc định |
| `TIME_ZONE` | Múi giờ quy đổi epoch millis, ví dụ `UTC+7` |
| `LOCAL_CURRENCY` | Tiền tệ ghi sổ, mặc định `VND` |
| `LOG_PAYLOAD` | `X` = lưu request/response trong log (khuyến nghị BẬT) — xem [08-log-tich-hop.md](08-log-tich-hop.md) |
| `LOG_MASK_TAGS` | Danh sách thẻ cần che trong log, cách nhau dấu phẩy. **Phải đúng** vì payload FPT/VNPT chứa mật khẩu ngay trong body |
| `LOG_TEST_RUN` | `X` = ghi log cả lần Test run (mặc định không, tránh rác) |
| `PLATFORM_CLASS` | Lớp nền tảng; để trống = ABAP cổ điển, Public Cloud đặt `ZCL_HDDT_PLAT_CLOUD` |
| `SELLER_NAME` / `SELLER_ADDR` / `SELLER_MAIL` / `SELLER_TEL` / `SELLER_BANK` / `SELLER_ACCT` | Thông tin bên bán — nhờ vậy **không hardcode** trong code |
| `SECRET_CLASS` | Lớp implement `ZIF_HDDT_SECRET` để lấy mật khẩu từ vault |
| `FPT_LANG` | `vi` / `en` — ngôn ngữ thông báo lỗi của FPT |
| `FPT_AUN` | `''` lưu nháp · `1` số do SAP cấp · `2` FPT cấp số |
| `FPT_USER_IN_BODY` | `X` gửi nút `user` trong payload · `N` không (khi dùng Basic/JWT) |
| `FPT_PLACE` | Địa danh — bắt buộc khi huỷ hoá đơn theo TT78 |
| `INV_DATE_MAX_BACKDAYS` | Ngày lập HĐ lùi tối đa N ngày so với hôm nay (seed `1`); trống = không giới hạn |
| `BUYER_TAX_IDTYPE` / `BUYER_ID_IDTYPE` | Loại số định danh BP (`BUT0ID-TYPE`) chứa MST (`VATRU`) / CCCD (`FS0001`) |
| `BUYER_NAME_FIELDS` | Trường `BUT000` ghép thành tên tổ chức, vd `NAME_ORG1,NAME_ORG2,NAME_ORG3,NAME_ORG4` |
| `ADDR_COUNTRY_SUFFIX` | Hậu tố nối vào địa chỉ VN (`Việt Nam`); `-` = không thêm |
| `EXCH_RATE_FACTOR` | Hệ số nhân `BKPF-KURSF` (dự án cũ dùng 1000), mặc định `1` |
| `SELLER_FROM_T001` | `X` = người bán từ `T001/ADRC/ADR6`; `SELLER_*` chỉ điền chỗ trống |
| `TEXT_LANGU` | Ngôn ngữ tên đơn vị tính / vật tư (`E`) |
| `ITEM_TEXT_IDS` | Long text lấy tên hàng theo thứ tự, `ID:OBJECT;ID:OBJECT` (`ZI03:VBBP;GRUN:MATERIAL`) |
| `ITEM_QTY_ABS` | `X` = số lượng luôn dương |
| `DEFAULT_PAYMENT` | Hình thức thanh toán khi chứng từ không có `ZLSCH` (`TM/CK`) |
| `TAX_COND_TYPE` | Loại điều kiện thuế đầu ra tra `A003/KONP` khi thiếu BSET (`MWAS`) |
| `STATUS_CHECK` | `N` = tắt kiểm tra nghiệp vụ theo trạng thái trong engine |
| `CANCEL_REQUIRES_REVERSAL` | `N` = cho huỷ HĐĐT khi chứng từ SAP chưa đảo (mặc định bắt buộc đảo) |

---

## 7. Bảo mật mật khẩu API

Ba phương án, ưu tiên từ trên xuống:

**(1) RFC destination — khuyến nghị.** SM59 → destination loại G → tab Logon &
Security → điền user/password. Trong `ZTB_HDDT_CONN` đặt `RFCDEST` và
`AUTH_MODE = 'N'`; destination tự gắn header Authorization. Mật khẩu nằm trong
secure store của SAP, không ai đọc được qua SE16.

> Lưu ý: cách này **không dùng được cho FPT khi `FPT_USER_IN_BODY = 'X'`**, vì
> FPT nhận tài khoản trong payload. Với FPT hãy dùng phương án (2), hoặc đặt
> `FPT_USER_IN_BODY = 'N'` + `AUTH_MODE = 'B'` (FPT hỗ trợ Basic auth — tài liệu
> mục 3.10.5.2).

**(2) Vault riêng.** Viết lớp:

```abap
CLASS zcl_my_hddt_vault DEFINITION PUBLIC CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES zif_hddt_secret.
ENDCLASS.

CLASS zcl_my_hddt_vault IMPLEMENTATION.
  METHOD zif_hddt_secret~get_secret.
    " is_cred-seckey là khoá tra cứu; trả về mật khẩu
    r_secret = ...   " gọi CyberArk / Vault / SSFS của bạn
  ENDMETHOD.
ENDCLASS.
```

Rồi khai `ZTB_HDDT_PARM: PARM_KEY = SECRET_CLASS, PARM_VAL = ZCL_MY_HDDT_VAULT`.

**(3) Trường `APISECRET`.** Chỉ khi hai cách trên không khả thi. Bắt buộc kèm:

- SE54 → Authorization group riêng cho `ZTB_HDDT_CRED`, chỉ cấp cho key user.
- Không cấp `S_TABU_DIS` / `S_TABU_NAM` cho bảng này ở PRD ngoài nhóm đó.
- Không cấp `SE16`/`SE16N` trên `ZTB_HDDT_CRED` cho developer ở PRD.

Chế độ **Test run** không đọc mật khẩu thật — payload hiển thị luôn là
`"password":"********"`.

---

## 8. `ZTB_HDDT_STAT` — Ánh xạ trạng thái

| Trường | Ý nghĩa |
|---|---|
| `PROVIDER` / `ACTION` / `RC_CODE` | Khoá. `ACTION = '*'` = áp cho mọi nghiệp vụ |
| `SAP_STATUS` | Trạng thái nội bộ: `00` chưa gửi · `10` đã gửi · `20` chờ cấp số · `30` chờ duyệt · `40` đã phát hành · `50` đã cấp mã CQT · `60` đã điều chỉnh · `70` đã thay thế · `80` đã huỷ · `90` lỗi |
| `MSGTY` | `S` / `W` / `E` — quyết định `SUCCESS` |
| `MSG_TEXT` | Thông điệp hiển thị khi NCC không trả text |

Không tìm thấy dòng nào → core tự suy từ mã HTTP + action. Bảng này để **ghi
đè** khi cần mịn hơn.

---

## 9. `ZTB_HDDT_MAP` — Ánh xạ giá trị

| `MAP_TYPE` | `SAP_VALUE` | `EXT_VALUE` | `EXT_TEXT` |
|---|---|---|---|
| `TAXRATE` | mã thuế `MWSKZ`, hoặc thuế suất | thuế suất số (`10`) hoặc mã NCC | nhãn (`10%`, `KCT`) |
| `PAYMENT` | `BSEG-ZLSCH` | mã NCC | tên hiển thị (`TM`, `CK`) |
| `UNIT` | `MEINS` | đơn vị theo NCC | |
| `GLACCT` | tài khoản doanh thu | `X` | tên hàng hoá mặc định |
| `INVTYPE` / `ITEMTYPE` / `CURRENCY` / `DOCTYPE` | tương tự | | |
| `TAXCODE` | mẫu `MWSKZ` (CP: `O*`, `**`) | `X` | mã thuế đầu ra được phát hành |
| `TAXACCT` | mẫu tài khoản (`3331*`) | `X` | TK thuế GTGT loại khỏi dòng hàng |
| `BILLTYPE` | `VBRK-FKART` | `X` | loại billing SD phát hành khi chưa có FI (**bắt buộc** cho nguồn SD) |
| `CONDTYPE` | `KSCHL` | `AMT+` / `AMT-` / `TAX` | vai trò loại điều kiện giá SD |

- `PROVIDER` để trống = ánh xạ dùng ở **tầng đọc dữ liệu nguồn** (không phụ
  thuộc nhà cung cấp).
- `PROVIDER` điền = ánh xạ riêng của nhà cung cấp đó.
- **Không có cấu hình → core dùng nguyên giá trị SAP** (fail-safe: không chặn
  nghiệp vụ, sai lệch sẽ hiện trong log và response của NCC).

---

## 10. `ZTB_HDDT_DATE` — Ngày lập hoá đơn

| `DATE_SRC` | Nguồn |
|---|---|
| `1` | Posting date `BKPF-BUDAT` |
| `2` | Entry date `BKPF-CPUDT` |
| `3` | System date `SY-DATUM` |
| `4` | Document date `BKPF-BLDAT` |

Không khai → dùng `SY-DATUM`.

---

## 11. `ZTB_HDDT_TPL` — Mẫu payload

Chỉ dùng cho `ZCL_HDDT_PROV_TEMPLATE` và lớp con (`ZCL_HDDT_PROV_VNPT`).
Xem [05-provider-vnpt.md](05-provider-vnpt.md).
