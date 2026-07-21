# Phase 4 — Data Cleaning Log

- customers: 99441 -> 99441 dòng sau khi bỏ duplicate
- geolocation: 1000163 -> 738305 dòng (bỏ duplicate + 27 tọa độ ngoài Brazil)
- orders: 99441 -> 99441 dòng, convert 5 cột sang datetime
- orders: order_status đã chuẩn hóa lowercase, giữ lại toàn bộ order kể cả canceled/unavailable (không xóa để không mất dữ liệu lịch sử — sẽ gắn flag ở Phase 5)
- order_items: 112650 -> 112650 dòng (bỏ duplicate, orphan order_id, giá trị âm)
- order_payments: 103886 -> 103886 dòng (chuẩn hóa payment_type, bỏ orphan/giá trị âm)
- order_reviews: 99224 -> 98410 dòng (bỏ duplicate review_id, orphan order_id, review_score ngoài 1-5)
- products: 32951 -> 32951 dòng, điền 610 category thiếu = 'unknown', merge tên tiếng Anh, điền missing numeric bằng median
- sellers: 3095 -> 3095 dòng sau khi bỏ duplicate