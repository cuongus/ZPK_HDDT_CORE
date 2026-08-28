*=====================================================================
* Tên/Mã     : ZFIIF_HDDT_PLATFORM
* Mô tả chung: Tách các API KHÁC NHAU giữa ABAP cổ điển (Private Cloud /
*              on-premise) và ABAP Cloud (S/4HANA Cloud Public Edition),
*              để tầng adapter nhà cung cấp dùng chung được cho CẢ HAI
*              nền tảng mà không phải viết hai lần.
*
*              Danh sách này KHÔNG phải đoán — nó là kết quả rà soát
*              thực tế:
*                (1) grep toàn bộ code cổ điển của package tìm API
*                    không được phép trong ABAP Cloud;
*                (2) đọc 6.018 dòng code ABAP Cloud đang chạy thật ở
*                    package ZPK_HDDT_CORE trên tenant CASLA (AK3) để
*                    biết nền tảng đó thực sự dùng gì.
*              Kết quả: chỉ còn 4 nhóm cần tách (ký tự điều khiển,
*              escape URL, xstring→string, quy đổi epoch millis).
*              `sy-datum` / `sy-uzeit` / `sy-uname` dùng được ở cả hai
*              (code cloud trên CASLA cũng đang dùng) nên KHÔNG đưa vào
*              đây — tránh phình interface vô ích.
*
*              Lớp thực thi khai trong ZFIT_HDDT_PARM, tham số
*              PLATFORM_CLASS. Không khai thì mặc định lớp cổ điển.
* Tham Số    : Không có (interface)
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       28/08/2026    cuongus - CuongUS        abapGit     Tạo mới
*=====================================================================
INTERFACE zfiif_hddt_platform
  PUBLIC .

*---------------------------------------------------------------------*
* 1. Ký tự điều khiển
*---------------------------------------------------------------------*
  " Cổ điển: CL_ABAP_CHAR_UTILITIES (không được phép trong ABAP Cloud)
  METHODS newline
    RETURNING VALUE(rv_char) TYPE c .

  METHODS carriage_return
    RETURNING VALUE(rv_char) TYPE c .

  METHODS tab
    RETURNING VALUE(rv_char) TYPE c .

*---------------------------------------------------------------------*
* 2. Escape URL (dùng cho body application/x-www-form-urlencoded)
*---------------------------------------------------------------------*
  " Cổ điển: CL_HTTP_UTILITY=>ESCAPE_URL
  " Cloud   : CL_WEB_HTTP_UTILITY=>ESCAPE_URL
  METHODS escape_url
    IMPORTING iv_value          TYPE string
    RETURNING VALUE(rv_escaped) TYPE string .

*---------------------------------------------------------------------*
* 3. Chuyển xstring sang string theo codepage
*---------------------------------------------------------------------*
  " Dùng để giải mã escape \uXXXX trong JSON parser.
  " Cổ điển: CL_ABAP_CONV_IN_CE  ·  Cloud: CL_ABAP_CONV_CODEPAGE
  METHODS xstring_to_string
    IMPORTING iv_data        TYPE xstring
              iv_encoding    TYPE string DEFAULT `UTF-16BE`
    RETURNING VALUE(rv_text) TYPE string .

*---------------------------------------------------------------------*
* 4. Giải mã base64 (file hoá đơn PDF/ZIP nhà cung cấp trả về)
*---------------------------------------------------------------------*
  " Cổ điển: CL_HTTP_UTILITY=>DECODE_X_BASE64
  " Cloud   : CL_WEB_HTTP_UTILITY=>DECODE_X_BASE64
  METHODS decode_base64
    IMPORTING iv_encoded     TYPE string
    RETURNING VALUE(rv_data) TYPE xstring .

*---------------------------------------------------------------------*
* 5. Múi giờ hiện hành của người dùng
*---------------------------------------------------------------------*
  " Cổ điển: SY-ZONLO  ·  Cloud: CL_ABAP_CONTEXT_INFO=>GET_USER_TIME_ZONE
  METHODS get_time_zone
    RETURNING VALUE(rv_tzone) TYPE timezone .

ENDINTERFACE.
