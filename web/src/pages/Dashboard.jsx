import { useQuery } from '@tanstack/react-query'
import { PieChart, Pie, Cell, ResponsiveContainer, LineChart, Line, XAxis, YAxis, Tooltip, Legend } from 'recharts'
import { TrendingUp, TrendingDown, Wallet, Target } from 'lucide-react'
import api from '../lib/api'

// Import AI Components
import HealthScoreCard from '../components/HealthScoreCard'
import AnomalyAlertCard from '../components/AnomalyAlertCard'
import InsightsCard from '../components/InsightsCard'
import SavingsCard from '../components/SavingsCard'
import SmartBudgetCard from '../components/SmartBudgetCard'

const COLORS = ['#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4', '#FFEAA7', '#DDA0DD', '#98D8C8', '#F7DC6F']

const formatCurrency = (value) => {
  return new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(value)
}

export default function Dashboard() {
  // Cache 5 phút cho data cơ bản
  const { data: summary } = useQuery({
    queryKey: ['summary'],
    queryFn: () => api.get('/reports/summary').then(res => res.data),
    staleTime: 5 * 60 * 1000, // 5 phút
  })

  const { data: byCategory } = useQuery({
    queryKey: ['byCategory'],
    queryFn: () => api.get('/reports/by-category').then(res => res.data),
    staleTime: 5 * 60 * 1000,
  })

  const { data: trend } = useQuery({
    queryKey: ['trend'],
    queryFn: () => api.get('/reports/monthly-trend').then(res => res.data),
    staleTime: 10 * 60 * 1000, // 10 phút - ít thay đổi
  })

  const { data: prediction } = useQuery({
    queryKey: ['prediction'],
    queryFn: () => api.get('/predictions/next-month').then(res => res.data),
    staleTime: 30 * 60 * 1000, // 30 phút - AI prediction ít thay đổi
  })

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">Dashboard</h1>
        <span className="text-sm text-gray-500">
          🧠 AI-Powered Analytics
        </span>
      </div>

      {/* Summary Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div className="bg-white p-6 rounded-xl shadow-sm hover:shadow-md transition-shadow">
          <div className="flex items-center gap-3">
            <div className="p-3 bg-green-100 rounded-lg">
              <TrendingUp className="text-green-600" />
            </div>
            <div>
              <p className="text-gray-500 text-sm">Thu nhập</p>
              <p className="text-xl font-bold text-green-600">
                {formatCurrency(summary?.totalIncome || 0)}
              </p>
            </div>
          </div>
        </div>

        <div className="bg-white p-6 rounded-xl shadow-sm hover:shadow-md transition-shadow">
          <div className="flex items-center gap-3">
            <div className="p-3 bg-red-100 rounded-lg">
              <TrendingDown className="text-red-600" />
            </div>
            <div>
              <p className="text-gray-500 text-sm">Chi tiêu</p>
              <p className="text-xl font-bold text-red-600">
                {formatCurrency(summary?.totalExpense || 0)}
              </p>
            </div>
          </div>
        </div>

        <div className="bg-white p-6 rounded-xl shadow-sm hover:shadow-md transition-shadow">
          <div className="flex items-center gap-3">
            <div className="p-3 bg-blue-100 rounded-lg">
              <Wallet className="text-blue-600" />
            </div>
            <div>
              <p className="text-gray-500 text-sm">Số dư</p>
              <p className="text-xl font-bold text-blue-600">
                {formatCurrency(summary?.balance || 0)}
              </p>
            </div>
          </div>
        </div>

        <div className="bg-white p-6 rounded-xl shadow-sm hover:shadow-md transition-shadow">
          <div className="flex items-center gap-3">
            <div className="p-3 bg-purple-100 rounded-lg">
              <Target className="text-purple-600" />
            </div>
            <div>
              <p className="text-gray-500 text-sm">Dự báo tháng sau</p>
              <p className="text-xl font-bold text-purple-600">
                {prediction?.prediction ? formatCurrency(prediction.prediction) : 'N/A'}
              </p>
            </div>
          </div>
        </div>
      </div>

      {/* AI Features Row - NEW! */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <HealthScoreCard />
        <AnomalyAlertCard />
      </div>

      {/* AI Insights & Savings Row */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <InsightsCard />
        <SavingsCard />
      </div>

      {/* Smart Budget */}
      <SmartBudgetCard />

      {/* Charts */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
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
                {(byCategory || []).map((_, index) => (
                  <Cell key={index} fill={COLORS[index % COLORS.length]} />
                ))}
              </Pie>
              <Tooltip formatter={(value) => formatCurrency(value)} />
            </PieChart>
          </ResponsiveContainer>
        </div>

        <div className="bg-white p-6 rounded-xl shadow-sm">
          <h2 className="text-lg font-semibold mb-4">Xu hướng thu chi</h2>
          <ResponsiveContainer width="100%" height={300}>
            <LineChart data={trend || []}>
              <XAxis dataKey="month" />
              <YAxis tickFormatter={(v) => `${(v / 1000000).toFixed(0)}M`} />
              <Tooltip formatter={(value) => formatCurrency(value)} />
              <Legend />
              <Line type="monotone" dataKey="income" stroke="#22c55e" strokeWidth={2} name="Thu nhập" dot={{ fill: '#22c55e' }} />
              <Line type="monotone" dataKey="expense" stroke="#ef4444" strokeWidth={2} name="Chi tiêu" dot={{ fill: '#ef4444' }} />
            </LineChart>
          </ResponsiveContainer>
        </div>
      </div>
    </div>
  )
}
