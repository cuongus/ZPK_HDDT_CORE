*=====================================================================
* Tên/Mã     : ZFIR_HDDT_INT_SEL
* Mô tả chung: Selection screen cho ZFIR_HDDT_INTEGRATION.
* Tham Số    : Xem header của ZFIR_HDDT_INTEGRATION
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       28/08/2026    cuongus - CuongUS        abapGit     Tạo mới
*=====================================================================
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-b01.
  PARAMETERS     p_bukrs TYPE bukrs OBLIGATORY MEMORY ID buk.
  PARAMETERS     p_gjahr TYPE gjahr OBLIGATORY.
  SELECT-OPTIONS s_belnr FOR bkpf-belnr.
  SELECT-OPTIONS s_budat FOR bkpf-budat.
  SELECT-OPTIONS s_blart FOR bkpf-blart.
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-b02.
  PARAMETERS     p_srct  TYPE zfide_hddt_srctype OBLIGATORY DEFAULT 'FI'.
  " Để trống = lấy nhà cung cấp đang hoạt động theo cấu hình
  PARAMETERS     p_prov  TYPE zfide_hddt_prov.
  SELECT-OPTIONS s_stat  FOR gv_status.
SELECTION-SCREEN END OF BLOCK b2.

SELECTION-SCREEN BEGIN OF BLOCK b3 WITH FRAME TITLE TEXT-b03.
  PARAMETERS p_test AS CHECKBOX.
SELECTION-SCREEN END OF BLOCK b3.
