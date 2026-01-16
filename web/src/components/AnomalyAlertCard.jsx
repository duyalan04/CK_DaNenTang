import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { AlertTriangle, AlertCircle, Info, X, ChevronRight, TrendingUp, TrendingDown } from 'lucide-react'
import api from '../lib/api'

const formatCurrency = (value) => {
    return new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(value)
}

const formatDate = (dateString) => {
    return new Date(dateString).toLocaleDateString('vi-VN', {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric'
    })
}

// Icon và màu theo severity
const getSeverityStyle = (severity) => {
    switch (severity) {
        case 'high':
            return {
                icon: AlertTriangle,
                bgColor: 'bg-red-50',
                borderColor: 'border-red-200',
                iconColor: 'text-red-500',
                textColor: 'text-red-700',
                badgeColor: 'bg-red-100 text-red-700'
            }
        case 'medium':
            return {
                icon: AlertCircle,
                bgColor: 'bg-yellow-50',
                borderColor: 'border-yellow-200',
                iconColor: 'text-yellow-500',
                textColor: 'text-yellow-700',
                badgeColor: 'bg-yellow-100 text-yellow-700'
            }
        default:
            return {
                icon: Info,
                bgColor: 'bg-blue-50',
                borderColor: 'border-blue-200',
                iconColor: 'text-blue-500',
                textColor: 'text-blue-700',
                badgeColor: 'bg-blue-100 text-blue-700'
            }
    }
}

// Single Anomaly Alert Item
const AnomalyItem = ({ anomaly, onDismiss }) => {
    const style = getSeverityStyle(anomaly.severity)
    const Icon = style.icon
    const transaction = anomaly.transaction

    return (
        <div className={`p-4 rounded-lg border ${style.bgColor} ${style.borderColor} transition-all duration-300 hover:shadow-md`}>
            <div className="flex items-start gap-3">
                {/* Icon */}
                <div className={`p-2 rounded-full ${style.bgColor}`}>
                    <Icon className={`w-5 h-5 ${style.iconColor}`} />
                </div>

                {/* Content */}
                <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 mb-1">
                        <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${style.badgeColor}`}>
                            {anomaly.severity === 'high' ? 'Nghiêm trọng' :
                                anomaly.severity === 'medium' ? 'Trung bình' : 'Nhẹ'}
                        </span>
                        <span className="text-xs text-gray-500">
                            Z-score: {anomaly.z_score}
                        </span>
                    </div>

                    <p className={`font-medium ${style.textColor} mb-1`}>
                        {transaction.type === 'expense' ? (
                            <TrendingDown className="w-4 h-4 inline mr-1" />
                        ) : (
                            <TrendingUp className="w-4 h-4 inline mr-1" />
                        )}
                        {formatCurrency(transaction.amount)}
                    </p>

                    <p className="text-sm text-gray-600">
                        {transaction.description || transaction.categories?.name || 'Không có mô tả'}
                    </p>

                    <p className="text-xs text-gray-500 mt-1">
                        {formatDate(transaction.transaction_date)} • {anomaly.description}
                    </p>
                </div>

                {/* Dismiss button */}
                <button
                    onClick={() => onDismiss(anomaly.id)}
                    className="p-1 hover:bg-white/50 rounded-full transition-colors"
                    title="Bỏ qua"
                >
                    <X className="w-4 h-4 text-gray-400 hover:text-gray-600" />
                </button>
            </div>
        </div>
    )
}

export default function AnomalyAlertCard() {
    const queryClient = useQueryClient()

    const { data, isLoading, error } = useQuery({
        queryKey: ['anomalies'],
        queryFn: () => api.get('/analytics/anomalies').then(res => res.data),
        refetchInterval: 300000 // Refresh mỗi 5 phút
    })

    // State để track dismissed anomalies (client-side)
    const dismissedIds = new Set()

    const handleDismiss = (id) => {
        dismissedIds.add(id)
        // Force re-render
        queryClient.invalidateQueries(['anomalies'])
    }

    if (isLoading) {
        return (
            <div className="bg-white p-6 rounded-xl shadow-sm animate-pulse">
                <div className="h-6 bg-gray-200 rounded w-1/3 mb-4"></div>
                <div className="space-y-3">
                    <div className="h-20 bg-gray-100 rounded-lg"></div>
                    <div className="h-20 bg-gray-100 rounded-lg"></div>
                </div>
            </div>
        )
    }

    if (error || !data?.success) {
        return (
            <div className="bg-white p-6 rounded-xl shadow-sm">
                <div className="flex items-center gap-2 text-red-500">
                    <AlertTriangle className="w-5 h-5" />
                    <span>Không thể tải dữ liệu anomaly</span>
                </div>
            </div>
        )
    }

    const { anomalies, statistics } = data.data

    // Filter out dismissed
    const visibleAnomalies = anomalies.filter(a => !dismissedIds.has(a.id))

    if (visibleAnomalies.length === 0) {
        return (
            <div className="bg-white p-6 rounded-xl shadow-sm">
                <h2 className="text-lg font-semibold flex items-center gap-2 mb-4">
                    <AlertCircle className="w-5 h-5 text-green-600" />
                    Phát hiện bất thường
                </h2>
                <div className="text-center py-8">
                    <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-3">
                        <svg className="w-8 h-8 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                        </svg>
                    </div>
                    <p className="text-gray-600">Không có giao dịch bất thường! 🎉</p>
                    <p className="text-sm text-gray-400 mt-1">Chi tiêu của bạn đang ổn định</p>
                </div>
            </div>
        )
    }

    return (
        <div className="bg-white p-6 rounded-xl shadow-sm">
            {/* Header */}
            <div className="flex items-center justify-between mb-4">
                <h2 className="text-lg font-semibold flex items-center gap-2">
                    <AlertTriangle className="w-5 h-5 text-orange-500" />
                    Phát hiện bất thường
                </h2>
                <div className="flex gap-2">
                    {statistics.highSeverity > 0 && (
                        <span className="px-2 py-1 bg-red-100 text-red-700 text-xs rounded-full">
                            {statistics.highSeverity} nghiêm trọng
                        </span>
                    )}
                    {statistics.mediumSeverity > 0 && (
                        <span className="px-2 py-1 bg-yellow-100 text-yellow-700 text-xs rounded-full">
                            {statistics.mediumSeverity} trung bình
                        </span>
                    )}
                </div>
            </div>

            {/* Algorithm explanation */}
            <div className="mb-4 p-3 bg-gray-50 rounded-lg">
                <p className="text-xs text-gray-500">
                    🧠 <strong>Z-score Algorithm:</strong> Phân tích độ lệch chuẩn để phát hiện giao dịch
                    khác biệt đáng kể so với thói quen chi tiêu của bạn.
                </p>
            </div>

            {/* Anomaly List */}
            <div className="space-y-3 max-h-[400px] overflow-y-auto pr-1">
                {visibleAnomalies.slice(0, 5).map((anomaly) => (
                    <AnomalyItem
                        key={anomaly.id}
                        anomaly={anomaly}
                        onDismiss={handleDismiss}
                    />
                ))}
            </div>

            {/* Show more link */}
            {visibleAnomalies.length > 5 && (
                <button className="mt-3 w-full py-2 text-sm text-blue-600 hover:text-blue-800 flex items-center justify-center gap-1">
                    Xem thêm {visibleAnomalies.length - 5} cảnh báo
                    <ChevronRight className="w-4 h-4" />
                </button>
            )}

            {/* Statistics footer */}
            <div className="mt-4 pt-3 border-t border-gray-100 text-center">
                <p className="text-xs text-gray-400">
                    Phân tích từ {statistics.totalTransactions} giao dịch trong 3 tháng gần đây
                </p>
            </div>
        </div>
    )
}
