import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { AlertTriangle, AlertCircle, Info, X, ChevronRight, TrendingUp, TrendingDown, ShieldCheck, Eye } from 'lucide-react'
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
                badgeColor: 'bg-red-100 text-red-700',
                label: '🔴 Cần chú ý ngay',
                emoji: '🚨'
            }
        case 'medium':
            return {
                icon: AlertCircle,
                bgColor: 'bg-yellow-50',
                borderColor: 'border-yellow-200',
                iconColor: 'text-yellow-500',
                textColor: 'text-yellow-700',
                badgeColor: 'bg-yellow-100 text-yellow-700',
                label: '🟡 Hơi khác thường',
                emoji: '⚠️'
            }
        default:
            return {
                icon: Info,
                bgColor: 'bg-blue-50',
                borderColor: 'border-blue-200',
                iconColor: 'text-blue-500',
                textColor: 'text-blue-700',
                badgeColor: 'bg-blue-100 text-blue-700',
                label: '🔵 Lưu ý nhẹ',
                emoji: 'ℹ️'
            }
    }
}

// Chuyển Z-score thành mô tả dễ hiểu
const getUnusualLevel = (zScore) => {
    const z = Math.abs(parseFloat(zScore) || 0)
    if (z >= 3) return { text: 'Rất khác biệt', level: 5, color: 'text-red-600' }
    if (z >= 2.5) return { text: 'Khác biệt nhiều', level: 4, color: 'text-orange-600' }
    if (z >= 2) return { text: 'Khá khác biệt', level: 3, color: 'text-yellow-600' }
    if (z >= 1.5) return { text: 'Hơi khác biệt', level: 2, color: 'text-blue-600' }
    return { text: 'Bình thường', level: 1, color: 'text-gray-500' }
}

// Tạo mô tả dễ hiểu từ anomaly description
const getFriendlyDescription = (anomaly) => {
    const transaction = anomaly.transaction
    const amount = transaction.amount
    const avgMatch = anomaly.description?.match(/trung bình \(([^)]+)\)/)
    const pctMatch = anomaly.description?.match(/(\d+)%/)
    
    if (pctMatch && avgMatch) {
        const pct = pctMatch[1]
        const avg = avgMatch[1]
        return `Khoản này cao gấp ~${Math.round(parseInt(pct) / 100)} lần so với mức thường chi (${avg})`
    }
    
    if (anomaly.description) {
        // Đơn giản hóa description có sẵn
        return anomaly.description
            .replace(/Giao dịch cao hơn/g, 'Cao hơn')
            .replace(/so với trung bình/g, 'so với mức thường chi')
    }
    
    return 'Khoản chi này khác biệt so với thói quen của bạn'
}

// Single Anomaly Alert Item
const AnomalyItem = ({ anomaly, onDismiss }) => {
    const style = getSeverityStyle(anomaly.severity)
    const Icon = style.icon
    const transaction = anomaly.transaction
    const unusualLevel = getUnusualLevel(anomaly.z_score)
    const friendlyDesc = getFriendlyDescription(anomaly)

    return (
        <div className={`p-4 rounded-lg border ${style.bgColor} ${style.borderColor} transition-all duration-300 hover:shadow-md`}>
            <div className="flex items-start gap-3">
                {/* Icon */}
                <div className={`p-2 rounded-full ${style.bgColor}`}>
                    <Icon className={`w-5 h-5 ${style.iconColor}`} />
                </div>

                {/* Content */}
                <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 mb-1 flex-wrap">
                        <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${style.badgeColor}`}>
                            {style.label}
                        </span>
                        {/* Thanh mức độ bất thường thay cho Z-score */}
                        <div className="flex items-center gap-1" title={`Mức khác biệt: ${unusualLevel.text}`}>
                            {[1, 2, 3, 4, 5].map(i => (
                                <div
                                    key={i}
                                    className={`w-1.5 h-3 rounded-sm transition-colors ${
                                        i <= unusualLevel.level
                                            ? i <= 2 ? 'bg-blue-400' : i <= 3 ? 'bg-yellow-400' : 'bg-red-400'
                                            : 'bg-gray-200'
                                    }`}
                                />
                            ))}
                            <span className={`text-xs ml-1 ${unusualLevel.color}`}>
                                {unusualLevel.text}
                            </span>
                        </div>
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
                        📅 {formatDate(transaction.transaction_date)} • {friendlyDesc}
                    </p>
                </div>

                {/* Dismiss button */}
                <button
                    onClick={() => onDismiss(anomaly.id)}
                    className="p-1 hover:bg-white/50 rounded-full transition-colors"
                    title="Bỏ qua cảnh báo này"
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
        staleTime: 5 * 60 * 1000, // Cache 5 phút
        refetchInterval: 300000 // Refresh mỗi 5 phút
    })

    // Dismiss anomaly — lưu vào DB
    const handleDismiss = async (transactionId) => {
        try {
            await api.put(`/analytics/anomalies/${transactionId}/dismiss`)
            // Refetch để cập nhật danh sách
            queryClient.invalidateQueries(['anomalies'])
        } catch (err) {
            console.error('Dismiss failed:', err)
        }
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

    if (anomalies.length === 0) {
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
                    <p className="text-gray-600">Không có giao dịch bất thường!</p>
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
                            🚨 {statistics.highSeverity} cần chú ý
                        </span>
                    )}
                    {statistics.mediumSeverity > 0 && (
                        <span className="px-2 py-1 bg-yellow-100 text-yellow-700 text-xs rounded-full">
                            ⚠️ {statistics.mediumSeverity} hơi khác thường
                        </span>
                    )}
                </div>
            </div>

            {/* Giải thích tính năng - ngôn ngữ đời thường */}
            <div className="mb-4 p-3 bg-gradient-to-r from-blue-50 to-indigo-50 rounded-lg border border-blue-100">
                <div className="flex items-start gap-2">
                    <Eye className="w-4 h-4 text-blue-500 mt-0.5 flex-shrink-0" />
                    <p className="text-xs text-gray-600">
                        <strong className="text-blue-700">Hệ thống tự động theo dõi</strong> các khoản chi tiêu của bạn.
                        Nếu phát hiện khoản nào <strong>cao hoặc thấp bất thường</strong> so với thói quen hàng ngày, 
                        sẽ thông báo để bạn kiểm tra lại.
                    </p>
                </div>
            </div>

            {/* Anomaly List */}
            <div className="space-y-3 max-h-[400px] overflow-y-auto pr-1">
                {anomalies.slice(0, 5).map((anomaly) => (
                    <AnomalyItem
                        key={anomaly.id}
                        anomaly={anomaly}
                        onDismiss={handleDismiss}
                    />
                ))}
            </div>

            {/* Show more link */}
            {anomalies.length > 5 && (
                <button className="mt-3 w-full py-2 text-sm text-blue-600 hover:text-blue-800 flex items-center justify-center gap-1">
                    Xem thêm {anomalies.length - 5} cảnh báo
                    <ChevronRight className="w-4 h-4" />
                </button>
            )}

            {/* Statistics footer */}
            <div className="mt-4 pt-3 border-t border-gray-100 text-center">
                <p className="text-xs text-gray-400">
                    📊 Đã kiểm tra {statistics.totalTransactions} giao dịch trong 3 tháng gần nhất
                </p>
            </div>
        </div>
    )
}
