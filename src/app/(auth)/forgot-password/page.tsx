'use client'

import { useSupabase } from '@/providers/supabase-provider'
import { useState } from 'react'

export default function ForgotPasswordPage() {
  const { supabase } = useSupabase()
  const [email, setEmail] = useState('')
  const [sent, setSent] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setError(null)
    const { error } = await supabase.auth.resetPasswordForEmail(email, {
      redirectTo: `${window.location.origin}/auth/callback?next=/auth/update-password`,
    })
    if (error) setError(error.message)
    else setSent(true)
  }

  if (sent) return <p>Check your email for a reset link.</p>

  return (
    <form onSubmit={handleSubmit}>
      <h1>Reset password</h1>
      <input
        type="email"
        value={email}
        onChange={(e) => setEmail(e.target.value)}
        placeholder="Email"
        required
      />
      {error && <p>{error}</p>}
      <button type="submit">Send reset link</button>
      <p><a href="/login">Back to sign in</a></p>
    </form>
  )
}
