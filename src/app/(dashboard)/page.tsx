export default function DashboardPage() {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900 dark:text-gray-50">Dashboard</h1>
        <p className="mt-1 text-sm text-gray-500 dark:text-gray-400">Overview of your gym</p>
      </div>

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {[
          { label: 'Active Members', value: '—', change: '' },
          { label: 'Today Check-ins', value: '—', change: '' },
          { label: 'Revenue This Month', value: '—', change: '' },
          { label: 'Upcoming Renewals', value: '—', change: '' },
        ].map((stat) => (
          <div key={stat.label} className="rounded-xl border bg-white p-4 dark:border-gray-800 dark:bg-gray-900">
            <p className="text-sm text-gray-500 dark:text-gray-400">{stat.label}</p>
            <p className="mt-1 text-2xl font-bold text-gray-900 dark:text-gray-50">{stat.value}</p>
          </div>
        ))}
      </div>
    </div>
  )
}
