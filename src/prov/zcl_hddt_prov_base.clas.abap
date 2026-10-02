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
* 1.0       28/08/2026    cuongus - CuongUS        S25K900131  Tạo mới
* 1.1       01/10/2026    F-DUBV                   DS4K900192  20261001_14 G6-006
*                                                             CATCH cụ thể thay
*                                                             CX_ROOT, kiểm subrc
*                                                             CONVERT DATE
* 1.2       02/10/2026    F-DUBV - DuBV            DS4K900192  G6-011 cot Transport
*                                                              ghi mã TR thật S25K900131 (20261002_17)
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

    "! Lý do điều chỉnh cho thẻ inv.adj.rea - chính câu mô tả của
    "! BUILD_ADJUST_NOTE nhưng cắt còn 100 ký tự theo giới hạn của
    "! FPT eInvoice (FS v0.17 mục 3.7.6).
    METHODS adjust_reason
      IMPORTING is_adjust        TYPE zif_hddt_types=>ty_adjust
      RETURNING VALUE(r_reason) TYPE string .

  PRIVATE SECTION.

    DATA mo_config TYPE REF TO zcl_hddt_config .

ENDCLASS.



CLASS ZCL_HDDT_PROV_BASE IMPLEMENTATION.


  METHOD adjust_reason.

    " FS v0.17 muc 3.7.6: the inv.adj.rea chi dai toi da 100 ky tu trong
    " khi cau mo ta day du nam o the inv.note (255 ky tu). Truyen chinh
    " cau do nhung CAT con 100.
    r_reason = build_adjust_note( is_adjust ).
    IF strlen( r_reason ) > 100.
      r_reason = r_reason(100).
    ENDIF.

  ENDMETHOD.


  METHOD build_adjust_note.

    IF is_adjust-reason IS NOT INITIAL.
      r_note = is_adjust-reason.
      RETURN.
    ENDIF.

    IF is_adjust-org_serial IS INITIAL AND is_adjust-org_seq IS INITIAL.
      RETURN.
    ENDIF.

    " FS v0.17 muc 3.6.4 chot CU PHAP CO DINH cua cau mo ta, in tren ban
    " the hien hoa don. Nguoi dung khong nhap va khong sua duoc:
    "   Hóa đơn điều chỉnh <tăng|giảm> cho hóa đơn điện tử mẫu số <mẫu
    "   số>, ký hiệu <ký hiệu>, số <số hóa đơn> lập ngày <dd/mm/yyyy>
    " Bon gia tri lay tu ban ghi HOA DON GOC tren so dang ky nen luon
    " khop voi bo the inv.ref.rform / rserial / rseq / ridt.
    " Ky hieu FPT gom MAU SO o ky tu dau (vi du 1C25MAG): tach ra thanh
    " mau so = ky tu dau, ky hieu = phan con lai.
    DATA(lv_form)   = CONV string( is_adjust-org_serial ).
    DATA(lv_serial) = lv_form.
    IF strlen( lv_form ) > 1.
      lv_form   = lv_form(1).
      lv_serial = lv_serial+1.
    ENDIF.

    IF is_adjust-adj_type = zif_hddt_types=>gc_adj_type-replace.
      " Nghiep vu thay the khong co loai dieu chinh nen giu cau cu
      r_note = |Thay thế cho hóa đơn điện tử mẫu số { lv_form }, | &&
               |ký hiệu { lv_serial }, số { is_adjust-org_seq }|.
    ELSE.
      " '1' tang, '0' giam - lay dung theo chieu ghi so cua dong doanh thu
      DATA(lv_ud) = COND string( WHEN is_adjust-adj_direction = '0'
                                 THEN `giảm` ELSE `tăng` ).
      r_note = |Hóa đơn điều chỉnh { lv_ud } cho hóa đơn điện tử mẫu số | &&
               |{ lv_form }, ký hiệu { lv_serial }, | &&
               |số { is_adjust-org_seq }|.
    ENDIF.

    IF is_adjust-org_inv_date IS NOT INITIAL.
      r_note = r_note && | lập ngày { fmt_date_vn( is_adjust-org_inv_date ) }|.
    ENDIF.

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


  METHOD fmt_date.

    IF i_date IS INITIAL.
      RETURN.
    ENDIF.
    r_text = |{ i_date(4) }-{ i_date+4(2) }-{ i_date+6(2) }|.

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


  METHOD fmt_date_vn.

    IF i_date IS INITIAL.
      RETURN.
    ENDIF.
    r_text = |{ i_date+6(2) }/{ i_date+4(2) }/{ i_date(4) }|.

  ENDMETHOD.


  METHOD get_config.
*---------------------------------------------------------------------*
* Tiện ích dùng chung
*---------------------------------------------------------------------*

    IF mo_config IS NOT BOUND.
      mo_config = zcl_hddt_config=>get_instance( ).
    ENDIF.
    ro_config = mo_config.

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


  METHOD num.

    r_text = zcl_hddt_json=>format_number( i_value    = i_value
                                             i_decimals = i_decimals ).

  ENDMETHOD.


  METHOD platform.

    ro_platform = zcl_hddt_platform=>get( ).

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
*       20261001_14 G6-006: sy-subrc 4/8 = khong doi duoc (mui gio sai)
        IF sy-subrc <> 0.
          RETURN.
        ENDIF.
*     20261001_14 G6-006: chi bat loi chuyen doi ngay/gio, khong CX_ROOT
      CATCH cx_sy_conversion_error.
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


  METHOD zif_hddt_provider~get_headers.

    CLEAR rt_headers.

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


  METHOD zif_hddt_provider~resolve_action.
*---------------------------------------------------------------------*
* Cài đặt mặc định của interface — adapter con override khi cần
*---------------------------------------------------------------------*
    r_action = is_request-action.

  ENDMETHOD.
ENDCLASS.
