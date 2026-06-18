'use client'

import Link from 'next/link'
import { useRouter, useSearchParams, usePathname } from 'next/navigation'
import { useCallback, useState } from 'react'
import { useSupabase } from '@/providers/supabase-provider'

type MembershipType = { id: string; name: string }

type MemberRow = {
  id: string
  code: string
  full_name: string
  email: string | null
  phone: string | null
  membership_type_id: string | null
  membership_start: string | null
  membership_end: string | null
  is_active: boolean
  membership_types: { name: string } | null
}

type Props = {
  members: MemberRow[]
  totalCount: number
  currentPage: number
  perPage: number
  membershipTypes: MembershipType[]
  initialSearch: string
  initialStatus: string
  initialMembershipTypeId: string
}

export function MemberList({
  members,
  totalCount,
  currentPage,
  perPage,
  membershipTypes,
  initialSearch,
  initialStatus,
  initialMembershipTypeId,
}: Props) {
  const router = useRouter()
  const pathname = usePathname()
  const searchParams = useSearchParams()
  const { supabase } = useSupabase()
  const slug = pathname.split('/')[1]

  const [search, setSearch] = useState(initialSearch)
  const [deletingId, setDeletingId] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)

  const buildUrl = useCallback(
    (overrides: Record<string, string>) => {
      const params = new URLSearchParams(searchParams.toString())
      Object.entries(overrides).forEach(([k, v]) => {
        if (v) params.set(k, v)
        else params.delete(k)
      })
      if (overrides.page === undefined) {
        params.set('page', '1')
      }
      return `/${slug}/members?${params.toString()}`
    },
    [slug, searchParams]
  )

  function handleSearchSubmit(e: React.FormEvent) {
    e.preventDefault()
    router.push(buildUrl({ search }))
  }

  function handleStatusChange(status: string) {
    router.push(buildUrl({ status, page: '1' }))
  }

  function handleMembershipTypeChange(id: string) {
    router.push(buildUrl({ membership_type_id: id, page: '1' }))
  }

  function handlePageChange(page: number) {
    router.push(buildUrl({ page: String(page) }))
  }

  async function handleDelete(memberId: string) {
    if (!window.confirm('Are you sure you want to delete this member?')) return

    setDeletingId(memberId)
    setError(null)

    const { error: deleteError } = await supabase
      .from('members')
      .delete()
      .eq('id', memberId)

    setDeletingId(null)

    if (deleteError) {
      setError(deleteError.message)
      return
    }

    router.refresh()
  }

  const totalPages = Math.ceil(totalCount / perPage)

  return (
    <div className="space-y-4">
      {error && (
        <div className="rounded-lg border border-red-200 bg-red-50 p-3 text-sm text-red-700 dark:border-red-800 dark:bg-red-950 dark:text-red-400">
          {error}
        </div>
      )}

      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <form onSubmit={handleSearchSubmit} className="flex gap-2">
          <input
            type="text"
            placeholder="Search members..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="w-48 rounded-lg border bg-white px-3 py-2 text-sm text-gray-900 placeholder-gray-400 dark:border-gray-700 dark:bg-gray-900 dark:text-gray-50 dark:placeholder-gray-500"
          />
          <button
            type="submit"
            className="rounded-lg bg-blue-600 px-3 py-2 text-sm font-medium text-white hover:bg-blue-700"
          >
            Search
          </button>
        </form>

        <Link
          href={`/${slug}/members/new`}
          className="inline-flex items-center gap-1.5 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
        >
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="h-4 w-4">
            <line x1="12" y1="5" x2="12" y2="19" /><line x1="5" y1="12" x2="19" y2="12" />
          </svg>
          Add Member
        </Link>
      </div>

      <div className="flex flex-wrap gap-3">
        <select
          value={initialStatus}
          onChange={(e) => handleStatusChange(e.target.value)}
          className="rounded-lg border bg-white px-3 py-2 text-sm dark:border-gray-700 dark:bg-gray-900 dark:text-gray-50"
        >
          <option value="active">Active</option>
          <option value="inactive">Inactive</option>
          <option value="all">All</option>
        </select>

        {membershipTypes.length > 0 && (
          <select
            value={initialMembershipTypeId}
            onChange={(e) => handleMembershipTypeChange(e.target.value)}
            className="rounded-lg border bg-white px-3 py-2 text-sm dark:border-gray-700 dark:bg-gray-900 dark:text-gray-50"
          >
            <option value="">All Types</option>
            {membershipTypes.map((mt) => (
              <option key={mt.id} value={mt.id}>{mt.name}</option>
            ))}
          </select>
        )}
      </div>

      {members.length === 0 ? (
        <div className="rounded-xl border bg-white p-8 text-center dark:border-gray-800 dark:bg-gray-900">
          <p className="text-gray-500 dark:text-gray-400">No members found</p>
          <Link
            href={`/${slug}/members/new`}
            className="mt-2 inline-block text-sm font-medium text-blue-600 hover:text-blue-500"
          >
            Add your first member
          </Link>
        </div>
      ) : (
        <>
          <div className="overflow-x-auto rounded-xl border dark:border-gray-800">
            <table className="w-full text-left text-sm">
              <thead>
                <tr className="border-b bg-gray-50 text-gray-600 dark:border-gray-800 dark:bg-gray-900 dark:text-gray-400">
                  <th className="px-4 py-3 font-medium">Code</th>
                  <th className="px-4 py-3 font-medium">Name</th>
                  <th className="hidden px-4 py-3 font-medium sm:table-cell">Email</th>
                  <th className="hidden px-4 py-3 font-medium md:table-cell">Phone</th>
                  <th className="hidden px-4 py-3 font-medium lg:table-cell">Membership</th>
                  <th className="hidden px-4 py-3 font-medium lg:table-cell">Ends</th>
                  <th className="px-4 py-3 font-medium">Status</th>
                  <th className="px-4 py-3 font-medium">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y dark:divide-gray-800">
                {members.map((member) => (
                  <tr key={member.id} className="bg-white hover:bg-gray-50 dark:bg-gray-950 dark:hover:bg-gray-900">
                    <td className="px-4 py-3 font-mono text-xs text-gray-500 dark:text-gray-400">
                      {member.code}
                    </td>
                    <td className="px-4 py-3 font-medium text-gray-900 dark:text-gray-50">
                      {member.full_name}
                    </td>
                    <td className="hidden px-4 py-3 text-gray-600 dark:text-gray-400 sm:table-cell">
                      {member.email || '—'}
                    </td>
                    <td className="hidden px-4 py-3 text-gray-600 dark:text-gray-400 md:table-cell">
                      {member.phone || '—'}
                    </td>
                    <td className="hidden px-4 py-3 text-gray-600 dark:text-gray-400 lg:table-cell">
                      {member.membership_types?.name || '—'}
                    </td>
                    <td className="hidden px-4 py-3 text-gray-600 dark:text-gray-400 lg:table-cell">
                      {member.membership_end
                        ? new Date(member.membership_end).toLocaleDateString()
                        : '—'}
                    </td>
                    <td className="px-4 py-3">
                      <span
                        className={`inline-flex rounded-full px-2 py-0.5 text-xs font-medium ${
                          member.is_active
                            ? 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400'
                            : 'bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400'
                        }`}
                      >
                        {member.is_active ? 'Active' : 'Inactive'}
                      </span>
                    </td>
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-2">
                        <Link
                          href={`/${slug}/members/${member.id}`}
                          className="rounded px-2 py-1 text-xs font-medium text-blue-600 hover:bg-blue-50 dark:text-blue-400 dark:hover:bg-blue-950"
                        >
                          View
                        </Link>
                        <Link
                          href={`/${slug}/members/${member.id}/edit`}
                          className="rounded px-2 py-1 text-xs font-medium text-gray-600 hover:bg-gray-100 dark:text-gray-400 dark:hover:bg-gray-800"
                        >
                          Edit
                        </Link>
                        <button
                          onClick={() => handleDelete(member.id)}
                          disabled={deletingId === member.id}
                          className="rounded px-2 py-1 text-xs font-medium text-red-600 hover:bg-red-50 disabled:opacity-50 dark:text-red-400 dark:hover:bg-red-950"
                        >
                          {deletingId === member.id ? '...' : 'Delete'}
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {totalPages > 1 && (
            <div className="flex items-center justify-center gap-2">
              <button
                onClick={() => handlePageChange(currentPage - 1)}
                disabled={currentPage <= 1}
                className="rounded-lg border bg-white px-3 py-2 text-sm text-gray-600 hover:bg-gray-50 disabled:opacity-50 dark:border-gray-700 dark:bg-gray-900 dark:text-gray-400 dark:hover:bg-gray-800"
              >
                Previous
              </button>
              <span className="text-sm text-gray-600 dark:text-gray-400">
                Page {currentPage} of {totalPages}
              </span>
              <button
                onClick={() => handlePageChange(currentPage + 1)}
                disabled={currentPage >= totalPages}
                className="rounded-lg border bg-white px-3 py-2 text-sm text-gray-600 hover:bg-gray-50 disabled:opacity-50 dark:border-gray-700 dark:bg-gray-900 dark:text-gray-400 dark:hover:bg-gray-800"
              >
                Next
              </button>
            </div>
          )}
        </>
      )}
    </div>
  )
}
