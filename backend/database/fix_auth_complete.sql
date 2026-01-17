-- =====================================================
-- KHẮC PHỤC TRIỆT ĐỂ LỖI ĐĂNG KÝ USER
-- "Database error saving new user"
-- 
-- HƯỚNG DẪN: Copy toàn bộ nội dung này và chạy trong
-- Supabase Dashboard > SQL Editor > New Query
-- =====================================================

-- BƯỚC 1: Xóa trigger cũ (nếu có)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- BƯỚC 2: Xóa function cũ (nếu có)
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;

-- BƯỚC 3: Đảm bảo extension uuid được enable
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- BƯỚC 4: Tạo bảng profiles nếu chưa có (hoặc sửa cấu trúc)
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY,
  full_name TEXT,
  avatar_url TEXT,
  currency VARCHAR(3) DEFAULT 'VND',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- BƯỚC 5: Thêm foreign key nếu chưa có (bỏ qua lỗi nếu đã tồn tại)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'profiles_id_fkey'
  ) THEN
    ALTER TABLE public.profiles 
    ADD CONSTRAINT profiles_id_fkey 
    FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
  END IF;
EXCEPTION WHEN OTHERS THEN
  NULL; -- Bỏ qua lỗi nếu constraint đã tồn tại
END $$;

-- BƯỚC 6: Enable RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- BƯỚC 7: Xóa tất cả policies cũ của profiles
DO $$
DECLARE
  pol RECORD;
BEGIN
  FOR pol IN SELECT policyname FROM pg_policies WHERE tablename = 'profiles'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.profiles', pol.policyname);
  END LOOP;
END $$;

-- BƯỚC 8: Tạo policies mới cho profiles
-- Policy cho authenticated users xem profile của mình
CREATE POLICY "profiles_select_own" ON public.profiles
  FOR SELECT USING (auth.uid() = id);

-- Policy cho authenticated users update profile của mình  
CREATE POLICY "profiles_update_own" ON public.profiles
  FOR UPDATE USING (auth.uid() = id);

-- Policy cho authenticated users insert profile của mình
CREATE POLICY "profiles_insert_own" ON public.profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

-- QUAN TRỌNG: Policy cho phép trigger (SECURITY DEFINER) insert
-- Trigger chạy với quyền của function owner, không phải user
CREATE POLICY "profiles_insert_trigger" ON public.profiles
  FOR INSERT WITH CHECK (true);

-- BƯỚC 9: Tạo function mới với error handling
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _full_name TEXT;
BEGIN
  -- Lấy full_name từ metadata, nếu không có thì dùng email
  _full_name := COALESCE(
    NEW.raw_user_meta_data->>'full_name',
    NEW.raw_user_meta_data->>'name',
    split_part(NEW.email, '@', 1)
  );
  
  -- Insert profile với ON CONFLICT để tránh lỗi duplicate
  INSERT INTO public.profiles (id, full_name, created_at, updated_at)
  VALUES (NEW.id, _full_name, NOW(), NOW())
  ON CONFLICT (id) DO UPDATE SET
    full_name = COALESCE(EXCLUDED.full_name, profiles.full_name),
    updated_at = NOW();
  
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Log lỗi nhưng không fail signup
  RAISE WARNING 'Error creating profile for user %: %', NEW.id, SQLERRM;
  RETURN NEW;
END;
$$;

-- BƯỚC 10: Tạo trigger mới
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- BƯỚC 11: Grant permissions
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA public TO anon;
GRANT ALL ON public.profiles TO authenticated;
GRANT ALL ON public.profiles TO service_role;
GRANT SELECT ON public.profiles TO anon;

-- BƯỚC 12: Tạo profiles cho users đã tồn tại nhưng chưa có profile
INSERT INTO public.profiles (id, full_name, created_at, updated_at)
SELECT 
  au.id,
  COALESCE(au.raw_user_meta_data->>'full_name', au.raw_user_meta_data->>'name', split_part(au.email, '@', 1)),
  au.created_at,
  NOW()
FROM auth.users au
LEFT JOIN public.profiles p ON au.id = p.id
WHERE p.id IS NULL
ON CONFLICT (id) DO NOTHING;

-- =====================================================
-- VERIFICATION - Chạy các query này để kiểm tra
-- =====================================================

-- Kiểm tra trigger đã được tạo
SELECT tgname, tgtype, tgenabled 
FROM pg_trigger 
WHERE tgname = 'on_auth_user_created';

-- Kiểm tra function đã được tạo
SELECT proname, prosrc 
FROM pg_proc 
WHERE proname = 'handle_new_user';

-- Kiểm tra policies
SELECT policyname, cmd, qual, with_check 
FROM pg_policies 
WHERE tablename = 'profiles';

-- Kiểm tra bảng profiles
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'profiles';

-- =====================================================
-- DONE! Thử đăng ký user mới để test
-- =====================================================
