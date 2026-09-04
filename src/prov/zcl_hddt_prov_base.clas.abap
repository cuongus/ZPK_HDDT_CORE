*=====================================================================
* Tên/Mã     : ZCL_HDDT_PROV_BASE
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
CLASS zcl_hddt_prov_base DEFINITION
  PUBLIC
  ABSTRACT
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES zif_hddt_provider ABSTRACT METHODS get_id
                                                   build_payload
                                                   parse_response .

    ALIASES get_id           FOR zif_hddt_provider~get_id .
    ALIASES build_payload    FOR zif_hddt_provider~build_payload .
    ALIASES parse_response   FOR zif_hddt_provider~parse_response .

    CONSTANTS gc_parm_timezone TYPE zde_hddt_parmkey
                               VALUE 'TIME_ZONE' ##NO_TEXT.

  PROTECTED SECTION.

    "! Tra bảng ánh xạ giá trị của chính nhà cung cấp này.
    METHODS map_val
      IMPORTING i_map_type    TYPE zde_hddt_maptype
                i_value       TYPE any
      RETURNING VALUE(r_ext)  TYPE string .

    METHODS map_val_text
      IMPORTING i_map_type    TYPE zde_hddt_maptype
                i_value       TYPE any
      RETURNING VALUE(r_text) TYPE string .

    "! 'YYYY-MM-DD hh:mm:ss'
    METHODS fmt_datetime
      IMPORTING i_date        TYPE dats
                i_time        TYPE uzeit OPTIONAL
      RETURNING VALUE(r_text) TYPE string .

    "! 'YYYY-MM-DD'
    METHODS fmt_date
      IMPORTING i_date        TYPE dats
      RETURNING VALUE(r_text) TYPE string .

    "! 'DD/MM/YYYY' — dùng trong câu ghi chú tiếng Việt
    METHODS fmt_date_vn
      IMPORTING i_date        TYPE dats
      RETURNING VALUE(r_text) TYPE string .

    "! Số milli giây kể từ 01/01/1970 (Viettel dùng cho invoiceIssuedDate)
    METHODS to_epoch_millis
      IMPORTING i_date          TYPE dats
                i_time          TYPE uzeit OPTIONAL
      RETURNING VALUE(r_millis) TYPE string .

    METHODS num
      IMPORTING i_value       TYPE any
                i_decimals    TYPE i DEFAULT 6
      RETURNING VALUE(r_text) TYPE string .

    "! Dựng body dạng application/x-www-form-urlencoded.
    "! Cần thiết vì không phải endpoint nào cũng nhận JSON — Viettel
    "! dùng form-urlencoded cho huỷ hoá đơn (mục 7.9), tra cứu theo
    "! transactionUuid (7.21), cập nhật trạng thái thanh toán (7.18)...
    "! Trường rỗng bị bỏ, giống nguyên tắc của JSON writer.
    METHODS build_form
      IMPORTING it_fields      TYPE zif_hddt_types=>ty_t_kv
      RETURNING VALUE(r_body) TYPE string .

    METHODS get_config
      RETURNING VALUE(ro_config) TYPE REF TO zcl_hddt_config .

    "! Lớp nền tảng — dùng cho escape URL, ký tự điều khiển, múi giờ.
    METHODS platform
      RETURNING VALUE(ro_platform) TYPE REF TO zif_hddt_platform .

    "! Câu ghi chú chuẩn cho hoá đơn điều chỉnh / thay thế.
    METHODS build_adjust_note
      IMPORTING is_adjust      TYPE zif_hddt_types=>ty_adjust
      RETURNING VALUE(r_note) TYPE string .

  PRIVATE SECTION.

    DATA mo_config TYPE REF TO zcl_hddt_config .

ENDCLASS.



CLASS zcl_hddt_prov_base IMPLEMENTATION.

*---------------------------------------------------------------------*
* Cài đặt mặc định của interface — adapter con override khi cần
*---------------------------------------------------------------------*
  METHOD zif_hddt_provider~resolve_action.

    r_action = is_request-action.

  ENDMETHOD.


  METHOD zif_hddt_provider~get_url_symbols.

    rt_symbols = VALUE #(
      ( name  = zif_hddt_types=>gc_symbol-taxcode
        value = |{ is_cred-taxcode }| )
      ( name  = zif_hddt_types=>gc_symbol-template
        value = |{ is_request-invoice-header-template }| )
      ( name  = zif_hddt_types=>gc_symbol-serial
        value = |{ is_request-invoice-header-serial }| )
      ( name  = zif_hddt_types=>gc_symbol-seq
        value = |{ is_request-invoice-header-seq }| )
      ( name  = zif_hddt_types=>gc_symbol-idkey
        value = |{ is_request-invoice-header-idkey }| )
      ( name  = zif_hddt_types=>gc_symbol-bukrs
        value = |{ is_request-bukrs }| )
      ( name  = zif_hddt_types=>gc_symbol-apiuser
        value = |{ is_cred-apiuser }| ) ).

    " Tham số tự do của caller cũng dùng được làm placeholder
    LOOP AT is_request-params ASSIGNING FIELD-SYMBOL(<fs_p>).
      APPEND <fs_p> TO rt_symbols.
    ENDLOOP.

  ENDMETHOD.


  METHOD zif_hddt_provider~get_headers.

    CLEAR rt_headers.

  ENDMETHOD.


  METHOD zif_hddt_provider~build_login_payload.

    r_payload = NEW zcl_hddt_json( )->begin_object(
      )->add_string( i_name = `username` i_value = is_cred-apiuser i_force = abap_true
      )->add_string( i_name = `password` i_value = i_secret       i_force = abap_true
      )->end_object(
      )->get_json( ).

  ENDMETHOD.


  METHOD zif_hddt_provider~extract_token.

    " Mặc định: body chính là token (chuỗi JWT thuần). Nếu là JSON thì
    " thử các tên thẻ thông dụng.
    DATA(lv_body) = i_body.
    CONDENSE lv_body.

    IF lv_body IS INITIAL.
      RETURN.
    ENDIF.

    IF substring( val = lv_body len = 1 ) <> `{`.
      r_token = lv_body.
      " Một số API bọc token trong dấu ngoặc kép
      REPLACE ALL OCCURRENCES OF `"` IN r_token WITH ``.
      RETURN.
    ENDIF.

    TRY.
        DATA(lt_val) = zcl_hddt_json=>parse( lv_body ).
      CATCH zcx_hddt_error.
        RETURN.
    ENDTRY.

    r_token = zcl_hddt_json=>get_value_by_name( it_values = lt_val
                                                  i_name   = `access_token` ).
    IF r_token IS INITIAL.
      r_token = zcl_hddt_json=>get_value_by_name( it_values = lt_val
                                                    i_name   = `token` ).
    ENDIF.
    IF r_token IS INITIAL.
      r_token = zcl_hddt_json=>get_value_by_name( it_values = lt_val
                                                    i_name   = `accessToken` ).
    ENDIF.

  ENDMETHOD.


*---------------------------------------------------------------------*
* Tiện ích dùng chung
*---------------------------------------------------------------------*
  METHOD get_config.

    IF mo_config IS NOT BOUND.
      mo_config = zcl_hddt_config=>get_instance( ).
    ENDIF.
    ro_config = mo_config.

  ENDMETHOD.


  METHOD platform.

    ro_platform = zcl_hddt_platform=>get( ).

  ENDMETHOD.


  METHOD map_val.

    get_config( )->map_value( EXPORTING i_provider  = get_id( )
                                        i_map_type  = i_map_type
                                        i_sap_value = i_value
                              IMPORTING e_ext_value = DATA(lv_ext) ).
    r_ext = lv_ext.
    CONDENSE r_ext.

  ENDMETHOD.


  METHOD map_val_text.

    get_config( )->map_value( EXPORTING i_provider  = get_id( )
                                        i_map_type  = i_map_type
                                        i_sap_value = i_value
                              IMPORTING e_ext_text  = DATA(lv_text) ).
    r_text = lv_text.

  ENDMETHOD.


  METHOD fmt_date.

    IF i_date IS INITIAL.
      RETURN.
    ENDIF.
    r_text = |{ i_date(4) }-{ i_date+4(2) }-{ i_date+6(2) }|.

  ENDMETHOD.


  METHOD fmt_date_vn.

    IF i_date IS INITIAL.
      RETURN.
    ENDIF.
    r_text = |{ i_date+6(2) }/{ i_date+4(2) }/{ i_date(4) }|.

  ENDMETHOD.


  METHOD fmt_datetime.

    IF i_date IS INITIAL.
      RETURN.
    ENDIF.

    DATA lv_time TYPE uzeit.
    lv_time = i_time.

    r_text = |{ i_date(4) }-{ i_date+4(2) }-{ i_date+6(2) }| &&
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

    IF i_date IS INITIAL.
      RETURN.
    ENDIF.
    lv_time = i_time.

    lv_tz = get_config( )->get_param( gc_parm_timezone ).
    IF lv_tz IS INITIAL.
      lv_tz = platform( )->get_time_zone( ).
    ENDIF.

    TRY.
        " Đổi giờ địa phương sang UTC. CONVERT DATE ... INTO TIME STAMP
        " là câu lệnh ABAP, dùng được ở cả hai nền tảng.
        CONVERT DATE i_date TIME lv_time
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

    r_millis = |{ lv_secs * 1000 }|.
    CONDENSE r_millis NO-GAPS.
    SHIFT r_millis LEFT DELETING LEADING '0'.

  ENDMETHOD.


  METHOD num.

    r_text = zcl_hddt_json=>format_number( i_value    = i_value
                                             i_decimals = i_decimals ).

  ENDMETHOD.


  METHOD build_form.

    LOOP AT it_fields ASSIGNING FIELD-SYMBOL(<fs_f>).
      IF <fs_f>-value IS INITIAL.
        CONTINUE.
      ENDIF.
      IF r_body IS NOT INITIAL.
        r_body = r_body && `&`.
      ENDIF.
      r_body = r_body
             && platform( )->escape_url( <fs_f>-name )
             && `=`
             && platform( )->escape_url( <fs_f>-value ).
    ENDLOOP.

  ENDMETHOD.


  METHOD build_adjust_note.

    IF is_adjust-reason IS NOT INITIAL.
      r_note = is_adjust-reason.
      RETURN.
    ENDIF.

    IF is_adjust-org_serial IS INITIAL AND is_adjust-org_seq IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lv_prefix) = COND string(
      WHEN is_adjust-adj_type = zif_hddt_types=>gc_adj_type-replace
      THEN `Thay thế cho hóa đơn `
      ELSE `Điều chỉnh cho hóa đơn ` ).

    r_note = |{ lv_prefix }{ is_adjust-org_serial }{ is_adjust-org_seq }|.
    IF is_adjust-org_inv_date IS NOT INITIAL.
      r_note = r_note && | ngày { fmt_date_vn( is_adjust-org_inv_date ) }|.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
