*=====================================================================
* Tên/Mã     : ZFIC_HDDT_LOG
* Mô tả chung: Ghi log lời gọi API (ZFIT_HDDT_LOG) và cập nhật sổ đăng
*              ký hoá đơn (ZFIT_HDDT_INV + ZFIT_HDDT_ITEM).
*              Ghi log là NGHĨA VỤ THUẾ: phải lưu được payload đã gửi
*              và phản hồi của nhà cung cấp để đối chiếu khi có tranh
*              chấp. Có thể tắt lưu payload bằng tham số LOG_PAYLOAD
*              nếu dung lượng là vấn đề (mặc định: BẬT).
* Tham Số    : LOG_CALL / SAVE_INVOICE / SAVE_ITEMS
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       28/08/2026    cuongus - CuongUS        abapGit     Tạo mới
*=====================================================================
CLASS zfic_hddt_log DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    "! Ghi 1 dòng log; trả về LOG_ID để gắn vào kết quả.
    METHODS log_call
      IMPORTING is_request       TYPE zfiif_hddt_types=>ty_request
                iv_action       TYPE zfide_hddt_action
                is_conn         TYPE zfit_hddt_conn
                iv_method       TYPE zfide_hddt_method
                iv_full_url     TYPE string
                iv_request      TYPE string OPTIONAL
                iv_response     TYPE string OPTIONAL
                iv_http_code    TYPE i OPTIONAL
                iv_reason       TYPE string OPTIONAL
                iv_duration_ms  TYPE i OPTIONAL
                is_result       TYPE zfiif_hddt_types=>ty_result OPTIONAL
      RETURNING VALUE(rv_log_id) TYPE zfide_hddt_logid .

    "! Cập nhật sổ đăng ký hoá đơn từ request + result.
    METHODS save_invoice
      IMPORTING is_request TYPE zfiif_hddt_types=>ty_request
                is_result  TYPE zfiif_hddt_types=>ty_result
                iv_provider TYPE zfide_hddt_prov .

    METHODS save_items
      IMPORTING is_request TYPE zfiif_hddt_types=>ty_request .

    "! Đọc sổ đăng ký của 1 chứng từ (dùng cho điều chỉnh/thay thế).
    CLASS-METHODS read_invoice
      IMPORTING iv_bukrs      TYPE bukrs
                iv_gjahr      TYPE gjahr
                iv_src_type   TYPE zfide_hddt_srctype OPTIONAL
                iv_src_docno  TYPE zfide_hddt_docno
      RETURNING VALUE(rs_inv) TYPE zfit_hddt_inv .

  PROTECTED SECTION.
  PRIVATE SECTION.

    METHODS new_guid
      RETURNING VALUE(rv_guid) TYPE zfide_hddt_logid .

ENDCLASS.



CLASS zfic_hddt_log IMPLEMENTATION.

  METHOD new_guid.

    TRY.
        rv_guid = cl_system_uuid=>create_uuid_c32_static( ).
      CATCH cx_uuid_error.
        " Rất khó xảy ra; dự phòng bằng timestamp + số tuần tự phiên
        DATA lv_ts TYPE timestampl.
        GET TIME STAMP FIELD lv_ts.
        rv_guid = |{ lv_ts }{ sy-uname }|.
        TRANSLATE rv_guid TO UPPER CASE.
    ENDTRY.

  ENDMETHOD.


  METHOD log_call.

    DATA ls_log TYPE zfit_hddt_log.

    DATA(lo_config) = zfic_hddt_config=>get_instance( ).
    DATA(lv_keep_payload) = abap_true.

    " Tham số LOG_PAYLOAD chỉ có tác dụng TẮT khi được khai báo tường
    " minh — mặc định luôn lưu để bảo đảm khả năng đối chiếu.
    IF lo_config->get_param( iv_key      = zfiif_hddt_types=>gc_parm-log_payload
                             iv_provider = is_conn-provider
                             iv_bukrs    = is_request-bukrs ) IS NOT INITIAL.
      lv_keep_payload = lo_config->get_param_bool(
                          iv_key      = zfiif_hddt_types=>gc_parm-log_payload
                          iv_provider = is_conn-provider
                          iv_bukrs    = is_request-bukrs ).
    ENDIF.

    rv_log_id = new_guid( ).

    ls_log-log_id      = rv_log_id.
    ls_log-provider    = is_conn-provider.
    ls_log-connid      = is_conn-connid.
    ls_log-action      = iv_action.
    ls_log-bukrs       = is_request-bukrs.
    ls_log-gjahr       = is_request-gjahr.
    ls_log-src_type    = is_request-src_type.
    ls_log-src_docno   = is_request-src_docno.
    ls_log-idkey       = is_request-invoice-header-idkey.
    ls_log-http_method = iv_method.
    ls_log-full_url    = iv_full_url.
    ls_log-http_code   = iv_http_code.
    ls_log-http_reason = iv_reason.
    ls_log-duration_ms = iv_duration_ms.
    ls_log-msgty       = is_result-msgty.
    ls_log-message     = is_result-message.
    ls_log-created_by  = sy-uname.
    GET TIME STAMP FIELD ls_log-created_at.

    IF lv_keep_payload = abap_true.
      ls_log-req_body = iv_request.
      ls_log-res_body = iv_response.
    ENDIF.

    INSERT zfit_hddt_log FROM ls_log.
    IF sy-subrc <> 0.
      " Không được để lỗi ghi log làm hỏng nghiệp vụ phát hành
      CLEAR rv_log_id.
    ENDIF.

  ENDMETHOD.


  METHOD save_invoice.

    DATA ls_inv TYPE zfit_hddt_inv.

    SELECT SINGLE * FROM zfit_hddt_inv
      INTO @ls_inv
      WHERE bukrs     = @is_request-bukrs
        AND gjahr     = @is_request-gjahr
        AND src_type  = @is_request-src_type
        AND src_docno = @is_request-src_docno.
    DATA(lv_exists) = xsdbool( sy-subrc = 0 ).

    IF lv_exists = abap_false.
      ls_inv-bukrs      = is_request-bukrs.
      ls_inv-gjahr      = is_request-gjahr.
      ls_inv-src_type   = is_request-src_type.
      ls_inv-src_docno  = is_request-src_docno.
      ls_inv-created_by = sy-uname.
      GET TIME STAMP FIELD ls_inv-created_at.
    ENDIF.

    DATA(ls_hdr) = is_request-invoice-header.
    DATA(ls_buy) = is_request-invoice-buyer.
    DATA(ls_sum) = is_request-invoice-summary.

    ls_inv-provider     = iv_provider.
    ls_inv-idkey        = ls_hdr-idkey.
    ls_inv-inv_type     = ls_hdr-inv_type.
    ls_inv-inv_date     = ls_hdr-inv_date.
    ls_inv-inv_time     = ls_hdr-inv_time.
    ls_inv-waers        = ls_hdr-currency.
    ls_inv-exrate       = ls_hdr-exch_rate.
    ls_inv-adj_type     = is_request-invoice-adjust-adj_type.
    ls_inv-ref_docno    = is_request-invoice-adjust-org_idkey.
    ls_inv-supp_taxcode = is_request-invoice-seller-tax_code.

    ls_inv-buyer_code = ls_buy-code.
    ls_inv-buyer_name = ls_buy-legal_name.
    ls_inv-buyer_tax  = ls_buy-tax_code.
    ls_inv-buyer_addr = ls_buy-address.
    ls_inv-buyer_mail = ls_buy-email.

    ls_inv-amount     = ls_sum-amount_wo_tax.
    ls_inv-vat_amount = ls_sum-tax_amount.
    ls_inv-total      = ls_sum-total.

    " Chỉ ghi đè các trường do nhà cung cấp trả về khi thực sự có giá
    " trị, để lần gọi lỗi không xoá mất số hoá đơn đã cấp trước đó.
    IF is_result-template IS NOT INITIAL.
      ls_inv-template = is_result-template.
    ELSEIF ls_inv-template IS INITIAL.
      ls_inv-template = ls_hdr-template.
    ENDIF.
    IF is_result-serial IS NOT INITIAL.
      ls_inv-serial = is_result-serial.
    ELSEIF ls_inv-serial IS INITIAL.
      ls_inv-serial = ls_hdr-serial.
    ENDIF.
    IF is_result-seq IS NOT INITIAL.
      ls_inv-seq = is_result-seq.
    ENDIF.
    IF is_result-issue_date IS NOT INITIAL.
      ls_inv-issue_date = is_result-issue_date.
    ENDIF.
    IF is_result-mscqt IS NOT INITIAL.
      ls_inv-mscqt = is_result-mscqt.
    ENDIF.
    IF is_result-sec_code IS NOT INITIAL.
      ls_inv-sec_code = is_result-sec_code.
    ENDIF.
    IF is_result-inv_link IS NOT INITIAL.
      ls_inv-inv_link = is_result-inv_link.
    ENDIF.

    ls_inv-status      = is_result-status.
    ls_inv-prov_status = is_result-prov_status.
    ls_inv-message     = is_result-message.

    IF is_result-status = zfiif_hddt_types=>gc_status-cancelled.
      ls_inv-cancel_date = sy-datum.
    ENDIF.

    ls_inv-changed_by = sy-uname.
    GET TIME STAMP FIELD ls_inv-changed_at.

    MODIFY zfit_hddt_inv FROM ls_inv.

  ENDMETHOD.


  METHOD save_items.

    DATA lt_item TYPE STANDARD TABLE OF zfit_hddt_item WITH EMPTY KEY.

    DELETE FROM zfit_hddt_item
      WHERE bukrs     = @is_request-bukrs
        AND gjahr     = @is_request-gjahr
        AND src_type  = @is_request-src_type
        AND src_docno = @is_request-src_docno.

    LOOP AT is_request-invoice-items ASSIGNING FIELD-SYMBOL(<ls_src>).
      APPEND VALUE #( bukrs      = is_request-bukrs
                      gjahr      = is_request-gjahr
                      src_type   = is_request-src_type
                      src_docno  = is_request-src_docno
                      line_no    = <ls_src>-line_no
                      item_code  = <ls_src>-item_code
                      item_name  = <ls_src>-item_name
                      item_type  = <ls_src>-item_type
                      unit       = <ls_src>-unit
                      quantity   = <ls_src>-quantity
                      price      = <ls_src>-price
                      amount     = <ls_src>-amount
                      tax_rate   = <ls_src>-tax_rate
                      tax_amount = <ls_src>-tax_amount
                      total      = <ls_src>-total
                      disc_pct   = <ls_src>-disc_percent
                      disc_amt   = <ls_src>-disc_amount
                      note       = <ls_src>-note ) TO lt_item.
    ENDLOOP.

    IF lt_item IS NOT INITIAL.
      INSERT zfit_hddt_item FROM TABLE @lt_item.
    ENDIF.

  ENDMETHOD.


  METHOD read_invoice.

    IF iv_src_type IS NOT INITIAL.
      SELECT SINGLE * FROM zfit_hddt_inv
        INTO @rs_inv
        WHERE bukrs     = @iv_bukrs
          AND gjahr     = @iv_gjahr
          AND src_type  = @iv_src_type
          AND src_docno = @iv_src_docno.
    ELSE.
      SELECT SINGLE * FROM zfit_hddt_inv
        INTO @rs_inv
        WHERE bukrs     = @iv_bukrs
          AND gjahr     = @iv_gjahr
          AND src_docno = @iv_src_docno.
    ENDIF.

    IF sy-subrc <> 0.
      CLEAR rs_inv.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
