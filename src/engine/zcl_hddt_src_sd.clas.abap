*=====================================================================
* Tên/Mã     : ZCL_HDDT_SRC_SD
* Mô tả chung: Lớp đọc dữ liệu nguồn cho HOÁ ĐƠN BILLING SD CHƯA SINH
*              CHỨNG TỪ FI (VBRK / VBRP / PRCD_ELEMENTS) — port từ
*              ZPG_INT_E_INVOICE (nhánh "Billing No FI") và
*              ZFM_GET_ITEMDOC FORM process_sd_no_refer_fi. Billing đã
*              có chứng từ FI được nguồn FI (ZCL_HDDT_SRC_FI) xử lý
*              qua BKPF-AWTYP = 'VBRK', nên lớp này LOẠI các billing
*              đã có BKPF để không phát hành trùng.
*
*              Chọn chứng từ:
*                - VBRK theo công ty, ngày FKDAT (range ngày hạch toán
*                  của màn hình), loại hoá đơn FKART trong MAP BILLTYPE
*                  (bắt buộc cấu hình), khách hàng KUNRG, người tạo;
*                - billing đã huỷ (FKSTO) chỉ lấy khi đã có số HĐĐT.
*              Dòng hàng:
*                - có MAP CONDTYPE: cộng/trừ theo loại điều kiện giá
*                  (EXT_VALUE = AMT+ / AMT- / TAX; TAX lấy KBETR/10 làm
*                  thuế suất) — đúng cách dự án tham chiếu dùng
*                  ZPR0/ZC04/ZC05/ZMST;
*                - không có: VBRP-NETWR (thành tiền) và MWSBP (thuế),
*                  thuế suất từ MAP TAXRATE theo VBRP-MWSKZ, fallback
*                  tỷ lệ MWSBP/NETWR.
* Tham Số    : SELECT_DOCUMENTS( is_selection ) -> ty_t_request
*              GET_DOC_STATE( bukrs gjahr docno ) -> ty_doc_state
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       03/09/2026    cuongus - CuongUS        abapGit     Tạo mới
*=====================================================================
CLASS zcl_hddt_src_sd DEFINITION
  PUBLIC
  INHERITING FROM zcl_hddt_src_base
  CREATE PUBLIC .

  PUBLIC SECTION.

    CONSTANTS gc_src_type TYPE zde_hddt_srctype VALUE 'SD' ##NO_TEXT.

    METHODS zif_hddt_source~select_documents REDEFINITION .
    METHODS zif_hddt_source~get_doc_state    REDEFINITION .

  PROTECTED SECTION.

    TYPES: BEGIN OF ty_vbrk,
             vbeln TYPE vbrk-vbeln,
             fkart TYPE vbrk-fkart,
             fkdat TYPE vbrk-fkdat,
             bukrs TYPE vbrk-bukrs,
             waerk TYPE vbrk-waerk,
             kurrf TYPE vbrk-kurrf,
             kunrg TYPE vbrk-kunrg,
             zlsch TYPE vbrk-zlsch,
             fksto TYPE vbrk-fksto,
             knumv TYPE vbrk-knumv,
             ernam TYPE vbrk-ernam,
             erdat TYPE vbrk-erdat,
             xblnr TYPE vbrk-xblnr,
           END OF ty_vbrk.
    TYPES ty_t_vbrk TYPE STANDARD TABLE OF ty_vbrk WITH EMPTY KEY.

    TYPES: BEGIN OF ty_vbrp,
             vbeln TYPE vbrp-vbeln,
             posnr TYPE vbrp-posnr,
             matnr TYPE vbrp-matnr,
             arktx TYPE vbrp-arktx,
             fkimg TYPE vbrp-fkimg,
             vrkme TYPE vbrp-vrkme,
             netwr TYPE vbrp-netwr,
             mwsbp TYPE vbrp-mwsbp,
             mwskz TYPE vbrp-mwskz,
             aubel TYPE vbrp-aubel,
             aupos TYPE vbrp-aupos,
           END OF ty_vbrp.
    TYPES ty_t_vbrp TYPE STANDARD TABLE OF ty_vbrp WITH EMPTY KEY.

    TYPES: BEGIN OF ty_cond,
             knumv TYPE prcd_elements-knumv,
             kposn TYPE prcd_elements-kposn,
             kschl TYPE prcd_elements-kschl,
             kwert TYPE prcd_elements-kwert,
             kbetr TYPE prcd_elements-kbetr,
           END OF ty_cond.
    TYPES ty_t_cond TYPE STANDARD TABLE OF ty_cond WITH EMPTY KEY.

    METHODS build_one
      IMPORTING is_vbrk           TYPE ty_vbrk
                it_vbrp           TYPE ty_t_vbrp
                it_cond           TYPE ty_t_cond
                i_use_cond       TYPE abap_bool
                i_gjahr          TYPE gjahr
      RETURNING VALUE(rs_request) TYPE zif_hddt_types=>ty_request .

ENDCLASS.



CLASS zcl_hddt_src_sd IMPLEMENTATION.

  METHOD zif_hddt_source~select_documents.

    IF is_selection-bukrs IS INITIAL.
      zcx_hddt_error=>raise_text( `Thiếu mã công ty (BUKRS) khi đọc hoá đơn SD.` ).
    ENDIF.

*---- Loại hoá đơn SD được phát hành: bắt buộc cấu hình --------------*
    DATA lr_fkart TYPE RANGE OF fkart.
    LOOP AT map_list_as_range( zif_hddt_types=>gc_map_type-bill_type )
         ASSIGNING FIELD-SYMBOL(<fs_r>).
      APPEND VALUE #( sign = <fs_r>-sign option = <fs_r>-option
                      low  = <fs_r>-low(4) ) TO lr_fkart.
    ENDLOOP.
    IF lr_fkart IS INITIAL.
      zcx_hddt_error=>raise_text(
        `Chưa khai báo loại hoá đơn SD được phát hành HĐĐT (ZTB_HDDT_MAP, ` &&
        `MAP_TYPE = BILLTYPE, SAP_VALUE = VBRK-FKART).` ).
    ENDIF.

    load_registry( i_bukrs    = is_selection-bukrs
                   i_gjahr    = is_selection-gjahr
                   i_src_type = gc_src_type ).

*---- 1. Header billing ----------------------------------------------*
    " VBRK không có năm tài chính: dùng năm dương lịch của FKDAT làm
    " GJAHR của sổ đăng ký (ghi rõ trong tài liệu).
    DATA(lv_from) = CONV dats( |{ is_selection-gjahr }0101| ).
    DATA(lv_to)   = CONV dats( |{ is_selection-gjahr }1231| ).

    DATA lt_vbrk TYPE ty_t_vbrk.
    SELECT vbeln, fkart, fkdat, bukrs, waerk, kurrf, kunrg, zlsch, fksto,
           knumv, ernam, erdat, xblnr
      FROM vbrk
      WHERE bukrs  = @is_selection-bukrs
        AND fkdat BETWEEN @lv_from AND @lv_to
        AND fkdat IN @is_selection-r_budat
        AND erdat IN @is_selection-r_cpudt
        AND vbeln IN @is_selection-r_docno
        AND vbeln IN @is_selection-r_vbeln
        AND fkart IN @lr_fkart
        AND kunrg IN @is_selection-r_kunnr
        AND ernam IN @is_selection-r_usnam
      ORDER BY vbeln
      INTO TABLE @lt_vbrk.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

*---- 2. Loại billing đã sinh chứng từ FI (nguồn FI xử lý) -----------*
    DATA lt_awkey TYPE RANGE OF awkey.
    DATA lt_vbeln TYPE RANGE OF vbeln_vf.
    LOOP AT lt_vbrk ASSIGNING FIELD-SYMBOL(<fs_vbrk>).
      APPEND VALUE #( sign = 'I' option = 'EQ' low = <fs_vbrk>-vbeln ) TO lt_awkey.
      APPEND VALUE #( sign = 'I' option = 'EQ' low = <fs_vbrk>-vbeln ) TO lt_vbeln.
    ENDLOOP.

    SELECT awkey FROM bkpf
      WHERE bukrs  = @is_selection-bukrs
        AND awtyp  = 'VBRK'
        AND awkey IN @lt_awkey
      INTO TABLE @DATA(lt_has_fi).
    SORT lt_has_fi BY awkey.

    LOOP AT lt_vbrk ASSIGNING <fs_vbrk>.
      READ TABLE lt_has_fi TRANSPORTING NO FIELDS
           WITH KEY awkey = CONV awkey( <fs_vbrk>-vbeln ) BINARY SEARCH.
      IF sy-subrc = 0.
        DELETE lt_vbrk.
        CONTINUE.
      ENDIF.
      DATA(ls_reg) = registry_of( i_bukrs    = <fs_vbrk>-bukrs
                                  i_gjahr    = is_selection-gjahr
                                  i_src_type = gc_src_type
                                  i_docno    = CONV #( <fs_vbrk>-vbeln ) ).
      IF keep_document( i_reversed  = xsdbool( <fs_vbrk>-fksto = 'X' )
                        is_reg       = ls_reg
                        is_selection = is_selection ) = abap_false.
        DELETE lt_vbrk.
        CONTINUE.
      ENDIF.
      IF is_selection-r_seq IS NOT INITIAL AND ls_reg-seq NOT IN is_selection-r_seq.
        DELETE lt_vbrk.
      ENDIF.
    ENDLOOP.
    IF lt_vbrk IS INITIAL.
      RETURN.
    ENDIF.

*---- 3. Dòng billing + điều kiện giá --------------------------------*
    CLEAR lt_vbeln.
    DATA lt_knumv TYPE RANGE OF knumv.
    LOOP AT lt_vbrk ASSIGNING <fs_vbrk>.
      APPEND VALUE #( sign = 'I' option = 'EQ' low = <fs_vbrk>-vbeln ) TO lt_vbeln.
      IF <fs_vbrk>-knumv IS NOT INITIAL.
        APPEND VALUE #( sign = 'I' option = 'EQ' low = <fs_vbrk>-knumv ) TO lt_knumv.
      ENDIF.
    ENDLOOP.

    DATA lt_vbrp TYPE ty_t_vbrp.
    SELECT vbeln, posnr, matnr, arktx, fkimg, vrkme, netwr, mwsbp, mwskz, aubel, aupos
      FROM vbrp
      WHERE vbeln IN @lt_vbeln
      ORDER BY vbeln, posnr
      INTO TABLE @lt_vbrp.

    " Chỉ đọc PRCD_ELEMENTS khi có cấu hình loại điều kiện
    DATA lt_cond TYPE ty_t_cond.
    DATA(lv_use_cond) = abap_false.
    DATA(lr_kschl) = map_list_as_range( zif_hddt_types=>gc_map_type-cond_type ).
    IF lr_kschl IS NOT INITIAL AND lt_knumv IS NOT INITIAL.
      lv_use_cond = abap_true.
      DATA lr_kschl4 TYPE RANGE OF kschl.
      LOOP AT lr_kschl ASSIGNING FIELD-SYMBOL(<fs_k>).
        APPEND VALUE #( sign = <fs_k>-sign option = <fs_k>-option
                        low  = <fs_k>-low(4) ) TO lr_kschl4.
      ENDLOOP.
      SELECT knumv, kposn, kschl, kwert, kbetr
        FROM prcd_elements
        WHERE knumv IN @lt_knumv
          AND kschl IN @lr_kschl4
          AND kinak  = @space
        INTO TABLE @lt_cond.
    ENDIF.

*---- 4. Dựng request ------------------------------------------------*
    LOOP AT lt_vbrk ASSIGNING <fs_vbrk>.
      DATA(lt_doc_vbrp) = VALUE ty_t_vbrp( FOR ls IN lt_vbrp
                                           WHERE ( vbeln = <fs_vbrk>-vbeln ) ( ls ) ).
      DATA(lt_doc_cond) = VALUE ty_t_cond( FOR lc IN lt_cond
                                           WHERE ( knumv = <fs_vbrk>-knumv ) ( lc ) ).
      DATA(ls_req) = build_one( is_vbrk     = <fs_vbrk>
                                it_vbrp     = lt_doc_vbrp
                                it_cond     = lt_doc_cond
                                i_use_cond = lv_use_cond
                                i_gjahr    = is_selection-gjahr ).
      IF ls_req-src_docno IS NOT INITIAL.
        ls_req-invoice-header-inv_type = is_selection-inv_type.
        apply_registry_edits(
          EXPORTING is_reg     = registry_of( i_bukrs    = ls_req-bukrs
                                              i_gjahr    = ls_req-gjahr
                                              i_src_type = gc_src_type
                                              i_docno    = ls_req-src_docno )
          CHANGING  cs_request = ls_req ).
        APPEND ls_req TO rt_request.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD zif_hddt_source~get_doc_state.

    DATA lv_vbeln TYPE vbeln_vf.
    lv_vbeln = i_docno.

    SELECT SINGLE fksto, waerk, kunrg
      FROM vbrk
      WHERE vbeln = @lv_vbeln
        AND bukrs = @i_bukrs
      INTO @DATA(ls_vbrk).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    rs_state-exists    = abap_true.
    rs_state-xreversed = xsdbool( ls_vbrk-fksto = 'X' ).
    rs_state-waers     = ls_vbrk-waerk.
    rs_state-kunnr     = ls_vbrk-kunrg.

  ENDMETHOD.


  METHOD build_one.

    DATA ls_item TYPE zif_hddt_types=>ty_item.
    DATA lv_line TYPE zde_hddt_lineno.

    rs_request-bukrs     = is_vbrk-bukrs.
    rs_request-gjahr     = i_gjahr.
    rs_request-src_type  = gc_src_type.
    rs_request-src_docno = is_vbrk-vbeln.

    rs_request-src_info = VALUE #(
      budat   = is_vbrk-fkdat
      bldat   = is_vbrk-fkdat
      cpudt   = is_vbrk-erdat
      usnam   = is_vbrk-ernam
      xblnr   = is_vbrk-xblnr
      kunnr   = is_vbrk-kunrg
      awtyp   = 'VBRK'
      awkey   = is_vbrk-vbeln
      fkart   = is_vbrk-fkart
      xcancel = xsdbool( is_vbrk-fksto = 'X' ) ).

    rs_request-invoice-header = VALUE #(
      currency  = is_vbrk-waerk
      exch_rate = exch_rate_of( i_bukrs = is_vbrk-bukrs
                                i_waers = is_vbrk-waerk
                                i_kursf = is_vbrk-kurrf )
      inv_date  = config( )->resolve_invoice_date( i_bukrs = is_vbrk-bukrs
                                                   i_budat = is_vbrk-fkdat
                                                   i_bldat = is_vbrk-fkdat
                                                   i_cpudt = is_vbrk-erdat )
      inv_time  = sy-uzeit ).

*---- Người mua: bên thanh toán (KUNRG) ------------------------------*
    DATA lv_aubel TYPE vbeln.
    READ TABLE it_vbrp INDEX 1 ASSIGNING FIELD-SYMBOL(<fs_first>).
    IF sy-subrc = 0.
      lv_aubel = <fs_first>-aubel.
    ENDIF.
    rs_request-invoice-buyer = read_buyer( i_kunnr = is_vbrk-kunrg
                                           i_bukrs = is_vbrk-bukrs
                                           i_aubel = lv_aubel ).
    IF rs_request-invoice-buyer-ref_no IS NOT INITIAL.
      rs_request-invoice-header-contract_no = rs_request-invoice-buyer-ref_no.
    ENDIF.

    DATA(ls_pay) = payment_of( i_zlsch = is_vbrk-zlsch i_bukrs = is_vbrk-bukrs ).
    IF ls_pay-method_code IS NOT INITIAL.
      APPEND ls_pay TO rs_request-invoice-payments.
    ENDIF.

*---- Dòng hàng -------------------------------------------------------*
    LOOP AT it_vbrp ASSIGNING FIELD-SYMBOL(<fs_vbrp>).
      CLEAR ls_item.
      lv_line = lv_line + 1.
      ls_item-line_no   = lv_line.
      ls_item-item_type = '0'.
      ls_item-item_code = <fs_vbrp>-matnr.
      ls_item-quantity  = <fs_vbrp>-fkimg.
      ls_item-unit      = unit_text( <fs_vbrp>-vrkme ).
      ls_item-item_name = item_name( i_bukrs   = is_vbrk-bukrs
                                     i_vbeln   = <fs_vbrp>-aubel
                                     i_posnr   = <fs_vbrp>-aupos
                                     i_matnr   = <fs_vbrp>-matnr
                                     i_default = <fs_vbrp>-arktx ).

      IF i_use_cond = abap_true.
        " Theo loại điều kiện giá đã cấu hình (AMT+ / AMT- / TAX)
        LOOP AT it_cond ASSIGNING FIELD-SYMBOL(<fs_cond>)
             WHERE kposn = <fs_vbrp>-posnr.
          config( )->map_value( EXPORTING i_provider  = space
                                          i_map_type  = zif_hddt_types=>gc_map_type-cond_type
                                          i_sap_value = <fs_cond>-kschl
                                IMPORTING e_ext_value = DATA(lv_role) ).
          TRANSLATE lv_role TO UPPER CASE.
          CONDENSE lv_role NO-GAPS.
          CASE lv_role.
            WHEN 'AMT+'.
              ls_item-amount = ls_item-amount + <fs_cond>-kwert.
            WHEN 'AMT-'.
              ls_item-amount = ls_item-amount - abs( <fs_cond>-kwert ).
            WHEN 'TAX'.
              ls_item-tax_amount = ls_item-tax_amount + <fs_cond>-kwert.
              IF <fs_cond>-kbetr IS NOT INITIAL.
                ls_item-tax_rate = <fs_cond>-kbetr / 10.
              ENDIF.
            WHEN OTHERS.
          ENDCASE.
        ENDLOOP.
      ELSE.
        ls_item-amount     = <fs_vbrp>-netwr.
        ls_item-tax_amount = <fs_vbrp>-mwsbp.
        ls_item-tax_rate   = tax_rate_of( i_bukrs = is_vbrk-bukrs
                                          i_mwskz = <fs_vbrp>-mwskz ).
        IF ls_item-tax_rate = 0 AND ls_item-amount <> 0 AND ls_item-tax_amount <> 0.
          ls_item-tax_rate = round( val = ls_item-tax_amount / ls_item-amount * 100
                                    dec = 0 ).
        ENDIF.
      ENDIF.

      " Billing huỷ (loại hoá đơn huỷ) mang dấu âm: giữ nguyên dấu để
      " adapter quyết định điều chỉnh tăng/giảm.
      IF ls_item-quantity <> 0.
        ls_item-price = ls_item-amount / ls_item-quantity.
      ENDIF.
      ls_item-tax_rate_txt = rate_text( ls_item-tax_rate ).
      ls_item-total        = ls_item-amount + ls_item-tax_amount.

      APPEND ls_item TO rs_request-invoice-items.
    ENDLOOP.

    " Không có BSET: bảng thuế do AGGREGATE_INVOICE gộp từ dòng hàng
    finalize_request( CHANGING cs_request = rs_request ).

  ENDMETHOD.

ENDCLASS.
