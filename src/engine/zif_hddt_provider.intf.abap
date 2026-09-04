*=====================================================================
* Tên/Mã     : ZIF_HDDT_PROVIDER
* Mô tả chung: HỢP ĐỒNG (contract) mà mọi adapter nhà cung cấp HĐĐT
*              phải thực hiện. Đây là điểm mở rộng duy nhất của hệ
*              thống: thêm nhà cung cấp mới = viết 1 lớp implement
*              interface này + thêm 1 dòng vào ZTB_HDDT_PROV.
*              Engine (ZCL_HDDT_SERVICE) KHÔNG biết tên lớp nào cả —
*              nó lấy tên lớp từ bảng cấu hình qua ZCL_HDDT_FACTORY.
* Tham Số    : Không có (interface)
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       28/08/2026    cuongus - CuongUS        abapGit     Tạo mới
*=====================================================================
INTERFACE zif_hddt_provider
  PUBLIC .

  "! Mã nhà cung cấp mà adapter này phục vụ (VIETTEL / FPT / VNPT...)
  METHODS get_id
    RETURNING VALUE(r_provider) TYPE zde_hddt_prov.

  "! Một số nhà cung cấp gộp nhiều nghiệp vụ vào 1 endpoint, số khác
  "! lại tách ra. Adapter được quyền chuyển đổi action nghiệp vụ mà
  "! caller yêu cầu sang action kỹ thuật thực sự cần gọi.
  "! Mặc định: trả về đúng is_request-action.
  METHODS resolve_action
    IMPORTING is_request       TYPE zif_hddt_types=>ty_request
    RETURNING VALUE(r_action) TYPE zde_hddt_action.

  "! Dựng payload gửi cho nhà cung cấp từ canonical model.
  METHODS build_payload
    IMPORTING is_request        TYPE zif_hddt_types=>ty_request
              i_action         TYPE zde_hddt_action
              is_cred           TYPE ztb_hddt_cred
    RETURNING VALUE(r_payload) TYPE string
    RAISING   zcx_hddt_error.

  "! Giá trị thay thế placeholder {...} trong ZTB_HDDT_ACT-API_PATH.
  "! Ví dụ Viettel cần {taxcode} ở cuối URL, FPT thì không.
  METHODS get_url_symbols
    IMPORTING is_request        TYPE zif_hddt_types=>ty_request
              is_cred           TYPE ztb_hddt_cred
    RETURNING VALUE(rt_symbols) TYPE zif_hddt_types=>ty_t_kv.

  "! Header HTTP bổ sung đặc thù nhà cung cấp (ngoài Content-Type,
  "! Accept và Authorization do engine tự set theo cấu hình).
  METHODS get_headers
    IMPORTING is_request        TYPE zif_hddt_types=>ty_request
              is_cred           TYPE ztb_hddt_cred
    RETURNING VALUE(rt_headers) TYPE zif_hddt_types=>ty_t_kv.

  "! Bóc tách response của nhà cung cấp vào ty_result chuẩn hoá.
  "! Adapter chỉ điền PROV_STATUS / các field nghiệp vụ; việc quy đổi
  "! PROV_STATUS -> SAP status do engine làm bằng bảng ZTB_HDDT_STAT.
  METHODS parse_response
    IMPORTING is_request   TYPE zif_hddt_types=>ty_request
              i_action    TYPE zde_hddt_action
              i_http_code TYPE i
              i_body      TYPE string
    CHANGING  cs_result    TYPE zif_hddt_types=>ty_result
    RAISING   zcx_hddt_error.

  "! Payload cho endpoint đăng nhập (chỉ dùng khi AUTH_MODE = 'T').
  METHODS build_login_payload
    IMPORTING is_cred           TYPE ztb_hddt_cred
              i_secret         TYPE string
    RETURNING VALUE(r_payload) TYPE string.

  "! Bóc access token ra khỏi response của endpoint đăng nhập.
  METHODS extract_token
    IMPORTING i_body         TYPE string
    RETURNING VALUE(r_token) TYPE string.

ENDINTERFACE.
