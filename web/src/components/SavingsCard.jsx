import { useQuery } from '@tanstack/react-query'
import { PiggyBank, TrendingDown, ChevronRight, Sparkles } from 'lucide-react'
import api from '../lib/api'

const formatCurrency = (value) => {
    return new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(value)
}

// Progress bar cho mức độ priority
const PriorityBar = ({ priority }) => {
    const width = ((4 - priority) / 3) * 100

    return (
        <div className="w-full h-1.5 bg-gray-200 rounded-full overflow-hidden">
            <div
                className={`h-full transition-all duration-300 ${priority === 1 ? 'bg-red-500' :
                        priority === 2 ? 'bg-orange-500' :
                            'bg-yellow-500'
                    }`}
                style={{ width: `${width}%` }}
            />
        </div>
    )
}

// Single Recommendation Item
const RecommendationItem = ({ recommendation }) => {
    const { category, currentMonthlySpending, suggestedReduction, potentialYearlySavings, tip, priority } = recommendation

    return (
        <div className="p-4 bg-white rounded-lg border border-gray-100 hover:border-green-200 hover:shadow-sm transition-all">
            <div className="flex items-start gap-3">
                {/* Category Icon */}
                <div
                    className="w-10 h-10 rounded-full flex items-center justify-center text-lg"
                    style={{ backgroundColor: category?.color + '20' || '#e5e7eb' }}
                >
                    {category?.icon || '📦'}
                </div>

                {/* Content */}
                <div className="flex-1 min-w-0">
                    <div className="flex items-center justify-between mb-1">
                        <h4 className="font-medium text-gray-800">
                            {category?.name || 'Không xác định'}
                        </h4>
                        <span className={`text-xs px-2 py-0.5 rounded-full ${priority === 1 ? 'bg-red-100 text-red-700' :
                                priority === 2 ? 'bg-orange-100 text-orange-700' :
                                    'bg-yellow-100 text-yellow-700'
                            }`}>
                            {priority === 1 ? 'Ưu tiên cao' : priority === 2 ? 'Quan trọng' : 'Gợi ý'}
                        </span>
                    </div>

                    <PriorityBar priority={priority} />

                    <div className="mt-2 flex items-center gap-4 text-sm">
                        <div>
                            <span className="text-gray-500">Hiện tại:</span>
                            <span className="ml-1 font-medium text-gray-700">
                                {formatCurrency(currentMonthlySpending)}/tháng
                            </span>
                        </div>
                        <div className="flex items-center text-green-600">
                            <TrendingDown className="w-4 h-4 mr-1" />
                            <span>Giảm {suggestedReduction}%</span>
                        </div>
                    </div>

                    <p className="mt-2 text-sm text-gray-500 italic">
                        💡 {tip}
                    </p>

                    <div className="mt-2 p-2 bg-green-50 rounded-md">
                        <div className="flex items-center justify-between">
                            <span className="text-sm text-gray-600">Tiết kiệm tiềm năng:</span>
                            <span className="font-bold text-green-600">
                                {formatCurrency(potentialYearlySavings)}/năm
                            </span>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    )
}

export default function SavingsCard() {
    const { data, isLoading, error } = useQuery({
        queryKey: ['savings'],
        queryFn: () => api.get('/analytics/savings').then(res => res.data),
        staleTime: 300000
    })

    if (isLoading) {
        return (
            <div className="bg-white p-6 rounded-xl shadow-sm animate-pulse">
                <div className="h-6 bg-gray-200 rounded w-1/3 mb-4"></div>
                <div className="space-y-4">
                    <div className="h-24 bg-gray-100 rounded-lg"></div>
                    <div className="h-24 bg-gray-100 rounded-lg"></div>
                </div>
            </div>
        )
    }

    if (error || !data?.success) {
        return (
            <div className="bg-white p-6 rounded-xl shadow-sm">
                <p className="text-gray-500 text-center">Không thể tải gợi ý tiết kiệm</p>
            </div>
        )
    }

    const { recommendations, summary } = data.data

    if (recommendations.length === 0) {
        return (
            <div className="bg-white p-6 rounded-xl shadow-sm">
                <h2 className="text-lg font-semibold flex items-center gap-2 mb-4">
                    <PiggyBank className="w-5 h-5 text-green-600" />
                    Gợi ý tiết kiệm
                </h2>
                <div className="text-center py-6">
                    <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-3">
                        <Sparkles className="w-8 h-8 text-green-500" />
                    </div>
                    <p className="text-gray-600">Chi tiêu của bạn đang hợp lý! 🎉</p>
                    <p className="text-sm text-gray-400 mt-1">Chưa cần điều chỉnh</p>
                </div>
            </div>
        )
    }

    return (
        <div className="bg-white p-6 rounded-xl shadow-sm">
            {/* Header */}
            <div className="flex items-center justify-between mb-4">
                <h2 className="text-lg font-semibold flex items-center gap-2">
                    <PiggyBank className="w-5 h-5 text-green-600" />
                    Gợi ý tiết kiệm
                </h2>
                <span className="text-sm text-gray-500">
                    {recommendations.length} gợi ý
                </span>
            </div>

            {/* Total Potential Savings */}
            <div className="mb-4 p-4 bg-gradient-to-r from-green-500 to-emerald-600 rounded-lg text-white">
                <div className="flex items-center justify-between">
                    <div>
                        <p className="text-sm text-green-100">Tiềm năng tiết kiệm/năm</p>
                        <p className="text-2xl font-bold">{formatCurrency(summary.totalPotentialYearlySavings)}</p>
                    </div>
                    <PiggyBank className="w-12 h-12 text-green-200" />
                </div>
            </div>

            {/* Recommendations List */}
            <div className="space-y-3 max-h-[400px] overflow-y-auto">
                {recommendations.map((rec, index) => (
                    <RecommendationItem key={index} recommendation={rec} />
                ))}
            </div>

            {/* Footer */}
            <div className="mt-4 pt-3 border-t border-gray-100 text-center">
                <p className="text-xs text-gray-400">
                    Chi tiêu trung bình: {formatCurrency(summary.totalMonthlyExpense)}/tháng
                </p>
            </div>
        </div>
    )
}
