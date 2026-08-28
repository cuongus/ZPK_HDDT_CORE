*=====================================================================
* Tên/Mã     : ZFIR_HDDT_INT_EVT
* Mô tả chung: Sự kiện của ZFIR_HDDT_INTEGRATION.
* Tham Số    : Không có
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       28/08/2026    cuongus - CuongUS        abapGit     Tạo mới
*=====================================================================
INITIALIZATION.
  p_gjahr = sy-datum(4).

AT SELECTION-SCREEN ON p_bukrs.
  " Không cho phát hành hoá đơn của công ty người dùng không có quyền
  AUTHORITY-CHECK OBJECT 'F_BKPF_BUK'
    ID 'BUKRS' FIELD p_bukrs
    ID 'ACTVT' FIELD '03'.
  IF sy-subrc <> 0.
    MESSAGE e004(zfie_hddt) WITH p_bukrs.
  ENDIF.

AT SELECTION-SCREEN ON p_prov.
  IF p_prov IS INITIAL.
    RETURN.
  ENDIF.
  SELECT SINGLE @abap_true FROM zfit_hddt_prov
    INTO @DATA(lv_exists)
    WHERE provider = @p_prov
      AND xactive  = @abap_true.
  IF lv_exists <> abap_true.
    MESSAGE e005(zfie_hddt) WITH p_prov.
  ENDIF.

START-OF-SELECTION.
  DATA(go_app) = NEW lcl_app( ).
  go_app->run( ).
