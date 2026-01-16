import { useQuery } from '@tanstack/react-query'
import { Activity, TrendingUp, Target, PiggyBank, AlertTriangle } from 'lucide-react'
import api from '../lib/api'

const formatCurrency = (value) => {
    return new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(value)
}

// Màu gradient theo score
const getScoreColor = (score) => {
    if (score >= 80) return { bg: 'from-green-500 to-emerald-600', text: 'text-green-600' }
    if (score >= 60) return { bg: 'from-blue-500 to-cyan-600', text: 'text-blue-600' }
    if (score >= 40) return { bg: 'from-yellow-500 to-orange-500', text: 'text-yellow-600' }
    return { bg: 'from-red-500 to-rose-600', text: 'text-red-600' }
}

// Circular Progress Component
const CircularProgress = ({ score, size = 120 }) => {
    const circumference = 2 * Math.PI * 45
    const strokeDashoffset = circumference - (score / 100) * circumference
    const colors = getScoreColor(score)

    return (
        <div className="relative" style={{ width: size, height: size }}>
            <svg className="transform -rotate-90" width={size} height={size}>
                {/* Background circle */}
                <circle
                    cx={size / 2}
                    cy={size / 2}
                    r={45}
                    stroke="#e5e7eb"
                    strokeWidth="10"
                    fill="none"
                />
                {/* Progress circle */}
                <circle
                    cx={size / 2}
                    cy={size / 2}
                    r={45}
                    stroke="url(#gradient)"
                    strokeWidth="10"
                    fill="none"
                    strokeLinecap="round"
                    strokeDasharray={circumference}
                    strokeDashoffset={strokeDashoffset}
                    className="transition-all duration-1000 ease-out"
                />
                <defs>
                    <linearGradient id="gradient" x1="0%" y1="0%" x2="100%" y2="0%">
                        <stop offset="0%" className={`${colors.bg.split(' ')[0].replace('from-', 'stop-')}`} />
                        <stop offset="100%" className={`${colors.bg.split(' ')[1].replace('to-', 'stop-')}`} />
                    </linearGradient>
                </defs>
            </svg>
            {/* Score text */}
            <div className="absolute inset-0 flex flex-col items-center justify-center">
                <span className={`text-3xl font-bold ${colors.text}`}>{score}</span>
                <span className="text-xs text-gray-500">/ 100</span>
            </div>
        </div>
    )
}

// Progress Bar nhỏ cho breakdown
const MiniProgressBar = ({ score, maxScore, color = 'blue' }) => {
    const percentage = (score / maxScore) * 100
    const colorClasses = {
        blue: 'bg-blue-500',
        green: 'bg-green-500',
        yellow: 'bg-yellow-500',
        purple: 'bg-purple-500'
    }

    return (
        <div className="w-full h-2 bg-gray-200 rounded-full overflow-hidden">
            <div
                className={`h-full ${colorClasses[color]} transition-all duration-500`}
                style={{ width: `${percentage}%` }}
            />
        </div>
    )
}

export default function HealthScoreCard() {
    const { data, isLoading, error, refetch } = useQuery({
        queryKey: ['healthScore'],
        queryFn: () => api.get('/analytics/health-score').then(res => res.data),
        refetchInterval: 60000 // Refresh mỗi phút
    })

    if (isLoading) {
        return (
            <div className="bg-white p-6 rounded-xl shadow-sm animate-pulse">
                <div className="h-6 bg-gray-200 rounded w-1/3 mb-4"></div>
                <div className="flex justify-center">
                    <div className="w-32 h-32 bg-gray-200 rounded-full"></div>
                </div>
            </div>
        )
    }

    if (error || !data?.success) {
        return (
            <div className="bg-white p-6 rounded-xl shadow-sm">
                <div className="flex items-center gap-2 text-red-500">
                    <AlertTriangle className="w-5 h-5" />
                    <span>Không thể tải dữ liệu</span>
                </div>
            </div>
        )
    }

    const { totalScore, grade, feedback, improvements, breakdown, summary } = data.data

    const breakdownItems = [
        { key: 'savingsRate', color: 'green', icon: PiggyBank },
        { key: 'budgetCompliance', color: 'blue', icon: Target },
        { key: 'spendingStability', color: 'yellow', icon: Activity },
        { key: 'diversification', color: 'purple', icon: TrendingUp }
    ]

    return (
        <div className="bg-white p-6 rounded-xl shadow-sm">
            {/* Header */}
            <div className="flex items-center justify-between mb-4">
                <h2 className="text-lg font-semibold flex items-center gap-2">
                    <Activity className="w-5 h-5 text-blue-600" />
                    Điểm sức khỏe tài chính
                </h2>
                <span className={`px-3 py-1 rounded-full text-sm font-bold ${grade === 'A' ? 'bg-green-100 text-green-700' :
                        grade === 'B' ? 'bg-blue-100 text-blue-700' :
                            grade === 'C' ? 'bg-yellow-100 text-yellow-700' :
                                'bg-red-100 text-red-700'
                    }`}>
                    Grade {grade}
                </span>
            </div>

            {/* Main Score */}
            <div className="flex flex-col md:flex-row items-center gap-6 mb-6">
                <CircularProgress score={totalScore} />

                <div className="flex-1">
                    <p className="text-gray-600 mb-3">{feedback}</p>

                    {improvements.length > 0 && (
                        <div className="space-y-1">
                            <p className="text-sm font-medium text-gray-700">Cần cải thiện:</p>
                            {improvements.map((tip, index) => (
                                <p key={index} className="text-sm text-gray-500">{tip}</p>
                            ))}
                        </div>
                    )}
                </div>
            </div>

            {/* Breakdown */}
            <div className="grid grid-cols-2 gap-4">
                {breakdownItems.map(({ key, color, icon: Icon }) => {
                    const item = breakdown[key]
                    return (
                        <div key={key} className="p-3 bg-gray-50 rounded-lg">
                            <div className="flex items-center gap-2 mb-2">
                                <Icon className={`w-4 h-4 text-${color}-500`} />
                                <span className="text-sm font-medium text-gray-700">{item.label}</span>
                            </div>
                            <MiniProgressBar score={item.score} maxScore={item.maxScore} color={color} />
                            <div className="flex justify-between mt-1">
                                <span className="text-xs text-gray-500">{item.score}/{item.maxScore}</span>
                                <span className="text-xs text-gray-600">{item.value}</span>
                            </div>
                        </div>
                    )
                })}
            </div>

            {/* Summary */}
            <div className="mt-4 pt-4 border-t border-gray-100 grid grid-cols-3 gap-2 text-center">
                <div>
                    <p className="text-xs text-gray-500">Thu nhập</p>
                    <p className="text-sm font-semibold text-green-600">{formatCurrency(summary.income)}</p>
                </div>
                <div>
                    <p className="text-xs text-gray-500">Chi tiêu</p>
                    <p className="text-sm font-semibold text-red-600">{formatCurrency(summary.expense)}</p>
                </div>
                <div>
                    <p className="text-xs text-gray-500">Tiết kiệm</p>
                    <p className={`text-sm font-semibold ${summary.savings >= 0 ? 'text-blue-600' : 'text-red-600'}`}>
                        {formatCurrency(summary.savings)}
                    </p>
                </div>
            </div>
        </div>
    )
}
