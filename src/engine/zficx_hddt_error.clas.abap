*=====================================================================
* Tên/Mã     : ZFICX_HDDT_ERROR
* Mô tả chung: Exception dùng chung cho toàn bộ package HĐĐT Core.
*              Hỗ trợ T100 (dùng được với MESSAGE ... INTO / RAISING)
*              và cả text tự do.
* Tham Số    : iv_text  - thông điệp tự do
*              iv_msgid/iv_msgno/iv_msgv1..4 - message T100
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       28/08/2026    cuongus - CuongUS        abapGit     Tạo mới
*=====================================================================
CLASS zficx_hddt_error DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_t100_dyn_msg .
    INTERFACES if_t100_message .

    CONSTANTS:
      "! Thông điệp mặc định: &1 &2 &3 &4
      BEGIN OF gc_free_text,
        msgid TYPE symsgid      VALUE 'ZFIE_HDDT',
        msgno TYPE symsgno      VALUE '000',
        attr1 TYPE scx_attrname VALUE 'MV_MSGV1',
        attr2 TYPE scx_attrname VALUE 'MV_MSGV2',
        attr3 TYPE scx_attrname VALUE 'MV_MSGV3',
        attr4 TYPE scx_attrname VALUE 'MV_MSGV4',
      END OF gc_free_text .

    DATA mv_msgv1 TYPE symsgv READ-ONLY .
    DATA mv_msgv2 TYPE symsgv READ-ONLY .
    DATA mv_msgv3 TYPE symsgv READ-ONLY .
    DATA mv_msgv4 TYPE symsgv READ-ONLY .
    "! Thông điệp đầy đủ (không bị cắt 50 ký tự như symsgv)
    DATA mv_text TYPE string READ-ONLY .
    "! Mã HTTP nếu lỗi phát sinh khi gọi API
    DATA mv_http_code TYPE i READ-ONLY .

    METHODS constructor
      IMPORTING
        !textid    LIKE if_t100_message=>t100key OPTIONAL
        !previous  LIKE previous OPTIONAL
        !iv_text   TYPE string OPTIONAL
        !iv_msgv1  TYPE symsgv OPTIONAL
        !iv_msgv2  TYPE symsgv OPTIONAL
        !iv_msgv3  TYPE symsgv OPTIONAL
        !iv_msgv4  TYPE symsgv OPTIONAL
        !iv_http_code TYPE i OPTIONAL .

    "! Tiện ích: raise exception với text tự do
    CLASS-METHODS raise_text
      IMPORTING
        !iv_text      TYPE string
        !iv_http_code TYPE i OPTIONAL
        !io_previous  TYPE REF TO cx_root OPTIONAL
      RAISING
        zficx_hddt_error .

    "! Lấy thông điệp để hiển thị / ghi log
    METHODS get_text_long
      RETURNING VALUE(rv_text) TYPE string .

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zficx_hddt_error IMPLEMENTATION.

  METHOD constructor.

    DATA lv_rest TYPE string.

    super->constructor( previous = previous ).
    CLEAR me->textid.

    me->mv_text      = iv_text.
    me->mv_http_code = iv_http_code.
    me->mv_msgv1     = iv_msgv1.
    me->mv_msgv2     = iv_msgv2.
    me->mv_msgv3     = iv_msgv3.
    me->mv_msgv4     = iv_msgv4.

    " Không truyền msgv nhưng có text -> tự cắt text thành 4 biến
    IF iv_msgv1 IS INITIAL AND iv_text IS NOT INITIAL.
      lv_rest = iv_text.
      me->mv_msgv1 = lv_rest(50).
      SHIFT lv_rest LEFT BY 50 PLACES.
      IF lv_rest IS NOT INITIAL.
        me->mv_msgv2 = lv_rest(50).
        SHIFT lv_rest LEFT BY 50 PLACES.
      ENDIF.
      IF lv_rest IS NOT INITIAL.
        me->mv_msgv3 = lv_rest(50).
        SHIFT lv_rest LEFT BY 50 PLACES.
      ENDIF.
      IF lv_rest IS NOT INITIAL.
        me->mv_msgv4 = lv_rest(50).
      ENDIF.
    ENDIF.

    IF textid IS INITIAL.
      if_t100_message~t100key = gc_free_text.
    ELSE.
      if_t100_message~t100key = textid.
    ENDIF.

  ENDMETHOD.


  METHOD raise_text.

    RAISE EXCEPTION TYPE zficx_hddt_error
      EXPORTING
        iv_text      = iv_text
        iv_http_code = iv_http_code
        previous     = io_previous.

  ENDMETHOD.


  METHOD get_text_long.

    IF mv_text IS NOT INITIAL.
      rv_text = mv_text.
    ELSE.
      rv_text = me->get_text( ).
    ENDIF.

  ENDMETHOD.

ENDCLASS.
