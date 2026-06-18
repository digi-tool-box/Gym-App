import { NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'

async function performLogout() {
  const supabase = await createClient()
  await supabase.auth.signOut()

  const siteUrl = process.env.NEXT_PUBLIC_SITE_URL
    || process.env.NEXT_PUBLIC_VERCEL_URL
    || 'http://localhost:3000'

  return NextResponse.redirect(
    new URL('/login', siteUrl.startsWith('http') ? siteUrl : `https://${siteUrl}`)
  )
}

export async function POST() {
  return performLogout()
}

export async function GET() {
  return performLogout()
}
