# 12 — Dynpro 0100 và GUI status ZGRID_HDDT

Từ 09/09/2026 màn hình danh sách của `ZPG_HDDT_INTEGRATION` dùng
`CL_GUI_ALV_GRID` trên docking container thay cho `CL_SALV_TABLE`. Lý do: SALV
toàn màn hình không cho thêm nút vào toolbar (`ADD_FUNCTION` ném
`CX_SALV_WRONG_CALL`), mà mỗi nút trên Application Toolbar của GUI status lại
đòi một function key và hệ chỉ còn khoảng 10 phím trống.

Với ALV grid, **12 nút khai trong code** qua event `TOOLBAR`. GUI status chỉ
còn cần Back / Exit / Cancel, không mã nghiệp vụ, không function key.

Đổi lại phải có một dynpro làm nền cho docking container. Hai object cần tạo
tay, cả hai đều nhanh:

## 1. Dynpro 0100 — layout để RỖNG

```
SE51 (hoặc SE80 → chương trình ZPG_HDDT_INTEGRATION → Screens → Create)
  Screen number : 0100
  Short text    : Danh sach tich hop HDDT
  Screen type   : Normal
  Layout        : KHÔNG vẽ gì — docking container chiếm toàn bộ vùng màn hình
  Flow logic    :
      PROCESS BEFORE OUTPUT.
        MODULE status_0100.

      PROCESS AFTER INPUT.
        MODULE user_command_0100.
  Activate
```

Hai module `STATUS_0100` và `USER_COMMAND_0100` đã có sẵn ở cuối
`ZIN_HDDT_INTEGRATION_F01`, chỉ gọi `go_app->pbo_0100( )` và
`go_app->pai_0100( sy-ucomm )`.

## 2. GUI status ZGRID_HDDT — chỉ 3 mã chuẩn

```
SE41 → Program ZPG_HDDT_INTEGRATION → Status ZGRID_HDDT → Create
  Status type : Normal screen
  Bấm "Display Standards" để điền sẵn Standard Toolbar
  Bảo đảm có 3 mã: BACK (F3), EXIT (Shift-F3), CANC (F12)
  Application Toolbar: ĐỂ TRỐNG
  Activate
```

Status `ZSALV_HDDT` tạo trước đó không còn dùng, xoá được.

## 3. Kiểm tra sau khi activate

1. Chạy `ZFI001`, chọn công ty và năm, Execute.
2. Màn hình danh sách hiện ra, thanh công cụ của **grid** có 12 nút nghiệp vụ
   chia ba nhóm, cách nhau bằng dấu phân cách.
3. Chọn một dòng rồi bấm `Xem payload`: pop-up nội dung JSON, không gọi API.
4. Bấm `F3` phải quay về màn hình chọn.
5. Nếu không thấy nút nào: kiểm tra status `ZGRID_HDDT` đã activate chưa và
   dynpro 0100 có đúng hai module trong flow logic.
6. Nếu màn hình trắng: docking container không tạo được, chương trình hiện
   thông báo lỗi ở dòng status.

## 4. 12 nút do code tạo

| # | Mã | Icon | Nhãn |
|---|---|---|---|
| 1 | `ZDRAFT` | `ICON_CREATE` | Tích hợp HĐ |
| 2 | `ZDELDRF` | `ICON_DELETE` | Hủy HĐ nháp |
| 3 | `ZISSUE` | `ICON_EXECUTE_OBJECT` | Phát hành HĐ |
| 4 | `ZUPDATE` | `ICON_REFRESH` | Cập nhật HĐ |
| 5 | `ZADJREF` | `ICON_CHANGE` | HĐ Điều chỉnh |
| 6 | `ZMAIL` | `ICON_MAIL` | Send Email |
| 7 | `ZGOM` | `ICON_COLLAPSE` | Gom HĐ |
| 8 | `ZUNGOM` | `ICON_EXPAND` | Huỷ Gom HĐ |
| 9 | `ZEDIT` | `ICON_EDIT_FILE` | Sửa ngày/giờ |
| 10 | `ZFILE` | `ICON_PDF` | Lấy file |
| 11 | `ZJSON` | `ICON_XML_DOC` | Xem payload |
| 12 | `ZLOG` | `ICON_PROTOCOL` | Log |

Thêm hay bớt nút chỉ sửa method `ON_TOOLBAR` trong `ZIN_HDDT_INTEGRATION_F01`
và hằng số `GC_FCODE` trong `ZIN_HDDT_INTEGRATION_TOP`, không đụng tới status.

## 5. Cột trên grid

Field catalog lấy từ metadata của SALV rồi đắp thêm:

```abap
        mt_fcat = cl_salv_controller_metadata=>get_lvc_fieldcatalog(
                    r_columns      = lo_meta->get_columns( )
                    r_aggregations = lo_meta->get_aggregations( ) ).
```

Cách này giữ nhãn cột theo data element như bản SALV, khỏi khai tay 45 cột và
không cần structure DDIC riêng. Sau đó method `BUILD_FCAT` đặt nhãn tiếng Việt,
bật cờ `icon` cho 3 cột đèn, `hotspot` cho cột link tra cứu, `tech` cho 2 cột
kỹ thuật.

## 6. Muốn quay lại bản SALV

Bản SALV nằm ở commit trước `9eb8270` trong repo. Hoàn nguyên ba file
`ZIN_HDDT_INTEGRATION_TOP`, `ZIN_HDDT_INTEGRATION_F01`,
`ZPG_HDDT_INTEGRATION` là đủ; khi đó cần lại status có 12 mã và không cần dynpro.

[Unverified] Toàn bộ phần này chưa chạy trên hệ SAP. Ba điểm nhiều khả năng
phải sửa ở lần activate đầu: chữ ký `CL_SALV_CONTROLLER_METADATA=>GET_LVC_FIELDCATALOG`,
tham số `ratio` của docking container, và tên tham số `ET_INDEX_ROWS` của
`GET_SELECTED_ROWS`.

## 7. Hai lỗi đã gặp khi tạo status (kiểm chứng trên S25 client 300, 09/09/2026)

**Thừa một hàng nút phía trên grid.** Status tạo bằng cách copy chuẩn danh sách
(`RSMPTEXTS` ghi text `Standard for General List Output`) nên Application Toolbar
mang theo toàn bộ mã của list: `&ETA` `&EB9` `&ALL` `&SAL` `&OUP` `&ODN` `&ILT`
`&UMC` `&SUM` `&XPA` `&OMP` `%PC` `%SL` `&ABC` `&OL0` `&OAD` `&AVE` `&LFO`
`&NFO` `&XXL` `&AQW` `&CRB` `&CRL` `&CRR` `&CRE` `P--` `P-` `P+` `P++`. Grid đã
có toolbar riêng nên hàng này chỉ gây rối.

Cách sửa nhanh nhất: SE41 xoá status rồi tạo lại với **Status type = Normal
screen**, bấm Display Standards, để Application Toolbar TRỐNG. Hoặc mở status
hiện có và xoá hết ô trong Application Toolbar.

**Bấm Back không có tác dụng.** Trong status copy từ chuẩn danh sách, mã của
Back / Exit / Cancel là `&F03` / `&F15` / `&F12`, không phải `BACK` / `EXIT` /
`CANC`. Method `PAI_0100` bản đầu chỉ nhận bộ thứ hai nên không khớp nhánh nào.
Đã sửa: nhận cả ba bộ mã, kể cả `RW` / `RE` của danh sách cổ điển.

```abap
    CASE i_ucomm.
      WHEN 'BACK' OR '&F03' OR 'RW'.
        LEAVE TO SCREEN 0.
      WHEN 'CANC' OR '&F12' OR 'RE'.
        LEAVE TO SCREEN 0.
      WHEN 'EXIT' OR '&F15'.
        LEAVE PROGRAM.
      WHEN OTHERS.
    ENDCASE.
```

Cách tự kiểm tra mã chức năng của một status bằng MCP hoặc SE16:

```sql
SELECT progname, obj_type, obj_code, text FROM rsmptexts
  WHERE progname = 'ZPG_HDDT_INTEGRATION'
```

`OBJ_TYPE = 'C'` là danh sách status, `'F'` là các mã chức năng kèm text.
