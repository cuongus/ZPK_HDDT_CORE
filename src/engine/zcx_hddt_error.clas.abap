*=====================================================================
* Tên/Mã     : ZCX_HDDT_ERROR
* Mô tả chung: Exception dùng chung cho toàn bộ package HĐĐT Core.
*              Hỗ trợ T100 (dùng được với MESSAGE ... INTO / RAISING)
*              và cả text tự do.
* Tham Số    : i_text  - thông điệp tự do
*              i_msgid/i_msgno/i_msgv1..4 - message T100
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       28/08/2026    cuongus - CuongUS        abapGit     Tạo mới
* 1.1       30/09/2026    cuongus - CuongUS        DS4K900172  Constructor
*                         cắt text vào MSGV1..4 không còn dump khi text
*                         không tròn bội số 50 ký tự; GET_TEXT trả text
*                         đầy đủ (trước đó ghép MSGV1..4 bằng khoảng
*                         trắng -> chữ bị tách "trên h ệ thống")
*=====================================================================
CLASS zcx_hddt_error DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_t100_dyn_msg .
    INTERFACES if_t100_message .

    CONSTANTS:
      "! Thông điệp mặc định: &1 &2 &3 &4
      BEGIN OF gc_free_text,
        msgid TYPE symsgid      VALUE 'ZMS_HDDT',
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
        !i_text   TYPE string OPTIONAL
        !i_msgv1  TYPE symsgv OPTIONAL
        !i_msgv2  TYPE symsgv OPTIONAL
        !i_msgv3  TYPE symsgv OPTIONAL
        !i_msgv4  TYPE symsgv OPTIONAL
        !i_http_code TYPE i OPTIONAL .

    "! Tiện ích: raise exception với text tự do
    CLASS-METHODS raise_text
      IMPORTING
        !i_text      TYPE string
        !i_http_code TYPE i OPTIONAL
        !io_previous  TYPE REF TO cx_root OPTIONAL
      RAISING
        zcx_hddt_error .

    "! Lấy thông điệp để hiển thị / ghi log
    METHODS get_text_long
      RETURNING VALUE(r_text) TYPE string .

*   >>> Begin of change 20260930_04 F-CUONGUS TR DS4K900172 - GET_TEXT trả text đầy đủ
    " Text tự do thì trả nguyên văn MV_TEXT. Bản chuẩn ghép message 000
    " "&1 &2 &3 &4" nên chèn khoảng trắng giữa mỗi 50 ký tự, cắt đôi chữ.
    METHODS if_message~get_text REDEFINITION .
*   <<< End of change 20260930_04

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCX_HDDT_ERROR IMPLEMENTATION.


  METHOD constructor ##ADT_SUPPRESS_GENERATION.

    DATA lv_rest TYPE string.

    super->constructor( previous = previous ).
    CLEAR me->textid.

    me->mv_text      = i_text.
    me->mv_http_code = i_http_code.
    me->mv_msgv1     = i_msgv1.
    me->mv_msgv2     = i_msgv2.
    me->mv_msgv3     = i_msgv3.
    me->mv_msgv4     = i_msgv4.

    " Không truyền msgv nhưng có text -> tự cắt text thành 4 biến
    IF i_msgv1 IS INITIAL AND i_text IS NOT INITIAL.
      lv_rest = i_text.
*   >>> Begin of change 20260930_03 F-CUONGUS TR DS4K900172 - Cắt text vào MSGV không dump
*      me->mv_msgv1 = lv_rest(50).
*      SHIFT lv_rest LEFT BY 50 PLACES.
*      IF lv_rest IS NOT INITIAL.
*        me->mv_msgv2 = lv_rest(50).
*        SHIFT lv_rest LEFT BY 50 PLACES.
*      ENDIF.
*      IF lv_rest IS NOT INITIAL.
*        me->mv_msgv3 = lv_rest(50).
*        SHIFT lv_rest LEFT BY 50 PLACES.
*      ENDIF.
*      IF lv_rest IS NOT INITIAL.
*        me->mv_msgv4 = lv_rest(50).
*      ENDIF.
      " LV_REST(50) trên STRING ngắn hơn 50 ký tự là CX_SY_RANGE_OUT_OF_BOUNDS
      " (không khai trong RAISING -> CX_SY_NO_HANDLER, người gọi CATCH
      " ZCX_HDDT_ERROR không bắt được -> dump). Kiểm trên DS4 30/09/2026:
      " text 30 / 65 / 115 ký tự đều dump, chỉ 50 / 100 / >= 200 là qua.
      " Gán STRING vào SYMSGV (CHAR 50) thì hệ tự cắt, không vượt biên.
      me->mv_msgv1 = lv_rest.
      SHIFT lv_rest LEFT BY 50 PLACES.
      me->mv_msgv2 = lv_rest.
      SHIFT lv_rest LEFT BY 50 PLACES.
      me->mv_msgv3 = lv_rest.
      SHIFT lv_rest LEFT BY 50 PLACES.
      me->mv_msgv4 = lv_rest.
*   <<< End of change 20260930_03
    ENDIF.

    IF textid IS INITIAL.
      if_t100_message~t100key = gc_free_text.
    ELSE.
      if_t100_message~t100key = textid.
    ENDIF.

  ENDMETHOD.


  METHOD if_message~get_text.

*   >>> Begin of change 20260930_04 F-CUONGUS TR DS4K900172 - GET_TEXT trả text đầy đủ
    IF mv_text IS NOT INITIAL.
      result = mv_text.
    ELSE.
      result = super->if_message~get_text( ).
    ENDIF.
*   <<< End of change 20260930_04

  ENDMETHOD.


  METHOD get_text_long.

    IF mv_text IS NOT INITIAL.
      r_text = mv_text.
    ELSE.
      r_text = me->get_text( ).
    ENDIF.

  ENDMETHOD.


  METHOD raise_text.

    RAISE EXCEPTION TYPE zcx_hddt_error
      EXPORTING
        i_text      = i_text
        i_http_code = i_http_code
        previous     = io_previous.

  ENDMETHOD.
ENDCLASS.
