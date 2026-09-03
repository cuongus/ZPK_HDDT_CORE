*=====================================================================
* Tên/Mã     : ZFIR_HDDT_INT_CL1
* Mô tả chung: Lớp local điều khiển màn hình ALV của
*              ZFIR_HDDT_INTEGRATION. Toàn bộ nghiệp vụ HĐĐT được uỷ
*              quyền cho ZFIC_HDDT_SERVICE — lớp này chỉ lo màn hình.
* Tham Số    : Không có
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       28/08/2026    cuongus - CuongUS        abapGit     Tạo mới
* 1.1       03/09/2026    cuongus - CuongUS        abapGit     Range mới,
*                         cột đảo/billing/HĐ gốc, chọn HĐ gốc khi ĐC/TT
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
    DATA mo_service TYPE REF TO zfic_hddt_service.

    METHODS select_data.
    METHODS build_alv.
    METHODS add_buttons.
    METHODS set_columns.
    METHODS refresh_row
      IMPORTING iv_index  TYPE i
                is_result TYPE zfiif_hddt_types=>ty_result.
    METHODS get_selected
      RETURNING VALUE(rt_index) TYPE salv_t_row.
    METHODS execute_action
      IMPORTING iv_action TYPE zfide_hddt_action.
    METHODS show_payload.
    METHODS show_log.
    METHODS map_light
      IMPORTING iv_status      TYPE zfide_hddt_status
                iv_msgty       TYPE symsgty
      RETURNING VALUE(rv_icon) TYPE c LENGTH 4.
    METHODS status_text
      IMPORTING iv_status      TYPE zfide_hddt_status
      RETURNING VALUE(rv_text) TYPE c LENGTH 60.

ENDCLASS.


CLASS lcl_app IMPLEMENTATION.

  METHOD run.

    mo_service = zfic_hddt_service=>get_instance( ).

    select_data( ).
    IF gt_alv IS INITIAL.
      MESSAGE s001(zfie_hddt) DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.

    build_alv( ).

  ENDMETHOD.


  METHOD select_data.

    CLEAR: gt_alv, gt_request.

    TRY.
        DATA(lo_source) = zfic_hddt_factory=>get_source( iv_bukrs    = p_bukrs
                                                         iv_src_type = p_srct ).

        DATA(ls_sel) = VALUE zfiif_hddt_source=>ty_selection(
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

      CATCH zficx_hddt_error INTO DATA(lx).
        MESSAGE lx->get_text_long( ) TYPE 'S' DISPLAY LIKE 'E'.
        RETURN.
    ENDTRY.

    " Ghép trạng thái đã lưu trong sổ đăng ký vào danh sách hiển thị
    SELECT * FROM zfit_hddt_inv
      INTO TABLE @DATA(lt_reg)
      WHERE bukrs = @p_bukrs
        AND gjahr = @p_gjahr.

    LOOP AT gt_request ASSIGNING FIELD-SYMBOL(<ls_req>).
      IF p_prov IS NOT INITIAL.
        <ls_req>-provider = p_prov.
      ENDIF.

      APPEND INITIAL LINE TO gt_alv ASSIGNING FIELD-SYMBOL(<ls_alv>).
      <ls_alv>-bukrs      = <ls_req>-bukrs.
      <ls_alv>-gjahr      = <ls_req>-gjahr.
      <ls_alv>-src_type   = <ls_req>-src_type.
      <ls_alv>-src_docno  = <ls_req>-src_docno.
      <ls_alv>-blart      = <ls_req>-src_info-blart.
      <ls_alv>-budat      = <ls_req>-src_info-budat.
      <ls_alv>-bldat      = <ls_req>-src_info-bldat.
      <ls_alv>-awkey      = <ls_req>-src_info-awkey.
      <ls_alv>-inv_date   = <ls_req>-invoice-header-inv_date.
      IF <ls_req>-src_info-xreversed = abap_true
         OR <ls_req>-src_info-xcancel = abap_true.
        <ls_alv>-reversed = icon_storno.
      ENDIF.
      READ TABLE <ls_req>-invoice-ext INTO DATA(ls_ext)
           WITH KEY name = 'TAX_RATE_SUMMARY'.
      IF sy-subrc = 0.
        <ls_alv>-tax_summ = ls_ext-value.
      ENDIF.
      <ls_alv>-buyer_code = <ls_req>-invoice-buyer-code.
      <ls_alv>-buyer_name = <ls_req>-invoice-buyer-legal_name.
      <ls_alv>-buyer_tax  = <ls_req>-invoice-buyer-tax_code.
      <ls_alv>-waers      = <ls_req>-invoice-header-currency.
      <ls_alv>-amount     = <ls_req>-invoice-summary-amount_wo_tax.
      <ls_alv>-vat_amount = <ls_req>-invoice-summary-tax_amount.
      <ls_alv>-total      = <ls_req>-invoice-summary-total.
      <ls_alv>-provider   = <ls_req>-provider.
      <ls_alv>-inv_type   = <ls_req>-invoice-header-inv_type.

      TRY.
          DATA(ls_reg) = lt_reg[ bukrs     = <ls_req>-bukrs
                                 gjahr     = <ls_req>-gjahr
                                 src_type  = <ls_req>-src_type
                                 src_docno = <ls_req>-src_docno ].
          <ls_alv>-provider   = ls_reg-provider.
          <ls_alv>-template   = ls_reg-template.
          <ls_alv>-serial     = ls_reg-serial.
          <ls_alv>-seq        = ls_reg-seq.
          <ls_alv>-issue_date = ls_reg-issue_date.
          <ls_alv>-mscqt      = ls_reg-mscqt.
          <ls_alv>-sec_code   = ls_reg-sec_code.
          <ls_alv>-inv_link   = ls_reg-inv_link.
          <ls_alv>-status     = ls_reg-status.
          <ls_alv>-message    = ls_reg-message.
          <ls_alv>-ref_docno  = ls_reg-ref_docno.
        CATCH cx_sy_itab_line_not_found.
          <ls_alv>-status = zfiif_hddt_types=>gc_status-not_sent.
      ENDTRY.

      <ls_alv>-status_txt = status_text( <ls_alv>-status ).
      <ls_alv>-light      = map_light( iv_status = <ls_alv>-status
                                       iv_msgty  = <ls_alv>-msgty ).
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
        execute_action( zfiif_hddt_types=>gc_action-create_invoice ).
      WHEN gc_fcode-adjust.
        execute_action( zfiif_hddt_types=>gc_action-adjust_invoice ).
      WHEN gc_fcode-replace.
        execute_action( zfiif_hddt_types=>gc_action-replace_invoice ).
      WHEN gc_fcode-cancel.
        execute_action( zfiif_hddt_types=>gc_action-cancel_invoice ).
      WHEN gc_fcode-search.
        execute_action( zfiif_hddt_types=>gc_action-search_invoice ).
      WHEN gc_fcode-getfile.
        execute_action( zfiif_hddt_types=>gc_action-get_file ).
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
      MESSAGE s002(zfie_hddt) DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.

    " Nghiệp vụ ghi (phát hành/điều chỉnh/thay thế/huỷ) phải được xác
    " nhận: đây là hành động không thể thu hồi phía cơ quan thuế.
    IF p_test = abap_false
       AND ( iv_action = zfiif_hddt_types=>gc_action-create_invoice
          OR iv_action = zfiif_hddt_types=>gc_action-adjust_invoice
          OR iv_action = zfiif_hddt_types=>gc_action-replace_invoice
          OR iv_action = zfiif_hddt_types=>gc_action-cancel_invoice ).

      DATA lv_answer TYPE char1.
      CALL FUNCTION 'POPUP_TO_CONFIRM'
        EXPORTING
          titlebar              = 'Xác nhận gửi hoá đơn điện tử'
          text_question         = |Thực hiện "{ iv_action }" cho { lines( lt_rows ) }| &&
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
      ls_req-action = iv_action.

      " Điều chỉnh / thay thế cần thông tin hoá đơn gốc từ sổ đăng ký
      IF iv_action = zfiif_hddt_types=>gc_action-adjust_invoice
         OR iv_action = zfiif_hddt_types=>gc_action-replace_invoice
         OR iv_action = zfiif_hddt_types=>gc_action-cancel_invoice.
        PERFORM fill_original CHANGING ls_req.
      ENDIF.

      DATA(ls_result) = mo_service->execute( is_request  = ls_req
                                             iv_test_run = p_test ).
      refresh_row( iv_index  = lv_row
                   is_result = ls_result ).

      IF iv_action = zfiif_hddt_types=>gc_action-get_file
         AND ls_result-file_content IS NOT INITIAL.
        PERFORM save_file USING ls_result-file_name ls_result-file_content.
      ENDIF.
    ENDLOOP.

    mo_alv->refresh( ).

  ENDMETHOD.


  METHOD refresh_row.

    IF iv_index < 1 OR iv_index > lines( gt_alv ).
      RETURN.
    ENDIF.

    ASSIGN gt_alv[ iv_index ] TO FIELD-SYMBOL(<ls_alv>).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    <ls_alv>-msgty   = is_result-msgty.
    <ls_alv>-message = is_result-message.
    <ls_alv>-log_id  = is_result-log_id.
    IF is_result-status IS NOT INITIAL.
      <ls_alv>-status     = is_result-status.
      <ls_alv>-status_txt = status_text( is_result-status ).
    ENDIF.
    IF is_result-template IS NOT INITIAL.
      <ls_alv>-template = is_result-template.
    ENDIF.
    IF is_result-serial IS NOT INITIAL.
      <ls_alv>-serial = is_result-serial.
    ENDIF.
    IF is_result-seq IS NOT INITIAL.
      <ls_alv>-seq = is_result-seq.
    ENDIF.
    IF is_result-issue_date IS NOT INITIAL.
      <ls_alv>-issue_date = is_result-issue_date.
    ENDIF.
    IF is_result-mscqt IS NOT INITIAL.
      <ls_alv>-mscqt = is_result-mscqt.
    ENDIF.
    IF is_result-sec_code IS NOT INITIAL.
      <ls_alv>-sec_code = is_result-sec_code.
    ENDIF.
    IF is_result-inv_link IS NOT INITIAL.
      <ls_alv>-inv_link = is_result-inv_link.
    ENDIF.

    <ls_alv>-light = map_light( iv_status = <ls_alv>-status
                                iv_msgty  = <ls_alv>-msgty ).

  ENDMETHOD.


  METHOD show_payload.

    DATA(lt_rows) = get_selected( ).
    IF lt_rows IS INITIAL.
      MESSAGE s002(zfie_hddt) DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.

    DATA(lv_row) = lt_rows[ 1 ].
    IF lv_row < 1 OR lv_row > lines( gt_request ).
      RETURN.
    ENDIF.

    DATA(ls_req) = gt_request[ lv_row ].
    IF ls_req-action IS INITIAL.
      ls_req-action = zfiif_hddt_types=>gc_action-create_invoice.
    ENDIF.

    " Test run => KHÔNG gọi API, chỉ dựng payload; mật khẩu được che
    DATA(ls_result) = mo_service->execute( is_request  = ls_req
                                           iv_test_run = abap_true ).

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
      MESSAGE s002(zfie_hddt) DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.

    DATA(lv_row) = lt_rows[ 1 ].
    IF lv_row < 1 OR lv_row > lines( gt_alv ).
      RETURN.
    ENDIF.

    DATA(ls_alv) = gt_alv[ lv_row ].

    SELECT log_id, created_at, action, http_code, http_reason,
           duration_ms, message, req_body, res_body
      FROM zfit_hddt_log
      INTO TABLE @DATA(lt_log)
      WHERE bukrs     = @ls_alv-bukrs
        AND gjahr     = @ls_alv-gjahr
        AND src_type  = @ls_alv-src_type
        AND src_docno = @ls_alv-src_docno
      ORDER BY created_at DESCENDING.
    IF sy-subrc <> 0.
      MESSAGE s003(zfie_hddt) DISPLAY LIKE 'W'.
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

    IF iv_msgty = 'E' OR iv_msgty = 'A'
       OR iv_status = zfiif_hddt_types=>gc_status-error.
      rv_icon = icon_red_light.
      RETURN.
    ENDIF.

    CASE iv_status.
      WHEN zfiif_hddt_types=>gc_status-issued
        OR zfiif_hddt_types=>gc_status-coded
        OR zfiif_hddt_types=>gc_status-adjusted
        OR zfiif_hddt_types=>gc_status-replaced.
        rv_icon = icon_green_light.
      WHEN zfiif_hddt_types=>gc_status-cancelled.
        rv_icon = icon_red_light.
      WHEN zfiif_hddt_types=>gc_status-not_sent.
        rv_icon = icon_light_out.
      WHEN OTHERS.
        rv_icon = icon_yellow_light.
    ENDCASE.

  ENDMETHOD.


  METHOD status_text.

    " Lấy đúng nhãn đã khai trong domain ZFIDO_HDDT_STATUS để text
    " hiển thị luôn khớp với cấu hình, không hardcode ở đây.
    SELECT SINGLE ddtext FROM dd07t
      INTO @rv_text
      WHERE domname    = 'ZFIDO_HDDT_STATUS'
        AND as4local   = 'A'
        AND ddlanguage = @sy-langu
        AND domvalue_l = @iv_status.
    IF sy-subrc <> 0.
      SELECT SINGLE ddtext FROM dd07t
        INTO @rv_text
        WHERE domname    = 'ZFIDO_HDDT_STATUS'
          AND as4local   = 'A'
          AND ddlanguage = 'E'
          AND domvalue_l = @iv_status.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
