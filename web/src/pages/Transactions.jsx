import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { CalendarDays, FileText, Plus, Receipt, ShoppingBag, Trash2, X } from 'lucide-react'
import api from '../lib/api'
import { useToast } from '../components/Toast'

const formatCurrency = (value) => {
  return new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(value)
}

export default function Transactions() {
  const queryClient = useQueryClient()
  const toast = useToast()
  const [showModal, setShowModal] = useState(false)
  const [selectedTransaction, setSelectedTransaction] = useState(null)
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
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ['transactions'], refetchType: 'active' })
      await queryClient.invalidateQueries({ queryKey: ['analytics'], refetchType: 'active' })
      await queryClient.invalidateQueries({ queryKey: ['budgets'], refetchType: 'active' })
      setShowModal(false)
      setForm({ categoryId: '', amount: '', type: 'expense', description: '', transactionDate: new Date().toISOString().split('T')[0] })
      toast.success('Thêm giao dịch thành công!')
    },
    onError: () => {
      toast.error('Không thể thêm giao dịch')
    }
  })

  const deleteMutation = useMutation({
    mutationFn: (id) => api.delete(`/transactions/${id}`),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ['transactions'], refetchType: 'active' })
      await queryClient.invalidateQueries({ queryKey: ['analytics'], refetchType: 'active' })
      await queryClient.invalidateQueries({ queryKey: ['budgets'], refetchType: 'active' })
      toast.success('Đã xóa giao dịch')
    },
    onError: () => {
      toast.error('Không thể xóa giao dịch')
    }
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
              <th className="px-6 py-3 text-left text-sm font-medium text-gray-500">Ngày giờ</th>
              <th className="px-6 py-3 text-left text-sm font-medium text-gray-500">Danh mục</th>
              <th className="px-6 py-3 text-left text-sm font-medium text-gray-500">Mô tả</th>
              <th className="px-6 py-3 text-right text-sm font-medium text-gray-500">Số tiền</th>
              <th className="px-6 py-3"></th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200">
            {transactions?.map((t) => (
              <tr
                key={t.id}
                onClick={() => setSelectedTransaction(t)}
                className="hover:bg-gray-50 cursor-pointer transition-colors"
              >
                <td className="px-6 py-4 text-sm">
                  <div>{t.transaction_date}</div>
                  {t.created_at && (
                    <div className="text-xs text-gray-400">
                      {new Date(t.created_at).toLocaleTimeString('vi-VN', { hour: '2-digit', minute: '2-digit' })}
                    </div>
                  )}
                </td>
                <td className="px-6 py-4">
                  <span className="inline-flex items-center gap-2">
                    <span className="w-3 h-3 rounded-full" style={{ backgroundColor: t.categories?.color }}></span>
                    {t.categories?.name}
                  </span>
                </td>
                <td className="px-6 py-4 text-sm text-gray-600">
                  <div className="flex items-center gap-2">
                    {t.ocr_data && (
                      <span className="inline-flex items-center gap-1 rounded-full bg-teal-50 px-2 py-1 text-xs font-medium text-teal-700">
                        <Receipt size={13} />
                        Bill
                      </span>
                    )}
                    <span className="line-clamp-2">{t.description}</span>
                  </div>
                </td>
                <td className={`px-6 py-4 text-right font-medium ${t.type === 'income' ? 'text-green-600' : 'text-red-600'}`}>
                  {t.type === 'income' ? '+' : '-'}{formatCurrency(t.amount)}
                </td>
                <td className="px-6 py-4">
                  <button
                    onClick={(e) => {
                      e.stopPropagation()
                      deleteMutation.mutate(t.id)
                    }}
                    className="text-red-500 hover:text-red-700"
                  >
                    <Trash2 size={18} />
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {showModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm px-4 py-6" onClick={() => setShowModal(false)}>
          <div className="bg-white rounded-2xl w-full max-w-lg shadow-2xl overflow-hidden max-h-[calc(100vh-48px)] flex flex-col" onClick={e => e.stopPropagation()}>
            <div className="px-6 pt-6 pb-4">
              <div className="flex items-center justify-between mb-1">
                <h2 className="text-xl font-bold text-gray-900">Thêm giao dịch</h2>
                <button onClick={() => setShowModal(false)} className="p-2 hover:bg-gray-100 rounded-xl transition-colors text-gray-400 hover:text-gray-600">
                  <X size={18} />
                </button>
              </div>
              <p className="text-sm text-gray-400">Ghi nhận giao dịch mới vào hệ thống</p>
            </div>
            <div className={`mx-6 mb-5 p-5 rounded-2xl text-center ${form.type === 'expense' ? 'bg-red-50 border border-red-100' : 'bg-emerald-50 border border-emerald-100'}`}>
              <p className="text-xs text-gray-400 mb-1">{form.type === 'expense' ? 'Chi tiêu' : 'Thu nhập'}</p>
              <p className={`text-3xl font-black tracking-tight ${form.type === 'expense' ? 'text-red-500' : 'text-emerald-500'}`}>
                {form.type === 'expense' ? '−' : '+'}{form.amount ? Number(form.amount).toLocaleString('vi-VN') : '0'} <span className="text-lg font-semibold opacity-50">₫</span>
              </p>
            </div>
            <form onSubmit={handleSubmit} className="px-6 pb-6 space-y-5 overflow-y-auto flex-1">
              <div className="flex gap-1 p-1 bg-gray-100 rounded-xl">
                <button type="button" onClick={() => setForm({ ...form, type: 'expense', categoryId: '' })}
                  className={`flex-1 flex items-center justify-center gap-2 py-2.5 rounded-lg text-sm font-semibold transition-all ${form.type === 'expense' ? 'bg-white shadow-sm text-red-500' : 'text-gray-400 hover:text-gray-600'}`}>
                  ↗ Chi tiêu
                </button>
                <button type="button" onClick={() => setForm({ ...form, type: 'income', categoryId: '' })}
                  className={`flex-1 flex items-center justify-center gap-2 py-2.5 rounded-lg text-sm font-semibold transition-all ${form.type === 'income' ? 'bg-white shadow-sm text-emerald-500' : 'text-gray-400 hover:text-gray-600'}`}>
                  ↙ Thu nhập
                </button>
              </div>
              <div>
                <label className="block text-xs font-bold text-gray-400 uppercase tracking-wider mb-2">Số tiền</label>
                <div className="relative">
                  <span className={`absolute left-4 top-1/2 -translate-y-1/2 text-lg font-bold ${form.type === 'expense' ? 'text-red-300' : 'text-emerald-300'}`}>₫</span>
                  <input type="text" inputMode="numeric" placeholder="0" value={form.amount ? Number(form.amount).toLocaleString('vi-VN') : ''}
                    onChange={(e) => { const value = e.target.value.replace(/[^0-9]/g, ''); setForm({ ...form, amount: value }) }}
                    className="w-full pl-10 pr-4 py-3.5 text-xl font-bold border border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-200 focus:border-blue-400 outline-none transition-all placeholder:text-gray-200" required autoFocus />
                </div>
              </div>
              <div>
                <label className="block text-xs font-bold text-gray-400 uppercase tracking-wider mb-2">Danh mục</label>
                <div className="flex flex-wrap gap-2 p-3 border border-gray-200 rounded-xl bg-gray-50/50 max-h-[160px] overflow-y-auto">
                  {filteredCategories.length > 0 ? filteredCategories.map(c => (
                    <button key={c.id} type="button" onClick={() => setForm({ ...form, categoryId: c.id })}
                      className={`flex items-center gap-2 px-3.5 py-2 rounded-xl text-sm font-medium transition-all border ${form.categoryId === c.id ? 'border-blue-300 bg-blue-50 text-blue-700 shadow-sm ring-1 ring-blue-200' : 'border-gray-200 bg-white text-gray-600 hover:border-gray-300 hover:bg-gray-50'}`}>
                      <span className="text-base">{c.icon || '📝'}</span>
                      <span>{c.name}</span>
                      {form.categoryId === c.id && <span className="text-blue-500 text-xs font-bold ml-1">✓</span>}
                    </button>
                  )) : <p className="text-sm text-gray-400 py-2">Chưa có danh mục</p>}
                </div>
              </div>
              <div>
                <label className="block text-xs font-bold text-gray-400 uppercase tracking-wider mb-2">Ghi chú</label>
                <input type="text" placeholder="Thêm ghi chú (không bắt buộc)" value={form.description}
                  onChange={(e) => setForm({ ...form, description: e.target.value })}
                  className="w-full px-4 py-3 border border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-200 focus:border-blue-400 outline-none transition-all text-sm placeholder:text-gray-300" />
              </div>
              <div>
                <label className="block text-xs font-bold text-gray-400 uppercase tracking-wider mb-2">Ngày</label>
                <input type="date" value={form.transactionDate}
                  onChange={(e) => setForm({ ...form, transactionDate: e.target.value })}
                  className="w-full px-4 py-3 border border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-200 focus:border-blue-400 outline-none transition-all text-sm" />
              </div>
              <div className="flex gap-3 pt-2">
                <button type="button" onClick={() => setShowModal(false)}
                  className="flex-1 py-3 border border-gray-200 rounded-xl text-sm font-semibold text-gray-500 hover:bg-gray-50 transition-colors">Hủy</button>
                <button type="submit" disabled={!form.amount || !form.categoryId}
                  className={`flex-1 py-3 rounded-xl text-sm font-bold transition-all flex items-center justify-center gap-2 ${form.amount && form.categoryId ? (form.type === 'expense' ? 'bg-red-500 hover:bg-red-600 text-white shadow-md shadow-red-200' : 'bg-emerald-500 hover:bg-emerald-600 text-white shadow-md shadow-emerald-200') : 'bg-gray-100 text-gray-300 cursor-not-allowed'}`}>
                  ✓ Lưu giao dịch
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {selectedTransaction && (
        <TransactionDetailModal
          transaction={selectedTransaction}
          onClose={() => setSelectedTransaction(null)}
        />
      )}
    </div>
  )
}

function getOcrData(transaction) {
  return transaction?.ocr_data || {}
}

function getAiAnalysis(transaction) {
  const data = getOcrData(transaction).aiAnalysis
  return data && typeof data === 'object' ? data : {}
}

function getReceiptItems(transaction) {
  const ocrData = getOcrData(transaction)
  const aiAnalysis = getAiAnalysis(transaction)

  if (Array.isArray(ocrData.receiptItems) && ocrData.receiptItems.length > 0) return ocrData.receiptItems
  if (Array.isArray(aiAnalysis.items) && aiAnalysis.items.length > 0) return aiAnalysis.items
  if (Array.isArray(ocrData.extractedItems)) return ocrData.extractedItems.map(name => ({ name, quantity: 1 }))
  return []
}

function firstValue(...values) {
  return values.find(value => value !== undefined && value !== null && String(value).trim() !== '')
}

function parseAmount(value) {
  if (typeof value === 'number') return value
  if (!value) return 0
  const cleaned = String(value).replace(/[^0-9.-]/g, '')
  return Number(cleaned) || 0
}

function formatDate(value) {
  if (!value) return 'Không rõ'
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return value
  return date.toLocaleDateString('vi-VN')
}

function TransactionDetailModal({ transaction, onClose }) {
  const ocrData = getOcrData(transaction)
  const aiAnalysis = getAiAnalysis(transaction)
  const items = getReceiptItems(transaction)
  const hasReceipt = Object.keys(ocrData).length > 0
  const isIncome = transaction.type === 'income'
  const storeName = firstValue(ocrData.storeName, aiAnalysis.storeName, ocrData.rawText, transaction.categories?.name)
  const invoiceNumber = firstValue(ocrData.invoiceNumber, aiAnalysis.invoiceNumber)
  const receiptDate = firstValue(ocrData.receiptDate, aiAnalysis.date)
  const receiptTime = firstValue(ocrData.receiptTime, aiAnalysis.time)
  const totalAmount = parseAmount(firstValue(ocrData.totalAmount, aiAnalysis.totalAmount, transaction.amount))

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/50 px-4 py-8 backdrop-blur-sm">
      <div className="flex max-h-[90vh] w-full max-w-4xl flex-col overflow-hidden rounded-xl bg-white shadow-2xl">
        <div className="flex items-start justify-between border-b border-gray-100 px-6 py-5">
          <div className="flex items-start gap-4">
            <div className={`rounded-lg p-3 ${hasReceipt ? 'bg-teal-50 text-teal-700' : 'bg-gray-100 text-gray-700'}`}>
              {hasReceipt ? <Receipt size={24} /> : <FileText size={24} />}
            </div>
            <div>
              <h2 className="text-xl font-bold text-gray-950">
                {hasReceipt ? storeName : 'Chi tiết giao dịch'}
              </h2>
              <p className="mt-1 text-sm text-gray-500">
                {hasReceipt ? 'Thông tin hóa đơn đã quét bằng AI' : transaction.description || 'Giao dịch thủ công'}
              </p>
            </div>
          </div>
          <button onClick={onClose} className="rounded-lg p-2 text-gray-400 hover:bg-gray-100 hover:text-gray-700">
            <X size={20} />
          </button>
        </div>

        <div className="overflow-y-auto px-6 py-5">
          <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
            <DetailCard
              label="Số tiền"
              value={`${isIncome ? '+' : '-'}${formatCurrency(transaction.amount)}`}
              tone={isIncome ? 'income' : 'expense'}
            />
            <DetailCard label="Danh mục" value={transaction.categories?.name || 'Không xác định'} />
            <DetailCard
              label="Ngày giao dịch"
              value={`${formatDate(transaction.transaction_date)}${transaction.created_at ? ' · ' + new Date(transaction.created_at).toLocaleTimeString('vi-VN', { hour: '2-digit', minute: '2-digit' }) : ''}`}
              icon={CalendarDays}
            />
          </div>

          <div className="mt-5 rounded-xl border border-gray-200 bg-gray-50 p-5">
            <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
              <InfoRow label="Mô tả" value={transaction.description || 'Không có'} />
              {hasReceipt && <InfoRow label="Tổng hóa đơn" value={formatCurrency(totalAmount)} />}
              {hasReceipt && receiptDate && (
                <InfoRow label="Ngày trên hóa đơn" value={`${formatDate(receiptDate)}${receiptTime ? ` ${receiptTime}` : ''}`} />
              )}
              {hasReceipt && invoiceNumber && <InfoRow label="Mã hóa đơn" value={invoiceNumber} />}
            </div>
          </div>

          {hasReceipt && (
            <div className="mt-6">
              <div className="mb-3 flex items-center justify-between">
                <h3 className="text-lg font-bold text-gray-950">Sản phẩm trong hóa đơn</h3>
                <span className="rounded-full bg-teal-50 px-3 py-1 text-sm font-medium text-teal-700">{items.length} mục</span>
              </div>

              {items.length === 0 ? (
                <div className="rounded-xl border border-dashed border-gray-300 p-6 text-sm text-gray-600">
                  Giao dịch này có dữ liệu OCR nhưng chưa lưu danh sách sản phẩm chi tiết.
                </div>
              ) : (
                <div className="overflow-hidden rounded-xl border border-gray-200">
                  <table className="w-full">
                    <thead className="bg-gray-50">
                      <tr>
                        <th className="px-4 py-3 text-left text-sm font-semibold text-gray-500">Sản phẩm</th>
                        <th className="px-4 py-3 text-right text-sm font-semibold text-gray-500">SL</th>
                        <th className="px-4 py-3 text-right text-sm font-semibold text-gray-500">Đơn giá</th>
                        <th className="px-4 py-3 text-right text-sm font-semibold text-gray-500">Thành tiền</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-gray-100 bg-white">
                      {items.map((item, index) => (
                        <ReceiptItemRow key={`${item.name || index}-${index}`} item={item} />
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  )
}

function DetailCard({ label, value, tone, icon: Icon }) {
  const color = tone === 'income' ? 'text-green-700' : tone === 'expense' ? 'text-red-700' : 'text-gray-950'

  return (
    <div className="rounded-xl border border-gray-200 bg-white p-4">
      <div className="flex items-center gap-2 text-sm font-medium text-gray-500">
        {Icon && <Icon size={16} />}
        {label}
      </div>
      <div className={`mt-2 text-xl font-bold ${color}`}>{value}</div>
    </div>
  )
}

function InfoRow({ label, value }) {
  return (
    <div>
      <div className="text-sm font-medium text-gray-500">{label}</div>
      <div className="mt-1 font-semibold text-gray-950">{value}</div>
    </div>
  )
}

function ReceiptItemRow({ item }) {
  const data = typeof item === 'object' && item !== null ? item : { name: String(item), quantity: 1 }
  const quantity = parseAmount(data.quantity || 1)
  const unitPrice = parseAmount(data.unitPrice || data.price)
  const total = parseAmount(data.total || data.unitPrice || data.price)

  return (
    <tr>
      <td className="px-4 py-3">
        <div className="flex items-center gap-3">
          <div className="rounded-lg bg-teal-50 p-2 text-teal-700">
            <ShoppingBag size={16} />
          </div>
          <span className="font-medium text-gray-900">{data.name || 'Sản phẩm'}</span>
        </div>
      </td>
      <td className="px-4 py-3 text-right text-gray-700">{quantity || 1}</td>
      <td className="px-4 py-3 text-right text-gray-700">{unitPrice ? formatCurrency(unitPrice) : '-'}</td>
      <td className="px-4 py-3 text-right font-semibold text-gray-950">{total ? formatCurrency(total) : '-'}</td>
    </tr>
  )
}
