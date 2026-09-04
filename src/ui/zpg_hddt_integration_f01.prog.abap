*=====================================================================
* Tên/Mã     : ZPG_HDDT_INTEGRATION_F01
* Mô tả chung: Lớp local điều khiển ALV (LCL_APP, gộp include _CL1 cũ)
*              và form routine hỗ trợ màn hình cho ZPG_HDDT_INTEGRATION:
*              hiển thị chuỗi dài (payload / log), lấy thông tin hoá
*              đơn gốc khi điều chỉnh - thay thế - huỷ, và lưu file
*              hoá đơn xuống máy trạm.
* Tham Số    : Xem từng FORM
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       28/08/2026    cuongus - CuongUS        abapGit     Tạo mới
* 1.1       03/09/2026    cuongus - CuongUS        abapGit     Popup chọn
*                         hoá đơn gốc, truyền chứng từ gốc cho engine
*=====================================================================

CLASS lcl_app DEFINITION FINAL CREATE PUBLIC.

  PUBLIC SECTION.

    METHODS run.

    METHODS on_function
      FOR EVENT added_function OF cl_salv_events
      IMPORTING e_salv_function.

    METHODS on_link_click
      FOR EVENT link_click OF cl_salv_events_table
      IMPORTING row column.

  PRIVATE SECTION.

    DATA mo_alv     TYPE REF TO cl_salv_table.
    DATA mo_service TYPE REF TO zcl_hddt_service.

    METHODS select_data.
    METHODS build_alv.
    METHODS add_buttons.
    METHODS set_columns.
    METHODS refresh_row
      IMPORTING i_index  TYPE i
                is_result TYPE zif_hddt_types=>ty_result.
    METHODS get_selected
      RETURNING VALUE(rt_index) TYPE salv_t_row.
    METHODS execute_action
      IMPORTING i_action TYPE zde_hddt_action.
    METHODS show_payload.
    METHODS show_log.
    METHODS map_light
      IMPORTING i_status      TYPE zde_hddt_status
                i_msgty       TYPE symsgty
      RETURNING VALUE(r_icon) TYPE c LENGTH 4.
    METHODS status_text
      IMPORTING i_status      TYPE zde_hddt_status
      RETURNING VALUE(r_text) TYPE c LENGTH 60.

ENDCLASS.


CLASS lcl_app IMPLEMENTATION.

  METHOD run.

    mo_service = zcl_hddt_service=>get_instance( ).

    select_data( ).
    IF gt_alv IS INITIAL.
      MESSAGE s001(zms_hddt) DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.

    build_alv( ).

  ENDMETHOD.


  METHOD select_data.

    CLEAR: gt_alv, gt_request.

    TRY.
        DATA(lo_source) = zcl_hddt_factory=>get_source( i_bukrs    = p_bukrs
                                                         i_src_type = p_srct ).

        DATA(ls_sel) = VALUE zif_hddt_source=>ty_selection(
          bukrs    = p_bukrs
          gjahr    = p_gjahr
          r_docno   = CORRESPONDING #( s_belnr[] )
          r_budat   = CORRESPONDING #( s_budat[] )
          r_bldat   = CORRESPONDING #( s_bldat[] )
          r_blart   = CORRESPONDING #( s_blart[] )
          r_vbeln   = CORRESPONDING #( s_vbeln[] )
          r_kunnr   = CORRESPONDING #( s_kunnr[] )
          r_usnam   = CORRESPONDING #( s_usnam[] )
          r_status  = CORRESPONDING #( s_stat[] )
          xreversed = p_rever ).

        gt_request = lo_source->select_documents( ls_sel ).

      CATCH zcx_hddt_error INTO DATA(lx).
        MESSAGE lx->get_text_long( ) TYPE 'S' DISPLAY LIKE 'E'.
        RETURN.
    ENDTRY.

    " Ghép trạng thái đã lưu trong sổ đăng ký vào danh sách hiển thị
    SELECT * FROM ztb_hddt_inv
      INTO TABLE @DATA(lt_reg)
      WHERE bukrs = @p_bukrs
        AND gjahr = @p_gjahr.

    LOOP AT gt_request ASSIGNING FIELD-SYMBOL(<fs_req>).
      IF p_prov IS NOT INITIAL.
        <fs_req>-provider = p_prov.
      ENDIF.

      APPEND INITIAL LINE TO gt_alv ASSIGNING FIELD-SYMBOL(<fs_alv>).
      <fs_alv>-bukrs      = <fs_req>-bukrs.
      <fs_alv>-gjahr      = <fs_req>-gjahr.
      <fs_alv>-src_type   = <fs_req>-src_type.
      <fs_alv>-src_docno  = <fs_req>-src_docno.
      <fs_alv>-blart      = <fs_req>-src_info-blart.
      <fs_alv>-budat      = <fs_req>-src_info-budat.
      <fs_alv>-bldat      = <fs_req>-src_info-bldat.
      <fs_alv>-awkey      = <fs_req>-src_info-awkey.
      <fs_alv>-inv_date   = <fs_req>-invoice-header-inv_date.
      IF <fs_req>-src_info-xreversed = abap_true
         OR <fs_req>-src_info-xcancel = abap_true.
        <fs_alv>-reversed = icon_storno.
      ENDIF.
      READ TABLE <fs_req>-invoice-ext INTO DATA(ls_ext)
           WITH KEY name = 'TAX_RATE_SUMMARY'.
      IF sy-subrc = 0.
        <fs_alv>-tax_summ = ls_ext-value.
      ENDIF.
      <fs_alv>-buyer_code = <fs_req>-invoice-buyer-code.
      <fs_alv>-buyer_name = <fs_req>-invoice-buyer-legal_name.
      <fs_alv>-buyer_tax  = <fs_req>-invoice-buyer-tax_code.
      <fs_alv>-waers      = <fs_req>-invoice-header-currency.
      <fs_alv>-amount     = <fs_req>-invoice-summary-amount_wo_tax.
      <fs_alv>-vat_amount = <fs_req>-invoice-summary-tax_amount.
      <fs_alv>-total      = <fs_req>-invoice-summary-total.
      <fs_alv>-provider   = <fs_req>-provider.
      <fs_alv>-inv_type   = <fs_req>-invoice-header-inv_type.

      TRY.
          DATA(ls_reg) = lt_reg[ bukrs     = <fs_req>-bukrs
                                 gjahr     = <fs_req>-gjahr
                                 src_type  = <fs_req>-src_type
                                 src_docno = <fs_req>-src_docno ].
          <fs_alv>-provider   = ls_reg-provider.
          <fs_alv>-template   = ls_reg-template.
          <fs_alv>-serial     = ls_reg-serial.
          <fs_alv>-seq        = ls_reg-seq.
          <fs_alv>-issue_date = ls_reg-issue_date.
          <fs_alv>-mscqt      = ls_reg-mscqt.
          <fs_alv>-sec_code   = ls_reg-sec_code.
          <fs_alv>-inv_link   = ls_reg-inv_link.
          <fs_alv>-status     = ls_reg-status.
          <fs_alv>-message    = ls_reg-message.
          <fs_alv>-ref_docno  = ls_reg-ref_docno.
        CATCH cx_sy_itab_line_not_found.
          <fs_alv>-status = zif_hddt_types=>gc_status-not_sent.
      ENDTRY.

      <fs_alv>-status_txt = status_text( <fs_alv>-status ).
      <fs_alv>-light      = map_light( i_status = <fs_alv>-status
                                       i_msgty  = <fs_alv>-msgty ).
    ENDLOOP.

  ENDMETHOD.


  METHOD build_alv.

    TRY.
        cl_salv_table=>factory( IMPORTING r_salv_table = mo_alv
                                CHANGING  t_table      = gt_alv ).
      CATCH cx_salv_msg INTO DATA(lx_salv).
        MESSAGE lx_salv->get_text( ) TYPE 'S' DISPLAY LIKE 'E'.
        RETURN.
    ENDTRY.

    mo_alv->get_functions( )->set_all( abap_true ).
    add_buttons( ).
    set_columns( ).

    mo_alv->get_selections( )->set_selection_mode(
      if_salv_c_selection_mode=>row_column ).

    DATA lv_title TYPE lvc_title.
    lv_title = |Tích hợp HĐĐT - công ty { p_bukrs } / năm { p_gjahr }|.
    mo_alv->get_display_settings( )->set_list_header( lv_title ).
    mo_alv->get_display_settings( )->set_striped_pattern( abap_true ).

    SET HANDLER me->on_function   FOR mo_alv->get_event( ).
    SET HANDLER me->on_link_click FOR mo_alv->get_event( ).

    mo_alv->display( ).

  ENDMETHOD.


  METHOD add_buttons.

    DATA(lo_fn) = mo_alv->get_functions( ).

    TRY.
        lo_fn->add_function( name     = gc_fcode-issue
                             icon     = CONV #( icon_execute_object )
                             text     = 'Phát hành'
                             tooltip  = 'Phát hành hoá đơn điện tử'
                             position = if_salv_c_function_position=>right_of_salv_functions ).
        lo_fn->add_function( name     = gc_fcode-adjust
                             icon     = CONV #( icon_change )
                             text     = 'Điều chỉnh'
                             tooltip  = 'Lập hoá đơn điều chỉnh'
                             position = if_salv_c_function_position=>right_of_salv_functions ).
        lo_fn->add_function( name     = gc_fcode-replace
                             icon     = CONV #( icon_replace )
                             text     = 'Thay thế'
                             tooltip  = 'Lập hoá đơn thay thế'
                             position = if_salv_c_function_position=>right_of_salv_functions ).
        lo_fn->add_function( name     = gc_fcode-cancel
                             icon     = CONV #( icon_delete )
                             text     = 'Huỷ'
                             tooltip  = 'Huỷ hoá đơn (thông báo sai sót)'
                             position = if_salv_c_function_position=>right_of_salv_functions ).
        lo_fn->add_function( name     = gc_fcode-search
                             icon     = CONV #( icon_display )
                             text     = 'Tra cứu'
                             tooltip  = 'Tra cứu trạng thái trên hệ thống NCC'
                             position = if_salv_c_function_position=>right_of_salv_functions ).
        lo_fn->add_function( name     = gc_fcode-getfile
                             icon     = CONV #( icon_pdf )
                             text     = 'Lấy file'
                             tooltip  = 'Tải file hoá đơn từ NCC'
                             position = if_salv_c_function_position=>right_of_salv_functions ).
        lo_fn->add_function( name     = gc_fcode-showjs
                             icon     = CONV #( icon_xml_doc )
                             text     = 'Xem payload'
                             tooltip  = 'Xem payload sẽ gửi cho NCC'
                             position = if_salv_c_function_position=>right_of_salv_functions ).
        lo_fn->add_function( name     = gc_fcode-showlog
                             icon     = CONV #( icon_protocol )
                             text     = 'Log'
                             tooltip  = 'Xem log gọi API'
                             position = if_salv_c_function_position=>right_of_salv_functions ).
      CATCH cx_salv_wrong_call cx_salv_existing.
        " Nút đã tồn tại -> bỏ qua, không chặn hiển thị
    ENDTRY.

  ENDMETHOD.


  METHOD set_columns.

    DATA(lo_cols) = mo_alv->get_columns( ).
    lo_cols->set_optimize( abap_true ).

    TRY.
        lo_cols->get_column( 'LIGHT' )->set_short_text( 'TT' ).
        lo_cols->get_column( 'LIGHT' )->set_medium_text( 'Trạng thái' ).
        lo_cols->get_column( 'LIGHT' )->set_long_text( 'Trạng thái' ).
        CAST cl_salv_column_table( lo_cols->get_column( 'LIGHT' )
          )->set_icon( abap_true ).

        lo_cols->get_column( 'SRC_DOCNO' )->set_medium_text( 'Số chứng từ' ).
        lo_cols->get_column( 'REVERSED' )->set_short_text( 'Đảo' ).
        lo_cols->get_column( 'REVERSED' )->set_medium_text( 'Đã đảo/huỷ' ).
        CAST cl_salv_column_table( lo_cols->get_column( 'REVERSED' )
          )->set_icon( abap_true ).
        lo_cols->get_column( 'AWKEY' )->set_medium_text( 'Billing SD' ).
        lo_cols->get_column( 'INV_DATE' )->set_medium_text( 'Ngày lập HĐ' ).
        lo_cols->get_column( 'REF_DOCNO' )->set_medium_text( 'CT hoá đơn gốc' ).
        lo_cols->get_column( 'TAX_SUMM' )->set_medium_text( 'Thuế suất' ).
        lo_cols->get_column( 'BUYER_NAME' )->set_medium_text( 'Người mua' ).
        lo_cols->get_column( 'STATUS_TXT' )->set_medium_text( 'Diễn giải TT' ).
        lo_cols->get_column( 'MESSAGE' )->set_medium_text( 'Thông điệp' ).

        lo_cols->get_column( 'LOG_ID' )->set_technical( abap_true ).
        lo_cols->get_column( 'MSGTY' )->set_technical( abap_true ).

        CAST cl_salv_column_table( lo_cols->get_column( 'INV_LINK' )
          )->set_cell_type( if_salv_c_cell_type=>hotspot ).
      CATCH cx_salv_not_found.
        " Cột có thể bị đổi tên khi mở rộng -> bỏ qua
    ENDTRY.

  ENDMETHOD.


  METHOD get_selected.

    rt_index = mo_alv->get_selections( )->get_selected_rows( ).

  ENDMETHOD.


  METHOD on_function.

    CASE e_salv_function.
      WHEN gc_fcode-issue.
        execute_action( zif_hddt_types=>gc_action-create_invoice ).
      WHEN gc_fcode-adjust.
        execute_action( zif_hddt_types=>gc_action-adjust_invoice ).
      WHEN gc_fcode-replace.
        execute_action( zif_hddt_types=>gc_action-replace_invoice ).
      WHEN gc_fcode-cancel.
        execute_action( zif_hddt_types=>gc_action-cancel_invoice ).
      WHEN gc_fcode-search.
        execute_action( zif_hddt_types=>gc_action-search_invoice ).
      WHEN gc_fcode-getfile.
        execute_action( zif_hddt_types=>gc_action-get_file ).
      WHEN gc_fcode-showjs.
        show_payload( ).
      WHEN gc_fcode-showlog.
        show_log( ).
      WHEN OTHERS.
    ENDCASE.

  ENDMETHOD.


  METHOD on_link_click.

    " Nhấn vào link tra cứu hoá đơn -> mở trình duyệt
    IF column <> 'INV_LINK'.
      RETURN.
    ENDIF.
    IF row < 1 OR row > lines( gt_alv ).
      RETURN.
    ENDIF.

    DATA(lv_url) = CONV string( gt_alv[ row ]-inv_link ).
    IF lv_url IS INITIAL.
      RETURN.
    ENDIF.

    cl_gui_frontend_services=>execute( document = lv_url
      EXCEPTIONS cntl_error = 1 OTHERS = 2 ).
    IF sy-subrc <> 0.
      MESSAGE 'Không mở được link tra cứu hoá đơn.' TYPE 'S' DISPLAY LIKE 'W'.
    ENDIF.

  ENDMETHOD.


  METHOD execute_action.

    DATA(lt_rows) = get_selected( ).
    IF lt_rows IS INITIAL.
      MESSAGE s002(zms_hddt) DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.

    " Nghiệp vụ ghi (phát hành/điều chỉnh/thay thế/huỷ) phải được xác
    " nhận: đây là hành động không thể thu hồi phía cơ quan thuế.
    IF p_test = abap_false
       AND ( i_action = zif_hddt_types=>gc_action-create_invoice
          OR i_action = zif_hddt_types=>gc_action-adjust_invoice
          OR i_action = zif_hddt_types=>gc_action-replace_invoice
          OR i_action = zif_hddt_types=>gc_action-cancel_invoice ).

      DATA lv_answer TYPE char1.
      CALL FUNCTION 'POPUP_TO_CONFIRM'
        EXPORTING
          titlebar              = 'Xác nhận gửi hoá đơn điện tử'
          text_question         = |Thực hiện "{ i_action }" cho { lines( lt_rows ) }| &&
                                  | chứng từ? Hành động này gửi dữ liệu lên cơ quan thuế| &&
                                  | và KHÔNG thể thu hồi.|
          text_button_1         = 'Thực hiện'
          text_button_2         = 'Huỷ'
          default_button        = '2'
          display_cancel_button = abap_false
        IMPORTING
          answer                = lv_answer
        EXCEPTIONS
          text_not_found        = 1
          OTHERS                = 2.
      IF lv_answer <> '1'.
        RETURN.
      ENDIF.
    ENDIF.

    LOOP AT lt_rows INTO DATA(lv_row).
      IF lv_row < 1 OR lv_row > lines( gt_request ).
        CONTINUE.
      ENDIF.

      DATA(ls_req) = gt_request[ lv_row ].
      ls_req-action = i_action.

      " Điều chỉnh / thay thế cần thông tin hoá đơn gốc từ sổ đăng ký
      IF i_action = zif_hddt_types=>gc_action-adjust_invoice
         OR i_action = zif_hddt_types=>gc_action-replace_invoice
         OR i_action = zif_hddt_types=>gc_action-cancel_invoice.
        PERFORM fill_original CHANGING ls_req.
      ENDIF.

      DATA(ls_result) = mo_service->execute( is_request  = ls_req
                                             i_test_run = p_test ).
      refresh_row( i_index  = lv_row
                   is_result = ls_result ).

      IF i_action = zif_hddt_types=>gc_action-get_file
         AND ls_result-file_content IS NOT INITIAL.
        PERFORM save_file USING ls_result-file_name ls_result-file_content.
      ENDIF.
    ENDLOOP.

    mo_alv->refresh( ).

  ENDMETHOD.


  METHOD refresh_row.

    IF i_index < 1 OR i_index > lines( gt_alv ).
      RETURN.
    ENDIF.

    ASSIGN gt_alv[ i_index ] TO FIELD-SYMBOL(<fs_alv>).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    <fs_alv>-msgty   = is_result-msgty.
    <fs_alv>-message = is_result-message.
    <fs_alv>-log_id  = is_result-log_id.
    IF is_result-status IS NOT INITIAL.
      <fs_alv>-status     = is_result-status.
      <fs_alv>-status_txt = status_text( is_result-status ).
    ENDIF.
    IF is_result-template IS NOT INITIAL.
      <fs_alv>-template = is_result-template.
    ENDIF.
    IF is_result-serial IS NOT INITIAL.
      <fs_alv>-serial = is_result-serial.
    ENDIF.
    IF is_result-seq IS NOT INITIAL.
      <fs_alv>-seq = is_result-seq.
    ENDIF.
    IF is_result-issue_date IS NOT INITIAL.
      <fs_alv>-issue_date = is_result-issue_date.
    ENDIF.
    IF is_result-mscqt IS NOT INITIAL.
      <fs_alv>-mscqt = is_result-mscqt.
    ENDIF.
    IF is_result-sec_code IS NOT INITIAL.
      <fs_alv>-sec_code = is_result-sec_code.
    ENDIF.
    IF is_result-inv_link IS NOT INITIAL.
      <fs_alv>-inv_link = is_result-inv_link.
    ENDIF.

    <fs_alv>-light = map_light( i_status = <fs_alv>-status
                                i_msgty  = <fs_alv>-msgty ).

  ENDMETHOD.


  METHOD show_payload.

    DATA(lt_rows) = get_selected( ).
    IF lt_rows IS INITIAL.
      MESSAGE s002(zms_hddt) DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.

    DATA(lv_row) = lt_rows[ 1 ].
    IF lv_row < 1 OR lv_row > lines( gt_request ).
      RETURN.
    ENDIF.

    DATA(ls_req) = gt_request[ lv_row ].
    IF ls_req-action IS INITIAL.
      ls_req-action = zif_hddt_types=>gc_action-create_invoice.
    ENDIF.

    " Test run => KHÔNG gọi API, chỉ dựng payload; mật khẩu được che
    DATA(ls_result) = mo_service->execute( is_request  = ls_req
                                           i_test_run = abap_true ).

    IF ls_result-request_body IS INITIAL.
      MESSAGE ls_result-message TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    PERFORM display_text USING 'Payload gửi nhà cung cấp'
                               ls_result-request_body.

  ENDMETHOD.


  METHOD show_log.

    DATA(lt_rows) = get_selected( ).
    IF lt_rows IS INITIAL.
      MESSAGE s002(zms_hddt) DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.

    DATA(lv_row) = lt_rows[ 1 ].
    IF lv_row < 1 OR lv_row > lines( gt_alv ).
      RETURN.
    ENDIF.

    DATA(ls_alv) = gt_alv[ lv_row ].

    SELECT log_id, created_at, action, http_code, http_reason,
           duration_ms, message, req_body, res_body
      FROM ztb_hddt_log
      INTO TABLE @DATA(lt_log)
      WHERE bukrs     = @ls_alv-bukrs
        AND gjahr     = @ls_alv-gjahr
        AND src_type  = @ls_alv-src_type
        AND src_docno = @ls_alv-src_docno
      ORDER BY created_at DESCENDING.
    IF sy-subrc <> 0.
      MESSAGE s003(zms_hddt) DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.

    DATA(ls_last) = lt_log[ 1 ].
    DATA(lv_text) = |=== REQUEST ({ ls_last-action }, HTTP { ls_last-http_code }| &&
                    |, { ls_last-duration_ms } ms) ===| &&
                    cl_abap_char_utilities=>newline && ls_last-req_body &&
                    cl_abap_char_utilities=>newline &&
                    |=== RESPONSE ===| &&
                    cl_abap_char_utilities=>newline && ls_last-res_body.

    PERFORM display_text USING 'Log gọi API' lv_text.

  ENDMETHOD.


  METHOD map_light.

    IF i_msgty = 'E' OR i_msgty = 'A'
       OR i_status = zif_hddt_types=>gc_status-error.
      r_icon = icon_red_light.
      RETURN.
    ENDIF.

    CASE i_status.
      WHEN zif_hddt_types=>gc_status-issued
        OR zif_hddt_types=>gc_status-coded
        OR zif_hddt_types=>gc_status-adjusted
        OR zif_hddt_types=>gc_status-replaced.
        r_icon = icon_green_light.
      WHEN zif_hddt_types=>gc_status-cancelled.
        r_icon = icon_red_light.
      WHEN zif_hddt_types=>gc_status-not_sent.
        r_icon = icon_light_out.
      WHEN OTHERS.
        r_icon = icon_yellow_light.
    ENDCASE.

  ENDMETHOD.


  METHOD status_text.

    " Lấy đúng nhãn đã khai trong domain ZDO_HDDT_STATUS để text
    " hiển thị luôn khớp với cấu hình, không hardcode ở đây.
    SELECT SINGLE ddtext FROM dd07t
      INTO @r_text
      WHERE domname    = 'ZDO_HDDT_STATUS'
        AND as4local   = 'A'
        AND ddlanguage = @sy-langu
        AND domvalue_l = @i_status.
    IF sy-subrc <> 0.
      SELECT SINGLE ddtext FROM dd07t
        INTO @r_text
        WHERE domname    = 'ZDO_HDDT_STATUS'
          AND as4local   = 'A'
          AND ddlanguage = 'E'
          AND domvalue_l = @i_status.
    ENDIF.

  ENDMETHOD.

ENDCLASS.

*&---------------------------------------------------------------------*
*& Form DISPLAY_TEXT
*&---------------------------------------------------------------------*
*& Hiển thị chuỗi dài trong ALV popup. Không dùng FM hiển thị chuỗi vì
*& không có sẵn ở mọi release; cắt thành dòng 250 ký tự là cách chắc
*& chắn chạy được trên mọi hệ SAP GUI.
*& --> I_TITLE  Tiêu đề popup
*& --> I_TEXT   Nội dung
*&---------------------------------------------------------------------*
FORM display_text USING i_title TYPE clike
                        i_text  TYPE string.

  TYPES: BEGIN OF lty_line,
           line_no TYPE i,
           line    TYPE c LENGTH 250,
         END OF lty_line.

  DATA lt_line TYPE STANDARD TABLE OF lty_line WITH EMPTY KEY.
  DATA lv_rest TYPE string.
  DATA lv_no   TYPE i.

  lv_rest = i_text.
  WHILE lv_rest IS NOT INITIAL.
    lv_no = lv_no + 1.
    APPEND VALUE #( line_no = lv_no
                    line    = lv_rest(250) ) TO lt_line.
    IF strlen( lv_rest ) <= 250.
      EXIT.
    ENDIF.
    SHIFT lv_rest LEFT BY 250 PLACES.
  ENDWHILE.

  IF lt_line IS INITIAL.
    RETURN.
  ENDIF.

  DATA lo_popup TYPE REF TO cl_salv_table.
  TRY.
      cl_salv_table=>factory( IMPORTING r_salv_table = lo_popup
                              CHANGING  t_table      = lt_line ).
      lo_popup->set_screen_popup( start_column = 5
                                  end_column   = 130
                                  start_line   = 2
                                  end_line     = 26 ).
      DATA lv_title TYPE lvc_title.
      lv_title = i_title.
      lo_popup->get_display_settings( )->set_list_header( lv_title ).
      lo_popup->get_columns( )->set_optimize( abap_true ).
      lo_popup->display( ).
    CATCH cx_salv_error INTO DATA(lx).
      MESSAGE lx->get_text( ) TYPE 'S' DISPLAY LIKE 'E'.
  ENDTRY.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form FILL_ORIGINAL
*&---------------------------------------------------------------------*
*& Điền thông tin hoá đơn GỐC (ký hiệu / số / ngày phát hành) vào
*& request khi lập hoá đơn điều chỉnh, thay thế hoặc huỷ.
*& Nguồn: sổ đăng ký ZTB_HDDT_INV — trường REF_DOCNO của chứng từ hiện
*& tại trỏ tới chứng từ gốc; nếu trống thì lấy chính chứng từ này.
*& <-> CS_REQUEST
*&---------------------------------------------------------------------*
FORM fill_original CHANGING cs_request TYPE zif_hddt_types=>ty_request.

  DATA(ls_self) = zcl_hddt_log=>read_invoice(
                    i_bukrs     = cs_request-bukrs
                    i_gjahr     = cs_request-gjahr
                    i_src_type  = cs_request-src_type
                    i_src_docno = cs_request-src_docno ).

  DATA(ls_org) = ls_self.

  " Điều chỉnh / thay thế mà sổ chưa biết chứng từ gốc -> hỏi người
  " dùng (như popup TYPE_DC/BELNR/GJAHR của dự án tham chiếu). Huỷ thì
  " chứng từ gốc là chính nó.
  IF ls_self-ref_docno IS INITIAL
     AND ( cs_request-action = zif_hddt_types=>gc_action-adjust_invoice
        OR cs_request-action = zif_hddt_types=>gc_action-replace_invoice ).
    PERFORM ask_original CHANGING ls_self-ref_docno ls_self-ref_gjahr.
    IF ls_self-ref_docno IS INITIAL.
      RETURN.                        " người dùng huỷ popup -> engine báo thiếu HĐ gốc
    ENDIF.
  ENDIF.

  " Chứng từ điều chỉnh có tham chiếu tới chứng từ gốc khác
  IF ls_self-ref_docno IS NOT INITIAL.
    DATA(ls_ref) = zcl_hddt_log=>read_invoice(
                     i_bukrs     = cs_request-bukrs
                     i_gjahr     = COND #( WHEN ls_self-ref_gjahr IS NOT INITIAL
                                            THEN ls_self-ref_gjahr
                                            ELSE cs_request-gjahr )
                     i_src_docno = ls_self-ref_docno ).
    IF ls_ref-serial IS NOT INITIAL OR ls_ref-seq IS NOT INITIAL.
      ls_org = ls_ref.
    ENDIF.
    " Chứng từ SAP của HĐ gốc -> engine kiểm tra trạng thái / đảo và
    " đổi trạng thái HĐ gốc sau khi phát hành thành công
    cs_request-invoice-adjust-org_docno    = ls_self-ref_docno.
    cs_request-invoice-adjust-org_gjahr    = COND #( WHEN ls_self-ref_gjahr IS NOT INITIAL
                                                     THEN ls_self-ref_gjahr
                                                     ELSE cs_request-gjahr ).
    cs_request-invoice-adjust-org_src_type = cs_request-src_type.
  ENDIF.

  cs_request-invoice-adjust-org_serial   = ls_org-serial.
  cs_request-invoice-adjust-org_seq      = ls_org-seq.
  cs_request-invoice-adjust-org_inv_date = COND #(
    WHEN ls_org-issue_date IS NOT INITIAL THEN ls_org-issue_date
    ELSE ls_org-inv_date ).
  cs_request-invoice-adjust-org_idkey    = ls_org-idkey.

  " Số / ngày hoá đơn của chính chứng từ này (dùng khi huỷ)
  IF cs_request-invoice-header-serial IS INITIAL.
    cs_request-invoice-header-serial = ls_self-serial.
  ENDIF.
  IF cs_request-invoice-header-seq IS INITIAL.
    cs_request-invoice-header-seq = ls_self-seq.
  ENDIF.
  IF cs_request-invoice-header-template IS INITIAL.
    cs_request-invoice-header-template = ls_self-template.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form ASK_ORIGINAL
*&---------------------------------------------------------------------*
*& Hỏi số chứng từ / năm của hoá đơn GỐC khi lập HĐ điều chỉnh, thay
*& thế (POPUP_GET_VALUES — như dự án tham chiếu). Chứng từ gốc phải đã
*& có trong sổ đăng ký; các điều kiện nghiệp vụ còn lại do engine kiểm.
*& <-> C_DOCNO  Số chứng từ gốc
*& <-> C_GJAHR  Năm chứng từ gốc
*&---------------------------------------------------------------------*
FORM ask_original CHANGING c_docno TYPE zde_hddt_docno
                           c_gjahr TYPE gjahr.

  DATA lt_fields TYPE STANDARD TABLE OF sval WITH EMPTY KEY.
  DATA lv_rc     TYPE c LENGTH 1.

  lt_fields = VALUE #( ( tabname = 'BKPF' fieldname = 'BELNR' fieldtext = 'Số chứng từ gốc' field_obl = 'X' )
                       ( tabname = 'BKPF' fieldname = 'GJAHR' fieldtext = 'Năm chứng từ gốc' field_obl = 'X'
                         value = p_gjahr ) ).

  CALL FUNCTION 'POPUP_GET_VALUES'
    EXPORTING
      popup_title     = 'Hoá đơn gốc cần điều chỉnh / thay thế'
      start_column    = '10'
      start_row       = '5'
    IMPORTING
      returncode      = lv_rc
    TABLES
      fields          = lt_fields
    EXCEPTIONS
      error_in_fields = 1
      OTHERS          = 2.
  IF sy-subrc <> 0 OR lv_rc = 'A'.
    CLEAR: c_docno, c_gjahr.
    RETURN.
  ENDIF.

  DATA lv_belnr TYPE belnr_d.
  LOOP AT lt_fields ASSIGNING FIELD-SYMBOL(<fs_f>).
    CASE <fs_f>-fieldname.
      WHEN 'BELNR'.
        " Chuyển về độ dài BELNR trước khi thêm số 0 đầu (ALPHA trên
        " SVAL-VALUE 132 ký tự sẽ đệm sai)
        lv_belnr = <fs_f>-value.
        lv_belnr = |{ lv_belnr ALPHA = IN }|.
        c_docno = lv_belnr.
      WHEN 'GJAHR'.
        c_gjahr = <fs_f>-value.
    ENDCASE.
  ENDLOOP.
  CONDENSE c_docno NO-GAPS.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form SAVE_FILE
*&---------------------------------------------------------------------*
*& Lưu file hoá đơn (PDF/XML) nhận từ nhà cung cấp xuống máy trạm.
*& --> I_NAME     Tên file gợi ý
*& --> I_CONTENT  Nội dung nhị phân
*&---------------------------------------------------------------------*
FORM save_file USING i_name    TYPE string
                     i_content TYPE xstring.

  DATA lt_bin TYPE STANDARD TABLE OF x255 WITH EMPTY KEY.
  DATA lv_len TYPE i.

  " Giá trị trả về của cl_gui_frontend_services phải nằm ở biến TOÀN CỤC
  " (gv_file_* trong _TOP) — quy ước chống SYSTEM_POINTER_PENDING
  CLEAR: gv_file_name, gv_file_path, gv_file_full, gv_file_action.

  IF i_content IS INITIAL.
    RETURN.
  ENDIF.

  gv_file_name = COND #( WHEN i_name IS INITIAL THEN 'einvoice.pdf' ELSE i_name ).

  cl_gui_frontend_services=>file_save_dialog(
    EXPORTING
      window_title      = 'Lưu file hoá đơn điện tử'
      default_file_name = gv_file_name
    CHANGING
      filename          = gv_file_name
      path              = gv_file_path
      fullpath          = gv_file_full
      user_action       = gv_file_action
    EXCEPTIONS
      OTHERS            = 1 ).
  IF sy-subrc <> 0
     OR gv_file_action <> cl_gui_frontend_services=>action_ok
     OR gv_file_full IS INITIAL.
    RETURN.
  ENDIF.

  CALL FUNCTION 'SCMS_XSTRING_TO_BINARY'
    EXPORTING
      buffer        = i_content
    IMPORTING
      output_length = lv_len
    TABLES
      binary_tab    = lt_bin.

  cl_gui_frontend_services=>gui_download(
    EXPORTING
      bin_filesize = lv_len
      filename     = gv_file_full
      filetype     = 'BIN'
    CHANGING
      data_tab     = lt_bin
    EXCEPTIONS
      OTHERS       = 1 ).
  IF sy-subrc <> 0.
    MESSAGE 'Không lưu được file hoá đơn.' TYPE 'S' DISPLAY LIKE 'E'.
  ELSE.
    MESSAGE |Đã lưu { gv_file_full }| TYPE 'S'.
  ENDIF.

ENDFORM.
