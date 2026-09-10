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

Nhãn cũng là biến chương trình (`GV_*_TXT`, CHAR 20, Output only) nên đổi chữ
không phải mở Screen Painter; `INIT_GOM_LABELS` gán giá trị ở PBO.

| Field giá trị | Format | Leng | Deci | Nhãn | Ghi chú |
|---|---|---|---|---|---|
| `GS_GOM_H-SRC_DOCNO` | CHAR | 20 | | `GV_SRC_DOCNO_TXT` | trống cho tới khi Save |
| `GS_GOM_H-CNT_DOC` | INT4 | 4 | | `GV_CNT_DOC_TXT` | |
| `GS_GOM_H-BUKRS` | CHAR | 4 | | `GV_BUKRS_TXT` | |
| `GS_GOM_H-GJAHR` | NUMC | 4 | | `GV_GJAHR_TXT` | |
| `GS_GOM_H-BLDAT` | DATS | 8 | | `GV_BLDAT_TXT` | |
| `GS_GOM_H-BUDAT` | DATS | 8 | | `GV_BUDAT_TXT` | ngày muộn nhất trong nhóm |
| `GS_GOM_H-BUYER_CODE` | CHAR | 10 | | `GV_BUYER_CODE_TXT` | |
| `GS_GOM_H-BUYER_NAME` | CHAR | 120 | | `GV_BUYER_NAME_TXT` | |
| `GS_GOM_H-WAERS` | CUKY | 5 | | `GV_WAERS_TXT` | |
| `GS_GOM_H-AMOUNT` | DEC | 23 | 6 | `GV_AMOUNT_TXT` | output length ≥ 31 |
| `GS_GOM_H-VAT_AMOUNT` | DEC | 23 | 6 | `GV_VAT_AMOUNT_TXT` | |
| `GS_GOM_H-TOTAL` | DEC | 23 | 6 | `GV_TOTAL_TXT` | |
| `GS_GOM_H-INV_DATE` | DATS | 8 | | `GV_INV_DATE_TXT` | sửa bằng nút, không gõ trực tiếp |
| `GS_GOM_H-INV_TIME` | TIMS | 6 | | `GV_INV_TIME_TXT` | sửa bằng nút, không gõ trực tiếp |

**Đừng gõ tay tên field rồi tự chọn Format.** Sai một ô Format là dump
`DYNPRO_FIELD_CONVERSION` với `FX027: Wrong data type` ngay lúc PBO, và dump
chỉ nêu field đầu tiên nó gặp nên tưởng chỉ sai một field. Cách chắc chắn:
Element List → xoá hết các dòng `GS_GOM_H-*` → **Goto → Dict./Program fields →
GS_GOM_H → Get from Program** → dán lại. Screen Painter tự ghi đúng
Format/Leng/Deci lấy từ bản đã generate của chương trình.

Suy ra: phải activate chương trình **trước** khi vẽ dynpro. Vẽ trước thì
Screen Painter báo "The field GS_GOM_H does not exist in (the generated
version of) program".

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

Thiếu status này thì dòng thông báo hiện `Status ZGOM_HDDT of the user
interface ZPG_HDDT_INTEGRATION missing` và màn hình 0200 không có nút nào.

**Bước 1.** SE41 → Program `ZPG_HDDT_INTEGRATION` → ô Status điền `ZGOM_HDDT`
→ nút **Create**.

**Bước 2.** Hộp thoại Short text: `Xem truoc chung tu gom`. Status type chọn
**Normal screen** (đừng chọn Dialog box, cũng đừng copy từ status chuẩn của
danh sách — xem mục 7).

**Bước 3.** Bấm **Display Standards** để Standard Toolbar có sẵn Back / Exit /
Cancel / Save. Ba ô đầu Screen Painter điền `BACK`, `EXIT`, `CANC`; ô Save
điền `SAVE`.

**Bước 4.** Mở khối **Function Keys**, điền hai mã:

| Ô | Mã | Text |
|---|---|---|
| F11 (Save) | `SAVE` | Luu gom |
| F5 | `ZEDIT` | Sua ngay/gio |

Gán `SAVE` vào F11 để bấm Ctrl+S cũng lưu được.

**Bước 5.** **Application Toolbar để TRỐNG.** Grid dòng hàng đã có toolbar
riêng của nó, thêm hàng nút nữa chỉ chiếm chỗ. Nếu muốn có nút bấm bằng chuột
thay vì nhớ F5, đặt đúng hai mã `SAVE` và `ZEDIT` vào Application Toolbar,
không thêm gì khác.

**Bước 6.** Gán icon cho hai mã: đặt con trỏ vào dòng mã → Goto → Attributes
→ Icon name `ICON_SYSTEM_SAVE` cho `SAVE`, `ICON_EDIT_FILE` cho `ZEDIT`.
Bước này chỉ để đẹp, bỏ qua được.

**Bước 7.** Activate status. Không cần activate lại chương trình.

`PAI_0200` nhận cả `SAVE`/`&SAVE`, `ZEDIT`/`EDIT`, `BACK`/`&F03`/`CANC`/`&F12`
nên gán mã theo kiểu nào cũng chạy — cùng cách phòng thân như dynpro 0100.

Nhãn `GV_*_TXT` trống mà giá trị vẫn hiện: `INIT_GOM_LABELS` gán nhãn ở PBO,
gọi **trước** `SET PF-STATUS`. Nếu bạn còn dùng bản `_F01` cũ chưa có method
này thì nhãn trống dù `_TOP` đã khai đủ 14 biến — kiểm tra bằng cách tìm
`init_gom_labels` trong include.

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

### 8.4 Chế độ sửa

Vào 0200 là **chế độ xem**: mọi field header khoá, grid không cho gõ. Toolbar
của grid có ba nút do code tạo (không cần sửa GUI status):

| Nút | Mã | Việc |
|---|---|---|
| Sửa dòng hàng / Kết thúc sửa | `ZCHG` | bật tắt chế độ sửa |
| Thêm dòng | `ZINS` | thêm một dòng hàng trống, chỉ bật ở chế độ sửa |
| Xoá dòng | `ZDEL` | xoá các dòng đang chọn, chỉ bật ở chế độ sửa |

`ZEDIT` (Sửa ngày/giờ) vẫn ở Application Toolbar của GUI status `ZGOM_HDDT`,
không đưa vào toolbar của grid. `PAI_0200` gọi method `EDIT_DATES`.

Bật chế độ sửa thì mở đúng hai field `INV_DATE` và `INV_TIME`; các field còn
lại và nhãn `GV_*_TXT` luôn khoá. Việc khoá do `LOOP AT SCREEN` trong module
`STATUS_0200` làm, nên **không cần tick Output only trong SE51** — và đó cũng
là lý do `LOOP AT SCREEN` phải nằm trực tiếp trong module PBO, không đặt trong
method của lớp.

Cột mở cho sửa: mã loại dòng, mã hàng, tên hàng, đơn vị tính, số lượng, đơn
giá, thành tiền, thuế suất %, tiền thuế, chiết khấu, ghi chú. Khoá: số chứng
từ, STT (engine đánh lại khi lưu), chữ loại dòng và chữ thuế suất (suy từ mã),
tổng sau thuế (bằng thành tiền + tiền thuế).

Grid dùng `EDIT` trong field catalog cộng `SET_READY_FOR_INPUT` làm công tắc
chung. Trước mỗi lần thêm / xoá / lưu đều gọi `CHECK_CHANGED_DATA` vì ô đang
gõ mà chưa Enter thì chưa vào bảng nội bộ.

**Bấm Sửa nhưng ô vẫn không gõ được.** Đổi cờ chế độ rồi để `PBO` gọi
`SET_READY_FOR_INPUT` là muộn: lần `REFRESH_TABLE_DISPLAY` cuối đã chạy trước
đó nên frontend vẫn vẽ grid ở chế độ xem. Phải đổi trạng thái **ngay trong**
`TOGGLE_EDIT`, theo đúng thứ tự:

```abap
mo_grid_it->set_frontend_fieldcatalog( it_fieldcatalog = mt_fcat_it ).
mo_grid_it->set_ready_for_input( i_ready_for_input = 1 ).
refresh_item_grid( ).
```

`SET_FRONTEND_FIELDCATALOG` đẩy lại cờ `EDIT` xuống control — cần khi bật/tắt
nhập lúc grid đã hiển thị, vì `SET_READY_FOR_INPUT` một mình chỉ là công tắc
chung. Giữ thêm lời gọi trong `PBO` cho lần hiển thị đầu.

**Hai thanh cuộn ngang ở đáy màn hình.** Thanh trên là của grid (17 cột, tổng
~240 ký tự nên luôn phải cuộn — không bỏ được). Thanh dưới là của **chính
dynpro**, xuất hiện khi layout rộng hơn cửa sổ: xem SE51 → Screen Attributes →
dòng `Occupied`, Columns > 120 là có thanh cuộn. Xếp lại các khối theo hàng
thay vì kéo ngang, giảm `Vis.length` của `BUYER_NAME` xuống 60 (giữ
`Def.length` 120), và dời khối tổng tiền xuống dưới thay vì để bên phải — chỉ
sửa layout, không sửa code.

**Bấm Sửa xong cột nhảy độ rộng.** Ở chế độ nhập, ALV tính độ rộng theo **độ
dài field** chứ không theo nội dung, nên cột `ITEM_NAME` / `NOTE` khai
`c LENGTH 250` phình ra chiếm hết màn hình và đẩy các cột khác ra ngoài. Thêm
`CWIDTH_OPT = X` thì mỗi lần refresh nó tối ưu lại một kiểu khác.

Cách xử lý: **bỏ `CWIDTH_OPT`** cho grid dòng hàng và khai `OUTPUTLEN` cố định
cho từng cột trong `ITEM_LABELS` (cột `OUTLEN` của `GTY_COL`). Độ rộng khi đó
giống nhau ở cả chế độ xem và chế độ sửa. Grid danh sách ở dynpro 0100 không
cho sửa nên vẫn để `CWIDTH_OPT` như cũ.

**Không suy thành tiền từ số lượng × đơn giá.** Dòng hàng nguồn FI lấy số tiền
từ dòng sổ cái, số lượng và đơn giá thường bằng 0 (xem dữ liệu thật của M800),
nhân lại là mất số. `RECALC_TOTALS` chỉ tính `tổng = thành tiền + tiền thuế`
rồi cộng lên header.

Chỉ được sửa khi **chưa phát hành hoá đơn**. `ITEMS_EDITABLE` cho phép đúng
hai trạng thái: `00` chưa tích hợp và `90` lỗi. Từ `10` trở lên (`20` chờ cấp
số đã là có bản nháp bên nhà cung cấp) thì:

* ba nút `ZCHG` / `ZINS` / `ZDEL` không hiện trên toolbar
* tiêu đề grid ghi thêm "(đã phát hành, chỉ xem)"
* bấm `ZEDIT` cũng bị chặn, vì `APPLY_REGISTRY_EDITS` bỏ qua ngày/giờ mới khi
  chứng từ đã gửi — không chặn thì người dùng sửa xong tưởng đã đổi
* `Save` không ghi `ZTB_HDDT_ITEM`

Cờ chỉ xem tính ngay ở `DO_GOM`: **một** thành viên đã gửi là cả chứng từ gom
chuyển sang chỉ xem. Lý do không cho sửa từ `20`: bản nháp đã nằm trên hệ HĐĐT,
sửa dòng hàng ở SAP là hai bên lệch nhau mà không có gì báo.

### 8.5 Dòng hàng đã sửa được lưu ở đâu

Engine dựng dòng hàng của chứng từ gom từ chứng từ nguồn mỗi lần đọc, nên sửa
tay mà không lưu là mất hết ở lần chạy sau. Cách xử lý:

* Save trên 0200 ghi bộ dòng hàng đang hiển thị vào `ZTB_HDDT_ITEM` bằng
  `ZCL_HDDT_LOG->SAVE_ITEMS` với khoá `src_type = 'GOM'`, `src_docno` = số gom
  vừa cấp
* `ZCL_HDDT_SRC_GOM->LOAD_ITEM_OVERRIDE` đọc ngược bảng đó và **thay** kết quả
  `MERGE`, rồi để `AGGREGATE_INVOICE` dựng lại bảng thuế và tổng cộng

Điều kiện áp dụng override: sổ đăng ký của chứng từ gom còn ở trạng thái chưa
gửi. An toàn vì `SAVE_ITEMS` của engine chỉ ghi bảng này **sau khi gửi thành
công**, nên không có chuyện lẫn giữa bản lưu tay và bản lưu vết.

Cờ đánh dấu đã sửa được bật ngay khi **vào** chế độ sửa, không phải khi thay
đổi ô: ALV không có cách rẻ để biết một ô đã đổi giá trị hay chưa. Hệ quả cần
biết: vào chế độ sửa rồi thoát mà không đổi gì, Save vẫn lưu ảnh chụp dòng
hàng — chứng từ gom đó từ đó không còn tự cập nhật theo chứng từ nguồn nữa.
Muốn quay lại hành vi tự dựng thì xoá các dòng `ZTB_HDDT_ITEM` của số gom đó.

`ITEM_TEXT` (tên hàng nhập tay ở popup Sửa ngày/giờ) ghi đè tên **mọi** dòng
hàng trong `APPLY_REGISTRY_EDITS`, nên khi đã sửa dòng hàng thì Save không lưu
`ITEM_TEXT` nữa — không thì tên vừa sửa bị xoá sạch ở lần đọc sau.

[Unverified] Phần sửa dòng hàng của hoá đơn gom là yêu cầu nghiệp vụ cần cân
nhắc về thuế: hoá đơn phát hành sẽ không còn khớp dòng hạch toán của chứng từ
nguồn. Nên chốt với kế toán phạm vi được sửa trước khi mở cho người dùng cuối.

### 8.6 Giải phóng control

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
