*=====================================================================
* Tên/Mã     : ZCL_HDDT_SRC_GOM
* Mô tả chung: Lớp đọc dữ liệu nguồn cho HOÁ ĐƠN GOM (FS MAG v0.5 mục
*              3.6.7): một hoá đơn gồm nhiều chứng từ kế toán của cùng
*              khách hàng / năm / loại tiền.
*              Cách dựng: đọc các thành viên trong ZTB_HDDT_GOM, dùng
*              lớp nguồn FI (theo cấu hình ZTB_HDDT_SRC) dựng request
*              từng thành viên rồi GỘP: header/người mua lấy từ thành
*              viên đầu; dòng hàng nối tiếp và đánh số lại; bảng thuế
*              gộp theo thuế suất; chứng từ gom bị coi là "đã đảo" nếu
*              bất kỳ thành viên nào đã đảo (không cho phát hành).
*              sid/idkey của hoá đơn gom = Company code + Số gom + Năm
*              (FS mục 3.7.1) do FILL_DEFAULTS của engine sinh.
* Tham Số    : SELECT_DOCUMENTS( is_selection ) -> ty_t_request
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       07/09/2026    cuongus - CuongUS        abapGit     Tạo mới
*=====================================================================
CLASS zcl_hddt_src_gom DEFINITION
  PUBLIC
  INHERITING FROM zcl_hddt_src_base
  CREATE PUBLIC .

  PUBLIC SECTION.

    CONSTANTS gc_src_type TYPE zde_hddt_srctype VALUE 'GOM' ##NO_TEXT.

    METHODS zif_hddt_source~select_documents REDEFINITION .
    METHODS zif_hddt_source~get_doc_state    REDEFINITION .

  PROTECTED SECTION.

    METHODS merge
      IMPORTING i_bukrs           TYPE bukrs
                i_gjahr           TYPE gjahr
                i_gom_no          TYPE zde_hddt_docno
                it_members        TYPE zif_hddt_types=>ty_t_request
      RETURNING VALUE(rs_request) TYPE zif_hddt_types=>ty_request .

  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_hddt_src_gom IMPLEMENTATION.

  METHOD zif_hddt_source~select_documents.

    IF is_selection-bukrs IS INITIAL.
      zcx_hddt_error=>raise_text( `Thiếu mã công ty (BUKRS) khi đọc hoá đơn gom.` ).
    ENDIF.

    load_registry( i_bukrs    = is_selection-bukrs
                   i_gjahr    = is_selection-gjahr
                   i_src_type = gc_src_type ).

    SELECT DISTINCT gom_no
      FROM ztb_hddt_gom
      WHERE bukrs   = @is_selection-bukrs
        AND gjahr   = @is_selection-gjahr
        AND gom_no IN @is_selection-r_gom
        AND gom_no IN @is_selection-r_docno
        AND xcancel = @space
      ORDER BY gom_no
      INTO TABLE @DATA(lt_gom).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    LOOP AT lt_gom ASSIGNING FIELD-SYMBOL(<fs_gom>).
      DATA(lt_mem) = zcl_hddt_gom=>members( i_bukrs  = is_selection-bukrs
                                            i_gjahr  = is_selection-gjahr
                                            i_gom_no = <fs_gom>-gom_no ).
      IF lt_mem IS INITIAL.
        CONTINUE.
      ENDIF.

      " Đọc thành viên: chỉ giữ bộ lọc công ty/năm, lấy cả CT đã đảo để
      " phát hiện và chặn phát hành
      DATA ls_sel TYPE zif_hddt_source=>ty_selection.
      CLEAR ls_sel.
      ls_sel-bukrs     = is_selection-bukrs.
      ls_sel-gjahr     = is_selection-gjahr.
      ls_sel-inv_type  = is_selection-inv_type.
      ls_sel-xreversed = abap_true.
      " FS 3.6.7: một chứng từ gom được gom từ NHIỀU loại nguồn khác nhau
      " nên phải đọc thành viên theo từng loại, không cố định FI
      DATA lt_mtype TYPE SORTED TABLE OF zde_hddt_srctype WITH UNIQUE KEY table_line.
      DATA lt_req   TYPE zif_hddt_types=>ty_t_request.
      CLEAR: lt_mtype, lt_req.
      LOOP AT lt_mem ASSIGNING FIELD-SYMBOL(<fs_mem>).
        INSERT <fs_mem>-src_type INTO TABLE lt_mtype.
      ENDLOOP.

      LOOP AT lt_mtype ASSIGNING FIELD-SYMBOL(<fs_mtype>).
        CLEAR ls_sel-r_docno.
        LOOP AT lt_mem ASSIGNING FIELD-SYMBOL(<fs_mem2>) WHERE src_type = <fs_mtype>.
          APPEND VALUE #( sign = 'I' option = 'EQ' low = <fs_mem2>-src_docno ) TO ls_sel-r_docno.
        ENDLOOP.
        IF ls_sel-r_docno IS INITIAL.
          CONTINUE.
        ENDIF.
        TRY.
            DATA(lo_mem) = zcl_hddt_factory=>get_source( i_bukrs    = is_selection-bukrs
                                                         i_src_type = <fs_mtype> ).
          CATCH zcx_hddt_error.
            CONTINUE.
        ENDTRY.
        APPEND LINES OF lo_mem->select_documents( ls_sel ) TO lt_req.
      ENDLOOP.
      IF lt_req IS INITIAL.
        CONTINUE.
      ENDIF.
      SORT lt_req BY src_type src_docno.

      DATA(ls_req) = merge( i_bukrs    = is_selection-bukrs
                            i_gjahr    = is_selection-gjahr
                            i_gom_no   = <fs_gom>-gom_no
                            it_members = lt_req ).

      DATA(ls_reg) = registry_of( i_bukrs    = is_selection-bukrs
                                  i_gjahr    = is_selection-gjahr
                                  i_src_type = gc_src_type
                                  i_docno    = <fs_gom>-gom_no ).
      IF keep_document( i_reversed   = ls_req-src_info-xreversed
                        is_reg       = ls_reg
                        is_selection = is_selection ) = abap_false.
        CONTINUE.
      ENDIF.
      IF is_selection-r_kunnr IS NOT INITIAL
         AND ls_req-invoice-buyer-code NOT IN is_selection-r_kunnr.
        CONTINUE.
      ENDIF.
      IF is_selection-r_seq IS NOT INITIAL AND ls_reg-seq NOT IN is_selection-r_seq.
        CONTINUE.
      ENDIF.

      apply_registry_edits( EXPORTING is_reg = ls_reg CHANGING cs_request = ls_req ).
      APPEND ls_req TO rt_request.
    ENDLOOP.

  ENDMETHOD.


  METHOD zif_hddt_source~get_doc_state.

    DATA(lt_mem) = zcl_hddt_gom=>members( i_bukrs  = i_bukrs
                                          i_gjahr  = i_gjahr
                                          i_gom_no = i_docno ).
    IF lt_mem IS INITIAL.
      RETURN.
    ENDIF.
    rs_state-exists = abap_true.

    LOOP AT lt_mem ASSIGNING FIELD-SYMBOL(<fs_mem>).
      TRY.
          DATA(lo_mem) = zcl_hddt_factory=>get_source( i_bukrs    = i_bukrs
                                                       i_src_type = <fs_mem>-src_type ).
        CATCH zcx_hddt_error.
          CONTINUE.
      ENDTRY.
      DATA(ls_st) = lo_mem->get_doc_state( i_bukrs = i_bukrs
                                           i_gjahr = <fs_mem>-gjahr
                                           i_docno = <fs_mem>-src_docno ).
      IF rs_state-waers IS INITIAL.
        rs_state-waers = ls_st-waers.
        rs_state-kunnr = ls_st-kunnr.
      ENDIF.
      IF ls_st-xreversed = abap_true.
        rs_state-xreversed = abap_true.
        rs_state-stblg     = ls_st-stblg.
        rs_state-stjah     = ls_st-stjah.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD merge.

    READ TABLE it_members INDEX 1 INTO DATA(ls_first).

    rs_request           = ls_first.
    rs_request-src_type  = gc_src_type.
    rs_request-src_docno = i_gom_no.
    CLEAR: rs_request-invoice-items, rs_request-invoice-taxes,
           rs_request-invoice-summary, rs_request-invoice-header-idkey,
           rs_request-invoice-adjust.

    DATA lv_line TYPE zde_hddt_lineno.
    DATA lv_budat TYPE dats.
    FIELD-SYMBOLS <fs_tax> TYPE zif_hddt_types=>ty_tax.

    LOOP AT it_members ASSIGNING FIELD-SYMBOL(<fs_m>).
      " Dòng hàng nối tiếp, đánh số lại; ghi nguồn gốc vào ext
      LOOP AT <fs_m>-invoice-items ASSIGNING FIELD-SYMBOL(<fs_it>).
        DATA(ls_it) = <fs_it>.
        lv_line = lv_line + 1.
        ls_it-line_no = lv_line.
        APPEND VALUE #( name = 'SRC_DOCNO' value = |{ <fs_m>-src_docno }| ) TO ls_it-ext.
        APPEND ls_it TO rs_request-invoice-items.
      ENDLOOP.

      " Bảng thuế gộp theo thuế suất
      LOOP AT <fs_m>-invoice-taxes ASSIGNING FIELD-SYMBOL(<fs_t>).
        READ TABLE rs_request-invoice-taxes ASSIGNING <fs_tax>
             WITH KEY tax_rate = <fs_t>-tax_rate.
        IF sy-subrc <> 0.
          APPEND <fs_t> TO rs_request-invoice-taxes.
        ELSE.
          <fs_tax>-taxable_amt   = <fs_tax>-taxable_amt   + <fs_t>-taxable_amt.
          <fs_tax>-taxable_amt_l = <fs_tax>-taxable_amt_l + <fs_t>-taxable_amt_l.
          <fs_tax>-tax_amt       = <fs_tax>-tax_amt       + <fs_t>-tax_amt.
          <fs_tax>-tax_amt_l     = <fs_tax>-tax_amt_l     + <fs_t>-tax_amt_l.
        ENDIF.
      ENDLOOP.

      " Chứng từ gom "đã đảo" nếu có thành viên đảo
      IF <fs_m>-src_info-xreversed = abap_true OR <fs_m>-src_info-xcancel = abap_true.
        rs_request-src_info-xreversed = abap_true.
      ENDIF.
      IF <fs_m>-src_info-budat > lv_budat.
        lv_budat = <fs_m>-src_info-budat.
      ENDIF.
    ENDLOOP.

    " Ngày lập theo cấu hình, lấy ngày hạch toán muộn nhất trong nhóm
    rs_request-src_info-budat = lv_budat.
    rs_request-invoice-header-inv_date =
      config( )->resolve_invoice_date( i_bukrs = i_bukrs
                                       i_budat = lv_budat
                                       i_bldat = lv_budat
                                       i_cpudt = sy-datum ).
    CLEAR: rs_request-src_info-awtyp, rs_request-src_info-awkey,
           rs_request-src_info-stblg, rs_request-src_info-stjah.

    " Tổng cộng do engine tính lại
    zcl_hddt_service=>aggregate_invoice( CHANGING cs_invoice = rs_request-invoice ).

  ENDMETHOD.

ENDCLASS.
