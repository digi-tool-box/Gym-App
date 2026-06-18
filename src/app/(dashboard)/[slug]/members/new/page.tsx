import { createClient } from '@/lib/supabase/server'
import { requireAuth } from '@/lib/auth/authorize'
import { MemberForm } from '@/components/members/member-form'

export default async function NewMemberPage() {
  await requireAuth()

  const supabase = await createClient()

  const { data: membershipTypes } = await supabase
    .from('membership_types')
    .select('id, name, duration_days, price')
    .eq('is_active', true)
    .order('name')

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900 dark:text-gray-50">Add Member</h1>
        <p className="mt-1 text-sm text-gray-500 dark:text-gray-400">
          Register a new member in your gym
        </p>
      </div>

      <div className="max-w-2xl">
        <MemberForm
          membershipTypes={membershipTypes ?? []}
          mode="create"
        />
      </div>
    </div>
  )
}
