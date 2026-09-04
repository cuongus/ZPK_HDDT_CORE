*=====================================================================
* Tên/Mã     : ZCL_HDDT_PLAT_CLASSIC
* Mô tả chung: Thực thi ZIF_HDDT_PLATFORM cho ABAP CỔ ĐIỂN
*              (SAP Private Cloud / on-premise). Đây là bản mặc định.
*              Bản cho ABAP Cloud là ZCL_HDDT_PLAT_CLOUD — nằm trong
*              subpackage riêng, chỉ import vào hệ Public Cloud.
* Tham Số    : Không có
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       28/08/2026    cuongus - CuongUS        abapGit     Tạo mới
*=====================================================================
CLASS zcl_hddt_plat_classic DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES zif_hddt_platform .

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_hddt_plat_classic IMPLEMENTATION.

  METHOD zif_hddt_platform~newline.

    r_char = cl_abap_char_utilities=>newline.

  ENDMETHOD.


  METHOD zif_hddt_platform~carriage_return.

    r_char = cl_abap_char_utilities=>cr_lf(1).

  ENDMETHOD.


  METHOD zif_hddt_platform~tab.

    r_char = cl_abap_char_utilities=>horizontal_tab.

  ENDMETHOD.


  METHOD zif_hddt_platform~escape_url.

    r_escaped = cl_http_utility=>escape_url( i_value ).

  ENDMETHOD.


  METHOD zif_hddt_platform~xstring_to_string.

    TRY.
        cl_abap_conv_in_ce=>create( encoding = CONV abap_encoding( i_encoding )
          )->convert( EXPORTING input = i_data
                      IMPORTING data  = r_text ).
      CATCH cx_root.
        CLEAR r_text.
    ENDTRY.

  ENDMETHOD.


  METHOD zif_hddt_platform~string_to_xstring.

    TRY.
        cl_abap_conv_out_ce=>create( encoding = CONV abap_encoding( i_encoding )
          )->convert( EXPORTING data   = i_text
                      IMPORTING buffer = r_data ).
      CATCH cx_root.
        CLEAR r_data.
    ENDTRY.

  ENDMETHOD.


  METHOD zif_hddt_platform~decode_base64.

    TRY.
        r_data = cl_http_utility=>decode_x_base64( i_encoded ).
      CATCH cx_root.
        CLEAR r_data.
    ENDTRY.

  ENDMETHOD.


  METHOD zif_hddt_platform~get_time_zone.

    r_tzone = sy-zonlo.

  ENDMETHOD.

ENDCLASS.
