*=====================================================================
* Tên/Mã     : ZPG_HDDT_INTEGRATION_TOP
* Mô tả chung: Khai báo dữ liệu + màn hình chọn cho ZPG_HDDT_INTEGRATION
*              (gộp include _SEL cũ theo chuẩn include _TOP/_F01).
* Tham Số    : Không có (include khai báo)
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       28/08/2026    cuongus - CuongUS        abapGit     Tạo mới
* 1.1       03/09/2026    cuongus - CuongUS        abapGit     Cột BLART/
*                         BLDAT/AWKEY/đảo/HĐ gốc/thuế suất
*=====================================================================
TYPE-POOLS icon.

TABLES: bkpf, bseg.

*---------------------------------------------------------------------*
* Dòng hiển thị trên ALV
*---------------------------------------------------------------------*
TYPES: BEGIN OF gty_alv,
         light      TYPE c LENGTH 4,   " đèn trạng thái
         bukrs      TYPE bukrs,
         gjahr      TYPE gjahr,
         src_type   TYPE zde_hddt_srctype,
         src_docno  TYPE zde_hddt_docno,
         blart      TYPE blart,
         budat      TYPE dats,
         bldat      TYPE dats,
         awkey      TYPE awkey,           " số billing SD tham chiếu
         reversed   TYPE c LENGTH 4,      " icon: CT đã đảo / billing đã huỷ
         inv_date   TYPE dats,
         buyer_code TYPE kunnr,
         buyer_name TYPE c LENGTH 120,
         buyer_tax  TYPE zde_hddt_taxcode,
         waers      TYPE waers,
         amount     TYPE zde_hddt_amount,
         vat_amount TYPE zde_hddt_amount,
         total      TYPE zde_hddt_amount,
         provider   TYPE zde_hddt_prov,
         inv_type   TYPE zde_hddt_invtype,
         template   TYPE zde_hddt_templ,
         serial     TYPE zde_hddt_serial,
         seq        TYPE zde_hddt_seq,
         issue_date TYPE dats,
         mscqt      TYPE zde_hddt_mscqt,
         sec_code   TYPE zde_hddt_sec,
         inv_link   TYPE zde_hddt_link,
         ref_docno  TYPE zde_hddt_docno, " chứng từ HĐ gốc (điều chỉnh/thay thế)
         tax_summ   TYPE c LENGTH 20,     " thuế suất: 10% / Nhiều loại
         status     TYPE zde_hddt_status,
         status_txt TYPE c LENGTH 60,
         msgty      TYPE symsgty,
         message    TYPE zde_hddt_msg,
         log_id     TYPE zde_hddt_logid,
       END OF gty_alv.
TYPES gty_t_alv TYPE STANDARD TABLE OF gty_alv WITH EMPTY KEY.

DATA gt_alv     TYPE gty_t_alv.
DATA gt_request TYPE zif_hddt_types=>ty_t_request.

" Dùng cho SELECT-OPTIONS trên trạng thái HĐĐT (không có bảng nguồn)
DATA gv_status  TYPE zde_hddt_status.

*---------------------------------------------------------------------*
* Mã chức năng tự thêm vào thanh công cụ ALV
*---------------------------------------------------------------------*
CONSTANTS: BEGIN OF gc_fcode,
             issue   TYPE salv_de_function VALUE 'ZISSUE',
             adjust  TYPE salv_de_function VALUE 'ZADJUST',
             replace TYPE salv_de_function VALUE 'ZREPLACE',
             cancel  TYPE salv_de_function VALUE 'ZCANCEL',
             search  TYPE salv_de_function VALUE 'ZSEARCH',
             getfile TYPE salv_de_function VALUE 'ZFILE',
             showjs  TYPE salv_de_function VALUE 'ZJSON',
             showlog TYPE salv_de_function VALUE 'ZLOG',
           END OF gc_fcode.

*---------------------------------------------------------------------*
* Biến toàn cục nhận giá trị từ CL_GUI_FRONTEND_SERVICES (quy ước:
* không dùng biến cục bộ — bẫy SYSTEM_POINTER_PENDING)
*---------------------------------------------------------------------*
DATA gv_file_name   TYPE string.
DATA gv_file_path   TYPE string.
DATA gv_file_full   TYPE string.
DATA gv_file_action TYPE i.

*---------------------------------------------------------------------*
* Màn hình chọn
*---------------------------------------------------------------------*
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
  PARAMETERS     p_srct  TYPE zde_hddt_srctype OBLIGATORY DEFAULT 'FI'.
  " Để trống = lấy nhà cung cấp đang hoạt động theo cấu hình
  PARAMETERS     p_prov  TYPE zde_hddt_prov.
  SELECT-OPTIONS s_stat  FOR gv_status.
  " Mặc định chứng từ đã đảo chỉ hiện khi đã có số HĐĐT (để huỷ)
  PARAMETERS     p_rever AS CHECKBOX.
SELECTION-SCREEN END OF BLOCK b2.

SELECTION-SCREEN BEGIN OF BLOCK b3 WITH FRAME TITLE TEXT-b03.
  PARAMETERS p_test AS CHECKBOX.
SELECTION-SCREEN END OF BLOCK b3.
