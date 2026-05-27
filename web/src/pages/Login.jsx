import { useState } from 'react'
import { supabase } from '../lib/supabase'
import {
  ArrowRight,
  BarChart3,
  Check,
  Eye,
  EyeOff,
  Lock,
  Mail,
  ShieldCheck,
  User
} from 'lucide-react'
import { useToast } from '../components/Toast'

export default function Login() {
  const toast = useToast()
  const [isLogin, setIsLogin] = useState(true)
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [fullName, setFullName] = useState('')
  const [loading, setLoading] = useState(false)
  const [resetLoading, setResetLoading] = useState(false)
  const [error, setError] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [showConfirmPassword, setShowConfirmPassword] = useState(false)

  const [touched, setTouched] = useState({
    email: false,
    password: false,
    confirmPassword: false,
    fullName: false
  })

  const passwordChecks = {
    length: password.length >= 8,
    hasLetter: /[a-zA-Z]/.test(password),
    hasNumber: /[0-9]/.test(password)
  }
  const isPasswordValid = passwordChecks.length && passwordChecks.hasLetter && passwordChecks.hasNumber
  const passwordsMatch = password === confirmPassword

  const handleSubmit = async (e) => {
    e.preventDefault()
    setError('')

    if (!isLogin) {
      if (!fullName.trim()) {
        setError('Vui lòng nhập họ tên')
        return
      }
      if (!isPasswordValid) {
        setError('Mật khẩu cần tối thiểu 8 ký tự, có chữ cái và số')
        return
      }
      if (!passwordsMatch) {
        setError('Mật khẩu nhập lại không khớp')
        return
      }
    }

    setLoading(true)

    try {
      if (isLogin) {
        const { error } = await supabase.auth.signInWithPassword({ email, password })
        if (error) throw error
        toast.success('Đăng nhập thành công!')
      } else {
        const { data, error } = await supabase.auth.signUp({
          email,
          password,
          options: {
            data: { full_name: fullName },
            emailRedirectTo: window.location.origin
          }
        })

        if (error) throw error

        if (data?.user && !data?.session) {
          setError('')
          toast.success('Đăng ký thành công! Vui lòng kiểm tra email để xác nhận tài khoản.')
          setIsLogin(true)
          return
        }
      }
    } catch (err) {
      setError(getFriendlyAuthError(err))
    } finally {
      setLoading(false)
    }
  }

  const handleForgotPassword = async () => {
    setError('')

    if (!email.trim()) {
      setError('Nhập email trước để nhận link đặt lại mật khẩu')
      return
    }

    setResetLoading(true)

    try {
      const { error } = await supabase.auth.resetPasswordForEmail(email, {
        redirectTo: window.location.origin
      })

      if (error) throw error
      toast.success('Đã gửi link đặt lại mật khẩu vào email của bạn.')
    } catch (err) {
      setError(getFriendlyAuthError(err))
    } finally {
      setResetLoading(false)
    }
  }

  const handleBlur = (field) => {
    setTouched(prev => ({ ...prev, [field]: true }))
  }

  const switchMode = () => {
    setIsLogin(prev => !prev)
    setError('')
    setPassword('')
    setConfirmPassword('')
    setTouched({
      email: false,
      password: false,
      confirmPassword: false,
      fullName: false
    })
  }

  return (
    <main className="min-h-screen bg-slate-50 text-slate-950">
      <div className="mx-auto grid min-h-screen w-full max-w-7xl grid-cols-1 lg:grid-cols-[1fr_480px]">
        <section className="hidden border-r border-slate-200 bg-white px-12 py-10 lg:flex lg:flex-col">
          <div className="flex items-center gap-3">
            <img
              src="/favicon.png"
              alt="Expense Tracker"
              className="h-16 w-auto object-contain"
            />
            <div className="sr-only">
              <p>Expense Tracker</p>
              <p className="text-sm text-slate-500">Quản lý tài chính cá nhân</p>
            </div>
          </div>

          <div className="flex flex-1 items-center">
            <div className="max-w-xl">
              <p className="mb-4 text-sm font-semibold uppercase tracking-wider text-emerald-700">
                Private finance workspace
              </p>
              <h1 className="text-5xl font-semibold leading-tight tracking-normal text-slate-950">
                Theo dõi thu chi rõ ràng, quyết định tiền bạc chắc hơn.
              </h1>
              <p className="mt-5 max-w-lg text-lg leading-8 text-slate-600">
                Một nơi gọn gàng để xem số dư, kiểm soát ngân sách và hiểu thói quen chi tiêu của bạn qua từng tháng.
              </p>

              <div className="mt-10 grid grid-cols-3 gap-3">
                <MetricCard label="Thu nhập" value="2.000.000 đ" tone="green" />
                <MetricCard label="Chi tiêu" value="1.430.000 đ" tone="red" />
                <MetricCard label="Còn lại" value="570.000 đ" tone="blue" />
              </div>

              <div className="mt-8 rounded-lg border border-slate-200 bg-slate-50 p-5">
                <div className="mb-4 flex items-center justify-between">
                  <div>
                    <p className="text-sm font-medium text-slate-500">Sức khỏe tài chính</p>
                    <p className="mt-1 text-2xl font-semibold text-slate-950">Grade A</p>
                  </div>
                  <BarChart3 className="h-7 w-7 text-emerald-700" />
                </div>
                <div className="h-2 rounded-full bg-slate-200">
                  <div className="h-2 w-4/5 rounded-full bg-emerald-600" />
                </div>
                <p className="mt-3 text-sm text-slate-500">
                  Dữ liệu được trình bày đơn giản để bạn nhìn ra vấn đề nhanh, không bị nhiễu bởi hiệu ứng trang trí.
                </p>
              </div>
            </div>
          </div>

          <div className="flex items-center gap-2 text-sm text-slate-500">
            <ShieldCheck className="h-4 w-4 text-emerald-700" />
            Dữ liệu đăng nhập được xử lý qua Supabase Authentication.
          </div>
        </section>

        <section className="flex min-h-screen items-center justify-center px-5 py-8 sm:px-8">
          <div className="w-full max-w-md">
            <div className="mb-8 lg:hidden">
              <img
                src="/favicon.png"
                alt="Expense Tracker"
                className="mb-4 h-16 w-auto object-contain"
              />
              <p className="mt-1 text-sm text-slate-500">Quản lý tài chính cá nhân</p>
            </div>

            <div className="rounded-xl border border-slate-200 bg-white p-6 shadow-sm sm:p-8">
              <div className="mb-7">
                <p className="text-sm font-medium text-slate-500">
                  {isLogin ? 'Chào mừng bạn quay lại' : 'Tạo tài khoản mới'}
                </p>
                <h2 className="mt-2 text-2xl font-semibold tracking-normal text-slate-950">
                  {isLogin ? 'Đăng nhập' : 'Đăng ký'}
                </h2>
              </div>

              <div className="mb-6 grid grid-cols-2 rounded-lg bg-slate-100 p-1">
                <button
                  type="button"
                  onClick={() => !isLogin && switchMode()}
                  className={`h-10 rounded-md text-sm font-medium transition-colors ${isLogin
                    ? 'bg-white text-slate-950 shadow-sm'
                    : 'text-slate-500 hover:text-slate-900'
                  }`}
                >
                  Đăng nhập
                </button>
                <button
                  type="button"
                  onClick={() => isLogin && switchMode()}
                  className={`h-10 rounded-md text-sm font-medium transition-colors ${!isLogin
                    ? 'bg-white text-slate-950 shadow-sm'
                    : 'text-slate-500 hover:text-slate-900'
                  }`}
                >
                  Đăng ký
                </button>
              </div>

              {error && (
                <div className="mb-5 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
                  {error}
                </div>
              )}

              <form onSubmit={handleSubmit} className="space-y-4">
                {!isLogin && (
                  <Field label="Họ và tên" error={touched.fullName && !fullName.trim()}>
                    <User className="h-5 w-5 text-slate-400" />
                    <input
                      type="text"
                      placeholder="Nguyễn Văn A"
                      value={fullName}
                      onChange={(e) => setFullName(e.target.value)}
                      onBlur={() => handleBlur('fullName')}
                      className="min-w-0 flex-1 bg-transparent text-sm text-slate-950 outline-none placeholder:text-slate-400"
                      required={!isLogin}
                    />
                  </Field>
                )}

                <Field label="Email">
                  <Mail className="h-5 w-5 text-slate-400" />
                  <input
                    type="email"
                    placeholder="email@example.com"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    onBlur={() => handleBlur('email')}
                    className="min-w-0 flex-1 bg-transparent text-sm text-slate-950 outline-none placeholder:text-slate-400"
                    required
                  />
                </Field>

                <Field label="Mật khẩu" error={touched.password && !isLogin && !isPasswordValid}>
                  <Lock className="h-5 w-5 text-slate-400" />
                  <input
                    type={showPassword ? 'text' : 'password'}
                    placeholder="Nhập mật khẩu"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    onBlur={() => handleBlur('password')}
                    className="min-w-0 flex-1 bg-transparent text-sm text-slate-950 outline-none placeholder:text-slate-400"
                    required
                  />
                  <PasswordToggle
                    active={showPassword}
                    onClick={() => setShowPassword(prev => !prev)}
                  />
                </Field>

                {!isLogin && touched.password && (
                  <div className="grid gap-2 rounded-lg bg-slate-50 p-3">
                    <PasswordCheck passed={passwordChecks.length} text="Ít nhất 8 ký tự" />
                    <PasswordCheck passed={passwordChecks.hasLetter} text="Có chữ cái" />
                    <PasswordCheck passed={passwordChecks.hasNumber} text="Có số" />
                  </div>
                )}

                {!isLogin && (
                  <>
                    <Field
                      label="Nhập lại mật khẩu"
                      error={touched.confirmPassword && confirmPassword && !passwordsMatch}
                      success={touched.confirmPassword && confirmPassword && passwordsMatch}
                    >
                      <Lock className="h-5 w-5 text-slate-400" />
                      <input
                        type={showConfirmPassword ? 'text' : 'password'}
                        placeholder="Nhập lại mật khẩu"
                        value={confirmPassword}
                        onChange={(e) => setConfirmPassword(e.target.value)}
                        onBlur={() => handleBlur('confirmPassword')}
                        className="min-w-0 flex-1 bg-transparent text-sm text-slate-950 outline-none placeholder:text-slate-400"
                        required={!isLogin}
                      />
                      <PasswordToggle
                        active={showConfirmPassword}
                        onClick={() => setShowConfirmPassword(prev => !prev)}
                      />
                    </Field>

                    {touched.confirmPassword && confirmPassword && (
                      <p className={`text-sm ${passwordsMatch ? 'text-emerald-700' : 'text-red-600'}`}>
                        {passwordsMatch ? 'Mật khẩu đã khớp' : 'Mật khẩu không khớp'}
                      </p>
                    )}
                  </>
                )}

                {isLogin && (
                  <div className="flex justify-end">
                    <button
                      type="button"
                      onClick={handleForgotPassword}
                      disabled={resetLoading}
                      className="text-sm font-medium text-slate-600 transition-colors hover:text-slate-950 disabled:cursor-not-allowed disabled:opacity-60"
                    >
                      {resetLoading ? 'Đang gửi...' : 'Quên mật khẩu?'}
                    </button>
                  </div>
                )}

                <button
                  type="submit"
                  disabled={loading || (!isLogin && (!isPasswordValid || !passwordsMatch))}
                  className="flex h-12 w-full items-center justify-center gap-2 rounded-lg bg-slate-950 px-4 text-sm font-semibold text-white transition-colors hover:bg-slate-800 disabled:cursor-not-allowed disabled:opacity-60"
                >
                  {loading ? (
                    <span className="h-5 w-5 animate-spin rounded-full border-2 border-white/30 border-t-white" />
                  ) : (
                    <>
                      {isLogin ? 'Đăng nhập' : 'Tạo tài khoản'}
                      <ArrowRight className="h-4 w-4" />
                    </>
                  )}
                </button>
              </form>
            </div>

            <p className="mt-6 text-center text-sm leading-6 text-slate-500">
              Bằng việc tiếp tục, bạn đồng ý với điều khoản sử dụng và chính sách bảo mật của Expense Tracker.
            </p>
          </div>
        </section>
      </div>
    </main>
  )
}

function Field({ label, error, success, children }) {
  const borderClass = error
    ? 'border-red-300 ring-1 ring-red-100'
    : success
      ? 'border-emerald-300 ring-1 ring-emerald-100'
      : 'border-slate-300 focus-within:border-slate-900'

  return (
    <label className="block">
      <span className="mb-2 block text-sm font-medium text-slate-700">{label}</span>
      <div className={`flex h-12 items-center gap-3 rounded-lg border bg-white px-3 transition-colors ${borderClass}`}>
        {children}
      </div>
    </label>
  )
}

function PasswordToggle({ active, onClick }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="flex h-8 w-8 items-center justify-center rounded-md text-slate-400 transition-colors hover:bg-slate-100 hover:text-slate-700"
      aria-label={active ? 'Ẩn mật khẩu' : 'Hiện mật khẩu'}
    >
      {active ? <EyeOff className="h-5 w-5" /> : <Eye className="h-5 w-5" />}
    </button>
  )
}

function PasswordCheck({ passed, text }) {
  return (
    <div className={`flex items-center gap-2 text-sm ${passed ? 'text-emerald-700' : 'text-slate-500'}`}>
      <span className={`flex h-4 w-4 items-center justify-center rounded-full border ${passed ? 'border-emerald-600 bg-emerald-600 text-white' : 'border-slate-300'}`}>
        {passed && <Check className="h-3 w-3" />}
      </span>
      {text}
    </div>
  )
}

function MetricCard({ label, value, tone }) {
  const toneClass = {
    green: 'text-emerald-700',
    red: 'text-red-700',
    blue: 'text-blue-700'
  }[tone]

  return (
    <div className="rounded-lg border border-slate-200 bg-white p-4 shadow-sm">
      <p className="text-sm text-slate-500">{label}</p>
      <p className={`mt-2 text-lg font-semibold ${toneClass}`}>{value}</p>
    </div>
  )
}

function getFriendlyAuthError(err) {
  const message = err?.message || 'Đã có lỗi xảy ra'

  if (message.includes('Invalid login credentials')) {
    return 'Email hoặc mật khẩu không đúng'
  }
  if (message.includes('User already registered')) {
    return 'Email này đã được đăng ký'
  }
  if (message.includes('Invalid email')) {
    return 'Email không hợp lệ'
  }
  if (message.includes('Email not confirmed')) {
    return 'Vui lòng xác nhận email trước khi đăng nhập. Kiểm tra hộp thư của bạn.'
  }
  if (message.includes('rate limit') || message.includes('429')) {
    return 'Quá nhiều yêu cầu. Vui lòng đợi 1 phút rồi thử lại.'
  }
  if (message.includes('Database error') || message.includes('saving new user')) {
    return 'Lỗi database khi tạo user. Vui lòng liên hệ admin.'
  }

  return message
}
