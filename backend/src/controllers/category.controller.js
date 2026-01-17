const supabase = require('../config/supabase');

// Danh mục mặc định
const DEFAULT_CATEGORIES = [
  // Chi tiêu (expense)
  { name: 'Ăn uống', icon: '🍜', color: '#FF6B6B', type: 'expense' },
  { name: 'Di chuyển', icon: '🚗', color: '#4ECDC4', type: 'expense' },
  { name: 'Mua sắm', icon: '🛒', color: '#45B7D1', type: 'expense' },
  { name: 'Giải trí', icon: '🎮', color: '#96CEB4', type: 'expense' },
  { name: 'Sức khỏe', icon: '💊', color: '#FFEAA7', type: 'expense' },
  { name: 'Giáo dục', icon: '📚', color: '#DDA0DD', type: 'expense' },
  { name: 'Hóa đơn', icon: '📄', color: '#98D8C8', type: 'expense' },
  { name: 'Nhà cửa', icon: '🏠', color: '#F7DC6F', type: 'expense' },
  { name: 'Khác', icon: '📦', color: '#808080', type: 'expense' },
  // Thu nhập (income)
  { name: 'Lương', icon: '💰', color: '#2ECC71', type: 'income' },
  { name: 'Thưởng', icon: '🎁', color: '#27AE60', type: 'income' },
  { name: 'Đầu tư', icon: '📈', color: '#1ABC9C', type: 'income' },
  { name: 'Kinh doanh', icon: '💼', color: '#16A085', type: 'income' },
  { name: 'Thu nhập khác', icon: '💵', color: '#3498DB', type: 'income' },
];

// Khởi tạo danh mục mặc định cho user
exports.initDefaults = async (req, res) => {
  try {
    const userId = req.user.id;

    // Kiểm tra xem user đã có danh mục chưa
    const { data: existing } = await supabase
      .from('categories')
      .select('id')
      .eq('user_id', userId)
      .limit(1);

    if (existing && existing.length > 0) {
      // Đã có danh mục, chỉ thêm những cái còn thiếu
      const { data: currentCats } = await supabase
        .from('categories')
        .select('name')
        .eq('user_id', userId);

      const currentNames = currentCats?.map(c => c.name) || [];
      const missingCats = DEFAULT_CATEGORIES.filter(c => !currentNames.includes(c.name));

      if (missingCats.length > 0) {
        const toInsert = missingCats.map(cat => ({
          ...cat,
          user_id: userId,
          is_default: true
        }));

        await supabase.from('categories').insert(toInsert);
      }

      return res.json({ 
        message: `Đã thêm ${missingCats.length} danh mục mới`,
        added: missingCats.length
      });
    }

    // Chưa có danh mục nào, tạo tất cả
    const toInsert = DEFAULT_CATEGORIES.map(cat => ({
      ...cat,
      user_id: userId,
      is_default: true
    }));

    const { error } = await supabase.from('categories').insert(toInsert);
    if (error) throw error;

    res.json({ 
      message: 'Đã tạo danh mục mặc định',
      added: DEFAULT_CATEGORIES.length
    });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
};

exports.getAll = async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('categories')
      .select('*')
      .eq('user_id', req.user.id)
      .order('name');

    if (error) throw error;
    
    // Loại bỏ duplicate theo tên (giữ lại cái đầu tiên)
    const uniqueCategories = data.reduce((acc, cat) => {
      if (!acc.find(c => c.name === cat.name)) {
        acc.push(cat);
      }
      return acc;
    }, []);
    
    res.json(uniqueCategories);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
};

exports.create = async (req, res) => {
  try {
    const { name, icon, color, type } = req.body;

    const { data, error } = await supabase
      .from('categories')
      .insert({
        user_id: req.user.id,
        name,
        icon,
        color,
        type,
        is_default: false
      })
      .select()
      .single();

    if (error) throw error;
    res.status(201).json(data);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
};

exports.update = async (req, res) => {
  try {
    const { id } = req.params;
    const { name, icon, color } = req.body;

    const { data, error } = await supabase
      .from('categories')
      .update({ name, icon, color })
      .eq('id', id)
      .eq('user_id', req.user.id)
      .select()
      .single();

    if (error) throw error;
    res.json(data);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
};

exports.delete = async (req, res) => {
  try {
    const { id } = req.params;

    const { error } = await supabase
      .from('categories')
      .delete()
      .eq('id', id)
      .eq('user_id', req.user.id)
      .eq('is_default', false);

    if (error) throw error;
    res.json({ message: 'Category deleted' });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
};
