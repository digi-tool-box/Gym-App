'use client'

import Link from 'next/link'
import { useRouter, usePathname } from 'next/navigation'
import { useState } from 'react'
import { useSupabase } from '@/providers/supabase-provider'

type Member = {
  id: string
  code: string
  full_name: string
  email: string | null
  phone: string | null
  photo_url: string | null
  membership_type_id: string | null
  membership_start: string | null
  membership_end: string | null
  is_active: boolean
  notes: string | null
  created_at: string
  membership_types: { name: string; duration_days: number; price: number } | null
}

type Attendance = {
  id: string
  check_in: string
  check_out: string | null
  method: 'qr' | 'manual'
}

type Props = {
  member: Member
  recentAttendance: Attendance[]
}

export function MemberDetail({ member, recentAttendance }: Props) {
  const router = useRouter()
  const pathname = usePathname()
  const { supabase } = useSupabase()
  const slug = pathname.split('/')[1]
  const [isDeleting, setIsDeleting] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function handleDelete() {
    if (!window.confirm('Are you sure you want to delete this member?')) return

    setIsDeleting(true)
    setError(null)

    const { error: deleteError } = await supabase
      .from('members')
      .delete()
      .eq('id', member.id)

    setIsDeleting(false)

    if (deleteError) {
      setError(deleteError.message)
      return
    }

    router.push(`/${slug}/members`)
    router.refresh()
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <Link
            href={`/${slug}/members`}
            className="text-sm text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200"
          >
            &larr; Back to members
          </Link>
          <h1 className="mt-1 text-2xl font-bold text-gray-900 dark:text-gray-50">
            {member.full_name}
          </h1>
          <p className="text-sm text-gray-500 dark:text-gray-400">
            Code: {member.code}
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Link
            href={`/${slug}/members/${member.id}/edit`}
            className="rounded-lg border bg-white px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 dark:border-gray-700 dark:bg-gray-900 dark:text-gray-300 dark:hover:bg-gray-800"
          >
            Edit
          </Link>
          <button
            onClick={handleDelete}
            disabled={isDeleting}
            className="rounded-lg bg-red-600 px-4 py-2 text-sm font-medium text-white hover:bg-red-700 disabled:opacity-50"
          >
            {isDeleting ? 'Deleting...' : 'Delete'}
          </button>
        </div>
      </div>

      {error && (
        <div className="rounded-lg border border-red-200 bg-red-50 p-3 text-sm text-red-700 dark:border-red-800 dark:bg-red-950 dark:text-red-400">
          {error}
        </div>
      )}

      <div className="grid gap-6 md:grid-cols-2">
        <div className="space-y-4 rounded-xl border bg-white p-6 dark:border-gray-800 dark:bg-gray-900">
          <h2 className="text-lg font-semibold text-gray-900 dark:text-gray-50">Personal Info</h2>
          <dl className="space-y-3 text-sm">
            <div className="flex justify-between">
              <dt className="text-gray-500 dark:text-gray-400">Email</dt>
              <dd className="text-gray-900 dark:text-gray-50">{member.email || '—'}</dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-gray-500 dark:text-gray-400">Phone</dt>
              <dd className="text-gray-900 dark:text-gray-50">{member.phone || '—'}</dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-gray-500 dark:text-gray-400">Status</dt>
              <dd>
                <span
                  className={`inline-flex rounded-full px-2 py-0.5 text-xs font-medium ${
                    member.is_active
                      ? 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400'
                      : 'bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400'
                  }`}
                >
                  {member.is_active ? 'Active' : 'Inactive'}
                </span>
              </dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-gray-500 dark:text-gray-400">Registered</dt>
              <dd className="text-gray-900 dark:text-gray-50">
                {new Date(member.created_at).toLocaleDateString()}
              </dd>
            </div>
          </dl>
        </div>

        <div className="space-y-4 rounded-xl border bg-white p-6 dark:border-gray-800 dark:bg-gray-900">
          <h2 className="text-lg font-semibold text-gray-900 dark:text-gray-50">Membership</h2>
          <dl className="space-y-3 text-sm">
            <div className="flex justify-between">
              <dt className="text-gray-500 dark:text-gray-400">Type</dt>
              <dd className="text-gray-900 dark:text-gray-50">
                {member.membership_types?.name || '—'}
              </dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-gray-500 dark:text-gray-400">Start</dt>
              <dd className="text-gray-900 dark:text-gray-50">
                {member.membership_start
                  ? new Date(member.membership_start).toLocaleDateString()
                  : '—'}
              </dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-gray-500 dark:text-gray-400">End</dt>
              <dd className="text-gray-900 dark:text-gray-50">
                {member.membership_end
                  ? new Date(member.membership_end).toLocaleDateString()
                  : '—'}
              </dd>
            </div>
          </dl>
        </div>
      </div>

      {member.notes && (
        <div className="space-y-2 rounded-xl border bg-white p-6 dark:border-gray-800 dark:bg-gray-900">
          <h2 className="text-lg font-semibold text-gray-900 dark:text-gray-50">Notes</h2>
          <p className="text-sm text-gray-700 dark:text-gray-300">{member.notes}</p>
        </div>
      )}

      <div className="space-y-4 rounded-xl border bg-white p-6 dark:border-gray-800 dark:bg-gray-900">
        <h2 className="text-lg font-semibold text-gray-900 dark:text-gray-50">Recent Attendance</h2>
        {recentAttendance.length === 0 ? (
          <p className="text-sm text-gray-500 dark:text-gray-400">No check-ins recorded yet.</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left text-sm">
              <thead>
                <tr className="border-b text-gray-600 dark:border-gray-800 dark:text-gray-400">
                  <th className="pb-2 font-medium">Date</th>
                  <th className="pb-2 font-medium">Check In</th>
                  <th className="pb-2 font-medium">Check Out</th>
                  <th className="pb-2 font-medium">Method</th>
                </tr>
              </thead>
              <tbody className="divide-y dark:divide-gray-800">
                {recentAttendance.map((a) => (
                  <tr key={a.id} className="text-gray-900 dark:text-gray-50">
                    <td className="py-2">{new Date(a.check_in).toLocaleDateString()}</td>
                    <td className="py-2">{new Date(a.check_in).toLocaleTimeString()}</td>
                    <td className="py-2">
                      {a.check_out ? new Date(a.check_out).toLocaleTimeString() : '—'}
                    </td>
                    <td className="py-2 capitalize">{a.method}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  )
}
