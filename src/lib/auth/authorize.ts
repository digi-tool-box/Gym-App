import { redirect } from 'next/navigation'
import { getUser, type Profile } from './get-session'

export type Role = Profile['role']

const ROLE_HIERARCHY: Record<Role, number> = {
  owner: 4,
  manager: 3,
  trainer: 2,
  receptionist: 1,
}

export function roleGte(userRole: Role, minimum: Role): boolean {
  return ROLE_HIERARCHY[userRole] >= ROLE_HIERARCHY[minimum]
}

export async function requireAuth(): Promise<Profile> {
  const { user, supabase } = await getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', user.id)
    .maybeSingle()

  if (!profile || !profile.is_active) {
    redirect('/login?error=account_disabled')
  }

  return profile
}

export async function requireRole(minimumRole: Role): Promise<Profile> {
  const profile = await requireAuth()
  if (!roleGte(profile.role, minimumRole)) redirect('/login')
  return profile
}
