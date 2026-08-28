*=====================================================================
* Tên/Mã     : ZFIC_HDDT_FACTORY
* Mô tả chung: Nhà máy sinh đối tượng adapter theo CẤU HÌNH.
*              Đây là điểm khiến "đổi nhà cung cấp = đổi cấu hình":
*              tên lớp adapter được đọc từ ZFIT_HDDT_PROV-CLASSNAME
*              rồi CREATE OBJECT động, nên trong toàn bộ engine KHÔNG
*              có một dòng nào nhắc tên VIETTEL / FPT / VNPT.
*              Đối tượng đã tạo được cache theo tên lớp trong 1 LUW.
* Tham Số    : Chỉ dùng class-method.
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       28/08/2026    cuongus - CuongUS        abapGit     Tạo mới
*=====================================================================
CLASS zfic_hddt_factory DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE .

  PUBLIC SECTION.

    "! Lấy adapter nhà cung cấp.
    "! Không truyền IV_PROVIDER => tự xác định theo công ty từ cấu hình.
    CLASS-METHODS get_provider
      IMPORTING iv_provider        TYPE zfide_hddt_prov OPTIONAL
                iv_bukrs           TYPE bukrs OPTIONAL
      RETURNING VALUE(ro_provider) TYPE REF TO zfiif_hddt_provider
      RAISING   zficx_hddt_error .

    "! Lấy lớp đọc dữ liệu nguồn (FI/SD/MM/GOM/CUST).
    CLASS-METHODS get_source
      IMPORTING iv_bukrs         TYPE bukrs
                iv_src_type      TYPE zfide_hddt_srctype
      RETURNING VALUE(ro_source) TYPE REF TO zfiif_hddt_source
      RAISING   zficx_hddt_error .

    CLASS-METHODS reset .

  PROTECTED SECTION.
  PRIVATE SECTION.

    TYPES: BEGIN OF ty_cache,
             classname TYPE zfide_hddt_class,
             instance  TYPE REF TO object,
           END OF ty_cache.

    CLASS-DATA mt_cache TYPE HASHED TABLE OF ty_cache
                        WITH UNIQUE KEY classname .

    CLASS-METHODS create_instance
      IMPORTING iv_class          TYPE zfide_hddt_class
      RETURNING VALUE(ro_object)  TYPE REF TO object
      RAISING   zficx_hddt_error .

ENDCLASS.



CLASS zfic_hddt_factory IMPLEMENTATION.

  METHOD get_provider.

    DATA(lo_config) = zfic_hddt_config=>get_instance( ).
    DATA lv_provider TYPE zfide_hddt_prov.

    lv_provider = iv_provider.
    IF lv_provider IS INITIAL.
      IF iv_bukrs IS INITIAL.
        zficx_hddt_error=>raise_text(
          `Phải truyền nhà cung cấp hoặc mã công ty để xác định adapter HĐĐT.` ).
      ENDIF.
      lv_provider = lo_config->get_active_provider( iv_bukrs ).
    ENDIF.

    DATA(lv_class) = lo_config->get_provider_class( lv_provider ).
    DATA(lo_object) = create_instance( lv_class ).

    TRY.
        ro_provider ?= lo_object.
      CATCH cx_sy_move_cast_error.
        zficx_hddt_error=>raise_text(
          |Lớp { lv_class } (nhà cung cấp { lv_provider }) không implement| &&
          | interface ZFIIF_HDDT_PROVIDER.| ).
    ENDTRY.

    " Bảo vệ cấu hình sai: adapter phải khai đúng mã nhà cung cấp
    IF ro_provider->get_id( ) <> lv_provider.
      zficx_hddt_error=>raise_text(
        |Lớp { lv_class } khai báo GET_ID = { ro_provider->get_id( ) } nhưng| &&
        | được cấu hình cho nhà cung cấp { lv_provider }.| ).
    ENDIF.

  ENDMETHOD.


  METHOD get_source.

    DATA(lo_config) = zfic_hddt_config=>get_instance( ).
    DATA(lv_class)  = lo_config->get_source_class( iv_bukrs    = iv_bukrs
                                                   iv_src_type = iv_src_type ).
    DATA(lo_object) = create_instance( lv_class ).

    TRY.
        ro_source ?= lo_object.
      CATCH cx_sy_move_cast_error.
        zficx_hddt_error=>raise_text(
          |Lớp { lv_class } không implement interface ZFIIF_HDDT_SOURCE.| ).
    ENDTRY.

  ENDMETHOD.


  METHOD create_instance.

    DATA lv_class TYPE zfide_hddt_class.

    lv_class = iv_class.
    TRANSLATE lv_class TO UPPER CASE.

    TRY.
        ro_object = mt_cache[ classname = lv_class ]-instance.
        RETURN.
      CATCH cx_sy_itab_line_not_found.
        " chưa có trong cache -> tạo mới
    ENDTRY.

    TRY.
        CREATE OBJECT ro_object TYPE (lv_class).
      CATCH cx_sy_create_object_error INTO DATA(lx_create).
        zficx_hddt_error=>raise_text(
          iv_text     = |Không tạo được đối tượng của lớp { lv_class }: | &&
                        |{ lx_create->get_text( ) }|
          io_previous = lx_create ).
    ENDTRY.

    INSERT VALUE ty_cache( classname = lv_class
                           instance  = ro_object ) INTO TABLE mt_cache.

  ENDMETHOD.


  METHOD reset.

    CLEAR mt_cache.
    zfic_hddt_config=>get_instance( )->invalidate( ).

  ENDMETHOD.

ENDCLASS.
