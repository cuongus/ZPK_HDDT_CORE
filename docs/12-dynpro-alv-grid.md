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

## 8. Dynpro 0200 — xem trước chứng từ gom

Nút **Gom HĐ** không gom ngay nữa: nó dựng kết quả gom rồi mở dynpro 0200 để
soát, chỉ khi bấm **Save** mới cấp số và ghi bảng.

### 8.1 Tạo dynpro

SE51 → program `ZPG_HDDT_INTEGRATION`, screen `0200`, Screen type **Normal**.

Layout chia hai phần:

```
Phần trên  : các field của GS_GOM_H, đặt Output only cho tất cả
Phần dưới  : một Custom Control tên CC_ITEM, kéo hết chiều rộng và
             chiều cao còn lại
```

Lấy field cho nhanh: Screen Painter → **Goto → Dict./Program fields** → gõ
`GS_GOM_H` → Get from program → chọn 14 dòng → dán vào layout. Đừng gõ tay
tên field, sai một chữ là dynpro không nhận.

| Field | Nhãn gợi ý | Ghi chú |
|---|---|---|
| `GS_GOM_H-SRC_DOCNO` | Số chứng từ gom | trống cho tới khi Save |
| `GS_GOM_H-CNT_DOC` | Số chứng từ gộp | |
| `GS_GOM_H-BUKRS` | Mã công ty | |
| `GS_GOM_H-GJAHR` | Năm tài chính | |
| `GS_GOM_H-BLDAT` | Ngày chứng từ | |
| `GS_GOM_H-BUDAT` | Ngày ghi sổ | ngày muộn nhất trong nhóm |
| `GS_GOM_H-BUYER_CODE` | Khách hàng | |
| `GS_GOM_H-BUYER_NAME` | Tên đơn vị | |
| `GS_GOM_H-WAERS` | Loại tiền | |
| `GS_GOM_H-AMOUNT` | Tổng thành tiền | |
| `GS_GOM_H-VAT_AMOUNT` | Tổng thuế | |
| `GS_GOM_H-TOTAL` | Tổng tiền | |
| `GS_GOM_H-INV_DATE` | Ngày phát hành | sửa bằng nút, không gõ trực tiếp |
| `GS_GOM_H-INV_TIME` | Giờ phát hành | sửa bằng nút, không gõ trực tiếp |

Flow logic đúng bốn dòng:

```abap
PROCESS BEFORE OUTPUT.
  MODULE status_0200.

PROCESS AFTER INPUT.
  MODULE user_command_0200.
```

Custom control **không** dùng chung với docking của 0100: dynpro 0100 vẫn để
layout rỗng, 0200 thì phải có `CC_ITEM` thật, thiếu nó chương trình báo
"Dynpro 0200 chưa có custom control CC_ITEM".

### 8.2 GUI status ZGOM_HDDT

SE41 → status `ZGOM_HDDT`, Normal screen. Application Toolbar để **trống**,
chỉ cần bốn mã:

| Mã | Vị trí | Nhãn | Icon |
|---|---|---|---|
| `SAVE` | Function key F11 + Standard toolbar (Save) | Lưu gom | `ICON_SYSTEM_SAVE` |
| `ZEDIT` | Function key F5 | Sửa ngày/giờ | `ICON_EDIT_FILE` |
| `BACK` | Standard toolbar (Back) | Quay lại | |
| `CANC` | Standard toolbar (Cancel) | Huỷ | |

`PAI_0200` nhận cả `SAVE`/`&SAVE`, `ZEDIT`/`EDIT`, `BACK`/`&F03`/`CANC`/`&F12`
nên gán mã theo kiểu nào cũng chạy — cùng cách xử lý như dynpro 0100.

### 8.3 Vì sao Save mới gom

`DO_GOM` chỉ dựng dữ liệu để xem: nó gọi đúng method `MERGE` của
`ZCL_HDDT_SRC_GOM` — cũng là method engine dùng khi đọc nhóm đã gom — nên số
liệu trên 0200 khớp với hoá đơn sẽ phát hành, không phải tính lại một lần nữa
trong màn hình. `MERGE` đổi từ PROTECTED sang PUBLIC để làm được việc này;
nó không đọc ghi bảng nào nên gọi để xem trước là an toàn.

`DO_GOM_SAVE` mới thật sự: `ZCL_HDDT_GOM->CREATE` cấp số gom và ghi
`ZTB_HDDT_GOM`, rồi nếu người dùng có sửa ngày/giờ thì ghi tiếp
`ZTB_HDDT_LOG`-registry qua `SAVE_EDIT` cho **chính chứng từ gom**, cuối cùng
mới `COMMIT WORK AND WAIT`. Không lưu ngày/giờ vào registry thì lần đọc sau
`MERGE` tính lại theo `ZTB_HDDT_DATE` và mất giá trị người dùng vừa sửa.

Bấm Back / Cancel là thoát, chưa có gì được ghi.

### 8.4 Giải phóng control

`FREE mo_grid_it` của ABAP chỉ xoá tham chiếu, control trên frontend vẫn còn
nên lần vào 0200 thứ hai báo `CC_ITEM` đã tồn tại. `FREE_ITEM_GRID` gọi
`free( )` của control rồi mới `CLEAR`, chạy ở cả nhánh Save và nhánh Cancel.

## 9. Dải trống phía trên grid

Sau khi xoá hết nút khỏi Application Toolbar, vẫn còn một dải xám giữa dòng tiêu
đề và toolbar của grid. Hai nguồn, xử lý riêng:

- **Dải ngang phía trên**: status vẫn còn khối Application Toolbar (rỗng) nên SAP
  GUI vẫn vẽ một hàng. Cách chắc chắn: SE41 xoá status rồi tạo lại với
  **Status type = Normal screen**, bấm Display Standards, không thêm gì vào
  Application Toolbar. Status kiểu danh sách luôn kèm hàng này.
- **Chữ `SAP` ở dòng tiêu đề**: chương trình chưa `SET TITLEBAR`. Muốn hiện chữ
  riêng thì SE41 → Titles → tạo title `T01` với nội dung
  `Tích hợp hoá đơn điện tử`, rồi thêm `SET TITLEBAR 'T01'.` vào `PBO_0100`.
  Không tạo cũng không sao, chỉ là mỹ quan.
- **Dải dọc bên phải**: do docking khai `ratio = 95`, tối đa của ratio là 95 nên
  luôn còn 5% trống. Đã sửa trong code: dùng `extension = 9999` thay cho `ratio`,
  container chiếm hết bề ngang.
