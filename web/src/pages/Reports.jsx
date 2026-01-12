import { useQuery } from '@tanstack/react-query'
import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, PieChart, Pie, Cell, Legend } from 'recharts'
import api from '../lib/api'

const COLORS = ['#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4', '#FFEAA7', '#DDA0DD', '#98D8C8', '#F7DC6F']

const formatCurrency = (value) => {
  return new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(value)
}

export default function Reports() {
  const { data: trend } = useQuery({
    queryKey: ['monthlyTrend'],
    queryFn: () => api.get('/reports/monthly-trend?months=12').then(res => res.data)
  })

  const { data: byCategory } = useQuery({
    queryKey: ['expenseByCategory'],
    queryFn: () => api.get('/reports/by-category?type=expense').then(res => res.data)
  })

  const { data: prediction } = useQuery({
    queryKey: ['prediction'],
    queryFn: () => api.get('/predictions/next-month').then(res => res.data)
  })

  const { data: categoryPredictions } = useQuery({
    queryKey: ['categoryPredictions'],
    queryFn: () => api.get('/predictions/by-category').then(res => res.data)
  })

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold">Báo cáo & Phân tích</h1>

      {/* Prediction Card */}
      {prediction?.prediction && (
        <div className="bg-gradient-to-r from-purple-500 to-indigo-600 text-white p-6 rounded-xl">
          <h2 className="text-lg font-semibold mb-2">🔮 Dự báo chi tiêu tháng tới</h2>
          <p className="text-3xl font-bold">{formatCurrency(prediction.prediction)}</p>
          <p className="text-sm opacity-80 mt-2">
            Độ tin cậy: {prediction.confidence}% | Dựa trên dữ liệu {prediction.historicalData?.length} tháng
          </p>
        </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Monthly Trend */}
        <div className="bg-white p-6 rounded-xl shadow-sm">
          <h2 className="text-lg font-semibold mb-4">Xu hướng thu chi theo tháng</h2>
          <ResponsiveContainer width="100%" height={300}>
            <BarChart data={trend || []}>
              <XAxis dataKey="month" />
              <YAxis tickFormatter={(v) => `${(v / 1000000).toFixed(0)}M`} />
              <Tooltip formatter={(value) => formatCurrency(value)} />
              <Legend />
              <Bar dataKey="income" fill="#22c55e" name="Thu nhập" />
              <Bar dataKey="expense" fill="#ef4444" name="Chi tiêu" />
            </BarChart>
          </ResponsiveContainer>
        </div>

        {/* Expense by Category */}
        <div className="bg-white p-6 rounded-xl shadow-sm">
          <h2 className="text-lg font-semibold mb-4">Chi tiêu theo danh mục</h2>
          <ResponsiveContainer width="100%" height={300}>
            <PieChart>
              <Pie
                data={byCategory || []}
                dataKey="total"
                nameKey="name"
                cx="50%"
                cy="50%"
                outerRadius={100}
                label={({ name, percent }) => `${name} ${(percent * 100).toFixed(0)}%`}
              >
                {(byCategory || []).map((entry, index) => (
                  <Cell key={index} fill={entry.color || COLORS[index % COLORS.length]} />
                ))}
              </Pie>
              <Tooltip formatter={(value) => formatCurrency(value)} />
            </PieChart>
          </ResponsiveContainer>
        </div>
      </div>

      {/* Category Predictions */}
      {categoryPredictions?.length > 0 && (
        <div className="bg-white p-6 rounded-xl shadow-sm">
          <h2 className="text-lg font-semibold mb-4">Dự báo chi tiêu theo danh mục</h2>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            {categoryPredictions.map((p, i) => (
              <div key={p.categoryId} className="p-4 bg-gray-50 rounded-lg">
                <p className="text-sm text-gray-600">{p.name}</p>
                <p className="text-lg font-bold">{formatCurrency(p.prediction)}</p>
                <p className="text-xs text-gray-500">Độ tin cậy: {p.confidence}%</p>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}
