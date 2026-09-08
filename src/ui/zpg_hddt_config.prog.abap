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
  PRIVATE SECTION.
    DATA mo_alv TYPE REF TO cl_salv_table.
    METHODS build_list.
    METHODS maintain
      IMPORTING i_tabname TYPE tabname.

    "! ZTB_HDDT_TPL không sinh được Table Maintenance Generator vì có
    "! field kiểu STRING; bảo trì bằng nạp mẫu payload từ file JSON.
    METHODS maintain_tpl.

    "! ZTB_HDDT_TOK là bộ đệm token, chỉ xem và xoá khi cần đăng nhập lại.
    METHODS maintain_tok.

    "! ZTB_HDDT_LOG xem bằng chương trình log, không bảo trì tay.
    METHODS maintain_log.
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
        descr = 'Mẫu payload adapter template - nạp từ file JSON' )
      ( seq = '11' area = 'Sổ hoá đơn'    tabname = 'ZTB_HDDT_INV'
        descr = 'Sổ đăng ký hoá đơn đã tích hợp (chỉ xem)' )
      ( seq = '12' area = 'Chi tiết HH'   tabname = 'ZTB_HDDT_ITEM'
        descr = 'Chi tiết hàng hoá đã phát hành (chỉ xem)' )
      ( seq = '13' area = 'Log API'       tabname = 'ZTB_HDDT_LOG'
        descr = 'Log request/response - mở chương trình log' )
      ( seq = '14' area = 'Token'         tabname = 'ZTB_HDDT_TOK'
        descr = 'Bộ đệm access token - xem và xoá khi cần' ) ).

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

    " SE54 không sinh TMG cho bảng có field STRING / RAWSTRING
    CASE i_tabname.
      WHEN 'ZTB_HDDT_TPL'.
        maintain_tpl( ).
        RETURN.
      WHEN 'ZTB_HDDT_TOK'.
        maintain_tok( ).
        RETURN.
      WHEN 'ZTB_HDDT_LOG'.
        maintain_log( ).
        RETURN.
      WHEN OTHERS.
        " bảng còn lại dùng Table Maintenance Generator
    ENDCASE.

    " DEFAULT KEY: code chuẩn của view maintenance dùng COLLECT trên bảng
    " này; EMPTY KEY làm COLLECT dump ITAB_NON_NUMERIC_COMPONENT
    DATA lt_excl TYPE STANDARD TABLE OF vimexclfun WITH DEFAULT KEY.

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


  METHOD maintain_log.

    SUBMIT zpg_hddt_log VIA SELECTION-SCREEN AND RETURN.

  ENDMETHOD.


ENDCLASS.


START-OF-SELECTION.
  DATA(go_cfg) = NEW lcl_cfg( ).
  go_cfg->run( ).
