*=====================================================================
* Tên/Mã     : ZCL_HDDT_SRC_PO
* Mô tả chung: Nguồn Nhóm 2 theo FS v0.17 mục 3.3 - hoá đơn ĐẦU VÀO
*              trường hợp TRẢ LẠI HÀNG NHÀ CUNG CẤP. Bán trả lại hàng cho
*              nhà cung cấp thì doanh nghiệp phải xuất hoá đơn cho nhà
*              cung cấp, nên nghiệp vụ này cũng phát hành HĐĐT.
*
*              Điều kiện lấy chứng từ (cấu hình ZTB_HDDT_PO theo công ty,
*              không hard-code - giá trị khởi tạo MAG: ZPO6 / I* / 1331*):
*                - có dòng BSEG-MWSKZ khớp mẫu mã thuế đầu vào MWSKZ_PAT;
*                - bắt nguồn từ đơn hàng mua có EKKO-BSART khai trong bảng.
*                  Số đơn hàng lấy từ BSEG-EBELN; chứng từ hoá đơn mua
*                  hàng từ MIRO (BKPF-AWTYP = 'RMRP') lấy qua RSEG.
*
*              Khác Nhóm 1 khi dựng hoá đơn:
*                - người mua là NHÀ CUNG CẤP: dòng công nợ KOART = 'K',
*                  tên / MST / địa chỉ từ LFA1 (READ_VENDOR);
*                - tiền thuế từ dòng thuế GTGT ĐẦU VÀO (HKONT_TAX, 1331*);
*                - giá trị hàng từ các dòng vật tư / chi phí.
*              Dải số dùng CHUNG với hoá đơn bán hàng của cùng pháp nhân.
*
*              Kế thừa ZCL_HDDT_SRC_FI để dùng lại TOÀN BỘ phần dựng
*              request (dòng hàng, thuế, tiền tệ, ngày lập, điều chỉnh,
*              loại cặp chứng từ đảo); chỉ viết lại phần chọn chứng từ và
*              redefine ba điểm móc IS_ITEM_ACCOUNT / IS_TAX_ACCOUNT /
*              BUYER_OF.
*
*              Kích hoạt: một dòng ZTB_HDDT_SRC (BUKRS, SRC_TYPE = 'PO',
*              CLASSNAME = ZCL_HDDT_SRC_PO) và ít nhất một dòng ZTB_HDDT_PO.
*              Công ty chưa khai ZTB_HDDT_PO thì nguồn này trả rỗng, không
*              báo lỗi - nhiều pháp nhân không có nghiệp vụ trả hàng.
* Tham Số    : SELECT_DOCUMENTS( is_selection ) -> ty_t_request
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       23/09/2026    cuongus - CuongUS        S25K900131  Tạo mới
*                         theo FS v0.17 mục 3.3 Nhóm 2
* 1.1       27/09/2026    F-DUBV                   S25K900131  R06: goi
*                         PREFETCH_SELLER / PREFETCH_MAT_TEXTS /
*                         PREFETCH_BUYER_DOCS truoc vong lap buoc 4; bo
*                         sung PREFETCH_TAX_COND (review S25 27/09)
* 1.2       29/09/2026    F-DUBV - DuBV            DS4K900150  20260929_01
*                         Review: LOOP long buoc 3 (LT_FI_PO, LT_RSEG,
*                         LT_BSEG) doc nhi phan
*=====================================================================
CLASS zcl_hddt_src_po DEFINITION
  PUBLIC
  INHERITING FROM zcl_hddt_src_fi
  CREATE PUBLIC .

  PUBLIC SECTION.

    "! Loại nguồn trên sổ đăng ký. Tên khác GC_SRC_TYPE của lớp cha vì
    "! lớp con không được khai lại thành phần trùng tên.
    CONSTANTS gc_src_po TYPE zde_hddt_srctype VALUE 'PO' ##NO_TEXT.

    METHODS zif_hddt_source~select_documents REDEFINITION .

  PROTECTED SECTION.

    METHODS is_item_account REDEFINITION .
    METHODS is_tax_account  REDEFINITION .
    METHODS buyer_of        REDEFINITION .

  PRIVATE SECTION.

    TYPES: BEGIN OF ty_po_cfg,
             bsart     TYPE ztb_hddt_po-bsart,
             mwskz_pat TYPE ztb_hddt_po-mwskz_pat,
             hkont_tax TYPE ztb_hddt_po-hkont_tax,
           END OF ty_po_cfg.
    TYPES ty_t_po_cfg TYPE STANDARD TABLE OF ty_po_cfg WITH EMPTY KEY.

    "! Cấu hình ZTB_HDDT_PO của công ty đang đọc
    DATA mt_po TYPE ty_t_po_cfg .

    "! Chứng từ có đúng nghiệp vụ trả lại hàng NCC không: tồn tại MỘT dòng
    "! cấu hình mà loại đơn hàng khớp VÀ chứng từ có dòng mã thuế khớp mẫu
    "! của chính dòng cấu hình đó.
    METHODS matches_config
      IMPORTING it_bseg          TYPE ty_t_bseg
                it_bsart         TYPE string_table
      RETURNING VALUE(r_matches) TYPE abap_bool .

ENDCLASS.



CLASS ZCL_HDDT_SRC_PO IMPLEMENTATION.


  METHOD buyer_of.

    rs_buyer = read_vendor( i_lifnr = is_hdr-kunnr
                            i_bukrs = is_hdr-bukrs
                            i_belnr = is_hdr-belnr
                            i_gjahr = is_hdr-gjahr ).

  ENDMETHOD.


  METHOD is_item_account.

    " Dòng vật tư / chi phí của chứng từ trả hàng: mọi dòng sổ cái không
    " phải dòng thuế GTGT đầu vào. Không dùng MAP GLACCT vì đó là danh
    " sách tài khoản DOANH THU của hoá đơn bán hàng.
    r_result = xsdbool( is_tax_account( i_bukrs = i_bukrs i_hkont = i_hkont ) = abap_false ).

  ENDMETHOD.


  METHOD is_tax_account.

    " Thuế GTGT ĐẦU VÀO theo cấu hình (1331*) thay cho MAP TAXACCT (3331*)
    DATA lv_hkont TYPE c LENGTH 20.
    lv_hkont = condense( CONV string( i_hkont ) ).
    LOOP AT mt_po ASSIGNING FIELD-SYMBOL(<fs_cfg>) WHERE hkont_tax IS NOT INITIAL.
      DATA(lv_pat) = condense( CONV string( <fs_cfg>-hkont_tax ) ).
      IF lv_hkont CP lv_pat.
        r_result = abap_true.
        RETURN.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD matches_config.

    LOOP AT mt_po ASSIGNING FIELD-SYMBOL(<fs_cfg>).
      IF NOT line_exists( it_bsart[ table_line = CONV string( <fs_cfg>-bsart ) ] ).
        CONTINUE.
      ENDIF.
      DATA(lv_pat) = condense( CONV string( <fs_cfg>-mwskz_pat ) ).
      LOOP AT it_bseg ASSIGNING FIELD-SYMBOL(<fs_l>) WHERE mwskz IS NOT INITIAL.
        IF <fs_l>-mwskz CP lv_pat.
          r_matches = abap_true.
          RETURN.
        ENDIF.
      ENDLOOP.
    ENDLOOP.

  ENDMETHOD.


  METHOD zif_hddt_source~select_documents.

    IF is_selection-bukrs IS INITIAL.
      zcx_hddt_error=>raise_text( `Thiếu mã công ty (BUKRS) khi đọc chứng từ trả lại hàng NCC.` ).
    ENDIF.

    " Dòng BUKRS trống dùng chung cho mọi pháp nhân (cùng quy ước với
    " ZTB_HDDT_SRC); dòng có BUKRS bổ sung thêm cho riêng pháp nhân đó.
    SELECT bsart, mwskz_pat, hkont_tax
      FROM ztb_hddt_po
      WHERE ( bukrs = @is_selection-bukrs OR bukrs = @space )
        AND xactive = @abap_true
      INTO TABLE @mt_po.
    IF mt_po IS INITIAL.
      RETURN.
    ENDIF.

    load_registry( i_bukrs    = is_selection-bukrs
                   i_gjahr    = is_selection-gjahr
                   i_src_type = gc_src_po ).

*---- 1. Header + dòng công nợ NHÀ CUNG CẤP ----------------------------*
    " Mã NCC đặt vào trường KUNNR của TY_HDR: cùng dạng CHAR 10, nhờ vậy
    " dùng lại được BUILD_ONE của lớp cha; BUYER_OF redefine đọc LFA1.
    DATA lt_hdr TYPE ty_t_hdr.
    SELECT k~bukrs, k~belnr, k~gjahr, k~blart, k~budat, k~bldat, k~cpudt,
           k~usnam, k~xblnr, k~bktxt, k~waers, k~kursf, k~awtyp, k~awkey,
           k~xreversed, k~xreversing, k~stblg, k~stjah,
           s~buzei AS cust_buzei, s~lifnr AS kunnr, s~mwskz AS cust_mwskz,
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
        AND k~blart      IN @is_selection-r_blart
        AND k~usnam      IN @is_selection-r_usnam
        AND k~xreversing  = @space
        AND s~koart       = 'K'
        AND s~lifnr      IN @is_selection-r_kunnr
      INTO TABLE @lt_hdr.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    " BELNR có ở cả BKPF lẫn BSEG nên không ORDER BY trong câu SELECT
    SORT lt_hdr BY belnr cust_buzei.
    DELETE ADJACENT DUPLICATES FROM lt_hdr COMPARING belnr.

    drop_reversed_pairs( EXPORTING is_selection = is_selection
                         CHANGING  ct_hdr       = lt_hdr ).
    IF lt_hdr IS INITIAL.
      RETURN.
    ENDIF.

*---- 2. Dòng chứng từ + nguồn gốc đơn hàng mua ---------------------*
    DATA lt_belnr  TYPE RANGE OF belnr_d.
    DATA lt_rbelnr TYPE RANGE OF re_belnr.
    LOOP AT lt_hdr ASSIGNING FIELD-SYMBOL(<fs_hdr>).
      APPEND VALUE #( sign = 'I' option = 'EQ' low = <fs_hdr>-belnr ) TO lt_belnr.
      " Hoá đơn mua hàng từ MIRO: AWKEY = số RBKP (10) + năm (4)
      IF <fs_hdr>-awtyp = 'RMRP' AND strlen( <fs_hdr>-awkey ) >= 10.
        APPEND VALUE #( sign = 'I' option = 'EQ' low = <fs_hdr>-awkey(10) ) TO lt_rbelnr.
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

    " Số đơn hàng mua trên dòng kế toán
    SELECT belnr, ebeln
      FROM bseg
      WHERE bukrs  = @is_selection-bukrs
        AND gjahr  = @is_selection-gjahr
        AND belnr IN @lt_belnr
        AND ebeln <> @space
      INTO TABLE @DATA(lt_fi_po).

    " Số đơn hàng mua của hoá đơn MIRO, đọc qua RSEG
    TYPES: BEGIN OF lty_rseg,
             belnr TYPE rseg-belnr,
             gjahr TYPE rseg-gjahr,
             ebeln TYPE rseg-ebeln,
           END OF lty_rseg.
    DATA lt_rseg TYPE STANDARD TABLE OF lty_rseg WITH EMPTY KEY.
    IF lt_rbelnr IS NOT INITIAL.
      SELECT belnr, gjahr, ebeln
        FROM rseg
        WHERE belnr IN @lt_rbelnr
          AND ebeln <> @space
        INTO TABLE @lt_rseg.
    ENDIF.

    " Loại đơn hàng của mọi đơn hàng vừa gặp - một câu cho cả danh sách
    DATA lt_ebeln TYPE RANGE OF ebeln.
    lt_ebeln = VALUE #( FOR <p> IN lt_fi_po ( sign = 'I' option = 'EQ' low = <p>-ebeln ) ).
    LOOP AT lt_rseg ASSIGNING FIELD-SYMBOL(<fs_rs>).
      APPEND VALUE #( sign = 'I' option = 'EQ' low = <fs_rs>-ebeln ) TO lt_ebeln.
    ENDLOOP.
    IF lt_ebeln IS INITIAL.
      RETURN.
    ENDIF.
    SORT lt_ebeln BY low.
    DELETE ADJACENT DUPLICATES FROM lt_ebeln COMPARING low.
    SELECT ebeln, bsart
      FROM ekko
      WHERE ebeln IN @lt_ebeln
      INTO TABLE @DATA(lt_ekko).
    SORT lt_ekko BY ebeln.

" FIS begin: 20260929_01 [DS4K900150]
*   SORT theo khoa doc cua vong buoc 3 de doc nhi phan (READ ... BINARY
*   SEARCH + LOOP FROM) thay vi LOOP ... WHERE quet ca bang moi chung tu.
*   LT_BSEG da ORDER BY belnr, buzei tu CSDL.
    SORT lt_fi_po BY belnr.
    SORT lt_rseg BY belnr gjahr.
    DATA lt_doc_bseg TYPE ty_t_bseg.
" FIS end: 20260929_01

*---- 3. Lọc theo cấu hình + sổ đăng ký ------------------------------*
    LOOP AT lt_hdr ASSIGNING <fs_hdr>.

      " Loại đơn hàng mua của chứng từ này
      DATA lt_bsart TYPE string_table.
      CLEAR lt_bsart.
" FIS begin: 20260929_01 [DS4K900150]
      READ TABLE lt_fi_po TRANSPORTING NO FIELDS
           WITH KEY belnr = <fs_hdr>-belnr BINARY SEARCH.
      IF sy-subrc = 0.
        LOOP AT lt_fi_po ASSIGNING FIELD-SYMBOL(<fs_fp>) FROM sy-tabix.
          IF <fs_fp>-belnr <> <fs_hdr>-belnr.
            EXIT.
          ENDIF.
          READ TABLE lt_ekko INTO DATA(ls_ekko) WITH KEY ebeln = <fs_fp>-ebeln BINARY SEARCH.
          IF sy-subrc = 0.
            APPEND CONV string( ls_ekko-bsart ) TO lt_bsart.
          ENDIF.
        ENDLOOP.
      ENDIF.
" FIS end: 20260929_01
      IF <fs_hdr>-awtyp = 'RMRP' AND strlen( <fs_hdr>-awkey ) >= 14.
        DATA lv_rbelnr TYPE re_belnr.
        lv_rbelnr = <fs_hdr>-awkey(10).
        DATA(lv_rgjahr) = CONV gjahr( <fs_hdr>-awkey+10(4) ).
" FIS begin: 20260929_01 [DS4K900150]
        READ TABLE lt_rseg TRANSPORTING NO FIELDS
             WITH KEY belnr = lv_rbelnr gjahr = lv_rgjahr BINARY SEARCH.
        IF sy-subrc = 0.
          LOOP AT lt_rseg ASSIGNING <fs_rs> FROM sy-tabix.
            IF <fs_rs>-belnr <> lv_rbelnr OR <fs_rs>-gjahr <> lv_rgjahr.
              EXIT.
            ENDIF.
            READ TABLE lt_ekko INTO ls_ekko WITH KEY ebeln = <fs_rs>-ebeln BINARY SEARCH.
            IF sy-subrc = 0.
              APPEND CONV string( ls_ekko-bsart ) TO lt_bsart.
            ENDIF.
          ENDLOOP.
        ENDIF.
" FIS end: 20260929_01
      ENDIF.

" FIS begin: 20260929_01 [DS4K900150]
*      DATA(lt_doc_bseg) = VALUE ty_t_bseg( FOR ls IN lt_bseg
*                                           WHERE ( belnr = <fs_hdr>-belnr ) ( ls ) ).
      CLEAR lt_doc_bseg.
      READ TABLE lt_bseg TRANSPORTING NO FIELDS
           WITH KEY belnr = <fs_hdr>-belnr BINARY SEARCH.
      IF sy-subrc = 0.
        LOOP AT lt_bseg ASSIGNING FIELD-SYMBOL(<fs_bs>) FROM sy-tabix.
          IF <fs_bs>-belnr <> <fs_hdr>-belnr.
            EXIT.
          ENDIF.
          APPEND <fs_bs> TO lt_doc_bseg.
        ENDLOOP.
      ENDIF.
" FIS end: 20260929_01
      IF matches_config( it_bseg = lt_doc_bseg it_bsart = lt_bsart ) = abap_false.
        DELETE lt_hdr.
        CONTINUE.
      ENDIF.

      DATA(ls_reg) = registry_of( i_bukrs    = <fs_hdr>-bukrs
                                  i_gjahr    = <fs_hdr>-gjahr
                                  i_src_type = gc_src_po
                                  i_docno    = CONV #( <fs_hdr>-belnr ) ).
      IF keep_document( i_reversed  = xsdbool( <fs_hdr>-xreversed = 'X' )
                        is_reg       = ls_reg
                        is_selection = is_selection ) = abap_false.
        DELETE lt_hdr.
        CONTINUE.
      ENDIF.
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

*---- 4. Bảng thuế + dựng request -----------------------------------*
    CLEAR lt_belnr.
    lt_belnr = VALUE #( FOR <h> IN lt_hdr ( sign = 'I' option = 'EQ' low = <h>-belnr ) ).
    DATA lt_bset TYPE ty_t_bset.
    SELECT bukrs, belnr, gjahr, mwskz, shkzg, kbetr, hwbas, hwste, fwbas, fwste
      FROM bset
      WHERE bukrs  = @is_selection-bukrs
        AND gjahr  = @is_selection-gjahr
        AND belnr IN @lt_belnr
      INTO TABLE @lt_bset.

    " Nhóm 2 không phát sinh từ Billing: ba bảng SD để trống
    DATA lt_vbrp     TYPE ty_t_vbrp.
    DATA lt_link     TYPE ty_t_link.
    DATA lt_vbrk_pay TYPE ty_t_vbrk_pay.

*   >>> Begin of change 20260927_20 F-DUBV TR S25K900131 - Review S25 R06 (DB trong vong lap)
*   Nap 1 lan truoc vong lap: nguoi ban T001/ADRC/ADR6 (READ_SELLER), ten vat
*   tu MAKT (MATERIAL_TEXT), NCC vang lai BSEC/BNKA (READ_VENDOR -> READ_BUYER).
*   Cac method do chi doc bo dem - khong con SELECT trong vong lap buoc 4.
    prefetch_seller( is_selection-bukrs ).
    prefetch_mat_texts( VALUE #( FOR ls_pm IN lt_bseg ( ls_pm-matnr ) ) ).
    prefetch_buyer_docs( it_doc = VALUE #( FOR ls_ph IN lt_hdr
                                           ( bukrs = ls_ph-bukrs
                                             belnr = ls_ph-belnr
                                             gjahr = ls_ph-gjahr ) ) ).
*   <<< End of change 20260927_20
*   >>> Begin of change 20260927_20 F-DUBV TR S25K900131 - Review S25 bug PO thieu PREFETCH_TAX_COND
*   Tu change 20260927_01 TAX_RATE_OF buoc 3 (A003/KONP) chi doc bo dem do
*   PREFETCH_TAX_COND nap; FI / SD da goi, PO (BUILD_ONE ke thua FI) chua goi
*   nen ma thue khong co trong BSET cua chung tu tra ve thue suat 0.
    prefetch_tax_cond( is_selection-bukrs ).
*   <<< End of change 20260927_20

" FIS begin: 20260929_01 [DS4K900150]
*   Buoc 4: tach dong BSEG / BSET cua tung chung tu bang BINARY SEARCH +
*   LOOP FROM (LT_BSEG da ORDER BY belnr; LT_BSET SORT STABLE theo belnr).
    SORT lt_bset STABLE BY belnr.
    DATA lt_one_bseg TYPE ty_t_bseg.
    DATA lt_one_bset TYPE ty_t_bset.
" FIS end: 20260929_01
    LOOP AT lt_hdr ASSIGNING <fs_hdr>.
" FIS begin: 20260929_01 [DS4K900150]
*      DATA(lt_one_bseg) = VALUE ty_t_bseg( FOR ls2 IN lt_bseg
*                                           WHERE ( belnr = <fs_hdr>-belnr ) ( ls2 ) ).
*      DATA(lt_one_bset) = VALUE ty_t_bset( FOR lt2 IN lt_bset
*                                           WHERE ( belnr = <fs_hdr>-belnr ) ( lt2 ) ).
      CLEAR: lt_one_bseg, lt_one_bset.
      READ TABLE lt_bseg TRANSPORTING NO FIELDS
           WITH KEY belnr = <fs_hdr>-belnr BINARY SEARCH.
      IF sy-subrc = 0.
        LOOP AT lt_bseg ASSIGNING <fs_bs> FROM sy-tabix.
          IF <fs_bs>-belnr <> <fs_hdr>-belnr.
            EXIT.
          ENDIF.
          APPEND <fs_bs> TO lt_one_bseg.
        ENDLOOP.
      ENDIF.
      READ TABLE lt_bset TRANSPORTING NO FIELDS
           WITH KEY belnr = <fs_hdr>-belnr BINARY SEARCH.
      IF sy-subrc = 0.
        LOOP AT lt_bset ASSIGNING FIELD-SYMBOL(<fs_bt>) FROM sy-tabix.
          IF <fs_bt>-belnr <> <fs_hdr>-belnr.
            EXIT.
          ENDIF.
          APPEND <fs_bt> TO lt_one_bset.
        ENDLOOP.
      ENDIF.
" FIS end: 20260929_01
      DATA(ls_req) = build_one( is_hdr      = <fs_hdr>
                                it_bseg     = lt_one_bseg
                                it_bset     = lt_one_bset
                                it_vbrp     = lt_vbrp
                                it_link     = lt_link
                                it_vbrk_pay = lt_vbrk_pay ).
      IF ls_req-src_docno IS INITIAL.
        CONTINUE.
      ENDIF.
      " BUILD_ONE của lớp cha đóng loại nguồn FI - đổi sang PO để sổ đăng
      " ký, gom và huỷ chứng từ nhận đúng nguồn
      ls_req-src_type = gc_src_po.
      IF ls_req-invoice-adjust-org_docno IS NOT INITIAL.
        ls_req-invoice-adjust-org_src_type = gc_src_po.
      ENDIF.
      ls_req-src_info-lifnr = <fs_hdr>-kunnr.
      ls_req-invoice-header-inv_type = is_selection-inv_type.
      apply_registry_edits(
        EXPORTING is_reg     = registry_of( i_bukrs    = ls_req-bukrs
                                            i_gjahr    = ls_req-gjahr
                                            i_src_type = gc_src_po
                                            i_docno    = ls_req-src_docno )
        CHANGING  cs_request = ls_req ).
      APPEND ls_req TO rt_request.
    ENDLOOP.

  ENDMETHOD.
ENDCLASS.
