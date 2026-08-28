*=====================================================================
* Tên/Mã     : ZFIC_HDDT_PROV_TEMPLATE
* Mô tả chung: Adapter TỔNG QUÁT dựng payload từ MẪU lưu trong bảng
*              cấu hình ZFIT_HDDT_TPL — không cần viết ABAP mới.
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
* Tham Số    : Đăng ký ZFIT_HDDT_PROV với CLASSNAME của lớp này (hoặc
*              lớp con) và khai mẫu trong ZFIT_HDDT_TPL.
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       28/08/2026    cuongus - CuongUS        abapGit     Tạo mới
*=====================================================================
CLASS zfic_hddt_prov_template DEFINITION
  PUBLIC
  INHERITING FROM zfic_hddt_prov_base
  CREATE PUBLIC .

  PUBLIC SECTION.

    CONSTANTS gc_provider TYPE zfide_hddt_prov VALUE 'TEMPLATE' ##NO_TEXT.

    METHODS zfiif_hddt_provider~get_id         REDEFINITION .
    METHODS zfiif_hddt_provider~build_payload  REDEFINITION .
    METHODS zfiif_hddt_provider~parse_response REDEFINITION .

  PROTECTED SECTION.

    "! Đọc mẫu của nghiệp vụ; lớp con có thể override để lấy từ nơi khác.
    METHODS get_template
      IMPORTING iv_action     TYPE zfide_hddt_action
      RETURNING VALUE(rv_tpl) TYPE string
      RAISING   zficx_hddt_error .

    "! Thay thế toàn bộ placeholder trong một đoạn mẫu.
    METHODS render
      IMPORTING iv_template     TYPE string
                is_request      TYPE zfiif_hddt_types=>ty_request
                is_cred         TYPE zfit_hddt_cred
                is_item         TYPE zfiif_hddt_types=>ty_item OPTIONAL
                is_tax          TYPE zfiif_hddt_types=>ty_tax OPTIONAL
      RETURNING VALUE(rv_result) TYPE string .

  PRIVATE SECTION.

    METHODS expand_loops
      IMPORTING iv_template      TYPE string
                is_request       TYPE zfiif_hddt_types=>ty_request
                is_cred          TYPE zfit_hddt_cred
      RETURNING VALUE(rv_result) TYPE string .

    METHODS resolve_token
      IMPORTING iv_token        TYPE string
                is_request      TYPE zfiif_hddt_types=>ty_request
                is_cred         TYPE zfit_hddt_cred
                is_item         TYPE zfiif_hddt_types=>ty_item
                is_tax          TYPE zfiif_hddt_types=>ty_tax
      RETURNING VALUE(rv_value) TYPE string .

    METHODS value_of
      IMPORTING is_struct       TYPE any
                iv_component    TYPE string
      RETURNING VALUE(rv_value) TYPE string .

    METHODS escape_xml
      IMPORTING iv_value          TYPE string
      RETURNING VALUE(rv_escaped) TYPE string .

ENDCLASS.



CLASS zfic_hddt_prov_template IMPLEMENTATION.

  METHOD zfiif_hddt_provider~get_id.

    rv_provider = gc_provider.

  ENDMETHOD.


  METHOD get_template.

    SELECT SINGLE tpl_body, xactive
      FROM zfit_hddt_tpl
      INTO @DATA(ls_tpl)
      WHERE provider = @( zfiif_hddt_provider~get_id( ) )
        AND action   = @iv_action.
    IF sy-subrc <> 0.
      zficx_hddt_error=>raise_text(
        |Chưa khai mẫu payload cho { zfiif_hddt_provider~get_id( ) } / | &&
        |nghiệp vụ { iv_action } trong bảng ZFIT_HDDT_TPL.| ).
    ENDIF.

    IF ls_tpl-xactive <> abap_true.
      zficx_hddt_error=>raise_text(
        |Mẫu payload { zfiif_hddt_provider~get_id( ) }/{ iv_action } đang bị khoá.| ).
    ENDIF.

    rv_tpl = ls_tpl-tpl_body.

  ENDMETHOD.


  METHOD zfiif_hddt_provider~build_payload.

    DATA(lv_tpl) = get_template( iv_action ).

    " Bước 1: bung các khối lặp {{#items}} / {{#taxes}}
    DATA(lv_body) = expand_loops( iv_template = lv_tpl
                                  is_request  = is_request
                                  is_cred     = is_cred ).

    " Bước 2: thay các placeholder còn lại ở cấp hoá đơn
    rv_payload = render( iv_template = lv_body
                         is_request  = is_request
                         is_cred     = is_cred ).

  ENDMETHOD.


  METHOD expand_loops.

    rv_result = iv_template.

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

      WHILE rv_result CS lv_open.
        lv_pos1 = sy-fdpos.
        IF NOT rv_result CS lv_close.
          EXIT.                              " mẫu thiếu thẻ đóng
        ENDIF.
        lv_pos2 = sy-fdpos.
        IF lv_pos2 < lv_pos1.
          EXIT.
        ENDIF.

        lv_off   = lv_pos1 + strlen( lv_open ).
        lv_len   = lv_pos2 - lv_off.
        lv_block = substring( val = rv_result off = lv_off len = lv_len ).

        CLEAR lv_out.
        IF lv_kind = 1.
          LOOP AT is_request-invoice-items ASSIGNING FIELD-SYMBOL(<ls_item>).
            lv_out = lv_out && render( iv_template = lv_block
                                       is_request  = is_request
                                       is_cred     = is_cred
                                       is_item     = <ls_item> ).
          ENDLOOP.
        ELSE.
          LOOP AT is_request-invoice-taxes ASSIGNING FIELD-SYMBOL(<ls_tax>).
            lv_out = lv_out && render( iv_template = lv_block
                                       is_request  = is_request
                                       is_cred     = is_cred
                                       is_tax      = <ls_tax> ).
          ENDLOOP.
        ENDIF.

        rv_result = substring( val = rv_result len = lv_pos1 )
                 && lv_out
                 && substring( val = rv_result off = lv_pos2 + strlen( lv_close ) ).
      ENDWHILE.
    ENDDO.

  ENDMETHOD.


  METHOD render.

    DATA lv_token TYPE string.
    DATA lv_pos1  TYPE i.
    DATA lv_pos2  TYPE i.

    rv_result = iv_template.

    WHILE rv_result CS `{{`.
      lv_pos1 = sy-fdpos.
      IF NOT rv_result CS `}}`.
        EXIT.
      ENDIF.
      lv_pos2 = sy-fdpos.
      IF lv_pos2 <= lv_pos1.
        EXIT.
      ENDIF.

      lv_token = substring( val = rv_result
                            off = lv_pos1 + 2
                            len = lv_pos2 - lv_pos1 - 2 ).
      CONDENSE lv_token NO-GAPS.

      DATA(lv_value) = resolve_token( iv_token   = lv_token
                                      is_request = is_request
                                      is_cred    = is_cred
                                      is_item    = is_item
                                      is_tax     = is_tax ).

      rv_result = substring( val = rv_result len = lv_pos1 )
               && lv_value
               && substring( val = rv_result off = lv_pos2 + 2 ).
    ENDWHILE.

  ENDMETHOD.


  METHOD resolve_token.

    DATA lv_token TYPE string.
    DATA lv_mode  TYPE string.

    lv_token = iv_token.

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
            rv_value = fmt_datetime( iv_date = ls_hdr-inv_date
                                     iv_time = ls_hdr-inv_time ).
          WHEN `invoice_date`.
            rv_value = fmt_date( ls_hdr-inv_date ).
          WHEN `invoice_date_vn`.
            rv_value = fmt_date_vn( ls_hdr-inv_date ).
          WHEN `invoice_millis`.
            rv_value = to_epoch_millis( iv_date = ls_hdr-inv_date
                                        iv_time = ls_hdr-inv_time ).
          WHEN `now_datetime`.
            rv_value = fmt_datetime( iv_date = sy-datum iv_time = sy-uzeit ).
          WHEN `item_count`.
            rv_value = |{ lines( is_request-invoice-items ) }|.
          WHEN OTHERS.
            CLEAR rv_value.
        ENDCASE.

      WHEN `header`.
        rv_value = value_of( is_struct    = is_request-invoice-header
                             iv_component = lv_field ).
      WHEN `seller`.
        rv_value = value_of( is_struct    = is_request-invoice-seller
                             iv_component = lv_field ).
      WHEN `buyer`.
        rv_value = value_of( is_struct    = is_request-invoice-buyer
                             iv_component = lv_field ).
      WHEN `summary`.
        rv_value = value_of( is_struct    = is_request-invoice-summary
                             iv_component = lv_field ).
      WHEN `adjust`.
        rv_value = value_of( is_struct    = is_request-invoice-adjust
                             iv_component = lv_field ).
      WHEN `item`.
        rv_value = value_of( is_struct    = is_item
                             iv_component = lv_field ).
      WHEN `tax`.
        rv_value = value_of( is_struct    = is_tax
                             iv_component = lv_field ).
      WHEN `cred`.
        rv_value = value_of( is_struct    = is_cred
                             iv_component = lv_field ).
      WHEN `req`.
        rv_value = value_of( is_struct    = is_request
                             iv_component = lv_field ).
      WHEN `parm`.
        rv_value = get_config( )->get_param( iv_key      = CONV #( to_upper( lv_field ) )
                                             iv_provider = zfiif_hddt_provider~get_id( )
                                             iv_bukrs    = is_request-bukrs ).
      WHEN OTHERS.
        " Placeholder không nhận dạng được -> trả rỗng, sẽ thấy ngay
        " trong log payload thay vì gửi chuỗi "{{...}}" cho NCC.
        CLEAR rv_value.
    ENDCASE.

    CASE lv_mode.
      WHEN `JSON`.
        rv_value = zfic_hddt_json=>escape( rv_value ).
      WHEN `XML`.
        rv_value = escape_xml( rv_value ).
      WHEN OTHERS.
    ENDCASE.

  ENDMETHOD.


  METHOD value_of.

    FIELD-SYMBOLS <lv_any> TYPE any.

    DATA(lv_comp) = to_upper( iv_component ).
    ASSIGN COMPONENT lv_comp OF STRUCTURE is_struct TO <lv_any>.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    DATA(lo_type) = cl_abap_typedescr=>describe_by_data( <lv_any> ).

    CASE lo_type->type_kind.
      WHEN cl_abap_typedescr=>typekind_packed
        OR cl_abap_typedescr=>typekind_float
        OR cl_abap_typedescr=>typekind_int
        OR cl_abap_typedescr=>typekind_int1
        OR cl_abap_typedescr=>typekind_int2
        OR cl_abap_typedescr=>typekind_int8.
        rv_value = zfic_hddt_json=>format_number( <lv_any> ).

      WHEN cl_abap_typedescr=>typekind_date.
        rv_value = fmt_date( CONV dats( <lv_any> ) ).

      WHEN cl_abap_typedescr=>typekind_time.
        DATA lv_time TYPE uzeit.
        lv_time  = <lv_any>.
        rv_value = |{ lv_time(2) }:{ lv_time+2(2) }:{ lv_time+4(2) }|.

      WHEN OTHERS.
        rv_value = |{ <lv_any> }|.
        " Trường CHAR trong DDIC được đệm khoảng trắng bên phải
        CONDENSE rv_value.
    ENDCASE.

  ENDMETHOD.


  METHOD escape_xml.

    rv_escaped = iv_value.
    REPLACE ALL OCCURRENCES OF `&`  IN rv_escaped WITH `&amp;`.
    REPLACE ALL OCCURRENCES OF `<`  IN rv_escaped WITH `&lt;`.
    REPLACE ALL OCCURRENCES OF `>`  IN rv_escaped WITH `&gt;`.
    REPLACE ALL OCCURRENCES OF `"`  IN rv_escaped WITH `&quot;`.
    REPLACE ALL OCCURRENCES OF `'`  IN rv_escaped WITH `&apos;`.

  ENDMETHOD.


  METHOD zfiif_hddt_provider~parse_response.

    DATA(lv_ok_http) = xsdbool( iv_http_code >= 200 AND iv_http_code < 300 ).

    cs_result-prov_status = |{ iv_http_code }|.
    cs_result-success     = lv_ok_http.

    IF iv_body IS INITIAL.
      cs_result-message = |HTTP { iv_http_code }: không có nội dung trả về.|.
      RETURN.
    ENDIF.

    DATA(lv_body) = iv_body.
    CONDENSE lv_body.

    " Nếu là JSON thì bóc các thẻ thông dụng để không mất thông tin
    IF substring( val = lv_body len = 1 ) = `{`
       OR substring( val = lv_body len = 1 ) = `[`.
      TRY.
          DATA(lt_val) = zfic_hddt_json=>parse( lv_body ).
          cs_result-fields   = lt_val.
          cs_result-serial   = zfic_hddt_json=>get_value_by_name(
                                 it_values = lt_val iv_name = `serial` ).
          cs_result-seq      = zfic_hddt_json=>get_value_by_name(
                                 it_values = lt_val iv_name = `seq` ).
          cs_result-sec_code = zfic_hddt_json=>get_value_by_name(
                                 it_values = lt_val iv_name = `sec` ).
          cs_result-inv_link = zfic_hddt_json=>get_value_by_name(
                                 it_values = lt_val iv_name = `link` ).
          DATA(lv_msg) = zfic_hddt_json=>get_value_by_name(
                           it_values = lt_val iv_name = `message` ).
          IF lv_msg IS NOT INITIAL.
            cs_result-message = lv_msg.
          ENDIF.
        CATCH zficx_hddt_error.
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
