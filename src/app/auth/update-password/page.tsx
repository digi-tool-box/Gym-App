'use client'

import { useSupabase } from '@/providers/supabase-provider'
import { useRouter } from 'next/navigation'
import { useState } from 'react'

export default function UpdatePasswordPage() {
  const { supabase } = useSupabase()
  const router = useRouter()
  const [password, setPassword] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [isLoading, setIsLoading] = useState(false)
  const [isComplete, setIsComplete] = useState(false)

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setError(null)
    setIsLoading(true)

    const { error } = await supabase.auth.updateUser({ password })

    if (error) {
      setError(error.message)
      setIsLoading(false)
      return
    }

    setIsComplete(true)
    setIsLoading(false)
  }

  if (isComplete) {
    return (
      <div>
        <h1>Password updated</h1>
        <p>Your password has been changed successfully.</p>
        <a href="/login">Go to sign in</a>
      </div>
    )
  }

  return (
    <form onSubmit={handleSubmit}>
      <h1>Set new password</h1>
      <div>
        <label htmlFor="password">New password</label>
        <input
          id="password"
          type="password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          required
          minLength={6}
          autoComplete="new-password"
        />
      </div>
      {error && <p>{error}</p>}
      <button type="submit" disabled={isLoading}>
        {isLoading ? 'Updating...' : 'Update password'}
      </button>
    </form>
  )
}
