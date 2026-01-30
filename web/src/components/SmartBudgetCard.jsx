import { useQuery } from '@tanstack/react-query'
import { Wallet, TrendingDown, TrendingUp, Check, RefreshCw } from 'lucide-react'
import api from '../lib/api'

const formatCurrency = (value) => {
    // Xử lý NaN, null, undefined
    const numValue = Number(value)
    if (!isFinite(numValue) || isNaN(numValue)) {
        return new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(0)
    }
    return new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(numValue)
}

// 50/30/20 Rule visualization
const BudgetRuleBar = ({ essentials, wants, savings }) => {
    return (
        <div className="mb-4">
            <div className="flex h-3 rounded-full overflow-hidden">
                <div 
                    className="bg-blue-500" 
                    style={{ width: '50%' }}
                    title={`Thiết yếu: ${formatCurrency(essentials)}`}
                />
                <div 
                    className="bg-orange-500" 
                    style={{ width: '30%' }}
                    title={`Mong muốn: ${formatCurrency(wants)}`}
                />
                <div 
                    className="bg-green-500" 
                    style={{ width: '20%' }}
                    title={`Tiết kiệm: ${formatCurrency(savings)}`}
                />
            </div>
            <div className="flex justify-between mt-2 text-xs">
                <div className="flex items-center gap-1">
                    <div className="w-2 h-2 bg-blue-500 rounded-full"></div>
                    <span className="text-gray-600">50% Thiết yếu</span>
                </div>
                <div className="flex items-center gap-1">
                    <div className="w-2 h-2 bg-orange-500 rounded-full"></div>
                    <span className="text-gray-600">30% Mong muốn</span>
                </div>
                <div className="flex items-center gap-1">
                    <div className="w-2 h-2 bg-green-500 rounded-full"></div>
                    <span className="text-gray-600">20% Tiết kiệm</span>
                </div>
            </div>
        </div>
    )
}

// Single suggestion item
const SuggestionItem = ({ suggestion }) => {
    const { 
        categoryName, 
        categoryIcon,
        categoryColor,
        currentMonthlyAvg, 
        suggestedBudget, 
        percentOfIncome, 
        recommendation,
        reason,
        priority,
        potentialMonthlySavings,
        benchmarkIdeal
    } = suggestion
    
    const getRecommendationStyle = () => {
        switch (recommendation) {
            case 'reduce':
                return { 
                    icon: TrendingDown, 
                    color: 'text-red-600', 
                    bg: 'bg-red-50',
                    border: 'border-red-200',
                    text: 'Nên giảm'
                }
            case 'increase':
                return { 
                    icon: TrendingUp, 
                    color: 'text-blue-600', 
                    bg: 'bg-blue-50',
                    border: 'border-blue-200',
                    text: 'Có thể tăng'
                }
            default:
                return { 
                    icon: Check, 
                    color: 'text-green-600', 
                    bg: 'bg-green-50',
                    border: 'border-green-200',
                    text: 'Hợp lý'
                }
        }
    }
    
    const style = getRecommendationStyle()
    const Icon = style.icon

    const getPriorityBadge = () => {
        if (priority === 1) return { text: 'Ưu tiên cao', color: 'bg-red-100 text-red-700' }
        if (priority === 2) return { text: 'Quan trọng', color: 'bg-orange-100 text-orange-700' }
        return { text: 'Gợi ý', color: 'bg-blue-100 text-blue-700' }
    }

    const priorityBadge = getPriorityBadge()

    return (
        <div className={`p-4 bg-white rounded-lg border-2 ${style.border} hover:shadow-md transition-all`}>
            <div className="flex items-start gap-3">
                {/* Category Icon */}
                <div
                    className="w-12 h-12 rounded-full flex items-center justify-center text-xl flex-shrink-0"
                    style={{ backgroundColor: categoryColor + '30' || '#e5e7eb' }}
                >
                    {categoryIcon || '📝'}
                </div>

                {/* Content */}
                <div className="flex-1 min-w-0">
                    <div className="flex items-start justify-between mb-2">
                        <h4 className="font-semibold text-gray-800">{categoryName}</h4>
                        <span className={`text-xs px-2 py-1 rounded-full ${priorityBadge.color} whitespace-nowrap`}>
                            {priorityBadge.text}
                        </span>
                    </div>

                    {/* Current vs Suggested */}
                    <div className="flex items-center gap-2 mb-2">
                        <div className="flex-1">
                            <div className="text-xs text-gray-500 mb-1">Hiện tại</div>
                            <div className="font-semibold text-gray-700">
                                {formatCurrency(currentMonthlyAvg || 0)}
                            </div>
                            <div className="text-xs text-gray-400">{percentOfIncome || 0}% thu nhập</div>
                        </div>
                        <div className="text-gray-300">→</div>
                        <div className="flex-1">
                            <div className="text-xs text-gray-500 mb-1">Gợi ý</div>
                            <div className={`font-semibold ${style.color}`}>
                                {formatCurrency(suggestedBudget || 0)}
                            </div>
                            <div className="text-xs text-gray-400">~{benchmarkIdeal || 0}% lý tưởng</div>
                        </div>
                    </div>

                    {/* Reason */}
                    <div className={`p-2 rounded-md ${style.bg} mb-2`}>
                        <p className="text-xs text-gray-600">{reason || 'Đang phân tích...'}</p>
                    </div>

                    {/* Savings Potential */}
                    {(potentialMonthlySavings || 0) > 0 && (
                        <div className="flex items-center justify-between p-2 bg-green-50 rounded-md">
                            <span className="text-xs text-gray-600">Tiết kiệm được:</span>
                            <div className="text-right">
                                <div className="font-bold text-green-600 text-sm">
                                    {formatCurrency(potentialMonthlySavings || 0)}/tháng
                                </div>
                                <div className="text-xs text-green-500">
                                    {formatCurrency((potentialMonthlySavings || 0) * 12)}/năm
                                </div>
                            </div>
                        </div>
                    )}

                    {/* Action Badge */}
                    <div className={`inline-flex items-center gap-1 px-2 py-1 rounded-full ${style.bg} mt-2`}>
                        <Icon className={`w-3 h-3 ${style.color}`} />
                        <span className={`text-xs font-medium ${style.color}`}>{style.text}</span>
                    </div>
                </div>
            </div>
        </div>
    )
}

export default function SmartBudgetCard() {
    const { data, isLoading, error, refetch } = useQuery({
        queryKey: ['smartBudget'],
        queryFn: () => api.get('/smart/budget-suggestions').then(res => res.data),
        staleTime: 300000
    })

    if (isLoading) {
        return (
            <div className="bg-white p-6 rounded-xl shadow-sm animate-pulse">
                <div className="h-6 bg-gray-200 rounded w-1/3 mb-4"></div>
                <div className="h-3 bg-gray-200 rounded mb-4"></div>
                <div className="space-y-3">
                    <div className="h-16 bg-gray-100 rounded"></div>
                    <div className="h-16 bg-gray-100 rounded"></div>
                </div>
            </div>
        )
    }

    if (error || !data?.success) {
        return (
            <div className="bg-white p-6 rounded-xl shadow-sm">
                <div className="text-center py-4">
                    <p className="text-gray-500">Không thể tải gợi ý ngân sách</p>
                    <button 
                        onClick={() => refetch()}
                        className="mt-2 text-sm text-blue-600 hover:text-blue-800"
                    >
                        Thử lại
                    </button>
                </div>
            </div>
        )
    }

    const { suggestions, summary } = data.data || {}

    return (
        <div className="bg-white p-6 rounded-xl shadow-sm">
            {/* Header */}
            <div className="flex items-center justify-between mb-4">
                <h2 className="text-lg font-semibold flex items-center gap-2">
                    <Wallet className="w-5 h-5 text-teal-600" />
                    Gợi ý ngân sách thông minh
                </h2>
                <button 
                    onClick={() => refetch()}
                    className="p-2 hover:bg-gray-100 rounded-full transition-colors"
                    title="Làm mới"
                >
                    <RefreshCw className="w-4 h-4 text-gray-500" />
                </button>
            </div>

            {/* 50/30/20 Badge */}
            <div className="inline-flex items-center gap-1 px-2 py-1 bg-teal-50 text-teal-700 text-xs rounded-full mb-4">
                <Wallet className="w-3 h-3" />
                <span>Quy tắc 50/30/20</span>
            </div>

            {/* Summary */}
            {summary && (
                <>
                    <div className="grid grid-cols-2 gap-3 mb-4">
                        <div className="p-3 bg-gradient-to-br from-blue-50 to-blue-100 rounded-lg">
                            <p className="text-xs text-gray-600 mb-1">Thu nhập/tháng</p>
                            <p className="text-lg font-bold text-blue-700">
                                {formatCurrency(summary.monthlyIncome || 0)}
                            </p>
                        </div>
                        <div className="p-3 bg-gradient-to-br from-green-50 to-green-100 rounded-lg">
                            <p className="text-xs text-gray-600 mb-1">Tiết kiệm tiềm năng</p>
                            <p className="text-lg font-bold text-green-700">
                                {formatCurrency(summary.potentialMonthlySavings || 0)}
                            </p>
                            <p className="text-xs text-green-600">
                                {formatCurrency(summary.potentialYearlySavings || 0)}/năm
                            </p>
                        </div>
                    </div>

                    {(summary.needsAdjustment || 0) > 0 && (
                        <div className="mb-4 p-3 bg-amber-50 border border-amber-200 rounded-lg">
                            <div className="flex items-center gap-2">
                                <Wallet className="w-4 h-4 text-amber-600" />
                                <span className="text-sm font-medium text-amber-800">
                                    {summary.needsAdjustment} danh mục cần điều chỉnh
                                </span>
                            </div>
                        </div>
                    )}

                    <BudgetRuleBar 
                        essentials={summary.essentials || 0}
                        wants={summary.wants || 0}
                        savings={summary.savings || 0}
                    />

                    <div className="grid grid-cols-3 gap-2 mb-4 text-center">
                        <div className="p-2 bg-blue-50 rounded-lg">
                            <p className="text-xs text-gray-600">Thiết yếu</p>
                            <p className="text-sm font-semibold text-blue-600">
                                {formatCurrency(summary.essentials || 0)}
                            </p>
                        </div>
                        <div className="p-2 bg-orange-50 rounded-lg">
                            <p className="text-xs text-gray-600">Mong muốn</p>
                            <p className="text-sm font-semibold text-orange-600">
                                {formatCurrency(summary.wants || 0)}
                            </p>
                        </div>
                        <div className="p-2 bg-green-50 rounded-lg">
                            <p className="text-xs text-gray-600">Tiết kiệm</p>
                            <p className="text-sm font-semibold text-green-600">
                                {formatCurrency(summary.savings || 0)}
                            </p>
                        </div>
                    </div>
                </>
            )}

            {/* Suggestions */}
            {suggestions && suggestions.length > 0 ? (
                <>
                    <div className="flex items-center justify-between mb-3">
                        <p className="text-sm font-medium text-gray-700">
                            Gợi ý chi tiết ({suggestions.length})
                        </p>
                        <span className="text-xs text-gray-400">
                            Dựa trên chi tiêu 3 tháng
                        </span>
                    </div>
                    <div className="space-y-3 max-h-[500px] overflow-y-auto pr-1">
                        {suggestions.map((suggestion, index) => (
                            <SuggestionItem key={index} suggestion={suggestion} />
                        ))}
                    </div>
                </>
            ) : (
                <div className="text-center py-6">
                    <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-3">
                        <Check className="w-8 h-8 text-green-500" />
                    </div>
                    <p className="text-gray-600 font-medium">Chi tiêu hợp lý!</p>
                    <p className="text-sm text-gray-400 mt-1">Không cần điều chỉnh</p>
                </div>
            )}

            {/* Footer */}
            <div className="mt-4 pt-3 border-t border-gray-100 text-center">
                <p className="text-xs text-gray-400">
                    Dựa trên chi tiêu 3 tháng gần đây
                </p>
            </div>
        </div>
    )
}
