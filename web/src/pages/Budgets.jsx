import { useState, useEffect, useMemo } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import {
  AlertTriangle,
  CalendarDays,
  CheckCircle2,
  Edit3,
  Plus,
  Target,
  Trash2,
  Wallet,
  X,
} from 'lucide-react'
import api from '../lib/api'

const formatCurrency = (value = 0) => {
  return new Intl.NumberFormat('vi-VN', {
    style: 'currency',
    currency: 'VND',
    maximumFractionDigits: 0,
  }).format(Number(value) || 0)
}

const getBudgetTone = (percentage, remaining) => {
  if (remaining < 0 || percentage >= 100) {
    return {
      label: 'Vượt ngân sách',
      bar: 'bg-red-500',
      text: 'text-red-700',
      bg: 'bg-red-50',
      border: 'border-red-100',
      icon: AlertTriangle,
    }
  }

  if (percentage >= 80) {
    return {
      label: 'Gần chạm hạn mức',
      bar: 'bg-amber-500',
      text: 'text-amber-700',
      bg: 'bg-amber-50',
      border: 'border-amber-100',
      icon: AlertTriangle,
    }
  }

  return {
    label: 'Đang an toàn',
    bar: 'bg-emerald-500',
    text: 'text-emerald-700',
    bg: 'bg-emerald-50',
    border: 'border-emerald-100',
    icon: CheckCircle2,
  }
}

export default function Budgets() {
  const queryClient = useQueryClient()
  const [showModal, setShowModal] = useState(false)
  const [editingBudget, setEditingBudget] = useState(null)
  const currentDate = new Date()
  const [month, setMonth] = useState(currentDate.getMonth() + 1)
  const [year, setYear] = useState(currentDate.getFullYear())
  const [form, setForm] = useState({ categoryId: '', amount: '' })

  const { data: budgetStatus, isLoading, isError } = useQuery({
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

  const budgets = budgetStatus || []
  const expenseCategories = categories?.filter(c => c.type === 'expense') || []
  const selectedMonth = `Tháng ${month}/${year}`
  const yearOptions = Array.from({ length: 5 }, (_, index) => currentDate.getFullYear() - 2 + index)

  const summary = useMemo(() => {
    const totalBudget = budgets.reduce((sum, item) => sum + Number(item.amount || 0), 0)
    const totalSpent = budgets.reduce((sum, item) => sum + Number(item.spent || 0), 0)
    const totalRemaining = totalBudget - totalSpent
    const usage = totalBudget > 0 ? Math.round((totalSpent / totalBudget) * 100) : 0
    const overLimit = budgets.filter(item => Number(item.remaining || 0) < 0).length
    const nearLimit = budgets.filter(item => {
      const percentage = Number(item.percentage || 0)
      return percentage >= 80 && percentage < 100 && Number(item.remaining || 0) >= 0
    }).length

    return { totalBudget, totalSpent, totalRemaining, usage, overLimit, nearLimit }
  }, [budgets])

  const createMutation = useMutation({
    mutationFn: (data) => api.post('/budgets', data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['budgetStatus'] })
      closeModal()
    }
  })

  const updateMutation = useMutation({
    mutationFn: ({ id, amount }) => api.put(`/budgets/${id}`, { amount }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['budgetStatus'] })
      closeModal()
    }
  })

  const deleteMutation = useMutation({
    mutationFn: (id) => api.delete(`/budgets/${id}`),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['budgetStatus'] })
    }
  })

  const closeModal = () => {
    setShowModal(false)
    setEditingBudget(null)
    setForm({ categoryId: '', amount: '' })
  }

  const openCreateModal = () => {
    setEditingBudget(null)
    setForm({ categoryId: '', amount: '' })
    setShowModal(true)
  }

  const openEditModal = (budget) => {
    setEditingBudget(budget)
    setForm({ categoryId: budget.category_id, amount: String(Math.round(Number(budget.amount || 0))) })
    setShowModal(true)
  }

  const handleSubmit = (e) => {
    e.preventDefault()
    const amount = parseFloat(form.amount)
    if (!amount || amount <= 0) return

    if (editingBudget) {
      updateMutation.mutate({ id: editingBudget.id, amount })
      return
    }

    createMutation.mutate({ ...form, amount, month, year })
  }

  const handleDelete = (budget) => {
    const categoryName = budget.categories?.name || 'danh mục này'
    if (window.confirm(`Xóa ngân sách ${categoryName} trong ${selectedMonth}?`)) {
      deleteMutation.mutate(budget.id)
    }
  }

  const isSaving = createMutation.isPending || updateMutation.isPending

  return (
    <div className="min-h-[calc(100vh-4rem)] space-y-6">
      <div className="flex flex-col gap-4 xl:flex-row xl:items-start xl:justify-between">
        <div>
          <div className="inline-flex items-center gap-2 rounded-full border border-blue-100 bg-blue-50 px-3 py-1 text-sm font-medium text-blue-700">
            <CalendarDays size={16} />
            {selectedMonth}
          </div>
          <h1 className="mt-3 text-3xl font-bold tracking-tight text-gray-950">Ngân sách</h1>
          <p className="mt-2 max-w-2xl text-sm text-gray-600">
            Theo dõi hạn mức theo danh mục, phát hiện khoản sắp vượt và điều chỉnh ngân sách ngay trên một màn hình.
          </p>
        </div>

        <div className="flex flex-wrap items-center gap-3">
          <select
            value={month}
            onChange={(e) => setMonth(parseInt(e.target.value))}
            className="h-11 rounded-lg border border-gray-200 bg-white px-4 text-sm font-medium text-gray-800 shadow-sm outline-none transition focus:border-blue-500 focus:ring-2 focus:ring-blue-100"
          >
            {Array.from({ length: 12 }, (_, i) => (
              <option key={i + 1} value={i + 1}>Tháng {i + 1}</option>
            ))}
          </select>
          <select
            value={year}
            onChange={(e) => setYear(parseInt(e.target.value))}
            className="h-11 rounded-lg border border-gray-200 bg-white px-4 text-sm font-medium text-gray-800 shadow-sm outline-none transition focus:border-blue-500 focus:ring-2 focus:ring-blue-100"
          >
            {yearOptions.map(y => <option key={y} value={y}>{y}</option>)}
          </select>
          <button
            onClick={openCreateModal}
            className="inline-flex h-11 items-center gap-2 rounded-lg bg-blue-600 px-4 text-sm font-semibold text-white shadow-sm transition hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-200"
          >
            <Plus size={18} />
            Thêm ngân sách
          </button>
        </div>
      </div>

      <div className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-4">
        <SummaryCard
          icon={Wallet}
          label="Tổng ngân sách"
          value={formatCurrency(summary.totalBudget)}
          helper={`${budgets.length} danh mục đang theo dõi`}
        />
        <SummaryCard
          icon={Target}
          label="Đã chi"
          value={formatCurrency(summary.totalSpent)}
          helper={`${summary.usage}% tổng hạn mức`}
        />
        <SummaryCard
          icon={summary.totalRemaining < 0 ? AlertTriangle : CheckCircle2}
          label="Còn lại"
          value={formatCurrency(summary.totalRemaining)}
          helper={summary.totalRemaining < 0 ? 'Cần giảm chi hoặc tăng hạn mức' : 'Có thể dùng đến cuối kỳ'}
          tone={summary.totalRemaining < 0 ? 'danger' : 'success'}
        />
        <SummaryCard
          icon={AlertTriangle}
          label="Cần chú ý"
          value={`${summary.overLimit + summary.nearLimit}`}
          helper={`${summary.overLimit} vượt mức, ${summary.nearLimit} gần chạm`}
          tone={summary.overLimit > 0 ? 'danger' : summary.nearLimit > 0 ? 'warning' : 'default'}
        />
      </div>

      {budgets.length > 0 && (
        <div className="rounded-xl border border-gray-200 bg-white p-5 shadow-sm">
          <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
            <div>
              <h2 className="text-base font-semibold text-gray-950">Tình trạng tháng này</h2>
              <p className="mt-1 text-sm text-gray-600">
                Đã dùng {summary.usage}% tổng ngân sách. Giữ các danh mục dưới 80% để còn dư địa cuối tháng.
              </p>
            </div>
            <div className="min-w-[240px]">
              <div className="mb-2 flex justify-between text-sm font-medium text-gray-700">
                <span>{formatCurrency(summary.totalSpent)}</span>
                <span>{formatCurrency(summary.totalBudget)}</span>
              </div>
              <div className="h-3 overflow-hidden rounded-full bg-gray-100">
                <div
                  className={`h-full rounded-full ${summary.usage >= 100 ? 'bg-red-500' : summary.usage >= 80 ? 'bg-amber-500' : 'bg-blue-600'}`}
                  style={{ width: `${Math.min(summary.usage, 100)}%` }}
                />
              </div>
            </div>
          </div>
        </div>
      )}

      {isLoading ? (
        <div className="grid grid-cols-1 gap-4 lg:grid-cols-2 xl:grid-cols-3">
          {Array.from({ length: 3 }).map((_, index) => (
            <div key={index} className="h-56 animate-pulse rounded-xl border border-gray-200 bg-white shadow-sm" />
          ))}
        </div>
      ) : isError ? (
        <div className="rounded-xl border border-red-100 bg-red-50 p-6 text-red-700">
          Không tải được dữ liệu ngân sách. Vui lòng thử lại sau.
        </div>
      ) : budgets.length === 0 ? (
        <EmptyState onCreate={openCreateModal} selectedMonth={selectedMonth} />
      ) : (
        <div className="grid grid-cols-1 gap-4 lg:grid-cols-2 xl:grid-cols-3">
          {budgets.map((budget) => (
            <BudgetCard
              key={budget.id}
              budget={budget}
              onEdit={openEditModal}
              onDelete={handleDelete}
              isDeleting={deleteMutation.isPending}
            />
          ))}
        </div>
      )}

      {showModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-gray-950/50 px-4 backdrop-blur-sm">
          <div className="w-full max-w-lg rounded-xl bg-white shadow-2xl">
            <div className="flex items-start justify-between border-b border-gray-100 px-6 py-5">
              <div>
                <h2 className="text-xl font-bold text-gray-950">
                  {editingBudget ? 'Chỉnh sửa ngân sách' : 'Thêm ngân sách'}
                </h2>
                <p className="mt-1 text-sm text-gray-500">{selectedMonth}</p>
              </div>
              <button
                onClick={closeModal}
                className="rounded-lg p-2 text-gray-400 transition hover:bg-gray-100 hover:text-gray-700"
                aria-label="Đóng"
              >
                <X size={18} />
              </button>
            </div>

            <form onSubmit={handleSubmit} className="space-y-5 px-6 py-5">
              <div>
                <label className="mb-2 block text-sm font-medium text-gray-700">Danh mục</label>
                {editingBudget ? (
                  <div className="flex items-center gap-3 rounded-lg border border-gray-200 bg-gray-50 px-4 py-3">
                    <span
                      className="h-3 w-3 rounded-full"
                      style={{ backgroundColor: editingBudget.categories?.color || '#2563eb' }}
                    />
                    <span className="font-medium text-gray-900">{editingBudget.categories?.name}</span>
                  </div>
                ) : (
                  <select
                    value={form.categoryId}
                    onChange={(e) => setForm({ ...form, categoryId: e.target.value })}
                    className="w-full rounded-lg border border-gray-200 px-4 py-3 outline-none transition focus:border-blue-500 focus:ring-2 focus:ring-blue-100"
                    required
                  >
                    <option value="">Chọn danh mục chi tiêu</option>
                    {expenseCategories.map(c => <option key={c.id} value={c.id}>{c.name}</option>)}
                  </select>
                )}
              </div>

              <div>
                <label className="mb-2 block text-sm font-medium text-gray-700">Hạn mức ngân sách</label>
                <input
                  type="text"
                  inputMode="numeric"
                  placeholder="Ví dụ: 1000000"
                  value={form.amount}
                  onChange={(e) => {
                    const value = e.target.value.replace(/[^0-9]/g, '')
                    setForm({ ...form, amount: value })
                  }}
                  className="w-full rounded-lg border border-gray-200 px-4 py-3 text-lg font-semibold outline-none transition focus:border-blue-500 focus:ring-2 focus:ring-blue-100"
                  required
                />
                <p className="mt-2 text-sm text-gray-500">
                  Giá trị: <span className="font-medium text-gray-800">{formatCurrency(form.amount)}</span>
                </p>
              </div>

              <div className="flex gap-3 pt-2">
                <button
                  type="button"
                  onClick={closeModal}
                  className="flex-1 rounded-lg border border-gray-200 py-3 text-sm font-semibold text-gray-700 transition hover:bg-gray-50"
                >
                  Hủy
                </button>
                <button
                  type="submit"
                  disabled={isSaving}
                  className="flex-1 rounded-lg bg-blue-600 py-3 text-sm font-semibold text-white transition hover:bg-blue-700 disabled:cursor-not-allowed disabled:opacity-60"
                >
                  {isSaving ? 'Đang lưu...' : editingBudget ? 'Cập nhật' : 'Lưu ngân sách'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  )
}

function SummaryCard({ icon: Icon, label, value, helper, tone = 'default' }) {
  const toneClass = {
    default: 'bg-blue-50 text-blue-700',
    success: 'bg-emerald-50 text-emerald-700',
    warning: 'bg-amber-50 text-amber-700',
    danger: 'bg-red-50 text-red-700',
  }[tone]

  return (
    <div className="rounded-xl border border-gray-200 bg-white p-5 shadow-sm">
      <div className="flex items-start justify-between gap-4">
        <div>
          <p className="text-sm font-medium text-gray-500">{label}</p>
          <p className="mt-2 text-2xl font-bold tracking-tight text-gray-950">{value}</p>
        </div>
        <div className={`rounded-lg p-2 ${toneClass}`}>
          <Icon size={20} />
        </div>
      </div>
      <p className="mt-4 text-sm text-gray-500">{helper}</p>
    </div>
  )
}

function BudgetCard({ budget, onEdit, onDelete, isDeleting }) {
  const amount = Number(budget.amount || 0)
  const spent = Number(budget.spent || 0)
  const remaining = Number(budget.remaining || 0)
  const percentage = amount > 0 ? Math.round((spent / amount) * 100) : 0
  const progress = Math.min(percentage, 100)
  const tone = getBudgetTone(percentage, remaining)
  const StatusIcon = tone.icon

  return (
    <div className="rounded-xl border border-gray-200 bg-white p-5 shadow-sm transition hover:-translate-y-0.5 hover:shadow-md">
      <div className="flex items-start justify-between gap-4">
        <div className="flex min-w-0 items-center gap-3">
          <span
            className="flex h-11 w-11 shrink-0 items-center justify-center rounded-lg text-lg"
            style={{ backgroundColor: `${budget.categories?.color || '#2563eb'}18` }}
          >
            <span
              className="h-3 w-3 rounded-full"
              style={{ backgroundColor: budget.categories?.color || '#2563eb' }}
            />
          </span>
          <div className="min-w-0">
            <h3 className="truncate text-base font-semibold text-gray-950">{budget.categories?.name || 'Danh mục'}</h3>
            <div className={`mt-1 inline-flex items-center gap-1 rounded-full px-2 py-1 text-xs font-medium ${tone.bg} ${tone.text}`}>
              <StatusIcon size={13} />
              {tone.label}
            </div>
          </div>
        </div>

        <div className="flex items-center gap-1">
          <button
            onClick={() => onEdit(budget)}
            className="rounded-lg p-2 text-gray-500 transition hover:bg-gray-100 hover:text-blue-700"
            aria-label="Sửa ngân sách"
          >
            <Edit3 size={17} />
          </button>
          <button
            onClick={() => onDelete(budget)}
            disabled={isDeleting}
            className="rounded-lg p-2 text-gray-500 transition hover:bg-red-50 hover:text-red-700 disabled:opacity-50"
            aria-label="Xóa ngân sách"
          >
            <Trash2 size={17} />
          </button>
        </div>
      </div>

      <div className="mt-5">
        <div className="mb-2 flex items-end justify-between gap-3">
          <div>
            <p className="text-sm text-gray-500">Đã chi</p>
            <p className="text-lg font-bold text-gray-950">{formatCurrency(spent)}</p>
          </div>
          <p className={`text-sm font-semibold ${tone.text}`}>{percentage}%</p>
        </div>
        <div className="h-3 overflow-hidden rounded-full bg-gray-100">
          <div className={`h-full rounded-full ${tone.bar}`} style={{ width: `${progress}%` }} />
        </div>
      </div>

      <div className="mt-5 grid grid-cols-2 gap-3">
        <div className="rounded-lg bg-gray-50 p-3">
          <p className="text-xs font-medium uppercase tracking-wide text-gray-500">Hạn mức</p>
          <p className="mt-1 font-semibold text-gray-950">{formatCurrency(amount)}</p>
        </div>
        <div className={`rounded-lg p-3 ${tone.bg}`}>
          <p className={`text-xs font-medium uppercase tracking-wide ${tone.text}`}>Còn lại</p>
          <p className={`mt-1 font-semibold ${tone.text}`}>{formatCurrency(remaining)}</p>
        </div>
      </div>
    </div>
  )
}

function EmptyState({ onCreate, selectedMonth }) {
  return (
    <div className="flex min-h-[420px] items-center justify-center rounded-xl border border-dashed border-gray-300 bg-white p-10 text-center shadow-sm">
      <div className="max-w-md">
        <div className="mx-auto flex h-14 w-14 items-center justify-center rounded-xl bg-blue-50 text-blue-700">
          <Target size={26} />
        </div>
        <h2 className="mt-5 text-xl font-bold text-gray-950">Chưa có ngân sách cho {selectedMonth}</h2>
        <p className="mt-2 text-sm leading-6 text-gray-600">
          Tạo hạn mức cho các khoản lớn như ăn uống, di chuyển, mua sắm để trang này tự động theo dõi mức đã chi và cảnh báo khi sắp vượt.
        </p>
        <button
          onClick={onCreate}
          className="mt-6 inline-flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-3 text-sm font-semibold text-white shadow-sm transition hover:bg-blue-700"
        >
          <Plus size={18} />
          Tạo ngân sách đầu tiên
        </button>
      </div>
    </div>
  )
}
