const supabase = require('../config/supabase');

exports.register = async (req, res) => {
  try {
    const { email, password, fullName } = req.body;

    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        data: { full_name: fullName }
      }
    });

    if (error) throw error;

    // Create profile
    if (data.user) {
      await supabase.from('profiles').insert({
        id: data.user.id,
        full_name: fullName
      });

      // Create default categories
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

      await supabase.from('categories').insert(
        defaultCategories.map(cat => ({ ...cat, user_id: data.user.id }))
      );
    }

    res.status(201).json({ message: 'Registration successful', user: data.user });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
};

exports.login = async (req, res) => {
  try {
    const { email, password } = req.body;

    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password
    });

    if (error) throw error;

    res.json({ user: data.user, session: data.session });
  } catch (error) {
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
