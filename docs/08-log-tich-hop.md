# 08 — Log tích hợp

Transaction: **`ZFI003`** · Bảng: `ZTB_HDDT_LOG`

## 1. Mục đích

Log HĐĐT không phải log kỹ thuật để lập trình viên debug. Nó là **bằng chứng
đối chiếu** với nhà cung cấp và với cơ quan thuế: hoá đơn nào đã gửi, lúc nào,
ai gửi, gửi đúng số tiền hay không, nhà cung cấp trả lời gì. Vì vậy mặc định
**luôn lưu payload**.

Bốn câu hỏi màn hình này trả lời:

| Câu hỏi | Cách xem |
|---|---|
| Chứng từ này đã gửi những lần nào, ai gửi? | danh sách ALV — cột `Lần thứ`, `Chương trình gọi`, `Người tạo` |
| JSON gửi đi có đúng không? | nút **Xem request** (nhấn đôi cũng được) |
| Nhà cung cấp trả về gì? | nút **Xem response** |
| Xác thực / header có đúng không? | nút **Xem header** |

Nút **Tải nguyên bản** lưu đúng byte đã đi trên đường truyền xuống máy trạm —
để gửi cho bộ phận hỗ trợ của nhà cung cấp khi cần đối chất.

## 2. Vì sao payload lưu dạng XSTRING

`REQ_BODY` / `RES_BODY` / `REQ_HEADER` / `RES_HEADER` có kiểu `ZDE_HDDT_RAW`
(DDIC `RAWSTRING`).

> **Đính chính một hiểu nhầm phổ biến:** field kiểu `STRING` trong bảng DDIC
> **không** bị giới hạn độ dài — nó là LOB, tối đa 2GB. Giới hạn ~1333 ký tự
> (và 255 ở nhiều trường hợp thực tế) chỉ áp cho field `CHAR`. Nên lý do đổi
> sang xstring **không phải** vì payload dài.

Lý do thật, và là lý do mạnh hơn: **toàn vẹn từng byte**. XSTRING lưu đúng dãy
byte đã gửi, kể cả cách encode UTF-8 của tiếng Việt. Giữa "cái đã gửi" và "cái
đã lưu" không có một lượt chuyển codepage nào chen vào. Khi tranh chấp, đó là
khác biệt giữa *bằng chứng* và *bản sao gần đúng*.

Trường `CODEPAGE` ghi lại bảng mã đã dùng (mặc định `UTF-8`) để màn hình giải
mã lại đúng. Trường `REQ_SIZE` / `RES_SIZE` là **số byte thật** (`xstrlen`),
không phải số ký tự — nên dùng được để theo dõi dung lượng bảng.

## 3. Che secret — bắt buộc, làm lúc GHI

Payload của một số nhà cung cấp chứa tài khoản **ngay trong body**:

```
FPT  :  { "user": { "username": "0100100008.admin", "password": "..." }, "inv": {...} }
VNPT :  { "account": "...", "acpass": "...", ... }
```

Nếu ghi nguyên văn thì mật khẩu API nằm plaintext trong bảng log — ai đọc được
bảng là đọc được mật khẩu, kể cả người chỉ được cấp quyền *xem log*.

`ZCL_HDDT_LOG=>MASK_SECRETS( )` che **trước khi ghi**, ở 4 dạng:

| Dạng | Trước | Sau |
|---|---|---|
| JSON có ngoặc kép | `"password":"admin@123"` | `"password":"********"` |
| JSON không ngoặc kép | `"token": abc123` | `"token":"********"` |
| form-urlencoded | `password=abc&x=1` | `password=********&x=1` |
| HTTP header | `Authorization: Basic eGY6...` | `Authorization: ********` |

Danh sách thẻ khai trong `ZTB_HDDT_PARM`, key **`LOG_MASK_TAGS`**, cách nhau
bằng dấu phẩy. Mặc định:

```
password,acpass,pass,secret,client_secret,token,access_token,authorization,apikey,api_key
```

Thêm nhà cung cấp có tên thẻ khác thì **thêm vào tham số này**, không sửa code.
Cột `MASKED` trên ALV cho biết dòng đó có thật sự bị che gì hay không.

> Việc che là **một chiều, không phục hồi được** — đúng như mong muốn. Nếu cần
> đối chiếu chính xác cả mật khẩu (rất hiếm), phải lấy từ phía nhà cung cấp.

## 4. Cấu trúc bảng `ZTB_HDDT_LOG`

| Nhóm | Trường |
|---|---|
| Khoá | `LOG_ID` (GUID 32 ký tự) |
| Định danh nghiệp vụ | `PROVIDER` `CONNID` `ACTION` `BUKRS` `GJAHR` `SRC_TYPE` `SRC_DOCNO` `IDKEY` |
| Lần gọi | `ATTEMPT` (lần thứ mấy cho cùng chứng từ + nghiệp vụ), `TEST_RUN` |
| Kết quả | `SERIAL` `SEQ` `SAP_STATUS` `PROV_STATUS` `MSGTY` `MESSAGE` |
| Kỹ thuật HTTP | `HTTP_METHOD` `FULL_URL` `CONT_TYPE` `HTTP_CODE` `HTTP_REASON` `DURATION_MS` |
| Dung lượng | `REQ_SIZE` `RES_SIZE` `CODEPAGE` `MASKED` |
| Truy vết nguồn gọi | `CALLER` (`SY-CPROG`) `TCODE` `CREATED_BY` `CREATED_AT` |
| Nội dung byte | `REQ_HEADER` `RES_HEADER` `REQ_BODY` `RES_BODY` |

`ATTEMPT` được đếm bằng `COUNT_ATTEMPTS( )` — bỏ qua các dòng `TEST_RUN`, nên
số lần hiển thị là **số lần gọi thật**. Nhờ trường này nhìn ngay ra chứng từ
nào phải gọi 5 lần mới thành công.

`CALLER` phân biệt phát hành từ màn hình `ZFI001`, từ job nền, hay từ
enhancement — khi một chứng từ có nhiều dòng log thì đây là thứ cho biết ai
đã gọi.

Màn hình danh sách **không đọc** `REQ_BODY` / `RES_BODY`: payload có thể vài
trăm KB mỗi dòng, đọc cả 500 dòng là vô ích. Nội dung chỉ được đọc khi bấm xem
đúng một dòng (`READ_PAYLOAD`).

## 5. Test run

Mặc định lần chạy **Test run** (chỉ dựng payload, không gọi API) **không** ghi
log, để bảng không bị rác khi người dùng xem trước hàng loạt.

Bật vết đó bằng `ZTB_HDDT_PARM` key **`LOG_TEST_RUN` = `X`** — hữu ích khi cần
biết ai đã xem payload nào. Dòng test run có `TEST_RUN = X` và mặc định bị ẩn
khỏi danh sách; tick "Kèm cả dòng Test run" để hiện.

Test run cũng **không đọc mật khẩu thật** (xem `ZCL_HDDT_SERVICE`), payload
hiển thị luôn là `"password":"********"` — nên hai lớp bảo vệ độc lập nhau.

## 6. Tắt lưu payload

`ZTB_HDDT_PARM` key `LOG_PAYLOAD`:

| Giá trị | Hành vi |
|---|---|
| không khai (mặc định) | **lưu** payload |
| `X` / `TRUE` / `1` | lưu payload |
| khai tường minh giá trị rỗng | **không** lưu nội dung, nhưng vẫn ghi `REQ_SIZE` / `RES_SIZE` để biết đã gửi bao nhiêu byte |

Chỉ tắt khi đã có nơi lưu bằng chứng khác. Tắt rồi thì màn hình xem log báo
*"Dòng log này không lưu nội dung"* thay vì hiện rỗng gây hiểu nhầm.

## 7. Xem JSON

`ZCL_HDDT_JSON=>PRETTY( )` xuống dòng + thụt lề bằng cách duyệt ký tự, có theo
dõi trạng thái "đang trong chuỗi" nên dấu `{` `}` `,` nằm trong tên hàng hoá
không làm vỡ định dạng. Không dùng `CL_SXML` vì API đó khác nhau giữa hai nền
tảng — hàm này chạy được ở cả ABAP cổ điển và ABAP Cloud.

Response không phải JSON (text thuần của FPT `del-invoice`, file nhị phân, trang
lỗi HTML của gateway) được hiển thị nguyên trạng, cắt theo dòng.

## 8. Dung lượng bảng — việc phải làm khi vận hành

Bảng này lớn nhanh: mỗi hoá đơn ít nhất 1 dòng, payload Viettel thường 3–15 KB,
hoá đơn nhiều dòng hàng có thể vài trăm KB. 100.000 hoá đơn/năm × 10 KB ≈
**1 GB/năm**, chưa tính lần gọi lại và response.

**Chưa có chương trình reorg trong bản này.** Cần bổ sung trước khi lên PRD, ba
hướng:

1. Job nền xoá dòng log quá hạn lưu trữ. Hoá đơn phải lưu 10 năm, nhưng các
   dòng `TEST_RUN` và các lần gọi lỗi đã khắc phục có thể xoá sớm hơn nhiều.
2. Giữ dòng log nhưng xoá nội dung sau N tháng — vẫn còn vết ai gửi gì lúc nào,
   chỉ bỏ payload:

```abap
DATA lv_empty TYPE xstring.
UPDATE ztb_hddt_log
   SET req_body   = @lv_empty,
       res_body   = @lv_empty,
       req_header = @lv_empty,
       res_header = @lv_empty
 WHERE created_at < @lv_cutoff
   AND req_body  <> @lv_empty.
```

3. Đưa `ZTB_HDDT_LOG` vào chiến lược archiving của hệ thống.

Theo dõi dung lượng bằng `REQ_SIZE` + `RES_SIZE` thay vì đếm dòng — hai chứng từ
cùng số dòng có thể chênh nhau 50 lần về byte.

## 9. Phân quyền

Bảng log chứa thông tin người mua (tên, MST, địa chỉ, email) → là **dữ liệu cá
nhân**. Đặt authorization group riêng khi sinh Table Maintenance Generator, và
chỉ cấp `ZFI003` cho người thực sự cần điều tra sự cố.

Secret đã được che lúc ghi nên rủi ro lộ mật khẩu được xử lý ở gốc, không phụ
thuộc vào việc cấp quyền có đúng hay không.
