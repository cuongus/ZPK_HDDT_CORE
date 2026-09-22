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
*              Gỡ gom: đánh dấu XCANCEL, xoá GOM_NO trên thành viên.
*              Không dùng number range object (SNRO) để package tự đủ
*              qua abapGit; khoá bằng lock object EZTB_HDDT_GOM khi cấp
*              số và khi gỡ gom.
*
*              [Bộ mã trạng thái - FS dùng số khác chương trình]
*              FS MAG đánh số 01..99, chương trình đang chạy bộ 00..90.
*              CHECK_STATUS đọc theo bảng quy đổi dưới đây, nên đọc FS
*              và đọc code phải nhớ cặp số tương ứng:
*                FS 01 Lập                 -> 00 NOT_SENT
*                FS 02 Hoá đơn nháp        -> 20 WAIT_SEQ
*                                             (10 SENT, 30 WAIT_APPR cùng nhóm)
*                FS 03 Đã phát hành        -> 40 ISSUED
*                FS 04 Lỗi tích hợp        -> 90 ERROR
*                FS 05 Đã huỷ              -> 80 CANCELLED
*                FS 06 Đã huỷ HĐ gom       -> không có mã riêng, nhận biết
*                                             bằng GOM_NO đã có giá trị
*                FS 07 Đã bị điều chỉnh    -> 60 ADJUSTED
*                FS 08 Đã bị thay thế      -> 70 REPLACED
*                FS 10 CQT từ chối         -> 45 REJECTED
*                FS 99 CQT đã cấp mã       -> 50 CODED
* Tham Số    : CREATE( i_bukrs i_gjahr it_requests ) -> gom_no
*              CANCEL( i_bukrs i_gjahr i_gom_no )
*              CHECK_STATUS( i_status i_gom_no i_docno i_ungom )
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       07/09/2026    cuongus - CuongUS        abapGit     Tạo mới
* 1.1       14/09/2026    cuongus - CuongUS        abapGit     FS 3.6.7/3.6.8:
*                                                             CHECK_STATUS ra
*                                                             message riêng cho
*                                                             từng trạng thái,
*                                                             kiểm cả thành viên
*                                                             khi gỡ gom, ghi
*                                                             log gom / gỡ gom
* 1.2       22/09/2026    cuongus - CuongUS        abapGit     Thay khoá chung
*                                                             ENQUEUE_E_TABLE
*                                                             bằng lock object
*                                                             riêng
*                                                             EZTB_HDDT_GOM;
*                                                             khoá cả thao tác
*                                                             gỡ gom theo số gom
* 1.3       22/09/2026    cuongus - CuongUS        abapGit     CREATE và CANCEL
*                                                             khoá thêm sổ đăng
*                                                             ký của từng chứng
*                                                             từ thành viên, nhả
*                                                             lại khi khoá hụt
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

    "! FS 3.6.7 / 3.6.8: điều kiện trạng thái khi bấm nút Gom HĐ và
    "! Huỷ Gom HĐ. Gọi được từ cả màn hình (chặn ngay lúc bấm nút) lẫn
    "! lớp nghiệp vụ (chặn lúc ghi), để hai chỗ không lệch luật nhau.
    "! @parameter i_status | trạng thái trên sổ đăng ký; rỗng = chưa có dòng sổ
    "! @parameter i_gom_no | số hoá đơn gom hiện có của chứng từ
    "! @parameter i_docno  | số chứng từ, chỉ để ghép vào message
    "! @parameter i_ungom  | X = đang gỡ gom, ' ' = đang gom
    CLASS-METHODS check_status
      IMPORTING i_status TYPE zde_hddt_status
                i_gom_no TYPE zde_hddt_docno OPTIONAL
                i_docno  TYPE zde_hddt_docno OPTIONAL
                i_ungom  TYPE abap_bool DEFAULT abap_false
      RAISING   zcx_hddt_error .

  PROTECTED SECTION.
  PRIVATE SECTION.

    "! Nhả khoá EZTB_HDDT_GOM của một số gom. Gom vào một chỗ vì CANCEL
    "! phải nhả ở ba đường: khoá sổ hụt, exception, và thành công.
    CLASS-METHODS unlock_gom
      IMPORTING i_bukrs  TYPE bukrs
                i_gjahr  TYPE gjahr
                i_gom_no TYPE zde_hddt_docno .

    "! Thân của CREATE, chạy TRONG khoá sổ đăng ký của cả nhóm thành viên.
    METHODS create_internal
      IMPORTING i_bukrs         TYPE bukrs
                i_gjahr         TYPE gjahr
                it_requests     TYPE zif_hddt_types=>ty_t_request
      RETURNING VALUE(r_gom_no) TYPE zde_hddt_docno
      RAISING   zcx_hddt_error .

    "! Thân của CANCEL, chạy TRONG khoá EZTB_HDDT_GOM. Tách ra để CANCEL
    "! chỉ còn khoá - gọi - nhả khoá, nhả đúng một chỗ cho cả đường
    "! thành công lẫn đường raise exception.
    METHODS cancel_internal
      IMPORTING i_bukrs  TYPE bukrs
                i_gjahr  TYPE gjahr
                i_gom_no TYPE zde_hddt_docno
      RAISING   zcx_hddt_error .

    "! Ghi ZTB_HDDT_LOG cho thao tác gom / gỡ gom. Gom và gỡ gom không
    "! gọi API nên không có dòng log nào tự sinh; không ghi ở đây thì
    "! sau này không truy được ai gỡ gom chứng từ nào, lúc nào.
    METHODS log_action
      IMPORTING i_bukrs     TYPE bukrs
                i_gjahr     TYPE gjahr
                i_gom_no    TYPE zde_hddt_docno
                i_action    TYPE zde_hddt_action
                it_members  TYPE ty_t_member .

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

    " Khoá theo công ty + năm để hai người gom cùng lúc không trùng số.
    " Đối số khoá có tính tiền tố: để trống GOM_NO trở xuống là khoá cả
    " dải số gom của công ty + năm đó — đúng phạm vi cần cho MAX( gom_no ).
    " Dùng lock object riêng EZTB_HDDT_GOM thay cho ENQUEUE_E_TABLE chung:
    " E_TABLE khoá theo chuỗi VARKEY tự ghép nên sai một ký tự là khoá
    " hụt mà không ai báo, và nó là lock object của SAP, dùng chung với
    " mọi bảng khác đang được SM30 bảo trì.
    CALL FUNCTION 'ENQUEUE_EZTB_HDDT_GOM'
      EXPORTING
        mode_ztb_hddt_gom = 'E'
        mandt             = sy-mandt
        bukrs             = i_bukrs
        gjahr             = i_gjahr
        _scope            = '1'
        _wait             = 'X'
      EXCEPTIONS
        foreign_lock      = 1
        system_failure    = 2
        OTHERS            = 3.
    IF sy-subrc = 1.
      zcx_hddt_error=>raise_text(
        |Người dùng { sy-msgv1 } đang cấp số chứng từ gom cho { i_bukrs }/{ i_gjahr }, thử lại sau.| ).
    ELSEIF sy-subrc <> 0.
      zcx_hddt_error=>raise_text( `Không khoá được ZTB_HDDT_GOM để cấp số chứng từ gom.` ).
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

    " _SCOPE = '1': khoá thuộc chương trình hội thoại, COMMIT WORK không
    " tự nhả nên phải DEQUEUE tường minh ở đây. Nhả ngay sau khi đã lấy
    " được số: phần ghi bảng phía sau đã có khoá theo số gom riêng.
    CALL FUNCTION 'DEQUEUE_EZTB_HDDT_GOM'
      EXPORTING
        mode_ztb_hddt_gom = 'E'
        mandt             = sy-mandt
        bukrs             = i_bukrs
        gjahr             = i_gjahr
        _scope            = '1'.

  ENDMETHOD.


  METHOD check_status.

    DATA lv_doc  TYPE string.
    DATA lv_text TYPE string.

    lv_doc = |{ i_docno ALPHA = OUT }|.
    CONDENSE lv_doc.

    " FS 06: chứng từ đã thuộc một hoá đơn gom. Gom lần nữa thì chặn,
    " còn gỡ gom thì đây chính là điều kiện BẮT BUỘC phải có.
    IF i_ungom = abap_false AND i_gom_no IS NOT INITIAL.
      zcx_hddt_error=>raise_text( |Chứng từ { lv_doc } đã được gom vào { i_gom_no }.| ).
    ENDIF.
    IF i_ungom = abap_true AND i_gom_no IS INITIAL.
      zcx_hddt_error=>raise_text( |Chứng từ { lv_doc } chưa được gom.| ).
    ENDIF.

    CASE i_status.

        " FS 01 - Lập và FS 10 - CQT từ chối: cho gom và cho gỡ gom.
        " Trạng thái rỗng = chưa có dòng sổ đăng ký, tính như FS 01.
      WHEN space
        OR zif_hddt_types=>gc_status-not_sent
        OR zif_hddt_types=>gc_status-rejected.
        RETURN.

        " FS 02 - Hoá đơn nháp. Bộ mã đang chạy tách làm ba: 10 đã gửi,
        " 20 chờ cấp số, 30 chờ duyệt - cùng nghĩa "đã có bản trên hệ
        " thống HDDT", nên chặn như nhau.
      WHEN zif_hddt_types=>gc_status-sent
        OR zif_hddt_types=>gc_status-wait_seq
        OR zif_hddt_types=>gc_status-wait_appr.
        lv_text = COND #(
          WHEN i_ungom = abap_true
          THEN `Không thể gỡ gom chứng từ đang có hoá đơn nháp trên hệ thống HDDT. `
            && `Bấm "Hủy HĐ nháp" trước khi gỡ gom.`
          ELSE `Không thể gom chứng từ đang có hoá đơn nháp trên hệ thống HDDT. `
            && `Bấm "Hủy HĐ nháp" trước khi gom.` ).

        " FS 03 - Đã phát hành và FS 99 - CQT đã cấp mã
      WHEN zif_hddt_types=>gc_status-issued
        OR zif_hddt_types=>gc_status-coded.
        lv_text = COND #( WHEN i_ungom = abap_true
                          THEN `Không thể gỡ gom hoá đơn đã phát hành.`
                          ELSE `Không thể gom hoá đơn đã phát hành.` ).

        " FS 04 - Lỗi tích hợp
      WHEN zif_hddt_types=>gc_status-error.
        lv_text = COND #( WHEN i_ungom = abap_true
                          THEN `Không thể gỡ gom hoá đơn đang tích hợp phát hành.`
                          ELSE `Không thể gom hoá đơn đang tích hợp phát hành.` ).

        " FS 05 - Đã huỷ
      WHEN zif_hddt_types=>gc_status-cancelled.
        lv_text = COND #( WHEN i_ungom = abap_true
                          THEN `Không thể gỡ gom chứng từ huỷ.`
                          ELSE `Không thể gom chứng từ huỷ.` ).

        " FS 07 - Hoá đơn đã bị điều chỉnh
      WHEN zif_hddt_types=>gc_status-adjusted.
        lv_text = COND #( WHEN i_ungom = abap_true
                          THEN `Không thể gỡ gom chứng từ đã bị điều chỉnh.`
                          ELSE `Không thể gom chứng từ điều chỉnh.` ).

        " FS 08 - Hoá đơn đã bị thay thế
      WHEN zif_hddt_types=>gc_status-replaced.
        lv_text = COND #( WHEN i_ungom = abap_true
                          THEN `Không thể gỡ gom chứng từ đã bị thay thế.`
                          ELSE `Không thể gom chứng từ bị thay thế.` ).

      WHEN OTHERS.
        lv_text = COND #( WHEN i_ungom = abap_true
                          THEN |Không thể gỡ gom chứng từ ở trạng thái { i_status }.|
                          ELSE |Không thể gom chứng từ ở trạng thái { i_status }.| ).

    ENDCASE.

    zcx_hddt_error=>raise_text( |{ lv_text } (chứng từ { lv_doc })| ).

  ENDMETHOD.


  METHOD log_action.

    DATA lv_prov TYPE zde_hddt_prov.
    DATA lv_list TYPE string.

    " Không có nhà cung cấp hoạt động thì vẫn phải ghi được log: gom /
    " gỡ gom là thao tác nội bộ, không phụ thuộc nhà cung cấp nào.
    TRY.
        lv_prov = zcl_hddt_config=>get_instance( )->get_active_provider( i_bukrs ).
      CATCH zcx_hddt_error.
        CLEAR lv_prov.
    ENDTRY.

    LOOP AT it_members ASSIGNING FIELD-SYMBOL(<fs_m>).
      lv_list = COND #( WHEN lv_list IS INITIAL
                        THEN |{ <fs_m>-src_type }/{ <fs_m>-src_docno }|
                        ELSE |{ lv_list },{ <fs_m>-src_type }/{ <fs_m>-src_docno }| ).
    ENDLOOP.

    DATA(lv_ungom) = xsdbool( i_action = zif_hddt_types=>gc_action-ungom_invoice ).
    DATA(lv_cnt)   = |{ lines( it_members ) }|.
    DATA(lv_verb)  = COND string( WHEN lv_ungom = abap_true THEN `Gỡ gom` ELSE `Gom` ).
    DATA(lv_mtxt)  = COND string(
      WHEN lv_ungom = abap_true
      THEN |Gỡ chứng từ khỏi hoá đơn gom { i_gom_no }|
      ELSE |Gom chứng từ vào hoá đơn gom { i_gom_no }| ).
    DATA(lo_log)   = NEW zcl_hddt_log( ).

    " Một dòng cho chính hoá đơn gom: đọc log theo số gom là ra ngay ai
    " gom / ai gỡ, mấy chứng từ, lúc nào.
    lo_log->log_call(
      is_request = VALUE #( bukrs     = i_bukrs
                            gjahr     = i_gjahr
                            src_type  = gc_src_type
                            src_docno = i_gom_no )
      i_action   = i_action
      i_provider = lv_prov
      is_call    = VALUE #( req_body = lv_list )
      is_result  = VALUE #( success = abap_true
                            msgty   = 'S'
                            message = |{ lv_verb } { lv_cnt } chứng từ - hoá đơn gom { i_gom_no }| ) ).

    " Và một dòng cho từng thành viên: người dùng thường tra log theo số
    " chứng từ kế toán chứ không nhớ số gom.
    LOOP AT it_members ASSIGNING <fs_m>.
      lo_log->log_call(
        is_request = VALUE #( bukrs     = i_bukrs
                              gjahr     = <fs_m>-gjahr
                              src_type  = <fs_m>-src_type
                              src_docno = <fs_m>-src_docno )
        i_action   = i_action
        i_provider = lv_prov
        is_call    = VALUE #( )
        is_result  = VALUE #( success = abap_true
                              msgty   = 'S'
                              message = CONV #( lv_mtxt ) ) ).
    ENDLOOP.

  ENDMETHOD.


  METHOD create.

    IF lines( it_requests ) < 2.
      zcx_hddt_error=>raise_text( `Chọn ít nhất 2 chứng từ cần gom.` ).
    ENDIF.

    " CREATE_INTERNAL đọc trạng thái + số gom của TỪNG thành viên rồi mới
    " ghi GOM_NO lên chúng, nên phải giữ khoá sổ đăng ký của cả nhóm suốt
    " thao tác. Khoá hụt một chứng từ thì LOCK_INVOICES nhả lại những cái
    " đã lấy, không để khoá treo lửng.
    DATA lt_keys TYPE zcl_hddt_log=>ty_t_inv_key.
    LOOP AT it_requests ASSIGNING FIELD-SYMBOL(<fs_k>).
      APPEND zcl_hddt_log=>key_of( <fs_k> ) TO lt_keys.
    ENDLOOP.

    zcl_hddt_log=>lock_invoices( EXPORTING it_keys   = lt_keys
                                 IMPORTING e_ok      = DATA(lv_ok)
                                           es_failed = DATA(ls_failed)
                                           e_user    = DATA(lv_user) ).
    IF lv_ok = abap_false.
      zcx_hddt_error=>raise_text(
        |Chứng từ { ls_failed-src_docno ALPHA = OUT } đang được user { lv_user } | &&
        |xử lý, chưa gom được.| ).
    ENDIF.

    TRY.
        r_gom_no = create_internal( i_bukrs     = i_bukrs
                                    i_gjahr     = i_gjahr
                                    it_requests = it_requests ).
      CLEANUP.
        zcl_hddt_log=>unlock_invoices( lt_keys ).
    ENDTRY.

    zcl_hddt_log=>unlock_invoices( lt_keys ).

  ENDMETHOD.


  METHOD create_internal.

    DATA lv_kunnr TYPE kunnr.
    DATA lv_waers TYPE waers.
    DATA lt_mem   TYPE STANDARD TABLE OF ztb_hddt_gom WITH EMPTY KEY.

    LOOP AT it_requests ASSIGNING FIELD-SYMBOL(<fs_req>).
      " FS 3.6.7 tách hai lỗi: khác công ty và khác năm không cùng câu chữ
      IF <fs_req>-bukrs <> i_bukrs.
        zcx_hddt_error=>raise_text( `Mã công ty không đồng nhất để gom.` ).
      ENDIF.
      IF <fs_req>-gjahr <> i_gjahr.
        zcx_hddt_error=>raise_text( `Năm chứng từ không đồng nhất để gom.` ).
      ENDIF.
      IF <fs_req>-src_type = gc_src_type.
        zcx_hddt_error=>raise_text( `Không gom lồng chứng từ gom.` ).
      ENDIF.

      " Trạng thái + số gom theo bảng điều kiện FS 3.6.7
      DATA(ls_reg) = zcl_hddt_log=>read_invoice( i_bukrs     = <fs_req>-bukrs
                                                 i_gjahr     = <fs_req>-gjahr
                                                 i_src_type  = <fs_req>-src_type
                                                 i_src_docno = <fs_req>-src_docno ).
      check_status( i_status = ls_reg-status
                    i_gom_no = ls_reg-gom_no
                    i_docno  = <fs_req>-src_docno ).

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
    DATA lt_log_mem TYPE ty_t_member.
    LOOP AT it_requests ASSIGNING <fs_req>.
      lo_log->set_gom_no( is_request = <fs_req> i_gom_no = r_gom_no ).
      APPEND VALUE #( src_type  = <fs_req>-src_type
                      src_docno = <fs_req>-src_docno
                      gjahr     = <fs_req>-gjahr ) TO lt_log_mem.
    ENDLOOP.

    log_action( i_bukrs    = i_bukrs
                i_gjahr    = i_gjahr
                i_gom_no   = r_gom_no
                i_action   = zif_hddt_types=>gc_action-gom_invoice
                it_members = lt_log_mem ).

  ENDMETHOD.


  METHOD cancel.

    " Gỡ gom đọc trạng thái của hoá đơn gom + từng thành viên rồi mới
    " quyết định ghi, nên phải khoá đúng số gom đó suốt cả thao tác.
    " Không khoá thì hai người cùng gỡ một nhóm: cả hai đều thấy trạng
    " thái cho phép, cả hai đều xoá GOM_NO, dòng log ra hai lần.
    CALL FUNCTION 'ENQUEUE_EZTB_HDDT_GOM'
      EXPORTING
        mode_ztb_hddt_gom = 'E'
        mandt             = sy-mandt
        bukrs             = i_bukrs
        gjahr             = i_gjahr
        gom_no            = i_gom_no
        _scope            = '1'
      EXCEPTIONS
        foreign_lock      = 1
        system_failure    = 2
        OTHERS            = 3.
    IF sy-subrc = 1.
      zcx_hddt_error=>raise_text(
        |Hoá đơn gom { i_gom_no } đang được user { sy-msgv1 } xử lý.| ).
    ELSEIF sy-subrc <> 0.
      zcx_hddt_error=>raise_text( |Không khoá được hoá đơn gom { i_gom_no }.| ).
    ENDIF.

    " Khoá thêm sổ đăng ký của hoá đơn gom và của từng thành viên: khoá
    " EZTB_HDDT_GOM ở trên chỉ chặn người khác gom/gỡ cùng nhóm, KHÔNG
    " chặn người khác phát hành riêng một chứng từ thành viên.
    DATA lt_keys TYPE zcl_hddt_log=>ty_t_inv_key.
    APPEND VALUE #( bukrs     = i_bukrs
                    gjahr     = i_gjahr
                    src_type  = gc_src_type
                    src_docno = i_gom_no ) TO lt_keys.
    LOOP AT members( i_bukrs  = i_bukrs
                     i_gjahr  = i_gjahr
                     i_gom_no = i_gom_no ) ASSIGNING FIELD-SYMBOL(<fs_k>).
      APPEND VALUE #( bukrs     = i_bukrs
                      gjahr     = <fs_k>-gjahr
                      src_type  = <fs_k>-src_type
                      src_docno = <fs_k>-src_docno ) TO lt_keys.
    ENDLOOP.

    zcl_hddt_log=>lock_invoices( EXPORTING it_keys   = lt_keys
                                 IMPORTING e_ok      = DATA(lv_ok)
                                           es_failed = DATA(ls_failed)
                                           e_user    = DATA(lv_user) ).
    IF lv_ok = abap_false.
      unlock_gom( i_bukrs = i_bukrs i_gjahr = i_gjahr i_gom_no = i_gom_no ).
      zcx_hddt_error=>raise_text(
        |Chứng từ { ls_failed-src_docno ALPHA = OUT } đang được user { lv_user } | &&
        |xử lý, chưa gỡ gom được.| ).
    ENDIF.

    " CLEANUP chạy khi exception bay ra khỏi TRY, nên khoá được nhả cả
    " khi CANCEL_INTERNAL báo lỗi trạng thái.
    TRY.
        cancel_internal( i_bukrs  = i_bukrs
                         i_gjahr  = i_gjahr
                         i_gom_no = i_gom_no ).
      CLEANUP.
        zcl_hddt_log=>unlock_invoices( lt_keys ).
        unlock_gom( i_bukrs = i_bukrs i_gjahr = i_gjahr i_gom_no = i_gom_no ).
    ENDTRY.

    zcl_hddt_log=>unlock_invoices( lt_keys ).
    unlock_gom( i_bukrs = i_bukrs i_gjahr = i_gjahr i_gom_no = i_gom_no ).

  ENDMETHOD.


  METHOD unlock_gom.

    CALL FUNCTION 'DEQUEUE_EZTB_HDDT_GOM'
      EXPORTING
        mode_ztb_hddt_gom = 'E'
        mandt             = sy-mandt
        bukrs             = i_bukrs
        gjahr             = i_gjahr
        gom_no            = i_gom_no
        _scope            = '1'.

  ENDMETHOD.


  METHOD cancel_internal.

    DATA(lt_mem) = members( i_bukrs = i_bukrs i_gjahr = i_gjahr i_gom_no = i_gom_no ).
    IF lt_mem IS INITIAL.
      zcx_hddt_error=>raise_text( |Chứng từ gom { i_gom_no } không tồn tại hoặc đã gỡ.| ).
    ENDIF.

    " Bảng điều kiện trạng thái FS 3.6.8 cho chính hoá đơn gom. Truyền
    " I_GOM_NO để CHECK_STATUS không báo "chưa được gom": chứng từ gom
    " tự nó là số gom.
    DATA(ls_reg) = zcl_hddt_log=>read_invoice( i_bukrs     = i_bukrs
                                               i_gjahr     = i_gjahr
                                               i_src_type  = gc_src_type
                                               i_src_docno = i_gom_no ).
    check_status( i_status = ls_reg-status
                  i_gom_no = i_gom_no
                  i_docno  = i_gom_no
                  i_ungom  = abap_true ).

    " Từng chứng từ thành viên cũng phải cho gỡ. Thiếu vòng này thì một
    " thành viên đã phát hành riêng lẻ vẫn bị gỡ khỏi nhóm.
    LOOP AT lt_mem ASSIGNING FIELD-SYMBOL(<fs_chk>).
      DATA(ls_mreg) = zcl_hddt_log=>read_invoice( i_bukrs     = i_bukrs
                                                  i_gjahr     = <fs_chk>-gjahr
                                                  i_src_type  = <fs_chk>-src_type
                                                  i_src_docno = <fs_chk>-src_docno ).
      check_status( i_status = ls_mreg-status
                    i_gom_no = i_gom_no
                    i_docno  = <fs_chk>-src_docno
                    i_ungom  = abap_true ).
    ENDLOOP.

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

    " Ghi log SAU khi đã xoá GOM_NO: dòng log là bằng chứng duy nhất còn
    " lại của nhóm vừa gỡ, vì ZTB_HDDT_INV không giữ số gom nữa.
    log_action( i_bukrs    = i_bukrs
                i_gjahr    = i_gjahr
                i_gom_no   = i_gom_no
                i_action   = zif_hddt_types=>gc_action-ungom_invoice
                it_members = lt_mem ).

  ENDMETHOD.

ENDCLASS.
