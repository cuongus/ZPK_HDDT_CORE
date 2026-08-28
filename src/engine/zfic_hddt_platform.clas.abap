*=====================================================================
* Tên/Mã     : ZFIC_HDDT_PLATFORM
* Mô tả chung: Bộ giải quyết nền tảng. Trả về đối tượng thực thi
*              ZFIIF_HDDT_PLATFORM phù hợp với hệ đang chạy:
*                - Khai tham số PLATFORM_CLASS trong ZFIT_HDDT_PARM
*                  (ví dụ ZFIC_HDDT_PLAT_CLOUD trên Public Cloud);
*                - Không khai => dùng ZFIC_HDDT_PLAT_CLASSIC.
*              Nhờ lớp này, adapter nhà cung cấp (ZFIC_HDDT_PROV_*) và
*              bộ JSON dùng CHUNG được cho cả Private Cloud và Public
*              Cloud mà không có một dòng IF nào theo nền tảng.
* Tham Số    : ZFIC_HDDT_PLATFORM=>GET( )
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       28/08/2026    cuongus - CuongUS        abapGit     Tạo mới
*=====================================================================
CLASS zfic_hddt_platform DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE .

  PUBLIC SECTION.

    CONSTANTS gc_parm_platform TYPE zfide_hddt_parmkey
                               VALUE 'PLATFORM_CLASS' ##NO_TEXT.
    CONSTANTS gc_class_classic TYPE zfide_hddt_class
                               VALUE 'ZFIC_HDDT_PLAT_CLASSIC' ##NO_TEXT.

    CLASS-METHODS get
      RETURNING VALUE(ro_platform) TYPE REF TO zfiif_hddt_platform .

    "! Cho phép unit test tiêm bản giả lập.
    CLASS-METHODS inject
      IMPORTING io_platform TYPE REF TO zfiif_hddt_platform .

    CLASS-METHODS reset .

  PROTECTED SECTION.
  PRIVATE SECTION.

    CLASS-DATA mo_platform TYPE REF TO zfiif_hddt_platform .

ENDCLASS.



CLASS zfic_hddt_platform IMPLEMENTATION.

  METHOD get.

    IF mo_platform IS BOUND.
      ro_platform = mo_platform.
      RETURN.
    ENDIF.

    DATA lv_class TYPE zfide_hddt_class.

    " Đọc cấu hình trong TRY: lúc cài đặt lần đầu bảng cấu hình có thể
    " chưa tồn tại / chưa có dòng nào, không được để chết ở đây.
    TRY.
        lv_class = zfic_hddt_config=>get_instance( )->get_param( gc_parm_platform ).
      CATCH cx_root.
        CLEAR lv_class.
    ENDTRY.

    CONDENSE lv_class.
    TRANSLATE lv_class TO UPPER CASE.
    IF lv_class IS INITIAL.
      lv_class = gc_class_classic.
    ENDIF.

    DATA lo_obj TYPE REF TO object.
    TRY.
        CREATE OBJECT lo_obj TYPE (lv_class).
        mo_platform ?= lo_obj.
      CATCH cx_sy_create_object_error cx_sy_move_cast_error.
        " Cấu hình sai -> lùi về bản cổ điển thay vì làm chết nghiệp vụ.
        " Sai lệch (nếu có) sẽ lộ ra ngay ở payload trong log.
        CREATE OBJECT mo_platform TYPE zfic_hddt_plat_classic.
    ENDTRY.

    ro_platform = mo_platform.

  ENDMETHOD.


  METHOD inject.

    mo_platform = io_platform.

  ENDMETHOD.


  METHOD reset.

    CLEAR mo_platform.

  ENDMETHOD.

ENDCLASS.
