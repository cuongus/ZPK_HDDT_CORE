*=====================================================================
* Tên/Mã     : ZCL_HDDT_TOKEN
* Mô tả chung: Quản lý access token cho các nhà cung cấp dùng xác thực
*              dạng Bearer (AUTH_MODE = 'T'). Token được cache trong
*              bảng ZTB_HDDT_TOK theo (provider, connid, bukrs, user)
*              và chỉ đăng nhập lại khi hết hạn — tránh gọi /auth/login
*              hay /c_signin cho từng hoá đơn.
*              Thời gian sống lấy từ ZTB_HDDT_CONN-TOKEN_TTL (giây),
*              mặc định 3000 giây nếu không cấu hình.
* Tham Số    : GET_TOKEN( io_provider, is_conn, is_cred, i_secret )
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       28/08/2026    cuongus - CuongUS        abapGit     Tạo mới
*=====================================================================
CLASS zcl_hddt_token DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    CONSTANTS gc_default_ttl TYPE i VALUE 3000 ##NO_TEXT.

    METHODS get_token
      IMPORTING io_provider     TYPE REF TO zif_hddt_provider
                is_conn         TYPE ztb_hddt_conn
                is_cred         TYPE ztb_hddt_cred
                i_secret       TYPE string
                i_force_new    TYPE abap_bool DEFAULT abap_false
      RETURNING VALUE(r_token) TYPE string
      RAISING   zcx_hddt_error .

    "! Xoá token đã cache (dùng khi nhà cung cấp trả 401).
    METHODS invalidate
      IMPORTING is_conn TYPE ztb_hddt_conn
                is_cred TYPE ztb_hddt_cred .

  PROTECTED SECTION.
  PRIVATE SECTION.

    METHODS read_cache
      IMPORTING is_conn         TYPE ztb_hddt_conn
                is_cred         TYPE ztb_hddt_cred
      RETURNING VALUE(r_token) TYPE string .

    METHODS write_cache
      IMPORTING is_conn   TYPE ztb_hddt_conn
                is_cred   TYPE ztb_hddt_cred
                i_token  TYPE string .

    METHODS login
      IMPORTING io_provider     TYPE REF TO zif_hddt_provider
                is_conn         TYPE ztb_hddt_conn
                is_cred         TYPE ztb_hddt_cred
                i_secret       TYPE string
      RETURNING VALUE(r_token) TYPE string
      RAISING   zcx_hddt_error .

ENDCLASS.



CLASS zcl_hddt_token IMPLEMENTATION.

  METHOD get_token.

    IF i_force_new = abap_false.
      r_token = read_cache( is_conn = is_conn
                             is_cred = is_cred ).
      IF r_token IS NOT INITIAL.
        RETURN.
      ENDIF.
    ENDIF.

    r_token = login( io_provider = io_provider
                      is_conn     = is_conn
                      is_cred     = is_cred
                      i_secret   = i_secret ).

    IF r_token IS INITIAL.
      zcx_hddt_error=>raise_text(
        |Đăng nhập { is_conn-provider } thành công nhưng không bóc được| &&
        | access token từ response. Kiểm tra EXTRACT_TOKEN của adapter.| ).
    ENDIF.

    write_cache( is_conn  = is_conn
                 is_cred  = is_cred
                 i_token = r_token ).

  ENDMETHOD.


  METHOD read_cache.

    DATA lv_now TYPE timestampl.

    GET TIME STAMP FIELD lv_now.

    SELECT SINGLE token, valid_to
      FROM ztb_hddt_tok
      WHERE provider = @is_conn-provider
        AND connid   = @is_conn-connid
        AND bukrs    = @is_cred-bukrs
        AND apiuser  = @is_cred-apiuser
      INTO @DATA(ls_tok).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    IF ls_tok-valid_to > lv_now.
      r_token = ls_tok-token.
    ENDIF.

  ENDMETHOD.


  METHOD write_cache.

    DATA ls_tok TYPE ztb_hddt_tok.
    DATA lv_now TYPE timestamp.
    DATA lv_ttl TYPE i.

    GET TIME STAMP FIELD lv_now.

    lv_ttl = is_conn-token_ttl.
    IF lv_ttl <= 0.
      lv_ttl = gc_default_ttl.
    ENDIF.

    ls_tok-provider   = is_conn-provider.
    ls_tok-connid     = is_conn-connid.
    ls_tok-bukrs      = is_cred-bukrs.
    ls_tok-apiuser    = is_cred-apiuser.
    ls_tok-token      = i_token.
    ls_tok-created_at = lv_now.
    ls_tok-valid_to   = cl_abap_tstmp=>add( tstmp = lv_now
                                            secs  = lv_ttl ).

    MODIFY ztb_hddt_tok FROM ls_tok.
    COMMIT WORK AND WAIT.

  ENDMETHOD.


  METHOD invalidate.

    DELETE FROM ztb_hddt_tok
      WHERE provider = @is_conn-provider
        AND connid   = @is_conn-connid
        AND bukrs    = @is_cred-bukrs
        AND apiuser  = @is_cred-apiuser.
    COMMIT WORK AND WAIT.

  ENDMETHOD.


  METHOD login.

    DATA(lo_config) = zcl_hddt_config=>get_instance( ).

    DATA(lv_action) = is_conn-token_action.
    IF lv_action IS INITIAL.
      lv_action = zif_hddt_types=>gc_action-login.
    ENDIF.

    DATA(ls_act) = lo_config->get_action( i_provider = is_conn-provider
                                          i_action   = lv_action ).

    DATA ls_call TYPE zcl_hddt_http=>ty_call.
    ls_call-conn      = is_conn.
    ls_call-action    = ls_act.
    ls_call-payload   = io_provider->build_login_payload( is_cred   = is_cred
                                                          i_secret = i_secret ).
    ls_call-username  = is_cred-apiuser.
    ls_call-secret    = i_secret.
    " API đăng nhập không thể dùng Bearer -> ép về Basic
    ls_call-auth_mode = zif_hddt_types=>gc_auth-basic.

    ls_call-symbols = VALUE zif_hddt_types=>ty_t_kv(
      ( name = zif_hddt_types=>gc_symbol-taxcode value = |{ is_cred-taxcode }| )
      ( name = zif_hddt_types=>gc_symbol-apiuser value = |{ is_cred-apiuser }| ) ).

    DATA(ls_resp) = NEW zcl_hddt_http( )->send( ls_call ).

    IF ls_resp-http_code < 200 OR ls_resp-http_code >= 300.
      zcx_hddt_error=>raise_text(
        i_text      = |Đăng nhập { is_conn-provider } thất bại (HTTP | &&
                       |{ ls_resp-http_code } { ls_resp-reason }): { ls_resp-body }|
        i_http_code = ls_resp-http_code ).
    ENDIF.

    r_token = io_provider->extract_token( ls_resp-body ).

  ENDMETHOD.

ENDCLASS.
