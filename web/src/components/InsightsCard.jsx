import { useQuery } from '@tanstack/react-query'
import { Lightbulb, RefreshCw, Sparkles } from 'lucide-react'
import { useState } from 'react'
import api from '../lib/api'

export default function InsightsCard() {
    const [isRefreshing, setIsRefreshing] = useState(false)

    const { data, isLoading, error, refetch } = useQuery({
        queryKey: ['insights'],
        queryFn: () => api.get('/analytics/insights').then(res => res.data),
        staleTime: 300000, // Cache 5 phút
    })

    const handleRefresh = async () => {
        setIsRefreshing(true)
        await refetch()
        setIsRefreshing(false)
    }

    if (isLoading) {
        return (
            <div className="bg-white p-6 rounded-xl shadow-sm animate-pulse">
                <div className="h-6 bg-gray-200 rounded w-1/3 mb-4"></div>
                <div className="space-y-3">
                    <div className="h-4 bg-gray-100 rounded w-full"></div>
                    <div className="h-4 bg-gray-100 rounded w-3/4"></div>
                    <div className="h-4 bg-gray-100 rounded w-5/6"></div>
                </div>
            </div>
        )
    }

    if (error || !data?.success) {
        return (
            <div className="bg-white p-6 rounded-xl shadow-sm">
                <div className="text-center py-4">
                    <p className="text-gray-500">Không thể tải insights</p>
                    <button
                        onClick={handleRefresh}
                        className="mt-2 text-sm text-blue-600 hover:text-blue-800"
                    >
                        Thử lại
                    </button>
                </div>
            </div>
        )
    }

    const { insights, basedOn } = data.data

    return (
        <div className="bg-gradient-to-br from-purple-50 to-blue-50 p-6 rounded-xl shadow-sm border border-purple-100">
            {/* Header */}
            <div className="flex items-center justify-between mb-4">
                <h2 className="text-lg font-semibold flex items-center gap-2">
                    <Sparkles className="w-5 h-5 text-purple-600" />
                    AI Insights
                </h2>
                <button
                    onClick={handleRefresh}
                    disabled={isRefreshing}
                    className="p-2 hover:bg-white/50 rounded-full transition-colors"
                    title="Làm mới insights"
                >
                    <RefreshCw className={`w-4 h-4 text-purple-600 ${isRefreshing ? 'animate-spin' : ''}`} />
                </button>
            </div>

            {/* AI Badge */}
            <div className="mb-4 inline-flex items-center gap-1 px-2 py-1 bg-purple-100 text-purple-700 text-xs rounded-full">
                <Lightbulb className="w-3 h-3" />
                <span>Phân tích bởi AI</span>
            </div>

            {/* Insights List */}
            <div className="space-y-3">
                {insights.map((insight, index) => (
                    <div
                        key={index}
                        className="p-3 bg-white/70 backdrop-blur-sm rounded-lg border border-white/50 hover:bg-white/90 transition-colors"
                    >
                        <p className="text-sm text-gray-700 leading-relaxed">
                            {insight.content}
                        </p>
                    </div>
                ))}
            </div>

            {/* Footer */}
            {basedOn && (
                <div className="mt-4 pt-3 border-t border-purple-100/50 text-center">
                    <p className="text-xs text-gray-400">
                        Dựa trên {basedOn.transactionCount} giao dịch trong {basedOn.period}
                    </p>
                </div>
            )}
        </div>
    )
}
