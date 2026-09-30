*----------------------------------------------------------------------*
***INCLUDE LZFG_VM_HDDTF01.
*----------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*& Routine cho Event 01 (BEFORE_SAVE) cua Table Maintenance
*& Function group  : ZFG_VM_HDDT
*& Include dich den : LZFG_VM_HDDTF01  (include NGUOI DUNG, do SE54 tao ra
*&                    khi khai event; TUYET DOI khong dat vao
*&                    LZFG_VM_HDDTF00 vi include do bi sinh lai moi lan
*&                    regenerate view va code se bi xoa)
*&
*& Dung chung cho CA 9 view cau hinh HDDT:
*&   ZTB_HDDT_PROV  ZTB_HDDT_CONN  ZTB_HDDT_ACT   ZTB_HDDT_CRED
*&   ZTB_HDDT_STAT  ZTB_HDDT_MAP   ZTB_HDDT_PARM  ZTB_HDDT_DATE
*&   ZTB_HDDT_SRC
*& Khai CUNG MOT ten form o event 01 cua tung view trong SE54 - khong
*& can 9 ban copy.
*&
*& [Vi sao can routine nay]
*& SM30 KHONG tu dien 4 truong vet. Khong co event 01 thi
*& CREATED_BY / CHANGED_BY / CREATED_AT / CHANGED_AT luon trong khi
*& nguoi dung sua cau hinh bang SM30, va muc dich bo sung cac truong nay
*& coi nhu mat. Code ABAP cua package chi dien duoc 3 duong:
*& ZPG_HDDT_SETUP, nap mau payload, va ghi dong hang.
*&
*& [Bien toan cuc dung o day - deu cua SVIM, da kiem cu phap tren S25]
*&   total              bang trong cua maintenance, CO header line
*&   extract            ban dang hien tren luoi
*&   <action>           'N' them moi / 'U' sua / 'D' xoa
*&   neuer_eintrag      hang so 'N'   (LSVIMDAT)
*&   aendern            hang so 'U'   (LSVIMDAT)
*&   <vim_total_struc>  tro toi dong TOTAL hien hanh
*&   <vim_xtotal_key>   khoa de doc nguoc EXTRACT
*&---------------------------------------------------------------------*
FORM zalv_set_audit.

  DATA lv_ts TYPE timestampl.
  FIELD-SYMBOLS <fs_val> TYPE any.

  " FS v0.17 muc 3.2: moi Company code + Fiscal Year chi duoc tich Default
  " cho DUNG MOT dai so. Kiem TRUOC khi dong dau vet de lan luu bi chan
  " khong de lai dong nao da sua CHANGED_BY/CHANGED_AT.
  IF vim_view_name = 'ZTB_HDDT_CRED'.
    PERFORM zalv_check_default.
    IF vim_abort_saving = abap_true.
      RETURN.
    ENDIF.
  ENDIF.

  GET TIME STAMP FIELD lv_ts.        " TIMESTAMPL gio UTC

  LOOP AT total.

    " Chi dong THEM MOI va dong SUA; dong xoa va dong khong doi bo qua
    IF <action> <> neuer_eintrag AND <action> <> aendern.
      CONTINUE.
    ENDIF.

    " ASSIGN COMPONENT nen bang nao khong co 4 truong vet nay thi
    " lang le bo qua - dung chung mot routine cho ca 9 view
    IF <action> = neuer_eintrag.
      ASSIGN COMPONENT 'CREATED_BY' OF STRUCTURE <vim_total_struc>
             TO <fs_val>.
      IF sy-subrc = 0 AND <fs_val> IS INITIAL.
        <fs_val> = sy-uname.
      ENDIF.
      ASSIGN COMPONENT 'CREATED_AT' OF STRUCTURE <vim_total_struc>
             TO <fs_val>.
      IF sy-subrc = 0 AND <fs_val> IS INITIAL.
        <fs_val> = lv_ts.
      ENDIF.
    ENDIF.

    " Nguoi/luc sua gan nhat: ghi de ca khi them moi lan khi sua
    ASSIGN COMPONENT 'CHANGED_BY' OF STRUCTURE <vim_total_struc>
           TO <fs_val>.
    IF sy-subrc = 0.
      <fs_val> = sy-uname.
    ENDIF.
    ASSIGN COMPONENT 'CHANGED_AT' OF STRUCTURE <vim_total_struc>
           TO <fs_val>.
    IF sy-subrc = 0.
      <fs_val> = lv_ts.
    ENDIF.

    MODIFY total.

    " EXTRACT la ban dang hien tren luoi. Khong dong bo thi man hinh van
    " hien gia tri cu cho toi lan doc lai.
    READ TABLE extract WITH KEY <vim_xtotal_key>.
    IF sy-subrc = 0.
      extract = total.
      MODIFY extract INDEX sy-tabix.
    ENDIF.

  ENDLOOP.

ENDFORM.


*&---------------------------------------------------------------------*
*& Form ZALV_CHECK_DEFAULT
*&---------------------------------------------------------------------*
*& Goi tu ZALV_SET_AUDIT khi luu view ZTB_HDDT_CRED. Gom cac dong con
*& hieu luc cua TOTAL (bo dong da xoa) roi giao cho
*& ZCL_HDDT_CONFIG=>CHECK_DEFAULT - cung mot quy tac voi luc chuong
*& trinh chon dai so, khong viet hai lan.
*& Vi pham: bao message 065 va dat VIM_ABORT_SAVING de SM30 huy lan luu.
*&---------------------------------------------------------------------*
FORM zalv_check_default.

  TYPES: BEGIN OF lty_row,
           bukrs    TYPE bukrs,
           gjahr    TYPE gjahr,
           xdefault TYPE xfeld,
           xactive  TYPE xfeld,
         END OF lty_row.
  DATA lt_row TYPE STANDARD TABLE OF lty_row WITH EMPTY KEY.
  DATA ls_row TYPE lty_row.
  FIELD-SYMBOLS <fs_f> TYPE any.

  LOOP AT total.
    " Dong da xoa (ke ca dong moi them roi xoa) khong tinh
    IF <action> = geloescht OR <action> = neuer_geloescht.
      CONTINUE.
    ENDIF.
    CLEAR ls_row.
    ASSIGN COMPONENT 'BUKRS' OF STRUCTURE <vim_total_struc> TO <fs_f>.
    IF sy-subrc = 0.
      ls_row-bukrs = <fs_f>.
    ENDIF.
    ASSIGN COMPONENT 'GJAHR' OF STRUCTURE <vim_total_struc> TO <fs_f>.
    IF sy-subrc = 0.
      ls_row-gjahr = <fs_f>.
    ENDIF.
    ASSIGN COMPONENT 'XDEFAULT' OF STRUCTURE <vim_total_struc> TO <fs_f>.
    IF sy-subrc = 0.
      ls_row-xdefault = <fs_f>.
    ENDIF.
    ASSIGN COMPONENT 'XACTIVE' OF STRUCTURE <vim_total_struc> TO <fs_f>.
    IF sy-subrc = 0.
      ls_row-xactive = <fs_f>.
    ENDIF.
    APPEND ls_row TO lt_row.
  ENDLOOP.

  zcl_hddt_config=>check_default( EXPORTING it_cred = lt_row
                                  IMPORTING e_bukrs = DATA(lv_bukrs)
                                            e_gjahr = DATA(lv_gjahr) ).
  IF lv_bukrs IS NOT INITIAL.
    MESSAGE s065(zms_hddt) WITH lv_bukrs lv_gjahr DISPLAY LIKE 'E'.
    vim_abort_saving = abap_true.
    sy-subrc = 4.
  ENDIF.

ENDFORM.
