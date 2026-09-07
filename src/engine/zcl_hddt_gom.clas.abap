*=====================================================================
* Tên/Mã     : ZCL_HDDT_GOM
* Mô tả chung: Gom nhiều chứng từ kế toán thành MỘT hoá đơn (FS MAG
*              v0.5 mục 3.6.7 / 3.6.8) và gỡ gom.
*              Quy tắc gom (FS): cùng khách hàng, cùng năm, cùng loại
*              tiền, chưa được gom, trạng thái 00 hoặc 45 (CQT từ chối);
*              số chứng từ gom tự sinh G000000001.. theo công ty + năm.
*              Dữ liệu: ZTB_HDDT_GOM (thành viên) + ZTB_HDDT_INV-GOM_NO
*              trên từng chứng từ thành viên. Hoá đơn gom là một chứng
*              từ nguồn loại 'GOM' (src_docno = số gom) do
*              ZCL_HDDT_SRC_GOM dựng từ các thành viên.
*              Gỡ gom: chỉ khi hoá đơn gom chưa phát hành (00/45/90);
*              đánh dấu XCANCEL, xoá GOM_NO trên thành viên.
*              Không dùng number range object (SNRO) để package tự đủ
*              qua abapGit; khoá bằng ENQUEUE_E_TABLE khi cấp số.
* Tham Số    : CREATE( i_bukrs i_gjahr it_requests ) -> gom_no
*              CANCEL( i_bukrs i_gjahr i_gom_no )
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       07/09/2026    cuongus - CuongUS        abapGit     Tạo mới
*=====================================================================
CLASS zcl_hddt_gom DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    CONSTANTS gc_src_type TYPE zde_hddt_srctype VALUE 'GOM' ##NO_TEXT.

    TYPES: BEGIN OF ty_member,
             src_type  TYPE zde_hddt_srctype,
             src_docno TYPE zde_hddt_docno,
             gjahr     TYPE gjahr,
           END OF ty_member.
    TYPES ty_t_member TYPE STANDARD TABLE OF ty_member WITH EMPTY KEY.

    "! Gom các request (đã đọc từ nguồn) thành một số chứng từ gom.
    METHODS create
      IMPORTING i_bukrs         TYPE bukrs
                i_gjahr         TYPE gjahr
                it_requests     TYPE zif_hddt_types=>ty_t_request
      RETURNING VALUE(r_gom_no) TYPE zde_hddt_docno
      RAISING   zcx_hddt_error .

    METHODS cancel
      IMPORTING i_bukrs  TYPE bukrs
                i_gjahr  TYPE gjahr
                i_gom_no TYPE zde_hddt_docno
      RAISING   zcx_hddt_error .

    CLASS-METHODS members
      IMPORTING i_bukrs           TYPE bukrs
                i_gjahr           TYPE gjahr
                i_gom_no          TYPE zde_hddt_docno
      RETURNING VALUE(rt_members) TYPE ty_t_member .

    CLASS-METHODS next_number
      IMPORTING i_bukrs         TYPE bukrs
                i_gjahr         TYPE gjahr
      RETURNING VALUE(r_gom_no) TYPE zde_hddt_docno
      RAISING   zcx_hddt_error .

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_hddt_gom IMPLEMENTATION.

  METHOD members.

    SELECT src_type, src_docno, gjahr
      FROM ztb_hddt_gom
      WHERE bukrs   = @i_bukrs
        AND gjahr   = @i_gjahr
        AND gom_no  = @i_gom_no
        AND xcancel = @space
      ORDER BY src_docno
      INTO CORRESPONDING FIELDS OF TABLE @rt_members.

  ENDMETHOD.


  METHOD next_number.

    DATA lv_varkey TYPE vim_enqkey.
    lv_varkey = |{ sy-mandt }{ i_bukrs }{ i_gjahr }|.

    " Khoá theo công ty + năm để hai người gom cùng lúc không trùng số
    CALL FUNCTION 'ENQUEUE_E_TABLE'
      EXPORTING
        tabname        = 'ZTB_HDDT_GOM'
        varkey         = lv_varkey
        _scope         = '1'
        _wait          = 'X'
      EXCEPTIONS
        foreign_lock   = 1
        system_failure = 2
        OTHERS         = 3.
    IF sy-subrc <> 0.
      zcx_hddt_error=>raise_text( `Không khoá được bảng ZTB_HDDT_GOM để cấp số chứng từ gom.` ).
    ENDIF.

    SELECT MAX( gom_no ) FROM ztb_hddt_gom
      WHERE bukrs = @i_bukrs AND gjahr = @i_gjahr
      INTO @DATA(lv_max).

    DATA lv_num TYPE n LENGTH 9.
    IF lv_max IS NOT INITIAL AND lv_max(1) = 'G'.
      lv_num = lv_max+1(9).
    ENDIF.
    lv_num = lv_num + 1.
    r_gom_no = |G{ lv_num }|.

    " Khoá được giải phóng khi COMMIT của caller (E_TABLE _SCOPE 1 =
    " giải phóng theo DEQUEUE_ALL / kết thúc LUW); gọi tường minh thêm
    CALL FUNCTION 'DEQUEUE_E_TABLE'
      EXPORTING
        tabname = 'ZTB_HDDT_GOM'
        varkey  = lv_varkey
        _scope  = '1'.

  ENDMETHOD.


  METHOD create.

    IF lines( it_requests ) < 2.
      zcx_hddt_error=>raise_text( `Chọn ít nhất 2 chứng từ cần gom.` ).
    ENDIF.

    DATA lv_kunnr TYPE kunnr.
    DATA lv_waers TYPE waers.
    DATA lt_mem   TYPE STANDARD TABLE OF ztb_hddt_gom WITH EMPTY KEY.

    LOOP AT it_requests ASSIGNING FIELD-SYMBOL(<fs_req>).
      IF <fs_req>-bukrs <> i_bukrs OR <fs_req>-gjahr <> i_gjahr.
        zcx_hddt_error=>raise_text( `Năm chứng từ / công ty không đồng nhất để gom.` ).
      ENDIF.
      IF <fs_req>-src_type = gc_src_type.
        zcx_hddt_error=>raise_text( `Không gom lồng chứng từ gom.` ).
      ENDIF.

      " Trạng thái theo FS: chỉ 01 (chưa tích hợp) và 10 (CQT từ chối)
      DATA(ls_reg) = zcl_hddt_log=>read_invoice( i_bukrs     = <fs_req>-bukrs
                                                 i_gjahr     = <fs_req>-gjahr
                                                 i_src_type  = <fs_req>-src_type
                                                 i_src_docno = <fs_req>-src_docno ).
      IF ls_reg-gom_no IS NOT INITIAL.
        zcx_hddt_error=>raise_text(
          |Chứng từ { <fs_req>-src_docno ALPHA = OUT } đã được gom vào { ls_reg-gom_no }.| ).
      ENDIF.
      IF ls_reg-status IS NOT INITIAL
         AND ls_reg-status <> zif_hddt_types=>gc_status-not_sent
         AND ls_reg-status <> zif_hddt_types=>gc_status-rejected.
        zcx_hddt_error=>raise_text(
          |Không thể gom chứng từ { <fs_req>-src_docno ALPHA = OUT } ở trạng thái { ls_reg-status }.| ).
      ENDIF.
      IF <fs_req>-src_info-xreversed = abap_true OR <fs_req>-src_info-xcancel = abap_true.
        zcx_hddt_error=>raise_text(
          |Không thể gom chứng từ đã đảo/huỷ { <fs_req>-src_docno ALPHA = OUT }.| ).
      ENDIF.

      IF lv_kunnr IS INITIAL.
        lv_kunnr = <fs_req>-invoice-buyer-code.
        lv_waers = <fs_req>-invoice-header-currency.
      ELSE.
        IF <fs_req>-invoice-buyer-code <> lv_kunnr.
          zcx_hddt_error=>raise_text( `Mã khách hàng không đồng nhất để gom.` ).
        ENDIF.
        IF <fs_req>-invoice-header-currency <> lv_waers.
          zcx_hddt_error=>raise_text( `Không được gom khác loại tiền.` ).
        ENDIF.
      ENDIF.

      APPEND VALUE #( bukrs     = i_bukrs
                      gjahr     = i_gjahr
                      src_type  = <fs_req>-src_type
                      src_docno = <fs_req>-src_docno ) TO lt_mem.
    ENDLOOP.

    r_gom_no = next_number( i_bukrs = i_bukrs i_gjahr = i_gjahr ).

    DATA lv_ts TYPE timestampl.
    GET TIME STAMP FIELD lv_ts.
    LOOP AT lt_mem ASSIGNING FIELD-SYMBOL(<fs_mem>).
      <fs_mem>-gom_no     = r_gom_no.
      <fs_mem>-created_by = sy-uname.
      <fs_mem>-created_at = lv_ts.
    ENDLOOP.
    INSERT ztb_hddt_gom FROM TABLE lt_mem.
    IF sy-subrc <> 0.
      zcx_hddt_error=>raise_text( |Không ghi được bảng ZTB_HDDT_GOM cho { r_gom_no }.| ).
    ENDIF.

    " Đánh dấu GOM_NO trên từng chứng từ thành viên (tạo dòng sổ nếu chưa có)
    DATA(lo_log) = NEW zcl_hddt_log( ).
    LOOP AT it_requests ASSIGNING <fs_req>.
      lo_log->set_gom_no( is_request = <fs_req> i_gom_no = r_gom_no ).
    ENDLOOP.

  ENDMETHOD.


  METHOD cancel.

    DATA(lt_mem) = members( i_bukrs = i_bukrs i_gjahr = i_gjahr i_gom_no = i_gom_no ).
    IF lt_mem IS INITIAL.
      zcx_hddt_error=>raise_text( |Chứng từ gom { i_gom_no } không tồn tại hoặc đã gỡ.| ).
    ENDIF.

    " Hoá đơn gom đã phát hành thì không gỡ
    DATA(ls_reg) = zcl_hddt_log=>read_invoice( i_bukrs     = i_bukrs
                                               i_gjahr     = i_gjahr
                                               i_src_type  = gc_src_type
                                               i_src_docno = i_gom_no ).
    IF ls_reg-status IS NOT INITIAL
       AND ls_reg-status <> zif_hddt_types=>gc_status-not_sent
       AND ls_reg-status <> zif_hddt_types=>gc_status-rejected
       AND ls_reg-status <> zif_hddt_types=>gc_status-error.
      zcx_hddt_error=>raise_text(
        |Không thể gỡ gom: hoá đơn gom { i_gom_no } đang ở trạng thái { ls_reg-status }.| ).
    ENDIF.

    DATA lv_ts TYPE timestampl.
    GET TIME STAMP FIELD lv_ts.
    UPDATE ztb_hddt_gom
      SET xcancel   = 'X',
          cancel_by = @sy-uname,
          cancel_at = @lv_ts
      WHERE bukrs  = @i_bukrs
        AND gjahr  = @i_gjahr
        AND gom_no = @i_gom_no.

    DATA(lo_log) = NEW zcl_hddt_log( ).
    LOOP AT lt_mem ASSIGNING FIELD-SYMBOL(<fs_mem>).
      lo_log->set_gom_no( is_request = VALUE #( bukrs     = i_bukrs
                                                gjahr     = <fs_mem>-gjahr
                                                src_type  = <fs_mem>-src_type
                                                src_docno = <fs_mem>-src_docno )
                          i_gom_no   = space ).
    ENDLOOP.

    " Dòng sổ của chính hoá đơn gom (chưa phát hành) -> xoá
    IF ls_reg-created_at IS NOT INITIAL.
      DELETE FROM ztb_hddt_inv
        WHERE bukrs     = @i_bukrs
          AND gjahr     = @i_gjahr
          AND src_type  = @gc_src_type
          AND src_docno = @i_gom_no.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
