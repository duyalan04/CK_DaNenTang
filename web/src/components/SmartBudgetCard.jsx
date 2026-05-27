import { useQuery } from '@tanstack/react-query'
import { TrendingDown, TrendingUp, Check, RefreshCw, ChevronDown, ChevronUp, Wallet, PiggyBank, ShoppingCart, Sparkles } from 'lucide-react'
import { useState } from 'react'
import api from '../lib/api'

const formatCurrency = (value) => {
    const numValue = Number(value)
    if (!isFinite(numValue) || isNaN(numValue)) return '0 ₫'
    return new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(numValue)
}

const formatShort = (value) => {
    const num = Number(value)
    if (!isFinite(num) || isNaN(num)) return '0'
    if (num >= 1000000) return `${(num / 1000000).toFixed(1)}tr`
    if (num >= 1000) return `${Math.round(num / 1000)}k`
    return num.toLocaleString('vi-VN')
}

// ── Donut chart cho 50/30/20 ──
const DonutChart = ({ essentials, wants, savings, income }) => {
    const total = income || 1
    const pEssentials = Math.round((essentials / total) * 100)
    const pWants = Math.round((wants / total) * 100)
    const pSavings = 100 - pEssentials - pWants

    const radius = 40
    const circumference = 2 * Math.PI * radius

    const s1 = (pEssentials / 100) * circumference
    const s2 = (pWants / 100) * circumference
    const s3 = (pSavings / 100) * circumference

    const gap = 2
    const offset1 = 0
    const offset2 = s1 + gap
    const offset3 = s1 + s2 + gap * 2

    return (
        <div className="relative w-32 h-32 flex-shrink-0">
            <svg viewBox="0 0 100 100" className="w-full h-full -rotate-90">
                {/* Essentials */}
                <circle cx="50" cy="50" r={radius}
                    fill="none" stroke="#3b82f6" strokeWidth="10"
                    strokeDasharray={`${s1 - gap} ${circumference - s1 + gap}`}
                    strokeDashoffset={-offset1}
                    strokeLinecap="round" className="transition-all duration-700"
                />
                {/* Wants */}
                <circle cx="50" cy="50" r={radius}
                    fill="none" stroke="#f97316" strokeWidth="10"
                    strokeDasharray={`${s2 - gap} ${circumference - s2 + gap}`}
                    strokeDashoffset={-offset2}
                    strokeLinecap="round" className="transition-all duration-700"
                />
                {/* Savings */}
                <circle cx="50" cy="50" r={radius}
                    fill="none" stroke="#22c55e" strokeWidth="10"
                    strokeDasharray={`${s3 - gap} ${circumference - s3 + gap}`}
                    strokeDashoffset={-offset3}
                    strokeLinecap="round" className="transition-all duration-700"
                />
            </svg>
            <div className="absolute inset-0 flex flex-col items-center justify-center">
                <span className="text-xs text-gray-400 leading-none">Thu nhập</span>
                <span className="text-base font-bold text-gray-800 leading-tight">{formatShort(income)}</span>
            </div>
        </div>
    )
}

// ── Visual bar comparison ──
const ComparisonBar = ({ current, suggested, income }) => {
    const max = income || 1
    const currentPct = Math.min((current / max) * 100, 100)
    const suggestedPct = Math.min((suggested / max) * 100, 100)
    const isReduce = suggested < current

    return (
        <div className="space-y-2 flex-1">
            <div className="flex items-center gap-2">
                <span className="text-xs text-gray-400 w-16 text-right">Đang chi</span>
                <div className="flex-1 h-2.5 bg-gray-100 rounded-full overflow-hidden">
                    <div
                        className="h-full rounded-full bg-gray-400 transition-all duration-500"
                        style={{ width: `${currentPct}%` }}
                    />
                </div>
                <span className="text-xs font-semibold text-gray-600 w-20 text-right">{formatShort(current)}</span>
            </div>
            <div className="flex items-center gap-2">
                <span className="text-xs text-gray-400 w-16 text-right">Nên chi</span>
                <div className="flex-1 h-2.5 bg-gray-100 rounded-full overflow-hidden">
                    <div
                        className={`h-full rounded-full transition-all duration-500 ${isReduce ? 'bg-emerald-500' : 'bg-blue-500'}`}
                        style={{ width: `${suggestedPct}%` }}
                    />
                </div>
                <span className={`text-xs font-semibold w-20 text-right ${isReduce ? 'text-emerald-600' : 'text-blue-600'}`}>
                    {formatShort(suggested)}
                </span>
            </div>
        </div>
    )
}

// ── Suggestion Item – gọn, dễ hiểu ──
const SuggestionItem = ({ suggestion, income }) => {
    const [isOpen, setIsOpen] = useState(false)
    const {
        categoryName, categoryIcon, categoryColor,
        currentMonthlyAvg, suggestedBudget,
        percentOfIncome, recommendation, reason,
        priority, potentialMonthlySavings, benchmarkIdeal
    } = suggestion

    const isReduce = recommendation === 'reduce'
    const isIncrease = recommendation === 'increase'

    const config = isReduce
        ? { icon: TrendingDown, color: 'text-red-500', bg: 'bg-red-50', ringColor: 'ring-red-200', label: 'Giảm bớt' }
        : isIncrease
            ? { icon: TrendingUp, color: 'text-blue-500', bg: 'bg-blue-50', ringColor: 'ring-blue-200', label: 'Tăng thêm' }
            : { icon: Check, color: 'text-emerald-500', bg: 'bg-emerald-50', ringColor: 'ring-emerald-200', label: 'Hợp lý' }

    const Icon = config.icon
    const savingsAmount = (potentialMonthlySavings || 0)

    return (
        <div
            className={`rounded-xl border transition-all duration-200 ${isOpen ? 'ring-1 ' + config.ringColor + ' shadow-sm' : 'hover:shadow-sm'} ${isReduce ? 'border-red-100' : isIncrease ? 'border-blue-100' : 'border-gray-100'}`}
        >
            {/* Header row — always visible */}
            <button
                onClick={() => setIsOpen(!isOpen)}
                className="w-full flex items-center gap-3 p-3.5 text-left"
            >
                {/* Category icon */}
                <div
                    className="w-11 h-11 rounded-lg flex items-center justify-center text-xl flex-shrink-0"
                    style={{ backgroundColor: (categoryColor || '#9CA3AF') + '20' }}
                >
                    {categoryIcon || '📝'}
                </div>

                {/* Name + percent */}
                <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2">
                        <span className="font-semibold text-base text-gray-800 truncate">{categoryName}</span>
                        {priority === 1 && (
                            <span className="flex-shrink-0 w-2 h-2 rounded-full bg-red-500 animate-pulse" title="Ưu tiên cao" />
                        )}
                    </div>
                    <span className="text-sm text-gray-400">
                        {(percentOfIncome || 0).toFixed(1)}% thu nhập · {formatCurrency(currentMonthlyAvg || 0)}/tháng
                    </span>
                </div>

                {/* Action tag */}
                <div className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm font-medium ${config.bg} ${config.color}`}>
                    <Icon className="w-3.5 h-3.5" />
                    <span className="hidden sm:inline">{config.label}</span>
                </div>

                {/* Expand arrow */}
                {isOpen
                    ? <ChevronUp className="w-4 h-4 text-gray-300 flex-shrink-0" />
                    : <ChevronDown className="w-4 h-4 text-gray-300 flex-shrink-0" />
                }
            </button>

            {/* Expanded details */}
            {isOpen && (
                <div className="px-3 pb-3 space-y-3 animate-in fade-in slide-in-from-top-1 duration-200">
                    {/* Visual comparison */}
                    <div className="flex items-center gap-3">
                        <ComparisonBar
                            current={currentMonthlyAvg || 0}
                            suggested={suggestedBudget || 0}
                            income={income}
                        />
                    </div>

                    {/* Reason */}
                    {reason && (
                        <p className="text-sm text-gray-500 leading-relaxed pl-1">
                            💡 {reason}
                        </p>
                    )}

                    {/* Savings highlight */}
                    {savingsAmount > 0 && (
                        <div className="flex items-center justify-between p-3 bg-emerald-50 rounded-lg">
                            <div className="flex items-center gap-2">
                                <PiggyBank className="w-4 h-4 text-emerald-500" />
                                <span className="text-sm text-gray-600">Có thể tiết kiệm</span>
                            </div>
                            <div className="text-right">
                                <span className="text-base font-bold text-emerald-600">{formatCurrency(savingsAmount)}</span>
                                <span className="text-[10px] text-emerald-400 ml-1">/tháng</span>
                            </div>
                        </div>
                    )}
                </div>
            )}
        </div>
    )
}

// ── Main Component ──
export default function SmartBudgetCard() {
    const { data, isLoading, error, refetch } = useQuery({
        queryKey: ['smartBudget'],
        queryFn: () => api.get('/smart/budget-suggestions').then(res => res.data),
        staleTime: 300000
    })

    if (isLoading) {
        return (
            <div className="bg-white p-6 rounded-xl shadow-sm animate-pulse">
                <div className="h-6 bg-gray-200 rounded w-1/3 mb-4" />
                <div className="flex gap-4 mb-4">
                    <div className="w-28 h-28 bg-gray-100 rounded-full" />
                    <div className="flex-1 space-y-3">
                        <div className="h-8 bg-gray-100 rounded" />
                        <div className="h-8 bg-gray-100 rounded" />
                        <div className="h-8 bg-gray-100 rounded" />
                    </div>
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
    const monthlyIncome = summary?.monthlyIncome || 0
    const needsAdjust = summary?.needsAdjustment || 0
    const totalSavings = summary?.potentialMonthlySavings || 0
    const reduceSuggestions = suggestions?.filter(s => s.recommendation === 'reduce') || []
    const otherSuggestions = suggestions?.filter(s => s.recommendation !== 'reduce') || []

    return (
        <div className="bg-white rounded-xl shadow-sm overflow-hidden">
            {/* ── Header ── */}
            <div className="px-5 pt-5 pb-0">
                <div className="flex items-center justify-between mb-1">
                    <h2 className="text-lg font-bold text-gray-800 flex items-center gap-2">
                        <Sparkles className="w-5 h-5 text-teal-500" />
                        Ngân sách thông minh
                    </h2>
                    <button
                        onClick={() => refetch()}
                        className="p-1.5 hover:bg-gray-100 rounded-lg transition-colors"
                        title="Làm mới"
                    >
                        <RefreshCw className="w-4 h-4 text-gray-400" />
                    </button>
                </div>
                <p className="text-sm text-gray-400 mb-4">Phân tích 3 tháng · Quy tắc 50/30/20</p>
            </div>

            {/* ── Overview: Donut + breakdown ── */}
            {summary && (
                <div className="px-5 pb-4">
                    <div className="flex items-center gap-5">
                        <DonutChart
                            essentials={summary.essentials}
                            wants={summary.wants}
                            savings={summary.savings}
                            income={monthlyIncome}
                        />

                        {/* Legend + amounts */}
                        <div className="flex-1 space-y-3">
                            {[
                                { label: 'Thiết yếu', pct: '50%', amount: summary.essentials, color: '#3b82f6', icon: '🏠' },
                                { label: 'Mong muốn', pct: '30%', amount: summary.wants, color: '#f97316', icon: '🛍️' },
                                { label: 'Tiết kiệm', pct: '20%', amount: summary.savings, color: '#22c55e', icon: '💰' },
                            ].map((item) => (
                                <div key={item.label} className="flex items-center gap-2.5">
                                    <div className="w-2.5 h-2.5 rounded-full flex-shrink-0" style={{ backgroundColor: item.color }} />
                                    <span className="text-sm text-gray-500 w-20">{item.label}</span>
                                    <span className="text-sm font-semibold text-gray-700 flex-1 text-right">
                                        {formatCurrency(item.amount || 0)}
                                    </span>
                                </div>
                            ))}
                        </div>
                    </div>

                    {/* Quick stats row */}
                    {(needsAdjust > 0 || totalSavings > 0) && (
                        <div className="flex gap-2 mt-4">
                            {needsAdjust > 0 && (
                                <div className="flex-1 flex items-center gap-2 px-3 py-2 bg-amber-50 rounded-lg">
                                    <ShoppingCart className="w-4 h-4 text-amber-500" />
                                    <span className="text-sm text-amber-700 font-medium">
                                        {needsAdjust} mục cần giảm
                                    </span>
                                </div>
                            )}
                            {totalSavings > 0 && (
                                <div className="flex-1 flex items-center gap-2 px-3 py-2.5 bg-emerald-50 rounded-lg">
                                    <PiggyBank className="w-4 h-4 text-emerald-500" />
                                    <span className="text-sm text-emerald-700 font-medium">
                                        Tiết kiệm ~{formatShort(totalSavings)}/tháng
                                    </span>
                                </div>
                            )}
                        </div>
                    )}
                </div>
            )}

            {/* ── Divider ── */}
            <div className="border-t border-gray-100" />

            {/* ── Suggestion list ── */}
            <div className="px-5 py-4">
                {suggestions && suggestions.length > 0 ? (
                    <>
                        {reduceSuggestions.length > 0 && (
                            <p className="text-sm font-semibold text-gray-500 uppercase tracking-wider mb-2">
                                Cần điều chỉnh
                            </p>
                        )}
                        <div className="space-y-2">
                            {reduceSuggestions.map((s, i) => (
                                <SuggestionItem key={`r-${i}`} suggestion={s} income={monthlyIncome} />
                            ))}
                        </div>

                        {otherSuggestions.length > 0 && (
                            <>
                                <p className="text-xs font-semibold text-gray-500 uppercase tracking-wider mb-2 mt-4">
                                    Đang hợp lý
                                </p>
                                <div className="space-y-2">
                                    {otherSuggestions.map((s, i) => (
                                        <SuggestionItem key={`o-${i}`} suggestion={s} income={monthlyIncome} />
                                    ))}
                                </div>
                            </>
                        )}
                    </>
                ) : (
                    <div className="text-center py-6">
                        <div className="w-14 h-14 bg-emerald-50 rounded-full flex items-center justify-center mx-auto mb-3">
                            <Check className="w-7 h-7 text-emerald-500" />
                        </div>
                        <p className="text-sm font-medium text-gray-700">Chi tiêu hợp lý!</p>
                        <p className="text-xs text-gray-400 mt-1">Không cần điều chỉnh gì</p>
                    </div>
                )}
            </div>

            {/* ── Footer ── */}
            <div className="px-5 py-2.5 bg-gray-50 text-center">
                <p className="text-xs text-gray-400">
                    Dựa trên chi tiêu 3 tháng gần đây · Cập nhật mỗi 5 phút
                </p>
            </div>
        </div>
    )
}
