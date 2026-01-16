-- =====================================================
-- ENHANCED EXPENSE TRACKER DATABASE SCHEMA
-- Thêm các bảng cho tính năng AI THÔNG MINH
-- =====================================================

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm"; -- Cho full-text search

-- =====================================================
-- 1. BẢNG MỤC TIÊU TÀI CHÍNH (Financial Goals)
-- Cho phép user đặt mục tiêu tiết kiệm
-- =====================================================
CREATE TABLE financial_goals (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  name VARCHAR(200) NOT NULL,
  target_amount DECIMAL(15,2) NOT NULL,
  current_amount DECIMAL(15,2) DEFAULT 0,
  deadline DATE,
  category VARCHAR(50), -- 'emergency_fund', 'vacation', 'car', 'house', 'education', 'other'
  priority INTEGER DEFAULT 1, -- 1=cao, 2=trung bình, 3=thấp
  status VARCHAR(20) DEFAULT 'active', -- 'active', 'completed', 'cancelled'
  icon VARCHAR(50),
  color VARCHAR(7),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- 2. BẢNG GÓP TIỀN VÀO MỤC TIÊU (Goal Contributions)
-- Theo dõi từng lần góp tiền
-- =====================================================
CREATE TABLE goal_contributions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  goal_id UUID REFERENCES financial_goals(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  amount DECIMAL(15,2) NOT NULL,
  note TEXT,
  contribution_date DATE DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- 3. BẢNG GIAO DỊCH ĐỊNH KỲ (Recurring Transactions)
-- Tự động tạo giao dịch hàng tháng/tuần
-- =====================================================
CREATE TABLE recurring_transactions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  category_id UUID REFERENCES categories(id) ON DELETE SET NULL,
  amount DECIMAL(15,2) NOT NULL,
  type VARCHAR(10) CHECK (type IN ('income', 'expense')),
  description TEXT,
  frequency VARCHAR(20) NOT NULL, -- 'daily', 'weekly', 'monthly', 'yearly'
  day_of_month INTEGER, -- Ngày trong tháng (1-31)
  day_of_week INTEGER, -- Ngày trong tuần (0-6, 0=CN)
  start_date DATE NOT NULL,
  end_date DATE,
  next_occurrence DATE,
  is_active BOOLEAN DEFAULT TRUE,
  last_generated TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- 4. BẢNG CẢNH BÁO NGÂN SÁCH (Budget Alerts)
-- Thông báo khi gần/vượt ngân sách
-- =====================================================
CREATE TABLE budget_alerts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  budget_id UUID REFERENCES budgets(id) ON DELETE CASCADE,
  alert_type VARCHAR(30) NOT NULL, -- 'warning_80', 'warning_90', 'exceeded', 'weekly_summary'
  threshold_percent INTEGER, -- 80, 90, 100
  message TEXT,
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- 5. BẢNG LỊCH SỬ CHAT AI (Chat History)
-- Lưu conversation để AI nhớ context
-- =====================================================
CREATE TABLE chat_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  conversation_id VARCHAR(100),
  role VARCHAR(20) NOT NULL, -- 'user', 'assistant', 'system'
  content TEXT NOT NULL,
  metadata JSONB, -- Lưu thêm context như transactions được đề cập
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- 6. BẢNG AI INSIGHTS CACHE
-- Cache insights để không gọi API liên tục
-- =====================================================
CREATE TABLE ai_insights_cache (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  insight_type VARCHAR(50) NOT NULL, -- 'daily', 'weekly', 'monthly', 'anomaly', 'savings'
  content JSONB NOT NULL,
  valid_until TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- 7. BẢNG SPENDING PATTERNS (Mẫu chi tiêu)
-- AI học thói quen chi tiêu của user
-- =====================================================
CREATE TABLE spending_patterns (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  category_id UUID REFERENCES categories(id) ON DELETE CASCADE,
  day_of_week INTEGER, -- 0-6
  hour_of_day INTEGER, -- 0-23
  avg_amount DECIMAL(15,2),
  frequency INTEGER, -- Số lần chi tiêu
  last_updated TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- 8. BẢNG ANOMALY LOG (Lịch sử phát hiện bất thường)
-- Lưu lại các anomaly đã phát hiện
-- =====================================================
CREATE TABLE anomaly_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  transaction_id UUID REFERENCES transactions(id) ON DELETE CASCADE,
  anomaly_type VARCHAR(50), -- 'unusual_amount', 'unusual_time', 'unusual_category', 'unusual_frequency'
  severity VARCHAR(20), -- 'low', 'medium', 'high'
  z_score DECIMAL(5,2),
  description TEXT,
  is_dismissed BOOLEAN DEFAULT FALSE,
  user_feedback VARCHAR(20), -- 'correct', 'false_positive', null
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- 9. BẢNG NOTIFICATION SETTINGS
-- Cài đặt thông báo cho user
-- =====================================================
CREATE TABLE notification_settings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE UNIQUE,
  daily_reminder BOOLEAN DEFAULT TRUE,
  daily_reminder_time TIME DEFAULT '20:00',
  budget_alerts BOOLEAN DEFAULT TRUE,
  budget_threshold INTEGER DEFAULT 80, -- Cảnh báo khi đạt 80%
  weekly_report BOOLEAN DEFAULT TRUE,
  anomaly_alerts BOOLEAN DEFAULT TRUE,
  goal_reminders BOOLEAN DEFAULT TRUE,
  push_enabled BOOLEAN DEFAULT TRUE,
  email_enabled BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- 10. BẢNG RECEIPTS (Lưu ảnh hóa đơn)
-- Lưu trữ ảnh và kết quả OCR
-- =====================================================
CREATE TABLE receipts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  transaction_id UUID REFERENCES transactions(id) ON DELETE SET NULL,
  image_url TEXT NOT NULL,
  ocr_result JSONB,
  ai_confidence INTEGER, -- 0-100
  store_name VARCHAR(200),
  receipt_date DATE,
  total_amount DECIMAL(15,2),
  items JSONB, -- Array of items
  is_processed BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- 11. BẢNG TAGS (Nhãn cho giao dịch)
-- Cho phép gắn nhiều tag cho 1 giao dịch
-- =====================================================
CREATE TABLE tags (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  name VARCHAR(50) NOT NULL,
  color VARCHAR(7) DEFAULT '#808080',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, name)
);

CREATE TABLE transaction_tags (
  transaction_id UUID REFERENCES transactions(id) ON DELETE CASCADE,
  tag_id UUID REFERENCES tags(id) ON DELETE CASCADE,
  PRIMARY KEY (transaction_id, tag_id)
);

-- =====================================================
-- 12. BẢNG SHARED BUDGETS (Ngân sách chia sẻ)
-- Cho phép nhiều người dùng chung 1 ngân sách (gia đình)
-- =====================================================
CREATE TABLE shared_budgets (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name VARCHAR(200) NOT NULL,
  description TEXT,
  owner_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  total_budget DECIMAL(15,2),
  month INTEGER,
  year INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE shared_budget_members (
  budget_id UUID REFERENCES shared_budgets(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  role VARCHAR(20) DEFAULT 'member', -- 'owner', 'admin', 'member'
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (budget_id, user_id)
);

-- =====================================================
-- INDEXES cho performance
-- =====================================================
CREATE INDEX idx_financial_goals_user ON financial_goals(user_id);
CREATE INDEX idx_goal_contributions_goal ON goal_contributions(goal_id);
CREATE INDEX idx_recurring_transactions_user ON recurring_transactions(user_id);
CREATE INDEX idx_recurring_next ON recurring_transactions(next_occurrence) WHERE is_active = TRUE;
CREATE INDEX idx_budget_alerts_user ON budget_alerts(user_id, is_read);
CREATE INDEX idx_chat_history_user ON chat_history(user_id, conversation_id);
CREATE INDEX idx_chat_history_created ON chat_history(created_at DESC);
CREATE INDEX idx_spending_patterns_user ON spending_patterns(user_id, category_id);
CREATE INDEX idx_anomaly_logs_user ON anomaly_logs(user_id, created_at DESC);
CREATE INDEX idx_receipts_user ON receipts(user_id, created_at DESC);
CREATE INDEX idx_tags_user ON tags(user_id);

-- =====================================================
-- ROW LEVEL SECURITY
-- =====================================================
ALTER TABLE financial_goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE goal_contributions ENABLE ROW LEVEL SECURITY;
ALTER TABLE recurring_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE budget_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_insights_cache ENABLE ROW LEVEL SECURITY;
ALTER TABLE spending_patterns ENABLE ROW LEVEL SECURITY;
ALTER TABLE anomaly_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE transaction_tags ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users manage own goals" ON financial_goals FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users manage own contributions" ON goal_contributions FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users manage own recurring" ON recurring_transactions FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users manage own alerts" ON budget_alerts FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users manage own chat" ON chat_history FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users manage own insights" ON ai_insights_cache FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users manage own patterns" ON spending_patterns FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users manage own anomalies" ON anomaly_logs FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users manage own notifications" ON notification_settings FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users manage own receipts" ON receipts FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users manage own tags" ON tags FOR ALL USING (auth.uid() = user_id);

-- =====================================================
-- FUNCTIONS & TRIGGERS
-- =====================================================

-- Function: Tự động tạo notification settings khi user mới
CREATE OR REPLACE FUNCTION create_default_notification_settings()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO notification_settings (user_id) VALUES (NEW.id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_profile_created_notifications
  AFTER INSERT ON profiles
  FOR EACH ROW EXECUTE FUNCTION create_default_notification_settings();

-- Function: Cập nhật current_amount của goal khi có contribution
CREATE OR REPLACE FUNCTION update_goal_amount()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE financial_goals 
  SET current_amount = (
    SELECT COALESCE(SUM(amount), 0) 
    FROM goal_contributions 
    WHERE goal_id = NEW.goal_id
  ),
  updated_at = NOW()
  WHERE id = NEW.goal_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_contribution_added
  AFTER INSERT ON goal_contributions
  FOR EACH ROW EXECUTE FUNCTION update_goal_amount();

-- Function: Kiểm tra và đánh dấu goal completed
CREATE OR REPLACE FUNCTION check_goal_completion()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.current_amount >= NEW.target_amount AND NEW.status = 'active' THEN
    NEW.status := 'completed';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_goal_updated
  BEFORE UPDATE ON financial_goals
  FOR EACH ROW EXECUTE FUNCTION check_goal_completion();
