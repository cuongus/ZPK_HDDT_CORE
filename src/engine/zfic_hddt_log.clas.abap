*=====================================================================
* Tên/Mã     : ZFIC_HDDT_LOG
* Mô tả chung: Ghi log lời gọi API (ZFIT_HDDT_LOG) và cập nhật sổ đăng
*              ký hoá đơn (ZFIT_HDDT_INV + ZFIT_HDDT_ITEM).
*
*              [Vì sao lưu payload dạng XSTRING chứ không phải STRING]
*              Log HĐĐT là bằng chứng đối chiếu với cơ quan thuế và với
*              nhà cung cấp khi có tranh chấp. XSTRING lưu ĐÚNG TỪNG
*              BYTE đã đi trên đường truyền — kể cả cách encode UTF-8
*              của tiếng Việt — nên không có một lượt chuyển codepage
*              nào chen vào giữa "cái đã gửi" và "cái đã lưu".
*              Trường CODEPAGE ghi lại bảng mã đã dùng để giải mã lại
*              đúng khi xem log.
*              (Ghi chú: field kiểu STRING trong bảng DDIC KHÔNG bị
*              giới hạn độ dài — nó là LOB. Việc đổi sang xstring ở đây
*              là vì tính toàn vẹn byte, không phải vì giới hạn độ dài.)
*
*              [Che secret — BẮT BUỘC]
*              Payload của một số nhà cung cấp chứa tài khoản NGAY
*              TRONG BODY: FPT có nút "user":{"username","password"},
*              VNPT có "acpass". Nếu ghi nguyên văn thì mật khẩu API
*              nằm plaintext trong bảng log, ai đọc được bảng là đọc
*              được mật khẩu. Lớp này che TRƯỚC khi ghi, cả body lẫn
*              header Authorization. Danh sách thẻ cần che khai được
*              trong ZFIT_HDDT_PARM key LOG_MASK_TAGS.
* Tham Số    : LOG_CALL / SAVE_INVOICE / SAVE_ITEMS / READ_PAYLOAD
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       28/08/2026    cuongus - CuongUS        abapGit     Tạo mới
* 1.1       28/08/2026    cuongus - CuongUS        abapGit     20260828_01 Lưu
*                                                             payload dạng
*                                                             xstring, che
*                                                             secret, bổ sung
*                                                             field truy vết
*=====================================================================
CLASS zfic_hddt_log DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    CONSTANTS gc_parm_mask_tags TYPE zfide_hddt_parmkey
                                VALUE 'LOG_MASK_TAGS' ##NO_TEXT.
    CONSTANTS gc_codepage       TYPE zfide_hddt_codepage
                                VALUE 'UTF-8' ##NO_TEXT.
    CONSTANTS gc_mask           TYPE string
                                VALUE '********' ##NO_TEXT.

    "! Thông tin kỹ thuật của một lần gọi, gom lại để chữ ký method
    "! không phình ra 20 tham số.
    TYPES: BEGIN OF ty_call_info,
             connid      TYPE zfide_hddt_connid,
             method      TYPE zfide_hddt_method,
             full_url    TYPE zfide_hddt_url,
             cont_type   TYPE zfide_hddt_parmval,
             http_code   TYPE i,
             reason      TYPE string,
             duration_ms TYPE i,
             attempt     TYPE zfide_hddt_attempt,
             test_run    TYPE abap_bool,
             req_body    TYPE string,
             res_body    TYPE string,
             req_header  TYPE string,
             res_header  TYPE string,
           END OF ty_call_info.

    "! Nội dung log đã giải mã lại thành text, dùng cho màn hình xem log.
    TYPES: BEGIN OF ty_payload,
             log_id     TYPE zfide_hddt_logid,
             codepage   TYPE zfide_hddt_codepage,
             req_header TYPE string,
             res_header TYPE string,
             req_body   TYPE string,
             res_body   TYPE string,
           END OF ty_payload.

    "! Ghi 1 dòng log; trả về LOG_ID để gắn vào kết quả.
    METHODS log_call
      IMPORTING is_request       TYPE zfiif_hddt_types=>ty_request
                iv_action        TYPE zfide_hddt_action
                iv_provider      TYPE zfide_hddt_prov
                is_call          TYPE ty_call_info
                is_result        TYPE zfiif_hddt_types=>ty_result OPTIONAL
      RETURNING VALUE(rv_log_id) TYPE zfide_hddt_logid .

    "! Đọc lại payload của một dòng log và giải mã về text.
    CLASS-METHODS read_payload
      IMPORTING iv_log_id         TYPE zfide_hddt_logid
      RETURNING VALUE(rs_payload) TYPE ty_payload .

    METHODS save_invoice
      IMPORTING is_request  TYPE zfiif_hddt_types=>ty_request
                is_result   TYPE zfiif_hddt_types=>ty_result
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

    "! Đếm số lần đã gọi cho cùng chứng từ + nghiệp vụ, để điền ATTEMPT.
    CLASS-METHODS count_attempts
      IMPORTING is_request      TYPE zfiif_hddt_types=>ty_request
                iv_action       TYPE zfide_hddt_action
      RETURNING VALUE(rv_count) TYPE zfide_hddt_attempt .

    "! Che secret trong text. Public để màn hình xem log dùng lại được
    "! khi hiển thị dữ liệu từ nguồn khác (ví dụ payload test run).
    CLASS-METHODS mask_secrets
      IMPORTING iv_text        TYPE string
      RETURNING VALUE(rv_text) TYPE string .

  PROTECTED SECTION.
  PRIVATE SECTION.

    "! Thẻ mặc định cần che nếu chưa khai LOG_MASK_TAGS.
    "! Gồm cả tên thẻ của FPT (password), VNPT (acpass) và chuẩn OAuth.
    CONSTANTS gc_default_tags TYPE string
      VALUE 'password,acpass,pass,secret,client_secret,token,access_token,authorization,apikey,api_key' ##NO_TEXT.

    METHODS new_guid
      RETURNING VALUE(rv_guid) TYPE zfide_hddt_logid .

    METHODS to_raw
      IMPORTING iv_text        TYPE string
      RETURNING VALUE(rv_data) TYPE xstring .

    METHODS keep_payload
      IMPORTING iv_provider    TYPE zfide_hddt_prov
                iv_bukrs       TYPE bukrs
      RETURNING VALUE(rv_keep) TYPE abap_bool .

ENDCLASS.



CLASS zfic_hddt_log IMPLEMENTATION.

  METHOD new_guid.

    TRY.
        rv_guid = cl_system_uuid=>create_uuid_c32_static( ).
      CATCH cx_uuid_error.
        " Rất khó xảy ra; dự phòng bằng timestamp + user
        DATA lv_ts TYPE timestampl.
        GET TIME STAMP FIELD lv_ts.
        rv_guid = |{ lv_ts }{ sy-uname }|.
        TRANSLATE rv_guid TO UPPER CASE.
    ENDTRY.

  ENDMETHOD.


  METHOD mask_secrets.

    rv_text = iv_text.
    IF rv_text IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lv_tags) = |{ zfic_hddt_config=>get_instance( )->get_param( gc_parm_mask_tags ) }|.
    CONDENSE lv_tags NO-GAPS.
    IF lv_tags IS INITIAL.
      lv_tags = gc_default_tags.
    ENDIF.

    SPLIT lv_tags AT ',' INTO TABLE DATA(lt_tags).

    LOOP AT lt_tags INTO DATA(lv_tag).
      CONDENSE lv_tag NO-GAPS.
      IF lv_tag IS INITIAL.
        CONTINUE.
      ENDIF.

      " (1) JSON:  "password" : "gia tri"   ->  "password":"********"
      REPLACE ALL OCCURRENCES OF REGEX
              |"{ lv_tag }"\\s*:\\s*"[^"]*"|
              IN rv_text WITH |"{ lv_tag }":"{ gc_mask }"| IGNORING CASE.

      " (2) JSON số / không ngoặc kép: "token": abc123
      REPLACE ALL OCCURRENCES OF REGEX
              |"{ lv_tag }"\\s*:\\s*[^",\{\}\\[\\]]+|
              IN rv_text WITH |"{ lv_tag }":"{ gc_mask }"| IGNORING CASE.

      " (3) form-urlencoded:  password=abc&  ->  password=********&
      REPLACE ALL OCCURRENCES OF REGEX
              |(^\|&){ lv_tag }=[^&]*|
              IN rv_text WITH |$1{ lv_tag }={ gc_mask }| IGNORING CASE.

      " (4) HTTP header:  Authorization: Basic xxx  ->  Authorization: ********
      REPLACE ALL OCCURRENCES OF REGEX
              |(^\|\\n){ lv_tag }\\s*:\\s*[^\\n]*|
              IN rv_text WITH |$1{ lv_tag }: { gc_mask }| IGNORING CASE.
    ENDLOOP.

  ENDMETHOD.


  METHOD to_raw.

    IF iv_text IS INITIAL.
      RETURN.
    ENDIF.
    rv_data = zfic_hddt_platform=>get( )->string_to_xstring(
                iv_text     = iv_text
                iv_encoding = CONV string( gc_codepage ) ).

  ENDMETHOD.


  METHOD keep_payload.

    DATA(lo_config) = zfic_hddt_config=>get_instance( ).

    " Mặc định LUÔN lưu payload — đây là nghĩa vụ đối chiếu thuế.
    " Chỉ tắt khi tham số LOG_PAYLOAD được khai tường minh là false.
    rv_keep = abap_true.

    IF lo_config->get_param( iv_key      = zfiif_hddt_types=>gc_parm-log_payload
                             iv_provider = iv_provider
                             iv_bukrs    = iv_bukrs ) IS NOT INITIAL.
      rv_keep = lo_config->get_param_bool(
                  iv_key      = zfiif_hddt_types=>gc_parm-log_payload
                  iv_provider = iv_provider
                  iv_bukrs    = iv_bukrs ).
    ENDIF.

  ENDMETHOD.


  METHOD count_attempts.

    SELECT COUNT( * )
      FROM zfit_hddt_log
      INTO @DATA(lv_count)
      WHERE bukrs     = @is_request-bukrs
        AND gjahr     = @is_request-gjahr
        AND src_type  = @is_request-src_type
        AND src_docno = @is_request-src_docno
        AND action    = @iv_action
        AND test_run  = @space.

    rv_count = lv_count + 1.

  ENDMETHOD.


  METHOD log_call.

    DATA ls_log TYPE zfit_hddt_log.

    rv_log_id = new_guid( ).

    ls_log-log_id      = rv_log_id.
    ls_log-provider    = iv_provider.
    ls_log-connid      = is_call-connid.
    ls_log-action      = iv_action.
    ls_log-bukrs       = is_request-bukrs.
    ls_log-gjahr       = is_request-gjahr.
    ls_log-src_type    = is_request-src_type.
    ls_log-src_docno   = is_request-src_docno.
    ls_log-idkey       = is_request-invoice-header-idkey.
    ls_log-test_run    = is_call-test_run.
    ls_log-attempt     = is_call-attempt.

    ls_log-serial      = is_result-serial.
    ls_log-seq         = is_result-seq.
    ls_log-sap_status  = is_result-status.
    ls_log-prov_status = is_result-prov_status.
    ls_log-msgty       = is_result-msgty.
    ls_log-message     = is_result-message.

    ls_log-http_method = is_call-method.
    ls_log-full_url    = is_call-full_url.
    ls_log-cont_type   = is_call-cont_type.
    ls_log-http_code   = is_call-http_code.
    ls_log-http_reason = is_call-reason.
    ls_log-duration_ms = is_call-duration_ms.

    " Kích thước tính theo SỐ BYTE thật đã ghi, không phải số ký tự
    ls_log-codepage    = gc_codepage.

    " Truy vết nguồn gọi: giúp phân biệt phát hành từ màn hình, từ job
    " nền hay từ enhancement khi cùng một chứng từ có nhiều dòng log.
    ls_log-caller      = sy-cprog.
    ls_log-tcode       = sy-tcode.
    ls_log-created_by  = sy-uname.
    GET TIME STAMP FIELD ls_log-created_at.

    IF keep_payload( iv_provider = iv_provider
                     iv_bukrs    = is_request-bukrs ) = abap_true.

      " Che secret TRƯỚC khi ghi. Payload FPT/VNPT chứa mật khẩu ngay
      " trong body; header có Authorization.
      DATA(lv_req) = mask_secrets( is_call-req_body ).
      DATA(lv_res) = mask_secrets( is_call-res_body ).

      ls_log-req_header = to_raw( mask_secrets( is_call-req_header ) ).
      ls_log-res_header = to_raw( mask_secrets( is_call-res_header ) ).
      ls_log-req_body   = to_raw( lv_req ).
      ls_log-res_body   = to_raw( lv_res ).
      ls_log-req_size   = xstrlen( ls_log-req_body ).
      ls_log-res_size   = xstrlen( ls_log-res_body ).
      ls_log-masked     = xsdbool( lv_req <> is_call-req_body
                                OR lv_res <> is_call-res_body ).
    ELSE.
      " Không lưu nội dung nhưng VẪN ghi kích thước để biết đã gửi gì
      ls_log-req_size = strlen( is_call-req_body ).
      ls_log-res_size = strlen( is_call-res_body ).
    ENDIF.

    INSERT zfit_hddt_log FROM ls_log.
    IF sy-subrc <> 0.
      " Không được để lỗi ghi log làm hỏng nghiệp vụ phát hành
      CLEAR rv_log_id.
    ENDIF.

  ENDMETHOD.


  METHOD read_payload.

    SELECT SINGLE log_id, codepage, req_header, res_header, req_body, res_body
      FROM zfit_hddt_log
      INTO @DATA(ls_db)
      WHERE log_id = @iv_log_id.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    DATA(lo_plat) = zfic_hddt_platform=>get( ).
    DATA(lv_cp)   = |{ ls_db-codepage }|.
    CONDENSE lv_cp.
    IF lv_cp IS INITIAL.
      lv_cp = |{ gc_codepage }|.
    ENDIF.

    rs_payload-log_id     = ls_db-log_id.
    rs_payload-codepage   = ls_db-codepage.
    rs_payload-req_header = lo_plat->xstring_to_string( iv_data     = ls_db-req_header
                                                        iv_encoding = lv_cp ).
    rs_payload-res_header = lo_plat->xstring_to_string( iv_data     = ls_db-res_header
                                                        iv_encoding = lv_cp ).
    rs_payload-req_body   = lo_plat->xstring_to_string( iv_data     = ls_db-req_body
                                                        iv_encoding = lv_cp ).
    rs_payload-res_body   = lo_plat->xstring_to_string( iv_data     = ls_db-res_body
                                                        iv_encoding = lv_cp ).

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
