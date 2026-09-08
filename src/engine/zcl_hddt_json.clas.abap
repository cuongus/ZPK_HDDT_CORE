*=====================================================================
* Tên/Mã     : ZCL_HDDT_JSON
* Mô tả chung: Bộ dựng (writer) và bộ đọc (parser) JSON tự chứa, không
*              phụ thuộc lớp Z bên ngoài hay /UI2/CL_JSON.
*              Lý do tự viết thay vì serialize cấu trúc ABAP:
*                - Nhà cung cấp HĐĐT rất kỹ tính về CHỮ HOA/CHỮ THƯỜNG
*                  của tên thẻ (camelCase như invoiceIssuedDate) —
*                  serializer theo tên field ABAP luôn phải "REPLACE
*                  ALL OCCURRENCES" để sửa lại, rất dễ vỡ.
*                - Số phải xuất dạng 10450 / 9500.5, không phải
*                  0000010450.000000, và dấu trừ phải nằm phía trước.
*                - Thẻ rỗng phải BỎ HẲN thay vì gửi "".
*              Writer dạng fluent nên adapter đọc như đọc tài liệu API.
* Tham Số    : Writer  : dùng instance (NEW zcl_hddt_json( ))
*              Parser  : dùng class-method PARSE / GET_VALUE
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       28/08/2026    cuongus - CuongUS        abapGit     Tạo mới
*=====================================================================
CLASS zcl_hddt_json DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    TYPES ty_t_kv TYPE zif_hddt_types=>ty_t_kv .

    "! ---- WRITER ----
    "! Bỏ qua thẻ có giá trị rỗng (mặc định bật). Nhiều nhà cung cấp
    "! báo lỗi validate khi nhận "" ở thẻ không bắt buộc.
    METHODS constructor
      IMPORTING i_skip_initial TYPE abap_bool DEFAULT abap_true .

    "! Khởi tạo ký tự CR/LF/TAB dùng khi escape chuỗi (phải PUBLIC)
    CLASS-METHODS class_constructor .

    METHODS begin_object
      IMPORTING i_name        TYPE string OPTIONAL
      RETURNING VALUE(ro_self) TYPE REF TO zcl_hddt_json .

    METHODS end_object
      RETURNING VALUE(ro_self) TYPE REF TO zcl_hddt_json .

    METHODS begin_array
      IMPORTING i_name        TYPE string
      RETURNING VALUE(ro_self) TYPE REF TO zcl_hddt_json .

    METHODS end_array
      RETURNING VALUE(ro_self) TYPE REF TO zcl_hddt_json .

    "! Chuỗi. i_force = X để gửi cả khi rỗng.
    METHODS add_string
      IMPORTING i_name        TYPE string
                i_value       TYPE any
                i_force       TYPE abap_bool DEFAULT abap_false
      RETURNING VALUE(ro_self) TYPE REF TO zcl_hddt_json .

    "! Số. i_decimals = số chữ số thập phân tối đa giữ lại.
    METHODS add_number
      IMPORTING i_name        TYPE string
                i_value       TYPE any
                i_decimals    TYPE i DEFAULT 6
                i_force       TYPE abap_bool DEFAULT abap_true
      RETURNING VALUE(ro_self) TYPE REF TO zcl_hddt_json .

    METHODS add_bool
      IMPORTING i_name        TYPE string
                i_value       TYPE abap_bool
      RETURNING VALUE(ro_self) TYPE REF TO zcl_hddt_json .

    "! Chuỗi 'true'/'false' dạng TEXT (một số API yêu cầu "true")
    METHODS add_bool_text
      IMPORTING i_name        TYPE string
                i_value       TYPE abap_bool
      RETURNING VALUE(ro_self) TYPE REF TO zcl_hddt_json .

    METHODS add_null
      IMPORTING i_name        TYPE string
      RETURNING VALUE(ro_self) TYPE REF TO zcl_hddt_json .

    "! Ghép nguyên một đoạn JSON đã dựng sẵn.
    METHODS add_raw
      IMPORTING i_name        TYPE string OPTIONAL
                i_json        TYPE string
      RETURNING VALUE(ro_self) TYPE REF TO zcl_hddt_json .

    "! Ghi các cặp name/value mở rộng (ty_t_kv) như chuỗi.
    METHODS add_ext
      IMPORTING it_ext         TYPE ty_t_kv
      RETURNING VALUE(ro_self) TYPE REF TO zcl_hddt_json .

    METHODS get_json
      RETURNING VALUE(r_json) TYPE string .

    "! ---- PARSER ----
    "! Trả về bảng phẳng path -> value.
    "! Ví dụ: {"inv":{"seq":"11"},"tax":[{"vrt":"10"}]} cho ra
    "!   inv/seq      = 11
    "!   tax[0]/vrt   = 10
    "!   tax#count    = 1
    CLASS-METHODS parse
      IMPORTING i_json          TYPE string
      RETURNING VALUE(rt_values) TYPE ty_t_kv
      RAISING   zcx_hddt_error .

    "! Lấy giá trị theo path chính xác.
    CLASS-METHODS get_value
      IMPORTING it_values       TYPE ty_t_kv
                i_path         TYPE string
      RETURNING VALUE(r_value) TYPE string .

    "! Lấy giá trị theo TÊN THẺ LÁ, bất kể nằm ở cấp nào. Dùng khi
    "! nhà cung cấp thay đổi độ sâu lồng nhau giữa các phiên bản API.
    CLASS-METHODS get_value_by_name
      IMPORTING it_values       TYPE ty_t_kv
                i_name         TYPE string
      RETURNING VALUE(r_value) TYPE string .

    "! Xuống dòng + thụt lề cho JSON để đọc được trên màn hình log.
    "! Không dùng CL_SXML (khác API giữa 2 nền tảng) — chỉ duyệt ký tự,
    "! nên chạy được ở cả ABAP cổ điển và ABAP Cloud.
    CLASS-METHODS pretty
      IMPORTING i_json        TYPE string
                i_indent      TYPE i DEFAULT 2
      RETURNING VALUE(rt_lines) TYPE string_table .

    "! Escape một chuỗi để nhúng vào JSON (không kèm dấu ngoặc kép).
    CLASS-METHODS escape
      IMPORTING i_value          TYPE any
      RETURNING VALUE(r_escaped) TYPE string .

    "! Định dạng số cho JSON: không zero dẫn đầu, dấu '.' thập phân,
    "! dấu trừ đứng trước, bỏ số 0 vô nghĩa ở cuối.
    CLASS-METHODS format_number
      IMPORTING i_value       TYPE any
                i_decimals    TYPE i DEFAULT 6
      RETURNING VALUE(r_text) TYPE string .

  PROTECTED SECTION.
  PRIVATE SECTION.

    CONSTANTS gc_quote TYPE c LENGTH 1 VALUE '"' .

    CLASS-DATA gv_cr  TYPE c LENGTH 1 .
    CLASS-DATA gv_lf  TYPE c LENGTH 1 .
    CLASS-DATA gv_tab TYPE c LENGTH 1 .

    DATA mv_buffer       TYPE string .
    DATA mv_skip_initial TYPE abap_bool .
    "! Mỗi phần tử = 1 cấp lồng; abap_true nghĩa là đã có phần tử,
    "! phần tử tiếp theo phải đặt dấu phẩy phía trước.
    DATA mt_has_item     TYPE STANDARD TABLE OF abap_bool WITH EMPTY KEY .

    METHODS open_level .
    METHODS close_level .
    METHODS separator .
    METHODS write_name
      IMPORTING i_name TYPE string .

    "! ---- trạng thái parser ----
    DATA mv_src    TYPE string .
    DATA mv_pos    TYPE i .
    DATA mv_len    TYPE i .
    DATA mt_result TYPE ty_t_kv .

    METHODS do_parse
      IMPORTING i_json          TYPE string
      RETURNING VALUE(rt_values) TYPE ty_t_kv
      RAISING   zcx_hddt_error .
    METHODS p_value
      IMPORTING i_path TYPE string
      RAISING   zcx_hddt_error .
    METHODS p_object
      IMPORTING i_path TYPE string
      RAISING   zcx_hddt_error .
    METHODS p_array
      IMPORTING i_path TYPE string
      RAISING   zcx_hddt_error .
    METHODS p_string
      RETURNING VALUE(r_value) TYPE string
      RAISING   zcx_hddt_error .
    METHODS p_scalar
      RETURNING VALUE(r_value) TYPE string .
    METHODS skip_ws .
    METHODS cur
      RETURNING VALUE(r_char) TYPE char1 .
    METHODS add_result
      IMPORTING i_path  TYPE string
                i_value TYPE string .

ENDCLASS.



CLASS zcl_hddt_json IMPLEMENTATION.

  METHOD class_constructor.

    " Lấy qua lớp nền tảng: CL_ABAP_CHAR_UTILITIES không được phép trong
    " ABAP Cloud, mà lớp này phải dùng chung cho cả hai nền tảng.
    DATA(lo_plat) = zcl_hddt_platform=>get( ).
    gv_cr  = lo_plat->carriage_return( ).
    gv_lf  = lo_plat->newline( ).
    gv_tab = lo_plat->tab( ).

  ENDMETHOD.


*---------------------------------------------------------------------*
* WRITER
*---------------------------------------------------------------------*
  METHOD constructor.

    mv_skip_initial = i_skip_initial.

  ENDMETHOD.


  METHOD open_level.

    APPEND abap_false TO mt_has_item.

  ENDMETHOD.


  METHOD close_level.

    DATA(lv_last) = lines( mt_has_item ).
    IF lv_last > 0.
      DELETE mt_has_item INDEX lv_last.
    ENDIF.

  ENDMETHOD.


  METHOD separator.

    DATA(lv_last) = lines( mt_has_item ).
    IF lv_last = 0.
      RETURN.
    ENDIF.
    IF mt_has_item[ lv_last ] = abap_true.
      mv_buffer = mv_buffer && `,`.
    ELSE.
      mt_has_item[ lv_last ] = abap_true.
    ENDIF.

  ENDMETHOD.


  METHOD write_name.

    IF i_name IS NOT INITIAL.
      mv_buffer = mv_buffer && gc_quote && i_name && gc_quote && `:`.
    ENDIF.

  ENDMETHOD.


  METHOD begin_object.

    separator( ).
    write_name( i_name ).
    mv_buffer = mv_buffer && `{`.
    open_level( ).
    ro_self = me.

  ENDMETHOD.


  METHOD end_object.

    close_level( ).
    mv_buffer = mv_buffer && `}`.
    ro_self = me.

  ENDMETHOD.


  METHOD begin_array.

    separator( ).
    write_name( i_name ).
    mv_buffer = mv_buffer && `[`.
    open_level( ).
    ro_self = me.

  ENDMETHOD.


  METHOD end_array.

    close_level( ).
    mv_buffer = mv_buffer && `]`.
    ro_self = me.

  ENDMETHOD.


  METHOD add_string.

    ro_self = me.

    DATA(lv_text) = escape( i_value ).
    IF lv_text IS INITIAL
       AND mv_skip_initial = abap_true
       AND i_force = abap_false.
      RETURN.
    ENDIF.

    separator( ).
    write_name( i_name ).
    mv_buffer = mv_buffer && gc_quote && lv_text && gc_quote.

  ENDMETHOD.


  METHOD add_number.

    ro_self = me.

    DATA(lv_num) = format_number( i_value    = i_value
                                  i_decimals = i_decimals ).
    IF lv_num = `0` AND i_force = abap_false.
      RETURN.
    ENDIF.

    separator( ).
    write_name( i_name ).
    mv_buffer = mv_buffer && lv_num.

  ENDMETHOD.


  METHOD add_bool.

    separator( ).
    write_name( i_name ).
    mv_buffer = mv_buffer && COND string( WHEN i_value = abap_true
                                          THEN `true` ELSE `false` ).
    ro_self = me.

  ENDMETHOD.


  METHOD add_bool_text.

    ro_self = add_string( i_name  = i_name
                          i_value = COND string( WHEN i_value = abap_true
                                                  THEN `true` ELSE `false` )
                          i_force = abap_true ).

  ENDMETHOD.


  METHOD add_null.

    separator( ).
    write_name( i_name ).
    mv_buffer = mv_buffer && `null`.
    ro_self = me.

  ENDMETHOD.


  METHOD add_raw.

    ro_self = me.
    IF i_json IS INITIAL.
      RETURN.
    ENDIF.

    separator( ).
    write_name( i_name ).
    mv_buffer = mv_buffer && i_json.

  ENDMETHOD.


  METHOD add_ext.

    ro_self = me.
    LOOP AT it_ext ASSIGNING FIELD-SYMBOL(<fs_ext>).
      add_string( i_name  = <fs_ext>-name
                  i_value = <fs_ext>-value ).
    ENDLOOP.

  ENDMETHOD.


  METHOD get_json.

    r_json = mv_buffer.

  ENDMETHOD.


  METHOD pretty.

    DATA lv_level  TYPE i.
    DATA lv_line   TYPE string.
    DATA lv_in_str TYPE abap_bool.
    DATA lv_esc    TYPE abap_bool.

    DATA(lv_len) = strlen( i_json ).
    DATA lv_i TYPE i.

    WHILE lv_i < lv_len.
      DATA(lv_c) = substring( val = i_json off = lv_i len = 1 ).
      lv_i = lv_i + 1.

      " Trong chuỗi thì mọi ký tự cấu trúc đều là dữ liệu, không xét
      IF lv_in_str = abap_true.
        lv_line = lv_line && lv_c.
        IF lv_esc = abap_true.
          lv_esc = abap_false.
        ELSEIF lv_c = `\`.
          lv_esc = abap_true.
        ELSEIF lv_c = `"`.
          lv_in_str = abap_false.
        ENDIF.
        CONTINUE.
      ENDIF.

      CASE lv_c.
        WHEN `"`.
          lv_in_str = abap_true.
          lv_line = lv_line && lv_c.

        WHEN `{` OR `[`.
          lv_line = lv_line && lv_c.
          APPEND lv_line TO rt_lines.
          lv_level = lv_level + 1.
          lv_line = repeat( val = ` ` occ = lv_level * i_indent ).

        WHEN `}` OR `]`.
          IF lv_line CN ` `.
            APPEND lv_line TO rt_lines.
          ENDIF.
          lv_level = nmax( val1 = 0 val2 = lv_level - 1 ).
          lv_line = repeat( val = ` ` occ = lv_level * i_indent ) && lv_c.

        WHEN `,`.
          lv_line = lv_line && lv_c.
          APPEND lv_line TO rt_lines.
          lv_line = repeat( val = ` ` occ = lv_level * i_indent ).

        WHEN `:`.
          lv_line = lv_line && `: `.

        WHEN OTHERS.
          " Bỏ khoảng trắng có sẵn giữa các token để thụt lề nhất quán
          IF lv_c <> ` `.
            lv_line = lv_line && lv_c.
          ENDIF.
      ENDCASE.
    ENDWHILE.

    IF lv_line CN ` `.
      APPEND lv_line TO rt_lines.
    ENDIF.

  ENDMETHOD.


  METHOD escape.

    r_escaped = |{ i_value }|.

    " Thứ tự quan trọng: backslash phải xử lý trước tiên.
    REPLACE ALL OCCURRENCES OF `\` IN r_escaped WITH `\\`.
    REPLACE ALL OCCURRENCES OF `"` IN r_escaped WITH `\"`.
    REPLACE ALL OCCURRENCES OF gv_cr && gv_lf IN r_escaped WITH `\r\n`.
    REPLACE ALL OCCURRENCES OF gv_cr  IN r_escaped WITH `\r`.
    REPLACE ALL OCCURRENCES OF gv_lf  IN r_escaped WITH `\n`.
    REPLACE ALL OCCURRENCES OF gv_tab IN r_escaped WITH `\t`.

  ENDMETHOD.


  METHOD format_number.

    DATA lv_packed TYPE p LENGTH 16 DECIMALS 6.
    DATA lv_dec    TYPE i.

    TRY.
        lv_packed = i_value.
      CATCH cx_sy_conversion_error.
        r_text = `0`.
        RETURN.
    ENDTRY.

    lv_dec = i_decimals.
    IF lv_dec < 0.
      lv_dec = 0.
    ELSEIF lv_dec > 6.
      lv_dec = 6.
    ENDIF.

    lv_packed = round( val = lv_packed dec = lv_dec ).

    " NUMBER = RAW luôn cho dấu '.' làm phân cách thập phân và dấu trừ ở
    " PHÍA TRƯỚC, độc lập cài đặt của người dùng — đúng yêu cầu JSON.
    " Bản trước dùng WRITE ... TO + NO-GROUPING + đổi ',' thành '.' + tự
    " đảo dấu; cách đó phụ thuộc user setting VÀ không được phép trong
    " ABAP Cloud. NUMBER = RAW giải quyết cả hai vấn đề.
    r_text = |{ lv_packed NUMBER = RAW }|.
    CONDENSE r_text NO-GAPS.

    " Bỏ các số 0 vô nghĩa ở cuối phần thập phân
    IF r_text CS `.`.
      WHILE strlen( r_text ) > 1 AND substring( val = r_text
                                                 off = strlen( r_text ) - 1
                                                 len = 1 ) = `0`.
        r_text = substring( val = r_text len = strlen( r_text ) - 1 ).
      ENDWHILE.
      IF strlen( r_text ) > 1 AND substring( val = r_text
                                              off = strlen( r_text ) - 1
                                              len = 1 ) = `.`.
        r_text = substring( val = r_text len = strlen( r_text ) - 1 ).
      ENDIF.
    ENDIF.

    IF r_text IS INITIAL OR r_text = `-0` OR r_text = `-`.
      r_text = `0`.
    ENDIF.

  ENDMETHOD.


*---------------------------------------------------------------------*
* PARSER
*---------------------------------------------------------------------*
  METHOD parse.

    rt_values = NEW zcl_hddt_json( )->do_parse( i_json ).

  ENDMETHOD.


  METHOD do_parse.

    CLEAR mt_result.
    mv_src = i_json.
    mv_len = strlen( mv_src ).
    mv_pos = 0.

    IF mv_len = 0.
      RETURN.
    ENDIF.

    skip_ws( ).
    p_value( `` ).
    rt_values = mt_result.

  ENDMETHOD.


  METHOD cur.

    IF mv_pos < mv_len.
      r_char = substring( val = mv_src off = mv_pos len = 1 ).
    ELSE.
      CLEAR r_char.
    ENDIF.

  ENDMETHOD.


  METHOD skip_ws.

    WHILE mv_pos < mv_len.
      DATA(lv_c) = substring( val = mv_src off = mv_pos len = 1 ).
      IF lv_c = ` ` OR lv_c = gv_tab
                    OR lv_c = gv_lf
                    OR lv_c = gv_cr.
        mv_pos = mv_pos + 1.
      ELSE.
        EXIT.
      ENDIF.
    ENDWHILE.

  ENDMETHOD.


  METHOD add_result.

    APPEND VALUE #( name = i_path value = i_value ) TO mt_result.

  ENDMETHOD.


  METHOD p_value.

    skip_ws( ).
    DATA(lv_c) = cur( ).

    CASE lv_c.
      WHEN `{`.
        p_object( i_path ).
      WHEN `[`.
        p_array( i_path ).
      WHEN `"`.
        add_result( i_path = i_path i_value = p_string( ) ).
      WHEN OTHERS.
        add_result( i_path = i_path i_value = p_scalar( ) ).
    ENDCASE.

  ENDMETHOD.


  METHOD p_object.

    mv_pos = mv_pos + 1.                     " bỏ qua '{'
    skip_ws( ).

    IF cur( ) = `}`.
      mv_pos = mv_pos + 1.
      RETURN.
    ENDIF.

    DO.
      skip_ws( ).
      IF cur( ) <> `"`.
        zcx_hddt_error=>raise_text(
          |JSON không hợp lệ: chờ tên thẻ tại vị trí { mv_pos }.| ).
      ENDIF.
      DATA(lv_key) = p_string( ).

      skip_ws( ).
      IF cur( ) <> `:`.
        zcx_hddt_error=>raise_text(
          |JSON không hợp lệ: thiếu ':' tại vị trí { mv_pos }.| ).
      ENDIF.
      mv_pos = mv_pos + 1.

      p_value( COND string( WHEN i_path IS INITIAL
                            THEN lv_key
                            ELSE i_path && `/` && lv_key ) ).

      skip_ws( ).
      IF cur( ) = `,`.
        mv_pos = mv_pos + 1.
        CONTINUE.
      ENDIF.

      IF cur( ) = `}`.
        mv_pos = mv_pos + 1.
        EXIT.
      ENDIF.

      zcx_hddt_error=>raise_text(
        |JSON không hợp lệ: chờ ',' hoặc '\}' tại vị trí { mv_pos }.| ).
    ENDDO.

  ENDMETHOD.


  METHOD p_array.

    DATA lv_idx TYPE i.

    mv_pos = mv_pos + 1.                     " bỏ qua '['
    skip_ws( ).

    IF cur( ) = `]`.
      mv_pos = mv_pos + 1.
      add_result( i_path = i_path && `#count` i_value = `0` ).
      RETURN.
    ENDIF.

    DO.
      p_value( |{ i_path }[{ lv_idx }]| ).
      lv_idx = lv_idx + 1.

      skip_ws( ).
      IF cur( ) = `,`.
        mv_pos = mv_pos + 1.
        CONTINUE.
      ENDIF.

      IF cur( ) = `]`.
        mv_pos = mv_pos + 1.
        EXIT.
      ENDIF.

      zcx_hddt_error=>raise_text(
        |JSON không hợp lệ: chờ ',' hoặc ']' tại vị trí { mv_pos }.| ).
    ENDDO.

    add_result( i_path  = i_path && `#count`
                i_value = |{ lv_idx }| ).

  ENDMETHOD.


  METHOD p_string.

    DATA lv_hex TYPE c LENGTH 4.

    mv_pos = mv_pos + 1.                     " bỏ qua '"' mở

    WHILE mv_pos < mv_len.
      DATA(lv_c) = substring( val = mv_src off = mv_pos len = 1 ).

      IF lv_c = `"`.
        mv_pos = mv_pos + 1.
        RETURN.
      ENDIF.

      IF lv_c = `\`.
        mv_pos = mv_pos + 1.
        DATA(lv_e) = cur( ).
        CASE lv_e.
          WHEN `n`. r_value = r_value && gv_lf.
          WHEN `r`. r_value = r_value && gv_cr.
          WHEN `t`. r_value = r_value && gv_tab.
          WHEN `b` OR `f`. "  bỏ qua backspace / form feed
          WHEN `u`.
            IF mv_pos + 4 < mv_len.
              lv_hex = substring( val = mv_src off = mv_pos + 1 len = 4 ).
              TRY.
                  DATA lv_x2   TYPE x LENGTH 2.
                  DATA lv_xstr TYPE xstring.
                  " Gán C chứa chữ số hex sang X = quy đổi hexa
                  lv_x2   = lv_hex.
                  lv_xstr = lv_x2.
                  r_value = r_value
                          && zcl_hddt_platform=>get( )->xstring_to_string(
                               i_data     = lv_xstr
                               i_encoding = `UTF-16BE` ).
                CATCH cx_root.
                  " Không dịch được -> bỏ qua, không làm vỡ toàn bộ parse
              ENDTRY.
              mv_pos = mv_pos + 4.
            ENDIF.
          WHEN OTHERS.
            r_value = r_value && lv_e.     " \" \\ \/ và mọi ký tự khác
        ENDCASE.
        mv_pos = mv_pos + 1.
        CONTINUE.
      ENDIF.

      r_value = r_value && lv_c.
      mv_pos   = mv_pos + 1.
    ENDWHILE.

    zcx_hddt_error=>raise_text( `JSON không hợp lệ: chuỗi không đóng.` ).

  ENDMETHOD.


  METHOD p_scalar.

    " Số, true, false, null — đọc tới dấu phân cách gần nhất.
    WHILE mv_pos < mv_len.
      DATA(lv_c) = substring( val = mv_src off = mv_pos len = 1 ).
      IF lv_c = `,` OR lv_c = `}` OR lv_c = `]`
         OR lv_c = ` ` OR lv_c = gv_lf
         OR lv_c = gv_tab
         OR lv_c = gv_cr.
        EXIT.
      ENDIF.
      r_value = r_value && lv_c.
      mv_pos   = mv_pos + 1.
    ENDWHILE.

    IF r_value = `null`.
      CLEAR r_value.
    ENDIF.

  ENDMETHOD.


  METHOD get_value.

    TRY.
        r_value = it_values[ name = i_path ]-value.
      CATCH cx_sy_itab_line_not_found.
        CLEAR r_value.
    ENDTRY.

  ENDMETHOD.


  METHOD get_value_by_name.

    DATA(lv_suffix) = `/` && i_name.

    LOOP AT it_values ASSIGNING FIELD-SYMBOL(<fs_val>).
      IF <fs_val>-name = i_name.
        r_value = <fs_val>-value.
        RETURN.
      ENDIF.
    ENDLOOP.

    LOOP AT it_values ASSIGNING <fs_val>.
      IF strlen( <fs_val>-name ) > strlen( lv_suffix )
         AND substring( val = <fs_val>-name
                        off = strlen( <fs_val>-name ) - strlen( lv_suffix )
                        len = strlen( lv_suffix ) ) = lv_suffix.
        r_value = <fs_val>-value.
        RETURN.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
