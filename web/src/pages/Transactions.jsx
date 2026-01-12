import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { Plus, Trash2 } from 'lucide-react'
import api from '../lib/api'

const formatCurrency = (value) => {
  return new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(value)
}

export default function Transactions() {
  const queryClient = useQueryClient()
  const [showModal, setShowModal] = useState(false)
  const [form, setForm] = useState({
    categoryId: '', amount: '', type: 'expense', description: '', transactionDate: new Date().toISOString().split('T')[0]
  })

  const { data: transactions } = useQuery({
    queryKey: ['transactions'],
    queryFn: () => api.get('/transactions').then(res => res.data)
  })

  const { data: categories } = useQuery({
    queryKey: ['categories'],
    queryFn: () => api.get('/categories').then(res => res.data)
  })

  const createMutation = useMutation({
    mutationFn: (data) => api.post('/transactions', data),
    onSuccess: () => {
      queryClient.invalidateQueries(['transactions'])
      setShowModal(false)
      setForm({ categoryId: '', amount: '', type: 'expense', description: '', transactionDate: new Date().toISOString().split('T')[0] })
    }
  })

  const deleteMutation = useMutation({
    mutationFn: (id) => api.delete(`/transactions/${id}`),
    onSuccess: () => queryClient.invalidateQueries(['transactions'])
  })

  const handleSubmit = (e) => {
    e.preventDefault()
    createMutation.mutate({ ...form, amount: parseFloat(form.amount) })
  }

  const filteredCategories = categories?.filter(c => c.type === form.type) || []

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h1 className="text-2xl font-bold">Giao dịch</h1>
        <button
          onClick={() => setShowModal(true)}
          className="flex items-center gap-2 bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700"
        >
          <Plus size={20} /> Thêm giao dịch
        </button>
      </div>

      <div className="bg-white rounded-xl shadow-sm overflow-hidden">
        <table className="w-full">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-6 py-3 text-left text-sm font-medium text-gray-500">Ngày</th>
              <th className="px-6 py-3 text-left text-sm font-medium text-gray-500">Danh mục</th>
              <th className="px-6 py-3 text-left text-sm font-medium text-gray-500">Mô tả</th>
              <th className="px-6 py-3 text-right text-sm font-medium text-gray-500">Số tiền</th>
              <th className="px-6 py-3"></th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200">
            {transactions?.map((t) => (
              <tr key={t.id} className="hover:bg-gray-50">
                <td className="px-6 py-4 text-sm">{t.transaction_date}</td>
                <td className="px-6 py-4">
                  <span className="inline-flex items-center gap-2">
                    <span className="w-3 h-3 rounded-full" style={{ backgroundColor: t.categories?.color }}></span>
                    {t.categories?.name}
                  </span>
                </td>
                <td className="px-6 py-4 text-sm text-gray-600">{t.description}</td>
                <td className={`px-6 py-4 text-right font-medium ${t.type === 'income' ? 'text-green-600' : 'text-red-600'}`}>
                  {t.type === 'income' ? '+' : '-'}{formatCurrency(t.amount)}
                </td>
                <td className="px-6 py-4">
                  <button onClick={() => deleteMutation.mutate(t.id)} className="text-red-500 hover:text-red-700">
                    <Trash2 size={18} />
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {showModal && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center">
          <div className="bg-white p-6 rounded-xl w-full max-w-md">
            <h2 className="text-xl font-bold mb-4">Thêm giao dịch</h2>
            <form onSubmit={handleSubmit} className="space-y-4">
              <div className="flex gap-4">
                <button type="button" onClick={() => setForm({ ...form, type: 'expense', categoryId: '' })}
                  className={`flex-1 py-2 rounded-lg ${form.type === 'expense' ? 'bg-red-100 text-red-600' : 'bg-gray-100'}`}>
                  Chi tiêu
                </button>
                <button type="button" onClick={() => setForm({ ...form, type: 'income', categoryId: '' })}
                  className={`flex-1 py-2 rounded-lg ${form.type === 'income' ? 'bg-green-100 text-green-600' : 'bg-gray-100'}`}>
                  Thu nhập
                </button>
              </div>
              <select value={form.categoryId} onChange={(e) => setForm({ ...form, categoryId: e.target.value })}
                className="w-full px-4 py-2 border rounded-lg" required>
                <option value="">Chọn danh mục</option>
                {filteredCategories.map(c => <option key={c.id} value={c.id}>{c.name}</option>)}
              </select>
              <input type="number" placeholder="Số tiền" value={form.amount}
                onChange={(e) => setForm({ ...form, amount: e.target.value })}
                className="w-full px-4 py-2 border rounded-lg" required />
              <input type="text" placeholder="Mô tả" value={form.description}
                onChange={(e) => setForm({ ...form, description: e.target.value })}
                className="w-full px-4 py-2 border rounded-lg" />
              <input type="date" value={form.transactionDate}
                onChange={(e) => setForm({ ...form, transactionDate: e.target.value })}
                className="w-full px-4 py-2 border rounded-lg" />
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
