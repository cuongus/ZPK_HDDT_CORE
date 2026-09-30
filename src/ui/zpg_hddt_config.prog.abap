*=====================================================================
* Tên/Mã     : ZPG_HDDT_CONFIG  (transaction ZHD002)
* Mô tả chung: Bàn điều khiển cấu hình HĐĐT. Liệt kê toàn bộ bảng cấu
*              hình của package, nhấn đôi để mở bảo trì bảng.
*              Màn hình chia hai lưới: TRÊN là bảng cấu hình (nhấn đôi
*              mở bảo trì), DƯỚI là bảng dữ liệu vận hành / log (nhấn
*              đôi chỉ xem, lọc theo công ty đã nhập).
*              Chỉ cần chương trình này là quản trị viên nghiệp vụ tự
*              đổi được nhà cung cấp, URL, tài khoản, ánh xạ trạng thái
*              mà KHÔNG cần developer.
*              Yêu cầu: mỗi bảng đã được sinh Table Maintenance
*              Generator (SE11 -> Utilities -> Table Maintenance
*              Generator). Xem docs/06-cai-dat.md §3.
*              NGOẠI LỆ: 3 bảng có field STRING / RAWSTRING nên SE54 báo
*              "Data type STRING is not supported", KHÔNG sinh được TMG:
*                - ZTB_HDDT_TPL : nạp mẫu payload từ file JSON
*                                 (MAINTAIN_TPL)
*                - ZTB_HDDT_TOK : xem bộ đệm + xoá để buộc đăng nhập lại
*                                 (MAINTAIN_TOK)
*                - ZTB_HDDT_LOG : mở chương trình ZPG_HDDT_LOG
*                                 (MAINTAIN_LOG)
* Tham Số    : Không có
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       28/08/2026    cuongus - CuongUS        abapGit     Tạo mới
* 1.1       08/09/2026    cuongus - CuongUS        abapGit     Bảo trì
*                         ZTB_HDDT_TPL bằng nạp file JSON, ZTB_HDDT_TOK
*                         và ZTB_HDDT_LOG bằng đường riêng (SE54 không
*                         sinh TMG cho field STRING / RAWSTRING)
* 1.2       21/09/2026    cuongus - CuongUS        abapGit     Lock object
*                         EZTB_HDDT_TPL / EZTB_HDDT_TOK cho hai đường ghi
*                         thẳng vào bảng (MODIFY mẫu payload, DELETE bộ
*                         đệm token) — trước đó không khoá gì
* 1.3       22/09/2026    cuongus - CuongUS        abapGit     Nạp mẫu payload
*                         điền ZST_ADMIN_DATA với ZSOURCE = UPLOAD
* 1.4       23/09/2026    cuongus - CuongUS        S25K900131  FS v0.17 mục
*                         3.2: pop-up Input Parameters nhập Company Code,
*                         kiểm F_BKPF_BUK ACTVT 02; bảng có BUKRS chỉ hiện
*                         và chỉ sửa dòng của đúng công ty đó; thêm bảng
*                         ZTB_HDDT_PO (Nhóm 2 - trả lại hàng NCC)
* 1.5       30/09/2026    cuongus - CuongUS        DS4K900172  Tách hai ALV
*                         trên selection screen 1001 (docking container):
*                         bảng cấu hình / bảng log và
*                         vận hành chỉ xem (thêm ZTB_HDDT_GOM). INV, ITEM,
*                         GOM không có TMG nên xem bằng ALV chỉ đọc lọc
*                         theo BUKRS thay vì SM30 (trước đó báo lỗi 006)
*=====================================================================
REPORT zpg_hddt_config MESSAGE-ID zms_hddt.

TYPES: BEGIN OF ty_entry,
         seq      TYPE n LENGTH 2,
         area     TYPE c LENGTH 30,
         tabname  TYPE tabname,
         descr    TYPE c LENGTH 70,
         mandatory TYPE c LENGTH 1,
       END OF ty_entry.

*   >>> Begin of change 20260930_02 F-CUONGUS TR DS4K900172 - Tách 2 ALV cấu hình / chỉ xem
*DATA gt_entry TYPE STANDARD TABLE OF ty_entry WITH EMPTY KEY.
" Hai danh sách toàn cục: SALV giữ tham chiếu tới bảng truyền vào factory
" nên bảng phải sống suốt thời gian hiển thị
DATA gt_cfg  TYPE STANDARD TABLE OF ty_entry WITH EMPTY KEY.
DATA gt_view TYPE STANDARD TABLE OF ty_entry WITH EMPTY KEY.

" Màn hình nền cho hai lưới: selection screen 1001 do hệ thống tự sinh từ
" khai báo dưới đây (không cần tạo dynpro ở SE51), docking container gắn
" vào nó ở AT SELECTION-SCREEN OUTPUT. Cách gắn vào DEFAULT_SCREEN của
" màn hình list thử trước đó không hiện được control.
" GV_T1001 / GV_C1001: hệ thống tự khai báo kiểu C, gán ở LCL_CFG->RUN
SELECTION-SCREEN BEGIN OF SCREEN 1001 TITLE gv_t1001.
SELECTION-SCREEN COMMENT /1(79) gv_c1001.
SELECTION-SCREEN END OF SCREEN 1001.
*   <<< End of change 20260930_02

*---------------------------------------------------------------------*
* Biến toàn cục nhận giá trị từ CL_GUI_FRONTEND_SERVICES (quy ước:
* không dùng biến cục bộ — bẫy SYSTEM_POINTER_PENDING)
*---------------------------------------------------------------------*
DATA gt_file_list TYPE filetable.
DATA gt_file_bin  TYPE solix_tab.
DATA gv_file_full TYPE string.
DATA gv_file_rc   TYPE i.
DATA gv_file_len  TYPE i.

CLASS lcl_cfg DEFINITION FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    METHODS run.
    METHODS on_double_click
      FOR EVENT double_click OF cl_salv_events_table
      IMPORTING row column.
*   >>> Begin of change 20260930_02 F-CUONGUS TR DS4K900172 - Tách 2 ALV cấu hình / chỉ xem
    "! PBO của selection screen 1001: tạo hai lưới (một lần) và bỏ nút
    "! Execute - màn hình này chỉ để hiển thị
    METHODS pbo_1001.
    METHODS on_double_click_view
      FOR EVENT double_click OF cl_salv_events_table
      IMPORTING row column.
*   <<< End of change 20260930_02
  PRIVATE SECTION.
*   >>> Begin of change 20260930_02 F-CUONGUS TR DS4K900172 - Tách 2 ALV cấu hình / chỉ xem
*    DATA mo_alv TYPE REF TO cl_salv_table.
    "! Số dòng tối đa khi xem bảng dữ liệu vận hành
    CONSTANTS gc_max_rows TYPE i VALUE 5000.
    DATA mo_dock     TYPE REF TO cl_gui_docking_container.
    DATA mo_split    TYPE REF TO cl_gui_splitter_container.
    DATA mo_alv_cfg  TYPE REF TO cl_salv_table.
    DATA mo_alv_view TYPE REF TO cl_salv_table.
*   <<< End of change 20260930_02
    "! Company code người dùng nhập ở pop-up đầu tiên (FS v0.17 mục 3.2)
    DATA mv_bukrs TYPE bukrs.

    "! Lớp 2 của phân quyền: pop-up Input Parameters nhập Company Code và
    "! kiểm quyền trên đúng công ty đó. Không có quyền thì báo lỗi và hỏi
    "! lại - người dùng ở lại màn hình đầu, không vào được danh sách bảng.
    "! Cancel thì thoát chương trình.
    METHODS ask_bukrs
      RETURNING VALUE(r_ok) TYPE abap_bool.

    "! Bảng có trường BUKRS thì mở bảo trì giới hạn theo công ty đã nhập.
    "! Dò bằng RTTI thay vì liệt kê cứng để bảng cấu hình mới thêm sau
    "! cũng tự được lọc.
    METHODS has_bukrs
      IMPORTING i_tabname    TYPE tabname
      RETURNING VALUE(r_has) TYPE abap_bool.
    METHODS build_list.
    METHODS maintain
      IMPORTING i_tabname TYPE tabname.
*   >>> Begin of change 20260930_02 F-CUONGUS TR DS4K900172 - Tách 2 ALV cấu hình / chỉ xem
    "! Tiêu đề cột tiếng Việt cho hai lưới danh sách bảng
    METHODS set_columns
      IMPORTING io_alv  TYPE REF TO cl_salv_table
                i_view  TYPE abap_bool.

    "! Nhấn đôi ở lưới dưới: LOG / TOK đi đường riêng, bảng còn lại hiện
    "! ALV chỉ đọc - các bảng này không có TMG (MAINFLAG = N, không có
    "! TVDIR) nên VIEW_MAINTENANCE_CALL báo lỗi no_tvdir_entry.
    METHODS show_data
      IMPORTING i_tabname TYPE tabname.
*   <<< End of change 20260930_02

    "! ZTB_HDDT_TPL không sinh được Table Maintenance Generator vì có
    "! field kiểu STRING; bảo trì bằng nạp mẫu payload từ file JSON.
    METHODS maintain_tpl.

    "! Phần việc của MAINTAIN_TPL chạy TRONG khoá. Tách riêng để mọi
    "! đường thoát (RETURN) đều quay về MAINTAIN_TPL và nhả khoá đúng
    "! một chỗ — ABAP không có finally cho luồng thường.
    METHODS load_tpl
      IMPORTING i_provider TYPE zde_hddt_prov
                i_action   TYPE zde_hddt_action.

    "! ZTB_HDDT_TOK là bộ đệm token, chỉ xem và xoá khi cần đăng nhập lại.
    METHODS maintain_tok.

    "! Phần việc của MAINTAIN_TOK chạy TRONG khoá.
    METHODS clear_tok.

    "! ZTB_HDDT_LOG xem bằng chương trình log, không bảo trì tay.
    METHODS maintain_log.
ENDCLASS.


CLASS lcl_cfg IMPLEMENTATION.

  METHOD ask_bukrs.

    DATA lt_fields TYPE STANDARD TABLE OF sval WITH DEFAULT KEY.
    DATA lv_rc     TYPE c LENGTH 1.

    GET PARAMETER ID 'BUK' FIELD mv_bukrs.

    DO.
      " T001-BUKRS: pop-up tự có search help chuẩn theo bảng T001
      lt_fields = VALUE #( ( tabname = 'T001' fieldname = 'BUKRS'
                             fieldtext = 'Company Code' value = mv_bukrs
                             field_obl = abap_true ) ).
      CALL FUNCTION 'POPUP_GET_VALUES'
        EXPORTING
          popup_title     = 'Input Parameters'
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
        r_ok = abap_false.
        RETURN.
      ENDIF.
      mv_bukrs = lt_fields[ 1 ]-value.
      TRANSLATE mv_bukrs TO UPPER CASE.

      " Xoá kết quả lần thử trước: SELECT không thấy dòng thì KHÔNG ghi
      " đè biến đích, giữ nguyên X cũ là lọt qua kiểm tra
      DATA lv_exists TYPE abap_bool.
      CLEAR lv_exists.
      SELECT SINGLE @abap_true FROM t001
        WHERE bukrs = @mv_bukrs
        INTO @lv_exists.
      IF lv_exists <> abap_true.
        MESSAGE s071(zms_hddt) WITH mv_bukrs DISPLAY LIKE 'E'.
        CONTINUE.
      ENDIF.

      " F_BKPF_BUK - đã có sẵn trong bộ role FI, ACTVT 02 = thay đổi
      AUTHORITY-CHECK OBJECT 'F_BKPF_BUK'
        ID 'BUKRS' FIELD mv_bukrs
        ID 'ACTVT' FIELD '02'.
      IF sy-subrc <> 0.
        MESSAGE s066(zms_hddt) WITH mv_bukrs DISPLAY LIKE 'E'.
        CONTINUE.
      ENDIF.

      SET PARAMETER ID 'BUK' FIELD mv_bukrs.
      r_ok = abap_true.
      RETURN.
    ENDDO.

  ENDMETHOD.


  METHOD has_bukrs.

    cl_abap_typedescr=>describe_by_name(
      EXPORTING  p_name         = i_tabname
      RECEIVING  p_descr_ref    = DATA(lo_type)
      EXCEPTIONS type_not_found = 1
                 OTHERS         = 2 ).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    TRY.
        DATA(lo_struct) = CAST cl_abap_structdescr( lo_type ).
      CATCH cx_sy_move_cast_error.
        RETURN.
    ENDTRY.
    r_has = xsdbool( line_exists( lo_struct->components[ name = 'BUKRS' ] ) ).

  ENDMETHOD.


  METHOD build_list.

*   >>> Begin of change 20260930_02 F-CUONGUS TR DS4K900172 - Tách 2 ALV cấu hình / chỉ xem
*    " Thứ tự trong danh sách = thứ tự nên cấu hình khi triển khai mới
*    gt_entry = VALUE #(
*      ( seq = '01' area = 'Nhà cung cấp'  tabname = 'ZTB_HDDT_PROV'
*        descr = 'Danh mục nhà cung cấp + tên lớp adapter' mandatory = 'X' )
*      ( seq = '02' area = 'Kết nối'       tabname = 'ZTB_HDDT_CONN'
*        descr = 'RFC destination / base URL / cách xác thực' mandatory = 'X' )
*      ( seq = '03' area = 'Endpoint'      tabname = 'ZTB_HDDT_ACT'
*        descr = 'Đường dẫn API theo từng nghiệp vụ' mandatory = 'X' )
*      ( seq = '04' area = 'Tài khoản'     tabname = 'ZTB_HDDT_CRED'
*        descr = 'Tài khoản API, MST, mẫu số, ký hiệu theo công ty' mandatory = 'X' )
*      ( seq = '05' area = 'Nguồn dữ liệu' tabname = 'ZTB_HDDT_SRC'
*        descr = 'Lớp đọc chứng từ nguồn theo công ty' mandatory = 'X' )
*      ( seq = '06' area = 'Tham số'       tabname = 'ZTB_HDDT_PARM'
*        descr = 'Tham số chung: nhà cung cấp đang dùng, thông tin bên bán' )
*      ( seq = '07' area = 'Ngày hoá đơn'  tabname = 'ZTB_HDDT_DATE'
*        descr = 'Nguồn ngày lập hoá đơn theo công ty' )
*      ( seq = '08' area = 'Ánh xạ giá trị' tabname = 'ZTB_HDDT_MAP'
*        descr = 'Thuế suất, hình thức thanh toán, tài khoản doanh thu' )
*      ( seq = '09' area = 'Ánh xạ trạng thái' tabname = 'ZTB_HDDT_STAT'
*        descr = 'Mã trả về của NCC -> trạng thái trong SAP' )
*      ( seq = '10' area = 'Mẫu payload'   tabname = 'ZTB_HDDT_TPL'
*        descr = 'Mẫu payload adapter template - nạp từ file JSON' )
*      ( seq = '11' area = 'Sổ hoá đơn'    tabname = 'ZTB_HDDT_INV'
*        descr = 'Sổ đăng ký hoá đơn đã tích hợp (chỉ xem)' )
*      ( seq = '12' area = 'Chi tiết HH'   tabname = 'ZTB_HDDT_ITEM'
*        descr = 'Chi tiết hàng hoá đã phát hành (chỉ xem)' )
*      ( seq = '13' area = 'Log API'       tabname = 'ZTB_HDDT_LOG'
*        descr = 'Log request/response - mở chương trình log' )
*      ( seq = '14' area = 'Token'         tabname = 'ZTB_HDDT_TOK'
*        descr = 'Bộ đệm access token - xem và xoá khi cần' )
*      ( seq = '15' area = 'Trả hàng NCC'  tabname = 'ZTB_HDDT_PO'
*        descr = 'Loại đơn hàng mua được phát hành HĐ (Nhóm 2, FS v0.17)' ) ).
    " Lưới trên - bảng cấu hình, thứ tự = thứ tự nên cấu hình khi triển
    " khai mới
    gt_cfg = VALUE #(
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
        descr = 'Mẫu payload adapter template - nạp từ file JSON' )
      ( seq = '11' area = 'Trả hàng NCC'  tabname = 'ZTB_HDDT_PO'
        descr = 'Loại đơn hàng mua được phát hành HĐ (Nhóm 2, FS v0.17)' ) ).

    " Lưới dưới - dữ liệu chương trình tự ghi khi chạy, chỉ xem
    gt_view = VALUE #(
      ( seq = '01' area = 'Sổ hoá đơn'    tabname = 'ZTB_HDDT_INV'
        descr = 'Sổ đăng ký hoá đơn đã tích hợp' )
      ( seq = '02' area = 'Chi tiết HH'   tabname = 'ZTB_HDDT_ITEM'
        descr = 'Chi tiết hàng hoá đã phát hành' )
      ( seq = '03' area = 'Hoá đơn gom'   tabname = 'ZTB_HDDT_GOM'
        descr = 'Chứng từ thành viên của hoá đơn gom' )
      ( seq = '04' area = 'Log API'       tabname = 'ZTB_HDDT_LOG'
        descr = 'Log request/response - mở chương trình log' )
      ( seq = '05' area = 'Token'         tabname = 'ZTB_HDDT_TOK'
        descr = 'Bộ đệm access token - xem và xoá khi cần' ) ).
*   <<< End of change 20260930_02

  ENDMETHOD.


  METHOD run.

    IF ask_bukrs( ) = abap_false.
      RETURN.
    ENDIF.
    build_list( ).

*   >>> Begin of change 20260930_02 F-CUONGUS TR DS4K900172 - Tách 2 ALV cấu hình / chỉ xem
*    TRY.
*        cl_salv_table=>factory( IMPORTING r_salv_table = mo_alv
*                                CHANGING  t_table      = gt_entry ).
*      CATCH cx_salv_msg INTO DATA(lx).
*        MESSAGE lx->get_text( ) TYPE 'S' DISPLAY LIKE 'E'.
*        RETURN.
*    ENDTRY.

*    mo_alv->get_functions( )->set_all( abap_true ).
*    mo_alv->get_columns( )->set_optimize( abap_true ).

*    DATA lv_title TYPE lvc_title.
*    lv_title = 'Cấu hình tích hợp hoá đơn điện tử - nhấn đôi để bảo trì'.
*    mo_alv->get_display_settings( )->set_list_header( lv_title ).

*    SET HANDLER me->on_double_click FOR mo_alv->get_event( ).
*    mo_alv->display( ).

    " Một màn hình hai lưới trên selection screen 1001; control tạo ở PBO
    " của màn hình (PBO_1001) vì docking container phải gắn vào dynpro đã
    " có. Back / Exit / Cancel trả về đây và kết thúc chương trình.
    gv_t1001 = 'Cấu hình tích hợp hoá đơn điện tử'.
    gv_c1001 = |Công ty { mv_bukrs }: lưới trên nhấn đôi để bảo trì, | &&
               |lưới dưới nhấn đôi để xem (chỉ đọc)|.
    CALL SELECTION-SCREEN 1001.
*   <<< End of change 20260930_02

  ENDMETHOD.


  METHOD pbo_1001.

*   >>> Begin of change 20260930_02 F-CUONGUS TR DS4K900172 - Tách 2 ALV cấu hình / chỉ xem
    " Status chuẩn của selection screen có Execute / Save variant / Print
    " - vô nghĩa ở đây. Phải đặt lại mỗi lần PBO.
    DATA lt_excl TYPE STANDARD TABLE OF sy-ucomm WITH DEFAULT KEY.
    lt_excl = VALUE #( ( 'ONLI' ) ( 'CRET' ) ( 'PRIN' ) ( 'SJOB' )
                       ( 'SPOS' ) ( 'GET' ) ( 'VDEL' ) ( 'VSHO' ) ).
    CALL FUNCTION 'RS_SET_SELSCREEN_STATUS'
      EXPORTING
        p_status  = sy-pfkey
      TABLES
        p_exclude = lt_excl.

    " PBO chạy lại sau mỗi lần quay về màn hình - control chỉ tạo một lần
    IF mo_dock IS BOUND.
      RETURN.
    ENDIF.

    mo_dock = NEW cl_gui_docking_container(
                    repid = sy-repid
                    dynnr = '1001'
                    side  = cl_gui_docking_container=>dock_at_bottom
                    ratio = 92 ).
    mo_split = NEW cl_gui_splitter_container(
                     parent  = mo_dock
                     rows    = 2
                     columns = 1 ).
    " 11 bảng cấu hình ở trên, 5 bảng chỉ xem ở dưới
    mo_split->set_row_height( id = 1 height = 62 ).

    TRY.
        cl_salv_table=>factory(
          EXPORTING r_container  = mo_split->get_container( row = 1 column = 1 )
          IMPORTING r_salv_table = mo_alv_cfg
          CHANGING  t_table      = gt_cfg ).
        cl_salv_table=>factory(
          EXPORTING r_container  = mo_split->get_container( row = 2 column = 1 )
          IMPORTING r_salv_table = mo_alv_view
          CHANGING  t_table      = gt_view ).
      CATCH cx_salv_msg INTO DATA(lx).
        MESSAGE lx->get_text( ) TYPE 'S' DISPLAY LIKE 'E'.
        RETURN.
    ENDTRY.

    DATA lv_title TYPE lvc_title.
    lv_title = |Bảng cấu hình - công ty { mv_bukrs } - nhấn đôi để bảo trì|.
    mo_alv_cfg->get_display_settings( )->set_list_header( lv_title ).
    set_columns( io_alv = mo_alv_cfg i_view = abap_false ).
    SET HANDLER me->on_double_click FOR mo_alv_cfg->get_event( ).
    mo_alv_cfg->display( ).

    lv_title = |Dữ liệu vận hành / log - công ty { mv_bukrs } - nhấn đôi để xem (chỉ đọc)|.
    mo_alv_view->get_display_settings( )->set_list_header( lv_title ).
    set_columns( io_alv = mo_alv_view i_view = abap_true ).
    SET HANDLER me->on_double_click_view FOR mo_alv_view->get_event( ).
    mo_alv_view->display( ).
*   <<< End of change 20260930_02

  ENDMETHOD.


  METHOD on_double_click.

*   >>> Begin of change 20260930_02 F-CUONGUS TR DS4K900172 - Tách 2 ALV cấu hình / chỉ xem
*    IF row < 1 OR row > lines( gt_entry ).
*      RETURN.
*    ENDIF.
*    maintain( gt_entry[ row ]-tabname ).

    IF row < 1 OR row > lines( gt_cfg ).
      RETURN.
    ENDIF.
    maintain( gt_cfg[ row ]-tabname ).
*   <<< End of change 20260930_02

  ENDMETHOD.


  METHOD on_double_click_view.

*   >>> Begin of change 20260930_02 F-CUONGUS TR DS4K900172 - Tách 2 ALV cấu hình / chỉ xem
    IF row < 1 OR row > lines( gt_view ).
      RETURN.
    ENDIF.
    show_data( gt_view[ row ]-tabname ).
*   <<< End of change 20260930_02

  ENDMETHOD.


  METHOD maintain.

    " SE54 không sinh TMG cho bảng có field STRING / RAWSTRING
    CASE i_tabname.
      WHEN 'ZTB_HDDT_TPL'.
        maintain_tpl( ).
        RETURN.
*   >>> Begin of change 20260930_02 F-CUONGUS TR DS4K900172 - Tách 2 ALV cấu hình / chỉ xem
      " TOK / LOG chuyển xuống lưới chỉ xem (SHOW_DATA)
*      WHEN 'ZTB_HDDT_TOK'.
*        maintain_tok( ).
*        RETURN.
*      WHEN 'ZTB_HDDT_LOG'.
*        maintain_log( ).
*        RETURN.

*   <<< End of change 20260930_02
      WHEN OTHERS.
        " bảng còn lại dùng Table Maintenance Generator
    ENDCASE.

    " DEFAULT KEY: code chuẩn của view maintenance dùng COLLECT trên bảng
    " này; EMPTY KEY làm COLLECT dump ITAB_NON_NUMERIC_COMPONENT
    DATA lt_excl TYPE STANDARD TABLE OF vimexclfun WITH DEFAULT KEY.

    " FS v0.17 mục 3.2: bảng có Company Code chỉ hiển thị và chỉ cho sửa
    " dòng có BUKRS bằng đúng công ty đã nhập ở pop-up đầu tiên. Điều kiện
    " EQ trên trường khoá nên SM30 điền sẵn BUKRS cho dòng mới.
    " Sáu bảng kỹ thuật không có BUKRS (quyết định 22/09/2026) - phân quyền
    " bằng quyền T-code.
    DATA lt_sel TYPE STANDARD TABLE OF vimsellist WITH DEFAULT KEY.
    IF has_bukrs( i_tabname ) = abap_true.
      lt_sel = VALUE #( ( viewfield = 'BUKRS' operator = 'EQ' value = mv_bukrs ) ).
    ENDIF.

    CALL FUNCTION 'VIEW_MAINTENANCE_CALL'
      EXPORTING
        action                       = 'U'
        view_name                    = i_tabname
      TABLES
        dba_sellist                  = lt_sel
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
*   >>> Begin of change 20260930_02 F-CUONGUS TR DS4K900172 - Tách 2 ALV cấu hình / chỉ xem
      " Gọi từ handler của control trên màn hình list: báo lỗi kiểu S
      " hiển thị như E, không dùng E để người dùng ở lại danh sách
*      WHEN 8 OR 13.
*        MESSAGE e006(zms_hddt) WITH i_tabname.
*      WHEN 7 OR 9 OR 4 OR 10.
*        MESSAGE e007(zms_hddt) WITH i_tabname.
*      WHEN OTHERS.
*        MESSAGE e008(zms_hddt) WITH i_tabname sy-subrc.

      WHEN 8 OR 13.
        MESSAGE s006(zms_hddt) WITH i_tabname DISPLAY LIKE 'E'.
      WHEN 7 OR 9 OR 4 OR 10.
        MESSAGE s007(zms_hddt) WITH i_tabname DISPLAY LIKE 'E'.
      WHEN OTHERS.
        MESSAGE s008(zms_hddt) WITH i_tabname sy-subrc DISPLAY LIKE 'E'.
*   <<< End of change 20260930_02
    ENDCASE.

  ENDMETHOD.

  METHOD maintain_tpl.

    DATA lt_fields TYPE STANDARD TABLE OF sval WITH DEFAULT KEY.
    DATA lv_rc     TYPE c LENGTH 1.

    lt_fields = VALUE #(
      ( tabname = 'ZTB_HDDT_TPL' fieldname = 'PROVIDER' fieldtext = 'Nhà cung cấp' )
      ( tabname = 'ZTB_HDDT_TPL' fieldname = 'ACTION'   fieldtext = 'Mã nghiệp vụ' ) ).

    CALL FUNCTION 'POPUP_GET_VALUES'
      EXPORTING
        popup_title     = 'Mẫu payload cần bảo trì'
      IMPORTING
        returncode      = lv_rc
      TABLES
        fields          = lt_fields
      EXCEPTIONS
        error_in_fields = 1
        OTHERS          = 2.
    IF sy-subrc <> 0 OR lv_rc = 'A'.
      RETURN.
    ENDIF.

    DATA ls_tpl TYPE ztb_hddt_tpl.
    ls_tpl-provider = lt_fields[ 1 ]-value.
    ls_tpl-action   = lt_fields[ 2 ]-value.
    TRANSLATE ls_tpl-provider TO UPPER CASE.
    TRANSLATE ls_tpl-action   TO UPPER CASE.
    IF ls_tpl-provider IS INITIAL OR ls_tpl-action IS INITIAL.
      MESSAGE 'Phải nhập nhà cung cấp và mã nghiệp vụ.' TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    " Khoá TRƯỚC khi đọc: dưới kia còn SELECT lấy độ dài mẫu hiện có để
    " hỏi người dùng rồi mới ghi đè. Đọc-để-quyết-định mà không khoá là
    " hai quản trị viên nạp cùng một mẫu thì người sau ghi đè người
    " trước, không ai biết mẫu vừa nạp đã bị mất.
    " _SCOPE = '1': khoá thuộc chương trình hội thoại, không chuyển sang
    " update task; COMMIT WORK không tự nhả, mình nhả bằng DEQUEUE.
    CALL FUNCTION 'ENQUEUE_EZTB_HDDT_TPL'
      EXPORTING
        mode_ztb_hddt_tpl = 'E'
        mandt             = sy-mandt
        provider          = ls_tpl-provider
        action            = ls_tpl-action
        _scope            = '1'
      EXCEPTIONS
        foreign_lock      = 1
        system_failure    = 2
        OTHERS            = 3.
    IF sy-subrc = 1.
*   >>> Begin of change 20260930_02 F-CUONGUS TR DS4K900172 - Tách 2 ALV cấu hình / chỉ xem
*      MESSAGE e051(zms_hddt) WITH ls_tpl-provider ls_tpl-action sy-msgv1.
*      RETURN.
*    ELSEIF sy-subrc <> 0.
*      MESSAGE e052(zms_hddt) WITH 'ZTB_HDDT_TPL'.

      MESSAGE s051(zms_hddt) WITH ls_tpl-provider ls_tpl-action sy-msgv1 DISPLAY LIKE 'E'.
      RETURN.
    ELSEIF sy-subrc <> 0.
      MESSAGE s052(zms_hddt) WITH 'ZTB_HDDT_TPL' DISPLAY LIKE 'E'.
*   <<< End of change 20260930_02
      RETURN.
    ENDIF.

    load_tpl( i_provider = ls_tpl-provider
              i_action   = ls_tpl-action ).

    CALL FUNCTION 'DEQUEUE_EZTB_HDDT_TPL'
      EXPORTING
        mode_ztb_hddt_tpl = 'E'
        mandt             = sy-mandt
        provider          = ls_tpl-provider
        action            = ls_tpl-action
        _scope            = '1'.

  ENDMETHOD.


  METHOD load_tpl.

    DATA ls_tpl TYPE ztb_hddt_tpl.
    ls_tpl-provider = i_provider.
    ls_tpl-action   = i_action.

    SELECT SINGLE tpl_body
      FROM ztb_hddt_tpl
      WHERE provider = @ls_tpl-provider
        AND action   = @ls_tpl-action
      INTO @DATA(lv_old).

    DATA(lv_quest) = COND string(
      WHEN sy-subrc = 0
      THEN |Mẫu hiện có { strlen( lv_old ) } ký tự. Nạp lại từ file JSON?|
      ELSE |Chưa có mẫu cho { ls_tpl-provider } / { ls_tpl-action }. Nạp từ file JSON?| ).

    DATA lv_answer TYPE c LENGTH 1.
    CALL FUNCTION 'POPUP_TO_CONFIRM'
      EXPORTING
        titlebar      = 'Bảo trì mẫu payload'
        text_question = lv_quest
      IMPORTING
        answer        = lv_answer
      EXCEPTIONS
        OTHERS        = 1.
    IF lv_answer <> '1'.
      RETURN.
    ENDIF.

    CLEAR: gt_file_list, gt_file_bin, gv_file_full, gv_file_rc, gv_file_len.
    cl_gui_frontend_services=>file_open_dialog(
      EXPORTING
        window_title   = 'Chọn file mẫu payload JSON'
        file_filter    = 'JSON (*.json)|*.json|Tất cả (*.*)|*.*'
        multiselection = abap_false
      CHANGING
        file_table     = gt_file_list
        rc             = gv_file_rc
      EXCEPTIONS
        OTHERS         = 1 ).
    IF sy-subrc <> 0 OR gv_file_rc < 1.
      RETURN.
    ENDIF.
    gv_file_full = gt_file_list[ 1 ]-filename.

    cl_gui_frontend_services=>gui_upload(
      EXPORTING
        filename   = gv_file_full
        filetype   = 'BIN'
      IMPORTING
        filelength = gv_file_len
      CHANGING
        data_tab   = gt_file_bin
      EXCEPTIONS
        OTHERS     = 1 ).
    IF sy-subrc <> 0 OR gv_file_len = 0.
      MESSAGE 'Không đọc được file mẫu payload.' TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    DATA lv_xstr TYPE xstring.
    CALL FUNCTION 'SCMS_BINARY_TO_XSTRING'
      EXPORTING
        input_length = gv_file_len
      IMPORTING
        buffer       = lv_xstr
      TABLES
        binary_tab   = gt_file_bin.

    ls_tpl-tpl_body = zcl_hddt_platform=>get( )->xstring_to_string(
                        i_data     = lv_xstr
                        i_encoding = `UTF-8` ).
    IF ls_tpl-tpl_body IS INITIAL.
      MESSAGE 'File mẫu payload rỗng.' TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.
    ls_tpl-descr   = gv_file_full.
    ls_tpl-xactive = abap_true.

    " lv_old co gia tri nghia la dong da ton tai -> chi cap nhat CHANGED_*
    zcl_hddt_log=>set_admin( EXPORTING i_new  = xsdbool( lv_old IS INITIAL )
                             CHANGING  cs_row = ls_tpl ).

    MODIFY ztb_hddt_tpl FROM ls_tpl.
    IF sy-subrc <> 0.
      ROLLBACK WORK.
      MESSAGE 'Không ghi được mẫu payload vào ZTB_HDDT_TPL.' TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.
    COMMIT WORK AND WAIT.
    zcl_hddt_factory=>reset( ).

    " Ghi trực tiếp nên KHÔNG vào transport: phải nạp lại trên từng hệ
    DATA(lv_done) = |Đã nạp mẫu { ls_tpl-provider } / { ls_tpl-action } | &&
                    |({ strlen( ls_tpl-tpl_body ) } ký tự). Bản ghi không vào | &&
                    |transport, phải nạp lại trên hệ QAS / PRD.|.
    MESSAGE lv_done TYPE 'S'.

  ENDMETHOD.


  METHOD maintain_tok.

    " Khoá CẢ BẢNG trong client: đối số khoá có tính tiền tố, không
    " truyền PROVIDER/CONNID/BUKRS/APIUSER nghĩa là khoá mọi dòng. Cần
    " vậy vì dưới kia là DELETE FROM ztb_hddt_tok (xoá sạch) — trong lúc
    " xoá mà một job nền vừa ghi token mới thì token đó biến mất ngay,
    " lần gọi API sau dùng token rỗng.
    CALL FUNCTION 'ENQUEUE_EZTB_HDDT_TOK'
      EXPORTING
        mode_ztb_hddt_tok = 'E'
        mandt             = sy-mandt
        _scope            = '1'
      EXCEPTIONS
        foreign_lock      = 1
        system_failure    = 2
        OTHERS            = 3.
    IF sy-subrc = 1.
*   >>> Begin of change 20260930_02 F-CUONGUS TR DS4K900172 - Tách 2 ALV cấu hình / chỉ xem
*      MESSAGE e053(zms_hddt) WITH sy-msgv1.
*      RETURN.
*    ELSEIF sy-subrc <> 0.
*      MESSAGE e052(zms_hddt) WITH 'ZTB_HDDT_TOK'.

      MESSAGE s053(zms_hddt) WITH sy-msgv1 DISPLAY LIKE 'E'.
      RETURN.
    ELSEIF sy-subrc <> 0.
      MESSAGE s052(zms_hddt) WITH 'ZTB_HDDT_TOK' DISPLAY LIKE 'E'.
*   <<< End of change 20260930_02
      RETURN.
    ENDIF.

    clear_tok( ).

    CALL FUNCTION 'DEQUEUE_EZTB_HDDT_TOK'
      EXPORTING
        mode_ztb_hddt_tok = 'E'
        mandt             = sy-mandt
        _scope            = '1'.

  ENDMETHOD.


  METHOD clear_tok.

    SELECT provider, connid, bukrs, apiuser, valid_to, created_at
      FROM ztb_hddt_tok
      ORDER BY provider, connid, bukrs, apiuser
      INTO TABLE @DATA(lt_tok)
      UP TO 200 ROWS.
    IF lt_tok IS INITIAL.
      MESSAGE 'Bộ đệm token đang rỗng.' TYPE 'S'.
      RETURN.
    ENDIF.

    DATA lo_alv TYPE REF TO cl_salv_table.
    TRY.
        cl_salv_table=>factory( IMPORTING r_salv_table = lo_alv
                                CHANGING  t_table      = lt_tok ).
        lo_alv->set_screen_popup( start_column = 5
                                  end_column   = 110
                                  start_line   = 3
                                  end_line     = 20 ).
        lo_alv->get_columns( )->set_optimize( abap_true ).
        lo_alv->display( ).
      CATCH cx_salv_msg INTO DATA(lx_alv).
        MESSAGE lx_alv->get_text( ) TYPE 'S' DISPLAY LIKE 'E'.
        RETURN.
    ENDTRY.

    DATA(lv_quest) = |Xoá toàn bộ { lines( lt_tok ) } dòng bộ đệm token | &&
                     |để buộc đăng nhập lại nhà cung cấp?|.
    DATA lv_answer TYPE c LENGTH 1.
    CALL FUNCTION 'POPUP_TO_CONFIRM'
      EXPORTING
        titlebar      = 'Bộ đệm access token'
        text_question = lv_quest
      IMPORTING
        answer        = lv_answer
      EXCEPTIONS
        OTHERS        = 1.
    IF lv_answer <> '1'.
      RETURN.
    ENDIF.

    DELETE FROM ztb_hddt_tok.
    IF sy-subrc <> 0.
      ROLLBACK WORK.
      MESSAGE 'Không xoá được bộ đệm token.' TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.
    COMMIT WORK AND WAIT.
    MESSAGE 'Đã xoá bộ đệm token, lần gọi sau sẽ đăng nhập lại.' TYPE 'S'.

  ENDMETHOD.


  METHOD set_columns.

*   >>> Begin of change 20260930_02 F-CUONGUS TR DS4K900172 - Tách 2 ALV cấu hình / chỉ xem
    DATA(lo_cols) = io_alv->get_columns( ).
    lo_cols->set_optimize( abap_true ).
    TRY.
        DATA(lo_col) = lo_cols->get_column( 'SEQ' ).
        lo_col->set_short_text( 'STT' ).
        lo_col->set_medium_text( 'STT' ).
        lo_col->set_long_text( 'STT' ).
        lo_col = lo_cols->get_column( 'AREA' ).
        lo_col->set_short_text( 'Nhóm' ).
        lo_col->set_medium_text( 'Nhóm' ).
        lo_col->set_long_text( 'Nhóm' ).
        lo_col = lo_cols->get_column( 'TABNAME' ).
        lo_col->set_short_text( 'Bảng' ).
        lo_col->set_medium_text( 'Tên bảng' ).
        lo_col->set_long_text( 'Tên bảng' ).
        lo_col = lo_cols->get_column( 'DESCR' ).
        lo_col->set_short_text( 'Nội dung' ).
        lo_col->set_medium_text( 'Nội dung' ).
        lo_col->set_long_text( 'Nội dung' ).
        lo_col = lo_cols->get_column( 'MANDATORY' ).
        lo_col->set_short_text( 'Bắt buộc' ).
        lo_col->set_medium_text( 'Bắt buộc' ).
        lo_col->set_long_text( 'Bắt buộc' ).
        " Bảng chỉ xem không có khái niệm bắt buộc cấu hình
        lo_col->set_visible( xsdbool( i_view = abap_false ) ).
      CATCH cx_salv_not_found.
        " cột cố định của TY_ENTRY - không xảy ra
    ENDTRY.
*   <<< End of change 20260930_02

  ENDMETHOD.


  METHOD show_data.

*   >>> Begin of change 20260930_02 F-CUONGUS TR DS4K900172 - Tách 2 ALV cấu hình / chỉ xem
    CASE i_tabname.
      WHEN 'ZTB_HDDT_LOG'.
        maintain_log( ).
        RETURN.
      WHEN 'ZTB_HDDT_TOK'.
        maintain_tok( ).
        RETURN.
      WHEN OTHERS.
        " bảng còn lại xem bằng ALV chỉ đọc
    ENDCASE.

    DATA lr_data TYPE REF TO data.
    FIELD-SYMBOLS <lt_data> TYPE STANDARD TABLE.
    TRY.
        CREATE DATA lr_data TYPE STANDARD TABLE OF (i_tabname) WITH DEFAULT KEY.
      CATCH cx_sy_create_data_error.
        MESSAGE s006(zms_hddt) WITH i_tabname DISPLAY LIKE 'E'.
        RETURN.
    ENDTRY.
    ASSIGN lr_data->* TO <lt_data>.

    " Cùng quy tắc FS v0.17 mục 3.2 như lưới cấu hình: bảng có BUKRS chỉ
    " hiện dòng của công ty đã nhập (quyền đã kiểm ở ASK_BUKRS)
    DATA(lv_bukrs) = mv_bukrs.
    DATA(lv_where) = COND string( WHEN has_bukrs( i_tabname ) = abap_true
                                  THEN `BUKRS = @LV_BUKRS` ).
    TRY.
        SELECT * FROM (i_tabname)
          WHERE (lv_where)
          ORDER BY PRIMARY KEY
          INTO TABLE @<lt_data>
          UP TO @gc_max_rows ROWS.
      CATCH cx_sy_dynamic_osql_error INTO DATA(lx_sql).
        MESSAGE lx_sql->get_text( ) TYPE 'S' DISPLAY LIKE 'E'.
        RETURN.
    ENDTRY.
    IF <lt_data> IS INITIAL.
      MESSAGE |{ i_tabname }: chưa có dòng nào của công ty { mv_bukrs }.| TYPE 'S'.
      RETURN.
    ENDIF.

    DATA lo_alv TYPE REF TO cl_salv_table.
    TRY.
        cl_salv_table=>factory( IMPORTING r_salv_table = lo_alv
                                CHANGING  t_table      = <lt_data> ).
      CATCH cx_salv_msg INTO DATA(lx_alv).
        MESSAGE lx_alv->get_text( ) TYPE 'S' DISPLAY LIKE 'E'.
        RETURN.
    ENDTRY.
    lo_alv->get_functions( )->set_all( abap_true ).
    lo_alv->get_columns( )->set_optimize( abap_true ).
    TRY.
        lo_alv->get_columns( )->get_column( 'MANDT' )->set_technical( abap_true ).
      CATCH cx_salv_not_found.
        " bảng không phụ thuộc client
    ENDTRY.

    DATA lv_title TYPE lvc_title.
    lv_title = COND #(
      WHEN lines( <lt_data> ) >= gc_max_rows
      THEN |{ i_tabname } - công ty { mv_bukrs } - chỉ xem { gc_max_rows } dòng đầu|
      ELSE |{ i_tabname } - công ty { mv_bukrs } - chỉ xem, { lines( <lt_data> ) } dòng| ).
    lo_alv->get_display_settings( )->set_list_header( lv_title ).
    lo_alv->display( ).
*   <<< End of change 20260930_02

  ENDMETHOD.


  METHOD maintain_log.

    SUBMIT zpg_hddt_log VIA SELECTION-SCREEN AND RETURN.

  ENDMETHOD.


ENDCLASS.


START-OF-SELECTION.
  DATA(go_cfg) = NEW lcl_cfg( ).
  go_cfg->run( ).

*   >>> Begin of change 20260930_02 F-CUONGUS TR DS4K900172 - Tách 2 ALV cấu hình / chỉ xem
AT SELECTION-SCREEN OUTPUT.
  IF sy-dynnr = '1001' AND go_cfg IS BOUND.
    go_cfg->pbo_1001( ).
  ENDIF.
*   <<< End of change 20260930_02