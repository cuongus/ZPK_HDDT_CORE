*=====================================================================
* Tên/Mã     : ZPG_HDDT_INTEGRATION_TOP
* Mô tả chung: Khai báo dữ liệu + màn hình chọn cho ZPG_HDDT_INTEGRATION
*              (gộp include _SEL cũ theo chuẩn include _TOP/_F01).
*              Tham số lọc và cột ALV theo FS MAG_SAP_2026_PM_FS_Tich
*              hop HDDT v0.5 (mục 3.3, 3.5).
* Tham Số    : Không có (include khai báo)
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       28/08/2026    cuongus - CuongUS        abapGit     Tạo mới
* 1.1       03/09/2026    cuongus - CuongUS        abapGit     Cột BLART/
*                         BLDAT/AWKEY/đảo/HĐ gốc/thuế suất
* 1.2       07/09/2026    cuongus - CuongUS        abapGit     FS MAG v0.5:
*                         tham số CPUDT/SEQ/GOM/loại HĐ/phát hành tự
*                         động; cột email, tên hàng, gom, loại ĐC, mail
*=====================================================================
TYPE-POOLS icon.

TABLES: bkpf, bseg, ztb_hddt_inv.

*---------------------------------------------------------------------*
* Dòng hiển thị trên ALV (FS mục 3.5)
*---------------------------------------------------------------------*
TYPES: BEGIN OF gty_alv,
         light       TYPE c LENGTH 4,   " đèn trạng thái HĐĐT
         mail_light  TYPE c LENGTH 4,   " icon trạng thái email
         bukrs       TYPE bukrs,
         gjahr       TYPE gjahr,
         src_type    TYPE zde_hddt_srctype,
         src_docno   TYPE zde_hddt_docno,
         gom_no      TYPE zde_hddt_docno, " số FI gom
         blart       TYPE blart,
         budat       TYPE dats,
         bldat       TYPE dats,
         awkey       TYPE awkey,          " số billing SD tham chiếu
         reversed    TYPE c LENGTH 4,     " icon: CT đã đảo / billing đã huỷ
         inv_date    TYPE dats,           " ngày phát hành (sửa được)
         inv_time    TYPE uzeit,          " giờ phát hành (sửa được)
         buyer_code  TYPE kunnr,
         buyer_name  TYPE c LENGTH 120,
         buyer_addr  TYPE zde_hddt_name,
         buyer_tax   TYPE zde_hddt_taxcode,
         buyer_mail  TYPE zde_hddt_name,
         item_text   TYPE zde_hddt_name,  " tên hàng nhập tay (ưu tiên 1)
         paym        TYPE c LENGTH 30,
         waers       TYPE waers,
         exch_rate   TYPE zde_hddt_amount,
         amount      TYPE zde_hddt_amount,
         vat_amount  TYPE zde_hddt_amount,
         total       TYPE zde_hddt_amount,
         tax_summ    TYPE c LENGTH 20,    " thuế suất: 10% / Nhiều loại
         provider    TYPE zde_hddt_prov,
         inv_type    TYPE zde_hddt_invtype,
         template    TYPE zde_hddt_templ,
         serial      TYPE zde_hddt_serial,
         seq         TYPE zde_hddt_seq,
         issue_date  TYPE dats,           " ngày tích hợp (phát hành thành công)
         mscqt       TYPE zde_hddt_mscqt,
         sec_code    TYPE zde_hddt_sec,
         inv_link    TYPE zde_hddt_link,
         adj_code    TYPE c LENGTH 1,     " loại ĐC theo FS: 2/3/4/5
         ref_docno   TYPE zde_hddt_docno, " số chứng từ gốc
         ref_gjahr   TYPE gjahr,          " năm chứng từ gốc
         status      TYPE zde_hddt_status,
         status_txt  TYPE c LENGTH 60,
         tax_status  TYPE zde_hddt_rccode, " status_received của CQT
         msgty       TYPE symsgty,
         message     TYPE zde_hddt_msg,
         log_id      TYPE zde_hddt_logid,
       END OF gty_alv.
TYPES gty_t_alv TYPE STANDARD TABLE OF gty_alv WITH EMPTY KEY.

DATA gt_alv     TYPE gty_t_alv.
DATA gt_request TYPE zif_hddt_types=>ty_t_request.

"! Danh sách loại nguồn dữ liệu đã cấu hình (ZTB_HDDT_SRC)
TYPES gty_t_srctype TYPE STANDARD TABLE OF zde_hddt_srctype WITH EMPTY KEY.

" Dùng cho SELECT-OPTIONS trên trạng thái HĐĐT và loại nguồn (không có
" bảng nguồn để tham chiếu)
DATA gv_srctype TYPE zde_hddt_srctype.
DATA gv_status  TYPE zde_hddt_status.

*---------------------------------------------------------------------*
* Mã chức năng trên thanh công cụ ALV — 8 nút theo FS mục 3.6 + tiện ích
*---------------------------------------------------------------------*
CONSTANTS: BEGIN OF gc_fcode,
             draft   TYPE salv_de_function VALUE 'ZDRAFT',   " Tích hợp HĐ (nháp)
             deldrf  TYPE salv_de_function VALUE 'ZDELDRF',  " Hủy HĐ nháp
             issue   TYPE salv_de_function VALUE 'ZISSUE',   " Phát hành HĐ
             update  TYPE salv_de_function VALUE 'ZUPDATE',  " Cập nhật HĐ
             adjref  TYPE salv_de_function VALUE 'ZADJREF',  " HĐ Điều chỉnh (gắn HĐ gốc)
             mail    TYPE salv_de_function VALUE 'ZMAIL',    " Send Email
             gom     TYPE salv_de_function VALUE 'ZGOM',     " Gom HĐ
             ungom   TYPE salv_de_function VALUE 'ZUNGOM',   " Huỷ Gom HĐ
             edit    TYPE salv_de_function VALUE 'ZEDIT',    " Sửa ngày/giờ/tên hàng
             getfile TYPE salv_de_function VALUE 'ZFILE',    " Lấy file PDF/XML
             showjs  TYPE salv_de_function VALUE 'ZJSON',    " Xem payload
             showlog TYPE salv_de_function VALUE 'ZLOG',     " Log
           END OF gc_fcode.

" Hoạt động (ACTVT) kiểm quyền theo chức năng — object khai ở tham số
" AUTH_OBJECT (trống = không kiểm), field BUKRS + ACTVT
CONSTANTS: BEGIN OF gc_actvt,
             create  TYPE activ_auth VALUE '01',   " tạo / huỷ nháp
             change  TYPE activ_auth VALUE '02',   " phát hành, điều chỉnh, gom
             display TYPE activ_auth VALUE '03',   " xem, tra cứu, email, file
           END OF gc_actvt.

*---------------------------------------------------------------------*
* Biến toàn cục nhận giá trị từ CL_GUI_FRONTEND_SERVICES (quy ước:
* không dùng biến cục bộ — bẫy SYSTEM_POINTER_PENDING)
*---------------------------------------------------------------------*
DATA gv_file_name   TYPE string.
DATA gv_file_path   TYPE string.
DATA gv_file_full   TYPE string.
DATA gv_file_action TYPE i.

*---------------------------------------------------------------------*
* Màn hình chọn (FS mục 3.3)
*---------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-b01.
  PARAMETERS     p_bukrs TYPE bukrs OBLIGATORY MEMORY ID buk.
  PARAMETERS     p_gjahr TYPE gjahr OBLIGATORY.
  SELECT-OPTIONS s_belnr FOR bkpf-belnr.
  SELECT-OPTIONS s_budat FOR bkpf-budat.
  SELECT-OPTIONS s_bldat FOR bkpf-bldat.
  SELECT-OPTIONS s_cpudt FOR bkpf-cpudt.
  SELECT-OPTIONS s_blart FOR bkpf-blart.
  " Số billing SD (BKPF-AWKEY khi nguồn FI, VBRK-VBELN khi nguồn SD)
  SELECT-OPTIONS s_vbeln FOR bkpf-awkey.
  SELECT-OPTIONS s_kunnr FOR bseg-kunnr.
  SELECT-OPTIONS s_usnam FOR bkpf-usnam.
  SELECT-OPTIONS s_seq   FOR ztb_hddt_inv-seq.
  SELECT-OPTIONS s_gom   FOR ztb_hddt_inv-gom_no.
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-b02.
  " Để trống = lấy mọi loại nguồn đã cấu hình cho công ty; chọn nhiều
  " loại để xem chung, cần cho nghiệp vụ gom nhiều loại chứng từ
  SELECT-OPTIONS s_srct  FOR gv_srctype.
  " Để trống = lấy nhà cung cấp đang hoạt động theo cấu hình
  PARAMETERS     p_prov  TYPE zde_hddt_prov.
  " Mẫu hoá đơn phát hành (01GTKT...) — trống = dòng mặc định ZTB_HDDT_CRED
  PARAMETERS     p_ityp  TYPE zde_hddt_invtype.
  SELECT-OPTIONS s_stat  FOR gv_status.
  " Mặc định chứng từ đã đảo chỉ hiện khi đã có số HĐĐT (để huỷ)
  PARAMETERS     p_rever AS CHECKBOX.
SELECTION-SCREEN END OF BLOCK b2.

SELECTION-SCREEN BEGIN OF BLOCK b3 WITH FRAME TITLE TEXT-b03.
  PARAMETERS p_test AS CHECKBOX.
  " FS 3.3 STT 15: chỉ có tác dụng khi chạy background job; mặc định KHÔNG tích
  PARAMETERS p_auto AS CHECKBOX.
SELECTION-SCREEN END OF BLOCK b3.
