*=====================================================================
* Tên/Mã     : ZCL_HDDT_SERVICE
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
* Tham Số    : EXECUTE( is_request i_test_run i_commit ) -> ty_result
*              Các method tiện ích: CREATE_INVOICE, ADJUST_INVOICE,
*              REPLACE_INVOICE, CANCEL_INVOICE, DELETE_INVOICE,
*              SEARCH_INVOICE, GET_INVOICE_FILE, PREVIEW_DRAFT
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       28/08/2026    cuongus - CuongUS        abapGit     Tạo mới
* 1.2       07/09/2026    cuongus - CuongUS        abapGit     FS MAG v0.5:
*                         nháp/phát hành/khôi phục theo tra cứu, gắn HĐ
*                         gốc, validate, ghi ngược, ký duyệt sau thay thế
*=====================================================================
CLASS zcl_hddt_service DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE .

  PUBLIC SECTION.

    CONSTANTS gc_parm_log_test_run TYPE zde_hddt_parmkey
                                    VALUE 'LOG_TEST_RUN' ##NO_TEXT.

    CLASS-METHODS get_instance
      RETURNING VALUE(ro_service) TYPE REF TO zcl_hddt_service .

    "! Thực hiện một nghiệp vụ HĐĐT. KHÔNG raise exception — mọi lỗi
    "! được gói vào RS_RESULT (status 90, msgty 'E') để chương trình
    "! xử lý hàng loạt không bị dừng giữa danh sách.
    METHODS execute
      IMPORTING is_request       TYPE zif_hddt_types=>ty_request
                i_test_run      TYPE abap_bool DEFAULT abap_false
                i_commit        TYPE abap_bool DEFAULT abap_true
      RETURNING VALUE(rs_result) TYPE zif_hddt_types=>ty_result .

    "! Xử lý hàng loạt; commit một lần ở cuối.
    METHODS execute_many
      IMPORTING it_request        TYPE zif_hddt_types=>ty_t_request
                i_test_run       TYPE abap_bool DEFAULT abap_false
      RETURNING VALUE(rt_result)  TYPE zif_hddt_types=>ty_t_result .

    "! ---- Tiện ích: chỉ khác nhau ở ACTION ----
    METHODS create_invoice
      IMPORTING is_request       TYPE zif_hddt_types=>ty_request
                i_test_run      TYPE abap_bool DEFAULT abap_false
      RETURNING VALUE(rs_result) TYPE zif_hddt_types=>ty_result .

    METHODS adjust_invoice
      IMPORTING is_request       TYPE zif_hddt_types=>ty_request
                i_test_run      TYPE abap_bool DEFAULT abap_false
      RETURNING VALUE(rs_result) TYPE zif_hddt_types=>ty_result .

    METHODS replace_invoice
      IMPORTING is_request       TYPE zif_hddt_types=>ty_request
                i_test_run      TYPE abap_bool DEFAULT abap_false
      RETURNING VALUE(rs_result) TYPE zif_hddt_types=>ty_result .

    METHODS cancel_invoice
      IMPORTING is_request       TYPE zif_hddt_types=>ty_request
                i_reason        TYPE string OPTIONAL
      RETURNING VALUE(rs_result) TYPE zif_hddt_types=>ty_result .

    METHODS delete_invoice
      IMPORTING is_request       TYPE zif_hddt_types=>ty_request
      RETURNING VALUE(rs_result) TYPE zif_hddt_types=>ty_result .

    METHODS search_invoice
      IMPORTING is_request       TYPE zif_hddt_types=>ty_request
      RETURNING VALUE(rs_result) TYPE zif_hddt_types=>ty_result .

    METHODS get_invoice_file
      IMPORTING is_request       TYPE zif_hddt_types=>ty_request
      RETURNING VALUE(rs_result) TYPE zif_hddt_types=>ty_result .

    METHODS preview_draft
      IMPORTING is_request       TYPE zif_hddt_types=>ty_request
      RETURNING VALUE(rs_result) TYPE zif_hddt_types=>ty_result .

    "! ---- FS MAG v0.5 (docs/10) ----
    "! 3.6.1 Tích hợp HĐ: tạo hoá đơn NHÁP (chờ cấp số, chưa có số)
    METHODS create_draft
      IMPORTING is_request       TYPE zif_hddt_types=>ty_request
                i_test_run       TYPE abap_bool DEFAULT abap_false
      RETURNING VALUE(rs_result) TYPE zif_hddt_types=>ty_result .

    "! 3.6.3 + 3.6.10 Phát hành HĐ: cấp số + ký duyệt trên chính bản nháp;
    "! trạng thái lỗi -> tra cứu trước rồi chọn đúng API (issue / apprs /
    "! chỉ đồng bộ / đưa về chưa tích hợp). Chứng từ đã gắn HĐ gốc và chưa
    "! có nháp -> phát hành trực tiếp bằng adjust / replace.
    METHODS issue_invoice
      IMPORTING is_request       TYPE zif_hddt_types=>ty_request
                i_test_run       TYPE abap_bool DEFAULT abap_false
      RETURNING VALUE(rs_result) TYPE zif_hddt_types=>ty_result .

    "! 3.7.5 Ký duyệt hoá đơn đã cấp số (status 2)
    METHODS approve_invoice
      IMPORTING is_request       TYPE zif_hddt_types=>ty_request
                i_test_run       TYPE abap_bool DEFAULT abap_false
      RETURNING VALUE(rs_result) TYPE zif_hddt_types=>ty_result .

    "! 3.6.2 Hủy HĐ nháp: xoá nháp trên NCC, đưa chứng từ về chưa tích hợp
    METHODS delete_draft
      IMPORTING is_request       TYPE zif_hddt_types=>ty_request
      RETURNING VALUE(rs_result) TYPE zif_hddt_types=>ty_result .

    "! 3.6.4 HĐ Điều chỉnh: gắn (docno trống = gỡ) hoá đơn gốc + loại điều
    "! chỉnh theo FS (2 tăng / 3 giảm / 4 thông tin / 5 thay thế). Không
    "! gọi API; API adjust/replace được chọn lúc Phát hành HĐ.
    METHODS attach_original
      IMPORTING is_request       TYPE zif_hddt_types=>ty_request
                i_org_docno      TYPE zde_hddt_docno
                i_org_gjahr      TYPE gjahr
                i_fs_code        TYPE clike
      RETURNING VALUE(rs_result) TYPE zif_hddt_types=>ty_result .

    "! Tính bảng thuế theo thuế suất + tổng cộng từ danh sách hàng hoá.
    "! Public để lớp đọc dữ liệu nguồn dùng lại được.
    CLASS-METHODS aggregate_invoice
      CHANGING cs_invoice TYPE zif_hddt_types=>ty_invoice .

  PROTECTED SECTION.
  PRIVATE SECTION.

    CLASS-DATA go_instance TYPE REF TO zcl_hddt_service .

    DATA mo_config TYPE REF TO zcl_hddt_config .
    DATA mo_log    TYPE REF TO zcl_hddt_log .
    DATA mo_token  TYPE REF TO zcl_hddt_token .

    METHODS constructor .

    METHODS fill_defaults
      IMPORTING is_cred    TYPE ztb_hddt_cred
      CHANGING  cs_request TYPE zif_hddt_types=>ty_request .

    "! Kiểm tra nghiệp vụ theo trạng thái sổ HĐĐT và trạng thái chứng từ
    "! nguồn (đảo/huỷ) — port từ ZPG_INT_E_INVOICE get_data_integration
    "! và dieu_chinh_e_invoices. Tắt bằng tham số STATUS_CHECK = 'N'.
    METHODS check_action
      IMPORTING is_request TYPE zif_hddt_types=>ty_request
                i_action  TYPE zde_hddt_action
      RAISING   zcx_hddt_error .

    METHODS check_original
      IMPORTING is_request TYPE zif_hddt_types=>ty_request
                i_action  TYPE zde_hddt_action
      RAISING   zcx_hddt_error .

    "! FS 3.6.1: kiểm tra trường bắt buộc trước khi gọi API (VALIDATE_REQUEST)
    METHODS validate_request
      IMPORTING is_request TYPE zif_hddt_types=>ty_request
                i_action   TYPE zde_hddt_action
      RAISING   zcx_hddt_error .

    "! Lấy hoá đơn gốc đã gắn trong sổ (REF_DOCNO) vào request và đổi
    "! CREATE -> ADJUST/REPLACE
    METHODS resolve_adjust
      CHANGING  cs_request TYPE zif_hddt_types=>ty_request
      RAISING   zcx_hddt_error .

    "! Sau khi thành công: đổi trạng thái HĐ gốc, reset khi xoá nháp, ký
    "! duyệt sau thay thế (AUTO_APPROVE_AFTER_REPLACE), ghi ngược chứng từ
    METHODS post_success
      IMPORTING is_request TYPE zif_hddt_types=>ty_request
                i_action   TYPE zde_hddt_action
                i_provider TYPE zde_hddt_prov
      CHANGING  cs_result  TYPE zif_hddt_types=>ty_result .

    METHODS is_not_found
      IMPORTING is_result          TYPE zif_hddt_types=>ty_result
      RETURNING VALUE(r_not_found) TYPE abap_bool .

    METHODS error_result
      IMPORTING i_message        TYPE string
                i_status         TYPE zde_hddt_status OPTIONAL
      RETURNING VALUE(rs_result) TYPE zif_hddt_types=>ty_result .

    METHODS derive_status
      IMPORTING i_provider TYPE zde_hddt_prov
                i_action   TYPE zde_hddt_action
                i_http_code TYPE i
      CHANGING  cs_result   TYPE zif_hddt_types=>ty_result .

ENDCLASS.



CLASS zcl_hddt_service IMPLEMENTATION.

  METHOD get_instance.

    IF go_instance IS NOT BOUND.
      go_instance = NEW zcl_hddt_service( ).
    ENDIF.
    ro_service = go_instance.

  ENDMETHOD.


  METHOD constructor.

    mo_config = zcl_hddt_config=>get_instance( ).
    mo_log    = NEW zcl_hddt_log( ).
    mo_token  = NEW zcl_hddt_token( ).

  ENDMETHOD.


  METHOD execute.

    DATA ls_request TYPE zif_hddt_types=>ty_request.
    DATA ls_conn    TYPE ztb_hddt_conn.
    DATA lv_action  TYPE zde_hddt_action.
    DATA lv_provider TYPE zde_hddt_prov.

    ls_request = is_request.

    TRY.
*---- 1. Nhà cung cấp -------------------------------------------------*
        lv_provider = ls_request-provider.
        IF lv_provider IS INITIAL.
          lv_provider = mo_config->get_active_provider( ls_request-bukrs ).
        ENDIF.
        ls_request-provider = lv_provider.

*---- 1b. Hoá đơn gốc đã gắn trong sổ -> điều chỉnh / thay thế ----------*
        resolve_adjust( CHANGING cs_request = ls_request ).

*---- 2. Adapter ------------------------------------------------------*
        DATA(lo_provider) = zcl_hddt_factory=>get_provider(
                              i_provider = lv_provider
                              i_bukrs    = ls_request-bukrs ).

*---- 3. Action + tài khoản + kết nối ---------------------------------*
        lv_action = lo_provider->resolve_action( ls_request ).
        IF lv_action IS INITIAL.
          lv_action = ls_request-action.
        ENDIF.

        DATA(ls_act) = mo_config->get_action( i_provider = lv_provider
                                              i_action   = lv_action ).

        DATA(ls_cred) = mo_config->get_credential(
                          i_provider = lv_provider
                          i_bukrs    = ls_request-bukrs
                          i_inv_type = ls_request-invoice-header-inv_type
                          i_date     = ls_request-invoice-header-inv_date ).

        ls_conn = mo_config->get_connection( i_provider = lv_provider
                                             i_connid   = ls_cred-connid ).

*---- 4. Điền mặc định + tính tổng ------------------------------------*
        fill_defaults( EXPORTING is_cred    = ls_cred
                       CHANGING  cs_request = ls_request ).

*---- 4b. Kiểm tra nghiệp vụ theo trạng thái --------------------------*
        " Chặn phát hành lại, phát hành chứng từ đã đảo, huỷ khi chưa đảo,
        " điều chỉnh/thay thế hoá đơn gốc chưa phát hành hoặc khác khách
        " hàng/tiền tệ. Áp cả Test run để người dùng thấy lỗi sớm.
        check_action( is_request = ls_request
                      i_action  = lv_action ).
        validate_request( is_request = ls_request
                          i_action   = lv_action ).

*---- 5. Secret + payload --------------------------------------------*
        " Adapter cần secret vì một số nhà cung cấp (FPT) nhận tài khoản
        " TRONG payload chứ không qua HTTP header.
        " Ở chế độ test run KHÔNG đọc secret thật: payload sẽ được người
        " dùng xem trên màn hình, không được để lộ mật khẩu.
        DATA lv_secret TYPE string.
        IF i_test_run = abap_true.
          ls_cred-apisecret = '********'.
        ELSE.
          lv_secret         = zcl_hddt_secret=>get_secret( ls_cred ).
          ls_cred-apisecret = lv_secret.
        ENDIF.

        DATA(lv_payload) = lo_provider->build_payload( is_request = ls_request
                                                       i_action  = lv_action
                                                       is_cred    = ls_cred ).
        rs_result-request_body = lv_payload.
        rs_result-idkey        = ls_request-invoice-header-idkey.

        DATA(lv_attempt) = zcl_hddt_log=>count_attempts(
                             is_request = ls_request
                             i_action  = lv_action ).

        IF i_test_run = abap_true.
          rs_result-success = abap_true.
          rs_result-msgty   = 'S'.
          rs_result-message = 'Test run: chỉ dựng payload, chưa gọi API.'.

          " Test run mặc định KHÔNG ghi log để bảng log không bị rác khi
          " người dùng xem trước hàng loạt. Bật tham số LOG_TEST_RUN nếu
          " cần vết ai đã xem payload nào.
          IF mo_config->get_param_bool( i_key      = gc_parm_log_test_run
                                        i_provider = lv_provider
                                        i_bukrs    = ls_request-bukrs ) = abap_true.
            rs_result-log_id = mo_log->log_call(
              is_request  = ls_request
              i_action   = lv_action
              i_provider = lv_provider
              is_call     = VALUE #( connid    = ls_conn-connid
                                     method    = ls_act-http_method
                                     cont_type = ls_act-cont_type
                                     test_run  = abap_true
                                     attempt   = lv_attempt
                                     req_body  = lv_payload )
              is_result   = rs_result ).
            IF i_commit = abap_true.
              COMMIT WORK AND WAIT.
            ENDIF.
          ENDIF.
          RETURN.
        ENDIF.

*---- 6. Gọi HTTP -----------------------------------------------------*
        DATA ls_call TYPE zcl_hddt_http=>ty_call.
        ls_call-conn     = ls_conn.
        ls_call-action   = ls_act.
        ls_call-payload  = lv_payload.
        ls_call-username = ls_cred-apiuser.
        ls_call-secret   = lv_secret.
        ls_call-symbols  = lo_provider->get_url_symbols( is_request = ls_request
                                                         is_cred    = ls_cred ).
        ls_call-headers  = lo_provider->get_headers( is_request = ls_request
                                                     is_cred    = ls_cred ).

        IF ls_conn-auth_mode = zif_hddt_types=>gc_auth-token
           OR ls_conn-auth_mode = zif_hddt_types=>gc_auth-oauth2.
          ls_call-bearer = mo_token->get_token( io_provider = lo_provider
                                                is_conn     = ls_conn
                                                is_cred     = ls_cred
                                                i_secret   = lv_secret ).
        ENDIF.

        DATA(lo_http)  = NEW zcl_hddt_http( ).
        DATA(ls_resp)  = lo_http->send( ls_call ).

        " Token hết hạn sớm hơn TTL đã khai -> đăng nhập lại đúng 1 lần
        IF ls_resp-http_code = 401 AND ls_call-bearer IS NOT INITIAL.
          mo_token->invalidate( is_conn = ls_conn is_cred = ls_cred ).
          ls_call-bearer = mo_token->get_token( io_provider  = lo_provider
                                                is_conn      = ls_conn
                                                is_cred      = ls_cred
                                                i_secret    = lv_secret
                                                i_force_new = abap_true ).
          ls_resp = lo_http->send( ls_call ).
        ENDIF.

        rs_result-http_code     = ls_resp-http_code.
        rs_result-response_body = ls_resp-body.

*---- 7. Bóc response ------------------------------------------------*
        lo_provider->parse_response( EXPORTING is_request   = ls_request
                                               i_action    = lv_action
                                               i_http_code = ls_resp-http_code
                                               i_body      = ls_resp-body
                                     CHANGING  cs_result    = rs_result ).

        IF lv_action = zif_hddt_types=>gc_action-get_file
           AND rs_result-file_content IS INITIAL
           AND rs_result-success = abap_true.
          " Nhà cung cấp trả file nhị phân trực tiếp trong body
          rs_result-file_content = ls_resp-body_x.
        ENDIF.

*---- 8. Quy đổi trạng thái ------------------------------------------*
        derive_status( EXPORTING i_provider  = lv_provider
                                 i_action    = lv_action
                                 i_http_code = ls_resp-http_code
                       CHANGING  cs_result    = rs_result ).

*---- 9. Ghi log + sổ hoá đơn ----------------------------------------*
        rs_result-log_id = mo_log->log_call(
          is_request  = ls_request
          i_action   = lv_action
          i_provider = lv_provider
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
                                i_provider = lv_provider ).
          IF rs_result-success = abap_true
             AND ls_request-invoice-items IS NOT INITIAL.
            mo_log->save_items( ls_request ).
          ENDIF.
          IF rs_result-success = abap_true.
            post_success( EXPORTING is_request = ls_request
                                    i_action   = lv_action
                                    i_provider = lv_provider
                          CHANGING  cs_result  = rs_result ).
          ENDIF.
        ENDIF.

        IF i_commit = abap_true.
          COMMIT WORK AND WAIT.
        ENDIF.

      CATCH zcx_hddt_error INTO DATA(lx_error).
        rs_result-success     = abap_false.
        rs_result-status      = zif_hddt_types=>gc_status-error.
        rs_result-msgty       = 'E'.
        rs_result-message     = lx_error->get_text_long( ).
        IF rs_result-http_code IS INITIAL.
          rs_result-http_code = lx_error->mv_http_code.
        ENDIF.

        " Vẫn ghi log để truy vết được cả trường hợp lỗi cấu hình
        IF ls_conn-provider IS NOT INITIAL.
          rs_result-log_id = mo_log->log_call(
            is_request  = ls_request
            i_action   = lv_action
            i_provider = lv_provider
            is_call     = VALUE #( connid    = ls_conn-connid
                                   method    = 'POST'
                                   http_code = rs_result-http_code
                                   req_body  = rs_result-request_body
                                   res_body  = rs_result-response_body ) ).
          IF ls_request-src_docno IS NOT INITIAL.
            mo_log->save_invoice( is_request  = ls_request
                                  is_result   = rs_result
                                  i_provider = lv_provider ).
          ENDIF.
          IF i_commit = abap_true.
            COMMIT WORK AND WAIT.
          ENDIF.
        ENDIF.

      CATCH cx_root INTO DATA(lx_root).
        " Lỗi không lường trước (dump tiềm ẩn) — không để job chết
        rs_result-success = abap_false.
        rs_result-status  = zif_hddt_types=>gc_status-error.
        rs_result-msgty   = 'E'.
        rs_result-message = |Lỗi không xác định: { lx_root->get_text( ) }|.
    ENDTRY.

  ENDMETHOD.


  METHOD execute_many.

    LOOP AT it_request ASSIGNING FIELD-SYMBOL(<fs_req>).
      APPEND execute( is_request  = <fs_req>
                      i_test_run = i_test_run
                      i_commit   = abap_false ) TO rt_result.
    ENDLOOP.

    IF i_test_run = abap_false.
      COMMIT WORK AND WAIT.
    ENDIF.

  ENDMETHOD.


  METHOD create_invoice.

    DATA(ls_req) = is_request.
    ls_req-action = zif_hddt_types=>gc_action-create_invoice.
    IF ls_req-invoice-adjust-adj_type IS INITIAL.
      ls_req-invoice-adjust-adj_type = zif_hddt_types=>gc_adj_type-original.
    ENDIF.
    rs_result = execute( is_request  = ls_req
                         i_test_run = i_test_run ).

  ENDMETHOD.


  METHOD adjust_invoice.

    DATA(ls_req) = is_request.
    ls_req-action = zif_hddt_types=>gc_action-adjust_invoice.
    ls_req-invoice-adjust-adj_type = zif_hddt_types=>gc_adj_type-adjust.
    rs_result = execute( is_request  = ls_req
                         i_test_run = i_test_run ).

  ENDMETHOD.


  METHOD replace_invoice.

    DATA(ls_req) = is_request.
    ls_req-action = zif_hddt_types=>gc_action-replace_invoice.
    ls_req-invoice-adjust-adj_type = zif_hddt_types=>gc_adj_type-replace.
    rs_result = execute( is_request  = ls_req
                         i_test_run = i_test_run ).

  ENDMETHOD.


  METHOD cancel_invoice.

    DATA(ls_req) = is_request.
    ls_req-action = zif_hddt_types=>gc_action-cancel_invoice.
    ls_req-invoice-adjust-adj_type = zif_hddt_types=>gc_adj_type-cancel.
    IF i_reason IS NOT INITIAL.
      ls_req-invoice-adjust-reason = i_reason.
    ENDIF.
    rs_result = execute( ls_req ).

  ENDMETHOD.


  METHOD delete_invoice.

    DATA(ls_req) = is_request.
    ls_req-action = zif_hddt_types=>gc_action-delete_invoice.
    rs_result = execute( ls_req ).

  ENDMETHOD.


  METHOD search_invoice.

    DATA(ls_req) = is_request.
    ls_req-action = zif_hddt_types=>gc_action-search_invoice.
    rs_result = execute( is_request = ls_req
                         i_commit  = abap_false ).

  ENDMETHOD.


  METHOD get_invoice_file.

    DATA(ls_req) = is_request.
    ls_req-action = zif_hddt_types=>gc_action-get_file.
    rs_result = execute( is_request = ls_req
                         i_commit  = abap_false ).

  ENDMETHOD.


  METHOD preview_draft.

    DATA(ls_req) = is_request.
    ls_req-action = zif_hddt_types=>gc_action-preview_draft.
    rs_result = execute( is_request = ls_req
                         i_commit  = abap_false ).

  ENDMETHOD.


  METHOD fill_defaults.

    " ---- Khoá đối chiếu: bắt buộc và phải ỔN ĐỊNH giữa các lần thử
    " lại, nếu không nhà cung cấp sẽ tạo trùng hoá đơn.
    IF cs_request-invoice-header-idkey IS INITIAL.
      " FS MAG 3.7.1 (sid/FKEY): Company code + Số chứng từ + Năm chứng từ
      cs_request-invoice-header-idkey =
        |{ cs_request-bukrs }{ cs_request-src_docno }{ cs_request-gjahr }|.
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
        i_key = zif_hddt_types=>gc_parm-seller_name i_bukrs = lv_bukrs ).
    ENDIF.
    IF cs_request-invoice-seller-address IS INITIAL.
      cs_request-invoice-seller-address = mo_config->get_param(
        i_key = zif_hddt_types=>gc_parm-seller_addr i_bukrs = lv_bukrs ).
    ENDIF.
    IF cs_request-invoice-seller-email IS INITIAL.
      cs_request-invoice-seller-email = mo_config->get_param(
        i_key = zif_hddt_types=>gc_parm-seller_mail i_bukrs = lv_bukrs ).
    ENDIF.
    IF cs_request-invoice-seller-phone IS INITIAL.
      cs_request-invoice-seller-phone = mo_config->get_param(
        i_key = zif_hddt_types=>gc_parm-seller_tel i_bukrs = lv_bukrs ).
    ENDIF.
    IF cs_request-invoice-seller-bank_name IS INITIAL.
      cs_request-invoice-seller-bank_name = mo_config->get_param(
        i_key = zif_hddt_types=>gc_parm-seller_bank i_bukrs = lv_bukrs ).
    ENDIF.
    IF cs_request-invoice-seller-bank_acct IS INITIAL.
      cs_request-invoice-seller-bank_acct = mo_config->get_param(
        i_key = zif_hddt_types=>gc_parm-seller_acct i_bukrs = lv_bukrs ).
    ENDIF.

    " ---- Ngày / giờ lập hoá đơn
    IF cs_request-invoice-header-inv_date IS INITIAL.
      cs_request-invoice-header-inv_date =
        mo_config->resolve_invoice_date( i_bukrs = lv_bukrs ).
    ENDIF.
    IF cs_request-invoice-header-inv_time IS INITIAL.
      cs_request-invoice-header-inv_time = sy-uzeit.
    ENDIF.

    " ---- Tiền tệ / tỷ giá
    IF cs_request-invoice-header-currency IS INITIAL.
      DATA(lv_local) = mo_config->get_param(
        i_key = zif_hddt_types=>gc_parm-local_currency i_bukrs = lv_bukrs ).
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

    DATA lv_line TYPE zde_hddt_lineno.
    FIELD-SYMBOLS <fs_agg> TYPE zif_hddt_types=>ty_tax.

    " Đánh số dòng nếu nguồn chưa đánh
    LOOP AT cs_invoice-items ASSIGNING FIELD-SYMBOL(<fs_item>).
      IF <fs_item>-line_no IS INITIAL.
        lv_line = sy-tabix.
        <fs_item>-line_no = lv_line.
      ENDIF.
      " Thành tiền sau thuế nếu nguồn chưa tính
      IF <fs_item>-total IS INITIAL.
        <fs_item>-total = <fs_item>-amount + <fs_item>-tax_amount.
      ENDIF.
    ENDLOOP.

    " ---- Bảng thuế theo từng thuế suất
    " Không dùng COLLECT vì ty_tax có component kiểu STRING (deep) —
    " COLLECT chỉ làm việc với structure phẳng.
    IF cs_invoice-taxes IS INITIAL.
      LOOP AT cs_invoice-items ASSIGNING <fs_item>.
        " Dòng ghi chú không tham gia tính thuế
        IF <fs_item>-item_type = '3'.
          CONTINUE.
        ENDIF.

        READ TABLE cs_invoice-taxes ASSIGNING <fs_agg>
             WITH KEY tax_rate = <fs_item>-tax_rate.
        IF sy-subrc <> 0.
          APPEND INITIAL LINE TO cs_invoice-taxes ASSIGNING <fs_agg>.
          <fs_agg>-tax_rate     = <fs_item>-tax_rate.
          <fs_agg>-tax_rate_txt = <fs_item>-tax_rate_txt.
          <fs_agg>-is_increase  = <fs_item>-is_increase.
        ENDIF.

        <fs_agg>-taxable_amt = <fs_agg>-taxable_amt + <fs_item>-amount.
        <fs_agg>-tax_amt     = <fs_agg>-tax_amt     + <fs_item>-tax_amount.
      ENDLOOP.

      " Quy đổi sang tiền VND theo tỷ giá
      LOOP AT cs_invoice-taxes ASSIGNING <fs_agg>.
        <fs_agg>-taxable_amt_l = <fs_agg>-taxable_amt
                               * cs_invoice-header-exch_rate.
        <fs_agg>-tax_amt_l     = <fs_agg>-tax_amt
                               * cs_invoice-header-exch_rate.
      ENDLOOP.
    ENDIF.

    " ---- Tổng cộng
    IF cs_invoice-summary-total IS INITIAL
       AND cs_invoice-summary-amount_wo_tax IS INITIAL.
      LOOP AT cs_invoice-items ASSIGNING <fs_item>.
        IF <fs_item>-item_type = '3'.
          CONTINUE.
        ENDIF.
        cs_invoice-summary-amount_wo_tax = cs_invoice-summary-amount_wo_tax
                                         + <fs_item>-amount.
        cs_invoice-summary-tax_amount    = cs_invoice-summary-tax_amount
                                         + <fs_item>-tax_amount.
        cs_invoice-summary-disc_amount   = cs_invoice-summary-disc_amount
                                         + <fs_item>-disc_amount.
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


  METHOD check_action.

    " Tắt kiểm tra bằng STATUS_CHECK = 'N' (ví dụ nạp lại lịch sử)
    DATA(lv_switch) = mo_config->get_param( i_key      = zif_hddt_types=>gc_parm-status_check
                                            i_provider = is_request-provider
                                            i_bukrs    = is_request-bukrs ).
    TRANSLATE lv_switch TO UPPER CASE.
    CONDENSE lv_switch.
    IF lv_switch = 'N' OR lv_switch = 'OFF'.
      RETURN.
    ENDIF.

    " Request tự do (không gắn chứng từ SAP) không kiểm tra được
    IF is_request-src_docno IS INITIAL.
      RETURN.
    ENDIF.

    DATA(ls_reg) = zcl_hddt_log=>read_invoice( i_bukrs     = is_request-bukrs
                                                i_gjahr     = is_request-gjahr
                                                i_src_type  = is_request-src_type
                                                i_src_docno = is_request-src_docno ).
    DATA(lv_status) = COND zde_hddt_status( WHEN ls_reg-status IS INITIAL
                                              THEN zif_hddt_types=>gc_status-not_sent
                                              ELSE ls_reg-status ).
    DATA(lv_docno) = |{ is_request-src_docno }|.
    CONDENSE lv_docno.

    " Trạng thái chứng từ nguồn: lấy từ request, thiếu thì hỏi lớp nguồn
    DATA(ls_src) = is_request-src_info.
    IF ls_src IS INITIAL AND is_request-src_type IS NOT INITIAL.
      TRY.
          DATA(ls_state) = zcl_hddt_factory=>get_source(
                             i_bukrs    = is_request-bukrs
                             i_src_type = is_request-src_type
                           )->get_doc_state( i_bukrs = is_request-bukrs
                                             i_gjahr = is_request-gjahr
                                             i_docno = is_request-src_docno ).
          ls_src-xreversed = ls_state-xreversed.
          ls_src-stblg     = ls_state-stblg.
        CATCH zcx_hddt_error.
          " Không có lớp nguồn -> bỏ qua phần kiểm tra đảo
      ENDTRY.
    ENDIF.
    DATA(lv_reversed) = xsdbool( ls_src-xreversed = abap_true
                              OR ls_src-xcancel   = abap_true
                              OR ls_src-stblg IS NOT INITIAL ).

    " FS 3.6: chứng từ đã gom chỉ được thao tác trên chứng từ gom
    IF ls_reg-gom_no IS NOT INITIAL AND is_request-src_type <> 'GOM'
       AND i_action <> zif_hddt_types=>gc_action-search_invoice
       AND i_action <> zif_hddt_types=>gc_action-get_file.
      zcx_hddt_error=>raise_text(
        |Chứng từ { lv_docno } đã được gom vào { ls_reg-gom_no } - thao tác trên chứng từ gom.| ).
    ENDIF.

    CASE i_action.

      WHEN zif_hddt_types=>gc_action-create_invoice
        OR zif_hddt_types=>gc_action-create_draft
        OR zif_hddt_types=>gc_action-preview_draft.

        " FS 3.6.1 bảng điều kiện trạng thái khi bấm "Tích hợp HĐ"
        CASE lv_status.
          WHEN zif_hddt_types=>gc_status-not_sent
            OR zif_hddt_types=>gc_status-error.
            " hợp lệ
          WHEN zif_hddt_types=>gc_status-wait_seq
            OR zif_hddt_types=>gc_status-wait_appr.
            zcx_hddt_error=>raise_text(
              |Chứng từ { lv_docno } đã có hoá đơn nháp trên hệ thống HĐĐT - bấm "Hủy HĐ nháp" trước.| ).
          WHEN zif_hddt_types=>gc_status-rejected.
            zcx_hddt_error=>raise_text(
              |Chứng từ { lv_docno } đã bị Cơ quan thuế từ chối - xử lý bằng điều chỉnh/thay thế.| ).
          WHEN zif_hddt_types=>gc_status-cancelled.
            zcx_hddt_error=>raise_text( |Hoá đơn của chứng từ { lv_docno } đã bị huỷ.| ).
          WHEN zif_hddt_types=>gc_status-adjusted.
            zcx_hddt_error=>raise_text( |Hoá đơn của chứng từ { lv_docno } đã bị điều chỉnh.| ).
          WHEN zif_hddt_types=>gc_status-replaced.
            zcx_hddt_error=>raise_text( |Hoá đơn của chứng từ { lv_docno } đã bị thay thế.| ).
          WHEN OTHERS.
            zcx_hddt_error=>raise_text(
              |Chứng từ { lv_docno } đã phát hành (trạng thái { lv_status }, số | &&
              |{ ls_reg-serial } { ls_reg-seq }) - không phát hành lại.| ).
        ENDCASE.
        IF lv_reversed = abap_true.
          zcx_hddt_error=>raise_text(
            |Không thể tích hợp chứng từ đã huỷ ({ lv_docno } đã bị đảo trên SAP).| ).
        ENDIF.

      WHEN zif_hddt_types=>gc_action-issue_invoice.

        " FS 3.6.3: chỉ phát hành khi đã có nháp (20), đã cấp số chờ duyệt
        " (30) hoặc đang lỗi / bị CQT từ chối (đi qua tra cứu ở ISSUE_INVOICE)
        CASE lv_status.
          WHEN zif_hddt_types=>gc_status-wait_seq
            OR zif_hddt_types=>gc_status-wait_appr
            OR zif_hddt_types=>gc_status-error
            OR zif_hddt_types=>gc_status-rejected.
            " hợp lệ
          WHEN zif_hddt_types=>gc_status-not_sent.
            zcx_hddt_error=>raise_text(
              |Chứng từ { lv_docno } chưa có hoá đơn nháp - bấm "Tích hợp HĐ" trước khi phát hành.| ).
          WHEN zif_hddt_types=>gc_status-cancelled.
            zcx_hddt_error=>raise_text( |Hoá đơn của chứng từ { lv_docno } đã bị huỷ.| ).
          WHEN zif_hddt_types=>gc_status-adjusted.
            zcx_hddt_error=>raise_text( |Hoá đơn của chứng từ { lv_docno } đã bị điều chỉnh.| ).
          WHEN zif_hddt_types=>gc_status-replaced.
            zcx_hddt_error=>raise_text( |Hoá đơn của chứng từ { lv_docno } đã bị thay thế.| ).
          WHEN OTHERS.
            zcx_hddt_error=>raise_text( |Hoá đơn của chứng từ { lv_docno } đã phát hành.| ).
        ENDCASE.
        IF lv_reversed = abap_true.
          zcx_hddt_error=>raise_text(
            |Không thể tích hợp chứng từ đã huỷ ({ lv_docno } đã bị đảo trên SAP).| ).
        ENDIF.

      WHEN zif_hddt_types=>gc_action-approve_invoice.

        IF lv_status <> zif_hddt_types=>gc_status-wait_appr
           AND lv_status <> zif_hddt_types=>gc_status-wait_seq
           AND lv_status <> zif_hddt_types=>gc_status-error
           AND lv_status <> zif_hddt_types=>gc_status-rejected.
          zcx_hddt_error=>raise_text(
            |Chứng từ { lv_docno } không ở trạng thái chờ ký duyệt (trạng thái { lv_status }).| ).
        ENDIF.

      WHEN zif_hddt_types=>gc_action-delete_invoice.

        " FS 3.6.2: chỉ xoá hoá đơn NHÁP (chờ cấp số)
        CASE lv_status.
          WHEN zif_hddt_types=>gc_status-wait_seq
            OR zif_hddt_types=>gc_status-error.
            " hợp lệ
          WHEN zif_hddt_types=>gc_status-not_sent.
            zcx_hddt_error=>raise_text(
              |Chứng từ { lv_docno } chưa có hoá đơn nháp trên hệ thống HĐĐT.| ).
          WHEN zif_hddt_types=>gc_status-cancelled.
            zcx_hddt_error=>raise_text( |Hoá đơn của chứng từ { lv_docno } đã bị huỷ.| ).
          WHEN zif_hddt_types=>gc_status-adjusted.
            zcx_hddt_error=>raise_text( |Hoá đơn của chứng từ { lv_docno } đã bị điều chỉnh.| ).
          WHEN zif_hddt_types=>gc_status-replaced.
            zcx_hddt_error=>raise_text( |Hoá đơn của chứng từ { lv_docno } đã bị thay thế.| ).
          WHEN OTHERS.
            zcx_hddt_error=>raise_text(
              |Không thể huỷ hoá đơn đã phát hành ({ lv_docno }) - dùng chức năng điều chỉnh hoặc thay thế.| ).
        ENDCASE.

      WHEN zif_hddt_types=>gc_action-adjust_invoice
        OR zif_hddt_types=>gc_action-replace_invoice.

        IF lv_status <> zif_hddt_types=>gc_status-not_sent
           AND lv_status <> zif_hddt_types=>gc_status-error.
          zcx_hddt_error=>raise_text(
            |Chứng từ { lv_docno } đã có HĐĐT (trạng thái { lv_status }) - | &&
            |không dùng làm hoá đơn điều chỉnh/thay thế.| ).
        ENDIF.
        IF lv_reversed = abap_true.
          zcx_hddt_error=>raise_text(
            |Chứng từ điều chỉnh/thay thế { lv_docno } đã bị đảo trên SAP.| ).
        ENDIF.
        check_original( is_request = is_request
                        i_action  = i_action ).

      WHEN zif_hddt_types=>gc_action-cancel_invoice
        OR zif_hddt_types=>gc_action-wrong_notice.

        IF ls_reg-created_at IS INITIAL
           OR lv_status = zif_hddt_types=>gc_status-not_sent
           OR lv_status = zif_hddt_types=>gc_status-error.
          zcx_hddt_error=>raise_text(
            |Chứng từ { lv_docno } chưa phát hành HĐĐT - không có gì để huỷ.| ).
        ENDIF.
        IF lv_status = zif_hddt_types=>gc_status-cancelled.
          zcx_hddt_error=>raise_text(
            |Hoá đơn của chứng từ { lv_docno } đã huỷ trước đó.| ).
        ENDIF.
        " Quy tắc kế toán của dự án tham chiếu: phải đảo chứng từ SAP
        " trước khi huỷ hoá đơn điện tử (trừ khi tắt bằng tham số).
        DATA(lv_req_rev) = mo_config->get_param( i_key      = zif_hddt_types=>gc_parm-cancel_req_rev
                                                 i_provider = is_request-provider
                                                 i_bukrs    = is_request-bukrs ).
        TRANSLATE lv_req_rev TO UPPER CASE.
        CONDENSE lv_req_rev.
        IF lv_req_rev <> 'N' AND lv_req_rev <> 'OFF' AND lv_reversed = abap_false.
          zcx_hddt_error=>raise_text(
            |Phải đảo chứng từ { lv_docno } trên SAP trước khi huỷ hoá đơn điện tử| &&
            | (tham số CANCEL_REQUIRES_REVERSAL).| ).
        ENDIF.

      WHEN zif_hddt_types=>gc_action-search_invoice
        OR zif_hddt_types=>gc_action-get_file
        OR zif_hddt_types=>gc_action-send_mail.

        IF ls_reg-created_at IS INITIAL.
          zcx_hddt_error=>raise_text(
            |Chứng từ { lv_docno } chưa tích hợp HĐĐT - không có gì để tra cứu.| ).
        ENDIF.

      WHEN OTHERS.
    ENDCASE.

  ENDMETHOD.


  METHOD check_original.

    DATA(ls_adj) = is_request-invoice-adjust.

    IF ls_adj-org_serial IS INITIAL AND ls_adj-org_seq IS INITIAL
       AND ls_adj-org_idkey IS INITIAL AND ls_adj-org_docno IS INITIAL.
      zcx_hddt_error=>raise_text(
        `Thiếu thông tin hoá đơn gốc (ký hiệu / số) khi lập hoá đơn điều chỉnh/thay thế.` ).
    ENDIF.

    " Chỉ kiểm tra sâu khi biết chứng từ SAP của hoá đơn gốc
    IF ls_adj-org_docno IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lv_gjahr) = COND gjahr( WHEN ls_adj-org_gjahr IS NOT INITIAL
                                 THEN ls_adj-org_gjahr ELSE is_request-gjahr ).
    DATA(lv_type)  = COND zde_hddt_srctype( WHEN ls_adj-org_src_type IS NOT INITIAL
                                              THEN ls_adj-org_src_type ELSE is_request-src_type ).
    DATA(lv_org)   = |{ ls_adj-org_docno }/{ lv_gjahr }|.

    IF ls_adj-org_docno = is_request-src_docno AND lv_gjahr = is_request-gjahr
       AND lv_type = is_request-src_type.
      zcx_hddt_error=>raise_text(
        |Hoá đơn gốc trùng với chính chứng từ { is_request-src_docno }.| ).
    ENDIF.

    DATA(ls_org) = zcl_hddt_log=>read_invoice( i_bukrs     = is_request-bukrs
                                                i_gjahr     = lv_gjahr
                                                i_src_type  = lv_type
                                                i_src_docno = ls_adj-org_docno ).
    IF ls_org-created_at IS INITIAL.
      zcx_hddt_error=>raise_text(
        |Chứng từ gốc { lv_org } chưa có trong sổ đăng ký HĐĐT (ZTB_HDDT_INV).| ).
    ENDIF.

    CASE ls_org-status.
      WHEN zif_hddt_types=>gc_status-replaced.
        zcx_hddt_error=>raise_text(
          |Hoá đơn gốc { lv_org } đã bị thay thế - không điều chỉnh/thay thế lần nữa.| ).
      WHEN zif_hddt_types=>gc_status-cancelled.
        zcx_hddt_error=>raise_text( |Hoá đơn gốc { lv_org } đã huỷ.| ).
      WHEN zif_hddt_types=>gc_status-issued
        OR zif_hddt_types=>gc_status-coded
        OR zif_hddt_types=>gc_status-adjusted
        OR zif_hddt_types=>gc_status-sent
        OR zif_hddt_types=>gc_status-wait_seq.
        " hợp lệ
      WHEN OTHERS.
        zcx_hddt_error=>raise_text(
          |Hoá đơn gốc { lv_org } chưa phát hành (trạng thái { ls_org-status }).| ).
    ENDCASE.

    IF ls_org-buyer_code IS NOT INITIAL
       AND is_request-invoice-buyer-code IS NOT INITIAL
       AND ls_org-buyer_code <> is_request-invoice-buyer-code.
      zcx_hddt_error=>raise_text(
        |Khách hàng của hoá đơn gốc ({ ls_org-buyer_code }) khác chứng từ hiện tại| &&
        | ({ is_request-invoice-buyer-code }).| ).
    ENDIF.

    IF ls_org-waers IS NOT INITIAL
       AND is_request-invoice-header-currency IS NOT INITIAL
       AND ls_org-waers <> is_request-invoice-header-currency.
      zcx_hddt_error=>raise_text(
        |Loại tiền hoá đơn gốc ({ ls_org-waers }) khác chứng từ hiện tại| &&
        | ({ is_request-invoice-header-currency }).| ).
    ENDIF.

    " Thay thế: chứng từ gốc phải được đảo trên SAP trước
    IF i_action = zif_hddt_types=>gc_action-replace_invoice.
      DATA ls_state TYPE zif_hddt_source=>ty_doc_state.
      TRY.
          ls_state = zcl_hddt_factory=>get_source(
                       i_bukrs    = is_request-bukrs
                       i_src_type = lv_type
                     )->get_doc_state( i_bukrs = is_request-bukrs
                                       i_gjahr = lv_gjahr
                                       i_docno = ls_adj-org_docno ).
        CATCH zcx_hddt_error.
          CLEAR ls_state.            " không có lớp nguồn -> bỏ qua kiểm tra đảo
      ENDTRY.
      IF ls_state-exists = abap_true AND ls_state-xreversed = abap_false.
        zcx_hddt_error=>raise_text(
          |Chứng từ gốc { lv_org } chưa được đảo trên SAP - hoá đơn thay thế| &&
          | yêu cầu đảo chứng từ gốc trước.| ).
      ENDIF.
    ENDIF.

  ENDMETHOD.


  METHOD error_result.

    rs_result-success = abap_false.
    rs_result-msgty   = 'E'.
    rs_result-message = i_message.
    rs_result-status  = i_status.

  ENDMETHOD.


  METHOD is_not_found.

    " Heuristic theo phản hồi tra cứu của NCC: HTTP 404, hoặc thông điệp
    " "không tồn tại / not found", hoặc 200 nhưng không có dữ liệu.
    DATA(lv_msg) = to_lower( is_result-message ).
    r_not_found = xsdbool(
         is_result-http_code = 404
      OR lv_msg CS 'not found'
      OR lv_msg CS 'không tồn tại'
      OR lv_msg CS 'không tìm thấy'
      OR lv_msg CS 'khong ton tai'
      OR ( is_result-http_code >= 200 AND is_result-http_code < 300
           AND is_result-fields IS INITIAL AND is_result-seq IS INITIAL ) ).

  ENDMETHOD.


  METHOD create_draft.

    " Chứng từ đã gắn hoá đơn gốc phát hành trực tiếp bằng adjust/replace,
    " không qua nháp (FS 3.6.4 quyết định API lúc phát hành).
    DATA(ls_reg) = zcl_hddt_log=>read_invoice( i_bukrs     = is_request-bukrs
                                               i_gjahr     = is_request-gjahr
                                               i_src_type  = is_request-src_type
                                               i_src_docno = is_request-src_docno ).
    IF ls_reg-ref_docno IS NOT INITIAL OR is_request-invoice-adjust-org_docno IS NOT INITIAL.
      rs_result = error_result(
        |Chứng từ đã gắn hoá đơn gốc { ls_reg-ref_docno } - phát hành trực tiếp bằng nút "Phát hành HĐ".| ).
      RETURN.
    ENDIF.

    DATA(ls_req) = is_request.
    ls_req-action = zif_hddt_types=>gc_action-create_draft.
    rs_result = execute( is_request = ls_req i_test_run = i_test_run ).

  ENDMETHOD.


  METHOD approve_invoice.

    DATA(ls_req) = is_request.
    ls_req-action = zif_hddt_types=>gc_action-approve_invoice.
    rs_result = execute( is_request = ls_req i_test_run = i_test_run ).

  ENDMETHOD.


  METHOD issue_invoice.

    DATA(ls_req) = is_request.
    DATA(ls_reg) = zcl_hddt_log=>read_invoice( i_bukrs     = ls_req-bukrs
                                               i_gjahr     = ls_req-gjahr
                                               i_src_type  = ls_req-src_type
                                               i_src_docno = ls_req-src_docno ).
    DATA(lv_status) = COND zde_hddt_status( WHEN ls_reg-status IS INITIAL
                                            THEN zif_hddt_types=>gc_status-not_sent
                                            ELSE ls_reg-status ).

    CASE lv_status.

      WHEN zif_hddt_types=>gc_status-not_sent.
        " Đã gắn HĐ gốc -> phát hành trực tiếp (RESOLVE_ADJUST đổi sang
        " adjust/replace); chưa gắn -> phải tạo nháp trước (FS 3.6.3)
        IF ls_reg-ref_docno IS NOT INITIAL OR ls_req-invoice-adjust-org_docno IS NOT INITIAL.
          ls_req-action = zif_hddt_types=>gc_action-create_invoice.
          rs_result = execute( is_request = ls_req i_test_run = i_test_run ).
          RETURN.
        ENDIF.
        rs_result = error_result(
          i_message = |Chứng từ { ls_req-src_docno ALPHA = OUT } chưa có hoá đơn nháp - bấm "Tích hợp HĐ" trước khi phát hành.|
          i_status  = lv_status ).
        RETURN.

      WHEN zif_hddt_types=>gc_status-wait_seq.
        ls_req-action = zif_hddt_types=>gc_action-issue_invoice.

      WHEN zif_hddt_types=>gc_status-wait_appr.
        ls_req-action = zif_hddt_types=>gc_action-approve_invoice.

      WHEN zif_hddt_types=>gc_status-error
        OR zif_hddt_types=>gc_status-rejected.
        " FS 3.6.10: tra cứu để biết trạng thái thật trên NCC
        IF i_test_run = abap_true.
          ls_req-action = zif_hddt_types=>gc_action-issue_invoice.
        ELSE.
          DATA(ls_search) = ls_req.
          ls_search-action = zif_hddt_types=>gc_action-search_invoice.
          DATA(ls_found) = execute( is_request = ls_search i_commit = abap_false ).

          IF ls_found-success = abap_false.
            IF is_not_found( ls_found ) = abap_true.
              mo_log->reset_registry(
                is_request = ls_req
                i_message  = 'Không tìm thấy hoá đơn trên NCC - đưa về trạng thái chưa tích hợp' ).
              COMMIT WORK AND WAIT.
              rs_result = ls_found.
              rs_result-status  = zif_hddt_types=>gc_status-not_sent.
              rs_result-msgty   = 'W'.
              rs_result-message = 'Không tìm thấy hoá đơn trên NCC - đã đưa về chưa tích hợp, bấm "Tích hợp HĐ" để tạo lại'.
              RETURN.
            ENDIF.
            rs_result = ls_found.
            RETURN.
          ENDIF.

          CASE ls_found-prov_status.
            WHEN '1'.                      " chờ cấp số -> issue
              ls_req-action = zif_hddt_types=>gc_action-issue_invoice.
            WHEN '2'.                      " đã cấp số, ký lỗi -> apprs
              ls_req-action = zif_hddt_types=>gc_action-approve_invoice.
            WHEN OTHERS.                   " 3/4: đã đồng bộ bằng kết quả tra cứu
              COMMIT WORK AND WAIT.
              rs_result = ls_found.
              rs_result-message = |Hoá đơn đã tồn tại trên NCC (status { ls_found-prov_status }) - đã đồng bộ về SAP.|.
              RETURN.
          ENDCASE.
        ENDIF.

      WHEN OTHERS.
        " CHECK_ACTION sẽ trả đúng thông điệp (đã phát hành / đã huỷ...)
        ls_req-action = zif_hddt_types=>gc_action-issue_invoice.
    ENDCASE.

    rs_result = execute( is_request = ls_req i_test_run = i_test_run ).

  ENDMETHOD.


  METHOD delete_draft.

    DATA(ls_req) = is_request.
    DATA(ls_reg) = zcl_hddt_log=>read_invoice( i_bukrs     = ls_req-bukrs
                                               i_gjahr     = ls_req-gjahr
                                               i_src_type  = ls_req-src_type
                                               i_src_docno = ls_req-src_docno ).
    ls_req-action = zif_hddt_types=>gc_action-delete_invoice.

    IF ls_reg-status = zif_hddt_types=>gc_status-error.
      " FS 3.6.2 trạng thái 04: tra cứu trước
      DATA(ls_search) = ls_req.
      ls_search-action = zif_hddt_types=>gc_action-search_invoice.
      DATA(ls_found) = execute( is_request = ls_search i_commit = abap_false ).
      IF ls_found-success = abap_false.
        IF is_not_found( ls_found ) = abap_true.
          mo_log->reset_registry( is_request = ls_req
                                  i_message  = 'Không có hoá đơn nháp trên NCC - đã đưa về chưa tích hợp' ).
          COMMIT WORK AND WAIT.
          rs_result = ls_found.
          rs_result-success = abap_true.
          rs_result-status  = zif_hddt_types=>gc_status-not_sent.
          rs_result-msgty   = 'S'.
          rs_result-message = 'Không có hoá đơn nháp trên NCC - đã đưa về chưa tích hợp'.
          RETURN.
        ENDIF.
        rs_result = ls_found.
        RETURN.
      ENDIF.
      IF ls_found-prov_status <> '1'.
        COMMIT WORK AND WAIT.
        rs_result = error_result(
          i_message = |Không thể huỷ hoá đơn đã cấp số (status { ls_found-prov_status }) - dùng điều chỉnh hoặc thay thế.|
          i_status  = ls_found-status ).
        RETURN.
      ENDIF.
    ENDIF.

    rs_result = execute( ls_req ).
    IF rs_result-success = abap_true AND rs_result-message IS INITIAL.
      rs_result-message = 'Đã huỷ hoá đơn nháp'.
    ENDIF.

  ENDMETHOD.


  METHOD attach_original.

    DATA(ls_reg) = zcl_hddt_log=>read_invoice( i_bukrs     = is_request-bukrs
                                               i_gjahr     = is_request-gjahr
                                               i_src_type  = is_request-src_type
                                               i_src_docno = is_request-src_docno ).
    DATA(lv_status) = COND zde_hddt_status( WHEN ls_reg-status IS INITIAL
                                            THEN zif_hddt_types=>gc_status-not_sent
                                            ELSE ls_reg-status ).

    " Gỡ hoá đơn gốc
    IF i_org_docno IS INITIAL.
      mo_log->attach_original( is_request    = is_request
                               i_org_docno   = space
                               i_org_gjahr   = space
                               i_org_srctype = space
                               i_adj_type    = space
                               i_adj_dir     = space ).
      COMMIT WORK AND WAIT.
      rs_result-success = abap_true.
      rs_result-msgty   = 'S'.
      rs_result-message = 'Đã gỡ hoá đơn gốc khỏi chứng từ'.
      rs_result-status  = lv_status.
      RETURN.
    ENDIF.

    " FS 3.6.4 điều kiện trạng thái của chứng từ điều chỉnh
    IF lv_status = zif_hddt_types=>gc_status-wait_seq
       OR lv_status = zif_hddt_types=>gc_status-wait_appr.
      rs_result = error_result(
        i_message = 'Chứng từ đang có hoá đơn nháp chưa phát hành - bấm "Hủy HĐ nháp" hoặc "Phát hành HĐ" trước'
        i_status  = lv_status ).
      RETURN.
    ENDIF.
    IF lv_status <> zif_hddt_types=>gc_status-not_sent
       AND lv_status <> zif_hddt_types=>gc_status-rejected
       AND lv_status <> zif_hddt_types=>gc_status-error.
      rs_result = error_result( i_message = 'Không thể cập nhật hoá đơn điều chỉnh với chứng từ này'
                                i_status  = lv_status ).
      RETURN.
    ENDIF.

    DATA(lv_code) = |{ i_fs_code }|.
    CONDENSE lv_code NO-GAPS.
    IF strlen( lv_code ) <> 1 OR lv_code NA '2345'.
      rs_result = error_result( i_message = 'Loại điều chỉnh phải là 2 (tăng), 3 (giảm), 4 (thông tin) hoặc 5 (thay thế)'
                                i_status  = lv_status ).
      RETURN.
    ENDIF.

    DATA lv_docno TYPE zde_hddt_docno.
    lv_docno = i_org_docno.
    IF lv_docno = is_request-src_docno AND i_org_gjahr = is_request-gjahr.
      rs_result = error_result( i_message = 'Hoá đơn gốc trùng với chính chứng từ đang chọn' i_status = lv_status ).
      RETURN.
    ENDIF.

    " Hoá đơn gốc phải có trong sổ với trạng thái đã phát hành / CQT cấp mã
    DATA(ls_org) = zcl_hddt_log=>read_invoice( i_bukrs     = is_request-bukrs
                                               i_gjahr     = i_org_gjahr
                                               i_src_type  = is_request-src_type
                                               i_src_docno = lv_docno ).
    IF ls_org-created_at IS INITIAL.
      rs_result = error_result( i_message = |Hoá đơn bị điều chỉnh không hợp lệ: chứng từ { lv_docno ALPHA = OUT }/{ i_org_gjahr } chưa có trong sổ HĐĐT|
                                i_status  = lv_status ).
      RETURN.
    ENDIF.
    IF ls_org-status <> zif_hddt_types=>gc_status-issued
       AND ls_org-status <> zif_hddt_types=>gc_status-coded.
      rs_result = error_result( i_message = |Chứng từ gốc phải ở trạng thái đã phát hành hoặc đã được CQT cấp mã (hiện { ls_org-status })|
                                i_status  = lv_status ).
      RETURN.
    ENDIF.

    DATA(lv_adj_type) = COND zde_hddt_adjtype( WHEN lv_code = '5'
                                               THEN zif_hddt_types=>gc_adj_type-replace
                                               ELSE zif_hddt_types=>gc_adj_type-adjust ).
    DATA(lv_adj_dir)  = SWITCH zde_hddt_adjdir( lv_code WHEN '2' THEN '1'
                                                        WHEN '3' THEN '0'
                                                        WHEN '4' THEN '2'
                                                        ELSE space ).
    mo_log->attach_original( is_request    = is_request
                             i_org_docno   = lv_docno
                             i_org_gjahr   = i_org_gjahr
                             i_org_srctype = is_request-src_type
                             i_adj_type    = lv_adj_type
                             i_adj_dir     = lv_adj_dir ).
    COMMIT WORK AND WAIT.

    rs_result-success = abap_true.
    rs_result-msgty   = 'S'.
    rs_result-status  = lv_status.
    rs_result-message = |Đã gắn hoá đơn gốc { lv_docno ALPHA = OUT }/{ i_org_gjahr } (loại { lv_code }) cho chứng từ|.

  ENDMETHOD.


  METHOD resolve_adjust.

    IF cs_request-src_docno IS INITIAL.
      RETURN.
    ENDIF.

    " Lấy hoá đơn gốc đã gắn trong sổ nếu caller chưa truyền
    IF cs_request-invoice-adjust-org_docno IS INITIAL.
      DATA(ls_reg) = zcl_hddt_log=>read_invoice( i_bukrs     = cs_request-bukrs
                                                 i_gjahr     = cs_request-gjahr
                                                 i_src_type  = cs_request-src_type
                                                 i_src_docno = cs_request-src_docno ).
      IF ls_reg-ref_docno IS INITIAL.
        RETURN.
      ENDIF.
      cs_request-invoice-adjust-org_docno    = ls_reg-ref_docno.
      cs_request-invoice-adjust-org_gjahr    = COND #( WHEN ls_reg-ref_gjahr IS NOT INITIAL
                                                       THEN ls_reg-ref_gjahr ELSE cs_request-gjahr ).
      cs_request-invoice-adjust-org_src_type = COND #( WHEN ls_reg-ref_srctype IS NOT INITIAL
                                                       THEN ls_reg-ref_srctype ELSE cs_request-src_type ).
      IF ls_reg-adj_type IS NOT INITIAL.
        cs_request-invoice-adjust-adj_type = ls_reg-adj_type.
      ENDIF.
      IF ls_reg-adj_dir IS NOT INITIAL.
        cs_request-invoice-adjust-adj_direction = ls_reg-adj_dir.
      ENDIF.
    ENDIF.

    DATA(ls_adj) = cs_request-invoice-adjust.
    IF ls_adj-adj_type IS INITIAL OR ls_adj-adj_type = zif_hddt_types=>gc_adj_type-original.
      ls_adj-adj_type = zif_hddt_types=>gc_adj_type-adjust.
    ENDIF.
    IF ls_adj-fs_code IS INITIAL.
      ls_adj-fs_code = COND #( WHEN ls_adj-adj_type = zif_hddt_types=>gc_adj_type-replace THEN '5'
                               WHEN ls_adj-adj_direction = '1' THEN '2'
                               WHEN ls_adj-adj_direction = '0' THEN '3'
                               ELSE '4' ).
    ENDIF.

    " Thông tin hoá đơn gốc (ký hiệu / số / ngày / sid) từ sổ đăng ký
    IF ls_adj-org_serial IS INITIAL OR ls_adj-org_seq IS INITIAL.
      DATA(ls_org) = zcl_hddt_log=>read_invoice( i_bukrs     = cs_request-bukrs
                                                 i_gjahr     = ls_adj-org_gjahr
                                                 i_src_type  = ls_adj-org_src_type
                                                 i_src_docno = ls_adj-org_docno ).
      IF ls_org-serial IS NOT INITIAL OR ls_org-seq IS NOT INITIAL.
        ls_adj-org_serial   = ls_org-serial.
        ls_adj-org_seq      = ls_org-seq.
        ls_adj-org_idkey    = ls_org-idkey.
        ls_adj-org_inv_date = COND #( WHEN ls_org-issue_date IS NOT INITIAL
                                      THEN ls_org-issue_date ELSE ls_org-inv_date ).
      ENDIF.
    ENDIF.
    cs_request-invoice-adjust = ls_adj.

    " Đổi nghiệp vụ: tạo mới -> điều chỉnh / thay thế
    CASE cs_request-action.
      WHEN zif_hddt_types=>gc_action-create_invoice.
        cs_request-action = COND #( WHEN ls_adj-adj_type = zif_hddt_types=>gc_adj_type-replace
                                    THEN zif_hddt_types=>gc_action-replace_invoice
                                    ELSE zif_hddt_types=>gc_action-adjust_invoice ).
      WHEN zif_hddt_types=>gc_action-create_draft.
        zcx_hddt_error=>raise_text(
          |Chứng từ đã gắn hoá đơn gốc { ls_adj-org_docno ALPHA = OUT } - phát hành trực tiếp bằng nút "Phát hành HĐ", không qua nháp.| ).
      WHEN OTHERS.
    ENDCASE.

  ENDMETHOD.


  METHOD validate_request.

    IF i_action <> zif_hddt_types=>gc_action-create_invoice
       AND i_action <> zif_hddt_types=>gc_action-create_draft
       AND i_action <> zif_hddt_types=>gc_action-adjust_invoice
       AND i_action <> zif_hddt_types=>gc_action-replace_invoice.
      RETURN.
    ENDIF.
    DATA(lv_sw) = mo_config->get_param( i_key      = zif_hddt_types=>gc_parm-validate_req
                                        i_provider = is_request-provider
                                        i_bukrs    = is_request-bukrs ).
    TRANSLATE lv_sw TO UPPER CASE.
    IF lv_sw = 'N' OR lv_sw = 'OFF'.
      RETURN.
    ENDIF.

    DATA(ls_hdr) = is_request-invoice-header.
    DATA(ls_buy) = is_request-invoice-buyer.
    DATA lt_missing TYPE STANDARD TABLE OF string WITH EMPTY KEY.

    IF ls_hdr-inv_type IS INITIAL.
      APPEND `type (loại hoá đơn)` TO lt_missing.
    ENDIF.
    IF ls_hdr-template IS INITIAL.
      APPEND `form (mẫu số)` TO lt_missing.
    ENDIF.
    IF ls_hdr-serial IS INITIAL.
      APPEND `serial (ký hiệu)` TO lt_missing.
    ENDIF.
    IF ls_hdr-inv_date IS INITIAL.
      APPEND `idt (ngày hoá đơn)` TO lt_missing.
    ENDIF.
    IF ls_hdr-currency IS INITIAL.
      APPEND `curr (loại tiền)` TO lt_missing.
    ENDIF.
    IF ls_hdr-exch_rate <= 0.
      APPEND `exrate (tỷ giá)` TO lt_missing.
    ENDIF.
    IF ls_buy-legal_name IS INITIAL.
      APPEND `bname (tên người mua)` TO lt_missing.
    ENDIF.
    IF ls_buy-address IS INITIAL.
      APPEND `badd (địa chỉ người mua)` TO lt_missing.
    ENDIF.
    " MST bắt buộc với tổ chức; cá nhân/khách lẻ có thể thay bằng CCCD
    IF ls_buy-tax_code IS INITIAL AND ls_buy-id_number IS INITIAL
       AND ls_buy-one_time = abap_false.
      APPEND `btax (mã số thuế người mua)` TO lt_missing.
    ENDIF.
    IF is_request-invoice-payments IS INITIAL.
      APPEND `paym (hình thức thanh toán)` TO lt_missing.
    ENDIF.
    IF is_request-invoice-items IS INITIAL.
      APPEND `items (dòng hàng)` TO lt_missing.
    ENDIF.
    LOOP AT is_request-invoice-items ASSIGNING FIELD-SYMBOL(<fs_it>) WHERE item_type <> '3'.
      IF <fs_it>-item_name IS INITIAL.
        APPEND |items[{ <fs_it>-line_no }].name (tên hàng)| TO lt_missing.
      ENDIF.
    ENDLOOP.

    IF lt_missing IS NOT INITIAL.
      DATA(lv_list) = concat_lines_of( table = lt_missing sep = `, ` ).
      zcx_hddt_error=>raise_text( |Thiếu dữ liệu bắt buộc: { lv_list }| ).
    ENDIF.

  ENDMETHOD.


  METHOD post_success.

    " (1) HĐ điều chỉnh / thay thế thành công -> đổi trạng thái HĐ gốc
    IF i_action = zif_hddt_types=>gc_action-adjust_invoice.
      mo_log->mark_original( is_request = is_request
                             i_status   = zif_hddt_types=>gc_status-adjusted ).
    ELSEIF i_action = zif_hddt_types=>gc_action-replace_invoice.
      mo_log->mark_original( is_request = is_request
                             i_status   = zif_hddt_types=>gc_status-replaced ).
    ENDIF.

    " (2) Xoá nháp thành công -> về chưa tích hợp, xoá sid/số (FS 3.6.2)
    IF i_action = zif_hddt_types=>gc_action-delete_invoice.
      mo_log->reset_registry( is_request = is_request
                              i_message  = COND #( WHEN cs_result-message IS INITIAL
                                                   THEN `Đã huỷ hoá đơn nháp` ELSE cs_result-message ) ).
      cs_result-status = zif_hddt_types=>gc_status-not_sent.
      RETURN.
    ENDIF.

    " (3) Thay thế: NCC để hoá đơn ở "chờ duyệt" -> ký duyệt tiếp (FS 3.7.7)
    IF i_action = zif_hddt_types=>gc_action-replace_invoice
       AND mo_config->get_param_bool( i_key      = zif_hddt_types=>gc_parm-auto_appr_repl
                                      i_provider = i_provider
                                      i_bukrs    = is_request-bukrs ) = abap_true.
      DATA(ls_appr) = is_request.
      ls_appr-action = zif_hddt_types=>gc_action-approve_invoice.
      IF cs_result-idkey IS NOT INITIAL.
        ls_appr-invoice-header-idkey = cs_result-idkey.
      ENDIF.
      DATA(ls_r2) = execute( is_request = ls_appr i_commit = abap_false ).
      IF ls_r2-success = abap_true.
        ls_r2-message = |{ cs_result-message } / ký duyệt: { ls_r2-message }|.
        cs_result = ls_r2.
      ELSE.
        cs_result-message = |{ cs_result-message } / ký duyệt lỗi: { ls_r2-message }|.
        cs_result-msgty   = 'W'.
      ENDIF.
    ENDIF.

    " (4) Ghi ngược chứng từ nguồn (BKPF-XBLNR / XREF2_HD) khi đã có số HĐ
    DATA(lv_class) = mo_config->get_param( i_key      = zif_hddt_types=>gc_parm-writeback_class
                                           i_provider = i_provider
                                           i_bukrs    = is_request-bukrs ).
    CONDENSE lv_class.
    IF lv_class IS INITIAL OR is_request-src_docno IS INITIAL.
      RETURN.
    ENDIF.
    DATA(ls_reg) = zcl_hddt_log=>read_invoice( i_bukrs     = is_request-bukrs
                                               i_gjahr     = is_request-gjahr
                                               i_src_type  = is_request-src_type
                                               i_src_docno = is_request-src_docno ).
    IF ls_reg-seq IS INITIAL.
      RETURN.
    ENDIF.
    TRY.
        DATA(lo_wb) = CAST zif_hddt_writeback(
                        zcl_hddt_factory=>create_object( CONV #( lv_class ) ) ).
        lo_wb->write( is_request = is_request is_result = cs_result is_reg = ls_reg ).
      CATCH zcx_hddt_error INTO DATA(lx).
        cs_result-message = |{ cs_result-message } (Ghi ngược chứng từ lỗi: { lx->get_text_long( ) })|.
        cs_result-msgty   = 'W'.
      CATCH cx_sy_move_cast_error.
        cs_result-message = |{ cs_result-message } (Lớp { lv_class } không implement ZIF_HDDT_WRITEBACK)|.
        cs_result-msgty   = 'W'.
    ENDTRY.

  ENDMETHOD.


  METHOD derive_status.

    DATA lv_found TYPE abap_bool.

    " Ưu tiên bảng anh xạ cấu hình
    mo_config->map_status( EXPORTING i_provider = i_provider
                                     i_action   = i_action
                                     i_rc_code  = cs_result-prov_status
                           IMPORTING e_status   = DATA(lv_status)
                                     e_msgty    = DATA(lv_msgty)
                                     e_msg_text = DATA(lv_text)
                                     e_found    = lv_found ).

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
      IF i_http_code >= 200 AND i_http_code < 300
         AND cs_result-success = abap_true.
        CASE i_action.
          WHEN zif_hddt_types=>gc_action-cancel_invoice.
            cs_result-status = zif_hddt_types=>gc_status-cancelled.
          WHEN zif_hddt_types=>gc_action-adjust_invoice.
            cs_result-status = zif_hddt_types=>gc_status-adjusted.
          WHEN zif_hddt_types=>gc_action-replace_invoice.
            cs_result-status = zif_hddt_types=>gc_status-replaced.
          WHEN zif_hddt_types=>gc_action-delete_invoice.
            cs_result-status = zif_hddt_types=>gc_status-not_sent.
          WHEN zif_hddt_types=>gc_action-create_draft.
            cs_result-status = zif_hddt_types=>gc_status-wait_seq.
          WHEN zif_hddt_types=>gc_action-issue_invoice
            OR zif_hddt_types=>gc_action-approve_invoice.
            cs_result-status = COND #(
              WHEN cs_result-seq IS NOT INITIAL
              THEN zif_hddt_types=>gc_status-issued
              ELSE zif_hddt_types=>gc_status-wait_appr ).
          WHEN zif_hddt_types=>gc_action-create_invoice.
            cs_result-status = COND #(
              WHEN cs_result-seq IS NOT INITIAL
              THEN zif_hddt_types=>gc_status-issued
              ELSE zif_hddt_types=>gc_status-wait_seq ).
          WHEN OTHERS.
            cs_result-status = zif_hddt_types=>gc_status-sent.
        ENDCASE.
      ELSE.
        cs_result-status  = zif_hddt_types=>gc_status-error.
        cs_result-success = abap_false.
      ENDIF.
    ENDIF.

    IF cs_result-msgty IS INITIAL.
      cs_result-msgty = COND #( WHEN cs_result-success = abap_true
                                THEN 'S' ELSE 'E' ).
    ENDIF.

  ENDMETHOD.

ENDCLASS.
