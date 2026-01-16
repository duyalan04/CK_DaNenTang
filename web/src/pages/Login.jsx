import { useState } from 'react'
import { supabase } from '../lib/supabase'
import { Eye, EyeOff, Mail, Lock, User, AlertCircle, Check } from 'lucide-react'

export default function Login() {
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
      } else {
        const { error } = await supabase.auth.signUp({
          email,
          password,
          options: { data: { full_name: fullName } }
        })
        if (error) throw error
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
      {/* Left side - Branding */}
      <div className="hidden lg:flex lg:w-1/2 bg-gradient-to-br from-emerald-500 to-teal-600 p-12 flex-col justify-between">
        <div>
          <h1 className="text-white text-3xl font-bold flex items-center gap-3">
            <span className="w-10 h-10 bg-white/20 rounded-xl flex items-center justify-center">
              💰
            </span>
            Expense Tracker
          </h1>
        </div>
        
        <div className="text-white">
          <h2 className="text-4xl font-bold mb-4">
            Quản lý chi tiêu<br />thông minh
          </h2>
          <p className="text-white/80 text-lg">
            Theo dõi thu chi, lập ngân sách và đạt được mục tiêu tài chính của bạn.
          </p>
          
          <div className="mt-8 space-y-4">
            <div className="flex items-center gap-3">
              <div className="w-8 h-8 bg-white/20 rounded-lg flex items-center justify-center">
                <Check className="w-5 h-5" />
              </div>
              <span>Theo dõi giao dịch dễ dàng</span>
            </div>
            <div className="flex items-center gap-3">
              <div className="w-8 h-8 bg-white/20 rounded-lg flex items-center justify-center">
                <Check className="w-5 h-5" />
              </div>
              <span>Báo cáo chi tiết theo danh mục</span>
            </div>
            <div className="flex items-center gap-3">
              <div className="w-8 h-8 bg-white/20 rounded-lg flex items-center justify-center">
                <Check className="w-5 h-5" />
              </div>
              <span>Đặt mục tiêu tiết kiệm</span>
            </div>
          </div>
        </div>

        <p className="text-white/60 text-sm">
          © 2026 Quản lý tài chính cá nhân. Create By Zuy
        </p>
      </div>

      {/* Right side - Form */}
      <div className="w-full lg:w-1/2 flex items-center justify-center p-8 bg-gray-50">
        <div className="w-full max-w-md">
          {/* Mobile logo */}
          <div className="lg:hidden text-center mb-8">
            <h1 className="text-2xl font-bold text-gray-800 flex items-center justify-center gap-2">
              <span>💰</span>
              Expense Tracker
            </h1>
          </div>

          <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-8">
            <h2 className="text-2xl font-bold text-gray-800 mb-2">
              {isLogin ? 'Đăng nhập' : 'Tạo tài khoản'}
            </h2>
            <p className="text-gray-500 mb-6">
              {isLogin 
                ? 'Chào mừng bạn quay lại!' 
                : 'Bắt đầu quản lý tài chính của bạn'}
            </p>

            {error && (
              <div className="bg-red-50 border border-red-200 text-red-600 px-4 py-3 rounded-xl mb-6 flex items-center gap-2">
                <AlertCircle className="w-5 h-5 flex-shrink-0" />
                <span className="text-sm">{error}</span>
              </div>
            )}

            <form onSubmit={handleSubmit} className="space-y-5">
              {/* Full Name - Register only */}
              {!isLogin && (
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1.5">
                    Họ và tên
                  </label>
                  <div className="relative">
                    <User className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
                    <input
                      type="text"
                      placeholder="Nguyễn Văn A"
                      value={fullName}
                      onChange={(e) => setFullName(e.target.value)}
                      onBlur={() => handleBlur('fullName')}
                      className={`w-full pl-10 pr-4 py-3 border rounded-xl focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 outline-none transition-all ${
                        touched.fullName && !fullName.trim() 
                          ? 'border-red-300 bg-red-50' 
                          : 'border-gray-200'
                      }`}
                      required={!isLogin}
                    />
                  </div>
                </div>
              )}

              {/* Email */}
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1.5">
                  Email
                </label>
                <div className="relative">
                  <Mail className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
                  <input
                    type="email"
                    placeholder="email@example.com"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    onBlur={() => handleBlur('email')}
                    className="w-full pl-10 pr-4 py-3 border border-gray-200 rounded-xl focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 outline-none transition-all"
                    required
                  />
                </div>
              </div>

              {/* Password */}
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1.5">
                  Mật khẩu
                </label>
                <div className="relative">
                  <Lock className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
                  <input
                    type={showPassword ? 'text' : 'password'}
                    placeholder="••••••••"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    onBlur={() => handleBlur('password')}
                    className={`w-full pl-10 pr-12 py-3 border rounded-xl focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 outline-none transition-all ${
                      touched.password && !isLogin && !isPasswordValid
                        ? 'border-red-300 bg-red-50'
                        : 'border-gray-200'
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
                  <div className="mt-2 space-y-1">
                    <div className={`flex items-center gap-2 text-xs ${passwordChecks.length ? 'text-emerald-600' : 'text-gray-400'}`}>
                      <div className={`w-4 h-4 rounded-full flex items-center justify-center ${passwordChecks.length ? 'bg-emerald-100' : 'bg-gray-100'}`}>
                        {passwordChecks.length && <Check className="w-3 h-3" />}
                      </div>
                      Ít nhất 8 ký tự
                    </div>
                    <div className={`flex items-center gap-2 text-xs ${passwordChecks.hasLetter ? 'text-emerald-600' : 'text-gray-400'}`}>
                      <div className={`w-4 h-4 rounded-full flex items-center justify-center ${passwordChecks.hasLetter ? 'bg-emerald-100' : 'bg-gray-100'}`}>
                        {passwordChecks.hasLetter && <Check className="w-3 h-3" />}
                      </div>
                      Có chữ cái
                    </div>
                    <div className={`flex items-center gap-2 text-xs ${passwordChecks.hasNumber ? 'text-emerald-600' : 'text-gray-400'}`}>
                      <div className={`w-4 h-4 rounded-full flex items-center justify-center ${passwordChecks.hasNumber ? 'bg-emerald-100' : 'bg-gray-100'}`}>
                        {passwordChecks.hasNumber && <Check className="w-3 h-3" />}
                      </div>
                      Có số
                    </div>
                  </div>
                )}
              </div>

              {/* Confirm Password - Register only */}
              {!isLogin && (
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1.5">
                    Nhập lại mật khẩu
                  </label>
                  <div className="relative">
                    <Lock className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
                    <input
                      type={showConfirmPassword ? 'text' : 'password'}
                      placeholder="••••••••"
                      value={confirmPassword}
                      onChange={(e) => setConfirmPassword(e.target.value)}
                      onBlur={() => handleBlur('confirmPassword')}
                      className={`w-full pl-10 pr-12 py-3 border rounded-xl focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 outline-none transition-all ${
                        touched.confirmPassword && confirmPassword && !passwordsMatch
                          ? 'border-red-300 bg-red-50'
                          : touched.confirmPassword && passwordsMatch && confirmPassword
                          ? 'border-emerald-300 bg-emerald-50'
                          : 'border-gray-200'
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
                    <p className="mt-1.5 text-xs text-red-500">Mật khẩu không khớp</p>
                  )}
                  {touched.confirmPassword && passwordsMatch && confirmPassword && (
                    <p className="mt-1.5 text-xs text-emerald-600 flex items-center gap-1">
                      <Check className="w-3 h-3" /> Mật khẩu khớp
                    </p>
                  )}
                </div>
              )}

              {/* Forgot password - Login only */}
              {isLogin && (
                <div className="text-right">
                  <button type="button" className="text-sm text-emerald-600 hover:text-emerald-700">
                    Quên mật khẩu?
                  </button>
                </div>
              )}

              {/* Submit button */}
              <button
                type="submit"
                disabled={loading || (!isLogin && (!isPasswordValid || !passwordsMatch))}
                className="w-full bg-emerald-600 text-white py-3 rounded-xl font-medium hover:bg-emerald-700 disabled:opacity-50 disabled:cursor-not-allowed transition-all flex items-center justify-center gap-2"
              >
                {loading ? (
                  <>
                    <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                    Đang xử lý...
                  </>
                ) : (
                  isLogin ? 'Đăng nhập' : 'Tạo tài khoản'
                )}
              </button>
            </form>

            {/* Switch mode */}
            <div className="mt-6 text-center">
              <span className="text-gray-500">
                {isLogin ? 'Chưa có tài khoản?' : 'Đã có tài khoản?'}
              </span>
              <button
                onClick={switchMode}
                className="text-emerald-600 font-medium ml-1 hover:text-emerald-700"
              >
                {isLogin ? 'Đăng ký ngay' : 'Đăng nhập'}
              </button>
            </div>
          </div>

          {/* Footer */}
          <p className="text-center text-gray-400 text-sm mt-6">
            Bằng việc tiếp tục, bạn đồng ý với{' '}
            <a href="#" className="text-emerald-600 hover:underline">Điều khoản sử dụng</a>
          </p>
        </div>
      </div>
    </div>
  )
}
