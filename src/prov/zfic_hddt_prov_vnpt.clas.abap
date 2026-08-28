*=====================================================================
* Tên/Mã     : ZFIC_HDDT_PROV_VNPT
* Mô tả chung: Adapter cho VNPT / Vinaphone Invoice.
*
*              [QUAN TRỌNG — trạng thái hoàn thiện]
*              Tại thời điểm tạo package, KHÔNG có tài liệu đặc tả API
*              của VNPT/Vinaphone trong bộ tài liệu được cung cấp
*              (chỉ có Viettel v2.44 và FPT v2.4.7). Vì vậy adapter này
*              KHÔNG hardcode cấu trúc payload — nó kế thừa
*              ZFIC_HDDT_PROV_TEMPLATE và dựng payload từ MẪU khai
*              trong bảng ZFIT_HDDT_TPL.
*              => Khi có tài liệu VNPT: chỉ cần dán mẫu payload vào
*                 ZFIT_HDDT_TPL (PROVIDER = 'VNPT', ACTION = ...),
*                 KHÔNG phải sửa dòng ABAP nào.
*              Xem docs/05-provider-vnpt.md để biết cách viết mẫu.
*
*              [Unverified] Phần bóc response bên dưới xử lý quy ước
*              text "OK:..." / "ERR:..." vốn phổ biến ở API VNPT cổ
*              điển; nếu hợp đồng dùng REST/JSON thì lớp cha đã xử lý
*              JSON sẵn, không cần sửa gì.
* Tham Số    : ZFIT_HDDT_PROV: PROVIDER='VNPT',
*              CLASSNAME='ZFIC_HDDT_PROV_VNPT'
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       28/08/2026    cuongus - CuongUS        abapGit     Tạo mới
*=====================================================================
CLASS zfic_hddt_prov_vnpt DEFINITION
  PUBLIC
  INHERITING FROM zfic_hddt_prov_template
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    CONSTANTS gc_provider TYPE zfide_hddt_prov VALUE 'VNPT' ##NO_TEXT.

    METHODS zfiif_hddt_provider~get_id         REDEFINITION .
    METHODS zfiif_hddt_provider~parse_response REDEFINITION .

  PROTECTED SECTION.
  PRIVATE SECTION.

    "! Bảng mã lỗi text của VNPT — dùng làm PROV_STATUS để ánh xạ
    "! trạng thái qua ZFIT_HDDT_STAT (không hardcode ý nghĩa ở đây).
    METHODS split_text_response
      IMPORTING iv_body   TYPE string
      EXPORTING ev_code   TYPE string
                ev_detail TYPE string
                ev_ok     TYPE abap_bool .

ENDCLASS.



CLASS zfic_hddt_prov_vnpt IMPLEMENTATION.

  METHOD zfiif_hddt_provider~get_id.

    rv_provider = gc_provider.

  ENDMETHOD.


  METHOD split_text_response.

    CLEAR: ev_code, ev_detail, ev_ok.

    DATA(lv_body) = iv_body.
    CONDENSE lv_body.
    IF lv_body IS INITIAL.
      RETURN.
    ENDIF.

    IF lv_body CS `:`.
      SPLIT lv_body AT `:` INTO ev_code ev_detail.
      CONDENSE ev_code.
      TRANSLATE ev_code TO UPPER CASE.
    ELSE.
      ev_code = lv_body.
      TRANSLATE ev_code TO UPPER CASE.
    ENDIF.

    ev_ok = xsdbool( ev_code = 'OK' ).

    " Mã lỗi dạng ERR:<n> -> dùng 'ERR<n>' làm RC_CODE cho bảng ánh xạ
    IF ev_code = 'ERR'.
      DATA(lv_num) = ev_detail.
      CONDENSE lv_num NO-GAPS.
      ev_code = |ERR{ lv_num }|.
    ENDIF.

  ENDMETHOD.


  METHOD zfiif_hddt_provider~parse_response.

    DATA(lv_body) = iv_body.
    CONDENSE lv_body.

    " JSON / XML -> để lớp cha (template adapter) xử lý
    IF lv_body IS INITIAL
       OR substring( val = lv_body len = 1 ) = `{`
       OR substring( val = lv_body len = 1 ) = `[`
       OR substring( val = lv_body len = 1 ) = `<`.
      super->zfiif_hddt_provider~parse_response(
        EXPORTING is_request   = is_request
                  iv_action    = iv_action
                  iv_http_code = iv_http_code
                  iv_body      = iv_body
        CHANGING  cs_result    = cs_result ).
      RETURN.
    ENDIF.

    " Quy ước text "OK:<pattern>;<serial>-<seq>" / "ERR:<n>"
    split_text_response( EXPORTING iv_body   = lv_body
                         IMPORTING ev_code   = DATA(lv_code)
                                   ev_detail = DATA(lv_detail)
                                   ev_ok     = DATA(lv_ok) ).

    cs_result-prov_status = lv_code.
    cs_result-success     = xsdbool( lv_ok = abap_true
                                 AND iv_http_code >= 200
                                 AND iv_http_code < 300 ).
    cs_result-message     = substring( val = lv_body
                                       len = nmin( val1 = 255
                                                   val2 = strlen( lv_body ) ) ).

    IF lv_ok = abap_false OR lv_detail IS INITIAL.
      RETURN.
    ENDIF.

    " <pattern>;<serial>-<seq>
    DATA lv_rest TYPE string.
    IF lv_detail CS `;`.
      SPLIT lv_detail AT `;` INTO DATA(lv_pattern) lv_rest.
      cs_result-template = lv_pattern.
    ELSE.
      lv_rest = lv_detail.
    ENDIF.

    IF lv_rest CS `-`.
      SPLIT lv_rest AT `-` INTO DATA(lv_serial) DATA(lv_seq).
      cs_result-serial = lv_serial.
      cs_result-seq    = lv_seq.
    ELSE.
      cs_result-seq = lv_rest.
    ENDIF.

    CONDENSE cs_result-template NO-GAPS.
    CONDENSE cs_result-serial NO-GAPS.
    CONDENSE cs_result-seq NO-GAPS.

  ENDMETHOD.

ENDCLASS.
