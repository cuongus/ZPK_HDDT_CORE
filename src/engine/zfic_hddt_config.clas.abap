*=====================================================================
* Tên/Mã     : ZFIC_HDDT_CONFIG
* Mô tả chung: Lớp truy cập CẤU HÌNH duy nhất của HĐĐT Core. Mọi bảng
*              ZFIT_HDDT_* chỉ được đọc qua lớp này (có buffer trong
*              bộ nhớ) — engine và adapter không SELECT trực tiếp.
*              Nhờ vậy khi bổ sung/đổi nguồn cấu hình chỉ sửa 1 nơi.
* Tham Số    : Singleton — dùng ZFIC_HDDT_CONFIG=>get_instance( )
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       28/08/2026    cuongus - CuongUS        abapGit     Tạo mới
*=====================================================================
CLASS zfic_hddt_config DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE .

  PUBLIC SECTION.

    CLASS-METHODS get_instance
      RETURNING VALUE(ro_config) TYPE REF TO zfic_hddt_config .

    "! Nhà cung cấp đang hoạt động cho một công ty.
    "! Thứ tự ưu tiên:
    "!   1) ZFIT_HDDT_PARM key ACTIVE_PROVIDER (theo công ty, rồi chung)
    "!   2) Nếu công ty chỉ có đúng 1 nhà cung cấp active trong CRED
    METHODS get_active_provider
      IMPORTING iv_bukrs           TYPE bukrs
      RETURNING VALUE(rv_provider) TYPE zfide_hddt_prov
      RAISING   zficx_hddt_error .

    METHODS get_provider_class
      IMPORTING iv_provider    TYPE zfide_hddt_prov
      RETURNING VALUE(rv_class) TYPE zfide_hddt_class
      RAISING   zficx_hddt_error .

    METHODS get_connection
      IMPORTING iv_provider     TYPE zfide_hddt_prov
                iv_connid       TYPE zfide_hddt_connid OPTIONAL
      RETURNING VALUE(rs_conn)  TYPE zfit_hddt_conn
      RAISING   zficx_hddt_error .

    METHODS get_action
      IMPORTING iv_provider    TYPE zfide_hddt_prov
                iv_action      TYPE zfide_hddt_action
      RETURNING VALUE(rs_act)  TYPE zfit_hddt_act
      RAISING   zficx_hddt_error .

    METHODS get_credential
      IMPORTING iv_provider     TYPE zfide_hddt_prov
                iv_bukrs        TYPE bukrs
                iv_inv_type     TYPE zfide_hddt_invtype OPTIONAL
                iv_date         TYPE dats OPTIONAL
      RETURNING VALUE(rs_cred)  TYPE zfit_hddt_cred
      RAISING   zficx_hddt_error .

    "! Đổi giá trị SAP sang giá trị của nhà cung cấp.
    "! Không có cấu hình => trả lại chính giá trị SAP (fail-safe).
    METHODS map_value
      IMPORTING iv_provider      TYPE zfide_hddt_prov
                iv_map_type      TYPE zfide_hddt_maptype
                iv_sap_value     TYPE any
      EXPORTING ev_ext_value     TYPE zfide_hddt_mapval
                ev_ext_text      TYPE zfide_hddt_descr .

    "! Quy đổi mã trả về của nhà cung cấp sang trạng thái SAP.
    "! Tìm theo (provider, action, rc) rồi (provider, '*', rc).
    METHODS map_status
      IMPORTING iv_provider  TYPE zfide_hddt_prov
                iv_action    TYPE zfide_hddt_action
                iv_rc_code   TYPE zfide_hddt_rccode
      EXPORTING ev_status    TYPE zfide_hddt_status
                ev_msgty     TYPE symsgty
                ev_msg_text  TYPE zfide_hddt_msg
                ev_found     TYPE abap_bool .

    METHODS get_date_config
      IMPORTING iv_bukrs        TYPE bukrs
      RETURNING VALUE(rs_date)  TYPE zfit_hddt_date .

    "! Xác định ngày lập hoá đơn theo cấu hình từng công ty.
    METHODS resolve_invoice_date
      IMPORTING iv_bukrs       TYPE bukrs
                iv_budat       TYPE dats OPTIONAL
                iv_bldat       TYPE dats OPTIONAL
                iv_cpudt       TYPE dats OPTIONAL
      RETURNING VALUE(rv_date) TYPE dats .

    "! Đọc tham số. Fallback: (prov,bukrs) -> (prov,'') -> ('',bukrs) -> ('','')
    METHODS get_param
      IMPORTING iv_key          TYPE zfide_hddt_parmkey
                iv_provider     TYPE zfide_hddt_prov OPTIONAL
                iv_bukrs        TYPE bukrs OPTIONAL
      RETURNING VALUE(rv_value) TYPE zfide_hddt_parmval .

    METHODS get_param_bool
      IMPORTING iv_key          TYPE zfide_hddt_parmkey
                iv_provider     TYPE zfide_hddt_prov OPTIONAL
                iv_bukrs        TYPE bukrs OPTIONAL
      RETURNING VALUE(rv_flag)  TYPE abap_bool .

    METHODS get_source_class
      IMPORTING iv_bukrs        TYPE bukrs
                iv_src_type     TYPE zfide_hddt_srctype
      RETURNING VALUE(rv_class) TYPE zfide_hddt_class
      RAISING   zficx_hddt_error .

    "! Xoá buffer — gọi sau khi bảo trì cấu hình trong cùng session.
    METHODS invalidate .

  PROTECTED SECTION.
  PRIVATE SECTION.

    CLASS-DATA go_instance TYPE REF TO zfic_hddt_config .

    TYPES ty_t_prov TYPE SORTED TABLE OF zfit_hddt_prov
                    WITH UNIQUE KEY provider .
    TYPES ty_t_conn TYPE SORTED TABLE OF zfit_hddt_conn
                    WITH UNIQUE KEY provider connid .
    TYPES ty_t_act  TYPE SORTED TABLE OF zfit_hddt_act
                    WITH UNIQUE KEY provider action .
    TYPES ty_t_cred TYPE SORTED TABLE OF zfit_hddt_cred
                    WITH UNIQUE KEY provider bukrs inv_type .
    TYPES ty_t_stat TYPE SORTED TABLE OF zfit_hddt_stat
                    WITH UNIQUE KEY provider action rc_code .
    TYPES ty_t_map  TYPE SORTED TABLE OF zfit_hddt_map
                    WITH UNIQUE KEY provider map_type sap_value .
    TYPES ty_t_parm TYPE SORTED TABLE OF zfit_hddt_parm
                    WITH UNIQUE KEY provider bukrs parm_key .
    TYPES ty_t_date TYPE SORTED TABLE OF zfit_hddt_date
                    WITH UNIQUE KEY bukrs .
    TYPES ty_t_src  TYPE SORTED TABLE OF zfit_hddt_src
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



CLASS zfic_hddt_config IMPLEMENTATION.

  METHOD get_instance.

    IF go_instance IS NOT BOUND.
      go_instance = NEW zfic_hddt_config( ).
    ENDIF.
    ro_config = go_instance.

  ENDMETHOD.


  METHOD load_buffer.

    IF mv_loaded = abap_true.
      RETURN.
    ENDIF.

    " Các bảng cấu hình đều nhỏ (hàng chục đến hàng trăm dòng) nên đọc
    " một lần vào buffer, tránh SELECT trong vòng lặp phát hành hoá đơn.
    SELECT * FROM zfit_hddt_prov INTO TABLE @mt_prov.
    SELECT * FROM zfit_hddt_conn INTO TABLE @mt_conn.
    SELECT * FROM zfit_hddt_act  INTO TABLE @mt_act.
    SELECT * FROM zfit_hddt_cred INTO TABLE @mt_cred.
    SELECT * FROM zfit_hddt_stat INTO TABLE @mt_stat.
    SELECT * FROM zfit_hddt_map  INTO TABLE @mt_map.
    SELECT * FROM zfit_hddt_parm INTO TABLE @mt_parm.
    SELECT * FROM zfit_hddt_date INTO TABLE @mt_date.
    SELECT * FROM zfit_hddt_src  INTO TABLE @mt_src.

    mv_loaded = abap_true.

  ENDMETHOD.


  METHOD invalidate.

    CLEAR: mt_prov, mt_conn, mt_act, mt_cred, mt_stat,
           mt_map, mt_parm, mt_date, mt_src, mv_loaded.

  ENDMETHOD.


  METHOD get_active_provider.

    load_buffer( ).

    " (1) Tham số cấu hình
    DATA(lv_parm) = get_param( iv_key   = zfiif_hddt_types=>gc_parm-active_provider
                               iv_bukrs = iv_bukrs ).
    IF lv_parm IS NOT INITIAL.
      CONDENSE lv_parm.
      TRANSLATE lv_parm TO UPPER CASE.
      rv_provider = lv_parm.
      RETURN.
    ENDIF.

    " (2) Suy ra từ bảng tài khoản nếu công ty chỉ dùng 1 nhà cung cấp
    DATA lt_found TYPE STANDARD TABLE OF zfide_hddt_prov WITH EMPTY KEY.
    LOOP AT mt_cred ASSIGNING FIELD-SYMBOL(<ls_cred>)
         WHERE bukrs = iv_bukrs AND xactive = abap_true.
      IF NOT line_exists( lt_found[ table_line = <ls_cred>-provider ] ).
        APPEND <ls_cred>-provider TO lt_found.
      ENDIF.
    ENDLOOP.

    IF lines( lt_found ) = 1.
      rv_provider = lt_found[ 1 ].
      RETURN.
    ENDIF.

    IF lt_found IS INITIAL.
      zficx_hddt_error=>raise_text(
        |Chưa cấu hình nhà cung cấp HĐĐT cho công ty { iv_bukrs }| &&
        | (bảng ZFIT_HDDT_CRED).| ).
    ELSE.
      zficx_hddt_error=>raise_text(
        |Công ty { iv_bukrs } có { lines( lt_found ) } nhà cung cấp active.| &&
        | Hãy khai báo tham số { zfiif_hddt_types=>gc_parm-active_provider }| &&
        | trong bảng ZFIT_HDDT_PARM.| ).
    ENDIF.

  ENDMETHOD.


  METHOD get_provider_class.

    load_buffer( ).

    DATA(ls_prov) = VALUE zfit_hddt_prov( ).
    TRY.
        ls_prov = mt_prov[ provider = iv_provider ].
      CATCH cx_sy_itab_line_not_found.
        zficx_hddt_error=>raise_text(
          |Nhà cung cấp { iv_provider } chưa khai báo trong ZFIT_HDDT_PROV.| ).
    ENDTRY.

    IF ls_prov-xactive <> abap_true.
      zficx_hddt_error=>raise_text(
        |Nhà cung cấp { iv_provider } đang bị khoá (XACTIVE = space).| ).
    ENDIF.

    IF ls_prov-classname IS INITIAL.
      zficx_hddt_error=>raise_text(
        |Nhà cung cấp { iv_provider } chưa khai báo lớp thực thi (CLASSNAME).| ).
    ENDIF.

    rv_class = ls_prov-classname.

  ENDMETHOD.


  METHOD get_connection.

    load_buffer( ).

    DATA lv_connid TYPE zfide_hddt_connid.
    lv_connid = iv_connid.

    IF lv_connid IS INITIAL.
      lv_connid = get_param( iv_key      = zfiif_hddt_types=>gc_parm-default_connid
                             iv_provider = iv_provider ).
    ENDIF.

    IF lv_connid IS NOT INITIAL.
      TRY.
          rs_conn = mt_conn[ provider = iv_provider connid = lv_connid ].
        CATCH cx_sy_itab_line_not_found.
          zficx_hddt_error=>raise_text(
            |Không tìm thấy kết nối { iv_provider }/{ lv_connid } trong ZFIT_HDDT_CONN.| ).
      ENDTRY.
    ELSE.
      " Không chỉ định => lấy kết nối active đầu tiên của nhà cung cấp
      LOOP AT mt_conn INTO rs_conn
           WHERE provider = iv_provider AND xactive = abap_true.
        EXIT.
      ENDLOOP.
      IF sy-subrc <> 0.
        zficx_hddt_error=>raise_text(
          |Nhà cung cấp { iv_provider } chưa có kết nối active trong ZFIT_HDDT_CONN.| ).
      ENDIF.
    ENDIF.

    IF rs_conn-xactive <> abap_true.
      zficx_hddt_error=>raise_text(
        |Kết nối { rs_conn-provider }/{ rs_conn-connid } đang bị khoá.| ).
    ENDIF.

    IF rs_conn-rfcdest IS INITIAL AND rs_conn-base_url IS INITIAL.
      zficx_hddt_error=>raise_text(
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
        rs_act = mt_act[ provider = iv_provider action = iv_action ].
      CATCH cx_sy_itab_line_not_found.
        zficx_hddt_error=>raise_text(
          |Nghiệp vụ { iv_action } của nhà cung cấp { iv_provider } chưa khai| &&
          | báo endpoint trong ZFIT_HDDT_ACT.| ).
    ENDTRY.

    IF rs_act-xactive <> abap_true.
      zficx_hddt_error=>raise_text(
        |Nghiệp vụ { iv_action } của { iv_provider } đang bị khoá.| ).
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
    lv_date = COND #( WHEN iv_date IS INITIAL THEN sy-datum ELSE iv_date ).

    " Khớp chính xác loại hoá đơn được ưu tiên; nếu không có thì dùng
    " dòng mặc định (INV_TYPE để trống).
    LOOP AT mt_cred ASSIGNING FIELD-SYMBOL(<ls_cred>)
         WHERE provider = iv_provider
           AND bukrs    = iv_bukrs
           AND xactive  = abap_true.

      IF <ls_cred>-inv_type IS NOT INITIAL AND <ls_cred>-inv_type <> iv_inv_type.
        CONTINUE.
      ENDIF.
      IF <ls_cred>-valid_from IS NOT INITIAL AND <ls_cred>-valid_from > lv_date.
        CONTINUE.
      ENDIF.
      IF <ls_cred>-valid_to IS NOT INITIAL AND <ls_cred>-valid_to < lv_date.
        CONTINUE.
      ENDIF.

      IF <ls_cred>-inv_type = iv_inv_type AND iv_inv_type IS NOT INITIAL.
        rs_cred = <ls_cred>.
        EXIT.                        " khớp chính xác -> dừng ngay
      ELSEIF rs_cred IS INITIAL.
        rs_cred = <ls_cred>.         " giữ dòng mặc định làm dự phòng
      ENDIF.
    ENDLOOP.

    IF rs_cred IS INITIAL.
      zficx_hddt_error=>raise_text(
        |Chưa cấu hình tài khoản/dải số HĐĐT cho { iv_provider } / công ty | &&
        |{ iv_bukrs } / loại HĐ { iv_inv_type } (ZFIT_HDDT_CRED).| ).
    ENDIF.

    IF rs_cred-taxcode IS INITIAL.
      zficx_hddt_error=>raise_text(
        |Thiếu mã số thuế người bán (TAXCODE) trong ZFIT_HDDT_CRED cho | &&
        |{ iv_provider }/{ iv_bukrs }.| ).
    ENDIF.

  ENDMETHOD.


  METHOD map_value.

    CLEAR: ev_ext_value, ev_ext_text.
    load_buffer( ).

    DATA lv_sap_value TYPE zfide_hddt_mapval.
    lv_sap_value = |{ iv_sap_value }|.
    CONDENSE lv_sap_value.

    TRY.
        DATA(ls_map) = mt_map[ provider  = iv_provider
                               map_type  = iv_map_type
                               sap_value = lv_sap_value ].
        ev_ext_value = ls_map-ext_value.
        ev_ext_text  = ls_map-ext_text.
      CATCH cx_sy_itab_line_not_found.
        " Không có cấu hình -> dùng nguyên giá trị SAP để không chặn
        " nghiệp vụ; sai lệch sẽ hiện trong log và response của NCC.
        ev_ext_value = lv_sap_value.
    ENDTRY.

  ENDMETHOD.


  METHOD map_status.

    CLEAR: ev_status, ev_msgty, ev_msg_text, ev_found.
    load_buffer( ).

    DATA(lv_rc) = iv_rc_code.

    TRY.
        DATA(ls_stat) = mt_stat[ provider = iv_provider
                                 action   = iv_action
                                 rc_code  = lv_rc ].
      CATCH cx_sy_itab_line_not_found.
        TRY.
            ls_stat = mt_stat[ provider = iv_provider
                               action   = '*'
                               rc_code  = lv_rc ].
          CATCH cx_sy_itab_line_not_found.
            RETURN.
        ENDTRY.
    ENDTRY.

    ev_status   = ls_stat-sap_status.
    ev_msgty    = ls_stat-msgty.
    ev_msg_text = ls_stat-msg_text.
    ev_found    = abap_true.

  ENDMETHOD.


  METHOD get_date_config.

    load_buffer( ).

    TRY.
        rs_date = mt_date[ bukrs = iv_bukrs ].
      CATCH cx_sy_itab_line_not_found.
        CLEAR rs_date.
    ENDTRY.

  ENDMETHOD.


  METHOD resolve_invoice_date.

    DATA(ls_cfg) = get_date_config( iv_bukrs ).

    CASE ls_cfg-date_src.
      WHEN '1'.  rv_date = iv_budat.
      WHEN '2'.  rv_date = iv_cpudt.
      WHEN '3'.  rv_date = sy-datum.
      WHEN '4'.  rv_date = iv_bldat.
      WHEN OTHERS.
        rv_date = sy-datum.          " chưa cấu hình -> ngày hệ thống
    ENDCASE.

    IF rv_date IS INITIAL.
      rv_date = sy-datum.
    ENDIF.

  ENDMETHOD.


  METHOD get_param.

    load_buffer( ).

    DATA lt_try TYPE STANDARD TABLE OF zfit_hddt_parm WITH EMPTY KEY.

    APPEND VALUE #( provider = iv_provider bukrs = iv_bukrs   parm_key = iv_key ) TO lt_try.
    APPEND VALUE #( provider = iv_provider bukrs = space      parm_key = iv_key ) TO lt_try.
    APPEND VALUE #( provider = space       bukrs = iv_bukrs   parm_key = iv_key ) TO lt_try.
    APPEND VALUE #( provider = space       bukrs = space      parm_key = iv_key ) TO lt_try.

    LOOP AT lt_try ASSIGNING FIELD-SYMBOL(<ls_try>).
      TRY.
          rv_value = mt_parm[ provider = <ls_try>-provider
                              bukrs    = <ls_try>-bukrs
                              parm_key = <ls_try>-parm_key ]-parm_val.
          IF rv_value IS NOT INITIAL.
            RETURN.
          ENDIF.
        CATCH cx_sy_itab_line_not_found.
          CONTINUE.
      ENDTRY.
    ENDLOOP.

  ENDMETHOD.


  METHOD get_param_bool.

    DATA(lv_value) = get_param( iv_key      = iv_key
                                iv_provider = iv_provider
                                iv_bukrs    = iv_bukrs ).
    TRANSLATE lv_value TO UPPER CASE.
    rv_flag = xsdbool( lv_value = 'X' OR lv_value = 'TRUE'
                    OR lv_value = 'Y' OR lv_value = '1' ).

  ENDMETHOD.


  METHOD get_source_class.

    load_buffer( ).

    TRY.
        DATA(ls_src) = mt_src[ bukrs = iv_bukrs src_type = iv_src_type ].
      CATCH cx_sy_itab_line_not_found.
        TRY.
            ls_src = mt_src[ bukrs = space src_type = iv_src_type ].
          CATCH cx_sy_itab_line_not_found.
            zficx_hddt_error=>raise_text(
              |Chưa khai báo lớp đọc dữ liệu nguồn cho công ty { iv_bukrs } /| &&
              | loại { iv_src_type } (ZFIT_HDDT_SRC).| ).
        ENDTRY.
    ENDTRY.

    IF ls_src-xactive <> abap_true OR ls_src-classname IS INITIAL.
      zficx_hddt_error=>raise_text(
        |Lớp đọc dữ liệu nguồn { iv_bukrs }/{ iv_src_type } chưa active hoặc| &&
        | thiếu CLASSNAME.| ).
    ENDIF.

    rv_class = ls_src-classname.

  ENDMETHOD.

ENDCLASS.
