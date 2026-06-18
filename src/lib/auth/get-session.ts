import { createClient } from '@/lib/supabase/server'
import type { Database } from '@/types/supabase'
import type { SupabaseClient, User } from '@supabase/supabase-js'

export type Profile = Database['public']['Tables']['profiles']['Row']

export async function getUser(): Promise<{ user: User | null; supabase: SupabaseClient<Database> }> {
  const supabase = await createClient()
  const { data, error } = await supabase.auth.getUser()
  if (error || !data.user) return { user: null, supabase }
  return { user: data.user, supabase }
}

export async function getProfile(): Promise<Profile | null> {
  const { user, supabase } = await getUser()
  if (!user) return null

  const { data, error } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', user.id)
    .maybeSingle()

  if (error || !data) return null
  return data
}

export async function getProfileByUserId(userId: string): Promise<Profile | null> {
  const supabase = await createClient()
  const { data, error } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', userId)
    .maybeSingle()

  if (error || !data) return null
  return data
}
