*=====================================================================
* Tên/Mã     : ZFIC_HDDT_SERVICE
* Mô tả chung: CỬA VÀO DUY NHẤT của HĐĐT Core. Chương trình SAP GUI,
*              job nền, enhancement hay BAPI khác chỉ cần gọi lớp này.
*              Toàn bộ pipeline dưới đây KHÔNG chứa tên nhà cung cấp:
*                1) Xác định nhà cung cấp     <- cấu hình
*                2) Lấy adapter               <- factory (CREATE động)
*                3) Lấy endpoint + tài khoản  <- cấu hình
*                4) Điền mặc định + tính tổng <- core
*                5) Dựng payload              <- adapter
*                6) Gọi HTTP                  <- core (cấu hình)
*                7) Bóc response              <- adapter
*                8) Quy đổi trạng thái        <- cấu hình
*                9) Ghi log + sổ hoá đơn      <- core
*              => Đổi Viettel/FPT/VNPT chỉ cần đổi bản ghi cấu hình.
* Tham Số    : EXECUTE( is_request iv_test_run iv_commit ) -> ty_result
*              Các method tiện ích: CREATE_INVOICE, ADJUST_INVOICE,
*              REPLACE_INVOICE, CANCEL_INVOICE, DELETE_INVOICE,
*              SEARCH_INVOICE, GET_INVOICE_FILE, PREVIEW_DRAFT
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       28/08/2026    cuongus - CuongUS        abapGit     Tạo mới
*=====================================================================
CLASS zfic_hddt_service DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE .

  PUBLIC SECTION.

    CONSTANTS gc_parm_log_test_run TYPE zfide_hddt_parmkey
                                    VALUE 'LOG_TEST_RUN' ##NO_TEXT.

    CLASS-METHODS get_instance
      RETURNING VALUE(ro_service) TYPE REF TO zfic_hddt_service .

    "! Thực hiện một nghiệp vụ HĐĐT. KHÔNG raise exception — mọi lỗi
    "! được gói vào RS_RESULT (status 90, msgty 'E') để chương trình
    "! xử lý hàng loạt không bị dừng giữa danh sách.
    METHODS execute
      IMPORTING is_request       TYPE zfiif_hddt_types=>ty_request
                iv_test_run      TYPE abap_bool DEFAULT abap_false
                iv_commit        TYPE abap_bool DEFAULT abap_true
      RETURNING VALUE(rs_result) TYPE zfiif_hddt_types=>ty_result .

    "! Xử lý hàng loạt; commit một lần ở cuối.
    METHODS execute_many
      IMPORTING it_request        TYPE zfiif_hddt_types=>ty_t_request
                iv_test_run       TYPE abap_bool DEFAULT abap_false
      RETURNING VALUE(rt_result)  TYPE zfiif_hddt_types=>ty_t_result .

*--- Tiện ích: chỉ khác nhau ở ACTION ---------------------------------*
    METHODS create_invoice
      IMPORTING is_request       TYPE zfiif_hddt_types=>ty_request
                iv_test_run      TYPE abap_bool DEFAULT abap_false
      RETURNING VALUE(rs_result) TYPE zfiif_hddt_types=>ty_result .

    METHODS adjust_invoice
      IMPORTING is_request       TYPE zfiif_hddt_types=>ty_request
                iv_test_run      TYPE abap_bool DEFAULT abap_false
      RETURNING VALUE(rs_result) TYPE zfiif_hddt_types=>ty_result .

    METHODS replace_invoice
      IMPORTING is_request       TYPE zfiif_hddt_types=>ty_request
                iv_test_run      TYPE abap_bool DEFAULT abap_false
      RETURNING VALUE(rs_result) TYPE zfiif_hddt_types=>ty_result .

    METHODS cancel_invoice
      IMPORTING is_request       TYPE zfiif_hddt_types=>ty_request
                iv_reason        TYPE string OPTIONAL
      RETURNING VALUE(rs_result) TYPE zfiif_hddt_types=>ty_result .

    METHODS delete_invoice
      IMPORTING is_request       TYPE zfiif_hddt_types=>ty_request
      RETURNING VALUE(rs_result) TYPE zfiif_hddt_types=>ty_result .

    METHODS search_invoice
      IMPORTING is_request       TYPE zfiif_hddt_types=>ty_request
      RETURNING VALUE(rs_result) TYPE zfiif_hddt_types=>ty_result .

    METHODS get_invoice_file
      IMPORTING is_request       TYPE zfiif_hddt_types=>ty_request
      RETURNING VALUE(rs_result) TYPE zfiif_hddt_types=>ty_result .

    METHODS preview_draft
      IMPORTING is_request       TYPE zfiif_hddt_types=>ty_request
      RETURNING VALUE(rs_result) TYPE zfiif_hddt_types=>ty_result .

    "! Tính bảng thuế theo thuế suất + tổng cộng từ danh sách hàng hoá.
    "! Public để lớp đọc dữ liệu nguồn dùng lại được.
    CLASS-METHODS aggregate_invoice
      CHANGING cs_invoice TYPE zfiif_hddt_types=>ty_invoice .

  PROTECTED SECTION.
  PRIVATE SECTION.

    CLASS-DATA go_instance TYPE REF TO zfic_hddt_service .

    DATA mo_config TYPE REF TO zfic_hddt_config .
    DATA mo_log    TYPE REF TO zfic_hddt_log .
    DATA mo_token  TYPE REF TO zfic_hddt_token .

    METHODS constructor .

    METHODS fill_defaults
      IMPORTING is_cred    TYPE zfit_hddt_cred
      CHANGING  cs_request TYPE zfiif_hddt_types=>ty_request .

    METHODS derive_status
      IMPORTING iv_provider TYPE zfide_hddt_prov
                iv_action   TYPE zfide_hddt_action
                iv_http_code TYPE i
      CHANGING  cs_result   TYPE zfiif_hddt_types=>ty_result .

ENDCLASS.



CLASS zfic_hddt_service IMPLEMENTATION.

  METHOD get_instance.

    IF go_instance IS NOT BOUND.
      go_instance = NEW zfic_hddt_service( ).
    ENDIF.
    ro_service = go_instance.

  ENDMETHOD.


  METHOD constructor.

    mo_config = zfic_hddt_config=>get_instance( ).
    mo_log    = NEW zfic_hddt_log( ).
    mo_token  = NEW zfic_hddt_token( ).

  ENDMETHOD.


  METHOD execute.

    DATA ls_request TYPE zfiif_hddt_types=>ty_request.
    DATA ls_conn    TYPE zfit_hddt_conn.
    DATA lv_action  TYPE zfide_hddt_action.
    DATA lv_provider TYPE zfide_hddt_prov.

    ls_request = is_request.

    TRY.
*---- 1. Nhà cung cấp -------------------------------------------------*
        lv_provider = ls_request-provider.
        IF lv_provider IS INITIAL.
          lv_provider = mo_config->get_active_provider( ls_request-bukrs ).
        ENDIF.
        ls_request-provider = lv_provider.

*---- 2. Adapter ------------------------------------------------------*
        DATA(lo_provider) = zfic_hddt_factory=>get_provider(
                              iv_provider = lv_provider
                              iv_bukrs    = ls_request-bukrs ).

*---- 3. Action + tài khoản + kết nối ---------------------------------*
        lv_action = lo_provider->resolve_action( ls_request ).
        IF lv_action IS INITIAL.
          lv_action = ls_request-action.
        ENDIF.

        DATA(ls_act) = mo_config->get_action( iv_provider = lv_provider
                                              iv_action   = lv_action ).

        DATA(ls_cred) = mo_config->get_credential(
                          iv_provider = lv_provider
                          iv_bukrs    = ls_request-bukrs
                          iv_inv_type = ls_request-invoice-header-inv_type
                          iv_date     = ls_request-invoice-header-inv_date ).

        ls_conn = mo_config->get_connection( iv_provider = lv_provider
                                             iv_connid   = ls_cred-connid ).

*---- 4. Điền mặc định + tính tổng ------------------------------------*
        fill_defaults( EXPORTING is_cred    = ls_cred
                       CHANGING  cs_request = ls_request ).

*---- 5. Secret + payload --------------------------------------------*
        " Adapter cần secret vì một số nhà cung cấp (FPT) nhận tài khoản
        " TRONG payload chứ không qua HTTP header.
        " Ở chế độ test run KHÔNG đọc secret thật: payload sẽ được người
        " dùng xem trên màn hình, không được để lộ mật khẩu.
        DATA lv_secret TYPE string.
        IF iv_test_run = abap_true.
          ls_cred-apisecret = '********'.
        ELSE.
          lv_secret         = zfic_hddt_secret=>get_secret( ls_cred ).
          ls_cred-apisecret = lv_secret.
        ENDIF.

        DATA(lv_payload) = lo_provider->build_payload( is_request = ls_request
                                                       iv_action  = lv_action
                                                       is_cred    = ls_cred ).
        rs_result-request_body = lv_payload.
        rs_result-idkey        = ls_request-invoice-header-idkey.

        DATA(lv_attempt) = zfic_hddt_log=>count_attempts(
                             is_request = ls_request
                             iv_action  = lv_action ).

        IF iv_test_run = abap_true.
          rs_result-success = abap_true.
          rs_result-msgty   = 'S'.
          rs_result-message = 'Test run: chỉ dựng payload, chưa gọi API.'.

          " Test run mặc định KHÔNG ghi log để bảng log không bị rác khi
          " người dùng xem trước hàng loạt. Bật tham số LOG_TEST_RUN nếu
          " cần vết ai đã xem payload nào.
          IF mo_config->get_param_bool( iv_key      = gc_parm_log_test_run
                                        iv_provider = lv_provider
                                        iv_bukrs    = ls_request-bukrs ) = abap_true.
            rs_result-log_id = mo_log->log_call(
              is_request  = ls_request
              iv_action   = lv_action
              iv_provider = lv_provider
              is_call     = VALUE #( connid    = ls_conn-connid
                                     method    = ls_act-http_method
                                     cont_type = ls_act-cont_type
                                     test_run  = abap_true
                                     attempt   = lv_attempt
                                     req_body  = lv_payload )
              is_result   = rs_result ).
            IF iv_commit = abap_true.
              COMMIT WORK AND WAIT.
            ENDIF.
          ENDIF.
          RETURN.
        ENDIF.

*---- 6. Gọi HTTP -----------------------------------------------------*
        DATA ls_call TYPE zfic_hddt_http=>ty_call.
        ls_call-conn     = ls_conn.
        ls_call-action   = ls_act.
        ls_call-payload  = lv_payload.
        ls_call-username = ls_cred-apiuser.
        ls_call-secret   = lv_secret.
        ls_call-symbols  = lo_provider->get_url_symbols( is_request = ls_request
                                                         is_cred    = ls_cred ).
        ls_call-headers  = lo_provider->get_headers( is_request = ls_request
                                                     is_cred    = ls_cred ).

        IF ls_conn-auth_mode = zfiif_hddt_types=>gc_auth-token
           OR ls_conn-auth_mode = zfiif_hddt_types=>gc_auth-oauth2.
          ls_call-bearer = mo_token->get_token( io_provider = lo_provider
                                                is_conn     = ls_conn
                                                is_cred     = ls_cred
                                                iv_secret   = lv_secret ).
        ENDIF.

        DATA(lo_http)  = NEW zfic_hddt_http( ).
        DATA(ls_resp)  = lo_http->send( ls_call ).

        " Token hết hạn sớm hơn TTL đã khai -> đăng nhập lại đúng 1 lần
        IF ls_resp-http_code = 401 AND ls_call-bearer IS NOT INITIAL.
          mo_token->invalidate( is_conn = ls_conn is_cred = ls_cred ).
          ls_call-bearer = mo_token->get_token( io_provider  = lo_provider
                                                is_conn      = ls_conn
                                                is_cred      = ls_cred
                                                iv_secret    = lv_secret
                                                iv_force_new = abap_true ).
          ls_resp = lo_http->send( ls_call ).
        ENDIF.

        rs_result-http_code     = ls_resp-http_code.
        rs_result-response_body = ls_resp-body.

*---- 7. Bóc response ------------------------------------------------*
        lo_provider->parse_response( EXPORTING is_request   = ls_request
                                               iv_action    = lv_action
                                               iv_http_code = ls_resp-http_code
                                               iv_body      = ls_resp-body
                                     CHANGING  cs_result    = rs_result ).

        IF lv_action = zfiif_hddt_types=>gc_action-get_file
           AND rs_result-file_content IS INITIAL
           AND rs_result-success = abap_true.
          " Nhà cung cấp trả file nhị phân trực tiếp trong body
          rs_result-file_content = ls_resp-body_x.
        ENDIF.

*---- 8. Quy đổi trạng thái ------------------------------------------*
        derive_status( EXPORTING iv_provider  = lv_provider
                                 iv_action    = lv_action
                                 iv_http_code = ls_resp-http_code
                       CHANGING  cs_result    = rs_result ).

*---- 9. Ghi log + sổ hoá đơn ----------------------------------------*
        rs_result-log_id = mo_log->log_call(
          is_request  = ls_request
          iv_action   = lv_action
          iv_provider = lv_provider
          is_call     = VALUE #( connid      = ls_conn-connid
                                 method      = ls_act-http_method
                                 full_url    = ls_resp-full_url
                                 cont_type   = ls_act-cont_type
                                 http_code   = ls_resp-http_code
                                 reason      = ls_resp-reason
                                 duration_ms = ls_resp-duration_ms
                                 attempt     = lv_attempt
                                 req_body    = lv_payload
                                 res_body    = ls_resp-body
                                 req_header  = ls_resp-req_header
                                 res_header  = ls_resp-res_header )
          is_result   = rs_result ).

        IF ls_request-src_docno IS NOT INITIAL.
          mo_log->save_invoice( is_request  = ls_request
                                is_result   = rs_result
                                iv_provider = lv_provider ).
          IF rs_result-success = abap_true
             AND ls_request-invoice-items IS NOT INITIAL.
            mo_log->save_items( ls_request ).
          ENDIF.
        ENDIF.

        IF iv_commit = abap_true.
          COMMIT WORK AND WAIT.
        ENDIF.

      CATCH zficx_hddt_error INTO DATA(lx_error).
        rs_result-success     = abap_false.
        rs_result-status      = zfiif_hddt_types=>gc_status-error.
        rs_result-msgty       = 'E'.
        rs_result-message     = lx_error->get_text_long( ).
        IF rs_result-http_code IS INITIAL.
          rs_result-http_code = lx_error->mv_http_code.
        ENDIF.

        " Vẫn ghi log để truy vết được cả trường hợp lỗi cấu hình
        IF ls_conn-provider IS NOT INITIAL.
          rs_result-log_id = mo_log->log_call(
            is_request  = ls_request
            iv_action   = lv_action
            iv_provider = lv_provider
            is_call     = VALUE #( connid    = ls_conn-connid
                                   method    = 'POST'
                                   http_code = rs_result-http_code
                                   req_body  = rs_result-request_body
                                   res_body  = rs_result-response_body ) ).
          IF ls_request-src_docno IS NOT INITIAL.
            mo_log->save_invoice( is_request  = ls_request
                                  is_result   = rs_result
                                  iv_provider = lv_provider ).
          ENDIF.
          IF iv_commit = abap_true.
            COMMIT WORK AND WAIT.
          ENDIF.
        ENDIF.

      CATCH cx_root INTO DATA(lx_root).
        " Lỗi không lường trước (dump tiềm ẩn) — không để job chết
        rs_result-success = abap_false.
        rs_result-status  = zfiif_hddt_types=>gc_status-error.
        rs_result-msgty   = 'E'.
        rs_result-message = |Lỗi không xác định: { lx_root->get_text( ) }|.
    ENDTRY.

  ENDMETHOD.


  METHOD execute_many.

    LOOP AT it_request ASSIGNING FIELD-SYMBOL(<ls_req>).
      APPEND execute( is_request  = <ls_req>
                      iv_test_run = iv_test_run
                      iv_commit   = abap_false ) TO rt_result.
    ENDLOOP.

    IF iv_test_run = abap_false.
      COMMIT WORK AND WAIT.
    ENDIF.

  ENDMETHOD.


  METHOD create_invoice.

    DATA(ls_req) = is_request.
    ls_req-action = zfiif_hddt_types=>gc_action-create_invoice.
    IF ls_req-invoice-adjust-adj_type IS INITIAL.
      ls_req-invoice-adjust-adj_type = zfiif_hddt_types=>gc_adj_type-original.
    ENDIF.
    rs_result = execute( is_request  = ls_req
                         iv_test_run = iv_test_run ).

  ENDMETHOD.


  METHOD adjust_invoice.

    DATA(ls_req) = is_request.
    ls_req-action = zfiif_hddt_types=>gc_action-adjust_invoice.
    ls_req-invoice-adjust-adj_type = zfiif_hddt_types=>gc_adj_type-adjust.
    rs_result = execute( is_request  = ls_req
                         iv_test_run = iv_test_run ).

  ENDMETHOD.


  METHOD replace_invoice.

    DATA(ls_req) = is_request.
    ls_req-action = zfiif_hddt_types=>gc_action-replace_invoice.
    ls_req-invoice-adjust-adj_type = zfiif_hddt_types=>gc_adj_type-replace.
    rs_result = execute( is_request  = ls_req
                         iv_test_run = iv_test_run ).

  ENDMETHOD.


  METHOD cancel_invoice.

    DATA(ls_req) = is_request.
    ls_req-action = zfiif_hddt_types=>gc_action-cancel_invoice.
    ls_req-invoice-adjust-adj_type = zfiif_hddt_types=>gc_adj_type-cancel.
    IF iv_reason IS NOT INITIAL.
      ls_req-invoice-adjust-reason = iv_reason.
    ENDIF.
    rs_result = execute( ls_req ).

  ENDMETHOD.


  METHOD delete_invoice.

    DATA(ls_req) = is_request.
    ls_req-action = zfiif_hddt_types=>gc_action-delete_invoice.
    rs_result = execute( ls_req ).

  ENDMETHOD.


  METHOD search_invoice.

    DATA(ls_req) = is_request.
    ls_req-action = zfiif_hddt_types=>gc_action-search_invoice.
    rs_result = execute( is_request = ls_req
                         iv_commit  = abap_false ).

  ENDMETHOD.


  METHOD get_invoice_file.

    DATA(ls_req) = is_request.
    ls_req-action = zfiif_hddt_types=>gc_action-get_file.
    rs_result = execute( is_request = ls_req
                         iv_commit  = abap_false ).

  ENDMETHOD.


  METHOD preview_draft.

    DATA(ls_req) = is_request.
    ls_req-action = zfiif_hddt_types=>gc_action-preview_draft.
    rs_result = execute( is_request = ls_req
                         iv_commit  = abap_false ).

  ENDMETHOD.


  METHOD fill_defaults.

    " ---- Khoá đối chiếu: bắt buộc và phải ỔN ĐỊNH giữa các lần thử
    " lại, nếu không nhà cung cấp sẽ tạo trùng hoá đơn.
    IF cs_request-invoice-header-idkey IS INITIAL.
      cs_request-invoice-header-idkey =
        |{ cs_request-bukrs }{ cs_request-gjahr }{ cs_request-src_docno }|.
      CONDENSE cs_request-invoice-header-idkey NO-GAPS.
    ENDIF.

    " ---- Mẫu / ký hiệu / MST người bán lấy từ cấu hình
    IF cs_request-invoice-header-inv_type IS INITIAL.
      cs_request-invoice-header-inv_type = is_cred-inv_type.
    ENDIF.
    IF cs_request-invoice-header-template IS INITIAL.
      cs_request-invoice-header-template = is_cred-template.
    ENDIF.
    IF cs_request-invoice-header-serial IS INITIAL.
      cs_request-invoice-header-serial = is_cred-serial.
    ENDIF.
    IF cs_request-invoice-seller-tax_code IS INITIAL.
      cs_request-invoice-seller-tax_code = is_cred-taxcode.
    ENDIF.

    " ---- Thông tin người bán từ tham số (không hardcode trong code)
    DATA(lv_bukrs) = cs_request-bukrs.
    IF cs_request-invoice-seller-name IS INITIAL.
      cs_request-invoice-seller-name = mo_config->get_param(
        iv_key = zfiif_hddt_types=>gc_parm-seller_name iv_bukrs = lv_bukrs ).
    ENDIF.
    IF cs_request-invoice-seller-address IS INITIAL.
      cs_request-invoice-seller-address = mo_config->get_param(
        iv_key = zfiif_hddt_types=>gc_parm-seller_addr iv_bukrs = lv_bukrs ).
    ENDIF.
    IF cs_request-invoice-seller-email IS INITIAL.
      cs_request-invoice-seller-email = mo_config->get_param(
        iv_key = zfiif_hddt_types=>gc_parm-seller_mail iv_bukrs = lv_bukrs ).
    ENDIF.
    IF cs_request-invoice-seller-phone IS INITIAL.
      cs_request-invoice-seller-phone = mo_config->get_param(
        iv_key = zfiif_hddt_types=>gc_parm-seller_tel iv_bukrs = lv_bukrs ).
    ENDIF.
    IF cs_request-invoice-seller-bank_name IS INITIAL.
      cs_request-invoice-seller-bank_name = mo_config->get_param(
        iv_key = zfiif_hddt_types=>gc_parm-seller_bank iv_bukrs = lv_bukrs ).
    ENDIF.
    IF cs_request-invoice-seller-bank_acct IS INITIAL.
      cs_request-invoice-seller-bank_acct = mo_config->get_param(
        iv_key = zfiif_hddt_types=>gc_parm-seller_acct iv_bukrs = lv_bukrs ).
    ENDIF.

    " ---- Ngày / giờ lập hoá đơn
    IF cs_request-invoice-header-inv_date IS INITIAL.
      cs_request-invoice-header-inv_date =
        mo_config->resolve_invoice_date( iv_bukrs = lv_bukrs ).
    ENDIF.
    IF cs_request-invoice-header-inv_time IS INITIAL.
      cs_request-invoice-header-inv_time = sy-uzeit.
    ENDIF.

    " ---- Tiền tệ / tỷ giá
    IF cs_request-invoice-header-currency IS INITIAL.
      DATA(lv_local) = mo_config->get_param(
        iv_key = zfiif_hddt_types=>gc_parm-local_currency iv_bukrs = lv_bukrs ).
      cs_request-invoice-header-currency =
        COND #( WHEN lv_local IS INITIAL THEN 'VND' ELSE lv_local ).
    ENDIF.
    IF cs_request-invoice-header-exch_rate IS INITIAL.
      cs_request-invoice-header-exch_rate = 1.
    ENDIF.

    " ---- Người mua không có địa chỉ => cờ "không lấy hoá đơn"
    IF cs_request-invoice-buyer-address IS INITIAL
       AND cs_request-invoice-buyer-legal_name IS INITIAL.
      cs_request-invoice-buyer-not_get_invoice = abap_true.
    ENDIF.

    " ---- Bảng thuế + tổng cộng
    aggregate_invoice( CHANGING cs_invoice = cs_request-invoice ).

  ENDMETHOD.


  METHOD aggregate_invoice.

    DATA lv_line TYPE zfide_hddt_lineno.
    FIELD-SYMBOLS <ls_agg> TYPE zfiif_hddt_types=>ty_tax.

    " Đánh số dòng nếu nguồn chưa đánh
    LOOP AT cs_invoice-items ASSIGNING FIELD-SYMBOL(<ls_item>).
      IF <ls_item>-line_no IS INITIAL.
        lv_line = sy-tabix.
        <ls_item>-line_no = lv_line.
      ENDIF.
      " Thành tiền sau thuế nếu nguồn chưa tính
      IF <ls_item>-total IS INITIAL.
        <ls_item>-total = <ls_item>-amount + <ls_item>-tax_amount.
      ENDIF.
    ENDLOOP.

    " ---- Bảng thuế theo từng thuế suất
    " Không dùng COLLECT vì ty_tax có component kiểu STRING (deep) —
    " COLLECT chỉ làm việc với structure phẳng.
    IF cs_invoice-taxes IS INITIAL.
      LOOP AT cs_invoice-items ASSIGNING <ls_item>.
        " Dòng ghi chú không tham gia tính thuế
        IF <ls_item>-item_type = '3'.
          CONTINUE.
        ENDIF.

        READ TABLE cs_invoice-taxes ASSIGNING <ls_agg>
             WITH KEY tax_rate = <ls_item>-tax_rate.
        IF sy-subrc <> 0.
          APPEND INITIAL LINE TO cs_invoice-taxes ASSIGNING <ls_agg>.
          <ls_agg>-tax_rate     = <ls_item>-tax_rate.
          <ls_agg>-tax_rate_txt = <ls_item>-tax_rate_txt.
          <ls_agg>-is_increase  = <ls_item>-is_increase.
        ENDIF.

        <ls_agg>-taxable_amt = <ls_agg>-taxable_amt + <ls_item>-amount.
        <ls_agg>-tax_amt     = <ls_agg>-tax_amt     + <ls_item>-tax_amount.
      ENDLOOP.

      " Quy đổi sang tiền VND theo tỷ giá
      LOOP AT cs_invoice-taxes ASSIGNING <ls_agg>.
        <ls_agg>-taxable_amt_l = <ls_agg>-taxable_amt
                               * cs_invoice-header-exch_rate.
        <ls_agg>-tax_amt_l     = <ls_agg>-tax_amt
                               * cs_invoice-header-exch_rate.
      ENDLOOP.
    ENDIF.

    " ---- Tổng cộng
    IF cs_invoice-summary-total IS INITIAL
       AND cs_invoice-summary-amount_wo_tax IS INITIAL.
      LOOP AT cs_invoice-items ASSIGNING <ls_item>.
        IF <ls_item>-item_type = '3'.
          CONTINUE.
        ENDIF.
        cs_invoice-summary-amount_wo_tax = cs_invoice-summary-amount_wo_tax
                                         + <ls_item>-amount.
        cs_invoice-summary-tax_amount    = cs_invoice-summary-tax_amount
                                         + <ls_item>-tax_amount.
        cs_invoice-summary-disc_amount   = cs_invoice-summary-disc_amount
                                         + <ls_item>-disc_amount.
      ENDLOOP.
      cs_invoice-summary-total = cs_invoice-summary-amount_wo_tax
                               + cs_invoice-summary-tax_amount.

      cs_invoice-summary-amount_wo_tax_l = cs_invoice-summary-amount_wo_tax
                                         * cs_invoice-header-exch_rate.
      cs_invoice-summary-tax_amount_l    = cs_invoice-summary-tax_amount
                                         * cs_invoice-header-exch_rate.
      cs_invoice-summary-disc_amount_l   = cs_invoice-summary-disc_amount
                                         * cs_invoice-header-exch_rate.
      cs_invoice-summary-total_l         = cs_invoice-summary-total
                                         * cs_invoice-header-exch_rate.
    ENDIF.

  ENDMETHOD.


  METHOD derive_status.

    DATA lv_found TYPE abap_bool.

    " Ưu tiên bảng anh xạ cấu hình
    mo_config->map_status( EXPORTING iv_provider = iv_provider
                                     iv_action   = iv_action
                                     iv_rc_code  = cs_result-prov_status
                           IMPORTING ev_status   = DATA(lv_status)
                                     ev_msgty    = DATA(lv_msgty)
                                     ev_msg_text = DATA(lv_text)
                                     ev_found    = lv_found ).

    IF lv_found = abap_true.
      IF lv_status IS NOT INITIAL.
        cs_result-status = lv_status.
      ENDIF.
      IF lv_msgty IS NOT INITIAL.
        cs_result-msgty = lv_msgty.
      ENDIF.
      IF lv_text IS NOT INITIAL AND cs_result-message IS INITIAL.
        cs_result-message = lv_text.
      ENDIF.
      cs_result-success = xsdbool( cs_result-msgty <> 'E'
                               AND cs_result-msgty <> 'A' ).
      RETURN.
    ENDIF.

    " Không có cấu hình -> suy từ mã HTTP (adapter đã set SUCCESS nếu
    " phân tích được nội dung response).
    IF cs_result-status IS INITIAL.
      IF iv_http_code >= 200 AND iv_http_code < 300
         AND cs_result-success = abap_true.
        CASE iv_action.
          WHEN zfiif_hddt_types=>gc_action-cancel_invoice.
            cs_result-status = zfiif_hddt_types=>gc_status-cancelled.
          WHEN zfiif_hddt_types=>gc_action-adjust_invoice.
            cs_result-status = zfiif_hddt_types=>gc_status-adjusted.
          WHEN zfiif_hddt_types=>gc_action-replace_invoice.
            cs_result-status = zfiif_hddt_types=>gc_status-replaced.
          WHEN zfiif_hddt_types=>gc_action-create_invoice.
            cs_result-status = COND #(
              WHEN cs_result-seq IS NOT INITIAL
              THEN zfiif_hddt_types=>gc_status-issued
              ELSE zfiif_hddt_types=>gc_status-wait_seq ).
          WHEN OTHERS.
            cs_result-status = zfiif_hddt_types=>gc_status-sent.
        ENDCASE.
      ELSE.
        cs_result-status  = zfiif_hddt_types=>gc_status-error.
        cs_result-success = abap_false.
      ENDIF.
    ENDIF.

    IF cs_result-msgty IS INITIAL.
      cs_result-msgty = COND #( WHEN cs_result-success = abap_true
                                THEN 'S' ELSE 'E' ).
    ENDIF.

  ENDMETHOD.

ENDCLASS.
