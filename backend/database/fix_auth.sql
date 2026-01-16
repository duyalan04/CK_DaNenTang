-- =====================================================
-- FIX AUTHENTICATION ISSUES
-- Chạy file này trong Supabase SQL Editor
-- =====================================================

-- 1. Xóa trigger và function cũ (nếu có)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();

-- 2. Tạo lại function với syntax đúng
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name)
  VALUES (NEW.id, NEW.raw_user_meta_data->>'full_name')
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Tạo lại trigger
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 4. Xóa RLS policies cũ cho profiles
DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;
DROP POLICY IF EXISTS "Service role can manage profiles" ON profiles;

-- 5. Tạo RLS policies mới cho profiles
-- Cho phép user xem profile của mình
CREATE POLICY "Users can view own profile" 
ON profiles FOR SELECT 
USING (auth.uid() = id);

-- Cho phép user update profile của mình
CREATE POLICY "Users can update own profile" 
ON profiles FOR UPDATE 
USING (auth.uid() = id);

-- Cho phép INSERT khi user tự tạo profile cho mình
CREATE POLICY "Users can insert own profile" 
ON profiles FOR INSERT 
WITH CHECK (auth.uid() = id);

-- 6. Cho phép service_role bypass RLS (quan trọng cho backend)
-- Đảm bảo service key có thể insert profiles
ALTER TABLE profiles FORCE ROW LEVEL SECURITY;

-- 7. Tạo policy cho service role (backend dùng service key)
CREATE POLICY "Service role full access" 
ON profiles FOR ALL 
USING (true)
WITH CHECK (true);

-- 8. Kiểm tra và sửa các bảng khác
-- Categories
DROP POLICY IF EXISTS "Users can manage own categories" ON categories;
CREATE POLICY "Users can manage own categories" 
ON categories FOR ALL 
USING (auth.uid() = user_id OR user_id IS NULL);

-- Cho phép service role
DROP POLICY IF EXISTS "Service role categories" ON categories;
CREATE POLICY "Service role categories" 
ON categories FOR ALL 
USING (true)
WITH CHECK (true);

-- 9. Đảm bảo extension uuid-ossp đã được enable
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 10. Kiểm tra bảng profiles tồn tại đúng cấu trúc
-- Nếu chưa có bảng, tạo mới
CREATE TABLE IF NOT EXISTS profiles (
  id UUID REFERENCES auth.users PRIMARY KEY,
  full_name TEXT,
  avatar_url TEXT,
  currency VARCHAR(3) DEFAULT 'VND',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 11. Grant permissions
GRANT ALL ON profiles TO authenticated;
GRANT ALL ON profiles TO service_role;
GRANT ALL ON categories TO authenticated;
GRANT ALL ON categories TO service_role;

-- =====================================================
-- VERIFICATION: Chạy query này để kiểm tra
-- =====================================================
-- SELECT * FROM pg_policies WHERE tablename = 'profiles';
-- SELECT * FROM pg_policies WHERE tablename = 'categories';
