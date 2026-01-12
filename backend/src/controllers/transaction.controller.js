const supabase = require('../config/supabase');

exports.getAll = async (req, res) => {
  try {
    const { startDate, endDate, type, categoryId, limit = 50, offset = 0 } = req.query;

    let query = supabase
      .from('transactions')
      .select('*, categories(name, icon, color)')
      .eq('user_id', req.user.id)
      .order('transaction_date', { ascending: false })
      .range(offset, offset + limit - 1);

    if (startDate) query = query.gte('transaction_date', startDate);
    if (endDate) query = query.lte('transaction_date', endDate);
    if (type) query = query.eq('type', type);
    if (categoryId) query = query.eq('category_id', categoryId);

    const { data, error } = await query;

    if (error) throw error;
    res.json(data);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
};

exports.getById = async (req, res) => {
  try {
    const { id } = req.params;

    const { data, error } = await supabase
      .from('transactions')
      .select('*, categories(name, icon, color)')
      .eq('id', id)
      .eq('user_id', req.user.id)
      .single();

    if (error) throw error;
    res.json(data);
  } catch (error) {
    res.status(404).json({ error: 'Transaction not found' });
  }
};

exports.create = async (req, res) => {
  try {
    const { categoryId, amount, type, description, transactionDate } = req.body;

    const { data, error } = await supabase
      .from('transactions')
      .insert({
        user_id: req.user.id,
        category_id: categoryId,
        amount,
        type,
        description,
        transaction_date: transactionDate || new Date().toISOString().split('T')[0]
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
    const { categoryId, amount, type, description, transactionDate } = req.body;

    const { data, error } = await supabase
      .from('transactions')
      .update({
        category_id: categoryId,
        amount,
        type,
        description,
        transaction_date: transactionDate
      })
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
      .from('transactions')
      .delete()
      .eq('id', id)
      .eq('user_id', req.user.id);

    if (error) throw error;
    res.json({ message: 'Transaction deleted' });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
};

exports.createFromOCR = async (req, res) => {
  try {
    const { ocrData, categoryId, transactionDate } = req.body;
    // ocrData: { rawText, extractedAmount, extractedItems }

    const { data, error } = await supabase
      .from('transactions')
      .insert({
        user_id: req.user.id,
        category_id: categoryId,
        amount: ocrData.extractedAmount,
        type: 'expense',
        description: ocrData.extractedItems?.join(', ') || 'OCR Import',
        transaction_date: transactionDate || new Date().toISOString().split('T')[0],
        ocr_data: ocrData
      })
      .select('*, categories(name, icon, color)')
      .single();

    if (error) throw error;
    res.status(201).json(data);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
};
