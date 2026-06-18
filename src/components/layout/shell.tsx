'use client'

import { useState, useCallback } from 'react'
import { ThemeToggle } from './theme-toggle'
import { UserMenu } from './user-menu'
import { Sidebar } from './sidebar'

export function DashboardShell({ children }: { children: React.ReactNode }) {
  const [sidebarOpen, setSidebarOpen] = useState(false)
  const closeSidebar = useCallback(() => setSidebarOpen(false), [])

  return (
    <div className="flex h-screen overflow-hidden bg-white dark:bg-gray-950">
      <DesktopSidebar />
      <MobileSidebar open={sidebarOpen} onClose={closeSidebar} />
      <div className="flex flex-1 flex-col overflow-hidden">
        <Header onToggle={() => setSidebarOpen((v) => !v)} />
        <main className="flex-1 overflow-y-auto p-4 md:p-6 lg:p-8 scrollbar-thin">
          {children}
        </main>
      </div>
    </div>
  )
}

function DesktopSidebar() {
  return (
    <aside className="hidden border-r bg-gray-50 dark:border-gray-800 dark:bg-gray-900 lg:flex lg:flex-col" style={{ width: 'var(--sidebar-width)' }}>
      <div className="flex h-16 items-center gap-2 border-b px-6 dark:border-gray-800">
        <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-blue-600 text-sm font-bold text-white">G</div>
        <span className="text-lg font-semibold text-gray-900 dark:text-gray-50">GymFlow</span>
      </div>
      <div className="flex-1 overflow-y-auto scrollbar-thin">
        <Sidebar />
      </div>
    </aside>
  )
}

function MobileSidebar({ open, onClose }: { open: boolean; onClose: () => void }) {
  return (
    <>
      {open && <div className="fixed inset-0 z-40 bg-black/50 lg:hidden" onClick={onClose} />}
      <aside
        className={`fixed inset-y-0 left-0 z-50 w-64 transform border-r bg-gray-50 transition-transform duration-200 ease-in-out dark:border-gray-800 dark:bg-gray-900 lg:hidden ${
          open ? 'translate-x-0' : '-translate-x-full'
        }`}
      >
        <div className="flex h-16 items-center justify-between border-b px-6 dark:border-gray-800">
          <div className="flex items-center gap-2">
            <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-blue-600 text-sm font-bold text-white">G</div>
            <span className="text-lg font-semibold text-gray-900 dark:text-gray-50">GymFlow</span>
          </div>
          <button onClick={onClose} className="rounded-lg p-2 text-gray-500 hover:bg-gray-100 dark:text-gray-400 dark:hover:bg-gray-800">
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="h-5 w-5">
              <line x1="18" y1="6" x2="6" y2="18" /><line x1="6" y1="6" x2="18" y2="18" />
            </svg>
          </button>
        </div>
        <div className="overflow-y-auto scrollbar-thin">
          <Sidebar onNav={onClose} />
        </div>
      </aside>
    </>
  )
}

function Header({ onToggle }: { onToggle: () => void }) {
  return (
    <header className="flex h-16 items-center justify-between border-b bg-white px-4 dark:border-gray-800 dark:bg-gray-950 md:px-6">
      <div className="flex items-center gap-3">
        <button
          onClick={onToggle}
          className="rounded-lg p-2 text-gray-600 hover:bg-gray-100 dark:text-gray-400 dark:hover:bg-gray-800 lg:hidden"
          aria-label="Toggle sidebar"
        >
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="h-5 w-5">
            <line x1="3" y1="6" x2="21" y2="6" />
            <line x1="3" y1="12" x2="21" y2="12" />
            <line x1="3" y1="18" x2="21" y2="18" />
          </svg>
        </button>
        <div className="text-sm text-gray-500 dark:text-gray-400">
          <span className="hidden sm:inline">Welcome back,</span>
          <span className="ml-1 font-medium text-gray-900 dark:text-gray-100">User</span>
        </div>
      </div>

      <div className="flex items-center gap-2">
        <ThemeToggle />
        <UserMenu />
      </div>
    </header>
  )
}
