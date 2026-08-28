*=====================================================================
* Tên/Mã     : ZFIC_HDDT_PROV_BASE
* Mô tả chung: Lớp cha TRỪU TƯỢNG cho mọi adapter nhà cung cấp HĐĐT.
*              Cài đặt sẵn phần lặp lại (symbol URL, header, đăng nhập,
*              định dạng ngày/số, tra bảng ánh xạ) để adapter con chỉ
*              phải viết đúng 3 việc thực sự khác nhau giữa các NCC:
*                GET_ID / BUILD_PAYLOAD / PARSE_RESPONSE
* Tham Số    : Trừu tượng — không tạo trực tiếp.
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       28/08/2026    cuongus - CuongUS        abapGit     Tạo mới
*=====================================================================
CLASS zfic_hddt_prov_base DEFINITION
  PUBLIC
  ABSTRACT
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES zfiif_hddt_provider ABSTRACT METHODS get_id
                                                   build_payload
                                                   parse_response .

    ALIASES get_id           FOR zfiif_hddt_provider~get_id .
    ALIASES build_payload    FOR zfiif_hddt_provider~build_payload .
    ALIASES parse_response   FOR zfiif_hddt_provider~parse_response .

    CONSTANTS gc_parm_timezone TYPE zfide_hddt_parmkey
                               VALUE 'TIME_ZONE' ##NO_TEXT.

  PROTECTED SECTION.

    "! Tra bảng ánh xạ giá trị của chính nhà cung cấp này.
    METHODS map_val
      IMPORTING iv_map_type    TYPE zfide_hddt_maptype
                iv_value       TYPE any
      RETURNING VALUE(rv_ext)  TYPE string .

    METHODS map_val_text
      IMPORTING iv_map_type    TYPE zfide_hddt_maptype
                iv_value       TYPE any
      RETURNING VALUE(rv_text) TYPE string .

    "! 'YYYY-MM-DD hh:mm:ss'
    METHODS fmt_datetime
      IMPORTING iv_date        TYPE dats
                iv_time        TYPE uzeit OPTIONAL
      RETURNING VALUE(rv_text) TYPE string .

    "! 'YYYY-MM-DD'
    METHODS fmt_date
      IMPORTING iv_date        TYPE dats
      RETURNING VALUE(rv_text) TYPE string .

    "! 'DD/MM/YYYY' — dùng trong câu ghi chú tiếng Việt
    METHODS fmt_date_vn
      IMPORTING iv_date        TYPE dats
      RETURNING VALUE(rv_text) TYPE string .

    "! Số milli giây kể từ 01/01/1970 (Viettel dùng cho invoiceIssuedDate)
    METHODS to_epoch_millis
      IMPORTING iv_date          TYPE dats
                iv_time          TYPE uzeit OPTIONAL
      RETURNING VALUE(rv_millis) TYPE string .

    METHODS num
      IMPORTING iv_value       TYPE any
                iv_decimals    TYPE i DEFAULT 6
      RETURNING VALUE(rv_text) TYPE string .

    "! Dựng body dạng application/x-www-form-urlencoded.
    "! Cần thiết vì không phải endpoint nào cũng nhận JSON — Viettel
    "! dùng form-urlencoded cho huỷ hoá đơn (mục 7.9), tra cứu theo
    "! transactionUuid (7.21), cập nhật trạng thái thanh toán (7.18)...
    "! Trường rỗng bị bỏ, giống nguyên tắc của JSON writer.
    METHODS build_form
      IMPORTING it_fields      TYPE zfiif_hddt_types=>ty_t_kv
      RETURNING VALUE(rv_body) TYPE string .

    METHODS get_config
      RETURNING VALUE(ro_config) TYPE REF TO zfic_hddt_config .

    "! Lớp nền tảng — dùng cho escape URL, ký tự điều khiển, múi giờ.
    METHODS platform
      RETURNING VALUE(ro_platform) TYPE REF TO zfiif_hddt_platform .

    "! Câu ghi chú chuẩn cho hoá đơn điều chỉnh / thay thế.
    METHODS build_adjust_note
      IMPORTING is_adjust      TYPE zfiif_hddt_types=>ty_adjust
      RETURNING VALUE(rv_note) TYPE string .

  PRIVATE SECTION.

    DATA mo_config TYPE REF TO zfic_hddt_config .

ENDCLASS.



CLASS zfic_hddt_prov_base IMPLEMENTATION.

*---------------------------------------------------------------------*
* Cài đặt mặc định của interface — adapter con override khi cần
*---------------------------------------------------------------------*
  METHOD zfiif_hddt_provider~resolve_action.

    rv_action = is_request-action.

  ENDMETHOD.


  METHOD zfiif_hddt_provider~get_url_symbols.

    rt_symbols = VALUE #(
      ( name  = zfiif_hddt_types=>gc_symbol-taxcode
        value = |{ is_cred-taxcode }| )
      ( name  = zfiif_hddt_types=>gc_symbol-template
        value = |{ is_request-invoice-header-template }| )
      ( name  = zfiif_hddt_types=>gc_symbol-serial
        value = |{ is_request-invoice-header-serial }| )
      ( name  = zfiif_hddt_types=>gc_symbol-seq
        value = |{ is_request-invoice-header-seq }| )
      ( name  = zfiif_hddt_types=>gc_symbol-idkey
        value = |{ is_request-invoice-header-idkey }| )
      ( name  = zfiif_hddt_types=>gc_symbol-bukrs
        value = |{ is_request-bukrs }| )
      ( name  = zfiif_hddt_types=>gc_symbol-apiuser
        value = |{ is_cred-apiuser }| ) ).

    " Tham số tự do của caller cũng dùng được làm placeholder
    LOOP AT is_request-params ASSIGNING FIELD-SYMBOL(<ls_p>).
      APPEND <ls_p> TO rt_symbols.
    ENDLOOP.

  ENDMETHOD.


  METHOD zfiif_hddt_provider~get_headers.

    CLEAR rt_headers.

  ENDMETHOD.


  METHOD zfiif_hddt_provider~build_login_payload.

    rv_payload = NEW zfic_hddt_json( )->begin_object(
      )->add_string( iv_name = `username` iv_value = is_cred-apiuser iv_force = abap_true
      )->add_string( iv_name = `password` iv_value = iv_secret       iv_force = abap_true
      )->end_object(
      )->get_json( ).

  ENDMETHOD.


  METHOD zfiif_hddt_provider~extract_token.

    " Mặc định: body chính là token (chuỗi JWT thuần). Nếu là JSON thì
    " thử các tên thẻ thông dụng.
    DATA(lv_body) = iv_body.
    CONDENSE lv_body.

    IF lv_body IS INITIAL.
      RETURN.
    ENDIF.

    IF substring( val = lv_body len = 1 ) <> `{`.
      rv_token = lv_body.
      " Một số API bọc token trong dấu ngoặc kép
      REPLACE ALL OCCURRENCES OF `"` IN rv_token WITH ``.
      RETURN.
    ENDIF.

    TRY.
        DATA(lt_val) = zfic_hddt_json=>parse( lv_body ).
      CATCH zficx_hddt_error.
        RETURN.
    ENDTRY.

    rv_token = zfic_hddt_json=>get_value_by_name( it_values = lt_val
                                                  iv_name   = `access_token` ).
    IF rv_token IS INITIAL.
      rv_token = zfic_hddt_json=>get_value_by_name( it_values = lt_val
                                                    iv_name   = `token` ).
    ENDIF.
    IF rv_token IS INITIAL.
      rv_token = zfic_hddt_json=>get_value_by_name( it_values = lt_val
                                                    iv_name   = `accessToken` ).
    ENDIF.

  ENDMETHOD.


*---------------------------------------------------------------------*
* Tiện ích dùng chung
*---------------------------------------------------------------------*
  METHOD get_config.

    IF mo_config IS NOT BOUND.
      mo_config = zfic_hddt_config=>get_instance( ).
    ENDIF.
    ro_config = mo_config.

  ENDMETHOD.


  METHOD platform.

    ro_platform = zfic_hddt_platform=>get( ).

  ENDMETHOD.


  METHOD map_val.

    get_config( )->map_value( EXPORTING iv_provider  = get_id( )
                                        iv_map_type  = iv_map_type
                                        iv_sap_value = iv_value
                              IMPORTING ev_ext_value = DATA(lv_ext) ).
    rv_ext = lv_ext.
    CONDENSE rv_ext.

  ENDMETHOD.


  METHOD map_val_text.

    get_config( )->map_value( EXPORTING iv_provider  = get_id( )
                                        iv_map_type  = iv_map_type
                                        iv_sap_value = iv_value
                              IMPORTING ev_ext_text  = DATA(lv_text) ).
    rv_text = lv_text.

  ENDMETHOD.


  METHOD fmt_date.

    IF iv_date IS INITIAL.
      RETURN.
    ENDIF.
    rv_text = |{ iv_date(4) }-{ iv_date+4(2) }-{ iv_date+6(2) }|.

  ENDMETHOD.


  METHOD fmt_date_vn.

    IF iv_date IS INITIAL.
      RETURN.
    ENDIF.
    rv_text = |{ iv_date+6(2) }/{ iv_date+4(2) }/{ iv_date(4) }|.

  ENDMETHOD.


  METHOD fmt_datetime.

    IF iv_date IS INITIAL.
      RETURN.
    ENDIF.

    DATA lv_time TYPE uzeit.
    lv_time = iv_time.

    rv_text = |{ iv_date(4) }-{ iv_date+4(2) }-{ iv_date+6(2) }| &&
              | { lv_time(2) }:{ lv_time+2(2) }:{ lv_time+4(2) }|.

  ENDMETHOD.


  METHOD to_epoch_millis.

    CONSTANTS lc_epoch TYPE d VALUE '19700101'.

    DATA lv_ts    TYPE timestamp.
    DATA lv_tz    TYPE timezone.
    DATA lv_time  TYPE uzeit.
    DATA lv_utc_d TYPE d.
    DATA lv_utc_t TYPE t.
    DATA lv_secs  TYPE p LENGTH 16 DECIMALS 0.

    IF iv_date IS INITIAL.
      RETURN.
    ENDIF.
    lv_time = iv_time.

    lv_tz = get_config( )->get_param( gc_parm_timezone ).
    IF lv_tz IS INITIAL.
      lv_tz = platform( )->get_time_zone( ).
    ENDIF.

    TRY.
        " Đổi giờ địa phương sang UTC. CONVERT DATE ... INTO TIME STAMP
        " là câu lệnh ABAP, dùng được ở cả hai nền tảng.
        CONVERT DATE iv_date TIME lv_time
                INTO TIME STAMP lv_ts TIME ZONE lv_tz.
      CATCH cx_root.
        RETURN.
    ENDTRY.

    " Tách timestamp YYYYMMDDhhmmss. Không dùng CL_ABAP_TSTMP vì lớp đó
    " không chắc được phép trong ABAP Cloud; số học ngày/giờ thì luôn được.
    DATA(lv_c) = |{ lv_ts NUMBER = RAW }|.
    CONDENSE lv_c NO-GAPS.
    IF strlen( lv_c ) < 14.
      RETURN.
    ENDIF.

    lv_utc_d = lv_c(8).
    lv_utc_t = lv_c+8(6).

    " Trừ ngày kiểu D cho ngày kiểu D trong ABAP ra SỐ NGÀY
    lv_secs = ( lv_utc_d - lc_epoch ) * 86400
            + lv_utc_t(2) * 3600
            + lv_utc_t+2(2) * 60
            + lv_utc_t+4(2).

    rv_millis = |{ lv_secs * 1000 }|.
    CONDENSE rv_millis NO-GAPS.
    SHIFT rv_millis LEFT DELETING LEADING '0'.

  ENDMETHOD.


  METHOD num.

    rv_text = zfic_hddt_json=>format_number( iv_value    = iv_value
                                             iv_decimals = iv_decimals ).

  ENDMETHOD.


  METHOD build_form.

    LOOP AT it_fields ASSIGNING FIELD-SYMBOL(<ls_f>).
      IF <ls_f>-value IS INITIAL.
        CONTINUE.
      ENDIF.
      IF rv_body IS NOT INITIAL.
        rv_body = rv_body && `&`.
      ENDIF.
      rv_body = rv_body
             && platform( )->escape_url( <ls_f>-name )
             && `=`
             && platform( )->escape_url( <ls_f>-value ).
    ENDLOOP.

  ENDMETHOD.


  METHOD build_adjust_note.

    IF is_adjust-reason IS NOT INITIAL.
      rv_note = is_adjust-reason.
      RETURN.
    ENDIF.

    IF is_adjust-org_serial IS INITIAL AND is_adjust-org_seq IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lv_prefix) = COND string(
      WHEN is_adjust-adj_type = zfiif_hddt_types=>gc_adj_type-replace
      THEN `Thay thế cho hóa đơn `
      ELSE `Điều chỉnh cho hóa đơn ` ).

    rv_note = |{ lv_prefix }{ is_adjust-org_serial }{ is_adjust-org_seq }|.
    IF is_adjust-org_inv_date IS NOT INITIAL.
      rv_note = rv_note && | ngày { fmt_date_vn( is_adjust-org_inv_date ) }|.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
