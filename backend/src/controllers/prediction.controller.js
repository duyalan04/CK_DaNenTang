const supabase = require('../config/supabase');
const { SimpleLinearRegression } = require('ml-regression');

exports.predictNextMonth = async (req, res) => {
  try {
    const userId = req.user.id;

    // Get last 6 months of expenses
    const startDate = new Date();
    startDate.setMonth(startDate.getMonth() - 6);

    const { data, error } = await supabase
      .from('transactions')
      .select('amount, transaction_date')
      .eq('user_id', userId)
      .eq('type', 'expense')
      .gte('transaction_date', startDate.toISOString().split('T')[0]);

    if (error) throw error;

    // Group by month
    const monthly = data.reduce((acc, t) => {
      const month = t.transaction_date.substring(0, 7);
      acc[month] = (acc[month] || 0) + parseFloat(t.amount);
      return acc;
    }, {});

    const months = Object.keys(monthly).sort();
    if (months.length < 3) {
      return res.json({
        prediction: null,
        message: 'Need at least 3 months of data for prediction',
        confidence: 0
      });
    }

    // Prepare data for regression
    const x = months.map((_, i) => i);
    const y = months.map(m => monthly[m]);

    // Linear regression
    const regression = new SimpleLinearRegression(x, y);
    const nextMonthIndex = x.length;
    const prediction = Math.max(0, regression.predict(nextMonthIndex));

    // Calculate R² for confidence
    const confidence = Math.round(regression.score(x, y).r2 * 100);

    // Save prediction
    const nextMonth = new Date();
    nextMonth.setMonth(nextMonth.getMonth() + 1);

    await supabase.from('predictions').insert({
      user_id: userId,
      predicted_amount: prediction,
      month: nextMonth.getMonth() + 1,
      year: nextMonth.getFullYear(),
      confidence
    });

    res.json({
      prediction: Math.round(prediction),
      month: nextMonth.getMonth() + 1,
      year: nextMonth.getFullYear(),
      confidence,
      historicalData: months.map(m => ({ month: m, amount: monthly[m] }))
    });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
};

exports.predictByCategory = async (req, res) => {
  try {
    const userId = req.user.id;

    const startDate = new Date();
    startDate.setMonth(startDate.getMonth() - 6);

    const { data, error } = await supabase
      .from('transactions')
      .select('amount, transaction_date, category_id, categories(name)')
      .eq('user_id', userId)
      .eq('type', 'expense')
      .gte('transaction_date', startDate.toISOString().split('T')[0]);

    if (error) throw error;

    // Group by category and month
    const byCategory = {};
    data.forEach(t => {
      const catId = t.category_id;
      const month = t.transaction_date.substring(0, 7);

      if (!byCategory[catId]) {
        byCategory[catId] = { name: t.categories?.name, months: {} };
      }
      byCategory[catId].months[month] = (byCategory[catId].months[month] || 0) + parseFloat(t.amount);
    });

    // Predict for each category
    const predictions = Object.entries(byCategory).map(([catId, catData]) => {
      const months = Object.keys(catData.months).sort();
      if (months.length < 3) {
        return { categoryId: catId, name: catData.name, prediction: null };
      }

      const x = months.map((_, i) => i);
      const y = months.map(m => catData.months[m]);

      const regression = new SimpleLinearRegression(x, y);
      const prediction = Math.max(0, regression.predict(x.length));

      return {
        categoryId: catId,
        name: catData.name,
        prediction: Math.round(prediction),
        confidence: Math.round(regression.score(x, y).r2 * 100)
      };
    });

    res.json(predictions.filter(p => p.prediction !== null));
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
};
