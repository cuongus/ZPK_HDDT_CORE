*=====================================================================
* Tên/Mã     : ZCL_HDDT_HTTP
* Mô tả chung: Bộ gọi REST dùng chung, điều khiển 100% bằng cấu hình
*              (ZTB_HDDT_CONN + ZTB_HDDT_ACT). Lớp này KHÔNG biết
*              nhà cung cấp nào — nó chỉ biết method, path, header và
*              phương thức xác thực lấy từ bảng.
*              Hỗ trợ 2 cách kết nối:
*                - RFC destination loại G (SM59) : ưu tiên, vì chứng
*                  chỉ SSL / proxy / user-password do Basis quản lý.
*                - BASE_URL trực tiếp + SSL_ID  : khi không muốn tạo
*                  destination.
*              Placeholder {taxcode} {serial} {seq} ... trong API_PATH
*              được thay bằng bảng symbol do adapter cung cấp.
* Tham Số    : SEND( is_call ) -> ty_response
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       28/08/2026    cuongus - CuongUS        abapGit     Tạo mới
*=====================================================================
CLASS zcl_hddt_http DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    TYPES: BEGIN OF ty_call,
             conn      TYPE ztb_hddt_conn,
             action    TYPE ztb_hddt_act,
             symbols   TYPE zif_hddt_types=>ty_t_kv,
             headers   TYPE zif_hddt_types=>ty_t_kv,
             payload   TYPE string,
             username  TYPE string,
             secret    TYPE string,
             bearer    TYPE string,
             "! Ghi đè AUTH_MODE của kết nối (dùng khi gọi API đăng nhập)
             auth_mode TYPE zde_hddt_auth,
           END OF ty_call.

    TYPES: BEGIN OF ty_response,
             http_code   TYPE i,
             reason      TYPE string,
             body        TYPE string,
             body_x      TYPE xstring,
             full_url    TYPE string,
             duration_ms TYPE i,
             "! Header thực tế đã gửi / nhận — để ghi log truy vết.
             "! CHƯA che secret; việc che do ZCL_HDDT_LOG làm.
             req_header  TYPE string,
             res_header  TYPE string,
           END OF ty_response.

    METHODS send
      IMPORTING is_call            TYPE ty_call
      RETURNING VALUE(rs_response) TYPE ty_response
      RAISING   zcx_hddt_error .

    "! Thay placeholder {ten} trong path bằng giá trị trong symbol.
    "! Placeholder không có giá trị sẽ bị xoá khỏi path.
    CLASS-METHODS resolve_path
      IMPORTING i_path        TYPE any
                it_symbols     TYPE zif_hddt_types=>ty_t_kv
      RETURNING VALUE(r_path) TYPE string .

  PROTECTED SECTION.
  PRIVATE SECTION.

    METHODS create_client
      IMPORTING is_call          TYPE ty_call
                i_path          TYPE string
      EXPORTING eo_client        TYPE REF TO if_http_client
                e_full_url      TYPE string
      RAISING   zcx_hddt_error .

    METHODS apply_auth
      IMPORTING is_call   TYPE ty_call
                io_client TYPE REF TO if_http_client .

    "! Gộp bảng header thành text 1 dòng/1 header để lưu log.
    METHODS header_text
      IMPORTING it_fields      TYPE tihttpnvp
      RETURNING VALUE(r_text) TYPE string .

ENDCLASS.



CLASS zcl_hddt_http IMPLEMENTATION.

  METHOD resolve_path.

    r_path = |{ i_path }|.
    CONDENSE r_path.

    LOOP AT it_symbols ASSIGNING FIELD-SYMBOL(<fs_sym>).
      REPLACE ALL OCCURRENCES OF |\{{ <fs_sym>-name }\}|
              IN r_path WITH <fs_sym>-value.
    ENDLOOP.

    " Placeholder còn sót (không được adapter cung cấp) -> bỏ đi để
    " không gửi chuỗi '{taxcode}' lên nhà cung cấp.
    REPLACE ALL OCCURRENCES OF REGEX '\{[A-Za-z_0-9]+\}'
            IN r_path WITH ``.

  ENDMETHOD.


  METHOD create_client.

    DATA lv_msg TYPE string.

    CLEAR: eo_client, e_full_url.

    IF is_call-conn-rfcdest IS NOT INITIAL.
      " ---- Qua RFC destination (SM59, loại G) ----
      cl_http_client=>create_by_destination(
        EXPORTING
          destination              = is_call-conn-rfcdest
        IMPORTING
          client                   = eo_client
        EXCEPTIONS
          argument_not_found       = 1
          destination_not_found    = 2
          destination_no_authority = 3
          plugin_not_active        = 4
          internal_error           = 5
          OTHERS                   = 6 ).
      IF sy-subrc <> 0.
        MESSAGE ID sy-msgid TYPE 'E' NUMBER sy-msgno
                WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 INTO lv_msg.
        zcx_hddt_error=>raise_text(
          |Không mở được RFC destination { is_call-conn-rfcdest } (SM59): | &&
          |{ lv_msg }| ).
      ENDIF.

      " Với destination, path phải set qua pseudo-header ~request_uri
      eo_client->request->set_header_field( name  = '~request_uri'
                                            value = i_path ).
      e_full_url = |{ is_call-conn-rfcdest }{ i_path }|.

    ELSE.
      " ---- Qua URL trực tiếp ----
      DATA(lv_base) = |{ is_call-conn-base_url }|.
      CONDENSE lv_base.
      WHILE strlen( lv_base ) > 0
            AND substring( val = lv_base off = strlen( lv_base ) - 1 len = 1 ) = `/`.
        lv_base = substring( val = lv_base len = strlen( lv_base ) - 1 ).
      ENDWHILE.

      DATA(lv_rel) = i_path.
      IF lv_rel IS NOT INITIAL AND substring( val = lv_rel len = 1 ) <> `/`.
        lv_rel = `/` && lv_rel.
      ENDIF.

      e_full_url = lv_base && lv_rel.

      cl_http_client=>create_by_url(
        EXPORTING
          url                = e_full_url
          ssl_id             = is_call-conn-ssl_id
        IMPORTING
          client             = eo_client
        EXCEPTIONS
          argument_not_found = 1
          plugin_not_active  = 2
          internal_error     = 3
          OTHERS             = 4 ).
      IF sy-subrc <> 0.
        MESSAGE ID sy-msgid TYPE 'E' NUMBER sy-msgno
                WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 INTO lv_msg.
        zcx_hddt_error=>raise_text(
          |Không mở được kết nối HTTP tới { e_full_url }: { lv_msg }| ).
      ENDIF.
    ENDIF.

    " Chạy nền / job không được phép hiện popup đăng nhập
    eo_client->propertytype_logon_popup = if_http_client=>co_disabled.
    eo_client->propertytype_redirect    = if_http_client=>co_enabled.

  ENDMETHOD.


  METHOD apply_auth.

    DATA(lv_mode) = is_call-auth_mode.
    IF lv_mode IS INITIAL.
      lv_mode = is_call-conn-auth_mode.
    ENDIF.

    CASE lv_mode.

      WHEN zif_hddt_types=>gc_auth-basic.
        io_client->request->set_authorization(
          username = is_call-username
          password = is_call-secret ).

      WHEN zif_hddt_types=>gc_auth-header.
        " Một số nhà cung cấp (Viettel) nhận user/pass qua header riêng
        " ĐỒNG THỜI vẫn kiểm tra Basic -> gửi cả hai cho chắc.
        io_client->request->set_header_field( name  = 'username'
                                             value = is_call-username ).
        io_client->request->set_header_field( name  = 'password'
                                             value = is_call-secret ).
        io_client->request->set_authorization(
          username = is_call-username
          password = is_call-secret ).

      WHEN zif_hddt_types=>gc_auth-token
        OR zif_hddt_types=>gc_auth-oauth2.
        IF is_call-bearer IS NOT INITIAL.
          io_client->request->set_header_field(
            name  = 'Authorization'
            value = |Bearer { is_call-bearer }| ).
        ENDIF.

      WHEN zif_hddt_types=>gc_auth-none.
        " Destination hoặc reverse proxy tự gắn Authorization

      WHEN OTHERS.
        " Không cấu hình -> không gắn gì, để destination quyết định
    ENDCASE.

  ENDMETHOD.


  METHOD header_text.

    LOOP AT it_fields ASSIGNING FIELD-SYMBOL(<fs_f>).
      IF r_text IS NOT INITIAL.
        r_text = r_text && cl_abap_char_utilities=>newline.
      ENDIF.
      r_text = r_text && |{ <fs_f>-name }: { <fs_f>-value }|.
    ENDLOOP.

  ENDMETHOD.


  METHOD send.

    DATA lo_client TYPE REF TO if_http_client.
    DATA lv_t1     TYPE i.
    DATA lv_t2     TYPE i.
    DATA lv_msg    TYPE string.

    DATA(lv_path) = resolve_path( i_path    = is_call-action-api_path
                                  it_symbols = is_call-symbols ).

    create_client( EXPORTING is_call     = is_call
                             i_path     = lv_path
                   IMPORTING eo_client   = lo_client
                             e_full_url = rs_response-full_url ).

    DATA(lv_method) = |{ is_call-action-http_method }|.
    CONDENSE lv_method.
    TRANSLATE lv_method TO UPPER CASE.

    lo_client->request->set_version( if_http_request=>co_protocol_version_1_1 ).
    lo_client->request->set_method( lv_method ).
    lo_client->request->set_content_type( |{ is_call-action-cont_type }| ).
    lo_client->request->set_header_field( name  = 'Accept'
                                         value = |{ is_call-action-accept_type }| ).

    LOOP AT is_call-headers ASSIGNING FIELD-SYMBOL(<fs_hdr>).
      lo_client->request->set_header_field( name  = <fs_hdr>-name
                                           value = <fs_hdr>-value ).
    ENDLOOP.

    apply_auth( is_call   = is_call
                io_client = lo_client ).

    IF is_call-payload IS NOT INITIAL
       AND lv_method <> 'GET' AND lv_method <> 'DELETE'.
      lo_client->request->set_cdata( is_call-payload ).
    ENDIF.

    GET RUN TIME FIELD lv_t1.

    lo_client->send(
      EXPORTING
        timeout                    = is_call-conn-timeout
      EXCEPTIONS
        http_communication_failure = 1
        http_invalid_state         = 2
        http_processing_failed     = 3
        http_invalid_timeout       = 4
        OTHERS                     = 5 ).
    IF sy-subrc <> 0.
      lo_client->get_last_error( IMPORTING message = lv_msg ).
      lo_client->close( EXCEPTIONS OTHERS = 0 ).
      zcx_hddt_error=>raise_text(
        i_text      = |Lỗi gửi request tới { rs_response-full_url }: { lv_msg }|
        i_http_code = 999 ).
    ENDIF.

    lo_client->receive(
      EXCEPTIONS
        http_communication_failure = 1
        http_invalid_state         = 2
        http_processing_failed     = 3
        OTHERS                     = 4 ).
    IF sy-subrc <> 0.
      lo_client->get_last_error( IMPORTING message = lv_msg ).
      lo_client->close( EXCEPTIONS OTHERS = 0 ).
      zcx_hddt_error=>raise_text(
        i_text      = |Lỗi nhận response từ { rs_response-full_url }: { lv_msg }|
        i_http_code = 999 ).
    ENDIF.

    GET RUN TIME FIELD lv_t2.
    rs_response-duration_ms = ( lv_t2 - lv_t1 ) / 1000.

    " Ghi lại header hai chiều TRƯỚC khi đóng client, phục vụ log.
    " GET_HEADER_FIELDS là method CHANGING, không phải functional method.
    DATA lt_req_hdr TYPE tihttpnvp.
    DATA lt_res_hdr TYPE tihttpnvp.
    lo_client->request->get_header_fields( CHANGING fields = lt_req_hdr ).
    lo_client->response->get_header_fields( CHANGING fields = lt_res_hdr ).
    rs_response-req_header = header_text( lt_req_hdr ).
    rs_response-res_header = header_text( lt_res_hdr ).

    lo_client->response->get_status( IMPORTING code   = rs_response-http_code
                                               reason = rs_response-reason ).
    rs_response-body   = lo_client->response->get_cdata( ).
    rs_response-body_x = lo_client->response->get_data( ).

    lo_client->close( EXCEPTIONS OTHERS = 0 ).

  ENDMETHOD.

ENDCLASS.
