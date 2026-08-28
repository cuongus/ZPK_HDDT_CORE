*=====================================================================
* Tên/Mã     : ZFIC_HDDT_PROV_FPT
* Mô tả chung: Adapter cho FPT.eInvoice (api-uat.einvoice.fpt.com.vn).
*
*              [Nguồn tham chiếu — đã đối chiếu tài liệu]
*              - "TÀI LIỆU ĐẶC TẢ API GIAO TIẾP VỚI HỆ THỐNG KHÁCH
*                HÀNG" FPT.eInvoice v2.4.7:
*                  §3.1  create-invoice   (khởi tạo)
*                  §3.3  create-appr-inv  (tạo + cấp số + ký duyệt)
*                  §3.5  replace-invoice  (thay thế)
*                  §3.7  cancel-invoice   (huỷ theo TT78)
*                  §3.8  adjust-invoice   (điều chỉnh)
*                  §3.9  search-invoice   (tra cứu — GET, tham số đặt
*                                          trong HTTP HEADER)
*                  §3.10 del-invoice      (xoá HĐ chờ cấp số)
*                  §3.11 c_signin         (đăng nhập JWT)
*              - Mã ABAP đang chạy tại hệ VJC, package ZPK_HDDT
*                (ZST_CR_EINV_JSON_FPT / ZST_DC_EINV_JSON_FPT).
*
*              Lưu ý đặc thù FPT: tài khoản nằm TRONG payload ở nút
*              "user" (không phải HTTP header). Core đã nạp secret vào
*              IS_CRED-APISECRET trước khi gọi BUILD_PAYLOAD, nên nếu
*              dùng Basic auth hoặc JWT thì để AUTH_MODE tương ứng và
*              cấu hình tham số FPT_USER_IN_BODY = '' để bỏ nút user.
* Tham Số    : ZFIT_HDDT_PROV: PROVIDER='FPT',
*              CLASSNAME='ZFIC_HDDT_PROV_FPT'
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       28/08/2026    cuongus - CuongUS        abapGit     Tạo mới
*=====================================================================
CLASS zfic_hddt_prov_fpt DEFINITION
  PUBLIC
  INHERITING FROM zfic_hddt_prov_base
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    CONSTANTS gc_provider TYPE zfide_hddt_prov VALUE 'FPT' ##NO_TEXT.

    "! Tham số cấu hình riêng của adapter FPT
    CONSTANTS: BEGIN OF gc_parm,
                 "! '' = bỏ nút "user" trong payload (dùng Basic/JWT)
                 user_in_body TYPE zfide_hddt_parmkey VALUE 'FPT_USER_IN_BODY',
                 "! Ngôn ngữ thông báo lỗi: vi / en
                 lang         TYPE zfide_hddt_parmkey VALUE 'FPT_LANG',
                 "! Cách cấp số: '' nháp, '1' số do SAP cấp, '2' FPT cấp
                 aun          TYPE zfide_hddt_parmkey VALUE 'FPT_AUN',
                 "! Địa danh bắt buộc khi huỷ hoá đơn
                 place        TYPE zfide_hddt_parmkey VALUE 'FPT_PLACE',
               END OF gc_parm.

    METHODS zfiif_hddt_provider~get_id            REDEFINITION .
    METHODS zfiif_hddt_provider~build_payload     REDEFINITION .
    METHODS zfiif_hddt_provider~parse_response    REDEFINITION .
    METHODS zfiif_hddt_provider~get_headers       REDEFINITION .
    METHODS zfiif_hddt_provider~build_login_payload REDEFINITION .

  PROTECTED SECTION.
  PRIVATE SECTION.

    METHODS build_invoice
      IMPORTING is_request        TYPE zfiif_hddt_types=>ty_request
                iv_action         TYPE zfide_hddt_action
                is_cred           TYPE zfit_hddt_cred
      RETURNING VALUE(rv_payload) TYPE string .

    METHODS build_cancel
      IMPORTING is_request        TYPE zfiif_hddt_types=>ty_request
                is_cred           TYPE zfit_hddt_cred
      RETURNING VALUE(rv_payload) TYPE string
      RAISING   zficx_hddt_error .

    METHODS build_delete
      IMPORTING is_request        TYPE zfiif_hddt_types=>ty_request
                is_cred           TYPE zfit_hddt_cred
      RETURNING VALUE(rv_payload) TYPE string .

    METHODS add_user_node
      IMPORTING io_json TYPE REF TO zfic_hddt_json
                is_cred TYPE zfit_hddt_cred .

    "! Mã thuế suất của FPT: số nguyên phần trăm, hoặc -1 (KCT) / -2
    "! (không kê khai). Cho phép cấu hình lại qua ánh xạ TAXRATE.
    METHODS get_vrt
      IMPORTING iv_tax_rate   TYPE zfiif_hddt_types=>ty_rate
      RETURNING VALUE(rv_vrt) TYPE string .

ENDCLASS.



CLASS zfic_hddt_prov_fpt IMPLEMENTATION.

  METHOD zfiif_hddt_provider~get_id.

    rv_provider = gc_provider.

  ENDMETHOD.


  METHOD zfiif_hddt_provider~build_login_payload.

    " §3.11 c_signin : {"lang":"vi","username":"...","password":"..."}
    " Body trả về là chuỗi JWT thuần -> EXTRACT_TOKEN của lớp cha xử lý.
    DATA(lv_lang) = get_config( )->get_param( gc_parm-lang ).
    IF lv_lang IS INITIAL.
      lv_lang = 'vi'.
    ENDIF.

    rv_payload = NEW zfic_hddt_json( )->begin_object(
      )->add_string( iv_name = `lang`     iv_value = lv_lang iv_force = abap_true
      )->add_string( iv_name = `username` iv_value = is_cred-apiuser
                     iv_force = abap_true
      )->add_string( iv_name = `password` iv_value = iv_secret
                     iv_force = abap_true
      )->end_object(
      )->get_json( ).

  ENDMETHOD.


  METHOD zfiif_hddt_provider~get_headers.

    " §3.9 search-invoice là GET và tham số tra cứu được đặt trong
    " HTTP HEADER, không phải query string.
    IF is_request-action <> zfiif_hddt_types=>gc_action-search_invoice.
      RETURN.
    ENDIF.

    DATA(ls_hdr) = is_request-invoice-header.

    rt_headers = VALUE #(
      ( name = `stax`   value = |{ is_cred-taxcode }| )
      ( name = `form`   value = |{ ls_hdr-template }| )
      ( name = `serial` value = |{ ls_hdr-serial }| )
      ( name = `seq`    value = |{ ls_hdr-seq }| )
      ( name = `sid`    value = |{ ls_hdr-idkey }| ) ).

    " type: json / xml / pdf / cvt / base64xml  (mặc định json)
    DATA(lv_type) = zfic_hddt_json=>get_value( it_values = is_request-params
                                               iv_path   = `type` ).
    APPEND VALUE #( name  = `type`
                    value = COND string( WHEN lv_type IS INITIAL
                                         THEN `json` ELSE lv_type ) )
           TO rt_headers.

    " Các tham số tra cứu khác do caller truyền (fd, td, btax, api...)
    LOOP AT is_request-params ASSIGNING FIELD-SYMBOL(<ls_p>)
         WHERE name <> `type`.
      APPEND <ls_p> TO rt_headers.
    ENDLOOP.

    " Bỏ header rỗng để FPT không hiểu sai là điều kiện lọc trống
    DELETE rt_headers WHERE value IS INITIAL.

  ENDMETHOD.


  METHOD zfiif_hddt_provider~build_payload.

    CASE iv_action.

      WHEN zfiif_hddt_types=>gc_action-create_invoice
        OR zfiif_hddt_types=>gc_action-create_draft
        OR zfiif_hddt_types=>gc_action-update_invoice
        OR zfiif_hddt_types=>gc_action-adjust_invoice
        OR zfiif_hddt_types=>gc_action-replace_invoice
        OR zfiif_hddt_types=>gc_action-approve_invoice.
        rv_payload = build_invoice( is_request = is_request
                                    iv_action  = iv_action
                                    is_cred    = is_cred ).

      WHEN zfiif_hddt_types=>gc_action-cancel_invoice.
        rv_payload = build_cancel( is_request = is_request
                                   is_cred    = is_cred ).

      WHEN zfiif_hddt_types=>gc_action-delete_invoice.
        rv_payload = build_delete( is_request = is_request
                                   is_cred    = is_cred ).

      WHEN zfiif_hddt_types=>gc_action-search_invoice.
        " GET — tham số nằm trong header, body rỗng
        CLEAR rv_payload.

      WHEN OTHERS.
        zficx_hddt_error=>raise_text(
          |Adapter FPT chưa hỗ trợ nghiệp vụ { iv_action }.| &&
          | Bổ sung trong ZFIC_HDDT_PROV_FPT~BUILD_PAYLOAD.| ).
    ENDCASE.

  ENDMETHOD.


  METHOD add_user_node.

    " Mặc định gửi nút "user"; đặt tham số FPT_USER_IN_BODY = 'N' khi
    " đã dùng Basic auth / JWT để không truyền mật khẩu 2 lần.
    DATA(lv_flag) = get_config( )->get_param( gc_parm-user_in_body ).
    TRANSLATE lv_flag TO UPPER CASE.
    IF lv_flag = 'N' OR lv_flag = 'FALSE' OR lv_flag = '0'.
      RETURN.
    ENDIF.

    io_json->begin_object( `user`
      )->add_string( iv_name = `username` iv_value = is_cred-apiuser
                     iv_force = abap_true
      )->add_string( iv_name = `password` iv_value = is_cred-apisecret
                     iv_force = abap_true
      )->end_object( ).

  ENDMETHOD.


  METHOD build_invoice.

    DATA(ls_inv) = is_request-invoice.
    DATA(ls_hdr) = ls_inv-header.
    DATA(ls_buy) = ls_inv-buyer.
    DATA(ls_sel) = ls_inv-seller.
    DATA(ls_sum) = ls_inv-summary.
    DATA(ls_adj) = ls_inv-adjust.

    DATA(lv_is_adjust) =
      xsdbool( ls_adj-adj_type = zfiif_hddt_types=>gc_adj_type-adjust
            OR ls_adj-adj_type = zfiif_hddt_types=>gc_adj_type-replace ).

    DATA(lo_cfg) = get_config( ).
    DATA(lv_lang) = lo_cfg->get_param( gc_parm-lang ).
    IF lv_lang IS INITIAL.
      lv_lang = 'vi'.
    ENDIF.

    DATA(lo) = NEW zfic_hddt_json( ).
    lo->begin_object( ).
    lo->add_string( iv_name = `lang` iv_value = lv_lang iv_force = abap_true ).
    add_user_node( io_json = lo is_cred = is_cred ).

*---- inv -------------------------------------------------------------*
    lo->begin_object( `inv` ).

    lo->add_string( iv_name = `sid`    iv_value = ls_hdr-idkey iv_force = abap_true
      )->add_string( iv_name = `idt`
                     iv_value = fmt_datetime( iv_date = ls_hdr-inv_date
                                              iv_time = ls_hdr-inv_time )
                     iv_force = abap_true
      )->add_string( iv_name = `type`   iv_value = ls_hdr-inv_type iv_force = abap_true
      )->add_string( iv_name = `form`   iv_value = ls_hdr-template
      )->add_string( iv_name = `serial` iv_value = ls_hdr-serial
      )->add_string( iv_name = `seq`    iv_value = ls_hdr-seq ).

    " Cách cấp số hoá đơn (§3.1: aun rỗng = lưu nháp)
    DATA(lv_aun) = lo_cfg->get_param( gc_parm-aun ).
    IF lv_aun IS NOT INITIAL.
      lo->add_string( iv_name = `aun` iv_value = lv_aun iv_force = abap_true ).
    ENDIF.

    " type_ref = 1 : hoá đơn theo NĐ123/2020 (TT78)
    lo->add_string( iv_name = `type_ref` iv_value = `1` iv_force = abap_true ).
    " sendtype = 0 : gửi CQT ngay, 1 : gửi theo bảng tổng hợp
    lo->add_string( iv_name  = `sendtype`
                    iv_value = COND string( WHEN ls_hdr-send_type IS INITIAL
                                            THEN `0` ELSE |{ ls_hdr-send_type }| )
                    iv_force = abap_true ).

*---- người mua -------------------------------------------------------*
    lo->add_string( iv_name = `bcode` iv_value = ls_buy-code
      )->add_string( iv_name = `bname` iv_value = ls_buy-legal_name
      )->add_string( iv_name = `buyer` iv_value = ls_buy-person_name
      )->add_string( iv_name = `btax`  iv_value = ls_buy-tax_code
      )->add_string( iv_name = `baddr` iv_value = ls_buy-address
      )->add_string( iv_name = `btel`  iv_value = ls_buy-phone
      )->add_string( iv_name = `bmail` iv_value = ls_buy-email
      )->add_string( iv_name = `bacc`  iv_value = ls_buy-bank_acct
      )->add_string( iv_name = `bbank` iv_value = ls_buy-bank_name ).

*---- người bán -------------------------------------------------------*
    lo->add_string( iv_name = `stax`  iv_value = ls_sel-tax_code iv_force = abap_true
      )->add_string( iv_name = `sname` iv_value = ls_sel-name
      )->add_string( iv_name = `saddr` iv_value = ls_sel-address
      )->add_string( iv_name = `stel`  iv_value = ls_sel-phone
      )->add_string( iv_name = `smail` iv_value = ls_sel-email
      )->add_string( iv_name = `sacc`  iv_value = ls_sel-bank_acct
      )->add_string( iv_name = `sbank` iv_value = ls_sel-bank_name ).

*---- tiền tệ / thanh toán / ghi chú ---------------------------------*
    lo->add_string( iv_name = `curr` iv_value = ls_hdr-currency iv_force = abap_true ).
    lo->add_number( iv_name     = `exrt`
                    iv_value    = COND #( WHEN ls_hdr-currency = 'VND'
                                          THEN 1 ELSE ls_hdr-exch_rate )
                    iv_decimals = 4 ).

    DATA lv_paym TYPE string.
    LOOP AT ls_inv-payments ASSIGNING FIELD-SYMBOL(<ls_pay>).
      lv_paym = <ls_pay>-method_name.
      EXIT.
    ENDLOOP.
    lo->add_string( iv_name = `paym` iv_value = lv_paym ).

    lo->add_string( iv_name  = `note`
                    iv_value = COND string( WHEN lv_is_adjust = abap_true
                                            THEN build_adjust_note( ls_adj )
                                            ELSE ls_hdr-note ) ).

*---- tổng cộng -------------------------------------------------------*
    lo->add_number( iv_name = `sum`    iv_value = ls_sum-amount_wo_tax
      )->add_number( iv_name = `sumv`   iv_value = ls_sum-amount_wo_tax_l
      )->add_number( iv_name = `vat`    iv_value = ls_sum-tax_amount
      )->add_number( iv_name = `vatv`   iv_value = ls_sum-tax_amount_l
      )->add_number( iv_name = `total`  iv_value = ls_sum-total
      )->add_number( iv_name = `totalv` iv_value = ls_sum-total_l
      )->add_string( iv_name = `word`   iv_value = ls_sum-amount_in_words ).

*---- hàng hoá --------------------------------------------------------*
    lo->begin_array( `items` ).
    LOOP AT ls_inv-items ASSIGNING FIELD-SYMBOL(<ls_item>).
      lo->begin_object( ).
      lo->add_number( iv_name = `line` iv_value = <ls_item>-line_no
                      iv_decimals = 0 ).
      lo->add_string( iv_name = `type` iv_value = <ls_item>-item_type
        )->add_string( iv_name = `code` iv_value = <ls_item>-item_code
        )->add_string( iv_name = `name` iv_value = <ls_item>-item_name
                       iv_force = abap_true
        )->add_string( iv_name = `unit` iv_value = <ls_item>-unit
        )->add_string( iv_name = `vrt`  iv_value = get_vrt( <ls_item>-tax_rate )
                       iv_force = abap_true ).
      lo->add_number( iv_name = `price`    iv_value = <ls_item>-price
        )->add_number( iv_name = `quantity` iv_value = <ls_item>-quantity
        )->add_number( iv_name = `amount`   iv_value = <ls_item>-amount
        )->add_number( iv_name = `vat`      iv_value = <ls_item>-tax_amount
        )->add_number( iv_name = `total`    iv_value = <ls_item>-total ).
      IF <ls_item>-disc_percent IS NOT INITIAL.
        lo->add_number( iv_name = `perdiscount` iv_value = <ls_item>-disc_percent
                        iv_decimals = 2 ).
      ENDIF.
      IF <ls_item>-disc_amount IS NOT INITIAL.
        lo->add_number( iv_name = `amtdiscount` iv_value = <ls_item>-disc_amount ).
      ENDIF.
      lo->add_ext( <ls_item>-ext ).
      lo->end_object( ).
    ENDLOOP.
    lo->end_array( ).

*---- bảng thuế theo thuế suất ---------------------------------------*
    lo->begin_array( `tax` ).
    LOOP AT ls_inv-taxes ASSIGNING FIELD-SYMBOL(<ls_tax>).
      lo->begin_object(
        )->add_string( iv_name = `vrt` iv_value = get_vrt( <ls_tax>-tax_rate )
                       iv_force = abap_true
        )->add_string( iv_name = `vrn` iv_value = <ls_tax>-tax_rate_txt
        )->add_number( iv_name = `amt`  iv_value = <ls_tax>-taxable_amt
        )->add_number( iv_name = `amtv` iv_value = <ls_tax>-taxable_amt_l
        )->add_number( iv_name = `vat`  iv_value = <ls_tax>-tax_amt
        )->add_number( iv_name = `vatv` iv_value = <ls_tax>-tax_amt_l
        )->end_object( ).
    ENDLOOP.
    lo->end_array( ).

*---- thông tin điều chỉnh / thay thế ---------------------------------*
    IF lv_is_adjust = abap_true.
      lo->begin_object( `adj`
        )->add_string( iv_name  = `seq`
                       iv_value = |1-{ ls_adj-org_serial }-{ ls_adj-org_seq }|
                       iv_force = abap_true
        )->add_string( iv_name  = `rdt`
                       iv_value = fmt_datetime(
                         iv_date = COND #( WHEN ls_adj-doc_ref_date IS NOT INITIAL
                                           THEN ls_adj-doc_ref_date
                                           ELSE ls_hdr-inv_date )
                         iv_time = ls_hdr-inv_time )
        )->add_string( iv_name = `ref` iv_value = COND string(
                         WHEN ls_adj-doc_ref_no IS NOT INITIAL
                         THEN ls_adj-doc_ref_no ELSE |{ ls_hdr-idkey }| )
        )->add_string( iv_name = `rea` iv_value = build_adjust_note( ls_adj )
        )->end_object( ).

      " ud: '1' điều chỉnh tăng, '0' điều chỉnh giảm
      IF ls_adj-adj_direction = '1' OR ls_adj-adj_direction = '0'.
        lo->add_string( iv_name  = `ud`
                        iv_value = |{ ls_adj-adj_direction }|
                        iv_force = abap_true ).
      ENDIF.
      " Điều chỉnh kiểu mới (chỉ ghi phần chênh lệch)
      lo->add_string( iv_name = `adj_only_add` iv_value = `1` iv_force = abap_true ).
    ENDIF.

    lo->add_ext( ls_inv-ext ).
    lo->end_object( ).                       " inv
    lo->end_object( ).                       " root

    rv_payload = lo->get_json( ).

  ENDMETHOD.


  METHOD build_cancel.

    " §3.7.3 cancel-invoice (huỷ theo TT78)
    DATA(ls_hdr) = is_request-invoice-header.
    DATA(ls_adj) = is_request-invoice-adjust.

    DATA(lv_serial) = |{ ls_hdr-serial }|.
    DATA(lv_seq)    = |{ ls_hdr-seq }|.
    DATA(lv_form)   = |{ ls_hdr-template }|.
    DATA(lv_idt)    = fmt_datetime( iv_date = ls_hdr-inv_date
                                    iv_time = ls_hdr-inv_time ).

    IF lv_seq IS INITIAL.
      DATA(ls_reg) = zfic_hddt_log=>read_invoice(
                       iv_bukrs     = is_request-bukrs
                       iv_gjahr     = is_request-gjahr
                       iv_src_type  = is_request-src_type
                       iv_src_docno = is_request-src_docno ).
      lv_serial = |{ ls_reg-serial }|.
      lv_seq    = |{ ls_reg-seq }|.
      lv_form   = |{ ls_reg-template }|.
      IF ls_reg-issue_date IS NOT INITIAL.
        lv_idt = fmt_datetime( iv_date = ls_reg-issue_date
                               iv_time = ls_reg-inv_time ).
      ENDIF.
    ENDIF.

    IF lv_seq IS INITIAL OR lv_serial IS INITIAL.
      zficx_hddt_error=>raise_text(
        |Không xác định được ký hiệu / số hoá đơn cần huỷ cho chứng từ | &&
        |{ is_request-src_docno }/{ is_request-gjahr }.| ).
    ENDIF.

    DATA(lv_place) = get_config( )->get_param(
                       iv_key   = gc_parm-place
                       iv_bukrs = is_request-bukrs ).
    IF lv_place IS INITIAL.
      lv_place = is_request-invoice-header-place.
    ENDIF.

    DATA(lo) = NEW zfic_hddt_json( ).
    lo->begin_object( ).
    lo->add_string( iv_name = `lang` iv_value = `vi` iv_force = abap_true ).
    add_user_node( io_json = lo is_cred = is_cred ).

    lo->begin_object( `wrongnotice`
      )->add_string( iv_name = `stax` iv_value = is_cred-taxcode iv_force = abap_true
      )->add_string( iv_name  = `noti_taxtype`
                     iv_value = COND string(
                       WHEN ls_adj-doc_ref_no IS NOT INITIAL THEN `2` ELSE `1` )
                     iv_force = abap_true
      )->add_string( iv_name = `noti_taxnum` iv_value = ls_adj-doc_ref_no
      )->add_string( iv_name = `noti_taxdt`
                     iv_value = fmt_datetime( ls_adj-doc_ref_date )
      )->add_string( iv_name = `budget_relationid`
                     iv_value = is_request-invoice-buyer-budget_code
      )->add_string( iv_name = `place` iv_value = lv_place iv_force = abap_true ).

    lo->begin_array( `items`
      )->begin_object(
      )->add_string( iv_name = `form`   iv_value = lv_form   iv_force = abap_true
      )->add_string( iv_name = `serial` iv_value = lv_serial iv_force = abap_true
      )->add_string( iv_name = `seq`    iv_value = lv_seq    iv_force = abap_true
      )->add_string( iv_name = `idt`    iv_value = lv_idt    iv_force = abap_true
      )->add_string( iv_name = `type_ref` iv_value = `1`     iv_force = abap_true
      )->add_string( iv_name = `noti_type` iv_value = `1`    iv_force = abap_true
      )->add_string( iv_name = `rea`    iv_value = ls_adj-reason
      )->end_object(
      )->end_array( ).

    lo->end_object( ).                       " wrongnotice
    lo->end_object( ).                       " root

    rv_payload = lo->get_json( ).

  ENDMETHOD.


  METHOD build_delete.

    " §3.10.3 del-invoice : { user, sid, stax }
    DATA(lo) = NEW zfic_hddt_json( ).
    lo->begin_object( ).
    add_user_node( io_json = lo is_cred = is_cred ).
    lo->add_string( iv_name = `sid`
                    iv_value = is_request-invoice-header-idkey
                    iv_force = abap_true
      )->add_string( iv_name = `stax` iv_value = is_cred-taxcode
                     iv_force = abap_true
      )->end_object( ).

    rv_payload = lo->get_json( ).

  ENDMETHOD.


  METHOD get_vrt.

    " Cho phép khách hàng ghi đè bằng bảng ánh xạ TAXRATE nếu FPT yêu
    " cầu mã khác (ví dụ 'KCT' thay cho -1).
    DATA(lv_mapped) = map_val( iv_map_type = zfiif_hddt_types=>gc_map_type-tax_rate
                               iv_value    = iv_tax_rate ).

    " map_val trả lại nguyên giá trị SAP khi chưa cấu hình -> tự chuẩn hoá
    IF lv_mapped CS `.` OR lv_mapped IS INITIAL.
      rv_vrt = zfic_hddt_json=>format_number( iv_value    = iv_tax_rate
                                              iv_decimals = 0 ).
    ELSE.
      rv_vrt = lv_mapped.
    ENDIF.

  ENDMETHOD.


  METHOD zfiif_hddt_provider~parse_response.

    DATA(lv_ok_http) = xsdbool( iv_http_code >= 200 AND iv_http_code < 300 ).

    IF iv_body IS INITIAL.
      cs_result-success = lv_ok_http.
      cs_result-message = |HTTP { iv_http_code }: FPT không trả nội dung.|.
      RETURN.
    ENDIF.

    DATA(lv_body) = iv_body.
    CONDENSE lv_body.

    " del-invoice trả về text thuần ("Delete complete" / "There are no
    " invoices to delete"), không phải JSON.
    IF substring( val = lv_body len = 1 ) <> `{`
       AND substring( val = lv_body len = 1 ) <> `[`.
      cs_result-success     = lv_ok_http.
      cs_result-prov_status = |{ iv_http_code }|.
      cs_result-message     = substring( val = lv_body
                                        len = nmin( val1 = 255
                                                    val2 = strlen( lv_body ) ) ).
      RETURN.
    ENDIF.

    DATA lt_val TYPE zfiif_hddt_types=>ty_t_kv.
    TRY.
        lt_val = zfic_hddt_json=>parse( lv_body ).
      CATCH zficx_hddt_error.
        cs_result-success = lv_ok_http.
        cs_result-message = substring( val = lv_body
                                       len = nmin( val1 = 255
                                                   val2 = strlen( lv_body ) ) ).
        RETURN.
    ENDTRY.
    cs_result-fields = lt_val.

    DATA(lv_err) = zfic_hddt_json=>get_value_by_name( it_values = lt_val
                                                      iv_name   = `error` ).
    DATA(lv_msg) = zfic_hddt_json=>get_value_by_name( it_values = lt_val
                                                      iv_name   = `message` ).
    IF lv_msg IS INITIAL.
      lv_msg = zfic_hddt_json=>get_value_by_name( it_values = lt_val
                                                  iv_name   = `mess` ).
    ENDIF.

    cs_result-serial     = zfic_hddt_json=>get_value_by_name(
                             it_values = lt_val iv_name = `serial` ).
    cs_result-seq        = zfic_hddt_json=>get_value_by_name(
                             it_values = lt_val iv_name = `seq` ).
    cs_result-template   = zfic_hddt_json=>get_value_by_name(
                             it_values = lt_val iv_name = `form` ).
    cs_result-sec_code   = zfic_hddt_json=>get_value_by_name(
                             it_values = lt_val iv_name = `sec` ).
    cs_result-inv_link   = zfic_hddt_json=>get_value_by_name(
                             it_values = lt_val iv_name = `link` ).
    cs_result-idkey      = zfic_hddt_json=>get_value_by_name(
                             it_values = lt_val iv_name = `sid` ).
    IF cs_result-idkey IS INITIAL.
      cs_result-idkey = is_request-invoice-header-idkey.
    ENDIF.

    " Ngày ký hoá đơn 'YYYY-MM-DD hh:mm:ss' -> DATS
    DATA(lv_adt) = zfic_hddt_json=>get_value_by_name( it_values = lt_val
                                                      iv_name   = `adt` ).
    IF lv_adt IS INITIAL.
      lv_adt = zfic_hddt_json=>get_value_by_name( it_values = lt_val
                                                  iv_name   = `idt` ).
    ENDIF.
    IF strlen( lv_adt ) >= 10.
      cs_result-issue_date = |{ lv_adt(4) }{ lv_adt+5(2) }{ lv_adt+8(2) }|.
    ENDIF.

    " §Phụ lục I: status 1 chờ cấp số, 2 chờ duyệt, 3 đã duyệt, 4 đã huỷ
    DATA(lv_status) = zfic_hddt_json=>get_value_by_name( it_values = lt_val
                                                         iv_name   = `status` ).
    " §Phụ lục II: status_received 10 = CQT đã cấp mã
    DATA(lv_recv) = zfic_hddt_json=>get_value_by_name(
                      it_values = lt_val iv_name = `status_received` ).

    cs_result-prov_status = COND #( WHEN lv_status IS NOT INITIAL
                                    THEN lv_status
                                    ELSE |{ iv_http_code }| ).

    cs_result-success = xsdbool( lv_ok_http = abap_true AND lv_err IS INITIAL ).

    IF cs_result-success = abap_true.
      CASE lv_status.
        WHEN '1'. cs_result-status = zfiif_hddt_types=>gc_status-wait_seq.
        WHEN '2'. cs_result-status = zfiif_hddt_types=>gc_status-wait_appr.
        WHEN '3'. cs_result-status = zfiif_hddt_types=>gc_status-issued.
        WHEN '4'. cs_result-status = zfiif_hddt_types=>gc_status-cancelled.
        WHEN OTHERS.
      ENDCASE.
      IF lv_recv = '10'.
        cs_result-status = zfiif_hddt_types=>gc_status-coded.
        cs_result-mscqt  = zfic_hddt_json=>get_value_by_name(
                             it_values = lt_val iv_name = `ic` ).
      ENDIF.
    ENDIF.

    IF lv_msg IS NOT INITIAL.
      cs_result-message = lv_msg.
    ELSEIF lv_err IS NOT INITIAL.
      cs_result-message = lv_err.
    ELSEIF cs_result-success = abap_true.
      cs_result-message = |Thành công. Số hoá đơn: { cs_result-serial }{ cs_result-seq }|.
    ELSE.
      cs_result-message = substring( val = lv_body
                                     len = nmin( val1 = 255
                                                 val2 = strlen( lv_body ) ) ).
    ENDIF.

  ENDMETHOD.

ENDCLASS.
