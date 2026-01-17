import { useQuery } from '@tanstack/react-query'
import { Wallet, TrendingDown, TrendingUp, Check, RefreshCw } from 'lucide-react'
import api from '../lib/api'

const formatCurrency = (value) => {
    return new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(value)
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
    const { categoryName, currentMonthlyAvg, suggestedBudget, percentOfIncome, recommendation } = suggestion
    
    const getRecommendationStyle = () => {
        switch (recommendation) {
            case 'reduce':
                return { 
                    icon: TrendingDown, 
                    color: 'text-red-600', 
                    bg: 'bg-red-50',
                    text: 'Giảm'
                }
            case 'increase':
                return { 
                    icon: TrendingUp, 
                    color: 'text-green-600', 
                    bg: 'bg-green-50',
                    text: 'Tăng'
                }
            default:
                return { 
                    icon: Check, 
                    color: 'text-blue-600', 
                    bg: 'bg-blue-50',
                    text: 'Giữ'
                }
        }
    }
    
    const style = getRecommendationStyle()
    const Icon = style.icon

    return (
        <div className="flex items-center justify-between p-3 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors">
            <div className="flex-1">
                <p className="font-medium text-gray-800">{categoryName}</p>
                <p className="text-xs text-gray-500">
                    {formatCurrency(currentMonthlyAvg)} → {formatCurrency(suggestedBudget)}
                </p>
                <p className="text-xs text-gray-400">{percentOfIncome}% thu nhập</p>
            </div>
            <div className={`flex items-center gap-1 px-2 py-1 rounded-full ${style.bg}`}>
                <Icon className={`w-3 h-3 ${style.color}`} />
                <span className={`text-xs font-medium ${style.color}`}>{style.text}</span>
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
                    <div className="text-center mb-4 p-3 bg-gray-50 rounded-lg">
                        <p className="text-sm text-gray-600">Thu nhập trung bình</p>
                        <p className="text-xl font-bold text-gray-800">
                            {formatCurrency(summary.monthlyIncome)}/tháng
                        </p>
                    </div>

                    <BudgetRuleBar 
                        essentials={summary.essentials}
                        wants={summary.wants}
                        savings={summary.savings}
                    />

                    <div className="grid grid-cols-3 gap-2 mb-4 text-center">
                        <div className="p-2 bg-blue-50 rounded-lg">
                            <p className="text-xs text-gray-600">Thiết yếu</p>
                            <p className="text-sm font-semibold text-blue-600">
                                {formatCurrency(summary.essentials)}
                            </p>
                        </div>
                        <div className="p-2 bg-orange-50 rounded-lg">
                            <p className="text-xs text-gray-600">Mong muốn</p>
                            <p className="text-sm font-semibold text-orange-600">
                                {formatCurrency(summary.wants)}
                            </p>
                        </div>
                        <div className="p-2 bg-green-50 rounded-lg">
                            <p className="text-xs text-gray-600">Tiết kiệm</p>
                            <p className="text-sm font-semibold text-green-600">
                                {formatCurrency(summary.savings)}
                            </p>
                        </div>
                    </div>
                </>
            )}

            {/* Suggestions */}
            {suggestions && suggestions.length > 0 && (
                <>
                    <p className="text-sm font-medium text-gray-700 mb-2">Gợi ý theo danh mục</p>
                    <div className="space-y-2 max-h-[300px] overflow-y-auto">
                        {suggestions.slice(0, 5).map((suggestion, index) => (
                            <SuggestionItem key={index} suggestion={suggestion} />
                        ))}
                    </div>
                    
                    {suggestions.length > 5 && (
                        <p className="text-xs text-gray-400 text-center mt-2">
                            +{suggestions.length - 5} danh mục khác
                        </p>
                    )}
                </>
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
