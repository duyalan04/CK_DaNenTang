import { useEffect, useMemo, useState } from 'react'
import {
  CalendarDays,
  Check,
  Eye,
  EyeOff,
  KeyRound,
  Lock,
  Mail,
  Save,
  ShieldCheck,
  User
} from 'lucide-react'
import { supabase } from '../lib/supabase'
import { useToast } from '../components/Toast'

export default function Profile() {
  const toast = useToast()
  const [user, setUser] = useState(null)
  const [profile, setProfile] = useState(null)
  const [fullName, setFullName] = useState('')
  const [currency, setCurrency] = useState('VND')
  const [loading, setLoading] = useState(true)
  const [savingProfile, setSavingProfile] = useState(false)
  const [changingPassword, setChangingPassword] = useState(false)
  const [error, setError] = useState('')
  const [passwordForm, setPasswordForm] = useState({
    currentPassword: '',
    newPassword: '',
    confirmPassword: ''
  })
  const [visiblePasswords, setVisiblePasswords] = useState({
    currentPassword: false,
    newPassword: false,
    confirmPassword: false
  })

  useEffect(() => {
    loadProfile()
  }, [])

  const primaryProvider = user?.app_metadata?.provider || user?.identities?.[0]?.provider || 'email'
  const isPasswordAccount = primaryProvider === 'email'
  const displayName = fullName || user?.user_metadata?.full_name || user?.email?.split('@')[0] || 'Người dùng'

  const passwordChecks = useMemo(() => ({
    length: passwordForm.newPassword.length >= 8,
    hasLetter: /[a-zA-Z]/.test(passwordForm.newPassword),
    hasNumber: /[0-9]/.test(passwordForm.newPassword),
    match: passwordForm.newPassword.length > 0 && passwordForm.newPassword === passwordForm.confirmPassword
  }), [passwordForm.confirmPassword, passwordForm.newPassword])

  const canChangePassword = passwordChecks.length
    && passwordChecks.hasLetter
    && passwordChecks.hasNumber
    && passwordChecks.match
    && (!isPasswordAccount || passwordForm.currentPassword.length > 0)

  async function loadProfile() {
    setLoading(true)
    setError('')

    try {
      const { data: userData, error: userError } = await supabase.auth.getUser()
      if (userError) throw userError

      const currentUser = userData.user
      setUser(currentUser)

      const { data: profileData, error: profileError } = await supabase
        .from('profiles')
        .select('id, full_name, avatar_url, currency, created_at, updated_at')
        .eq('id', currentUser.id)
        .maybeSingle()

      if (profileError) throw profileError

      setProfile(profileData)
      setFullName(profileData?.full_name || currentUser.user_metadata?.full_name || currentUser.user_metadata?.name || '')
      setCurrency(profileData?.currency || 'VND')
    } catch (err) {
      setError(getFriendlyError(err))
    } finally {
      setLoading(false)
    }
  }

  async function handleSaveProfile(e) {
    e.preventDefault()
    setError('')

    if (!fullName.trim()) {
      setError('Vui lòng nhập họ tên')
      return
    }

    setSavingProfile(true)

    try {
      const cleanName = fullName.trim()

      const { error: authError } = await supabase.auth.updateUser({
        data: { full_name: cleanName }
      })
      if (authError) throw authError

      const { data: profileData, error: profileError } = await supabase
        .from('profiles')
        .upsert({
          id: user.id,
          full_name: cleanName,
          currency,
          updated_at: new Date().toISOString()
        })
        .select('id, full_name, avatar_url, currency, created_at, updated_at')
        .single()

      if (profileError) throw profileError

      setProfile(profileData)
      toast.success('Đã cập nhật thông tin cá nhân.')
    } catch (err) {
      setError(getFriendlyError(err))
    } finally {
      setSavingProfile(false)
    }
  }

  async function handleChangePassword(e) {
    e.preventDefault()
    setError('')

    if (!canChangePassword) {
      setError('Kiểm tra lại thông tin đổi mật khẩu')
      return
    }

    setChangingPassword(true)

    try {
      if (isPasswordAccount) {
        const { error: verifyError } = await supabase.auth.signInWithPassword({
          email: user.email,
          password: passwordForm.currentPassword
        })
        if (verifyError) {
          throw new Error('Mật khẩu hiện tại không đúng')
        }
      }

      const { error: updateError } = await supabase.auth.updateUser({
        password: passwordForm.newPassword
      })
      if (updateError) throw updateError

      setPasswordForm({
        currentPassword: '',
        newPassword: '',
        confirmPassword: ''
      })
      toast.success('Đã đổi mật khẩu thành công.')
    } catch (err) {
      setError(getFriendlyError(err))
    } finally {
      setChangingPassword(false)
    }
  }

  function updatePasswordField(field, value) {
    setPasswordForm(prev => ({ ...prev, [field]: value }))
  }

  function togglePassword(field) {
    setVisiblePasswords(prev => ({ ...prev, [field]: !prev[field] }))
  }

  if (loading) {
    return (
      <div className="flex min-h-[50vh] items-center justify-center">
        <div className="h-10 w-10 animate-spin rounded-full border-2 border-blue-100 border-t-blue-600" />
      </div>
    )
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Thông tin cá nhân</h1>
        <p className="mt-1 text-gray-500">Quản lý hồ sơ đăng nhập và bảo mật tài khoản.</p>
      </div>

      {error && (
        <div className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          {error}
        </div>
      )}

      <section className="grid grid-cols-1 gap-6 xl:grid-cols-[360px_1fr]">
        <ProfileSummary
          displayName={displayName}
          email={user?.email}
          provider={primaryProvider}
          createdAt={user?.created_at || profile?.created_at}
          lastSignInAt={user?.last_sign_in_at}
        />

        <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
          <form onSubmit={handleSaveProfile} className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
            <div className="mb-5 flex items-center gap-3">
              <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-blue-50 text-blue-600">
                <User size={20} />
              </div>
              <div>
                <h2 className="text-lg font-semibold">Hồ sơ</h2>
                <p className="text-sm text-gray-500">Thông tin hiển thị trong tài khoản.</p>
              </div>
            </div>

            <div className="space-y-4">
              <ProfileField label="Họ và tên">
                <User className="h-5 w-5 text-gray-400" />
                <input
                  value={fullName}
                  onChange={(e) => setFullName(e.target.value)}
                  placeholder="Nhập họ tên"
                  className="min-w-0 flex-1 bg-transparent text-sm outline-none placeholder:text-gray-400"
                />
              </ProfileField>

              <ProfileField label="Email">
                <Mail className="h-5 w-5 text-gray-400" />
                <input
                  value={user?.email || ''}
                  disabled
                  className="min-w-0 flex-1 bg-transparent text-sm text-gray-500 outline-none"
                />
              </ProfileField>

              <label className="block">
                <span className="mb-2 block text-sm font-medium text-gray-700">Tiền tệ mặc định</span>
                <select
                  value={currency}
                  onChange={(e) => setCurrency(e.target.value)}
                  className="h-12 w-full rounded-lg border border-gray-300 bg-white px-3 text-sm outline-none transition-colors focus:border-blue-600"
                >
                  <option value="VND">VND - Việt Nam đồng</option>
                  <option value="USD">USD - US Dollar</option>
                </select>
              </label>
            </div>

            <button
              type="submit"
              disabled={savingProfile}
              className="mt-6 flex h-11 w-full items-center justify-center gap-2 rounded-lg bg-blue-600 px-4 text-sm font-semibold text-white transition-colors hover:bg-blue-700 disabled:cursor-not-allowed disabled:opacity-60"
            >
              {savingProfile ? (
                <span className="h-5 w-5 animate-spin rounded-full border-2 border-white/30 border-t-white" />
              ) : (
                <>
                  <Save size={18} />
                  Lưu thay đổi
                </>
              )}
            </button>
          </form>

          <form onSubmit={handleChangePassword} className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
            <div className="mb-5 flex items-center gap-3">
              <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-emerald-50 text-emerald-600">
                <KeyRound size={20} />
              </div>
              <div>
                <h2 className="text-lg font-semibold">Đổi mật khẩu</h2>
                <p className="text-sm text-gray-500">
                  {isPasswordAccount ? 'Xác nhận mật khẩu hiện tại trước khi đổi.' : 'Tài khoản Google có thể đặt thêm mật khẩu đăng nhập.'}
                </p>
              </div>
            </div>

            <div className="space-y-4">
              {isPasswordAccount && (
                <PasswordField
                  label="Mật khẩu hiện tại"
                  value={passwordForm.currentPassword}
                  visible={visiblePasswords.currentPassword}
                  onChange={(value) => updatePasswordField('currentPassword', value)}
                  onToggle={() => togglePassword('currentPassword')}
                />
              )}

              <PasswordField
                label="Mật khẩu mới"
                value={passwordForm.newPassword}
                visible={visiblePasswords.newPassword}
                onChange={(value) => updatePasswordField('newPassword', value)}
                onToggle={() => togglePassword('newPassword')}
              />

              <PasswordField
                label="Nhập lại mật khẩu mới"
                value={passwordForm.confirmPassword}
                visible={visiblePasswords.confirmPassword}
                onChange={(value) => updatePasswordField('confirmPassword', value)}
                onToggle={() => togglePassword('confirmPassword')}
              />

              <div className="grid gap-2 rounded-lg bg-gray-50 p-3">
                <PasswordCheck passed={passwordChecks.length} text="Ít nhất 8 ký tự" />
                <PasswordCheck passed={passwordChecks.hasLetter} text="Có chữ cái" />
                <PasswordCheck passed={passwordChecks.hasNumber} text="Có số" />
                <PasswordCheck passed={passwordChecks.match} text="Mật khẩu nhập lại khớp" />
              </div>
            </div>

            <button
              type="submit"
              disabled={!canChangePassword || changingPassword}
              className="mt-6 flex h-11 w-full items-center justify-center gap-2 rounded-lg bg-gray-900 px-4 text-sm font-semibold text-white transition-colors hover:bg-gray-800 disabled:cursor-not-allowed disabled:opacity-60"
            >
              {changingPassword ? (
                <span className="h-5 w-5 animate-spin rounded-full border-2 border-white/30 border-t-white" />
              ) : (
                <>
                  <Lock size={18} />
                  Cập nhật mật khẩu
                </>
              )}
            </button>
          </form>
        </div>
      </section>
    </div>
  )
}

function ProfileSummary({ displayName, email, provider, createdAt, lastSignInAt }) {
  const initials = displayName
    .split(' ')
    .filter(Boolean)
    .slice(0, 2)
    .map(word => word[0])
    .join('')
    .toUpperCase() || 'U'

  return (
    <aside className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
      <div className="flex items-center gap-4">
        <div className="flex h-16 w-16 items-center justify-center rounded-full bg-blue-600 text-xl font-bold text-white">
          {initials}
        </div>
        <div className="min-w-0">
          <h2 className="truncate text-lg font-semibold">{displayName}</h2>
          <p className="truncate text-sm text-gray-500">{email}</p>
        </div>
      </div>

      <div className="mt-6 space-y-3">
        <SummaryRow icon={ShieldCheck} label="Phương thức đăng nhập" value={provider === 'google' ? 'Google' : 'Email'} />
        <SummaryRow icon={CalendarDays} label="Ngày tạo tài khoản" value={formatDate(createdAt)} />
        <SummaryRow icon={KeyRound} label="Lần đăng nhập gần nhất" value={formatDate(lastSignInAt)} />
      </div>
    </aside>
  )
}

function SummaryRow({ icon: Icon, label, value }) {
  return (
    <div className="flex items-center gap-3 rounded-lg bg-gray-50 p-3">
      <Icon className="h-5 w-5 text-gray-500" />
      <div>
        <p className="text-xs text-gray-500">{label}</p>
        <p className="text-sm font-medium text-gray-900">{value}</p>
      </div>
    </div>
  )
}

function ProfileField({ label, children }) {
  return (
    <label className="block">
      <span className="mb-2 block text-sm font-medium text-gray-700">{label}</span>
      <div className="flex h-12 items-center gap-3 rounded-lg border border-gray-300 bg-white px-3 transition-colors focus-within:border-blue-600">
        {children}
      </div>
    </label>
  )
}

function PasswordField({ label, value, visible, onChange, onToggle }) {
  return (
    <ProfileField label={label}>
      <Lock className="h-5 w-5 text-gray-400" />
      <input
        type={visible ? 'text' : 'password'}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder="Nhập mật khẩu"
        className="min-w-0 flex-1 bg-transparent text-sm outline-none placeholder:text-gray-400"
      />
      <button
        type="button"
        onClick={onToggle}
        className="flex h-8 w-8 items-center justify-center rounded-md text-gray-400 transition-colors hover:bg-gray-100 hover:text-gray-700"
        aria-label={visible ? 'Ẩn mật khẩu' : 'Hiện mật khẩu'}
      >
        {visible ? <EyeOff className="h-5 w-5" /> : <Eye className="h-5 w-5" />}
      </button>
    </ProfileField>
  )
}

function PasswordCheck({ passed, text }) {
  return (
    <div className={`flex items-center gap-2 text-sm ${passed ? 'text-emerald-700' : 'text-gray-500'}`}>
      <span className={`flex h-4 w-4 items-center justify-center rounded-full border ${passed ? 'border-emerald-600 bg-emerald-600 text-white' : 'border-gray-300'}`}>
        {passed && <Check className="h-3 w-3" />}
      </span>
      {text}
    </div>
  )
}

function formatDate(value) {
  if (!value) return 'Chưa có'

  return new Intl.DateTimeFormat('vi-VN', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric'
  }).format(new Date(value))
}

function getFriendlyError(err) {
  const message = err?.message || 'Đã có lỗi xảy ra'

  if (message.includes('Invalid login credentials')) {
    return 'Email hoặc mật khẩu không đúng'
  }
  if (message.includes('New password should be different')) {
    return 'Mật khẩu mới cần khác mật khẩu hiện tại'
  }
  if (message.includes('Password should be at least')) {
    return 'Mật khẩu cần đủ mạnh hơn'
  }
  if (message.includes('JWT')) {
    return 'Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại'
  }

  return message
}
