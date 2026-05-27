const supabase = require('../config/supabase');

const formatCurrency = (amount) =>
  `${Math.round(Number(amount) || 0).toLocaleString('vi-VN')}đ`;

const getBudgetAlert = (budget) => {
  const amount = Number(budget.amount) || 0;
  const spent = Number(budget.spent) || 0;
  const percentage = Number(budget.percentage) || 0;
  const categoryName = budget.categories?.name || 'Danh mục';

  if (amount <= 0 || percentage < 80) return null;

  if (percentage >= 100) {
    return {
      budget_id: budget.id,
      alert_type: 'exceeded',
      threshold_percent: 100,
      message: `Ngân sách ${categoryName} đã vượt ${formatCurrency(Math.max(spent - amount, 0))}. Đã dùng ${percentage}% (${formatCurrency(spent)}/${formatCurrency(amount)}).`
    };
  }

  if (percentage >= 90) {
    return {
      budget_id: budget.id,
      alert_type: 'warning_90',
      threshold_percent: 90,
      message: `Ngân sách ${categoryName} đã dùng ${percentage}% (${formatCurrency(spent)}/${formatCurrency(amount)}). Bạn sắp chạm giới hạn.`
    };
  }

  return {
    budget_id: budget.id,
    alert_type: 'warning_80',
    threshold_percent: 80,
    message: `Ngân sách ${categoryName} đã dùng ${percentage}% (${formatCurrency(spent)}/${formatCurrency(amount)}). Bạn nên theo dõi chi tiêu trong danh mục này.`
  };
};

const syncBudgetAlerts = async (userId, budgetStatuses) => {
  const alerts = budgetStatuses
    .map(getBudgetAlert)
    .filter(Boolean)
    .map(alert => ({
      ...alert,
      user_id: userId,
      is_read: false
    }));

  if (alerts.length === 0) return;

  const budgetIds = [...new Set(alerts.map(alert => alert.budget_id))];
  const { data: existingAlerts, error: existingError } = await supabase
    .from('budget_alerts')
    .select('budget_id, alert_type')
    .eq('user_id', userId)
    .in('budget_id', budgetIds);

  if (existingError) {
    console.error('Budget alerts lookup error:', existingError);
    return;
  }

  const existingKeys = new Set(
    (existingAlerts || []).map(alert => `${alert.budget_id}:${alert.alert_type}`)
  );

  const alertsToInsert = alerts.filter(
    alert => !existingKeys.has(`${alert.budget_id}:${alert.alert_type}`)
  );

  if (alertsToInsert.length === 0) return;

  const { error: insertError } = await supabase
    .from('budget_alerts')
    .insert(alertsToInsert);

  if (insertError) {
    console.error('Budget alerts insert error:', insertError);
  }
};

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

    const result = budgets.map(b => {
      const amount = Number(b.amount) || 0;
      const spent = spending[b.category_id] || 0;

      return {
        ...b,
        spent,
        remaining: amount - spent,
        percentage: amount > 0 ? Math.round((spent / amount) * 100) : 0
      };
    });

    await syncBudgetAlerts(userId, result);

    res.json(result);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
};
