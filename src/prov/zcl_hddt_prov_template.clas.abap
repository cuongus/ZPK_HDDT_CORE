*=====================================================================
* Tên/Mã     : ZCL_HDDT_PROV_TEMPLATE
* Mô tả chung: Adapter TỔNG QUÁT dựng payload từ MẪU lưu trong bảng
*              cấu hình ZTB_HDDT_TPL — không cần viết ABAP mới.
*              Dùng cho nhà cung cấp mà ta chưa/không muốn viết adapter
*              chuyên biệt (Vinaphone/VNPT, MISO, BKAV, Wintech...),
*              hoặc khi nhà cung cấp yêu cầu XML thay vì JSON.
*
*              Cú pháp mẫu
*              -----------
*              Giá trị đơn:      {{header.idkey}}  {{buyer.tax_code}}
*                                {{seller.tax_code}} {{summary.total}}
*                                {{adjust.org_seq}} {{cred.taxcode}}
*                                {{cred.apiuser}}  {{cred.apisecret}}
*                                {{req.bukrs}}     {{req.src_docno}}
*              Hàm dựng sẵn:     {{fn.invoice_datetime}}  YYYY-MM-DD hh:mm:ss
*                                {{fn.invoice_date}}      YYYY-MM-DD
*                                {{fn.invoice_millis}}    epoch millis
*                                {{fn.now_datetime}}
*              Vòng lặp hàng hoá:
*                  {{#items}} ... {{item.item_name}} ... {{/items}}
*              Vòng lặp bảng thuế:
*                  {{#taxes}} ... {{tax.tax_rate}} ... {{/taxes}}
*
*              Số được xuất theo chuẩn JSON (dấu '.', không zero dẫn
*              đầu); ngày dạng DATS được xuất YYYY-MM-DD. Chuỗi KHÔNG
*              tự escape — nếu mẫu là JSON hãy dùng {{$json.xxx}} để
*              escape, còn mẫu XML dùng {{$xml.xxx}}.
* Tham Số    : Đăng ký ZTB_HDDT_PROV với CLASSNAME của lớp này (hoặc
*              lớp con) và khai mẫu trong ZTB_HDDT_TPL.
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       28/08/2026    cuongus - CuongUS        abapGit     Tạo mới
*=====================================================================
CLASS zcl_hddt_prov_template DEFINITION
  PUBLIC
  INHERITING FROM zcl_hddt_prov_base
  CREATE PUBLIC .

  PUBLIC SECTION.

    CONSTANTS gc_provider TYPE zde_hddt_prov VALUE 'TEMPLATE' ##NO_TEXT.

    METHODS zif_hddt_provider~get_id         REDEFINITION .
    METHODS zif_hddt_provider~build_payload  REDEFINITION .
    METHODS zif_hddt_provider~parse_response REDEFINITION .

  PROTECTED SECTION.

    "! Đọc mẫu của nghiệp vụ; lớp con có thể override để lấy từ nơi khác.
    METHODS get_template
      IMPORTING i_action     TYPE zde_hddt_action
      RETURNING VALUE(r_tpl) TYPE string
      RAISING   zcx_hddt_error .

    "! Thay thế toàn bộ placeholder trong một đoạn mẫu.
    METHODS render
      IMPORTING i_template     TYPE string
                is_request      TYPE zif_hddt_types=>ty_request
                is_cred         TYPE ztb_hddt_cred
                is_item         TYPE zif_hddt_types=>ty_item OPTIONAL
                is_tax          TYPE zif_hddt_types=>ty_tax OPTIONAL
      RETURNING VALUE(r_result) TYPE string .

  PRIVATE SECTION.

    METHODS expand_loops
      IMPORTING i_template      TYPE string
                is_request       TYPE zif_hddt_types=>ty_request
                is_cred          TYPE ztb_hddt_cred
      RETURNING VALUE(r_result) TYPE string .

    METHODS resolve_token
      IMPORTING i_token        TYPE string
                is_request      TYPE zif_hddt_types=>ty_request
                is_cred         TYPE ztb_hddt_cred
                is_item         TYPE zif_hddt_types=>ty_item
                is_tax          TYPE zif_hddt_types=>ty_tax
      RETURNING VALUE(r_value) TYPE string .

    METHODS value_of
      IMPORTING is_struct       TYPE any
                i_component    TYPE string
      RETURNING VALUE(r_value) TYPE string .

    METHODS escape_xml
      IMPORTING i_value          TYPE string
      RETURNING VALUE(r_escaped) TYPE string .

ENDCLASS.



CLASS zcl_hddt_prov_template IMPLEMENTATION.

  METHOD zif_hddt_provider~get_id.

    r_provider = gc_provider.

  ENDMETHOD.


  METHOD get_template.

    SELECT SINGLE tpl_body, xactive
      FROM ztb_hddt_tpl
      WHERE provider = @( zif_hddt_provider~get_id( ) )
        AND action   = @i_action
      INTO @DATA(ls_tpl).
    IF sy-subrc <> 0.
      zcx_hddt_error=>raise_text(
        |Chưa khai mẫu payload cho { zif_hddt_provider~get_id( ) } / | &&
        |nghiệp vụ { i_action } trong bảng ZTB_HDDT_TPL.| ).
    ENDIF.

    IF ls_tpl-xactive <> abap_true.
      zcx_hddt_error=>raise_text(
        |Mẫu payload { zif_hddt_provider~get_id( ) }/{ i_action } đang bị khoá.| ).
    ENDIF.

    r_tpl = ls_tpl-tpl_body.

  ENDMETHOD.


  METHOD zif_hddt_provider~build_payload.

    DATA(lv_tpl) = get_template( i_action ).

    " Bước 1: bung các khối lặp {{#items}} / {{#taxes}}
    DATA(lv_body) = expand_loops( i_template = lv_tpl
                                  is_request  = is_request
                                  is_cred     = is_cred ).

    " Bước 2: thay các placeholder còn lại ở cấp hoá đơn
    r_payload = render( i_template = lv_body
                         is_request  = is_request
                         is_cred     = is_cred ).

  ENDMETHOD.


  METHOD expand_loops.

    r_result = i_template.

    DATA lv_open  TYPE string.
    DATA lv_close TYPE string.
    DATA lv_block TYPE string.
    DATA lv_out   TYPE string.
    DATA lv_off   TYPE i.
    DATA lv_len   TYPE i.
    DATA lv_pos1  TYPE i.
    DATA lv_pos2  TYPE i.

    DATA lv_kind TYPE i.

    DO 2 TIMES.
      " Phải giữ lại chỉ số của DO: SY-INDEX bên trong WHILE là của
      " chính WHILE, không còn là của DO nữa.
      lv_kind = sy-index.
      CASE lv_kind.
        WHEN 1.
          lv_open  = `{{#items}}`.
          lv_close = `{{/items}}`.
        WHEN 2.
          lv_open  = `{{#taxes}}`.
          lv_close = `{{/taxes}}`.
      ENDCASE.

      WHILE r_result CS lv_open.
        lv_pos1 = sy-fdpos.
        IF NOT r_result CS lv_close.
          EXIT.                              " mẫu thiếu thẻ đóng
        ENDIF.
        lv_pos2 = sy-fdpos.
        IF lv_pos2 < lv_pos1.
          EXIT.
        ENDIF.

        lv_off   = lv_pos1 + strlen( lv_open ).
        lv_len   = lv_pos2 - lv_off.
        lv_block = substring( val = r_result off = lv_off len = lv_len ).

        CLEAR lv_out.
        IF lv_kind = 1.
          LOOP AT is_request-invoice-items ASSIGNING FIELD-SYMBOL(<fs_item>).
            lv_out = lv_out && render( i_template = lv_block
                                       is_request  = is_request
                                       is_cred     = is_cred
                                       is_item     = <fs_item> ).
          ENDLOOP.
        ELSE.
          LOOP AT is_request-invoice-taxes ASSIGNING FIELD-SYMBOL(<fs_tax>).
            lv_out = lv_out && render( i_template = lv_block
                                       is_request  = is_request
                                       is_cred     = is_cred
                                       is_tax      = <fs_tax> ).
          ENDLOOP.
        ENDIF.

        r_result = substring( val = r_result len = lv_pos1 )
                 && lv_out
                 && substring( val = r_result off = lv_pos2 + strlen( lv_close ) ).
      ENDWHILE.
    ENDDO.

  ENDMETHOD.


  METHOD render.

    DATA lv_token TYPE string.
    DATA lv_pos1  TYPE i.
    DATA lv_pos2  TYPE i.

    r_result = i_template.

    WHILE r_result CS `{{`.
      lv_pos1 = sy-fdpos.
      IF NOT r_result CS `}}`.
        EXIT.
      ENDIF.
      lv_pos2 = sy-fdpos.
      IF lv_pos2 <= lv_pos1.
        EXIT.
      ENDIF.

      lv_token = substring( val = r_result
                            off = lv_pos1 + 2
                            len = lv_pos2 - lv_pos1 - 2 ).
      CONDENSE lv_token NO-GAPS.

      DATA(lv_value) = resolve_token( i_token   = lv_token
                                      is_request = is_request
                                      is_cred    = is_cred
                                      is_item    = is_item
                                      is_tax     = is_tax ).

      r_result = substring( val = r_result len = lv_pos1 )
               && lv_value
               && substring( val = r_result off = lv_pos2 + 2 ).
    ENDWHILE.

  ENDMETHOD.


  METHOD resolve_token.

    DATA lv_token TYPE string.
    DATA lv_mode  TYPE string.

    lv_token = i_token.

    " Tiền tố escape: $json.xxx / $xml.xxx
    IF strlen( lv_token ) > 6 AND substring( val = lv_token len = 6 ) = `$json.`.
      lv_mode  = `JSON`.
      lv_token = substring( val = lv_token off = 6 ).
    ELSEIF strlen( lv_token ) > 5 AND substring( val = lv_token len = 5 ) = `$xml.`.
      lv_mode  = `XML`.
      lv_token = substring( val = lv_token off = 5 ).
    ENDIF.

    SPLIT lv_token AT `.` INTO DATA(lv_group) DATA(lv_field).
    TRANSLATE lv_group TO LOWER CASE.
    TRANSLATE lv_field TO LOWER CASE.

    CASE lv_group.

      WHEN `fn`.
        DATA(ls_hdr) = is_request-invoice-header.
        CASE lv_field.
          WHEN `invoice_datetime`.
            r_value = fmt_datetime( i_date = ls_hdr-inv_date
                                     i_time = ls_hdr-inv_time ).
          WHEN `invoice_date`.
            r_value = fmt_date( ls_hdr-inv_date ).
          WHEN `invoice_date_vn`.
            r_value = fmt_date_vn( ls_hdr-inv_date ).
          WHEN `invoice_millis`.
            r_value = to_epoch_millis( i_date = ls_hdr-inv_date
                                        i_time = ls_hdr-inv_time ).
          WHEN `now_datetime`.
            r_value = fmt_datetime( i_date = sy-datum i_time = sy-uzeit ).
          WHEN `item_count`.
            r_value = |{ lines( is_request-invoice-items ) }|.
          WHEN OTHERS.
            CLEAR r_value.
        ENDCASE.

      WHEN `header`.
        r_value = value_of( is_struct    = is_request-invoice-header
                             i_component = lv_field ).
      WHEN `seller`.
        r_value = value_of( is_struct    = is_request-invoice-seller
                             i_component = lv_field ).
      WHEN `buyer`.
        r_value = value_of( is_struct    = is_request-invoice-buyer
                             i_component = lv_field ).
      WHEN `summary`.
        r_value = value_of( is_struct    = is_request-invoice-summary
                             i_component = lv_field ).
      WHEN `adjust`.
        r_value = value_of( is_struct    = is_request-invoice-adjust
                             i_component = lv_field ).
      WHEN `item`.
        r_value = value_of( is_struct    = is_item
                             i_component = lv_field ).
      WHEN `tax`.
        r_value = value_of( is_struct    = is_tax
                             i_component = lv_field ).
      WHEN `cred`.
        r_value = value_of( is_struct    = is_cred
                             i_component = lv_field ).
      WHEN `req`.
        r_value = value_of( is_struct    = is_request
                             i_component = lv_field ).
      WHEN `parm`.
        r_value = get_config( )->get_param( i_key      = CONV #( to_upper( lv_field ) )
                                             i_provider = zif_hddt_provider~get_id( )
                                             i_bukrs    = is_request-bukrs ).
      WHEN OTHERS.
        " Placeholder không nhận dạng được -> trả rỗng, sẽ thấy ngay
        " trong log payload thay vì gửi chuỗi "{{...}}" cho NCC.
        CLEAR r_value.
    ENDCASE.

    CASE lv_mode.
      WHEN `JSON`.
        r_value = zcl_hddt_json=>escape( r_value ).
      WHEN `XML`.
        r_value = escape_xml( r_value ).
      WHEN OTHERS.
    ENDCASE.

  ENDMETHOD.


  METHOD value_of.

    FIELD-SYMBOLS <fs_any> TYPE any.

    DATA(lv_comp) = to_upper( i_component ).
    ASSIGN COMPONENT lv_comp OF STRUCTURE is_struct TO <fs_any>.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    DATA(lo_type) = cl_abap_typedescr=>describe_by_data( <fs_any> ).

    CASE lo_type->type_kind.
      WHEN cl_abap_typedescr=>typekind_packed
        OR cl_abap_typedescr=>typekind_float
        OR cl_abap_typedescr=>typekind_int
        OR cl_abap_typedescr=>typekind_int1
        OR cl_abap_typedescr=>typekind_int2
        OR cl_abap_typedescr=>typekind_int8.
        r_value = zcl_hddt_json=>format_number( <fs_any> ).

      WHEN cl_abap_typedescr=>typekind_date.
        r_value = fmt_date( CONV dats( <fs_any> ) ).

      WHEN cl_abap_typedescr=>typekind_time.
        DATA lv_time TYPE uzeit.
        lv_time  = <fs_any>.
        r_value = |{ lv_time(2) }:{ lv_time+2(2) }:{ lv_time+4(2) }|.

      WHEN OTHERS.
        r_value = |{ <fs_any> }|.
        " Trường CHAR trong DDIC được đệm khoảng trắng bên phải
        CONDENSE r_value.
    ENDCASE.

  ENDMETHOD.


  METHOD escape_xml.

    r_escaped = i_value.
    REPLACE ALL OCCURRENCES OF `&`  IN r_escaped WITH `&amp;`.
    REPLACE ALL OCCURRENCES OF `<`  IN r_escaped WITH `&lt;`.
    REPLACE ALL OCCURRENCES OF `>`  IN r_escaped WITH `&gt;`.
    REPLACE ALL OCCURRENCES OF `"`  IN r_escaped WITH `&quot;`.
    REPLACE ALL OCCURRENCES OF `'`  IN r_escaped WITH `&apos;`.

  ENDMETHOD.


  METHOD zif_hddt_provider~parse_response.

    DATA(lv_ok_http) = xsdbool( i_http_code >= 200 AND i_http_code < 300 ).

    cs_result-prov_status = |{ i_http_code }|.
    cs_result-success     = lv_ok_http.

    IF i_body IS INITIAL.
      cs_result-message = |HTTP { i_http_code }: không có nội dung trả về.|.
      RETURN.
    ENDIF.

    DATA(lv_body) = i_body.
    CONDENSE lv_body.

    " Nếu là JSON thì bóc các thẻ thông dụng để không mất thông tin
    IF substring( val = lv_body len = 1 ) = `{`
       OR substring( val = lv_body len = 1 ) = `[`.
      TRY.
          DATA(lt_val) = zcl_hddt_json=>parse( lv_body ).
          cs_result-fields   = lt_val.
          cs_result-serial   = zcl_hddt_json=>get_value_by_name(
                                 it_values = lt_val i_name = `serial` ).
          cs_result-seq      = zcl_hddt_json=>get_value_by_name(
                                 it_values = lt_val i_name = `seq` ).
          cs_result-sec_code = zcl_hddt_json=>get_value_by_name(
                                 it_values = lt_val i_name = `sec` ).
          cs_result-inv_link = zcl_hddt_json=>get_value_by_name(
                                 it_values = lt_val i_name = `link` ).
          DATA(lv_msg) = zcl_hddt_json=>get_value_by_name(
                           it_values = lt_val i_name = `message` ).
          IF lv_msg IS NOT INITIAL.
            cs_result-message = lv_msg.
          ENDIF.
        CATCH zcx_hddt_error.
          " để nguyên, dùng nhánh text bên dưới
      ENDTRY.
    ENDIF.

    IF cs_result-message IS INITIAL.
      cs_result-message = substring( val = lv_body
                                     len = nmin( val1 = 255
                                                 val2 = strlen( lv_body ) ) ).
    ENDIF.

  ENDMETHOD.

ENDCLASS.
