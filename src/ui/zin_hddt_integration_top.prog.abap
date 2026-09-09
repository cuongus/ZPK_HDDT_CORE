*=====================================================================
* Tên/Mã     : ZIN_HDDT_INTEGRATION_TOP
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
* 1.3       09/09/2026    cuongus - CuongUS        abapGit     Cột EXPAND
*                         và cấu trúc dòng hàng cho popup chi tiết
* 1.4       09/09/2026    cuongus - CuongUS        abapGit     Màn hình
*                         0200 xem trước chứng từ gom trước khi lưu
*=====================================================================
TYPE-POOLS icon.

TABLES: bkpf, bseg, ztb_hddt_inv.

*---------------------------------------------------------------------*
* Dòng hiển thị trên ALV (FS mục 3.5)
*---------------------------------------------------------------------*
TYPES: BEGIN OF gty_alv,
         expand      TYPE c LENGTH 4,   " icon mở rộng -> popup dòng hàng
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

"! Kiểu CÓ TÊN cho tham số method của lớp local: tham số method không
"! nhận kiểu dựng sẵn dạng "TYPE c LENGTH n", ADT báo "A RETURNING
"! parameter must be fully typed".
TYPES gty_icon    TYPE c LENGTH 4.
TYPES gty_sttext  TYPE c LENGTH 60.
TYPES gty_adjcode TYPE c LENGTH 1.
TYPES gty_ittext  TYPE c LENGTH 30.

*---------------------------------------------------------------------*
* Nhãn cột dùng chung cho field catalog của grid và cột của SALV
*---------------------------------------------------------------------*
" flag: I = cột icon · H = cột bấm được · B = icon bấm được
"       · T = cột kỹ thuật, ẩn
TYPES: BEGIN OF gty_col,
         field  TYPE lvc_fname,
         short  TYPE scrtext_s,
         medium TYPE scrtext_m,
         flag   TYPE gty_adjcode,
       END OF gty_col.
TYPES gty_t_col TYPE STANDARD TABLE OF gty_col WITH DEFAULT KEY.

*---------------------------------------------------------------------*
* Dòng hàng hiển thị trong popup khi bấm icon mở rộng
*---------------------------------------------------------------------*
" ZIF_HDDT_TYPES=>TY_ITEM có cột kiểu STRING mà ALV không hiển thị được,
" nên popup dùng cấu trúc phẳng theo data element của package.
TYPES: BEGIN OF gty_item_alv,
         src_docno  TYPE zde_hddt_docno,
         line_no    TYPE zde_hddt_lineno,
         item_type  TYPE zde_hddt_itemtype,
         type_txt   TYPE gty_ittext,
         item_code  TYPE c LENGTH 40,
         item_name  TYPE c LENGTH 250,
         unit       TYPE c LENGTH 20,
         quantity   TYPE zde_hddt_qty,
         price      TYPE zde_hddt_amount,
         amount     TYPE zde_hddt_amount,
         tax_txt    TYPE c LENGTH 10,
         tax_amount TYPE zde_hddt_amount,
         total      TYPE zde_hddt_amount,
         disc_pct   TYPE zde_hddt_rate,
         disc_amt   TYPE zde_hddt_amount,
         note       TYPE c LENGTH 250,
       END OF gty_item_alv.
TYPES gty_t_item_alv TYPE STANDARD TABLE OF gty_item_alv WITH EMPTY KEY.

*---------------------------------------------------------------------*
* Màn hình 0200 — xem trước chứng từ gom rồi mới lưu
*---------------------------------------------------------------------*
" Các field này đặt trên dynpro 0200 (SE51: Goto -> Dict./Program
" fields -> GS_GOM_H). Tất cả chỉ để xem, trừ ngày/giờ phát hành
" được sửa qua nút riêng.
TYPES: BEGIN OF gty_gom_head,
         src_docno  TYPE zde_hddt_docno,   " số gom, cấp khi lưu
         cnt_doc    TYPE i,                " số chứng từ thành viên
         bukrs      TYPE bukrs,
         gjahr      TYPE gjahr,
         bldat      TYPE dats,
         budat      TYPE dats,
         buyer_code TYPE kunnr,
         buyer_name TYPE c LENGTH 120,
         waers      TYPE waers,
         amount     TYPE zde_hddt_amount,
         vat_amount TYPE zde_hddt_amount,
         total      TYPE zde_hddt_amount,
         inv_date   TYPE dats,
         inv_time   TYPE uzeit,
       END OF gty_gom_head.

DATA gs_gom_h    TYPE gty_gom_head.
DATA gt_gom_item TYPE gty_t_item_alv.
DATA gt_gom_req  TYPE zif_hddt_types=>ty_t_request.
DATA gv_gom_text TYPE zde_hddt_name.
DATA gv_gom_edit TYPE abap_bool.

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

" GUI status của dynpro 0100 chứa ALV grid. Chỉ cần Back / Exit /
" Cancel: 12 nút nghiệp vụ do event TOOLBAR của grid tự thêm.
CONSTANTS gc_pfstatus TYPE sypfkey VALUE 'ZGRID_HDDT' ##NO_TEXT.
CONSTANTS gc_dynnr    TYPE sydynnr VALUE '0100' ##NO_TEXT.

" Dynpro 0200: header GS_GOM_H + custom control CC_ITEM chứa ALV
" dòng hàng. GUI status ZGOM_HDDT cần SAVE / ZEDIT / BACK / CANC.
CONSTANTS gc_dynnr_gom  TYPE sydynnr VALUE '0200' ##NO_TEXT.
CONSTANTS gc_pfstat_gom TYPE sypfkey VALUE 'ZGOM_HDDT' ##NO_TEXT.
CONSTANTS gc_cc_item    TYPE scrfname VALUE 'CC_ITEM' ##NO_TEXT.

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
