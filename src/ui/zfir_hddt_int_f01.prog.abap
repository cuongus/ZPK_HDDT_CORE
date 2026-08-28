*=====================================================================
* Tên/Mã     : ZFIR_HDDT_INT_F01
* Mô tả chung: Form routine hỗ trợ màn hình cho ZFIR_HDDT_INTEGRATION:
*              hiển thị chuỗi dài (payload / log), lấy thông tin hoá
*              đơn gốc khi điều chỉnh - thay thế - huỷ, và lưu file
*              hoá đơn xuống máy trạm.
* Tham Số    : Xem từng FORM
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       28/08/2026    cuongus - CuongUS        abapGit     Tạo mới
*=====================================================================

*&---------------------------------------------------------------------*
*& Form DISPLAY_TEXT
*&---------------------------------------------------------------------*
*& Hiển thị chuỗi dài trong ALV popup. Không dùng FM hiển thị chuỗi vì
*& không có sẵn ở mọi release; cắt thành dòng 250 ký tự là cách chắc
*& chắn chạy được trên mọi hệ SAP GUI.
*& --> IV_TITLE  Tiêu đề popup
*& --> IV_TEXT   Nội dung
*&---------------------------------------------------------------------*
FORM display_text USING iv_title TYPE clike
                        iv_text  TYPE string.

  TYPES: BEGIN OF lty_line,
           line_no TYPE i,
           line    TYPE c LENGTH 250,
         END OF lty_line.

  DATA lt_line TYPE STANDARD TABLE OF lty_line WITH EMPTY KEY.
  DATA lv_rest TYPE string.
  DATA lv_no   TYPE i.

  lv_rest = iv_text.
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
      lv_title = iv_title.
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
*& Nguồn: sổ đăng ký ZFIT_HDDT_INV — trường REF_DOCNO của chứng từ hiện
*& tại trỏ tới chứng từ gốc; nếu trống thì lấy chính chứng từ này.
*& <-> CS_REQUEST
*&---------------------------------------------------------------------*
FORM fill_original CHANGING cs_request TYPE zfiif_hddt_types=>ty_request.

  DATA(ls_self) = zfic_hddt_log=>read_invoice(
                    iv_bukrs     = cs_request-bukrs
                    iv_gjahr     = cs_request-gjahr
                    iv_src_type  = cs_request-src_type
                    iv_src_docno = cs_request-src_docno ).

  DATA(ls_org) = ls_self.

  " Chứng từ điều chỉnh có tham chiếu tới chứng từ gốc khác
  IF ls_self-ref_docno IS NOT INITIAL.
    DATA(ls_ref) = zfic_hddt_log=>read_invoice(
                     iv_bukrs     = cs_request-bukrs
                     iv_gjahr     = COND #( WHEN ls_self-ref_gjahr IS NOT INITIAL
                                            THEN ls_self-ref_gjahr
                                            ELSE cs_request-gjahr )
                     iv_src_docno = ls_self-ref_docno ).
    IF ls_ref-serial IS NOT INITIAL OR ls_ref-seq IS NOT INITIAL.
      ls_org = ls_ref.
    ENDIF.
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
*& Form SAVE_FILE
*&---------------------------------------------------------------------*
*& Lưu file hoá đơn (PDF/XML) nhận từ nhà cung cấp xuống máy trạm.
*& --> IV_NAME     Tên file gợi ý
*& --> IV_CONTENT  Nội dung nhị phân
*&---------------------------------------------------------------------*
FORM save_file USING iv_name    TYPE string
                     iv_content TYPE xstring.

  DATA lt_bin      TYPE STANDARD TABLE OF x255 WITH EMPTY KEY.
  DATA lv_len      TYPE i.
  DATA lv_path     TYPE string.
  DATA lv_fullpath TYPE string.
  DATA lv_filename TYPE string.
  DATA lv_action   TYPE i.

  IF iv_content IS INITIAL.
    RETURN.
  ENDIF.

  lv_filename = COND #( WHEN iv_name IS INITIAL THEN 'einvoice.pdf' ELSE iv_name ).

  cl_gui_frontend_services=>file_save_dialog(
    EXPORTING
      window_title      = 'Lưu file hoá đơn điện tử'
      default_file_name = lv_filename
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
      buffer        = iv_content
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
    MESSAGE 'Không lưu được file hoá đơn.' TYPE 'S' DISPLAY LIKE 'E'.
  ELSE.
    MESSAGE |Đã lưu { lv_fullpath }| TYPE 'S'.
  ENDIF.

ENDFORM.
