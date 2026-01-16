const supabase = require('../config/supabase');

exports.register = async (req, res) => {
  try {
    const { email, password, fullName } = req.body;

    // Validate input
    if (!email || !password) {
      return res.status(400).json({ error: 'Email và password là bắt buộc' });
    }

    if (password.length < 8) {
      return res.status(400).json({ error: 'Mật khẩu phải có ít nhất 8 ký tự' });
    }

    // Kiểm tra mật khẩu có chữ và số
    if (!/[a-zA-Z]/.test(password) || !/[0-9]/.test(password)) {
      return res.status(400).json({ error: 'Mật khẩu phải có cả chữ và số' });
    }

    // Đăng ký user với Supabase Auth
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        data: { full_name: fullName || '' }
      }
    });

    if (error) {
      console.error('Supabase Auth Error:', error);
      throw error;
    }

    // Kiểm tra user đã được tạo
    if (!data.user) {
      return res.status(400).json({ error: 'Không thể tạo tài khoản' });
    }

    // Tạo profile (trigger có thể đã tạo, nên dùng upsert)
    const { error: profileError } = await supabase
      .from('profiles')
      .upsert({
        id: data.user.id,
        full_name: fullName || ''
      }, { onConflict: 'id' });

    if (profileError) {
      console.error('Profile Error:', profileError);
      // Không throw error vì user đã được tạo
    }

    // Tạo default categories
    const defaultCategories = [
      { name: 'Ăn uống', icon: 'restaurant', color: '#FF6B6B', type: 'expense', is_default: true },
      { name: 'Di chuyển', icon: 'directions_car', color: '#4ECDC4', type: 'expense', is_default: true },
      { name: 'Mua sắm', icon: 'shopping_bag', color: '#45B7D1', type: 'expense', is_default: true },
      { name: 'Giải trí', icon: 'movie', color: '#96CEB4', type: 'expense', is_default: true },
      { name: 'Hóa đơn', icon: 'receipt', color: '#FFEAA7', type: 'expense', is_default: true },
      { name: 'Sức khỏe', icon: 'medical_services', color: '#DDA0DD', type: 'expense', is_default: true },
      { name: 'Lương', icon: 'payments', color: '#98D8C8', type: 'income', is_default: true },
      { name: 'Thưởng', icon: 'card_giftcard', color: '#F7DC6F', type: 'income', is_default: true },
    ];

    const { error: catError } = await supabase
      .from('categories')
      .insert(defaultCategories.map(cat => ({ ...cat, user_id: data.user.id })));

    if (catError) {
      console.error('Categories Error:', catError);
      // Không throw error vì user đã được tạo
    }

    res.status(201).json({ 
      message: 'Đăng ký thành công', 
      user: data.user,
      session: data.session 
    });
  } catch (error) {
    console.error('Register Error:', error);
    res.status(400).json({ error: error.message });
  }
};

exports.login = async (req, res) => {
  try {
    const { email, password } = req.body;

    // Validate input
    if (!email || !password) {
      return res.status(400).json({ error: 'Email và password là bắt buộc' });
    }

    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password
    });

    if (error) {
      console.error('Login Error:', error);
      
      // Xử lý các lỗi cụ thể
      if (error.message.includes('Invalid login credentials')) {
        return res.status(401).json({ error: 'Email hoặc mật khẩu không đúng' });
      }
      if (error.message.includes('Email not confirmed')) {
        return res.status(401).json({ error: 'Vui lòng xác nhận email trước khi đăng nhập' });
      }
      
      throw error;
    }

    // Lấy profile
    const { data: profile } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', data.user.id)
      .single();

    res.json({ 
      user: data.user, 
      session: data.session,
      profile: profile || null
    });
  } catch (error) {
    console.error('Login Error:', error);
    res.status(401).json({ error: error.message });
  }
};

exports.logout = async (req, res) => {
  try {
    const { error } = await supabase.auth.signOut();
    if (error) throw error;
    res.json({ message: 'Logged out successfully' });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
};

exports.getProfile = async (req, res) => {
  try {
    const token = req.headers.authorization?.replace('Bearer ', '');
    const { data: { user }, error } = await supabase.auth.getUser(token);

    if (error) throw error;

    const { data: profile } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', user.id)
      .single();

    res.json({ user, profile });
  } catch (error) {
    res.status(401).json({ error: error.message });
  }
};
