import { useState, useEffect } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { Plus } from 'lucide-react'
import api from '../lib/api'

const formatCurrency = (value) => {
  return new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(value)
}

export default function Budgets() {
  const queryClient = useQueryClient()
  const [showModal, setShowModal] = useState(false)
  const currentDate = new Date()
  const [month, setMonth] = useState(currentDate.getMonth() + 1)
  const [year, setYear] = useState(currentDate.getFullYear())
  const [form, setForm] = useState({ categoryId: '', amount: '' })

  const { data: budgetStatus } = useQuery({
    queryKey: ['budgetStatus', year, month],
    queryFn: () => api.get(`/reports/budget-status?year=${year}&month=${month}`).then(res => res.data)
  })

  const { data: categories, refetch: refetchCategories } = useQuery({
    queryKey: ['categories'],
    queryFn: () => api.get('/categories').then(res => res.data)
  })

  // Tự động khởi tạo danh mục mặc định nếu chưa có
  useEffect(() => {
    const initCategories = async () => {
      if (categories && categories.length < 5) {
        try {
          await api.post('/categories/init-defaults')
          refetchCategories()
        } catch (e) {
          console.log('Categories already initialized')
        }
      }
    }
    initCategories()
  }, [categories, refetchCategories])

  const createMutation = useMutation({
    mutationFn: (data) => api.post('/budgets', data),
    onSuccess: () => {
      queryClient.invalidateQueries(['budgetStatus'])
      setShowModal(false)
      setForm({ categoryId: '', amount: '' })
    }
  })

  const handleSubmit = (e) => {
    e.preventDefault()
    createMutation.mutate({ ...form, amount: parseFloat(form.amount), month, year })
  }

  const expenseCategories = categories?.filter(c => c.type === 'expense') || []

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h1 className="text-2xl font-bold">Ngân sách</h1>
        <div className="flex items-center gap-4">
          <select value={month} onChange={(e) => setMonth(parseInt(e.target.value))}
            className="px-4 py-2 border rounded-lg">
            {Array.from({ length: 12 }, (_, i) => (
              <option key={i + 1} value={i + 1}>Tháng {i + 1}</option>
            ))}
          </select>
          <select value={year} onChange={(e) => setYear(parseInt(e.target.value))}
            className="px-4 py-2 border rounded-lg">
            {[2024, 2025, 2026].map(y => <option key={y} value={y}>{y}</option>)}
          </select>
          <button onClick={() => setShowModal(true)}
            className="flex items-center gap-2 bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700">
            <Plus size={20} /> Thêm ngân sách
          </button>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {budgetStatus?.map((b) => (
          <div key={b.id} className="bg-white p-6 rounded-xl shadow-sm">
            <div className="flex items-center gap-3 mb-4">
              <span className="w-4 h-4 rounded-full" style={{ backgroundColor: b.categories?.color }}></span>
              <h3 className="font-semibold">{b.categories?.name}</h3>
            </div>
            <div className="mb-2">
              <div className="flex justify-between text-sm mb-1">
                <span>Đã chi: {formatCurrency(b.spent)}</span>
                <span>{b.percentage}%</span>
              </div>
              <div className="w-full bg-gray-200 rounded-full h-2">
                <div
                  className={`h-2 rounded-full ${b.percentage > 100 ? 'bg-red-500' : b.percentage > 80 ? 'bg-yellow-500' : 'bg-green-500'}`}
                  style={{ width: `${Math.min(b.percentage, 100)}%` }}
                ></div>
              </div>
            </div>
            <div className="flex justify-between text-sm text-gray-600">
              <span>Ngân sách: {formatCurrency(b.amount)}</span>
              <span className={b.remaining < 0 ? 'text-red-600' : 'text-green-600'}>
                Còn lại: {formatCurrency(b.remaining)}
              </span>
            </div>
          </div>
        ))}
      </div>

      {showModal && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center">
          <div className="bg-white p-6 rounded-xl w-full max-w-md">
            <h2 className="text-xl font-bold mb-4">Thêm ngân sách</h2>
            <form onSubmit={handleSubmit} className="space-y-4">
              <select value={form.categoryId} onChange={(e) => setForm({ ...form, categoryId: e.target.value })}
                className="w-full px-4 py-2 border rounded-lg" required>
                <option value="">Chọn danh mục</option>
                {expenseCategories.map(c => <option key={c.id} value={c.id}>{c.name}</option>)}
              </select>
              <input type="text" inputMode="numeric" placeholder="Số tiền ngân sách" value={form.amount}
                onChange={(e) => {
                  const value = e.target.value.replace(/[^0-9]/g, '')
                  setForm({ ...form, amount: value })
                }}
                className="w-full px-4 py-2 border rounded-lg" required />
              <div className="flex gap-4">
                <button type="button" onClick={() => setShowModal(false)}
                  className="flex-1 py-2 border rounded-lg hover:bg-gray-50">Hủy</button>
                <button type="submit" className="flex-1 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700">
                  Lưu
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  )
}
