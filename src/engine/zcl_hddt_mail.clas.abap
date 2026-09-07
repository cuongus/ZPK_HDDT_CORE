*=====================================================================
* Tên/Mã     : ZCL_HDDT_MAIL
* Mô tả chung: Gửi email hoá đơn (file PDF lấy từ NCC) cho khách hàng
*              theo FS MAG v0.5 mục 3.6.6:
*                - hoá đơn NHÁP (trạng thái 20): tiêu đề/nội dung phải
*                  nêu rõ là MẪU HOÁ ĐƠN NHÁP chưa có giá trị pháp lý;
*                - hoá đơn đã được CQT cấp mã (trạng thái 50): gửi
*                  hoá đơn chính thức;
*                - trạng thái khác: lỗi "Hoá đơn chưa được CQT chấp nhận"
*                  (danh sách trạng thái cho phép: MAIL_ALLOWED_STATUS).
*              Tiêu đề / nội dung lấy từ tham số MAIL_SUBJECT_* /
*              MAIL_BODY_* với placeholder {SERIAL} {SEQ} {BUYER}
*              {DOCNO} {DATE} {COMPANY}. Người gửi: MAIL_SENDER (email)
*              hoặc user đăng nhập. Nhiều địa chỉ cách nhau ';'.
*              Tầng nền tảng cổ điển (CL_BCS).
* Tham Số    : SEND_INVOICE( is_request is_reg i_pdf i_file_name )
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       07/09/2026    cuongus - CuongUS        abapGit     Tạo mới
*=====================================================================
CLASS zcl_hddt_mail DEFINITION
  PUBLIC
  CREATE PUBLIC .

  PUBLIC SECTION.

    "! Gửi email; kết quả trả về dạng ty_result (success/message).
    METHODS send_invoice
      IMPORTING is_request       TYPE zif_hddt_types=>ty_request
                is_reg           TYPE ztb_hddt_inv
                i_pdf            TYPE xstring
                i_file_name      TYPE string OPTIONAL
      RETURNING VALUE(rs_result) TYPE zif_hddt_types=>ty_result .

    "! Trạng thái có được gửi email không (theo MAIL_ALLOWED_STATUS)
    METHODS is_allowed
      IMPORTING i_bukrs          TYPE bukrs
                i_status         TYPE zde_hddt_status
      RETURNING VALUE(r_allowed) TYPE abap_bool .

  PROTECTED SECTION.
  PRIVATE SECTION.

    METHODS render
      IMPORTING i_template    TYPE string
                is_request    TYPE zif_hddt_types=>ty_request
                is_reg        TYPE ztb_hddt_inv
      RETURNING VALUE(r_text) TYPE string .

    METHODS param
      IMPORTING i_key          TYPE zde_hddt_parmkey
                i_bukrs        TYPE bukrs
                i_default      TYPE string OPTIONAL
      RETURNING VALUE(r_value) TYPE string .

ENDCLASS.



CLASS zcl_hddt_mail IMPLEMENTATION.

  METHOD param.

    r_value = zcl_hddt_config=>get_instance( )->get_param( i_key   = i_key
                                                           i_bukrs = i_bukrs ).
    IF r_value IS INITIAL.
      r_value = i_default.
    ENDIF.

  ENDMETHOD.


  METHOD is_allowed.

    DATA(lv_list) = param( i_key     = zif_hddt_types=>gc_parm-mail_allowed
                           i_bukrs   = i_bukrs
                           i_default = |{ zif_hddt_types=>gc_status-wait_seq },{ zif_hddt_types=>gc_status-coded }| ).
    SPLIT lv_list AT ',' INTO TABLE DATA(lt_st).
    LOOP AT lt_st ASSIGNING FIELD-SYMBOL(<fs_st>).
      CONDENSE <fs_st> NO-GAPS.
      IF <fs_st> = i_status.
        r_allowed = abap_true.
        RETURN.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD render.

    r_text = i_template.
    REPLACE ALL OCCURRENCES OF '{SERIAL}'  IN r_text WITH |{ is_reg-serial }|.
    REPLACE ALL OCCURRENCES OF '{SEQ}'     IN r_text WITH |{ is_reg-seq }|.
    REPLACE ALL OCCURRENCES OF '{BUYER}'   IN r_text WITH |{ is_request-invoice-buyer-legal_name }|.
    REPLACE ALL OCCURRENCES OF '{DOCNO}'   IN r_text WITH |{ is_request-src_docno ALPHA = OUT }|.
    REPLACE ALL OCCURRENCES OF '{DATE}'    IN r_text WITH |{ is_request-invoice-header-inv_date DATE = USER }|.
    REPLACE ALL OCCURRENCES OF '{COMPANY}' IN r_text WITH |{ is_request-invoice-seller-name }|.
    REPLACE ALL OCCURRENCES OF '\n' IN r_text WITH cl_abap_char_utilities=>cr_lf.

  ENDMETHOD.


  METHOD send_invoice.

    DATA(lv_bukrs) = is_request-bukrs.
    rs_result-status = is_reg-status.

    IF is_allowed( i_bukrs = lv_bukrs i_status = is_reg-status ) = abap_false.
      rs_result-msgty   = 'E'.
      rs_result-message = 'Hoá đơn chưa được Cơ quan thuế chấp nhận'.
      RETURN.
    ENDIF.

    DATA(lv_to) = is_request-invoice-buyer-email.
    IF lv_to IS INITIAL.
      lv_to = is_reg-buyer_mail.
    ENDIF.
    IF lv_to IS INITIAL.
      rs_result-msgty   = 'E'.
      rs_result-message = 'Khách hàng chưa có địa chỉ email'.
      RETURN.
    ENDIF.

    IF i_pdf IS INITIAL.
      rs_result-msgty   = 'E'.
      rs_result-message = 'Chưa lấy được file PDF hoá đơn từ nhà cung cấp'.
      RETURN.
    ENDIF.

    DATA(lv_draft) = xsdbool( is_reg-status = zif_hddt_types=>gc_status-wait_seq
                           OR is_reg-status = zif_hddt_types=>gc_status-wait_appr ).

    DATA(lv_subject) = render(
      i_template = COND #( WHEN lv_draft = abap_true
        THEN param( i_key = zif_hddt_types=>gc_parm-mail_subj_draft i_bukrs = lv_bukrs
                    i_default = `[MẪU HOÁ ĐƠN NHÁP - chưa có giá trị pháp lý] Chứng từ {DOCNO} - {COMPANY}` )
        ELSE param( i_key = zif_hddt_types=>gc_parm-mail_subj_final i_bukrs = lv_bukrs
                    i_default = `Hoá đơn điện tử {SERIAL} {SEQ} - {COMPANY}` ) )
      is_request = is_request
      is_reg     = is_reg ).

    DATA(lv_body) = render(
      i_template = COND #( WHEN lv_draft = abap_true
        THEN param( i_key = zif_hddt_types=>gc_parm-mail_body_draft i_bukrs = lv_bukrs
                    i_default = `Kính gửi {BUYER},\n\nĐây là MẪU HOÁ ĐƠN NHÁP (chưa cấp số, chưa có giá trị pháp lý) ` &&
                                `cho chứng từ {DOCNO}. Vui lòng kiểm tra và xác nhận để chúng tôi phát hành hoá đơn chính thức.\n\n{COMPANY}` )
        ELSE param( i_key = zif_hddt_types=>gc_parm-mail_body_final i_bukrs = lv_bukrs
                    i_default = `Kính gửi {BUYER},\n\nGửi quý khách hoá đơn điện tử ký hiệu {SERIAL} số {SEQ} ` &&
                                `ngày {DATE} (file PDF đính kèm).\n\n{COMPANY}` ) )
      is_request = is_request
      is_reg     = is_reg ).

    TRY.
        DATA(lo_bcs) = cl_bcs=>create_persistent( ).

        " Nội dung dạng text thuần
        DATA lt_text TYPE soli_tab.
        SPLIT lv_body AT cl_abap_char_utilities=>cr_lf INTO TABLE DATA(lt_lines).
        LOOP AT lt_lines ASSIGNING FIELD-SYMBOL(<fs_line>).
          APPEND VALUE soli( line = <fs_line> ) TO lt_text.
        ENDLOOP.

        DATA(lo_doc) = cl_document_bcs=>create_document(
                         i_type    = 'RAW'
                         i_text    = lt_text
                         i_subject = CONV so_obj_des( lv_subject ) ).

        DATA(lv_name) = COND string( WHEN i_file_name IS NOT INITIAL THEN i_file_name
                                     ELSE |HoaDon_{ is_reg-serial }_{ is_reg-seq }.pdf| ).
        lo_doc->add_attachment(
          i_attachment_type    = 'PDF'
          i_attachment_subject = CONV so_obj_des( lv_name )
          i_att_content_hex    = cl_document_bcs=>xstring_to_solix( i_pdf ) ).

        lo_bcs->set_document( lo_doc ).
        lo_bcs->set_message_subject( lv_subject ).

        " Người gửi
        DATA(lv_sender) = param( i_key = zif_hddt_types=>gc_parm-mail_sender i_bukrs = lv_bukrs ).
        IF lv_sender IS NOT INITIAL.
          lo_bcs->set_sender( cl_cam_address_bcs=>create_internet_address( CONV adr6-smtp_addr( lv_sender ) ) ).
        ELSE.
          lo_bcs->set_sender( cl_sapuser_bcs=>create( sy-uname ) ).
        ENDIF.

        " Người nhận: nhiều địa chỉ cách nhau ';'
        SPLIT lv_to AT ';' INTO TABLE DATA(lt_to).
        LOOP AT lt_to ASSIGNING FIELD-SYMBOL(<fs_to>).
          CONDENSE <fs_to>.
          IF <fs_to> IS INITIAL.
            CONTINUE.
          ENDIF.
          lo_bcs->add_recipient( cl_cam_address_bcs=>create_internet_address( CONV adr6-smtp_addr( <fs_to> ) ) ).
        ENDLOOP.

        lo_bcs->set_send_immediately( abap_true ).
        lo_bcs->send( ).

        rs_result-success = abap_true.
        rs_result-msgty   = 'S'.
        rs_result-message = |Đã gửi email hoá đơn tới { lv_to }|.

      CATCH cx_bcs INTO DATA(lx).
        rs_result-success = abap_false.
        rs_result-msgty   = 'E'.
        rs_result-message = |Gửi email lỗi: { lx->get_text( ) }|.
    ENDTRY.

  ENDMETHOD.

ENDCLASS.
