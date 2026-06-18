import type { Metadata, Viewport } from 'next'
import { ThemeProvider } from '@/providers/theme-provider'
import { SupabaseProvider } from '@/providers/supabase-provider'
import { PWARegister } from '@/components/layout/pwa-register'
import './globals.css'

export const metadata: Metadata = {
  title: 'GymFlow — Gym Management',
  description: 'Multi-tenant gym management platform',
  manifest: '/manifest.json',
  appleWebApp: {
    capable: true,
    statusBarStyle: 'default',
    title: 'GymFlow',
  },
}

export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
  maximumScale: 1,
  themeColor: [
    { media: '(prefers-color-scheme: light)', color: '#ffffff' },
    { media: '(prefers-color-scheme: dark)', color: '#030712' },
  ],
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <head>
        <link rel="apple-touch-icon" href="/icons/icon-192.svg" />
      </head>
      <body className="min-h-screen">
        <ThemeProvider>
          <SupabaseProvider>
            <PWARegister />
            {children}
          </SupabaseProvider>
        </ThemeProvider>
      </body>
    </html>
  )
}
