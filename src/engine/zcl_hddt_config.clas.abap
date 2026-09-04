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

    METHODS get_credential
      IMPORTING i_provider     TYPE zde_hddt_prov
                i_bukrs        TYPE bukrs
                i_inv_type     TYPE zde_hddt_invtype OPTIONAL
                i_date         TYPE dats OPTIONAL
      RETURNING VALUE(rs_cred)  TYPE ztb_hddt_cred
      RAISING   zcx_hddt_error .

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
    TYPES ty_t_cred TYPE SORTED TABLE OF ztb_hddt_cred
                    WITH UNIQUE KEY provider bukrs inv_type .
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



CLASS zcl_hddt_config IMPLEMENTATION.

  METHOD get_instance.

    IF go_instance IS NOT BOUND.
      go_instance = NEW zcl_hddt_config( ).
    ENDIF.
    ro_config = go_instance.

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


  METHOD invalidate.

    CLEAR: mt_prov, mt_conn, mt_act, mt_cred, mt_stat,
           mt_map, mt_parm, mt_date, mt_src, mv_loaded.

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


  METHOD get_credential.

    load_buffer( ).

    DATA lv_date TYPE dats.
    lv_date = COND #( WHEN i_date IS INITIAL THEN sy-datum ELSE i_date ).

    " Khớp chính xác loại hoá đơn được ưu tiên; nếu không có thì dùng
    " dòng mặc định (INV_TYPE để trống).
    LOOP AT mt_cred ASSIGNING FIELD-SYMBOL(<fs_cred>)
         WHERE provider = i_provider
           AND bukrs    = i_bukrs
           AND xactive  = abap_true.

      IF <fs_cred>-inv_type IS NOT INITIAL AND <fs_cred>-inv_type <> i_inv_type.
        CONTINUE.
      ENDIF.
      IF <fs_cred>-valid_from IS NOT INITIAL AND <fs_cred>-valid_from > lv_date.
        CONTINUE.
      ENDIF.
      IF <fs_cred>-valid_to IS NOT INITIAL AND <fs_cred>-valid_to < lv_date.
        CONTINUE.
      ENDIF.

      IF <fs_cred>-inv_type = i_inv_type AND i_inv_type IS NOT INITIAL.
        rs_cred = <fs_cred>.
        EXIT.                        " khớp chính xác -> dừng ngay
      ELSEIF rs_cred IS INITIAL.
        rs_cred = <fs_cred>.         " giữ dòng mặc định làm dự phòng
      ENDIF.
    ENDLOOP.

    IF rs_cred IS INITIAL.
      zcx_hddt_error=>raise_text(
        |Chưa cấu hình tài khoản/dải số HĐĐT cho { i_provider } / công ty | &&
        |{ i_bukrs } / loại HĐ { i_inv_type } (ZTB_HDDT_CRED).| ).
    ENDIF.

    IF rs_cred-taxcode IS INITIAL.
      zcx_hddt_error=>raise_text(
        |Thiếu mã số thuế người bán (TAXCODE) trong ZTB_HDDT_CRED cho | &&
        |{ i_provider }/{ i_bukrs }.| ).
    ENDIF.

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


  METHOD get_date_config.

    load_buffer( ).

    TRY.
        rs_date = mt_date[ bukrs = i_bukrs ].
      CATCH cx_sy_itab_line_not_found.
        CLEAR rs_date.
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


  METHOD get_map_list.

    load_buffer( ).

    LOOP AT mt_map ASSIGNING FIELD-SYMBOL(<fs_map>)
         WHERE provider = i_provider AND map_type = i_map_type.
      APPEND <fs_map> TO rt_map.
    ENDLOOP.

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

ENDCLASS.
