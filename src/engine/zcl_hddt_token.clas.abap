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
* 1.0       28/08/2026    cuongus - CuongUS        S25K900131  Tạo mới
* 1.1       25/09/2026    F-DUBV                   S25K900131  Review S25: GET_TOKEN khoa
*                                                                  EZTB_HDDT_TOK quanh dang nhap
* 1.2       01/10/2026    F-DUBV - DuBV            DS4K900192  20261001_07 Review G6-008:
*                                                                  ghi/xoa cache o service
*                                                                  connection R/3*HDDT_TOK
*                                                                  (COMMIT CONNECTION, bo
*                                                                  COMMIT WORK); khong ghi
*                                                                  cache khi khong giu khoa;
*                                                                  INVALIDATE co khoa.
*                                                                  G6-001: ZST_ADMIN_DATA
* 1.3       02/10/2026    F-DUBV - DuBV            DS4K900192  G6-011 cot Transport
*                                                              ghi mã TR thật S25K900131 (20261002_17)
*=====================================================================
CLASS zcl_hddt_token DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    CONSTANTS gc_default_ttl TYPE i VALUE 3000 ##NO_TEXT.
    " >>> Begin of insert 20261001_07 F-DUBV TR DS4K900192 - Review G6-008
    " Ket noi DB phu (service connection) de ghi/xoa cache token trong LUW
    " RIENG: COMMIT CONNECTION chi chot ZTB_HDDT_TOK, KHONG chot cac ghi do
    " dang cua lo dang xu ly (EXECUTE_MANY) o ket noi chinh.
    CONSTANTS gc_tok_con TYPE dbcon_name VALUE 'R/3*HDDT_TOK' ##NO_TEXT.
    " <<< End of insert 20261001_07

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



CLASS ZCL_HDDT_TOKEN IMPLEMENTATION.


  METHOD get_token.

    IF i_force_new = abap_false.
      r_token = read_cache( is_conn = is_conn
                             is_cred = is_cred ).
      IF r_token IS NOT INITIAL.
        RETURN.
      ENDIF.
    ENDIF.

*   >>> Begin of change 20260925_01 F-DUBV TR S25K900131 - Review S25 25/09 (khoa)
*   Hai phien cung het cache se cung dang nhap; nha cung cap cap token moi
*   co the vo hieu token cu -> phien kia nhan 401. Khoa theo dung khoa cache
*   (cho toi da ENQUEUE/DELAY_TIME), doc lai cache: phien truoc vua dang nhap
*   xong thi dung luon token do. Khong lay duoc khoa thi van dang nhap nhu
*   cu (khong chan phat hanh hoa don), chi mat tinh tuan tu.
    DATA lv_locked TYPE abap_bool.

    CALL FUNCTION 'ENQUEUE_EZTB_HDDT_TOK'
      EXPORTING
        mode_ztb_hddt_tok = 'E'
        provider          = is_conn-provider
        connid            = is_conn-connid
        bukrs             = is_cred-bukrs
        apiuser           = is_cred-apiuser
        _scope            = '1'
        _wait             = abap_true
      EXCEPTIONS
        foreign_lock      = 1
        system_failure    = 2
        OTHERS            = 3.
    lv_locked = xsdbool( sy-subrc = 0 ).

    IF lv_locked = abap_true AND i_force_new = abap_false.
      r_token = read_cache( is_conn = is_conn
                             is_cred = is_cred ).
      IF r_token IS NOT INITIAL.
        CALL FUNCTION 'DEQUEUE_EZTB_HDDT_TOK'
          EXPORTING
            mode_ztb_hddt_tok = 'E'
            provider          = is_conn-provider
            connid            = is_conn-connid
            bukrs             = is_cred-bukrs
            apiuser           = is_cred-apiuser
            _scope            = '1'.
        RETURN.
      ENDIF.
    ENDIF.

    TRY.
        r_token = login( io_provider = io_provider
                          is_conn     = is_conn
                          is_cred     = is_cred
                          i_secret   = i_secret ).

        IF r_token IS INITIAL.
          zcx_hddt_error=>raise_text(
            |Đăng nhập { is_conn-provider } thành công nhưng không bóc được| &&
            | access token từ response. Kiểm tra EXTRACT_TOKEN của adapter.| ).
        ENDIF.

        " >>> Begin of change 20261001_07 F-DUBV TR DS4K900192 - Review G6-008
        " Chi ghi cache khi GIU khoa: khong lay duoc khoa thi token vua cap
        " dung cho lan goi nay, khong ghi de cache cua phien dang giu khoa.
        IF lv_locked = abap_true.
          write_cache( is_conn  = is_conn
                       is_cred  = is_cred
                       i_token = r_token ).
        ENDIF.
        " <<< End of change 20261001_07

      CLEANUP.
        IF lv_locked = abap_true.
          CALL FUNCTION 'DEQUEUE_EZTB_HDDT_TOK'
            EXPORTING
              mode_ztb_hddt_tok = 'E'
              provider          = is_conn-provider
              connid            = is_conn-connid
              bukrs             = is_cred-bukrs
              apiuser           = is_cred-apiuser
              _scope            = '1'.
        ENDIF.
    ENDTRY.

    IF lv_locked = abap_true.
      CALL FUNCTION 'DEQUEUE_EZTB_HDDT_TOK'
        EXPORTING
          mode_ztb_hddt_tok = 'E'
          provider          = is_conn-provider
          connid            = is_conn-connid
          bukrs             = is_cred-bukrs
          apiuser           = is_cred-apiuser
          _scope            = '1'.
    ENDIF.
*   <<< End of change 20260925_01

  ENDMETHOD.


  METHOD invalidate.

    " >>> Begin of change 20261001_07 F-DUBV TR DS4K900192 - Review G6-008
    " Khoa dung khoa cache nhu GET_TOKEN (khong xoa token phien khac vua cap
    " trong luc dang dang nhap); xoa o ket noi phu + COMMIT CONNECTION thay
    " COMMIT WORK (khong chot ghi do dang cua lo noi goi).
    CALL FUNCTION 'ENQUEUE_EZTB_HDDT_TOK'
      EXPORTING
        mode_ztb_hddt_tok = 'E'
        provider          = is_conn-provider
        connid            = is_conn-connid
        bukrs             = is_cred-bukrs
        apiuser           = is_cred-apiuser
        _scope            = '1'
        _wait             = abap_true
      EXCEPTIONS
        foreign_lock      = 1
        system_failure    = 2
        OTHERS            = 3.
    IF sy-subrc <> 0.
      " Phien khac dang lam moi token: token cu se bi thay, khong can xoa
      RETURN.
    ENDIF.

    DELETE FROM ztb_hddt_tok CONNECTION (gc_tok_con)
      WHERE provider = @is_conn-provider
        AND connid   = @is_conn-connid
        AND bukrs    = @is_cred-bukrs
        AND apiuser  = @is_cred-apiuser.
    " sy-subrc = 4: khong co token cache - binh thuong
    IF sy-subrc <= 4.
      COMMIT CONNECTION (gc_tok_con).
    ELSE.
      ROLLBACK CONNECTION (gc_tok_con).
    ENDIF.

    CALL FUNCTION 'DEQUEUE_EZTB_HDDT_TOK'
      EXPORTING
        mode_ztb_hddt_tok = 'E'
        provider          = is_conn-provider
        connid            = is_conn-connid
        bukrs             = is_cred-bukrs
        apiuser           = is_cred-apiuser
        _scope            = '1'.
    " <<< End of change 20261001_07

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


  METHOD read_cache.

    DATA lv_now TYPE timestampl.

    GET TIME STAMP FIELD lv_now.

    SELECT SINGLE token, valid_to
      FROM ztb_hddt_tok
      INTO @DATA(ls_tok)
      WHERE provider = @is_conn-provider
        AND connid   = @is_conn-connid
        AND bukrs    = @is_cred-bukrs
        AND apiuser  = @is_cred-apiuser.
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
    ls_tok-valid_to   = cl_abap_tstmp=>add( tstmp = lv_now
                                            secs  = lv_ttl ).

    " >>> Begin of change 20261001_07 F-DUBV TR DS4K900192 - Review G6-001/G6-008
    " CREATED_AT rieng -> ZST_ADMIN_DATA (ZCREATED_AT = luc cap token).
    zcl_hddt_log=>set_admin( EXPORTING i_source = zcl_bc_audit=>gc_source-api
                             CHANGING  cs_row   = ls_tok ).
    " Ghi o ket noi phu + COMMIT CONNECTION: khong COMMIT WORK giua lo cua
    " noi goi. Loi ghi cache chi lam mat cache (lan sau dang nhap lai).
    MODIFY ztb_hddt_tok CONNECTION (gc_tok_con) FROM @ls_tok.
    IF sy-subrc = 0.
      COMMIT CONNECTION (gc_tok_con).
    ELSE.
      ROLLBACK CONNECTION (gc_tok_con).
    ENDIF.
    " <<< End of change 20261001_07

  ENDMETHOD.
ENDCLASS.
