const supabase = require('../config/supabase');
const Groq = require('groq-sdk');

const groq = new Groq({ apiKey: process.env.GROQ_API_KEY });

/**
 * Lấy tất cả mục tiêu tài chính
 */
exports.getAll = async (req, res) => {
    try {
        const { data, error } = await supabase
            .from('financial_goals')
            .select('*')
            .eq('user_id', req.user.id)
            .order('priority', { ascending: true });

        if (error) throw error;

        // Tính % hoàn thành và ngày còn lại
        const goalsWithProgress = data.map(goal => {
            const progress = goal.target_amount > 0 
                ? Math.min(100, (goal.current_amount / goal.target_amount) * 100)
                : 0;
            
            const daysRemaining = goal.deadline 
                ? Math.ceil((new Date(goal.deadline) - new Date()) / (1000 * 60 * 60 * 24))
                : null;

            const monthlyNeeded = daysRemaining && daysRemaining > 0
                ? ((goal.target_amount - goal.current_amount) / (daysRemaining / 30)).toFixed(0)
                : 0;

            return {
                ...goal,
                progress: Math.round(progress * 10) / 10,
                daysRemaining,
                monthlyNeeded: parseFloat(monthlyNeeded),
                isOnTrack: daysRemaining === null || monthlyNeeded <= 0 || progress >= (100 - (daysRemaining / 30) * 10)
            };
        });

        res.json({ success: true, data: goalsWithProgress });
    } catch (error) {
        res.status(400).json({ success: false, error: error.message });
    }
};

/**
 * Tạo mục tiêu mới
 */
exports.create = async (req, res) => {
    try {
        const { name, targetAmount, deadline, category, priority, icon, color } = req.body;

        const { data, error } = await supabase
            .from('financial_goals')
            .insert({
                user_id: req.user.id,
                name,
                target_amount: targetAmount,
                deadline,
                category,
                priority: priority || 1,
                icon,
                color
            })
            .select()
            .single();

        if (error) throw error;
        res.status(201).json({ success: true, data });
    } catch (error) {
        res.status(400).json({ success: false, error: error.message });
    }
};

/**
 * Góp tiền vào mục tiêu
 */
exports.contribute = async (req, res) => {
    try {
        const { goalId } = req.params;
        const { amount, note } = req.body;

        const { data, error } = await supabase
            .from('goal_contributions')
            .insert({
                goal_id: goalId,
                user_id: req.user.id,
                amount,
                note
            })
            .select()
            .single();

        if (error) throw error;
        res.status(201).json({ success: true, data });
    } catch (error) {
        res.status(400).json({ success: false, error: error.message });
    }
};

/**
 * AI gợi ý mục tiêu dựa trên thu chi
 */
exports.getAISuggestions = async (req, res) => {
    try {
        const userId = req.user.id;

        // Lấy dữ liệu tài chính 3 tháng
        const threeMonthsAgo = new Date();
        threeMonthsAgo.setMonth(threeMonthsAgo.getMonth() - 3);

        const { data: transactions } = await supabase
            .from('transactions')
            .select('amount, type')
            .eq('user_id', userId)
            .gte('transaction_date', threeMonthsAgo.toISOString().split('T')[0]);

        const income = transactions?.filter(t => t.type === 'income').reduce((s, t) => s + parseFloat(t.amount), 0) || 0;
        const expense = transactions?.filter(t => t.type === 'expense').reduce((s, t) => s + parseFloat(t.amount), 0) || 0;
        const monthlySavings = (income - expense) / 3;

        const prompt = `Dựa trên dữ liệu tài chính:
- Thu nhập 3 tháng: ${income.toLocaleString('vi-VN')} VND
- Chi tiêu 3 tháng: ${expense.toLocaleString('vi-VN')} VND  
- Tiết kiệm trung bình/tháng: ${monthlySavings.toLocaleString('vi-VN')} VND

Hãy gợi ý 3 mục tiêu tài chính phù hợp với format JSON:
[
  {"name": "Tên mục tiêu", "targetAmount": số tiền, "months": số tháng, "reason": "Lý do ngắn gọn"}
]
Chỉ trả về JSON, không có text khác.`;

        const completion = await groq.chat.completions.create({
            model: 'llama-3.3-70b-versatile',
            messages: [
                { role: 'system', content: 'Bạn là chuyên gia tài chính cá nhân Việt Nam. Trả lời bằng JSON.' },
                { role: 'user', content: prompt }
            ],
            temperature: 0.7,
            max_tokens: 500
        });

        const response = completion.choices[0]?.message?.content || '[]';
        const jsonMatch = response.match(/\[[\s\S]*\]/);
        const suggestions = jsonMatch ? JSON.parse(jsonMatch[0]) : [];

        res.json({
            success: true,
            data: {
                suggestions,
                financialSummary: {
                    monthlyIncome: income / 3,
                    monthlyExpense: expense / 3,
                    monthlySavings
                }
            }
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

/**
 * Cập nhật mục tiêu
 */
exports.update = async (req, res) => {
    try {
        const { id } = req.params;
        const updates = req.body;

        const { data, error } = await supabase
            .from('financial_goals')
            .update({ ...updates, updated_at: new Date().toISOString() })
            .eq('id', id)
            .eq('user_id', req.user.id)
            .select()
            .single();

        if (error) throw error;
        res.json({ success: true, data });
    } catch (error) {
        res.status(400).json({ success: false, error: error.message });
    }
};

/**
 * Xóa mục tiêu
 */
exports.delete = async (req, res) => {
    try {
        const { id } = req.params;

        const { error } = await supabase
            .from('financial_goals')
            .delete()
            .eq('id', id)
            .eq('user_id', req.user.id);

        if (error) throw error;
        res.json({ success: true, message: 'Goal deleted' });
    } catch (error) {
        res.status(400).json({ success: false, error: error.message });
    }
};
