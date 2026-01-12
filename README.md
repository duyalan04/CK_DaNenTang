# 💰 Expense Tracker - Quản lý Tài chính cá nhân thông minh

Ứng dụng quản lý tài chính đa nền tảng với tính năng OCR và dự báo chi tiêu AI.

## 🏗️ Kiến trúc

```
├── backend/          # Express.js API
├── web/              # React.js Dashboard  
├── mobile/           # Flutter Mobile App
```

## ⚡ Tính năng chính

- ✅ Ghi chép thu chi
- ✅ Lập ngân sách theo danh mục
- ✅ Báo cáo biểu đồ chi tiết
- ✅ OCR quét hóa đơn (Google ML Kit)
- ✅ Dự báo chi tiêu (Linear Regression)
- ✅ Đa nền tảng (Mobile + Web)

## 🚀 Cài đặt

### 1. Supabase Setup

1. Tạo project tại [supabase.com](https://supabase.com)
2. Chạy SQL trong `backend/database/schema.sql`
3. Copy URL và Keys từ Settings > API

### 2. Backend

```bash
cd backend
npm install
cp .env.example .env
# Cập nhật .env với Supabase credentials
npm run dev
```

### 3. Web Dashboard

```bash
cd web
npm install
cp .env.example .env.local
# Cập nhật .env.local
npm run dev
```

### 4. Mobile App

```bash
cd mobile
flutter pub get
# Cập nhật Supabase URL/Key trong lib/main.dart
flutter run
```

## 📱 API Endpoints

| Method | Endpoint | Mô tả |
|--------|----------|-------|
| POST | /api/auth/register | Đăng ký |
| POST | /api/auth/login | Đăng nhập |
| GET | /api/transactions | Danh sách giao dịch |
| POST | /api/transactions | Tạo giao dịch |
| POST | /api/transactions/ocr | Tạo từ OCR |
| GET | /api/categories | Danh mục |
| GET | /api/budgets | Ngân sách |
| GET | /api/reports/summary | Tổng quan |
| GET | /api/predictions/next-month | Dự báo |

## 🛠️ Tech Stack

- **Backend**: Express.js, Supabase, ml-regression
- **Web**: React, Vite, TailwindCSS, Recharts, TanStack Query
- **Mobile**: Flutter, Google ML Kit, Riverpod
- **Database**: PostgreSQL (Supabase)
