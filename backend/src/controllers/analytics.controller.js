const supabase = require('../config/supabase');
const Groq = require('groq-sdk');

const groq = new Groq({
    apiKey: process.env.GROQ_API_KEY
});

/**
 * Tính Z-score cho một giá trị
 * Z = (x - μ) / σ
 */
const calculateZScore = (value, mean, stdDev) => {
    if (stdDev === 0) return 0;
    return (value - mean) / stdDev;
};

/**
 * Tính trung bình (mean)
 */
const calculateMean = (values) => {
    if (values.length === 0) return 0;
    return values.reduce((sum, val) => sum + val, 0) / values.length;
};

/**
 * Tính độ lệch chuẩn (standard deviation)
 */
const calculateStdDev = (values, mean) => {
    if (values.length === 0) return 0;
    const squaredDiffs = values.map(val => Math.pow(val - mean, 2));
    return Math.sqrt(squaredDiffs.reduce((sum, val) => sum + val, 0) / values.length);
};

/**
 * Phát hiện giao dịch bất thường bằng Z-score
 * |Z| > 2: Bất thường nhẹ (low)
 * |Z| > 2.5: Bất thường trung bình (medium)
 * |Z| > 3: Bất thường nghiêm trọng (high)
 */
exports.detectAnomalies = async (req, res) => {
    try {
        const userId = req.user.id;

        // Lấy tất cả giao dịch của user trong 3 tháng gần đây
        const threeMonthsAgo = new Date();
        threeMonthsAgo.setMonth(threeMonthsAgo.getMonth() - 3);

        const { data: transactions, error } = await supabase
            .from('transactions')
            .select('*, categories(name, icon, color)')
            .eq('user_id', userId)
            .gte('transaction_date', threeMonthsAgo.toISOString().split('T')[0])
            .order('transaction_date', { ascending: false });

        if (error) throw error;

        if (transactions.length < 5) {
            return res.json({
                success: true,
                data: {
                    anomalies: [],
                    message: 'Cần ít nhất 5 giao dịch để phân tích'
                }
            });
        }

        // Phân tích theo từng loại (income/expense)
        const expenseTransactions = transactions.filter(t => t.type === 'expense');
        const incomeTransactions = transactions.filter(t => t.type === 'income');

        const anomalies = [];

        // Phát hiện anomaly cho chi tiêu
        if (expenseTransactions.length >= 3) {
            const expenseAmounts = expenseTransactions.map(t => parseFloat(t.amount));
            const expenseMean = calculateMean(expenseAmounts);
            const expenseStdDev = calculateStdDev(expenseAmounts, expenseMean);

            expenseTransactions.forEach(transaction => {
                const amount = parseFloat(transaction.amount);
                const zScore = calculateZScore(amount, expenseMean, expenseStdDev);
                const absZScore = Math.abs(zScore);

                if (absZScore > 2) {
                    let severity = 'low';
                    if (absZScore > 3) severity = 'high';
                    else if (absZScore > 2.5) severity = 'medium';

                    const percentAboveAvg = ((amount - expenseMean) / expenseMean * 100).toFixed(0);

                    anomalies.push({
                        id: transaction.id,
                        transaction,
                        anomaly_type: 'unusual_amount',
                        severity,
                        z_score: zScore.toFixed(2),
                        description: `Giao dịch cao hơn ${percentAboveAvg}% so với trung bình (${formatCurrency(expenseMean)})`,
                        mean: expenseMean,
                        stdDev: expenseStdDev
                    });
                }
            });
        }

        // Phát hiện anomaly cho thu nhập
        if (incomeTransactions.length >= 3) {
            const incomeAmounts = incomeTransactions.map(t => parseFloat(t.amount));
            const incomeMean = calculateMean(incomeAmounts);
            const incomeStdDev = calculateStdDev(incomeAmounts, incomeMean);

            incomeTransactions.forEach(transaction => {
                const amount = parseFloat(transaction.amount);
                const zScore = calculateZScore(amount, incomeMean, incomeStdDev);
                const absZScore = Math.abs(zScore);

                if (absZScore > 2) {
                    let severity = 'low';
                    if (absZScore > 3) severity = 'high';
                    else if (absZScore > 2.5) severity = 'medium';

                    anomalies.push({
                        id: transaction.id,
                        transaction,
                        anomaly_type: zScore > 0 ? 'unusual_high_income' : 'unusual_low_income',
                        severity,
                        z_score: zScore.toFixed(2),
                        description: zScore > 0
                            ? `Thu nhập cao bất thường`
                            : `Thu nhập thấp hơn đáng kể so với trung bình`,
                        mean: incomeMean,
                        stdDev: incomeStdDev
                    });
                }
            });
        }

        // Sắp xếp theo severity và thời gian
        const severityOrder = { high: 0, medium: 1, low: 2 };
        anomalies.sort((a, b) => {
            if (severityOrder[a.severity] !== severityOrder[b.severity]) {
                return severityOrder[a.severity] - severityOrder[b.severity];
            }
            return new Date(b.transaction.transaction_date) - new Date(a.transaction.transaction_date);
        });

        res.json({
            success: true,
            data: {
                anomalies: anomalies.slice(0, 10), // Giới hạn 10 anomaly gần nhất
                statistics: {
                    totalTransactions: transactions.length,
                    anomalyCount: anomalies.length,
                    highSeverity: anomalies.filter(a => a.severity === 'high').length,
                    mediumSeverity: anomalies.filter(a => a.severity === 'medium').length,
                    lowSeverity: anomalies.filter(a => a.severity === 'low').length
                }
            }
        });

    } catch (error) {
        console.error('Anomaly detection error:', error);
        res.status(500).json({
            success: false,
            error: 'Không thể phân tích anomaly'
        });
    }
};

/**
 * Tính điểm sức khỏe tài chính (0-100)
 * 
 * Công thức:
 * - Savings Rate (25 điểm): % tiết kiệm so với thu nhập
 * - Budget Compliance (25 điểm): % tuân thủ ngân sách
 * - Spending Stability (25 điểm): Độ ổn định chi tiêu
 * - Diversification (25 điểm): Đa dạng hóa chi tiêu
 */
exports.calculateHealthScore = async (req, res) => {
    try {
        const userId = req.user.id;
        const now = new Date();
        const currentMonth = now.getMonth() + 1;
        const currentYear = now.getFullYear();

        // Lấy giao dịch tháng này
        const startOfMonth = `${currentYear}-${String(currentMonth).padStart(2, '0')}-01`;
        const endOfMonth = new Date(currentYear, currentMonth, 0).toISOString().split('T')[0];

        const { data: transactions, error: txError } = await supabase
            .from('transactions')
            .select('*')
            .eq('user_id', userId)
            .gte('transaction_date', startOfMonth)
            .lte('transaction_date', endOfMonth);

        if (txError) throw txError;

        // Lấy ngân sách tháng này
        const { data: budgets, error: budgetError } = await supabase
            .from('budgets')
            .select('*, categories(name)')
            .eq('user_id', userId)
            .eq('month', currentMonth)
            .eq('year', currentYear);

        if (budgetError) throw budgetError;

        // Tính toán các chỉ số
        const income = transactions
            .filter(t => t.type === 'income')
            .reduce((sum, t) => sum + parseFloat(t.amount), 0);

        const expense = transactions
            .filter(t => t.type === 'expense')
            .reduce((sum, t) => sum + parseFloat(t.amount), 0);

        const savings = income - expense;

        // 1. Savings Rate Score (25 điểm)
        let savingsRateScore = 0;
        if (income > 0) {
            const savingsRate = (savings / income) * 100;
            // 20% savings rate = full score
            savingsRateScore = Math.min(25, Math.max(0, (savingsRate / 20) * 25));
        }

        // 2. Budget Compliance Score (25 điểm)
        let budgetComplianceScore = 25; // Mặc định nếu không có budget
        if (budgets.length > 0) {
            const expenseByCategory = {};
            transactions
                .filter(t => t.type === 'expense')
                .forEach(t => {
                    expenseByCategory[t.category_id] = (expenseByCategory[t.category_id] || 0) + parseFloat(t.amount);
                });

            let compliantBudgets = 0;
            budgets.forEach(budget => {
                const spent = expenseByCategory[budget.category_id] || 0;
                if (spent <= parseFloat(budget.amount)) {
                    compliantBudgets++;
                }
            });

            budgetComplianceScore = (compliantBudgets / budgets.length) * 25;
        }

        // 3. Spending Stability Score (25 điểm)
        // Lấy chi tiêu 3 tháng gần đây để tính độ ổn định
        const threeMonthsAgo = new Date();
        threeMonthsAgo.setMonth(threeMonthsAgo.getMonth() - 3);

        const { data: recentTransactions } = await supabase
            .from('transactions')
            .select('amount, transaction_date, type')
            .eq('user_id', userId)
            .eq('type', 'expense')
            .gte('transaction_date', threeMonthsAgo.toISOString().split('T')[0]);

        let spendingStabilityScore = 25;
        if (recentTransactions && recentTransactions.length > 0) {
            // Nhóm chi tiêu theo tháng
            const monthlyExpenses = {};
            recentTransactions.forEach(t => {
                const month = t.transaction_date.substring(0, 7);
                monthlyExpenses[month] = (monthlyExpenses[month] || 0) + parseFloat(t.amount);
            });

            const monthlyValues = Object.values(monthlyExpenses);
            if (monthlyValues.length >= 2) {
                const mean = calculateMean(monthlyValues);
                const stdDev = calculateStdDev(monthlyValues, mean);
                const cv = mean > 0 ? (stdDev / mean) * 100 : 0; // Coefficient of Variation

                // CV < 20% = excellent, CV > 50% = poor
                spendingStabilityScore = Math.max(0, 25 - (cv - 20) * 0.5);
            }
        }

        // 4. Diversification Score (25 điểm)
        const categories = new Set(
            transactions
                .filter(t => t.type === 'expense')
                .map(t => t.category_id)
        );
        // 5+ categories = full score
        const diversificationScore = Math.min(25, (categories.size / 5) * 25);

        // Tổng điểm
        const totalScore = Math.round(
            savingsRateScore +
            budgetComplianceScore +
            spendingStabilityScore +
            diversificationScore
        );

        // Tạo feedback dựa trên điểm
        let feedback = '';
        let grade = '';
        if (totalScore >= 80) {
            grade = 'A';
            feedback = 'Tuyệt vời! Bạn đang quản lý tài chính rất tốt! 🌟';
        } else if (totalScore >= 60) {
            grade = 'B';
            feedback = 'Khá tốt! Còn một số điểm có thể cải thiện. 👍';
        } else if (totalScore >= 40) {
            grade = 'C';
            feedback = 'Trung bình. Cần chú ý hơn đến việc quản lý chi tiêu. ⚠️';
        } else {
            grade = 'D';
            feedback = 'Cần cải thiện. Hãy xem xét lại thói quen chi tiêu của bạn. 🔴';
        }

        // Gợi ý cải thiện
        const improvements = [];
        if (savingsRateScore < 20) {
            improvements.push('💰 Cố gắng tiết kiệm ít nhất 20% thu nhập');
        }
        if (budgetComplianceScore < 20) {
            improvements.push('📊 Tuân thủ ngân sách đã đề ra');
        }
        if (spendingStabilityScore < 20) {
            improvements.push('📈 Duy trì chi tiêu ổn định hàng tháng');
        }
        if (diversificationScore < 20) {
            improvements.push('🎯 Phân bổ chi tiêu đều hơn giữa các danh mục');
        }

        res.json({
            success: true,
            data: {
                totalScore,
                grade,
                feedback,
                improvements,
                breakdown: {
                    savingsRate: {
                        score: Math.round(savingsRateScore),
                        maxScore: 25,
                        label: 'Tỷ lệ tiết kiệm',
                        value: income > 0 ? `${((savings / income) * 100).toFixed(1)}%` : '0%'
                    },
                    budgetCompliance: {
                        score: Math.round(budgetComplianceScore),
                        maxScore: 25,
                        label: 'Tuân thủ ngân sách',
                        value: budgets.length > 0 ? `${Math.round((budgetComplianceScore / 25) * 100)}%` : 'N/A'
                    },
                    spendingStability: {
                        score: Math.round(spendingStabilityScore),
                        maxScore: 25,
                        label: 'Ổn định chi tiêu',
                        value: `${Math.round((spendingStabilityScore / 25) * 100)}%`
                    },
                    diversification: {
                        score: Math.round(diversificationScore),
                        maxScore: 25,
                        label: 'Đa dạng hóa',
                        value: `${categories.size} danh mục`
                    }
                },
                summary: {
                    income,
                    expense,
                    savings,
                    transactionCount: transactions.length
                }
            }
        });

    } catch (error) {
        console.error('Health score error:', error);
        res.status(500).json({
            success: false,
            error: 'Không thể tính điểm sức khỏe tài chính'
        });
    }
};

/**
 * Tạo AI insights từ dữ liệu tài chính
 */
exports.generateInsights = async (req, res) => {
    try {
        const userId = req.user.id;

        // Lấy dữ liệu tổng hợp
        const threeMonthsAgo = new Date();
        threeMonthsAgo.setMonth(threeMonthsAgo.getMonth() - 3);

        const { data: transactions, error } = await supabase
            .from('transactions')
            .select('*, categories(name)')
            .eq('user_id', userId)
            .gte('transaction_date', threeMonthsAgo.toISOString().split('T')[0])
            .order('transaction_date', { ascending: false });

        if (error) throw error;

        if (transactions.length < 5) {
            return res.json({
                success: true,
                data: {
                    insights: [{
                        type: 'info',
                        icon: '📊',
                        title: 'Chưa đủ dữ liệu',
                        content: 'Hãy ghi chép thêm giao dịch để nhận insights cá nhân hóa!'
                    }]
                }
            });
        }

        // Tính toán thống kê
        const income = transactions.filter(t => t.type === 'income').reduce((sum, t) => sum + parseFloat(t.amount), 0);
        const expense = transactions.filter(t => t.type === 'expense').reduce((sum, t) => sum + parseFloat(t.amount), 0);

        // Chi tiêu theo category
        const expenseByCategory = {};
        transactions.filter(t => t.type === 'expense').forEach(t => {
            const categoryName = t.categories?.name || 'Khác';
            expenseByCategory[categoryName] = (expenseByCategory[categoryName] || 0) + parseFloat(t.amount);
        });

        // Top categories
        const sortedCategories = Object.entries(expenseByCategory)
            .sort((a, b) => b[1] - a[1])
            .slice(0, 5);

        // Tạo prompt cho Groq
        const prompt = `Phân tích dữ liệu tài chính sau và đưa ra 3-4 insights ngắn gọn, hữu ích:

Tổng thu nhập 3 tháng: ${formatCurrency(income)}
Tổng chi tiêu 3 tháng: ${formatCurrency(expense)}
Tiết kiệm: ${formatCurrency(income - expense)} (${income > 0 ? ((income - expense) / income * 100).toFixed(1) : 0}%)

Chi tiêu theo danh mục cao nhất:
${sortedCategories.map(([name, amount]) => `- ${name}: ${formatCurrency(amount)}`).join('\n')}

Số giao dịch: ${transactions.length}

Yêu cầu:
- Đưa ra insights cụ thể, không chung chung
- Mỗi insight bắt đầu bằng emoji phù hợp
- Ngắn gọn, dễ hiểu
- Đưa ra gợi ý cải thiện nếu cần
- Format: mỗi insight là 1 dòng`;

        const completion = await groq.chat.completions.create({
            model: 'llama-3.3-70b-versatile',
            messages: [
                {
                    role: 'system',
                    content: 'Bạn là chuyên gia tài chính cá nhân. Trả lời bằng tiếng Việt, ngắn gọn và thực tế.'
                },
                { role: 'user', content: prompt }
            ],
            temperature: 0.7,
            max_tokens: 500
        });

        const aiResponse = completion.choices[0]?.message?.content || '';

        // Parse insights từ response
        const insightLines = aiResponse.split('\n').filter(line => line.trim());
        const insights = insightLines.map(line => ({
            type: 'ai',
            content: line.trim()
        }));

        res.json({
            success: true,
            data: {
                insights,
                generatedAt: new Date().toISOString(),
                basedOn: {
                    transactionCount: transactions.length,
                    period: '3 tháng gần đây'
                }
            }
        });

    } catch (error) {
        console.error('Generate insights error:', error);
        res.status(500).json({
            success: false,
            error: 'Không thể tạo insights'
        });
    }
};

/**
 * Gợi ý tiết kiệm dựa trên phân tích chi tiêu
 */
exports.calculateSavings = async (req, res) => {
    try {
        const userId = req.user.id;

        // Lấy chi tiêu 3 tháng gần đây
        const threeMonthsAgo = new Date();
        threeMonthsAgo.setMonth(threeMonthsAgo.getMonth() - 3);

        const { data: transactions, error } = await supabase
            .from('transactions')
            .select('*, categories(id, name, icon, color)')
            .eq('user_id', userId)
            .eq('type', 'expense')
            .gte('transaction_date', threeMonthsAgo.toISOString().split('T')[0]);

        if (error) throw error;

        if (transactions.length < 5) {
            return res.json({
                success: true,
                data: {
                    recommendations: [],
                    message: 'Cần thêm dữ liệu để đưa ra gợi ý tiết kiệm'
                }
            });
        }

        // Nhóm chi tiêu theo category
        const categorySpending = {};
        transactions.forEach(t => {
            const catId = t.category_id;
            if (!categorySpending[catId]) {
                categorySpending[catId] = {
                    category: t.categories,
                    total: 0,
                    count: 0,
                    transactions: []
                };
            }
            categorySpending[catId].total += parseFloat(t.amount);
            categorySpending[catId].count++;
            categorySpending[catId].transactions.push(t);
        });

        // Tính trung bình hàng tháng
        const totalExpense = Object.values(categorySpending).reduce((sum, c) => sum + c.total, 0);
        const monthlyAvg = totalExpense / 3;

        // Tạo recommendations
        const recommendations = Object.entries(categorySpending)
            .map(([catId, data]) => {
                const monthlySpending = data.total / 3;
                const percentOfTotal = (data.total / totalExpense) * 100;

                // Gợi ý giảm cho các category chiếm >15% tổng chi tiêu
                let suggestedReduction = 0;
                let potentialSavings = 0;
                let priority = 3;

                if (percentOfTotal > 30) {
                    suggestedReduction = 20;
                    priority = 1;
                } else if (percentOfTotal > 20) {
                    suggestedReduction = 15;
                    priority = 2;
                } else if (percentOfTotal > 15) {
                    suggestedReduction = 10;
                    priority = 3;
                }

                if (suggestedReduction > 0) {
                    potentialSavings = (monthlySpending * suggestedReduction / 100) * 12; // Tiết kiệm/năm
                }

                return {
                    categoryId: catId,
                    category: data.category,
                    currentMonthlySpending: monthlySpending,
                    percentOfTotal: percentOfTotal.toFixed(1),
                    suggestedReduction,
                    potentialMonthlySavings: monthlySpending * suggestedReduction / 100,
                    potentialYearlySavings: potentialSavings,
                    priority,
                    tip: getSavingTip(data.category?.name, suggestedReduction)
                };
            })
            .filter(r => r.suggestedReduction > 0)
            .sort((a, b) => a.priority - b.priority);

        const totalPotentialSavings = recommendations.reduce((sum, r) => sum + r.potentialYearlySavings, 0);

        res.json({
            success: true,
            data: {
                recommendations,
                summary: {
                    totalMonthlyExpense: monthlyAvg,
                    totalPotentialYearlySavings: totalPotentialSavings,
                    recommendationCount: recommendations.length
                }
            }
        });

    } catch (error) {
        console.error('Calculate savings error:', error);
        res.status(500).json({
            success: false,
            error: 'Không thể tính gợi ý tiết kiệm'
        });
    }
};

/**
 * Helper: Format tiền VND
 */
function formatCurrency(value) {
    return new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(value);
}

/**
 * Helper: Lấy tip tiết kiệm theo category
 */
function getSavingTip(categoryName, reduction) {
    const tips = {
        'Ăn uống': 'Thử nấu ăn tại nhà nhiều hơn, mang cơm đi làm',
        'Di chuyển': 'Sử dụng phương tiện công cộng hoặc đi chung xe',
        'Giải trí': 'Tìm các hoạt động giải trí miễn phí hoặc giảm giá',
        'Mua sắm': 'Lập danh sách trước khi mua, tránh mua sắm bốc đồng',
        'Cafe': 'Pha cafe tại nhà, giảm tần suất ra quán',
        'default': `Cố gắng giảm ${reduction}% chi tiêu trong danh mục này`
    };

    return tips[categoryName] || tips['default'];
}
