const supabase = require('../config/supabase');
const Groq = require('groq-sdk');

const groq = new Groq({ apiKey: process.env.GROQ_API_KEY });

/**
 * SMART SPENDING ANALYSIS
 * Phân tích chi tiêu thông minh với AI
 */
exports.getSmartAnalysis = async (req, res) => {
    try {
        const userId = req.user.id;
        const { period = 'month' } = req.query;

        // Xác định khoảng thời gian
        const startDate = new Date();
        if (period === 'week') startDate.setDate(startDate.getDate() - 7);
        else if (period === 'month') startDate.setMonth(startDate.getMonth() - 1);
        else startDate.setMonth(startDate.getMonth() - 3);

        // Lấy transactions
        const { data: transactions } = await supabase
            .from('transactions')
            .select('*, categories(name)')
            .eq('user_id', userId)
            .gte('transaction_date', startDate.toISOString().split('T')[0])
            .order('transaction_date', { ascending: false });

        if (!transactions || transactions.length < 3) {
            return res.json({
                success: true,
                data: { message: 'Cần thêm dữ liệu để phân tích' }
            });
        }

        // Phân tích cơ bản
        const analysis = analyzeTransactions(transactions);

        // AI Deep Analysis
        const aiAnalysis = await getAIDeepAnalysis(analysis, transactions);

        res.json({
            success: true,
            data: {
                ...analysis,
                aiAnalysis,
                period
            }
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

/**
 * SPENDING PATTERNS - Phát hiện mẫu chi tiêu
 */
exports.getSpendingPatterns = async (req, res) => {
    try {
        const userId = req.user.id;

        const threeMonthsAgo = new Date();
        threeMonthsAgo.setMonth(threeMonthsAgo.getMonth() - 3);

        const { data: transactions } = await supabase
            .from('transactions')
            .select('*, categories(name)')
            .eq('user_id', userId)
            .eq('type', 'expense')
            .gte('transaction_date', threeMonthsAgo.toISOString().split('T')[0]);

        if (!transactions || transactions.length < 10) {
            return res.json({
                success: true,
                data: { patterns: [], message: 'Cần thêm dữ liệu' }
            });
        }

        // Phân tích theo ngày trong tuần
        const byDayOfWeek = Array(7).fill(0).map(() => ({ count: 0, total: 0 }));
        const byCategory = {};
        const byWeekOfMonth = [0, 0, 0, 0, 0]; // 5 tuần

        transactions.forEach(t => {
            const date = new Date(t.transaction_date);
            const dayOfWeek = date.getDay();
            const weekOfMonth = Math.floor((date.getDate() - 1) / 7);
            const amount = parseFloat(t.amount);
            const catName = t.categories?.name || 'Khác';

            byDayOfWeek[dayOfWeek].count++;
            byDayOfWeek[dayOfWeek].total += amount;

            byWeekOfMonth[weekOfMonth] += amount;

            if (!byCategory[catName]) byCategory[catName] = { count: 0, total: 0 };
            byCategory[catName].count++;
            byCategory[catName].total += amount;
        });

        // Tìm ngày chi tiêu nhiều nhất
        const dayNames = ['Chủ nhật', 'Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7'];
        const peakDay = byDayOfWeek.reduce((max, day, idx) => 
            day.total > byDayOfWeek[max].total ? idx : max, 0);

        // Tìm tuần chi tiêu nhiều nhất
        const peakWeek = byWeekOfMonth.reduce((max, week, idx) => 
            week > byWeekOfMonth[max] ? idx : max, 0);

        // Top categories
        const topCategories = Object.entries(byCategory)
            .sort((a, b) => b[1].total - a[1].total)
            .slice(0, 5)
            .map(([name, data]) => ({
                name,
                total: data.total,
                count: data.count,
                avgPerTransaction: Math.round(data.total / data.count)
            }));

        res.json({
            success: true,
            data: {
                patterns: {
                    peakSpendingDay: {
                        day: dayNames[peakDay],
                        avgAmount: Math.round(byDayOfWeek[peakDay].total / byDayOfWeek[peakDay].count || 0)
                    },
                    peakSpendingWeek: {
                        week: peakWeek + 1,
                        description: peakWeek === 0 ? 'Đầu tháng' : peakWeek >= 3 ? 'Cuối tháng' : 'Giữa tháng'
                    },
                    byDayOfWeek: dayNames.map((name, idx) => ({
                        day: name,
                        total: Math.round(byDayOfWeek[idx].total),
                        count: byDayOfWeek[idx].count
                    })),
                    topCategories
                },
                insights: generatePatternInsights(peakDay, peakWeek, topCategories, dayNames)
            }
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

/**
 * SMART BUDGET SUGGESTIONS - Gợi ý ngân sách thông minh
 */
exports.getSmartBudgetSuggestions = async (req, res) => {
    try {
        const userId = req.user.id;

        // Lấy chi tiêu 3 tháng gần đây
        const threeMonthsAgo = new Date();
        threeMonthsAgo.setMonth(threeMonthsAgo.getMonth() - 3);

        const { data: transactions } = await supabase
            .from('transactions')
            .select('*, categories(id, name)')
            .eq('user_id', userId)
            .eq('type', 'expense')
            .gte('transaction_date', threeMonthsAgo.toISOString().split('T')[0]);

        // Lấy thu nhập
        const { data: incomeData } = await supabase
            .from('transactions')
            .select('amount')
            .eq('user_id', userId)
            .eq('type', 'income')
            .gte('transaction_date', threeMonthsAgo.toISOString().split('T')[0]);

        const totalIncome = incomeData?.reduce((s, t) => s + parseFloat(t.amount), 0) || 0;
        const monthlyIncome = totalIncome / 3;

        // Nhóm theo category
        const byCategory = {};
        transactions?.forEach(t => {
            const catId = t.category_id;
            const catName = t.categories?.name || 'Khác';
            if (!byCategory[catId]) {
                byCategory[catId] = { name: catName, total: 0, count: 0 };
            }
            byCategory[catId].total += parseFloat(t.amount);
            byCategory[catId].count++;
        });

        // Tính ngân sách gợi ý theo quy tắc 50/30/20
        const suggestions = Object.entries(byCategory).map(([catId, data]) => {
            const monthlyAvg = data.total / 3;
            const percentOfIncome = monthlyIncome > 0 ? (monthlyAvg / monthlyIncome) * 100 : 0;

            // Gợi ý dựa trên loại category
            let suggestedBudget = monthlyAvg;
            let recommendation = 'maintain';

            if (percentOfIncome > 30) {
                suggestedBudget = monthlyAvg * 0.85; // Giảm 15%
                recommendation = 'reduce';
            } else if (percentOfIncome < 5 && data.count > 5) {
                suggestedBudget = monthlyAvg * 1.1; // Tăng 10%
                recommendation = 'increase';
            }

            return {
                categoryId: catId,
                categoryName: data.name,
                currentMonthlyAvg: Math.round(monthlyAvg),
                suggestedBudget: Math.round(suggestedBudget),
                percentOfIncome: Math.round(percentOfIncome * 10) / 10,
                recommendation,
                transactionCount: data.count
            };
        }).sort((a, b) => b.currentMonthlyAvg - a.currentMonthlyAvg);

        // Tổng ngân sách gợi ý
        const totalSuggested = suggestions.reduce((s, item) => s + item.suggestedBudget, 0);
        const savingsTarget = monthlyIncome * 0.2; // 20% tiết kiệm

        res.json({
            success: true,
            data: {
                suggestions,
                summary: {
                    monthlyIncome: Math.round(monthlyIncome),
                    totalSuggestedBudget: Math.round(totalSuggested),
                    suggestedSavings: Math.round(savingsTarget),
                    budgetRule: '50/30/20',
                    essentials: Math.round(monthlyIncome * 0.5),
                    wants: Math.round(monthlyIncome * 0.3),
                    savings: Math.round(monthlyIncome * 0.2)
                }
            }
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

/**
 * FINANCIAL FORECAST - Dự báo tài chính
 */
exports.getFinancialForecast = async (req, res) => {
    try {
        const userId = req.user.id;
        const { months = 3 } = req.query;

        // Lấy dữ liệu 6 tháng gần đây
        const sixMonthsAgo = new Date();
        sixMonthsAgo.setMonth(sixMonthsAgo.getMonth() - 6);

        const { data: transactions } = await supabase
            .from('transactions')
            .select('amount, type, transaction_date')
            .eq('user_id', userId)
            .gte('transaction_date', sixMonthsAgo.toISOString().split('T')[0]);

        // Nhóm theo tháng
        const monthlyData = {};
        transactions?.forEach(t => {
            const month = t.transaction_date.substring(0, 7);
            if (!monthlyData[month]) {
                monthlyData[month] = { income: 0, expense: 0 };
            }
            if (t.type === 'income') {
                monthlyData[month].income += parseFloat(t.amount);
            } else {
                monthlyData[month].expense += parseFloat(t.amount);
            }
        });

        const sortedMonths = Object.keys(monthlyData).sort();
        if (sortedMonths.length < 3) {
            return res.json({
                success: true,
                data: { message: 'Cần ít nhất 3 tháng dữ liệu để dự báo' }
            });
        }

        // Simple Moving Average forecast
        const incomes = sortedMonths.map(m => monthlyData[m].income);
        const expenses = sortedMonths.map(m => monthlyData[m].expense);

        const avgIncome = incomes.reduce((a, b) => a + b, 0) / incomes.length;
        const avgExpense = expenses.reduce((a, b) => a + b, 0) / expenses.length;

        // Trend calculation
        const incomeTrend = calculateTrend(incomes);
        const expenseTrend = calculateTrend(expenses);

        // Generate forecast
        const forecast = [];
        const currentDate = new Date();

        for (let i = 1; i <= parseInt(months); i++) {
            const forecastDate = new Date(currentDate);
            forecastDate.setMonth(forecastDate.getMonth() + i);
            const monthStr = forecastDate.toISOString().substring(0, 7);

            forecast.push({
                month: monthStr,
                predictedIncome: Math.round(avgIncome + (incomeTrend * i)),
                predictedExpense: Math.round(avgExpense + (expenseTrend * i)),
                predictedSavings: Math.round((avgIncome + incomeTrend * i) - (avgExpense + expenseTrend * i))
            });
        }

        res.json({
            success: true,
            data: {
                historical: sortedMonths.map(m => ({
                    month: m,
                    income: Math.round(monthlyData[m].income),
                    expense: Math.round(monthlyData[m].expense),
                    savings: Math.round(monthlyData[m].income - monthlyData[m].expense)
                })),
                forecast,
                trends: {
                    income: incomeTrend > 0 ? 'increasing' : incomeTrend < 0 ? 'decreasing' : 'stable',
                    expense: expenseTrend > 0 ? 'increasing' : expenseTrend < 0 ? 'decreasing' : 'stable',
                    incomeChange: Math.round(incomeTrend),
                    expenseChange: Math.round(expenseTrend)
                }
            }
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

// ============ HELPER FUNCTIONS ============

function analyzeTransactions(transactions) {
    const income = transactions.filter(t => t.type === 'income').reduce((s, t) => s + parseFloat(t.amount), 0);
    const expense = transactions.filter(t => t.type === 'expense').reduce((s, t) => s + parseFloat(t.amount), 0);

    const byCategory = {};
    transactions.filter(t => t.type === 'expense').forEach(t => {
        const cat = t.categories?.name || 'Khác';
        byCategory[cat] = (byCategory[cat] || 0) + parseFloat(t.amount);
    });

    const topExpenses = Object.entries(byCategory)
        .sort((a, b) => b[1] - a[1])
        .slice(0, 5);

    return {
        totalIncome: income,
        totalExpense: expense,
        savings: income - expense,
        savingsRate: income > 0 ? ((income - expense) / income * 100).toFixed(1) : 0,
        transactionCount: transactions.length,
        topExpenseCategories: topExpenses.map(([name, amount]) => ({ name, amount }))
    };
}

async function getAIDeepAnalysis(analysis, transactions) {
    try {
        const prompt = `Phân tích tài chính ngắn gọn (3-4 bullet points):
- Thu nhập: ${analysis.totalIncome.toLocaleString('vi-VN')} VND
- Chi tiêu: ${analysis.totalExpense.toLocaleString('vi-VN')} VND
- Tiết kiệm: ${analysis.savingsRate}%
- Top chi tiêu: ${analysis.topExpenseCategories.map(c => c.name).join(', ')}

Đưa ra nhận xét và 1-2 gợi ý cải thiện cụ thể.`;

        const completion = await groq.chat.completions.create({
            model: 'llama-3.3-70b-versatile',
            messages: [
                { role: 'system', content: 'Bạn là chuyên gia tài chính. Trả lời ngắn gọn bằng tiếng Việt.' },
                { role: 'user', content: prompt }
            ],
            temperature: 0.7,
            max_tokens: 300
        });

        return completion.choices[0]?.message?.content || null;
    } catch {
        return null;
    }
}

function generatePatternInsights(peakDay, peakWeek, topCategories, dayNames) {
    const insights = [];

    insights.push(`Bạn chi tiêu nhiều nhất vào ${dayNames[peakDay]}`);

    if (peakWeek === 0) {
        insights.push('Chi tiêu tập trung đầu tháng - có thể do nhận lương');
    } else if (peakWeek >= 3) {
        insights.push('Chi tiêu nhiều cuối tháng - cần kiểm soát tốt hơn');
    }

    if (topCategories[0]) {
        insights.push(`${topCategories[0].name} chiếm phần lớn chi tiêu của bạn`);
    }

    return insights;
}

function calculateTrend(values) {
    if (values.length < 2) return 0;
    const n = values.length;
    let sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;

    for (let i = 0; i < n; i++) {
        sumX += i;
        sumY += values[i];
        sumXY += i * values[i];
        sumX2 += i * i;
    }

    const slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
    return isNaN(slope) ? 0 : slope;
}
