import { useQuery } from '@tanstack/react-query'
import { PiggyBank, TrendingDown, ArrowDownRight, Sparkles, RefreshCw, Target } from 'lucide-react'
import api from '../lib/api'

const formatCurrency = (value) =>
    new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(value)

const formatShortCurrency = (value) => {
    if (value >= 1000000) return `${(value / 1000000).toFixed(1).replace('.0', '')}tr`
    if (value >= 1000) return `${(value / 1000).toFixed(0)}K`
    return value.toString()
}

const PriorityDot = ({ priority }) => (
    <span className={`inline-block w-2 h-2 rounded-full ${priority === 1 ? 'bg-red-400' : priority === 2 ? 'bg-amber-400' : 'bg-emerald-400'}`} />
)

const RecommendationItem = ({ recommendation, index }) => {
    const { category, currentMonthlySpending, suggestedReduction, potentialYearlySavings, tip, priority } = recommendation
    const monthlySaving = potentialYearlySavings / 12

    return (
        <div className="group relative p-4 rounded-xl border border-gray-100 hover:border-emerald-200 hover:bg-emerald-50/30 transition-all duration-200">
            <div className="flex items-start gap-3">
                {/* Icon */}
                <div
                    className="w-10 h-10 rounded-xl flex items-center justify-center text-lg shrink-0"
                    style={{ backgroundColor: (category?.color || '#9ca3af') + '15' }}
                >
                    {category?.icon || '📦'}
                </div>

                {/* Content */}
                <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 mb-1">
                        <PriorityDot priority={priority} />
                        <h4 className="font-semibold text-gray-800 text-[15px]">{category?.name || 'Không xác định'}</h4>
                    </div>

                    {/* Spending → Target flow */}
                    <div className="flex items-center gap-2 text-sm mb-2">
                        <span className="text-gray-500">{formatShortCurrency(currentMonthlySpending)}/th</span>
                        <ArrowDownRight className="w-3.5 h-3.5 text-emerald-500" />
                        <span className="font-semibold text-emerald-600">
                            {formatShortCurrency(currentMonthlySpending * (1 - suggestedReduction / 100))}/th
                        </span>
                        <span className="text-xs text-gray-400">(-{suggestedReduction}%)</span>
                    </div>

                    {/* Tip */}
                    {tip && (
                        <p className="text-xs text-gray-400 leading-relaxed line-clamp-2">{tip}</p>
                    )}
                </div>

                {/* Savings badge */}
                <div className="shrink-0 text-right">
                    <div className="px-3 py-1.5 bg-emerald-50 rounded-lg border border-emerald-100">
                        <p className="text-[11px] text-emerald-500 font-medium">Tiết kiệm</p>
                        <p className="text-sm font-bold text-emerald-600">{formatShortCurrency(monthlySaving)}/th</p>
                    </div>
                </div>
            </div>
        </div>
    )
}

export default function SavingsCard() {
    const { data, isLoading, error, refetch } = useQuery({
        queryKey: ['savings'],
        queryFn: () => api.get('/analytics/savings').then(res => res.data),
        staleTime: 300000
    })

    if (isLoading) {
        return (
            <div className="bg-white p-6 rounded-2xl shadow-sm animate-pulse">
                <div className="h-5 bg-gray-100 rounded w-1/3 mb-4"></div>
                <div className="h-20 bg-gray-50 rounded-xl mb-3"></div>
                <div className="space-y-3">
                    <div className="h-16 bg-gray-50 rounded-xl"></div>
                    <div className="h-16 bg-gray-50 rounded-xl"></div>
                </div>
            </div>
        )
    }

    if (error || !data?.success) {
        return (
            <div className="bg-white p-6 rounded-2xl shadow-sm text-center">
                <PiggyBank className="w-8 h-8 text-gray-300 mx-auto mb-2" />
                <p className="text-gray-400 text-sm">Không thể tải gợi ý tiết kiệm</p>
            </div>
        )
    }

    const { recommendations, summary } = data.data

    if (recommendations.length === 0) {
        return (
            <div className="bg-white p-6 rounded-2xl shadow-sm">
                <h2 className="text-base font-bold text-gray-800 flex items-center gap-2 mb-4">
                    <PiggyBank className="w-5 h-5 text-emerald-500" />
                    Gợi ý tiết kiệm
                </h2>
                <div className="text-center py-6">
                    <div className="w-14 h-14 bg-emerald-50 rounded-2xl flex items-center justify-center mx-auto mb-3">
                        <Sparkles className="w-7 h-7 text-emerald-400" />
                    </div>
                    <p className="text-sm text-gray-600 font-medium">Chi tiêu hợp lý!</p>
                    <p className="text-xs text-gray-400 mt-1">Chưa cần điều chỉnh</p>
                </div>
            </div>
        )
    }

    const monthlySaving = summary.totalPotentialYearlySavings / 12

    return (
        <div className="bg-white p-5 rounded-2xl shadow-sm">
            {/* Header */}
            <div className="flex items-center justify-between mb-4">
                <h2 className="text-base font-bold text-gray-800 flex items-center gap-2">
                    <PiggyBank className="w-5 h-5 text-emerald-500" />
                    Cơ hội tiết kiệm
                </h2>
                <button onClick={() => refetch()} className="p-1.5 hover:bg-gray-100 rounded-lg transition-colors" title="Làm mới">
                    <RefreshCw className="w-3.5 h-3.5 text-gray-400" />
                </button>
            </div>

            {/* Summary - cleaner */}
            <div className="mb-4 p-4 bg-gradient-to-br from-emerald-500 to-teal-600 rounded-xl text-white">
                <div className="flex items-center justify-between">
                    <div>
                        <p className="text-emerald-100 text-xs font-medium mb-0.5">Bạn có thể tiết kiệm mỗi tháng</p>
                        <p className="text-2xl font-black tracking-tight">{formatCurrency(monthlySaving)}</p>
                        <p className="text-emerald-200 text-[11px] mt-1">≈ {formatCurrency(summary.totalPotentialYearlySavings)}/năm</p>
                    </div>
                    <div className="w-12 h-12 bg-white/15 rounded-2xl flex items-center justify-center">
                        <Target className="w-6 h-6 text-white" />
                    </div>
                </div>
            </div>

            {/* Legend */}
            <div className="flex items-center gap-4 mb-3 px-1">
                <div className="flex items-center gap-1.5 text-[11px] text-gray-400">
                    <span className="w-2 h-2 rounded-full bg-red-400" /> Ưu tiên cao
                </div>
                <div className="flex items-center gap-1.5 text-[11px] text-gray-400">
                    <span className="w-2 h-2 rounded-full bg-amber-400" /> Quan trọng
                </div>
                <div className="flex items-center gap-1.5 text-[11px] text-gray-400">
                    <span className="w-2 h-2 rounded-full bg-emerald-400" /> Gợi ý
                </div>
            </div>

            {/* Recommendations */}
            <div className="space-y-2 max-h-[400px] overflow-y-auto">
                {recommendations.map((rec, index) => (
                    <RecommendationItem key={index} recommendation={rec} index={index} />
                ))}
            </div>

            {/* Footer */}
            <div className="mt-3 pt-3 border-t border-gray-50 text-center">
                <p className="text-[11px] text-gray-300">
                    Dựa trên chi tiêu TB {formatCurrency(summary.totalMonthlyExpense)}/tháng
                </p>
            </div>
        </div>
    )
}
