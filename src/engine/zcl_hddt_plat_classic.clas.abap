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
* 1.0       28/08/2026    cuongus - CuongUS        S25K900131  Tạo mới
* 1.2       01/10/2026    F-DUBV                   DS4K900192  20261001_14 G6-006
*                                                             decode_base64 bỏ
*                                                             CATCH CX_ROOT
* 1.1       01/10/2026    F-DUBV                   DS4K900192  20261001_07 G6-006
*                                                             thu hẹp CATCH
*                                                             CX_ROOT ở
*                                                             STRING/XSTRING
* 1.3       02/10/2026    F-DUBV - DuBV            DS4K900192  G6-011 cot Transport
*                                                              ghi mã TR thật S25K900131 (20261002_17)
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



CLASS ZCL_HDDT_PLAT_CLASSIC IMPLEMENTATION.


  METHOD zif_hddt_platform~carriage_return.

    r_char = cl_abap_char_utilities=>cr_lf(1).

  ENDMETHOD.


  METHOD zif_hddt_platform~decode_base64.

    TRY.
        r_data = cl_http_utility=>decode_x_base64( i_encoded ).
*     20261001_14 G6-006: chi bat loi chuyen doi, khong CX_ROOT
      CATCH cx_sy_conversion_error.
        CLEAR r_data.
    ENDTRY.

  ENDMETHOD.


  METHOD zif_hddt_platform~escape_url.

    r_escaped = cl_http_utility=>escape_url( i_value ).

  ENDMETHOD.


  METHOD zif_hddt_platform~get_time_zone.

    r_tzone = sy-zonlo.

  ENDMETHOD.


  METHOD zif_hddt_platform~newline.

    r_char = cl_abap_char_utilities=>newline.

  ENDMETHOD.


  METHOD zif_hddt_platform~string_to_xstring.

    TRY.
        cl_abap_conv_out_ce=>create( encoding = CONV abap_encoding( i_encoding )
          )->convert( EXPORTING data   = i_text
                      IMPORTING buffer = r_data ).
      " 20261001_07 G6-006: bắt đúng exception khai trong CREATE/CONVERT
      CATCH cx_parameter_invalid_range cx_parameter_invalid_type
            cx_sy_codepage_converter_init cx_sy_conversion_codepage.
        CLEAR r_data.
    ENDTRY.

  ENDMETHOD.


  METHOD zif_hddt_platform~tab.

    r_char = cl_abap_char_utilities=>horizontal_tab.

  ENDMETHOD.


  METHOD zif_hddt_platform~xstring_to_string.

    TRY.
        cl_abap_conv_in_ce=>create( encoding = CONV abap_encoding( i_encoding )
          )->convert( EXPORTING input = i_data
                      IMPORTING data  = r_text ).
      " 20261001_07 G6-006: bắt đúng exception khai trong CREATE/CONVERT
      CATCH cx_parameter_invalid_range cx_parameter_invalid_type
            cx_sy_codepage_converter_init cx_sy_conversion_codepage.
        CLEAR r_text.
    ENDTRY.

  ENDMETHOD.
ENDCLASS.
