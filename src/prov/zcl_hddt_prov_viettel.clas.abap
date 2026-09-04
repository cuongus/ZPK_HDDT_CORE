*=====================================================================
* Tên/Mã     : ZCL_HDDT_PROV_VIETTEL
* Mô tả chung: Adapter cho Viettel SInvoice (api-vinvoice.viettel.vn).
*              Chuyển canonical model sang payload SInvoice v2 và bóc
*              response về ty_result.
*
*              [Nguồn tham chiếu]
*              - Mã ABAP đang chạy thật tại hệ EEMC, package ZPK_HDDT,
*                function ZFM_CREATE_E_INVOICES (cấu trúc
*                ZST_JSON_E_INVOICE: generalInvoiceInfo / buyerInfo /
*                sellerInfo / itemInfo / summarizeInfo / taxBreakdowns
*                / payments).
*              - Postman collection "New Collection" của Viettel: danh
*                sách endpoint mục 7.2 … 7.37.
*              [Unverified] Tên một số thẻ JSON lấy theo tên component
*              của cấu trúc DDIC trong mã cũ (mã cũ phải dùng bảng
*              ZTB_JSON_REPLACE để sửa lại chữ hoa/thường). Trước khi
*              go-live cần đối chiếu lại với tài liệu
*              "tailieu_mo_ta_webservice_hoadondientu_doitac" mục 7.2.
*              Sửa tên thẻ chỉ ảnh hưởng DUY NHẤT lớp này.
* Tham Số    : Đăng ký qua ZTB_HDDT_PROV: PROVIDER = 'VIETTEL',
*              CLASSNAME = 'ZCL_HDDT_PROV_VIETTEL'
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       28/08/2026    cuongus - CuongUS        abapGit     Tạo mới
*=====================================================================
CLASS zcl_hddt_prov_viettel DEFINITION
  PUBLIC
  INHERITING FROM zcl_hddt_prov_base
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    CONSTANTS gc_provider TYPE zde_hddt_prov VALUE 'VIETTEL' ##NO_TEXT.

    METHODS zif_hddt_provider~get_id         REDEFINITION .
    METHODS zif_hddt_provider~build_payload  REDEFINITION .
    METHODS zif_hddt_provider~parse_response REDEFINITION .

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
      RETURNING VALUE(r_payload) TYPE string .

    METHODS build_search
      IMPORTING is_request        TYPE zif_hddt_types=>ty_request
                is_cred           TYPE ztb_hddt_cred
      RETURNING VALUE(r_payload) TYPE string .

    METHODS build_get_file
      IMPORTING is_request        TYPE zif_hddt_types=>ty_request
                is_cred           TYPE ztb_hddt_cred
      RETURNING VALUE(r_payload) TYPE string .

    "! Quy đổi loại điều chỉnh của core sang adjustmentType của Viettel
    "! 1 = gốc, 3 = thay thế, 5 = điều chỉnh, 7 = xoá bỏ
    METHODS get_adjustment_type
      IMPORTING is_adjust      TYPE zif_hddt_types=>ty_adjust
      RETURNING VALUE(r_type) TYPE string .

    "! Quy đổi hình thức dòng hàng hoá sang thẻ SELECTION của Viettel
    "! (mục 6.6). Đây là thẻ quyết định dòng có sinh số thứ tự và có
    "! cộng vào tổng tiền thanh toán hay không — thiếu nó thì dòng ghi
    "! chú và dòng chiết khấu bị tính như hàng hoá bình thường.
    METHODS get_selection
      IMPORTING i_item_type        TYPE zde_hddt_itemtype
      RETURNING VALUE(r_selection) TYPE string .

ENDCLASS.



CLASS zcl_hddt_prov_viettel IMPLEMENTATION.

  METHOD zif_hddt_provider~get_id.

    r_provider = gc_provider.

  ENDMETHOD.


  METHOD zif_hddt_provider~build_payload.

    CASE i_action.

      WHEN zif_hddt_types=>gc_action-create_invoice
        OR zif_hddt_types=>gc_action-adjust_invoice
        OR zif_hddt_types=>gc_action-replace_invoice
        OR zif_hddt_types=>gc_action-create_draft
        OR zif_hddt_types=>gc_action-preview_draft
        OR zif_hddt_types=>gc_action-update_invoice.
        r_payload = build_invoice( is_request = is_request
                                    i_action  = i_action
                                    is_cred    = is_cred ).

      WHEN zif_hddt_types=>gc_action-cancel_invoice
        OR zif_hddt_types=>gc_action-delete_invoice.
        r_payload = build_cancel( is_request = is_request
                                   is_cred    = is_cred ).

      WHEN zif_hddt_types=>gc_action-search_invoice.
        r_payload = build_search( is_request = is_request
                                   is_cred    = is_cred ).

      WHEN zif_hddt_types=>gc_action-get_file.
        r_payload = build_get_file( is_request = is_request
                                     is_cred    = is_cred ).

      WHEN OTHERS.
        zcx_hddt_error=>raise_text(
          |Adapter VIETTEL chưa hỗ trợ nghiệp vụ { i_action }.| &&
          | Bổ sung trong ZCL_HDDT_PROV_VIETTEL~BUILD_PAYLOAD.| ).
    ENDCASE.

  ENDMETHOD.


  METHOD build_invoice.

    DATA(ls_inv) = is_request-invoice.
    DATA(ls_hdr) = ls_inv-header.
    DATA(ls_adj) = ls_inv-adjust.

    DATA(lv_adj_type) = get_adjustment_type( ls_adj ).
    DATA(lv_is_adjust) = xsdbool( lv_adj_type = '5' ).
    DATA(lv_increase)  = xsdbool( ls_adj-adj_direction = '1' ).

    DATA(lo) = NEW zcl_hddt_json( ).

    lo->begin_object( ).

*---- generalInvoiceInfo ----------------------------------------------*
    lo->begin_object( `generalInvoiceInfo`
      )->add_string( i_name  = `invoiceType`
                     i_value = ls_hdr-inv_type   i_force = abap_true
      )->add_string( i_name  = `templateCode`
                     i_value = ls_hdr-template   i_force = abap_true
      )->add_string( i_name  = `invoiceSeries`
                     i_value = ls_hdr-serial     i_force = abap_true
      )->add_string( i_name  = `currencyCode`
                     i_value = ls_hdr-currency   i_force = abap_true
      )->add_string( i_name  = `adjustmentType`
                     i_value = lv_adj_type       i_force = abap_true
      )->add_string( i_name  = `transactionUuid`
                     i_value = ls_hdr-idkey      i_force = abap_true
      )->add_string( i_name  = `invoiceIssuedDate`
                     i_value = to_epoch_millis( i_date = ls_hdr-inv_date
                                                 i_time = ls_hdr-inv_time )
                     i_force = abap_true ).

    " Tỷ giá: VND luôn là 1
    lo->add_number( i_name     = `exchangeRate`
                    i_value    = COND #( WHEN ls_hdr-currency = 'VND'
                                          THEN 1 ELSE ls_hdr-exch_rate )
                    i_decimals = 4 ).

    lo->add_bool( i_name = `paymentStatus`      i_value = ls_hdr-paid
      )->add_bool( i_name = `cusGetInvoiceRight` i_value = abap_true ).

    " Ghi chú: hoá đơn gốc dùng khoá đối chiếu để tra soát,
    " hoá đơn điều chỉnh/thay thế dùng câu diễn giải chuẩn.
    IF lv_adj_type = '1'.
      lo->add_string( i_name  = `invoiceNote`
                      i_value = COND string( WHEN ls_hdr-note IS NOT INITIAL
                                              THEN ls_hdr-note
                                              ELSE |{ ls_hdr-idkey }| ) ).
    ELSE.
      lo->add_string( i_name  = `invoiceNote`
                      i_value = build_adjust_note( ls_adj ) ).
    ENDIF.

    " Thông tin hoá đơn gốc — chỉ gửi khi thực sự có (mã cũ phải dùng
    " REPLACE để xoá cặp thẻ rỗng; writer ở đây tự bỏ khi rỗng).
    IF ls_adj-org_serial IS NOT INITIAL OR ls_adj-org_seq IS NOT INITIAL.
      lo->add_string( i_name  = `originalInvoiceId`
                      i_value = |{ ls_adj-org_serial }{ ls_adj-org_seq }|
        )->add_string( i_name  = `originalInvoiceIssueDate`
                       i_value = to_epoch_millis( ls_adj-org_inv_date ) ).
    ENDIF.

    " 1 = điều chỉnh tiền, 2 = điều chỉnh thông tin
    IF lv_is_adjust = abap_true.
      lo->add_string( i_name  = `adjustmentInvoiceType`
                      i_value = COND string( WHEN ls_adj-adj_direction = '2'
                                              THEN `2` ELSE `1` ) ).
    ENDIF.

    " Lý do sai sót — thẻ RIÊNG, tối đa 255 ký tự (mục 6.2 adjustedNote).
    " Khác invoiceNote: adjustedNote là lý do điều chỉnh/thay thế,
    " invoiceNote là ghi chú in trên hoá đơn.
    IF lv_adj_type <> '1' AND ls_adj-reason IS NOT INITIAL.
      lo->add_string( i_name  = `adjustedNote`
                      i_value = ls_adj-reason ).
    ENDIF.

    lo->end_object( ).

*---- buyerInfo -------------------------------------------------------*
    DATA(ls_buy) = ls_inv-buyer.
    lo->begin_object( `buyerInfo`
      )->add_string( i_name = `buyerName`         i_value = ls_buy-person_name
      )->add_string( i_name = `buyerLegalName`    i_value = ls_buy-legal_name
      )->add_string( i_name = `buyerTaxCode`      i_value = ls_buy-tax_code
      )->add_string( i_name = `buyerAddressLine`  i_value = ls_buy-address
      )->add_string( i_name = `buyerPhoneNumber`  i_value = ls_buy-phone
      )->add_string( i_name = `buyerEmail`        i_value = ls_buy-email
      )->add_string( i_name = `buyerBankName`     i_value = ls_buy-bank_name
      )->add_string( i_name = `buyerBankAccount`  i_value = ls_buy-bank_acct
      )->add_string( i_name = `buyerCode`         i_value = ls_buy-code
      )->add_string( i_name = `buyerIdNo`         i_value = ls_buy-id_number
      )->add_string( i_name = `buyerBudgetCode`   i_value = ls_buy-budget_code ).
    IF ls_buy-not_get_invoice = abap_true.
      lo->add_string( i_name = `buyerNotGetInvoice` i_value = `1`
                      i_force = abap_true ).
    ENDIF.
    lo->end_object( ).

*---- sellerInfo ------------------------------------------------------*
    DATA(ls_sel) = ls_inv-seller.
    lo->begin_object( `sellerInfo`
      )->add_string( i_name = `sellerLegalName`   i_value = ls_sel-name
      )->add_string( i_name = `sellerTaxCode`     i_value = ls_sel-tax_code
                     i_force = abap_true
      )->add_string( i_name = `sellerAddressLine` i_value = ls_sel-address
      )->add_string( i_name = `sellerPhoneNumber` i_value = ls_sel-phone
      )->add_string( i_name = `sellerEmail`       i_value = ls_sel-email
      )->add_string( i_name = `sellerBankName`    i_value = ls_sel-bank_name
      )->add_string( i_name = `sellerBankAccount` i_value = ls_sel-bank_acct
      )->end_object( ).

*---- itemInfo --------------------------------------------------------*
    lo->begin_array( `itemInfo` ).
    LOOP AT ls_inv-items ASSIGNING FIELD-SYMBOL(<fs_item>).
      DATA(lv_selection) = get_selection( <fs_item>-item_type ).

      lo->begin_object( ).
      lo->add_number( i_name = `lineNumber` i_value = <fs_item>-line_no
                      i_decimals = 0 ).
      lo->add_number( i_name = `selection` i_value = lv_selection
                      i_decimals = 0 ).
      lo->add_string( i_name = `itemCode`  i_value = <fs_item>-item_code
        )->add_string( i_name = `itemName` i_value = <fs_item>-item_name
                       i_force = abap_true
        )->add_string( i_name = `unitName` i_value = <fs_item>-unit ).
      lo->add_number( i_name = `unitPrice` i_value = <fs_item>-price
        )->add_number( i_name = `quantity`  i_value = <fs_item>-quantity
        )->add_number( i_name = `itemTotalAmountWithoutTax`
                       i_value = <fs_item>-amount
        )->add_number( i_name = `taxPercentage` i_value = <fs_item>-tax_rate
                       i_decimals = 2
        )->add_number( i_name = `taxAmount` i_value = <fs_item>-tax_amount
        )->add_number( i_name = `itemTotalAmountWithTax`
                       i_value = <fs_item>-total ).
      IF <fs_item>-disc_percent IS NOT INITIAL.
        lo->add_number( i_name = `discount` i_value = <fs_item>-disc_percent
                        i_decimals = 2 ).
      ENDIF.
      IF <fs_item>-disc_amount IS NOT INITIAL.
        lo->add_number( i_name = `itemDiscount` i_value = <fs_item>-disc_amount ).
      ENDIF.
      IF <fs_item>-note IS NOT INITIAL.
        lo->add_string( i_name = `itemNote` i_value = <fs_item>-note ).
      ENDIF.
      " Dòng chiết khấu (selection = 3) BẮT BUỘC isIncreaseItem = false
      " để hệ thống hiểu là giảm tiền — kể cả trên hoá đơn gốc (mục 6.6).
      " Ngoài ra chỉ hoá đơn điều chỉnh mới gửi thẻ này.
      IF lv_selection = `3`.
        lo->add_bool_text( i_name = `isIncreaseItem` i_value = abap_false ).
      ELSEIF lv_is_adjust = abap_true.
        lo->add_bool_text( i_name = `isIncreaseItem` i_value = lv_increase ).
      ENDIF.
      lo->add_ext( <fs_item>-ext ).
      lo->end_object( ).
    ENDLOOP.
    lo->end_array( ).

*---- summarizeInfo ---------------------------------------------------*
    DATA(ls_sum) = ls_inv-summary.
    lo->begin_object( `summarizeInfo`
      )->add_number( i_name = `sumOfTotalLineAmountWithoutTax`
                     i_value = ls_sum-amount_wo_tax
      )->add_number( i_name = `totalAmountWithoutTax`
                     i_value = ls_sum-amount_wo_tax
      )->add_number( i_name = `totalTaxAmount`  i_value = ls_sum-tax_amount
      )->add_number( i_name = `totalAmountWithTax` i_value = ls_sum-total
      )->add_number( i_name = `discountAmount` i_value = ls_sum-disc_amount
      )->add_string( i_name = `totalAmountWithTaxInWords`
                     i_value = ls_sum-amount_in_words ).
    IF lv_is_adjust = abap_true.
      lo->add_bool_text( i_name = `isTotalAmountPos`        i_value = lv_increase
        )->add_bool_text( i_name = `isTotalTaxAmountPos`     i_value = lv_increase
        )->add_bool_text( i_name = `isTotalAmtWithoutTaxPos` i_value = lv_increase
        )->add_bool_text( i_name = `isDiscountAmtPos`        i_value = lv_increase ).
    ENDIF.
    lo->end_object( ).

*---- taxBreakdowns ---------------------------------------------------*
    lo->begin_array( `taxBreakdowns` ).
    LOOP AT ls_inv-taxes ASSIGNING FIELD-SYMBOL(<fs_tax>).
      lo->begin_object(
        )->add_number( i_name = `taxPercentage` i_value = <fs_tax>-tax_rate
                       i_decimals = 2
        )->add_number( i_name = `taxableAmount` i_value = <fs_tax>-taxable_amt
        )->add_number( i_name = `taxAmount`     i_value = <fs_tax>-tax_amt ).
      IF lv_is_adjust = abap_true.
        lo->add_bool_text( i_name = `taxableAmountPos` i_value = lv_increase
          )->add_bool_text( i_name = `taxAmountPos`     i_value = lv_increase ).
      ENDIF.
      lo->end_object( ).
    ENDLOOP.
    lo->end_array( ).

*---- payments --------------------------------------------------------*
    lo->begin_array( `payments` ).
    LOOP AT ls_inv-payments ASSIGNING FIELD-SYMBOL(<fs_pay>).
      lo->begin_object(
        )->add_string( i_name  = `paymentMethod`
                       i_value = <fs_pay>-method_code
        )->add_string( i_name  = `paymentMethodName`
                       i_value = <fs_pay>-method_name i_force = abap_true
        )->end_object( ).
    ENDLOOP.
    lo->end_array( ).

*---- phần mở rộng cấp hoá đơn ---------------------------------------*
    lo->add_ext( ls_inv-ext ).

    lo->end_object( ).
    r_payload = lo->get_json( ).

  ENDMETHOD.


  METHOD build_cancel.

    " Mục 7.9: Content-Type = application/x-www-form-urlencoded (KHÔNG
    " phải JSON), và strIssueDate / additionalReferenceDate là
    " milliseconds since epoch — không phải chuỗi ngày.
    DATA(ls_hdr) = is_request-invoice-header.
    DATA(ls_adj) = is_request-invoice-adjust.

    DATA(lv_seq)    = |{ ls_hdr-seq }|.
    DATA(lv_serial) = |{ ls_hdr-serial }|.
    DATA(lv_tmpl)   = |{ ls_hdr-template }|.
    DATA(lv_date)   = ls_hdr-inv_date.
    DATA(lv_time)   = ls_hdr-inv_time.

    IF lv_seq IS INITIAL.
      DATA(ls_reg) = zcl_hddt_log=>read_invoice(
                       i_bukrs     = is_request-bukrs
                       i_gjahr     = is_request-gjahr
                       i_src_type  = is_request-src_type
                       i_src_docno = is_request-src_docno ).
      lv_seq    = |{ ls_reg-seq }|.
      lv_serial = |{ ls_reg-serial }|.
      lv_tmpl   = |{ ls_reg-template }|.
      IF ls_reg-issue_date IS NOT INITIAL.
        lv_date = ls_reg-issue_date.
        lv_time = ls_reg-inv_time.
      ENDIF.
    ENDIF.

    IF lv_seq IS INITIAL.
      zcx_hddt_error=>raise_text(
        |Không xác định được số hoá đơn cần huỷ cho chứng từ | &&
        |{ is_request-src_docno }/{ is_request-gjahr }.| ).
    ENDIF.

    " additionalReferenceDesc là BẮT BUỘC (mục 7.9, tối đa 400) — tên
    " văn bản thoả thuận huỷ. Không có thì dùng lý do huỷ để tránh 400.
    DATA(lv_ref_desc) = COND string( WHEN ls_adj-doc_ref_no IS NOT INITIAL
                                     THEN ls_adj-doc_ref_no
                                     ELSE ls_adj-reason ).
    DATA(lv_ref_date) = COND #( WHEN ls_adj-doc_ref_date IS NOT INITIAL
                                THEN ls_adj-doc_ref_date
                                ELSE sy-datum ).

    r_payload = build_form( VALUE #(
      ( name  = `supplierTaxCode`
        value = |{ is_cred-taxcode }| )
      ( name  = `templateCode`
        value = lv_tmpl )
      ( name  = `invoiceNo`
        value = |{ lv_serial }{ lv_seq }| )
      ( name  = `strIssueDate`
        value = to_epoch_millis( i_date = lv_date i_time = lv_time ) )
      ( name  = `additionalReferenceDesc`
        value = lv_ref_desc )
      ( name  = `additionalReferenceDate`
        value = to_epoch_millis( lv_ref_date ) )
      ( name  = `reasonDelete`
        value = ls_adj-reason ) ) ).

  ENDMETHOD.


  METHOD build_search.

    " Mục 7.21: form-urlencoded, đúng 2 tham số
    r_payload = build_form( VALUE #(
      ( name  = `supplierTaxCode`
        value = |{ is_cred-taxcode }| )
      ( name  = `transactionUuid`
        value = |{ is_request-invoice-header-idkey }| ) ) ).

  ENDMETHOD.


  METHOD build_get_file.

    DATA(ls_hdr) = is_request-invoice-header.

    DATA(lv_type) = zcl_hddt_json=>get_value(
                      it_values = is_request-params
                      i_path   = `fileType` ).
    IF lv_type IS INITIAL.
      lv_type = `PDF`.
    ENDIF.

    r_payload = NEW zcl_hddt_json( )->begin_object(
      )->add_string( i_name = `supplierTaxCode` i_value = is_cred-taxcode
                     i_force = abap_true
      )->add_string( i_name = `templateCode` i_value = ls_hdr-template
      )->add_string( i_name = `invoiceNo`
                     i_value = |{ ls_hdr-serial }{ ls_hdr-seq }|
                     i_force = abap_true
      )->add_string( i_name = `fileType` i_value = lv_type i_force = abap_true
      )->end_object(
      )->get_json( ).

  ENDMETHOD.


  METHOD get_selection.

    " Cho phép ghi đè bằng ánh xạ ITEMTYPE trong ZTB_HDDT_MAP, để
    " khách hàng dùng giá trị khác mà không phải sửa code.
    DATA(lv_mapped) = map_val( i_map_type = zif_hddt_types=>gc_map_type-item_type
                               i_value    = i_item_type ).
    IF lv_mapped IS NOT INITIAL AND lv_mapped <> |{ i_item_type }|.
      r_selection = lv_mapped.
      RETURN.
    ENDIF.

    " Mặc định theo mục 6.6, cột "Đối với Thông tư 78":
    "   1 Hàng hoá · 2 Ghi chú · 3 Chiết khấu · 4 Phí khác
    "   5 Khuyến mại · 6 Hàng hoá đặc trưng (NĐ70)
    CASE i_item_type.
      WHEN '1'.    r_selection = `5`.   " khuyến mại
      WHEN '2'.    r_selection = `3`.   " chiết khấu thương mại
      WHEN '3'.    r_selection = `2`.   " ghi chú / diễn giải
      WHEN OTHERS. r_selection = `1`.   " hàng hoá, dịch vụ
    ENDCASE.

  ENDMETHOD.


  METHOD get_adjustment_type.

    CASE is_adjust-adj_type.
      WHEN zif_hddt_types=>gc_adj_type-replace.  r_type = `3`.
      WHEN zif_hddt_types=>gc_adj_type-adjust.   r_type = `5`.
      WHEN zif_hddt_types=>gc_adj_type-cancel.   r_type = `7`.
      WHEN OTHERS.                                 r_type = `1`.
    ENDCASE.

  ENDMETHOD.


  METHOD zif_hddt_provider~parse_response.

    IF i_body IS INITIAL.
      cs_result-success = xsdbool( i_http_code >= 200 AND i_http_code < 300 ).
      cs_result-message = |HTTP { i_http_code }: nhà cung cấp không trả nội dung.|.
      RETURN.
    ENDIF.

    DATA lt_val TYPE zif_hddt_types=>ty_t_kv.
    TRY.
        lt_val = zcl_hddt_json=>parse( i_body ).
      CATCH zcx_hddt_error.
        " Response không phải JSON (ví dụ getInvoiceRepresentationFile
        " trả về nhị phân, hoặc trang lỗi HTML của gateway)
        cs_result-success = xsdbool( i_http_code >= 200 AND i_http_code < 300 ).
        cs_result-message = substring( val = i_body
                                       len = nmin( val1 = 255
                                                   val2 = strlen( i_body ) ) ).
        RETURN.
    ENDTRY.
    cs_result-fields = lt_val.

    DATA(lv_error) = zcl_hddt_json=>get_value_by_name( it_values = lt_val
                                                        i_name   = `errorCode` ).
    DATA(lv_desc)  = zcl_hddt_json=>get_value_by_name( it_values = lt_val
                                                        i_name   = `description` ).
    IF lv_desc IS INITIAL.
      lv_desc = zcl_hddt_json=>get_value_by_name( it_values = lt_val
                                                   i_name   = `message` ).
    ENDIF.

    cs_result-prov_status = COND #( WHEN lv_error IS NOT INITIAL
                                    THEN lv_error
                                    ELSE |{ i_http_code }| ).

    " SInvoice trả errorCode = null khi thành công
    cs_result-success = xsdbool( i_http_code >= 200 AND i_http_code < 300
                                 AND lv_error IS INITIAL ).

    DATA(lv_inv_no) = zcl_hddt_json=>get_value_by_name( it_values = lt_val
                                                         i_name   = `invoiceNo` ).
    IF lv_inv_no IS NOT INITIAL.
      " Mục 7.9 / 7.21: invoiceNo = ký hiệu hoá đơn + số hoá đơn
      " (ví dụ AB/19E0000522). Ký hiệu đã biết từ cấu hình nên tách
      " bằng cách bỏ TIỀN TỐ — không đoán theo chữ số ở cuối, vì ký
      " hiệu theo TT78 có thể kết thúc bằng số (ví dụ K23T01).
      DATA(lv_known) = |{ is_request-invoice-header-serial }|.
      CONDENSE lv_known NO-GAPS.

      IF lv_known IS NOT INITIAL
         AND strlen( lv_inv_no ) > strlen( lv_known )
         AND substring( val = lv_inv_no len = strlen( lv_known ) ) = lv_known.
        cs_result-serial = lv_known.
        cs_result-seq    = substring( val = lv_inv_no off = strlen( lv_known ) ).
      ELSE.
        " Không khớp tiền tố (đổi ký hiệu giữa kỳ…) -> tách chữ số cuối
        DATA lv_digits TYPE string.
        DATA lv_i      TYPE i.
        CLEAR lv_digits.
        lv_i = strlen( lv_inv_no ).
        WHILE lv_i > 0.
          DATA(lv_c) = substring( val = lv_inv_no off = lv_i - 1 len = 1 ).
          IF lv_c CO '0123456789'.
            lv_digits = lv_c && lv_digits.
            lv_i = lv_i - 1.
          ELSE.
            EXIT.
          ENDIF.
        ENDWHILE.
        IF lv_digits IS NOT INITIAL AND lv_i > 0.
          cs_result-serial = substring( val = lv_inv_no len = lv_i ).
          cs_result-seq    = lv_digits.
        ELSE.
          cs_result-seq = lv_inv_no.
        ENDIF.
      ENDIF.
    ENDIF.

    cs_result-mscqt = zcl_hddt_json=>get_value_by_name(
                        it_values = lt_val i_name = `codeOfTax` ).
    IF cs_result-mscqt IS INITIAL.
      cs_result-mscqt = zcl_hddt_json=>get_value_by_name(
                          it_values = lt_val i_name = `reservationCode` ).
    ENDIF.

    cs_result-idkey = zcl_hddt_json=>get_value_by_name(
                        it_values = lt_val i_name = `transactionUuid` ).
    IF cs_result-idkey IS INITIAL.
      cs_result-idkey = is_request-invoice-header-idkey.
    ENDIF.

    " File hoá đơn trả về dạng base64 trong thẻ fileToBytes
    DATA(lv_file) = zcl_hddt_json=>get_value_by_name(
                      it_values = lt_val i_name = `fileToBytes` ).
    IF lv_file IS NOT INITIAL.
      cs_result-file_content = platform( )->decode_base64( lv_file ).
      IF cs_result-file_content IS NOT INITIAL.
        cs_result-file_name = |{ cs_result-serial }{ cs_result-seq }.pdf|.
      ENDIF.
    ENDIF.

    IF lv_desc IS NOT INITIAL.
      cs_result-message = lv_desc.
    ELSEIF cs_result-success = abap_true.
      cs_result-message = |Thành công. Số hoá đơn: { cs_result-serial }{ cs_result-seq }|.
    ELSE.
      cs_result-message = substring( val = i_body
                                     len = nmin( val1 = 255
                                                 val2 = strlen( i_body ) ) ).
    ENDIF.

  ENDMETHOD.

ENDCLASS.
