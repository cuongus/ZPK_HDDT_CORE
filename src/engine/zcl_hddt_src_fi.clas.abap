*=====================================================================
* Tên/Mã     : ZCL_HDDT_SRC_FI
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
*              hình ZTB_HDDT_SRC sang lớp mới — engine/adapter không đổi.
* Tham Số    : SELECT_DOCUMENTS( is_selection ) -> ty_t_request
*              GET_DOC_STATE( bukrs gjahr docno ) -> ty_doc_state
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       28/08/2026    cuongus - CuongUS        abapGit     Tạo mới
* 2.0       03/09/2026    cuongus - CuongUS        abapGit     Port logic
*                         FI/Billing từ dự án tham chiếu; kế thừa
*                         ZCL_HDDT_SRC_BASE
* 2.1       27/09/2026    F-DUBV                   S25K900131  R06: goi
*                         PREFETCH_SELLER / PREFETCH_MAT_TEXTS /
*                         PREFETCH_BUYER_DOCS truoc vong lap buoc 4
*                         (review S25 27/09)
* 2.2       28/09/2026    F-DUBV                   S25K900131  R06: goi
*                         PREFETCH_BUYER_MASTER truoc vong lap buoc 4
*                         (review S25 28/09)
* 1.3       30/09/2026    cuongus - CuongUS        DS4K900172  20260930_01 Kiem
*                         chung DS4: quy doi so tien theo TCURX (VND
*                         luu chia 100), ty gia theo TCURF (1:1000)
*=====================================================================
CLASS zcl_hddt_src_fi DEFINITION
  PUBLIC
  INHERITING FROM zcl_hddt_src_base
  CREATE PUBLIC .

  PUBLIC SECTION.

    CONSTANTS gc_src_type TYPE zde_hddt_srctype VALUE 'FI' ##NO_TEXT.

    METHODS zif_hddt_source~select_documents REDEFINITION .
    METHODS zif_hddt_source~get_doc_state    REDEFINITION .

  PROTECTED SECTION.

    "! Header chứng từ + dòng khách hàng (kết quả JOIN BKPF-BSEG)
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
             rebzg      TYPE bseg-rebzg,
             rebzj      TYPE bseg-rebzj,
             awref_rev  TYPE bkpf-awref_rev,
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

    "! Loại CẶP chứng từ gốc - chứng từ đảo khỏi danh sách (FS v0.17
    "! mục 3.3). Quy tắc ghép cặp phụ thuộc nguồn gốc chứng từ:
    "! AWTYP = VBRK thì BKPF-AWREF_REV bằng 08 ký tự CUỐI của AWKEY;
    "! AWTYP khác VBRK thì bằng 10 ký tự ĐẦU của AWKEY. Thêm điều kiện
    "! BUDAT của hai chứng từ trùng nhau thì loại CẢ CẶP.
    "! Người dùng tích tham số Loại chứng từ hủy thì giữ nguyên.
    METHODS drop_reversed_pairs
      IMPORTING is_selection TYPE zif_hddt_source=>ty_selection
      CHANGING  ct_hdr       TYPE ty_t_hdr .

    "! Chiều điều chỉnh theo FS v0.17 mục 3.6.4: cộng RÒNG các dòng tài
    "! khoản doanh thu (khai trong MAP GLACCT, tài khoản 5*), quy ước
    "! dòng ghi Có mang dấu dương và dòng ghi Nợ mang dấu âm.
    "! Tổng ròng lớn hơn 0 cho 1 - điều chỉnh TĂNG (adjtype 2).
    "! Tổng ròng nhỏ hơn 0 cho 0 - điều chỉnh GIẢM (adjtype 3).
    "! Dòng thuế GTGT đầu ra luôn cùng chiều với dòng doanh thu nên bị
    "! loại khỏi phép tính, chỉ dùng để dựng nội dung hoá đơn.
    METHODS adjust_dir
      IMPORTING it_bseg      TYPE ty_t_bseg
      RETURNING VALUE(r_dir) TYPE zde_hddt_adjdir .

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

    "! Dòng billing SD tham chiếu (khi BKPF-AWTYP = 'VBRK')
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

    "! Nối dòng kế toán với dòng billing (ACDOCA-AWREF/AWITEM)
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

    "! Dòng BSEG này có dựng thành dòng hàng hoá không. FI: tài khoản
    "! doanh thu (MAP GLACCT) và không phải tài khoản thuế GTGT. Lớp con
    "! redefine khi dòng hàng lấy từ tài khoản khác - ZCL_HDDT_SRC_PO lấy
    "! dòng vật tư / chi phí của chứng từ trả lại hàng NCC.
    METHODS is_item_account
      IMPORTING i_bukrs         TYPE bukrs
                i_hkont         TYPE hkont
      RETURNING VALUE(r_result) TYPE abap_bool .

    "! Dòng BSEG này có phải dòng thuế GTGT không. FI: MAP TAXACCT (thuế
    "! đầu ra 3331*). ZCL_HDDT_SRC_PO: thuế đầu vào 1331* (ZTB_HDDT_PO).
    METHODS is_tax_account
      IMPORTING i_bukrs         TYPE bukrs
                i_hkont         TYPE hkont
      RETURNING VALUE(r_result) TYPE abap_bool .

    "! Người mua trên hoá đơn. FI: khách hàng của dòng công nợ. Lớp con
    "! ZCL_HDDT_SRC_PO: nhà cung cấp (LFA1).
    METHODS buyer_of
      IMPORTING is_hdr          TYPE ty_hdr
                i_aubel         TYPE vbeln OPTIONAL
      RETURNING VALUE(rs_buyer) TYPE zif_hddt_types=>ty_buyer .

    METHODS build_one
      IMPORTING is_hdr            TYPE ty_hdr
                it_bseg           TYPE ty_t_bseg
                it_bset           TYPE ty_t_bset
                it_vbrp           TYPE ty_t_vbrp
                it_link           TYPE ty_t_link
                it_vbrk_pay       TYPE ty_t_vbrk_pay
      RETURNING VALUE(rs_request) TYPE zif_hddt_types=>ty_request .

    "! Bảng thuế từ dòng BSEG có tài khoản thuế GTGT (MAP TAXACCT) — FS MAG
    METHODS taxes_from_taxacct
      IMPORTING i_bukrs         TYPE bukrs
*   >>> Begin of change 20260930_01 F-CUONGUS TR DS4K900172 - Kiem chung DS4: so tien theo TCURX, ty gia theo TCURF
                i_waers         TYPE waers
*   <<< End of change 20260930_01
                it_bseg         TYPE ty_t_bseg
                it_rate         TYPE ty_t_mwskz_rate
      RETURNING VALUE(rt_taxes) TYPE zif_hddt_types=>ty_t_tax .

    "! Bảng thuế của chứng từ từ BSET (đã gộp theo thuế suất, có dấu)
    METHODS taxes_from_bset
      IMPORTING i_bukrs        TYPE bukrs
*   >>> Begin of change 20260930_01 F-CUONGUS TR DS4K900172 - Kiem chung DS4: so tien theo TCURX, ty gia theo TCURF
                i_waers         TYPE waers
*   <<< End of change 20260930_01
                it_bset         TYPE ty_t_bset
                it_rate         TYPE ty_t_mwskz_rate
      RETURNING VALUE(rt_taxes) TYPE zif_hddt_types=>ty_t_tax .

ENDCLASS.



CLASS ZCL_HDDT_SRC_FI IMPLEMENTATION.


  METHOD adjust_dir.

    " Cong RONG cac dong tai khoan doanh thu: Co mang dau duong, No mang
    " dau am. Dong thue GTGT dau ra luon cung chieu voi dong doanh thu
    " nen loai ra, khong dung de xac dinh loai dieu chinh.
    DATA lv_net TYPE bseg-dmbtr.

    LOOP AT it_bseg ASSIGNING FIELD-SYMBOL(<fs_l>) WHERE koart = 'S'.
      IF is_item_account( i_bukrs = <fs_l>-bukrs i_hkont = <fs_l>-hkont ) = abap_false.
        CONTINUE.
      ENDIF.
      IF <fs_l>-shkzg = 'H'.
        lv_net = lv_net + <fs_l>-dmbtr.
      ELSE.
        lv_net = lv_net - <fs_l>-dmbtr.
      ENDIF.
    ENDLOOP.

    " Tren SAP khong phat sinh chung tu co so tien bang 0 nen khong co
    " truong hop tong rong bang 0; de trong de caller tu bao loi.
    r_dir = COND #( WHEN lv_net > 0 THEN '1'
                    WHEN lv_net < 0 THEN '0' ).

  ENDMETHOD.


  METHOD build_one.

    DATA ls_item TYPE zif_hddt_types=>ty_item.
    DATA lv_line TYPE zde_hddt_lineno.
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
      stjah     = is_hdr-stjah
      rebzg     = is_hdr-rebzg
      rebzj     = is_hdr-rebzj
      awref_rev = is_hdr-awref_rev
      bill_doc  = lv_vbeln ).

*---- Header ----------------------------------------------------------*
    rs_request-invoice-header = VALUE #(
      currency  = is_hdr-waers
      exch_rate = exch_rate_of( i_bukrs = is_hdr-bukrs
                                i_waers = is_hdr-waers
*   >>> Begin of change 20260930_01 F-CUONGUS TR DS4K900172 - Kiem chung DS4: so tien theo TCURX, ty gia theo TCURF
*                                i_kursf = is_hdr-kursf )
                                i_kursf = is_hdr-kursf
                                i_date  = is_hdr-budat )
*   <<< End of change 20260930_01
      note      = is_hdr-bktxt
      inv_date  = config( )->resolve_invoice_date( i_bukrs = is_hdr-bukrs
                                                   i_budat = is_hdr-budat
                                                   i_bldat = is_hdr-bldat
                                                   i_cpudt = is_hdr-cpudt )
      inv_time  = sy-uzeit ).

*---- Người mua -------------------------------------------------------*
    DATA lv_aubel TYPE vbeln.
    IF lv_sd = abap_true.
      LOOP AT it_vbrp ASSIGNING FIELD-SYMBOL(<fs_vbrp0>) WHERE vbeln = lv_vbeln.
        lv_aubel = <fs_vbrp0>-aubel.
        EXIT.
      ENDLOOP.
    ENDIF.
    rs_request-invoice-buyer = buyer_of( is_hdr = is_hdr i_aubel = lv_aubel ).
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
    DATA(ls_pay) = payment_of( i_zlsch = lv_zlsch i_bukrs = is_hdr-bukrs ).
    IF ls_pay-method_code IS NOT INITIAL.
      APPEND ls_pay TO rs_request-invoice-payments.
    ENDIF.

*---- Hoá đơn gốc + loại điều chỉnh (FS v0.17 mục 3.6.4) --------------*
    " Chứng từ có REBZG khác trống là chứng từ ĐIỀU CHỈNH hoặc THAY THẾ.
    " Hoá đơn gốc lấy từ chính dữ liệu đã hạch toán, không hỏi người dùng.
    IF is_hdr-rebzg IS NOT INITIAL.
      rs_request-invoice-adjust-org_docno    = is_hdr-rebzg.
      rs_request-invoice-adjust-org_gjahr    = COND #(
        WHEN is_hdr-rebzj IS NOT INITIAL THEN is_hdr-rebzj ELSE is_hdr-gjahr ).
      rs_request-invoice-adjust-org_src_type = gc_src_type.
      rs_request-invoice-adjust-adj_direction = adjust_dir( it_bseg ).
    ENDIF.

*---- Thuế suất theo mã thuế từ bảng thuế chứng từ --------------------*
    LOOP AT it_bset ASSIGNING FIELD-SYMBOL(<fs_bset>).
      INSERT VALUE #( mwskz = <fs_bset>-mwskz kbetr = <fs_bset>-kbetr ) INTO TABLE lt_rate.
    ENDLOOP.

*---- Dòng hàng: BSEG KOART = 'S' có mã thuế -------------------------*
    LOOP AT it_bseg ASSIGNING FIELD-SYMBOL(<fs_line>)
         WHERE koart = 'S' AND mwskz <> space.

      " Tài khoản sinh dòng hàng theo nghiệp vụ; loại tài khoản thuế GTGT
      IF is_item_account( i_bukrs = <fs_line>-bukrs i_hkont = <fs_line>-hkont ) = abap_false.
        CONTINUE.
      ENDIF.

      CLEAR ls_item.
      lv_line = lv_line + 1.
      ls_item-line_no   = lv_line.
      ls_item-item_type = '0'.
      ls_item-item_code = <fs_line>-matnr.
      ls_item-quantity  = <fs_line>-menge.
      ls_item-unit      = unit_text( <fs_line>-meins ).

      " Ghi Có = doanh thu dương; ghi Nợ (giảm trừ) = âm
      DATA(lv_sign) = COND i( WHEN <fs_line>-shkzg = 'H' THEN 1 ELSE -1 ).
*   >>> Begin of change 20260930_01 F-CUONGUS TR DS4K900172 - Kiem chung DS4: so tien theo TCURX, ty gia theo TCURF
*      ls_item-amount = <fs_line>-wrbtr * lv_sign.
      " WRBTR lưu theo số lẻ của đồng tiền (VND chia 100) - quy đổi ngay
      ls_item-amount = amount_of( i_amount = CONV #( <fs_line>-wrbtr )
                                  i_waers  = is_hdr-waers ) * lv_sign.
*   <<< End of change 20260930_01

      " Tên hàng
      IF lv_sd = abap_true.
        DATA ls_vbrp TYPE ty_vbrp.
        CLEAR ls_vbrp.
        LOOP AT it_link ASSIGNING FIELD-SYMBOL(<fs_link>)
             WHERE belnr = <fs_line>-belnr AND buzei = <fs_line>-buzei.
          TRY.
              ls_vbrp = it_vbrp[ vbeln = <fs_link>-awref
                                 posnr = CONV posnr( <fs_link>-awitem ) ].
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
          ls_item-item_name = item_name( i_bukrs   = is_hdr-bukrs
                                         i_vbeln   = ls_vbrp-aubel
                                         i_posnr   = ls_vbrp-aupos
                                         i_matnr   = ls_vbrp-matnr
                                         i_default = ls_vbrp-arktx ).
        ENDIF.
      ENDIF.
      IF ls_item-item_name IS INITIAL.
        ls_item-item_name = <fs_line>-sgtxt.
      ENDIF.
      IF ls_item-item_name IS INITIAL.
        config( )->map_value( EXPORTING i_provider  = space
                                        i_map_type  = zif_hddt_types=>gc_map_type-gl_acct
                                        i_sap_value = <fs_line>-hkont
                              IMPORTING e_ext_text  = DATA(lv_acct_txt) ).
        ls_item-item_name = lv_acct_txt.
      ENDIF.
      IF ls_item-item_name IS INITIAL.
        ls_item-item_name = material_text( <fs_line>-matnr ).
      ENDIF.
      IF ls_item-item_name IS INITIAL.
        ls_item-item_name = |{ <fs_line>-hkont ALPHA = OUT }|.
      ENDIF.
      CONDENSE ls_item-item_name.

      IF ls_item-quantity <> 0.
        ls_item-price = ls_item-amount / ls_item-quantity.
      ENDIF.

      ls_item-tax_rate     = tax_rate_of( i_bukrs = is_hdr-bukrs
                                          i_mwskz = <fs_line>-mwskz
                                          it_rate  = lt_rate ).
      ls_item-tax_rate_txt = rate_text( ls_item-tax_rate ).
      ls_item-tax_amount   = line_tax( i_amount = ls_item-amount
                                       i_rate   = ls_item-tax_rate
                                       i_waers  = is_hdr-waers ).
      ls_item-total        = ls_item-amount + ls_item-tax_amount.

      APPEND ls_item TO rs_request-invoice-items.
    ENDLOOP.

*---- Bảng thuế từ BSET và chốt tiền thuế từng dòng -------------------*
    " FS MAG mục 3.5: tiền thuế = tổng dòng BSEG có tài khoản 3331* (MAP
    " TAXACCT). Mặc định vẫn dùng BSET (sổ thuế); tham số TAX_SOURCE =
    " GLACCT hoặc chứng từ không có BSET -> tính từ dòng tài khoản thuế.
    IF param( i_key = zif_hddt_types=>gc_parm-tax_source
              i_bukrs = is_hdr-bukrs i_default = `BSET` ) = 'GLACCT'
       OR it_bset IS INITIAL.
*   >>> Begin of change 20260930_01 F-CUONGUS TR DS4K900172 - Kiem chung DS4: so tien theo TCURX, ty gia theo TCURF
*      rs_request-invoice-taxes = taxes_from_taxacct( i_bukrs = is_hdr-bukrs
      rs_request-invoice-taxes = taxes_from_taxacct( i_bukrs = is_hdr-bukrs
                                                     i_waers  = is_hdr-waers
*   <<< End of change 20260930_01
                                                     it_bseg  = it_bseg
                                                     it_rate  = lt_rate ).
    ELSE.
*   >>> Begin of change 20260930_01 F-CUONGUS TR DS4K900172 - Kiem chung DS4: so tien theo TCURX, ty gia theo TCURF
*      rs_request-invoice-taxes = taxes_from_bset( i_bukrs = is_hdr-bukrs
      rs_request-invoice-taxes = taxes_from_bset( i_bukrs = is_hdr-bukrs
                                                  i_waers  = is_hdr-waers
*   <<< End of change 20260930_01
                                                  it_bset  = it_bset
                                                  it_rate  = lt_rate ).
    ENDIF.
    reconcile_tax( EXPORTING it_tax   = rs_request-invoice-taxes
                   CHANGING  ct_items = rs_request-invoice-items ).

    finalize_request( CHANGING cs_request = rs_request ).

  ENDMETHOD.


  METHOD buyer_of.

    rs_buyer = read_buyer( i_kunnr = is_hdr-kunnr
                           i_bukrs = is_hdr-bukrs
                           i_belnr = is_hdr-belnr
                           i_gjahr = is_hdr-gjahr
                           i_bvtyp = is_hdr-bvtyp
                           i_aubel = i_aubel ).

  ENDMETHOD.


  METHOD drop_reversed_pairs.

    IF is_selection-xreversed = abap_true OR ct_hdr IS INITIAL.
      RETURN.
    ENDIF.

    " Voi moi chung tu dang co, dung ra gia tri AWREF_REV ma chung tu dao
    " cua no se mang, roi doc BKPF MOT lan cho ca danh sach.
    TYPES: BEGIN OF ty_pair,
             belnr TYPE bkpf-belnr,
             ref   TYPE bkpf-awref_rev,
             budat TYPE bkpf-budat,
           END OF ty_pair.
    DATA lt_pair TYPE STANDARD TABLE OF ty_pair WITH EMPTY KEY.
    DATA lr_ref  TYPE RANGE OF bkpf-awref_rev.
    DATA lv_ref  TYPE bkpf-awref_rev.

    LOOP AT ct_hdr ASSIGNING FIELD-SYMBOL(<fs_h>) WHERE awkey IS NOT INITIAL.
      IF <fs_h>-awtyp = 'VBRK'.
        lv_ref = substring( val = <fs_h>-awkey
                            off = strlen( <fs_h>-awkey ) - 8
                            len = 8 ).
      ELSE.
        lv_ref = <fs_h>-awkey(10).
      ENDIF.
      APPEND VALUE #( belnr = <fs_h>-belnr ref = lv_ref
                      budat = <fs_h>-budat ) TO lt_pair.
      APPEND VALUE #( sign = 'I' option = 'EQ' low = lv_ref ) TO lr_ref.
    ENDLOOP.
    IF lr_ref IS INITIAL.
      RETURN.
    ENDIF.
    SORT lr_ref BY low.
    DELETE ADJACENT DUPLICATES FROM lr_ref COMPARING low.

    SELECT awref_rev, budat
      FROM bkpf
      WHERE bukrs      = @is_selection-bukrs
        AND gjahr      = @is_selection-gjahr
        AND awref_rev IN @lr_ref
      INTO TABLE @DATA(lt_rev).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    SORT lt_rev BY awref_rev budat.

    " Co chung tu dao khop ca AWREF_REV lan BUDAT thi loai chung tu goc.
    " Ban than chung tu dao khong nam trong CT_HDR vi cau SELECT o tren
    " da chan XREVERSING.
    LOOP AT lt_pair ASSIGNING FIELD-SYMBOL(<fs_p>).
      READ TABLE lt_rev TRANSPORTING NO FIELDS
           WITH KEY awref_rev = <fs_p>-ref budat = <fs_p>-budat
           BINARY SEARCH.
      IF sy-subrc = 0.
        DELETE ct_hdr WHERE belnr = <fs_p>-belnr.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD is_item_account.

    r_result = xsdbool(
      in_map_list( i_map_type = zif_hddt_types=>gc_map_type-gl_acct
                   i_value    = i_hkont ) = abap_true
      AND is_tax_account( i_bukrs = i_bukrs i_hkont = i_hkont ) = abap_false ).

  ENDMETHOD.


  METHOD is_tax_account.

    r_result = in_map_list( i_map_type = zif_hddt_types=>gc_map_type-tax_acct
                            i_value    = i_hkont
                            i_default  = abap_false ).

  ENDMETHOD.


  METHOD taxes_from_bset.

    FIELD-SYMBOLS <fs_tax> TYPE zif_hddt_types=>ty_tax.
*   >>> Begin of change 20260930_01 F-CUONGUS TR DS4K900172 - Kiem chung DS4: so tien theo TCURX, ty gia theo TCURF
    " FWBAS / FWSTE theo đồng tiền chứng từ, HWBAS / HWSTE theo đồng tiền
    " công ty - quy đổi số lẻ riêng từng loại
    DATA(lv_local) = local_currency( i_bukrs ).
*   <<< End of change 20260930_01

    LOOP AT it_bset ASSIGNING FIELD-SYMBOL(<fs_bset>).
      IF <fs_bset>-fwbas IS INITIAL AND <fs_bset>-hwbas IS INITIAL
         AND <fs_bset>-fwste IS INITIAL AND <fs_bset>-hwste IS INITIAL.
        CONTINUE.
      ENDIF.

      DATA(lv_rate) = tax_rate_of( i_bukrs = i_bukrs
                                   i_mwskz = <fs_bset>-mwskz
                                   it_rate  = it_rate ).
      " Thuế đầu ra ghi Có (H) = dương; ghi Nợ (S) = âm — như dự án tham chiếu
      DATA(lv_sign) = COND i( WHEN <fs_bset>-shkzg = 'S' THEN -1 ELSE 1 ).

      READ TABLE rt_taxes ASSIGNING <fs_tax> WITH KEY tax_rate = lv_rate.
      IF sy-subrc <> 0.
        APPEND INITIAL LINE TO rt_taxes ASSIGNING <fs_tax>.
        <fs_tax>-tax_rate     = lv_rate.
        <fs_tax>-tax_rate_txt = rate_text( lv_rate ).
        <fs_tax>-is_increase  = abap_true.
      ENDIF.
*   >>> Begin of change 20260930_01 F-CUONGUS TR DS4K900172 - Kiem chung DS4: so tien theo TCURX, ty gia theo TCURF
*      <fs_tax>-taxable_amt   = <fs_tax>-taxable_amt   + <fs_bset>-fwbas * lv_sign.
*      <fs_tax>-taxable_amt_l = <fs_tax>-taxable_amt_l + <fs_bset>-hwbas * lv_sign.
*      <fs_tax>-tax_amt       = <fs_tax>-tax_amt       + <fs_bset>-fwste * lv_sign.
*      <fs_tax>-tax_amt_l     = <fs_tax>-tax_amt_l     + <fs_bset>-hwste * lv_sign.
      <fs_tax>-taxable_amt   = <fs_tax>-taxable_amt
        + amount_of( i_amount = CONV #( <fs_bset>-fwbas ) i_waers = i_waers ) * lv_sign.
      <fs_tax>-taxable_amt_l = <fs_tax>-taxable_amt_l
        + amount_of( i_amount = CONV #( <fs_bset>-hwbas ) i_waers = lv_local ) * lv_sign.
      <fs_tax>-tax_amt       = <fs_tax>-tax_amt
        + amount_of( i_amount = CONV #( <fs_bset>-fwste ) i_waers = i_waers ) * lv_sign.
      <fs_tax>-tax_amt_l     = <fs_tax>-tax_amt_l
        + amount_of( i_amount = CONV #( <fs_bset>-hwste ) i_waers = lv_local ) * lv_sign.
*   <<< End of change 20260930_01
    ENDLOOP.

  ENDMETHOD.


  METHOD taxes_from_taxacct.

    FIELD-SYMBOLS <fs_tax> TYPE zif_hddt_types=>ty_tax.
*   >>> Begin of change 20260930_01 F-CUONGUS TR DS4K900172 - Kiem chung DS4: so tien theo TCURX, ty gia theo TCURF
    " WRBTR theo đồng tiền chứng từ, DMBTR theo đồng tiền công ty
    DATA(lv_local) = local_currency( i_bukrs ).
*   <<< End of change 20260930_01

    LOOP AT it_bseg ASSIGNING FIELD-SYMBOL(<fs_line>)
         WHERE koart = 'S' AND mwskz <> space.
      IF is_tax_account( i_bukrs = i_bukrs i_hkont = <fs_line>-hkont ) = abap_false.
        CONTINUE.
      ENDIF.
      DATA(lv_rate) = tax_rate_of( i_bukrs = i_bukrs
                                   i_mwskz = <fs_line>-mwskz
                                   it_rate = it_rate ).
      DATA(lv_sign) = COND i( WHEN <fs_line>-shkzg = 'H' THEN 1 ELSE -1 ).

      READ TABLE rt_taxes ASSIGNING <fs_tax> WITH KEY tax_rate = lv_rate.
      IF sy-subrc <> 0.
        APPEND INITIAL LINE TO rt_taxes ASSIGNING <fs_tax>.
        <fs_tax>-tax_rate     = lv_rate.
        <fs_tax>-tax_rate_txt = rate_text( lv_rate ).
        <fs_tax>-is_increase  = abap_true.
      ENDIF.
*   >>> Begin of change 20260930_01 F-CUONGUS TR DS4K900172 - Kiem chung DS4: so tien theo TCURX, ty gia theo TCURF
*      <fs_tax>-tax_amt   = <fs_tax>-tax_amt   + <fs_line>-wrbtr * lv_sign.
*      <fs_tax>-tax_amt_l = <fs_tax>-tax_amt_l + <fs_line>-dmbtr * lv_sign.
      <fs_tax>-tax_amt   = <fs_tax>-tax_amt
        + amount_of( i_amount = CONV #( <fs_line>-wrbtr ) i_waers = i_waers ) * lv_sign.
      <fs_tax>-tax_amt_l = <fs_tax>-tax_amt_l
        + amount_of( i_amount = CONV #( <fs_line>-dmbtr ) i_waers = lv_local ) * lv_sign.
*   <<< End of change 20260930_01
    ENDLOOP.

    " Tiền chưa thuế của từng thuế suất suy từ tiền thuế / thuế suất
    LOOP AT rt_taxes ASSIGNING <fs_tax> WHERE tax_rate > 0.
      <fs_tax>-taxable_amt   = <fs_tax>-tax_amt   * 100 / <fs_tax>-tax_rate.
      <fs_tax>-taxable_amt_l = <fs_tax>-tax_amt_l * 100 / <fs_tax>-tax_rate.
    ENDLOOP.

  ENDMETHOD.


  METHOD zif_hddt_source~get_doc_state.

    DATA lv_belnr TYPE belnr_d.
    lv_belnr = i_docno.

    SELECT SINGLE xreversed, stblg, stjah, waers
      FROM bkpf
      WHERE bukrs = @i_bukrs
        AND belnr = @lv_belnr
        AND gjahr = @i_gjahr
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
      WHERE bukrs = @i_bukrs
        AND belnr = @lv_belnr
        AND gjahr = @i_gjahr
        AND koart = 'D'
      ORDER BY buzei
      INTO TABLE @DATA(lt_kunnr)
      UP TO 1 ROWS.
    IF sy-subrc = 0.
      rs_state-kunnr = lt_kunnr[ 1 ]-kunnr.
    ENDIF.

  ENDMETHOD.


  METHOD zif_hddt_source~select_documents.

    IF is_selection-bukrs IS INITIAL.
      zcx_hddt_error=>raise_text( `Thiếu mã công ty (BUKRS) khi đọc chứng từ FI.` ).
    ENDIF.

    load_registry( i_bukrs    = is_selection-bukrs
                   i_gjahr    = is_selection-gjahr
                   i_src_type = gc_src_type ).

*---- Loại chứng từ: range màn hình, trống -> MAP DOCTYPE -------------*
    DATA lr_blart TYPE zif_hddt_types=>ty_r_blart.
    lr_blart = is_selection-r_blart.
    IF lr_blart IS INITIAL.
      LOOP AT map_list_as_range( zif_hddt_types=>gc_map_type-doc_type )
           ASSIGNING FIELD-SYMBOL(<fs_r>).
        APPEND VALUE #( sign = <fs_r>-sign option = <fs_r>-option
                        low  = <fs_r>-low(2) ) TO lr_blart.
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
           s~zlsch, s~bvtyp, s~rebzg, s~rebzj, k~awref_rev
      FROM bkpf AS k
      INNER JOIN bseg AS s ON s~bukrs = k~bukrs
                          AND s~belnr = k~belnr
                          AND s~gjahr = k~gjahr
      WHERE k~bukrs       = @is_selection-bukrs
        AND k~gjahr       = @is_selection-gjahr
        AND k~belnr      IN @is_selection-r_docno
        AND k~budat      IN @is_selection-r_budat
        AND k~bldat      IN @is_selection-r_bldat
        AND k~cpudt      IN @is_selection-r_cpudt
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

    drop_reversed_pairs( EXPORTING is_selection = is_selection
                         CHANGING  ct_hdr       = lt_hdr ).
    IF lt_hdr IS INITIAL.
      RETURN.
    ENDIF.

*---- 2. Lọc theo mã thuế đầu ra, chứng từ đã đảo, trạng thái ---------*
    LOOP AT lt_hdr ASSIGNING FIELD-SYMBOL(<fs_hdr>).
      IF in_map_list( i_map_type = zif_hddt_types=>gc_map_type-tax_code
                      i_value    = <fs_hdr>-cust_mwskz ) = abap_false.
        DELETE lt_hdr.
        CONTINUE.
      ENDIF.
      DATA(ls_reg) = registry_of( i_bukrs    = <fs_hdr>-bukrs
                                  i_gjahr    = <fs_hdr>-gjahr
                                  i_src_type = gc_src_type
                                  i_docno    = CONV #( <fs_hdr>-belnr ) ).
      IF keep_document( i_reversed  = xsdbool( <fs_hdr>-xreversed = 'X' )
                        is_reg       = ls_reg
                        is_selection = is_selection ) = abap_false.
        DELETE lt_hdr.
        CONTINUE.
      ENDIF.
      " FS MAG: lọc theo số hoá đơn đã cấp / số chứng từ gom
      IF is_selection-r_seq IS NOT INITIAL AND ls_reg-seq NOT IN is_selection-r_seq.
        DELETE lt_hdr.
        CONTINUE.
      ENDIF.
      IF is_selection-r_gom IS NOT INITIAL AND ls_reg-gom_no NOT IN is_selection-r_gom.
        DELETE lt_hdr.
      ENDIF.
    ENDLOOP.
    IF lt_hdr IS INITIAL.
      RETURN.
    ENDIF.

*---- 3. Dòng chứng từ, bảng thuế, dữ liệu billing tham chiếu --------*
    DATA lt_belnr TYPE RANGE OF belnr_d.
    DATA lt_vbeln TYPE RANGE OF vbeln_vf.
    LOOP AT lt_hdr ASSIGNING <fs_hdr>.
      APPEND VALUE #( sign = 'I' option = 'EQ' low = <fs_hdr>-belnr ) TO lt_belnr.
      IF <fs_hdr>-awtyp = 'VBRK' AND <fs_hdr>-awkey IS NOT INITIAL.
        APPEND VALUE #( sign = 'I' option = 'EQ' low = <fs_hdr>-awkey(10) ) TO lt_vbeln.
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

*   >>> Begin of change 20260927_01 F-DUBV TR S25K900131 - Review S25 (SELECT trong vong lap)
*   Nap 1 lan truoc vong lap: header STXH cho ten hang (ITEM_NAME) va dieu
*   kien thue A003/KONP (TAX_RATE_OF) - thay SELECT theo tung dong hang.
    prefetch_item_texts( i_bukrs = is_selection-bukrs
                         it_keys = VALUE #( FOR ls_tk IN lt_vbrp
                                            ( vbeln = ls_tk-aubel
                                              posnr = ls_tk-aupos
                                              matnr = ls_tk-matnr ) ) ).
    prefetch_tax_cond( is_selection-bukrs ).
*   <<< End of change 20260927_01

*   >>> Begin of change 20260927_20 F-DUBV TR S25K900131 - Review S25 R06 (DB trong vong lap)
*   Nap 1 lan truoc vong lap: nguoi ban T001/ADRC/ADR6 (READ_SELLER), ten vat
*   tu MAKT (MATERIAL_TEXT), khach le BSEC/BNKA va VBKD-BSTKD (READ_BUYER).
*   Cac method do chi doc bo dem - khong con SELECT trong vong lap buoc 4.
    prefetch_seller( is_selection-bukrs ).
    DATA lt_pf_matnr TYPE ty_t_matnr.
    lt_pf_matnr = VALUE #( FOR ls_pm IN lt_bseg ( ls_pm-matnr ) ).
    lt_pf_matnr = VALUE #( BASE lt_pf_matnr FOR ls_pv IN lt_vbrp ( ls_pv-matnr ) ).
    prefetch_mat_texts( lt_pf_matnr ).
    prefetch_buyer_docs( it_doc   = VALUE #( FOR ls_ph IN lt_hdr
                                             ( bukrs = ls_ph-bukrs
                                               belnr = ls_ph-belnr
                                               gjahr = ls_ph-gjahr ) )
                         it_aubel = VALUE #( FOR ls_pa IN lt_vbrp ( ls_pa-aubel ) ) ).
*   <<< End of change 20260927_20

*   >>> Begin of change 20260928_30 F-DUBV TR S25K900131 - Review S25 R06 (DB trong vong lap)
*   Nap 1 lan truoc vong lap du lieu BP / KNA1 (CVI_CUST_LINK, BUT000, BUT020,
*   ADRC, ADR6, ADR2, BUT0ID, BUT0BK, BNKA, KNA1) cua moi khach hang tren
*   chung tu: BUYER_FROM_BP / BUYER_FROM_KNA1 (qua READ_BUYER) chi doc bo dem.
    prefetch_buyer_master( VALUE #( FOR ls_pb IN lt_hdr
                                    ( kunnr = ls_pb-kunnr
                                      bvtyp = ls_pb-bvtyp ) ) ).
*   <<< End of change 20260928_30

*---- 4. Dựng request từng chứng từ -----------------------------------*
    LOOP AT lt_hdr ASSIGNING <fs_hdr>.
      DATA(lt_doc_bseg) = VALUE ty_t_bseg( FOR ls IN lt_bseg
                                           WHERE ( belnr = <fs_hdr>-belnr ) ( ls ) ).
      DATA(lt_doc_bset) = VALUE ty_t_bset( FOR lt IN lt_bset
                                           WHERE ( belnr = <fs_hdr>-belnr ) ( lt ) ).

      DATA(ls_req) = build_one( is_hdr      = <fs_hdr>
                                it_bseg     = lt_doc_bseg
                                it_bset     = lt_doc_bset
                                it_vbrp     = lt_vbrp
                                it_link     = lt_link
                                it_vbrk_pay = lt_vbrk_pay ).
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
ENDCLASS.
