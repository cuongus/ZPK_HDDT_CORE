# 14 — Chuyển package ZPK_MAG_HDDT sang ZPK_INT_HDDT

Hệ MAG S25 client 100, transport `S25K900150` (task `S25K900151`). Đổi
**package**, KHÔNG đổi tên object: tiền tố `ZCL_HDDT_*` / `ZTB_HDDT_*` /
`ZPG_HDDT_*` / `ZIN_HDDT_*` giữ nguyên. Chuyển package chỉ sửa TADIR nên không
phải activate lại và không sửa một dòng code nào.

Đã thực hiện 11/09/2026 qua bridge ADT-over-RFC `MAG_S25_100`
(`127.0.0.1:8410`). Kết quả ở mục 4.

## 1. Trạng thái thật trên hệ (đã kiểm, không phải suy đoán)

`ZPK_MAG_HDDT` là package **phẳng** — không có sub-package nào. `ZPK_INT_HDDT`
**đã tồn tại sẵn** trong TDEVC (DLVUNIT `HOME`, PARENTCL rỗng), không phải tạo
mới. Vì vậy chuyển là **một package sang một package**, không tách 4 package con.

Cấu trúc repo lại chia 4 thư mục con (`src/ddic`, `src/engine`, `src/prov`,
`src/ui`) và `.abapgit.xml` khai `FOLDER_LOGIC = PREFIX`. Nghĩa là nếu sau này
pull repo bằng abapGit vào `ZPK_INT_HDDT` thì abapGit **sẽ đòi** 4 sub-package
`ZPK_INT_HDDT_DDIC` / `_ENGINE` / `_PROV` / `_UI`. Hai chuyện độc lập nhau:
hệ đang phẳng vẫn đúng, chỉ cần nhớ điều này trước khi clone lại repo.

## 2. Object thật trong package nguồn — 139 object + 1 DEVC

| Loại | Số lượng | Có URI ADT | Ghi chú |
|---|---|---|---|
| CLAS — Class | 23 | có | |
| DOMA — Domain | 10 | có | |
| DTEL — Data element | 53 | có | |
| TABL — Table | 15 | có | |
| INTF — Interface | 7 | có | |
| PROG — Program / include | 8 | có | 4 PROG/P + 4 PROG/I |
| MSAG — Message class | 1 | có | `ZMS_HDDT` |
| FUGR — Function group | 1 | có | `ZFG_VM_HDDT` (SE54 sinh) |
| TOBJ — Table auth. object | 9 | có | SE54 sinh |
| TRAN — Transaction | 3 | có | `ZHD001` `ZHD002` `ZHD003` |
| SVIM — View maintenance | 9 | **không** | SE54 sinh — xem mục 5 |
| DEVC — Package | 1 | — | chính `ZPK_MAG_HDDT` |

Lệch so với bản trước của tài liệu này: tổng là **139** object (không phải 118
hay 123); transaction là `ZHD001–003` (không phải `ZFI001–003`); PROG có 8
(thêm `ZIN_HDDT_INTEGRATION_I01` và `_O01`); và có thêm FUGR + 9 SVIM + 9 TOBJ
do SE54 sinh ra khi tạo table maintenance.

### PROG (8)

```
ZIN_HDDT_INTEGRATION_F01  ZIN_HDDT_INTEGRATION_I01
ZIN_HDDT_INTEGRATION_O01  ZIN_HDDT_INTEGRATION_TOP
ZPG_HDDT_CONFIG  ZPG_HDDT_INTEGRATION  ZPG_HDDT_LOG  ZPG_HDDT_SETUP
```

### TOBJ (9) và SVIM (9)

TOBJ mang hậu tố `S`, SVIM trùng tên table:

```
TOBJ: ZTB_HDDT_ACTS  ZTB_HDDT_CONNS  ZTB_HDDT_CREDS  ZTB_HDDT_DATES
      ZTB_HDDT_MAPS  ZTB_HDDT_PARMS  ZTB_HDDT_PROVS  ZTB_HDDT_SRCS
      ZTB_HDDT_STATS

SVIM: ZTB_HDDT_ACT  ZTB_HDDT_CONN  ZTB_HDDT_CRED  ZTB_HDDT_DATE
      ZTB_HDDT_MAP  ZTB_HDDT_PARM  ZTB_HDDT_PROV  ZTB_HDDT_SRC
      ZTB_HDDT_STAT
```

Danh sách CLAS / INTF / DOMA / DTEL / TABL giữ như cũ (23 / 7 / 10 / 53 / 15) —
xem mục 6.

## 3. Cách chuyển: refactoring `changepackage` của ADT

Không cần SE03 bấm tay, không cần `ZADT_VSP`, không cần `ExecuteABAP`. ADT có
sẵn resource **Change Package Assignment**. Ba bước, tất cả là POST tới
`/sap/bc/adt/refactorings`:

| Bước | Query | Body |
|---|---|---|
| 1 | `?step=evaluate&uri=<uri>&rel=<rel>` | bất kỳ (`<x/>`) |
| 2 | `?step=preview&rel=<rel>` | XML bước 1 đã sửa |
| 3 | `?step=execute&rel=<rel>` | XML bước 2 trả về |

với `rel` = `http://www.sap.com/adt/relations/refactoring/changepackage` và
Content-Type bước 2–3:

```
application/vnd.sap.as+xml; charset=UTF-8; dataname=com.sap.adt.refactoring.changePackageRefactoring
```

Bước `evaluate` trả về `changePackageRefactoring` chứa `oldPackage`,
`newPackage`, `generic:transport`. Chỉ cần sửa ba chỗ rồi đẩy tiếp:

```xml
<changepackage:newPackage>ZPK_INT_HDDT</changepackage:newPackage>
...
<generic:newPackage>ZPK_INT_HDDT</generic:newPackage>
...
<generic:transport>S25K900150</generic:transport>
```

Lấy URI ADT của cả package bằng một lời gọi:

```
POST /sap/bc/adt/repository/nodestructure?parent_name=ZPK_MAG_HDDT&parent_type=DEVC%2FK
```

Trường `OBJECT_URI` của từng `SEU_ADT_REPOSITORY_OBJ_NODE` chính là `uri` cần
truyền. 130/139 object có `OBJECT_URI`; 9 SVIM không có.

### Ba cái bẫy đã gặp

1. **Thứ tự tham số không quan trọng, nhưng Git Bash thì có.** Truyền
   `/sap/bc/adt/...` làm tham số dòng lệnh trong Git Bash bị MSYS đổi thành
   `C:/Program Files/Git/sap/bc/adt/...`, bridge trả 502
   `STRING_OFFSET_TOO_LARGE` — thông báo không liên quan gì tới nguyên nhân.
   Chạy với `MSYS_NO_PATHCONV=1` hoặc dựng URI trong script.
2. **Query `datapreview` phải đúng Accept.** `Accept: application/xml` bị trả
   406; phải là `application/vnd.sap.adt.datapreview.table.v1+xml`.
3. **Object mới đi vào task, không vào request.** Refactoring khai
   `transport = S25K900150` nhưng SAP ghi E071 vào task con `S25K900151`. Đếm
   `E071` theo số request sẽ ra 0 dòng và tưởng là thất bại.

## 4. Kết quả thực tế

130 object chuyển bằng refactoring trên: 129 lần `OK`, 1 lần `ALREADY`
(`ZCL_HDDT_CONFIG` đã chuyển ở lượt chạy thử). Không có lỗi.

Sau khi chuyển, `nodestructure` của `ZPK_INT_HDDT` trả đúng 130 object; của
`ZPK_MAG_HDDT` trả rỗng. Đọc thử source `ZCL_HDDT_SERVICE` (68.733 byte),
`ZPG_HDDT_INTEGRATION` (4.193 byte), `ZTB_HDDT_LOG` (1.910 byte) — còn nguyên,
không phải activate lại.

`TADIR` sau khi chuyển:

| DEVCLASS | OBJECT | CNT |
|---|---|---|
| ZPK_INT_HDDT | CLAS | 23 |
| ZPK_INT_HDDT | DEVC | 1 |
| ZPK_INT_HDDT | DOMA | 10 |
| ZPK_INT_HDDT | DTEL | 53 |
| ZPK_INT_HDDT | FUGR | 1 |
| ZPK_INT_HDDT | INTF | 7 |
| ZPK_INT_HDDT | MSAG | 1 |
| ZPK_INT_HDDT | PROG | 8 |
| ZPK_INT_HDDT | TABL | 15 |
| ZPK_INT_HDDT | TOBJ | 9 |
| ZPK_INT_HDDT | TRAN | 3 |
| ZPK_MAG_HDDT | DEVC | 1 |
| ZPK_MAG_HDDT | SVIM | 9 |

`E071` của task `S25K900151`: 168 dòng (164 trước khi chuyển — object đã nằm
sẵn trong task từ lúc tạo; refactoring thêm 4 dòng).

## 5. Còn lại: 9 SVIM và package cũ

ADT từ chối đổi package cho SVIM. Cả hai URI dưới đây đều resolve được nhưng
trả 500 **"Changing the package assignment for this object is not supported."**:

```
/sap/bc/adt/transportobject/objects/ztb_hddt_act
/sap/bc/adt/vit/wb/object_type/svimn/object_name/ZTB_HDDT_ACT
```

Hai đường còn lại:

* **SE03** → *Change Object Directory Entries* → chọn `Object type = SVIM`,
  package `ZPK_MAG_HDDT` → đích `ZPK_INT_HDDT`, TR `S25K900150`; hoặc
* **SE54** mở lại từng maintenance view rồi generate lại vào `ZPK_INT_HDDT`.

Chưa xoá `ZPK_MAG_HDDT`: còn 9 SVIM trong đó thì SAP không cho xoá. Xoá xong
SVIM mới xoá được package, cũng gán vào `S25K900150`.

## 6. Câu kiểm

```sql
SELECT devclass, object, COUNT(*) AS cnt FROM tadir
  WHERE devclass LIKE 'ZPK_INT_HDDT%'
  GROUP BY devclass, object ORDER BY devclass ASCENDING, object ASCENDING
```

Câu này phải về **0 dòng** sau khi xử lý xong 9 SVIM:

```sql
SELECT devclass, object, obj_name FROM tadir
  WHERE devclass LIKE 'ZPK_MAG_HDDT%' AND object <> 'DEVC'
```

Object trong TR — chú ý query theo **task** `S25K900151`, không phải request:

```sql
SELECT trkorr, pgmid, object, obj_name FROM e071
  WHERE trkorr IN ('S25K900150','S25K900151')
  ORDER BY object ASCENDING, obj_name ASCENDING
```

### Danh sách đối chiếu chi tiết

DOMA (10):

```
ZDO_HDDT_ACTION  ZDO_HDDT_ADJTYPE  ZDO_HDDT_AUTH
ZDO_HDDT_DATESRC  ZDO_HDDT_ITEMTYPE  ZDO_HDDT_MAPTYPE
ZDO_HDDT_METHOD  ZDO_HDDT_PROV  ZDO_HDDT_SRCTYPE
ZDO_HDDT_STATUS
```

DTEL (53):

```
ZDE_HDDT_ACTION  ZDE_HDDT_ADJDIR  ZDE_HDDT_ADJTYPE
ZDE_HDDT_AMOUNT  ZDE_HDDT_APIVER  ZDE_HDDT_ATTEMPT
ZDE_HDDT_AUTH  ZDE_HDDT_CALLER  ZDE_HDDT_CLASS
ZDE_HDDT_CODEPAGE  ZDE_HDDT_CONNID  ZDE_HDDT_DATESRC
ZDE_HDDT_DESCR  ZDE_HDDT_DIRECT  ZDE_HDDT_DOCNO
ZDE_HDDT_HOST  ZDE_HDDT_IDKEY  ZDE_HDDT_INVTYPE
ZDE_HDDT_ITEMTYPE  ZDE_HDDT_JSON  ZDE_HDDT_LINENO
ZDE_HDDT_LINK  ZDE_HDDT_LOGID  ZDE_HDDT_MAILST
ZDE_HDDT_MAPTYPE  ZDE_HDDT_MAPVAL  ZDE_HDDT_METHOD
ZDE_HDDT_MSCQT  ZDE_HDDT_MSG  ZDE_HDDT_NAME
ZDE_HDDT_OBJTYPE  ZDE_HDDT_PARMKEY  ZDE_HDDT_PARMVAL
ZDE_HDDT_PATH  ZDE_HDDT_PROV  ZDE_HDDT_QTY
ZDE_HDDT_RATE  ZDE_HDDT_RAW  ZDE_HDDT_RCCODE
ZDE_HDDT_SEC  ZDE_HDDT_SECKEY  ZDE_HDDT_SECRET
ZDE_HDDT_SEQ  ZDE_HDDT_SERIAL  ZDE_HDDT_SIZE
ZDE_HDDT_SRCTYPE  ZDE_HDDT_STATUS  ZDE_HDDT_TAXCODE
ZDE_HDDT_TEMPL  ZDE_HDDT_TIMEOUT  ZDE_HDDT_TOKEN
ZDE_HDDT_URL  ZDE_HDDT_USER
```

TABL (15):

```
ZTB_HDDT_ACT  ZTB_HDDT_CONN  ZTB_HDDT_CRED
ZTB_HDDT_DATE  ZTB_HDDT_GOM  ZTB_HDDT_INV
ZTB_HDDT_ITEM  ZTB_HDDT_LOG  ZTB_HDDT_MAP
ZTB_HDDT_PARM  ZTB_HDDT_PROV  ZTB_HDDT_SRC
ZTB_HDDT_STAT  ZTB_HDDT_TOK  ZTB_HDDT_TPL
```

INTF (7):

```
ZIF_HDDT_LOG_SINK  ZIF_HDDT_PLATFORM  ZIF_HDDT_PROVIDER
ZIF_HDDT_SECRET  ZIF_HDDT_SOURCE  ZIF_HDDT_TYPES
ZIF_HDDT_WRITEBACK
```

CLAS (23):

```
ZCL_HDDT_CONFIG  ZCL_HDDT_FACTORY  ZCL_HDDT_GOM
ZCL_HDDT_HTTP  ZCL_HDDT_JSON  ZCL_HDDT_LOG
ZCL_HDDT_MAIL  ZCL_HDDT_PLATFORM  ZCL_HDDT_PLAT_CLASSIC
ZCL_HDDT_PROV_BASE  ZCL_HDDT_PROV_FPT  ZCL_HDDT_PROV_TEMPLATE
ZCL_HDDT_PROV_VIETTEL  ZCL_HDDT_PROV_VNPT  ZCL_HDDT_SECRET
ZCL_HDDT_SERVICE  ZCL_HDDT_SRC_BASE  ZCL_HDDT_SRC_FI
ZCL_HDDT_SRC_GOM  ZCL_HDDT_SRC_SD  ZCL_HDDT_TOKEN
ZCL_HDDT_WRITEBACK_FI  ZCX_HDDT_ERROR
```

## 7. abapGit

Repo không phải sửa gì cho việc chuyển package: `.abapgit.xml` và 5 file
`package.devc.xml` chỉ chứa `CTEXT`, không chỗ nào ghi tên package.

Nếu muốn nối lại repo với `ZPK_INT_HDDT`: abapGit → **Advanced → Remove** (chỉ
bỏ liên kết) → Clone lại. Đọc kỹ chữ trước khi bấm: **Remove** bỏ liên kết,
**Uninstall** XOÁ object khỏi hệ. Nhớ chuyện `FOLDER_LOGIC = PREFIX` ở mục 1:
với layout repo hiện tại, abapGit cần 4 sub-package
`ZPK_INT_HDDT_DDIC` / `_ENGINE` / `_PROV` / `_UI`, hoặc phải làm phẳng repo về
một thư mục `/src/` cho khớp hệ.
