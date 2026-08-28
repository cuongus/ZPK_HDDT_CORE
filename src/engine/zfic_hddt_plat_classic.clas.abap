*=====================================================================
* Tên/Mã     : ZFIC_HDDT_PLAT_CLASSIC
* Mô tả chung: Thực thi ZFIIF_HDDT_PLATFORM cho ABAP CỔ ĐIỂN
*              (SAP Private Cloud / on-premise). Đây là bản mặc định.
*              Bản cho ABAP Cloud là ZFIC_HDDT_PLAT_CLOUD — nằm trong
*              subpackage riêng, chỉ import vào hệ Public Cloud.
* Tham Số    : Không có
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       28/08/2026    cuongus - CuongUS        abapGit     Tạo mới
*=====================================================================
CLASS zfic_hddt_plat_classic DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES zfiif_hddt_platform .

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zfic_hddt_plat_classic IMPLEMENTATION.

  METHOD zfiif_hddt_platform~newline.

    rv_char = cl_abap_char_utilities=>newline.

  ENDMETHOD.


  METHOD zfiif_hddt_platform~carriage_return.

    rv_char = cl_abap_char_utilities=>cr_lf(1).

  ENDMETHOD.


  METHOD zfiif_hddt_platform~tab.

    rv_char = cl_abap_char_utilities=>horizontal_tab.

  ENDMETHOD.


  METHOD zfiif_hddt_platform~escape_url.

    rv_escaped = cl_http_utility=>escape_url( iv_value ).

  ENDMETHOD.


  METHOD zfiif_hddt_platform~xstring_to_string.

    TRY.
        cl_abap_conv_in_ce=>create( encoding = CONV abap_encoding( iv_encoding )
          )->convert( EXPORTING input = iv_data
                      IMPORTING data  = rv_text ).
      CATCH cx_root.
        CLEAR rv_text.
    ENDTRY.

  ENDMETHOD.


  METHOD zfiif_hddt_platform~string_to_xstring.

    TRY.
        cl_abap_conv_out_ce=>create( encoding = CONV abap_encoding( iv_encoding )
          )->convert( EXPORTING data   = iv_text
                      IMPORTING buffer = rv_data ).
      CATCH cx_root.
        CLEAR rv_data.
    ENDTRY.

  ENDMETHOD.


  METHOD zfiif_hddt_platform~decode_base64.

    TRY.
        rv_data = cl_http_utility=>decode_x_base64( iv_encoded ).
      CATCH cx_root.
        CLEAR rv_data.
    ENDTRY.

  ENDMETHOD.


  METHOD zfiif_hddt_platform~get_time_zone.

    rv_tzone = sy-zonlo.

  ENDMETHOD.

ENDCLASS.
