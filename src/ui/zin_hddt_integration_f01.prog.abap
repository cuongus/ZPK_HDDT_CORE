*=====================================================================
* Tên/Mã     : ZIN_HDDT_INTEGRATION_F01
* Mô tả chung: Lớp local điều khiển ALV GRID (LCL_APP) và form routine của
*              ZPG_HDDT_INTEGRATION theo FS MAG v0.5 mục 3.6:
*                Tích hợp HĐ   -> ZCL_HDDT_SERVICE->CREATE_DRAFT
*                Hủy HĐ nháp   -> DELETE_DRAFT (tra cứu trước khi lỗi)
*                Phát hành HĐ  -> ISSUE_INVOICE (issue / apprs / đồng bộ)
*                Cập nhật HĐ   -> SEARCH_INVOICE (+ ghi ngược BKPF)
*                HĐ Điều chỉnh -> popup HĐ gốc + loại ĐC -> ATTACH_ORIGINAL
*                Send Email    -> GET_INVOICE_FILE(pdf) + ZCL_HDDT_MAIL
*                Gom HĐ / Huỷ Gom HĐ -> ZCL_HDDT_GOM
*              Toàn bộ điều kiện trạng thái do engine kiểm (CHECK_ACTION)
*              nên job nền và màn hình cùng một luật. Lớp này chỉ lo
*              màn hình, popup, phân quyền theo chức năng.
* Tham Số    : Xem từng method / FORM
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       28/08/2026    cuongus - CuongUS        abapGit     Tạo mới
* 1.1       03/09/2026    cuongus - CuongUS        abapGit     Popup chọn
*                         hoá đơn gốc, truyền chứng từ gốc cho engine
* 1.3       09/09/2026    cuongus - CuongUS        abapGit     Đổi màn hình
*                         danh sách từ CL_SALV_TABLE sang CL_GUI_ALV_GRID +
*                         docking trên dynpro 0100: 12 nút khai trong code
*                         qua event TOOLBAR, GUI status chỉ cần Back/Exit/
*                         Cancel. Field catalog lấy từ metadata của SALV.
* 1.2       07/09/2026    cuongus - CuongUS        abapGit     FS MAG v0.5:
*                         8 nút nghiệp vụ, email, gom, sửa ngày/giờ,
*                         phát hành tự động, kiểm quyền theo chức năng
*=====================================================================

CLASS lcl_app DEFINITION FINAL CREATE PUBLIC.

  PUBLIC SECTION.

    METHODS run.
    "! FS 3.6.9: phát hành tự động bằng background job
    METHODS run_auto.

    "! PBO / PAI của dynpro 0100 — gọi từ hai module trong include này
    METHODS pbo_0100.
    METHODS pai_0100
      IMPORTING i_ucomm TYPE syucomm.

    "! 12 nút nghiệp vụ thêm vào toolbar của grid (không cần GUI status)
    METHODS on_toolbar
      FOR EVENT toolbar OF cl_gui_alv_grid
      IMPORTING e_object.

    METHODS on_user_command
      FOR EVENT user_command OF cl_gui_alv_grid
      IMPORTING e_ucomm.

    METHODS on_hotspot
      FOR EVENT hotspot_click OF cl_gui_alv_grid
      IMPORTING e_row_id e_column_id.

  PRIVATE SECTION.

    DATA mo_dock    TYPE REF TO cl_gui_docking_container.
    DATA mo_grid    TYPE REF TO cl_gui_alv_grid.
    DATA mt_fcat    TYPE lvc_t_fcat.
    DATA mo_service TYPE REF TO zcl_hddt_service.

    METHODS select_data.

    "! Loại nguồn cần đọc: theo s_srct, để trống thì lấy mọi loại đang
    "! hoạt động trong ZTB_HDDT_SRC của công ty.
    METHODS src_types
      RETURNING VALUE(rt_type) TYPE gty_t_srctype.
    METHODS reload.

    "! Field catalog: lấy metadata từ SALV (nhãn cột theo data element) rồi
    "! đắp thêm cột icon / hotspot / cột ẩn.
    METHODS build_fcat.
    METHODS refresh_grid.

    "! Điều phối mã chức năng của toolbar sang từng nghiệp vụ
    METHODS dispatch
      IMPORTING i_code TYPE syucomm.
    METHODS fill_row_from_registry
      IMPORTING is_reg TYPE ztb_hddt_inv
      CHANGING  cs_alv TYPE gty_alv.
    METHODS refresh_row
      IMPORTING i_index   TYPE i
                is_result TYPE zif_hddt_types=>ty_result.
    METHODS get_selected
      RETURNING VALUE(rt_index) TYPE salv_t_row.
    METHODS check_auth
      IMPORTING i_actvt     TYPE activ_auth
                i_function  TYPE string
      RETURNING VALUE(r_ok) TYPE abap_bool.
    METHODS confirm
      IMPORTING i_title     TYPE string
                i_question  TYPE string
      RETURNING VALUE(r_ok) TYPE abap_bool.

    METHODS do_draft.
    METHODS do_delete_draft.
    METHODS do_issue.
    METHODS do_update.
    METHODS do_adjust_ref.
    METHODS do_mail.
    METHODS do_gom.
    METHODS do_ungom.
    METHODS do_edit.
    METHODS do_getfile.
    METHODS show_payload.
    METHODS show_log.

    METHODS map_light
      IMPORTING i_status      TYPE zde_hddt_status
                i_msgty       TYPE symsgty
      RETURNING VALUE(r_icon) TYPE gty_icon.
    METHODS status_text
      IMPORTING i_status      TYPE zde_hddt_status
      RETURNING VALUE(r_text) TYPE gty_sttext.
    METHODS adj_code_of
      IMPORTING is_reg        TYPE ztb_hddt_inv
      RETURNING VALUE(r_code) TYPE gty_adjcode.

ENDCLASS.

" Hai module của dynpro 0100 nằm ngoài lớp nên cần tham chiếu toàn cục
DATA go_app TYPE REF TO lcl_app.


CLASS lcl_app IMPLEMENTATION.

  METHOD run.

    mo_service = zcl_hddt_service=>get_instance( ).

    select_data( ).
    IF gt_alv IS INITIAL.
      MESSAGE s001(zms_hddt) DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.

    build_fcat( ).
    CALL SCREEN 100.

  ENDMETHOD.


  METHOD run_auto.

    " FS 3.6.9: 01 -> create-appr-inv (CREATE_INVOICE); 02 -> issue-invoice;
    " 04 -> tra cứu rồi gọi API phù hợp (ISSUE_INVOICE tự xử lý); còn lại
    " bỏ qua và ghi log. Commit từng chứng từ (EXECUTE tự commit).
    mo_service = zcl_hddt_service=>get_instance( ).
    select_data( ).

    DATA lv_ok   TYPE i.
    DATA lv_err  TYPE i.
    DATA lv_skip TYPE i.

    WRITE: / 'Phát hành tự động HĐĐT -', p_bukrs, p_gjahr, sy-datum, sy-uzeit.
    ULINE.

    LOOP AT gt_request ASSIGNING FIELD-SYMBOL(<fs_req>).
      DATA(lv_idx) = sy-tabix.
      DATA(ls_reg) = zcl_hddt_log=>read_invoice( i_bukrs     = <fs_req>-bukrs
                                                 i_gjahr     = <fs_req>-gjahr
                                                 i_src_type  = <fs_req>-src_type
                                                 i_src_docno = <fs_req>-src_docno ).
      DATA(lv_status) = COND zde_hddt_status( WHEN ls_reg-status IS INITIAL
                                              THEN zif_hddt_types=>gc_status-not_sent
                                              ELSE ls_reg-status ).
      DATA ls_result TYPE zif_hddt_types=>ty_result.
      CLEAR ls_result.

      CASE lv_status.
        WHEN zif_hddt_types=>gc_status-not_sent.
          IF <fs_req>-src_info-xreversed = abap_true OR <fs_req>-src_info-xcancel = abap_true.
            lv_skip = lv_skip + 1.
            WRITE: / <fs_req>-src_docno, 'bỏ qua: chứng từ đã đảo/huỷ'.
            CONTINUE.
          ENDIF.
          ls_result = mo_service->create_invoice( is_request = <fs_req> ).
        WHEN zif_hddt_types=>gc_status-wait_seq
          OR zif_hddt_types=>gc_status-wait_appr
          OR zif_hddt_types=>gc_status-error.
          ls_result = mo_service->issue_invoice( is_request = <fs_req> ).
        WHEN OTHERS.
          lv_skip = lv_skip + 1.
          WRITE: / <fs_req>-src_docno, 'bỏ qua: trạng thái', lv_status.
          CONTINUE.
      ENDCASE.

      refresh_row( i_index = lv_idx is_result = ls_result ).
      IF ls_result-success = abap_true.
        lv_ok = lv_ok + 1.
        WRITE: / <fs_req>-src_docno, 'OK  ', ls_result-status, ls_result-serial, ls_result-seq, ls_result-message.
      ELSE.
        lv_err = lv_err + 1.
        WRITE: / <fs_req>-src_docno, 'LỖI ', ls_result-status, ls_result-message.
      ENDIF.
    ENDLOOP.

    ULINE.
    MESSAGE s043(zms_hddt) WITH lv_ok lv_err lv_skip.
    WRITE: / |Thành công { lv_ok }, lỗi { lv_err }, bỏ qua { lv_skip }|.

  ENDMETHOD.


  METHOD src_types.

    SELECT DISTINCT src_type
      FROM ztb_hddt_src
      WHERE ( bukrs = @p_bukrs OR bukrs = @space )
        AND src_type IN @s_srct
        AND xactive  = @abap_true
      ORDER BY src_type
      INTO TABLE @rt_type.

  ENDMETHOD.


  METHOD select_data.

    CLEAR: gt_alv, gt_request.

    DATA(lt_type) = src_types( ).
    IF lt_type IS INITIAL.
      MESSAGE 'Chưa cấu hình lớp đọc nguồn nào cho công ty này (ZTB_HDDT_SRC).'
              TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    DATA(ls_sel) = VALUE zif_hddt_source=>ty_selection(
      bukrs     = p_bukrs
      gjahr     = p_gjahr
      r_docno   = CORRESPONDING #( s_belnr[] )
      r_budat   = CORRESPONDING #( s_budat[] )
      r_bldat   = CORRESPONDING #( s_bldat[] )
      r_cpudt   = CORRESPONDING #( s_cpudt[] )
      r_blart   = CORRESPONDING #( s_blart[] )
      r_vbeln   = CORRESPONDING #( s_vbeln[] )
      r_kunnr   = CORRESPONDING #( s_kunnr[] )
      r_usnam   = CORRESPONDING #( s_usnam[] )
      r_seq     = CORRESPONDING #( s_seq[] )
      r_gom     = CORRESPONDING #( s_gom[] )
      r_status  = CORRESPONDING #( s_stat[] )
      inv_type  = p_ityp
      xreversed = p_rever ).

    " Một loại nguồn lỗi cấu hình thì vẫn hiện các loại còn lại
    DATA lv_err TYPE string.
    LOOP AT lt_type ASSIGNING FIELD-SYMBOL(<fs_type>).
      TRY.
          DATA(lo_source) = zcl_hddt_factory=>get_source( i_bukrs    = p_bukrs
                                                          i_src_type = <fs_type> ).
          APPEND LINES OF lo_source->select_documents( ls_sel ) TO gt_request.
        CATCH zcx_hddt_error INTO DATA(lx).
          lv_err = COND #( WHEN lv_err IS INITIAL
                           THEN |{ <fs_type> }: { lx->get_text_long( ) }|
                           ELSE |{ lv_err } / { <fs_type> }| ).
      ENDTRY.
    ENDLOOP.
    IF lv_err IS NOT INITIAL.
      MESSAGE lv_err TYPE 'S' DISPLAY LIKE 'W'.
    ENDIF.

    " Ghép sổ đăng ký vào danh sách hiển thị
    SELECT * FROM ztb_hddt_inv
      WHERE bukrs = @p_bukrs
        AND gjahr = @p_gjahr
      INTO TABLE @DATA(lt_reg).

    LOOP AT gt_request ASSIGNING FIELD-SYMBOL(<fs_req>).
      IF p_prov IS NOT INITIAL.
        <fs_req>-provider = p_prov.
      ENDIF.

      APPEND INITIAL LINE TO gt_alv ASSIGNING FIELD-SYMBOL(<fs_alv>).
      <fs_alv>-bukrs      = <fs_req>-bukrs.
      <fs_alv>-gjahr      = <fs_req>-gjahr.
      <fs_alv>-src_type   = <fs_req>-src_type.
      <fs_alv>-src_docno  = <fs_req>-src_docno.
      <fs_alv>-blart      = <fs_req>-src_info-blart.
      <fs_alv>-budat      = <fs_req>-src_info-budat.
      <fs_alv>-bldat      = <fs_req>-src_info-bldat.
      <fs_alv>-awkey      = <fs_req>-src_info-awkey.
      <fs_alv>-inv_date   = <fs_req>-invoice-header-inv_date.
      <fs_alv>-inv_time   = <fs_req>-invoice-header-inv_time.
      IF <fs_req>-src_info-xreversed = abap_true
         OR <fs_req>-src_info-xcancel = abap_true.
        <fs_alv>-reversed = icon_storno.
      ENDIF.
      READ TABLE <fs_req>-invoice-ext INTO DATA(ls_ext)
           WITH KEY name = 'TAX_RATE_SUMMARY'.
      IF sy-subrc = 0.
        <fs_alv>-tax_summ = ls_ext-value.
      ENDIF.
      <fs_alv>-buyer_code = <fs_req>-invoice-buyer-code.
      <fs_alv>-buyer_name = <fs_req>-invoice-buyer-legal_name.
      <fs_alv>-buyer_addr = <fs_req>-invoice-buyer-address.
      <fs_alv>-buyer_tax  = <fs_req>-invoice-buyer-tax_code.
      <fs_alv>-buyer_mail = <fs_req>-invoice-buyer-email.
      READ TABLE <fs_req>-invoice-payments INDEX 1 INTO DATA(ls_pay).
      IF sy-subrc = 0.
        <fs_alv>-paym = ls_pay-method_name.
      ENDIF.
      <fs_alv>-waers      = <fs_req>-invoice-header-currency.
      <fs_alv>-exch_rate  = <fs_req>-invoice-header-exch_rate.
      <fs_alv>-amount     = <fs_req>-invoice-summary-amount_wo_tax.
      <fs_alv>-vat_amount = <fs_req>-invoice-summary-tax_amount.
      <fs_alv>-total      = <fs_req>-invoice-summary-total.
      <fs_alv>-provider   = <fs_req>-provider.
      <fs_alv>-inv_type   = <fs_req>-invoice-header-inv_type.
      <fs_alv>-status     = zif_hddt_types=>gc_status-not_sent.

      READ TABLE lt_reg INTO DATA(ls_reg)
           WITH KEY bukrs     = <fs_req>-bukrs
                    gjahr     = <fs_req>-gjahr
                    src_type  = <fs_req>-src_type
                    src_docno = <fs_req>-src_docno.
      IF sy-subrc = 0.
        fill_row_from_registry( EXPORTING is_reg = ls_reg CHANGING cs_alv = <fs_alv> ).
      ENDIF.

      <fs_alv>-status_txt = status_text( <fs_alv>-status ).
      <fs_alv>-light      = map_light( i_status = <fs_alv>-status
                                       i_msgty  = <fs_alv>-msgty ).
    ENDLOOP.

  ENDMETHOD.


  METHOD fill_row_from_registry.

    IF is_reg-provider IS NOT INITIAL.
      cs_alv-provider = is_reg-provider.
    ENDIF.
    cs_alv-template   = is_reg-template.
    cs_alv-serial     = is_reg-serial.
    cs_alv-seq        = is_reg-seq.
    cs_alv-issue_date = is_reg-issue_date.
    cs_alv-mscqt      = is_reg-mscqt.
    cs_alv-sec_code   = is_reg-sec_code.
    cs_alv-inv_link   = is_reg-inv_link.
    IF is_reg-status IS NOT INITIAL.
      cs_alv-status   = is_reg-status.
    ENDIF.
    cs_alv-tax_status = is_reg-tax_status.
    cs_alv-message    = is_reg-message.
    cs_alv-ref_docno  = is_reg-ref_docno.
    cs_alv-ref_gjahr  = is_reg-ref_gjahr.
    cs_alv-adj_code   = adj_code_of( is_reg ).
    cs_alv-gom_no     = is_reg-gom_no.
    cs_alv-item_text  = is_reg-item_text.
    IF is_reg-inv_time IS NOT INITIAL AND is_reg-status = zif_hddt_types=>gc_status-not_sent.
      cs_alv-inv_time = is_reg-inv_time.
    ENDIF.
    cs_alv-mail_light = SWITCH #( is_reg-mail_status
                                  WHEN 'S' THEN icon_mail
                                  WHEN 'E' THEN icon_message_error_small
                                  ELSE space ).

  ENDMETHOD.


  METHOD adj_code_of.

    IF is_reg-ref_docno IS INITIAL.
      RETURN.
    ENDIF.
    IF is_reg-adj_type = zif_hddt_types=>gc_adj_type-replace.
      r_code = '5'.
    ELSE.
      r_code = SWITCH #( is_reg-adj_dir WHEN '1' THEN '2'
                                        WHEN '0' THEN '3'
                                        ELSE '4' ).
    ENDIF.

  ENDMETHOD.


  METHOD reload.

    select_data( ).
    refresh_grid( ).

  ENDMETHOD.


  METHOD build_fcat.

    " Field catalog lấy từ metadata của SALV: nhãn cột theo data element,
    " kiểu và độ dài đầy đủ, khỏi phải khai tay 45 cột và không cần
    " structure DDIC riêng. Sau đó chỉ đắp thêm cột icon / hotspot / ẩn.
    CLEAR mt_fcat.
    DATA lo_meta TYPE REF TO cl_salv_table.
    TRY.
        cl_salv_table=>factory( IMPORTING r_salv_table = lo_meta
                                CHANGING  t_table      = gt_alv ).
        mt_fcat = cl_salv_controller_metadata=>get_lvc_fieldcatalog(
                    r_columns      = lo_meta->get_columns( )
                    r_aggregations = lo_meta->get_aggregations( ) ).
      CATCH cx_salv_error INTO DATA(lx_meta).
        MESSAGE lx_meta->get_text( ) TYPE 'S' DISPLAY LIKE 'W'.
    ENDTRY.

    TYPES: BEGIN OF lty_col,
             field  TYPE lvc_fname,
             short  TYPE scrtext_s,
             medium TYPE scrtext_m,
             flag   TYPE gty_adjcode,
           END OF lty_col.
    DATA lt_col TYPE STANDARD TABLE OF lty_col WITH DEFAULT KEY.

    " flag: I = cột icon · H = cột bấm được (link) · T = cột kỹ thuật, ẩn
    lt_col = VALUE #(
      ( field = 'LIGHT'      short = 'TT'        medium = 'Trạng thái'          flag = 'I' )
      ( field = 'MAIL_LIGHT' short = 'Email'     medium = 'Trạng thái email'    flag = 'I' )
      ( field = 'BUKRS'      short = 'Công ty'   medium = 'Mã công ty' )
      ( field = 'GJAHR'      short = 'Năm'       medium = 'Năm tài chính' )
      ( field = 'SRC_TYPE'   short = 'Nguồn'     medium = 'Loại nguồn' )
      ( field = 'SRC_DOCNO'  short = 'Số CT'     medium = 'Số chứng từ' )
      ( field = 'GOM_NO'     short = 'Gom'       medium = 'Số FI gom' )
      ( field = 'BLART'      short = 'Loại CT'   medium = 'Loại chứng từ' )
      ( field = 'BUDAT'      short = 'Ghi sổ'    medium = 'Ngày ghi sổ' )
      ( field = 'BLDAT'      short = 'Ngày CT'   medium = 'Ngày chứng từ' )
      ( field = 'AWKEY'      short = 'Billing'   medium = 'Billing SD' )
      ( field = 'REVERSED'   short = 'Đảo'       medium = 'Đã đảo/huỷ'          flag = 'I' )
      ( field = 'INV_DATE'   short = 'Ngày PH'   medium = 'Ngày phát hành' )
      ( field = 'INV_TIME'   short = 'Giờ PH'    medium = 'Giờ phát hành' )
      ( field = 'BUYER_CODE' short = 'Khách'     medium = 'Khách hàng' )
      ( field = 'BUYER_NAME' short = 'Tên ĐV'    medium = 'Tên đơn vị' )
      ( field = 'BUYER_ADDR' short = 'Địa chỉ'   medium = 'Địa chỉ' )
      ( field = 'BUYER_TAX'  short = 'MST'       medium = 'Mã số thuế' )
      ( field = 'BUYER_MAIL' short = 'Email KH'  medium = 'Email khách hàng' )
      ( field = 'ITEM_TEXT'  short = 'Tên hàng'  medium = 'Tên hàng (nhập tay)' )
      ( field = 'PAYM'       short = 'HTTT'      medium = 'HT thanh toán' )
      ( field = 'WAERS'      short = 'Tiền'      medium = 'Loại tiền' )
      ( field = 'EXCH_RATE'  short = 'Tỷ giá'    medium = 'Tỷ giá' )
      ( field = 'AMOUNT'     short = 'Tiền hàng' medium = 'Thành tiền' )
      ( field = 'VAT_AMOUNT' short = 'Thuế'      medium = 'Tiền thuế' )
      ( field = 'TOTAL'      short = 'Tổng'      medium = 'Tổng tiền' )
      ( field = 'TAX_SUMM'   short = 'Thuế suất' medium = 'Thuế suất' )
      ( field = 'PROVIDER'   short = 'NCC'       medium = 'Nhà cung cấp' )
      ( field = 'INV_TYPE'   short = 'Loại HĐ'   medium = 'Mẫu HĐ phát hành' )
      ( field = 'TEMPLATE'   short = 'Mẫu số'    medium = 'Mẫu hoá đơn' )
      ( field = 'SERIAL'     short = 'Ký hiệu'   medium = 'Ký hiệu hoá đơn' )
      ( field = 'SEQ'        short = 'Số HĐ'     medium = 'Số hoá đơn' )
      ( field = 'ISSUE_DATE' short = 'Ngày TH'   medium = 'Ngày tích hợp' )
      ( field = 'MSCQT'      short = 'Mã CQT'    medium = 'Mã của CQT' )
      ( field = 'SEC_CODE'   short = 'Mã tra'    medium = 'Mã tra cứu' )
      ( field = 'INV_LINK'   short = 'Link'      medium = 'Link tra cứu'        flag = 'H' )
      ( field = 'ADJ_CODE'   short = 'Loại ĐC'   medium = 'Loại điều chỉnh' )
      ( field = 'REF_DOCNO'  short = 'CT gốc'    medium = 'Số chứng từ gốc' )
      ( field = 'REF_GJAHR'  short = 'Năm gốc'   medium = 'Năm chứng từ gốc' )
      ( field = 'STATUS'     short = 'Mã TT'     medium = 'Mã trạng thái' )
      ( field = 'STATUS_TXT' short = 'Diễn giải' medium = 'Diễn giải trạng thái' )
      ( field = 'TAX_STATUS' short = 'TT CQT'    medium = 'TT Cơ quan thuế' )
      ( field = 'MESSAGE'    short = 'Thông báo' medium = 'Thông báo' )
      ( field = 'MSGTY'                                                        flag = 'T' )
      ( field = 'LOG_ID'                                                       flag = 'T' ) ).

    LOOP AT lt_col ASSIGNING FIELD-SYMBOL(<fs_col>).
      ASSIGN mt_fcat[ fieldname = <fs_col>-field ] TO FIELD-SYMBOL(<fs_fcat>).
      IF sy-subrc <> 0.
        " Metadata của SALV không có cột này -> thêm dòng tối thiểu
        APPEND VALUE lvc_s_fcat( fieldname = <fs_col>-field ) TO mt_fcat.
        ASSIGN mt_fcat[ fieldname = <fs_col>-field ] TO <fs_fcat>.
        IF sy-subrc <> 0.
          CONTINUE.
        ENDIF.
      ENDIF.
      IF <fs_col>-medium IS NOT INITIAL.
        <fs_fcat>-scrtext_s = <fs_col>-short.
        <fs_fcat>-scrtext_m = <fs_col>-medium.
        <fs_fcat>-scrtext_l = <fs_col>-medium.
        <fs_fcat>-coltext   = <fs_col>-medium.
      ENDIF.
      CASE <fs_col>-flag.
        WHEN 'I'.
          <fs_fcat>-icon = abap_true.
        WHEN 'H'.
          <fs_fcat>-hotspot = abap_true.
        WHEN 'T'.
          <fs_fcat>-tech = abap_true.
        WHEN OTHERS.
      ENDCASE.
    ENDLOOP.

  ENDMETHOD.


  METHOD pbo_0100.

    SET PF-STATUS gc_pfstatus.

    IF mo_grid IS BOUND.
      RETURN.
    ENDIF.

    " Docking chiếm TOÀN BỘ dynpro 0100 (layout của dynpro để rỗng).
    " Dùng EXTENSION lớn thay cho RATIO: ratio tối đa 95 nên còn dải trống
    " bên phải màn hình.
    CREATE OBJECT mo_dock
      EXPORTING
        repid     = sy-repid
        dynnr     = sy-dynnr
        side      = cl_gui_docking_container=>dock_at_left
        extension = 9999
      EXCEPTIONS
        OTHERS    = 1.
    IF sy-subrc <> 0.
      MESSAGE 'Không tạo được docking container cho ALV.' TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    CREATE OBJECT mo_grid
      EXPORTING
        i_parent = mo_dock
      EXCEPTIONS
        OTHERS   = 1.
    IF sy-subrc <> 0.
      MESSAGE 'Không tạo được ALV grid.' TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    SET HANDLER me->on_toolbar      FOR mo_grid.
    SET HANDLER me->on_user_command FOR mo_grid.
    SET HANDLER me->on_hotspot      FOR mo_grid.

    DATA ls_layout TYPE lvc_s_layo.
    ls_layout-grid_title = |Tích hợp HĐĐT - công ty { p_bukrs } / năm { p_gjahr }|.
    ls_layout-zebra      = abap_true.
    ls_layout-cwidth_opt = abap_true.
    ls_layout-sel_mode   = 'A'.

    mo_grid->set_table_for_first_display(
      EXPORTING
        is_layout       = ls_layout
      CHANGING
        it_fieldcatalog = mt_fcat
        it_outtab       = gt_alv ).

  ENDMETHOD.


  METHOD pai_0100.

    " GUI status copy từ chuẩn danh sách dùng mã &F03 / &F15 / &F12, status
    " tự tạo thường dùng BACK / EXIT / CANC, danh sách cổ điển dùng RW / RE.
    " Nhận cả ba bộ để nút Back luôn có tác dụng.
    CASE i_ucomm.
      WHEN 'BACK' OR '&F03' OR 'RW'.
        LEAVE TO SCREEN 0.
      WHEN 'CANC' OR '&F12' OR 'RE'.
        LEAVE TO SCREEN 0.
      WHEN 'EXIT' OR '&F15'.
        LEAVE PROGRAM.
      WHEN OTHERS.
        " Nút của grid đi qua event USER_COMMAND, không qua PAI
    ENDCASE.

  ENDMETHOD.


  METHOD on_toolbar.

    " 12 nút nghiệp vụ khai ngay trong code: GUI status chỉ cần Back /
    " Exit / Cancel, không phải khai mã và không cần function key.
    DATA lt_btn TYPE STANDARD TABLE OF stb_button WITH DEFAULT KEY.

    lt_btn = VALUE #(
      ( butn_type = 3 )
      ( function = gc_fcode-draft   icon = CONV #( icon_create )
        text = 'Tích hợp HĐ'   quickinfo = 'Tạo hoá đơn nháp trên hệ thống HĐĐT (chờ cấp số)' )
      ( function = gc_fcode-deldrf  icon = CONV #( icon_delete )
        text = 'Hủy HĐ nháp'   quickinfo = 'Xoá hoá đơn nháp, đưa chứng từ về chưa tích hợp' )
      ( function = gc_fcode-issue   icon = CONV #( icon_execute_object )
        text = 'Phát hành HĐ'  quickinfo = 'Cấp số và ký duyệt trên chính bản nháp' )
      ( function = gc_fcode-update  icon = CONV #( icon_refresh )
        text = 'Cập nhật HĐ'   quickinfo = 'Tra cứu và đồng bộ trạng thái về SAP' )
      ( function = gc_fcode-adjref  icon = CONV #( icon_change )
        text = 'HĐ Điều chỉnh' quickinfo = 'Gắn hoá đơn gốc và loại điều chỉnh / thay thế' )
      ( butn_type = 3 )
      ( function = gc_fcode-mail    icon = CONV #( icon_mail )
        text = 'Send Email'    quickinfo = 'Gửi email hoá đơn (PDF) cho khách hàng' )
      ( function = gc_fcode-gom     icon = CONV #( icon_collapse )
        text = 'Gom HĐ'        quickinfo = 'Gom các chứng từ đã chọn thành một hoá đơn' )
      ( function = gc_fcode-ungom   icon = CONV #( icon_expand )
        text = 'Huỷ Gom HĐ'    quickinfo = 'Gỡ toàn bộ chứng từ khỏi chứng từ gom' )
      ( function = gc_fcode-edit    icon = CONV #( icon_edit_file )
        text = 'Sửa ngày/giờ'  quickinfo = 'Sửa ngày, giờ phát hành và tên hàng' )
      ( butn_type = 3 )
      ( function = gc_fcode-getfile icon = CONV #( icon_pdf )
        text = 'Lấy file'      quickinfo = 'Tải file PDF hoá đơn từ nhà cung cấp' )
      ( function = gc_fcode-showjs  icon = CONV #( icon_xml_doc )
        text = 'Xem payload'   quickinfo = 'Xem payload sẽ gửi cho nhà cung cấp (không gọi API)' )
      ( function = gc_fcode-showlog icon = CONV #( icon_protocol )
        text = 'Log'           quickinfo = 'Xem log gọi API của chứng từ' ) ).

    APPEND LINES OF lt_btn TO e_object->mt_toolbar.

  ENDMETHOD.


  METHOD on_user_command.

    dispatch( e_ucomm ).

  ENDMETHOD.


  METHOD dispatch.

    CASE i_code.
      WHEN gc_fcode-draft.    do_draft( ).
      WHEN gc_fcode-deldrf.   do_delete_draft( ).
      WHEN gc_fcode-issue.    do_issue( ).
      WHEN gc_fcode-update.   do_update( ).
      WHEN gc_fcode-adjref.   do_adjust_ref( ).
      WHEN gc_fcode-mail.     do_mail( ).
      WHEN gc_fcode-gom.      do_gom( ).
      WHEN gc_fcode-ungom.    do_ungom( ).
      WHEN gc_fcode-edit.     do_edit( ).
      WHEN gc_fcode-getfile.  do_getfile( ).
      WHEN gc_fcode-showjs.   show_payload( ).
      WHEN gc_fcode-showlog.  show_log( ).
      WHEN OTHERS.
    ENDCASE.

  ENDMETHOD.


  METHOD refresh_grid.

    IF mo_grid IS NOT BOUND.
      RETURN.
    ENDIF.

    DATA ls_stable TYPE lvc_s_stbl.
    ls_stable-row = abap_true.
    ls_stable-col = abap_true.
    mo_grid->refresh_table_display(
      EXPORTING
        is_stable = ls_stable
      EXCEPTIONS
        OTHERS    = 0 ).

  ENDMETHOD.


  METHOD on_hotspot.

    " Nhấn vào link tra cứu hoá đơn -> mở trình duyệt
    IF e_column_id-fieldname <> 'INV_LINK'.
      RETURN.
    ENDIF.
    IF e_row_id-index < 1 OR e_row_id-index > lines( gt_alv ).
      RETURN.
    ENDIF.

    DATA(lv_url) = CONV string( gt_alv[ e_row_id-index ]-inv_link ).
    IF lv_url IS INITIAL.
      RETURN.
    ENDIF.

    " Dạng ngắn ( name = value ) không đi kèm được EXCEPTIONS
    cl_gui_frontend_services=>execute(
      EXPORTING  document   = lv_url
      EXCEPTIONS cntl_error = 1
                 OTHERS     = 2 ).
    IF sy-subrc <> 0.
      MESSAGE 'Không mở được link tra cứu hoá đơn.' TYPE 'S' DISPLAY LIKE 'W'.
    ENDIF.

  ENDMETHOD.


  METHOD get_selected.

    IF mo_grid IS NOT BOUND.
      RETURN.
    ENDIF.

    DATA lt_rows TYPE lvc_t_row.
    mo_grid->get_selected_rows( IMPORTING et_index_rows = lt_rows ).
    LOOP AT lt_rows ASSIGNING FIELD-SYMBOL(<fs_row>).
      APPEND <fs_row>-index TO rt_index.
    ENDLOOP.

  ENDMETHOD.


  METHOD check_auth.

    " Object phân quyền riêng của chương trình (FS mục 3.10), khai trong
    " tham số AUTH_OBJECT với field BUKRS + ACTVT; trống = không kiểm.
    DATA(lv_obj) = zcl_hddt_config=>get_instance( )->get_param(
                     i_key = zif_hddt_types=>gc_parm-auth_object i_bukrs = p_bukrs ).
    CONDENSE lv_obj.
    IF lv_obj IS INITIAL.
      r_ok = abap_true.
      RETURN.
    ENDIF.
    DATA lv_object TYPE xuobject.
    lv_object = lv_obj.
    AUTHORITY-CHECK OBJECT lv_object
      ID 'BUKRS' FIELD p_bukrs
      ID 'ACTVT' FIELD i_actvt.
    r_ok = xsdbool( sy-subrc = 0 ).
    IF r_ok = abap_false.
      MESSAGE s032(zms_hddt) WITH i_function DISPLAY LIKE 'E'.
    ENDIF.

  ENDMETHOD.


  METHOD confirm.

    DATA lv_answer TYPE char1.
    CALL FUNCTION 'POPUP_TO_CONFIRM'
      EXPORTING
        titlebar              = i_title
        text_question         = i_question
        text_button_1         = 'Thực hiện'
        text_button_2         = 'Huỷ'
        default_button        = '2'
        display_cancel_button = abap_false
      IMPORTING
        answer                = lv_answer
      EXCEPTIONS
        text_not_found        = 1
        OTHERS                = 2.
    r_ok = xsdbool( sy-subrc = 0 AND lv_answer = '1' ).

  ENDMETHOD.


*---------------------------------------------------------------------*
* Nút Tích hợp HĐ (FS 3.6.1) — tạo hoá đơn nháp
*---------------------------------------------------------------------*
  METHOD do_draft.

    IF check_auth( i_actvt = gc_actvt-create i_function = 'Tích hợp HĐ' ) = abap_false.
      RETURN.
    ENDIF.
    DATA(lt_rows) = get_selected( ).
    IF lt_rows IS INITIAL.
      MESSAGE s013(zms_hddt) DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.

    LOOP AT lt_rows INTO DATA(lv_row).
      IF lv_row < 1 OR lv_row > lines( gt_request ).
        CONTINUE.
      ENDIF.
      DATA(ls_result) = mo_service->create_draft( is_request = gt_request[ lv_row ]
                                                  i_test_run = p_test ).
      refresh_row( i_index = lv_row is_result = ls_result ).
      IF p_test = abap_true AND ls_result-request_body IS NOT INITIAL.
        " FS 3.3 STT 14: Test -> pop-up nội dung JSON sẽ gửi
        " PERFORM ... USING chỉ nhận TÊN BIẾN, không nhận biểu thức
        DATA(lv_title) = |Payload (Test run) - { gt_request[ lv_row ]-src_docno }|.
        PERFORM display_text USING lv_title
                                   ls_result-request_body.
      ENDIF.
    ENDLOOP.
    refresh_grid( ).

  ENDMETHOD.


*---------------------------------------------------------------------*
* Nút Hủy HĐ nháp (FS 3.6.2)
*---------------------------------------------------------------------*
  METHOD do_delete_draft.

    IF check_auth( i_actvt = gc_actvt-create i_function = 'Hủy HĐ nháp' ) = abap_false.
      RETURN.
    ENDIF.
    DATA(lt_rows) = get_selected( ).
    IF lt_rows IS INITIAL.
      MESSAGE 'Chọn chứng từ cần huỷ hoá đơn nháp' TYPE 'S' DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.
    IF confirm( i_title    = 'Huỷ hoá đơn nháp'
                i_question = |Bạn có chắc chắn huỷ hoá đơn nháp của { lines( lt_rows ) } chứng từ đã chọn không?| ) = abap_false.
      RETURN.
    ENDIF.

    LOOP AT lt_rows INTO DATA(lv_row).
      IF lv_row < 1 OR lv_row > lines( gt_request ).
        CONTINUE.
      ENDIF.
      DATA(ls_result) = mo_service->delete_draft( gt_request[ lv_row ] ).
      refresh_row( i_index = lv_row is_result = ls_result ).
    ENDLOOP.
    refresh_grid( ).

  ENDMETHOD.


*---------------------------------------------------------------------*
* Nút Phát hành HĐ (FS 3.6.3 + 3.6.10)
*---------------------------------------------------------------------*
  METHOD do_issue.

    IF check_auth( i_actvt = gc_actvt-change i_function = 'Phát hành HĐ' ) = abap_false.
      RETURN.
    ENDIF.
    DATA(lt_rows) = get_selected( ).
    IF lt_rows IS INITIAL.
      MESSAGE 'Chọn chứng từ cần tích hợp' TYPE 'S' DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.
    IF p_test = abap_false
       AND confirm( i_title    = 'Xác nhận phát hành hoá đơn điện tử'
                    i_question = |Phát hành { lines( lt_rows ) } hoá đơn? Hành động này cấp số, ký duyệt| &&
                                 | và gửi dữ liệu lên Cơ quan thuế - KHÔNG thể thu hồi.| ) = abap_false.
      RETURN.
    ENDIF.

    LOOP AT lt_rows INTO DATA(lv_row).
      IF lv_row < 1 OR lv_row > lines( gt_request ).
        CONTINUE.
      ENDIF.
      DATA(ls_result) = mo_service->issue_invoice( is_request = gt_request[ lv_row ]
                                                   i_test_run = p_test ).
      refresh_row( i_index = lv_row is_result = ls_result ).
      IF p_test = abap_true AND ls_result-request_body IS NOT INITIAL.
        " PERFORM ... USING chỉ nhận TÊN BIẾN, không nhận biểu thức
        DATA(lv_title) = |Payload (Test run) - { gt_request[ lv_row ]-src_docno }|.
        PERFORM display_text USING lv_title
                                   ls_result-request_body.
      ENDIF.
    ENDLOOP.
    refresh_grid( ).

  ENDMETHOD.


*---------------------------------------------------------------------*
* Nút Cập nhật HĐ (FS 3.6.5) — tra cứu, đồng bộ, ghi ngược BKPF
*---------------------------------------------------------------------*
  METHOD do_update.

    IF check_auth( i_actvt = gc_actvt-display i_function = 'Cập nhật HĐ' ) = abap_false.
      RETURN.
    ENDIF.
    DATA(lt_rows) = get_selected( ).
    IF lt_rows IS INITIAL.
      MESSAGE s041(zms_hddt) DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.

    LOOP AT lt_rows INTO DATA(lv_row).
      IF lv_row < 1 OR lv_row > lines( gt_request ).
        CONTINUE.
      ENDIF.
      DATA(ls_req) = gt_request[ lv_row ].
      APPEND VALUE #( name = `type` value = `json` ) TO ls_req-params.
      DATA(ls_result) = mo_service->search_invoice( ls_req ).
      IF ls_result-success = abap_true.
        COMMIT WORK AND WAIT.        " search_invoice không tự commit
      ENDIF.
      refresh_row( i_index = lv_row is_result = ls_result ).
    ENDLOOP.
    refresh_grid( ).

  ENDMETHOD.


*---------------------------------------------------------------------*
* Nút HĐ Điều chỉnh (FS 3.6.4) — gắn hoá đơn gốc + loại điều chỉnh
*---------------------------------------------------------------------*
  METHOD do_adjust_ref.

    IF check_auth( i_actvt = gc_actvt-change i_function = 'HĐ Điều chỉnh' ) = abap_false.
      RETURN.
    ENDIF.
    DATA(lt_rows) = get_selected( ).
    IF lt_rows IS INITIAL.
      MESSAGE 'Cần chọn chứng từ điều chỉnh' TYPE 'S' DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.
    IF lines( lt_rows ) > 1.
      MESSAGE s019(zms_hddt) DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.
    DATA(lv_row) = lt_rows[ 1 ].
    IF lv_row < 1 OR lv_row > lines( gt_request ).
      RETURN.
    ENDIF.
    DATA(ls_req) = gt_request[ lv_row ].
    IF ls_req-src_info-xreversed = abap_true OR ls_req-src_info-xcancel = abap_true.
      MESSAGE 'Không thể điều chỉnh chứng từ đã huỷ' TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    DATA lv_docno TYPE zde_hddt_docno.
    DATA lv_gjahr TYPE gjahr.
    DATA lv_code  TYPE c LENGTH 1.
    lv_docno = gt_alv[ lv_row ]-ref_docno.
    lv_gjahr = COND #( WHEN gt_alv[ lv_row ]-ref_gjahr IS NOT INITIAL
                       THEN gt_alv[ lv_row ]-ref_gjahr ELSE p_gjahr ).
    lv_code  = gt_alv[ lv_row ]-adj_code.
    DATA lv_ok TYPE abap_bool.
    PERFORM popup_original CHANGING lv_docno lv_gjahr lv_code lv_ok.
    IF lv_ok = abap_false.
      RETURN.
    ENDIF.

    DATA(ls_result) = mo_service->attach_original( is_request  = ls_req
                                                   i_org_docno = lv_docno
                                                   i_org_gjahr = lv_gjahr
                                                   i_fs_code   = lv_code ).
    DATA(lv_like) = COND symsgty( WHEN ls_result-success = abap_true THEN 'S' ELSE 'E' ).
    MESSAGE ls_result-message TYPE 'S' DISPLAY LIKE lv_like.
    IF ls_result-success = abap_true.
      reload( ).
    ENDIF.

  ENDMETHOD.


*---------------------------------------------------------------------*
* Nút Send Email (FS 3.6.6) — lấy PDF từ NCC rồi gửi cho khách hàng
*---------------------------------------------------------------------*
  METHOD do_mail.

    IF check_auth( i_actvt = gc_actvt-display i_function = 'Send Email' ) = abap_false.
      RETURN.
    ENDIF.
    DATA(lt_rows) = get_selected( ).
    IF lt_rows IS INITIAL.
      MESSAGE s002(zms_hddt) DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.

    DATA(lo_mail) = NEW zcl_hddt_mail( ).
    DATA(lo_log)  = NEW zcl_hddt_log( ).

    LOOP AT lt_rows INTO DATA(lv_row).
      IF lv_row < 1 OR lv_row > lines( gt_request ).
        CONTINUE.
      ENDIF.
      DATA(ls_req) = gt_request[ lv_row ].
      DATA(ls_reg) = zcl_hddt_log=>read_invoice( i_bukrs     = ls_req-bukrs
                                                 i_gjahr     = ls_req-gjahr
                                                 i_src_type  = ls_req-src_type
                                                 i_src_docno = ls_req-src_docno ).
      DATA ls_result TYPE zif_hddt_types=>ty_result.
      CLEAR ls_result.

      IF lo_mail->is_allowed( i_bukrs = ls_req-bukrs i_status = ls_reg-status ) = abap_false.
        ls_result-msgty   = 'E'.
        ls_result-message = 'Hoá đơn chưa được Cơ quan thuế chấp nhận'.
        refresh_row( i_index = lv_row is_result = ls_result ).
        CONTINUE.
      ENDIF.

      " Lấy file PDF từ NCC (search-invoice type = pdf)
      APPEND VALUE #( name = `type` value = `pdf` ) TO ls_req-params.
      ls_req-invoice-header-idkey = ls_reg-idkey.
      DATA(ls_file) = mo_service->get_invoice_file( ls_req ).
      IF ls_file-success = abap_false OR ls_file-file_content IS INITIAL.
        ls_result-msgty   = 'E'.
        ls_result-message = |Không lấy được file PDF: { ls_file-message }|.
        lo_log->set_mail_status( is_request = ls_req i_status = 'E' ).
        refresh_row( i_index = lv_row is_result = ls_result ).
        CONTINUE.
      ENDIF.

      ls_result = lo_mail->send_invoice( is_request  = ls_req
                                         is_reg      = ls_reg
                                         i_pdf       = ls_file-file_content
                                         i_file_name = ls_file-file_name ).
      lo_log->set_mail_status( is_request = ls_req
                               i_status   = COND #( WHEN ls_result-success = abap_true THEN 'S' ELSE 'E' ) ).
      COMMIT WORK AND WAIT.
      refresh_row( i_index = lv_row is_result = ls_result ).
      gt_alv[ lv_row ]-mail_light = COND #( WHEN ls_result-success = abap_true
                                            THEN icon_mail ELSE icon_message_error_small ).
    ENDLOOP.
    refresh_grid( ).

  ENDMETHOD.


*---------------------------------------------------------------------*
* Nút Gom HĐ (FS 3.6.7)
*---------------------------------------------------------------------*
  METHOD do_gom.

    IF check_auth( i_actvt = gc_actvt-change i_function = 'Gom HĐ' ) = abap_false.
      RETURN.
    ENDIF.
    DATA(lt_rows) = get_selected( ).
    IF lines( lt_rows ) < 2.
      MESSAGE s024(zms_hddt) DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.

    DATA lt_req TYPE zif_hddt_types=>ty_t_request.
    LOOP AT lt_rows INTO DATA(lv_row).
      IF lv_row < 1 OR lv_row > lines( gt_request ).
        CONTINUE.
      ENDIF.
      IF gt_alv[ lv_row ]-gom_no IS NOT INITIAL.
        MESSAGE s025(zms_hddt) DISPLAY LIKE 'E'.
        RETURN.
      ENDIF.
      APPEND gt_request[ lv_row ] TO lt_req.
    ENDLOOP.

    TRY.
        DATA(lo_gom) = NEW zcl_hddt_gom( ).
        DATA(lv_gom) = lo_gom->create( i_bukrs     = p_bukrs
                                       i_gjahr     = p_gjahr
                                       it_requests = lt_req ).
        COMMIT WORK AND WAIT.
        " MESSAGE ... WITH chỉ nhận tên biến / literal, không nhận biểu thức
        DATA(lv_cnt) = |{ lines( lt_req ) }|.
        MESSAGE s028(zms_hddt) WITH lv_cnt lv_gom.
        reload( ).
      CATCH zcx_hddt_error INTO DATA(lx).
        ROLLBACK WORK.
        MESSAGE lx->get_text_long( ) TYPE 'S' DISPLAY LIKE 'E'.
    ENDTRY.

  ENDMETHOD.


*---------------------------------------------------------------------*
* Nút Huỷ Gom HĐ (FS 3.6.8)
*---------------------------------------------------------------------*
  METHOD do_ungom.

    IF check_auth( i_actvt = gc_actvt-change i_function = 'Huỷ Gom HĐ' ) = abap_false.
      RETURN.
    ENDIF.
    DATA(lt_rows) = get_selected( ).
    IF lt_rows IS INITIAL.
      MESSAGE 'Chọn chứng từ gom cần gỡ' TYPE 'S' DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.

    DATA lt_gom TYPE SORTED TABLE OF zde_hddt_docno WITH UNIQUE KEY table_line.
    LOOP AT lt_rows INTO DATA(lv_row).
      IF lv_row < 1 OR lv_row > lines( gt_alv ).
        CONTINUE.
      ENDIF.
      DATA(ls_alv) = gt_alv[ lv_row ].
      DATA(lv_gom) = COND zde_hddt_docno( WHEN ls_alv-src_type = zcl_hddt_gom=>gc_src_type
                                          THEN ls_alv-src_docno ELSE ls_alv-gom_no ).
      IF lv_gom IS INITIAL.
        MESSAGE s029(zms_hddt) DISPLAY LIKE 'E'.
        RETURN.
      ENDIF.
      INSERT lv_gom INTO TABLE lt_gom.
    ENDLOOP.

    DATA(lo_gom) = NEW zcl_hddt_gom( ).
    LOOP AT lt_gom INTO lv_gom.
      TRY.
          lo_gom->cancel( i_bukrs = p_bukrs i_gjahr = p_gjahr i_gom_no = lv_gom ).
          COMMIT WORK AND WAIT.
          MESSAGE s030(zms_hddt) WITH lv_gom.
        CATCH zcx_hddt_error INTO DATA(lx).
          ROLLBACK WORK.
          MESSAGE lx->get_text_long( ) TYPE 'S' DISPLAY LIKE 'E'.
      ENDTRY.
    ENDLOOP.
    reload( ).

  ENDMETHOD.


*---------------------------------------------------------------------*
* Sửa ngày / giờ phát hành / tên hàng (FS 3.5: các cột "cho sửa")
*---------------------------------------------------------------------*
  METHOD do_edit.

    IF check_auth( i_actvt = gc_actvt-change i_function = 'Sửa ngày/giờ/tên hàng' ) = abap_false.
      RETURN.
    ENDIF.
    DATA(lt_rows) = get_selected( ).
    IF lt_rows IS INITIAL.
      MESSAGE s002(zms_hddt) DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.

    DATA(lv_first) = lt_rows[ 1 ].
    DATA lv_date TYPE dats.
    DATA lv_time TYPE uzeit.
    DATA lv_text TYPE zde_hddt_name.
    DATA lv_ok   TYPE abap_bool.
    lv_date = gt_alv[ lv_first ]-inv_date.
    lv_time = gt_alv[ lv_first ]-inv_time.
    lv_text = gt_alv[ lv_first ]-item_text.
    PERFORM popup_edit CHANGING lv_date lv_time lv_text lv_ok.
    IF lv_ok = abap_false.
      RETURN.
    ENDIF.

    DATA(lo_log) = NEW zcl_hddt_log( ).
    DATA lv_cnt TYPE i.
    LOOP AT lt_rows INTO DATA(lv_row).
      IF lv_row < 1 OR lv_row > lines( gt_request ).
        CONTINUE.
      ENDIF.
      IF gt_alv[ lv_row ]-status <> zif_hddt_types=>gc_status-not_sent
         AND gt_alv[ lv_row ]-status <> zif_hddt_types=>gc_status-error.
        CONTINUE.                      " đã có nháp/hoá đơn -> không sửa
      ENDIF.
      lo_log->save_edit( is_request  = gt_request[ lv_row ]
                         i_inv_date  = lv_date
                         i_inv_time  = lv_time
                         i_item_text = CONV #( lv_text ) ).
      lv_cnt = lv_cnt + 1.
    ENDLOOP.
    COMMIT WORK AND WAIT.
    MESSAGE s034(zms_hddt) WITH lv_cnt.
    reload( ).

  ENDMETHOD.


  METHOD do_getfile.

    IF check_auth( i_actvt = gc_actvt-display i_function = 'Lấy file' ) = abap_false.
      RETURN.
    ENDIF.
    DATA(lt_rows) = get_selected( ).
    IF lt_rows IS INITIAL.
      MESSAGE s002(zms_hddt) DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.

    LOOP AT lt_rows INTO DATA(lv_row).
      IF lv_row < 1 OR lv_row > lines( gt_request ).
        CONTINUE.
      ENDIF.
      DATA(ls_req) = gt_request[ lv_row ].
      APPEND VALUE #( name = `type` value = `pdf` ) TO ls_req-params.
      DATA(ls_result) = mo_service->get_invoice_file( ls_req ).
      refresh_row( i_index = lv_row is_result = ls_result ).
      IF ls_result-file_content IS NOT INITIAL.
        PERFORM save_file USING ls_result-file_name ls_result-file_content.
      ENDIF.
    ENDLOOP.
    refresh_grid( ).

  ENDMETHOD.


  METHOD refresh_row.

    IF i_index < 1 OR i_index > lines( gt_alv ).
      RETURN.
    ENDIF.

    ASSIGN gt_alv[ i_index ] TO FIELD-SYMBOL(<fs_alv>).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    <fs_alv>-msgty   = is_result-msgty.
    <fs_alv>-message = is_result-message.
    <fs_alv>-log_id  = is_result-log_id.
    IF is_result-status IS NOT INITIAL.
      <fs_alv>-status     = is_result-status.
      <fs_alv>-status_txt = status_text( is_result-status ).
      IF is_result-status = zif_hddt_types=>gc_status-not_sent.
        CLEAR: <fs_alv>-template, <fs_alv>-serial, <fs_alv>-seq, <fs_alv>-issue_date,
               <fs_alv>-mscqt, <fs_alv>-sec_code, <fs_alv>-inv_link, <fs_alv>-tax_status.
      ENDIF.
    ENDIF.
    IF is_result-template IS NOT INITIAL.
      <fs_alv>-template = is_result-template.
    ENDIF.
    IF is_result-serial IS NOT INITIAL.
      <fs_alv>-serial = is_result-serial.
    ENDIF.
    IF is_result-seq IS NOT INITIAL.
      <fs_alv>-seq = is_result-seq.
    ENDIF.
    IF is_result-issue_date IS NOT INITIAL.
      <fs_alv>-issue_date = is_result-issue_date.
    ENDIF.
    IF is_result-mscqt IS NOT INITIAL.
      <fs_alv>-mscqt = is_result-mscqt.
    ENDIF.
    IF is_result-sec_code IS NOT INITIAL.
      <fs_alv>-sec_code = is_result-sec_code.
    ENDIF.
    IF is_result-inv_link IS NOT INITIAL.
      <fs_alv>-inv_link = is_result-inv_link.
    ENDIF.
    IF is_result-tax_status IS NOT INITIAL.
      <fs_alv>-tax_status = is_result-tax_status.
    ENDIF.

    <fs_alv>-light = map_light( i_status = <fs_alv>-status
                                i_msgty  = <fs_alv>-msgty ).

  ENDMETHOD.


  METHOD show_payload.

    DATA(lt_rows) = get_selected( ).
    IF lt_rows IS INITIAL.
      MESSAGE s002(zms_hddt) DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.

    DATA(lv_row) = lt_rows[ 1 ].
    IF lv_row < 1 OR lv_row > lines( gt_request ).
      RETURN.
    ENDIF.

    DATA(ls_req) = gt_request[ lv_row ].
    " Payload theo bước tiếp theo của chứng từ: chưa tích hợp -> nháp;
    " đã có nháp -> phát hành
    ls_req-action = COND #( WHEN gt_alv[ lv_row ]-status = zif_hddt_types=>gc_status-wait_seq
                            THEN zif_hddt_types=>gc_action-issue_invoice
                            ELSE zif_hddt_types=>gc_action-create_draft ).

    " Test run => KHÔNG gọi API, chỉ dựng payload; mật khẩu được che
    DATA(ls_result) = mo_service->execute( is_request = ls_req
                                           i_test_run = abap_true ).

    IF ls_result-request_body IS INITIAL.
      MESSAGE ls_result-message TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    PERFORM display_text USING 'Payload gửi nhà cung cấp'
                               ls_result-request_body.

  ENDMETHOD.


  METHOD show_log.

    DATA(lt_rows) = get_selected( ).
    IF lt_rows IS INITIAL.
      MESSAGE s002(zms_hddt) DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.

    DATA(lv_row) = lt_rows[ 1 ].
    IF lv_row < 1 OR lv_row > lines( gt_alv ).
      RETURN.
    ENDIF.

    DATA(ls_alv) = gt_alv[ lv_row ].

    SELECT log_id, created_at, action, http_code, http_reason, duration_ms, message
      FROM ztb_hddt_log
      WHERE bukrs     = @ls_alv-bukrs
        AND gjahr     = @ls_alv-gjahr
        AND src_type  = @ls_alv-src_type
        AND src_docno = @ls_alv-src_docno
      ORDER BY created_at DESCENDING
      INTO TABLE @DATA(lt_log)
      UP TO 1 ROWS.
    IF sy-subrc <> 0.
      MESSAGE s003(zms_hddt) DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.

    DATA(ls_last) = lt_log[ 1 ].
    DATA(ls_pay)  = zcl_hddt_log=>read_payload( ls_last-log_id ).
    DATA(lv_text) = |=== REQUEST ({ ls_last-action }, HTTP { ls_last-http_code }| &&
                    |, { ls_last-duration_ms } ms) ===| &&
                    cl_abap_char_utilities=>newline && ls_pay-req_body &&
                    cl_abap_char_utilities=>newline &&
                    |=== RESPONSE ===| &&
                    cl_abap_char_utilities=>newline && ls_pay-res_body.

    PERFORM display_text USING 'Log gọi API' lv_text.

  ENDMETHOD.


  METHOD map_light.

    IF i_msgty = 'E' OR i_msgty = 'A'
       OR i_status = zif_hddt_types=>gc_status-error
       OR i_status = zif_hddt_types=>gc_status-rejected.
      r_icon = icon_red_light.
      RETURN.
    ENDIF.

    CASE i_status.
      WHEN zif_hddt_types=>gc_status-issued
        OR zif_hddt_types=>gc_status-coded
        OR zif_hddt_types=>gc_status-adjusted
        OR zif_hddt_types=>gc_status-replaced.
        r_icon = icon_green_light.
      WHEN zif_hddt_types=>gc_status-cancelled.
        r_icon = icon_red_light.
      WHEN zif_hddt_types=>gc_status-not_sent.
        r_icon = icon_light_out.
      WHEN OTHERS.
        r_icon = icon_yellow_light.
    ENDCASE.

  ENDMETHOD.


  METHOD status_text.

    " Lấy đúng nhãn đã khai trong domain ZDO_HDDT_STATUS để text hiển
    " thị luôn khớp với cấu hình, không hardcode ở đây.
    SELECT SINGLE ddtext FROM dd07t
      WHERE domname    = 'ZDO_HDDT_STATUS'
        AND as4local   = 'A'
        AND ddlanguage = @sy-langu
        AND domvalue_l = @i_status
      INTO @r_text.
    IF sy-subrc <> 0.
      SELECT SINGLE ddtext FROM dd07t
        WHERE domname    = 'ZDO_HDDT_STATUS'
          AND as4local   = 'A'
          AND ddlanguage = 'E'
          AND domvalue_l = @i_status
        INTO @r_text.
    ENDIF.

  ENDMETHOD.

ENDCLASS.


*&---------------------------------------------------------------------*
*& Form DISPLAY_TEXT
*&---------------------------------------------------------------------*
*& Hiển thị chuỗi dài trong ALV popup, cắt thành dòng 250 ký tự.
*& --> I_TITLE  Tiêu đề popup
*& --> I_TEXT   Nội dung
*&---------------------------------------------------------------------*
FORM display_text USING i_title TYPE clike
                        i_text  TYPE string.

  TYPES: BEGIN OF lty_line,
           line_no TYPE i,
           line    TYPE c LENGTH 250,
         END OF lty_line.

  DATA lt_line TYPE STANDARD TABLE OF lty_line WITH EMPTY KEY.
  DATA lv_rest TYPE string.
  DATA lv_no   TYPE i.

  lv_rest = i_text.
  WHILE lv_rest IS NOT INITIAL.
    lv_no = lv_no + 1.
    APPEND VALUE #( line_no = lv_no
                    line    = lv_rest(250) ) TO lt_line.
    IF strlen( lv_rest ) <= 250.
      EXIT.
    ENDIF.
    SHIFT lv_rest LEFT BY 250 PLACES.
  ENDWHILE.

  IF lt_line IS INITIAL.
    RETURN.
  ENDIF.

  DATA lo_popup TYPE REF TO cl_salv_table.
  TRY.
      cl_salv_table=>factory( IMPORTING r_salv_table = lo_popup
                              CHANGING  t_table      = lt_line ).
      lo_popup->set_screen_popup( start_column = 5
                                  end_column   = 130
                                  start_line   = 2
                                  end_line     = 26 ).
      DATA lv_title TYPE lvc_title.
      lv_title = i_title.
      lo_popup->get_display_settings( )->set_list_header( lv_title ).
      lo_popup->get_columns( )->set_optimize( abap_true ).
      lo_popup->display( ).
    CATCH cx_salv_error INTO DATA(lx).
      MESSAGE lx->get_text( ) TYPE 'S' DISPLAY LIKE 'E'.
  ENDTRY.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form POPUP_ORIGINAL
*&---------------------------------------------------------------------*
*& FS 3.6.4: pop-up nhập Số chứng từ gốc, Năm chứng từ gốc, Loại điều
*& chỉnh (2 tăng / 3 giảm / 4 thông tin / 5 thay thế). Để trống cả 3 để
*& gỡ hoá đơn gốc. Điều kiện nghiệp vụ do engine kiểm (ATTACH_ORIGINAL).
*& <-> C_DOCNO  C_GJAHR  C_CODE
*& <-- C_OK     abap_true khi người dùng bấm Save
*&---------------------------------------------------------------------*
FORM popup_original CHANGING c_docno TYPE zde_hddt_docno
                             c_gjahr TYPE gjahr
                             c_code  TYPE c
                             c_ok    TYPE abap_bool.

  DATA lt_fields TYPE STANDARD TABLE OF sval WITH DEFAULT KEY.
  DATA lv_rc     TYPE c LENGTH 1.

  lt_fields = VALUE #(
    ( tabname = 'BKPF'         fieldname = 'BELNR'   fieldtext = 'Số chứng từ gốc'
      value = c_docno )
    ( tabname = 'BKPF'         fieldname = 'GJAHR'   fieldtext = 'Năm chứng từ gốc'
      value = c_gjahr )
    ( tabname = 'ZTB_HDDT_INV' fieldname = 'ADJ_DIR' fieldtext = 'Loại ĐC (2/3/4/5)'
      value = c_code ) ).

  CALL FUNCTION 'POPUP_GET_VALUES'
    EXPORTING
      popup_title     = 'Hoá đơn gốc cần điều chỉnh / thay thế (trống = gỡ)'
      start_column    = '10'
      start_row       = '5'
    IMPORTING
      returncode      = lv_rc
    TABLES
      fields          = lt_fields
    EXCEPTIONS
      error_in_fields = 1
      OTHERS          = 2.
  IF sy-subrc <> 0 OR lv_rc = 'A'.
    c_ok = abap_false.
    RETURN.
  ENDIF.

  DATA lv_belnr TYPE belnr_d.
  LOOP AT lt_fields ASSIGNING FIELD-SYMBOL(<fs_f>).
    CASE <fs_f>-fieldname.
      WHEN 'BELNR'.
        " Chuyển về độ dài BELNR trước khi thêm số 0 đầu (ALPHA trên
        " SVAL-VALUE 132 ký tự sẽ đệm sai)
        lv_belnr = <fs_f>-value.
        CONDENSE lv_belnr NO-GAPS.
        IF lv_belnr IS NOT INITIAL.
          lv_belnr = |{ lv_belnr ALPHA = IN }|.
        ENDIF.
        c_docno = lv_belnr.
      WHEN 'GJAHR'.
        c_gjahr = <fs_f>-value.
      WHEN 'ADJ_DIR'.
        c_code = <fs_f>-value.
    ENDCASE.
  ENDLOOP.
  CONDENSE c_docno NO-GAPS.
  c_ok = abap_true.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form POPUP_EDIT
*&---------------------------------------------------------------------*
*& FS 3.5: các cột "cho sửa" — ngày phát hành, giờ phát hành (mặc định
*& 08:00:00) và tên hàng nhập tay (ưu tiên 1 khi dựng itemName).
*& <-> C_DATE C_TIME C_TEXT   <-- C_OK
*&---------------------------------------------------------------------*
FORM popup_edit CHANGING c_date TYPE dats
                         c_time TYPE uzeit
                         c_text TYPE zde_hddt_name
                         c_ok   TYPE abap_bool.

  DATA lt_fields TYPE STANDARD TABLE OF sval WITH DEFAULT KEY.
  DATA lv_rc     TYPE c LENGTH 1.

  lt_fields = VALUE #(
    ( tabname = 'ZTB_HDDT_INV' fieldname = 'INV_DATE'  fieldtext = 'Ngày phát hành' value = c_date )
    ( tabname = 'ZTB_HDDT_INV' fieldname = 'INV_TIME'  fieldtext = 'Giờ phát hành'          value = c_time )
    ( tabname = 'ZTB_HDDT_INV' fieldname = 'ITEM_TEXT' fieldtext = 'Tên hàng (ưu tiên 1)'  value = c_text ) ).

  CALL FUNCTION 'POPUP_GET_VALUES'
    EXPORTING
      popup_title     = 'Sửa ngày / giờ phát hành và tên hàng'
      start_column    = '10'
      start_row       = '5'
    IMPORTING
      returncode      = lv_rc
    TABLES
      fields          = lt_fields
    EXCEPTIONS
      error_in_fields = 1
      OTHERS          = 2.
  IF sy-subrc <> 0 OR lv_rc = 'A'.
    c_ok = abap_false.
    RETURN.
  ENDIF.

  LOOP AT lt_fields ASSIGNING FIELD-SYMBOL(<fs_f>).
    CASE <fs_f>-fieldname.
      WHEN 'INV_DATE'.  c_date = <fs_f>-value.
      WHEN 'INV_TIME'.  c_time = <fs_f>-value.
      WHEN 'ITEM_TEXT'. c_text = <fs_f>-value.
    ENDCASE.
  ENDLOOP.
  c_ok = abap_true.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form SAVE_FILE
*&---------------------------------------------------------------------*
*& Lưu file hoá đơn (PDF/XML) nhận từ nhà cung cấp xuống máy trạm.
*& --> I_NAME     Tên file gợi ý
*& --> I_CONTENT  Nội dung nhị phân
*&---------------------------------------------------------------------*
FORM save_file USING i_name    TYPE string
                     i_content TYPE xstring.

  DATA lt_bin TYPE STANDARD TABLE OF x255 WITH DEFAULT KEY.
  DATA lv_len TYPE i.

  IF i_content IS INITIAL.
    RETURN.
  ENDIF.

  " Giá trị trả về của cl_gui_frontend_services phải nằm ở biến TOÀN CỤC
  " (gv_file_* trong _TOP) — quy ước chống SYSTEM_POINTER_PENDING
  CLEAR: gv_file_name, gv_file_path, gv_file_full, gv_file_action.
  gv_file_name = COND #( WHEN i_name IS INITIAL THEN 'einvoice.pdf' ELSE i_name ).

  cl_gui_frontend_services=>file_save_dialog(
    EXPORTING
      window_title      = 'Lưu file hoá đơn điện tử'
      default_file_name = gv_file_name
    CHANGING
      filename          = gv_file_name
      path              = gv_file_path
      fullpath          = gv_file_full
      user_action       = gv_file_action
    EXCEPTIONS
      OTHERS            = 1 ).
  IF sy-subrc <> 0
     OR gv_file_action <> cl_gui_frontend_services=>action_ok
     OR gv_file_full IS INITIAL.
    RETURN.
  ENDIF.

  CALL FUNCTION 'SCMS_XSTRING_TO_BINARY'
    EXPORTING
      buffer        = i_content
    IMPORTING
      output_length = lv_len
    TABLES
      binary_tab    = lt_bin.

  cl_gui_frontend_services=>gui_download(
    EXPORTING
      bin_filesize = lv_len
      filename     = gv_file_full
      filetype     = 'BIN'
    CHANGING
      data_tab     = lt_bin
    EXCEPTIONS
      OTHERS       = 1 ).
  IF sy-subrc <> 0.
    MESSAGE 'Không lưu được file hoá đơn.' TYPE 'S' DISPLAY LIKE 'E'.
  ELSE.
    MESSAGE |Đã lưu { gv_file_full }| TYPE 'S'.
  ENDIF.

ENDFORM.


*&---------------------------------------------------------------------*
*& Module STATUS_0100 OUTPUT
*&---------------------------------------------------------------------*
*& Dynpro 0100 có layout RỖNG: toàn bộ vùng màn hình do docking
*& container chiếm. Flow logic của dynpro chỉ gồm hai module này.
*&---------------------------------------------------------------------*
MODULE status_0100 OUTPUT.

  go_app->pbo_0100( ).

ENDMODULE.


*&---------------------------------------------------------------------*
*& Module USER_COMMAND_0100 INPUT
*&---------------------------------------------------------------------*
MODULE user_command_0100 INPUT.

  go_app->pai_0100( sy-ucomm ).

ENDMODULE.
