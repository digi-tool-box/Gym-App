import { notFound } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import { requireAuth } from '@/lib/auth/authorize'
import { MemberDetail } from '@/components/members/member-detail'

type Props = {
  params: { slug: string; memberId: string }
}

export default async function MemberDetailPage({ params }: Props) {
  await requireAuth()

  const supabase = await createClient()

  const [memberResult, attendanceResult] = await Promise.all([
    supabase
      .from('members')
      .select('*, membership_types(name, duration_days, price)')
      .eq('id', params.memberId)
      .maybeSingle(),
    supabase
      .from('attendance')
      .select('*')
      .eq('member_id', params.memberId)
      .order('check_in', { ascending: false })
      .limit(10),
  ])

  const member = memberResult.data
  if (!member) notFound()

  const recentAttendance = attendanceResult.data ?? []

  return (
    <div className="space-y-6">
      <MemberDetail
        member={(member as unknown) as any}
        recentAttendance={(recentAttendance ?? []) as any[]}
      />
    </div>
  )
}
