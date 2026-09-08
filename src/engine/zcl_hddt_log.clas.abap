*=====================================================================
* Tên/Mã     : ZCL_HDDT_LOG
* Mô tả chung: Ghi log lời gọi API (ZTB_HDDT_LOG) và cập nhật sổ đăng
*              ký hoá đơn (ZTB_HDDT_INV + ZTB_HDDT_ITEM).
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
*              trong ZTB_HDDT_PARM key LOG_MASK_TAGS.
* Tham Số    : LOG_CALL / SAVE_INVOICE / SAVE_ITEMS / READ_PAYLOAD
* Kiểu       : TY_PAYLOAD - nội dung log đã giải mã lại thành text,
*              dùng cho màn hình xem log.
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
CLASS zcl_hddt_log DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    CONSTANTS gc_parm_mask_tags TYPE zde_hddt_parmkey
                                VALUE 'LOG_MASK_TAGS' ##NO_TEXT.
    CONSTANTS gc_codepage       TYPE zde_hddt_codepage
                                VALUE 'UTF-8' ##NO_TEXT.
    CONSTANTS gc_mask           TYPE string
                                VALUE '********' ##NO_TEXT.

    TYPES: BEGIN OF ty_call_info,
             connid      TYPE zde_hddt_connid,
             method      TYPE zde_hddt_method,
             full_url    TYPE zde_hddt_url,
             cont_type   TYPE zde_hddt_parmval,
             http_code   TYPE i,
             reason      TYPE string,
             duration_ms TYPE i,
             attempt     TYPE zde_hddt_attempt,
             test_run    TYPE abap_bool,
             req_body    TYPE string,
             res_body    TYPE string,
             req_header  TYPE string,
             res_header  TYPE string,
           END OF ty_call_info.

    TYPES: BEGIN OF ty_payload,
             log_id     TYPE zde_hddt_logid,
             codepage   TYPE zde_hddt_codepage,
             req_header TYPE string,
             res_header TYPE string,
             req_body   TYPE string,
             res_body   TYPE string,
           END OF ty_payload.

    "! Ghi 1 dòng log; trả về LOG_ID để gắn vào kết quả.
    METHODS log_call
      IMPORTING is_request       TYPE zif_hddt_types=>ty_request
                i_action        TYPE zde_hddt_action
                i_provider      TYPE zde_hddt_prov
                is_call          TYPE ty_call_info
                is_result        TYPE zif_hddt_types=>ty_result OPTIONAL
      RETURNING VALUE(r_log_id) TYPE zde_hddt_logid .

    "! Đọc lại payload của một dòng log và giải mã về text.
    CLASS-METHODS read_payload
      IMPORTING i_log_id         TYPE zde_hddt_logid
      RETURNING VALUE(rs_payload) TYPE ty_payload .

    METHODS save_invoice
      IMPORTING is_request  TYPE zif_hddt_types=>ty_request
                is_result   TYPE zif_hddt_types=>ty_result
                i_provider TYPE zde_hddt_prov .

    METHODS save_items
      IMPORTING is_request TYPE zif_hddt_types=>ty_request .

    "! Đọc sổ đăng ký của 1 chứng từ (dùng cho điều chỉnh/thay thế).
    "! Đánh dấu hoá đơn GỐC đã bị điều chỉnh / thay thế sau khi HĐ điều
    "! chỉnh phát hành thành công (dự án tham chiếu ghi XREF2_HD 06/07).
    METHODS mark_original
      IMPORTING is_request TYPE zif_hddt_types=>ty_request
                i_status  TYPE zde_hddt_status .

    "! FS MAG: đánh dấu chứng từ thành viên thuộc hoá đơn gom (trống = gỡ)
    METHODS set_gom_no
      IMPORTING is_request TYPE zif_hddt_types=>ty_request
                i_gom_no   TYPE zde_hddt_docno .

    "! FS MAG: người dùng sửa ngày/giờ phát hành, tên hàng trước khi gửi
    METHODS save_edit
      IMPORTING is_request  TYPE zif_hddt_types=>ty_request
                i_inv_date  TYPE dats
                i_inv_time  TYPE uzeit
                i_item_text TYPE string .

    "! FS MAG 3.6.4: gắn (hoặc gỡ khi docno trống) hoá đơn gốc cho chứng từ
    METHODS attach_original
      IMPORTING is_request    TYPE zif_hddt_types=>ty_request
                i_org_docno   TYPE zde_hddt_docno
                i_org_gjahr   TYPE gjahr
                i_org_srctype TYPE zde_hddt_srctype
                i_adj_type    TYPE zde_hddt_adjtype
                i_adj_dir     TYPE zde_hddt_adjdir .

    METHODS set_mail_status
      IMPORTING is_request TYPE zif_hddt_types=>ty_request
                i_status   TYPE zde_hddt_mailst .

    "! Đưa chứng từ về 'chưa tích hợp' (huỷ nháp thành công / NCC không
    "! còn hoá đơn): xoá số, ký hiệu, link, trạng thái NCC.
    METHODS reset_registry
      IMPORTING is_request TYPE zif_hddt_types=>ty_request
                i_message  TYPE string OPTIONAL .

    CLASS-METHODS read_invoice
      IMPORTING i_bukrs      TYPE bukrs
                i_gjahr      TYPE gjahr
                i_src_type   TYPE zde_hddt_srctype OPTIONAL
                i_src_docno  TYPE zde_hddt_docno
      RETURNING VALUE(rs_inv) TYPE ztb_hddt_inv .

    "! Đếm số lần đã gọi cho cùng chứng từ + nghiệp vụ, để điền ATTEMPT.
    CLASS-METHODS count_attempts
      IMPORTING is_request      TYPE zif_hddt_types=>ty_request
                i_action       TYPE zde_hddt_action
      RETURNING VALUE(r_count) TYPE zde_hddt_attempt .

    "! Che secret trong text. Public để màn hình xem log dùng lại được
    "! khi hiển thị dữ liệu từ nguồn khác (ví dụ payload test run).
    CLASS-METHODS mask_secrets
      IMPORTING i_text        TYPE string
      RETURNING VALUE(r_text) TYPE string .

  PROTECTED SECTION.
  PRIVATE SECTION.

    "! Thẻ mặc định cần che nếu chưa khai LOG_MASK_TAGS.
    "! Gồm cả tên thẻ của FPT (password), VNPT (acpass) và chuẩn OAuth.
    CONSTANTS gc_default_tags TYPE string
      VALUE 'password,acpass,pass,secret,client_secret,token,access_token,authorization,apikey,api_key' ##NO_TEXT.

    METHODS new_guid
      RETURNING VALUE(r_guid) TYPE zde_hddt_logid .

    METHODS to_raw
      IMPORTING i_text        TYPE string
      RETURNING VALUE(r_data) TYPE xstring .

    "! Đọc dòng sổ, tạo dòng tối thiểu nếu chưa có
    METHODS ensure_row
      IMPORTING is_request    TYPE zif_hddt_types=>ty_request
      RETURNING VALUE(rs_inv) TYPE ztb_hddt_inv .

    METHODS object_type_of
      IMPORTING i_action      TYPE zde_hddt_action
                is_request    TYPE zif_hddt_types=>ty_request
      RETURNING VALUE(r_type) TYPE zde_hddt_objtype .

    METHODS call_sink
      IMPORTING is_log     TYPE ztb_hddt_log
                is_request TYPE zif_hddt_types=>ty_request
                is_result  TYPE zif_hddt_types=>ty_result .

    METHODS keep_payload
      IMPORTING i_provider    TYPE zde_hddt_prov
                i_bukrs       TYPE bukrs
      RETURNING VALUE(r_keep) TYPE abap_bool .

ENDCLASS.



CLASS zcl_hddt_log IMPLEMENTATION.

  METHOD new_guid.

    TRY.
        r_guid = cl_system_uuid=>create_uuid_c32_static( ).
      CATCH cx_uuid_error.
        " Rất khó xảy ra; dự phòng bằng timestamp + user
        DATA lv_ts TYPE timestampl.
        GET TIME STAMP FIELD lv_ts.
        r_guid = |{ lv_ts }{ sy-uname }|.
        TRANSLATE r_guid TO UPPER CASE.
    ENDTRY.

  ENDMETHOD.


  METHOD mask_secrets.

    r_text = i_text.
    IF r_text IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lv_tags) = |{ zcl_hddt_config=>get_instance( )->get_param( gc_parm_mask_tags ) }|.
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
      REPLACE ALL OCCURRENCES OF PCRE
              |"{ lv_tag }"\\s*:\\s*"[^"]*"|
              IN r_text WITH |"{ lv_tag }":"{ gc_mask }"| IGNORING CASE.

      " (2) JSON số / không ngoặc kép: "token": abc123
      REPLACE ALL OCCURRENCES OF PCRE
              |"{ lv_tag }"\\s*:\\s*[^",\{\}\\[\\]]+|
              IN r_text WITH |"{ lv_tag }":"{ gc_mask }"| IGNORING CASE.

      " (3) form-urlencoded:  password=abc&  ->  password=********&
      REPLACE ALL OCCURRENCES OF PCRE
              |(^\|&){ lv_tag }=[^&]*|
              IN r_text WITH |$1{ lv_tag }={ gc_mask }| IGNORING CASE.

      " (4) HTTP header:  Authorization: Basic xxx  ->  Authorization: ********
      REPLACE ALL OCCURRENCES OF PCRE
              |(^\|\\n){ lv_tag }\\s*:\\s*[^\\n]*|
              IN r_text WITH |$1{ lv_tag }: { gc_mask }| IGNORING CASE.
    ENDLOOP.

  ENDMETHOD.


  METHOD to_raw.

    IF i_text IS INITIAL.
      RETURN.
    ENDIF.
    r_data = zcl_hddt_platform=>get( )->string_to_xstring(
                i_text     = i_text
                i_encoding = CONV string( gc_codepage ) ).

  ENDMETHOD.


  METHOD keep_payload.

    DATA(lo_config) = zcl_hddt_config=>get_instance( ).

    " Mặc định LUÔN lưu payload — đây là nghĩa vụ đối chiếu thuế.
    " Chỉ tắt khi tham số LOG_PAYLOAD được khai tường minh là false.
    r_keep = abap_true.

    IF lo_config->get_param( i_key      = zif_hddt_types=>gc_parm-log_payload
                             i_provider = i_provider
                             i_bukrs    = i_bukrs ) IS NOT INITIAL.
      r_keep = lo_config->get_param_bool(
                  i_key      = zif_hddt_types=>gc_parm-log_payload
                  i_provider = i_provider
                  i_bukrs    = i_bukrs ).
    ENDIF.

  ENDMETHOD.


  METHOD count_attempts.

    SELECT COUNT( * )
      FROM ztb_hddt_log
      WHERE bukrs     = @is_request-bukrs
        AND gjahr     = @is_request-gjahr
        AND src_type  = @is_request-src_type
        AND src_docno = @is_request-src_docno
        AND action    = @i_action
        AND test_run  = @space
      INTO @DATA(lv_count).

    r_count = lv_count + 1.

  ENDMETHOD.


  METHOD log_call.

    DATA ls_log TYPE ztb_hddt_log.

    r_log_id = new_guid( ).

    ls_log-log_id      = r_log_id.
    ls_log-provider    = i_provider.
    ls_log-connid      = is_call-connid.
    ls_log-action      = i_action.
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

    " FS MAG: các trường khớp bảng log dùng chung ZTB_INT_LOG
    ls_log-direction   = 'O'.
    ls_log-object_type = object_type_of( i_action = i_action is_request = is_request ).
    ls_log-api_version = zcl_hddt_config=>get_instance( )->get_param(
                           i_key = zif_hddt_types=>gc_parm-api_version
                           i_provider = i_provider i_bukrs = is_request-bukrs ).
    ls_log-success     = is_result-success.
    IF is_result-success = abap_false.
      ls_log-error_code = is_result-prov_status.
    ENDIF.
    ls_log-hostname    = sy-host.
    ls_log-has_req     = xsdbool( is_call-req_body IS NOT INITIAL ).
    ls_log-has_res     = xsdbool( is_call-res_body IS NOT INITIAL ).

    IF keep_payload( i_provider = i_provider
                     i_bukrs    = is_request-bukrs ) = abap_true.

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

    INSERT ztb_hddt_log FROM ls_log.
    IF sy-subrc <> 0.
      " Không được để lỗi ghi log làm hỏng nghiệp vụ phát hành
      CLEAR r_log_id.
      RETURN.
    ENDIF.

    call_sink( is_log = ls_log is_request = is_request is_result = is_result ).

  ENDMETHOD.


  METHOD read_payload.

    SELECT SINGLE log_id, codepage, req_header, res_header, req_body, res_body
      FROM ztb_hddt_log
      WHERE log_id = @i_log_id
      INTO @DATA(ls_db).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    DATA(lo_plat) = zcl_hddt_platform=>get( ).
    DATA(lv_cp)   = |{ ls_db-codepage }|.
    CONDENSE lv_cp.
    IF lv_cp IS INITIAL.
      lv_cp = |{ gc_codepage }|.
    ENDIF.

    rs_payload-log_id     = ls_db-log_id.
    rs_payload-codepage   = ls_db-codepage.
    rs_payload-req_header = lo_plat->xstring_to_string( i_data     = ls_db-req_header
                                                        i_encoding = lv_cp ).
    rs_payload-res_header = lo_plat->xstring_to_string( i_data     = ls_db-res_header
                                                        i_encoding = lv_cp ).
    rs_payload-req_body   = lo_plat->xstring_to_string( i_data     = ls_db-req_body
                                                        i_encoding = lv_cp ).
    rs_payload-res_body   = lo_plat->xstring_to_string( i_data     = ls_db-res_body
                                                        i_encoding = lv_cp ).

  ENDMETHOD.


  METHOD save_invoice.

    DATA ls_inv TYPE ztb_hddt_inv.

    SELECT SINGLE * FROM ztb_hddt_inv
      WHERE bukrs     = @is_request-bukrs
        AND gjahr     = @is_request-gjahr
        AND src_type  = @is_request-src_type
        AND src_docno = @is_request-src_docno
      INTO @ls_inv.
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

    ls_inv-provider     = i_provider.
    ls_inv-idkey        = ls_hdr-idkey.
    ls_inv-inv_type     = ls_hdr-inv_type.
    ls_inv-inv_date     = ls_hdr-inv_date.
    ls_inv-inv_time     = ls_hdr-inv_time.
    ls_inv-waers        = ls_hdr-currency.
    ls_inv-exrate       = ls_hdr-exch_rate.
    ls_inv-adj_type     = is_request-invoice-adjust-adj_type.
    " Tham chiếu HĐ gốc: ưu tiên số chứng từ SAP (để kiểm tra trạng thái
    " và đảo), fallback idkey như bản 1.0
    IF is_request-invoice-adjust-org_docno IS NOT INITIAL.
      ls_inv-ref_docno = is_request-invoice-adjust-org_docno.
      ls_inv-ref_gjahr = is_request-invoice-adjust-org_gjahr.
    ELSEIF is_request-invoice-adjust-org_idkey IS NOT INITIAL.
      ls_inv-ref_docno = is_request-invoice-adjust-org_idkey.
    ENDIF.
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
    IF is_result-tax_status IS NOT INITIAL.
      ls_inv-tax_status = is_result-tax_status.
    ENDIF.
    IF is_request-invoice-adjust-org_docno IS NOT INITIAL.
      ls_inv-ref_srctype = is_request-invoice-adjust-org_src_type.
      ls_inv-adj_dir     = is_request-invoice-adjust-adj_direction.
    ENDIF.

    IF is_result-status = zif_hddt_types=>gc_status-cancelled.
      ls_inv-cancel_date = sy-datum.
    ENDIF.

    ls_inv-changed_by = sy-uname.
    GET TIME STAMP FIELD ls_inv-changed_at.

    MODIFY ztb_hddt_inv FROM ls_inv.

  ENDMETHOD.


  METHOD save_items.

    DATA lt_item TYPE STANDARD TABLE OF ztb_hddt_item WITH EMPTY KEY.

    DELETE FROM ztb_hddt_item
      WHERE bukrs     = @is_request-bukrs
        AND gjahr     = @is_request-gjahr
        AND src_type  = @is_request-src_type
        AND src_docno = @is_request-src_docno.

    LOOP AT is_request-invoice-items ASSIGNING FIELD-SYMBOL(<fs_src>).
      APPEND VALUE #( bukrs      = is_request-bukrs
                      gjahr      = is_request-gjahr
                      src_type   = is_request-src_type
                      src_docno  = is_request-src_docno
                      line_no    = <fs_src>-line_no
                      item_code  = <fs_src>-item_code
                      item_name  = <fs_src>-item_name
                      item_type  = <fs_src>-item_type
                      unit       = <fs_src>-unit
                      quantity   = <fs_src>-quantity
                      price      = <fs_src>-price
                      amount     = <fs_src>-amount
                      tax_rate   = <fs_src>-tax_rate
                      tax_amount = <fs_src>-tax_amount
                      total      = <fs_src>-total
                      disc_pct   = <fs_src>-disc_percent
                      disc_amt   = <fs_src>-disc_amount
                      note       = <fs_src>-note ) TO lt_item.
    ENDLOOP.

    IF lt_item IS NOT INITIAL.
      INSERT ztb_hddt_item FROM TABLE @lt_item.
    ENDIF.

  ENDMETHOD.


  METHOD mark_original.

    DATA(ls_adj) = is_request-invoice-adjust.
    IF ls_adj-org_docno IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lv_gjahr) = COND gjahr( WHEN ls_adj-org_gjahr IS NOT INITIAL
                                 THEN ls_adj-org_gjahr ELSE is_request-gjahr ).
    DATA(lv_type)  = COND zde_hddt_srctype( WHEN ls_adj-org_src_type IS NOT INITIAL
                                              THEN ls_adj-org_src_type ELSE is_request-src_type ).
    DATA lv_ts  TYPE timestampl.
    DATA lv_msg TYPE zde_hddt_msg.
    GET TIME STAMP FIELD lv_ts.
    lv_msg = |Đã { COND string( WHEN i_status = zif_hddt_types=>gc_status-replaced
                                THEN 'thay thế' ELSE 'điều chỉnh' ) }| &&
             | bởi chứng từ { is_request-src_docno }/{ is_request-gjahr }|.

    UPDATE ztb_hddt_inv
      SET status     = @i_status,
          message    = @lv_msg,
          changed_by = @sy-uname,
          changed_at = @lv_ts
      WHERE bukrs     = @is_request-bukrs
        AND gjahr     = @lv_gjahr
        AND src_type  = @lv_type
        AND src_docno = @ls_adj-org_docno.

  ENDMETHOD.


  METHOD ensure_row.

    SELECT SINGLE * FROM ztb_hddt_inv
      WHERE bukrs     = @is_request-bukrs
        AND gjahr     = @is_request-gjahr
        AND src_type  = @is_request-src_type
        AND src_docno = @is_request-src_docno
      INTO @rs_inv.
    IF sy-subrc = 0.
      RETURN.
    ENDIF.

    CLEAR rs_inv.
    rs_inv-bukrs      = is_request-bukrs.
    rs_inv-gjahr      = is_request-gjahr.
    rs_inv-src_type   = is_request-src_type.
    rs_inv-src_docno  = is_request-src_docno.
    rs_inv-status     = zif_hddt_types=>gc_status-not_sent.
    rs_inv-buyer_code = is_request-invoice-buyer-code.
    rs_inv-buyer_name = is_request-invoice-buyer-legal_name.
    rs_inv-waers      = is_request-invoice-header-currency.
    rs_inv-inv_date   = is_request-invoice-header-inv_date.
    rs_inv-inv_time   = is_request-invoice-header-inv_time.
    rs_inv-created_by = sy-uname.
    GET TIME STAMP FIELD rs_inv-created_at.

  ENDMETHOD.


  METHOD set_gom_no.

    DATA(ls_inv) = ensure_row( is_request ).
    ls_inv-gom_no     = i_gom_no.
    ls_inv-changed_by = sy-uname.
    GET TIME STAMP FIELD ls_inv-changed_at.
    MODIFY ztb_hddt_inv FROM ls_inv.

  ENDMETHOD.


  METHOD save_edit.

    DATA(ls_inv) = ensure_row( is_request ).
    IF i_inv_date IS NOT INITIAL.
      ls_inv-inv_date = i_inv_date.
    ENDIF.
    IF i_inv_time IS NOT INITIAL.
      ls_inv-inv_time = i_inv_time.
    ENDIF.
    ls_inv-item_text  = i_item_text.
    ls_inv-changed_by = sy-uname.
    GET TIME STAMP FIELD ls_inv-changed_at.
    MODIFY ztb_hddt_inv FROM ls_inv.

  ENDMETHOD.


  METHOD attach_original.

    DATA(ls_inv) = ensure_row( is_request ).
    ls_inv-ref_docno   = i_org_docno.
    ls_inv-ref_gjahr   = COND #( WHEN i_org_docno IS INITIAL THEN space ELSE i_org_gjahr ).
    ls_inv-ref_srctype = COND #( WHEN i_org_docno IS INITIAL THEN space ELSE i_org_srctype ).
    ls_inv-adj_type    = COND #( WHEN i_org_docno IS INITIAL THEN space ELSE i_adj_type ).
    ls_inv-adj_dir     = COND #( WHEN i_org_docno IS INITIAL THEN space ELSE i_adj_dir ).
    ls_inv-changed_by  = sy-uname.
    GET TIME STAMP FIELD ls_inv-changed_at.
    MODIFY ztb_hddt_inv FROM ls_inv.

  ENDMETHOD.


  METHOD set_mail_status.

    DATA(ls_inv) = ensure_row( is_request ).
    ls_inv-mail_status = i_status.
    ls_inv-mail_date   = sy-datum.
    ls_inv-changed_by  = sy-uname.
    GET TIME STAMP FIELD ls_inv-changed_at.
    MODIFY ztb_hddt_inv FROM ls_inv.

  ENDMETHOD.


  METHOD reset_registry.

    DATA(ls_inv) = ensure_row( is_request ).
    CLEAR: ls_inv-template, ls_inv-serial, ls_inv-seq, ls_inv-issue_date,
           ls_inv-cancel_date, ls_inv-mscqt, ls_inv-sec_code, ls_inv-inv_link,
           ls_inv-prov_status, ls_inv-tax_status, ls_inv-mail_status, ls_inv-mail_date.
    ls_inv-status     = zif_hddt_types=>gc_status-not_sent.
    ls_inv-message    = i_message.
    ls_inv-changed_by = sy-uname.
    GET TIME STAMP FIELD ls_inv-changed_at.
    MODIFY ztb_hddt_inv FROM ls_inv.

  ENDMETHOD.


  METHOD object_type_of.

    CASE i_action.
      WHEN zif_hddt_types=>gc_action-create_draft
        OR zif_hddt_types=>gc_action-preview_draft
        OR zif_hddt_types=>gc_action-delete_invoice.
        r_type = 'DRAFT'.
      WHEN zif_hddt_types=>gc_action-adjust_invoice.
        r_type = 'ADJUST'.
      WHEN zif_hddt_types=>gc_action-replace_invoice.
        r_type = 'REPLACE'.
      WHEN zif_hddt_types=>gc_action-search_invoice
        OR zif_hddt_types=>gc_action-get_file.
        r_type = 'SEARCH'.
      WHEN zif_hddt_types=>gc_action-cancel_invoice
        OR zif_hddt_types=>gc_action-wrong_notice.
        r_type = 'CANCEL'.
      WHEN OTHERS.
        r_type = 'INVOICE'.
    ENDCASE.
    IF is_request-src_type = 'GOM'.
      r_type = |{ r_type }_GOM|.
    ENDIF.

  ENDMETHOD.


  METHOD call_sink.

    " Lớp sink của khách hàng (vd ánh xạ sang ZTB_INT_LOG của MAG).
    " Lỗi ở sink không được làm hỏng nghiệp vụ -> bắt hết.
    DATA(lv_class) = zcl_hddt_config=>get_instance( )->get_param(
                       i_key = zif_hddt_types=>gc_parm-log_sink_class
                       i_bukrs = is_request-bukrs ).
    CONDENSE lv_class.
    IF lv_class IS INITIAL.
      RETURN.
    ENDIF.
    TRY.
        DATA(lo_sink) = CAST zif_hddt_log_sink(
                          zcl_hddt_factory=>create_object( CONV #( lv_class ) ) ).
        lo_sink->write( is_log = is_log is_request = is_request is_result = is_result ).
      CATCH cx_root.
        " bỏ qua có chủ ý
    ENDTRY.

  ENDMETHOD.


  METHOD read_invoice.

    IF i_src_type IS NOT INITIAL.
      SELECT SINGLE * FROM ztb_hddt_inv
        WHERE bukrs     = @i_bukrs
          AND gjahr     = @i_gjahr
          AND src_type  = @i_src_type
          AND src_docno = @i_src_docno
        INTO @rs_inv.
    ELSE.
      SELECT SINGLE * FROM ztb_hddt_inv
        WHERE bukrs     = @i_bukrs
          AND gjahr     = @i_gjahr
          AND src_docno = @i_src_docno
        INTO @rs_inv.
    ENDIF.

    IF sy-subrc <> 0.
      CLEAR rs_inv.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
