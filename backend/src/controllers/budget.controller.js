const supabase = require('../config/supabase');

exports.getAll = async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('budgets')
      .select('*, categories(name, icon, color)')
      .eq('user_id', req.user.id);

    if (error) throw error;
    res.json(data);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
};

exports.getByMonth = async (req, res) => {
  try {
    const { year, month } = req.params;

    const { data, error } = await supabase
      .from('budgets')
      .select('*, categories(name, icon, color)')
      .eq('user_id', req.user.id)
      .eq('year', parseInt(year))
      .eq('month', parseInt(month));

    if (error) throw error;
    res.json(data);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
};

exports.create = async (req, res) => {
  try {
    const { categoryId, amount, month, year } = req.body;

    const { data, error } = await supabase
      .from('budgets')
      .upsert({
        user_id: req.user.id,
        category_id: categoryId,
        amount,
        month,
        year
      }, {
        onConflict: 'user_id,category_id,month,year'
      })
      .select('*, categories(name, icon, color)')
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
    const { amount } = req.body;

    const { data, error } = await supabase
      .from('budgets')
      .update({ amount })
      .eq('id', id)
      .eq('user_id', req.user.id)
      .select('*, categories(name, icon, color)')
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
      .from('budgets')
      .delete()
      .eq('id', id)
      .eq('user_id', req.user.id);

    if (error) throw error;
    res.json({ message: 'Budget deleted' });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
};
