'use client'

import { useRouter, usePathname } from 'next/navigation'
import { useState } from 'react'
import { useSupabase } from '@/providers/supabase-provider'

type MembershipType = { id: string; name: string; duration_days: number; price: number }

type Member = {
  id: string
  full_name: string
  email: string | null
  phone: string | null
  membership_type_id: string | null
  membership_start: string | null
  membership_end: string | null
  is_active: boolean
  notes: string | null
}

type Props =
  | { mode: 'create'; member?: never; membershipTypes: MembershipType[] }
  | { mode: 'edit'; member: Member; membershipTypes: MembershipType[] }

export function MemberForm(props: Props) {
  const { supabase } = useSupabase()
  const router = useRouter()
  const pathname = usePathname()
  const slug = pathname.split('/')[1]

  const isEdit = props.mode === 'edit'
  const initial = props.member

  const [fullName, setFullName] = useState(initial?.full_name ?? '')
  const [email, setEmail] = useState(initial?.email ?? '')
  const [phone, setPhone] = useState(initial?.phone ?? '')
  const [membershipTypeId, setMembershipTypeId] = useState(initial?.membership_type_id ?? '')
  const [membershipStart, setMembershipStart] = useState(initial?.membership_start?.slice(0, 10) ?? '')
  const [membershipEnd, setMembershipEnd] = useState(initial?.membership_end?.slice(0, 10) ?? '')
  const [isActive, setIsActive] = useState(initial?.is_active ?? true)
  const [notes, setNotes] = useState(initial?.notes ?? '')
  const [error, setError] = useState<string | null>(null)
  const [isLoading, setIsLoading] = useState(false)

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setError(null)
    setIsLoading(true)

    const payload = {
      full_name: fullName.trim(),
      email: email.trim() || null,
      phone: phone.trim() || null,
      membership_type_id: membershipTypeId || null,
      membership_start: membershipStart || null,
      membership_end: membershipEnd || null,
      is_active: isActive,
      notes: notes.trim() || null,
    }

    if (isEdit) {
      const { error: updateError } = await supabase
        .from('members')
        .update(payload)
        .eq('id', initial!.id)

      if (updateError) {
        setError(updateError.message)
        setIsLoading(false)
        return
      }

      router.push(`/${slug}/members/${initial!.id}`)
      router.refresh()
    } else {
      const { error: insertError } = await supabase
        .from('members')
        .insert(payload)

      if (insertError) {
        setError(insertError.message)
        setIsLoading(false)
        return
      }

      router.push(`/${slug}/members`)
      router.refresh()
    }
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-6">
      {error && (
        <div className="rounded-lg border border-red-200 bg-red-50 p-3 text-sm text-red-700 dark:border-red-800 dark:bg-red-950 dark:text-red-400">
          {error}
        </div>
      )}

      <div className="space-y-4 rounded-xl border bg-white p-6 dark:border-gray-800 dark:bg-gray-900">
        <h2 className="text-lg font-semibold text-gray-900 dark:text-gray-50">Personal Info</h2>

        <div>
          <label htmlFor="fullName" className="block text-sm font-medium text-gray-700 dark:text-gray-300">
            Full name <span className="text-red-500">*</span>
          </label>
          <input
            id="fullName"
            type="text"
            value={fullName}
            onChange={(e) => setFullName(e.target.value)}
            required
            className="mt-1 w-full rounded-lg border bg-white px-3 py-2 text-sm text-gray-900 dark:border-gray-700 dark:bg-gray-950 dark:text-gray-50"
          />
        </div>

        <div className="grid gap-4 sm:grid-cols-2">
          <div>
            <label htmlFor="email" className="block text-sm font-medium text-gray-700 dark:text-gray-300">
              Email
            </label>
            <input
              id="email"
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              autoComplete="email"
              className="mt-1 w-full rounded-lg border bg-white px-3 py-2 text-sm text-gray-900 dark:border-gray-700 dark:bg-gray-950 dark:text-gray-50"
            />
          </div>

          <div>
            <label htmlFor="phone" className="block text-sm font-medium text-gray-700 dark:text-gray-300">
              Phone
            </label>
            <input
              id="phone"
              type="tel"
              value={phone}
              onChange={(e) => setPhone(e.target.value)}
              className="mt-1 w-full rounded-lg border bg-white px-3 py-2 text-sm text-gray-900 dark:border-gray-700 dark:bg-gray-950 dark:text-gray-50"
            />
          </div>
        </div>
      </div>

      <div className="space-y-4 rounded-xl border bg-white p-6 dark:border-gray-800 dark:bg-gray-900">
        <h2 className="text-lg font-semibold text-gray-900 dark:text-gray-50">Membership</h2>

        <div>
          <label htmlFor="membershipType" className="block text-sm font-medium text-gray-700 dark:text-gray-300">
            Membership type
          </label>
          <select
            id="membershipType"
            value={membershipTypeId}
            onChange={(e) => setMembershipTypeId(e.target.value)}
            className="mt-1 w-full rounded-lg border bg-white px-3 py-2 text-sm text-gray-900 dark:border-gray-700 dark:bg-gray-950 dark:text-gray-50"
          >
            <option value="">No membership</option>
            {props.membershipTypes.map((mt) => (
              <option key={mt.id} value={mt.id}>
                {mt.name} — ${mt.price} / {mt.duration_days} days
              </option>
            ))}
          </select>
        </div>

        <div className="grid gap-4 sm:grid-cols-2">
          <div>
            <label htmlFor="membershipStart" className="block text-sm font-medium text-gray-700 dark:text-gray-300">
              Start date
            </label>
            <input
              id="membershipStart"
              type="date"
              value={membershipStart}
              onChange={(e) => setMembershipStart(e.target.value)}
              className="mt-1 w-full rounded-lg border bg-white px-3 py-2 text-sm text-gray-900 dark:border-gray-700 dark:bg-gray-950 dark:text-gray-50"
            />
          </div>

          <div>
            <label htmlFor="membershipEnd" className="block text-sm font-medium text-gray-700 dark:text-gray-300">
              End date
            </label>
            <input
              id="membershipEnd"
              type="date"
              value={membershipEnd}
              onChange={(e) => setMembershipEnd(e.target.value)}
              className="mt-1 w-full rounded-lg border bg-white px-3 py-2 text-sm text-gray-900 dark:border-gray-700 dark:bg-gray-950 dark:text-gray-50"
            />
          </div>
        </div>
      </div>

      <div className="space-y-4 rounded-xl border bg-white p-6 dark:border-gray-800 dark:bg-gray-900">
        <h2 className="text-lg font-semibold text-gray-900 dark:text-gray-50">Additional</h2>

        <div>
          <label htmlFor="notes" className="block text-sm font-medium text-gray-700 dark:text-gray-300">
            Notes
          </label>
          <textarea
            id="notes"
            rows={3}
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            className="mt-1 w-full rounded-lg border bg-white px-3 py-2 text-sm text-gray-900 dark:border-gray-700 dark:bg-gray-950 dark:text-gray-50"
          />
        </div>

        <label className="flex items-center gap-2">
          <input
            type="checkbox"
            checked={isActive}
            onChange={(e) => setIsActive(e.target.checked)}
            className="rounded border-gray-300 text-blue-600 dark:border-gray-600"
          />
          <span className="text-sm text-gray-700 dark:text-gray-300">Active member</span>
        </label>
      </div>

      <div className="flex items-center gap-3">
        <button
          type="submit"
          disabled={isLoading}
          className="rounded-lg bg-blue-600 px-6 py-2 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50"
        >
          {isLoading ? 'Saving...' : isEdit ? 'Update Member' : 'Add Member'}
        </button>
        <button
          type="button"
          onClick={() => router.back()}
          className="rounded-lg border bg-white px-6 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 dark:border-gray-700 dark:bg-gray-900 dark:text-gray-300 dark:hover:bg-gray-800"
        >
          Cancel
        </button>
      </div>
    </form>
  )
}
