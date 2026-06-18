'use client'

import { useSupabase } from '@/providers/supabase-provider'
import { useState } from 'react'

export function RegisterForm() {
  const { supabase } = useSupabase()

  const [fullName, setFullName] = useState('')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [gymName, setGymName] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [isLoading, setIsLoading] = useState(false)
  const [isComplete, setIsComplete] = useState(false)

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setError(null)
    setIsLoading(true)

    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        data: {
          full_name: fullName,
          gym_name: gymName,
        },
        emailRedirectTo: `${window.location.origin}/auth/callback`,
      },
    })

    if (error) {
      setError(error.message)
      setIsLoading(false)
      return
    }

    if (data.user?.identities?.length === 0) {
      setError('An account with this email already exists.')
      setIsLoading(false)
      return
    }

    setIsComplete(true)
    setIsLoading(false)
  }

  if (isComplete) {
    return (
      <div>
        <h2>Check your email</h2>
        <p>We sent a confirmation link to {email}. Click it to activate your account.</p>
        <p><a href="/login">Go to sign in</a></p>
      </div>
    )
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div>
        <label htmlFor="gymName">Gym name</label>
        <input
          id="gymName"
          type="text"
          value={gymName}
          onChange={(e) => setGymName(e.target.value)}
          required
        />
      </div>

      <div>
        <label htmlFor="fullName">Full name</label>
        <input
          id="fullName"
          type="text"
          value={fullName}
          onChange={(e) => setFullName(e.target.value)}
          required
        />
      </div>

      <div>
        <label htmlFor="email">Email</label>
        <input
          id="email"
          type="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          required
          autoComplete="email"
        />
      </div>

      <div>
        <label htmlFor="password">Password</label>
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

      {error && <div>{error}</div>}

      <button type="submit" disabled={isLoading}>
        {isLoading ? 'Creating account...' : 'Create account'}
      </button>

      <p>
        Already have an account? <a href="/login">Sign in</a>
      </p>
    </form>
  )
}
