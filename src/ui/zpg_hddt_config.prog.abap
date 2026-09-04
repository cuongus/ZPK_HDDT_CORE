*=====================================================================
* Tên/Mã     : ZPG_HDDT_CONFIG  (transaction ZFI002)
* Mô tả chung: Bàn điều khiển cấu hình HĐĐT. Liệt kê toàn bộ bảng cấu
*              hình của package, nhấn đôi để mở bảo trì bảng.
*              Chỉ cần chương trình này là quản trị viên nghiệp vụ tự
*              đổi được nhà cung cấp, URL, tài khoản, ánh xạ trạng thái
*              mà KHÔNG cần developer.
*              Yêu cầu: mỗi bảng đã được sinh Table Maintenance
*              Generator (SE11 -> Utilities -> Table Maintenance
*              Generator). Xem docs/06-cai-dat.md §3.
* Tham Số    : Không có
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       28/08/2026    cuongus - CuongUS        abapGit     Tạo mới
*=====================================================================
REPORT zpg_hddt_config MESSAGE-ID zms_hddt.

TYPES: BEGIN OF ty_entry,
         seq      TYPE n LENGTH 2,
         area     TYPE c LENGTH 30,
         tabname  TYPE tabname,
         descr    TYPE c LENGTH 70,
         mandatory TYPE c LENGTH 1,
       END OF ty_entry.

DATA gt_entry TYPE STANDARD TABLE OF ty_entry WITH EMPTY KEY.

CLASS lcl_cfg DEFINITION FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    METHODS run.
    METHODS on_double_click
      FOR EVENT double_click OF cl_salv_events_table
      IMPORTING row column.
  PRIVATE SECTION.
    DATA mo_alv TYPE REF TO cl_salv_table.
    METHODS build_list.
    METHODS maintain
      IMPORTING i_tabname TYPE tabname.
ENDCLASS.


CLASS lcl_cfg IMPLEMENTATION.

  METHOD build_list.

    " Thứ tự trong danh sách = thứ tự nên cấu hình khi triển khai mới
    gt_entry = VALUE #(
      ( seq = '01' area = 'Nhà cung cấp'  tabname = 'ZTB_HDDT_PROV'
        descr = 'Danh mục nhà cung cấp + tên lớp adapter' mandatory = 'X' )
      ( seq = '02' area = 'Kết nối'       tabname = 'ZTB_HDDT_CONN'
        descr = 'RFC destination / base URL / cách xác thực' mandatory = 'X' )
      ( seq = '03' area = 'Endpoint'      tabname = 'ZTB_HDDT_ACT'
        descr = 'Đường dẫn API theo từng nghiệp vụ' mandatory = 'X' )
      ( seq = '04' area = 'Tài khoản'     tabname = 'ZTB_HDDT_CRED'
        descr = 'Tài khoản API, MST, mẫu số, ký hiệu theo công ty' mandatory = 'X' )
      ( seq = '05' area = 'Nguồn dữ liệu' tabname = 'ZTB_HDDT_SRC'
        descr = 'Lớp đọc chứng từ nguồn theo công ty' mandatory = 'X' )
      ( seq = '06' area = 'Tham số'       tabname = 'ZTB_HDDT_PARM'
        descr = 'Tham số chung: nhà cung cấp đang dùng, thông tin bên bán' )
      ( seq = '07' area = 'Ngày hoá đơn'  tabname = 'ZTB_HDDT_DATE'
        descr = 'Nguồn ngày lập hoá đơn theo công ty' )
      ( seq = '08' area = 'Ánh xạ giá trị' tabname = 'ZTB_HDDT_MAP'
        descr = 'Thuế suất, hình thức thanh toán, tài khoản doanh thu' )
      ( seq = '09' area = 'Ánh xạ trạng thái' tabname = 'ZTB_HDDT_STAT'
        descr = 'Mã trả về của NCC -> trạng thái trong SAP' )
      ( seq = '10' area = 'Mẫu payload'   tabname = 'ZTB_HDDT_TPL'
        descr = 'Mẫu payload cho adapter dạng template (VNPT...)' )
      ( seq = '11' area = 'Sổ hoá đơn'    tabname = 'ZTB_HDDT_INV'
        descr = 'Sổ đăng ký hoá đơn đã tích hợp (chỉ xem)' )
      ( seq = '12' area = 'Chi tiết HH'   tabname = 'ZTB_HDDT_ITEM'
        descr = 'Chi tiết hàng hoá đã phát hành (chỉ xem)' )
      ( seq = '13' area = 'Log API'       tabname = 'ZTB_HDDT_LOG'
        descr = 'Log request/response (chỉ xem)' )
      ( seq = '14' area = 'Token'         tabname = 'ZTB_HDDT_TOK'
        descr = 'Bộ đệm access token (chỉ xem / xoá khi cần)' ) ).

  ENDMETHOD.


  METHOD run.

    build_list( ).

    TRY.
        cl_salv_table=>factory( IMPORTING r_salv_table = mo_alv
                                CHANGING  t_table      = gt_entry ).
      CATCH cx_salv_msg INTO DATA(lx).
        MESSAGE lx->get_text( ) TYPE 'S' DISPLAY LIKE 'E'.
        RETURN.
    ENDTRY.

    mo_alv->get_functions( )->set_all( abap_true ).
    mo_alv->get_columns( )->set_optimize( abap_true ).

    DATA lv_title TYPE lvc_title.
    lv_title = 'Cấu hình tích hợp hoá đơn điện tử - nhấn đôi để bảo trì'.
    mo_alv->get_display_settings( )->set_list_header( lv_title ).

    SET HANDLER me->on_double_click FOR mo_alv->get_event( ).
    mo_alv->display( ).

  ENDMETHOD.


  METHOD on_double_click.

    IF row < 1 OR row > lines( gt_entry ).
      RETURN.
    ENDIF.
    maintain( gt_entry[ row ]-tabname ).

  ENDMETHOD.


  METHOD maintain.

    DATA lt_excl TYPE STANDARD TABLE OF vimexclfun WITH EMPTY KEY.

    CALL FUNCTION 'VIEW_MAINTENANCE_CALL'
      EXPORTING
        action                       = 'U'
        view_name                    = i_tabname
      TABLES
        excl_cua_funct               = lt_excl
      EXCEPTIONS
        client_reference             = 1
        foreign_lock                 = 2
        invalid_action               = 3
        no_clientindependent_auth    = 4
        no_database_function         = 5
        no_editor_function           = 6
        no_show_auth                 = 7
        no_tvdir_entry               = 8
        no_upd_auth                  = 9
        only_show_allowed            = 10
        system_failure               = 11
        unknown_field_in_dba_sellist = 12
        view_not_found               = 13
        maintenance_prohibited       = 14
        OTHERS                       = 15.

    CASE sy-subrc.
      WHEN 0.
        " người dùng đã bảo trì -> xoá buffer cấu hình trong session
        zcl_hddt_factory=>reset( ).
      WHEN 8 OR 13.
        MESSAGE e006(zms_hddt) WITH i_tabname.
      WHEN 7 OR 9 OR 4 OR 10.
        MESSAGE e007(zms_hddt) WITH i_tabname.
      WHEN OTHERS.
        MESSAGE e008(zms_hddt) WITH i_tabname sy-subrc.
    ENDCASE.

  ENDMETHOD.

ENDCLASS.


START-OF-SELECTION.
  DATA(go_cfg) = NEW lcl_cfg( ).
  go_cfg->run( ).
