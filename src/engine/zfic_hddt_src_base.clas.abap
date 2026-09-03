*=====================================================================
* Tên/Mã     : ZFIC_HDDT_SRC_BASE
* Mô tả chung: Lớp cha DÙNG CHUNG cho các lớp đọc dữ liệu nguồn
*              (FI, SD...). Chứa phần nghiệp vụ đã được kiểm chứng ở
*              dự án HĐĐT private cloud (ZPG_INT_E_INVOICE +
*              FUGR ZFG_E_INVOICES: ZFM_GET_BUYER / ZFM_GET_SELLER /
*              ZFM_GET_ITEMDOC) nhưng viết lại theo canonical model
*              và điều khiển bằng cấu hình thay cho hằng số:
*                - Người bán  : T001 -> ADRC/ADR6 (cache theo BUKRS)
*                - Người mua  : khách lẻ BSEC, hoặc BP qua CVI_CUST_LINK
*                               -> BUT000/BUT020/ADRC/BUT0ID/ADR6/ADR2/
*                               BUT0BK/BNKA; fallback KNA1 (cache KUNNR)
*                - Thuế suất  : MAP TAXRATE -> BSET-KBETR -> A003/KONP
*                - Tiền thuế  : tính theo % từng dòng rồi CHỐT theo
*                               bảng thuế (BSET) — chênh lệch làm tròn
*                               dồn vào dòng cuối cùng cùng thuế suất
*                - Tên hàng   : long text theo cấu hình ITEM_TEXT_IDS
*                               -> MAKT -> SGTXT/ARKTX
*              Lớp này thuộc TẦNG NỀN TẢNG CỔ ĐIỂN (đọc bảng SAP trực
*              tiếp, READ_TEXT). Bản Public Cloud khai báo lớp nguồn
*              riêng trong ZFIT_HDDT_SRC — engine không đổi.
* Tham Số    : Xem từng method
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       03/09/2026    cuongus - CuongUS        abapGit     Tạo mới
*=====================================================================
CLASS zfic_hddt_src_base DEFINITION
  PUBLIC
  ABSTRACT
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES zfiif_hddt_source
      ABSTRACT METHODS select_documents get_doc_state .

  PROTECTED SECTION.

    " Thuế suất theo mã thuế đọc từ bảng thuế của chứng từ
    TYPES: BEGIN OF ty_mwskz_rate,
             mwskz TYPE mwskz,
             kbetr TYPE kbetr,
           END OF ty_mwskz_rate.
    TYPES ty_t_mwskz_rate TYPE SORTED TABLE OF ty_mwskz_rate
                          WITH UNIQUE KEY mwskz.

    TYPES ty_t_reg TYPE SORTED TABLE OF zfit_hddt_inv
                   WITH UNIQUE KEY bukrs gjahr src_type src_docno.

    " Bản ghi sổ đăng ký của các chứng từ trong phạm vi chọn
    DATA mt_reg TYPE ty_t_reg .

    METHODS config
      RETURNING VALUE(ro_config) TYPE REF TO zfic_hddt_config .

    "! Tham số cấu hình có giá trị mặc định
    METHODS param
      IMPORTING iv_key          TYPE zfide_hddt_parmkey
                iv_bukrs        TYPE bukrs
                iv_default      TYPE string OPTIONAL
      RETURNING VALUE(rv_value) TYPE string .

    "! Đọc sổ đăng ký HĐĐT của công ty/năm/loại nguồn vào MT_REG
    METHODS load_registry
      IMPORTING iv_bukrs    TYPE bukrs
                iv_gjahr    TYPE gjahr
                iv_src_type TYPE zfide_hddt_srctype .

    METHODS registry_of
      IMPORTING iv_bukrs      TYPE bukrs
                iv_gjahr      TYPE gjahr
                iv_src_type   TYPE zfide_hddt_srctype
                iv_docno      TYPE zfide_hddt_docno
      RETURNING VALUE(rs_reg) TYPE zfit_hddt_inv .

    "! Chứng từ có được đưa vào danh sách không:
    "!   - đã đảo/huỷ: chỉ khi đã phát hành HĐĐT (để huỷ) hoặc người
    "!     dùng yêu cầu lấy cả chứng từ đã đảo
    "!   - lọc theo range trạng thái
    METHODS keep_document
      IMPORTING iv_reversed     TYPE abap_bool
                is_reg          TYPE zfit_hddt_inv
                is_selection    TYPE zfiif_hddt_source=>ty_selection
      RETURNING VALUE(rv_keep)  TYPE abap_bool .

*---- Người bán / người mua -------------------------------------------*
    METHODS read_seller
      IMPORTING iv_bukrs         TYPE bukrs
      RETURNING VALUE(rs_seller) TYPE zfiif_hddt_types=>ty_seller .

    "! Người mua. Truyền BELNR/GJAHR để nhận diện khách lẻ (BSEC);
    "! BVTYP để lấy ngân hàng; AUBEL để lấy số tham chiếu KH (VBKD).
    METHODS read_buyer
      IMPORTING iv_kunnr        TYPE kunnr
                iv_bukrs        TYPE bukrs
                iv_belnr        TYPE belnr_d OPTIONAL
                iv_gjahr        TYPE gjahr OPTIONAL
                iv_bvtyp        TYPE bvtyp OPTIONAL
                iv_aubel        TYPE vbeln OPTIONAL
      RETURNING VALUE(rs_buyer) TYPE zfiif_hddt_types=>ty_buyer .

    METHODS clean_address
      IMPORTING iv_land1       TYPE land1 OPTIONAL
                iv_bukrs       TYPE bukrs OPTIONAL
      CHANGING  cv_addr        TYPE string .

*---- Thuế ------------------------------------------------------------*
    "! Thuế suất theo mã thuế: MAP TAXRATE -> bảng thuế chứng từ
    "! (KBETR/10) -> điều kiện thuế A003/KONP (loại điều kiện TAX_COND_TYPE)
    METHODS tax_rate_of
      IMPORTING iv_bukrs       TYPE bukrs
                iv_mwskz       TYPE mwskz
                it_rate        TYPE ty_t_mwskz_rate OPTIONAL
      RETURNING VALUE(rv_rate) TYPE zfiif_hddt_types=>ty_rate .

    METHODS rate_text
      IMPORTING iv_rate        TYPE zfiif_hddt_types=>ty_rate
      RETURNING VALUE(rv_text) TYPE string .

    "! Tiền thuế một dòng — làm tròn theo tiền tệ (VND: 0 lẻ)
    METHODS line_tax
      IMPORTING iv_amount     TYPE zfiif_hddt_types=>ty_amount
                iv_rate       TYPE zfiif_hddt_types=>ty_rate
                iv_waers      TYPE waers
      RETURNING VALUE(rv_tax) TYPE zfiif_hddt_types=>ty_amount .

    "! Chốt tiền thuế từng dòng theo bảng thuế: chênh lệch làm tròn dồn
    "! vào DÒNG CUỐI cùng thuế suất (đúng như dự án tham chiếu).
    METHODS reconcile_tax
      IMPORTING it_tax   TYPE zfiif_hddt_types=>ty_t_tax
      CHANGING  ct_items TYPE zfiif_hddt_types=>ty_t_item .

    "! 'Nhiều loại' nếu hoá đơn có nhiều thuế suất, ngược lại nhãn
    METHODS rate_summary
      IMPORTING it_items       TYPE zfiif_hddt_types=>ty_t_item
      RETURNING VALUE(rv_text) TYPE string .

*---- Dòng hàng -------------------------------------------------------*
    METHODS unit_text
      IMPORTING iv_meins       TYPE meins
      RETURNING VALUE(rv_text) TYPE string .

    METHODS material_text
      IMPORTING iv_matnr       TYPE matnr
      RETURNING VALUE(rv_text) TYPE string .

    "! Tên hàng theo thứ tự ưu tiên cấu hình ITEM_TEXT_IDS
    "! (dạng 'ID:OBJECT;ID:OBJECT', xem docs/09) -> MAKT -> IV_DEFAULT
    METHODS item_name
      IMPORTING iv_bukrs       TYPE bukrs
                iv_vbeln       TYPE vbeln OPTIONAL
                iv_posnr       TYPE posnr OPTIONAL
                iv_matnr       TYPE matnr OPTIONAL
                iv_default     TYPE clike OPTIONAL
      RETURNING VALUE(rv_name) TYPE string .

    "! Đọc long text (STXH/READ_TEXT) — nền tảng cổ điển
    METHODS read_text
      IMPORTING iv_id          TYPE tdid
                iv_object      TYPE tdobject
                iv_name        TYPE tdobname
      RETURNING VALUE(rv_text) TYPE string .

*---- Header ----------------------------------------------------------*
    METHODS payment_of
      IMPORTING iv_zlsch          TYPE dzlsch
                iv_bukrs          TYPE bukrs
      RETURNING VALUE(rs_payment) TYPE zfiif_hddt_types=>ty_payment .

    METHODS exch_rate_of
      IMPORTING iv_bukrs       TYPE bukrs
                iv_waers       TYPE waers
                iv_kursf       TYPE kursf
      RETURNING VALUE(rv_rate) TYPE zfiif_hddt_types=>ty_amount .

    METHODS local_currency
      IMPORTING iv_bukrs        TYPE bukrs
      RETURNING VALUE(rv_waers) TYPE waers .

    "! Hoàn thiện request: số lượng dương, người bán, tổng hợp thuế suất,
    "! tính tổng (aggregate) — gọi cuối cùng ở mỗi lớp con.
    METHODS finalize_request
      CHANGING cs_request TYPE zfiif_hddt_types=>ty_request .

*---- Ánh xạ danh sách ------------------------------------------------*
    "! Giá trị có nằm trong danh sách MAP (hỗ trợ mẫu CP: O*, **)?
    "! Danh sách trống => RV_ALLOWED = IV_DEFAULT.
    METHODS in_map_list
      IMPORTING iv_map_type       TYPE zfide_hddt_maptype
                iv_value          TYPE clike
                iv_default        TYPE abap_bool DEFAULT abap_true
      RETURNING VALUE(rv_allowed) TYPE abap_bool .

    METHODS map_list_as_range
      IMPORTING iv_map_type     TYPE zfide_hddt_maptype
      RETURNING VALUE(rt_range) TYPE zfiif_hddt_types=>ty_r_docno .

  PRIVATE SECTION.

    TYPES: BEGIN OF ty_seller_cache,
             bukrs  TYPE bukrs,
             seller TYPE zfiif_hddt_types=>ty_seller,
           END OF ty_seller_cache.
    TYPES: BEGIN OF ty_buyer_cache,
             kunnr TYPE kunnr,
             buyer TYPE zfiif_hddt_types=>ty_buyer,
           END OF ty_buyer_cache.
    TYPES: BEGIN OF ty_text_cache,
             key  TYPE c LENGTH 40,
             text TYPE string,
           END OF ty_text_cache.

    DATA mo_config   TYPE REF TO zfic_hddt_config .
    DATA mt_seller   TYPE SORTED TABLE OF ty_seller_cache WITH UNIQUE KEY bukrs .
    DATA mt_buyer    TYPE SORTED TABLE OF ty_buyer_cache  WITH UNIQUE KEY kunnr .
    DATA mt_unit     TYPE SORTED TABLE OF ty_text_cache   WITH UNIQUE KEY key .
    DATA mt_matnr    TYPE SORTED TABLE OF ty_text_cache   WITH UNIQUE KEY key .

    METHODS text_langu
      IMPORTING iv_bukrs        TYPE bukrs OPTIONAL
      RETURNING VALUE(rv_langu) TYPE spras .

    METHODS buyer_from_bp
      IMPORTING iv_kunnr TYPE kunnr
                iv_bukrs TYPE bukrs
                iv_bvtyp TYPE bvtyp
      CHANGING  cs_buyer TYPE zfiif_hddt_types=>ty_buyer
      RETURNING VALUE(rv_found) TYPE abap_bool .

    METHODS buyer_from_kna1
      IMPORTING iv_kunnr TYPE kunnr
                iv_bukrs TYPE bukrs
      CHANGING  cs_buyer TYPE zfiif_hddt_types=>ty_buyer .

ENDCLASS.



CLASS zfic_hddt_src_base IMPLEMENTATION.

  METHOD config.

    IF mo_config IS NOT BOUND.
      mo_config = zfic_hddt_config=>get_instance( ).
    ENDIF.
    ro_config = mo_config.

  ENDMETHOD.


  METHOD param.

    rv_value = config( )->get_param( iv_key   = iv_key
                                     iv_bukrs = iv_bukrs ).
    IF rv_value IS INITIAL.
      rv_value = iv_default.
    ENDIF.

  ENDMETHOD.


  METHOD text_langu.

    DATA(lv_parm) = param( iv_key   = zfiif_hddt_types=>gc_parm-text_langu
                           iv_bukrs = iv_bukrs ).
    IF lv_parm IS INITIAL.
      rv_langu = sy-langu.
    ELSE.
      " Cho phép khai 'E' hoặc 'EN'
      IF strlen( lv_parm ) = 1.
        rv_langu = lv_parm.
      ELSE.
        DATA lv_laiso TYPE laiso.
        lv_laiso = lv_parm.
        SELECT SINGLE spras FROM t002
          WHERE laiso = @lv_laiso
          INTO @rv_langu.
        IF sy-subrc <> 0.
          rv_langu = sy-langu.
        ENDIF.
      ENDIF.
    ENDIF.

  ENDMETHOD.


  METHOD load_registry.

    CLEAR mt_reg.
    SELECT * FROM zfit_hddt_inv
      WHERE bukrs    = @iv_bukrs
        AND gjahr    = @iv_gjahr
        AND src_type = @iv_src_type
      INTO TABLE @mt_reg.

  ENDMETHOD.


  METHOD registry_of.

    TRY.
        rs_reg = mt_reg[ bukrs     = iv_bukrs
                         gjahr     = iv_gjahr
                         src_type  = iv_src_type
                         src_docno = iv_docno ].
      CATCH cx_sy_itab_line_not_found.
        CLEAR rs_reg.
        rs_reg-status = zfiif_hddt_types=>gc_status-not_sent.
    ENDTRY.
    IF rs_reg-status IS INITIAL.
      rs_reg-status = zfiif_hddt_types=>gc_status-not_sent.
    ENDIF.

  ENDMETHOD.


  METHOD keep_document.

    rv_keep = abap_true.

    " Chứng từ đã đảo / huỷ: chỉ giữ khi đã có số HĐĐT (để người dùng
    " huỷ hoá đơn) hoặc khi người dùng chủ động yêu cầu.
    IF iv_reversed = abap_true
       AND is_selection-xreversed = abap_false
       AND is_reg-serial IS INITIAL
       AND is_reg-seq    IS INITIAL.
      rv_keep = abap_false.
      RETURN.
    ENDIF.

    IF is_selection-r_status IS NOT INITIAL
       AND is_reg-status NOT IN is_selection-r_status.
      rv_keep = abap_false.
    ENDIF.

  ENDMETHOD.


*---------------------------------------------------------------------*
* Người bán — port từ ZFM_GET_SELLER
*---------------------------------------------------------------------*
  METHOD read_seller.

    TRY.
        rs_seller = mt_seller[ bukrs = iv_bukrs ]-seller.
        RETURN.
      CATCH cx_sy_itab_line_not_found.
    ENDTRY.

    SELECT SINGLE bukrs, butxt, stceg, adrnr, land1
      FROM t001
      WHERE bukrs = @iv_bukrs
      INTO @DATA(ls_t001).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    rs_seller-tax_code = ls_t001-stceg.
    rs_seller-name     = ls_t001-butxt.

    SELECT SINGLE name1, name2, street, str_suppl1, str_suppl2, str_suppl3,
                  location, city2, city1, tel_number, fax_number, country
      FROM adrc
      WHERE addrnumber = @ls_t001-adrnr
      INTO @DATA(ls_adrc).
    IF sy-subrc = 0.
      rs_seller-name = |{ ls_adrc-name1 } { ls_adrc-name2 }|.
      CONDENSE rs_seller-name.
      rs_seller-address = |{ ls_adrc-street } { ls_adrc-str_suppl1 }, { ls_adrc-str_suppl2 }, | &&
                          |{ ls_adrc-str_suppl3 }, { ls_adrc-location }, { ls_adrc-city2 }, { ls_adrc-city1 }|.
      clean_address( EXPORTING iv_land1 = ls_adrc-country
                               iv_bukrs = iv_bukrs
                     CHANGING  cv_addr  = rs_seller-address ).
      rs_seller-phone = ls_adrc-tel_number.
    ENDIF.

    SELECT smtp_addr FROM adr6
      WHERE addrnumber = @ls_t001-adrnr
      ORDER BY consnumber
      INTO TABLE @DATA(lt_adr6)
      UP TO 1 ROWS.
    IF sy-subrc = 0.
      rs_seller-email = lt_adr6[ 1 ]-smtp_addr.
    ENDIF.

    INSERT VALUE #( bukrs = iv_bukrs seller = rs_seller ) INTO TABLE mt_seller.

  ENDMETHOD.


*---------------------------------------------------------------------*
* Người mua — port từ ZFM_GET_BUYER / get_customer_detail
*---------------------------------------------------------------------*
  METHOD read_buyer.

    rs_buyer-code = iv_kunnr.

*---- (1) Khách lẻ: dữ liệu nhập tay trên chứng từ (BSEC) -----------*
    IF iv_belnr IS NOT INITIAL.
      SELECT SINGLE name1, name2, name3, name4, stras, ort01, pstlz,
                    land1, stcd1, stcd3, intad, banks, bankl, bankn
        FROM bsec
        WHERE bukrs = @iv_bukrs
          AND belnr = @iv_belnr
          AND gjahr = @iv_gjahr
        INTO @DATA(ls_bsec).
      IF sy-subrc = 0.
        rs_buyer-one_time   = abap_true.
        rs_buyer-legal_name = |{ ls_bsec-name1 } { ls_bsec-name2 } { ls_bsec-name3 } { ls_bsec-name4 }|.
        CONDENSE rs_buyer-legal_name.
        rs_buyer-address    = |{ ls_bsec-stras }, { ls_bsec-ort01 }|.
        clean_address( EXPORTING iv_land1 = ls_bsec-land1
                                 iv_bukrs = iv_bukrs
                       CHANGING  cv_addr  = rs_buyer-address ).
        rs_buyer-tax_code   = COND #( WHEN ls_bsec-stcd1 IS NOT INITIAL
                                      THEN ls_bsec-stcd1 ELSE ls_bsec-stcd3 ).
        rs_buyer-email      = ls_bsec-intad.
        rs_buyer-bank_acct  = ls_bsec-bankn.
        IF ls_bsec-bankl IS NOT INITIAL.
          SELECT SINGLE banka FROM bnka
            WHERE banks = @ls_bsec-banks AND bankl = @ls_bsec-bankl
            INTO @DATA(lv_banka).
          IF sy-subrc = 0.
            rs_buyer-bank_name = lv_banka.
          ENDIF.
        ENDIF.
        " Khách lẻ không có mã BP -> không cache
        RETURN.
      ENDIF.
    ENDIF.

    IF iv_kunnr IS INITIAL.
      RETURN.
    ENDIF.

*---- (2) Cache theo mã khách -----------------------------------------*
    TRY.
        rs_buyer = mt_buyer[ kunnr = iv_kunnr ]-buyer.
      CATCH cx_sy_itab_line_not_found.
        IF buyer_from_bp( EXPORTING iv_kunnr = iv_kunnr
                                    iv_bukrs = iv_bukrs
                                    iv_bvtyp = iv_bvtyp
                          CHANGING  cs_buyer = rs_buyer ) = abap_false.
          buyer_from_kna1( EXPORTING iv_kunnr = iv_kunnr
                                     iv_bukrs = iv_bukrs
                           CHANGING  cs_buyer = rs_buyer ).
        ENDIF.
        INSERT VALUE #( kunnr = iv_kunnr buyer = rs_buyer ) INTO TABLE mt_buyer.
    ENDTRY.

*---- (3) Số tham chiếu của khách hàng trên đơn bán (VBKD-BSTKD) ------*
    IF iv_aubel IS NOT INITIAL.
      SELECT bstkd FROM vbkd
        WHERE vbeln = @iv_aubel
          AND bstkd <> @space
        ORDER BY posnr
        INTO TABLE @DATA(lt_vbkd)
        UP TO 1 ROWS.
      IF sy-subrc = 0.
        rs_buyer-ref_no = lt_vbkd[ 1 ]-bstkd.
      ENDIF.
    ENDIF.

  ENDMETHOD.


  METHOD buyer_from_bp.

    DATA lv_partner TYPE bu_partner.

    " Khách hàng -> Business Partner (CVI); nếu không có link thì thử
    " chính mã khách là số BP (mô hình đồng bộ số).
    SELECT SINGLE partner_guid FROM cvi_cust_link
      WHERE customer = @iv_kunnr
      INTO @DATA(lv_guid).
    IF sy-subrc = 0.
      SELECT SINGLE partner, type, name_org1, name_org2, name_org3, name_org4,
                    name_first, name_last
        FROM but000
        WHERE partner_guid = @lv_guid
        INTO @DATA(ls_but000).
    ELSE.
      lv_partner = iv_kunnr.
      SELECT SINGLE partner, type, name_org1, name_org2, name_org3, name_org4,
                    name_first, name_last
        FROM but000
        WHERE partner = @lv_partner
        INTO @ls_but000.
    ENDIF.
    IF sy-subrc <> 0.
      rv_found = abap_false.
      RETURN.
    ENDIF.
    rv_found = abap_true.

*---- Tên -------------------------------------------------------------*
    IF ls_but000-type = '1'.               " cá nhân
      cs_buyer-legal_name = |{ ls_but000-name_first } { ls_but000-name_last }|.
    ELSE.
      " Thứ tự trường tên theo cấu hình (dự án tham chiếu dùng
      " NAME_ORG2..4 và fallback NAME_ORG1 vì ORG1 chứa tên viết tắt).
      DATA(lv_fields) = param( iv_key     = zfiif_hddt_types=>gc_parm-buyer_name_flds
                               iv_bukrs   = iv_bukrs
                               iv_default = `NAME_ORG1,NAME_ORG2,NAME_ORG3,NAME_ORG4` ).
      SPLIT lv_fields AT ',' INTO TABLE DATA(lt_fields).
      LOOP AT lt_fields ASSIGNING FIELD-SYMBOL(<lv_field>).
        CONDENSE <lv_field>.
        TRANSLATE <lv_field> TO UPPER CASE.
        ASSIGN COMPONENT <lv_field> OF STRUCTURE ls_but000 TO FIELD-SYMBOL(<lv_val>).
        IF sy-subrc = 0 AND <lv_val> IS NOT INITIAL.
          cs_buyer-legal_name = |{ cs_buyer-legal_name } { <lv_val> }|.
        ENDIF.
      ENDLOOP.
      IF cs_buyer-legal_name IS INITIAL.
        cs_buyer-legal_name = ls_but000-name_org1.
      ENDIF.
    ENDIF.
    CONDENSE cs_buyer-legal_name.

*---- Địa chỉ: số địa chỉ lớn nhất của BP (như dự án tham chiếu) ------*
    SELECT addrnumber FROM but020
      WHERE partner = @ls_but000-partner
      ORDER BY addrnumber DESCENDING
      INTO TABLE @DATA(lt_but020)
      UP TO 1 ROWS.
    DATA lv_land1 TYPE land1.
    IF sy-subrc = 0.
      DATA(lv_adrnr) = lt_but020[ 1 ]-addrnumber.

      SELECT SINGLE street, str_suppl1, str_suppl2, str_suppl3, location,
                    city1, city2, country
        FROM adrc
        WHERE addrnumber = @lv_adrnr
        INTO @DATA(ls_adrc).
      IF sy-subrc = 0.
        lv_land1 = ls_adrc-country.
        cs_buyer-address = |{ ls_adrc-street } { ls_adrc-str_suppl1 }, { ls_adrc-str_suppl2 }, | &&
                           |{ ls_adrc-str_suppl3 }, { ls_adrc-location }, { ls_adrc-city2 }, { ls_adrc-city1 }|.
        clean_address( EXPORTING iv_land1 = lv_land1
                                 iv_bukrs = iv_bukrs
                       CHANGING  cv_addr  = cs_buyer-address ).
      ENDIF.

      " Email: nối tất cả địa chỉ bằng ';' (NCC gửi HĐ tới nhiều mail)
      SELECT smtp_addr FROM adr6
        WHERE addrnumber = @lv_adrnr
        ORDER BY consnumber
        INTO TABLE @DATA(lt_adr6).
      LOOP AT lt_adr6 ASSIGNING FIELD-SYMBOL(<ls_adr6>).
        IF <ls_adr6>-smtp_addr IS INITIAL.
          CONTINUE.
        ENDIF.
        cs_buyer-email = COND #( WHEN cs_buyer-email IS INITIAL
                                 THEN <ls_adr6>-smtp_addr
                                 ELSE |{ cs_buyer-email };{ <ls_adr6>-smtp_addr }| ).
      ENDLOOP.

      SELECT tel_number FROM adr2
        WHERE addrnumber = @lv_adrnr
        ORDER BY consnumber
        INTO TABLE @DATA(lt_adr2).
      LOOP AT lt_adr2 ASSIGNING FIELD-SYMBOL(<ls_adr2>).
        IF <ls_adr2>-tel_number IS INITIAL.
          CONTINUE.
        ENDIF.
        cs_buyer-phone = COND #( WHEN cs_buyer-phone IS INITIAL
                                 THEN <ls_adr2>-tel_number
                                 ELSE |{ cs_buyer-phone };{ <ls_adr2>-tel_number }| ).
      ENDLOOP.
    ENDIF.

*---- Mã số thuế và CCCD từ số định danh BP ---------------------------*
    DATA(lv_tax_type) = param( iv_key     = zfiif_hddt_types=>gc_parm-buyer_tax_idtype
                               iv_bukrs   = iv_bukrs
                               iv_default = `VATRU` ).
    " Loại số định danh chứa CCCD là quy ước riêng từng khách hàng ->
    " không có mặc định trong code; trống = không lấy
    DATA(lv_id_type)  = param( iv_key     = zfiif_hddt_types=>gc_parm-buyer_id_idtype
                               iv_bukrs   = iv_bukrs ).
    SELECT type, idnumber FROM but0id
      WHERE partner = @ls_but000-partner
      INTO TABLE @DATA(lt_but0id).
    LOOP AT lt_but0id ASSIGNING FIELD-SYMBOL(<ls_id>).
      IF <ls_id>-type = lv_tax_type AND cs_buyer-tax_code IS INITIAL.
        cs_buyer-tax_code = <ls_id>-idnumber.
      ELSEIF lv_id_type IS NOT INITIAL AND <ls_id>-type = lv_id_type
         AND cs_buyer-id_number IS INITIAL.
        cs_buyer-id_number = <ls_id>-idnumber.
      ENDIF.
    ENDLOOP.
    IF cs_buyer-tax_code IS INITIAL.
      SELECT SINGLE stcd1, stcd3 FROM kna1
        WHERE kunnr = @iv_kunnr
        INTO @DATA(ls_kna1_tax).
      IF sy-subrc = 0.
        cs_buyer-tax_code = COND #( WHEN ls_kna1_tax-stcd1 IS NOT INITIAL
                                    THEN ls_kna1_tax-stcd1 ELSE ls_kna1_tax-stcd3 ).
      ENDIF.
    ENDIF.

*---- Ngân hàng theo loại đối tác NH ghi trên chứng từ (BVTYP) --------*
    IF iv_bvtyp IS NOT INITIAL.
      SELECT SINGLE banks, bankl, bankn, accname FROM but0bk
        WHERE partner = @ls_but000-partner
          AND bkvid   = @iv_bvtyp
        INTO @DATA(ls_but0bk).
      IF sy-subrc = 0.
        cs_buyer-bank_acct = ls_but0bk-bankn.
        SELECT SINGLE banka FROM bnka
          WHERE banks = @ls_but0bk-banks AND bankl = @ls_but0bk-bankl
          INTO @DATA(lv_banka).
        IF sy-subrc = 0.
          cs_buyer-bank_name = lv_banka.
        ENDIF.
      ENDIF.
    ENDIF.

  ENDMETHOD.


  METHOD buyer_from_kna1.

    " Hệ không dùng BP (hoặc chưa đồng bộ CVI) -> dữ liệu khách hàng cổ điển
    SELECT SINGLE name1, name2, stras, ort01, land1, stcd1, stcd3, telf1, adrnr
      FROM kna1
      WHERE kunnr = @iv_kunnr
      INTO @DATA(ls_kna1).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    cs_buyer-legal_name = |{ ls_kna1-name1 } { ls_kna1-name2 }|.
    CONDENSE cs_buyer-legal_name.
    cs_buyer-tax_code = COND #( WHEN ls_kna1-stcd1 IS NOT INITIAL
                                THEN ls_kna1-stcd1 ELSE ls_kna1-stcd3 ).
    cs_buyer-phone    = ls_kna1-telf1.
    cs_buyer-address  = |{ ls_kna1-stras }, { ls_kna1-ort01 }|.

    IF ls_kna1-adrnr IS NOT INITIAL.
      SELECT SINGLE street, str_suppl1, str_suppl2, str_suppl3, location, city1, city2, country
        FROM adrc
        WHERE addrnumber = @ls_kna1-adrnr
        INTO @DATA(ls_adrc).
      IF sy-subrc = 0.
        cs_buyer-address = |{ ls_adrc-street } { ls_adrc-str_suppl1 }, { ls_adrc-str_suppl2 }, | &&
                           |{ ls_adrc-str_suppl3 }, { ls_adrc-location }, { ls_adrc-city2 }, { ls_adrc-city1 }|.
        ls_kna1-land1 = ls_adrc-country.
      ENDIF.
      SELECT smtp_addr FROM adr6
        WHERE addrnumber = @ls_kna1-adrnr
        ORDER BY consnumber
        INTO TABLE @DATA(lt_adr6)
        UP TO 1 ROWS.
      IF sy-subrc = 0.
        cs_buyer-email = lt_adr6[ 1 ]-smtp_addr.
      ENDIF.
    ENDIF.

    clean_address( EXPORTING iv_land1 = ls_kna1-land1
                             iv_bukrs = iv_bukrs
                   CHANGING  cv_addr  = cs_buyer-address ).

  ENDMETHOD.


  METHOD clean_address.

    " Gộp các đoạn ', , ,' do trường trống thành một dấu phẩy, cắt dấu
    " phẩy / khoảng trắng đầu-cuối (dự án tham chiếu REPLACE 6 lần + SHIFT)
    cv_addr = replace( val = cv_addr regex = `(\s*,\s*)+` with = `, ` occ = 0 ).
    cv_addr = replace( val = cv_addr regex = `^[\s,]+|[\s,]+$` with = `` occ = 0 ).
    CONDENSE cv_addr.

    IF cv_addr IS INITIAL OR iv_land1 IS INITIAL.
      RETURN.
    ENDIF.

    " Hậu tố quốc gia: VN lấy từ tham số (mặc định 'Việt Nam'), nước
    " ngoài lấy tên nước theo ngôn ngữ đăng nhập.
    IF iv_land1 = 'VN'.
      DATA(lv_sfx) = param( iv_key     = zfiif_hddt_types=>gc_parm-addr_country_sfx
                            iv_bukrs   = iv_bukrs
                            iv_default = `Việt Nam` ).
      IF lv_sfx <> '-'.                    " '-' = không thêm hậu tố
        cv_addr = |{ cv_addr }, { lv_sfx }|.
      ENDIF.
    ELSE.
      SELECT SINGLE landx50 FROM t005t
        WHERE land1 = @iv_land1 AND spras = @sy-langu
        INTO @DATA(lv_landx).
      IF sy-subrc = 0.
        cv_addr = |{ cv_addr }, { lv_landx }|.
      ENDIF.
    ENDIF.

  ENDMETHOD.


*---------------------------------------------------------------------*
* Thuế
*---------------------------------------------------------------------*
  METHOD tax_rate_of.

    DATA lv_char TYPE c LENGTH 20.

    IF iv_mwskz IS INITIAL.
      RETURN.
    ENDIF.

    " (1) Cấu hình MAP TAXRATE: MWSKZ -> thuế suất (kể cả -1 KCT, -2 KKKNT)
    config( )->map_value( EXPORTING iv_provider  = space
                                    iv_map_type  = zfiif_hddt_types=>gc_map_type-tax_rate
                                    iv_sap_value = iv_mwskz
                          IMPORTING ev_ext_value = DATA(lv_ext) ).
    lv_char = lv_ext.
    CONDENSE lv_char NO-GAPS.
    IF lv_char IS NOT INITIAL AND lv_char <> iv_mwskz
       AND lv_char CO '0123456789.- '.
      rv_rate = lv_char.
      RETURN.
    ENDIF.

    " (2) Bảng thuế của chứng từ (BSET-KBETR lưu 1/10 %: 10% -> 100)
    TRY.
        rv_rate = it_rate[ mwskz = iv_mwskz ]-kbetr / 10.
        RETURN.
      CATCH cx_sy_itab_line_not_found.
    ENDTRY.

    " (3) Điều kiện thuế đầu ra A003/KONP theo nước của công ty
    DATA(lv_kschl) = param( iv_key     = zfiif_hddt_types=>gc_parm-tax_cond_type
                            iv_bukrs   = iv_bukrs
                            iv_default = `MWAS` ).
    SELECT SINGLE land1 FROM t001 WHERE bukrs = @iv_bukrs INTO @DATA(lv_land1).
    SELECT k~kbetr
      FROM a003 AS a INNER JOIN konp AS k ON k~knumh = a~knumh
      WHERE a~kappl = 'TX'
        AND a~kschl = @lv_kschl
        AND a~aland = @lv_land1
        AND a~mwskz = @iv_mwskz
        AND k~loevm_ko = @space
      ORDER BY a~datbi DESCENDING
      INTO TABLE @DATA(lt_konp)
      UP TO 1 ROWS.
    IF sy-subrc = 0.
      rv_rate = lt_konp[ 1 ]-kbetr / 10.
    ENDIF.

  ENDMETHOD.


  METHOD rate_text.

    IF iv_rate >= 0.
      rv_text = |{ zfic_hddt_json=>format_number( iv_value    = iv_rate
                                                   iv_decimals = 0 ) }%|.
    ELSE.
      " Thuế suất âm (-1 KCT, -2 KKKNT...) -> nhãn từ ánh xạ
      config( )->map_value( EXPORTING iv_provider  = space
                                      iv_map_type  = zfiif_hddt_types=>gc_map_type-tax_rate
                                      iv_sap_value = iv_rate
                            IMPORTING ev_ext_text  = DATA(lv_txt) ).
      rv_text = lv_txt.
    ENDIF.

  ENDMETHOD.


  METHOD line_tax.

    IF iv_rate <= 0.
      rv_tax = 0.
      RETURN.
    ENDIF.
    DATA(lv_tax) = iv_amount * iv_rate / 100.
    IF iv_waers = 'VND' OR iv_waers IS INITIAL.
      rv_tax = round( val = lv_tax dec = 0 ).
    ELSE.
      rv_tax = round( val = lv_tax dec = 2 ).
    ENDIF.

  ENDMETHOD.


  METHOD reconcile_tax.

    LOOP AT it_tax ASSIGNING FIELD-SYMBOL(<ls_tax>).
      DATA lv_sum  TYPE zfiif_hddt_types=>ty_amount.
      DATA lv_last TYPE i.
      CLEAR: lv_sum, lv_last.

      LOOP AT ct_items ASSIGNING FIELD-SYMBOL(<ls_it>)
           WHERE tax_rate = <ls_tax>-tax_rate
             AND item_type <> '3'.
        lv_sum  = lv_sum + <ls_it>-tax_amount.
        lv_last = sy-tabix.
      ENDLOOP.

      IF lv_last > 0 AND lv_sum <> <ls_tax>-tax_amt.
        ASSIGN ct_items[ lv_last ] TO <ls_it>.
        <ls_it>-tax_amount = <ls_it>-tax_amount + ( <ls_tax>-tax_amt - lv_sum ).
        <ls_it>-total      = <ls_it>-amount + <ls_it>-tax_amount.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD rate_summary.

    DATA lv_first TYPE zfiif_hddt_types=>ty_rate.
    DATA lv_has   TYPE abap_bool.

    LOOP AT it_items ASSIGNING FIELD-SYMBOL(<ls_it>) WHERE item_type <> '3'.
      IF lv_has = abap_false.
        lv_first = <ls_it>-tax_rate.
        lv_has   = abap_true.
      ELSEIF <ls_it>-tax_rate <> lv_first.
        rv_text = 'Nhiều loại'.
        RETURN.
      ENDIF.
    ENDLOOP.

    IF lv_has = abap_true.
      rv_text = rate_text( lv_first ).
    ENDIF.

  ENDMETHOD.


*---------------------------------------------------------------------*
* Dòng hàng
*---------------------------------------------------------------------*
  METHOD unit_text.

    IF iv_meins IS INITIAL.
      RETURN.
    ENDIF.
    TRY.
        rv_text = mt_unit[ key = iv_meins ]-text.
        RETURN.
      CATCH cx_sy_itab_line_not_found.
    ENDTRY.

    DATA(lv_langu) = text_langu( ).
    SELECT SINGLE msehl FROM t006a
      WHERE spras = @lv_langu AND msehi = @iv_meins
      INTO @DATA(lv_msehl).
    IF sy-subrc <> 0 AND lv_langu <> sy-langu.
      SELECT SINGLE msehl FROM t006a
        WHERE spras = @sy-langu AND msehi = @iv_meins
        INTO @lv_msehl.
    ENDIF.
    rv_text = COND #( WHEN lv_msehl IS NOT INITIAL THEN lv_msehl ELSE iv_meins ).
    INSERT VALUE #( key = iv_meins text = rv_text ) INTO TABLE mt_unit.

  ENDMETHOD.


  METHOD material_text.

    IF iv_matnr IS INITIAL.
      RETURN.
    ENDIF.
    TRY.
        rv_text = mt_matnr[ key = iv_matnr ]-text.
        RETURN.
      CATCH cx_sy_itab_line_not_found.
    ENDTRY.

    DATA(lv_langu) = text_langu( ).
    SELECT SINGLE maktx FROM makt
      WHERE matnr = @iv_matnr AND spras = @lv_langu
      INTO @DATA(lv_maktx).
    IF sy-subrc <> 0 AND lv_langu <> sy-langu.
      SELECT SINGLE maktx FROM makt
        WHERE matnr = @iv_matnr AND spras = @sy-langu
        INTO @lv_maktx.
    ENDIF.
    rv_text = lv_maktx.
    INSERT VALUE #( key = iv_matnr text = rv_text ) INTO TABLE mt_matnr.

  ENDMETHOD.


  METHOD item_name.

    " Thứ tự ưu tiên tên hàng trong dự án tham chiếu:
    "   1) long text dòng đơn bán  (ZI03 / VBBP, tên = VBELN+POSNR)
    "   2) long text vật tư        (GRUN / MATERIAL, tên = MATNR)
    "   3) MAKT
    "   4) diễn giải trên chứng từ (SGTXT / ARKTX)
    " Bước 1-2 khai trong ITEM_TEXT_IDS dạng 'ID:OBJECT;ID:OBJECT'. Mặc
    " định trong code chỉ dùng text chuẩn SAP (GRUN/MATERIAL); text ID
    " riêng của khách hàng nằm ở cấu hình.
    DATA(lv_ids) = param( iv_key     = zfiif_hddt_types=>gc_parm-item_text_ids
                          iv_bukrs   = iv_bukrs
                          iv_default = `GRUN:MATERIAL` ).
    SPLIT lv_ids AT ';' INTO TABLE DATA(lt_ids).
    LOOP AT lt_ids ASSIGNING FIELD-SYMBOL(<lv_pair>).
      SPLIT <lv_pair> AT ':' INTO DATA(lv_id) DATA(lv_obj).
      CONDENSE: lv_id, lv_obj.
      TRANSLATE: lv_id TO UPPER CASE, lv_obj TO UPPER CASE.
      IF lv_id IS INITIAL OR lv_obj IS INITIAL.
        CONTINUE.
      ENDIF.

      DATA lv_name TYPE tdobname.
      CLEAR lv_name.
      CASE lv_obj.
        WHEN 'VBBP'.
          IF iv_vbeln IS INITIAL.
            CONTINUE.
          ENDIF.
          lv_name = |{ iv_vbeln }{ iv_posnr }|.
        WHEN 'MATERIAL'.
          IF iv_matnr IS INITIAL.
            CONTINUE.
          ENDIF.
          lv_name = iv_matnr.
        WHEN OTHERS.
          CONTINUE.
      ENDCASE.

      rv_name = read_text( iv_id     = CONV #( lv_id )
                           iv_object = CONV #( lv_obj )
                           iv_name   = lv_name ).
      IF rv_name IS NOT INITIAL.
        RETURN.
      ENDIF.
    ENDLOOP.

    rv_name = material_text( iv_matnr ).
    IF rv_name IS INITIAL.
      rv_name = iv_default.
      CONDENSE rv_name.
    ENDIF.

  ENDMETHOD.


  METHOD read_text.

    DATA lt_lines TYPE STANDARD TABLE OF tline WITH EMPTY KEY.

    " Kiểm tra header trước để lấy đúng ngôn ngữ đã lưu (long text
    " thường chỉ có 1 ngôn ngữ và không trùng ngôn ngữ đăng nhập).
    SELECT SINGLE tdspras FROM stxh
      WHERE tdobject = @iv_object
        AND tdname   = @iv_name
        AND tdid     = @iv_id
      INTO @DATA(lv_spras).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    CALL FUNCTION 'READ_TEXT'
      EXPORTING
        id       = iv_id
        language = lv_spras
        name     = iv_name
        object   = iv_object
      TABLES
        lines    = lt_lines
      EXCEPTIONS
        OTHERS   = 1.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    LOOP AT lt_lines ASSIGNING FIELD-SYMBOL(<ls_line>).
      rv_text = COND #( WHEN rv_text IS INITIAL THEN <ls_line>-tdline
                        ELSE |{ rv_text } { <ls_line>-tdline }| ).
    ENDLOOP.
    CONDENSE rv_text.

  ENDMETHOD.


*---------------------------------------------------------------------*
* Header
*---------------------------------------------------------------------*
  METHOD payment_of.

    DATA(lv_zlsch) = iv_zlsch.
    IF lv_zlsch IS INITIAL.
      " Chứng từ không ghi phương thức -> hình thức mặc định (vd 'TM/CK')
      DATA(lv_def) = param( iv_key   = zfiif_hddt_types=>gc_parm-default_payment
                            iv_bukrs = iv_bukrs ).
      IF lv_def IS INITIAL.
        RETURN.
      ENDIF.
      rs_payment-method_code = lv_def.
      rs_payment-method_name = lv_def.
      RETURN.
    ENDIF.

    " Ánh xạ ở tầng nguồn dùng PROVIDER = blank (không phụ thuộc NCC);
    " adapter có thể ánh xạ lần hai theo NCC nếu cần.
    config( )->map_value( EXPORTING iv_provider  = space
                                    iv_map_type  = zfiif_hddt_types=>gc_map_type-payment
                                    iv_sap_value = lv_zlsch
                          IMPORTING ev_ext_value = DATA(lv_code)
                                    ev_ext_text  = DATA(lv_text) ).
    rs_payment-method_code = lv_code.
    rs_payment-method_name = COND #( WHEN lv_text IS NOT INITIAL THEN lv_text ELSE lv_code ).

  ENDMETHOD.


  METHOD local_currency.

    DATA(lv_local) = param( iv_key   = zfiif_hddt_types=>gc_parm-local_currency
                            iv_bukrs = iv_bukrs ).
    rv_waers = COND #( WHEN lv_local IS INITIAL THEN 'VND' ELSE lv_local ).

  ENDMETHOD.


  METHOD exch_rate_of.

    IF iv_waers IS INITIAL OR iv_waers = local_currency( iv_bukrs ) OR iv_kursf IS INITIAL.
      rv_rate = 1.
      RETURN.
    ENDIF.

    " KURSF âm = tỷ giá nghịch đảo; hệ số nhân (vd 1000 khi TCURF khai
    " factor) lấy từ tham số — dự án tham chiếu nhân cứng 1000.
    DATA(lv_factor) = param( iv_key     = zfiif_hddt_types=>gc_parm-exch_rate_factor
                             iv_bukrs   = iv_bukrs
                             iv_default = `1` ).
    DATA lv_f TYPE zfiif_hddt_types=>ty_amount.
    TRY.
        lv_f = lv_factor.
      CATCH cx_sy_conversion_no_number.
        lv_f = 1.
    ENDTRY.
    IF lv_f = 0.
      lv_f = 1.
    ENDIF.

    IF iv_kursf < 0.
      rv_rate = ( 1 / abs( iv_kursf ) ) * lv_f.
    ELSE.
      rv_rate = iv_kursf * lv_f.
    ENDIF.

  ENDMETHOD.


  METHOD finalize_request.

    DATA(lv_bukrs) = cs_request-bukrs.

    " Người dùng yêu cầu số lượng luôn dương (dự án tham chiếu)
    IF param( iv_key = zfiif_hddt_types=>gc_parm-item_qty_abs
              iv_bukrs = lv_bukrs iv_default = `X` ) = 'X'.
      LOOP AT cs_request-invoice-items ASSIGNING FIELD-SYMBOL(<ls_it>).
        <ls_it>-quantity = abs( <ls_it>-quantity ).
      ENDLOOP.
    ENDIF.

    " Người bán từ T001/ADRC — tham số SELLER_* trong FILL_DEFAULTS của
    " service chỉ điền các trường còn trống.
    IF param( iv_key = zfiif_hddt_types=>gc_parm-seller_from_t001
              iv_bukrs = lv_bukrs iv_default = `X` ) = 'X'.
      DATA(ls_seller) = read_seller( lv_bukrs ).
      IF cs_request-invoice-seller-name IS INITIAL.
        cs_request-invoice-seller-name = ls_seller-name.
      ENDIF.
      IF cs_request-invoice-seller-address IS INITIAL.
        cs_request-invoice-seller-address = ls_seller-address.
      ENDIF.
      IF cs_request-invoice-seller-phone IS INITIAL.
        cs_request-invoice-seller-phone = ls_seller-phone.
      ENDIF.
      IF cs_request-invoice-seller-email IS INITIAL.
        cs_request-invoice-seller-email = ls_seller-email.
      ENDIF.
    ENDIF.

    " Tổng hợp thuế suất để hiển thị ('10%' hoặc 'Nhiều loại')
    DATA(lv_summary) = rate_summary( cs_request-invoice-items ).
    IF lv_summary IS NOT INITIAL.
      APPEND VALUE #( name = 'TAX_RATE_SUMMARY' value = lv_summary )
             TO cs_request-invoice-ext.
    ENDIF.

    " Tổng cộng do engine tính (không lặp lại công thức ở tầng nguồn)
    zfic_hddt_service=>aggregate_invoice( CHANGING cs_invoice = cs_request-invoice ).

  ENDMETHOD.


*---------------------------------------------------------------------*
* Ánh xạ danh sách
*---------------------------------------------------------------------*
  METHOD in_map_list.

    DATA(lt_map) = config( )->get_map_list( iv_provider = space
                                            iv_map_type = iv_map_type ).
    IF lt_map IS INITIAL.
      rv_allowed = iv_default.
      RETURN.
    ENDIF.

    DATA lv_value TYPE c LENGTH 50.
    lv_value = iv_value.
    CONDENSE lv_value.

    rv_allowed = abap_false.
    LOOP AT lt_map ASSIGNING FIELD-SYMBOL(<ls_map>).
      DATA lv_pat TYPE c LENGTH 50.
      lv_pat = <ls_map>-sap_value.
      CONDENSE lv_pat.
      IF lv_pat IS INITIAL.
        CONTINUE.
      ENDIF.
      IF lv_pat CA '*+' .
        IF lv_value CP lv_pat.
          rv_allowed = abap_true.
          RETURN.
        ENDIF.
      ELSEIF lv_value = lv_pat.
        rv_allowed = abap_true.
        RETURN.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD map_list_as_range.

    DATA(lt_map) = config( )->get_map_list( iv_provider = space
                                            iv_map_type = iv_map_type ).
    LOOP AT lt_map ASSIGNING FIELD-SYMBOL(<ls_map>).
      DATA lv_val TYPE zfide_hddt_docno.
      lv_val = <ls_map>-sap_value.
      CONDENSE lv_val.
      IF lv_val IS INITIAL.
        CONTINUE.
      ENDIF.
      IF lv_val CA '*+'.
        APPEND VALUE #( sign = 'I' option = 'CP' low = lv_val ) TO rt_range.
      ELSE.
        APPEND VALUE #( sign = 'I' option = 'EQ' low = lv_val ) TO rt_range.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
