const supabase = require('../config/supabase');

/**
 * Lấy tất cả giao dịch định kỳ
 */
exports.getAll = async (req, res) => {
    try {
        const { data, error } = await supabase
            .from('recurring_transactions')
            .select('*, categories(name, icon, color)')
            .eq('user_id', req.user.id)
            .order('next_occurrence', { ascending: true });

        if (error) throw error;
        res.json({ success: true, data });
    } catch (error) {
        res.status(400).json({ success: false, error: error.message });
    }
};

/**
 * Tạo giao dịch định kỳ mới
 */
exports.create = async (req, res) => {
    try {
        const { 
            categoryId, amount, type, description, 
            frequency, dayOfMonth, dayOfWeek, startDate, endDate 
        } = req.body;

        // Tính next_occurrence
        const nextOccurrence = calculateNextOccurrence(frequency, dayOfMonth, dayOfWeek, startDate);

        const { data, error } = await supabase
            .from('recurring_transactions')
            .insert({
                user_id: req.user.id,
                category_id: categoryId,
                amount,
                type,
                description,
                frequency,
                day_of_month: dayOfMonth,
                day_of_week: dayOfWeek,
                start_date: startDate,
                end_date: endDate,
                next_occurrence: nextOccurrence
            })
            .select('*, categories(name, icon, color)')
            .single();

        if (error) throw error;
        res.status(201).json({ success: true, data });
    } catch (error) {
        res.status(400).json({ success: false, error: error.message });
    }
};

/**
 * Xử lý tạo giao dịch từ recurring (chạy bằng cron job)
 */
exports.processRecurring = async (req, res) => {
    try {
        const today = new Date().toISOString().split('T')[0];

        // Lấy các recurring cần xử lý
        const { data: recurringList, error: fetchError } = await supabase
            .from('recurring_transactions')
            .select('*')
            .eq('is_active', true)
            .lte('next_occurrence', today);

        if (fetchError) throw fetchError;

        const results = [];

        for (const recurring of recurringList) {
            // Kiểm tra end_date
            if (recurring.end_date && new Date(recurring.end_date) < new Date()) {
                await supabase
                    .from('recurring_transactions')
                    .update({ is_active: false })
                    .eq('id', recurring.id);
                continue;
            }

            // Tạo transaction
            const { data: transaction, error: txError } = await supabase
                .from('transactions')
                .insert({
                    user_id: recurring.user_id,
                    category_id: recurring.category_id,
                    amount: recurring.amount,
                    type: recurring.type,
                    description: `[Tự động] ${recurring.description || ''}`,
                    transaction_date: today
                })
                .select()
                .single();

            if (!txError) {
                results.push(transaction);

                // Cập nhật next_occurrence
                const nextOccurrence = calculateNextOccurrence(
                    recurring.frequency,
                    recurring.day_of_month,
                    recurring.day_of_week,
                    recurring.next_occurrence,
                    true
                );

                await supabase
                    .from('recurring_transactions')
                    .update({ 
                        next_occurrence: nextOccurrence,
                        last_generated: new Date().toISOString()
                    })
                    .eq('id', recurring.id);
            }
        }

        res.json({ 
            success: true, 
            data: { 
                processed: results.length,
                transactions: results 
            }
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

/**
 * Cập nhật giao dịch định kỳ
 */
exports.update = async (req, res) => {
    try {
        const { id } = req.params;
        const updates = req.body;

        if (updates.frequency || updates.dayOfMonth || updates.dayOfWeek) {
            updates.next_occurrence = calculateNextOccurrence(
                updates.frequency,
                updates.dayOfMonth || updates.day_of_month,
                updates.dayOfWeek || updates.day_of_week,
                new Date().toISOString().split('T')[0]
            );
        }

        const { data, error } = await supabase
            .from('recurring_transactions')
            .update(updates)
            .eq('id', id)
            .eq('user_id', req.user.id)
            .select('*, categories(name, icon, color)')
            .single();

        if (error) throw error;
        res.json({ success: true, data });
    } catch (error) {
        res.status(400).json({ success: false, error: error.message });
    }
};

/**
 * Xóa/Dừng giao dịch định kỳ
 */
exports.delete = async (req, res) => {
    try {
        const { id } = req.params;

        const { error } = await supabase
            .from('recurring_transactions')
            .delete()
            .eq('id', id)
            .eq('user_id', req.user.id);

        if (error) throw error;
        res.json({ success: true, message: 'Recurring transaction deleted' });
    } catch (error) {
        res.status(400).json({ success: false, error: error.message });
    }
};

/**
 * Dự báo chi tiêu định kỳ tháng tới
 */
exports.getForecast = async (req, res) => {
    try {
        const { data, error } = await supabase
            .from('recurring_transactions')
            .select('*, categories(name, icon, color)')
            .eq('user_id', req.user.id)
            .eq('is_active', true);

        if (error) throw error;

        // Tính tổng theo tháng
        let monthlyIncome = 0;
        let monthlyExpense = 0;

        data.forEach(r => {
            let monthlyAmount = parseFloat(r.amount);
            
            switch (r.frequency) {
                case 'daily':
                    monthlyAmount *= 30;
                    break;
                case 'weekly':
                    monthlyAmount *= 4;
                    break;
                case 'yearly':
                    monthlyAmount /= 12;
                    break;
            }

            if (r.type === 'income') {
                monthlyIncome += monthlyAmount;
            } else {
                monthlyExpense += monthlyAmount;
            }
        });

        res.json({
            success: true,
            data: {
                recurring: data,
                forecast: {
                    monthlyIncome: Math.round(monthlyIncome),
                    monthlyExpense: Math.round(monthlyExpense),
                    netMonthly: Math.round(monthlyIncome - monthlyExpense)
                }
            }
        });
    } catch (error) {
        res.status(400).json({ success: false, error: error.message });
    }
};

/**
 * Helper: Tính ngày occurrence tiếp theo
 */
function calculateNextOccurrence(frequency, dayOfMonth, dayOfWeek, fromDate, skipCurrent = false) {
    const date = new Date(fromDate);
    
    if (skipCurrent) {
        // Bỏ qua ngày hiện tại, tính ngày tiếp theo
        switch (frequency) {
            case 'daily':
                date.setDate(date.getDate() + 1);
                break;
            case 'weekly':
                date.setDate(date.getDate() + 7);
                break;
            case 'monthly':
                date.setMonth(date.getMonth() + 1);
                if (dayOfMonth) date.setDate(Math.min(dayOfMonth, new Date(date.getFullYear(), date.getMonth() + 1, 0).getDate()));
                break;
            case 'yearly':
                date.setFullYear(date.getFullYear() + 1);
                break;
        }
    } else {
        // Tính từ ngày bắt đầu
        const today = new Date();
        
        switch (frequency) {
            case 'daily':
                if (date <= today) date.setDate(today.getDate() + 1);
                break;
            case 'weekly':
                if (dayOfWeek !== undefined) {
                    const currentDay = date.getDay();
                    const daysUntil = (dayOfWeek - currentDay + 7) % 7 || 7;
                    date.setDate(date.getDate() + daysUntil);
                }
                break;
            case 'monthly':
                if (dayOfMonth) {
                    date.setDate(dayOfMonth);
                    if (date <= today) {
                        date.setMonth(date.getMonth() + 1);
                    }
                }
                break;
            case 'yearly':
                if (date <= today) {
                    date.setFullYear(date.getFullYear() + 1);
                }
                break;
        }
    }

    return date.toISOString().split('T')[0];
}
