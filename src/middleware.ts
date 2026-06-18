import { updateSession } from '@/lib/supabase/middleware'
import { NextResponse, type NextRequest } from 'next/server'
import { PUBLIC_ROUTES, STATIC_ASSET_PATTERN } from '@/lib/constants'

export async function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl

  if (STATIC_ASSET_PATTERN.test(pathname)) return NextResponse.next()

  const { supabase, supabaseResponse, user } = await updateSession(request)

  const isPublic = PUBLIC_ROUTES.some(
    (route) => pathname === route
  )

  if (user && isPublic) {
    const { data: profile } = await supabase
      .from('profiles')
      .select('tenant_id')
      .eq('id', user.id)
      .maybeSingle()

    if (profile) {
      const { data: tenant } = await supabase
        .from('tenants')
        .select('slug')
        .eq('id', profile.tenant_id)
        .maybeSingle()

      if (tenant) return NextResponse.redirect(new URL(`/${tenant.slug}`, request.url))
    }

    return NextResponse.redirect(new URL('/', request.url))
  }

  if (isPublic) return supabaseResponse

  if (!user) {
    const loginUrl = new URL('/login', request.url)
    loginUrl.searchParams.set('redirect', pathname)
    return NextResponse.redirect(loginUrl)
  }

  const { data: profile } = await supabase
    .from('profiles')
    .select('role, tenant_id, is_active')
    .eq('id', user.id)
    .maybeSingle()

  if (!profile || !profile.is_active) {
    const loginUrl = new URL('/login', request.url)
    loginUrl.searchParams.set('error', 'account_disabled')
    return NextResponse.redirect(loginUrl)
  }

  const firstSegment = pathname.split('/')[1]

  if (firstSegment && !pathname.startsWith('/api/') && !pathname.startsWith('/auth/')) {
    const { data: tenant } = await supabase
      .from('tenants')
      .select('id, slug, is_active')
      .eq('slug', firstSegment)
      .maybeSingle()

    if (tenant && tenant.is_active && profile.tenant_id !== tenant.id) {
      const { data: userTenant } = await supabase
        .from('tenants')
        .select('slug')
        .eq('id', profile.tenant_id)
        .maybeSingle()

      if (userTenant) return NextResponse.redirect(new URL(`/${userTenant.slug}`, request.url))
      return NextResponse.redirect(new URL('/login', request.url))
    }

    if (!tenant || !tenant.is_active) {
      const { data: userTenant } = await supabase
        .from('tenants')
        .select('slug')
        .eq('id', profile.tenant_id)
        .maybeSingle()

      if (userTenant) return NextResponse.redirect(new URL(`/${userTenant.slug}`, request.url))
      return NextResponse.redirect(new URL('/login', request.url))
    }
  }

  return supabaseResponse
}

export const config = {
  matcher: ['/((?!_next/|favicon.ico|manifest.json|sw.js).*)'],
}
