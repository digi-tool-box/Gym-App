import { LoginForm } from '@/components/auth/login-form'

export default function LoginPage() {
  return (
    <div>
      <h1>Sign in</h1>
      <p>Sign in to your gym account</p>
      <LoginForm />
      <p>
        <a href="/register">Create an account</a>
      </p>
      <p>
        <a href="/forgot-password">Forgot password?</a>
      </p>
    </div>
  )
}
