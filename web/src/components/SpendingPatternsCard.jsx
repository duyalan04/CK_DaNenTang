import { useQuery } from '@tanstack/react-query'
import { Calendar, TrendingUp, Clock, RefreshCw } from 'lucide-react'
import api from '../lib/api'

const formatCurrency = (value) => {
    return new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(value)
}

// Mini bar chart for day of week
const DayOfWeekChart = ({ data }) => {
    if (!data || data.length === 0) return null
    
    const maxTotal = Math.max(...data.map(d => d.total || 0))
    
    return (
        <div className="flex items-end justify-between gap-1 h-16">
            {data.map((day, index) => {
                const height = maxTotal > 0 ? (day.total / maxTotal) * 100 : 0
                return (
                    <div key={index} className="flex-1 flex flex-col items-center">
                        <div 
                            className="w-full bg-indigo-400 rounded-t transition-all duration-300 hover:bg-indigo-500"
                            style={{ height: `${height}%`, minHeight: day.total > 0 ? '4px' : '0' }}
                            title={`${day.day}: ${formatCurrency(day.total)}`}
                        />
                        <span className="text-[10px] text-gray-500 mt-1">
                            {day.day?.substring(0, 2)}
                        </span>
                    </div>
                )
            })}
        </div>
    )
}

// Pattern highlight card
const PatternCard = ({ icon: Icon, iconColor, title, value, subtitle }) => (
    <div className={`p-3 rounded-lg bg-${iconColor}-50`}>
        <div className="flex items-center gap-2 mb-1">
            <Icon className={`w-4 h-4 text-${iconColor}-500`} />
            <span className="text-xs text-gray-600">{title}</span>
        </div>
        <p className="font-semibold text-gray-800">{value}</p>
        <p className="text-xs text-gray-500">{subtitle}</p>
    </div>
)

export default function SpendingPatternsCard() {
    const { data, isLoading, error, refetch } = useQuery({
        queryKey: ['spendingPatterns'],
        queryFn: () => api.get('/smart/patterns').then(res => res.data),
        staleTime: 300000
    })

    if (isLoading) {
        return (
            <div className="bg-white p-6 rounded-xl shadow-sm animate-pulse">
                <div className="h-6 bg-gray-200 rounded w-1/3 mb-4"></div>
                <div className="space-y-3">
                    <div className="h-16 bg-gray-100 rounded"></div>
                    <div className="grid grid-cols-2 gap-3">
                        <div className="h-20 bg-gray-100 rounded"></div>
                        <div className="h-20 bg-gray-100 rounded"></div>
                    </div>
                </div>
            </div>
        )
    }

    if (error || !data?.success) {
        return (
            <div className="bg-white p-6 rounded-xl shadow-sm">
                <div className="text-center py-4">
                    <p className="text-gray-500">Không thể tải mẫu chi tiêu</p>
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

    const { patterns, insights } = data.data || {}
    
    if (!patterns) {
        return (
            <div className="bg-white p-6 rounded-xl shadow-sm">
                <h2 className="text-lg font-semibold flex items-center gap-2 mb-4">
                    <TrendingUp className="w-5 h-5 text-indigo-600" />
                    Mẫu chi tiêu
                </h2>
                <p className="text-gray-500 text-center py-4">Cần thêm dữ liệu để phân tích</p>
            </div>
        )
    }

    const { peakSpendingDay, peakSpendingWeek, byDayOfWeek, topCategories } = patterns

    return (
        <div className="bg-white p-6 rounded-xl shadow-sm">
            {/* Header */}
            <div className="flex items-center justify-between mb-4">
                <h2 className="text-lg font-semibold flex items-center gap-2">
                    <TrendingUp className="w-5 h-5 text-indigo-600" />
                    Mẫu chi tiêu
                </h2>
                <button 
                    onClick={() => refetch()}
                    className="p-2 hover:bg-gray-100 rounded-full transition-colors"
                    title="Làm mới"
                >
                    <RefreshCw className="w-4 h-4 text-gray-500" />
                </button>
            </div>

            {/* Peak patterns */}
            <div className="grid grid-cols-2 gap-3 mb-4">
                <PatternCard 
                    icon={Calendar}
                    iconColor="blue"
                    title="Ngày chi nhiều nhất"
                    value={peakSpendingDay?.day || 'N/A'}
                    subtitle={`TB: ${formatCurrency(peakSpendingDay?.avgAmount || 0)}`}
                />
                <PatternCard 
                    icon={Clock}
                    iconColor="orange"
                    title="Tuần chi nhiều nhất"
                    value={peakSpendingWeek?.description || 'N/A'}
                    subtitle={`Tuần ${peakSpendingWeek?.week || 0}`}
                />
            </div>

            {/* Day of week chart */}
            {byDayOfWeek && byDayOfWeek.length > 0 && (
                <div className="mb-4">
                    <p className="text-sm font-medium text-gray-700 mb-2">Chi tiêu theo ngày trong tuần</p>
                    <DayOfWeekChart data={byDayOfWeek} />
                </div>
            )}

            {/* Top categories */}
            {topCategories && topCategories.length > 0 && (
                <div className="mb-4">
                    <p className="text-sm font-medium text-gray-700 mb-2">Top danh mục</p>
                    <div className="space-y-2">
                        {topCategories.slice(0, 3).map((cat, index) => (
                            <div key={index} className="flex items-center justify-between text-sm">
                                <span className="text-gray-600">{cat.name}</span>
                                <span className="font-medium">{formatCurrency(cat.total)}</span>
                            </div>
                        ))}
                    </div>
                </div>
            )}

            {/* Insights */}
            {insights && insights.length > 0 && (
                <div className="pt-3 border-t border-gray-100">
                    <div className="space-y-1">
                        {insights.map((insight, index) => (
                            <p key={index} className="text-xs text-gray-600">{insight}</p>
                        ))}
                    </div>
                </div>
            )}
        </div>
    )
}
