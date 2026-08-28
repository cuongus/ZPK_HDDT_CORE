*=====================================================================
* Tên/Mã     : ZFIC_HDDT_PROV_VIETTEL
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
* Tham Số    : Đăng ký qua ZFIT_HDDT_PROV: PROVIDER = 'VIETTEL',
*              CLASSNAME = 'ZFIC_HDDT_PROV_VIETTEL'
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       28/08/2026    cuongus - CuongUS        abapGit     Tạo mới
*=====================================================================
CLASS zfic_hddt_prov_viettel DEFINITION
  PUBLIC
  INHERITING FROM zfic_hddt_prov_base
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    CONSTANTS gc_provider TYPE zfide_hddt_prov VALUE 'VIETTEL' ##NO_TEXT.

    METHODS zfiif_hddt_provider~get_id         REDEFINITION .
    METHODS zfiif_hddt_provider~build_payload  REDEFINITION .
    METHODS zfiif_hddt_provider~parse_response REDEFINITION .

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
      RETURNING VALUE(rv_payload) TYPE string .

    METHODS build_search
      IMPORTING is_request        TYPE zfiif_hddt_types=>ty_request
                is_cred           TYPE zfit_hddt_cred
      RETURNING VALUE(rv_payload) TYPE string .

    METHODS build_get_file
      IMPORTING is_request        TYPE zfiif_hddt_types=>ty_request
                is_cred           TYPE zfit_hddt_cred
      RETURNING VALUE(rv_payload) TYPE string .

    "! Quy đổi loại điều chỉnh của core sang adjustmentType của Viettel
    "! 1 = gốc, 3 = thay thế, 5 = điều chỉnh, 7 = xoá bỏ
    METHODS get_adjustment_type
      IMPORTING is_adjust      TYPE zfiif_hddt_types=>ty_adjust
      RETURNING VALUE(rv_type) TYPE string .

ENDCLASS.



CLASS zfic_hddt_prov_viettel IMPLEMENTATION.

  METHOD zfiif_hddt_provider~get_id.

    rv_provider = gc_provider.

  ENDMETHOD.


  METHOD zfiif_hddt_provider~build_payload.

    CASE iv_action.

      WHEN zfiif_hddt_types=>gc_action-create_invoice
        OR zfiif_hddt_types=>gc_action-adjust_invoice
        OR zfiif_hddt_types=>gc_action-replace_invoice
        OR zfiif_hddt_types=>gc_action-create_draft
        OR zfiif_hddt_types=>gc_action-preview_draft
        OR zfiif_hddt_types=>gc_action-update_invoice.
        rv_payload = build_invoice( is_request = is_request
                                    iv_action  = iv_action
                                    is_cred    = is_cred ).

      WHEN zfiif_hddt_types=>gc_action-cancel_invoice
        OR zfiif_hddt_types=>gc_action-delete_invoice.
        rv_payload = build_cancel( is_request = is_request
                                   is_cred    = is_cred ).

      WHEN zfiif_hddt_types=>gc_action-search_invoice.
        rv_payload = build_search( is_request = is_request
                                   is_cred    = is_cred ).

      WHEN zfiif_hddt_types=>gc_action-get_file.
        rv_payload = build_get_file( is_request = is_request
                                     is_cred    = is_cred ).

      WHEN OTHERS.
        zficx_hddt_error=>raise_text(
          |Adapter VIETTEL chưa hỗ trợ nghiệp vụ { iv_action }.| &&
          | Bổ sung trong ZFIC_HDDT_PROV_VIETTEL~BUILD_PAYLOAD.| ).
    ENDCASE.

  ENDMETHOD.


  METHOD build_invoice.

    DATA(ls_inv) = is_request-invoice.
    DATA(ls_hdr) = ls_inv-header.
    DATA(ls_adj) = ls_inv-adjust.

    DATA(lv_adj_type) = get_adjustment_type( ls_adj ).
    DATA(lv_is_adjust) = xsdbool( lv_adj_type = '5' ).
    DATA(lv_increase)  = xsdbool( ls_adj-adj_direction = '1' ).

    DATA(lo) = NEW zfic_hddt_json( ).

    lo->begin_object( ).

*---- generalInvoiceInfo ----------------------------------------------*
    lo->begin_object( `generalInvoiceInfo`
      )->add_string( iv_name  = `invoiceType`
                     iv_value = ls_hdr-inv_type   iv_force = abap_true
      )->add_string( iv_name  = `templateCode`
                     iv_value = ls_hdr-template   iv_force = abap_true
      )->add_string( iv_name  = `invoiceSeries`
                     iv_value = ls_hdr-serial     iv_force = abap_true
      )->add_string( iv_name  = `currencyCode`
                     iv_value = ls_hdr-currency   iv_force = abap_true
      )->add_string( iv_name  = `adjustmentType`
                     iv_value = lv_adj_type       iv_force = abap_true
      )->add_string( iv_name  = `transactionUuid`
                     iv_value = ls_hdr-idkey      iv_force = abap_true
      )->add_string( iv_name  = `invoiceIssuedDate`
                     iv_value = to_epoch_millis( iv_date = ls_hdr-inv_date
                                                 iv_time = ls_hdr-inv_time )
                     iv_force = abap_true ).

    " Tỷ giá: VND luôn là 1
    lo->add_number( iv_name     = `exchangeRate`
                    iv_value    = COND #( WHEN ls_hdr-currency = 'VND'
                                          THEN 1 ELSE ls_hdr-exch_rate )
                    iv_decimals = 4 ).

    lo->add_bool( iv_name = `paymentStatus`      iv_value = ls_hdr-paid
      )->add_bool( iv_name = `cusGetInvoiceRight` iv_value = abap_true ).

    " Ghi chú: hoá đơn gốc dùng khoá đối chiếu để tra soát,
    " hoá đơn điều chỉnh/thay thế dùng câu diễn giải chuẩn.
    IF lv_adj_type = '1'.
      lo->add_string( iv_name  = `invoiceNote`
                      iv_value = COND string( WHEN ls_hdr-note IS NOT INITIAL
                                              THEN ls_hdr-note
                                              ELSE |{ ls_hdr-idkey }| ) ).
    ELSE.
      lo->add_string( iv_name  = `invoiceNote`
                      iv_value = build_adjust_note( ls_adj ) ).
    ENDIF.

    " Thông tin hoá đơn gốc — chỉ gửi khi thực sự có (mã cũ phải dùng
    " REPLACE để xoá cặp thẻ rỗng; writer ở đây tự bỏ khi rỗng).
    IF ls_adj-org_serial IS NOT INITIAL OR ls_adj-org_seq IS NOT INITIAL.
      lo->add_string( iv_name  = `originalInvoiceId`
                      iv_value = |{ ls_adj-org_serial }{ ls_adj-org_seq }|
        )->add_string( iv_name  = `originalInvoiceIssueDate`
                       iv_value = to_epoch_millis( ls_adj-org_inv_date ) ).
    ENDIF.

    " 1 = điều chỉnh tiền, 2 = điều chỉnh thông tin
    IF lv_is_adjust = abap_true.
      lo->add_string( iv_name  = `adjustmentInvoiceType`
                      iv_value = COND string( WHEN ls_adj-adj_direction = '2'
                                              THEN `2` ELSE `1` ) ).
    ENDIF.

    lo->end_object( ).

*---- buyerInfo -------------------------------------------------------*
    DATA(ls_buy) = ls_inv-buyer.
    lo->begin_object( `buyerInfo`
      )->add_string( iv_name = `buyerName`         iv_value = ls_buy-person_name
      )->add_string( iv_name = `buyerLegalName`    iv_value = ls_buy-legal_name
      )->add_string( iv_name = `buyerTaxCode`      iv_value = ls_buy-tax_code
      )->add_string( iv_name = `buyerAddressLine`  iv_value = ls_buy-address
      )->add_string( iv_name = `buyerPhoneNumber`  iv_value = ls_buy-phone
      )->add_string( iv_name = `buyerEmail`        iv_value = ls_buy-email
      )->add_string( iv_name = `buyerBankName`     iv_value = ls_buy-bank_name
      )->add_string( iv_name = `buyerBankAccount`  iv_value = ls_buy-bank_acct
      )->add_string( iv_name = `buyerCode`         iv_value = ls_buy-code
      )->add_string( iv_name = `buyerIdNo`         iv_value = ls_buy-id_number ).
    IF ls_buy-not_get_invoice = abap_true.
      lo->add_string( iv_name = `buyerNotGetInvoice` iv_value = `1`
                      iv_force = abap_true ).
    ENDIF.
    lo->end_object( ).

*---- sellerInfo ------------------------------------------------------*
    DATA(ls_sel) = ls_inv-seller.
    lo->begin_object( `sellerInfo`
      )->add_string( iv_name = `sellerLegalName`   iv_value = ls_sel-name
      )->add_string( iv_name = `sellerTaxCode`     iv_value = ls_sel-tax_code
                     iv_force = abap_true
      )->add_string( iv_name = `sellerAddressLine` iv_value = ls_sel-address
      )->add_string( iv_name = `sellerPhoneNumber` iv_value = ls_sel-phone
      )->add_string( iv_name = `sellerEmail`       iv_value = ls_sel-email
      )->add_string( iv_name = `sellerBankName`    iv_value = ls_sel-bank_name
      )->add_string( iv_name = `sellerBankAccount` iv_value = ls_sel-bank_acct
      )->end_object( ).

*---- itemInfo --------------------------------------------------------*
    lo->begin_array( `itemInfo` ).
    LOOP AT ls_inv-items ASSIGNING FIELD-SYMBOL(<ls_item>).
      lo->begin_object( ).
      lo->add_number( iv_name = `lineNumber` iv_value = <ls_item>-line_no
                      iv_decimals = 0 ).
      lo->add_string( iv_name = `itemCode`  iv_value = <ls_item>-item_code
        )->add_string( iv_name = `itemName` iv_value = <ls_item>-item_name
                       iv_force = abap_true
        )->add_string( iv_name = `unitName` iv_value = <ls_item>-unit ).
      lo->add_number( iv_name = `unitPrice` iv_value = <ls_item>-price
        )->add_number( iv_name = `quantity`  iv_value = <ls_item>-quantity
        )->add_number( iv_name = `itemTotalAmountWithoutTax`
                       iv_value = <ls_item>-amount
        )->add_number( iv_name = `taxPercentage` iv_value = <ls_item>-tax_rate
                       iv_decimals = 2
        )->add_number( iv_name = `taxAmount` iv_value = <ls_item>-tax_amount
        )->add_number( iv_name = `itemTotalAmountWithTax`
                       iv_value = <ls_item>-total ).
      IF <ls_item>-disc_percent IS NOT INITIAL.
        lo->add_number( iv_name = `discount` iv_value = <ls_item>-disc_percent
                        iv_decimals = 2 ).
      ENDIF.
      IF <ls_item>-disc_amount IS NOT INITIAL.
        lo->add_number( iv_name = `itemDiscount` iv_value = <ls_item>-disc_amount ).
      ENDIF.
      IF <ls_item>-note IS NOT INITIAL.
        lo->add_string( iv_name = `itemNote` iv_value = <ls_item>-note ).
      ENDIF.
      " Chỉ hoá đơn điều chỉnh mới có thẻ này
      IF lv_is_adjust = abap_true.
        lo->add_bool_text( iv_name = `isIncreaseItem` iv_value = lv_increase ).
      ENDIF.
      lo->add_ext( <ls_item>-ext ).
      lo->end_object( ).
    ENDLOOP.
    lo->end_array( ).

*---- summarizeInfo ---------------------------------------------------*
    DATA(ls_sum) = ls_inv-summary.
    lo->begin_object( `summarizeInfo`
      )->add_number( iv_name = `sumOfTotalLineAmountWithoutTax`
                     iv_value = ls_sum-amount_wo_tax
      )->add_number( iv_name = `totalAmountWithoutTax`
                     iv_value = ls_sum-amount_wo_tax
      )->add_number( iv_name = `totalTaxAmount`  iv_value = ls_sum-tax_amount
      )->add_number( iv_name = `totalAmountWithTax` iv_value = ls_sum-total
      )->add_number( iv_name = `discountAmount` iv_value = ls_sum-disc_amount
      )->add_string( iv_name = `totalAmountWithTaxInWords`
                     iv_value = ls_sum-amount_in_words ).
    IF lv_is_adjust = abap_true.
      lo->add_bool_text( iv_name = `isTotalAmountPos`        iv_value = lv_increase
        )->add_bool_text( iv_name = `isTotalTaxAmountPos`     iv_value = lv_increase
        )->add_bool_text( iv_name = `isTotalAmtWithoutTaxPos` iv_value = lv_increase
        )->add_bool_text( iv_name = `isDiscountAmtPos`        iv_value = lv_increase ).
    ENDIF.
    lo->end_object( ).

*---- taxBreakdowns ---------------------------------------------------*
    lo->begin_array( `taxBreakdowns` ).
    LOOP AT ls_inv-taxes ASSIGNING FIELD-SYMBOL(<ls_tax>).
      lo->begin_object(
        )->add_number( iv_name = `taxPercentage` iv_value = <ls_tax>-tax_rate
                       iv_decimals = 2
        )->add_number( iv_name = `taxableAmount` iv_value = <ls_tax>-taxable_amt
        )->add_number( iv_name = `taxAmount`     iv_value = <ls_tax>-tax_amt ).
      IF lv_is_adjust = abap_true.
        lo->add_bool_text( iv_name = `taxableAmountPos` iv_value = lv_increase
          )->add_bool_text( iv_name = `taxAmountPos`     iv_value = lv_increase ).
      ENDIF.
      lo->end_object( ).
    ENDLOOP.
    lo->end_array( ).

*---- payments --------------------------------------------------------*
    lo->begin_array( `payments` ).
    LOOP AT ls_inv-payments ASSIGNING FIELD-SYMBOL(<ls_pay>).
      lo->begin_object(
        )->add_string( iv_name  = `paymentMethodName`
                       iv_value = <ls_pay>-method_name iv_force = abap_true
        )->end_object( ).
    ENDLOOP.
    lo->end_array( ).

*---- phần mở rộng cấp hoá đơn ---------------------------------------*
    lo->add_ext( ls_inv-ext ).

    lo->end_object( ).
    rv_payload = lo->get_json( ).

  ENDMETHOD.


  METHOD build_cancel.

    DATA(ls_hdr) = is_request-invoice-header.
    DATA(ls_adj) = is_request-invoice-adjust.

    " Số hoá đơn cần huỷ: ưu tiên tham số truyền vào, sau đó lấy từ sổ
    " đăng ký (ZFIT_HDDT_INV) đã lưu khi phát hành.
    DATA(lv_seq)    = |{ ls_hdr-seq }|.
    DATA(lv_serial) = |{ ls_hdr-serial }|.
    DATA(lv_date)   = ls_hdr-inv_date.

    IF lv_seq IS INITIAL.
      DATA(ls_reg) = zfic_hddt_log=>read_invoice(
                       iv_bukrs     = is_request-bukrs
                       iv_gjahr     = is_request-gjahr
                       iv_src_type  = is_request-src_type
                       iv_src_docno = is_request-src_docno ).
      lv_seq    = |{ ls_reg-seq }|.
      lv_serial = |{ ls_reg-serial }|.
      IF ls_reg-issue_date IS NOT INITIAL.
        lv_date = ls_reg-issue_date.
      ENDIF.
    ENDIF.

    IF lv_seq IS INITIAL.
      zficx_hddt_error=>raise_text(
        |Không xác định được số hoá đơn cần huỷ cho chứng từ | &&
        |{ is_request-src_docno }/{ is_request-gjahr }.| ).
    ENDIF.

    rv_payload = NEW zfic_hddt_json( )->begin_object(
      )->add_string( iv_name = `supplierTaxCode` iv_value = is_cred-taxcode
                     iv_force = abap_true
      )->add_string( iv_name = `templateCode`  iv_value = ls_hdr-template
      )->add_string( iv_name = `invoiceNo`     iv_value = |{ lv_serial }{ lv_seq }|
                     iv_force = abap_true
      )->add_string( iv_name = `strIssueDate`
                     iv_value = fmt_datetime( iv_date = lv_date
                                              iv_time = ls_hdr-inv_time )
      )->add_string( iv_name = `additionalReferenceDesc`
                     iv_value = ls_adj-reason
      )->add_string( iv_name = `additionalReferenceDate`
                     iv_value = fmt_datetime( iv_date = COND #(
                                  WHEN ls_adj-doc_ref_date IS NOT INITIAL
                                  THEN ls_adj-doc_ref_date ELSE sy-datum ) )
      )->end_object(
      )->get_json( ).

  ENDMETHOD.


  METHOD build_search.

    rv_payload = NEW zfic_hddt_json( )->begin_object(
      )->add_string( iv_name = `supplierTaxCode` iv_value = is_cred-taxcode
                     iv_force = abap_true
      )->add_string( iv_name = `transactionUuid`
                     iv_value = is_request-invoice-header-idkey
                     iv_force = abap_true
      )->end_object(
      )->get_json( ).

  ENDMETHOD.


  METHOD build_get_file.

    DATA(ls_hdr) = is_request-invoice-header.

    DATA(lv_type) = zfic_hddt_json=>get_value(
                      it_values = is_request-params
                      iv_path   = `fileType` ).
    IF lv_type IS INITIAL.
      lv_type = `PDF`.
    ENDIF.

    rv_payload = NEW zfic_hddt_json( )->begin_object(
      )->add_string( iv_name = `supplierTaxCode` iv_value = is_cred-taxcode
                     iv_force = abap_true
      )->add_string( iv_name = `templateCode` iv_value = ls_hdr-template
      )->add_string( iv_name = `invoiceNo`
                     iv_value = |{ ls_hdr-serial }{ ls_hdr-seq }|
                     iv_force = abap_true
      )->add_string( iv_name = `fileType` iv_value = lv_type iv_force = abap_true
      )->end_object(
      )->get_json( ).

  ENDMETHOD.


  METHOD get_adjustment_type.

    CASE is_adjust-adj_type.
      WHEN zfiif_hddt_types=>gc_adj_type-replace.  rv_type = `3`.
      WHEN zfiif_hddt_types=>gc_adj_type-adjust.   rv_type = `5`.
      WHEN zfiif_hddt_types=>gc_adj_type-cancel.   rv_type = `7`.
      WHEN OTHERS.                                 rv_type = `1`.
    ENDCASE.

  ENDMETHOD.


  METHOD zfiif_hddt_provider~parse_response.

    IF iv_body IS INITIAL.
      cs_result-success = xsdbool( iv_http_code >= 200 AND iv_http_code < 300 ).
      cs_result-message = |HTTP { iv_http_code }: nhà cung cấp không trả nội dung.|.
      RETURN.
    ENDIF.

    DATA lt_val TYPE zfiif_hddt_types=>ty_t_kv.
    TRY.
        lt_val = zfic_hddt_json=>parse( iv_body ).
      CATCH zficx_hddt_error.
        " Response không phải JSON (ví dụ getInvoiceRepresentationFile
        " trả về nhị phân, hoặc trang lỗi HTML của gateway)
        cs_result-success = xsdbool( iv_http_code >= 200 AND iv_http_code < 300 ).
        cs_result-message = substring( val = iv_body
                                       len = nmin( val1 = 255
                                                   val2 = strlen( iv_body ) ) ).
        RETURN.
    ENDTRY.
    cs_result-fields = lt_val.

    DATA(lv_error) = zfic_hddt_json=>get_value_by_name( it_values = lt_val
                                                        iv_name   = `errorCode` ).
    DATA(lv_desc)  = zfic_hddt_json=>get_value_by_name( it_values = lt_val
                                                        iv_name   = `description` ).
    IF lv_desc IS INITIAL.
      lv_desc = zfic_hddt_json=>get_value_by_name( it_values = lt_val
                                                   iv_name   = `message` ).
    ENDIF.

    cs_result-prov_status = COND #( WHEN lv_error IS NOT INITIAL
                                    THEN lv_error
                                    ELSE |{ iv_http_code }| ).

    " SInvoice trả errorCode = null khi thành công
    cs_result-success = xsdbool( iv_http_code >= 200 AND iv_http_code < 300
                                 AND lv_error IS INITIAL ).

    DATA(lv_seq) = zfic_hddt_json=>get_value_by_name( it_values = lt_val
                                                      iv_name   = `invoiceNo` ).
    IF lv_seq IS NOT INITIAL.
      " invoiceNo của SInvoice là ký hiệu + số; tách phần số ở cuối.
      DATA lv_digits TYPE string.
      DATA lv_i      TYPE i.
      lv_i = strlen( lv_seq ).
      WHILE lv_i > 0.
        DATA(lv_c) = substring( val = lv_seq off = lv_i - 1 len = 1 ).
        IF lv_c CO '0123456789'.
          lv_digits = lv_c && lv_digits.
          lv_i = lv_i - 1.
        ELSE.
          EXIT.
        ENDIF.
      ENDWHILE.
      IF lv_digits IS NOT INITIAL AND lv_i > 0.
        cs_result-serial = substring( val = lv_seq len = lv_i ).
        cs_result-seq    = lv_digits.
      ELSE.
        cs_result-seq = lv_seq.
      ENDIF.
    ENDIF.

    cs_result-mscqt = zfic_hddt_json=>get_value_by_name(
                        it_values = lt_val iv_name = `codeOfTax` ).
    IF cs_result-mscqt IS INITIAL.
      cs_result-mscqt = zfic_hddt_json=>get_value_by_name(
                          it_values = lt_val iv_name = `reservationCode` ).
    ENDIF.

    cs_result-idkey = zfic_hddt_json=>get_value_by_name(
                        it_values = lt_val iv_name = `transactionUuid` ).
    IF cs_result-idkey IS INITIAL.
      cs_result-idkey = is_request-invoice-header-idkey.
    ENDIF.

    " File hoá đơn trả về dạng base64 trong thẻ fileToBytes
    DATA(lv_file) = zfic_hddt_json=>get_value_by_name(
                      it_values = lt_val iv_name = `fileToBytes` ).
    IF lv_file IS NOT INITIAL.
      TRY.
          cs_result-file_content = cl_http_utility=>decode_x_base64( lv_file ).
          cs_result-file_name    = |{ cs_result-serial }{ cs_result-seq }.pdf|.
        CATCH cx_root.
          CLEAR cs_result-file_content.
      ENDTRY.
    ENDIF.

    IF lv_desc IS NOT INITIAL.
      cs_result-message = lv_desc.
    ELSEIF cs_result-success = abap_true.
      cs_result-message = |Thành công. Số hoá đơn: { cs_result-serial }{ cs_result-seq }|.
    ELSE.
      cs_result-message = substring( val = iv_body
                                     len = nmin( val1 = 255
                                                 val2 = strlen( iv_body ) ) ).
    ENDIF.

  ENDMETHOD.

ENDCLASS.
