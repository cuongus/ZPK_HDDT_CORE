*=====================================================================
* Tên/Mã     : ZCL_HDDT_SRC_BASE
* Mô tả chung: Lớp cha DÙNG CHUNG cho các lớp đọc dữ liệu nguồn
*              (FI, SD...). Chứa phần nghiệp vụ đã được kiểm chứng ở
*              dự án HĐĐT private cloud (ZPG_INT_E_INVOICE +
*              FUGR ZFG_E_INVOICES: ZFM_GET_BUYER / ZFM_GET_SELLER /
*              ZFM_GET_ITEMDOC) nhưng viết lại theo canonical model
*              và điều khiển bằng cấu hình thay cho hằng số:
*                - Người bán  : T001 -> ADRC/ADR6 (cache theo BUKRS)
*                - Người mua  : khách lẻ BSEC, hoặc BP qua CVI_CUST_LINK
*                               -> BUT000/BUT020/ADRC/BUT0ID/ADR6/ADR2/
*                               BUT0BK/BNKA; fallback KNA1 (cache KUNNR)
*                - Thuế suất  : MAP TAXRATE -> BSET-KBETR -> A003/KONP
*                - Tiền thuế  : tính theo % từng dòng rồi CHỐT theo
*                               bảng thuế (BSET) — chênh lệch làm tròn
*                               dồn vào dòng cuối cùng cùng thuế suất
*                - Tên hàng   : long text theo cấu hình ITEM_TEXT_IDS
*                               -> MAKT -> SGTXT/ARKTX
*              Lớp này thuộc TẦNG NỀN TẢNG CỔ ĐIỂN (đọc bảng SAP trực
*              tiếp, READ_TEXT). Bản Public Cloud khai báo lớp nguồn
*              riêng trong ZTB_HDDT_SRC — engine không đổi.
* Tham Số    : Xem từng method
*=====================================================================
* Version   Ngày          Người sửa                Transport   Mô tả
*=====================================================================
* 1.0       03/09/2026    cuongus - CuongUS        abapGit     Tạo mới
* 1.1       27/09/2026    F-DUBV                   S25K900131  R06: them
*                         PREFETCH_SELLER / PREFETCH_MAT_TEXTS /
*                         PREFETCH_BUYER_DOCS (T001-ADRC-ADR6, MAKT, BSEC-
*                         BNKA, VBKD doc 1 lan truoc vong lap); sua bo dem
*                         MT_BUYER theo KUNNR + BVTYP (review S25 27/09)
* 1.2       28/09/2026    F-DUBV                   S25K900131  R06: them
*                         PREFETCH_BUYER_MASTER (CVI_CUST_LINK, BUT000,
*                         BUT020, ADRC, ADR6, ADR2, BUT0ID, KNA1, BUT0BK,
*                         BNKA doc 1 lan truoc vong lap); BUYER_FROM_BP /
*                         BUYER_FROM_KNA1 chi doc bo dem (review S25 28/09)
* 1.3       30/09/2026    cuongus - CuongUS        DS4K900172  20260930_01 Kiem
*                         chung DS4: quy doi so tien theo TCURX (VND
*                         luu chia 100), ty gia theo TCURF (1:1000)
*=====================================================================
CLASS zcl_hddt_src_base DEFINITION
  PUBLIC
  ABSTRACT
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES zif_hddt_source
      ABSTRACT METHODS select_documents get_doc_state .

  PROTECTED SECTION.

    "! Thuế suất theo mã thuế đọc từ bảng thuế của chứng từ
    TYPES: BEGIN OF ty_mwskz_rate,
             mwskz TYPE mwskz,
             kbetr TYPE kbetr,
           END OF ty_mwskz_rate.
    TYPES ty_t_mwskz_rate TYPE SORTED TABLE OF ty_mwskz_rate
                          WITH UNIQUE KEY mwskz.

    TYPES ty_t_reg TYPE SORTED TABLE OF ztb_hddt_inv
                   WITH UNIQUE KEY bukrs gjahr src_type src_docno.

    "! Bản ghi sổ đăng ký của các chứng từ trong phạm vi chọn
    DATA mt_reg TYPE ty_t_reg .

    METHODS config
      RETURNING VALUE(ro_config) TYPE REF TO zcl_hddt_config .

    "! Tham số cấu hình có giá trị mặc định
    METHODS param
      IMPORTING i_key          TYPE zde_hddt_parmkey
                i_bukrs        TYPE bukrs
                i_default      TYPE string OPTIONAL
      RETURNING VALUE(r_value) TYPE string .

    "! Đọc sổ đăng ký HĐĐT của công ty/năm/loại nguồn vào MT_REG
    METHODS load_registry
      IMPORTING i_bukrs    TYPE bukrs
                i_gjahr    TYPE gjahr
                i_src_type TYPE zde_hddt_srctype .

    METHODS registry_of
      IMPORTING i_bukrs       TYPE bukrs
                i_gjahr       TYPE gjahr
                i_src_type    TYPE zde_hddt_srctype
                i_docno       TYPE zde_hddt_docno
      RETURNING VALUE(rs_reg) TYPE ztb_hddt_inv .

    "! Chứng từ có được đưa vào danh sách không:
    "!   - đã đảo/huỷ: chỉ khi đã phát hành HĐĐT (để huỷ) hoặc người
    "!     dùng yêu cầu lấy cả chứng từ đã đảo
    "!   - lọc theo range trạng thái
    "! FS MAG: áp giá trị người dùng đã sửa trên màn hình (ngày/giờ phát
    "! hành, tên hàng) và giờ mặc định INV_TIME_DEFAULT vào request.
    METHODS apply_registry_edits
      IMPORTING is_reg     TYPE ztb_hddt_inv
      CHANGING  cs_request TYPE zif_hddt_types=>ty_request .

    METHODS keep_document
      IMPORTING i_reversed    TYPE abap_bool
                is_reg        TYPE ztb_hddt_inv
                is_selection  TYPE zif_hddt_source=>ty_selection
      RETURNING VALUE(r_keep) TYPE abap_bool .

    "! ---- Người bán / người mua ----
    METHODS read_seller
      IMPORTING i_bukrs          TYPE bukrs
      RETURNING VALUE(rs_seller) TYPE zif_hddt_types=>ty_seller .

    "! Người mua. Truyền BELNR/GJAHR để nhận diện khách lẻ (BSEC);
    "! BVTYP để lấy ngân hàng; AUBEL để lấy số tham chiếu KH (VBKD).
    METHODS read_buyer
      IMPORTING i_kunnr         TYPE kunnr
                i_bukrs         TYPE bukrs
                i_belnr         TYPE belnr_d OPTIONAL
                i_gjahr         TYPE gjahr OPTIONAL
                i_bvtyp         TYPE bvtyp OPTIONAL
                i_aubel         TYPE vbeln OPTIONAL
      RETURNING VALUE(rs_buyer) TYPE zif_hddt_types=>ty_buyer .

    "! Nhà cung cấp làm NGƯỜI MUA trên hoá đơn đầu vào trả lại hàng (FS
    "! v0.17 mục 3.3 Nhóm 2). Tên / mã số thuế / địa chỉ lấy từ LFA1 (kèm
    "! ADRC / ADR6 khi có địa chỉ quản lý tập trung), đối xứng với cách
    "! đọc khách hàng. NCC vãng lai lấy từ BSEC như khách lẻ.
    METHODS read_vendor
      IMPORTING i_lifnr         TYPE lifnr
                i_bukrs         TYPE bukrs
                i_belnr         TYPE belnr_d OPTIONAL
                i_gjahr         TYPE gjahr OPTIONAL
      RETURNING VALUE(rs_buyer) TYPE zif_hddt_types=>ty_buyer .

    METHODS clean_address
      IMPORTING i_land1 TYPE land1 OPTIONAL
                i_bukrs TYPE bukrs OPTIONAL
      CHANGING  c_addr  TYPE string .

    "! ---- Thuế ----
    "! Thuế suất theo mã thuế: MAP TAXRATE -> bảng thuế chứng từ
    "! (KBETR/10) -> điều kiện thuế A003/KONP (loại điều kiện TAX_COND_TYPE)
    METHODS tax_rate_of
      IMPORTING i_bukrs       TYPE bukrs
                i_mwskz       TYPE mwskz
                it_rate       TYPE ty_t_mwskz_rate OPTIONAL
      RETURNING VALUE(r_rate) TYPE zif_hddt_types=>ty_rate .

    METHODS rate_text
      IMPORTING i_rate        TYPE zif_hddt_types=>ty_rate
      RETURNING VALUE(r_text) TYPE string .

    "! Tiền thuế một dòng — làm tròn theo tiền tệ (VND: 0 lẻ)
    METHODS line_tax
      IMPORTING i_amount     TYPE zif_hddt_types=>ty_amount
                i_rate       TYPE zif_hddt_types=>ty_rate
                i_waers      TYPE waers
      RETURNING VALUE(r_tax) TYPE zif_hddt_types=>ty_amount .

    "! Chốt tiền thuế từng dòng theo bảng thuế: chênh lệch làm tròn dồn
    "! vào DÒNG CUỐI cùng thuế suất (đúng như dự án tham chiếu).
    METHODS reconcile_tax
      IMPORTING it_tax   TYPE zif_hddt_types=>ty_t_tax
      CHANGING  ct_items TYPE zif_hddt_types=>ty_t_item .

    "! 'Nhiều loại' nếu hoá đơn có nhiều thuế suất, ngược lại nhãn
    METHODS rate_summary
      IMPORTING it_items      TYPE zif_hddt_types=>ty_t_item
      RETURNING VALUE(r_text) TYPE string .

    "! ---- Dòng hàng ----
    METHODS unit_text
      IMPORTING i_meins       TYPE meins
      RETURNING VALUE(r_text) TYPE string .

    METHODS material_text
      IMPORTING i_matnr       TYPE matnr
      RETURNING VALUE(r_text) TYPE string .

    "! Tên hàng theo thứ tự ưu tiên cấu hình ITEM_TEXT_IDS
    "! (dạng 'ID:OBJECT;ID:OBJECT', xem docs/09) -> MAKT -> I_DEFAULT
    METHODS item_name
      IMPORTING i_bukrs       TYPE bukrs
                i_vbeln       TYPE vbeln OPTIONAL
                i_posnr       TYPE posnr OPTIONAL
                i_matnr       TYPE matnr OPTIONAL
                i_default     TYPE clike OPTIONAL
      RETURNING VALUE(r_name) TYPE string .

    "! Đọc long text (STXH/READ_TEXT) — nền tảng cổ điển
    METHODS read_text
      IMPORTING i_id          TYPE tdid
                i_object      TYPE tdobject
                i_name        TYPE tdobname
      RETURNING VALUE(r_text) TYPE string .

*   >>> Begin of change 20260927_01 F-DUBV TR S25K900131 - Review S25 (SELECT trong vong lap)
    TYPES: BEGIN OF ty_text_key,
             vbeln TYPE vbeln,
             posnr TYPE posnr,
             matnr TYPE matnr,
           END OF ty_text_key.
    TYPES ty_t_text_key TYPE STANDARD TABLE OF ty_text_key WITH EMPTY KEY.

    "! Doc header STXH MOT lan cho moi ten text co the dung o ITEM_NAME
    "! (theo ITEM_TEXT_IDS). BAT BUOC goi truoc vong lap dong hang:
    "! READ_TEXT chi tra bo dem nay, text khong co trong bo dem = khong co text.
    METHODS prefetch_item_texts
      IMPORTING i_bukrs   TYPE bukrs
                it_keys   TYPE ty_t_text_key .

    "! Nap MOT lan dieu kien thue A003/KONP cua nuoc cong ty (TAX_RATE_OF
    "! buoc 3). BAT BUOC goi truoc vong lap: TAX_RATE_OF chi doc bo dem nay.
    METHODS prefetch_tax_cond
      IMPORTING i_bukrs TYPE bukrs .
*   <<< End of change 20260927_01

*   >>> Begin of change 20260927_20 F-DUBV TR S25K900131 - Review S25 R06 (DB trong vong lap)
    TYPES: BEGIN OF ty_doc_key,
             bukrs TYPE bukrs,
             belnr TYPE belnr_d,
             gjahr TYPE gjahr,
           END OF ty_doc_key.
    TYPES ty_t_doc_key TYPE STANDARD TABLE OF ty_doc_key WITH EMPTY KEY.
    TYPES ty_t_matnr   TYPE STANDARD TABLE OF matnr WITH EMPTY KEY.
    TYPES ty_t_aubel   TYPE STANDARD TABLE OF vbeln WITH EMPTY KEY.

    "! Nap MOT lan nguoi ban (T001 / ADRC / ADR6) cua cong ty vao MT_SELLER.
    "! BAT BUOC goi truoc vong lap: READ_SELLER chi doc bo dem nay.
    METHODS prefetch_seller
      IMPORTING i_bukrs TYPE bukrs .

    "! Nap MOT lan ten vat tu MAKT (ngon ngu TEXT_LANGU, du phong sy-langu)
    "! vao MT_MATNR. BAT BUOC goi truoc vong lap: MATERIAL_TEXT chi doc bo dem.
    METHODS prefetch_mat_texts
      IMPORTING it_matnr TYPE ty_t_matnr .

    "! Nap MOT lan du lieu nguoi mua theo chung tu: khach le BSEC (+ ten ngan
    "! hang BNKA) theo BUKRS/BELNR/GJAHR va so tham chieu VBKD-BSTKD theo don
    "! ban AUBEL. BAT BUOC goi truoc vong lap: READ_BUYER chi doc bo dem nay.
    METHODS prefetch_buyer_docs
      IMPORTING it_doc   TYPE ty_t_doc_key OPTIONAL
                it_aubel TYPE ty_t_aubel OPTIONAL .
*   <<< End of change 20260927_20

*   >>> Begin of change 20260928_30 F-DUBV TR S25K900131 - Review S25 R06 (DB trong vong lap)
    TYPES: BEGIN OF ty_buyer_key,
             kunnr TYPE kunnr,
             bvtyp TYPE bvtyp,
           END OF ty_buyer_key.
    TYPES ty_t_buyer_key TYPE STANDARD TABLE OF ty_buyer_key WITH EMPTY KEY.

    "! Nap MOT lan du lieu chu the nguoi mua cua moi khach hang (BP qua
    "! CVI_CUST_LINK: BUT000 / BUT020 / ADRC / ADR6 / ADR2 / BUT0ID / BUT0BK /
    "! BNKA; KNA1 va dia chi KNA1-ADRNR). BAT BUOC goi truoc vong lap:
    "! BUYER_FROM_BP / BUYER_FROM_KNA1 chi doc bo dem nay.
    METHODS prefetch_buyer_master
      IMPORTING it_buyer TYPE ty_t_buyer_key .
*   <<< End of change 20260928_30

    "! ---- Header ----
    METHODS payment_of
      IMPORTING i_zlsch           TYPE dzlsch
                i_bukrs           TYPE bukrs
      RETURNING VALUE(rs_payment) TYPE zif_hddt_types=>ty_payment .

    METHODS exch_rate_of
      IMPORTING i_bukrs       TYPE bukrs
                i_waers       TYPE waers
                i_kursf       TYPE kursf
*   >>> Begin of change 20260930_01 F-CUONGUS TR DS4K900172 - Kiem chung DS4: so tien theo TCURX, ty gia theo TCURF
                i_date        TYPE dats OPTIONAL
*   <<< End of change 20260930_01
      RETURNING VALUE(r_rate) TYPE zif_hddt_types=>ty_amount .

    METHODS local_currency
      IMPORTING i_bukrs        TYPE bukrs
      RETURNING VALUE(r_waers) TYPE waers .
*   >>> Begin of change 20260930_01 F-CUONGUS TR DS4K900172 - Kiem chung DS4: so tien theo TCURX, ty gia theo TCURF

    "! Số tiền đọc từ bảng SAP ra GIÁ TRỊ THẬT theo số lẻ của đồng tiền.
    "! SAP lưu trường CURR của đồng tiền có ít hơn 2 số lẻ đã CHIA
    "! 10^(2 - TCURX-CURRDEC): 25.442.000 VND nằm trong DB là 254420.00.
    "! Đồng tiền không có trong TCURX là 2 số lẻ - giữ nguyên. Gọi NGAY
    "! tại chỗ đọc WRBTR / DMBTR / BSET / VBRP / KONV, không gọi lại trên số
    "! đã quy đổi.
    METHODS amount_of
      IMPORTING i_amount        TYPE zif_hddt_types=>ty_amount
                i_waers         TYPE waers
      RETURNING VALUE(r_amount) TYPE zif_hddt_types=>ty_amount .
*   <<< End of change 20260930_01

    "! Hoàn thiện request: số lượng dương, người bán, tổng hợp thuế suất,
    "! tính tổng (aggregate) — gọi cuối cùng ở mỗi lớp con.
    METHODS finalize_request
      CHANGING cs_request TYPE zif_hddt_types=>ty_request .

    "! ---- Ánh xạ danh sách ----
    "! Giá trị có nằm trong danh sách MAP (hỗ trợ mẫu CP: O*, **)?
    "! Danh sách trống => R_ALLOWED = I_DEFAULT.
    METHODS in_map_list
      IMPORTING i_map_type       TYPE zde_hddt_maptype
                i_value          TYPE clike
                i_default        TYPE abap_bool DEFAULT abap_true
      RETURNING VALUE(r_allowed) TYPE abap_bool .

    METHODS map_list_as_range
      IMPORTING i_map_type      TYPE zde_hddt_maptype
      RETURNING VALUE(rt_range) TYPE zif_hddt_types=>ty_r_docno .

  PRIVATE SECTION.
*   >>> Begin of change 20260930_01 F-CUONGUS TR DS4K900172 - Kiem chung DS4: so tien theo TCURX, ty gia theo TCURF
    TYPES: BEGIN OF ty_currdec,
             currkey TYPE tcurx-currkey,
             currdec TYPE tcurx-currdec,
           END OF ty_currdec.
    TYPES: BEGIN OF ty_fx_factor,
             fcurr  TYPE tcurf-fcurr,
             tcurr  TYPE tcurf-tcurr,
             factor TYPE zif_hddt_types=>ty_amount,
           END OF ty_fx_factor.
    "! Loại tỷ giá dùng tra hệ số TCURF
    CONSTANTS gc_rate_type TYPE kurst_curr VALUE 'M' ##NO_TEXT.
    "! Số lẻ theo đồng tiền (TCURX), nạp một lần trong AMOUNT_OF
    DATA mt_currdec      TYPE HASHED TABLE OF ty_currdec WITH UNIQUE KEY currkey .
    DATA mv_currdec_load TYPE abap_bool .
    "! Hệ số TCURF theo cặp đồng tiền, mỗi cặp đọc DB một lần
    DATA mt_fx           TYPE HASHED TABLE OF ty_fx_factor WITH UNIQUE KEY fcurr tcurr .

    "! Hệ số TCURF (TFACT / FFACT) của cặp đồng tiền tại ngày cho trước,
    "! không có dòng thì 1. Dòng còn hiệu lực là dòng có GDATU (ngày đảo
    "! ngược 99999999 - YYYYMMDD) nhỏ nhất mà vẫn >= ngày đảo của I_DATE.
    METHODS fx_factor
      IMPORTING i_from          TYPE waers
                i_to            TYPE waers
                i_date          TYPE dats
      RETURNING VALUE(r_factor) TYPE zif_hddt_types=>ty_amount .
*   <<< End of change 20260930_01

    TYPES: BEGIN OF ty_seller_cache,
             bukrs  TYPE bukrs,
             seller TYPE zif_hddt_types=>ty_seller,
           END OF ty_seller_cache.
    TYPES: BEGIN OF ty_buyer_cache,
             kunnr TYPE kunnr,
*   >>> Begin of change 20260927_20 F-DUBV TR S25K900131 - Review S25 bug MT_BUYER theo BVTYP
*   Ngan hang nguoi mua phu thuoc BVTYP cua chung tu -> bo dem theo ca BVTYP
             bvtyp TYPE bvtyp,
*   <<< End of change 20260927_20
             buyer TYPE zif_hddt_types=>ty_buyer,
           END OF ty_buyer_cache.
    TYPES: BEGIN OF ty_text_cache,
             key  TYPE c LENGTH 40,
             text TYPE string,
           END OF ty_text_cache.

    DATA mo_config   TYPE REF TO zcl_hddt_config .
    DATA mt_seller   TYPE SORTED TABLE OF ty_seller_cache WITH UNIQUE KEY bukrs .
*   >>> Begin of change 20260927_20 F-DUBV TR S25K900131 - Review S25 bug MT_BUYER theo BVTYP
*    DATA mt_buyer    TYPE SORTED TABLE OF ty_buyer_cache  WITH UNIQUE KEY kunnr .
    DATA mt_buyer    TYPE SORTED TABLE OF ty_buyer_cache  WITH UNIQUE KEY kunnr bvtyp .
*   <<< End of change 20260927_20
    "! Bộ đệm NCC riêng: KUNNR và LIFNR cùng dạng CHAR 10, dùng chung một
    "! bảng thì khách hàng và NCC trùng số sẽ đè nhau
    DATA mt_vendor   TYPE SORTED TABLE OF ty_buyer_cache  WITH UNIQUE KEY kunnr .
    DATA mt_unit     TYPE SORTED TABLE OF ty_text_cache   WITH UNIQUE KEY key .
    DATA mt_matnr    TYPE SORTED TABLE OF ty_text_cache   WITH UNIQUE KEY key .

*   >>> Begin of change 20260927_01 F-DUBV TR S25K900131 - Review S25 (SELECT trong vong lap)
    TYPES: BEGIN OF ty_stxh_buf,
             tdobject TYPE stxh-tdobject,
             tdname   TYPE stxh-tdname,
             tdid     TYPE stxh-tdid,
             tdspras  TYPE stxh-tdspras,
           END OF ty_stxh_buf.
    TYPES: BEGIN OF ty_taxcond_buf,
             bukrs TYPE bukrs,
             kschl TYPE kschl,
             mwskz TYPE mwskz,
             kopos TYPE konp-kopos,
             kbetr TYPE konp-kbetr,
           END OF ty_taxcond_buf.
    TYPES: BEGIN OF ty_taxcond_done,
             bukrs TYPE bukrs,
             kschl TYPE kschl,
           END OF ty_taxcond_done.
    DATA mt_stxh         TYPE HASHED TABLE OF ty_stxh_buf WITH UNIQUE KEY tdobject tdname tdid .
    DATA mt_taxcond      TYPE SORTED TABLE OF ty_taxcond_buf WITH NON-UNIQUE KEY bukrs kschl mwskz kopos .
    DATA mt_taxcond_done TYPE SORTED TABLE OF ty_taxcond_done WITH UNIQUE KEY bukrs kschl .
*   <<< End of change 20260927_01

*   >>> Begin of change 20260927_20 F-DUBV TR S25K900131 - Review S25 R06 (DB trong vong lap)
    TYPES: BEGIN OF ty_bsec_buf,
             bukrs TYPE bsec-bukrs,
             belnr TYPE bsec-belnr,
             gjahr TYPE bsec-gjahr,
             buzei TYPE bsec-buzei,
             name1 TYPE bsec-name1,
             name2 TYPE bsec-name2,
             name3 TYPE bsec-name3,
             name4 TYPE bsec-name4,
             stras TYPE bsec-stras,
             ort01 TYPE bsec-ort01,
             pstlz TYPE bsec-pstlz,
             land1 TYPE bsec-land1,
             stcd1 TYPE bsec-stcd1,
             stcd3 TYPE bsec-stcd3,
             intad TYPE bsec-intad,
             banks TYPE bsec-banks,
             bankl TYPE bsec-bankl,
             bankn TYPE bsec-bankn,
           END OF ty_bsec_buf.
    TYPES: BEGIN OF ty_bnka_buf,
             banks TYPE bnka-banks,
             bankl TYPE bnka-bankl,
             banka TYPE bnka-banka,
           END OF ty_bnka_buf.
    TYPES: BEGIN OF ty_vbkd_buf,
             vbeln TYPE vbkd-vbeln,
             posnr TYPE vbkd-posnr,
             bstkd TYPE vbkd-bstkd,
           END OF ty_vbkd_buf.
    DATA mt_bsec TYPE HASHED TABLE OF ty_bsec_buf WITH UNIQUE KEY bukrs belnr gjahr .
    DATA mt_bnka TYPE HASHED TABLE OF ty_bnka_buf WITH UNIQUE KEY banks bankl .
    DATA mt_vbkd TYPE HASHED TABLE OF ty_vbkd_buf WITH UNIQUE KEY vbeln .
*   <<< End of change 20260927_20

*   >>> Begin of change 20260928_30 F-DUBV TR S25K900131 - Review S25 R06 (DB trong vong lap)
    TYPES: BEGIN OF ty_bp_link_buf,
             kunnr   TYPE kunnr,
             partner TYPE bu_partner,
           END OF ty_bp_link_buf.
    TYPES: BEGIN OF ty_but000_buf,
             partner      TYPE but000-partner,
             partner_guid TYPE but000-partner_guid,
             type         TYPE but000-type,
             name_org1    TYPE but000-name_org1,
             name_org2    TYPE but000-name_org2,
             name_org3    TYPE but000-name_org3,
             name_org4    TYPE but000-name_org4,
             name_first   TYPE but000-name_first,
             name_last    TYPE but000-name_last,
           END OF ty_but000_buf.
    TYPES: BEGIN OF ty_but020_buf,
             partner    TYPE but020-partner,
             addrnumber TYPE but020-addrnumber,
           END OF ty_but020_buf.
    TYPES: BEGIN OF ty_adrc_buf,
             addrnumber TYPE adrc-addrnumber,
             date_from  TYPE adrc-date_from,
             nation     TYPE adrc-nation,
             street     TYPE adrc-street,
             str_suppl1 TYPE adrc-str_suppl1,
             str_suppl2 TYPE adrc-str_suppl2,
             str_suppl3 TYPE adrc-str_suppl3,
             location   TYPE adrc-location,
             city1      TYPE adrc-city1,
             city2      TYPE adrc-city2,
             country    TYPE adrc-country,
           END OF ty_adrc_buf.
    TYPES: BEGIN OF ty_adr6_buf,
             addrnumber TYPE adr6-addrnumber,
             persnumber TYPE adr6-persnumber,
             date_from  TYPE adr6-date_from,
             consnumber TYPE adr6-consnumber,
             smtp_addr  TYPE adr6-smtp_addr,
           END OF ty_adr6_buf.
    TYPES: BEGIN OF ty_adr2_buf,
             addrnumber TYPE adr2-addrnumber,
             persnumber TYPE adr2-persnumber,
             date_from  TYPE adr2-date_from,
             consnumber TYPE adr2-consnumber,
             tel_number TYPE adr2-tel_number,
           END OF ty_adr2_buf.
    TYPES: BEGIN OF ty_but0id_buf,
             partner  TYPE but0id-partner,
             type     TYPE but0id-type,
             idnumber TYPE but0id-idnumber,
           END OF ty_but0id_buf.
    TYPES: BEGIN OF ty_kna1_buf,
             kunnr TYPE kna1-kunnr,
             name1 TYPE kna1-name1,
             name2 TYPE kna1-name2,
             stras TYPE kna1-stras,
             ort01 TYPE kna1-ort01,
             land1 TYPE kna1-land1,
             stcd1 TYPE kna1-stcd1,
             stcd3 TYPE kna1-stcd3,
             telf1 TYPE kna1-telf1,
             adrnr TYPE kna1-adrnr,
           END OF ty_kna1_buf.
    TYPES: BEGIN OF ty_but0bk_buf,
             partner TYPE but0bk-partner,
             bkvid   TYPE but0bk-bkvid,
             banks   TYPE but0bk-banks,
             bankl   TYPE but0bk-bankl,
             bankn   TYPE but0bk-bankn,
             accname TYPE but0bk-accname,
           END OF ty_but0bk_buf.
    "! Khach hang co link CVI -> BP (PARTNER rong = GUID khong co BUT000)
    DATA mt_bp_link  TYPE HASHED TABLE OF ty_bp_link_buf WITH UNIQUE KEY kunnr .
    DATA mt_but000   TYPE HASHED TABLE OF ty_but000_buf WITH UNIQUE KEY partner .
    "! So dia chi LON NHAT moi BP (= ORDER BY addrnumber DESCENDING UP TO 1 ROWS)
    DATA mt_but020   TYPE HASHED TABLE OF ty_but020_buf WITH UNIQUE KEY partner .
    DATA mt_adrc     TYPE HASHED TABLE OF ty_adrc_buf WITH UNIQUE KEY addrnumber .
    DATA mt_adr6     TYPE SORTED TABLE OF ty_adr6_buf
                     WITH NON-UNIQUE KEY addrnumber consnumber persnumber date_from .
    DATA mt_adr2     TYPE SORTED TABLE OF ty_adr2_buf
                     WITH NON-UNIQUE KEY addrnumber consnumber persnumber date_from .
    DATA mt_but0id   TYPE SORTED TABLE OF ty_but0id_buf WITH NON-UNIQUE KEY partner type idnumber .
    DATA mt_kna1     TYPE HASHED TABLE OF ty_kna1_buf WITH UNIQUE KEY kunnr .
    DATA mt_but0bk   TYPE HASHED TABLE OF ty_but0bk_buf WITH UNIQUE KEY partner bkvid .
    DATA mt_bp_bnka  TYPE HASHED TABLE OF ty_bnka_buf WITH UNIQUE KEY banks bankl .
*   <<< End of change 20260928_30

    METHODS text_langu
      IMPORTING i_bukrs        TYPE bukrs OPTIONAL
      RETURNING VALUE(r_langu) TYPE spras .

    METHODS buyer_from_bp
      IMPORTING i_kunnr        TYPE kunnr
                i_bukrs        TYPE bukrs
                i_bvtyp        TYPE bvtyp
      CHANGING  cs_buyer       TYPE zif_hddt_types=>ty_buyer
      RETURNING VALUE(r_found) TYPE abap_bool .

    METHODS buyer_from_kna1
      IMPORTING i_kunnr  TYPE kunnr
                i_bukrs  TYPE bukrs
      CHANGING  cs_buyer TYPE zif_hddt_types=>ty_buyer .

ENDCLASS.



CLASS ZCL_HDDT_SRC_BASE IMPLEMENTATION.


  METHOD apply_registry_edits.

    " Giờ phát hành mặc định (FS: 08:00:00) khi người dùng chưa sửa
    IF is_reg-inv_time IS NOT INITIAL AND is_reg-status = zif_hddt_types=>gc_status-not_sent.
      cs_request-invoice-header-inv_time = is_reg-inv_time.
    ELSE.
      DATA(lv_def) = param( i_key = zif_hddt_types=>gc_parm-inv_time_default
                            i_bukrs = cs_request-bukrs ).
      CONDENSE lv_def NO-GAPS.
      IF strlen( lv_def ) = 6 AND lv_def CO '0123456789'.
        cs_request-invoice-header-inv_time = lv_def.
      ENDIF.
    ENDIF.

    " Ngày phát hành người dùng sửa (chỉ khi chưa tích hợp)
    IF is_reg-inv_date IS NOT INITIAL AND is_reg-status = zif_hddt_types=>gc_status-not_sent
       AND is_reg-changed_by IS NOT INITIAL.
      cs_request-invoice-header-inv_date = is_reg-inv_date.
    ENDIF.

    " Tên hàng nhập tay: ưu tiên 1 theo FS -> ghi đè mọi dòng hàng
    IF is_reg-item_text IS NOT INITIAL.
      LOOP AT cs_request-invoice-items ASSIGNING FIELD-SYMBOL(<fs_it>)
           WHERE item_type <> '3'.
        <fs_it>-item_name = is_reg-item_text.
      ENDLOOP.
    ENDIF.

    IF is_reg-gom_no IS NOT INITIAL.
      APPEND VALUE #( name = 'GOM_NO' value = |{ is_reg-gom_no }| ) TO cs_request-params.
    ENDIF.

  ENDMETHOD.


  METHOD buyer_from_bp.

    DATA lv_partner TYPE bu_partner.

    " Khách hàng -> Business Partner (CVI); nếu không có link thì thử
    " chính mã khách là số BP (mô hình đồng bộ số).
*   >>> Begin of change 20260928_30 F-DUBV TR S25K900131 - Review S25 R06 (DB trong vong lap)
*   CVI_CUST_LINK / BUT000 nap 1 lan truoc vong lap (PREFETCH_BUYER_MASTER)
*   SELECT SINGLE partner_guid FROM cvi_cust_link
*     WHERE customer = @i_kunnr
*     INTO @DATA(lv_guid).
*   IF sy-subrc = 0.
*     SELECT SINGLE partner, type, name_org1, name_org2, name_org3, name_org4,
*                   name_first, name_last
*       FROM but000
*       WHERE partner_guid = @lv_guid
*       INTO @DATA(ls_but000).
*   ELSE.
*     lv_partner = i_kunnr.
*     SELECT SINGLE partner, type, name_org1, name_org2, name_org3, name_org4,
*                   name_first, name_last
*       FROM but000
*       WHERE partner = @lv_partner
*       INTO @ls_but000.
*   ENDIF.
*   IF sy-subrc <> 0.
*     r_found = abap_false.
*     RETURN.
*   ENDIF.
    DATA: BEGIN OF ls_but000,
            partner    TYPE but000-partner,
            type       TYPE but000-type,
            name_org1  TYPE but000-name_org1,
            name_org2  TYPE but000-name_org2,
            name_org3  TYPE but000-name_org3,
            name_org4  TYPE but000-name_org4,
            name_first TYPE but000-name_first,
            name_last  TYPE but000-name_last,
          END OF ls_but000.
    " Co link CVI: BP theo GUID (PARTNER rong = GUID khong co BUT000 -> khong
    " thu tiep theo so KH, dung nhu ban cu); khong co link: so KH = so BP
    READ TABLE mt_bp_link INTO DATA(ls_bp_link) WITH TABLE KEY kunnr = i_kunnr.
    IF sy-subrc = 0.
      lv_partner = ls_bp_link-partner.
    ELSE.
      lv_partner = i_kunnr.
    ENDIF.
    READ TABLE mt_but000 INTO DATA(ls_but000_buf) WITH TABLE KEY partner = lv_partner.
    IF sy-subrc <> 0 OR lv_partner IS INITIAL.
      r_found = abap_false.
      RETURN.
    ENDIF.
    ls_but000 = CORRESPONDING #( ls_but000_buf ).
*   <<< End of change 20260928_30
    r_found = abap_true.

*---- Tên -------------------------------------------------------------*
    IF ls_but000-type = '1'.               " cá nhân
      " FS MAG: NAME_LAST + NAME_FIRST; tham số BUYER_PERSON_NAME = FIRST_LAST
      " để đổi thứ tự
      IF param( i_key = zif_hddt_types=>gc_parm-buyer_person_nm
                i_bukrs = i_bukrs i_default = `LAST_FIRST` ) = 'FIRST_LAST'.
        cs_buyer-legal_name = |{ ls_but000-name_first } { ls_but000-name_last }|.
      ELSE.
        cs_buyer-legal_name = |{ ls_but000-name_last } { ls_but000-name_first }|.
      ENDIF.
    ELSE.
      " Thứ tự trường tên theo cấu hình (dự án tham chiếu dùng
      " NAME_ORG2..4 và fallback NAME_ORG1 vì ORG1 chứa tên viết tắt).
      DATA(lv_fields) = param( i_key     = zif_hddt_types=>gc_parm-buyer_name_flds
                               i_bukrs   = i_bukrs
                               i_default = `NAME_ORG1,NAME_ORG2,NAME_ORG3,NAME_ORG4` ).
      SPLIT lv_fields AT ',' INTO TABLE DATA(lt_fields).
      LOOP AT lt_fields ASSIGNING FIELD-SYMBOL(<fs_field>).
        CONDENSE <fs_field>.
        TRANSLATE <fs_field> TO UPPER CASE.
        ASSIGN COMPONENT <fs_field> OF STRUCTURE ls_but000 TO FIELD-SYMBOL(<fs_val>).
        IF sy-subrc = 0 AND <fs_val> IS NOT INITIAL.
          cs_buyer-legal_name = |{ cs_buyer-legal_name } { <fs_val> }|.
        ENDIF.
      ENDLOOP.
      IF cs_buyer-legal_name IS INITIAL.
        cs_buyer-legal_name = ls_but000-name_org1.
      ENDIF.
    ENDIF.
    CONDENSE cs_buyer-legal_name.

*---- Địa chỉ: số địa chỉ lớn nhất của BP (như dự án tham chiếu) ------*
*   >>> Begin of change 20260928_30 F-DUBV TR S25K900131 - Review S25 R06 (DB trong vong lap)
*   BUT020 / ADRC / ADR6 / ADR2 nap 1 lan truoc vong lap (PREFETCH_BUYER_MASTER)
*   SELECT addrnumber FROM but020
*     WHERE partner = @ls_but000-partner
*     ORDER BY addrnumber DESCENDING
*     INTO TABLE @DATA(lt_but020)
*     UP TO 1 ROWS.
*   DATA lv_land1 TYPE land1.
*   IF sy-subrc = 0.
*     DATA(lv_adrnr) = lt_but020[ 1 ]-addrnumber.
    READ TABLE mt_but020 INTO DATA(ls_but020) WITH TABLE KEY partner = ls_but000-partner.
    DATA lv_land1 TYPE land1.
    IF sy-subrc = 0.
      DATA(lv_adrnr) = ls_but020-addrnumber.
*   <<< End of change 20260928_30

*   >>> Begin of change 20260928_30 F-DUBV TR S25K900131 - Review S25 R06 (DB trong vong lap)
*     SELECT SINGLE street, str_suppl1, str_suppl2, str_suppl3, location,
*                   city1, city2, country
*       FROM adrc
*       WHERE addrnumber = @lv_adrnr
*       INTO @DATA(ls_adrc).
      READ TABLE mt_adrc INTO DATA(ls_adrc) WITH TABLE KEY addrnumber = lv_adrnr.
*   <<< End of change 20260928_30
      IF sy-subrc = 0.
        lv_land1 = ls_adrc-country.
        cs_buyer-address = |{ ls_adrc-street } { ls_adrc-str_suppl1 }, { ls_adrc-str_suppl2 }, | &&
                           |{ ls_adrc-str_suppl3 }, { ls_adrc-location }, { ls_adrc-city2 }, { ls_adrc-city1 }|.
        clean_address( EXPORTING i_land1 = lv_land1
                                 i_bukrs = i_bukrs
                       CHANGING  c_addr  = cs_buyer-address ).
      ENDIF.

      " Email: nối tất cả địa chỉ bằng ';' (NCC gửi HĐ tới nhiều mail)
*   >>> Begin of change 20260928_30 F-DUBV TR S25K900131 - Review S25 R06 (DB trong vong lap)
*     SELECT smtp_addr FROM adr6
*       WHERE addrnumber = @lv_adrnr
*       ORDER BY consnumber
*       INTO TABLE @DATA(lt_adr6).
*     LOOP AT lt_adr6 ASSIGNING FIELD-SYMBOL(<fs_adr6>).
      LOOP AT mt_adr6 ASSIGNING FIELD-SYMBOL(<fs_adr6>) WHERE addrnumber = lv_adrnr.
*   <<< End of change 20260928_30
        IF <fs_adr6>-smtp_addr IS INITIAL.
          CONTINUE.
        ENDIF.
        cs_buyer-email = COND #( WHEN cs_buyer-email IS INITIAL
                                 THEN <fs_adr6>-smtp_addr
                                 ELSE |{ cs_buyer-email };{ <fs_adr6>-smtp_addr }| ).
      ENDLOOP.

*   >>> Begin of change 20260928_30 F-DUBV TR S25K900131 - Review S25 R06 (DB trong vong lap)
*     SELECT tel_number FROM adr2
*       WHERE addrnumber = @lv_adrnr
*       ORDER BY consnumber
*       INTO TABLE @DATA(lt_adr2).
*     LOOP AT lt_adr2 ASSIGNING FIELD-SYMBOL(<fs_adr2>).
      LOOP AT mt_adr2 ASSIGNING FIELD-SYMBOL(<fs_adr2>) WHERE addrnumber = lv_adrnr.
*   <<< End of change 20260928_30
        IF <fs_adr2>-tel_number IS INITIAL.
          CONTINUE.
        ENDIF.
        cs_buyer-phone = COND #( WHEN cs_buyer-phone IS INITIAL
                                 THEN <fs_adr2>-tel_number
                                 ELSE |{ cs_buyer-phone };{ <fs_adr2>-tel_number }| ).
      ENDLOOP.
    ENDIF.

*---- Mã số thuế và CCCD từ số định danh BP ---------------------------*
    DATA(lv_tax_type) = param( i_key     = zif_hddt_types=>gc_parm-buyer_tax_idtype
                               i_bukrs   = i_bukrs
                               i_default = `VATRU` ).
    " Loại số định danh chứa CCCD là quy ước riêng từng khách hàng ->
    " không có mặc định trong code; trống = không lấy
    DATA(lv_id_type)  = param( i_key     = zif_hddt_types=>gc_parm-buyer_id_idtype
                               i_bukrs   = i_bukrs ).
*   >>> Begin of change 20260928_30 F-DUBV TR S25K900131 - Review S25 R06 (DB trong vong lap)
*   BUT0ID / KNA1 / BUT0BK / BNKA nap 1 lan truoc vong lap (PREFETCH_BUYER_MASTER)
*   SELECT type, idnumber FROM but0id
*     WHERE partner = @ls_but000-partner
*     INTO TABLE @DATA(lt_but0id).
*   LOOP AT lt_but0id ASSIGNING FIELD-SYMBOL(<fs_id>).
    LOOP AT mt_but0id ASSIGNING FIELD-SYMBOL(<fs_id>) WHERE partner = ls_but000-partner.
*   <<< End of change 20260928_30
      IF <fs_id>-type = lv_tax_type AND cs_buyer-tax_code IS INITIAL.
        cs_buyer-tax_code = <fs_id>-idnumber.
      ELSEIF lv_id_type IS NOT INITIAL AND <fs_id>-type = lv_id_type
         AND cs_buyer-id_number IS INITIAL.
        cs_buyer-id_number = <fs_id>-idnumber.
      ENDIF.
    ENDLOOP.
    IF cs_buyer-tax_code IS INITIAL.
*   >>> Begin of change 20260928_30 F-DUBV TR S25K900131 - Review S25 R06 (DB trong vong lap)
*     SELECT SINGLE stcd1, stcd3 FROM kna1
*       WHERE kunnr = @i_kunnr
*       INTO @DATA(ls_kna1_tax).
      READ TABLE mt_kna1 INTO DATA(ls_kna1_tax) WITH TABLE KEY kunnr = i_kunnr.
*   <<< End of change 20260928_30
      IF sy-subrc = 0.
        cs_buyer-tax_code = COND #( WHEN ls_kna1_tax-stcd1 IS NOT INITIAL
                                    THEN ls_kna1_tax-stcd1 ELSE ls_kna1_tax-stcd3 ).
      ENDIF.
    ENDIF.

*---- Ngân hàng theo loại đối tác NH ghi trên chứng từ (BVTYP) --------*
    IF i_bvtyp IS NOT INITIAL.
*   >>> Begin of change 20260928_30 F-DUBV TR S25K900131 - Review S25 R06 (DB trong vong lap)
*     SELECT SINGLE banks, bankl, bankn, accname FROM but0bk
*       WHERE partner = @ls_but000-partner
*         AND bkvid   = @i_bvtyp
*       INTO @DATA(ls_but0bk).
      READ TABLE mt_but0bk INTO DATA(ls_but0bk)
           WITH TABLE KEY partner = ls_but000-partner
                          bkvid   = i_bvtyp.
*   <<< End of change 20260928_30
      IF sy-subrc = 0.
        cs_buyer-bank_acct = ls_but0bk-bankn.
*   >>> Begin of change 20260928_30 F-DUBV TR S25K900131 - Review S25 R06 (DB trong vong lap)
*       SELECT SINGLE banka FROM bnka
*         WHERE banks = @ls_but0bk-banks AND bankl = @ls_but0bk-bankl
*         INTO @DATA(lv_banka).
*       IF sy-subrc = 0.
*         cs_buyer-bank_name = lv_banka.
*       ENDIF.
        READ TABLE mt_bp_bnka INTO DATA(ls_bp_bnka)
             WITH TABLE KEY banks = ls_but0bk-banks
                            bankl = ls_but0bk-bankl.
        IF sy-subrc = 0.
          cs_buyer-bank_name = ls_bp_bnka-banka.
        ENDIF.
*   <<< End of change 20260928_30
      ENDIF.
    ENDIF.

  ENDMETHOD.


  METHOD buyer_from_kna1.

    " Hệ không dùng BP (hoặc chưa đồng bộ CVI) -> dữ liệu khách hàng cổ điển
*   >>> Begin of change 20260928_30 F-DUBV TR S25K900131 - Review S25 R06 (DB trong vong lap)
*   KNA1 / ADRC / ADR6 nap 1 lan truoc vong lap (PREFETCH_BUYER_MASTER)
*   SELECT SINGLE name1, name2, stras, ort01, land1, stcd1, stcd3, telf1, adrnr
*     FROM kna1
*     WHERE kunnr = @i_kunnr
*     INTO @DATA(ls_kna1).
    READ TABLE mt_kna1 INTO DATA(ls_kna1) WITH TABLE KEY kunnr = i_kunnr.
*   <<< End of change 20260928_30
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    cs_buyer-legal_name = |{ ls_kna1-name1 } { ls_kna1-name2 }|.
    CONDENSE cs_buyer-legal_name.
    cs_buyer-tax_code = COND #( WHEN ls_kna1-stcd1 IS NOT INITIAL
                                THEN ls_kna1-stcd1 ELSE ls_kna1-stcd3 ).
    cs_buyer-phone    = ls_kna1-telf1.
    cs_buyer-address  = |{ ls_kna1-stras }, { ls_kna1-ort01 }|.

    IF ls_kna1-adrnr IS NOT INITIAL.
*   >>> Begin of change 20260928_30 F-DUBV TR S25K900131 - Review S25 R06 (DB trong vong lap)
*     SELECT SINGLE street, str_suppl1, str_suppl2, str_suppl3, location, city1, city2, country
*       FROM adrc
*       WHERE addrnumber = @ls_kna1-adrnr
*       INTO @DATA(ls_adrc).
      READ TABLE mt_adrc INTO DATA(ls_adrc) WITH TABLE KEY addrnumber = ls_kna1-adrnr.
*   <<< End of change 20260928_30
      IF sy-subrc = 0.
        cs_buyer-address = |{ ls_adrc-street } { ls_adrc-str_suppl1 }, { ls_adrc-str_suppl2 }, | &&
                           |{ ls_adrc-str_suppl3 }, { ls_adrc-location }, { ls_adrc-city2 }, { ls_adrc-city1 }|.
        ls_kna1-land1 = ls_adrc-country.
      ENDIF.
*   >>> Begin of change 20260928_30 F-DUBV TR S25K900131 - Review S25 R06 (DB trong vong lap)
*   = ORDER BY consnumber UP TO 1 ROWS: dong dau tien cua dia chi (ke ca mail rong)
*     SELECT smtp_addr FROM adr6
*       WHERE addrnumber = @ls_kna1-adrnr
*       ORDER BY consnumber
*       INTO TABLE @DATA(lt_adr6)
*       UP TO 1 ROWS.
*     IF sy-subrc = 0.
*       cs_buyer-email = lt_adr6[ 1 ]-smtp_addr.
*     ENDIF.
      LOOP AT mt_adr6 ASSIGNING FIELD-SYMBOL(<fs_adr6>) WHERE addrnumber = ls_kna1-adrnr.
        cs_buyer-email = <fs_adr6>-smtp_addr.
        EXIT.
      ENDLOOP.
*   <<< End of change 20260928_30
    ENDIF.

    clean_address( EXPORTING i_land1 = ls_kna1-land1
                             i_bukrs = i_bukrs
                   CHANGING  c_addr  = cs_buyer-address ).

  ENDMETHOD.


  METHOD clean_address.

    " Gộp các đoạn ', , ,' do trường trống thành một dấu phẩy, cắt dấu
    " phẩy / khoảng trắng đầu-cuối (dự án tham chiếu REPLACE 6 lần + SHIFT)
    c_addr = replace( val = c_addr regex = `(\s*,\s*)+` with = `, ` occ = 0 ).
    c_addr = replace( val = c_addr regex = `^[\s,]+|[\s,]+$` with = `` occ = 0 ).
    CONDENSE c_addr.

    IF c_addr IS INITIAL OR i_land1 IS INITIAL.
      RETURN.
    ENDIF.

    " Hậu tố quốc gia: VN lấy từ tham số (mặc định 'Việt Nam'), nước
    " ngoài lấy tên nước theo ngôn ngữ đăng nhập.
    IF i_land1 = 'VN'.
      DATA(lv_sfx) = param( i_key     = zif_hddt_types=>gc_parm-addr_country_sfx
                            i_bukrs   = i_bukrs
                            i_default = `Việt Nam` ).
      IF lv_sfx <> '-'.                    " '-' = không thêm hậu tố
        c_addr = |{ c_addr }, { lv_sfx }|.
      ENDIF.
    ELSE.
      SELECT SINGLE landx50 FROM t005t
        WHERE land1 = @i_land1 AND spras = @sy-langu
        INTO @DATA(lv_landx).
      IF sy-subrc = 0.
        c_addr = |{ c_addr }, { lv_landx }|.
      ENDIF.
    ENDIF.

  ENDMETHOD.


  METHOD config.

    IF mo_config IS NOT BOUND.
      mo_config = zcl_hddt_config=>get_instance( ).
    ENDIF.
    ro_config = mo_config.

  ENDMETHOD.


  METHOD exch_rate_of.

    IF i_waers IS INITIAL OR i_waers = local_currency( i_bukrs ) OR i_kursf IS INITIAL.
      r_rate = 1.
      RETURN.
    ENDIF.

    " KURSF âm = tỷ giá nghịch đảo; hệ số nhân (vd 1000 khi TCURF khai
    " factor) lấy từ tham số — dự án tham chiếu nhân cứng 1000.
    DATA(lv_factor) = param( i_key     = zif_hddt_types=>gc_parm-exch_rate_factor
                             i_bukrs   = i_bukrs
                             i_default = `1` ).
    DATA lv_f TYPE zif_hddt_types=>ty_amount.
    TRY.
        lv_f = lv_factor.
      CATCH cx_sy_conversion_no_number.
        lv_f = 1.
    ENDTRY.
    IF lv_f = 0.
      lv_f = 1.
    ENDIF.

*   >>> Begin of change 20260930_01 F-CUONGUS TR DS4K900172 - Kiem chung DS4: so tien theo TCURX, ty gia theo TCURF
*    IF i_kursf < 0.
*      r_rate = ( 1 / abs( i_kursf ) ) * lv_f.
*    ELSE.
*      r_rate = i_kursf * lv_f.
*    ENDIF.
    " KURSF là tỷ giá TRƯỚC hệ số TCURF: USD -> VND khai 1 : 1000 nên
    " KURSF 25,442 nghĩa là 25.442 VND / USD
    DATA(lv_tcurf) = fx_factor( i_from = i_waers
                                i_to   = local_currency( i_bukrs )
                                i_date = COND #( WHEN i_date IS INITIAL
                                                 THEN sy-datum ELSE i_date ) ).
    IF i_kursf < 0.
      " KURSF âm = niêm yết gián tiếp
      r_rate = ( 1 / abs( i_kursf ) ) * lv_tcurf * lv_f.
    ELSE.
      r_rate = i_kursf * lv_tcurf * lv_f.
    ENDIF.
*   <<< End of change 20260930_01

  ENDMETHOD.


  METHOD finalize_request.

    DATA(lv_bukrs) = cs_request-bukrs.

    " Người dùng yêu cầu số lượng luôn dương (dự án tham chiếu)
    IF param( i_key = zif_hddt_types=>gc_parm-item_qty_abs
              i_bukrs = lv_bukrs i_default = `X` ) = 'X'.
      LOOP AT cs_request-invoice-items ASSIGNING FIELD-SYMBOL(<fs_it>).
        <fs_it>-quantity = abs( <fs_it>-quantity ).
      ENDLOOP.
    ENDIF.

    " Người bán từ T001/ADRC — tham số SELLER_* trong FILL_DEFAULTS của
    " service chỉ điền các trường còn trống.
    IF param( i_key = zif_hddt_types=>gc_parm-seller_from_t001
              i_bukrs = lv_bukrs i_default = `X` ) = 'X'.
      DATA(ls_seller) = read_seller( lv_bukrs ).
      IF cs_request-invoice-seller-name IS INITIAL.
        cs_request-invoice-seller-name = ls_seller-name.
      ENDIF.
      IF cs_request-invoice-seller-address IS INITIAL.
        cs_request-invoice-seller-address = ls_seller-address.
      ENDIF.
      IF cs_request-invoice-seller-phone IS INITIAL.
        cs_request-invoice-seller-phone = ls_seller-phone.
      ENDIF.
      IF cs_request-invoice-seller-email IS INITIAL.
        cs_request-invoice-seller-email = ls_seller-email.
      ENDIF.
    ENDIF.

    " Tổng hợp thuế suất để hiển thị ('10%' hoặc 'Nhiều loại')
    DATA(lv_summary) = rate_summary( cs_request-invoice-items ).
    IF lv_summary IS NOT INITIAL.
      APPEND VALUE #( name = 'TAX_RATE_SUMMARY' value = lv_summary )
             TO cs_request-invoice-ext.
    ENDIF.

    " Tổng cộng do engine tính (không lặp lại công thức ở tầng nguồn)
    zcl_hddt_service=>aggregate_invoice( CHANGING cs_invoice = cs_request-invoice ).

  ENDMETHOD.


  METHOD in_map_list.
*---------------------------------------------------------------------*
* Ánh xạ danh sách
*---------------------------------------------------------------------*

    DATA(lt_map) = config( )->get_map_list( i_provider = space
                                            i_map_type = i_map_type ).
    IF lt_map IS INITIAL.
      r_allowed = i_default.
      RETURN.
    ENDIF.

    DATA lv_value TYPE c LENGTH 50.
    lv_value = i_value.
    CONDENSE lv_value.

    r_allowed = abap_false.
    LOOP AT lt_map ASSIGNING FIELD-SYMBOL(<fs_map>).
      DATA lv_pat TYPE c LENGTH 50.
      lv_pat = <fs_map>-sap_value.
      CONDENSE lv_pat.
      IF lv_pat IS INITIAL.
        CONTINUE.
      ENDIF.
      IF lv_pat CA '*+' .
        IF lv_value CP lv_pat.
          r_allowed = abap_true.
          RETURN.
        ENDIF.
      ELSEIF lv_value = lv_pat.
        r_allowed = abap_true.
        RETURN.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD item_name.

    " Thứ tự ưu tiên tên hàng trong dự án tham chiếu:
    "   1) long text dòng đơn bán  (ZI03 / VBBP, tên = VBELN+POSNR)
    "   2) long text vật tư        (GRUN / MATERIAL, tên = MATNR)
    "   3) MAKT
    "   4) diễn giải trên chứng từ (SGTXT / ARKTX)
    " Bước 1-2 khai trong ITEM_TEXT_IDS dạng 'ID:OBJECT;ID:OBJECT'. Mặc
    " định trong code chỉ dùng text chuẩn SAP (GRUN/MATERIAL); text ID
    " riêng của khách hàng nằm ở cấu hình.
    DATA(lv_ids) = param( i_key     = zif_hddt_types=>gc_parm-item_text_ids
                          i_bukrs   = i_bukrs
                          i_default = `GRUN:MATERIAL` ).
    SPLIT lv_ids AT ';' INTO TABLE DATA(lt_ids).
    LOOP AT lt_ids ASSIGNING FIELD-SYMBOL(<fs_pair>).
      SPLIT <fs_pair> AT ':' INTO DATA(lv_id) DATA(lv_obj).
      CONDENSE: lv_id, lv_obj.
      TRANSLATE: lv_id TO UPPER CASE, lv_obj TO UPPER CASE.
      IF lv_id IS INITIAL OR lv_obj IS INITIAL.
        CONTINUE.
      ENDIF.

      DATA lv_name TYPE tdobname.
      CLEAR lv_name.
      CASE lv_obj.
        WHEN 'VBBP'.
          IF i_vbeln IS INITIAL.
            CONTINUE.
          ENDIF.
          lv_name = |{ i_vbeln }{ i_posnr }|.
        WHEN 'MATERIAL'.
          IF i_matnr IS INITIAL.
            CONTINUE.
          ENDIF.
          lv_name = i_matnr.
        WHEN OTHERS.
          CONTINUE.
      ENDCASE.

      r_name = read_text( i_id     = CONV #( lv_id )
                           i_object = CONV #( lv_obj )
                           i_name   = lv_name ).
      IF r_name IS NOT INITIAL.
        RETURN.
      ENDIF.
    ENDLOOP.

    r_name = material_text( i_matnr ).
    IF r_name IS INITIAL.
      r_name = i_default.
      CONDENSE r_name.
    ENDIF.

  ENDMETHOD.


  METHOD keep_document.

    r_keep = abap_true.

    " FS v0.17 mục 3.3: MỌI chứng từ đã bị huỷ trên SAP đều bị loại khỏi
    " ALV ở các lần chạy sau, KHÔNG phụ thuộc chứng từ đó đã từng phát
    " hành hoá đơn hay chưa. Khác bản FS trước - trước đây còn giữ lại
    " chứng từ đã có số hoá đơn để người dùng huỷ hoá đơn.
    " Hai ngoại lệ:
    "   - người dùng tích tham số Loại chứng từ hủy;
    "   - bản ghi đang ở trạng thái Lỗi tích hợp: đã huỷ được chứng từ
    "     trên SAP nhưng chưa xoá được hoá đơn nháp trên nhà cung cấp,
    "     phải hiện để người dùng xử lý dứt điểm.
    IF i_reversed = abap_true
       AND is_selection-xreversed = abap_false
       AND is_reg-status <> zif_hddt_types=>gc_status-error.
      r_keep = abap_false.
      RETURN.
    ENDIF.

    IF is_selection-r_status IS NOT INITIAL
       AND is_reg-status NOT IN is_selection-r_status.
      r_keep = abap_false.
    ENDIF.

  ENDMETHOD.


  METHOD line_tax.

    IF i_rate <= 0.
      r_tax = 0.
      RETURN.
    ENDIF.
    " KHÔNG khai inline biến nhận kết quả phép nhân / chia: với biểu thức
    " kiểu P, ABAP cho biến inline kiểu P LENGTH 8 DECIMALS 0, phần lẻ
    " bị làm tròn mất ngay lúc gán nên ROUND( dec = 2 ) phía dưới vô tác
    " dụng - hoá đơn ngoại tệ mất số lẻ tiền thuế (12,345 USD thành 12,00).
    " Khai cùng kiểu số tiền (6 số lẻ) rồi mới làm tròn theo loại tiền.
    DATA lv_tax TYPE zif_hddt_types=>ty_amount.
    lv_tax = i_amount * i_rate / 100.
    IF i_waers = 'VND' OR i_waers IS INITIAL.
      r_tax = round( val = lv_tax dec = 0 ).
    ELSE.
      r_tax = round( val = lv_tax dec = 2 ).
    ENDIF.

  ENDMETHOD.


  METHOD load_registry.

    CLEAR mt_reg.
    SELECT * FROM ztb_hddt_inv
      WHERE bukrs    = @i_bukrs
        AND gjahr    = @i_gjahr
        AND src_type = @i_src_type
      INTO TABLE @mt_reg.

  ENDMETHOD.


  METHOD fx_factor.
*   >>> Begin of change 20260930_01 F-CUONGUS TR DS4K900172 - Kiem chung DS4: so tien theo TCURX, ty gia theo TCURF

    " Hệ số theo cặp đồng tiền hầu như không đổi: giữ một giá trị cho cả
    " lần chạy, không phân biệt ngày
    READ TABLE mt_fx INTO DATA(ls_fx) WITH TABLE KEY fcurr = i_from tcurr = i_to.
    IF sy-subrc = 0.
      r_factor = ls_fx-factor.
      RETURN.
    ENDIF.

    r_factor = 1.
    DATA lv_n TYPE n LENGTH 8.
    lv_n = i_date.
    DATA lv_inv TYPE tcurf-gdatu.
    lv_inv = 99999999 - lv_n.
    SELECT gdatu, ffact, tfact
      FROM tcurf
      WHERE kurst  = @gc_rate_type
        AND fcurr  = @i_from
        AND tcurr  = @i_to
        AND gdatu >= @lv_inv
      ORDER BY gdatu
      INTO TABLE @DATA(lt_f)
      UP TO 1 ROWS.
    IF sy-subrc = 0 AND lt_f[ 1 ]-ffact <> 0 AND lt_f[ 1 ]-tfact <> 0.
      r_factor = lt_f[ 1 ]-tfact / lt_f[ 1 ]-ffact.
    ENDIF.
    INSERT VALUE #( fcurr = i_from tcurr = i_to factor = r_factor ) INTO TABLE mt_fx.
*   <<< End of change 20260930_01

  ENDMETHOD.


  METHOD amount_of.
*   >>> Begin of change 20260930_01 F-CUONGUS TR DS4K900172 - Kiem chung DS4: so tien theo TCURX, ty gia theo TCURF

    " TCURX chỉ vài chục dòng: nạp một lần cho cả lần chạy
    IF mv_currdec_load = abap_false.
      mv_currdec_load = abap_true.
      SELECT currkey, currdec FROM tcurx INTO TABLE @mt_currdec.
    ENDIF.

    r_amount = i_amount.
    READ TABLE mt_currdec INTO DATA(ls_cd) WITH TABLE KEY currkey = i_waers.
    IF sy-subrc <> 0 OR ls_cd-currdec = 2.
      RETURN.
    ENDIF.
    IF ls_cd-currdec < 2.
      r_amount = i_amount * ipow( base = 10 exp = 2 - ls_cd-currdec ).
    ELSE.
      r_amount = i_amount / ipow( base = 10 exp = ls_cd-currdec - 2 ).
    ENDIF.
*   <<< End of change 20260930_01

  ENDMETHOD.


  METHOD local_currency.

    DATA(lv_local) = param( i_key   = zif_hddt_types=>gc_parm-local_currency
                            i_bukrs = i_bukrs ).
    r_waers = COND #( WHEN lv_local IS INITIAL THEN 'VND' ELSE lv_local ).

  ENDMETHOD.


  METHOD map_list_as_range.

    DATA(lt_map) = config( )->get_map_list( i_provider = space
                                            i_map_type = i_map_type ).
    LOOP AT lt_map ASSIGNING FIELD-SYMBOL(<fs_map>).
      DATA lv_val TYPE zde_hddt_docno.
      lv_val = <fs_map>-sap_value.
      CONDENSE lv_val.
      IF lv_val IS INITIAL.
        CONTINUE.
      ENDIF.
      IF lv_val CA '*+'.
        APPEND VALUE #( sign = 'I' option = 'CP' low = lv_val ) TO rt_range.
      ELSE.
        APPEND VALUE #( sign = 'I' option = 'EQ' low = lv_val ) TO rt_range.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD material_text.

    IF i_matnr IS INITIAL.
      RETURN.
    ENDIF.
    TRY.
        r_text = mt_matnr[ key = i_matnr ]-text.
        RETURN.
      CATCH cx_sy_itab_line_not_found.
    ENDTRY.

*   >>> Begin of change 20260927_20 F-DUBV TR S25K900131 - Review S25 R06 (DB trong vong lap)
*   MAKT nap 1 lan truoc vong lap (PREFETCH_MAT_TEXTS, goi tu SELECT_DOCUMENTS
*   cua ZCL_HDDT_SRC_FI / SD / PO). Khong co trong bo dem = khong co ten.
*    DATA(lv_langu) = text_langu( ).
*    SELECT SINGLE maktx FROM makt
*      WHERE matnr = @i_matnr AND spras = @lv_langu
*      INTO @DATA(lv_maktx).
*    IF sy-subrc <> 0 AND lv_langu <> sy-langu.
*      SELECT SINGLE maktx FROM makt
*        WHERE matnr = @i_matnr AND spras = @sy-langu
*        INTO @lv_maktx.
*    ENDIF.
*    r_text = lv_maktx.
*    INSERT VALUE #( key = i_matnr text = r_text ) INTO TABLE mt_matnr.
*   <<< End of change 20260927_20

  ENDMETHOD.


  METHOD param.

    r_value = config( )->get_param( i_key   = i_key
                                     i_bukrs = i_bukrs ).
    IF r_value IS INITIAL.
      r_value = i_default.
    ENDIF.

  ENDMETHOD.


  METHOD payment_of.
*---------------------------------------------------------------------*
* Header
*---------------------------------------------------------------------*
    DATA(lv_zlsch) = i_zlsch.
    IF lv_zlsch IS INITIAL.
      " Chứng từ không ghi phương thức -> hình thức mặc định (vd 'TM/CK')
      DATA(lv_def) = param( i_key   = zif_hddt_types=>gc_parm-default_payment
                            i_bukrs = i_bukrs ).
      IF lv_def IS INITIAL.
        RETURN.
      ENDIF.
      rs_payment-method_code = lv_def.
      rs_payment-method_name = lv_def.
      RETURN.
    ENDIF.

    " Ánh xạ ở tầng nguồn dùng PROVIDER = blank (không phụ thuộc NCC);
    " adapter có thể ánh xạ lần hai theo NCC nếu cần.
    config( )->map_value( EXPORTING i_provider  = space
                                    i_map_type  = zif_hddt_types=>gc_map_type-payment
                                    i_sap_value = lv_zlsch
                          IMPORTING e_ext_value = DATA(lv_code)
                                    e_ext_text  = DATA(lv_text) ).
    rs_payment-method_code = lv_code.
    rs_payment-method_name = COND #( WHEN lv_text IS NOT INITIAL THEN lv_text ELSE lv_code ).

  ENDMETHOD.


  METHOD prefetch_buyer_docs.

*   >>> Begin of change 20260927_20 F-DUBV TR S25K900131 - Review S25 R06 (DB trong vong lap)
*   Thay SELECT SINGLE BSEC / BNKA va SELECT VBKD UP TO 1 ROWS tung chung
*   tu trong READ_BUYER: doc 1 lan cho ca danh sach cua lan chon nay.
    DATA lt_bsec  TYPE STANDARD TABLE OF ty_bsec_buf WITH EMPTY KEY.
    DATA lt_bank  TYPE SORTED TABLE OF ty_bnka_buf WITH UNIQUE KEY banks bankl.
    DATA lt_aubel TYPE SORTED TABLE OF vbeln WITH UNIQUE KEY table_line.
    DATA lt_vbkd  TYPE STANDARD TABLE OF ty_vbkd_buf WITH EMPTY KEY.

    CLEAR: mt_bsec, mt_bnka, mt_vbkd.

*---- Khach le / NCC vang lai (BSEC) + ten ngan hang (BNKA) ----------*
    IF it_doc IS NOT INITIAL.
      SELECT bukrs, belnr, gjahr, buzei, name1, name2, name3, name4, stras,
             ort01, pstlz, land1, stcd1, stcd3, intad, banks, bankl, bankn
        FROM bsec
        FOR ALL ENTRIES IN @it_doc
        WHERE bukrs = @it_doc-bukrs
          AND belnr = @it_doc-belnr
          AND gjahr = @it_doc-gjahr
        INTO TABLE @lt_bsec.
      " Ban cu SELECT SINGLE lay 1 dong moi chung tu: giu dong BUZEI nho nhat
      SORT lt_bsec BY bukrs belnr gjahr buzei.
      DELETE ADJACENT DUPLICATES FROM lt_bsec COMPARING bukrs belnr gjahr.
      INSERT LINES OF lt_bsec INTO TABLE mt_bsec.

      LOOP AT lt_bsec ASSIGNING FIELD-SYMBOL(<fs_bsec>) WHERE bankl IS NOT INITIAL.
        INSERT VALUE #( banks = <fs_bsec>-banks bankl = <fs_bsec>-bankl ) INTO TABLE lt_bank.
      ENDLOOP.
      IF lt_bank IS NOT INITIAL.
        SELECT banks, bankl, banka
          FROM bnka
          FOR ALL ENTRIES IN @lt_bank
          WHERE banks = @lt_bank-banks
            AND bankl = @lt_bank-bankl
          INTO TABLE @mt_bnka.
      ENDIF.
    ENDIF.

*---- So tham chieu cua khach tren don ban (VBKD-BSTKD) --------------*
    LOOP AT it_aubel INTO DATA(lv_aubel) WHERE table_line IS NOT INITIAL.
      INSERT lv_aubel INTO TABLE lt_aubel.
    ENDLOOP.
    IF lt_aubel IS NOT INITIAL.
      SELECT vbeln, posnr, bstkd
        FROM vbkd
        FOR ALL ENTRIES IN @lt_aubel
        WHERE vbeln = @lt_aubel-table_line
          AND bstkd <> @space
        INTO TABLE @lt_vbkd.
      " = ORDER BY posnr UP TO 1 ROWS cua ban cu: giu POSNR nho nhat moi don
      SORT lt_vbkd BY vbeln posnr.
      DELETE ADJACENT DUPLICATES FROM lt_vbkd COMPARING vbeln.
      INSERT LINES OF lt_vbkd INTO TABLE mt_vbkd.
    ENDIF.
*   <<< End of change 20260927_20

  ENDMETHOD.


  METHOD prefetch_buyer_master.

*   >>> Begin of change 20260928_30 F-DUBV TR S25K900131 - Review S25 R06 (DB trong vong lap)
*   Thay 15 SELECT theo tung khach hang trong BUYER_FROM_BP / BUYER_FROM_KNA1
*   (CVI_CUST_LINK, BUT000, BUT020, ADRC, ADR6, ADR2, BUT0ID, KNA1, BUT0BK,
*   BNKA): doc 1 lan cho moi khach hang cua lan chon nay ma MT_BUYER chua co.
*   Moi cau FOR ALL ENTRIES doc du truong khoa de khong bi gop mat dong trung.
    TYPES: BEGIN OF lty_cvi,
             customer     TYPE cvi_cust_link-customer,
             partner_guid TYPE cvi_cust_link-partner_guid,
           END OF lty_cvi.
    TYPES: BEGIN OF lty_bk_key,
             partner TYPE but0bk-partner,
             bkvid   TYPE but0bk-bkvid,
           END OF lty_bk_key.
    DATA lt_kunnr    TYPE SORTED TABLE OF kunnr WITH UNIQUE KEY table_line.
    DATA lt_bvtyp    TYPE SORTED TABLE OF ty_buyer_key WITH UNIQUE KEY kunnr bvtyp.
    DATA lt_cvi      TYPE STANDARD TABLE OF lty_cvi WITH EMPTY KEY.
    DATA lt_but000   TYPE STANDARD TABLE OF ty_but000_buf WITH EMPTY KEY.
    DATA lt_part     TYPE SORTED TABLE OF bu_partner WITH UNIQUE KEY table_line.
    DATA lt_kunnr_bp TYPE SORTED TABLE OF ty_bp_link_buf WITH UNIQUE KEY kunnr.
    DATA lt_bp       TYPE SORTED TABLE OF bu_partner WITH UNIQUE KEY table_line.
    DATA lt_but020   TYPE STANDARD TABLE OF ty_but020_buf WITH EMPTY KEY.
    DATA lt_bk_key   TYPE SORTED TABLE OF lty_bk_key WITH UNIQUE KEY partner bkvid.
    DATA lt_bank     TYPE SORTED TABLE OF ty_bnka_buf WITH UNIQUE KEY banks bankl.
    DATA lt_addr     TYPE SORTED TABLE OF ad_addrnum WITH UNIQUE KEY table_line.
    DATA lt_adrc     TYPE STANDARD TABLE OF ty_adrc_buf WITH EMPTY KEY.
    DATA lv_partner  TYPE bu_partner.

    CLEAR: mt_bp_link, mt_but000, mt_but020, mt_adrc, mt_adr6, mt_adr2,
           mt_but0id, mt_kna1, mt_but0bk, mt_bp_bnka.

    " Chi cac khach hang ma READ_BUYER con phai doc (chua co trong MT_BUYER)
    LOOP AT it_buyer INTO DATA(ls_key) WHERE kunnr IS NOT INITIAL.
      IF line_exists( mt_buyer[ kunnr = ls_key-kunnr bvtyp = ls_key-bvtyp ] ).
        CONTINUE.
      ENDIF.
      INSERT ls_key-kunnr INTO TABLE lt_kunnr.
      IF ls_key-bvtyp IS NOT INITIAL.
        INSERT ls_key INTO TABLE lt_bvtyp.
      ENDIF.
    ENDLOOP.
    IF lt_kunnr IS INITIAL.
      RETURN.
    ENDIF.

*---- Khach hang -> BP: link CVI (BP theo GUID), khong co link thi so KH = so BP
    SELECT customer, partner_guid
      FROM cvi_cust_link
      FOR ALL ENTRIES IN @lt_kunnr
      WHERE customer = @lt_kunnr-table_line
      INTO TABLE @lt_cvi.
    SORT lt_cvi BY customer partner_guid.
    DELETE ADJACENT DUPLICATES FROM lt_cvi COMPARING customer.

    IF lt_cvi IS NOT INITIAL.
      SELECT partner, partner_guid, type, name_org1, name_org2, name_org3, name_org4,
             name_first, name_last
        FROM but000
        FOR ALL ENTRIES IN @lt_cvi
        WHERE partner_guid = @lt_cvi-partner_guid
        INTO TABLE @lt_but000.
    ENDIF.
    SORT lt_but000 BY partner_guid.
    LOOP AT lt_cvi ASSIGNING FIELD-SYMBOL(<fs_cvi>).
      " Co link nhung GUID khong co BUT000 -> PARTNER rong = khong tim thay BP
      CLEAR lv_partner.
      READ TABLE lt_but000 ASSIGNING FIELD-SYMBOL(<fs_b0>)
           WITH KEY partner_guid = <fs_cvi>-partner_guid BINARY SEARCH.
      IF sy-subrc = 0.
        lv_partner = <fs_b0>-partner.
      ENDIF.
      INSERT VALUE #( kunnr = <fs_cvi>-customer partner = lv_partner ) INTO TABLE mt_bp_link.
    ENDLOOP.
    LOOP AT lt_but000 ASSIGNING <fs_b0>.
      INSERT <fs_b0> INTO TABLE mt_but000.
    ENDLOOP.

    LOOP AT lt_kunnr INTO DATA(lv_kunnr).
      IF NOT line_exists( mt_bp_link[ kunnr = lv_kunnr ] ).
        lv_partner = lv_kunnr.
        INSERT lv_partner INTO TABLE lt_part.
      ENDIF.
    ENDLOOP.
    IF lt_part IS NOT INITIAL.
      CLEAR lt_but000.
      SELECT partner, partner_guid, type, name_org1, name_org2, name_org3, name_org4,
             name_first, name_last
        FROM but000
        FOR ALL ENTRIES IN @lt_part
        WHERE partner = @lt_part-table_line
        INTO TABLE @lt_but000.
      LOOP AT lt_but000 ASSIGNING <fs_b0>.
        INSERT <fs_b0> INTO TABLE mt_but000.
      ENDLOOP.
    ENDIF.

    " Khach hang tim thay BP (cung quy tac voi BUYER_FROM_BP)
    LOOP AT lt_kunnr INTO lv_kunnr.
      READ TABLE mt_bp_link INTO DATA(ls_link) WITH TABLE KEY kunnr = lv_kunnr.
      IF sy-subrc = 0.
        lv_partner = ls_link-partner.
      ELSE.
        lv_partner = lv_kunnr.
      ENDIF.
      IF lv_partner IS NOT INITIAL AND line_exists( mt_but000[ partner = lv_partner ] ).
        INSERT VALUE #( kunnr = lv_kunnr partner = lv_partner ) INTO TABLE lt_kunnr_bp.
        INSERT lv_partner INTO TABLE lt_bp.
      ENDIF.
    ENDLOOP.

*---- Du lieu BP: dia chi, so dinh danh, ngan hang ----------------------*
    IF lt_bp IS NOT INITIAL.
      SELECT partner, addrnumber
        FROM but020
        FOR ALL ENTRIES IN @lt_bp
        WHERE partner = @lt_bp-table_line
        INTO TABLE @lt_but020.
      " = ORDER BY addrnumber DESCENDING UP TO 1 ROWS: so dia chi lon nhat moi BP
      SORT lt_but020 BY partner ASCENDING addrnumber DESCENDING.
      DELETE ADJACENT DUPLICATES FROM lt_but020 COMPARING partner.
      LOOP AT lt_but020 ASSIGNING FIELD-SYMBOL(<fs_b20>).
        INSERT <fs_b20> INTO TABLE mt_but020.
        INSERT <fs_b20>-addrnumber INTO TABLE lt_addr.
      ENDLOOP.

      SELECT partner, type, idnumber
        FROM but0id
        FOR ALL ENTRIES IN @lt_bp
        WHERE partner = @lt_bp-table_line
        INTO TABLE @mt_but0id.

      " Ngan hang chi can cho cap (BP, BVTYP) co tren chung tu
      LOOP AT lt_bvtyp INTO ls_key.
        READ TABLE lt_kunnr_bp INTO DATA(ls_kbp) WITH TABLE KEY kunnr = ls_key-kunnr.
        IF sy-subrc = 0.
          INSERT VALUE #( partner = ls_kbp-partner bkvid = ls_key-bvtyp ) INTO TABLE lt_bk_key.
        ENDIF.
      ENDLOOP.
      IF lt_bk_key IS NOT INITIAL.
        SELECT partner, bkvid, banks, bankl, bankn, accname
          FROM but0bk
          FOR ALL ENTRIES IN @lt_bk_key
          WHERE partner = @lt_bk_key-partner
            AND bkvid   = @lt_bk_key-bkvid
          INTO TABLE @mt_but0bk.
        LOOP AT mt_but0bk ASSIGNING FIELD-SYMBOL(<fs_bk>).
          INSERT VALUE #( banks = <fs_bk>-banks bankl = <fs_bk>-bankl ) INTO TABLE lt_bank.
        ENDLOOP.
        IF lt_bank IS NOT INITIAL.
          SELECT banks, bankl, banka
            FROM bnka
            FOR ALL ENTRIES IN @lt_bank
            WHERE banks = @lt_bank-banks
              AND bankl = @lt_bank-bankl
            INTO TABLE @mt_bp_bnka.
        ENDIF.
      ENDIF.
    ENDIF.

*---- KNA1: MST du phong cua BP va du lieu khach hang co dien -----------*
    SELECT kunnr, name1, name2, stras, ort01, land1, stcd1, stcd3, telf1, adrnr
      FROM kna1
      FOR ALL ENTRIES IN @lt_kunnr
      WHERE kunnr = @lt_kunnr-table_line
      INTO TABLE @mt_kna1.
    " Dia chi KNA1-ADRNR chi dung khi khong tim thay BP (BUYER_FROM_KNA1)
    LOOP AT mt_kna1 ASSIGNING FIELD-SYMBOL(<fs_k1>) WHERE adrnr IS NOT INITIAL.
      IF NOT line_exists( lt_kunnr_bp[ kunnr = <fs_k1>-kunnr ] ).
        INSERT <fs_k1>-adrnr INTO TABLE lt_addr.
      ENDIF.
    ENDLOOP.

*---- ADRC / ADR6 / ADR2 cho moi so dia chi o tren ----------------------*
    IF lt_addr IS NOT INITIAL.
      SELECT addrnumber, date_from, nation, street, str_suppl1, str_suppl2, str_suppl3,
             location, city1, city2, country
        FROM adrc
        FOR ALL ENTRIES IN @lt_addr
        WHERE addrnumber = @lt_addr-table_line
        INTO TABLE @lt_adrc.
      " Ban cu SELECT SINGLE chi theo ADDRNUMBER: giu 1 dong moi dia chi theo
      " thu tu khoa chinh (DATE_FROM, NATION - phien ban quoc te NATION rong truoc)
      SORT lt_adrc BY addrnumber date_from nation.
      DELETE ADJACENT DUPLICATES FROM lt_adrc COMPARING addrnumber.
      LOOP AT lt_adrc ASSIGNING FIELD-SYMBOL(<fs_adrc>).
        INSERT <fs_adrc> INTO TABLE mt_adrc.
      ENDLOOP.

      SELECT addrnumber, persnumber, date_from, consnumber, smtp_addr
        FROM adr6
        FOR ALL ENTRIES IN @lt_addr
        WHERE addrnumber = @lt_addr-table_line
        INTO TABLE @mt_adr6.

      SELECT addrnumber, persnumber, date_from, consnumber, tel_number
        FROM adr2
        FOR ALL ENTRIES IN @lt_addr
        WHERE addrnumber = @lt_addr-table_line
        INTO TABLE @mt_adr2.
    ENDIF.
*   <<< End of change 20260928_30

  ENDMETHOD.


  METHOD prefetch_item_texts.

*   >>> Begin of change 20260927_01 F-DUBV TR S25K900131 - Review S25 (SELECT trong vong lap)
*   Dung ten text GIONG HET ITEM_NAME (ITEM_TEXT_IDS 'ID:OBJECT;...', VBBP =
*   VBELN+POSNR, MATERIAL = MATNR) roi doc STXH MOT lan cho ca danh sach.
    TYPES: BEGIN OF lty_req,
             tdobject TYPE stxh-tdobject,
             tdname   TYPE stxh-tdname,
             tdid     TYPE stxh-tdid,
           END OF lty_req.
    DATA lt_req  TYPE SORTED TABLE OF lty_req WITH UNIQUE KEY tdobject tdname tdid.
    DATA lv_name TYPE tdobname.

    DATA(lv_ids) = param( i_key     = zif_hddt_types=>gc_parm-item_text_ids
                          i_bukrs   = i_bukrs
                          i_default = `GRUN:MATERIAL` ).
    SPLIT lv_ids AT ';' INTO TABLE DATA(lt_ids).
    LOOP AT lt_ids ASSIGNING FIELD-SYMBOL(<fs_pair>).
      SPLIT <fs_pair> AT ':' INTO DATA(lv_id) DATA(lv_obj).
      CONDENSE: lv_id, lv_obj.
      TRANSLATE: lv_id TO UPPER CASE, lv_obj TO UPPER CASE.
      IF lv_id IS INITIAL OR lv_obj IS INITIAL.
        CONTINUE.
      ENDIF.
      LOOP AT it_keys ASSIGNING FIELD-SYMBOL(<fs_key>).
        CLEAR lv_name.
        CASE lv_obj.
          WHEN 'VBBP'.
            IF <fs_key>-vbeln IS INITIAL.
              CONTINUE.
            ENDIF.
            lv_name = |{ <fs_key>-vbeln }{ <fs_key>-posnr }|.
          WHEN 'MATERIAL'.
            IF <fs_key>-matnr IS INITIAL.
              CONTINUE.
            ENDIF.
            lv_name = <fs_key>-matnr.
          WHEN OTHERS.
            CONTINUE.
        ENDCASE.
        INSERT VALUE #( tdobject = CONV #( lv_obj )
                        tdname   = lv_name
                        tdid     = CONV #( lv_id ) ) INTO TABLE lt_req.
      ENDLOOP.
    ENDLOOP.

    IF lt_req IS INITIAL.
      RETURN.
    ENDIF.

    SELECT tdobject, tdname, tdid, tdspras
      FROM stxh
      FOR ALL ENTRIES IN @lt_req
      WHERE tdobject = @lt_req-tdobject
        AND tdname   = @lt_req-tdname
        AND tdid     = @lt_req-tdid
      INTO TABLE @DATA(lt_stxh).
    LOOP AT lt_stxh ASSIGNING FIELD-SYMBOL(<fs_stxh>).
      " Nhieu ngon ngu cung khoa: giu dong dau (ban cu SELECT SINGLE cung lay 1 dong bat ky)
      INSERT VALUE #( tdobject = <fs_stxh>-tdobject
                      tdname   = <fs_stxh>-tdname
                      tdid     = <fs_stxh>-tdid
                      tdspras  = <fs_stxh>-tdspras ) INTO TABLE mt_stxh.
    ENDLOOP.
*   <<< End of change 20260927_01

  ENDMETHOD.


  METHOD prefetch_mat_texts.

*   >>> Begin of change 20260927_20 F-DUBV TR S25K900131 - Review S25 R06 (DB trong vong lap)
*   Thay SELECT SINGLE MAKT tung vat tu trong MATERIAL_TEXT: doc 1 lan moi
*   vat tu chua co trong bo dem, giu dung thu tu ngon ngu TEXT_LANGU roi
*   sy-langu. Vat tu khong co ten van ghi vao bo dem (ten rong) nhu ban cu.
    DATA lt_req   TYPE SORTED TABLE OF matnr WITH UNIQUE KEY table_line.
    DATA lv_maktx TYPE makt-maktx.

    LOOP AT it_matnr INTO DATA(lv_matnr) WHERE table_line IS NOT INITIAL.
      IF line_exists( mt_matnr[ key = lv_matnr ] ).
        CONTINUE.
      ENDIF.
      INSERT lv_matnr INTO TABLE lt_req.
    ENDLOOP.
    IF lt_req IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lv_langu) = text_langu( ).
    SELECT matnr, spras, maktx
      FROM makt
      FOR ALL ENTRIES IN @lt_req
      WHERE matnr = @lt_req-table_line
        AND ( spras = @lv_langu OR spras = @sy-langu )
      INTO TABLE @DATA(lt_makt).
    SORT lt_makt BY matnr spras.

    LOOP AT lt_req INTO lv_matnr.
      CLEAR lv_maktx.
      READ TABLE lt_makt INTO DATA(ls_makt)
           WITH KEY matnr = lv_matnr spras = lv_langu BINARY SEARCH.
      IF sy-subrc = 0.
        lv_maktx = ls_makt-maktx.
      ELSEIF lv_langu <> sy-langu.
        READ TABLE lt_makt INTO ls_makt
             WITH KEY matnr = lv_matnr spras = sy-langu BINARY SEARCH.
        IF sy-subrc = 0.
          lv_maktx = ls_makt-maktx.
        ENDIF.
      ENDIF.
      INSERT VALUE #( key = lv_matnr text = CONV string( lv_maktx ) ) INTO TABLE mt_matnr.
    ENDLOOP.
*   <<< End of change 20260927_20

  ENDMETHOD.


  METHOD prefetch_seller.

*   >>> Begin of change 20260927_20 F-DUBV TR S25K900131 - Review S25 R06 (DB trong vong lap)
*   Chuyen nguyen van phan doc DB cua READ_SELLER sang day, goi 1 lan.
    DATA ls_seller TYPE zif_hddt_types=>ty_seller.

    IF line_exists( mt_seller[ bukrs = i_bukrs ] ).
      RETURN.
    ENDIF.

    SELECT SINGLE bukrs, butxt, stceg, adrnr, land1
      FROM t001
      WHERE bukrs = @i_bukrs
      INTO @DATA(ls_t001).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    ls_seller-tax_code = ls_t001-stceg.
    ls_seller-name     = ls_t001-butxt.

    SELECT SINGLE name1, name2, street, str_suppl1, str_suppl2, str_suppl3,
                  location, city2, city1, tel_number, fax_number, country
      FROM adrc
      WHERE addrnumber = @ls_t001-adrnr
      INTO @DATA(ls_adrc).
    IF sy-subrc = 0.
      ls_seller-name = |{ ls_adrc-name1 } { ls_adrc-name2 }|.
      CONDENSE ls_seller-name.
      ls_seller-address = |{ ls_adrc-street } { ls_adrc-str_suppl1 }, { ls_adrc-str_suppl2 }, | &&
                          |{ ls_adrc-str_suppl3 }, { ls_adrc-location }, { ls_adrc-city2 }, { ls_adrc-city1 }|.
      clean_address( EXPORTING i_land1 = ls_adrc-country
                               i_bukrs = i_bukrs
                     CHANGING  c_addr  = ls_seller-address ).
      ls_seller-phone = ls_adrc-tel_number.
    ENDIF.

    SELECT smtp_addr FROM adr6
      WHERE addrnumber = @ls_t001-adrnr
      ORDER BY consnumber
      INTO TABLE @DATA(lt_adr6)
      UP TO 1 ROWS.
    IF sy-subrc = 0.
      ls_seller-email = lt_adr6[ 1 ]-smtp_addr.
    ENDIF.

    INSERT VALUE #( bukrs = i_bukrs seller = ls_seller ) INTO TABLE mt_seller.
*   <<< End of change 20260927_20

  ENDMETHOD.


  METHOD prefetch_tax_cond.

*   >>> Begin of change 20260927_01 F-DUBV TR S25K900131 - Review S25 (SELECT trong vong lap)
    DATA lv_kschl TYPE kschl.
    lv_kschl = param( i_key     = zif_hddt_types=>gc_parm-tax_cond_type
                      i_bukrs   = i_bukrs
                      i_default = `MWAS` ).
    IF line_exists( mt_taxcond_done[ bukrs = i_bukrs kschl = lv_kschl ] ).
      RETURN.
    ENDIF.

    SELECT SINGLE land1 FROM t001 WHERE bukrs = @i_bukrs INTO @DATA(lv_land1).

    " A003 trên hệ này không có DATBI (một KNUMH cho mỗi khoá) nên
    " chọn theo KOPOS nhỏ nhất của KONP (bộ đệm sắp theo KOPOS)
    SELECT a~mwskz AS mwskz, k~kopos AS kopos, k~kbetr AS kbetr
      FROM a003 AS a INNER JOIN konp AS k ON k~knumh = a~knumh
      WHERE a~kappl = 'TX'
        AND a~kschl = @lv_kschl
        AND a~aland = @lv_land1
        AND k~loevm_ko = @space
      INTO TABLE @DATA(lt_konp).

    LOOP AT lt_konp ASSIGNING FIELD-SYMBOL(<fs_konp>).
      INSERT VALUE #( bukrs = i_bukrs
                      kschl = lv_kschl
                      mwskz = <fs_konp>-mwskz
                      kopos = <fs_konp>-kopos
                      kbetr = <fs_konp>-kbetr ) INTO TABLE mt_taxcond.
    ENDLOOP.
    INSERT VALUE #( bukrs = i_bukrs kschl = lv_kschl ) INTO TABLE mt_taxcond_done.
*   <<< End of change 20260927_01

  ENDMETHOD.


  METHOD rate_summary.

    DATA lv_first TYPE zif_hddt_types=>ty_rate.
    DATA lv_has   TYPE abap_bool.

    LOOP AT it_items ASSIGNING FIELD-SYMBOL(<fs_it>) WHERE item_type <> '3'.
      IF lv_has = abap_false.
        lv_first = <fs_it>-tax_rate.
        lv_has   = abap_true.
      ELSEIF <fs_it>-tax_rate <> lv_first.
        r_text = 'Nhiều loại'.
        RETURN.
      ENDIF.
    ENDLOOP.

    IF lv_has = abap_true.
      r_text = rate_text( lv_first ).
    ENDIF.

  ENDMETHOD.


  METHOD rate_text.

    IF i_rate >= 0.
      r_text = |{ zcl_hddt_json=>format_number( i_value    = i_rate
                                                   i_decimals = 0 ) }%|.
    ELSE.
      " Thuế suất âm (-1 KCT, -2 KKKNT...) -> nhãn từ ánh xạ
      config( )->map_value( EXPORTING i_provider  = space
                                      i_map_type  = zif_hddt_types=>gc_map_type-tax_rate
                                      i_sap_value = i_rate
                            IMPORTING e_ext_text  = DATA(lv_txt) ).
      r_text = lv_txt.
    ENDIF.

  ENDMETHOD.


  METHOD read_buyer.
*---------------------------------------------------------------------*
* Người mua — port từ ZFM_GET_BUYER / get_customer_detail
*---------------------------------------------------------------------*
    rs_buyer-code = i_kunnr.

*---- (1) Khách lẻ: dữ liệu nhập tay trên chứng từ (BSEC) -----------*
    IF i_belnr IS NOT INITIAL.
*   >>> Begin of change 20260927_20 F-DUBV TR S25K900131 - Review S25 R06 (DB trong vong lap)
*   BSEC / BNKA nap 1 lan truoc vong lap (PREFETCH_BUYER_DOCS)
*      SELECT SINGLE name1, name2, name3, name4, stras, ort01, pstlz,
*                    land1, stcd1, stcd3, intad, banks, bankl, bankn
*        FROM bsec
*        WHERE bukrs = @i_bukrs
*          AND belnr = @i_belnr
*          AND gjahr = @i_gjahr
*        INTO @DATA(ls_bsec).
      READ TABLE mt_bsec INTO DATA(ls_bsec)
           WITH TABLE KEY bukrs = i_bukrs
                          belnr = i_belnr
                          gjahr = i_gjahr.
*   <<< End of change 20260927_20
      IF sy-subrc = 0.
        rs_buyer-one_time   = abap_true.
        rs_buyer-legal_name = |{ ls_bsec-name1 } { ls_bsec-name2 } { ls_bsec-name3 } { ls_bsec-name4 }|.
        CONDENSE rs_buyer-legal_name.
        rs_buyer-address    = |{ ls_bsec-stras }, { ls_bsec-ort01 }|.
        clean_address( EXPORTING i_land1 = ls_bsec-land1
                                 i_bukrs = i_bukrs
                       CHANGING  c_addr  = rs_buyer-address ).
        rs_buyer-tax_code   = COND #( WHEN ls_bsec-stcd1 IS NOT INITIAL
                                      THEN ls_bsec-stcd1 ELSE ls_bsec-stcd3 ).
        rs_buyer-email      = ls_bsec-intad.
        rs_buyer-bank_acct  = ls_bsec-bankn.
        IF ls_bsec-bankl IS NOT INITIAL.
*   >>> Begin of change 20260927_20 F-DUBV TR S25K900131 - Review S25 R06 (DB trong vong lap)
*          SELECT SINGLE banka FROM bnka
*            WHERE banks = @ls_bsec-banks AND bankl = @ls_bsec-bankl
*            INTO @DATA(lv_banka).
*          IF sy-subrc = 0.
*            rs_buyer-bank_name = lv_banka.
*          ENDIF.
          READ TABLE mt_bnka INTO DATA(ls_bnka)
               WITH TABLE KEY banks = ls_bsec-banks
                              bankl = ls_bsec-bankl.
          IF sy-subrc = 0.
            rs_buyer-bank_name = ls_bnka-banka.
          ENDIF.
*   <<< End of change 20260927_20
        ENDIF.
        " Khách lẻ không có mã BP -> không cache
        RETURN.
      ENDIF.
    ENDIF.

    IF i_kunnr IS INITIAL.
      RETURN.
    ENDIF.

*---- (2) Cache theo mã khách -----------------------------------------*
    TRY.
*   >>> Begin of change 20260927_20 F-DUBV TR S25K900131 - Review S25 bug MT_BUYER theo BVTYP
*        rs_buyer = mt_buyer[ kunnr = i_kunnr ]-buyer.
        rs_buyer = mt_buyer[ kunnr = i_kunnr bvtyp = i_bvtyp ]-buyer.
*   <<< End of change 20260927_20
      CATCH cx_sy_itab_line_not_found.
        IF buyer_from_bp( EXPORTING i_kunnr = i_kunnr
                                    i_bukrs = i_bukrs
                                    i_bvtyp = i_bvtyp
                          CHANGING  cs_buyer = rs_buyer ) = abap_false.
          buyer_from_kna1( EXPORTING i_kunnr = i_kunnr
                                     i_bukrs = i_bukrs
                           CHANGING  cs_buyer = rs_buyer ).
        ENDIF.
*   >>> Begin of change 20260927_20 F-DUBV TR S25K900131 - Review S25 bug MT_BUYER theo BVTYP
*        INSERT VALUE #( kunnr = i_kunnr buyer = rs_buyer ) INTO TABLE mt_buyer.
        INSERT VALUE #( kunnr = i_kunnr bvtyp = i_bvtyp buyer = rs_buyer ) INTO TABLE mt_buyer.
*   <<< End of change 20260927_20
    ENDTRY.

*---- (3) Số tham chiếu của khách hàng trên đơn bán (VBKD-BSTKD) ------*
    IF i_aubel IS NOT INITIAL.
*   >>> Begin of change 20260927_20 F-DUBV TR S25K900131 - Review S25 R06 (DB trong vong lap)
*   VBKD nap 1 lan truoc vong lap (PREFETCH_BUYER_DOCS): bo dem giu dong
*   POSNR nho nhat co BSTKD cua moi don ban = ORDER BY posnr UP TO 1 ROWS.
*      SELECT bstkd FROM vbkd
*        WHERE vbeln = @i_aubel
*          AND bstkd <> @space
*        ORDER BY posnr
*        INTO TABLE @DATA(lt_vbkd)
*        UP TO 1 ROWS.
*      IF sy-subrc = 0.
*        rs_buyer-ref_no = lt_vbkd[ 1 ]-bstkd.
*      ENDIF.
      READ TABLE mt_vbkd INTO DATA(ls_vbkd)
           WITH TABLE KEY vbeln = i_aubel.
      IF sy-subrc = 0.
        rs_buyer-ref_no = ls_vbkd-bstkd.
      ENDIF.
*   <<< End of change 20260927_20
    ENDIF.

  ENDMETHOD.


  METHOD read_seller.
*---------------------------------------------------------------------*
* Người bán — port từ ZFM_GET_SELLER
*---------------------------------------------------------------------*
    TRY.
        rs_seller = mt_seller[ bukrs = i_bukrs ]-seller.
        RETURN.
      CATCH cx_sy_itab_line_not_found.
    ENDTRY.

*   >>> Begin of change 20260927_20 F-DUBV TR S25K900131 - Review S25 R06 (DB trong vong lap)
*   T001 / ADRC / ADR6 nap 1 lan truoc vong lap (PREFETCH_SELLER, goi tu
*   SELECT_DOCUMENTS cua ZCL_HDDT_SRC_FI / SD / PO). Khong co trong bo dem =
*   khong co cong ty (giong ban cu: T001 khong co -> tra rong).
*   SELECT SINGLE bukrs, butxt, stceg, adrnr, land1
*     FROM t001
*     WHERE bukrs = @i_bukrs
*     INTO @DATA(ls_t001).
*   IF sy-subrc <> 0.
*     RETURN.
*   ENDIF.
*
*   rs_seller-tax_code = ls_t001-stceg.
*   rs_seller-name     = ls_t001-butxt.
*
*   SELECT SINGLE name1, name2, street, str_suppl1, str_suppl2, str_suppl3,
*                 location, city2, city1, tel_number, fax_number, country
*     FROM adrc
*     WHERE addrnumber = @ls_t001-adrnr
*     INTO @DATA(ls_adrc).
*   IF sy-subrc = 0.
*     rs_seller-name = |{ ls_adrc-name1 } { ls_adrc-name2 }|.
*     CONDENSE rs_seller-name.
*     rs_seller-address = |{ ls_adrc-street } { ls_adrc-str_suppl1 }, { ls_adrc-str_suppl2 }, | &&
*                         |{ ls_adrc-str_suppl3 }, { ls_adrc-location }, { ls_adrc-city2 }, { ls_adrc-city1 }|.
*     clean_address( EXPORTING i_land1 = ls_adrc-country
*                              i_bukrs = i_bukrs
*                    CHANGING  c_addr  = rs_seller-address ).
*     rs_seller-phone = ls_adrc-tel_number.
*   ENDIF.
*
*   SELECT smtp_addr FROM adr6
*     WHERE addrnumber = @ls_t001-adrnr
*     ORDER BY consnumber
*     INTO TABLE @DATA(lt_adr6)
*     UP TO 1 ROWS.
*   IF sy-subrc = 0.
*     rs_seller-email = lt_adr6[ 1 ]-smtp_addr.
*   ENDIF.
*
*   INSERT VALUE #( bukrs = i_bukrs seller = rs_seller ) INTO TABLE mt_seller.
*   <<< End of change 20260927_20

  ENDMETHOD.


  METHOD read_text.

    DATA lt_lines TYPE STANDARD TABLE OF tline WITH EMPTY KEY.

    " Kiểm tra header trước để lấy đúng ngôn ngữ đã lưu (long text
    " thường chỉ có 1 ngôn ngữ và không trùng ngôn ngữ đăng nhập).
*   >>> Begin of change 20260927_01 F-DUBV TR S25K900131 - Review S25 (SELECT trong vong lap)
*   Header STXH lay tu bo dem MT_STXH do PREFETCH_ITEM_TEXTS nap 1 lan truoc
*   vong lap dong hang (ZCL_HDDT_SRC_FI / ZCL_HDDT_SRC_SD->SELECT_DOCUMENTS).
    READ TABLE mt_stxh INTO DATA(ls_stxh)
         WITH TABLE KEY tdobject = i_object
                        tdname   = i_name
                        tdid     = i_id.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    DATA(lv_spras) = ls_stxh-tdspras.
*   <<< End of change 20260927_01

    CALL FUNCTION 'READ_TEXT'
      EXPORTING
        id       = i_id
        language = lv_spras
        name     = i_name
        object   = i_object
      TABLES
        lines    = lt_lines
      EXCEPTIONS
        OTHERS   = 1.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    LOOP AT lt_lines ASSIGNING FIELD-SYMBOL(<fs_line>).
      r_text = COND #( WHEN r_text IS INITIAL THEN <fs_line>-tdline
                        ELSE |{ r_text } { <fs_line>-tdline }| ).
    ENDLOOP.
    CONDENSE r_text.

  ENDMETHOD.


  METHOD read_vendor.

*---- (1) NCC vãng lai: dữ liệu nhập tay trên chứng từ (BSEC) ---------*
    IF i_belnr IS NOT INITIAL.
      rs_buyer = read_buyer( i_kunnr = space
                             i_bukrs = i_bukrs
                             i_belnr = i_belnr
                             i_gjahr = i_gjahr ).
      IF rs_buyer-one_time = abap_true.
        rs_buyer-code = i_lifnr.
        RETURN.
      ENDIF.
      CLEAR rs_buyer.
    ENDIF.

    rs_buyer-code = i_lifnr.
    IF i_lifnr IS INITIAL.
      RETURN.
    ENDIF.

*---- (2) Bộ đệm theo mã NCC ------------------------------------------*
    TRY.
        rs_buyer = mt_vendor[ kunnr = i_lifnr ]-buyer.
        RETURN.
      CATCH cx_sy_itab_line_not_found.
    ENDTRY.

    SELECT SINGLE name1, name2, stras, ort01, land1, stcd1, stcd3, telf1, adrnr
      FROM lfa1
      WHERE lifnr = @i_lifnr
      INTO @DATA(ls_lfa1).
    IF sy-subrc = 0.
      rs_buyer-legal_name = |{ ls_lfa1-name1 } { ls_lfa1-name2 }|.
      CONDENSE rs_buyer-legal_name.
      rs_buyer-tax_code = COND #( WHEN ls_lfa1-stcd1 IS NOT INITIAL
                                  THEN ls_lfa1-stcd1 ELSE ls_lfa1-stcd3 ).
      rs_buyer-phone    = ls_lfa1-telf1.
      rs_buyer-address  = |{ ls_lfa1-stras }, { ls_lfa1-ort01 }|.

      IF ls_lfa1-adrnr IS NOT INITIAL.
        SELECT SINGLE street, str_suppl1, str_suppl2, str_suppl3, location, city1, city2, country
          FROM adrc
          WHERE addrnumber = @ls_lfa1-adrnr
          INTO @DATA(ls_adrc).
        IF sy-subrc = 0.
          rs_buyer-address = |{ ls_adrc-street } { ls_adrc-str_suppl1 }, { ls_adrc-str_suppl2 }, | &&
                             |{ ls_adrc-str_suppl3 }, { ls_adrc-location }, { ls_adrc-city2 }, { ls_adrc-city1 }|.
          ls_lfa1-land1 = ls_adrc-country.
        ENDIF.
        SELECT smtp_addr FROM adr6
          WHERE addrnumber = @ls_lfa1-adrnr
          ORDER BY consnumber
          INTO TABLE @DATA(lt_adr6)
          UP TO 1 ROWS.
        IF sy-subrc = 0.
          rs_buyer-email = lt_adr6[ 1 ]-smtp_addr.
        ENDIF.
      ENDIF.

      clean_address( EXPORTING i_land1 = ls_lfa1-land1
                               i_bukrs = i_bukrs
                     CHANGING  c_addr  = rs_buyer-address ).
    ENDIF.
    INSERT VALUE #( kunnr = i_lifnr buyer = rs_buyer ) INTO TABLE mt_vendor.

  ENDMETHOD.


  METHOD reconcile_tax.

    LOOP AT it_tax ASSIGNING FIELD-SYMBOL(<fs_tax>).
      DATA lv_sum  TYPE zif_hddt_types=>ty_amount.
      DATA lv_last TYPE i.
      CLEAR: lv_sum, lv_last.

      LOOP AT ct_items ASSIGNING FIELD-SYMBOL(<fs_it>)
           WHERE tax_rate = <fs_tax>-tax_rate
             AND item_type <> '3'.
        lv_sum  = lv_sum + <fs_it>-tax_amount.
        lv_last = sy-tabix.
      ENDLOOP.

      IF lv_last > 0 AND lv_sum <> <fs_tax>-tax_amt.
        ASSIGN ct_items[ lv_last ] TO <fs_it>.
        <fs_it>-tax_amount = <fs_it>-tax_amount + ( <fs_tax>-tax_amt - lv_sum ).
        <fs_it>-total      = <fs_it>-amount + <fs_it>-tax_amount.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD registry_of.

    TRY.
        rs_reg = mt_reg[ bukrs     = i_bukrs
                         gjahr     = i_gjahr
                         src_type  = i_src_type
                         src_docno = i_docno ].
      CATCH cx_sy_itab_line_not_found.
        CLEAR rs_reg.
        rs_reg-status = zif_hddt_types=>gc_status-not_sent.
    ENDTRY.
    IF rs_reg-status IS INITIAL.
      rs_reg-status = zif_hddt_types=>gc_status-not_sent.
    ENDIF.

  ENDMETHOD.


  METHOD tax_rate_of.
*---------------------------------------------------------------------*
* Thuế
*---------------------------------------------------------------------*
    DATA lv_char TYPE c LENGTH 20.

    IF i_mwskz IS INITIAL.
      RETURN.
    ENDIF.

    " (1) Cấu hình MAP TAXRATE: MWSKZ -> thuế suất (kể cả -1 KCT, -2 KKKNT)
    config( )->map_value( EXPORTING i_provider  = space
                                    i_map_type  = zif_hddt_types=>gc_map_type-tax_rate
                                    i_sap_value = i_mwskz
                          IMPORTING e_ext_value = DATA(lv_ext) ).
    lv_char = lv_ext.
    CONDENSE lv_char NO-GAPS.
    IF lv_char IS NOT INITIAL AND lv_char <> i_mwskz
       AND lv_char CO '0123456789.- '.
      r_rate = lv_char.
      RETURN.
    ENDIF.

    " (2) Bảng thuế của chứng từ (BSET-KBETR lưu 1/10 %: 10% -> 100)
    TRY.
        r_rate = it_rate[ mwskz = i_mwskz ]-kbetr / 10.
        RETURN.
      CATCH cx_sy_itab_line_not_found.
    ENDTRY.

    " (3) Điều kiện thuế đầu ra A003/KONP theo nước của công ty
    DATA(lv_kschl) = param( i_key     = zif_hddt_types=>gc_parm-tax_cond_type
                            i_bukrs   = i_bukrs
                            i_default = `MWAS` ).
*   >>> Begin of change 20260927_01 F-DUBV TR S25K900131 - Review S25 (SELECT trong vong lap)
*   A003/KONP cua ca nuoc cong ty nap 1 lan (PREFETCH_TAX_COND), o day chi
*   doc bo nho. Bo dem sap theo KOPOS tang dan -> dong dau = ORDER BY kopos
*   UP TO 1 ROWS nhu ban cu.
*   PREFETCH_TAX_COND do lop con goi TRUOC vong lap (SELECT_DOCUMENTS cua
*   ZCL_HDDT_SRC_FI / ZCL_HDDT_SRC_SD) - o day KHONG goi de khong co SELECT trong vong lap.
    DATA(lv_kschl_c) = CONV kschl( lv_kschl ).
    LOOP AT mt_taxcond INTO DATA(ls_tc)
         WHERE bukrs = i_bukrs
           AND kschl = lv_kschl_c
           AND mwskz = i_mwskz.
      r_rate = ls_tc-kbetr / 10.
      EXIT.
    ENDLOOP.
*   <<< End of change 20260927_01

  ENDMETHOD.


  METHOD text_langu.

    DATA(lv_parm) = param( i_key   = zif_hddt_types=>gc_parm-text_langu
                           i_bukrs = i_bukrs ).
    IF lv_parm IS INITIAL.
      r_langu = sy-langu.
    ELSE.
      " Cho phép khai 'E' hoặc 'EN'
      IF strlen( lv_parm ) = 1.
        r_langu = lv_parm.
      ELSE.
        DATA lv_laiso TYPE laiso.
        lv_laiso = lv_parm.
        SELECT SINGLE spras FROM t002
          WHERE laiso = @lv_laiso
          INTO @r_langu.
        IF sy-subrc <> 0.
          r_langu = sy-langu.
        ENDIF.
      ENDIF.
    ENDIF.

  ENDMETHOD.


  METHOD unit_text.
*---------------------------------------------------------------------*
* Dòng hàng
*---------------------------------------------------------------------*
    IF i_meins IS INITIAL.
      RETURN.
    ENDIF.
    TRY.
        r_text = mt_unit[ key = i_meins ]-text.
        RETURN.
      CATCH cx_sy_itab_line_not_found.
    ENDTRY.

    DATA(lv_langu) = text_langu( ).
    SELECT SINGLE msehl FROM t006a
      WHERE spras = @lv_langu AND msehi = @i_meins
      INTO @DATA(lv_msehl).
    IF sy-subrc <> 0 AND lv_langu <> sy-langu.
      SELECT SINGLE msehl FROM t006a
        WHERE spras = @sy-langu AND msehi = @i_meins
        INTO @lv_msehl.
    ENDIF.
    r_text = COND #( WHEN lv_msehl IS NOT INITIAL THEN lv_msehl ELSE i_meins ).
    INSERT VALUE #( key = i_meins text = r_text ) INTO TABLE mt_unit.

  ENDMETHOD.
ENDCLASS.
