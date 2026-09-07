*=====================================================================
* Tên/Mã     : ZCL_HDDT_PROV_FPT
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
* Tham Số    : ZTB_HDDT_PROV: PROVIDER='FPT',
*              CLASSNAME='ZCL_HDDT_PROV_FPT'
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       28/08/2026    cuongus - CuongUS        abapGit     Tạo mới
* 1.1       07/09/2026    cuongus - CuongUS        abapGit     FS MAG v0.5:
*                         issue-invoice, apprs riêng, aun theo action,
*                         adjtype/ref (API v3.2), status_received 9
*=====================================================================
CLASS zcl_hddt_prov_fpt DEFINITION
  PUBLIC
  INHERITING FROM zcl_hddt_prov_base
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    CONSTANTS gc_provider TYPE zde_hddt_prov VALUE 'FPT' ##NO_TEXT.

    "! Tham số cấu hình riêng của adapter FPT
    CONSTANTS: BEGIN OF gc_parm,
                 "! '' = bỏ nút "user" trong payload (dùng Basic/JWT)
                 user_in_body TYPE zde_hddt_parmkey VALUE 'FPT_USER_IN_BODY',
                 "! Ngôn ngữ thông báo lỗi: vi / en
                 lang         TYPE zde_hddt_parmkey VALUE 'FPT_LANG',
                 "! Cách cấp số: '' nháp, '1' số do SAP cấp, '2' FPT cấp
                 aun          TYPE zde_hddt_parmkey VALUE 'FPT_AUN',
                 "! Địa danh bắt buộc khi huỷ hoá đơn
                 place        TYPE zde_hddt_parmkey VALUE 'FPT_PLACE',
               END OF gc_parm.

    METHODS zif_hddt_provider~get_id            REDEFINITION .
    METHODS zif_hddt_provider~build_payload     REDEFINITION .
    METHODS zif_hddt_provider~parse_response    REDEFINITION .
    METHODS zif_hddt_provider~get_headers       REDEFINITION .
    METHODS zif_hddt_provider~build_login_payload REDEFINITION .

  PROTECTED SECTION.
  PRIVATE SECTION.

    METHODS build_invoice
      IMPORTING is_request        TYPE zif_hddt_types=>ty_request
                i_action         TYPE zde_hddt_action
                is_cred           TYPE ztb_hddt_cred
      RETURNING VALUE(r_payload) TYPE string .

    METHODS build_cancel
      IMPORTING is_request        TYPE zif_hddt_types=>ty_request
                is_cred           TYPE ztb_hddt_cred
      RETURNING VALUE(r_payload) TYPE string
      RAISING   zcx_hddt_error .

    "! issue-invoice (tài liệu bổ sung FPT, FS MAG 3.7.3): cấp số + ký duyệt
    "! trên chính bản nháp — chỉ truyền stax + sid
    METHODS build_issue
      IMPORTING is_request        TYPE zif_hddt_types=>ty_request
                is_cred           TYPE ztb_hddt_cred
      RETURNING VALUE(r_payload) TYPE string .

    "! apprs (FS MAG 3.7.5): ký duyệt hoá đơn đã cấp số (status 2)
    METHODS build_approve
      IMPORTING is_request        TYPE zif_hddt_types=>ty_request
                is_cred           TYPE ztb_hddt_cred
      RETURNING VALUE(r_payload) TYPE string .

    METHODS api_v3
      IMPORTING i_bukrs      TYPE bukrs
      RETURNING VALUE(r_v3) TYPE abap_bool .

    METHODS build_delete
      IMPORTING is_request        TYPE zif_hddt_types=>ty_request
                is_cred           TYPE ztb_hddt_cred
      RETURNING VALUE(r_payload) TYPE string .

    METHODS add_user_node
      IMPORTING io_json TYPE REF TO zcl_hddt_json
                is_cred TYPE ztb_hddt_cred .

    "! Mã thuế suất của FPT: số nguyên phần trăm, hoặc -1 (KCT) / -2
    "! (không kê khai). Cho phép cấu hình lại qua ánh xạ TAXRATE.
    METHODS get_vrt
      IMPORTING i_tax_rate   TYPE zif_hddt_types=>ty_rate
      RETURNING VALUE(r_vrt) TYPE string .

ENDCLASS.



CLASS zcl_hddt_prov_fpt IMPLEMENTATION.

  METHOD zif_hddt_provider~get_id.

    r_provider = gc_provider.

  ENDMETHOD.


  METHOD zif_hddt_provider~build_login_payload.

    " §3.11 c_signin : {"lang":"vi","username":"...","password":"..."}
    " Body trả về là chuỗi JWT thuần -> EXTRACT_TOKEN của lớp cha xử lý.
    DATA(lv_lang) = get_config( )->get_param( gc_parm-lang ).
    IF lv_lang IS INITIAL.
      lv_lang = 'vi'.
    ENDIF.

    r_payload = NEW zcl_hddt_json( )->begin_object(
      )->add_string( i_name = `lang`     i_value = lv_lang i_force = abap_true
      )->add_string( i_name = `username` i_value = is_cred-apiuser
                     i_force = abap_true
      )->add_string( i_name = `password` i_value = i_secret
                     i_force = abap_true
      )->end_object(
      )->get_json( ).

  ENDMETHOD.


  METHOD zif_hddt_provider~get_headers.

    " §3.9 search-invoice là GET và tham số tra cứu được đặt trong
    " HTTP HEADER, không phải query string.
    IF is_request-action <> zif_hddt_types=>gc_action-search_invoice
       AND is_request-action <> zif_hddt_types=>gc_action-get_file.
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
    DATA(lv_type) = zcl_hddt_json=>get_value( it_values = is_request-params
                                               i_path   = `type` ).
    APPEND VALUE #( name  = `type`
                    value = COND string( WHEN lv_type IS INITIAL
                                         THEN `json` ELSE lv_type ) )
           TO rt_headers.

    " Các tham số tra cứu khác do caller truyền (fd, td, btax, api...)
    LOOP AT is_request-params ASSIGNING FIELD-SYMBOL(<fs_p>)
         WHERE name <> `type`.
      APPEND <fs_p> TO rt_headers.
    ENDLOOP.

    " Bỏ header rỗng để FPT không hiểu sai là điều kiện lọc trống
    DELETE rt_headers WHERE value IS INITIAL.

  ENDMETHOD.


  METHOD zif_hddt_provider~build_payload.

    CASE i_action.

      WHEN zif_hddt_types=>gc_action-create_invoice
        OR zif_hddt_types=>gc_action-create_draft
        OR zif_hddt_types=>gc_action-update_invoice
        OR zif_hddt_types=>gc_action-adjust_invoice
        OR zif_hddt_types=>gc_action-replace_invoice.
        r_payload = build_invoice( is_request = is_request
                                    i_action  = i_action
                                    is_cred    = is_cred ).

      WHEN zif_hddt_types=>gc_action-issue_invoice.
        r_payload = build_issue( is_request = is_request is_cred = is_cred ).

      WHEN zif_hddt_types=>gc_action-approve_invoice.
        r_payload = build_approve( is_request = is_request is_cred = is_cred ).

      WHEN zif_hddt_types=>gc_action-cancel_invoice.
        r_payload = build_cancel( is_request = is_request
                                   is_cred    = is_cred ).

      WHEN zif_hddt_types=>gc_action-delete_invoice.
        r_payload = build_delete( is_request = is_request
                                   is_cred    = is_cred ).

      WHEN zif_hddt_types=>gc_action-search_invoice
        OR zif_hddt_types=>gc_action-get_file.
        " GET — tham số nằm trong header, body rỗng (get_file = type pdf/xml)
        CLEAR r_payload.

      WHEN OTHERS.
        zcx_hddt_error=>raise_text(
          |Adapter FPT chưa hỗ trợ nghiệp vụ { i_action }.| &&
          | Bổ sung trong ZCL_HDDT_PROV_FPT~BUILD_PAYLOAD.| ).
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
      )->add_string( i_name = `username` i_value = is_cred-apiuser
                     i_force = abap_true
      )->add_string( i_name = `password` i_value = is_cred-apisecret
                     i_force = abap_true
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
      xsdbool( ls_adj-adj_type = zif_hddt_types=>gc_adj_type-adjust
            OR ls_adj-adj_type = zif_hddt_types=>gc_adj_type-replace ).

    DATA(lo_cfg) = get_config( ).
    DATA(lv_lang) = lo_cfg->get_param( gc_parm-lang ).
    IF lv_lang IS INITIAL.
      lv_lang = 'vi'.
    ENDIF.

    DATA(lo) = NEW zcl_hddt_json( ).
    lo->begin_object( ).
    lo->add_string( i_name = `lang` i_value = lv_lang i_force = abap_true ).
    add_user_node( io_json = lo is_cred = is_cred ).

*---- inv -------------------------------------------------------------*
    lo->begin_object( `inv` ).

    lo->add_string( i_name = `sid`    i_value = ls_hdr-idkey i_force = abap_true
      )->add_string( i_name = `idt`
                     i_value = fmt_datetime( i_date = ls_hdr-inv_date
                                              i_time = ls_hdr-inv_time )
                     i_force = abap_true
      )->add_string( i_name = `type`   i_value = ls_hdr-inv_type i_force = abap_true
      )->add_string( i_name = `form`   i_value = ls_hdr-template
      )->add_string( i_name = `serial` i_value = ls_hdr-serial
      )->add_string( i_name = `seq`    i_value = ls_hdr-seq ).

    " Cách cấp số hoá đơn (§3.1: aun rỗng = lưu nháp). FS MAG: hoá đơn
    " NHÁP (create-invoice) KHÔNG truyền aun; create-appr-inv / điều
    " chỉnh / thay thế truyền aun = 2 (FPT tự cấp số).
    IF i_action <> zif_hddt_types=>gc_action-create_draft
       AND i_action <> zif_hddt_types=>gc_action-update_invoice.
      DATA(lv_aun) = lo_cfg->get_param( i_key = gc_parm-aun i_bukrs = is_request-bukrs ).
      IF lv_aun IS NOT INITIAL.
        lo->add_string( i_name = `aun` i_value = lv_aun i_force = abap_true ).
      ENDIF.
    ENDIF.
    " notsendmail / sendfile (FS 3.7.4) do caller truyền qua params
    DATA(lv_nsm) = zcl_hddt_json=>get_value( it_values = is_request-params i_path = `notsendmail` ).
    IF lv_nsm IS NOT INITIAL.
      lo->add_string( i_name = `notsendmail` i_value = lv_nsm i_force = abap_true ).
    ENDIF.
    DATA(lv_sf) = zcl_hddt_json=>get_value( it_values = is_request-params i_path = `sendfile` ).
    IF lv_sf IS NOT INITIAL.
      lo->add_string( i_name = `sendfile` i_value = lv_sf i_force = abap_true ).
    ENDIF.

    " type_ref = 1 : hoá đơn theo NĐ123/2020 (TT78)
    lo->add_string( i_name = `type_ref` i_value = `1` i_force = abap_true ).
    " sendtype = 0 : gửi CQT ngay, 1 : gửi theo bảng tổng hợp
    lo->add_string( i_name  = `sendtype`
                    i_value = COND string( WHEN ls_hdr-send_type IS INITIAL
                                            THEN `0` ELSE |{ ls_hdr-send_type }| )
                    i_force = abap_true ).

*---- người mua -------------------------------------------------------*
    lo->add_string( i_name = `bcode` i_value = ls_buy-code
      )->add_string( i_name = `bname` i_value = ls_buy-legal_name
      )->add_string( i_name = `buyer` i_value = ls_buy-person_name
      )->add_string( i_name = `btax`  i_value = ls_buy-tax_code
      )->add_string( i_name = `baddr` i_value = ls_buy-address
      )->add_string( i_name = `btel`  i_value = ls_buy-phone
      )->add_string( i_name = `bmail` i_value = ls_buy-email
      )->add_string( i_name = `bacc`  i_value = ls_buy-bank_acct
      )->add_string( i_name = `bbank` i_value = ls_buy-bank_name ).

*---- người bán -------------------------------------------------------*
    lo->add_string( i_name = `stax`  i_value = ls_sel-tax_code i_force = abap_true
      )->add_string( i_name = `sname` i_value = ls_sel-name
      )->add_string( i_name = `saddr` i_value = ls_sel-address
      )->add_string( i_name = `stel`  i_value = ls_sel-phone
      )->add_string( i_name = `smail` i_value = ls_sel-email
      )->add_string( i_name = `sacc`  i_value = ls_sel-bank_acct
      )->add_string( i_name = `sbank` i_value = ls_sel-bank_name ).

*---- tiền tệ / thanh toán / ghi chú ---------------------------------*
    lo->add_string( i_name = `curr` i_value = ls_hdr-currency i_force = abap_true ).
    lo->add_number( i_name     = `exrt`
                    i_value    = COND #( WHEN ls_hdr-currency = 'VND'
                                          THEN 1 ELSE ls_hdr-exch_rate )
                    i_decimals = 4 ).

    DATA lv_paym TYPE string.
    LOOP AT ls_inv-payments ASSIGNING FIELD-SYMBOL(<fs_pay>).
      lv_paym = <fs_pay>-method_name.
      EXIT.
    ENDLOOP.
    lo->add_string( i_name = `paym` i_value = lv_paym ).

    lo->add_string( i_name  = `note`
                    i_value = COND string( WHEN lv_is_adjust = abap_true
                                            THEN build_adjust_note( ls_adj )
                                            ELSE ls_hdr-note ) ).

*---- tổng cộng -------------------------------------------------------*
    lo->add_number( i_name = `sum`    i_value = ls_sum-amount_wo_tax
      )->add_number( i_name = `sumv`   i_value = ls_sum-amount_wo_tax_l
      )->add_number( i_name = `vat`    i_value = ls_sum-tax_amount
      )->add_number( i_name = `vatv`   i_value = ls_sum-tax_amount_l
      )->add_number( i_name = `total`  i_value = ls_sum-total
      )->add_number( i_name = `totalv` i_value = ls_sum-total_l
      )->add_string( i_name = `word`   i_value = ls_sum-amount_in_words ).

*---- hàng hoá --------------------------------------------------------*
    lo->begin_array( `items` ).
    LOOP AT ls_inv-items ASSIGNING FIELD-SYMBOL(<fs_item>).
      lo->begin_object( ).
      lo->add_number( i_name = `line` i_value = <fs_item>-line_no
                      i_decimals = 0 ).
      lo->add_string( i_name = `type` i_value = <fs_item>-item_type
        )->add_string( i_name = `code` i_value = <fs_item>-item_code
        )->add_string( i_name = `name` i_value = <fs_item>-item_name
                       i_force = abap_true
        )->add_string( i_name = `unit` i_value = <fs_item>-unit
        )->add_string( i_name = `vrt`  i_value = get_vrt( <fs_item>-tax_rate )
                       i_force = abap_true ).
      lo->add_number( i_name = `price`    i_value = <fs_item>-price
        )->add_number( i_name = `quantity` i_value = <fs_item>-quantity
        )->add_number( i_name = `amount`   i_value = <fs_item>-amount
        )->add_number( i_name = `vat`      i_value = <fs_item>-tax_amount
        )->add_number( i_name = `total`    i_value = <fs_item>-total ).
      IF <fs_item>-disc_percent IS NOT INITIAL.
        lo->add_number( i_name = `perdiscount` i_value = <fs_item>-disc_percent
                        i_decimals = 2 ).
      ENDIF.
      IF <fs_item>-disc_amount IS NOT INITIAL.
        lo->add_number( i_name = `amtdiscount` i_value = <fs_item>-disc_amount ).
      ENDIF.
      lo->add_ext( <fs_item>-ext ).
      lo->end_object( ).
    ENDLOOP.
    lo->end_array( ).

*---- bảng thuế theo thuế suất ---------------------------------------*
    lo->begin_array( `tax` ).
    LOOP AT ls_inv-taxes ASSIGNING FIELD-SYMBOL(<fs_tax>).
      lo->begin_object(
        )->add_string( i_name = `vrt` i_value = get_vrt( <fs_tax>-tax_rate )
                       i_force = abap_true
        )->add_string( i_name = `vrn` i_value = <fs_tax>-tax_rate_txt
        )->add_number( i_name = `amt`  i_value = <fs_tax>-taxable_amt
        )->add_number( i_name = `amtv` i_value = <fs_tax>-taxable_amt_l
        )->add_number( i_name = `vat`  i_value = <fs_tax>-tax_amt
        )->add_number( i_name = `vatv` i_value = <fs_tax>-tax_amt_l
        )->end_object( ).
    ENDLOOP.
    lo->end_array( ).

*---- thông tin điều chỉnh / thay thế ---------------------------------*
    IF lv_is_adjust = abap_true AND api_v3( is_request-bukrs ) = abap_true.
      " FPT eInvoice NĐ70 v3.2 (FS MAG 3.7.6/3.7.7): adjtype 2 tăng, 3 giảm,
      " 4 thông tin; ref = bộ mẫu-ký hiệu-số-ngày của hoá đơn gốc.
      IF ls_adj-adj_type = zif_hddt_types=>gc_adj_type-adjust.
        DATA(lv_adjtype) = COND string(
          WHEN ls_adj-fs_code IS NOT INITIAL THEN |{ ls_adj-fs_code }|
          WHEN ls_adj-adj_direction = '1'   THEN `2`
          WHEN ls_adj-adj_direction = '0'   THEN `3`
          ELSE `4` ).
        lo->add_string( i_name = `adjtype` i_value = lv_adjtype i_force = abap_true ).
      ENDIF.
      DATA(lv_rform) = |{ ls_adj-org_serial }|.
      DATA(lv_rserial) = lv_rform.
      " Ký hiệu FPT gồm mẫu số ở đầu (1C25MAG): rform = ký tự đầu
      IF strlen( lv_rform ) > 1.
        lv_rform   = lv_rform(1).
        lv_rserial = lv_rserial+1.
      ENDIF.
      lo->begin_object( `ref`
        )->add_string( i_name = `rform`   i_value = lv_rform   i_force = abap_true
        )->add_string( i_name = `rserial` i_value = lv_rserial i_force = abap_true
        )->add_string( i_name = `rseq`    i_value = |{ ls_adj-org_seq }| i_force = abap_true
        )->add_string( i_name = `ridt`    i_value = fmt_datetime( i_date = ls_adj-org_inv_date
                                                                  i_time = ls_hdr-inv_time )
                       i_force = abap_true
        )->end_object( ).
      DATA(lv_class) = zcl_hddt_json=>get_value( it_values = is_request-params i_path = `class` ).
      IF lv_class IS NOT INITIAL.
        lo->add_string( i_name = `class` i_value = lv_class i_force = abap_true ).
      ENDIF.
    ELSEIF lv_is_adjust = abap_true.
      lo->begin_object( `adj`
        )->add_string( i_name  = `seq`
                       i_value = |1-{ ls_adj-org_serial }-{ ls_adj-org_seq }|
                       i_force = abap_true
        )->add_string( i_name  = `rdt`
                       i_value = fmt_datetime(
                         i_date = COND #( WHEN ls_adj-doc_ref_date IS NOT INITIAL
                                           THEN ls_adj-doc_ref_date
                                           ELSE ls_hdr-inv_date )
                         i_time = ls_hdr-inv_time )
        )->add_string( i_name = `ref` i_value = COND string(
                         WHEN ls_adj-doc_ref_no IS NOT INITIAL
                         THEN ls_adj-doc_ref_no ELSE |{ ls_hdr-idkey }| )
        )->add_string( i_name = `rea` i_value = build_adjust_note( ls_adj )
        )->end_object( ).

      " ud: '1' điều chỉnh tăng, '0' điều chỉnh giảm
      IF ls_adj-adj_direction = '1' OR ls_adj-adj_direction = '0'.
        lo->add_string( i_name  = `ud`
                        i_value = |{ ls_adj-adj_direction }|
                        i_force = abap_true ).
      ENDIF.
      " Điều chỉnh kiểu mới (chỉ ghi phần chênh lệch)
      lo->add_string( i_name = `adj_only_add` i_value = `1` i_force = abap_true ).
    ENDIF.

    lo->add_ext( ls_inv-ext ).
    lo->end_object( ).                       " inv
    lo->end_object( ).                       " root

    r_payload = lo->get_json( ).

  ENDMETHOD.


  METHOD build_cancel.

    " §3.7.3 cancel-invoice (huỷ theo TT78)
    DATA(ls_hdr) = is_request-invoice-header.
    DATA(ls_adj) = is_request-invoice-adjust.

    DATA(lv_serial) = |{ ls_hdr-serial }|.
    DATA(lv_seq)    = |{ ls_hdr-seq }|.
    DATA(lv_form)   = |{ ls_hdr-template }|.
    DATA(lv_idt)    = fmt_datetime( i_date = ls_hdr-inv_date
                                    i_time = ls_hdr-inv_time ).

    IF lv_seq IS INITIAL.
      DATA(ls_reg) = zcl_hddt_log=>read_invoice(
                       i_bukrs     = is_request-bukrs
                       i_gjahr     = is_request-gjahr
                       i_src_type  = is_request-src_type
                       i_src_docno = is_request-src_docno ).
      lv_serial = |{ ls_reg-serial }|.
      lv_seq    = |{ ls_reg-seq }|.
      lv_form   = |{ ls_reg-template }|.
      IF ls_reg-issue_date IS NOT INITIAL.
        lv_idt = fmt_datetime( i_date = ls_reg-issue_date
                               i_time = ls_reg-inv_time ).
      ENDIF.
    ENDIF.

    IF lv_seq IS INITIAL OR lv_serial IS INITIAL.
      zcx_hddt_error=>raise_text(
        |Không xác định được ký hiệu / số hoá đơn cần huỷ cho chứng từ | &&
        |{ is_request-src_docno }/{ is_request-gjahr }.| ).
    ENDIF.

    DATA(lv_place) = get_config( )->get_param(
                       i_key   = gc_parm-place
                       i_bukrs = is_request-bukrs ).
    IF lv_place IS INITIAL.
      lv_place = is_request-invoice-header-place.
    ENDIF.

    DATA(lo) = NEW zcl_hddt_json( ).
    lo->begin_object( ).
    lo->add_string( i_name = `lang` i_value = `vi` i_force = abap_true ).
    add_user_node( io_json = lo is_cred = is_cred ).

    lo->begin_object( `wrongnotice`
      )->add_string( i_name = `stax` i_value = is_cred-taxcode i_force = abap_true
      )->add_string( i_name  = `noti_taxtype`
                     i_value = COND string(
                       WHEN ls_adj-doc_ref_no IS NOT INITIAL THEN `2` ELSE `1` )
                     i_force = abap_true
      )->add_string( i_name = `noti_taxnum` i_value = ls_adj-doc_ref_no
      )->add_string( i_name = `noti_taxdt`
                     i_value = fmt_datetime( ls_adj-doc_ref_date )
      )->add_string( i_name = `budget_relationid`
                     i_value = is_request-invoice-buyer-budget_code
      )->add_string( i_name = `place` i_value = lv_place i_force = abap_true ).

    lo->begin_array( `items`
      )->begin_object(
      )->add_string( i_name = `form`   i_value = lv_form   i_force = abap_true
      )->add_string( i_name = `serial` i_value = lv_serial i_force = abap_true
      )->add_string( i_name = `seq`    i_value = lv_seq    i_force = abap_true
      )->add_string( i_name = `idt`    i_value = lv_idt    i_force = abap_true
      )->add_string( i_name = `type_ref` i_value = `1`     i_force = abap_true
      )->add_string( i_name = `noti_type` i_value = `1`    i_force = abap_true
      )->add_string( i_name = `rea`    i_value = ls_adj-reason
      )->end_object(
      )->end_array( ).

    lo->end_object( ).                       " wrongnotice
    lo->end_object( ).                       " root

    r_payload = lo->get_json( ).

  ENDMETHOD.


  METHOD api_v3.

    " Tham số API_VERSION (theo NCC/công ty): '3.2' = tài liệu NĐ70 v3.2
    DATA(lv_ver) = get_config( )->get_param( i_key      = zif_hddt_types=>gc_parm-api_version
                                             i_provider = gc_provider
                                             i_bukrs    = i_bukrs ).
    CONDENSE lv_ver NO-GAPS.
    r_v3 = xsdbool( lv_ver IS NOT INITIAL AND lv_ver(1) >= '3' ).

  ENDMETHOD.


  METHOD build_issue.

    " { lang, user?, inv: { stax, sid } } — không truyền lại nội dung hoá đơn
    DATA(lv_lang) = get_config( )->get_param( gc_parm-lang ).
    IF lv_lang IS INITIAL.
      lv_lang = 'vi'.
    ENDIF.

    DATA(lo) = NEW zcl_hddt_json( ).
    lo->begin_object( ).
    lo->add_string( i_name = `lang` i_value = lv_lang i_force = abap_true ).
    add_user_node( io_json = lo is_cred = is_cred ).
    lo->begin_object( `inv`
      )->add_string( i_name = `stax` i_value = is_cred-taxcode i_force = abap_true
      )->add_string( i_name = `sid`  i_value = is_request-invoice-header-idkey
                     i_force = abap_true
      )->end_object( ).
    lo->end_object( ).

    r_payload = lo->get_json( ).

  ENDMETHOD.


  METHOD build_approve.

    " { lang, user?, inv: { stax, sid | form+serial+seq, notsendmail, sendfile } }
    DATA(lv_lang) = get_config( )->get_param( gc_parm-lang ).
    IF lv_lang IS INITIAL.
      lv_lang = 'vi'.
    ENDIF.
    DATA(ls_hdr) = is_request-invoice-header.

    DATA(lo) = NEW zcl_hddt_json( ).
    lo->begin_object( ).
    lo->add_string( i_name = `lang` i_value = lv_lang i_force = abap_true ).
    add_user_node( io_json = lo is_cred = is_cred ).
    lo->begin_object( `inv` ).
    lo->add_string( i_name = `stax` i_value = is_cred-taxcode i_force = abap_true ).
    IF ls_hdr-idkey IS NOT INITIAL.
      lo->add_string( i_name = `sid` i_value = ls_hdr-idkey i_force = abap_true ).
    ELSE.
      lo->add_string( i_name = `form`   i_value = ls_hdr-template i_force = abap_true
        )->add_string( i_name = `serial` i_value = ls_hdr-serial   i_force = abap_true
        )->add_string( i_name = `seq`    i_value = ls_hdr-seq      i_force = abap_true ).
    ENDIF.
    DATA(lv_nsm) = zcl_hddt_json=>get_value( it_values = is_request-params i_path = `notsendmail` ).
    IF lv_nsm IS NOT INITIAL.
      lo->add_string( i_name = `notsendmail` i_value = lv_nsm i_force = abap_true ).
    ENDIF.
    DATA(lv_sf) = zcl_hddt_json=>get_value( it_values = is_request-params i_path = `sendfile` ).
    IF lv_sf IS NOT INITIAL.
      lo->add_string( i_name = `sendfile` i_value = lv_sf i_force = abap_true ).
    ENDIF.
    lo->end_object( ).
    lo->end_object( ).

    r_payload = lo->get_json( ).

  ENDMETHOD.


  METHOD build_delete.

    " §3.10.3 del-invoice : { user, sid, stax }
    DATA(lo) = NEW zcl_hddt_json( ).
    lo->begin_object( ).
    add_user_node( io_json = lo is_cred = is_cred ).
    lo->add_string( i_name = `sid`
                    i_value = is_request-invoice-header-idkey
                    i_force = abap_true
      )->add_string( i_name = `stax` i_value = is_cred-taxcode
                     i_force = abap_true
      )->end_object( ).

    r_payload = lo->get_json( ).

  ENDMETHOD.


  METHOD get_vrt.

    " Cho phép khách hàng ghi đè bằng bảng ánh xạ TAXRATE nếu FPT yêu
    " cầu mã khác (ví dụ 'KCT' thay cho -1).
    DATA(lv_mapped) = map_val( i_map_type = zif_hddt_types=>gc_map_type-tax_rate
                               i_value    = i_tax_rate ).

    " map_val trả lại nguyên giá trị SAP khi chưa cấu hình -> tự chuẩn hoá
    IF lv_mapped CS `.` OR lv_mapped IS INITIAL.
      r_vrt = zcl_hddt_json=>format_number( i_value    = i_tax_rate
                                              i_decimals = 0 ).
    ELSE.
      r_vrt = lv_mapped.
    ENDIF.

  ENDMETHOD.


  METHOD zif_hddt_provider~parse_response.

    DATA(lv_ok_http) = xsdbool( i_http_code >= 200 AND i_http_code < 300 ).

    " Lấy file (type = pdf/xml): body là nội dung file, engine gán từ body_x
    IF i_action = zif_hddt_types=>gc_action-get_file AND lv_ok_http = abap_true.
      DATA(lv_ftype) = zcl_hddt_json=>get_value( it_values = is_request-params i_path = `type` ).
      cs_result-success   = abap_true.
      cs_result-msgty     = 'S'.
      cs_result-file_name = |{ is_request-invoice-header-serial }{ is_request-invoice-header-seq }.| &&
                            |{ COND string( WHEN lv_ftype IS INITIAL THEN `pdf` ELSE lv_ftype ) }|.
      cs_result-message   = 'Đã lấy file hoá đơn'.
      RETURN.
    ENDIF.

    IF i_body IS INITIAL.
      cs_result-success = lv_ok_http.
      cs_result-message = |HTTP { i_http_code }: FPT không trả nội dung.|.
      RETURN.
    ENDIF.

    DATA(lv_body) = i_body.
    CONDENSE lv_body.

    " del-invoice trả về text thuần ("Delete complete" / "There are no
    " invoices to delete"), không phải JSON.
    IF substring( val = lv_body len = 1 ) <> `{`
       AND substring( val = lv_body len = 1 ) <> `[`.
      cs_result-success     = lv_ok_http.
      cs_result-prov_status = |{ i_http_code }|.
      cs_result-message     = substring( val = lv_body
                                        len = nmin( val1 = 255
                                                    val2 = strlen( lv_body ) ) ).
      RETURN.
    ENDIF.

    DATA lt_val TYPE zif_hddt_types=>ty_t_kv.
    TRY.
        lt_val = zcl_hddt_json=>parse( lv_body ).
      CATCH zcx_hddt_error.
        cs_result-success = lv_ok_http.
        cs_result-message = substring( val = lv_body
                                       len = nmin( val1 = 255
                                                   val2 = strlen( lv_body ) ) ).
        RETURN.
    ENDTRY.
    cs_result-fields = lt_val.

    DATA(lv_err) = zcl_hddt_json=>get_value_by_name( it_values = lt_val
                                                      i_name   = `error` ).
    DATA(lv_msg) = zcl_hddt_json=>get_value_by_name( it_values = lt_val
                                                      i_name   = `message` ).
    IF lv_msg IS INITIAL.
      lv_msg = zcl_hddt_json=>get_value_by_name( it_values = lt_val
                                                  i_name   = `mess` ).
    ENDIF.

    cs_result-serial     = zcl_hddt_json=>get_value_by_name(
                             it_values = lt_val i_name = `serial` ).
    cs_result-seq        = zcl_hddt_json=>get_value_by_name(
                             it_values = lt_val i_name = `seq` ).
    cs_result-template   = zcl_hddt_json=>get_value_by_name(
                             it_values = lt_val i_name = `form` ).
    cs_result-sec_code   = zcl_hddt_json=>get_value_by_name(
                             it_values = lt_val i_name = `sec` ).
    cs_result-inv_link   = zcl_hddt_json=>get_value_by_name(
                             it_values = lt_val i_name = `link` ).
    cs_result-idkey      = zcl_hddt_json=>get_value_by_name(
                             it_values = lt_val i_name = `sid` ).
    IF cs_result-idkey IS INITIAL.
      cs_result-idkey = is_request-invoice-header-idkey.
    ENDIF.

    " Ngày ký hoá đơn 'YYYY-MM-DD hh:mm:ss' -> DATS
    DATA(lv_adt) = zcl_hddt_json=>get_value_by_name( it_values = lt_val
                                                      i_name   = `adt` ).
    IF lv_adt IS INITIAL.
      lv_adt = zcl_hddt_json=>get_value_by_name( it_values = lt_val
                                                  i_name   = `idt` ).
    ENDIF.
    IF strlen( lv_adt ) >= 10.
      cs_result-issue_date = |{ lv_adt(4) }{ lv_adt+5(2) }{ lv_adt+8(2) }|.
    ENDIF.

    " §Phụ lục I: status 1 chờ cấp số, 2 chờ duyệt, 3 đã duyệt, 4 đã huỷ
    DATA(lv_status) = zcl_hddt_json=>get_value_by_name( it_values = lt_val
                                                         i_name   = `status` ).
    " §Phụ lục II: status_received 10 = CQT đã cấp mã
    DATA(lv_recv) = zcl_hddt_json=>get_value_by_name(
                      it_values = lt_val i_name = `status_received` ).

    cs_result-prov_status = COND #( WHEN lv_status IS NOT INITIAL
                                    THEN lv_status
                                    ELSE |{ i_http_code }| ).

    cs_result-success = xsdbool( lv_ok_http = abap_true AND lv_err IS INITIAL ).

    IF cs_result-success = abap_true.
      CASE lv_status.
        WHEN '1'. cs_result-status = zif_hddt_types=>gc_status-wait_seq.
        WHEN '2'. cs_result-status = zif_hddt_types=>gc_status-wait_appr.
        WHEN '3'. cs_result-status = zif_hddt_types=>gc_status-issued.
        WHEN '4'. cs_result-status = zif_hddt_types=>gc_status-cancelled.
        WHEN OTHERS.
      ENDCASE.
      IF lv_recv = '10'.
        cs_result-status = zif_hddt_types=>gc_status-coded.
        cs_result-mscqt  = zcl_hddt_json=>get_value_by_name(
                             it_values = lt_val i_name = `ic` ).
        IF cs_result-mscqt IS INITIAL.
          cs_result-mscqt = zcl_hddt_json=>get_value_by_name(
                              it_values = lt_val i_name = `ma_cqthu` ).
        ENDIF.
      ELSEIF lv_recv = '9'.
        " FS MAG 3.8: CQT kiểm tra không hợp lệ -> trạng thái 10 (ở đây 45)
        cs_result-status = zif_hddt_types=>gc_status-rejected.
      ENDIF.
    ENDIF.
    cs_result-tax_status = lv_recv.

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
