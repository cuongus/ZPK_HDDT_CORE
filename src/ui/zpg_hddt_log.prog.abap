*=====================================================================
* Tên/Mã     : ZPG_HDDT_LOG  (transaction ZFI003)
* Mô tả chung: Màn hình tra cứu LOG TÍCH HỢP hoá đơn điện tử. Trả lời
*              được 4 câu hỏi hay phải trả lời nhất khi có sự cố:
*                1. Chứng từ này đã gửi đi những lần nào, lúc nào, ai gửi?
*                2. JSON gửi đi có đúng không?  -> nút "Xem request"
*                3. Nhà cung cấp trả về gì?     -> nút "Xem response"
*                4. Header / xác thực có đúng không? -> nút "Xem header"
*
*              Payload trong bảng lưu dạng XSTRING (byte đã đi trên
*              đường truyền). Màn hình này giải mã lại theo trường
*              CODEPAGE của từng dòng rồi xuống dòng - thụt lề cho dễ
*              đọc, và cho phép tải nguyên bản xuống máy trạm để gửi
*              cho bộ phận hỗ trợ của nhà cung cấp.
*
*              Mật khẩu đã được che NGAY LÚC GHI (ZCL_HDDT_LOG), nên
*              màn hình này không thể làm lộ secret kể cả khi cấp quyền
*              rộng.
* Tham Số    : p_bukrs  - Mã công ty
*              p_gjahr  - Năm tài chính
*              s_docno  - Số chứng từ nguồn
*              s_date   - Ngày ghi log
*              s_prov   - Nhà cung cấp
*              s_action - Mã nghiệp vụ
*              s_code   - Mã HTTP
*              p_onlyer - Chỉ hiện dòng lỗi
*              p_test   - Kèm cả dòng Test run
*              p_max    - Số dòng tối đa
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       28/08/2026    cuongus - CuongUS        abapGit     Tạo mới
*=====================================================================
REPORT zpg_hddt_log MESSAGE-ID zms_hddt.

TYPE-POOLS icon.

*---------------------------------------------------------------------*
* Khai báo
*---------------------------------------------------------------------*
TYPES: BEGIN OF gty_log,
         light       TYPE c LENGTH 4,
         created_at  TYPE timestampl,
         bukrs       TYPE bukrs,
         gjahr       TYPE gjahr,
         src_type    TYPE zde_hddt_srctype,
         src_docno   TYPE zde_hddt_docno,
         action      TYPE zde_hddt_action,
         provider    TYPE zde_hddt_prov,
         connid      TYPE zde_hddt_connid,
         attempt     TYPE zde_hddt_attempt,
         test_run    TYPE xfeld,
         http_method TYPE zde_hddt_method,
         http_code   TYPE zde_hddt_size,
         http_reason TYPE zde_hddt_msg,
         duration_ms TYPE zde_hddt_size,
         serial      TYPE zde_hddt_serial,
         seq         TYPE zde_hddt_seq,
         sap_status  TYPE zde_hddt_status,
         prov_status TYPE zde_hddt_rccode,
         msgty       TYPE symsgty,
         message     TYPE zde_hddt_msg,
         req_size    TYPE zde_hddt_size,
         res_size    TYPE zde_hddt_size,
         masked      TYPE xfeld,
         cont_type   TYPE zde_hddt_parmval,
         full_url    TYPE zde_hddt_url,
         caller      TYPE zde_hddt_caller,
         tcode       TYPE tcode,
         created_by  TYPE syuname,
         log_id      TYPE zde_hddt_logid,
       END OF gty_log.

DATA gt_log TYPE STANDARD TABLE OF gty_log WITH EMPTY KEY.

DATA gv_docno    TYPE zde_hddt_docno.
DATA gv_date     TYPE dats.
DATA gv_provider TYPE zde_hddt_prov.
DATA gv_action   TYPE zde_hddt_action.
DATA gv_code     TYPE zde_hddt_size.

CONSTANTS: BEGIN OF gc_fcode,
             req    TYPE salv_de_function VALUE 'ZREQ',
             res    TYPE salv_de_function VALUE 'ZRES',
             hdr    TYPE salv_de_function VALUE 'ZHDR',
             export TYPE salv_de_function VALUE 'ZEXP',
           END OF gc_fcode.

*---------------------------------------------------------------------*
* Selection screen
*---------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-b01.
  PARAMETERS     p_bukrs TYPE bukrs.
  PARAMETERS     p_gjahr TYPE gjahr.
  SELECT-OPTIONS s_docno FOR gv_docno.
  SELECT-OPTIONS s_date  FOR gv_date DEFAULT sy-datum.
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-b02.
  SELECT-OPTIONS s_prov   FOR gv_provider.
  SELECT-OPTIONS s_action FOR gv_action.
  SELECT-OPTIONS s_code   FOR gv_code.
  PARAMETERS     p_onlyer AS CHECKBOX.
  PARAMETERS     p_test   AS CHECKBOX.
  PARAMETERS     p_max    TYPE i DEFAULT 500.
SELECTION-SCREEN END OF BLOCK b2.


*---------------------------------------------------------------------*
CLASS lcl_log DEFINITION FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS run.

    METHODS on_function
      FOR EVENT added_function OF cl_salv_events
      IMPORTING e_salv_function.

    METHODS on_double_click
      FOR EVENT double_click OF cl_salv_events_table
      IMPORTING row column.

  PRIVATE SECTION.
    DATA mo_alv TYPE REF TO cl_salv_table.

    METHODS select_data.
    METHODS build_alv.
    METHODS add_buttons.
    METHODS set_columns.
    METHODS selected_log
      RETURNING VALUE(r_log_id) TYPE zde_hddt_logid.
    METHODS show_part
      IMPORTING i_part TYPE salv_de_function.
    METHODS export_payload.
    METHODS map_light
      IMPORTING i_code        TYPE zde_hddt_size
                i_msgty       TYPE symsgty
      RETURNING VALUE(r_icon) TYPE c LENGTH 4.

ENDCLASS.


CLASS lcl_log IMPLEMENTATION.

  METHOD run.

    select_data( ).
    IF gt_log IS INITIAL.
      MESSAGE s003(zms_hddt) DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.
    build_alv( ).

  ENDMETHOD.


  METHOD select_data.

    CLEAR gt_log.

    " Khoảng ngày -> khoảng timestamp. CREATED_AT là TIMESTAMPL nên
    " không so trực tiếp với DATS được.
    DATA lv_from TYPE timestampl.
    DATA lv_to   TYPE timestampl.

    DATA lv_d_from TYPE dats VALUE '19700101'.
    DATA lv_d_to   TYPE dats VALUE '99991231'.

    " Đọc từng bước, không dùng COND với s_date[ 1 ]: bảng rỗng thì
    " truy cập chỉ số 1 sẽ raise CX_SY_ITAB_LINE_NOT_FOUND.
    IF s_date[] IS NOT INITIAL.
      READ TABLE s_date INDEX 1 INTO DATA(ls_date).
      IF sy-subrc = 0.
        lv_d_from = ls_date-low.
        lv_d_to   = COND #( WHEN ls_date-high IS NOT INITIAL
                            THEN ls_date-high ELSE ls_date-low ).
      ENDIF.
    ENDIF.

    CONVERT DATE lv_d_from TIME '000000' INTO TIME STAMP lv_from TIME ZONE sy-zonlo.
    CONVERT DATE lv_d_to   TIME '235959' INTO TIME STAMP lv_to   TIME ZONE sy-zonlo.

    DATA(lv_max) = COND i( WHEN p_max <= 0 THEN 500 ELSE p_max ).

    " Điều kiện tuỳ chọn phải đi qua RANGE: ABAP SQL không cho viết
    " "( bukrs = @p_bukrs OR @p_bukrs IS INITIAL )". Range rỗng = không lọc.
    DATA lr_bukrs TYPE RANGE OF bukrs.
    DATA lr_gjahr TYPE RANGE OF gjahr.
    IF p_bukrs IS NOT INITIAL.
      lr_bukrs = VALUE #( ( sign = 'I' option = 'EQ' low = p_bukrs ) ).
    ENDIF.
    IF p_gjahr IS NOT INITIAL.
      lr_gjahr = VALUE #( ( sign = 'I' option = 'EQ' low = p_gjahr ) ).
    ENDIF.

    " Không đọc REQ_BODY / RES_BODY ở đây: payload có thể vài trăm KB
    " mỗi dòng, đọc cả danh sách là vô ích. Chỉ đọc khi người dùng bấm
    " xem đúng một dòng (READ_PAYLOAD).
    SELECT log_id, created_at, bukrs, gjahr, src_type, src_docno,
           action, provider, connid, attempt, test_run,
           http_method, http_code, http_reason, duration_ms,
           serial, seq, sap_status, prov_status, msgty, message,
           req_size, res_size, masked, cont_type, full_url,
           caller, tcode, created_by
      FROM ztb_hddt_log
      WHERE created_at >= @lv_from
        AND created_at <= @lv_to
        AND bukrs      IN @lr_bukrs
        AND gjahr      IN @lr_gjahr
        AND src_docno  IN @s_docno
        AND provider   IN @s_prov
        AND action     IN @s_action
        AND http_code  IN @s_code
      ORDER BY created_at DESCENDING
      INTO CORRESPONDING FIELDS OF TABLE @gt_log
      UP TO @lv_max ROWS.

    IF p_test = abap_false.
      DELETE gt_log WHERE test_run = abap_true.
    ENDIF.

    IF p_onlyer = abap_true.
      DELETE gt_log WHERE msgty <> 'E' AND msgty <> 'A'
                      AND ( http_code >= 200 AND http_code < 300 ).
    ENDIF.

    LOOP AT gt_log ASSIGNING FIELD-SYMBOL(<fs_log>).
      <fs_log>-light = map_light( i_code  = <fs_log>-http_code
                                  i_msgty = <fs_log>-msgty ).
    ENDLOOP.

  ENDMETHOD.


  METHOD map_light.

    IF i_msgty = 'E' OR i_msgty = 'A'.
      r_icon = icon_red_light.
    ELSEIF i_code >= 200 AND i_code < 300.
      r_icon = icon_green_light.
    ELSEIF i_code = 0.
      r_icon = icon_light_out.
    ELSE.
      r_icon = icon_yellow_light.
    ENDIF.

  ENDMETHOD.


  METHOD build_alv.

    TRY.
        cl_salv_table=>factory( IMPORTING r_salv_table = mo_alv
                                CHANGING  t_table      = gt_log ).
      CATCH cx_salv_msg INTO DATA(lx).
        MESSAGE lx->get_text( ) TYPE 'S' DISPLAY LIKE 'E'.
        RETURN.
    ENDTRY.

    mo_alv->get_functions( )->set_all( abap_true ).
    add_buttons( ).
    set_columns( ).
    mo_alv->get_selections( )->set_selection_mode(
      if_salv_c_selection_mode=>row_column ).

    DATA lv_title TYPE lvc_title.
    lv_title = |Log tích hợp HĐĐT - { lines( gt_log ) } dòng|.
    mo_alv->get_display_settings( )->set_list_header( lv_title ).
    mo_alv->get_display_settings( )->set_striped_pattern( abap_true ).

    SET HANDLER me->on_function     FOR mo_alv->get_event( ).
    SET HANDLER me->on_double_click FOR mo_alv->get_event( ).

    mo_alv->display( ).

  ENDMETHOD.


  METHOD add_buttons.

    DATA(lo_fn) = mo_alv->get_functions( ).
    TRY.
        lo_fn->add_function( name     = gc_fcode-req
                             icon     = CONV #( icon_xml_doc )
                             text     = 'Xem request'
                             tooltip  = 'JSON / form đã gửi cho nhà cung cấp'
                             position = if_salv_c_function_position=>right_of_salv_functions ).
        lo_fn->add_function( name     = gc_fcode-res
                             icon     = CONV #( icon_display )
                             text     = 'Xem response'
                             tooltip  = 'Nội dung nhà cung cấp trả về'
                             position = if_salv_c_function_position=>right_of_salv_functions ).
        lo_fn->add_function( name     = gc_fcode-hdr
                             icon     = CONV #( icon_information )
                             text     = 'Xem header'
                             tooltip  = 'Header HTTP hai chiều (đã che secret)'
                             position = if_salv_c_function_position=>right_of_salv_functions ).
        lo_fn->add_function( name     = gc_fcode-export
                             icon     = CONV #( icon_export )
                             text     = 'Tải nguyên bản'
                             tooltip  = 'Lưu payload xuống máy trạm'
                             position = if_salv_c_function_position=>right_of_salv_functions ).
      CATCH cx_salv_wrong_call cx_salv_existing.
    ENDTRY.

  ENDMETHOD.


  METHOD set_columns.

    DATA(lo_cols) = mo_alv->get_columns( ).
    lo_cols->set_optimize( abap_true ).

    TRY.
        lo_cols->get_column( 'LIGHT' )->set_short_text( 'KQ' ).
        lo_cols->get_column( 'LIGHT' )->set_medium_text( 'Kết quả' ).
        lo_cols->get_column( 'LIGHT' )->set_long_text( 'Kết quả' ).
        CAST cl_salv_column_table( lo_cols->get_column( 'LIGHT' )
          )->set_icon( abap_true ).

        lo_cols->get_column( 'CREATED_AT' )->set_medium_text( 'Thời điểm' ).
        lo_cols->get_column( 'SRC_DOCNO' )->set_medium_text( 'Số chứng từ' ).
        lo_cols->get_column( 'ATTEMPT' )->set_medium_text( 'Lần thứ' ).
        lo_cols->get_column( 'DURATION_MS' )->set_medium_text( 'Thời gian (ms)' ).
        lo_cols->get_column( 'REQ_SIZE' )->set_medium_text( 'Request (byte)' ).
        lo_cols->get_column( 'RES_SIZE' )->set_medium_text( 'Response (byte)' ).
        lo_cols->get_column( 'MASKED' )->set_medium_text( 'Đã che secret' ).
        lo_cols->get_column( 'CALLER' )->set_medium_text( 'Chương trình gọi' ).

        lo_cols->get_column( 'LOG_ID' )->set_technical( abap_true ).
        lo_cols->get_column( 'FULL_URL' )->set_visible( abap_false ).
        lo_cols->get_column( 'CONT_TYPE' )->set_visible( abap_false ).
      CATCH cx_salv_not_found.
    ENDTRY.

  ENDMETHOD.


  METHOD selected_log.

    DATA(lt_rows) = mo_alv->get_selections( )->get_selected_rows( ).
    IF lt_rows IS INITIAL.
      MESSAGE s002(zms_hddt) DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.

    DATA(lv_row) = lt_rows[ 1 ].
    IF lv_row < 1 OR lv_row > lines( gt_log ).
      RETURN.
    ENDIF.
    r_log_id = gt_log[ lv_row ]-log_id.

  ENDMETHOD.


  METHOD on_double_click.

    " Nhấn đôi = xem request, việc hay làm nhất
    show_part( gc_fcode-req ).

  ENDMETHOD.


  METHOD on_function.

    CASE e_salv_function.
      WHEN gc_fcode-req OR gc_fcode-res OR gc_fcode-hdr.
        show_part( e_salv_function ).
      WHEN gc_fcode-export.
        export_payload( ).
      WHEN OTHERS.
    ENDCASE.

  ENDMETHOD.


  METHOD show_part.

    DATA(lv_log_id) = selected_log( ).
    IF lv_log_id IS INITIAL.
      RETURN.
    ENDIF.

    DATA(ls_pay) = zcl_hddt_log=>read_payload( lv_log_id ).

    DATA lv_text  TYPE string.
    DATA lv_title TYPE string.

    CASE i_part.
      WHEN gc_fcode-req.
        lv_text  = ls_pay-req_body.
        lv_title = 'Request đã gửi cho nhà cung cấp'.
      WHEN gc_fcode-res.
        lv_text  = ls_pay-res_body.
        lv_title = 'Response của nhà cung cấp'.
      WHEN gc_fcode-hdr.
        lv_text  = |=== REQUEST HEADER ===| && cl_abap_char_utilities=>newline
                && ls_pay-req_header && cl_abap_char_utilities=>newline
                && cl_abap_char_utilities=>newline
                && |=== RESPONSE HEADER ===| && cl_abap_char_utilities=>newline
                && ls_pay-res_header.
        lv_title = 'Header HTTP (secret đã được che)'.
    ENDCASE.

    IF lv_text IS INITIAL.
      MESSAGE 'Dòng log này không lưu nội dung (tham số LOG_PAYLOAD đang tắt).'
              TYPE 'S' DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.

    " JSON thì xuống dòng + thụt lề cho đọc được; dạng khác giữ nguyên
    DATA lt_line TYPE string_table.
    DATA(lv_first) = |{ lv_text }|.
    CONDENSE lv_first.
    IF strlen( lv_first ) > 0
       AND ( substring( val = lv_first len = 1 ) = `{`
          OR substring( val = lv_first len = 1 ) = `[` ).
      lt_line = zcl_hddt_json=>pretty( lv_text ).
    ELSE.
      SPLIT lv_text AT cl_abap_char_utilities=>newline INTO TABLE lt_line.
    ENDIF.

    PERFORM show_lines USING lv_title lt_line.

  ENDMETHOD.


  METHOD export_payload.

    DATA(lv_log_id) = selected_log( ).
    IF lv_log_id IS INITIAL.
      RETURN.
    ENDIF.

    " Tải NGUYÊN BẢN byte trong bảng, không giải mã — để gửi cho bộ
    " phận hỗ trợ của nhà cung cấp đúng thứ đã đi trên đường truyền.
    SELECT SINGLE req_body, res_body, action, src_docno
      FROM ztb_hddt_log
      WHERE log_id = @lv_log_id
      INTO @DATA(ls_db).
    IF sy-subrc <> 0 OR ls_db-req_body IS INITIAL.
      MESSAGE 'Dòng log này không có nội dung để tải.' TYPE 'S' DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.

    " PERFORM ... USING chỉ nhận TÊN BIẾN, không nhận biểu thức
    DATA(lv_fn_req) = |{ ls_db-src_docno }_{ ls_db-action }_request.json|.
    PERFORM save_raw USING lv_fn_req
                           ls_db-req_body.
    IF ls_db-res_body IS NOT INITIAL.
      DATA(lv_fn_res) = |{ ls_db-src_docno }_{ ls_db-action }_response.json|.
      PERFORM save_raw USING lv_fn_res
                             ls_db-res_body.
    ENDIF.

  ENDMETHOD.

ENDCLASS.


*---------------------------------------------------------------------*
* Sự kiện
*---------------------------------------------------------------------*
START-OF-SELECTION.
  DATA(go_app) = NEW lcl_log( ).
  go_app->run( ).


*&---------------------------------------------------------------------*
*& Form SHOW_LINES — hiển thị danh sách dòng text trong ALV popup
*&---------------------------------------------------------------------*
FORM show_lines USING i_title TYPE string
                      it_line  TYPE string_table.

  TYPES: BEGIN OF lty_row,
           no   TYPE i,
           line TYPE c LENGTH 250,
         END OF lty_row.

  DATA lt_row TYPE STANDARD TABLE OF lty_row WITH EMPTY KEY.
  DATA lv_no  TYPE i.

  LOOP AT it_line INTO DATA(lv_line).
    lv_no = lv_no + 1.
    APPEND VALUE #( no = lv_no line = lv_line ) TO lt_row.
  ENDLOOP.

  IF lt_row IS INITIAL.
    RETURN.
  ENDIF.

  DATA lo_popup TYPE REF TO cl_salv_table.
  TRY.
      cl_salv_table=>factory( IMPORTING r_salv_table = lo_popup
                              CHANGING  t_table      = lt_row ).
      lo_popup->set_screen_popup( start_column = 3
                                  end_column   = 140
                                  start_line   = 2
                                  end_line     = 28 ).
      DATA lv_t TYPE lvc_title.
      lv_t = i_title.
      lo_popup->get_display_settings( )->set_list_header( lv_t ).
      lo_popup->get_columns( )->set_optimize( abap_true ).
      lo_popup->get_functions( )->set_all( abap_true ).
      lo_popup->display( ).
    CATCH cx_salv_error INTO DATA(lx).
      MESSAGE lx->get_text( ) TYPE 'S' DISPLAY LIKE 'E'.
  ENDTRY.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form SAVE_RAW — lưu xstring xuống máy trạm
*&---------------------------------------------------------------------*
FORM save_raw USING i_name TYPE string
                    i_data TYPE xstring.

  DATA lt_bin      TYPE STANDARD TABLE OF x255 WITH EMPTY KEY.
  DATA lv_len      TYPE i.
  DATA lv_path     TYPE string.
  DATA lv_fullpath TYPE string.
  DATA lv_filename TYPE string.
  DATA lv_action   TYPE i.

  lv_filename = i_name.

  cl_gui_frontend_services=>file_save_dialog(
    EXPORTING
      window_title      = 'Lưu payload log HĐĐT'
      default_file_name = lv_filename
      default_extension = 'json'
    CHANGING
      filename          = lv_filename
      path              = lv_path
      fullpath          = lv_fullpath
      user_action       = lv_action
    EXCEPTIONS
      OTHERS            = 1 ).
  IF sy-subrc <> 0
     OR lv_action <> cl_gui_frontend_services=>action_ok
     OR lv_fullpath IS INITIAL.
    RETURN.
  ENDIF.

  CALL FUNCTION 'SCMS_XSTRING_TO_BINARY'
    EXPORTING
      buffer        = i_data
    IMPORTING
      output_length = lv_len
    TABLES
      binary_tab    = lt_bin.

  cl_gui_frontend_services=>gui_download(
    EXPORTING
      bin_filesize = lv_len
      filename     = lv_fullpath
      filetype     = 'BIN'
    CHANGING
      data_tab     = lt_bin
    EXCEPTIONS
      OTHERS       = 1 ).
  IF sy-subrc <> 0.
    MESSAGE 'Không lưu được file.' TYPE 'S' DISPLAY LIKE 'E'.
  ELSE.
    MESSAGE |Đã lưu { lv_fullpath }| TYPE 'S'.
  ENDIF.

ENDFORM.
