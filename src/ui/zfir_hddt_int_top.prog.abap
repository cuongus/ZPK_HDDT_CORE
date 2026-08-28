*=====================================================================
* Tên/Mã     : ZFIR_HDDT_INT_TOP
* Mô tả chung: Khai báo dữ liệu cho ZFIR_HDDT_INTEGRATION.
* Tham Số    : Không có (include khai báo)
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       28/08/2026    cuongus - CuongUS        abapGit     Tạo mới
*=====================================================================
TYPE-POOLS icon.

TABLES bkpf.

*---------------------------------------------------------------------*
* Dòng hiển thị trên ALV
*---------------------------------------------------------------------*
TYPES: BEGIN OF gty_alv,
         light      TYPE c LENGTH 4,   " đèn trạng thái
         bukrs      TYPE bukrs,
         gjahr      TYPE gjahr,
         src_type   TYPE zfide_hddt_srctype,
         src_docno  TYPE zfide_hddt_docno,
         budat      TYPE dats,
         buyer_code TYPE kunnr,
         buyer_name TYPE c LENGTH 120,
         buyer_tax  TYPE zfide_hddt_taxcode,
         waers      TYPE waers,
         amount     TYPE zfide_hddt_amount,
         vat_amount TYPE zfide_hddt_amount,
         total      TYPE zfide_hddt_amount,
         provider   TYPE zfide_hddt_prov,
         inv_type   TYPE zfide_hddt_invtype,
         template   TYPE zfide_hddt_templ,
         serial     TYPE zfide_hddt_serial,
         seq        TYPE zfide_hddt_seq,
         issue_date TYPE dats,
         mscqt      TYPE zfide_hddt_mscqt,
         sec_code   TYPE zfide_hddt_sec,
         inv_link   TYPE zfide_hddt_link,
         status     TYPE zfide_hddt_status,
         status_txt TYPE c LENGTH 60,
         msgty      TYPE symsgty,
         message    TYPE zfide_hddt_msg,
         log_id     TYPE zfide_hddt_logid,
       END OF gty_alv.
TYPES gty_t_alv TYPE STANDARD TABLE OF gty_alv WITH EMPTY KEY.

DATA gt_alv     TYPE gty_t_alv.
DATA gt_request TYPE zfiif_hddt_types=>ty_t_request.

" Dùng cho SELECT-OPTIONS trên trạng thái HĐĐT (không có bảng nguồn)
DATA gv_status  TYPE zfide_hddt_status.

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
