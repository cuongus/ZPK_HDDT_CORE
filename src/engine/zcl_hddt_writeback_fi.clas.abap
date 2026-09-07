*=====================================================================
* Tên/Mã     : ZCL_HDDT_WRITEBACK_FI
* Mô tả chung: Ghi ngược thông tin hoá đơn vào chứng từ kế toán (BKPF)
*              theo FS MAG v0.5 mục 3.6.3 / 3.6.5:
*                - Reference (BKPF-XBLNR)  = Mẫu HĐ + Ký hiệu # Số HĐ
*                  (vd 1C25MAG#00001234) của chính chứng từ;
*                - Ref key 2 HD (BKPF-XREF2_HD) = chuỗi tương ứng của
*                  HOÁ ĐƠN GỐC, chỉ với chứng từ là hoá đơn điều chỉnh;
*                - KHÔNG ghi BKTXT, KHÔNG ghi trạng thái vào XREF2_HD;
*                - chỉ ghi khi giá trị mới khác giá trị đang có.
*              Ghi bằng FM chuẩn FI_DOCUMENT_CHANGE (tương đương FB02,
*              có change document). Chứng từ gom: ghi vào mọi chứng từ
*              thành viên (ZTB_HDDT_GOM).
*              Lưu ý độ dài: XBLNR 16 ký tự vừa đủ 1 + 6 + 1 + 8;
*              XREF2_HD chỉ 12 ký tự -> lấy 12 ký tự cuối của chuỗi HĐ
*              gốc (giữ được '#' + số HĐ). Điểm này FS chưa nêu — đã
*              ghi vào docs/10 để MAG xác nhận.
*              Tầng nền tảng cổ điển. Kích hoạt bằng tham số
*              WRITEBACK_CLASS = ZCL_HDDT_WRITEBACK_FI.
* Tham Số    : WRITE( is_request is_result is_reg )
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       07/09/2026    cuongus - CuongUS        abapGit     Tạo mới
*=====================================================================
CLASS zcl_hddt_writeback_fi DEFINITION
  PUBLIC
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES zif_hddt_writeback .

    "! Chuỗi hoá đơn theo FS: Mẫu + Ký hiệu # Số
    CLASS-METHODS invoice_ref
      IMPORTING i_template   TYPE clike
                i_serial     TYPE clike
                i_seq        TYPE clike
      RETURNING VALUE(r_ref) TYPE string .

  PROTECTED SECTION.
  PRIVATE SECTION.

    TYPES ty_t_accchg TYPE STANDARD TABLE OF accchg WITH EMPTY KEY .

    METHODS change_header
      IMPORTING i_bukrs TYPE bukrs
                i_belnr TYPE belnr_d
                i_gjahr TYPE gjahr
                i_xblnr TYPE string
                i_xref2 TYPE string
                i_set_xref2 TYPE abap_bool
      RAISING   zcx_hddt_error .

ENDCLASS.



CLASS zcl_hddt_writeback_fi IMPLEMENTATION.

  METHOD invoice_ref.

    DATA(lv_tpl) = |{ i_template }|.
    DATA(lv_ser) = |{ i_serial }|.
    DATA(lv_seq) = |{ i_seq }|.
    CONDENSE: lv_tpl NO-GAPS, lv_ser NO-GAPS, lv_seq NO-GAPS.
    IF lv_seq IS INITIAL.
      RETURN.
    ENDIF.
    " Một số NCC trả serial đã gồm mẫu số (Viettel '1C25MAG') -> không
    " nối mẫu số hai lần
    IF lv_tpl IS NOT INITIAL AND strlen( lv_ser ) > 0
       AND lv_ser(1) = lv_tpl AND strlen( lv_ser ) >= 6.
      r_ref = |{ lv_ser }#{ lv_seq }|.
    ELSE.
      r_ref = |{ lv_tpl }{ lv_ser }#{ lv_seq }|.
    ENDIF.

  ENDMETHOD.


  METHOD zif_hddt_writeback~write.

    " Chỉ có ý nghĩa khi đã có số hoá đơn
    DATA(lv_ref) = invoice_ref( i_template = is_reg-template
                                i_serial   = is_reg-serial
                                i_seq      = is_reg-seq ).
    IF lv_ref IS INITIAL.
      RETURN.
    ENDIF.

    " Hoá đơn điều chỉnh / thay thế: chuỗi của hoá đơn gốc -> XREF2_HD
    DATA lv_xref2 TYPE string.
    DATA lv_set_xref2 TYPE abap_bool.
    IF is_reg-ref_docno IS NOT INITIAL.
      DATA(ls_org) = zcl_hddt_log=>read_invoice(
                       i_bukrs     = is_request-bukrs
                       i_gjahr     = COND #( WHEN is_reg-ref_gjahr IS NOT INITIAL
                                             THEN is_reg-ref_gjahr ELSE is_request-gjahr )
                       i_src_type  = COND #( WHEN is_reg-ref_srctype IS NOT INITIAL
                                             THEN is_reg-ref_srctype ELSE is_request-src_type )
                       i_src_docno = is_reg-ref_docno ).
      lv_xref2 = invoice_ref( i_template = ls_org-template
                              i_serial   = ls_org-serial
                              i_seq      = ls_org-seq ).
      IF lv_xref2 IS NOT INITIAL.
        lv_set_xref2 = abap_true.
        " XREF2_HD dài 12: giữ 12 ký tự cuối ('#' + số hoá đơn)
        IF strlen( lv_xref2 ) > 12.
          DATA(lv_off) = strlen( lv_xref2 ) - 12.
          lv_xref2 = lv_xref2+lv_off.
        ENDIF.
      ENDIF.
    ENDIF.

    " XBLNR dài 16: chuỗi FS vừa đủ; dài hơn thì cắt đầu, giữ số HĐ
    IF strlen( lv_ref ) > 16.
      lv_off = strlen( lv_ref ) - 16.
      lv_ref = lv_ref+lv_off.
    ENDIF.

    " Danh sách chứng từ FI cần ghi: chính chứng từ, hoặc các thành viên
    " của chứng từ gom
    TYPES: BEGIN OF ty_doc,
             belnr TYPE belnr_d,
             gjahr TYPE gjahr,
           END OF ty_doc.
    DATA lt_doc TYPE STANDARD TABLE OF ty_doc WITH EMPTY KEY.

    CASE is_request-src_type.
      WHEN 'FI'.
        APPEND VALUE #( belnr = is_request-src_docno gjahr = is_request-gjahr ) TO lt_doc.
      WHEN 'GOM'.
        SELECT src_docno, gjahr FROM ztb_hddt_gom
          WHERE bukrs    = @is_request-bukrs
            AND gjahr    = @is_request-gjahr
            AND gom_no   = @is_request-src_docno
            AND src_type = 'FI'
            AND xcancel  = @space
          INTO TABLE @DATA(lt_mem).
        LOOP AT lt_mem ASSIGNING FIELD-SYMBOL(<fs_mem>).
          APPEND VALUE #( belnr = <fs_mem>-src_docno gjahr = <fs_mem>-gjahr ) TO lt_doc.
        ENDLOOP.
      WHEN OTHERS.
        RETURN.                        " billing SD không có BKPF
    ENDCASE.

    LOOP AT lt_doc ASSIGNING FIELD-SYMBOL(<fs_doc>).
      change_header( i_bukrs     = is_request-bukrs
                     i_belnr     = <fs_doc>-belnr
                     i_gjahr     = <fs_doc>-gjahr
                     i_xblnr     = lv_ref
                     i_xref2     = lv_xref2
                     i_set_xref2 = lv_set_xref2 ).
    ENDLOOP.

  ENDMETHOD.


  METHOD change_header.

    SELECT SINGLE xblnr, xref2_hd, awtyp, awkey
      FROM bkpf
      WHERE bukrs = @i_bukrs
        AND belnr = @i_belnr
        AND gjahr = @i_gjahr
      INTO @DATA(ls_bkpf).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    DATA lt_chg TYPE ty_t_accchg.
    IF ls_bkpf-xblnr <> i_xblnr.
      APPEND VALUE #( fdname = 'XBLNR' oldval = ls_bkpf-xblnr newval = i_xblnr ) TO lt_chg.
    ENDIF.
    IF i_set_xref2 = abap_true AND ls_bkpf-xref2_hd <> i_xref2.
      APPEND VALUE #( fdname = 'XREF2_HD' oldval = ls_bkpf-xref2_hd newval = i_xref2 ) TO lt_chg.
    ENDIF.
    IF lt_chg IS INITIAL.
      RETURN.                          " không sinh change document thừa
    ENDIF.

    DATA(lv_aworg) = |{ i_bukrs }{ i_gjahr }|.
    CALL FUNCTION 'FI_DOCUMENT_CHANGE'
      EXPORTING
        i_awtyp              = 'BKPF'
        i_awref              = CONV awref( i_belnr )
        i_aworg              = CONV aworg( lv_aworg )
        i_bukrs              = i_bukrs
        i_belnr              = i_belnr
        i_gjahr              = i_gjahr
      TABLES
        t_accchg             = lt_chg
      EXCEPTIONS
        no_reference         = 1
        no_document          = 2
        many_documents       = 3
        wrong_input          = 4
        overwrite_creditcard = 5
        OTHERS               = 6.
    IF sy-subrc <> 0.
      zcx_hddt_error=>raise_text(
        |Không ghi ngược được chứng từ { i_belnr }/{ i_gjahr } (FI_DOCUMENT_CHANGE rc { sy-subrc }).| ).
    ENDIF.

  ENDMETHOD.

ENDCLASS.
