*=====================================================================
* Tên/Mã     : ZFIC_HDDT_SRC_FI
* Mô tả chung: Lớp ĐỌC DỮ LIỆU NGUỒN mặc định cho chứng từ FI (BKPF /
*              BSEG / BSET) — kể cả chứng từ FI sinh từ Billing SD
*              (BKPF-AWTYP = 'VBRK'). Logic chọn chứng từ và dựng dòng
*              hàng được port từ dự án HĐĐT private cloud
*              (ZPG_INT_E_INVOICE FORM get_data + ZFM_GET_ITEMDOC
*              proccess_fi / process_type_EXCL), viết lại theo
*              canonical model và điều khiển bằng cấu hình:
*
*              Chọn chứng từ (một dòng = một chứng từ kế toán):
*                - BKPF JOIN BSEG dòng khách hàng (KOART = 'D');
*                - không lấy chứng từ ĐẢO (XREVERSING = 'X');
*                - chứng từ BỊ ĐẢO (XREVERSED) chỉ lấy khi đã có số
*                  HĐĐT (để huỷ) hoặc người dùng tick "lấy CT đã đảo";
*                - mã thuế dòng khách hàng phải khớp MAP TAXCODE
*                  (mặc định seed 'O*' và '**' như dự án tham chiếu);
*                - loại chứng từ theo range màn hình, trống thì lấy
*                  MAP DOCTYPE (trống nữa = mọi loại).
*              Dòng hàng:
*                - BSEG KOART = 'S' có mã thuế; tài khoản trong MAP
*                  GLACCT (nếu khai) và không thuộc MAP TAXACCT;
*                - dấu: ghi Có (H) = dương, ghi Nợ (S) = âm;
*                - thành tiền = WRBTR (nguyên tệ), số lượng MENGE;
*                - CT từ SD: tên hàng theo long text đơn bán / vật tư
*                  (ITEM_TEXT_IDS) -> MAKT -> ARKTX; nối BSEG-VBRP qua
*                  ACDOCA (AWREF/AWITEM);
*                - thuế: MAP TAXRATE -> BSET -> A003/KONP; tiền thuế
*                  từng dòng tính theo % rồi CHỐT theo BSET (chênh
*                  lệch làm tròn dồn vào dòng cuối cùng thuế suất).
*              Khách hàng có logic riêng: copy lớp này, sửa, trỏ cấu
*              hình ZFIT_HDDT_SRC sang lớp mới — engine/adapter không đổi.
* Tham Số    : SELECT_DOCUMENTS( is_selection ) -> ty_t_request
*              GET_DOC_STATE( bukrs gjahr docno ) -> ty_doc_state
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       28/08/2026    cuongus - CuongUS        abapGit     Tạo mới
* 2.0       03/09/2026    cuongus - CuongUS        abapGit     Port logic
*                         FI/Billing từ dự án tham chiếu; kế thừa
*                         ZFIC_HDDT_SRC_BASE
*=====================================================================
CLASS zfic_hddt_src_fi DEFINITION
  PUBLIC
  INHERITING FROM zfic_hddt_src_base
  CREATE PUBLIC .

  PUBLIC SECTION.

    CONSTANTS gc_src_type TYPE zfide_hddt_srctype VALUE 'FI' ##NO_TEXT.

    METHODS zfiif_hddt_source~select_documents REDEFINITION .
    METHODS zfiif_hddt_source~get_doc_state    REDEFINITION .

  PROTECTED SECTION.

    " Header chứng từ + dòng khách hàng (kết quả JOIN BKPF-BSEG)
    TYPES: BEGIN OF ty_hdr,
             bukrs      TYPE bkpf-bukrs,
             belnr      TYPE bkpf-belnr,
             gjahr      TYPE bkpf-gjahr,
             blart      TYPE bkpf-blart,
             budat      TYPE bkpf-budat,
             bldat      TYPE bkpf-bldat,
             cpudt      TYPE bkpf-cpudt,
             usnam      TYPE bkpf-usnam,
             xblnr      TYPE bkpf-xblnr,
             bktxt      TYPE bkpf-bktxt,
             waers      TYPE bkpf-waers,
             kursf      TYPE bkpf-kursf,
             awtyp      TYPE bkpf-awtyp,
             awkey      TYPE bkpf-awkey,
             xreversed  TYPE bkpf-xreversed,
             xreversing TYPE bkpf-xreversing,
             stblg      TYPE bkpf-stblg,
             stjah      TYPE bkpf-stjah,
             cust_buzei TYPE bseg-buzei,
             kunnr      TYPE bseg-kunnr,
             cust_mwskz TYPE bseg-mwskz,
             zlsch      TYPE bseg-zlsch,
             bvtyp      TYPE bseg-bvtyp,
           END OF ty_hdr.
    TYPES ty_t_hdr TYPE STANDARD TABLE OF ty_hdr WITH EMPTY KEY.

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
             menge TYPE bseg-menge,
             meins TYPE bseg-meins,
             matnr TYPE bseg-matnr,
           END OF ty_bseg.
    TYPES ty_t_bseg TYPE STANDARD TABLE OF ty_bseg WITH EMPTY KEY.

    TYPES: BEGIN OF ty_bset,
             bukrs TYPE bset-bukrs,
             belnr TYPE bset-belnr,
             gjahr TYPE bset-gjahr,
             mwskz TYPE bset-mwskz,
             shkzg TYPE bset-shkzg,
             kbetr TYPE bset-kbetr,
             hwbas TYPE bset-hwbas,
             hwste TYPE bset-hwste,
             fwbas TYPE bset-fwbas,
             fwste TYPE bset-fwste,
           END OF ty_bset.
    TYPES ty_t_bset TYPE STANDARD TABLE OF ty_bset WITH EMPTY KEY.

    " Dòng billing SD tham chiếu (khi BKPF-AWTYP = 'VBRK')
    TYPES: BEGIN OF ty_vbrp,
             vbeln TYPE vbrp-vbeln,
             posnr TYPE vbrp-posnr,
             aubel TYPE vbrp-aubel,
             aupos TYPE vbrp-aupos,
             matnr TYPE vbrp-matnr,
             arktx TYPE vbrp-arktx,
             fkimg TYPE vbrp-fkimg,
             vrkme TYPE vbrp-vrkme,
           END OF ty_vbrp.
    TYPES ty_t_vbrp TYPE SORTED TABLE OF ty_vbrp WITH UNIQUE KEY vbeln posnr.

    " Nối dòng kế toán với dòng billing (ACDOCA-AWREF/AWITEM)
    TYPES: BEGIN OF ty_link,
             belnr  TYPE acdoca-belnr,
             buzei  TYPE acdoca-buzei,
             awref  TYPE acdoca-awref,
             awitem TYPE acdoca-awitem,
           END OF ty_link.
    TYPES ty_t_link TYPE SORTED TABLE OF ty_link WITH NON-UNIQUE KEY belnr buzei.

    TYPES: BEGIN OF ty_vbrk_pay,
             vbeln TYPE vbrk-vbeln,
             zlsch TYPE vbrk-zlsch,
           END OF ty_vbrk_pay.
    TYPES ty_t_vbrk_pay TYPE SORTED TABLE OF ty_vbrk_pay WITH UNIQUE KEY vbeln.

    METHODS build_one
      IMPORTING is_hdr            TYPE ty_hdr
                it_bseg           TYPE ty_t_bseg
                it_bset           TYPE ty_t_bset
                it_vbrp           TYPE ty_t_vbrp
                it_link           TYPE ty_t_link
                it_vbrk_pay       TYPE ty_t_vbrk_pay
      RETURNING VALUE(rs_request) TYPE zfiif_hddt_types=>ty_request .

    "! Bảng thuế của chứng từ từ BSET (đã gộp theo thuế suất, có dấu)
    METHODS taxes_from_bset
      IMPORTING iv_bukrs        TYPE bukrs
                it_bset         TYPE ty_t_bset
                it_rate         TYPE ty_t_mwskz_rate
      RETURNING VALUE(rt_taxes) TYPE zfiif_hddt_types=>ty_t_tax .

ENDCLASS.



CLASS zfic_hddt_src_fi IMPLEMENTATION.

  METHOD zfiif_hddt_source~select_documents.

    IF is_selection-bukrs IS INITIAL.
      zficx_hddt_error=>raise_text( `Thiếu mã công ty (BUKRS) khi đọc chứng từ FI.` ).
    ENDIF.

    load_registry( iv_bukrs    = is_selection-bukrs
                   iv_gjahr    = is_selection-gjahr
                   iv_src_type = gc_src_type ).

*---- Loại chứng từ: range màn hình, trống -> MAP DOCTYPE -------------*
    DATA lr_blart TYPE zfiif_hddt_types=>ty_r_blart.
    lr_blart = is_selection-r_blart.
    IF lr_blart IS INITIAL.
      LOOP AT map_list_as_range( zfiif_hddt_types=>gc_map_type-doc_type )
           ASSIGNING FIELD-SYMBOL(<ls_r>).
        APPEND VALUE #( sign = <ls_r>-sign option = <ls_r>-option
                        low  = <ls_r>-low(2) ) TO lr_blart.
      ENDLOOP.
    ENDIF.

*---- 1. Header + dòng khách hàng --------------------------------------*
    " Không lấy chứng từ ĐẢO (XREVERSING); chứng từ BỊ ĐẢO lọc ở dưới
    " theo quy tắc "chỉ lấy khi đã có số HĐĐT".
    DATA lt_hdr TYPE ty_t_hdr.
    SELECT k~bukrs, k~belnr, k~gjahr, k~blart, k~budat, k~bldat, k~cpudt,
           k~usnam, k~xblnr, k~bktxt, k~waers, k~kursf, k~awtyp, k~awkey,
           k~xreversed, k~xreversing, k~stblg, k~stjah,
           s~buzei AS cust_buzei, s~kunnr, s~mwskz AS cust_mwskz,
           s~zlsch, s~bvtyp
      FROM bkpf AS k
      INNER JOIN bseg AS s ON s~bukrs = k~bukrs
                          AND s~belnr = k~belnr
                          AND s~gjahr = k~gjahr
      WHERE k~bukrs       = @is_selection-bukrs
        AND k~gjahr       = @is_selection-gjahr
        AND k~belnr      IN @is_selection-r_docno
        AND k~budat      IN @is_selection-r_budat
        AND k~bldat      IN @is_selection-r_bldat
        AND k~blart      IN @lr_blart
        AND k~usnam      IN @is_selection-r_usnam
        AND k~awkey      IN @is_selection-r_vbeln
        AND k~xreversing  = @space
        AND s~koart       = 'D'
        AND s~kunnr      IN @is_selection-r_kunnr
      ORDER BY k~belnr, s~buzei
      INTO TABLE @lt_hdr.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    " Một chứng từ = một hoá đơn: lấy dòng khách hàng đầu tiên
    DELETE ADJACENT DUPLICATES FROM lt_hdr COMPARING belnr.

*---- 2. Lọc theo mã thuế đầu ra, chứng từ đã đảo, trạng thái ---------*
    LOOP AT lt_hdr ASSIGNING FIELD-SYMBOL(<ls_hdr>).
      IF in_map_list( iv_map_type = zfiif_hddt_types=>gc_map_type-tax_code
                      iv_value    = <ls_hdr>-cust_mwskz ) = abap_false.
        DELETE lt_hdr.
        CONTINUE.
      ENDIF.
      DATA(ls_reg) = registry_of( iv_bukrs    = <ls_hdr>-bukrs
                                  iv_gjahr    = <ls_hdr>-gjahr
                                  iv_src_type = gc_src_type
                                  iv_docno    = CONV #( <ls_hdr>-belnr ) ).
      IF keep_document( iv_reversed  = xsdbool( <ls_hdr>-xreversed = 'X' )
                        is_reg       = ls_reg
                        is_selection = is_selection ) = abap_false.
        DELETE lt_hdr.
      ENDIF.
    ENDLOOP.
    IF lt_hdr IS INITIAL.
      RETURN.
    ENDIF.

*---- 3. Dòng chứng từ, bảng thuế, dữ liệu billing tham chiếu --------*
    DATA lt_belnr TYPE RANGE OF belnr_d.
    DATA lt_vbeln TYPE RANGE OF vbeln_vf.
    LOOP AT lt_hdr ASSIGNING <ls_hdr>.
      APPEND VALUE #( sign = 'I' option = 'EQ' low = <ls_hdr>-belnr ) TO lt_belnr.
      IF <ls_hdr>-awtyp = 'VBRK' AND <ls_hdr>-awkey IS NOT INITIAL.
        APPEND VALUE #( sign = 'I' option = 'EQ' low = <ls_hdr>-awkey(10) ) TO lt_vbeln.
      ENDIF.
    ENDLOOP.

    DATA lt_bseg TYPE ty_t_bseg.
    SELECT bukrs, belnr, gjahr, buzei, koart, shkzg, hkont, kunnr,
           dmbtr, wrbtr, mwskz, sgtxt, menge, meins, matnr
      FROM bseg
      WHERE bukrs  = @is_selection-bukrs
        AND gjahr  = @is_selection-gjahr
        AND belnr IN @lt_belnr
      ORDER BY belnr, buzei
      INTO TABLE @lt_bseg.

    DATA lt_bset TYPE ty_t_bset.
    SELECT bukrs, belnr, gjahr, mwskz, shkzg, kbetr, hwbas, hwste, fwbas, fwste
      FROM bset
      WHERE bukrs  = @is_selection-bukrs
        AND gjahr  = @is_selection-gjahr
        AND belnr IN @lt_belnr
      INTO TABLE @lt_bset.

    DATA lt_vbrp     TYPE ty_t_vbrp.
    DATA lt_link     TYPE ty_t_link.
    DATA lt_vbrk_pay TYPE ty_t_vbrk_pay.
    IF lt_vbeln IS NOT INITIAL.
      SELECT vbeln, posnr, aubel, aupos, matnr, arktx, fkimg, vrkme
        FROM vbrp
        WHERE vbeln IN @lt_vbeln
        INTO TABLE @lt_vbrp.

      SELECT vbeln, zlsch
        FROM vbrk
        WHERE vbeln IN @lt_vbeln
        INTO TABLE @lt_vbrk_pay.

      " Nối dòng kế toán <-> dòng billing như dự án tham chiếu (ACDOCA)
      SELECT belnr, buzei, awref, awitem
        FROM acdoca
        WHERE rldnr   = '0L'
          AND rbukrs  = @is_selection-bukrs
          AND gjahr   = @is_selection-gjahr
          AND belnr  IN @lt_belnr
          AND awtyp   = 'VBRK'
          AND awref  <> @space
        INTO TABLE @lt_link.
    ENDIF.

*---- 4. Dựng request từng chứng từ -----------------------------------*
    LOOP AT lt_hdr ASSIGNING <ls_hdr>.
      DATA(lt_doc_bseg) = VALUE ty_t_bseg( FOR ls IN lt_bseg
                                           WHERE ( belnr = <ls_hdr>-belnr ) ( ls ) ).
      DATA(lt_doc_bset) = VALUE ty_t_bset( FOR lt IN lt_bset
                                           WHERE ( belnr = <ls_hdr>-belnr ) ( lt ) ).

      DATA(ls_req) = build_one( is_hdr      = <ls_hdr>
                                it_bseg     = lt_doc_bseg
                                it_bset     = lt_doc_bset
                                it_vbrp     = lt_vbrp
                                it_link     = lt_link
                                it_vbrk_pay = lt_vbrk_pay ).
      IF ls_req-src_docno IS NOT INITIAL.
        APPEND ls_req TO rt_request.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD zfiif_hddt_source~get_doc_state.

    DATA lv_belnr TYPE belnr_d.
    lv_belnr = iv_docno.

    SELECT SINGLE xreversed, stblg, stjah, waers
      FROM bkpf
      WHERE bukrs = @iv_bukrs
        AND belnr = @lv_belnr
        AND gjahr = @iv_gjahr
      INTO @DATA(ls_bkpf).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    rs_state-exists    = abap_true.
    rs_state-xreversed = xsdbool( ls_bkpf-xreversed = 'X' OR ls_bkpf-stblg IS NOT INITIAL ).
    rs_state-stblg     = ls_bkpf-stblg.
    rs_state-stjah     = ls_bkpf-stjah.
    rs_state-waers     = ls_bkpf-waers.

    SELECT kunnr FROM bseg
      WHERE bukrs = @iv_bukrs
        AND belnr = @lv_belnr
        AND gjahr = @iv_gjahr
        AND koart = 'D'
      ORDER BY buzei
      INTO TABLE @DATA(lt_kunnr)
      UP TO 1 ROWS.
    IF sy-subrc = 0.
      rs_state-kunnr = lt_kunnr[ 1 ]-kunnr.
    ENDIF.

  ENDMETHOD.


  METHOD build_one.

    DATA ls_item TYPE zfiif_hddt_types=>ty_item.
    DATA lv_line TYPE zfide_hddt_lineno.
    DATA lt_rate TYPE ty_t_mwskz_rate.

    rs_request-bukrs     = is_hdr-bukrs.
    rs_request-gjahr     = is_hdr-gjahr.
    rs_request-src_type  = gc_src_type.
    rs_request-src_docno = is_hdr-belnr.

    DATA(lv_sd) = xsdbool( is_hdr-awtyp = 'VBRK' AND is_hdr-awkey IS NOT INITIAL ).
    DATA lv_vbeln TYPE vbeln_vf.
    IF lv_sd = abap_true.
      lv_vbeln = is_hdr-awkey(10).
    ENDIF.

*---- Thông tin chứng từ nguồn cho engine kiểm tra nghiệp vụ ----------*
    rs_request-src_info = VALUE #(
      blart     = is_hdr-blart
      budat     = is_hdr-budat
      bldat     = is_hdr-bldat
      cpudt     = is_hdr-cpudt
      usnam     = is_hdr-usnam
      xblnr     = is_hdr-xblnr
      kunnr     = is_hdr-kunnr
      awtyp     = is_hdr-awtyp
      awkey     = is_hdr-awkey
      xreversed = xsdbool( is_hdr-xreversed = 'X' OR is_hdr-stblg IS NOT INITIAL )
      stblg     = is_hdr-stblg
      stjah     = is_hdr-stjah ).

*---- Header ----------------------------------------------------------*
    rs_request-invoice-header = VALUE #(
      currency  = is_hdr-waers
      exch_rate = exch_rate_of( iv_bukrs = is_hdr-bukrs
                                iv_waers = is_hdr-waers
                                iv_kursf = is_hdr-kursf )
      note      = is_hdr-bktxt
      inv_date  = config( )->resolve_invoice_date( iv_bukrs = is_hdr-bukrs
                                                   iv_budat = is_hdr-budat
                                                   iv_bldat = is_hdr-bldat
                                                   iv_cpudt = is_hdr-cpudt )
      inv_time  = sy-uzeit ).

*---- Người mua -------------------------------------------------------*
    DATA lv_aubel TYPE vbeln.
    IF lv_sd = abap_true.
      LOOP AT it_vbrp ASSIGNING FIELD-SYMBOL(<ls_vbrp0>) WHERE vbeln = lv_vbeln.
        lv_aubel = <ls_vbrp0>-aubel.
        EXIT.
      ENDLOOP.
    ENDIF.
    rs_request-invoice-buyer = read_buyer( iv_kunnr = is_hdr-kunnr
                                           iv_bukrs = is_hdr-bukrs
                                           iv_belnr = is_hdr-belnr
                                           iv_gjahr = is_hdr-gjahr
                                           iv_bvtyp = is_hdr-bvtyp
                                           iv_aubel = lv_aubel ).
    IF rs_request-invoice-buyer-ref_no IS NOT INITIAL.
      rs_request-invoice-header-contract_no = rs_request-invoice-buyer-ref_no.
    ENDIF.

*---- Hình thức thanh toán: BSEG-ZLSCH, không có thì VBRK-ZLSCH -------*
    DATA(lv_zlsch) = is_hdr-zlsch.
    IF lv_zlsch IS INITIAL AND lv_sd = abap_true.
      TRY.
          lv_zlsch = it_vbrk_pay[ vbeln = lv_vbeln ]-zlsch.
        CATCH cx_sy_itab_line_not_found.
      ENDTRY.
    ENDIF.
    DATA(ls_pay) = payment_of( iv_zlsch = lv_zlsch iv_bukrs = is_hdr-bukrs ).
    IF ls_pay-method_code IS NOT INITIAL.
      APPEND ls_pay TO rs_request-invoice-payments.
    ENDIF.

*---- Thuế suất theo mã thuế từ bảng thuế chứng từ --------------------*
    LOOP AT it_bset ASSIGNING FIELD-SYMBOL(<ls_bset>).
      INSERT VALUE #( mwskz = <ls_bset>-mwskz kbetr = <ls_bset>-kbetr ) INTO TABLE lt_rate.
    ENDLOOP.

*---- Dòng hàng: BSEG KOART = 'S' có mã thuế -------------------------*
    LOOP AT it_bseg ASSIGNING FIELD-SYMBOL(<ls_line>)
         WHERE koart = 'S' AND mwskz <> space.

      " Tài khoản doanh thu theo cấu hình; loại tài khoản thuế GTGT
      IF in_map_list( iv_map_type = zfiif_hddt_types=>gc_map_type-gl_acct
                      iv_value    = <ls_line>-hkont ) = abap_false.
        CONTINUE.
      ENDIF.
      IF in_map_list( iv_map_type = zfiif_hddt_types=>gc_map_type-tax_acct
                      iv_value    = <ls_line>-hkont
                      iv_default  = abap_false ) = abap_true.
        CONTINUE.
      ENDIF.

      CLEAR ls_item.
      lv_line = lv_line + 1.
      ls_item-line_no   = lv_line.
      ls_item-item_type = '0'.
      ls_item-item_code = <ls_line>-matnr.
      ls_item-quantity  = <ls_line>-menge.
      ls_item-unit      = unit_text( <ls_line>-meins ).

      " Ghi Có = doanh thu dương; ghi Nợ (giảm trừ) = âm
      DATA(lv_sign) = COND i( WHEN <ls_line>-shkzg = 'H' THEN 1 ELSE -1 ).
      ls_item-amount = <ls_line>-wrbtr * lv_sign.

      " Tên hàng
      IF lv_sd = abap_true.
        DATA ls_vbrp TYPE ty_vbrp.
        CLEAR ls_vbrp.
        LOOP AT it_link ASSIGNING FIELD-SYMBOL(<ls_link>)
             WHERE belnr = <ls_line>-belnr AND buzei = <ls_line>-buzei.
          TRY.
              ls_vbrp = it_vbrp[ vbeln = <ls_link>-awref
                                 posnr = CONV posnr( <ls_link>-awitem ) ].
              EXIT.
            CATCH cx_sy_itab_line_not_found.
              CLEAR ls_vbrp.
          ENDTRY.
        ENDLOOP.
        IF ls_vbrp IS NOT INITIAL.
          IF ls_item-item_code IS INITIAL.
            ls_item-item_code = ls_vbrp-matnr.
          ENDIF.
          IF ls_item-quantity IS INITIAL.
            ls_item-quantity = ls_vbrp-fkimg.
            ls_item-unit     = unit_text( ls_vbrp-vrkme ).
          ENDIF.
          ls_item-item_name = item_name( iv_bukrs   = is_hdr-bukrs
                                         iv_vbeln   = ls_vbrp-aubel
                                         iv_posnr   = ls_vbrp-aupos
                                         iv_matnr   = ls_vbrp-matnr
                                         iv_default = ls_vbrp-arktx ).
        ENDIF.
      ENDIF.
      IF ls_item-item_name IS INITIAL.
        ls_item-item_name = <ls_line>-sgtxt.
      ENDIF.
      IF ls_item-item_name IS INITIAL.
        config( )->map_value( EXPORTING iv_provider  = space
                                        iv_map_type  = zfiif_hddt_types=>gc_map_type-gl_acct
                                        iv_sap_value = <ls_line>-hkont
                              IMPORTING ev_ext_text  = DATA(lv_acct_txt) ).
        ls_item-item_name = lv_acct_txt.
      ENDIF.
      IF ls_item-item_name IS INITIAL.
        ls_item-item_name = material_text( <ls_line>-matnr ).
      ENDIF.
      IF ls_item-item_name IS INITIAL.
        ls_item-item_name = |{ <ls_line>-hkont ALPHA = OUT }|.
      ENDIF.
      CONDENSE ls_item-item_name.

      IF ls_item-quantity <> 0.
        ls_item-price = ls_item-amount / ls_item-quantity.
      ENDIF.

      ls_item-tax_rate     = tax_rate_of( iv_bukrs = is_hdr-bukrs
                                          iv_mwskz = <ls_line>-mwskz
                                          it_rate  = lt_rate ).
      ls_item-tax_rate_txt = rate_text( ls_item-tax_rate ).
      ls_item-tax_amount   = line_tax( iv_amount = ls_item-amount
                                       iv_rate   = ls_item-tax_rate
                                       iv_waers  = is_hdr-waers ).
      ls_item-total        = ls_item-amount + ls_item-tax_amount.

      APPEND ls_item TO rs_request-invoice-items.
    ENDLOOP.

*---- Bảng thuế từ BSET và chốt tiền thuế từng dòng -------------------*
    rs_request-invoice-taxes = taxes_from_bset( iv_bukrs = is_hdr-bukrs
                                                it_bset  = it_bset
                                                it_rate  = lt_rate ).
    reconcile_tax( EXPORTING it_tax   = rs_request-invoice-taxes
                   CHANGING  ct_items = rs_request-invoice-items ).

    finalize_request( CHANGING cs_request = rs_request ).

  ENDMETHOD.


  METHOD taxes_from_bset.

    FIELD-SYMBOLS <ls_tax> TYPE zfiif_hddt_types=>ty_tax.

    LOOP AT it_bset ASSIGNING FIELD-SYMBOL(<ls_bset>).
      IF <ls_bset>-fwbas IS INITIAL AND <ls_bset>-hwbas IS INITIAL
         AND <ls_bset>-fwste IS INITIAL AND <ls_bset>-hwste IS INITIAL.
        CONTINUE.
      ENDIF.

      DATA(lv_rate) = tax_rate_of( iv_bukrs = iv_bukrs
                                   iv_mwskz = <ls_bset>-mwskz
                                   it_rate  = it_rate ).
      " Thuế đầu ra ghi Có (H) = dương; ghi Nợ (S) = âm — như dự án tham chiếu
      DATA(lv_sign) = COND i( WHEN <ls_bset>-shkzg = 'S' THEN -1 ELSE 1 ).

      READ TABLE rt_taxes ASSIGNING <ls_tax> WITH KEY tax_rate = lv_rate.
      IF sy-subrc <> 0.
        APPEND INITIAL LINE TO rt_taxes ASSIGNING <ls_tax>.
        <ls_tax>-tax_rate     = lv_rate.
        <ls_tax>-tax_rate_txt = rate_text( lv_rate ).
        <ls_tax>-is_increase  = abap_true.
      ENDIF.
      <ls_tax>-taxable_amt   = <ls_tax>-taxable_amt   + <ls_bset>-fwbas * lv_sign.
      <ls_tax>-taxable_amt_l = <ls_tax>-taxable_amt_l + <ls_bset>-hwbas * lv_sign.
      <ls_tax>-tax_amt       = <ls_tax>-tax_amt       + <ls_bset>-fwste * lv_sign.
      <ls_tax>-tax_amt_l     = <ls_tax>-tax_amt_l     + <ls_bset>-hwste * lv_sign.
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
