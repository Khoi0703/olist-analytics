# Phase 3 — Data Profiling Report

Kiểm tra chất lượng dữ liệu thô (raw) trước khi làm sạch.


## Bảng: `customers`
- Số dòng: **99,441** | Số cột: **5**
- Số dòng trùng lặp (duplicate rows): **0**
- Missing values: không có
- Kiểu dữ liệu:
  - `customer_id`: str
  - `customer_unique_id`: str
  - `customer_zip_code_prefix`: int64
  - `customer_city`: str
  - `customer_state`: str

## Bảng: `geolocation`
- Số dòng: **1,000,163** | Số cột: **5**
- Số dòng trùng lặp (duplicate rows): **261,831**
- Missing values: không có
- Kiểu dữ liệu:
  - `geolocation_zip_code_prefix`: int64
  - `geolocation_lat`: float64
  - `geolocation_lng`: float64
  - `geolocation_city`: str
  - `geolocation_state`: str

## Bảng: `order_items`
- Số dòng: **112,650** | Số cột: **7**
- Số dòng trùng lặp (duplicate rows): **0**
- Missing values: không có
- Kiểu dữ liệu:
  - `order_id`: str
  - `order_item_id`: int64
  - `product_id`: str
  - `seller_id`: str
  - `shipping_limit_date`: str
  - `price`: float64
  - `freight_value`: float64

## Bảng: `order_payments`
- Số dòng: **103,886** | Số cột: **5**
- Số dòng trùng lặp (duplicate rows): **0**
- Missing values: không có
- Kiểu dữ liệu:
  - `order_id`: str
  - `payment_sequential`: int64
  - `payment_type`: str
  - `payment_installments`: int64
  - `payment_value`: float64

## Bảng: `order_reviews`
- Số dòng: **99,224** | Số cột: **7**
- Số dòng trùng lặp (duplicate rows): **0**
- Missing values:
  - `review_comment_title`: 87,656 (88.34%)
  - `review_comment_message`: 58,247 (58.70%)
- Kiểu dữ liệu:
  - `review_id`: str
  - `order_id`: str
  - `review_score`: int64
  - `review_comment_title`: str
  - `review_comment_message`: str
  - `review_creation_date`: str
  - `review_answer_timestamp`: str

## Bảng: `orders`
- Số dòng: **99,441** | Số cột: **8**
- Số dòng trùng lặp (duplicate rows): **0**
- Missing values:
  - `order_approved_at`: 160 (0.16%)
  - `order_delivered_carrier_date`: 1,783 (1.79%)
  - `order_delivered_customer_date`: 2,965 (2.98%)
- Kiểu dữ liệu:
  - `order_id`: str
  - `customer_id`: str
  - `order_status`: str
  - `order_purchase_timestamp`: str
  - `order_approved_at`: str
  - `order_delivered_carrier_date`: str
  - `order_delivered_customer_date`: str
  - `order_estimated_delivery_date`: str

## Bảng: `products`
- Số dòng: **32,951** | Số cột: **9**
- Số dòng trùng lặp (duplicate rows): **0**
- Missing values:
  - `product_category_name`: 610 (1.85%)
  - `product_name_lenght`: 610 (1.85%)
  - `product_description_lenght`: 610 (1.85%)
  - `product_photos_qty`: 610 (1.85%)
  - `product_weight_g`: 2 (0.01%)
  - `product_length_cm`: 2 (0.01%)
  - `product_height_cm`: 2 (0.01%)
  - `product_width_cm`: 2 (0.01%)
- Kiểu dữ liệu:
  - `product_id`: str
  - `product_category_name`: str
  - `product_name_lenght`: float64
  - `product_description_lenght`: float64
  - `product_photos_qty`: float64
  - `product_weight_g`: float64
  - `product_length_cm`: float64
  - `product_height_cm`: float64
  - `product_width_cm`: float64

## Bảng: `sellers`
- Số dòng: **3,095** | Số cột: **4**
- Số dòng trùng lặp (duplicate rows): **0**
- Missing values: không có
- Kiểu dữ liệu:
  - `seller_id`: str
  - `seller_zip_code_prefix`: int64
  - `seller_city`: str
  - `seller_state`: str

## Bảng: `category_translation`
- Số dòng: **71** | Số cột: **2**
- Số dòng trùng lặp (duplicate rows): **0**
- Missing values: không có
- Kiểu dữ liệu:
  - `product_category_name`: str
  - `product_category_name_english`: str

## Trả lời các câu hỏi profiling cụ thể

### Phân bố order_status
- delivered: 96,478
- shipped: 1,107
- canceled: 625
- unavailable: 609
- invoiced: 314
- processing: 301
- created: 5
- approved: 2

**Số đơn hàng bị hủy (canceled): 625 (0.63%)**

**Review thiếu comment message: 58,247 (58.70%)**

**Sản phẩm thiếu category: 610 (1.85%)**

**Số customer_id duy nhất trong orders: 99,441 / tổng customers: 99,441**
(Lưu ý: mỗi order có 1 customer_id riêng ngay cả khi cùng 1 khách mua nhiều lần — cần dùng `customer_unique_id` để xác định khách hàng thật sự.)

**Số khách hàng thật sự (customer_unique_id) duy nhất: 96,096**
→ Cho thấy có khách hàng quay lại mua nhiều lần (nhiều customer_id map về cùng 1 customer_unique_id).

**Order items không khớp với order nào: 0**

**Delivery days — min: 0, max: 209, mean: 12.1, median: 10.0**
**Số đơn có delivery_days âm (bất thường): 0**