const supabase = require('../config/supabase');

exports.getAll = async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('categories')
      .select('*')
      .eq('user_id', req.user.id)
      .order('name');

    if (error) throw error;
    res.json(data);
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
