import { notFound } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import { requireAuth } from '@/lib/auth/authorize'
import { MemberForm } from '@/components/members/member-form'

type Props = {
  params: { slug: string; memberId: string }
}

export default async function EditMemberPage({ params }: Props) {
  await requireAuth()

  const supabase = await createClient()

  const { data: member } = await supabase
    .from('members')
    .select('*')
    .eq('id', params.memberId)
    .maybeSingle()

  if (!member) notFound()

  const { data: membershipTypes } = await supabase
    .from('membership_types')
    .select('id, name, duration_days, price')
    .eq('is_active', true)
    .order('name')

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900 dark:text-gray-50">Edit Member</h1>
        <p className="mt-1 text-sm text-gray-500 dark:text-gray-400">
          Update member information
        </p>
      </div>

      <div className="max-w-2xl">
        <MemberForm
          member={(member as unknown) as any}
          membershipTypes={membershipTypes ?? []}
          mode="edit"
        />
      </div>
    </div>
  )
}
