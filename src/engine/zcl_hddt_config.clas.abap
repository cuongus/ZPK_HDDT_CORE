*=====================================================================
* Tên/Mã     : ZCL_HDDT_CONFIG
* Mô tả chung: Lớp truy cập CẤU HÌNH duy nhất của HĐĐT Core. Mọi bảng
*              ZTB_HDDT_* chỉ được đọc qua lớp này (có buffer trong
*              bộ nhớ) — engine và adapter không SELECT trực tiếp.
*              Nhờ vậy khi bổ sung/đổi nguồn cấu hình chỉ sửa 1 nơi.
* Tham Số    : Singleton — dùng ZCL_HDDT_CONFIG=>get_instance( )
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       28/08/2026    cuongus - CuongUS        abapGit     Tạo mới
*=====================================================================
CLASS zcl_hddt_config DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE .

  PUBLIC SECTION.

    "! Danh sách dải số. Khoá phải KHỚP khoá bảng ZTB_HDDT_CRED: FS v0.17
    "! mục 3.2 thêm GJAHR và mẫu số (TEMPLATE) vào khoá vì một công ty
    "! đăng ký nhiều dải số trong cùng một năm và mỗi năm một bộ khác
    "! nhau. Thiếu trường nào là SELECT ... INTO TABLE dump trùng khoá.
    "! Khai TRƯỚC các method: ABAP đòi kiểu phải có trước chỗ dùng, để
    "! sau thì báo 'Type TY_T_CRED is unknown'.
    TYPES ty_t_cred TYPE SORTED TABLE OF ztb_hddt_cred
                    WITH UNIQUE KEY provider bukrs gjahr inv_type template serial .

    CLASS-METHODS get_instance
      RETURNING VALUE(ro_config) TYPE REF TO zcl_hddt_config .

    "! Nhà cung cấp đang hoạt động cho một công ty.
    "! Thứ tự ưu tiên:
    "!   1) ZTB_HDDT_PARM key ACTIVE_PROVIDER (theo công ty, rồi chung)
    "!   2) Nếu công ty chỉ có đúng 1 nhà cung cấp active trong CRED
    METHODS get_active_provider
      IMPORTING i_bukrs           TYPE bukrs
      RETURNING VALUE(r_provider) TYPE zde_hddt_prov
      RAISING   zcx_hddt_error .

    METHODS get_provider_class
      IMPORTING i_provider    TYPE zde_hddt_prov
      RETURNING VALUE(r_class) TYPE zde_hddt_class
      RAISING   zcx_hddt_error .

    METHODS get_connection
      IMPORTING i_provider     TYPE zde_hddt_prov
                i_connid       TYPE zde_hddt_connid OPTIONAL
      RETURNING VALUE(rs_conn)  TYPE ztb_hddt_conn
      RAISING   zcx_hddt_error .

    METHODS get_action
      IMPORTING i_provider    TYPE zde_hddt_prov
                i_action      TYPE zde_hddt_action
      RETURNING VALUE(rs_act)  TYPE ztb_hddt_act
      RAISING   zcx_hddt_error .

    "! Tài khoản + dải số của một công ty trong MỘT NĂM.
    "! Một đơn vị có thể khai NHIỀU dải số trong cùng một năm, nên thứ tự
    "! chọn là: khớp đúng I_SERIAL -> dòng đánh dấu XDEFAULT của đúng năm
    "! đó -> dòng đầu tiên còn hiệu lực.
    "! @parameter i_gjahr | Năm dải số; trống thì lấy năm của I_DATE
    METHODS get_credential
      IMPORTING i_provider     TYPE zde_hddt_prov
                i_bukrs        TYPE bukrs
                i_inv_type     TYPE zde_hddt_invtype OPTIONAL
                i_serial       TYPE zde_hddt_serial OPTIONAL
                i_date         TYPE dats OPTIONAL
                i_gjahr        TYPE gjahr OPTIONAL
      RETURNING VALUE(rs_cred)  TYPE ztb_hddt_cred
      RAISING   zcx_hddt_error .

    "! Danh sách dải số còn hiệu lực của một công ty, để màn hình tham số
    "! dựng F4 và để kiểm tra giá trị người dùng gõ tay.
    METHODS get_cred_list
      IMPORTING i_provider     TYPE zde_hddt_prov OPTIONAL
                i_bukrs        TYPE bukrs
                i_inv_type     TYPE zde_hddt_invtype OPTIONAL
                i_date         TYPE dats OPTIONAL
                i_gjahr        TYPE gjahr OPTIONAL
      RETURNING VALUE(rt_cred) TYPE ty_t_cred .

    "! Dải số mặc định (XDEFAULT = 'X') để màn hình tham số tự điền.
    "! Không có dòng nào đánh dấu thì trả về rỗng — KHÔNG tự đoán.
    METHODS get_default_serial
      IMPORTING i_provider       TYPE zde_hddt_prov OPTIONAL
                i_bukrs          TYPE bukrs
                i_inv_type       TYPE zde_hddt_invtype OPTIONAL
                i_date           TYPE dats OPTIONAL
                i_gjahr          TYPE gjahr OPTIONAL
      RETURNING VALUE(r_serial)  TYPE zde_hddt_serial .

    "! Kiểm cờ Mặc định: mỗi tổ hợp Company code + Fiscal Year chỉ được
    "! tích Default cho ĐÚNG MỘT dòng (FS v0.17 mục 3.2). Dùng chung cho
    "! lúc lưu cấu hình (event SM30) và lúc chọn dải số.
    "! @parameter it_cred | Bảng bất kỳ có BUKRS / GJAHR / XDEFAULT
    "! @parameter e_bukrs | Công ty vi phạm, trống là không vi phạm
    "! @parameter e_gjahr | Năm vi phạm
    CLASS-METHODS check_default
      IMPORTING it_cred TYPE ANY TABLE
      EXPORTING e_bukrs TYPE bukrs
                e_gjahr TYPE gjahr .

    "! Năm áp dụng dải số: I_GJAHR nếu có, không thì năm của I_DATE,
    "! không có nốt thì năm hiện hành theo ngày hệ thống.
    CLASS-METHODS year_of
      IMPORTING i_gjahr        TYPE gjahr OPTIONAL
                i_date         TYPE dats  OPTIONAL
      RETURNING VALUE(r_gjahr) TYPE gjahr .

    "! Đổi giá trị SAP sang giá trị của nhà cung cấp.
    "! Không có cấu hình => trả lại chính giá trị SAP (fail-safe).
    METHODS map_value
      IMPORTING i_provider      TYPE zde_hddt_prov
                i_map_type      TYPE zde_hddt_maptype
                i_sap_value     TYPE any
      EXPORTING e_ext_value     TYPE zde_hddt_mapval
                e_ext_text      TYPE zde_hddt_descr .

    "! Quy đổi mã trả về của nhà cung cấp sang trạng thái SAP.
    "! Tìm theo (provider, action, rc) rồi (provider, '*', rc).
    METHODS map_status
      IMPORTING i_provider  TYPE zde_hddt_prov
                i_action    TYPE zde_hddt_action
                i_rc_code   TYPE zde_hddt_rccode
      EXPORTING e_status    TYPE zde_hddt_status
                e_msgty     TYPE symsgty
                e_msg_text  TYPE zde_hddt_msg
                e_found     TYPE abap_bool .

    METHODS get_date_config
      IMPORTING i_bukrs        TYPE bukrs
      RETURNING VALUE(rs_date)  TYPE ztb_hddt_date .

    "! Xác định ngày lập hoá đơn theo cấu hình từng công ty.
    METHODS resolve_invoice_date
      IMPORTING i_bukrs       TYPE bukrs
                i_budat       TYPE dats OPTIONAL
                i_bldat       TYPE dats OPTIONAL
                i_cpudt       TYPE dats OPTIONAL
      RETURNING VALUE(r_date) TYPE dats .

    "! Đọc tham số. Fallback: (prov,bukrs) -> (prov,'') -> ('',bukrs) -> ('','')
    METHODS get_param
      IMPORTING i_key          TYPE zde_hddt_parmkey
                i_provider     TYPE zde_hddt_prov OPTIONAL
                i_bukrs        TYPE bukrs OPTIONAL
      RETURNING VALUE(r_value) TYPE zde_hddt_parmval .

    METHODS get_param_bool
      IMPORTING i_key          TYPE zde_hddt_parmkey
                i_provider     TYPE zde_hddt_prov OPTIONAL
                i_bukrs        TYPE bukrs OPTIONAL
      RETURNING VALUE(r_flag)  TYPE abap_bool .

    TYPES ty_t_map_list TYPE STANDARD TABLE OF ztb_hddt_map WITH DEFAULT KEY .

    "! Toàn bộ dòng ánh xạ của một loại (danh sách tài khoản, mẫu mã
    "! thuế, loại hoá đơn SD...). Tầng đọc nguồn dùng để lọc theo danh sách.
    METHODS get_map_list
      IMPORTING i_provider    TYPE zde_hddt_prov
                i_map_type    TYPE zde_hddt_maptype
      RETURNING VALUE(rt_map)  TYPE ty_t_map_list .

    METHODS get_source_class
      IMPORTING i_bukrs        TYPE bukrs
                i_src_type     TYPE zde_hddt_srctype
      RETURNING VALUE(r_class) TYPE zde_hddt_class
      RAISING   zcx_hddt_error .

    "! Xoá buffer — gọi sau khi bảo trì cấu hình trong cùng session.
    METHODS invalidate .

  PROTECTED SECTION.
  PRIVATE SECTION.

    CLASS-DATA go_instance TYPE REF TO zcl_hddt_config .

    TYPES ty_t_prov TYPE SORTED TABLE OF ztb_hddt_prov
                    WITH UNIQUE KEY provider .
    TYPES ty_t_conn TYPE SORTED TABLE OF ztb_hddt_conn
                    WITH UNIQUE KEY provider connid .
    TYPES ty_t_act  TYPE SORTED TABLE OF ztb_hddt_act
                    WITH UNIQUE KEY provider action .
    TYPES ty_t_stat TYPE SORTED TABLE OF ztb_hddt_stat
                    WITH UNIQUE KEY provider action rc_code .
    TYPES ty_t_map  TYPE SORTED TABLE OF ztb_hddt_map
                    WITH UNIQUE KEY provider map_type sap_value .
    TYPES ty_t_parm TYPE SORTED TABLE OF ztb_hddt_parm
                    WITH UNIQUE KEY provider bukrs parm_key .
    TYPES ty_t_date TYPE SORTED TABLE OF ztb_hddt_date
                    WITH UNIQUE KEY bukrs .
    TYPES ty_t_src  TYPE SORTED TABLE OF ztb_hddt_src
                    WITH UNIQUE KEY bukrs src_type .

    DATA mt_prov TYPE ty_t_prov .
    DATA mt_conn TYPE ty_t_conn .
    DATA mt_act  TYPE ty_t_act .
    DATA mt_cred TYPE ty_t_cred .
    DATA mt_stat TYPE ty_t_stat .
    DATA mt_map  TYPE ty_t_map .
    DATA mt_parm TYPE ty_t_parm .
    DATA mt_date TYPE ty_t_date .
    DATA mt_src  TYPE ty_t_src .

    DATA mv_loaded TYPE abap_bool .

    METHODS load_buffer .

ENDCLASS.



CLASS ZCL_HDDT_CONFIG IMPLEMENTATION.


  METHOD check_default.

    CLEAR: e_bukrs, e_gjahr.

    " Bảng truyền vào có thể là TOTAL của SM30 (kiểu dòng của view bảo
    " trì) hoặc chính ZTB_HDDT_CRED, nên đọc trường bằng ASSIGN COMPONENT.
    TYPES: BEGIN OF ty_key,
             bukrs TYPE bukrs,
             gjahr TYPE gjahr,
           END OF ty_key.
    DATA lt_seen TYPE SORTED TABLE OF ty_key WITH UNIQUE KEY bukrs gjahr.
    FIELD-SYMBOLS <fs_def>   TYPE any.
    FIELD-SYMBOLS <fs_act>   TYPE any.
    FIELD-SYMBOLS <fs_bukrs> TYPE any.
    FIELD-SYMBOLS <fs_gjahr> TYPE any.

    LOOP AT it_cred ASSIGNING FIELD-SYMBOL(<fs_row>).
      ASSIGN COMPONENT 'XDEFAULT' OF STRUCTURE <fs_row> TO <fs_def>.
      IF sy-subrc <> 0 OR <fs_def> <> abap_true.
        CONTINUE.
      ENDIF.
      " Dòng đã tắt kích hoạt không tính
      ASSIGN COMPONENT 'XACTIVE' OF STRUCTURE <fs_row> TO <fs_act>.
      IF sy-subrc = 0 AND <fs_act> <> abap_true.
        CONTINUE.
      ENDIF.
      ASSIGN COMPONENT 'BUKRS' OF STRUCTURE <fs_row> TO <fs_bukrs>.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      ASSIGN COMPONENT 'GJAHR' OF STRUCTURE <fs_row> TO <fs_gjahr>.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      INSERT VALUE #( bukrs = <fs_bukrs> gjahr = <fs_gjahr> ) INTO TABLE lt_seen.
      IF sy-subrc <> 0.
        " Trùng khoá = tổ hợp này đã có một dòng Default
        e_bukrs = <fs_bukrs>.
        e_gjahr = <fs_gjahr>.
        RETURN.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD get_action.

    load_buffer( ).

    TRY.
        rs_act = mt_act[ provider = i_provider action = i_action ].
      CATCH cx_sy_itab_line_not_found.
        zcx_hddt_error=>raise_text(
          |Nghiệp vụ { i_action } của nhà cung cấp { i_provider } chưa khai| &&
          | báo endpoint trong ZTB_HDDT_ACT.| ).
    ENDTRY.

    IF rs_act-xactive <> abap_true.
      zcx_hddt_error=>raise_text(
        |Nghiệp vụ { i_action } của { i_provider } đang bị khoá.| ).
    ENDIF.

    IF rs_act-http_method IS INITIAL.
      rs_act-http_method = 'POST'.
    ENDIF.
    IF rs_act-cont_type IS INITIAL.
      rs_act-cont_type = 'application/json'.
    ENDIF.
    IF rs_act-accept_type IS INITIAL.
      rs_act-accept_type = '*/*'.
    ENDIF.

  ENDMETHOD.


  METHOD get_active_provider.

    load_buffer( ).

    " (1) Tham số cấu hình
    DATA(lv_parm) = get_param( i_key   = zif_hddt_types=>gc_parm-active_provider
                               i_bukrs = i_bukrs ).
    IF lv_parm IS NOT INITIAL.
      CONDENSE lv_parm.
      TRANSLATE lv_parm TO UPPER CASE.
      r_provider = lv_parm.
      RETURN.
    ENDIF.

    " (2) Suy ra từ bảng tài khoản nếu công ty chỉ dùng 1 nhà cung cấp
    DATA lt_found TYPE STANDARD TABLE OF zde_hddt_prov WITH EMPTY KEY.
    LOOP AT mt_cred ASSIGNING FIELD-SYMBOL(<fs_cred>)
         WHERE bukrs = i_bukrs AND xactive = abap_true.
      IF NOT line_exists( lt_found[ table_line = <fs_cred>-provider ] ).
        APPEND <fs_cred>-provider TO lt_found.
      ENDIF.
    ENDLOOP.

    IF lines( lt_found ) = 1.
      r_provider = lt_found[ 1 ].
      RETURN.
    ENDIF.

    IF lt_found IS INITIAL.
      zcx_hddt_error=>raise_text(
        |Chưa cấu hình nhà cung cấp HĐĐT cho công ty { i_bukrs }| &&
        | (bảng ZTB_HDDT_CRED).| ).
    ELSE.
      zcx_hddt_error=>raise_text(
        |Công ty { i_bukrs } có { lines( lt_found ) } nhà cung cấp active.| &&
        | Hãy khai báo tham số { zif_hddt_types=>gc_parm-active_provider }| &&
        | trong bảng ZTB_HDDT_PARM.| ).
    ENDIF.

  ENDMETHOD.


  METHOD get_connection.

    load_buffer( ).

    DATA lv_connid TYPE zde_hddt_connid.
    lv_connid = i_connid.

    IF lv_connid IS INITIAL.
      lv_connid = get_param( i_key      = zif_hddt_types=>gc_parm-default_connid
                             i_provider = i_provider ).
    ENDIF.

    IF lv_connid IS NOT INITIAL.
      TRY.
          rs_conn = mt_conn[ provider = i_provider connid = lv_connid ].
        CATCH cx_sy_itab_line_not_found.
          zcx_hddt_error=>raise_text(
            |Không tìm thấy kết nối { i_provider }/{ lv_connid } trong ZTB_HDDT_CONN.| ).
      ENDTRY.
    ELSE.
      " Không chỉ định => lấy kết nối active đầu tiên của nhà cung cấp
      LOOP AT mt_conn INTO rs_conn
           WHERE provider = i_provider AND xactive = abap_true.
        EXIT.
      ENDLOOP.
      IF sy-subrc <> 0.
        zcx_hddt_error=>raise_text(
          |Nhà cung cấp { i_provider } chưa có kết nối active trong ZTB_HDDT_CONN.| ).
      ENDIF.
    ENDIF.

    IF rs_conn-xactive <> abap_true.
      zcx_hddt_error=>raise_text(
        |Kết nối { rs_conn-provider }/{ rs_conn-connid } đang bị khoá.| ).
    ENDIF.

    IF rs_conn-rfcdest IS INITIAL AND rs_conn-base_url IS INITIAL.
      zcx_hddt_error=>raise_text(
        |Kết nối { rs_conn-provider }/{ rs_conn-connid } phải có RFCDEST (SM59)| &&
        | hoặc BASE_URL.| ).
    ENDIF.

    IF rs_conn-timeout IS INITIAL.
      rs_conn-timeout = 60.
    ENDIF.

  ENDMETHOD.


  METHOD get_credential.

    load_buffer( ).

    DATA lv_date TYPE dats.
    lv_date = COND #( WHEN i_date IS INITIAL THEN sy-datum ELSE i_date ).

    DATA ls_default TYPE ztb_hddt_cred.
    DATA lv_ndef    TYPE i.
    DATA(lv_gjahr)  = year_of( i_gjahr = i_gjahr i_date = lv_date ).

    " Ba mức ưu tiên: khớp đúng dải số người dùng chọn -> dòng đánh dấu
    " XDEFAULT -> dòng đầu tiên còn hiệu lực. Trong mỗi mức, khớp đúng
    " INV_TYPE vẫn hơn dòng dùng chung (INV_TYPE để trống).
    LOOP AT mt_cred ASSIGNING FIELD-SYMBOL(<fs_cred>)
         WHERE provider = i_provider
           AND bukrs    = i_bukrs
           AND xactive  = abap_true.

      IF <fs_cred>-gjahr IS NOT INITIAL AND <fs_cred>-gjahr <> lv_gjahr.
        CONTINUE.
      ENDIF.
      IF <fs_cred>-inv_type IS NOT INITIAL AND <fs_cred>-inv_type <> i_inv_type.
        CONTINUE.
      ENDIF.
      IF <fs_cred>-valid_from IS NOT INITIAL AND <fs_cred>-valid_from > lv_date.
        CONTINUE.
      ENDIF.
      IF <fs_cred>-valid_to IS NOT INITIAL AND <fs_cred>-valid_to < lv_date.
        CONTINUE.
      ENDIF.

      IF i_serial IS NOT INITIAL AND <fs_cred>-serial = i_serial.
        rs_cred = <fs_cred>.
        IF <fs_cred>-inv_type = i_inv_type AND i_inv_type IS NOT INITIAL.
          EXIT.                      " khớp cả dải số lẫn loại HĐ -> dừng
        ENDIF.
        CONTINUE.
      ENDIF.

      IF <fs_cred>-xdefault = abap_true.
        lv_ndef = lv_ndef + 1.
        IF ls_default IS INITIAL
           OR ( <fs_cred>-inv_type = i_inv_type AND i_inv_type IS NOT INITIAL ).
          ls_default = <fs_cred>.
        ENDIF.
      ENDIF.

      IF ls_default IS INITIAL AND rs_cred IS INITIAL.
        rs_cred = <fs_cred>.         " dự phòng: dòng còn hiệu lực đầu tiên
      ENDIF.
    ENDLOOP.

    " Người dùng chọn một dải số không có trong cấu hình thì phải báo,
    " không được âm thầm phát hành bằng dải số khác.
    IF i_serial IS NOT INITIAL AND rs_cred-serial <> i_serial.
      zcx_hddt_error=>raise_text(
        |Dải số { i_serial } chưa cấu hình (hoặc hết hiệu lực) cho | &&
        |{ i_provider } / công ty { i_bukrs } / loại HĐ { i_inv_type }.| ).
    ENDIF.

    IF i_serial IS INITIAL AND ls_default IS NOT INITIAL.
      IF lv_ndef > 1.
        " FS v0.17 mục 3.2 - mỗi Company code + Fiscal Year một Default
        DATA lv_msg TYPE string.
        MESSAGE e065(zms_hddt) WITH i_bukrs lv_gjahr INTO lv_msg.
        zcx_hddt_error=>raise_text( lv_msg ).
      ENDIF.
      rs_cred = ls_default.
    ENDIF.

    IF rs_cred IS INITIAL.
      zcx_hddt_error=>raise_text(
        |Chưa cấu hình tài khoản/dải số HĐĐT cho { i_provider } / công ty | &&
        |{ i_bukrs } / năm { lv_gjahr } / loại HĐ { i_inv_type } (ZTB_HDDT_CRED).| ).
    ENDIF.

    IF rs_cred-taxcode IS INITIAL.
      zcx_hddt_error=>raise_text(
        |Thiếu mã số thuế người bán (TAXCODE) trong ZTB_HDDT_CRED cho | &&
        |{ i_provider }/{ i_bukrs }.| ).
    ENDIF.

  ENDMETHOD.


  METHOD get_cred_list.

    load_buffer( ).

    DATA lv_date TYPE dats.
    lv_date = COND #( WHEN i_date IS INITIAL THEN sy-datum ELSE i_date ).

    DATA(lv_gjahr) = year_of( i_gjahr = i_gjahr i_date = lv_date ).

    LOOP AT mt_cred ASSIGNING FIELD-SYMBOL(<fs_cred>)
         WHERE bukrs   = i_bukrs
           AND xactive = abap_true.

      IF i_provider IS NOT INITIAL AND <fs_cred>-provider <> i_provider.
        CONTINUE.
      ENDIF.
      " GJAHR để trống trong cấu hình = dòng dùng chung cho mọi năm
      IF <fs_cred>-gjahr IS NOT INITIAL AND <fs_cred>-gjahr <> lv_gjahr.
        CONTINUE.
      ENDIF.
      " INV_TYPE để trống trong cấu hình = dòng dùng chung cho mọi loại
      IF i_inv_type IS NOT INITIAL
         AND <fs_cred>-inv_type IS NOT INITIAL
         AND <fs_cred>-inv_type <> i_inv_type.
        CONTINUE.
      ENDIF.
      IF <fs_cred>-valid_from IS NOT INITIAL AND <fs_cred>-valid_from > lv_date.
        CONTINUE.
      ENDIF.
      IF <fs_cred>-valid_to IS NOT INITIAL AND <fs_cred>-valid_to < lv_date.
        CONTINUE.
      ENDIF.

      INSERT <fs_cred> INTO TABLE rt_cred.
    ENDLOOP.

  ENDMETHOD.


  METHOD get_date_config.

    load_buffer( ).

    TRY.
        rs_date = mt_date[ bukrs = i_bukrs ].
      CATCH cx_sy_itab_line_not_found.
        CLEAR rs_date.
    ENDTRY.

  ENDMETHOD.


  METHOD get_default_serial.

    DATA(lt_cred) = get_cred_list( i_provider = i_provider
                                   i_bukrs    = i_bukrs
                                   i_inv_type = i_inv_type
                                   i_date     = i_date
                                   i_gjahr    = i_gjahr ).

    LOOP AT lt_cred ASSIGNING FIELD-SYMBOL(<fs_cred>)
         WHERE xdefault = abap_true.
      r_serial = <fs_cred>-serial.
      EXIT.
    ENDLOOP.

    " Chỉ có đúng một dải số còn hiệu lực thì không cần tích Mặc định:
    " không có lựa chọn nào khác để nhầm.
    IF r_serial IS INITIAL AND lines( lt_cred ) = 1.
      r_serial = lt_cred[ 1 ]-serial.
    ENDIF.

  ENDMETHOD.


  METHOD get_instance.

    IF go_instance IS NOT BOUND.
      go_instance = NEW zcl_hddt_config( ).
    ENDIF.
    ro_config = go_instance.

  ENDMETHOD.


  METHOD get_map_list.

    load_buffer( ).

    LOOP AT mt_map ASSIGNING FIELD-SYMBOL(<fs_map>)
         WHERE provider = i_provider AND map_type = i_map_type.
      APPEND <fs_map> TO rt_map.
    ENDLOOP.

  ENDMETHOD.


  METHOD get_param.

    load_buffer( ).

    DATA lt_try TYPE STANDARD TABLE OF ztb_hddt_parm WITH EMPTY KEY.

    APPEND VALUE #( provider = i_provider bukrs = i_bukrs   parm_key = i_key ) TO lt_try.
    APPEND VALUE #( provider = i_provider bukrs = space      parm_key = i_key ) TO lt_try.
    APPEND VALUE #( provider = space       bukrs = i_bukrs   parm_key = i_key ) TO lt_try.
    APPEND VALUE #( provider = space       bukrs = space      parm_key = i_key ) TO lt_try.

    LOOP AT lt_try ASSIGNING FIELD-SYMBOL(<fs_try>).
      TRY.
          r_value = mt_parm[ provider = <fs_try>-provider
                              bukrs    = <fs_try>-bukrs
                              parm_key = <fs_try>-parm_key ]-parm_val.
          IF r_value IS NOT INITIAL.
            RETURN.
          ENDIF.
        CATCH cx_sy_itab_line_not_found.
          CONTINUE.
      ENDTRY.
    ENDLOOP.

  ENDMETHOD.


  METHOD get_param_bool.

    DATA(lv_value) = get_param( i_key      = i_key
                                i_provider = i_provider
                                i_bukrs    = i_bukrs ).
    TRANSLATE lv_value TO UPPER CASE.
    r_flag = xsdbool( lv_value = 'X' OR lv_value = 'TRUE'
                    OR lv_value = 'Y' OR lv_value = '1' ).

  ENDMETHOD.


  METHOD get_provider_class.

    load_buffer( ).

    DATA(ls_prov) = VALUE ztb_hddt_prov( ).
    TRY.
        ls_prov = mt_prov[ provider = i_provider ].
      CATCH cx_sy_itab_line_not_found.
        zcx_hddt_error=>raise_text(
          |Nhà cung cấp { i_provider } chưa khai báo trong ZTB_HDDT_PROV.| ).
    ENDTRY.

    IF ls_prov-xactive <> abap_true.
      zcx_hddt_error=>raise_text(
        |Nhà cung cấp { i_provider } đang bị khoá (XACTIVE = space).| ).
    ENDIF.

    IF ls_prov-classname IS INITIAL.
      zcx_hddt_error=>raise_text(
        |Nhà cung cấp { i_provider } chưa khai báo lớp thực thi (CLASSNAME).| ).
    ENDIF.

    r_class = ls_prov-classname.

  ENDMETHOD.


  METHOD get_source_class.

    load_buffer( ).

    TRY.
        DATA(ls_src) = mt_src[ bukrs = i_bukrs src_type = i_src_type ].
      CATCH cx_sy_itab_line_not_found.
        TRY.
            ls_src = mt_src[ bukrs = space src_type = i_src_type ].
          CATCH cx_sy_itab_line_not_found.
            zcx_hddt_error=>raise_text(
              |Chưa khai báo lớp đọc dữ liệu nguồn cho công ty { i_bukrs } /| &&
              | loại { i_src_type } (ZTB_HDDT_SRC).| ).
        ENDTRY.
    ENDTRY.

    IF ls_src-xactive <> abap_true OR ls_src-classname IS INITIAL.
      zcx_hddt_error=>raise_text(
        |Lớp đọc dữ liệu nguồn { i_bukrs }/{ i_src_type } chưa active hoặc| &&
        | thiếu CLASSNAME.| ).
    ENDIF.

    r_class = ls_src-classname.

  ENDMETHOD.


  METHOD invalidate.

    CLEAR: mt_prov, mt_conn, mt_act, mt_cred, mt_stat,
           mt_map, mt_parm, mt_date, mt_src, mv_loaded.

  ENDMETHOD.


  METHOD load_buffer.

    IF mv_loaded = abap_true.
      RETURN.
    ENDIF.

    " Các bảng cấu hình đều nhỏ (hàng chục đến hàng trăm dòng) nên đọc
    " một lần vào buffer, tránh SELECT trong vòng lặp phát hành hoá đơn.
    SELECT * FROM ztb_hddt_prov INTO TABLE @mt_prov.
    SELECT * FROM ztb_hddt_conn INTO TABLE @mt_conn.
    SELECT * FROM ztb_hddt_act  INTO TABLE @mt_act.
    SELECT * FROM ztb_hddt_cred INTO TABLE @mt_cred.
    SELECT * FROM ztb_hddt_stat INTO TABLE @mt_stat.
    SELECT * FROM ztb_hddt_map  INTO TABLE @mt_map.
    SELECT * FROM ztb_hddt_parm INTO TABLE @mt_parm.
    SELECT * FROM ztb_hddt_date INTO TABLE @mt_date.
    SELECT * FROM ztb_hddt_src  INTO TABLE @mt_src.

    mv_loaded = abap_true.

  ENDMETHOD.


  METHOD map_status.

    CLEAR: e_status, e_msgty, e_msg_text, e_found.
    load_buffer( ).

    DATA(lv_rc) = i_rc_code.

    TRY.
        DATA(ls_stat) = mt_stat[ provider = i_provider
                                 action   = i_action
                                 rc_code  = lv_rc ].
      CATCH cx_sy_itab_line_not_found.
        TRY.
            ls_stat = mt_stat[ provider = i_provider
                               action   = '*'
                               rc_code  = lv_rc ].
          CATCH cx_sy_itab_line_not_found.
            RETURN.
        ENDTRY.
    ENDTRY.

    e_status   = ls_stat-sap_status.
    e_msgty    = ls_stat-msgty.
    e_msg_text = ls_stat-msg_text.
    e_found    = abap_true.

  ENDMETHOD.


  METHOD map_value.

    CLEAR: e_ext_value, e_ext_text.
    load_buffer( ).

    DATA lv_sap_value TYPE zde_hddt_mapval.
    lv_sap_value = |{ i_sap_value }|.
    CONDENSE lv_sap_value.

    TRY.
        DATA(ls_map) = mt_map[ provider  = i_provider
                               map_type  = i_map_type
                               sap_value = lv_sap_value ].
        e_ext_value = ls_map-ext_value.
        e_ext_text  = ls_map-ext_text.
      CATCH cx_sy_itab_line_not_found.
        " Không có cấu hình -> dùng nguyên giá trị SAP để không chặn
        " nghiệp vụ; sai lệch sẽ hiện trong log và response của NCC.
        e_ext_value = lv_sap_value.
    ENDTRY.

  ENDMETHOD.


  METHOD resolve_invoice_date.

    DATA(ls_cfg) = get_date_config( i_bukrs ).

    CASE ls_cfg-date_src.
      WHEN '1'.  r_date = i_budat.
      WHEN '2'.  r_date = i_cpudt.
      WHEN '3'.  r_date = sy-datum.
      WHEN '4'.  r_date = i_bldat.
      WHEN OTHERS.
        r_date = sy-datum.          " chưa cấu hình -> ngày hệ thống
    ENDCASE.

    IF r_date IS INITIAL.
      r_date = sy-datum.
    ENDIF.

    " Không lùi ngày lập quá N ngày so với hôm nay (tham số
    " INV_DATE_MAX_BACKDAYS; dự án tham chiếu cố định 1 ngày). Trống =
    " không giới hạn.
    DATA(lv_max) = get_param( i_key   = zif_hddt_types=>gc_parm-inv_date_maxback
                              i_bukrs = i_bukrs ).
    CONDENSE lv_max NO-GAPS.
    IF lv_max IS NOT INITIAL AND lv_max CO '0123456789 '.
      DATA lv_days TYPE i.
      lv_days = lv_max.
      IF sy-datum - r_date > lv_days.
        r_date = sy-datum - lv_days.
      ENDIF.
    ENDIF.

  ENDMETHOD.


  METHOD year_of.

    IF i_gjahr IS NOT INITIAL.
      r_gjahr = i_gjahr.
    ELSEIF i_date IS NOT INITIAL.
      r_gjahr = i_date(4).
    ELSE.
      r_gjahr = sy-datum(4).
    ENDIF.

  ENDMETHOD.
ENDCLASS.
