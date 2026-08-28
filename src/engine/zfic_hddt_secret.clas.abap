*=====================================================================
* Tên/Mã     : ZFIC_HDDT_SECRET
* Mô tả chung: Bộ giải quyết secret API theo thứ tự ưu tiên:
*                1) Lớp khách hàng tự cắm qua tham số SECRET_CLASS
*                   (implement ZFIIF_HDDT_SECRET) — dùng khi có vault.
*                2) Trường ZFIT_HDDT_CRED-APISECRET.
*              [Lưu ý bảo mật] Cách an toàn nhất trên SAP Private Cloud
*              là KHÔNG lưu mật khẩu trong bảng Z: khai báo user/password
*              ngay trong RFC destination loại G (SM59) và đặt
*              ZFIT_HDDT_CONN-AUTH_MODE = 'N' để destination tự gắn
*              Authorization. Xem docs/02-cau-hinh.md §Bảo mật.
* Tham Số    : Chỉ dùng class-method GET_SECRET.
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       28/08/2026    cuongus - CuongUS        abapGit     Tạo mới
*=====================================================================
CLASS zfic_hddt_secret DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE .

  PUBLIC SECTION.

    CONSTANTS gc_parm_secret_class TYPE zfide_hddt_parmkey
                                   VALUE 'SECRET_CLASS' ##NO_TEXT.

    CLASS-METHODS get_secret
      IMPORTING is_cred          TYPE zfit_hddt_cred
      RETURNING VALUE(rv_secret) TYPE string
      RAISING   zficx_hddt_error .

  PROTECTED SECTION.
  PRIVATE SECTION.

    CLASS-DATA mo_plugin  TYPE REF TO zfiif_hddt_secret .
    CLASS-DATA mv_checked TYPE abap_bool .

    CLASS-METHODS get_plugin
      RETURNING VALUE(ro_plugin) TYPE REF TO zfiif_hddt_secret
      RAISING   zficx_hddt_error .

ENDCLASS.



CLASS zfic_hddt_secret IMPLEMENTATION.

  METHOD get_secret.

    DATA(lo_plugin) = get_plugin( ).

    IF lo_plugin IS BOUND.
      rv_secret = lo_plugin->get_secret( is_cred ).
      IF rv_secret IS NOT INITIAL.
        RETURN.
      ENDIF.
    ENDIF.

    rv_secret = is_cred-apisecret.

  ENDMETHOD.


  METHOD get_plugin.

    IF mv_checked = abap_true.
      ro_plugin = mo_plugin.
      RETURN.
    ENDIF.
    mv_checked = abap_true.

    DATA(lv_class) = zfic_hddt_config=>get_instance(
                       )->get_param( gc_parm_secret_class ).
    IF lv_class IS INITIAL.
      RETURN.
    ENDIF.

    CONDENSE lv_class.
    TRANSLATE lv_class TO UPPER CASE.

    DATA lo_obj TYPE REF TO object.
    TRY.
        CREATE OBJECT lo_obj TYPE (lv_class).
        mo_plugin ?= lo_obj.
      CATCH cx_sy_create_object_error cx_sy_move_cast_error INTO DATA(lx).
        zficx_hddt_error=>raise_text(
          iv_text     = |Tham số SECRET_CLASS = { lv_class } không dùng được: | &&
                        |{ lx->get_text( ) }|
          io_previous = lx ).
    ENDTRY.

    ro_plugin = mo_plugin.

  ENDMETHOD.

ENDCLASS.
