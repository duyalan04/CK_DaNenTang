const supabase = require('../config/supabase');

exports.getSummary = async (req, res) => {
  try {
    const { startDate, endDate } = req.query;
    const userId = req.user.id;

    let query = supabase
      .from('transactions')
      .select('amount, type')
      .eq('user_id', userId);

    if (startDate) query = query.gte('transaction_date', startDate);
    if (endDate) query = query.lte('transaction_date', endDate);

    const { data, error } = await query;
    if (error) throw error;

    const summary = data.reduce((acc, t) => {
      if (t.type === 'income') acc.totalIncome += parseFloat(t.amount);
      else acc.totalExpense += parseFloat(t.amount);
      return acc;
    }, { totalIncome: 0, totalExpense: 0 });

    summary.balance = summary.totalIncome - summary.totalExpense;
    summary.transactionCount = data.length;

    res.json(summary);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
};

exports.getByCategory = async (req, res) => {
  try {
    const { startDate, endDate, type = 'expense' } = req.query;
    const userId = req.user.id;

    let query = supabase
      .from('transactions')
      .select('amount, category_id, categories(name, icon, color)')
      .eq('user_id', userId)
      .eq('type', type);

    if (startDate) query = query.gte('transaction_date', startDate);
    if (endDate) query = query.lte('transaction_date', endDate);

    const { data, error } = await query;
    if (error) throw error;

    const byCategory = data.reduce((acc, t) => {
      const catId = t.category_id;
      if (!acc[catId]) {
        acc[catId] = {
          categoryId: catId,
          name: t.categories?.name || 'Unknown',
          icon: t.categories?.icon,
          color: t.categories?.color,
          total: 0,
          count: 0
        };
      }
      acc[catId].total += parseFloat(t.amount);
      acc[catId].count++;
      return acc;
    }, {});

    const result = Object.values(byCategory).sort((a, b) => b.total - a.total);
    res.json(result);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
};

exports.getMonthlyTrend = async (req, res) => {
  try {
    const { months = 6 } = req.query;
    const userId = req.user.id;

    const startDate = new Date();
    startDate.setMonth(startDate.getMonth() - parseInt(months));

    const { data, error } = await supabase
      .from('transactions')
      .select('amount, type, transaction_date')
      .eq('user_id', userId)
      .gte('transaction_date', startDate.toISOString().split('T')[0]);

    if (error) throw error;

    const monthly = data.reduce((acc, t) => {
      const month = t.transaction_date.substring(0, 7); // YYYY-MM
      if (!acc[month]) acc[month] = { month, income: 0, expense: 0 };
      if (t.type === 'income') acc[month].income += parseFloat(t.amount);
      else acc[month].expense += parseFloat(t.amount);
      return acc;
    }, {});

    const result = Object.values(monthly).sort((a, b) => a.month.localeCompare(b.month));
    res.json(result);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
};

exports.getBudgetStatus = async (req, res) => {
  try {
    const { year, month } = req.query;
    const userId = req.user.id;

    const currentYear = year || new Date().getFullYear();
    const currentMonth = month || new Date().getMonth() + 1;

    const startDate = `${currentYear}-${String(currentMonth).padStart(2, '0')}-01`;
    const endDate = new Date(currentYear, currentMonth, 0).toISOString().split('T')[0];

    // Get budgets
    const { data: budgets, error: budgetError } = await supabase
      .from('budgets')
      .select('*, categories(name, icon, color)')
      .eq('user_id', userId)
      .eq('year', currentYear)
      .eq('month', currentMonth);

    if (budgetError) throw budgetError;

    // Get actual spending
    const { data: transactions, error: txError } = await supabase
      .from('transactions')
      .select('amount, category_id')
      .eq('user_id', userId)
      .eq('type', 'expense')
      .gte('transaction_date', startDate)
      .lte('transaction_date', endDate);

    if (txError) throw txError;

    const spending = transactions.reduce((acc, t) => {
      acc[t.category_id] = (acc[t.category_id] || 0) + parseFloat(t.amount);
      return acc;
    }, {});

    const result = budgets.map(b => ({
      ...b,
      spent: spending[b.category_id] || 0,
      remaining: b.amount - (spending[b.category_id] || 0),
      percentage: Math.round(((spending[b.category_id] || 0) / b.amount) * 100)
    }));

    res.json(result);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
};
