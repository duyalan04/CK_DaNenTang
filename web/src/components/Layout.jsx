import { Link, useLocation } from 'react-router-dom'
import { LayoutDashboard, Receipt, PiggyBank, BarChart3, LogOut } from 'lucide-react'
import { supabase } from '../lib/supabase'
import ChatBot from './ChatBot'

const navItems = [
  { path: '/', icon: LayoutDashboard, label: 'Dashboard' },
  { path: '/transactions', icon: Receipt, label: 'Giao dịch' },
  { path: '/budgets', icon: PiggyBank, label: 'Ngân sách' },
  { path: '/reports', icon: BarChart3, label: 'Báo cáo' },
]

export default function Layout({ children }) {
  const location = useLocation()

  const handleLogout = async () => {
    await supabase.auth.signOut()
  }

  return (
    <div className="min-h-screen flex">
      <aside className="w-64 bg-white border-r border-gray-200 p-4">
        <div className="mb-8">
          <h1 className="text-xl font-bold text-blue-600">💰 Expense Tracker</h1>
        </div>
        <nav className="space-y-2">
          {navItems.map(({ path, icon: Icon, label }) => (
            <Link
              key={path}
              to={path}
              className={`flex items-center gap-3 px-4 py-2 rounded-lg transition-colors ${location.pathname === path
                ? 'bg-blue-50 text-blue-600'
                : 'text-gray-600 hover:bg-gray-50'
                }`}
            >
              <Icon size={20} />
              {label}
            </Link>
          ))}
        </nav>
        <button
          onClick={handleLogout}
          className="flex items-center gap-3 px-4 py-2 mt-8 text-red-600 hover:bg-red-50 rounded-lg w-full"
        >
          <LogOut size={20} />
          Đăng xuất
        </button>
      </aside>
      <main className="flex-1 p-8">{children}</main>
      <ChatBot />
    </div>
  )
}
