*=====================================================================
* Tên/Mã     : ZFIC_HDDT_SRC_FI
* Mô tả chung: Lớp ĐỌC DỮ LIỆU NGUỒN mặc định cho chứng từ FI
*              (BKPF / BSEG / BSET) và dựng canonical model.
*              Đây là phần phụ thuộc nghiệp vụ nhiều nhất giữa các
*              khách hàng, nên được tách hẳn khỏi engine và khai báo
*              bằng cấu hình (ZFIT_HDDT_SRC). Khách hàng có logic
*              riêng chỉ cần copy lớp này, sửa rồi trỏ cấu hình sang
*              lớp mới — engine và adapter không đổi.
*
*              Quy tắc lấy dòng hàng hoá:
*                - Dòng doanh thu = BSEG có KOART='S', SHKZG='H'
*                  (ghi Có). Nếu có cấu hình ánh xạ GLACCT thì chỉ
*                  lấy các tài khoản được khai; EXT_TEXT của ánh xạ
*                  dùng làm tên hàng hoá khi SGTXT trống.
*                - Thuế suất: ưu tiên ánh xạ TAXRATE theo MWSKZ,
*                  nếu chưa cấu hình thì suy từ BSET-KBETR / 10.
*                - Tiền thuế từng dòng tính theo thuế suất rồi CHỐT
*                  lại theo BSET để tổng khớp sổ kế toán.
* Tham Số    : SELECT_DOCUMENTS( is_selection ) -> ty_t_request
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       28/08/2026    cuongus - CuongUS        abapGit     Tạo mới
*=====================================================================
CLASS zfic_hddt_src_fi DEFINITION
  PUBLIC
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES zfiif_hddt_source .

    CONSTANTS gc_src_type TYPE zfide_hddt_srctype VALUE 'FI' ##NO_TEXT.

  PROTECTED SECTION.

    TYPES: BEGIN OF ty_bseg,
             bukrs TYPE bseg-bukrs,
             belnr TYPE bseg-belnr,
             gjahr TYPE bseg-gjahr,
             buzei TYPE bseg-buzei,
             koart TYPE bseg-koart,
             shkzg TYPE bseg-shkzg,
             hkont TYPE bseg-hkont,
             kunnr TYPE bseg-kunnr,
             dmbtr TYPE bseg-dmbtr,
             wrbtr TYPE bseg-wrbtr,
             mwskz TYPE bseg-mwskz,
             sgtxt TYPE bseg-sgtxt,
             zlsch TYPE bseg-zlsch,
             menge TYPE bseg-menge,
             meins TYPE bseg-meins,
             matnr TYPE bseg-matnr,
             bvtyp TYPE bseg-bvtyp,
           END OF ty_bseg.
    TYPES ty_t_bseg TYPE STANDARD TABLE OF ty_bseg WITH EMPTY KEY.

    TYPES: BEGIN OF ty_bset,
             bukrs TYPE bset-bukrs,
             belnr TYPE bset-belnr,
             gjahr TYPE bset-gjahr,
             mwskz TYPE bset-mwskz,
             kbetr TYPE bset-kbetr,
             hwbas TYPE bset-hwbas,
             hwste TYPE bset-hwste,
             fwbas TYPE bset-fwbas,
             fwste TYPE bset-fwste,
           END OF ty_bset.
    TYPES ty_t_bset TYPE STANDARD TABLE OF ty_bset WITH EMPTY KEY.

    METHODS build_one
      IMPORTING is_bkpf           TYPE bkpf
                it_bseg           TYPE ty_t_bseg
                it_bset           TYPE ty_t_bset
      RETURNING VALUE(rs_request) TYPE zfiif_hddt_types=>ty_request .

    METHODS fill_buyer
      IMPORTING iv_kunnr TYPE kunnr
      CHANGING  cs_buyer TYPE zfiif_hddt_types=>ty_buyer .

    METHODS get_tax_rate
      IMPORTING iv_mwskz       TYPE mwskz
                it_bset        TYPE ty_t_bset
      RETURNING VALUE(rv_rate) TYPE zfiif_hddt_types=>ty_rate .

  PRIVATE SECTION.

    DATA mo_config TYPE REF TO zfic_hddt_config .

    METHODS config
      RETURNING VALUE(ro_config) TYPE REF TO zfic_hddt_config .

ENDCLASS.



CLASS zfic_hddt_src_fi IMPLEMENTATION.

  METHOD config.

    IF mo_config IS NOT BOUND.
      mo_config = zfic_hddt_config=>get_instance( ).
    ENDIF.
    ro_config = mo_config.

  ENDMETHOD.


  METHOD zfiif_hddt_source~select_documents.

    DATA lt_bkpf TYPE STANDARD TABLE OF bkpf WITH EMPTY KEY.

    IF is_selection-bukrs IS INITIAL.
      zficx_hddt_error=>raise_text( `Thiếu mã công ty (BUKRS) khi đọc chứng từ FI.` ).
    ENDIF.

    SELECT * FROM bkpf
      INTO TABLE @lt_bkpf
      WHERE bukrs  = @is_selection-bukrs
        AND gjahr  = @is_selection-gjahr
        AND belnr IN @is_selection-r_docno
        AND budat IN @is_selection-r_budat
        AND blart IN @is_selection-r_blart
        AND xreversal = @space
      ORDER BY belnr.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    DATA lt_belnr TYPE RANGE OF belnr_d.
    LOOP AT lt_bkpf ASSIGNING FIELD-SYMBOL(<ls_bkpf>).
      APPEND VALUE #( sign = 'I' option = 'EQ' low = <ls_bkpf>-belnr ) TO lt_belnr.
    ENDLOOP.

    DATA lt_bseg TYPE ty_t_bseg.
    SELECT bukrs, belnr, gjahr, buzei, koart, shkzg, hkont, kunnr,
           dmbtr, wrbtr, mwskz, sgtxt, zlsch, menge, meins, matnr, bvtyp
      FROM bseg
      INTO TABLE @lt_bseg
      WHERE bukrs  = @is_selection-bukrs
        AND gjahr  = @is_selection-gjahr
        AND belnr IN @lt_belnr.

    DATA lt_bset TYPE ty_t_bset.
    SELECT bukrs, belnr, gjahr, mwskz, kbetr, hwbas, hwste, fwbas, fwste
      FROM bset
      INTO TABLE @lt_bset
      WHERE bukrs  = @is_selection-bukrs
        AND gjahr  = @is_selection-gjahr
        AND belnr IN @lt_belnr.

    " Trạng thái đã tích hợp — để lọc theo yêu cầu người dùng
    SELECT bukrs, gjahr, src_docno, status
      FROM zfit_hddt_inv
      INTO TABLE @DATA(lt_reg)
      WHERE bukrs    = @is_selection-bukrs
        AND gjahr    = @is_selection-gjahr
        AND src_type = @gc_src_type.

    LOOP AT lt_bkpf ASSIGNING <ls_bkpf>.

      DATA lv_status TYPE zfide_hddt_status.
      CLEAR lv_status.
      TRY.
          lv_status = lt_reg[ bukrs     = <ls_bkpf>-bukrs
                              gjahr     = <ls_bkpf>-gjahr
                              src_docno = CONV zfide_hddt_docno( <ls_bkpf>-belnr )
                            ]-status.
        CATCH cx_sy_itab_line_not_found.
          lv_status = zfiif_hddt_types=>gc_status-not_sent.
      ENDTRY.

      IF is_selection-r_status IS NOT INITIAL AND lv_status NOT IN is_selection-r_status.
        CONTINUE.
      ENDIF.

      DATA(lt_doc_bseg) = VALUE ty_t_bseg( FOR ls IN lt_bseg
                                           WHERE ( belnr = <ls_bkpf>-belnr )
                                           ( ls ) ).
      DATA(lt_doc_bset) = VALUE ty_t_bset( FOR lt IN lt_bset
                                           WHERE ( belnr = <ls_bkpf>-belnr )
                                           ( lt ) ).

      DATA(ls_req) = build_one( is_bkpf = <ls_bkpf>
                                it_bseg = lt_doc_bseg
                                it_bset = lt_doc_bset ).
      IF ls_req-src_docno IS NOT INITIAL.
        APPEND ls_req TO rt_request.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD build_one.

    DATA ls_item TYPE zfiif_hddt_types=>ty_item.
    DATA lv_line TYPE zfide_hddt_lineno.

    rs_request-bukrs     = is_bkpf-bukrs.
    rs_request-gjahr     = is_bkpf-gjahr.
    rs_request-src_type  = gc_src_type.
    rs_request-src_docno = is_bkpf-belnr.

    DATA(ls_hdr) = VALUE zfiif_hddt_types=>ty_header(
      currency  = is_bkpf-waers
      exch_rate = COND #( WHEN is_bkpf-kursf IS INITIAL OR is_bkpf-waers = 'VND'
                          THEN 1 ELSE is_bkpf-kursf )
      note      = is_bkpf-bktxt
      inv_date  = config( )->resolve_invoice_date( iv_bukrs = is_bkpf-bukrs
                                                   iv_budat = is_bkpf-budat
                                                   iv_bldat = is_bkpf-bldat
                                                   iv_cpudt = is_bkpf-cpudt )
      inv_time  = sy-uzeit ).

*---- Người mua: dòng khách hàng của chứng từ -------------------------*
    LOOP AT it_bseg ASSIGNING FIELD-SYMBOL(<ls_cust>) WHERE koart = 'D'.
      rs_request-invoice-buyer-code = <ls_cust>-kunnr.
      fill_buyer( EXPORTING iv_kunnr = <ls_cust>-kunnr
                  CHANGING  cs_buyer = rs_request-invoice-buyer ).
      " Hình thức thanh toán từ ZLSCH của dòng khách hàng
      IF <ls_cust>-zlsch IS NOT INITIAL.
        " Ánh xạ ở tầng nguồn dùng PROVIDER = blank (không phụ thuộc NCC);
        " adapter có thể ánh xạ lần hai theo NCC nếu cần.
        config( )->map_value(
          EXPORTING iv_provider  = space
                    iv_map_type  = zfiif_hddt_types=>gc_map_type-payment
                    iv_sap_value = <ls_cust>-zlsch
          IMPORTING ev_ext_value = DATA(lv_pm_code)
                    ev_ext_text  = DATA(lv_pm_text) ).
        APPEND VALUE #( method_code = lv_pm_code
                        method_name = COND string( WHEN lv_pm_text IS NOT INITIAL
                                                   THEN lv_pm_text
                                                   ELSE lv_pm_code ) )
               TO rs_request-invoice-payments.
      ENDIF.
      EXIT.
    ENDLOOP.

*---- Dòng hàng hoá: các dòng ghi Có tài khoản doanh thu --------------*
    LOOP AT it_bseg ASSIGNING FIELD-SYMBOL(<ls_line>)
         WHERE koart = 'S' AND shkzg = 'H'.

      " Nếu có cấu hình danh sách tài khoản doanh thu thì tôn trọng nó
      config( )->map_value(
        EXPORTING iv_provider  = space
                  iv_map_type  = zfiif_hddt_types=>gc_map_type-gl_acct
                  iv_sap_value = <ls_line>-hkont
        IMPORTING ev_ext_value = DATA(lv_acct_ok)
                  ev_ext_text  = DATA(lv_acct_txt) ).

      CLEAR ls_item.
      lv_line = lv_line + 1.
      ls_item-line_no   = lv_line.
      ls_item-item_type = '0'.
      ls_item-item_code = <ls_line>-matnr.
      ls_item-item_name = COND string(
        WHEN <ls_line>-sgtxt IS NOT INITIAL THEN <ls_line>-sgtxt
        WHEN lv_acct_txt IS NOT INITIAL     THEN lv_acct_txt
        ELSE |{ <ls_line>-hkont ALPHA = OUT }| ).
      ls_item-unit     = <ls_line>-meins.
      ls_item-quantity = COND #( WHEN <ls_line>-menge IS INITIAL
                                 THEN 1 ELSE <ls_line>-menge ).
      ls_item-amount   = <ls_line>-wrbtr.
      IF ls_item-quantity <> 0.
        ls_item-price = ls_item-amount / ls_item-quantity.
      ENDIF.

      ls_item-tax_rate = get_tax_rate( iv_mwskz = <ls_line>-mwskz
                                       it_bset  = it_bset ).
      IF ls_item-tax_rate > 0.
        ls_item-tax_rate_txt = |{ zfic_hddt_json=>format_number(
                                    iv_value = ls_item-tax_rate
                                    iv_decimals = 0 ) }%|.
        ls_item-tax_amount = ls_item-amount * ls_item-tax_rate / 100.
      ELSE.
        " Thuế suất âm (-1 KCT, -2 KKKNT...) -> lấy nhãn từ ánh xạ
        config( )->map_value(
          EXPORTING iv_provider  = space
                    iv_map_type  = zfiif_hddt_types=>gc_map_type-tax_rate
                    iv_sap_value = ls_item-tax_rate
          IMPORTING ev_ext_text  = DATA(lv_rate_txt) ).
        ls_item-tax_rate_txt = lv_rate_txt.
      ENDIF.
      ls_item-total = ls_item-amount + ls_item-tax_amount.

      APPEND ls_item TO rs_request-invoice-items.
    ENDLOOP.

*---- Bảng thuế lấy thẳng từ BSET để khớp sổ kế toán ------------------*
    LOOP AT it_bset ASSIGNING FIELD-SYMBOL(<ls_bset>).
      IF <ls_bset>-fwbas IS INITIAL AND <ls_bset>-hwbas IS INITIAL.
        CONTINUE.
      ENDIF.
      DATA(lv_rate) = get_tax_rate( iv_mwskz = <ls_bset>-mwskz
                                    it_bset  = it_bset ).
      APPEND VALUE #(
        tax_rate      = lv_rate
        tax_rate_txt  = COND string( WHEN lv_rate > 0
                                     THEN |{ zfic_hddt_json=>format_number(
                                               iv_value = lv_rate
                                               iv_decimals = 0 ) }%| )
        taxable_amt   = <ls_bset>-fwbas
        taxable_amt_l = <ls_bset>-hwbas
        tax_amt       = <ls_bset>-fwste
        tax_amt_l     = <ls_bset>-hwste ) TO rs_request-invoice-taxes.
    ENDLOOP.

*---- Chốt tiền thuế từng dòng theo BSET -----------------------------*
    " Chênh lệch làm tròn dồn vào dòng có giá trị lớn nhất của cùng
    " thuế suất, để tổng thuế trên hoá đơn = tổng thuế trên sổ.
    LOOP AT rs_request-invoice-taxes ASSIGNING FIELD-SYMBOL(<ls_tax>).
      DATA lv_sum_item TYPE zfiif_hddt_types=>ty_amount.
      DATA lv_idx_max  TYPE i.
      DATA lv_amt_max  TYPE zfiif_hddt_types=>ty_amount.
      CLEAR: lv_sum_item, lv_idx_max, lv_amt_max.

      LOOP AT rs_request-invoice-items ASSIGNING FIELD-SYMBOL(<ls_it>)
           WHERE tax_rate = <ls_tax>-tax_rate.
        lv_sum_item = lv_sum_item + <ls_it>-tax_amount.
        IF <ls_it>-amount > lv_amt_max.
          lv_amt_max = <ls_it>-amount.
          lv_idx_max = sy-tabix.
        ENDIF.
      ENDLOOP.

      IF lv_idx_max > 0 AND lv_sum_item <> <ls_tax>-tax_amt.
        DATA(lv_diff) = <ls_tax>-tax_amt - lv_sum_item.
        rs_request-invoice-items[ lv_idx_max ]-tax_amount =
          rs_request-invoice-items[ lv_idx_max ]-tax_amount + lv_diff.
        rs_request-invoice-items[ lv_idx_max ]-total =
            rs_request-invoice-items[ lv_idx_max ]-amount
          + rs_request-invoice-items[ lv_idx_max ]-tax_amount.
      ENDIF.
    ENDLOOP.

    rs_request-invoice-header = ls_hdr.

    " Tổng cộng do engine tính lại (aggregate_invoice) — không lặp ở đây
    zfic_hddt_service=>aggregate_invoice( CHANGING cs_invoice = rs_request-invoice ).

  ENDMETHOD.


  METHOD fill_buyer.

    IF iv_kunnr IS INITIAL.
      RETURN.
    ENDIF.

    SELECT SINGLE name1, name2, stras, ort01, pstlz, stcd1, stcd3,
                  telf1, adrnr
      FROM kna1
      INTO @DATA(ls_kna1)
      WHERE kunnr = @iv_kunnr.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    cs_buyer-legal_name = |{ ls_kna1-name1 } { ls_kna1-name2 }|.
    CONDENSE cs_buyer-legal_name.
    cs_buyer-tax_code   = COND #( WHEN ls_kna1-stcd1 IS NOT INITIAL
                                  THEN ls_kna1-stcd1 ELSE ls_kna1-stcd3 ).
    cs_buyer-phone      = ls_kna1-telf1.
    cs_buyer-address    = |{ ls_kna1-stras } { ls_kna1-ort01 }|.
    CONDENSE cs_buyer-address.

    IF ls_kna1-adrnr IS INITIAL.
      RETURN.
    ENDIF.

    " Địa chỉ đầy đủ + email từ Business Address Services
    SELECT SINGLE street, house_num1, city1, city2, region, post_code1
      FROM adrc
      INTO @DATA(ls_adrc)
      WHERE addrnumber = @ls_kna1-adrnr.
    IF sy-subrc = 0.
      cs_buyer-address = |{ ls_adrc-house_num1 } { ls_adrc-street }| &&
                         |{ COND string( WHEN ls_adrc-city2 IS NOT INITIAL
                                         THEN |, { ls_adrc-city2 }| ) }| &&
                         |{ COND string( WHEN ls_adrc-city1 IS NOT INITIAL
                                         THEN |, { ls_adrc-city1 }| ) }|.
      CONDENSE cs_buyer-address.
    ENDIF.

    " Thứ tự mệnh đề theo cú pháp ABAP SQL chặt (strict mode): INTO và
    " UP TO đứng SAU WHERE / ORDER BY — thứ tự cũ bị chặn khi dùng @.
    SELECT smtp_addr FROM adr6
      WHERE addrnumber = @ls_kna1-adrnr
      ORDER BY consnumber
      INTO TABLE @DATA(lt_adr6)
      UP TO 1 ROWS.
    IF sy-subrc = 0.
      cs_buyer-email = lt_adr6[ 1 ]-smtp_addr.
    ENDIF.

  ENDMETHOD.


  METHOD get_tax_rate.

    DATA lv_char TYPE c LENGTH 20.

    IF iv_mwskz IS INITIAL.
      RETURN.
    ENDIF.

    " (1) Ánh xạ cấu hình TAXRATE: MWSKZ -> thuế suất
    config( )->map_value( EXPORTING iv_provider  = space
                                    iv_map_type  = zfiif_hddt_types=>gc_map_type-tax_rate
                                    iv_sap_value = iv_mwskz
                          IMPORTING ev_ext_value = DATA(lv_ext) ).
    lv_char = lv_ext.
    CONDENSE lv_char NO-GAPS.
    IF lv_char IS NOT INITIAL AND lv_char <> iv_mwskz
       AND lv_char CO '0123456789.-'.
      rv_rate = lv_char.
      RETURN.
    ENDIF.

    " (2) Suy từ BSET-KBETR (lưu theo 1/10 phần trăm: 10% -> 100)
    LOOP AT it_bset ASSIGNING FIELD-SYMBOL(<ls_bset>)
         WHERE mwskz = iv_mwskz.
      rv_rate = <ls_bset>-kbetr / 10.
      EXIT.
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
