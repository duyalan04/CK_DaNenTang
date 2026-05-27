import { useQuery } from '@tanstack/react-query'
import { PieChart, Pie, Cell, ResponsiveContainer, AreaChart, Area, CartesianGrid, XAxis, YAxis, Tooltip, Legend } from 'recharts'
import { TrendingUp, TrendingDown, Wallet, Target, Sparkles } from 'lucide-react'
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

const CustomTooltip = ({ active, payload, label }) => {
  if (active && payload && payload.length) {
    return (
      <div className="bg-white/95 backdrop-blur-sm px-4 py-3 rounded-xl shadow-lg border border-gray-100">
        <p className="font-bold text-gray-700 mb-2 text-sm">{label}</p>
        <div className="space-y-1.5">
          {payload.map((entry, index) => (
            <div key={index} className="flex items-center justify-between gap-6">
              <div className="flex items-center gap-2">
                <span className="w-2 h-2 rounded-full" style={{ backgroundColor: entry.color }} />
                <span className="text-gray-500 text-xs">{entry.name}</span>
              </div>
              <span className="font-bold text-sm" style={{ color: entry.color }}>
                {formatCurrency(entry.value)}
              </span>
            </div>
          ))}
        </div>
      </div>
    )
  }
  return null
}

export default function Dashboard() {
  const { data: summary } = useQuery({
    queryKey: ['summary'],
    queryFn: () => api.get('/reports/summary').then(res => res.data),
    staleTime: 5 * 60 * 1000,
  })

  const { data: byCategory } = useQuery({
    queryKey: ['byCategory'],
    queryFn: () => api.get('/reports/by-category').then(res => res.data),
    staleTime: 5 * 60 * 1000,
  })

  const { data: trend } = useQuery({
    queryKey: ['trend'],
    queryFn: () => api.get('/reports/monthly-trend').then(res => res.data),
    staleTime: 10 * 60 * 1000,
  })

  const { data: prediction, isLoading: isPredictionLoading } = useQuery({
    queryKey: ['prediction'],
    queryFn: () => api.get('/predictions/next-month').then(res => res.data),
    staleTime: 30 * 60 * 1000,
  })

  const hasPrediction = typeof prediction?.prediction === 'number'
  const predictionText = isPredictionLoading
    ? 'Đang tính...'
    : hasPrediction
      ? formatCurrency(prediction.prediction)
      : 'Chưa đủ dữ liệu'

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-gray-800">Tổng quan</h1>
        <div className="px-3 py-1.5 bg-purple-50 text-purple-600 rounded-full text-xs font-semibold flex items-center gap-1.5">
          <Sparkles className="w-3.5 h-3.5" />
          <span>AI Analytics</span>
        </div>
      </div>

      {/* Summary Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div className="bg-white p-5 rounded-2xl shadow-sm border border-gray-100/60 hover:shadow-md transition-all">
          <div className="flex items-center gap-4">
            <div className="w-11 h-11 bg-emerald-50 rounded-xl flex items-center justify-center">
              <TrendingUp className="text-emerald-500 w-5 h-5" />
            </div>
            <div>
              <p className="text-gray-400 text-xs font-medium uppercase tracking-wider mb-0.5">Thu nhập</p>
              <p className="text-xl font-bold text-gray-800">
                {formatCurrency(summary?.totalIncome || 0)}
              </p>
            </div>
          </div>
        </div>

        <div className="bg-white p-5 rounded-2xl shadow-sm border border-gray-100/60 hover:shadow-md transition-all">
          <div className="flex items-center gap-4">
            <div className="w-11 h-11 bg-red-50 rounded-xl flex items-center justify-center">
              <TrendingDown className="text-red-500 w-5 h-5" />
            </div>
            <div>
              <p className="text-gray-400 text-xs font-medium uppercase tracking-wider mb-0.5">Chi tiêu</p>
              <p className="text-xl font-bold text-gray-800">
                {formatCurrency(summary?.totalExpense || 0)}
              </p>
            </div>
          </div>
        </div>

        <div className="bg-white p-5 rounded-2xl shadow-sm border border-gray-100/60 hover:shadow-md transition-all">
          <div className="flex items-center gap-4">
            <div className="w-11 h-11 bg-blue-50 rounded-xl flex items-center justify-center">
              <Wallet className="text-blue-500 w-5 h-5" />
            </div>
            <div>
              <p className="text-gray-400 text-xs font-medium uppercase tracking-wider mb-0.5">Số dư</p>
              <p className="text-xl font-bold text-gray-800">
                {formatCurrency(summary?.balance || 0)}
              </p>
            </div>
          </div>
        </div>

        <div className="bg-white p-5 rounded-2xl shadow-sm border border-gray-100/60 hover:shadow-md transition-all relative overflow-hidden">
          <div className="absolute -right-4 -top-4 w-20 h-20 bg-purple-100/50 rounded-full blur-2xl"></div>
          <div className="flex items-center gap-4 relative z-10">
            <div className="w-11 h-11 bg-purple-50 rounded-xl flex items-center justify-center">
              <Target className="text-purple-500 w-5 h-5" />
            </div>
            <div>
              <p className="text-gray-400 text-xs font-medium uppercase tracking-wider mb-0.5">Dự báo tháng tới</p>
              <p className={`${hasPrediction ? 'text-xl' : 'text-base'} font-bold text-gray-800`}>
                {predictionText}
              </p>
            </div>
          </div>
        </div>
      </div>

      {/* AI Features Row */}
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
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6 pb-6">
        {/* Donut Chart - By Category */}
        <div className="bg-white p-6 rounded-2xl shadow-sm border border-gray-100/60">
          <div className="flex items-center justify-between mb-5">
            <h2 className="text-base font-bold text-gray-800">Cơ cấu chi tiêu</h2>
            <span className="text-[11px] font-medium text-gray-400 bg-gray-50 px-2.5 py-1 rounded-md">Tháng này</span>
          </div>
          <ResponsiveContainer width="100%" height={280}>
            <PieChart>
              <Pie
                data={byCategory || []}
                dataKey="total"
                nameKey="name"
                cx="50%"
                cy="45%"
                innerRadius={65}
                outerRadius={95}
                paddingAngle={3}
                stroke="none"
              >
                {(byCategory || []).map((_, index) => (
                  <Cell key={index} fill={COLORS[index % COLORS.length]} />
                ))}
              </Pie>
              <Tooltip content={<CustomTooltip />} />
              <Legend
                verticalAlign="bottom"
                height={40}
                iconType="circle"
                iconSize={8}
                formatter={(value) => <span className="text-xs text-gray-600 ml-1">{value}</span>}
              />
            </PieChart>
          </ResponsiveContainer>
        </div>

        {/* Area Chart - Income vs Expense Trend */}
        <div className="bg-white p-6 rounded-2xl shadow-sm border border-gray-100/60">
          <div className="flex items-center justify-between mb-5">
            <h2 className="text-base font-bold text-gray-800">Xu hướng dòng tiền</h2>
            <span className="text-[11px] font-medium text-gray-400 bg-gray-50 px-2.5 py-1 rounded-md">6 tháng</span>
          </div>
          <ResponsiveContainer width="100%" height={280}>
            <AreaChart data={trend || []} margin={{ top: 5, right: 10, left: -10, bottom: 0 }}>
              <defs>
                <linearGradient id="gradIncome" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#10b981" stopOpacity={0.15}/>
                  <stop offset="95%" stopColor="#10b981" stopOpacity={0}/>
                </linearGradient>
                <linearGradient id="gradExpense" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#ef4444" stopOpacity={0.15}/>
                  <stop offset="95%" stopColor="#ef4444" stopOpacity={0}/>
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#f1f5f9" />
              <XAxis
                dataKey="month"
                axisLine={false}
                tickLine={false}
                tick={{ fill: '#94a3b8', fontSize: 12 }}
                dy={8}
              />
              <YAxis
                axisLine={false}
                tickLine={false}
                tick={{ fill: '#94a3b8', fontSize: 12 }}
                tickFormatter={(v) => `${(v / 1000000).toFixed(0)}M`}
                dx={-5}
              />
              <Tooltip content={<CustomTooltip />} />
              <Legend
                verticalAlign="top"
                height={36}
                iconType="circle"
                iconSize={8}
                wrapperStyle={{ paddingBottom: '12px' }}
                formatter={(value) => <span className="text-xs text-gray-600 ml-1">{value}</span>}
              />
              <Area
                type="monotone"
                dataKey="income"
                name="Thu nhập"
                stroke="#10b981"
                strokeWidth={2.5}
                fillOpacity={1}
                fill="url(#gradIncome)"
                activeDot={{ r: 5, strokeWidth: 0, fill: '#10b981' }}
              />
              <Area
                type="monotone"
                dataKey="expense"
                name="Chi tiêu"
                stroke="#ef4444"
                strokeWidth={2.5}
                fillOpacity={1}
                fill="url(#gradExpense)"
                activeDot={{ r: 5, strokeWidth: 0, fill: '#ef4444' }}
              />
            </AreaChart>
          </ResponsiveContainer>
        </div>
      </div>
    </div>
  )
}
