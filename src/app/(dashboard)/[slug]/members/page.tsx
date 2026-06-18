import { createClient } from '@/lib/supabase/server'
import { requireAuth } from '@/lib/auth/authorize'
import { MemberList } from '@/components/members/member-list'

type Props = {
  params: { slug: string }
  searchParams: { search?: string; status?: string; membership_type_id?: string; page?: string }
}

export default async function MembersPage({ searchParams }: Props) {
  await requireAuth()

  const search = searchParams.search?.trim() || ''
  const status = searchParams.status || 'active'
  const membershipTypeId = searchParams.membership_type_id || ''
  const page = Math.max(1, Number(searchParams.page) || 1)
  const perPage = 20

  const supabase = await createClient()

  let query = supabase.from('members').select('*, membership_types(name)', { count: 'exact' })

  if (search) {
    query = query.ilike('full_name', `%${search}%`)
  }

  if (status === 'active') {
    query = query.eq('is_active', true)
  } else if (status === 'inactive') {
    query = query.eq('is_active', false)
  }

  if (membershipTypeId) {
    query = query.eq('membership_type_id', membershipTypeId)
  }

  const from = (page - 1) * perPage
  const to = from + perPage - 1

  const { data: members, count: totalCount } = await query
    .order('created_at', { ascending: false })
    .range(from, to)

  const { data: membershipTypes } = await supabase
    .from('membership_types')
    .select('id, name')
    .eq('is_active', true)
    .order('name')

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 dark:text-gray-50">Members</h1>
          <p className="mt-1 text-sm text-gray-500 dark:text-gray-400">
            Manage your gym members
          </p>
        </div>
      </div>

      <MemberList
        members={(members as unknown[]) as any[]}
        totalCount={totalCount ?? 0}
        currentPage={page}
        perPage={perPage}
        membershipTypes={membershipTypes ?? []}
        initialSearch={search}
        initialStatus={status}
        initialMembershipTypeId={membershipTypeId}
      />
    </div>
  )
}
