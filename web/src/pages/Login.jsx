import { useState } from 'react'
import { supabase } from '../lib/supabase'
import { Eye, EyeOff } from 'lucide-react'
import { useToast } from '../components/Toast'

export default function Login() {
  const toast = useToast()
  const [isLogin, setIsLogin] = useState(true)
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [fullName, setFullName] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [showConfirmPassword, setShowConfirmPassword] = useState(false)

  // Validation states
  const [touched, setTouched] = useState({
    email: false,
    password: false,
    confirmPassword: false,
    fullName: false
  })

  // Password validation
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

    // Validation
    if (!isLogin) {
      if (!fullName.trim()) {
        setError('Vui lòng nhập họ tên')
        return
      }
      if (!isPasswordValid) {
        setError('Mật khẩu chưa đủ mạnh')
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
        // Đăng ký user mới
        const { data, error } = await supabase.auth.signUp({
          email,
          password,
          options: {
            data: { full_name: fullName },
            emailRedirectTo: window.location.origin
          }
        })

        if (error) throw error

        // Nếu signup thành công nhưng cần confirm email
        if (data?.user && !data?.session) {
          setError('')
          toast.success('Đăng ký thành công! Vui lòng kiểm tra email để xác nhận tài khoản.')
          setIsLogin(true)
          return
        }
      }
    } catch (err) {
      // Xử lý lỗi tiếng Việt
      let errorMsg = err.message
      if (err.message.includes('Invalid login credentials')) {
        errorMsg = 'Email hoặc mật khẩu không đúng'
      } else if (err.message.includes('User already registered')) {
        errorMsg = 'Email này đã được đăng ký'
      } else if (err.message.includes('Invalid email')) {
        errorMsg = 'Email không hợp lệ'
      } else if (err.message.includes('Email not confirmed')) {
        errorMsg = 'Vui lòng xác nhận email trước khi đăng nhập. Kiểm tra hộp thư của bạn.'
      } else if (err.message.includes('rate limit') || err.message.includes('429')) {
        errorMsg = 'Quá nhiều yêu cầu. Vui lòng đợi 1 phút rồi thử lại.'
      } else if (err.message.includes('Database error') || err.message.includes('saving new user')) {
        errorMsg = 'Lỗi database khi tạo user. Vui lòng liên hệ admin để chạy script fix_auth_complete.sql'
      } else if (err.message.includes('trigger') || err.message.includes('function')) {
        errorMsg = 'Lỗi cấu hình database. Admin cần chạy migration script.'
      }
      setError(errorMsg)
    } finally {
      setLoading(false)
    }
  }

  const handleBlur = (field) => {
    setTouched(prev => ({ ...prev, [field]: true }))
  }

  const switchMode = () => {
    setIsLogin(!isLogin)
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
    <div className="min-h-screen flex">
      {/* Left side - Clean illustration */}
      <div
        className="hidden lg:flex lg:w-1/2 p-12 flex-col justify-between relative overflow-hidden"
        style={{
          background: 'linear-gradient(135deg, #059669 0%, #047857 50%, #065f46 100%)'
        }}
      >
        {/* Subtle decorative elements */}
        <div className="absolute top-20 right-20 w-64 h-64 rounded-full opacity-10"
          style={{ background: 'radial-gradient(circle, white 0%, transparent 70%)' }}
        />
        <div className="absolute bottom-32 left-10 w-48 h-48 rounded-full opacity-10"
          style={{ background: 'radial-gradient(circle, white 0%, transparent 70%)' }}
        />

        <div className="relative z-10">
          <h1 className="text-white text-2xl font-semibold">
            Expense Tracker
          </h1>
        </div>

        <div className="text-white relative z-10">
          <h2 className="text-4xl font-bold mb-6 leading-tight">
            Quản lý chi tiêu<br />đơn giản & hiệu quả
          </h2>
          <p className="text-white/70 text-lg max-w-md">
            Theo dõi thu chi hàng ngày, lập kế hoạch ngân sách và đạt được mục tiêu tài chính của bạn.
          </p>

          <div className="mt-10 space-y-3">
            <div className="flex items-center gap-3 text-white/90">
              <span className="w-1.5 h-1.5 bg-white rounded-full"></span>
              <span>Theo dõi giao dịch dễ dàng</span>
            </div>
            <div className="flex items-center gap-3 text-white/90">
              <span className="w-1.5 h-1.5 bg-white rounded-full"></span>
              <span>Báo cáo chi tiết theo danh mục</span>
            </div>
            <div className="flex items-center gap-3 text-white/90">
              <span className="w-1.5 h-1.5 bg-white rounded-full"></span>
              <span>Đặt mục tiêu tiết kiệm</span>
            </div>
          </div>
        </div>

        <p className="text-white/50 text-sm relative z-10">
          © 2026 Quản lý tài chính cá nhân
        </p>
      </div>

      {/* Right side - Form */}
      <div className="w-full lg:w-1/2 flex items-center justify-center p-8 bg-white">
        <div className="w-full max-w-md">
          {/* Mobile logo */}
          <div className="lg:hidden text-center mb-10">
            <h1 className="text-2xl font-semibold text-gray-800">
              Expense Tracker
            </h1>
          </div>

          <div>
            <h2 className="text-3xl font-bold text-gray-900 mb-2">
              {isLogin ? 'Đăng nhập' : 'Tạo tài khoản'}
            </h2>
            <p className="text-gray-500 mb-8">
              {isLogin
                ? 'Chào mừng bạn quay lại!'
                : 'Bắt đầu quản lý tài chính của bạn'}
            </p>

            {error && (
              <div className="bg-red-50 text-red-600 px-4 py-3 rounded-lg mb-6 text-sm">
                {error}
              </div>
            )}

            <form onSubmit={handleSubmit} className="space-y-5">
              {/* Full Name - Register only */}
              {!isLogin && (
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Họ và tên
                  </label>
                  <input
                    type="text"
                    placeholder="Nguyễn Văn A"
                    value={fullName}
                    onChange={(e) => setFullName(e.target.value)}
                    onBlur={() => handleBlur('fullName')}
                    className={`w-full px-4 py-3 border rounded-lg focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 outline-none transition-all ${touched.fullName && !fullName.trim()
                      ? 'border-red-300'
                      : 'border-gray-300'
                      }`}
                    required={!isLogin}
                  />
                </div>
              )}

              {/* Email */}
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Email
                </label>
                <input
                  type="email"
                  placeholder="email@example.com"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  onBlur={() => handleBlur('email')}
                  className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 outline-none transition-all"
                  required
                />
              </div>

              {/* Password */}
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Mật khẩu
                </label>
                <div className="relative">
                  <input
                    type={showPassword ? 'text' : 'password'}
                    placeholder="••••••••"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    onBlur={() => handleBlur('password')}
                    className={`w-full px-4 py-3 pr-12 border rounded-lg focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 outline-none transition-all ${touched.password && !isLogin && !isPasswordValid
                      ? 'border-red-300'
                      : 'border-gray-300'
                      }`}
                    required
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword(!showPassword)}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
                  >
                    {showPassword ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}
                  </button>
                </div>

                {/* Password requirements - Register only */}
                {!isLogin && touched.password && (
                  <div className="mt-3 space-y-1.5 text-sm">
                    <div className={passwordChecks.length ? 'text-emerald-600' : 'text-gray-400'}>
                      {passwordChecks.length ? '✓' : '○'} Ít nhất 8 ký tự
                    </div>
                    <div className={passwordChecks.hasLetter ? 'text-emerald-600' : 'text-gray-400'}>
                      {passwordChecks.hasLetter ? '✓' : '○'} Có chữ cái
                    </div>
                    <div className={passwordChecks.hasNumber ? 'text-emerald-600' : 'text-gray-400'}>
                      {passwordChecks.hasNumber ? '✓' : '○'} Có số
                    </div>
                  </div>
                )}
              </div>

              {/* Confirm Password - Register only */}
              {!isLogin && (
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Nhập lại mật khẩu
                  </label>
                  <div className="relative">
                    <input
                      type={showConfirmPassword ? 'text' : 'password'}
                      placeholder="••••••••"
                      value={confirmPassword}
                      onChange={(e) => setConfirmPassword(e.target.value)}
                      onBlur={() => handleBlur('confirmPassword')}
                      className={`w-full px-4 py-3 pr-12 border rounded-lg focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 outline-none transition-all ${touched.confirmPassword && confirmPassword && !passwordsMatch
                        ? 'border-red-300'
                        : touched.confirmPassword && passwordsMatch && confirmPassword
                          ? 'border-emerald-500'
                          : 'border-gray-300'
                        }`}
                      required={!isLogin}
                    />
                    <button
                      type="button"
                      onClick={() => setShowConfirmPassword(!showConfirmPassword)}
                      className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
                    >
                      {showConfirmPassword ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}
                    </button>
                  </div>
                  {touched.confirmPassword && confirmPassword && !passwordsMatch && (
                    <p className="mt-2 text-sm text-red-500">Mật khẩu không khớp</p>
                  )}
                  {touched.confirmPassword && passwordsMatch && confirmPassword && (
                    <p className="mt-2 text-sm text-emerald-600">✓ Mật khẩu khớp</p>
                  )}
                </div>
              )}

              {/* Forgot password - Login only */}
              {isLogin && (
                <div className="text-right">
                  <button type="button" className="text-sm text-emerald-600 hover:text-emerald-700 hover:underline">
                    Quên mật khẩu?
                  </button>
                </div>
              )}

              {/* Submit button */}
              <button
                type="submit"
                disabled={loading || (!isLogin && (!isPasswordValid || !passwordsMatch))}
                className="w-full bg-emerald-600 text-white py-3.5 rounded-lg font-medium hover:bg-emerald-700 disabled:opacity-50 disabled:cursor-not-allowed transition-all"
              >
                {loading ? 'Đang xử lý...' : (isLogin ? 'Đăng nhập' : 'Tạo tài khoản')}
              </button>
            </form>

            {/* Switch mode */}
            <div className="mt-8 text-center">
              <span className="text-gray-500">
                {isLogin ? 'Chưa có tài khoản?' : 'Đã có tài khoản?'}
              </span>
              <button
                onClick={switchMode}
                className="text-emerald-600 font-medium ml-1 hover:text-emerald-700 hover:underline"
              >
                {isLogin ? 'Đăng ký ngay' : 'Đăng nhập'}
              </button>
            </div>
          </div>

          {/* Footer */}
          <p className="text-center text-gray-400 text-sm mt-10">
            Bằng việc tiếp tục, bạn đồng ý với{' '}
            <a href="#" className="text-emerald-600 hover:underline">Điều khoản sử dụng</a>
          </p>
        </div>
      </div>
    </div>
  )
}
