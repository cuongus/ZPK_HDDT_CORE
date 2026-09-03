*=====================================================================
* Tên/Mã     : ZFIR_HDDT_INT_SEL
* Mô tả chung: Selection screen cho ZFIR_HDDT_INTEGRATION.
* Tham Số    : Xem header của ZFIR_HDDT_INTEGRATION
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       28/08/2026    cuongus - CuongUS        abapGit     Tạo mới
* 1.1       03/09/2026    cuongus - CuongUS        abapGit     Thêm BLDAT,
*                         VBELN, KUNNR, USNAM, cờ lấy CT đã đảo
*=====================================================================
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-b01.
  PARAMETERS     p_bukrs TYPE bukrs OBLIGATORY MEMORY ID buk.
  PARAMETERS     p_gjahr TYPE gjahr OBLIGATORY.
  SELECT-OPTIONS s_belnr FOR bkpf-belnr.
  SELECT-OPTIONS s_budat FOR bkpf-budat.
  SELECT-OPTIONS s_bldat FOR bkpf-bldat.
  SELECT-OPTIONS s_blart FOR bkpf-blart.
  " Số billing SD (BKPF-AWKEY khi nguồn FI, VBRK-VBELN khi nguồn SD)
  SELECT-OPTIONS s_vbeln FOR bkpf-awkey.
  SELECT-OPTIONS s_kunnr FOR bseg-kunnr.
  SELECT-OPTIONS s_usnam FOR bkpf-usnam.
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-b02.
  PARAMETERS     p_srct  TYPE zfide_hddt_srctype OBLIGATORY DEFAULT 'FI'.
  " Để trống = lấy nhà cung cấp đang hoạt động theo cấu hình
  PARAMETERS     p_prov  TYPE zfide_hddt_prov.
  SELECT-OPTIONS s_stat  FOR gv_status.
  " Mặc định chứng từ đã đảo chỉ hiện khi đã có số HĐĐT (để huỷ)
  PARAMETERS     p_rever AS CHECKBOX.
SELECTION-SCREEN END OF BLOCK b2.

SELECTION-SCREEN BEGIN OF BLOCK b3 WITH FRAME TITLE TEXT-b03.
  PARAMETERS p_test AS CHECKBOX.
SELECTION-SCREEN END OF BLOCK b3.
